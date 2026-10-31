# Game Buddy

See `README.md` for how to run things, `docs/PLAN.md` for the plan and decisions,
`docs/eu5-survey.md` for what the EU5 files look like, `docs/community-questions.md` for real
player questions (quoted, dated, with URLs) to use as examples and client tests. Phoenix
conventions: `AGENTS.md`.

Rules of the project:
- Only the game's own files are sources of truth. Never pull facts from wikis or guides
  into the data or the code. Survey the files instead.
- Game files live outside the repo (`~/dev/game-data/<game>`), are untrusted input and
  read-only.
- Generic first: parser, ingest, rendering, search and the four MCP tools know nothing
  about EU5 and carry no game vocabulary. Game specifics (file layout, loc key patterns,
  which kinds hold the trigger/effect/modifier rendering tables, aliases, intro notes) go
  in `GameBuddy.Adapters.<Game>` as declarations. The scaling unit is the engine family.
- Clients get documents, not structures: one document per entity (conditions and
  effects in the game's own tooltip language, connections with keys), stored as markdown
  plus the structured `sections` it was printed from; indexes per kind, localization text
  by file, the intro. The client does the reasoning by escalating through keys; the
  server never evaluates game rules.
- UI is MCP Apps and lives in one presentation tool, `game_show` (returns no new facts). Never
  attach UI metadata to the text tools. The page in `priv/mcp_apps/` renders the generic
  sections and knows no game: its look (icons, frame texture, fonts, colors) comes from
  the game's own files through the adapter's declarations (`icon_paths/3`, `theme/0`) and
  `mix game.assets`; never bake a game's art or palette into the page.
- Lessons from client tests live in `docs/PLAN.md` (Status). Tool descriptions and the intro
  document are the main lever on how clients use the tools; keep them current. Descriptions
  are computed at request time and open by naming the catalog's games from the catalog, because
  clients that load schemas lazily judge a tool by its first sentence. The catalog always
  lists several games (placeholders without data return empty content, not errors), so no
  tool text may read as single-game.
- Postgres: Docker container `game_dev`, port 5012, `game`/`game`, database `game_dev`.
- No auth on the MCP endpoint while prototyping (exposed via ngrok by the user).
