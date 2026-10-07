#!/usr/bin/env python3
"""Cuts a generated icon sheet into a clean atlas for Roblox.

The sheets come from an image model: 16 icons in a rough 4 x 4 grid on a flat background, no alpha channel.
This removes the background (flood fill from the border, so background-coloured areas inside an icon stay),
finds each icon, and packs them into a 1024 x 1024 PNG with a 4 x 4 grid of 256 px cells, each icon centred
in the middle 216 px of its cell. Transparent pixels carry the outline colour, so edges do not fringe when
Roblox scales the image.

Usage: icon_atlas.py sheet.png atlas.png [preview.png] [tolerance]
"""
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

GRID = 4
CELL = 256
INNER = 216
INK = (43, 18, 64)
TOLERANCE = 34  # how far from the background colour a pixel may be and still count as background
# A sheet that came back with a darker tile behind each icon (sheet D did) needs more: `icon_atlas.py sheet atlas
# preview 65` takes the tiles off as background, and the icons' white sticker edge stops the fill.
if len(sys.argv) > 4:
    TOLERANCE = int(sys.argv[4])


def background_mask(image: Image.Image) -> np.ndarray:
    """True where a pixel is background reachable from the border."""
    rgb = np.asarray(image.convert("RGB")).astype(np.int32)
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    colour = np.median(border, axis=0)
    close = np.sqrt(((rgb - colour) ** 2).sum(axis=2)) < TOLERANCE
    # Flood fill over the "close" pixels, starting from every border pixel that is one.
    canvas = Image.fromarray(np.where(close, 0, 255).astype(np.uint8)).copy()  # fromarray alone is read-only
    height, width = close.shape
    step = max(1, width // 64)
    seeds = [(x, 0) for x in range(0, width, step)] + [(x, height - 1) for x in range(0, width, step)]
    seeds += [(0, y) for y in range(0, height, step)] + [(width - 1, y) for y in range(0, height, step)]
    for seed in seeds:
        if canvas.getpixel(seed) == 0:
            ImageDraw.floodfill(canvas, seed, 128)
    return np.asarray(canvas) == 128


def bands(profile: np.ndarray, count: int) -> list:
    """Splits a projection profile into `count` runs of foreground, merging the closest runs if there are more."""
    runs, start = [], None
    for index, filled in enumerate(profile):
        if filled and start is None:
            start = index
        elif not filled and start is not None:
            runs.append([start, index])
            start = None
    if start is not None:
        runs.append([start, len(profile)])
    runs = [run for run in runs if run[1] - run[0] > 8]  # specks are not icons
    while len(runs) > count:
        gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
        nearest = gaps.index(min(gaps))
        runs[nearest][1] = runs[nearest + 1][1]
        del runs[nearest + 1]
    if len(runs) != count:
        raise SystemExit(f"expected {count} rows/columns of icons, found {len(runs)}")
    return runs


def main() -> None:
    source = Image.open(sys.argv[1]).convert("RGB")
    outside = background_mask(source)
    inside = ~outside

    # Alpha: the icon, pulled in by a pixel and feathered, so the background's colour never shows at the rim.
    alpha = Image.fromarray((inside * 255).astype(np.uint8))
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    rgb = np.asarray(source).copy()
    rgb[outside] = INK
    cut = Image.fromarray(rgb)
    cut.putalpha(alpha)

    solid = np.asarray(alpha) > 40
    atlas = Image.new("RGBA", (CELL * GRID, CELL * GRID), INK + (0,))
    rows = bands(solid.sum(axis=1) > 6, GRID)
    for row_index, (top, bottom) in enumerate(rows):
        strip = solid[top:bottom]
        columns = bands(strip.sum(axis=0) > 3, GRID)
        for column_index, (left, right) in enumerate(columns):
            block = strip[:, left:right]
            filled = np.where(block.sum(axis=1) > 0)[0]
            box = (left - 2, top + filled[0] - 2, right + 2, top + filled[-1] + 3)
            icon = cut.crop(box)
            scale = INNER / max(icon.size)
            icon = icon.resize((round(icon.width * scale), round(icon.height * scale)), Image.LANCZOS)
            x = column_index * CELL + (CELL - icon.width) // 2
            y = row_index * CELL + (CELL - icon.height) // 2
            atlas.paste(icon, (x, y))
    atlas.save(sys.argv[2])

    if len(sys.argv) > 3:
        # What it looks like in the game: on the HUD's plum and on cream.
        preview = Image.new("RGB", atlas.size, (58, 31, 85))
        ImageDraw.Draw(preview).rectangle([0, CELL * 2, atlas.width, atlas.height], fill=(255, 243, 214))
        preview.paste(atlas, (0, 0), atlas)
        preview.save(sys.argv[3], quality=90)


if __name__ == "__main__":
    main()
