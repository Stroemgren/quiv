defmodule GameBuddy.MCP.Server do
  @moduledoc """
  MCP server exposing game data extracted from game files. Four tools, meant
  to be used in order: game_lookup → game_intro → search → entity (as often
  as needed, following keys), plus `show`, which renders entities as an
  interactive view (an MCP App) in clients that support it.
  """
  use Anubis.Server,
    name: "game-buddy",
    version: "0.3.0",
    capabilities: [:tools, :resources, extensions: %{"io.modelcontextprotocol/ui" => %{}}]

  # The initialize result: a title naming the indexed games (what a host shows
  # before any tool is loaded) and instructions it may add to the model's context.
  @impl true
  def server_info do
    %{
      "name" => "game-buddy",
      "version" => "0.3.0",
      "title" =>
        "Game Buddy: #{GameBuddy.MCP.Tools.Helpers.games_names()}, from the installed game files"
    }
  end

  @impl true
  def server_instructions do
    "Game Buddy answers questions about #{GameBuddy.MCP.Tools.Helpers.games_phrase()} " <>
      "from the games' own files, extracted from the installed game " <>
      "(#{GameBuddy.MCP.Tools.Helpers.snapshot_phrase()}), so it is more exact and " <>
      "current than wikis or guides. For any question about these games' rules, mechanics, " <>
      "requirements or content, use it before web search: game_search first (no setup " <>
      "needed; `game` is one of #{GameBuddy.MCP.Tools.Helpers.game_choices()}, version " <>
      "defaults to the latest indexed one), then game_entity " <>
      "for exact conditions, effects and numbers, following keys. game_lookup and " <>
      "game_intro are optional (several games, a specific version, or a term that matches " <>
      "nothing). game_show renders cards when the answer centers on specific entities or " <>
      "the user asks to see or compare."
  end

  # One row per client handshake in the tool-call log, so the dashboard shows
  # when a host connected, what it identified as, and which protocol it spoke.
  @impl true
  def init(client_info, frame) do
    ctx = Map.get(frame, :context) || %{}

    GameBuddy.ToolCalls.record(%{
      tool: "initialize",
      arguments: %{
        "client" => client_info,
        "protocol" => Map.get(ctx, :protocol_version),
        "capabilities" => Map.get(ctx, :client_capabilities)
      },
      result: %{"title" => server_info()["title"]},
      is_error: false,
      duration_ms: 0,
      session_id: Map.get(ctx, :session_id),
      client_name: client_info["name"],
      client_version: client_info["version"],
      remote_ip: ip_string(Map.get(ctx, :remote_ip))
    })

    {:ok, frame}
  end

  defp ip_string(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> to_string()
  defp ip_string(nil), do: nil
  defp ip_string(ip), do: to_string(ip)

  # Wire names are set here: anubis derives them from the module name unless
  # the registration says otherwise (the `name:` option of the component is
  # not consulted). The `game_` family tells a host what they are for before
  # it loads their schemas.
  component(GameBuddy.MCP.Tools.GameLookup, name: "game_lookup")
  component(GameBuddy.MCP.Tools.GameIntro, name: "game_intro")
  component(GameBuddy.MCP.Tools.Search, name: "game_search")
  component(GameBuddy.MCP.Tools.Entity, name: "game_entity")
  component(GameBuddy.MCP.Tools.Show, name: "game_show")
  component(GameBuddy.MCP.Resources.EntityView)
end
