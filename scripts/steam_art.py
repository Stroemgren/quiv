#!/usr/bin/env python3
"""Fetch Steam's own art for games into priv/static/images/games/<slug>/ for the landing page.

This is not game data and not for the MCP tools: it is the store and library art
Steam shows for an app (client icon, logo, header, capsules, hero). steamcmd prints
the app info of any public app after an anonymous login (no ownership needed); the
art itself is plain files on Steam's CDN, named by the hashes in that app info.

Usage:
  python3 -I scripts/steam_art.py [--out priv/static/images/games] slug=appid ...
  python3 -I scripts/steam_art.py eu5=3450310 eu4=236850 hoi4=394360 civ7=1295660 tww3=1142710

Needs steamcmd on PATH and Python 3 with Pillow (to pick the largest frame of the
.ico and to record image sizes). Writes per game:

  icon.png           largest frame of the Steam client icon (256 px for most apps,
                     smaller when Steam has no larger frame)
  logo.png           library logo, the game's wordmark on transparency, 640x360
  header.jpg         store header, 460x215
  capsule-small.jpg  small store capsule, 231x87
  capsule.jpg        library capsule, 600x900
  hero.jpg           library hero banner, 1920x620

and one steam.json in the output folder with the app id, name, source URL and size
of every file, merged with the games already listed there. Phoenix serves the folder
as is at /images/games/<slug>/<file>; the files are already web formats, so they do
not go through mix assets.images. The site shows icon.png small next to a game's
name (game cards, the connect steps) when it exists.

Known gaps: Steam's client icon for Total War: WARHAMMER III has a single 32 px
frame, so its icon.png is 32x32 (use its logo); Civilization VII's is 184 px.
"""

import argparse
import datetime as dt
import io
import json
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image

COMMUNITY = "https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/apps/{appid}/{name}"
STORE = "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/{appid}/{path}"
STORE_LEGACY = "https://cdn.cloudflare.steamstatic.com/steam/apps/{appid}/{path}"
USER_AGENT = "game-buddy steam_art (landing page assets)"


# --- steamcmd app info (Valve KeyValues text) ---------------------------------

TOKEN = re.compile(r'"((?:[^"\\]|\\.)*)"|(\{)|(\})|//[^\n]*')


def app_info(appids):
    """Run steamcmd anonymously and return {appid: info} for the given ids."""
    cmd = ["steamcmd", "+login", "anonymous", "+app_info_update", "1"]
    for appid in appids:
        cmd += ["+app_info_print", str(appid)]
    cmd.append("+quit")
    out = subprocess.run(cmd, capture_output=True, text=True, errors="replace").stdout
    # Skip steamcmd's own chatter: the first app block starts with a line that is
    # just the quoted app id.
    m = re.search(r'^"\d+"\s*$', out, re.M)
    if not m:
        sys.exit("steamcmd printed no app info; is steamcmd installed and online?\n" + out[-800:])
    return parse_keyvalues(out[m.start():])


def parse_keyvalues(text):
    root, stack, key = {}, [], None
    for m in TOKEN.finditer(text):
        s, open_, close = m.group(1), m.group(2), m.group(3)
        cur = stack[-1] if stack else root
        if open_:
            if key is None:
                raise ValueError("'{' without a key")
            child = {}
            cur[key] = child
            stack.append(child)
            key = None
        elif close:
            if not stack:
                break  # trailing junk after the last block
            stack.pop()
        elif s is not None:
            s = s.replace('\\"', '"').replace("\\\\", "\\")
            if key is None:
                key = s
            else:
                cur[key] = s
                key = None
    return root


# --- choosing the art ------------------------------------------------------------


def localized(block, prefer_2x=False):
    """The path of an image block ({'image': {'english': ...}, 'image2x': ...})."""
    keys = ["image2x", "image"] if prefer_2x else ["image", "image2x"]
    for k in keys:
        img = block.get(k) or {}
        if isinstance(img, dict) and img:
            return img.get("english") or next(iter(img.values()))
    return None


def plan(appid, common):
    """[(file name, [candidate urls], kind)] for one app."""
    full = common.get("library_assets_full") or {}
    items = []

    if common.get("clienticon"):
        items.append(("icon.png", [COMMUNITY.format(appid=appid, name=common["clienticon"] + ".ico")], "ico"))
    elif common.get("icon"):
        items.append(("icon.png", [COMMUNITY.format(appid=appid, name=common["icon"] + ".jpg")], "image"))

    def store(path, legacy):
        urls = []
        if path:
            urls.append(STORE.format(appid=appid, path=path))
        urls.append(STORE_LEGACY.format(appid=appid, path=legacy))
        return urls

    logo = localized(full.get("library_logo") or {})
    items.append(("logo.png", store(logo, "logo.png"), "image"))
    header = (common.get("header_image") or {}).get("english")
    items.append(("header.jpg", store(header, "header.jpg"), "image"))
    small = (common.get("small_capsule") or {}).get("english")
    items.append(("capsule-small.jpg", store(small, "capsule_231x87.jpg"), "image"))
    capsule = localized(full.get("library_capsule") or {}, prefer_2x=True)
    items.append(("capsule.jpg", store(capsule, "library_600x900.jpg"), "image"))
    hero = localized(full.get("library_hero") or {})
    items.append(("hero.jpg", store(hero, "library_hero.jpg"), "image"))
    return items


# --- fetching ------------------------------------------------------------------------


def fetch(urls):
    last = None
    for url in urls:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return url, r.read()
        except urllib.error.HTTPError as e:
            last = f"{url}: HTTP {e.code}"
        except urllib.error.URLError as e:
            last = f"{url}: {e.reason}"
    return None, last


def largest_ico_frame(data):
    im = Image.open(io.BytesIO(data))
    size = max(im.ico.sizes(), key=lambda s: s[0] * s[1])
    return im.ico.getimage(size).convert("RGBA")


def write(path, data, kind):
    """Write the file; returns (bytes written, 'WxH')."""
    if kind == "ico":
        frame = largest_ico_frame(data)
        buf = io.BytesIO()
        frame.save(buf, format="PNG", optimize=True)
        data, size = buf.getvalue(), frame.size
    else:
        size = Image.open(io.BytesIO(data)).size
    path.write_bytes(data)
    return len(data), "%dx%d" % size


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("games", nargs="+", metavar="slug=appid")
    ap.add_argument("--out", default="priv/static/images/games", help="output folder (default priv/static/images/games)")
    args = ap.parse_args()

    games = []
    for g in args.games:
        slug, _, appid = g.partition("=")
        if not slug or not appid.isdigit():
            ap.error(f"expected slug=appid, got {g!r}")
        games.append((slug, int(appid)))

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    index_path = out / "steam.json"
    index = json.loads(index_path.read_text()) if index_path.exists() else {}

    print("asking steamcmd for app info of", ", ".join(str(a) for _, a in games), "...", flush=True)
    infos = app_info([a for _, a in games])
    today = dt.date.today().isoformat()
    failures = 0

    for slug, appid in games:
        common = (infos.get(str(appid)) or {}).get("common") or {}
        if not common:
            print(f"{slug}: steamcmd returned no 'common' block for app {appid}", file=sys.stderr)
            failures += 1
            continue
        folder = out / slug
        folder.mkdir(exist_ok=True)
        entry = {"appid": appid, "name": common.get("name"), "fetched": today, "files": {}}
        print(f"{slug}: {common.get('name')} (app {appid})")
        for name, urls, kind in plan(appid, common):
            url, data = fetch(urls)
            if url is None:
                print(f"  {name:18} missing ({data})", file=sys.stderr)
                failures += 1
                continue
            nbytes, size = write(folder / name, data, kind)
            entry["files"][name] = {"source": url, "bytes": nbytes, "size": size}
            print(f"  {name:18} {size:>10} {nbytes:>8} B")
        index[slug] = entry

    index_path.write_text(json.dumps(dict(sorted(index.items())), indent=2) + "\n")
    print("wrote", index_path)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
