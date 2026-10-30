defmodule GameBuddy.Catalog.GameVersion do
  @moduledoc "One ingest snapshot: a game at a version, build and DLC set."
  use Ecto.Schema
  import Ecto.Changeset

  schema "game_versions" do
    belongs_to :game, GameBuddy.Catalog.Game
    field :version, :string
    field :build_id, :string
    # when the build was published (the Steam manifest's LastUpdated), the
    # closest thing to a release date the files carry
    field :build_date, :date
    field :dlcs, {:array, :string}, default: []
    field :source_path, :string
    field :status, :string, default: "pending"
    field :is_default, :boolean, default: false
    field :ingested_at, :utc_datetime
    field :stats, :map, default: %{}
    timestamps(type: :utc_datetime)
  end

  def changeset(gv, attrs) do
    gv
    |> cast(attrs, [
      :game_id,
      :version,
      :build_id,
      :build_date,
      :dlcs,
      :source_path,
      :status,
      :is_default,
      :ingested_at,
      :stats
    ])
    |> validate_required([:game_id, :version])
    |> unique_constraint([:game_id, :version, :build_id])
  end
end
