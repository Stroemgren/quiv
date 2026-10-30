defmodule GameBuddy.Adapter do
  @moduledoc """
  Per-game knowledge. Everything the generic pipeline needs to know about where
  a game keeps its files and how it names things. Implementations are small
  and declarative: file layout, localization key patterns, a few notes for the
  intro. Rendering, search and the tools know nothing about any game.

  A *source* is a group of script files that all define entities of one kind:

      %{kind: "laws", files: [path, ...], dlc: nil | "D009_across_the_pillars"}

  An optional `mode: :nested` means each file wraps its entities one level deep
  (`countries = { DAN = { ... } }`); the entity kind then becomes
  `<kind>_<wrapper>` and the entity key the inner key. `mode: :file` means each
  whole file is one entity, keyed by the file name without extension.

  Sources are ordered; when the same kind/key appears twice the later source wins,
  which is how the games themselves treat base vs. DLC definitions.
  """

  @type source :: %{
          required(:kind) => String.t(),
          required(:files) => [Path.t()],
          required(:dlc) => String.t() | nil,
          optional(:mode) => :flat | :nested | :file
        }
  @type version_info :: %{
          required(:version) => String.t(),
          required(:build_id) => String.t() | nil,
          required(:dlcs) => [String.t()],
          optional(:build_date) => Date.t() | nil
        }

  @callback slug() :: String.t()
  @callback name() :: String.t()
  @callback engine() :: String.t()

  @doc "Detect version, build and DLC list from the install root."
  @callback detect_version(root :: Path.t()) :: version_info

  @doc "Ordered script sources."
  @callback sources(root :: Path.t()) :: [source]

  @doc "Localization files for a language, ordered (later override earlier)."
  @callback localization_files(root :: Path.t(), lang :: String.t()) :: [Path.t()]

  @doc "Text documentation shipped with the game (readme / .info files)."
  @callback doc_files(root :: Path.t()) :: [Path.t()]

  @doc "Candidate localization keys for an entity's display name, in priority order."
  @callback name_keys(kind :: String.t(), key :: String.t(), data :: map) :: [String.t()]

  @doc "Candidate localization keys for an entity's description, in priority order."
  @callback desc_keys(kind :: String.t(), key :: String.t(), data :: map) :: [String.t()]

  @doc "Statement keys at file top level that are not entities (e.g. `namespace`)."
  @callback skip_top_level_keys() :: [String.t()]

  @doc "Candidate localization keys for a field name or scalar value when rendering."
  @callback label_keys(term :: String.t()) :: [String.t()]

  @doc "Other names players use for the game, for `game_lookup`."
  @callback aliases() :: [String.t()]

  @doc """
  Kinds that hold the engine's rendering rules: trigger and effect
  localization tables, modifier type definitions, and the glossary.
  """
  @callback render_kinds() :: %{
              triggers: String.t(),
              effects: String.t(),
              modifiers: String.t(),
              concepts: String.t(),
              defines: String.t()
            }

  @doc """
  Short notes for the game intro, derived from the files. `lookup.(kind, key)`
  returns a parsed entity (with `data`) or nil.
  """
  @callback intro_notes(lookup :: (String.t(), String.t() -> map | nil)) :: [String.t()]

  @doc """
  Directories that texture paths (`gfx/interface/...`) resolve against, in
  priority order. Empty when the game ships no usable textures.
  """
  @callback gfx_roots(root :: Path.t()) :: [Path.t()]

  @doc """
  Candidate texture paths for an entity's icon, relative to a gfx root, in
  priority order with the game's own fallback (`_default.dds`) last. The
  first path that exists is kept on the document.
  """
  @callback icon_paths(kind :: String.t(), key :: String.t(), data :: map) :: [String.t()]

  @doc """
  How the game draws a tooltip, as declarations that `mix game.assets`
  resolves against the files: font families, text colors looked up in the
  game's text formatting file, color roles bound to its flat color textures,
  and frame textures with the 9-slice borders its GUI uses.
  """
  @callback theme() :: map

  @optional_callbacks label_keys: 1,
                      aliases: 0,
                      render_kinds: 0,
                      intro_notes: 1,
                      gfx_roots: 1,
                      icon_paths: 3,
                      theme: 0

  # Conventions of the Clausewitz/Jomini engine family.
  @default_render_kinds %{
    triggers: "trigger_localization",
    effects: "effect_localization",
    modifiers: "modifier_type_definitions",
    concepts: "game_concepts",
    defines: "defines"
  }

  @doc "Label keys for a term via the adapter, falling back to the term itself."
  def label_keys(adapter, term), do: call(adapter, :label_keys, [term], [term])

  def aliases(adapter), do: call(adapter, :aliases, [], [adapter.slug(), adapter.name()])

  def render_kinds(adapter),
    do: Map.merge(@default_render_kinds, call(adapter, :render_kinds, [], %{}))

  def intro_notes(adapter, lookup), do: call(adapter, :intro_notes, [lookup], [])

  def gfx_roots(adapter, root), do: call(adapter, :gfx_roots, [root], [])

  def icon_paths(adapter, kind, key, data),
    do: call(adapter, :icon_paths, [kind, key, data || %{}], [])

  def theme(adapter), do: call(adapter, :theme, [], %{})

  defp call(adapter, fun, args, default) do
    Code.ensure_loaded!(adapter)

    if function_exported?(adapter, fun, length(args)),
      do: apply(adapter, fun, args),
      else: default
  end

  # Every game the server knows, with data or as a placeholder; the catalog
  # registers all of them at start so that nothing in the tool text is
  # single-game.
  @adapters [GameBuddy.Adapters.EU5, GameBuddy.Adapters.HOI4, GameBuddy.Adapters.Civ7]

  def all, do: @adapters

  def for_slug(slug) do
    Enum.find(@adapters, &(&1.slug() == slug)) ||
      raise(ArgumentError, "no adapter for game #{inspect(slug)}")
  end

  @doc "Adapter for an ingested snapshot (needs `game` preloaded)."
  def for_version(%{game: %{slug: slug}}), do: for_slug(slug)
end
