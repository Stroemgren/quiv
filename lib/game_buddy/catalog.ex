defmodule GameBuddy.Catalog do
  @moduledoc "Games and their ingested version snapshots."
  import Ecto.Query
  alias GameBuddy.Repo
  alias GameBuddy.Catalog.{Game, GameVersion}

  def default_game_slug, do: Application.get_env(:game_buddy, :default_game, "eu5")

  def list_games, do: Repo.all(from g in Game, order_by: g.slug)

  @doc """
  Register every adapter's game (name and engine), whether or not a snapshot
  exists for it. Run at application start; harmless to repeat.
  """
  def ensure_games do
    for adapter <- GameBuddy.Adapter.all() do
      Repo.insert!(
        %Game{slug: adapter.slug(), name: adapter.name(), engine: adapter.engine()},
        on_conflict: {:replace, [:name, :engine, :updated_at]},
        conflict_target: :slug
      )
    end

    :ok
  rescue
    e ->
      require Logger
      Logger.warning("games not registered: #{Exception.message(e)}")
      :error
  end

  def get_game(slug) when is_binary(slug), do: Repo.get_by(Game, slug: slug)

  @doc "Default snapshot for a game slug: the one flagged default, else the newest ingested."
  def default_version(slug \\ nil) do
    slug = slug || default_game_slug()

    Repo.one(
      from gv in GameVersion,
        join: g in assoc(gv, :game),
        where: g.slug == ^slug and gv.status == "ready",
        order_by: [desc: gv.is_default, desc: gv.ingested_at],
        limit: 1,
        preload: [game: g]
    )
  end

  @doc "Resolve a snapshot from an optional slug and version string."
  def resolve_version(slug \\ nil, version \\ nil)
  def resolve_version(slug, nil), do: default_version(slug)

  def resolve_version(slug, version) do
    slug = slug || default_game_slug()

    Repo.one(
      from gv in GameVersion,
        join: g in assoc(gv, :game),
        where: g.slug == ^slug and gv.version == ^version and gv.status == "ready",
        order_by: [desc: gv.ingested_at],
        limit: 1,
        preload: [game: g]
    )
  end

  def kinds_with_counts(game_version_id) do
    Repo.all(
      from e in "entities",
        where: e.game_version_id == ^game_version_id,
        group_by: e.kind,
        order_by: e.kind,
        select: {e.kind, count(e.id)}
    )
  end

  @doc """
  Games matching a free-form name (slug, name or an adapter alias), each with
  its ready versions (none for a game that has no snapshot yet). Without a
  query, everything.
  """
  def lookup(query) do
    q = query |> to_string() |> String.downcase() |> String.trim()

    versions =
      Repo.all(
        from gv in GameVersion,
          where: gv.status == "ready",
          order_by: [desc: gv.is_default, desc: gv.ingested_at]
      )
      |> Enum.group_by(& &1.game_id)

    list_games()
    |> Enum.map(fn game ->
      vs = versions[game.id] || []
      aliases = GameBuddy.Adapter.aliases(GameBuddy.Adapter.for_slug(game.slug))

      %{
        game: game.slug,
        name: game.name,
        engine: game.engine,
        aliases: aliases,
        versions:
          Enum.map(vs, fn v ->
            %{
              version: v.version,
              build_id: v.build_id,
              dlcs: v.dlcs,
              default: v.is_default,
              ingested_at: v.ingested_at
            }
          end)
      }
    end)
    |> Enum.filter(fn g -> q == "" or matches?(q, [g.game, g.name | g.aliases]) end)
    |> Enum.sort_by(& &1.game)
  end

  defp matches?(q, names) do
    names = Enum.map(names, &String.downcase/1)
    tokens = String.split(q, ~r/\s+/, trim: true)

    Enum.any?(names, fn n ->
      String.contains?(n, q) or String.contains?(q, n) or
        (tokens != [] and Enum.all?(tokens, &String.contains?(n, &1)))
    end)
  end
end
