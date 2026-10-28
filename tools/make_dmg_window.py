#!/usr/bin/env python3
"""Write the Finder window layout (.DS_Store) for the AirCard DMG.

Why this exists
---------------
`create-dmg` lays out the window by driving Finder through AppleScript, which
requires the "Automation" permission (-1743 "Not authorized to send Apple events
to Finder" without it). On a machine that has not granted it, the whole build
dies after the artwork has already been copied.

This script writes the same layout straight into `.DS_Store`: window bounds,
icon view options, the background picture bookmark, and per-icon positions.
No AppleScript, no Finder, no permission prompt.

Usage:
    make_dmg_window.py <mount-point> [--background <path-inside-volume>]

Requires: ds_store, mac_alias  (both vendored under tools/pylib, or installed).
"""

import argparse
import os
import plistlib
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "pylib"))

from mac_alias import Bookmark  # noqa: E402
from ds_store.store import (  # noqa: E402
    BookmarkCodec,
    DSStore,
    DSStoreEntry,
    ILocCodec,
    PlistCodec,
)

# Geometry mirrors what build.sh passes to create-dmg, so both paths produce an
# identical looking window.
WINDOW_X, WINDOW_Y = 200, 120
WINDOW_W, WINDOW_H = 700, 488          # includes the 28 pt title bar
ICON_SIZE = 110.0

# Icon centres, in points, inside the window's content area (700x460).
# README stays at y=332: any lower and its cell overruns the content area,
# which makes Finder show a phantom scrollbar.
ICON_POSITIONS = {
    "AirCard.app": (175, 220),
    "Applications": (525, 220),
    "README.txt": (350, 332),
}

BACKGROUND_REL = ".background/background_700.png"


def build_entries(mount_point, background_rel):
    background_path = os.path.join(mount_point, background_rel)
    if not os.path.exists(background_path):
        raise SystemExit("background artwork missing: %s" % background_path)

    window_bounds = "{{%d, %d}, {%d, %d}}" % (WINDOW_X, WINDOW_Y, WINDOW_W, WINDOW_H)

    bwsp = {
        "ContainerShowSidebar": False,
        "PreviewPaneVisibility": False,
        "ShowPathbar": False,
        "ShowSidebar": False,
        "ShowStatusBar": False,
        "ShowTabView": False,
        "ShowToolbar": False,
        "SidebarWidth": 0.0,
        "WindowBounds": window_bounds,
    }

    icvp = {
        "arrangeBy": "none",
        "backgroundColorBlue": 1.0,
        "backgroundColorGreen": 1.0,
        "backgroundColorRed": 1.0,
        "backgroundType": 2,          # 2 = picture
        "gridOffsetX": 0.0,
        "gridOffsetY": 0.0,
        "gridSpacing": 100.0,
        "iconSize": ICON_SIZE,
        "labelOnBottom": True,
        "showIconPreview": True,
        "showItemInfo": False,
        "scrollPositionX": 0.0,
        "scrollPositionY": 0.0,
        "textSize": 12.0,
        "viewOptionsVersion": 1,
    }

    entries = [
        DSStoreEntry(".", "bwsp", PlistCodec, bwsp),
        DSStoreEntry(".", "icvp", PlistCodec, icvp),
        DSStoreEntry(".", "vSrn", "long", 1),
        DSStoreEntry(".", "pBBk", BookmarkCodec, Bookmark.for_file(background_path)),
    ]

    for name, (x, y) in ICON_POSITIONS.items():
        if not os.path.exists(os.path.join(mount_point, name)):
            print("    warning: skipping missing item %r" % name)
            continue
        entries.append(DSStoreEntry(name, "Iloc", ILocCodec, (x, y)))

    return entries


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mount_point")
    ap.add_argument("--background", default=BACKGROUND_REL)
    args = ap.parse_args()

    mount_point = args.mount_point.rstrip("/")
    if not os.path.isdir(mount_point):
        raise SystemExit("not a directory: %s" % mount_point)

    entries = build_entries(mount_point, args.background)

    ds_path = os.path.join(mount_point, ".DS_Store")
    if os.path.exists(ds_path):
        os.remove(ds_path)

    # "w+" not "w": the buddy allocator needs to read back what it wrote.
    store = DSStore.open(ds_path, "w+")
    try:
        for entry in entries:
            store.insert(entry)
    finally:
        store.close()

    print("    wrote %s (%d entries)" % (ds_path, len(entries)))


if __name__ == "__main__":
    main()
