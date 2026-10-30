defmodule GameBuddyWeb.PageController do
  @moduledoc "The public site: the landing page and the design system."
  use GameBuddyWeb, :controller
  alias GameBuddy.Catalog

  def home(conn, _params) do
    games =
      Catalog.list_games()
      |> Enum.map(fn game ->
        %{game: game, version: Catalog.default_version(game.slug), image: game_image(game.slug)}
      end)
      |> Enum.sort_by(&is_nil(&1.version))

    render(conn, :home,
      page_title: "Game knowledge from the game's own files",
      games: games,
      chats: GameBuddyWeb.PageHTML.hero_chats(games),
      featured: Enum.find(games, & &1.version),
      mcp_url: mcp_url(conn)
    )
  end

  def design(conn, _params) do
    render(conn, :design,
      page_title: "Design system",
      sections: GameBuddyWeb.DesignComponents.sections()
    )
  end

  # The game's own small icon, fetched by scripts/steam_art.py into
  # priv/static/images/games/<slug>/; without one the card draws its own tile.
  defp game_image(slug) do
    if File.exists?(
         Application.app_dir(:game_buddy, "priv/static/images/games/#{slug}/icon.png")
       ),
       do: "/images/games/#{slug}/icon.png"
  end

  # The MCP endpoint as the visitor reaches it, so that it is right behind ngrok too.
  defp mcp_url(conn) do
    scheme =
      case get_req_header(conn, "x-forwarded-proto") do
        [proto | _] -> proto
        [] -> to_string(conn.scheme)
      end

    port =
      if conn.port in [80, 443] or get_req_header(conn, "x-forwarded-proto") != [],
        do: "",
        else: ":#{conn.port}"

    "#{scheme}://#{conn.host}#{port}/mcp"
  end
end
