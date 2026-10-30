defmodule GameBuddy.Repo.Migrations.CreateAssets do
  use Ecto.Migration

  def change do
    create table(:assets) do
      add :game_version_id, references(:game_versions, on_delete: :delete_all), null: false
      add :path, :string, null: false
      add :mime, :string, null: false
      add :width, :integer
      add :height, :integer
      add :data, :binary, null: false
      timestamps(updated_at: false)
    end

    create unique_index(:assets, [:game_version_id, :path])
  end
end
