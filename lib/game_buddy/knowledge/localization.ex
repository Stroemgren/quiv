defmodule GameBuddy.Knowledge.Localization do
  use Ecto.Schema

  schema "localizations" do
    belongs_to :game_version, GameBuddy.Catalog.GameVersion
    field :lang, :string
    field :key, :string
    field :value, :string
    field :source_file, :string
    field :source_line, :integer
  end
end
