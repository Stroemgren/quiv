defmodule GameBuddy.Repo.Migrations.CreateToolCalls do
  use Ecto.Migration

  def change do
    create table(:tool_calls) do
      add :tool, :string, null: false
      add :session_id, :string
      add :client_name, :string
      add :client_version, :string
      add :remote_ip, :string
      add :arguments, :map
      add :result, :map
      add :is_error, :boolean, null: false, default: false
      add :duration_ms, :integer
      add :inserted_at, :utc_datetime_usec, null: false
    end

    create index(:tool_calls, [:inserted_at])
    create index(:tool_calls, [:tool, :inserted_at])
  end
end
