defmodule GameBuddyWeb.ToolCallsLiveTest do
  use GameBuddyWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias GameBuddy.ToolCalls.ToolCall

  defp insert_call!(attrs) do
    %ToolCall{}
    |> ToolCall.changeset(
      Map.merge(
        %{
          tool: "search",
          client_name: "test",
          session_id: "s1",
          duration_ms: 12,
          arguments: %{"query" => "merchant republic"},
          result: %{
            "content" => [
              %{"type" => "text", "text" => ~s({"results":[{"id":"laws/x","title":"X"}]})}
            ],
            "isError" => false
          }
        },
        attrs
      )
    )
    |> GameBuddy.Repo.insert!()
  end

  test "lists calls, shows full input and output on click, filters by tool", %{conn: conn} do
    call = insert_call!(%{})

    insert_call!(%{
      tool: "fetch",
      is_error: true,
      arguments: %{"id" => "nope"},
      result: %{
        "content" => [%{"type" => "text", "text" => "no document nope"}],
        "isError" => true
      }
    })

    {:ok, view, html} = live(conn, "/dashboard")
    assert html =~ "Tool calls"
    assert html =~ "search"
    assert html =~ "fetch"

    html = view |> element("tr[phx-value-id='#{call.id}']") |> render_click()
    assert html =~ "&quot;query&quot;: &quot;merchant republic&quot;"
    assert html =~ "&quot;title&quot;: &quot;X&quot;"
    assert html =~ "12 ms"

    html = view |> element("form") |> render_change(%{tool: "fetch"})
    refute html =~ "merchant republic"
    assert html =~ "no document nope" or html =~ "fetch"
  end

  test "live updates arrive over PubSub", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")
    call = insert_call!(%{tool: "resolve", arguments: %{"name" => "Denmark"}})
    send(view.pid, {:tool_call, call})
    assert render(view) =~ "Denmark"
  end
end
