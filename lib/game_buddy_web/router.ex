defmodule GameBuddyWeb.Router do
  use GameBuddyWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GameBuddyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # MCP over Streamable HTTP. No auth while prototyping; exposed via ngrok.
  forward "/mcp", Anubis.Server.Transport.StreamableHTTP.Plug, server: GameBuddy.MCP.Server

  scope "/", GameBuddyWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/design", PageController, :design
    live "/dashboard", ToolCallsLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", GameBuddyWeb do
  #   pipe_through :api
  # end
end
