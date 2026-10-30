defmodule GameBuddy.MCP.Tools.GameIntro do
  @moduledoc """
  The introduction to one game version: what it is, what was indexed from its
  files, how to use search and entity, the game's own core vocabulary, the
  kinds of entities with counts, and notes specific to the game. Read it once
  before searching; it tells you what the game calls things.
  """
  use Anubis.Server.Component,
    type: :tool,
    name: "game_intro",
    title: "Game introduction",
    annotations: %{"readOnlyHint" => true}

  alias GameBuddy.MCP.Tools.Helpers

  schema do
    field(:game, :string,
      description: "Optional. Defaults to the default game; identifiers from game_lookup."
    )

    field(:version, :string, description: "Optional. Defaults to the latest indexed version.")
  end

  @impl true
  def description do
    "Optional orientation for one game version (#{Helpers.games_phrase()}): what was " <>
      "indexed from its files, the game's own core vocabulary, the kinds of entities with " <>
      "counts, and notes specific to the game. Read it when a term from the user matches " <>
      "nothing in game_search, or for an overview; game_search results and game_entity " <>
      "documents already carry the game's names for things. Game and version are optional " <>
      "and default to the latest indexed version; `game` is one of #{Helpers.game_choices()}."
  end

  @impl true
  def execute(params, frame) do
    Helpers.with_version(
      params,
      frame,
      fn gv ->
        case GameBuddy.Knowledge.document(gv, "intro", "game") do
          nil -> {:error, "no intro for #{gv.game.slug} #{gv.version}; re-ingest"}
          doc -> {:text, doc.body}
        end
      end,
      fn game -> "# #{game.name}\n\nNothing indexed for this game yet." end
    )
  end
end
