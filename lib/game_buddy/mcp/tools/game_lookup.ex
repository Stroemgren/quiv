defmodule GameBuddy.MCP.Tools.GameLookup do
  @moduledoc """
  Find which games and versions are available from a free-form name
  ("eu5", "Europa Universalis V"). Returns the `game` and `version`
  identifiers every other tool takes; without a query, lists everything.
  Call this first, then game_intro.
  """
  use Anubis.Server.Component,
    type: :tool,
    name: "game_lookup",
    title: "Find a game and version",
    annotations: %{"readOnlyHint" => true}

  alias Anubis.Server.Response
  alias GameBuddy.MCP.Tools.Helpers

  schema do
    field(:query, :string,
      description: "Game name as a player would say it. Optional; without it, lists everything."
    )
  end

  @impl true
  def description do
    "Which games and versions are indexed (#{Helpers.games_phrase()}), from a free-form " <>
      "name, with aliases, DLCs and the default version. Optional: every tool defaults to " <>
      "the latest indexed version of the default game, so call this only to confirm a game " <>
      "when several are indexed or to pick a specific version. The data comes from the " <>
      "installed game's own files, more exact and current than wikis; use these tools " <>
      "before web search for these games."
  end

  @impl true
  def execute(params, frame) do
    games = GameBuddy.Catalog.lookup(Helpers.get(params, :query))

    {:reply,
     Response.json(Response.tool(), %{
       games: games,
       note:
         if(games == [],
           do: "No game matches; call without a query to list what is available.",
           else:
             "Pass game and version to game_intro, search and entity. Omitting version uses the default snapshot."
         )
     }), frame}
  end
end
