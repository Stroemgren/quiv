defmodule GameBuddy.ToolCalls.Telemetry do
  @moduledoc """
  Attaches to anubis' `[:anubis_mcp, :server, :tool_call]` span. The start
  event carries the validated arguments, the stop event the full result and the
  frame (session, client, remote IP); both fire in the tool's own process, so
  the arguments are parked in the process dictionary between them.
  Requires `config :anubis_mcp, telemetry_capture_tool_payload: true`.
  """

  require Logger

  @events [
    [:anubis_mcp, :server, :tool_call, :start],
    [:anubis_mcp, :server, :tool_call, :stop],
    [:anubis_mcp, :server, :tool_call, :exception]
  ]

  def attach do
    :telemetry.attach_many("game-buddy-tool-calls", @events, &__MODULE__.handle_event/4, nil)
  end

  def handle_event([_, _, _, :start], _measurements, meta, _config) do
    Process.put({__MODULE__, meta[:telemetry_span_context]}, meta[:arguments])
  end

  def handle_event([_, _, _, :stop], %{duration: duration}, meta, _config) do
    arguments = Process.delete({__MODULE__, meta[:telemetry_span_context]})

    {result, frame, is_error} =
      case meta[:result] do
        {:reply, response, frame} -> {response, frame, meta[:is_error] == true}
        {:error, error, frame} -> {%{"error" => jsonable(error)}, frame, true}
        other -> {%{"unexpected" => inspect(other, limit: 50)}, nil, true}
      end

    record(meta[:tool], arguments, result, is_error, duration, frame)
  end

  def handle_event([_, _, _, :exception], %{duration: duration}, meta, _config) do
    arguments = Process.delete({__MODULE__, meta[:telemetry_span_context]})
    text = Exception.format(meta[:kind], meta[:reason], meta[:stacktrace] || [])

    record(
      meta[:tool],
      arguments,
      %{"exception" => String.slice(text, 0, 4000)},
      true,
      duration,
      nil
    )
  end

  defp record(tool, arguments, result, is_error, duration, frame) do
    ctx = frame && Map.get(frame, :context)
    client = (ctx && ctx.client_info) || %{}

    GameBuddy.ToolCalls.record(%{
      tool: tool || "unknown",
      arguments: jsonable(arguments),
      result: jsonable(result),
      is_error: is_error,
      duration_ms: System.convert_time_unit(duration, :native, :millisecond),
      session_id: ctx && ctx.session_id,
      client_name: client["name"] || client[:name],
      client_version: client["version"] || client[:version],
      remote_ip: ctx && ip_string(ctx.remote_ip)
    })
  rescue
    e -> Logger.warning("tool call not recorded: #{Exception.message(e)}")
  end

  defp ip_string(nil), do: nil
  defp ip_string(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> to_string()
  defp ip_string(ip), do: to_string(ip)

  # Anything the DB can hold as jsonb; falls back to inspect for odd terms.
  defp jsonable(%_{} = struct), do: struct |> Map.from_struct() |> jsonable()

  defp jsonable(map) when is_map(map),
    do: Map.new(map, fn {k, v} -> {to_string(k), jsonable(v)} end)

  defp jsonable(list) when is_list(list), do: Enum.map(list, &jsonable/1)
  defp jsonable(v) when is_binary(v) or is_number(v) or is_boolean(v) or is_nil(v), do: v
  defp jsonable(v) when is_atom(v), do: Atom.to_string(v)
  defp jsonable(v), do: inspect(v, limit: 50)
end
