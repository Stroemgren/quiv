# Game Buddy

An MCP server that turns an AI assistant into a game buddy. Every fact it serves is
extracted directly from a game's own files: no wikis, no guides. First game:
Europa Universalis V.

- Plan: `docs/PLAN.md` · EU5 file survey: `docs/eu5-survey.md`
- Stack: Elixir 1.19 / Phoenix 1.8, Postgres 17 + pgvector, anubis_mcp (Streamable HTTP),
  Bumblebee for local embeddings (EMLX on the Metal GPU on macOS, EXLA elsewhere).

## Running

Postgres runs in Docker (`pgvector/pgvector:pg17`, port 5012, user/pass `game`/`game`,
database `game_dev`). Game files live outside the repo at `~/dev/game-data/eu5`.

```sh
scripts/steam_download.sh <steam_user>          # download / update EU5 (Windows depots)
mix setup                                         # deps, db, migrations
mix pdx.check ~/dev/game-data/eu5/game/in_game/common   # parse report, no db needed
mix game.ingest eu5 --path ~/dev/game-data/eu5    # new snapshot, ~75 s
mix game.embed                                    # embeddings for the default snapshot (long, resumable)
mix game.assets                                   # icons and theme textures for the view (needs python3 + Pillow)
mix assets.images                                 # site illustrations to WebP (python3 + Pillow)
python3 -I scripts/steam_art.py eu5=3450310 ...  # Steam store art per game into priv/static/images/games/<slug>/ (see the script)
mix phx.server                                    # MCP at http://localhost:4000/mcp
GAMEBUDDY_EMBEDDINGS=0 mix phx.server             # same, without loading the embedding model
ngrok http 4000                                   # then add https://<id>.ngrok-free.app/mcp as a connector
```

`mix pdx.parse FILE [--fold|--loc]` prints one file as JSON.

## Public site

`/` is the landing page and `/design` the design system (one page, left nav, so
find-in-page covers it). Both are plain controller views: `PageController`, templates in
`lib/game_buddy_web/controllers/page_html/`. The look is plain Tailwind v4 (no component
library) on the tokens declared in `assets/css/app.css`; the components (buttons, pills,
fields, cards, the mascot) are function components in `GameBuddyWeb.SiteComponents`, the
header and footer in `Layouts.site`, and the little behaviour the pages need (the hero's
example chats, scroll-spy, menu toggle, copy buttons) in `assets/js/site.js`. Plus Jakarta Sans is self-hosted in
`priv/static/fonts`.

The product's public name is Quiv; the modules, the repo and the MCP server still say
Game Buddy.

Illustrations: drop sources in `assets/images/site/`, then `mix assets.images` (python3 +
Pillow) writes the WebP files the site serves under `priv/static/images/site/`. Game
icons are Steam's own client icons, fetched per game by `scripts/steam_art.py` into
`priv/static/images/games/<slug>/`; the site shows `icon.png` next to a game's name
when it exists and draws its own tile otherwise.

Tool-call inspector: `http://localhost:4000/dashboard` shows every MCP call with its
complete arguments and result, client, session and timing, updating live, plus one
`initialize` row per client handshake (client name and version, protocol). Calls are
stored in the `tool_calls` table (recorded from anubis telemetry, see
`GameBuddy.ToolCalls.Telemetry`).

## MCP tools

Four tools plus one presentation tool, all named `game_*` so that a host which
lists tool names before loading their schemas can tell what they are for.
`game_search` is the first call and needs no setup; `game` and `version` are optional
and default to the default game's latest snapshot. Nothing in the tools' code is
specific to a game: the descriptions name the catalog's games with their aliases at
request time, the server's title and `instructions` name them with the snapshot's
build and ingest date at connect, and the intro document tells the client what the
game calls things.

The catalog lists every adapter's game, with or without data (registered at start
by `Catalog.ensure_games/0`). Hearts of Iron IV and Civilization VII are placeholder
adapters with no files surveyed yet: the tools return empty content for them (a
search with 0 results, "no document has the key"), never an error, so that client
tests cover the multi-game case the way production will.

| Tool | Returns |
|---|---|
| `game_lookup(query?)` | Games and versions matching a free-form name, with DLCs and the default version |
| `game_intro(game?, version?)` | Markdown intro: how to use the data, the game's own core vocabulary (its glossary, most-referenced first), kinds with counts, per-game notes |
| `game_search(query, limit?, game?, version?)` | One compiled markdown document: the best matches across entities, localization text and shipped docs, each with its key and matched passage |
| `game_entity(key, game?, version?)` | The full document for a key: description, attached text, conditions and effects in the game's own tooltip language, properties, connections (with keys), source, script |
| `game_show(keys, game?, version?)` | An interactive view of up to 12 entities (MCP App): a card for one, a comparison for several. Presentation only; text-only clients get a one-line summary |

Keys are `kind/key`. `index/<kind>` lists every entity of a kind; `text/<file>`
holds the localization strings of a file; `docs/<file>` a shipped doc;
`intro/game` the intro.

### The interactive view (MCP App)

`game_show` is an [MCP App](https://claude.com/docs/connectors/building/mcp-apps/getting-started):
the tool carries `_meta.ui.resourceUri = ui://game-buddy/entities`, and the
resource (`GameBuddy.MCP.Resources.EntityView`) serves `priv/mcp_apps/entities.html`
with MIME type `text/html;profile=mcp-app`. The host renders the page in a sandboxed
frame and hands it the tool's `structuredContent`: the entities' `sections` (the same
parts the markdown is printed from), so the page is generic and knows no game.
Inline it shows a card (one key) or a carousel (several); its fullscreen mode shows
the full document or a comparison table, and connection chips open other entities
through the same tool without involving the model. The look follows the game's own
tooltips; modifier values are colored good/bad from the modifier type's `color` field
in the files.

The view uses the game's own art. At ingest the adapter names candidate textures
for each entity (`icon_paths/3`: the folder convention per kind, the game's
`_default.dds` last) and the first file that exists is kept on the document's
`sections` as `icon`; modifier rows carry their modifier type's icon the same way.
`mix game.assets` converts those textures and the adapter's theme (`theme/0`: font
families, text colors looked up in the game's text formatting file, color roles
sampled from its flat color textures, the tooltip frame texture with its 9-slice
border, tinted the way the GUI tints it) to WebP through
`priv/scripts/convert_textures.py` (Python 3 with Pillow, which decodes DDS) into
the `assets` table. `game_show` attaches them as data URIs within a byte budget (theme
first, then entity icons, then modifier icons) and the page applies the theme: the
frame texture as a 9-slice border, the panel colors and top glow of the game's
tooltip template, its font families from Google Fonts (allowed in the resource's
CSP), icons in the title tile and before modifier labels. Without assets the page
keeps its built-in look.

UI is bound to the tool, not chosen per call, which is why `game_show` is separate from
`game_entity`: the model decides by picking the tool, guided by the descriptions and the
intro. Claude.ai on the web and Claude Desktop render it (custom connectors included);
mobile renders it in a WebView; Claude Code and other text clients just get the
summary line. The page loads the MCP Apps client from unpkg (allowed in the resource's
CSP); everything else is inline. No `ui.domain` is set, as that is only needed for an
app with its own OAuth flow, so nothing changes when the ngrok URL changes. To debug a
view that does not appear, Claude Desktop's developer tools show the app's iframe
(Help → Troubleshooting → Enable Developer Mode).

## Layout

```
lib/game_buddy/pdx/          lexer, parser, fold, localization parser, script printer (game-agnostic)
lib/game_buddy/adapter.ex    per-game behaviour; adapters/eu5.ex is the only implementation
lib/game_buddy/ingest.ex     files → snapshot (entities, refs, localizations, documents, chunks)
lib/game_buddy/loc.ex        localization table + markup cleaning (concept links, $refs$, Get*('key') calls)
lib/game_buddy/render/       script.ex: conditions/effects/modifiers from the game's own templates;
                             document.ex: one document per entity; pages.ex: indexes, intro, search result
lib/game_buddy/knowledge.ex  queries: hybrid search, documents by key, name resolution
lib/game_buddy/assets.ex     textures → assets table (icons, theme) via priv/scripts/convert_textures.py
lib/game_buddy/mcp/          anubis server and the four tool components
```

## Data model

`games` → `game_versions` (one per ingest snapshot) → `entities` (kind, key, name,
description, folded `data`, exact `ast`, source file and line, rendered `card`,
tsvector), `entity_refs`, `localizations`, `documents` (markdown `body` plus, for entity
documents, the structured `sections` it was printed from) → `chunks` (tsvector + 384-dim
vector); `assets` (converted textures and the theme, per snapshot).

## What is indexed

One document per scripted entity (kind = the `common/` directory name), rendered
like a reference page: description, the localization strings that extend the
key (tooltips, mechanic text), conditions and effects written with the game's
own `trigger_localization` / `effect_localization` templates and modifier
formats ("Belongs to the Russian culture group", "Discipline +5%"), remaining
properties, connections (what the entity references and what references it,
with keys), the script, and as the last line the source location, labelled as
internal so that clients do not quote file names to the player. Plus:

- `index/<kind>`: every entity of a kind on one line (name, key, main facets), in parts of 400.
- `topic/<concept>`: how a glossary concept works, compiled from the game's own glossary
  graph (the entry, the entries it links to, the modifiers whose descriptions mention it,
  the engine constants named after it). Glossary links inside any description are also
  references, so concept documents connect to each other.
- `text/<file>`: every localization string of 40+ characters, grouped by file.
- `docs/<file>`: readme and `.info` files shipped with the game, and the defines files
  with the developers' inline comments on each constant. `[GetDefine(...)]` calls in text
  render as the constant's value.
- `intro/game`: the intro served by `game_intro`.

Embeddings are cached by chunk text (`embedding_cache`), so a re-ingest only
embeds chunks whose text changed; run `mix game.embed` after `mix game.ingest`.
