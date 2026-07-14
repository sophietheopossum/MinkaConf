#!/usr/bin/env python3
"""Render every installed XCursor to a PNG preview cache for MinkaConf.

Scans the XCursor search path for themes (any icon directory with a
cursors/ subdir), decodes each real cursor file (symlinked aliases are
skipped, which is also what dedupes the grid), and writes straight-alpha
PNGs to ~/.cache/minkaconf/cursor-previews/<theme>/<cursor>.png. Cached
files are only rewritten when the source is newer.

Output protocol (consumed by CursorPage.qml), one line per cursor:
    theme<TAB>cursor-name<TAB>/absolute/path/to.png
Lines are grouped by theme, themes and cursors both sorted.
"""

import os
import struct
import sys

from PIL import Image

XCURSOR_MAGIC = b"Xcur"
XCURSOR_IMAGE_TYPE = 0xFFFD0002
# Preferred nominal size: previews compare shapes, not fidelity, and 32 is
# present in practically every theme.
WANT_NOMINAL = 32

SEARCH_DIRS = [
    os.path.expanduser("~/.icons"),
    os.path.expanduser("~/.local/share/icons"),
    "/usr/local/share/icons",
    "/usr/share/icons",
]

CACHE_ROOT = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
    "minkaconf",
    "cursor-previews",
)


def decode_first_frame(path):
    """Return an RGBA PIL image of the cursor's frame-0 at the nominal size
    closest to WANT_NOMINAL, or None if the file isn't a valid Xcursor."""
    with open(path, "rb") as handle:
        data = handle.read()
    if data[:4] != XCURSOR_MAGIC or len(data) < 16:
        return None
    (ntoc,) = struct.unpack_from("<I", data, 12)
    best = None  # (distance, toc-order, position)
    for i in range(ntoc):
        try:
            type_, subtype, position = struct.unpack_from("<III", data, 16 + i * 12)
        except struct.error:
            return None
        if type_ != XCURSOR_IMAGE_TYPE:
            continue
        distance = abs(subtype - WANT_NOMINAL)
        # Strict < keeps the FIRST chunk at the winning size: frames of an
        # animated cursor appear in TOC order, so this is frame 0.
        if best is None or distance < best[0]:
            best = (distance, i, position)
    if best is None:
        return None
    position = best[2]
    try:
        width, height = struct.unpack_from("<II", data, position + 16)
    except struct.error:
        return None
    if width == 0 or height == 0 or width > 1024 or height > 1024:
        return None
    pixels = data[position + 36 : position + 36 + width * height * 4]
    if len(pixels) < width * height * 4:
        return None
    image = Image.frombuffer("RGBA", (width, height), pixels, "raw", "BGRA", 0, 1)
    # Xcursor stores premultiplied alpha; PNG wants straight alpha.
    loaded = image.load()
    for y in range(height):
        for x in range(width):
            r, g, b, a = loaded[x, y]
            if 0 < a < 255:
                loaded[x, y] = (
                    min(255, r * 255 // a),
                    min(255, g * 255 // a),
                    min(255, b * 255 // a),
                    a,
                )
    return image


def discover_themes():
    """{theme-name: cursors-dir}, first hit along the search path wins."""
    themes = {}
    for base in SEARCH_DIRS:
        if not os.path.isdir(base):
            continue
        for entry in sorted(os.listdir(base)):
            cursors_dir = os.path.join(base, entry, "cursors")
            if entry not in themes and os.path.isdir(cursors_dir):
                themes[entry] = cursors_dir
    return themes


def main():
    for theme, cursors_dir in sorted(discover_themes().items()):
        out_dir = os.path.join(CACHE_ROOT, theme)
        os.makedirs(out_dir, exist_ok=True)
        for name in sorted(os.listdir(cursors_dir)):
            source = os.path.join(cursors_dir, name)
            # Symlinks are aliases of another cursor in the same theme —
            # skipping them is the dedupe.
            if os.path.islink(source) or not os.path.isfile(source):
                continue
            target = os.path.join(out_dir, name + ".png")
            try:
                if (
                    not os.path.exists(target)
                    or os.path.getmtime(target) < os.path.getmtime(source)
                ):
                    image = decode_first_frame(source)
                    if image is None:
                        continue
                    image.save(target)
                print(f"{theme}\t{name}\t{target}", flush=False)
            except OSError as error:
                print(f"xcursor-previews: {source}: {error}", file=sys.stderr)
    sys.stdout.flush()


if __name__ == "__main__":
    main()