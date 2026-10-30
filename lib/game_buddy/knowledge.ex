defmodule GameBuddy.Knowledge do
  @moduledoc """
  Query API over an ingested snapshot. Every function takes a `GameVersion`
  (resolved by `GameBuddy.Catalog`) so callers never mix snapshots.
  """

  import Ecto.Query

  @low_priority_kinds ~w(coat_of_arms flag_definitions modifier_icons named_colors customizable_localization
                         trigger_localization effect_localization scripted_triggers scripted_effects script_values)
  alias GameBuddy.Repo
  alias GameBuddy.Knowledge.{Chunk, Document, Entity}

  @doc """
  Full-text search over chunks (entity cards and shipped docs). Returns one
  row per document, best chunk first. Hybrid (vector) ranking is added in a
  later phase; this is the lexical half.
  """
  def search(gv, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    kinds = Keyword.get(opts, :kinds)
    want = max(limit * 4, 40)

    # All words first; a whole question rarely matches every word, so fall back
    # to any-word matching ranked by how many words hit.
    lexical =
      case lexical_search(gv, query, kinds, want) do
        hits when length(hits) >= 3 ->
          hits

        hits ->
          Enum.uniq_by(hits ++ lexical_search(gv, any_word(query), kinds, want), & &1.document_id)
      end

    # Entities whose name occurs in the query ("marriage union" → Marriage Union)
    # outrank everything that merely mentions the words.
    names = name_search(gv, query, kinds, 10)

    semantic =
      if GameBuddy.Embeddings.available?(),
        do: semantic_search(gv, query, kinds, want),
        else: []

    fuse([{names, 1.5}, {lexical, 1.0}, {semantic, 1.0}], limit)
  end

  # Reciprocal rank fusion over weighted ranked lists, one row per document.
  defp fuse(lists, limit) do
    k = 60

    scores =
      lists
      |> Enum.flat_map(fn {list, weight} ->
        list |> Enum.with_index(1) |> Enum.map(fn {r, i} -> {r, weight / (k + i)} end)
      end)
      |> Enum.reduce(%{}, fn {r, s}, acc ->
        Map.update(acc, r.document_id, {s, r}, fn {s0, r0} ->
          {s0 + s, if(r0[:snippet], do: r0, else: r)}
        end)
      end)

    scores
    |> Map.values()
    |> Enum.map(fn {s, r} ->
      r
      |> Map.put(:rank, s)
      |> Map.put_new(:snippet, String.slice(r[:text] || "", 0, 300))
      |> Map.delete(:text)
    end)
    |> demote()
    |> Enum.take(limit)
  end

  defp semantic_search(gv, query, kinds, limit) do
    qvec = query |> GameBuddy.Embeddings.embed_one() |> Pgvector.new()

    base =
      from c in Chunk,
        join: d in Document,
        on: d.id == c.document_id,
        where: d.game_version_id == ^gv.id and not is_nil(c.embedding),
        order_by: fragment("? <=> ?", c.embedding, type(^qvec, Pgvector.Ecto.Vector)),
        limit: ^limit,
        select: %{
          document_id: d.id,
          kind: d.kind,
          key: d.key,
          title: d.title,
          dlc: d.dlc,
          source_file: d.source_file,
          text: c.text
        }

    base = if kinds, do: where(base, [c, d], d.kind in ^kinds), else: base

    base
    |> Repo.all()
    |> Enum.uniq_by(& &1.document_id)
    |> Enum.map(&Map.put(&1, :id, doc_ref(&1.kind, &1.key)))
  end

  # Entities whose name (or key) is a close match for a stretch of the query.
  # The trigram index pre-filters on word n-grams of the query; word_similarity
  # against the whole query then decides.
  defp name_search(gv, query, kinds, limit) do
    q = String.trim(query)
    grams = ngrams(q)

    base =
      from d in Document,
        join: e in Entity,
        on: e.id == d.entity_id,
        where: d.game_version_id == ^gv.id,
        where:
          (fragment("length(?) >= 5", e.name) and fragment("? % ANY(?)", e.name, ^grams)) or
            (fragment("length(?) >= 6", e.key) and
               fragment("replace(?, '_', ' ') % ANY(?)", e.key, ^grams)),
        where:
          fragment(
            "greatest(word_similarity(?, ?), word_similarity(replace(?, '_', ' '), ?)) >= 0.6",
            e.name,
            ^q,
            e.key,
            ^q
          ),
        order_by: [
          desc:
            fragment(
              "greatest(word_similarity(?, ?), word_similarity(replace(?, '_', ' '), ?))",
              e.name,
              ^q,
              e.key,
              ^q
            )
        ],
        limit: ^limit,
        select: %{
          document_id: d.id,
          kind: d.kind,
          key: d.key,
          title: d.title,
          dlc: d.dlc,
          source_file: d.source_file,
          rank: 0.0,
          text: fragment("left(?, 300)", d.body)
        }

    base = if kinds, do: where(base, [d, e], d.kind in ^kinds), else: base

    if grams == [] do
      []
    else
      base
      |> Repo.all()
      |> Enum.reject(&(&1.kind in @low_priority_kinds))
      |> Enum.map(&Map.put(&1, :id, doc_ref(&1.kind, &1.key)))
    end
  end

  # word 1–3-grams of the query, longest first; single words only when long enough
  defp ngrams(q) do
    words = q |> String.downcase() |> String.split(~r/[^\p{L}\p{N}_']+/u, trim: true)
    tri = words |> Enum.chunk_every(3, 1, :discard) |> Enum.map(&Enum.join(&1, " "))
    bi = words |> Enum.chunk_every(2, 1, :discard) |> Enum.map(&Enum.join(&1, " "))
    uni = Enum.filter(words, &(String.length(&1) >= 6))
    (tri ++ bi ++ uni) |> Enum.uniq() |> Enum.take(16)
  end

  defp lexical_search(gv, query, kinds, limit) do
    tsquery = websearch(query)

    base =
      from c in Chunk,
        join: d in Document,
        on: d.id == c.document_id,
        where: d.game_version_id == ^gv.id,
        where: fragment("? @@ websearch_to_tsquery('english', ?)", c.search, ^tsquery),
        select: %{
          document_id: d.id,
          kind: d.kind,
          key: d.key,
          title: d.title,
          dlc: d.dlc,
          source_file: d.source_file,
          rank: fragment("ts_rank_cd(?, websearch_to_tsquery('english', ?))", c.search, ^tsquery),
          snippet:
            fragment(
              "ts_headline('english', ?, websearch_to_tsquery('english', ?), 'MaxWords=40, MinWords=15, MaxFragments=2')",
              c.text,
              ^tsquery
            )
        }

    base = if kinds, do: where(base, [c, d], d.kind in ^kinds), else: base

    # best chunk per document
    sub =
      from r in subquery(base), distinct: r.document_id, order_by: [r.document_id, desc: r.rank]

    from(r in subquery(sub), order_by: [desc: r.rank], limit: ^limit)
    |> Repo.all()
    |> Enum.map(&Map.put(&1, :id, doc_ref(&1.kind, &1.key)))
  end

  # Plain words → websearch syntax is already forgiving; keep as is but guard empties.
  defp websearch(q) do
    q = String.trim(q)
    if q == "", do: "''", else: q
  end

  @stopwords ~w(a an and are as at be but by for from how i if in into is it its of on or that the
                their there these they this to was what when where which who why will with you your do
                does did can could should would me my we our us any anything something explain tell about)

  # "Explain marriage unions. Is there anything to it?" → every pair of content
  # words OR-ed: "marriage unions". Pairs keep the index usable; a plain OR over
  # single words would scan half the chunks.
  defp any_word(q) do
    words =
      q
      |> String.downcase()
      |> String.split(~r/[^\p{L}\p{N}_']+/u, trim: true)
      |> Enum.reject(&(&1 in @stopwords or String.length(&1) < 3))
      |> Enum.uniq()
      |> Enum.take(8)

    case words do
      [] ->
        q

      [w] ->
        w

      ws ->
        for({a, i} <- Enum.with_index(ws), {b, j} <- Enum.with_index(ws), i < j, do: "#{a} #{b}")
        |> Enum.join(" or ")
    end
  end

  # Cosmetic and plumbing kinds rank below everything else at equal score.
  defp demote(results) do
    Enum.sort_by(results, fn r -> {if(r.kind in @low_priority_kinds, do: 1, else: 0), -r.rank} end)
  end

  @doc "Document reference string used as the `id` in search/fetch tools."
  def doc_ref(kind, key), do: "#{kind}/#{key}"

  def parse_ref(ref) when is_binary(ref) do
    case String.split(ref, "/", parts: 2) do
      [kind, key] -> {:ok, kind, key}
      _ -> :error
    end
  end

  @doc "Fetch a document (entity card or shipped doc) by `kind/key`."
  def fetch(gv, ref) do
    with {:ok, kind, key} <- parse_ref(ref) do
      case Repo.one(
             from d in Document,
               where: d.game_version_id == ^gv.id and d.kind == ^kind and d.key == ^key
           ) do
        nil -> {:error, :not_found}
        doc -> {:ok, doc}
      end
    end
  end

  @doc "Entity by kind and key, with data."
  def get_entity(gv, kind, key) do
    case Repo.one(
           from e in Entity,
             where: e.game_version_id == ^gv.id and e.kind == ^kind and e.key == ^key
         ) do
      nil -> {:error, :not_found}
      e -> {:ok, e}
    end
  end

  @doc "One document by kind and key, or nil."
  def document(gv, kind, key) do
    Repo.one(
      from d in Document,
        where: d.game_version_id == ^gv.id and d.kind == ^kind and d.key == ^key
    )
  end

  @doc """
  Documents for a key as a client would give it: `kind/key`, or a bare key
  (every kind that has it).
  """
  def documents_for_key(gv, ref) do
    direct =
      case parse_ref(ref) do
        {:ok, kind, key} ->
          Repo.all(
            from d in Document,
              where: d.game_version_id == ^gv.id and d.kind == ^kind and d.key == ^key
          )

        :error ->
          []
      end

    case direct do
      [] ->
        Repo.all(
          from d in Document,
            where: d.game_version_id == ^gv.id and d.key == ^ref,
            order_by: d.kind
        )

      docs ->
        docs
    end
  end

  @doc "Bodies of documents by id."
  def bodies(_gv, []), do: %{}

  def bodies(gv, ids) do
    Repo.all(
      from d in Document,
        where: d.game_version_id == ^gv.id and d.id in ^ids,
        select: {d.id, d.body}
    )
    |> Map.new()
  end

  defp escape_like(s), do: String.replace(s, ~r/[\\%_]/, fn c -> "\\" <> c end)

  @doc "Fuzzy lookup of an entity by name or key across kinds (trigram)."
  def resolve(gv, text, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    kinds = Keyword.get(opts, :kinds)
    fetch = limit * 4

    q =
      from e in Entity,
        where: e.game_version_id == ^gv.id,
        where:
          fragment("? % ? OR ? % ?", e.name, ^text, e.key, ^text) or
            ilike(e.name, ^"%#{escape_like(text)}%"),
        order_by: [
          desc:
            fragment("greatest(similarity(?, ?), similarity(?, ?))", e.name, ^text, e.key, ^text)
        ],
        limit: ^fetch,
        select: %{
          kind: e.kind,
          key: e.key,
          name: e.name,
          similarity:
            fragment("greatest(similarity(?, ?), similarity(?, ?))", e.name, ^text, e.key, ^text)
        }

    q = if kinds, do: where(q, [e], e.kind in ^kinds), else: q

    q
    |> Repo.all()
    |> Enum.sort_by(fn r ->
      {-Float.round(r.similarity * 1.0, 2), if(r.kind in @low_priority_kinds, do: 1, else: 0),
       r.kind}
    end)
    |> Enum.take(limit)
  end
end
