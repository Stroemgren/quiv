# EU5 file survey (Phase 0)

Everything below was established by reading the installed files. No outside sources.

Install: `~/dev/game-data/eu5`, Steam app 3450310, Windows depots via steamcmd.
Size on disk 14 GB, of which `game/in_game/gfx` is 6.1 GB. Steam build id `26211608`
(from `steamapps/appmanifest_3450310.acf`). Game repo revision `42f8b31e`
(`game/loading_screen/caesar_rev.txt`), engine revision `27ae177fab`. There is no
plain version string file; the snapshot is identified as `build-26211608`.

## Layout

```
binaries/                      eu5.exe and DLLs
clausewitz/ jomini/            engine data
game/
  in_game/
    common/<kind>/**/*.txt     133 kinds, 2024 files, 21 MB   ← scripted definitions
    events/**/*.txt            373 files, 12 MB
    setup/countries/*.txt      46 files: colours, culture, religion per tag
    map_data/                  definitions.txt (region tree), location_templates.txt (3.7 MB),
                               nodes.dat (binary), csv/png map assets
    localization/jomini/       11 engine-level yml files
    gfx/ gui/ fonts/           graphics and UI, not ingested
  main_menu/
    common/<kind>/             game_concepts, game_rules, scenarios, bookmarks, static_modifiers...
    setup/1337/*.txt           the 1337 start: countries, institutions, religion, pops, characters...
    setup/1658/*.txt           a test bookmark built from `include` of the 1337 files
    setup/templates/*.txt      207 templates pulled into countries via `include = "name"`
    localization/<lang>/**     585 English yml files (11 languages shipped)
  loading_screen/              settings, 2 English yml files
  dlc/<DLC>/{in_game,main_menu}/...   same layout, overlaid per DLC
```

DLC directories present: `D000_shared`, `D008_fate_of_the_phoenix`,
`D009_across_the_pillars`, `D015_ancient_monuments_pack`, `D017_sacred_sites_pack`.
Each has a `<name>.dlc.json` with `steam_id`, and overlays `common/` kinds
(for example `government_reforms`, `laws`) and `setup/1337/`.

## Script dialect

All `.txt` script files are UTF-8 with BOM. Measured over `common/` and `events/`
(1.15 M lines):

| Feature | Seen | Example |
|---|---|---|
| Comparison operators | `<= >= != == < >` all present | `societal_value:x > 80` |
| Existence operator | `?=` | `ruler_or_regent ?= { ... }` |
| Quoted keys | yes | `"estate_power(estate_type:peasants_estate)" > 0.1` |
| Tagged blocks | yes | `color2 = rgb { 255 223 0 }`, `hsv360 { ... }` |
| Bare value lists | yes | `graphical_cultures = { pirate_gfx }` |
| File constants | `@name = value`, 15 definitions | `@debug_timer = 5` |
| Inline math `@[ ]` | none | |
| Prefixed identifiers | `scope:`, `government_type:`, `c:DAN`, dotted `root.x` | |
| Dates | `1337.4.1` | |

Parse results with `mix pdx.check`: 3338 files (all script dirs plus English
localization), 3337 clean, 1 warning (a `l_english: # comment` header, now handled),
0 failures, under 1 second.

Top level of `common/` files: 20,044 statements, 19,946 blocks (entities), 98 scalars
(`script_values` constants and `@` file constants). Duplicate keys within a kind are
rare (`on_action` 6, `genes` 3), so later-file-wins is the merge rule.

## Localization

Format: `l_english:` header, then ` key:0 "text"` lines. Markup measured over all
English files (257k keys):

| Markup | Count | Handling |
|---|---|---|
| `$key$` references | 39,618 | substituted recursively |
| `[Function(...)]` / `[concept\|e]` | 77,679 | concept → name, scope function → `[Scope]` |
| `#tag ... #!` formatting | 2,917 / 6,512 | stripped |
| `@icon!` icons | 3,505 | removed |
| `\n` | 7,229 | newline |

Naming: an entity's name is at `<key>` and its description at `<key>_desc`.
Confirmed for government types, reforms, laws and law options, ages, advances.
Events carry their own `title` and `desc` loc keys in the data.

## Kinds relevant to the north-star question

| Kind | Where | What |
|---|---|---|
| `government_types` | `common/government_types/00_default.txt` | monarchy, republic, theocracy, steppe_horde, tribe; succession laws per type |
| `government_reforms` | `common/government_reforms/*.txt` (+ DLC) | 356 reforms; fields documented in `readme.txt` in the same dir: `government`, `age`, `major`, `potential`, `allow`, `country_modifier`, `years` |
| `laws` | `common/laws/*.txt` | 200 law groups with `law_gov_group`, `potential`, nested options each with `potential`/`allow`/`country_modifier` |
| `age` | `common/age/00_default.txt` | `age_1_traditions` ... (the fifth age is `age_5_absolutism`, seen as a trigger value) |
| `setup_countries` | `main_menu/setup/1337/10_countries.txt` | per-tag start: `government = { type = monarchy ... }`, `laws`, `reforms`, `include` templates |
| `setup_templates` | `main_menu/setup/templates/*.txt` | e.g. `catholic_monarchy`: government type, succession, societal values, privileges |
| `trigger_localization` | `common/trigger_localization/*.txt` | maps trigger names to readable loc keys (the game's own tooltip text) |
| `effect_localization` | `common/effect_localization/*.txt` | same for effects |
| `game_concepts` | `main_menu/common/game_concepts/00_game_concepts.txt` | glossary entries |

Denmark (`DAN`) at 1337: block at `10_countries.txt:168`, `include = "catholic_monarchy"`,
capital `roskilde`, `laws = { legal_code_law = dan_regional_law }`, `country_rank =
rank_kingdom`, culture `danish`, religion `catholic`.

## Documentation shipped in the files

75 `.info` files and several `readme.txt` describe formats for modders
(for example `government_types/00_government_types.info`,
`government_reforms/readme.txt`, `trigger_localization/_trigger_localization.info`).
These are ingested as documents of kind `docs`.
