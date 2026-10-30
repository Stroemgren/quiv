defmodule GameBuddy.Adapters.HOI4 do
  @moduledoc """
  Hearts of Iron IV: a placeholder until its files are surveyed. It registers
  the game and the names players use, so that the catalog, the tool text and
  the client tests cover more than one game; every tool returns empty content
  for it until a snapshot exists. Nothing here describes the files.
  """
  @behaviour GameBuddy.Adapter

  @impl true
  def slug, do: "hoi4"
  @impl true
  def name, do: "Hearts of Iron IV"
  @impl true
  def engine, do: "clausewitz"
  @impl true
  def aliases, do: ["hoi4", "hoi 4", "hoi iv", "hearts of iron 4", "hearts of iron iv"]

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
