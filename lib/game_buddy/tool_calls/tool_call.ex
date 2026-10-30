defmodule GameBuddy.ToolCalls.ToolCall do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tool_calls" do
    field :tool, :string
    field :session_id, :string
    field :client_name, :string
    field :client_version, :string
    field :remote_ip, :string
    field :arguments, :map
    field :result, :map
    field :is_error, :boolean, default: false
    field :duration_ms, :integer
    field :inserted_at, :utc_datetime_usec
  end

  def changeset(call, attrs) do
    call
    |> cast(attrs, [
      :tool,
      :session_id,
      :client_name,
      :client_version,
      :remote_ip,
      :arguments,
      :result,
      :is_error,
      :duration_ms
    ])
    |> put_change(:inserted_at, DateTime.utc_now())
    |> validate_required([:tool])
  end
end
