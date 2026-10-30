defmodule GameBuddy.Adapters.EU5 do
  @moduledoc """
  Europa Universalis V. Everything here was established by surveying the
  installed files (see docs/eu5-survey.md), not from outside sources.

  Layout under the install root:

      game/in_game/common/<kind>/**/*.txt     scripted definitions, one kind per directory
      game/in_game/events/**/*.txt            events (keys like `namespace.1`)
      game/in_game/setup/countries/*.txt      country colours, culture, religion
      game/in_game/map_data/*.txt             location templates and the region tree
      game/main_menu/common/<kind>/**/*.txt   more kinds (game concepts, rules, scenarios...)
      game/main_menu/setup/1337/*.txt         start-of-game state for the 1337 bookmark
      game/main_menu/localization/<lang>/**   localization
      game/dlc/<DLC>/{in_game,main_menu}/...  the same layout, overlaid per DLC
  """
  @behaviour GameBuddy.Adapter

  @impl true
  def slug, do: "eu5"
  @impl true
  def name, do: "Europa Universalis V"
  @impl true
  def engine, do: "jomini"

  # The install carries no player-facing version label (that lives in the
  # launcher, a separate depot); the Steam build id and its LastUpdated time
  # are the version the files have.
  @impl true
  def detect_version(root) do
    acf =
      case File.read(Path.join(root, "steamapps/appmanifest_3450310.acf")) do
        {:ok, acf} -> acf
        _ -> ""
      end

    build_id =
      case Regex.run(~r/"buildid"\s+"(\d+)"/, acf) do
        [_, id] -> id
        _ -> nil
      end

    build_date =
      case Regex.run(~r/"LastUpdated"\s+"(\d+)"/, acf) do
        [_, t] -> t |> String.to_integer() |> DateTime.from_unix!() |> DateTime.to_date()
        _ -> nil
      end

    rev =
      case File.read(Path.join(root, "game/loading_screen/caesar_rev.txt")) do
        {:ok, r} -> String.trim(r)
        _ -> nil
      end

    version =
      cond do
        build_id -> "build-#{build_id}"
        rev -> "rev-#{rev}"
        true -> "unknown"
      end

    %{version: version, build_id: build_id || rev, build_date: build_date, dlcs: dlc_dirs(root)}
  end

  defp dlc_dirs(root) do
    root
    |> Path.join("game/dlc/*")
    |> Path.wildcard()
    |> Enum.filter(&File.dir?/1)
    |> Enum.map(&Path.basename/1)
    |> Enum.sort()
  end

  # Base content first, then each DLC in directory order, so DLC definitions override.
  defp content_roots(root) do
    base = [{Path.join(root, "game/in_game"), nil}, {Path.join(root, "game/main_menu"), nil}]

    dlc =
      for d <- dlc_dirs(root),
          sub <- ["in_game", "main_menu"],
          dir = Path.join([root, "game/dlc", d, sub]),
          File.dir?(dir),
          do: {dir, d}

    base ++ dlc
  end

  @impl true
  def sources(root) do
    Enum.flat_map(content_roots(root), fn {r, dlc} ->
      common =
        for dir <- Path.wildcard(Path.join(r, "common/*")), File.dir?(dir) do
          %{kind: Path.basename(dir), files: sorted_txt(Path.join(dir, "**/*.txt")), dlc: dlc}
        end

      extra = [
        %{kind: "events", files: sorted_txt(Path.join(r, "events/**/*.txt")), dlc: dlc},
        # Start-of-game setup. Files wrap their content one level deep
        # (`countries = { DAN = { ... } }`), so entities are the children and the
        # kind is named after the wrapper: setup_countries, setup_institution_manager...
        %{
          kind: "setup",
          files: sorted_txt(Path.join(r, "setup/1337/*.txt")),
          dlc: dlc,
          mode: :nested
        },
        # Setup templates: one file per template, pulled into countries with `include = "name"`.
        %{
          kind: "setup_templates",
          files: sorted_txt(Path.join(r, "setup/templates/*.txt")),
          dlc: dlc,
          mode: :file
        },
        %{
          kind: "country_setup",
          files: sorted_txt(Path.join(r, "setup/countries/*.txt")),
          dlc: dlc
        },
        %{
          kind: "locations",
          files: existing([Path.join(r, "map_data/location_templates.txt")]),
          dlc: dlc
        },
        %{
          kind: "map_regions",
          files: existing([Path.join(r, "map_data/definitions.txt")]),
          dlc: dlc
        }
      ]

      Enum.reject(common ++ extra, &(&1.files == []))
    end) ++
      [
        # Engine constants (NGame, NDiplomacy, ...): one entity per group.
        %{
          kind: "defines",
          files: sorted_txt(Path.join(root, "game/loading_screen/common/defines/**/*.txt")),
          dlc: nil
        }
      ]
  end

  defp sorted_txt(glob),
    do: glob |> Path.wildcard() |> Enum.filter(&File.regular?/1) |> Enum.sort()

  defp existing(paths), do: Enum.filter(paths, &File.regular?/1)

  @impl true
  def localization_files(root, lang) do
    # Every .yml under any localization directory whose header says l_<lang>.
    # Base game first, then DLC overlays.
    Enum.flat_map(content_roots(root) ++ [{Path.join(root, "game/loading_screen"), nil}], fn {r,
                                                                                              _} ->
      r
      |> Path.join("localization/**/*.yml")
      |> Path.wildcard()
      |> Enum.filter(&String.contains?(&1, "/#{lang}/"))
      |> Enum.sort()
    end)
  end

  @impl true
  def doc_files(root) do
    Enum.flat_map(content_roots(root), fn {r, _} ->
      Path.wildcard(Path.join(r, "{common,setup}/**/*.info")) ++
        Path.wildcard(Path.join(r, "{common,setup}/**/readme*.{txt,md}")) ++
        Path.wildcard(Path.join(r, "{common,setup}/**/*.md"))
    end)
    # the defines carry the engine's own comments on each constant
    |> Kernel.++(Path.wildcard(Path.join(root, "game/loading_screen/common/defines/**/*.txt")))
    |> Enum.uniq()
    |> Enum.sort()
  end

  @impl true
  def name_keys("events", key, data), do: string_keys(data, ["title"]) ++ [key]
  def name_keys("game_concepts", key, _data), do: ["game_concept_#{key}", key]
  def name_keys("modifier_type_definitions", key, _data), do: ["MODIFIER_TYPE_NAME_#{key}", key]
  def name_keys("setup_countries", key, _data), do: [key]
  def name_keys(_kind, key, _data), do: [key, "#{key}_name"]

  @impl true
  def desc_keys("events", _key, data), do: string_keys(data, ["desc"])
  def desc_keys("game_concepts", key, _data), do: ["game_concept_#{key}_desc"]
  def desc_keys("modifier_type_definitions", key, _data), do: ["MODIFIER_TYPE_DESC_#{key}"]
  def desc_keys(_kind, key, _data), do: ["#{key}_desc", "desc_#{key}", "#{key}_description"]

  @impl true
  def label_keys(term), do: [term, "MODIFIER_TYPE_NAME_#{term}", "game_concept_#{term}"]

  defp string_keys(data, fields), do: for(f <- fields, is_binary(data[f]), do: data[f])

  @impl true
  def skip_top_level_keys, do: ["namespace"]

  # -- textures ---------------------------------------------------------------
  # Surveyed: the in-game GUI references `gfx/interface/...`, which resolves
  # against the main_menu content set for icons and against loading_screen for
  # the engine's tooltip frames; DLCs add illustrations under the same layout.

  @impl true
  def gfx_roots(root) do
    dlc =
      for d <- dlc_dirs(root),
          sub <- ["in_game", "main_menu"],
          dir = Path.join([root, "game/dlc", d, sub]),
          File.dir?(Path.join(dir, "gfx")),
          do: dir

    dlc ++
      Enum.map(["game/main_menu", "game/in_game", "game/loading_screen"], &Path.join(root, &1))
  end

  # Folders under gfx/interface/icons whose files are named after the kind's
  # keys, each with the game's `_default.dds` fallback. Checked against the
  # files: every kind listed resolves for at least three quarters of its keys.
  @icon_dirs %{
    "estate_privileges" => "privileges",
    "laws" => "laws",
    "building_types" => "buildings",
    "building_categories" => "building_categories",
    "estates" => "estates",
    "institution" => "institutions",
    "subject_types" => "subject_types",
    "wargoals" => "war_goals",
    "religions" => "religion",
    "religious_schools" => "religious_schools",
    "religious_focuses" => "religious_focuses",
    "modifier_type_definitions" => "modifier_types",
    "international_organizations" => "international_organizations",
    "situations" => "situations",
    "disasters" => "disasters",
    "town_rights" => "town_rights",
    "parliament_types" => "parliament_types",
    "traits" => "traits",
    "achievements" => "achievements",
    "chivalric_orders" => "chivalric_orders",
    "character_interactions" => "character_interactions",
    "heir_selections" => "heir_selection",
    "unit_abilities" => "unit_ability",
    "unit_categories" => "unit_category"
  }

  # Kinds whose `icon` field names the file (falling back to the key).
  @icon_field_dirs %{
    "gods" => "gods",
    "cabinet_actions" => "cabinet_actions",
    "religious_aspects" => "religious_aspects"
  }

  @impl true
  def icon_paths("advances", key, data),
    do: [
      "gfx/interface/advance/#{icon_name(data, key)}.dds",
      "gfx/interface/advance/_default.dds"
    ]

  # reforms are drawn as cards with a portrait illustration
  def icon_paths("government_reforms", key, _data),
    do: icon_candidates("government_reforms/illustrations", key)

  def icon_paths("goods", key, _data), do: icon_candidates("trade_goods", "icon_goods_#{key}")

  def icon_paths("game_concepts", _key, %{"texture" => t}) when is_binary(t),
    do: ["gfx/interface/icons/#{t}.dds"]

  def icon_paths(kind, key, data) do
    cond do
      dir = @icon_dirs[kind] -> icon_candidates(dir, key)
      dir = @icon_field_dirs[kind] -> icon_candidates(dir, icon_name(data, key))
      true -> []
    end
  end

  defp icon_name(%{"icon" => icon}, _key) when is_binary(icon), do: icon
  defp icon_name(_data, key), do: key

  defp icon_candidates(dir, name),
    do: ["gfx/interface/icons/#{dir}/#{name}.dds", "gfx/interface/icons/#{dir}/_default.dds"]

  # game/loading_screen/gui/tooltip.gui, template bg_tooltip: a black rounded
  # background with dark_blue at 0.3 and blue fading in from the top at 0.5,
  # and (when locked) a frame colored new_gold, spriteborder 10 at
  # texture_density 2; table fields are turquoise at 0.2
  # (main_menu_cooltip_types.gui). Fonts: loading_screen_fonts.font maps
  # StandardGameFont and HeadersFont to Noto Serif. Text colors:
  # textformatting.gui, default block.
  @impl true
  def theme do
    %{
      "fonts" => %{"body" => "Noto Serif", "heading" => "Noto Serif"},
      "text_formats" => %{
        "file" => "game/loading_screen/gui/textformatting.gui",
        "roles" => %{
          "text" => "color_white",
          "muted" => "color_gray",
          "dim" => "color_dark_gray",
          "good" => "color_green",
          "bad" => "color_red",
          "gold" => "color_gold",
          "link" => "color_link",
          "title" => "color_yellow",
          "concept" => "color_concept",
          "highlight" => "color_highlight",
          "title_dim" => "color_goldy_yellow"
        }
      },
      "colors" => %{
        "panel" => "gfx/interface/colors/dark_blue.dds",
        "glow" => "gfx/interface/colors/blue.dds",
        "box" => "gfx/interface/colors/turquoise.dds",
        "frame" => "gfx/interface/colors/new_gold.dds"
      },
      "textures" => %{
        "frame" => %{
          "path" => "gfx/interface/component_tiles/bg_round_corners_frame.dds",
          "slice" => 10,
          "density" => 2,
          "tint" => "gfx/interface/colors/new_gold.dds"
        }
      }
    }
  end

  @impl true
  def aliases,
    do: ["eu5", "eu v", "europa universalis 5", "europa universalis v", "europa universalis"]

  @impl true
  def intro_notes(lookup) do
    dates =
      case lookup.("defines", "NGame") do
        %{data: %{"START_DATE" => s, "END_DATE" => e}} ->
          ["The campaign runs from #{s} to #{e} (defines/NGame)."]

        _ ->
          []
      end

    dates ++
      [
        "The player plays a country. A country's start-of-game state (government, laws, privileges, rank, capital) is setup_countries/<TAG>; its culture and religion are in country_setup/<TAG>. Three-letter tags are the keys (DAN = Denmark); search by name to find one.",
        "Content is rarely keyed to a country: reforms, laws, advances, privileges and decisions are gated by culture, culture group, religion, language or region in their conditions. Follow a country → culture → culture group and read what references the group.",
        "Government reforms are government_reforms (government type, age from which they are available, conditions, effects); laws are laws with one block per policy option; the ages are age. Modifier names are in modifier_type_definitions; game_concepts is the glossary."
      ]
  end
end
