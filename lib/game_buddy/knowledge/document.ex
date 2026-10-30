defmodule GameBuddy.Knowledge.Document do
  use Ecto.Schema

  schema "documents" do
    belongs_to :game_version, GameBuddy.Catalog.GameVersion
    belongs_to :entity, GameBuddy.Knowledge.Entity
    field :kind, :string
    field :key, :string
    field :title, :string
    field :body, :string
    field :source_file, :string
    field :dlc, :string
    field :sections, :map
    has_many :chunks, GameBuddy.Knowledge.Chunk
    timestamps(type: :utc_datetime)
  end
end
