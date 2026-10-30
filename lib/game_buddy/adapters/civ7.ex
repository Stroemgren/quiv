defmodule GameBuddy.Adapters.Civ7 do
  @moduledoc """
  Sid Meier's Civilization VII: a placeholder until its files are surveyed
  (a different engine family from the Paradox games, so the parser and the
  rendering tables will need their own path). It registers the game and the
  names players use; every tool returns empty content for it until a snapshot
  exists. Nothing here describes the files.
  """
  @behaviour GameBuddy.Adapter

  @impl true
  def slug, do: "civ7"
  @impl true
  def name, do: "Sid Meier's Civilization VII"
  @impl true
  def engine, do: "firaxis"
  @impl true
  def aliases, do: ["civ7", "civ 7", "civ vii", "civilization 7", "civilization vii", "civ"]

  @impl true
  def detect_version(_root), do: %{version: "unknown", build_id: nil, dlcs: []}
  @impl true
  def sources(_root), do: []
  @impl true
  def localization_files(_root, _lang), do: []
  @impl true
  def doc_files(_root), do: []
  @impl true
  def name_keys(_kind, key, _data), do: [key]
  @impl true
  def desc_keys(_kind, _key, _data), do: []
  @impl true
  def skip_top_level_keys, do: []
end
