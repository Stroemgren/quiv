#!/usr/bin/env python3
"""Convert game textures (DDS and anything Pillow reads) to WebP for the interactive view.

usage: convert_textures.py MANIFEST.json

MANIFEST is a JSON list of items:
  {"path": "<relative path, echoed back>", "src": "<absolute source>", "out": "<absolute .webp>",
   "max": 96 | null, "lossless": bool, "tint": "<absolute color texture>" | null,
   "alpha": 0.5 | null, "sample": bool}
A "sample" item only reports the texture's average color. Prints a JSON list with, per item,
{"path", "out", "width", "height"}, {"path", "hex"} or {"path", "error"}.
"""
import json
import os
import sys
from multiprocessing import Pool

from PIL import Image


def average(path):
    im = Image.open(path).convert("RGBA")
    return im.resize((1, 1), Image.BOX).getpixel((0, 0))


def convert(item):
    im = Image.open(item["src"])
    im.load()
    im = im.convert("RGBA")
    if item.get("tint"):
        # the engine's modify_texture: the color texture replaces the color, the alpha stays
        t = average(item["tint"])
        a = im.getchannel("A")
        im = Image.new("RGBA", im.size, (t[0], t[1], t[2], 255))
        im.putalpha(a)
    if item.get("alpha") is not None:
        f = float(item["alpha"])
        r, g, b, a = im.split()
        im = Image.merge("RGBA", (r, g, b, a.point(lambda v: int(v * f))))
    mx = item.get("max")
    if mx and max(im.size) > mx:
        im.thumbnail((mx, mx), Image.LANCZOS)
    # method 4: a few percent larger than the slowest setting, several times faster over thousands of icons
    im.save(item["out"], "WEBP", lossless=bool(item.get("lossless")), quality=80, method=4)
    return {"path": item["path"], "out": item["out"], "width": im.width, "height": im.height}


def process(item):
    try:
        if item.get("sample"):
            px = average(item["src"])
            return {"path": item["path"], "hex": "#%02x%02x%02x" % px[:3]}
        return convert(item)
    except Exception as e:  # report per item, keep going
        return {"path": item["path"], "error": "%s: %s" % (type(e).__name__, e)}


def main():
    with open(sys.argv[1]) as f:
        manifest = json.load(f)
    with Pool(os.cpu_count() or 2) as pool:
        out = list(pool.imap(process, manifest, chunksize=16))
    json.dump(out, sys.stdout)


if __name__ == "__main__":
    main()
