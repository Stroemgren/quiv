defmodule GameBuddy.Repo.Migrations.CreateCoreTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS vector", "DROP EXTENSION IF EXISTS vector"
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm", "DROP EXTENSION IF EXISTS pg_trgm"
    execute "CREATE EXTENSION IF NOT EXISTS unaccent", "DROP EXTENSION IF EXISTS unaccent"

    create table(:games) do
      add :slug, :string, null: false
      add :name, :string, null: false
      add :engine, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:games, [:slug])

    # One row per ingest snapshot of a game at a given version/build/DLC set.
    create table(:game_versions) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :version, :string, null: false
      add :build_id, :string
      add :dlcs, {:array, :string}, null: false, default: []
      add :source_path, :string
      add :status, :string, null: false, default: "pending"
      add :is_default, :boolean, null: false, default: false
      add :ingested_at, :utc_datetime
      add :stats, :map, null: false, default: %{}
      timestamps(type: :utc_datetime)
    end

    create unique_index(:game_versions, [:game_id, :version, :build_id])
    create index(:game_versions, [:game_id, :is_default])

    # Generic store for every scripted definition in the game files.
    create table(:entities) do
      add :game_version_id, references(:game_versions, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :key, :string, null: false
      add :name, :text
      add :description, :text
      # Folded map: duplicate keys become arrays. Good for jsonb queries.
      add :data, :map, null: false, default: %{}
      # Exact ordered statements, wrapped as %{"statements" => [...]}.
      add :ast, :map
      add :source_file, :string
      add :source_line, :integer
      # DLC directory the definition came from, nil for the base game.
      add :dlc, :string
      # Rendered, human-readable markdown card.
      add :card, :text
      add :search, :tsvector
      timestamps(type: :utc_datetime)
    end

    create unique_index(:entities, [:game_version_id, :kind, :key])
    create index(:entities, [:game_version_id, :kind])
    create index(:entities, [:search], using: :gin)
    create index(:entities, [:data], using: :gin)
    create index(:entities, ["name gin_trgm_ops"], using: :gin, name: :entities_name_trgm_index)
    create index(:entities, ["key gin_trgm_ops"], using: :gin, name: :entities_key_trgm_index)

    # Cross references discovered in entity data (e.g. a law that names an age).
    create table(:entity_refs) do
      add :from_entity_id, references(:entities, on_delete: :delete_all), null: false
      add :path, :string
      add :to_kind, :string
      add :to_key, :string, null: false
    end

    create index(:entity_refs, [:from_entity_id])
    create index(:entity_refs, [:to_kind, :to_key])

    create table(:localizations) do
      add :game_version_id, references(:game_versions, on_delete: :delete_all), null: false
      add :lang, :string, null: false
      add :key, :string, null: false
      add :value, :text, null: false
      add :source_file, :string
      add :source_line, :integer
    end

    create unique_index(:localizations, [:game_version_id, :lang, :key])

    # Unstructured text: one per entity card plus text-only material.
    create table(:documents) do
      add :game_version_id, references(:game_versions, on_delete: :delete_all), null: false
      add :entity_id, references(:entities, on_delete: :delete_all)
      add :kind, :string, null: false
      add :key, :string, null: false
      add :title, :text
      add :body, :text, null: false
      add :source_file, :string
      add :dlc, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:documents, [:game_version_id, :kind, :key])
    create index(:documents, [:entity_id])

    create table(:chunks) do
      add :document_id, references(:documents, on_delete: :delete_all), null: false
      add :ord, :integer, null: false
      add :text, :text, null: false
      add :search, :tsvector
      add :embedding, :vector, size: 384
    end

    create unique_index(:chunks, [:document_id, :ord])
    create index(:chunks, [:search], using: :gin)

    create index(:chunks, ["embedding vector_cosine_ops"],
             using: :hnsw,
             name: :chunks_embedding_hnsw_index
           )
  end
end
