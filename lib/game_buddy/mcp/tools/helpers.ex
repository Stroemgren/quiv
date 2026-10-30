defmodule GameBuddy.MCP.Tools.Helpers do
  @moduledoc false
  alias Anubis.Server.Response

  @doc """
  The indexed games for tool descriptions and the server instructions, e.g.
  "Europa Universalis V (eu5)". Read from the catalog at request time, so the
  tools carry no game vocabulary of their own. Clients that load tool schemas
  lazily decide from the first sentence whether a tool is worth loading, so
  that sentence names the games and the questions they answer.
  """
  def games_phrase do
    case games() do
      [] -> "the strategy games indexed here"
      games -> Enum.map_join(games, ", ", &"#{&1.name} (#{aliases(&1)})")
    end
  rescue
    _ -> "the strategy games indexed here"
  end

  # The catalog's games with the default game first.
  defp games do
    default = GameBuddy.Catalog.default_game_slug()
    Enum.sort_by(GameBuddy.Catalog.list_games(), &{&1.slug != default, &1.slug})
  end

  @doc """
  The `game` values a tool accepts: "eu5 (default), hoi4, civ7".
  """
  def game_choices do
    default = GameBuddy.Catalog.default_game_slug()

    games()
    |> Enum.map_join(", ", &if(&1.slug == default, do: "#{&1.slug} (default)", else: &1.slug))
  rescue
    _ -> GameBuddy.Catalog.default_game_slug() <> " (default)"
  end

  @doc """
  The snapshots that exist, for text that already names the games: "eu5: Steam
  build 26211608 of 2026-10-29, ingested 2026-10-30". Games without a snapshot
  are left out; a client finds that out by calling, as it would in production.
  """
  def snapshot_phrase do
    games()
    |> Enum.flat_map(fn g ->
      case GameBuddy.Catalog.default_version(g.slug) do
        nil -> []
        gv -> ["#{g.slug}: #{build_label(gv)}, ingested #{Date.to_iso8601(gv.ingested_at)}"]
      end
    end)
    |> case do
      [] -> "no snapshot yet"
      l -> Enum.join(l, "; ")
    end
  rescue
    _ -> "the current snapshots"
  end

  defp build_label(%{build_id: id, build_date: %Date{} = d}) when is_binary(id),
    do: "Steam build #{id} of #{Date.to_iso8601(d)}"

  defp build_label(%{build_id: id}) when is_binary(id), do: "Steam build #{id}"
  defp build_label(gv), do: gv.version

  # Every name players use, as the adapter declares them, so that a literal
  # keyword match on "EU5" or "HOI4" finds the tools: "EU5, EU V, Europa Universalis 5".
  defp aliases(game) do
    GameBuddy.Adapter.for_slug(game.slug)
    |> GameBuddy.Adapter.aliases()
    |> Enum.reject(&(String.downcase(&1) == String.downcase(game.name)))
    |> Enum.map(&format_alias/1)
    |> Enum.uniq()
    |> Enum.join(", ")
  end

  @romans ~w(i ii iii iv v vi vii viii ix x)
  @small ~w(of the and)

  @doc false
  def format_alias(alias) do
    alias
    |> String.split(" ")
    |> Enum.map_join(" ", fn token ->
      cond do
        token in @romans -> String.upcase(token)
        token in @small -> token
        # acronyms and tags: eu5, hoi4, civ, eu
        String.match?(token, ~r/\d/) or String.length(token) <= 3 -> String.upcase(token)
        true -> String.capitalize(token)
      end
    end)
  end

  @doc "The games by name, for the server title: \"Europa Universalis V, Hearts of Iron IV, ...\"."
  def games_names do
    case games() do
      [] -> "strategy games"
      games -> Enum.map_join(games, ", ", & &1.name)
    end
  rescue
    _ -> "strategy games"
  end

  @doc """
  Resolve the snapshot from params and run `fun`. The function returns
  `{:text, markdown}`, `{:error, message}`, a built `%Response{}` or a map
  (sent as JSON). A known game without a snapshot gets `empty.(game)` as its
  text (empty content, not an error); an unknown game or version is an error.
  """
  def with_version(params, frame, fun, empty \\ nil) do
    slug = get(params, :game) || GameBuddy.Catalog.default_game_slug()

    case GameBuddy.Catalog.resolve_version(slug, get(params, :version)) do
      nil ->
        case {GameBuddy.Catalog.get_game(slug), get(params, :version), empty} do
          {%{} = game, nil, empty} when is_function(empty, 1) ->
            {:reply, Response.text(Response.tool(), empty.(game)), frame}

          {%{}, version, _} when is_binary(version) ->
            {:reply,
             Response.error(
               Response.tool(),
               "no version #{version} for #{slug}; call game_lookup"
             ), frame}

          _ ->
            {:reply, Response.error(Response.tool(), "unknown game #{slug}; call game_lookup"),
             frame}
        end

      gv ->
        case fun.(gv) do
          {:error, msg} -> {:reply, Response.error(Response.tool(), msg), frame}
          {:text, text} -> {:reply, Response.text(Response.tool(), text), frame}
          %Response{} = r -> {:reply, r, frame}
          data -> {:reply, Response.json(Response.tool(), data), frame}
        end
    end
  end

  @doc "Read a param by atom or string key (anubis hands validated params with atom keys)."
  def get(params, key) when is_atom(key) do
    case Map.fetch(params, key) do
      {:ok, v} -> v
      :error -> Map.get(params, Atom.to_string(key))
    end
  end

  def clamp(nil, _min, _max, default), do: default
  def clamp(n, min, max, _default) when is_integer(n), do: n |> max(min) |> min(max)
  def clamp(_, _min, _max, default), do: default
end
