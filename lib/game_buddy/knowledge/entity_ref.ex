defmodule GameBuddy.Knowledge.EntityRef do
  use Ecto.Schema

  schema "entity_refs" do
    belongs_to :from_entity, GameBuddy.Knowledge.Entity
    field :path, :string
    field :to_kind, :string
    field :to_key, :string
  end
end
