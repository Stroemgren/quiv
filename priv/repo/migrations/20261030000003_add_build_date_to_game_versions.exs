defmodule GameBuddy.Repo.Migrations.AddBuildDateToGameVersions do
  use Ecto.Migration

  def change do
    alter table(:game_versions) do
      add :build_date, :date
    end
  end
end
