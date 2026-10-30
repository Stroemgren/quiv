defmodule GameBuddy.MCP.Tools.Search do
  @moduledoc """
  Search one game version and get a compiled document of the best matches:
  entities (reforms, laws, countries, cultures, concepts, ...), the game's own
  localization text (tooltips, messages, hints) and shipped docs, each with
  its key and the passage that matched. Use the player's own words; the game's
  name for a thing is often not what other games call it. Then call entity(key)
  for any result, and follow the connections in that document to escalate.
  """
  use Anubis.Server.Component,
    type: :tool,
    name: "game_search",
    title: "Search game data",
    annotations: %{"readOnlyHint" => true}

  alias GameBuddy.MCP.Tools.Helpers
  alias GameBuddy.{Knowledge, Render}

  schema do
    field(:query, :string,
      required: true,
      description: "Words, a phrase, or the question itself."
    )

    field(:limit, :integer, description: "Max results, default 8, max 25.")
    field(:game, :string, description: "Optional. Defaults to the default game.")
    field(:version, :string, description: "Optional. Defaults to the latest indexed version.")
  end

  @impl true
  def description do
    "Search the game's own files for anything about #{Helpers.games_phrase()}: rules, " <>
      "mechanics, requirements, what something does or unlocks. Use it before web search " <>
      "for these games: the data is extracted from the installed game " <>
      "(#{Helpers.snapshot_phrase()}), so it is as current as the game and exact to the " <>
      "number. The usual first call, no setup needed: game and version are optional and " <>
      "default to the latest indexed version. Returns a compiled document of the best " <>
      "matches (entities such as reforms, laws, countries, cultures, concepts; the game's " <>
      "own tooltips, messages and hints; shipped docs), each with its key and the matched " <>
      "passage. Use the player's own words; the game's name for a thing is often not what " <>
      "other games call it. Then game_entity(key) for exact conditions, effects and " <>
      "numbers, following the connections in that document to escalate. `game` is one " <>
      "of #{Helpers.game_choices()}."
  end

  @impl true
  def execute(params, frame) do
    query = Helpers.get(params, :query)

    Helpers.with_version(
      params,
      frame,
      fn gv ->
        limit = Helpers.get(params, :limit) |> Helpers.clamp(1, 25, 8)
        hits = Knowledge.search(gv, query, limit: limit)
        bodies = Knowledge.bodies(gv, Enum.map(hits, & &1.document_id))
        hits = Enum.map(hits, &Map.put(&1, :body, bodies[&1.document_id]))
        {:text, Render.Pages.search(query, meta(gv), hits)}
      end,
      fn game -> "# Search: \"#{query}\" · #{game.name}\n0 results." end
    )
  end

  defp meta(gv), do: %{game: gv.game.name, version: gv.version, dlcs: gv.dlcs}
end
