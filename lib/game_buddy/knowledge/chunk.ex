defmodule GameBuddy.Knowledge.Chunk do
  use Ecto.Schema

  schema "chunks" do
    belongs_to :document, GameBuddy.Knowledge.Document
    field :ord, :integer
    field :text, :string
    field :embedding, Pgvector.Ecto.Vector
    # tsvector maintained by the ingest; referenced in queries, never loaded
    field :search, :string, load_in_query: false
  end
end
