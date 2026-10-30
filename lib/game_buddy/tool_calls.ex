defmodule GameBuddy.ToolCalls do
  @moduledoc """
  Log of every MCP tool call: arguments, complete result, timing and client.
  Written asynchronously from telemetry (see `GameBuddy.ToolCalls.Telemetry`),
  broadcast on PubSub topic `"tool_calls"` for the live dashboard.
  """

  import Ecto.Query
  alias GameBuddy.Repo
  alias GameBuddy.ToolCalls.ToolCall

  @topic "tool_calls"

  def subscribe, do: Phoenix.PubSub.subscribe(GameBuddy.PubSub, @topic)

  @doc "Insert off the caller's process and broadcast. Never raises into the tool call."
  def record(attrs) when is_map(attrs) do
    Task.Supervisor.start_child(GameBuddy.TaskSupervisor, fn ->
      call =
        %ToolCall{}
        |> ToolCall.changeset(attrs)
        |> Repo.insert!()

      Phoenix.PubSub.broadcast(GameBuddy.PubSub, @topic, {:tool_call, call})
    end)

    :ok
  end

  def list(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    tool = Keyword.get(opts, :tool)
    q = from c in ToolCall, order_by: [desc: c.inserted_at, desc: c.id], limit: ^limit
    q = if tool, do: where(q, [c], c.tool == ^tool), else: q
    Repo.all(q)
  end

  def get!(id), do: Repo.get!(ToolCall, id)

  @doc "Calls and errors per tool."
  def stats do
    Repo.all(
      from c in ToolCall,
        group_by: c.tool,
        order_by: [desc: count(c.id)],
        select:
          {c.tool, count(c.id), sum(fragment("case when ? then 1 else 0 end", c.is_error)),
           avg(c.duration_ms)}
    )
    |> Enum.map(fn {tool, n, errors, avg} ->
      %{tool: tool, count: n, errors: errors || 0, avg_ms: avg && round(Decimal.to_float(avg))}
    end)
  end

  def clear, do: Repo.delete_all(ToolCall)

  @doc """
  The output as the client saw it, pretty-printed. Our tools send one JSON text
  item, which is decoded and re-indented; anything else is shown as the raw
  protocol payload.
  """
  def output_text(%ToolCall{result: result}) do
    case result do
      %{"content" => [%{"type" => "text", "text" => text}]} ->
        case Jason.decode(text) do
          {:ok, decoded} -> Jason.encode!(decoded, pretty: true)
          _ -> text
        end

      other ->
        Jason.encode!(other, pretty: true)
    end
  end

  def arguments_text(%ToolCall{arguments: args}), do: Jason.encode!(args || %{}, pretty: true)
end
