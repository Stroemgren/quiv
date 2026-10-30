# Site images

Originals for the public site. `mix assets.images` converts everything here to WebP
under `priv/static/images/<same path>` (served at `/images/...`), resized to a sensible
width, and skips files that are already up to date.

- `site/`: illustrations used by the landing page and documented on `/design`.
  Islands have transparent backgrounds; `valley.png` is a wide background.

Game icons do not live here: they are Steam's own client icons, fetched by
`scripts/steam_art.py` straight into `priv/static/images/games/<slug>/icon.png`.
