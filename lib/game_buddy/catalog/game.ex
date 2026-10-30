defmodule GameBuddy.Catalog.Game do
  use Ecto.Schema
  import Ecto.Changeset

  schema "games" do
    field :slug, :string
    field :name, :string
    field :engine, :string
    has_many :versions, GameBuddy.Catalog.GameVersion
    timestamps(type: :utc_datetime)
  end

  def changeset(game, attrs) do
    game
    |> cast(attrs, [:slug, :name, :engine])
    |> validate_required([:slug, :name])
    |> unique_constraint(:slug)
  end
end
