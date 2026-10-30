# Game Buddy: plan v0 (EU5 first)

An MCP server that turns an AI assistant into a game buddy. Every fact it serves is
extracted directly from the game's own files. No wikis, no guides, no other sources.

First target: Europa Universalis V (Steam app 3450310). The pipeline is designed so a
second game is an adapter, not a rewrite, but we only build what EU5 needs now.

## North-star question

> "Playing as Denmark in the fifth age, how would my available reforms change by
> switching my monarchy for a republic?"

This is hard to answer by browsing, and easy to answer if the system can:

1. Enumerate every reform-like entity with its conditions as structured data
   (government type, age, country, culture, religion, prerequisites, ...).
2. Read Denmark's starting state from the setup/history files.
3. Evaluate those conditions against two hypothetical states (monarchy vs. republic,
   age five) and report: available in both, only in A, only in B, and conditions it
   could not decide, each shown in readable form.
4. Present everything with localized in-game names and descriptions, with a source
   file and line for every fact.

Phases 0 to 5 build the generic machinery. Phase 6 nails this question.

## Principles

- **Game files are the only source.** Each stored fact carries `source_file` and
  `source_line`. The survey of the files decides the structure, not prior knowledge.
- **Generic first, typed second.** A generic script parser and a generic entity store
  handle any game written in Clausewitz/Jomini script. A small per-game adapter
  supplies paths, version detection and naming hints. Typed tables exist only for
  kinds that need richer queries.
- **Versioned snapshots.** Every ingest run is a `(game, version, build, dlcs)`
  snapshot. Nothing is overwritten; the MCP serves a default snapshot and can take
  an explicit one.
- **Prototype.** Optimize for learning. Expect to restructure after EU5 works.

## Stack (decided)

| Layer | Choice |
|---|---|
| Language | Elixir 1.19.1 / OTP 28 |
| Web + MCP host | Phoenix 1.8, anubis_mcp 2.2 (Streamable HTTP, mounted at `/mcp`) |
| Database | Postgres 17 with pgvector 0.8.7, Docker container `game_dev`, port 5012, user/pass `game`/`game` |
| ORM | Ecto 3.14, `pgvector` 0.4 for the vector type |
| Script parser | Elixir, hand-written lexer and recursive-descent parser (`GameBuddy.Pdx`) |
| Embeddings | Bumblebee 0.8, model `BAAI/bge-small-en-v1.5` (384 dims), run locally: EMLX 0.5 (Apple MLX, Metal GPU) on macOS, EXLA 1.0 (CPU) elsewhere |
| Search | Hybrid: Postgres full-text (tsvector) + pgvector cosine, merged with reciprocal rank fusion |
| Exposure | ngrok to `localhost:4000`, no auth while testing |
| Clients | ChatGPT in Developer Mode (custom connector), Claude custom connector |
| Game files | `~/dev/game-data/eu5`, Windows depots via steamcmd, treated as read-only untrusted input |

## Architecture

```
steamcmd ──► ~/dev/game-data/eu5            raw game files (read-only)
                    │
                    ▼
          mix game.survey  ───────────────► docs/eu5-survey.md (phase 0)
                    │
                    ▼
          mix game.ingest eu5
            scan ─► parse (Pdx) ─► normalize (adapter) ─► render cards ─► store
                    │
                    ▼
          Postgres: games, game_versions, entities, entity_refs,
                    localizations, documents, chunks (tsvector + vector)
                    │
                    ▼
          GameBuddy.Knowledge  (search / fetch / list / get / refs / compare)
                    │
                    ▼
          GameBuddy.MCP tools ─► Phoenix /mcp ─► ngrok ─► ChatGPT, Claude
```

### Modules

- `GameBuddy.Pdx` — generic parser for Paradox script (`key = { ... }` files) and
  Paradox localization YAML (`l_english:` files, which are not real YAML).
  Output is an ordered AST that preserves duplicate keys and comparison operators
  (`=`, `!=`, `<`, `>`, `<=`, `>=`, `?=`), handles `@variables`, inline math,
  dates, quoted strings, bare values in lists, and comments. One module, no game
  knowledge.
- `GameBuddy.Adapter` behaviour and `GameBuddy.Adapters.EU5` — where the files are
  (data roots, localization dir), how to detect version and build, how directories
  map to entity kinds, localization key patterns for names and descriptions, and
  optional vocabulary for condition rendering. Everything in the EU5 adapter is
  learned from the phase 0 survey.
- `GameBuddy.Ingest` — the pipeline: parallel file parsing (`Task.async_stream`),
  normalization into entities, bulk inserts, card rendering, chunking, embedding.
  Idempotent per snapshot.
- `GameBuddy.Render` — turns an entity into a readable markdown card: localized
  name, description, each block rendered with localized names, condition blocks
  rendered as readable requirement lists. The card is what gets embedded and what
  `fetch` returns.
- `GameBuddy.Script.Eval` — partial evaluator for condition blocks (phase 6).
  Given a context map and a block, returns true, false or unknown per leaf, with
  AND/OR/NOT/NOR/NAND combinators. Unknown leaves are reported, never guessed.
- `GameBuddy.Knowledge` — query API used by the tools.
- `GameBuddy.MCP` — anubis server and tool components.
- `GameBuddyWeb` — Phoenix endpoint and router. LiveView admin can come later.

## Data model

```
games             id, slug, name, engine
game_versions     id, game_id, version, build_id, dlcs jsonb, source_path,
                  ingested_at, status, is_default
entities          id, game_version_id, kind, key, name, description,
                  data jsonb (folded map: duplicate keys become arrays),
                  ast jsonb (ordered statements, exact),
                  source_file, source_line, card text, search tsvector
                  unique (game_version_id, kind, key)
entity_refs       from_entity_id, path, to_kind, to_key   (cross references found in data)
localizations     game_version_id, lang, key, value, source_file, source_line
                  unique (game_version_id, lang, key)
documents         id, game_version_id, kind, key, title, body, source_file
                  (one per entity card, plus text-only material such as
                   concept descriptions, event text, tooltips)
chunks            id, document_id, ord, text, search tsvector, embedding vector(384)
```

`kind` is the directory path relative to the data root, normalized (for example
`common/laws` becomes `laws`). No singularizing or guessing. The adapter can rename
kinds where that reads better.

## MCP tools (v2: documents only)

- `game_lookup(query?)` — free-form game name → game and version identifiers.
- `game_intro(game, version)` — the intro document: usage, the game's core
  vocabulary from its own glossary, kinds, per-game notes.
- `search(query)` — one compiled document of the best matches with keys and
  matched passages, across entity documents, localization text and docs.
- `entity(key)` — the full document for a key, including connections with keys
  so the client can escalate (country → culture → culture group → what
  references it) and `index/<kind>` listings.
- `show(keys)` — presentation only: renders up to 12 entities as an MCP App
  (card, carousel, comparison table) from their structured sections. Returns
  no new facts; the description tells the model to use it after the answer is
  known, when the user wants to see or compare things, at most once per reply.

No tool schema mentions a game-specific concept. Evaluation of conditions is
left to the client, which reads them in the game's own tooltip language.

## Status (2026-10-30)

MCP App prototype: `show` plus the `ui://game-buddy/entities` resource. Entity
documents are now stored as markdown plus their structured `sections` (same
renderer, two outputs). First claude.ai test: the view renders (one `show` call
with six reforms); the page was then restyled after the game's own tooltips.

Lessons from the first claude.ai session (tool-call log):
- "Show me Ruthenian reforms" and "Show me Fortification Licenses" did not
  trigger `show`: Claude fetched the entities and answered in text. The intro is
  read once per conversation at best (one `game_intro` call all morning), so the
  tool descriptions are the lever: `show` now says to call it whenever the user
  asks to show, see, display or compare, after `entity`, and the intro repeats
  it. Watch the next session.
- A file name leaked into an answer ("10 cultural advances in
  `culture_ruthenian.txt`"): the `Source:` line sat in the document header,
  right under the key, so the model read it as a fact. It is now the last line
  of the document, labelled "Source file: ... (internal, not for the player)",
  the search excerpt skips it, and the `entity` description and the intro say
  to answer in the game's names and keep file names and keys out unless asked.
  Costs a re-ingest and ~12 min of re-embedding (the first chunk of every
  entity document changed).

Game art in the view (same day): the files hold everything the look needs.
Icons are named by key per kind under `gfx/interface/icons/<folder>/` with a
`_default.dds` fallback (privileges, laws, buildings, estates, institutions,
subject types, religions, modifier types, ...), advances under
`gfx/interface/advance/`, reforms as portrait illustrations, concepts via their
`texture` field. The engine's tooltip is `template bg_tooltip` in
`game/loading_screen/gui/tooltip.gui`: a black rounded background with
dark_blue at 0.3 and blue fading in from the top, and when locked a frame
colored new_gold (spriteborder 10 at density 2); its `modify_texture` replaces
the color and keeps the alpha, which the converter mirrors. The UI font is Noto
Serif (`loading_screen_fonts.font`); text colors are in `textformatting.gui`,
read at asset time from the non-color-blind block. In-game interface textures
live under `game/main_menu/gfx/interface` (12k files), not `in_game`; the
engine's own under `game/loading_screen`. DDS decodes with Pillow (DXT1, DXT5,
BC7), so conversion is a Python step; a 96 px icon is 1.5-4 KB as WebP and the
frame texture 340 bytes, so everything travels inline in the `show` payload as
data URIs within a budget (the MCP Apps CSP allows `data:` images; app-only
tools and proxied resource reads exist for lazy loading if the budget binds).
The kind-to-folder mapping was checked against sampled keys: 24 kinds resolve
for 75% or more; unit types, casus belli, pop types and a few others follow no
key convention and get no icon.

Lazy tool loading (afternoon): a claude.ai test went to the web without one
call reaching the server. Its trace began "Checking whether the lookup tool's
schema is worth loading": claude.ai now loads connector tool schemas lazily and
decides from the tool name and the start of its description. `game_lookup`'s
"Find which games and versions are available" did not read as a source of
answers about EU5. Now every tool description is computed at request time
(`description/0`) and its first sentence names the indexed games from the
catalog and the questions the tool answers ("Start here for any question about
Europa Universalis V (eu5): rules, mechanics, ..."), and the server sends
`instructions` with the initialize result saying the same and "instead of web
search". No game vocabulary in code: the names come from the `games` table.
- With the tools loaded, "Explain the estate privilege called Fortification
  Licenses" fetched the privilege and six related documents but never called
  `show`, whose description only named "show, see, compare" wording. The
  trigger is now "the answer centers on specific entities" (asked about one, or
  to see or compare some; skip broad questions), repeated in the server
  instructions, and the `entity` description ends with the nudge to follow up
  with `show` for the entity the user asked about. The intro says the same
  from the next ingest.
- A later run began "Weighing whether to search or use the Game_Buddy tool"
  and went to the web without loading the connector at all: that decision is
  made from the connector's name and whatever summary the host keeps, before
  any tool description is seen, and it varies run to run (the previous run
  loaded the tools). Server-side levers: `serverInfo.title` now names the
  indexed games ("Game Buddy: Europa Universalis V (eu5) from the game
  files") and the instructions say "instead of web search". The user-side
  lever is the connector's name in claude.ai; a name that says what the data
  is ("EU5 game files") beats a brand. Each handshake is now logged as an
  `initialize` row, so the dashboard shows when a host connected and with
  which protocol.
- Asked why it skipped the connector, claude.ai's Claude explained: the tools
  "were listed as available but not yet loaded"; it could not tell from the
  connector's name and the bare tool names (search, entity, ...) whether this
  was a third-party partner app it should only offer rather than call
  unprompted, so it took the cautious path; it was also confident the web had
  the numbers and did not know how current the connector's coverage was. It
  conceded loading the definitions is cheap. Changes: the tools are now a
  `game_*` family (`game_search`, `game_entity`, `game_show`), and the title
  and instructions carry the build and ingest date ("as current as the
  installed game"). The remaining levers are the user's: the connector's name
  in claude.ai, naming it in the question, or a project instruction such as
  "use Game Buddy for EU5 questions".
- Asked what to change, the same Claude listed: server instructions with every
  name players use, the version and the call order (the one thing it sees
  before deciding); game names in tool names (declined: does not scale past
  one game); game names and "before web search" in every tool description,
  with abbreviations, because keyword search over deferred tools may surface
  only one of them; a concrete version; a shorter warm-up (four calls before
  the first answer vs one web search). Adopted: the instructions and every
  description name the games with their aliases, the build and ingest date,
  and "use before web search"; `game_search` is the first call with no setup,
  `game` and `version` are optional everywhere and default to the latest
  indexed version, `game_lookup` and `game_intro` are described as optional.
  It also reported that `game_show` is tagged `third_party_mcp_app` by the
  host because it carries UI metadata, which makes the model treat it as
  something to offer rather than call unprompted; nothing to do about that
  server-side.
- Multi-game from the start (user decision): client tests would not hold if
  every text named only EU5. Hearts of Iron IV and Civilization VII are
  placeholder adapters (slug, name, aliases, no files); `ensure_games` registers
  all adapters at start; the title, instructions and descriptions list all
  three with aliases, the default game first; snapshots are named only for
  games that have one. A known game without a snapshot gets empty content from
  every tool (0 results, no document, nothing indexed), not an error, so the
  client only learns by trying, as it would in production.

Pending: ChatGPT render test; script-value modifier values in the view; coats of
arms (composed from layered definitions, not single textures).

### Earlier (2026-10-29)

Rebuilt around documents after the first client tests. Everything a client
gets is a markdown document rendered from the files; the four tools carry no
game vocabulary. The structured ingest (parser, folded data, reference graph)
is the production line for those documents, not something clients see.
Pending: client re-test of the three questions; the engine-level knowledge
question (how the game plays) once the documents are judged.

First client lessons (both questions failed for the same two reasons):

1. The client narrowed `search` to guessed kinds and never saw the right one
   (`international_organizations/marriage_union`), and it searched for the
   EU4 term ("personal union") instead of the player's words. Now there are
   no kinds to guess: search returns one compiled document across everything.
2. Country-specific content is almost never keyed to the tag; it is gated by
   culture group, religion or region inside `potential`/`allow`. Now every
   document has a Connections section, so Kyiv → Ruthenian → russian_group →
   "referenced by 6 government reforms" is three lookups, and conditions read
   "Belongs to the Russian culture group" rather than script.

## Phases

### Phase 0: acquire and survey

- Download EU5 via `scripts/steam_download.sh` (running).
- Write `mix game.survey <path>`: directory tree with file counts and sizes,
  encodings, version and build detection, a first-pass parse of every `.txt` and
  `.yml` with a success rate per directory, localization key-pattern hit rates per
  kind, and a list of directories whose content relates to governments, reforms,
  laws, ages and country setup, found by reading the files.
- Output: `docs/eu5-survey.md`.
- Done when the survey names the data roots, the version string, the kinds to
  ingest, and the kinds relevant to the north-star question.

### Phase 1: scaffold

- `mix phx.new game_buddy` inside this repo (no mailer), Ecto pointed at
  `game_dev` on port 5012, `vector` extension migration, core tables.
- anubis_mcp server with `game_info` only, mounted at `/mcp`.
- Done when MCP Inspector lists the tool locally and a Claude custom connector
  calls it through ngrok.

### Phase 2: parser

- NimbleParsec grammar for script and the localization format. Fixture tests with
  small excerpts copied from the game files.
- `mix pdx.parse <file>` prints the AST as JSON for inspection.
- Done when 100% of files under the chosen data roots parse, or every failure is
  documented as out of scope (binary assets, GUI files).

### Phase 3: generic ingest, cards and full-text search

- `mix game.ingest eu5 --path ~/dev/game-data/eu5` creates a snapshot and fills
  entities, refs, localizations, documents and chunks with tsvector.
- Card renderer with localized names and readable condition blocks.
- `search` (full-text only), `fetch`, `list_entities`, `get_entity`,
  `find_references`.
- Done when counts match the survey and "what does building X do" works from
  Claude and ChatGPT over ngrok with correct source references.

### Phase 4: embeddings and hybrid search

- Bumblebee serving for bge-small in the supervision tree, batch embedding during
  ingest, HNSW index, reciprocal rank fusion in `search`.
- Done when paraphrased questions that miss on full-text hit on hybrid, checked by
  hand on a dozen queries.

### Phase 5: client hardening

- Verify the ChatGPT Developer Mode connector and the Claude connector end to end,
  tune tool descriptions so agents pick the right tool, add result size limits and
  pagination.

### Phase 6: the north-star question

- From the survey, identify the kinds that model governments, reforms, laws, ages
  and country setup, and give them adapter hints so names, descriptions and
  conditions render well.
- Build `GameBuddy.Script.Eval` with the predicates these conditions actually use
  (found by scanning the ASTs, not assumed).
- `compare_availability` tool, with contexts pre-filled from a country's setup
  (`tag: DAN`) and overridable (`government_type`, `age`).
- Done when Claude answers the Denmark question using the tools and the answer is
  verified by hand against the raw files.

### Phase 7: generalization checkpoint

- Write up what in the code is EU5-specific versus generic. Tidy the adapter
  behaviour so a second Paradox game would need only a new adapter module.
- Optional dry run on another Paradox game if one is installed.

## Risks and unknowns

- **File layout** is unknown until the survey. The parser and store do not assume
  it; the adapter does, and the adapter is written after the survey.
- **Localization markup** (`$refs$`, `[functions]`, `#formatting`) needs cleaning
  rules. Start with stripping and reference substitution, measure what is left.
- **Condition rendering quality** drives answer quality for phase 6. Start generic
  (localized key, operator, localized value), then add vocabulary where the
  rendering reads badly.
- **Scale.** Expect tens of thousands of entities and more chunks. Parallel parsing
  and bulk inserts keep ingest to minutes. Embedding on CPU with bge-small should
  be a few hundred chunks per second; measured in phase 4.
- **Parser edge cases.** Elixir-native is the decision. If a family of files resists,
  that family is excluded and documented rather than the parser being replaced.
- **Phoenix assets** are unused for now and kept for a later admin UI.

## Decisions log

- 2026-10-29: Elixir + Phoenix. Postgres in Docker with pgvector. Elixir-native
  parser. Local embeddings via Bumblebee. No auth while testing over ngrok.
  ChatGPT via Developer Mode. Game files only; no wiki or external content.
- 2026-10-29: Parser is hand-written (binary pattern matching) rather than
  NimbleParsec: simpler line tracking, no extra dependency. Dropped the dep.
- 2026-10-29: Kind names are the `common/` subdirectory names verbatim
  (`government_reforms`, `laws`). Setup files use `setup_<wrapper>` kinds.
- 2026-10-29: Ingest shares the localization table through `persistent_term`
  with an ETS memo; capturing the 257k-key map in a closure copied it into every
  worker process and stalled the first run.
- 2026-10-29: `compare_availability` evaluates `government`/`age` fields plus
  `potential`/`allow` triggers; undecidable conditions are reported verbatim.
  `has_tribal_government` is decided from the government type's
  `government_power` (tribal cohesion = tribal; horde unity left undecided).
  International-organization laws (`type = international_organization`) are
  excluded from country comparisons by default.
- 2026-10-29: Embeddings skip geographic, cosmetic and engine-plumbing kinds
  (locations, coats of arms, trigger/effect localization...) and run concepts,
  docs, governments and laws first. bge-small at 256 tokens on CPU: ~40 chunks/s.
- 2026-10-29: After the first client tests: localization text is indexed as
  `text/<file>` documents (40+ char strings, grouped by file); cards carry the
  loc strings that extend the entity key; `[GetXType('key').GetName]`-style
  calls resolve to names; `defines` are ingested. Embeddings are cached by chunk
  text across ingests.
- 2026-10-29: Generalization of the evaluator: the adapter owns the country
  context (`context/2`), the gate spec per kind (`gates/1`: fields, age field,
  trigger blocks, sub-options, default exclusions) and the identity predicate
  list; `Availability`, `Context` and the tools know nothing about EU5.
  `Script.Eval` reports satisfied leaves with their predicate (and marks
  negations), which is what `evaluate_for_country` mode `special` is built on.
- 2026-10-29: Dropped the server-side evaluator (`Availability`, `Context`,
  `Script.Eval`, `compare_availability`, `evaluate_for_country`). Its interface
  was game-shaped (tags, ages, governments) and the client is the intelligence:
  it reads conditions rendered in the game's own words and escalates through
  connections and kind indexes. A copy of the code is in the session attic in
  case a declarative, per-game evaluation layer is wanted later.
- 2026-10-29: Rendering uses the engine's own rules: `trigger_localization`
  and `effect_localization` tables map predicates to tooltip templates,
  modifier type definitions give the value format. Generic for the
  Clausewitz/Jomini family; the adapter only names the kinds that hold them.
- 2026-10-29: Four tools, documents only (`game_lookup`, `game_intro`,
  `search`, `entity`). The intro's core vocabulary is the game's glossary
  ordered by how often its own texts link to each concept.
- 2026-10-29: Engine-level knowledge ("how does combat work") is served from the
  files without any per-game text: `topic/<concept>` documents compile a glossary
  entry with its linked entries, the modifiers that mention it and the engine
  constants named after it; glossary links in descriptions are references;
  `GetDefine` calls render as values; the defines files are indexed as docs so
  the developers' comments on each constant are searchable. What the files do
  not contain (the exact damage formula in the binary) stays unknown and is
  reported as such.
- 2026-10-30: Storage direction. The tools serve documents only; the
  structured tables are build intermediates plus a name index. Documents are
  markdown plus a `sections` JSON (identity, prose, condition/effect blocks as
  rendered lines, properties, connections, script), produced by the same
  renderer. The parsed data stays as a build artifact (version diffs, UI).
  Splitting the pipeline into an offline build step and a serve layer is
  deferred until the second game shows what is really generic.
- 2026-10-30: Interactive UI via MCP Apps. UI is a property of a tool, not a
  per-call choice, so presentation lives in its own tool (`show`) and the text
  tools never carry UI metadata; gating is done by the tool description and
  the intro. Inline keeps to a card or carousel; detail and comparison go to
  fullscreen; connection chips call `show` from inside the frame (no model
  calls). The MCP Apps client is loaded from unpkg under the resource CSP.
  `ui.domain` is not set (only needed for an app with its own OAuth), so the
  ngrok URL can change without reconfiguration.
- 2026-10-30: The view follows the game's own tooltip (dark panel, bronze
  frame, serif, headline numbers, Modifiers box with values right-aligned,
  italic description). Modifier lines in the sections carry `label`, `value`
  and `tone`; the tone comes from the modifier type's `color` field in the
  files (`bad` types are bad when positive, `neutral` has none), not from the
  sign alone. Entity icons are DDS textures and are not served yet.
- 2026-10-30: Landing hero holds the example chats instead of the mascot: a chip per
  catalog game above a stage of fixed height that cycles through separate exchanges
  (`chatDemo` in site.js: question, typing dots, answer, a dwell, then the next one
  crossfades in; chips and dots jump and lock the cycle to that game; paused while
  hovered or off screen; shown whole under reduced motion). The exchanges live in
  `PageHTML.example_chats/1`: the EU5 ones quote our own data (Fortification Licenses,
  the Castle advance, the Serfdom event); games without a snapshot show real player
  questions and an honest "being surveyed" reply, never invented facts. The separate
  demo band is gone.
- 2026-10-30: Public site. `/` (landing) and `/design` (design system: one page, left
  nav with scroll-spy, so find-in-page covers it) are controller views composed from
  `GameBuddyWeb.SiteComponents`. daisyUI is dropped: plain Tailwind v4 on tokens in
  `assets/css/app.css` (violet brand, night panels, coral/lime/sun accents, Plus Jakarta
  Sans self-hosted); the dashboard and core components were ported to the same tokens.
  The mascot and the app icon are inline SVG components. Illustrations are sources in
  `assets/images/site/` converted to WebP by `mix assets.images`; game icons are Steam's
  own client icons (`scripts/steam_art.py`), shown small next to game names. Dark
  sections are full-width bands and the header is transparent over the hero. The site
  is one surface of the platform (MCP today; own chat and in-game overlay are listed as
  planned). Later the same day the product was named Quiv: the site says Quiv, while
  the modules, the repo and the MCP server still say Game Buddy.
- 2026-10-30: Embeddings run through EMLX (Apple MLX) on macOS, EXLA elsewhere;
  the backend and defn compiler are picked in `config.exs` by `:os.type()`. On an
  M3 Pro, bge-small at 256 tokens, batch 64: EXLA CPU 40 chunks/s, EMLX 135-150
  chunks/s on either MLX device. The GPU itself is not the win for a model this
  small (the bare forward takes ~450 ms per batch on both MLX devices, so it is
  dispatch-bound, while a 4096x4096 matmul is 3.5x faster on the GPU); the gain
  is the MLX runtime over XLA CPU. Vectors match EXLA to ~4e-7.
