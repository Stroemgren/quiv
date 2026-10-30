defmodule GameBuddy.Repo.Migrations.AddSectionsToDocuments do
  use Ecto.Migration

  # The structured form of an entity document (the same parts the markdown is
  # printed from), for clients that render UI. Nil for non-entity documents.
  def change do
    alter table(:documents) do
      add :sections, :map
    end
  end
end
