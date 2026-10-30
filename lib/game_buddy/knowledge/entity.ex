defmodule GameBuddy.Knowledge.Entity do
  use Ecto.Schema

  schema "entities" do
    belongs_to :game_version, GameBuddy.Catalog.GameVersion
    field :kind, :string
    field :key, :string
    field :name, :string
    field :description, :string
    field :data, :map
    field :ast, :map
    field :source_file, :string
    field :source_line, :integer
    field :dlc, :string
    field :card, :string
    # tsvector maintained by the ingest; referenced in queries, never loaded
    field :search, :string, load_in_query: false
    timestamps(type: :utc_datetime)
  end
end
