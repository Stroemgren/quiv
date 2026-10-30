#!/usr/bin/env python3
"""Convert the site's source images (assets/images) to WebP under priv/static/images.

Usage: python3 priv/scripts/site_images.py [assets/images] [priv/static/images]

Each PNG/JPG is written next to its relative path with a .webp extension, resized so
that its width does not exceed the limit for its folder (site: 1600), and
skipped when the output is newer than the source. Needs Pillow.
"""
import sys
from pathlib import Path

from PIL import Image

MAX_WIDTH = {"site": 1600}
DEFAULT_WIDTH = 1200
QUALITY = 84


def convert(src: Path, dst: Path, max_width: int) -> str:
    if dst.exists() and dst.stat().st_mtime >= src.stat().st_mtime:
        return "up to date"
    with Image.open(src) as im:
        # Illustrations with transparency are shown small; backgrounds stay wide.
        if "A" in im.getbands():
            max_width = min(max_width, 900)
        if im.width > max_width:
            ratio = max_width / im.width
            im = im.resize((max_width, round(im.height * ratio)), Image.LANCZOS)
        mode = "RGBA" if im.mode in ("RGBA", "LA", "P") and "A" in im.getbands() else "RGB"
        im = im.convert(mode)
        dst.parent.mkdir(parents=True, exist_ok=True)
        im.save(dst, "WEBP", quality=QUALITY, method=6)
    return f"{dst.stat().st_size // 1024} KB"


def main() -> None:
    src_root = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/images")
    dst_root = Path(sys.argv[2] if len(sys.argv) > 2 else "priv/static/images")
    sources = sorted(p for p in src_root.rglob("*") if p.suffix.lower() in (".png", ".jpg", ".jpeg"))
    if not sources:
        print(f"no images under {src_root}")
        return
    for src in sources:
        rel = src.relative_to(src_root)
        folder = rel.parts[0] if len(rel.parts) > 1 else ""
        dst = (dst_root / rel).with_suffix(".webp")
        print(f"{rel} -> {dst.relative_to(dst_root)}: {convert(src, dst, MAX_WIDTH.get(folder, DEFAULT_WIDTH))}")


if __name__ == "__main__":
    main()
