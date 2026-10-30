defmodule Mix.Tasks.Game.Embed do
  @shortdoc "Compute embeddings for every chunk of the default snapshot that lacks one"
  @moduledoc """
      mix game.embed [--game eu5] [--batch 64]

  Idempotent: only chunks with a NULL embedding are processed, so it can be
  re-run after a crash or a new ingest.
  """
  use Mix.Task
  import Ecto.Query
  require Logger

  # Kinds that are not worth embedding: geographic grids, cosmetics, engine plumbing.
  @skip_kinds ~w(locations setup_locations map_regions coat_of_arms flag_definitions modifier_icons named_colors
                 persistent_dna genes attribute_columns music_player_tracks setup_character_db setup_dynasty_manager
                 setup_road_network setup_development setup_building_manager setup_townrights_manager
                 customizable_localization trigger_localization effect_localization scripted_guis tests
                 avatars artist_work ethnicities)

  # Embedded first; everything else follows alphabetically.
  @priority ~w(intro game_concepts docs text government_types government_reforms laws age estates estate_privileges
               advances building_types institution societal_values religions cultures decisions events
               international_organizations defines country_setup setup_countries setup_templates)

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [game: :string, batch: :integer])
    Application.put_env(:game_buddy, :embeddings, enabled: true)
    Mix.Task.run("app.start")

    gv = GameBuddy.Catalog.default_version(opts[:game]) || Mix.raise("no ingested snapshot")
    batch = opts[:batch] || 64
    kinds = kinds_in_order(gv.id)
    total = remaining(gv.id)

    Logger.info(
      "embedding #{total} chunks for #{gv.game.slug} #{gv.version} (batch #{batch}, #{length(kinds)} kinds)"
    )

    t0 = System.monotonic_time(:millisecond)
    Enum.reduce(kinds, 0, fn kind, done -> loop(gv.id, kind, 0, batch, done, t0) end)
    Logger.info("done in #{System.monotonic_time(:millisecond) - t0} ms")
  end

  defp kinds_in_order(gv_id) do
    present =
      GameBuddy.Repo.all(
        from d in "documents", where: d.game_version_id == ^gv_id, distinct: true, select: d.kind
      )
      |> Enum.reject(&(&1 in @skip_kinds))

    Enum.filter(@priority, &(&1 in present)) ++ Enum.sort(present -- @priority)
  end

  defp remaining(gv_id) do
    GameBuddy.Repo.one(
      from c in "chunks",
        join: d in "documents",
        on: d.id == c.document_id,
        where: d.game_version_id == ^gv_id and is_nil(c.embedding) and d.kind not in @skip_kinds,
        select: count(c.id)
    )
  end

  defp loop(gv_id, kind, last_id, batch, done, t0) do
    rows =
      GameBuddy.Repo.all(
        from c in "chunks",
          join: d in "documents",
          on: d.id == c.document_id,
          where:
            d.game_version_id == ^gv_id and d.kind == ^kind and is_nil(c.embedding) and
              c.id > ^last_id,
          order_by: c.id,
          limit: ^batch,
          select: {c.id, c.text}
      )

    case rows do
      [] ->
        done

      rows ->
        {ids, texts} = Enum.unzip(rows)
        vectors = GameBuddy.Embeddings.embed(texts)
        store(ids, vectors)
        done = done + length(ids)
        elapsed = System.monotonic_time(:millisecond) - t0

        if rem(div(done, batch), 25) == 0,
          do:
            Logger.info("#{done} chunks (#{kind}), #{div(done * 1000, max(elapsed, 1))} chunks/s")

        loop(gv_id, kind, List.last(ids), batch, done, t0)
    end
  end

  defp store(ids, vectors) do
    texts = Enum.map(vectors, fn v -> "[" <> Enum.map_join(v, ",", &Float.to_string/1) <> "]" end)

    GameBuddy.Repo.query!(
      "UPDATE chunks AS c SET embedding = v.e::vector FROM unnest($1::bigint[], $2::text[]) AS v(id, e) WHERE c.id = v.id",
      [ids, texts]
    )

    # remember them for the next ingest of the same text
    GameBuddy.Repo.query!(
      "INSERT INTO embedding_cache (hash, embedding) SELECT md5(c.text), c.embedding FROM chunks c WHERE c.id = ANY($1::bigint[]) ON CONFLICT DO NOTHING",
      [ids]
    )
  end
end
