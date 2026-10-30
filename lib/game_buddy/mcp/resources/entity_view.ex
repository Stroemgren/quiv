defmodule GameBuddy.MCP.Resources.EntityView do
  @moduledoc """
  The interactive view behind the `show` tool, as an MCP App resource: one
  HTML page the host renders in a sandboxed frame and feeds the tool's
  structured content. Generic: it renders the sections every entity document
  has and knows nothing about any game.
  """
  use Anubis.Server.Component,
    type: :resource,
    uri: "ui://game-buddy/entities",
    name: "entity_view",
    title: "Entity view",
    mime_type: "text/html;profile=mcp-app"

  alias Anubis.Server.Response

  @page "priv/mcp_apps/entities.html"

  # The page loads the MCP Apps client from unpkg and the game's font families
  # from Google Fonts (data: images are allowed by default); the rest is inline.
  @ui_meta %{
    "ui" => %{
      "csp" => %{
        "resourceDomains" => [
          "https://unpkg.com",
          "https://fonts.googleapis.com",
          "https://fonts.gstatic.com"
        ],
        "connectDomains" => []
      },
      "prefersBorder" => false
    }
  }

  @impl true
  def meta, do: @ui_meta

  @impl true
  def read(_params, frame) do
    html = File.read!(Application.app_dir(:game_buddy, @page))
    {:reply, Response.resource() |> Response.text(html) |> Response.meta(@ui_meta), frame}
  end
end
