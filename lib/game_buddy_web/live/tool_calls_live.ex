defmodule GameBuddyWeb.ToolCallsLive do
  @moduledoc "Live inspector for MCP tool calls: every call with its complete input and output."
  use GameBuddyWeb, :live_view
  alias GameBuddy.ToolCalls

  @limit 200

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: ToolCalls.subscribe()

    {:ok,
     socket
     |> assign(page_title: "Dashboard", tool: nil, live: true, selected: nil, pending: 0)
     |> reload()}
  end

  defp reload(socket) do
    calls = ToolCalls.list(tool: socket.assigns.tool, limit: @limit)
    assign(socket, calls: calls, stats: ToolCalls.stats(), pending: 0)
  end

  @impl true
  def handle_info({:tool_call, call}, socket) do
    socket = assign(socket, stats: ToolCalls.stats())

    cond do
      not socket.assigns.live ->
        {:noreply, update(socket, :pending, &(&1 + 1))}

      socket.assigns.tool && socket.assigns.tool != call.tool ->
        {:noreply, socket}

      true ->
        {:noreply, update(socket, :calls, fn calls -> Enum.take([call | calls], @limit) end)}
    end
  end

  @impl true
  def handle_event("filter", %{"tool" => tool}, socket) do
    {:noreply,
     socket |> assign(tool: if(tool == "", do: nil, else: tool), selected: nil) |> reload()}
  end

  def handle_event("select", %{"id" => id}, socket) do
    id = String.to_integer(id)

    selected =
      if socket.assigns.selected && socket.assigns.selected.id == id,
        do: nil,
        else: ToolCalls.get!(id)

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_event("toggle_live", _params, socket) do
    socket = assign(socket, live: not socket.assigns.live)
    {:noreply, if(socket.assigns.live, do: reload(socket), else: socket)}
  end

  def handle_event("refresh", _params, socket), do: {:noreply, reload(socket)}

  def handle_event("clear", _params, socket) do
    ToolCalls.clear()
    {:noreply, socket |> assign(selected: nil) |> reload()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title="Dashboard">
      <div class="space-y-5">
        <div class="flex flex-wrap items-center gap-3">
          <h1 class="text-h4 text-ink">Tool calls</h1>
          <.pill tone="neutral" size="sm">{length(@calls)} shown</.pill>
          <div class="grow"></div>
          <form phx-change="filter" class="flex items-center gap-2">
            <.select_field
              id="tool-filter"
              name="tool"
              prompt="all tools"
              options={for s <- @stats, do: {"#{s.tool} (#{s.count})", s.tool}}
              value={@tool}
              class="w-56"
            />
          </form>
          <.button
            phx-click="toggle_live"
            size="sm"
            variant={if(@live, do: "primary", else: "secondary")}
            icon={if(@live, do: "hero-signal", else: "hero-pause")}
          >
            {if @live,
              do: "live",
              else: "paused#{if @pending > 0, do: " · #{@pending} new", else: ""}"}
          </.button>
          <.button phx-click="refresh" size="sm" variant="ghost" icon="hero-arrow-path">
            refresh
          </.button>
          <.button
            phx-click="clear"
            data-confirm="Delete all recorded tool calls?"
            size="sm"
            variant="destructive"
            icon="hero-trash"
          >
            clear
          </.button>
        </div>

        <div class="flex flex-wrap gap-2">
          <div
            :for={s <- @stats}
            class="flex items-center gap-2 rounded-xl border border-line bg-surface px-3 py-1.5 text-sm"
          >
            <span class="font-mono font-semibold text-ink">{s.tool}</span>
            <span class="text-ink-soft">· {s.count} calls · avg {s.avg_ms} ms</span>
            <.pill :if={s.errors > 0} tone="coral" size="sm">{s.errors} errors</.pill>
          </div>
          <div :if={@stats == []} class="text-sm text-ink-soft">
            No calls recorded yet. Point an MCP client at /mcp.
          </div>
        </div>

        <div class="grid gap-4 lg:grid-cols-5">
          <div class="overflow-x-auto rounded-2xl border border-line bg-surface lg:col-span-2">
            <table class="w-full text-left text-xs">
              <thead class="border-b border-line text-[11px] font-bold uppercase tracking-wider text-ink-soft">
                <tr>
                  <th class="px-3 py-2">when</th>
                  <th class="px-3 py-2">tool</th>
                  <th class="px-3 py-2">client</th>
                  <th class="px-3 py-2 text-right">ms</th>
                  <th class="px-3 py-2">arguments</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={c <- @calls}
                  phx-click="select"
                  phx-value-id={c.id}
                  class={[
                    "cursor-pointer border-b border-line/70 transition-colors hover:bg-muted",
                    @selected && @selected.id == c.id && "bg-lavender/60",
                    c.is_error && "text-coral-deep"
                  ]}
                >
                  <td class="whitespace-nowrap px-3 py-2 font-mono">
                    {Calendar.strftime(c.inserted_at, "%H:%M:%S")}
                  </td>
                  <td class="px-3 py-2 font-mono">{c.tool}</td>
                  <td class="px-3 py-2 text-ink-soft">{c.client_name || "?"}</td>
                  <td class="px-3 py-2 text-right font-mono">{c.duration_ms}</td>
                  <td class="max-w-[22rem] truncate px-3 py-2 font-mono text-ink-soft">
                    {Jason.encode!(c.arguments || %{})}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="lg:col-span-3">
            <div
              :if={is_nil(@selected)}
              class="rounded-2xl border border-dashed border-line p-8 text-center text-sm text-ink-soft"
            >
              Select a call to see its complete input and output.
            </div>
            <div :if={@selected} class="space-y-3">
              <div class="flex flex-wrap items-center gap-2 text-sm">
                <.pill tone="violet" size="sm" class="font-mono">{@selected.tool}</.pill>
                <.pill tone={if(@selected.is_error, do: "coral", else: "lime")} size="sm" dot>
                  {if @selected.is_error, do: "error", else: "ok"}
                </.pill>
                <span class="font-mono text-xs text-ink-soft">{@selected.duration_ms} ms</span>
                <span class="font-mono text-xs text-ink-soft">
                  {Calendar.strftime(@selected.inserted_at, "%Y-%m-%d %H:%M:%S")}
                </span>
                <span class="text-xs text-ink-soft">
                  {@selected.client_name} {@selected.client_version} · session {@selected.session_id} · {@selected.remote_ip}
                </span>
              </div>
              <div>
                <div class="mb-1 text-xs font-bold uppercase tracking-wider text-ink-soft">Input</div>
                <pre class="max-h-64 overflow-auto rounded-2xl border border-line bg-surface p-3 font-mono text-xs">{ToolCalls.arguments_text(@selected)}</pre>
              </div>
              <div>
                <div class="mb-1 text-xs font-bold uppercase tracking-wider text-ink-soft">
                  Output
                  <span class="font-normal normal-case tracking-normal">
                    ({byte_size(ToolCalls.output_text(@selected))} bytes)
                  </span>
                </div>
                <pre class="max-h-[60vh] overflow-auto rounded-2xl border border-line bg-surface p-3 font-mono text-xs">{ToolCalls.output_text(@selected)}</pre>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
