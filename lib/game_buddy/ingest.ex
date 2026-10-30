defmodule GameBuddy.Ingest do
  @moduledoc """
  The pipeline: game files → Postgres snapshot of documents.

      GameBuddy.Ingest.run("eu5", "~/dev/game-data/eu5")

  Steps: detect version → load localization → parse all sources → build the
  rendering tables from the parsed files (trigger/effect templates, modifier
  formats) → localize names → cross-reference → render one document per
  entity, one index per kind, the localization text documents, the shipped
  docs and the game intro → chunk, restore cached embeddings, build full-text
  vectors → mark ready. Re-running for the same version replaces the snapshot.
  """

  require Logger
  import Ecto.Query
  alias GameBuddy.{Adapter, Loc, Pdx, Repo}
  alias GameBuddy.Catalog.{Game, GameVersion}
  alias GameBuddy.Render.{Document, Pages, Script}

  @batch 300
  @chunk_chars 1500

  def run(slug, root, opts \\ []) do
    adapter = Adapter.for_slug(slug)
    root = Path.expand(root)
    lang = Keyword.get(opts, :lang, "english")
    t0 = System.monotonic_time(:millisecond)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    info = adapter.detect_version(root)

    Logger.info(
      "ingest #{slug}: #{info.version} build=#{info.build_id} dlcs=#{inspect(info.dlcs)}"
    )

    game = upsert_game(adapter)
    remember_embeddings(game, info)
    gv = reset_version(game, info, root)
    meta = %{game: adapter.name(), version: info.version, dlcs: info.dlcs}

    # 1. localization
    loc_files = adapter.localization_files(root, lang)
    {loc, loc_rows} = GameBuddy.Ingest.Localization.load(loc_files, lang, root)

    insert_batches(
      "localizations",
      Enum.map(loc_rows, &Map.put(&1, :game_version_id, gv.id)),
      1000
    )

    concept_counts = concept_link_counts(loc_rows)
    labels = &Adapter.label_keys(adapter, &1)
    loc = loc |> Loc.index() |> Loc.with_labels(labels) |> Loc.with_cache()
    Logger.info("localization: #{length(loc_rows)} keys from #{length(loc_files)} files")

    # 2. parse + merge entities
    entities = parse_sources(adapter, root)
    Logger.info("parsed #{length(entities)} entities")

    # 3. rendering tables from the parsed files
    rk = Adapter.render_kinds(adapter)
    by_kind = Enum.group_by(entities, & &1.kind)
    defines = defines_map(by_kind[rk.defines] || [])
    loc = Loc.with_defines(loc, defines)

    # icons: the adapter names candidate textures, the files decide
    gfx_roots = Adapter.gfx_roots(adapter, root)
    icon_for = fn e -> icon_path(adapter, gfx_roots, e) end

    modifier_icons =
      for e <- by_kind[rk.modifiers] || [], p = icon_for.(e), into: %{}, do: {e.key, p}

    tables =
      Script.new(
        triggers: table(by_kind[rk.triggers]),
        effects: table(by_kind[rk.effects]),
        modifiers: table(by_kind[rk.modifiers]),
        icons: modifier_icons,
        loc: loc,
        labels: labels
      )

    # Shared read-only state for the worker pools, without copying it per task.
    tables_term = {__MODULE__, :tables, gv.id}
    keys_term = {__MODULE__, :keys, gv.id}
    conn_term = {__MODULE__, :connections, gv.id}
    :persistent_term.put(tables_term, tables)
    :persistent_term.put(keys_term, MapSet.new(entities, & &1.key))
    other_key? = fn k -> MapSet.member?(:persistent_term.get(keys_term), k) end

    {entities, refs, text_docs} =
      try do
        # 4. names, descriptions, attached text
        entities =
          entities
          |> Task.async_stream(
            fn e ->
              e
              |> decorate(adapter, :persistent_term.get(tables_term).loc, other_key?)
              |> Map.put(:icon, icon_for.(e))
            end,
            ordered: true,
            timeout: 300_000
          )
          |> Enum.map(fn {:ok, e} -> e end)

        Logger.info("localized: #{Enum.count(entities, & &1.name)} named")

        # 5. cross references
        # a key defined in several kinds links to the richest definition unless
        # the reference carries a kind prefix (`government_type:monarchy`)
        kinds_for_key =
          entities
          |> Enum.group_by(& &1.key, &{&1.kind, map_size(&1.data || %{})})
          |> Map.new(fn {k, kinds} ->
            {k, kinds |> Enum.sort_by(fn {_, n} -> -n end) |> Enum.map(&elem(&1, 0))}
          end)

        # glossary links inside localized text are references too
        concepts = by_kind[rk.concepts] || []
        concept_keys = MapSet.new(concepts, & &1.key)
        alias_map = concept_aliases(concepts)
        loc0 = :persistent_term.get(tables_term).loc

        refs =
          Enum.flat_map(entities, fn e ->
            refs_for(e, kinds_for_key) ++
              text_refs(e, loc0, adapter, rk.concepts, concept_keys, alias_map)
          end)
          |> Enum.uniq_by(&{&1.from_kind, &1.from_key, &1.to_kind, &1.to_key})

        names = Map.new(entities, &{{&1.kind, &1.key}, &1.name})
        outgoing = Enum.group_by(refs, &{&1.from_kind, &1.from_key}, &{&1.to_kind, &1.to_key})
        incoming = Enum.group_by(refs, &{&1.to_kind, &1.to_key}, &{&1.from_kind, &1.from_key})
        :persistent_term.put(conn_term, {names, outgoing, incoming})
        Logger.info("#{length(refs)} references")

        # 6. one document per entity
        entities =
          entities
          |> Task.async_stream(
            fn e ->
              t = :persistent_term.get(tables_term)
              conn = connections_for(e, :persistent_term.get(conn_term))
              sections = Document.build(e, t, conn, meta)
              e |> Map.put(:sections, sections) |> Map.put(:card, Document.to_markdown(sections))
            end,
            ordered: true,
            timeout: 300_000
          )
          |> Enum.map(fn {:ok, e} -> e end)

        topics = topic_docs(entities, rk, {names, outgoing, incoming}, defines, meta, gv.id, now)
        {entities, refs, localization_docs(tables.loc, loc_rows, gv.id, now) ++ topics}
      after
        Enum.each([tables_term, keys_term, conn_term], &:persistent_term.erase/1)
      end

    Logger.info("rendered #{length(entities)} documents")

    # 7. insert entities, keep ids
    rows =
      Enum.map(entities, fn e ->
        %{
          game_version_id: gv.id,
          kind: e.kind,
          key: e.key,
          name: e.name,
          description: e.description,
          data: e.data,
          ast: %{"statements" => e.ast},
          source_file: e.source_file,
          source_line: e.source_line,
          dlc: e.dlc,
          card: e.card,
          inserted_at: now,
          updated_at: now
        }
      end)

    ids = insert_batches_returning("entities", rows, @batch, [:id, :kind, :key])
    id_of = Map.new(ids, fn %{id: id, kind: k, key: key} -> {{k, key}, id} end)

    ref_rows =
      for r <- refs,
          from = id_of[{r.from_kind, r.from_key}],
          from != nil,
          do: %{from_entity_id: from, path: r.path, to_kind: r.to_kind, to_key: r.to_key}

    insert_batches("entity_refs", ref_rows, 2000)

    # 8. documents: entities, indexes, intro, localization text, shipped docs
    entity_docs =
      Enum.map(entities, fn e ->
        doc(
          gv.id,
          e.kind,
          e.key,
          e.name || e.key,
          e.card,
          e.source_file,
          e.dlc,
          now,
          id_of[{e.kind, e.key}],
          e.sections
        )
      end)

    index_docs =
      Enum.flat_map(Enum.group_by(entities, & &1.kind), fn {kind, es} ->
        for p <- Pages.index(kind, es, tables, meta),
            do:
              doc(
                gv.id,
                "index",
                p.key |> String.replace_prefix("index/", ""),
                p.title,
                p.body,
                nil,
                nil,
                now
              )
      end)

    shipped = shipped_docs(adapter, root, gv.id, now)
    by_kind = Enum.group_by(entities, & &1.kind)

    intro =
      Pages.intro(
        meta,
        kinds_summary(entities),
        core_concepts(by_kind[rk.concepts] || [], concept_counts),
        Adapter.intro_notes(adapter, fn kind, key ->
          Enum.find(by_kind[kind] || [], &(&1.key == key))
        end),
        %{entities: length(entities), text_docs: length(text_docs), doc_files: length(shipped)}
      )

    doc_rows =
      entity_docs ++
        index_docs ++
        [doc(gv.id, "intro", "game", "#{meta.game} #{meta.version}", intro, nil, nil, now)] ++
        text_docs ++ shipped

    Loc.drop_cache(loc)
    doc_ids = insert_batches_returning("documents", doc_rows, @batch, [:id, :kind, :key])
    doc_id_of = Map.new(doc_ids, fn %{id: id, kind: k, key: key} -> {{k, key}, id} end)

    # 9. chunks
    chunk_rows =
      Enum.flat_map(doc_rows, fn d ->
        d.body
        |> chunk_text()
        |> Enum.with_index()
        |> Enum.map(fn {text, i} ->
          %{document_id: doc_id_of[{d.kind, d.key}], ord: i, text: text}
        end)
      end)

    insert_batches("chunks", chunk_rows, 1000)
    cached = restore_embeddings(gv.id)
    build_search_vectors(gv.id)

    elapsed = System.monotonic_time(:millisecond) - t0

    stats = %{
      localization_files: length(loc_files),
      localization_keys: length(loc_rows),
      entities: length(entities),
      entities_named: Enum.count(entities, & &1.name),
      entities_described: Enum.count(entities, & &1.description),
      entity_refs: length(ref_rows),
      documents: map_size(doc_id_of),
      chunks: length(chunk_rows),
      chunks_embedded_from_cache: cached,
      elapsed_ms: elapsed
    }

    gv
    |> GameVersion.changeset(%{status: "ready", ingested_at: now, stats: stats, is_default: true})
    |> Repo.update!()
    |> tap(fn gv -> clear_other_defaults(gv) end)
    |> tap(fn _ -> Logger.info("done in #{elapsed} ms: #{inspect(stats)}") end)
  end

  defp doc(
         gv_id,
         kind,
         key,
         title,
         body,
         source_file,
         dlc,
         now,
         entity_id \\ nil,
         sections \\ nil
       ) do
    %{
      game_version_id: gv_id,
      entity_id: entity_id,
      sections: sections,
      kind: kind,
      key: key,
      title: title,
      body: body,
      source_file: source_file,
      dlc: dlc,
      inserted_at: now,
      updated_at: now
    }
  end

  # -- catalog -------------------------------------------------------------

  defp upsert_game(adapter) do
    Repo.insert!(
      %Game{slug: adapter.slug(), name: adapter.name(), engine: adapter.engine()},
      on_conflict: {:replace, [:name, :engine, :updated_at]},
      conflict_target: :slug,
      returning: true
    )
  end

  # The new snapshot first takes over the converted textures of the snapshot it
  # replaces (same version string), so a re-ingest does not redo the conversion;
  # the temporary version name avoids colliding with the old row until it is gone.
  defp reset_version(game, info, root) do
    build = info.build_id || info.version

    old_ids =
      Repo.all(
        from(gv in GameVersion,
          where:
            gv.game_id == ^game.id and (gv.version == ^info.version or gv.build_id == ^build),
          select: gv.id
        )
      )

    gv =
      %GameVersion{}
      |> GameVersion.changeset(%{
        game_id: game.id,
        version: info.version <> "~ingesting",
        build_id: info.build_id,
        build_date: info[:build_date],
        dlcs: info.dlcs,
        source_path: root,
        status: "ingesting"
      })
      |> Repo.insert!()

    if old_ids != [] do
      {moved, _} =
        Repo.update_all(
          from(a in "assets", where: a.game_version_id in ^old_ids),
          [set: [game_version_id: gv.id]],
          timeout: :infinity
        )

      Logger.info("kept #{moved} converted textures from the previous snapshot")

      Repo.delete_all(from(v in GameVersion, where: v.id in ^old_ids), timeout: :infinity)
    end

    gv |> GameVersion.changeset(%{version: info.version}) |> Repo.update!()
  end

  defp clear_other_defaults(gv) do
    Repo.update_all(
      from(v in GameVersion,
        where: v.game_id == ^gv.game_id and v.id != ^gv.id and v.is_default == true
      ),
      [set: [is_default: false]],
      timeout: :infinity
    )
  end

  # -- parsing --------------------------------------------------------------

  defp parse_sources(adapter, root) do
    skip = adapter.skip_top_level_keys()

    adapter.sources(root)
    |> Enum.with_index()
    |> Enum.flat_map(fn {source, order} ->
      source.files
      |> Task.async_stream(fn f -> parse_file(f, source, root, skip) end,
        ordered: true,
        timeout: 120_000
      )
      |> Enum.flat_map(fn {:ok, es} -> es end)
      |> Enum.map(&Map.put(&1, :order, order))
    end)
    |> Enum.reduce(%{}, fn e, acc ->
      key = {e.kind, e.key}

      case {Map.get(acc, key), e[:merge]} do
        # setup-style definitions accumulate across files
        {%{} = prev, true} -> Map.put(acc, key, merge_entities(prev, e))
        _ -> Map.put(acc, key, e)
      end
    end)
    |> Map.values()
    |> Enum.sort_by(&{&1.kind, &1.source_file, &1.source_line})
  end

  defp merge_entities(prev, e) do
    %{prev | data: deep_merge(prev.data, e.data), ast: prev.ast ++ e.ast}
  end

  defp deep_merge(a, b) when is_map(a) and is_map(b) do
    Map.merge(a, b, fn _k, va, vb -> deep_merge(va, vb) end)
  end

  defp deep_merge(a, b) when is_list(a) and is_list(b), do: a ++ b
  defp deep_merge(_a, b), do: b

  defp parse_file(path, source, root, skip) do
    rel = Path.relative_to(path, root)

    case Pdx.parse_file(path) do
      {:ok, ast, warnings} ->
        unless warnings == [], do: Logger.debug("#{rel}: #{inspect(warnings)}")

        case Map.get(source, :mode, :flat) do
          :flat ->
            statements_to_entities(ast, source.kind, rel, source.dlc, skip)

          :file ->
            key = Path.basename(rel, Path.extname(rel))
            data = Pdx.fold(ast)
            data = if is_map(data), do: data, else: %{"_items" => data}

            [
              %{
                kind: source.kind,
                key: key,
                data: data,
                ast: Pdx.ast_to_json(ast),
                source_file: rel,
                source_line: 1,
                dlc: source.dlc
              }
            ]

          :nested ->
            Enum.flat_map(ast, fn
              %{k: k, v: %{block: stmts}} when is_binary(k) ->
                stmts
                |> unwrap_single_wrapper()
                |> statements_to_entities("#{source.kind}_#{k}", rel, source.dlc, skip)
                |> Enum.map(&Map.put(&1, :merge, true))

              %{k: k} = s when is_binary(k) ->
                statements_to_entities([s], source.kind, rel, source.dlc, skip)

              _ ->
                []
            end)
        end

      {:error, reason} ->
        Logger.warning("#{rel}: #{reason}")
        []
    end
  end

  # `countries = { countries = { DAN = {...} } }` → the inner statements
  defp unwrap_single_wrapper([%{k: k, v: %{block: inner}}]) when is_binary(k),
    do: unwrap_single_wrapper(inner)

  defp unwrap_single_wrapper(stmts), do: stmts

  defp statements_to_entities(statements, kind, rel, dlc, skip) do
    statements
    |> Enum.reject(fn s ->
      not Map.has_key?(s, :k) or s.k in skip or String.starts_with?(s.k, "@")
    end)
    |> Enum.map(fn s ->
      {data, ast_json} =
        case s.v do
          %{block: stmts} ->
            {Pdx.fold(stmts), Pdx.ast_to_json(stmts)}

          %{tag: _} = v ->
            {Pdx.fold([%{k: s.k, op: s.op, v: v, line: s.line}])[s.k], Pdx.ast_to_json([s])}

          scalar ->
            {%{"_value" => scalar}, Pdx.ast_to_json([s])}
        end

      data = if is_map(data), do: data, else: %{"_items" => data}

      %{
        kind: kind,
        key: s.k,
        data: data,
        ast: ast_json,
        source_file: rel,
        source_line: s.line,
        dlc: dlc
      }
    end)
  end

  # -- rendering tables ------------------------------------------------------

  # `NCombat.COMBAT_DICE_SIDE => 10` from the defines entities (one per group)
  defp defines_map(entities) do
    for e <- entities, is_map(e.data), {k, v} <- e.data, into: %{}, do: {"#{e.key}.#{k}", v}
  end

  # `trigger_localization` entities: key → %{"global" => "LOC_KEY", ...}
  defp table(nil), do: %{}

  defp table(entities) do
    Map.new(entities, fn e -> {e.key, if(is_map(e.data), do: e.data, else: %{})} end)
  end

  # -- names, descriptions, attached text ------------------------------------

  defp decorate(e, adapter, loc, other_key?) do
    name_keys = adapter.name_keys(e.kind, e.key, e.data)
    desc_keys = adapter.desc_keys(e.kind, e.key, e.data)
    name = blank_to_nil(Loc.first(loc, name_keys))
    desc = blank_to_nil(Loc.first(loc, desc_keys))
    texts = related_text(loc, e.key, name_keys ++ desc_keys, other_key?, [name, desc])
    Map.merge(e, %{name: name, description: desc, texts: texts})
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(s), do: s

  # The first candidate texture that exists under a gfx root, as its relative path.
  defp icon_path(_adapter, [], _e), do: nil

  defp icon_path(adapter, roots, e) do
    adapter
    |> Adapter.icon_paths(e.kind, e.key, e.data)
    |> Enum.find(fn rel -> Enum.any?(roots, &File.regular?(Path.join(&1, rel))) end)
  end

  # Localization strings that extend the entity key (`<key>_tooltip`,
  # `<key>_mechanic_desc`, `<event>.a`) and do not belong to another entity.
  @max_related 12
  @min_related_chars 15

  defp related_text(loc, key, used_keys, other_key?, used_texts) do
    loc
    |> Loc.related_keys(key, 60)
    |> Enum.reject(&(&1 in used_keys or belongs_elsewhere?(&1, key, other_key?)))
    |> Enum.sort_by(&byte_size/1)
    |> Enum.map(&{&1, Loc.text(loc, &1)})
    |> Enum.reject(fn {_k, t} ->
      is_nil(t) or String.length(t) < @min_related_chars or t in used_texts or
        Regex.match?(~r/\A\[[^\]]*\]\z/, t)
    end)
    |> Enum.take(@max_related)
  end

  # `union_integration_level_desc` extends `union` only if no longer entity key
  # (`union_integration_level`) sits between.
  defp belongs_elsewhere?(k, key, other_key?) do
    n = byte_size(key) + 1
    rest = binary_part(k, n, byte_size(k) - n)

    ~r/[_.]/
    |> Regex.scan(rest, return: :index)
    |> Enum.map(fn [{pos, _}] -> binary_part(k, 0, n + pos) end)
    |> Kernel.++([k])
    |> Enum.any?(other_key?)
  end

  # -- references -----------------------------------------------------------

  @max_refs 500

  defp refs_for(e, kinds_for_key) do
    e.data
    |> walk([])
    |> Enum.flat_map(fn {path, value} ->
      {prefix, key} =
        case String.split(value, ":") do
          [k] -> {nil, k}
          parts -> {Enum.at(parts, -2), List.last(parts)}
        end

      case Map.get(kinds_for_key, key) do
        nil ->
          []

        [kind] ->
          [%{from_kind: e.kind, from_key: e.key, path: path, to_kind: kind, to_key: key}]

        kinds ->
          field = path |> String.split(".") |> List.last()

          [
            %{
              from_kind: e.kind,
              from_key: e.key,
              path: path,
              to_kind: pick_kind(kinds, prefix, field),
              to_key: key
            }
          ]
      end
    end)
    |> Enum.uniq_by(&{&1.to_kind, &1.to_key})
    |> Enum.reject(&(&1.to_key == e.key and &1.to_kind == e.kind))
    |> Enum.take(@max_refs)
  end

  # Which kind a shared key refers to: the kind named by the value's prefix
  # (`government_type:monarchy`), else the kind named like the field holding
  # the reference (`culture_groups = { russian_group }`, `religion = orthodox`),
  # else the richest definition (kinds come sorted by richness).
  # `[regiment|e]` links in an entity's description and attached text point at
  # glossary entries; the glossary's `alias` lists map alternative words.
  defp text_refs(e, loc, adapter, concepts_kind, concept_keys, alias_map) do
    desc_key = Enum.find(adapter.desc_keys(e.kind, e.key, e.data), &Loc.has?(loc, &1))
    keys = Enum.reject([desc_key | Enum.map(e[:texts] || [], &elem(&1, 0))], &is_nil/1)

    keys
    |> Enum.flat_map(fn k ->
      Regex.scan(~r/\[([a-z0-9_]+)\|[A-Za-z]+\]/, Loc.raw(loc, k) || "", capture: :all_but_first)
    end)
    |> Enum.map(fn [term] -> concept_for(term, concept_keys, alias_map) end)
    |> Enum.reject(&(is_nil(&1) or (&1 == e.key and e.kind == concepts_kind)))
    |> Enum.uniq()
    |> Enum.map(
      &%{from_kind: e.kind, from_key: e.key, path: "text", to_kind: concepts_kind, to_key: &1}
    )
  end

  defp concept_for(term, keys, aliases) do
    cond do
      MapSet.member?(keys, term) ->
        term

      Map.has_key?(aliases, term) ->
        aliases[term]

      String.ends_with?(term, "_with_icon") ->
        concept_for(String.replace_suffix(term, "_with_icon", ""), keys, aliases)

      true ->
        nil
    end
  end

  defp concept_aliases(concepts) do
    for c <- concepts,
        is_map(c.data),
        a <- List.wrap(c.data["alias"]),
        is_binary(a),
        into: %{},
        do: {a, c.key}
  end

  # One topic document per glossary entry with a description.
  @min_constant_key 4

  defp topic_docs(entities, rk, {names, outgoing, incoming}, defines, meta, gv_id, now) do
    desc_of = Map.new(entities, &{{&1.kind, &1.key}, &1.description})
    ck = rk.concepts

    constants =
      for {"" <> gk, v} <- defines,
          [group, key] = String.split(gk, ".", parts: 2),
          do: {group, key, v}

    entities
    |> Enum.filter(&(&1.kind == ck and is_binary(&1.description)))
    |> Enum.map(fn c ->
      id = {ck, c.key}

      linked =
        for {^ck, key} <- outgoing[id] || [], do: {key, names[{ck, key}], desc_of[{ck, key}]}

      modifiers =
        for {kind, key} <- incoming[id] || [],
            kind == rk.modifiers,
            do: {key, names[{kind, key}], desc_of[{kind, key}]}

      upper = String.upcase(c.key)

      consts =
        if String.length(c.key) >= @min_constant_key,
          do:
            constants
            |> Enum.filter(fn {_g, k, _v} -> String.contains?(k, upper) end)
            |> Enum.sort(),
          else: []

      mentioned_by =
        (incoming[id] || [])
        |> Enum.reject(fn {kind, _} -> kind in [ck, rk.modifiers] end)
        |> Enum.group_by(fn {kind, _} -> kind end, fn {kind, key} -> {key, names[{kind, key}]} end)
        |> Enum.map(fn {kind, items} ->
          {kind, items |> Enum.sort_by(&elem(&1, 0)) |> Enum.take(12)}
        end)
        |> Enum.sort()

      body =
        Pages.topic(
          c,
          linked,
          modifiers,
          consts |> Enum.map(fn {g, k, v} -> {g, k, Script.value_text(v, %Script{})} end),
          mentioned_by,
          meta
        )

      doc(gv_id, "topic", c.key, "#{c.name || c.key} (topic)", body, c.source_file, c.dlc, now)
    end)
  end

  defp pick_kind(kinds, prefix, field) do
    by_prefix = prefix && Enum.find(kinds, &String.starts_with?(&1, prefix))
    by_field = field && Enum.find(kinds, &same_name?(&1, field))
    by_prefix || by_field || hd(kinds)
  end

  defp same_name?(kind, field),
    do: kind == field or kind == field <> "s" or field == kind <> "s" or kind == field <> "es"

  # yields {dotted_path, string_value} for every string scalar in the data
  defp walk(map, path) when is_map(map) do
    Enum.flat_map(map, fn
      {"_tag", _} -> []
      {k, v} -> walk(v, [k | path])
    end)
  end

  defp walk(list, path) when is_list(list), do: Enum.flat_map(list, &walk(&1, path))

  defp walk(s, path) when is_binary(s) do
    if Regex.match?(~r/\A[A-Za-z0-9_:.\-]{2,80}\z/, s),
      do: [{path |> Enum.reverse() |> Enum.join("."), s}],
      else: []
  end

  defp walk(_, _), do: []

  @max_incoming 25

  defp connections_for(e, {names, outgoing, incoming}) do
    id = {e.kind, e.key}

    references =
      (outgoing[id] || [])
      |> Enum.group_by(fn {kind, _} -> kind end, fn {kind, key} -> {key, names[{kind, key}]} end)
      |> Map.new(fn {kind, items} -> {kind, Enum.sort_by(items, &elem(&1, 0))} end)

    referenced_by =
      (incoming[id] || [])
      |> Enum.group_by(fn {kind, _} -> kind end, fn {kind, key} -> {key, names[{kind, key}]} end)
      |> Map.new(fn {kind, items} ->
        {kind, {length(items), items |> Enum.sort_by(&elem(&1, 0)) |> Enum.take(@max_incoming)}}
      end)

    %{references: references, referenced_by: referenced_by}
  end

  # -- intro inputs -----------------------------------------------------------

  # How often each `[concept|e]` link appears in the localization: the game's
  # own measure of which concepts matter.
  defp concept_link_counts(loc_rows) do
    Enum.reduce(loc_rows, %{}, fn %{value: v}, acc ->
      ~r/\[([a-z0-9_]+)\|[A-Za-z]+\]/
      |> Regex.scan(v, capture: :all_but_first)
      |> Enum.reduce(acc, fn [c], a -> Map.update(a, c, 1, &(&1 + 1)) end)
    end)
  end

  @max_core_concepts 40

  defp core_concepts(concept_entities, counts) do
    by_key = Map.new(concept_entities, &{&1.key, &1})

    counts
    |> Enum.sort_by(fn {_k, n} -> -n end)
    |> Enum.flat_map(fn {k, _n} ->
      case by_key[k] do
        %{description: d} = e when is_binary(d) ->
          [{e.name || k, k, d |> String.replace("\n", " ") |> String.slice(0, 300)}]

        _ ->
          []
      end
    end)
    |> Enum.take(@max_core_concepts)
  end

  defp kinds_summary(entities) do
    entities
    |> Enum.group_by(& &1.kind)
    |> Enum.map(fn {kind, es} ->
      example =
        Enum.find_value(es, fn e -> if e.name && e.name != e.key, do: "#{e.name} (#{e.key})" end)

      {kind, length(es), example}
    end)
  end

  # -- documents and chunks -------------------------------------------------

  defp shipped_docs(adapter, root, gv_id, now) do
    for f <- adapter.doc_files(root), {:ok, bin} <- [File.read(f)] do
      rel = Path.relative_to(f, root)
      body = bin |> strip_bom() |> String.replace(~r/\r\n/, "\n")
      doc(gv_id, "docs", rel, Path.basename(rel), "# #{rel}\n\n" <> body, rel, nil, now)
    end
  end

  defp strip_bom(<<0xEF, 0xBB, 0xBF, rest::binary>>), do: rest
  defp strip_bom(bin), do: bin

  # Every localization string worth reading, grouped by file: tooltips, UI
  # text, messages, hints. Kind `text`, key = file path.
  @min_text_chars 40

  defp localization_docs(loc, loc_rows, gv_id, now) do
    loc_rows
    |> Enum.group_by(& &1.source_file)
    |> Enum.sort()
    |> Enum.flat_map(fn {file, rows} ->
      lines =
        rows
        |> Enum.sort_by(& &1.source_line)
        |> Enum.uniq_by(& &1.key)
        |> Enum.flat_map(fn r ->
          t = Loc.text(loc, r.key)

          if t && String.length(t) >= @min_text_chars && not Regex.match?(~r/\A\[[^\]]*\]\z/, t),
            do: ["#{r.key}: #{String.replace(t, "\n", " ")}"],
            else: []
        end)

      if lines == [] do
        []
      else
        title = file |> Path.basename() |> String.replace(~r/(_l_[a-z_]+)?\.yml\z/, "")
        body = "# #{title} — localization text from #{file}\n\n" <> Enum.join(lines, "\n")
        [doc(gv_id, "text", file, "#{title} (localization text)", body, file, nil, now)]
      end
    end)
  end

  @doc false
  def chunk_text(body) when byte_size(body) <= @chunk_chars, do: [body]

  def chunk_text(body) do
    [header | lines] = String.split(body, "\n")

    lines
    |> Enum.chunk_while(
      {[], 0},
      fn line, {acc, size} ->
        if size + byte_size(line) + 1 > @chunk_chars and acc != [] do
          {:cont, Enum.reverse(acc), {[line], byte_size(line)}}
        else
          {:cont, {[line | acc], size + byte_size(line) + 1}}
        end
      end,
      fn
        {[], _} -> {:cont, []}
        {acc, _} -> {:cont, Enum.reverse(acc), []}
      end
    )
    |> Enum.map(fn lines -> Enum.join([header | lines], "\n") end)
  end

  # -- embedding cache -------------------------------------------------------

  defp remember_embeddings(game, info) do
    Repo.query!(
      """
      INSERT INTO embedding_cache (hash, embedding)
      SELECT md5(c.text), c.embedding
      FROM chunks c
      JOIN documents d ON d.id = c.document_id
      JOIN game_versions gv ON gv.id = d.game_version_id
      WHERE gv.game_id = $1 AND gv.version = $2 AND c.embedding IS NOT NULL
      ON CONFLICT DO NOTHING
      """,
      [game.id, info.version],
      timeout: :infinity
    )
  end

  defp restore_embeddings(gv_id) do
    %{num_rows: n} =
      Repo.query!(
        """
        UPDATE chunks c SET embedding = ec.embedding
        FROM documents d, embedding_cache ec
        WHERE c.document_id = d.id AND d.game_version_id = $1
          AND c.embedding IS NULL AND ec.hash = md5(c.text)
        """,
        [gv_id],
        timeout: :infinity
      )

    n
  end

  defp build_search_vectors(gv_id) do
    Repo.query!(
      """
      UPDATE entities SET search =
        setweight(to_tsvector('english', coalesce(name, '')), 'A') ||
        setweight(to_tsvector('english', replace(replace(key, '_', ' '), '.', ' ')), 'A') ||
        setweight(to_tsvector('english', coalesce(description, '')), 'B') ||
        setweight(to_tsvector('english', left(coalesce(card, ''), 100000)), 'C')
      WHERE game_version_id = $1
      """,
      [gv_id],
      timeout: :infinity
    )

    Repo.query!(
      """
      UPDATE chunks c SET search = to_tsvector('english', left(c.text, 100000))
      FROM documents d WHERE c.document_id = d.id AND d.game_version_id = $1
      """,
      [gv_id],
      timeout: :infinity
    )
  end

  # -- inserts ---------------------------------------------------------------

  defp insert_batches(table, rows, size) do
    rows
    |> Enum.chunk_every(size)
    |> Enum.each(fn batch -> Repo.insert_all(table, batch, timeout: :infinity) end)
  end

  defp insert_batches_returning(table, rows, size, returning) do
    rows
    |> Enum.chunk_every(size)
    |> Enum.flat_map(fn batch ->
      {_, returned} = Repo.insert_all(table, batch, returning: returning, timeout: :infinity)
      returned
    end)
  end
end
