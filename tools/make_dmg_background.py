#!/usr/bin/env python3
"""Generate the DMG window background for AirCard.

Why this exists
---------------
Finder draws the icon labels ("AirCard", "Applications", "README.txt") itself,
in near-black text, and there is NO supported way to recolor them (the legacy
`.DS_Store` `icvl` record is ignored on modern macOS — verified by setting it to
pure red and watching the labels stay black). A dark background therefore makes
the labels unreadable, so the background must be LIGHT.

This script rebuilds the background in a light theme while keeping the exact
geometry of the original dark artwork, so icon positions in build.sh do not
need to change:

    window          700 x 488 pt   (create-dmg --window-size 700 488)
                    the 28 pt title bar leaves a 700 x 460 pt content area
    artwork         1400 x 920 px  (2x of the 700 x 460 pt content area)
    icon "AirCard"  175 220 pt     -> 350 440 px
    "Applications"  525 220 pt     -> 1050 440 px
    "README.txt"    350 332 pt     -> 700 664 px

Rendered point size is kept a hair BELOW the window size on purpose: an image
that renders even 0.03pt larger than the content area makes Finder show a
phantom scrollbar. The window height therefore includes the title bar.

Usage:
    python3 tools/make_dmg_background.py [output.png]
"""

import sys

from PIL import Image, ImageDraw, ImageFont

# --- canvas -----------------------------------------------------------------
SCALE = 2
WINDOW_W_PT, WINDOW_H_PT = 700, 460  # content area; +28pt title bar = 700x488 window
W, H = WINDOW_W_PT * SCALE, WINDOW_H_PT * SCALE  # 1400 x 920

# Render 1400px as 699.7pt instead of 700pt (see "phantom scrollbar" above).
TARGET_DPI = 1400 * 72 / 699.7  # ~144.06

# --- palette (light theme) --------------------------------------------------
BG_TOP = (252, 251, 255)
BG_BOTTOM = (240, 235, 250)
GLOW_RGB = (124, 92, 224)
GLOW_ALPHA = 12          # 0-255, deliberately faint
GLOW_RADIUS = 195
GLOW_SLOTS = [(350, 440), (1050, 440)]  # px centres of the two app slots

TITLE_TEXT = "AirCard"
TITLE_SIZE = 72
TITLE_COLOR = (23, 18, 43)
TITLE_CENTER = (697, 125)        # bbox centre of the original artwork

PILL_TEXT = "Universal \u00b7 Apple Silicon & Intel"
PILL_TEXT_SIZE = 30
PILL_TEXT_COLOR = (91, 63, 209)
PILL_FILL = (241, 235, 254)
PILL_BORDER = (215, 200, 250)
PILL_BORDER_W = 2
PILL_PAD_X = 48
PILL_H = 50
PILL_CENTER = (700, 216)

HINT_TEXT = "Drag AirCard to Applications to install"
HINT_SIZE = 28
HINT_COLOR = (107, 100, 128)
HINT_CENTER = (700, 278)

ARROW_COLOR = (124, 92, 224)
ARROW_X0, ARROW_X1 = 530, 830          # shaft
ARROW_Y = 487                          # shaft centre
ARROW_SHAFT_W = 8
ARROW_HEAD_LEN = 61
ARROW_HEAD_HALF = 22
ARROW_CENTER = (710, 487)              # matches the original artwork


def load_font(size, weight):
    """Prefer real SF Pro (variable), fall back to Helvetica Neue."""
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
        font.set_variation_by_name(weight)
        return font
    except Exception:
        index = {"Regular": 0, "Medium": 10, "Semibold": 10, "Bold": 1}[weight]
        return ImageFont.truetype(
            "/System/Library/Fonts/HelveticaNeue.ttc", size, index=index
        )


def vertical_gradient(top, bottom):
    grad = Image.new("RGB", (1, H))
    px = grad.load()
    for y in range(H):
        t = y / (H - 1)
        px[0, y] = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return grad.resize((W, H), Image.BILINEAR)


def radial_glow(size, centre, radius, rgb, alpha):
    """One soft purple bloom, drawn with concentric alpha rings."""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    steps = 60
    for i in range(steps, 0, -1):
        r = radius * i / steps
        a = int(alpha * (1 - i / steps) ** 1.6)
        if a <= 0:
            continue
        cx, cy = centre
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgb + (a,))
    return layer


def ink_layer(size):
    return Image.new("RGBA", size, (0, 0, 0, 0))


def paste_centered(base, layer, centre):
    """Paste `layer` so its ink bounding box is centred on `centre`."""
    box = layer.getbbox()
    if box is None:
        return
    x0, y0, x1, y1 = box
    dx = int(round(centre[0] - (x0 + x1) / 2))
    dy = int(round(centre[1] - (y0 + y1) / 2))
    base.alpha_composite(layer, (dx, dy))


def build():
    canvas = vertical_gradient(BG_TOP, BG_BOTTOM).convert("RGBA")

    for slot in GLOW_SLOTS:
        canvas.alpha_composite(
            radial_glow((W, H), slot, GLOW_RADIUS, GLOW_RGB, GLOW_ALPHA)
        )

    # Title
    title = ink_layer((W, H))
    ImageDraw.Draw(title).text(
        (W // 2, H // 2), TITLE_TEXT, font=load_font(TITLE_SIZE, "Bold"),
        fill=TITLE_COLOR + (255,), anchor="mm",
    )
    paste_centered(canvas, title, TITLE_CENTER)

    # Version pill (auto-fits its text, like the original artwork did)
    font_pill = load_font(PILL_TEXT_SIZE, "Semibold")
    probe = ImageDraw.Draw(ink_layer((8, 8)))
    text_w = probe.textlength(PILL_TEXT, font=font_pill)
    pill_w = int(text_w + PILL_PAD_X * 2)

    pill = ink_layer((W, H))
    d = ImageDraw.Draw(pill)
    pill_x0 = (W - pill_w) // 2
    pill_y0 = (H - PILL_H) // 2
    d.rounded_rectangle(
        [pill_x0, pill_y0, pill_x0 + pill_w, pill_y0 + PILL_H],
        radius=PILL_H // 2, fill=PILL_FILL + (255,),
        outline=PILL_BORDER + (255,), width=PILL_BORDER_W,
    )
    d.text(
        (W // 2, H // 2), PILL_TEXT, font=font_pill,
        fill=PILL_TEXT_COLOR + (255,), anchor="mm",
    )
    paste_centered(canvas, pill, PILL_CENTER)

    # Hint line
    hint = ink_layer((W, H))
    ImageDraw.Draw(hint).text(
        (W // 2, H // 2), HINT_TEXT, font=load_font(HINT_SIZE, "Regular"),
        fill=HINT_COLOR + (255,), anchor="mm",
    )
    paste_centered(canvas, hint, HINT_CENTER)

    # Arrow
    arrow = ink_layer((W, H))
    d = ImageDraw.Draw(arrow)
    y = H // 2
    d.rectangle(
        [ARROW_X0, y - ARROW_SHAFT_W // 2, ARROW_X1, y + ARROW_SHAFT_W // 2],
        fill=ARROW_COLOR + (255,),
    )
    d.polygon(
        [
            (ARROW_X1, y - ARROW_HEAD_HALF),
            (ARROW_X1, y + ARROW_HEAD_HALF),
            (ARROW_X1 + ARROW_HEAD_LEN, y),
        ],
        fill=ARROW_COLOR + (255,),
    )
    paste_centered(canvas, arrow, ARROW_CENTER)

    return canvas.convert("RGB")


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "dmg_assets/background_700.png"
    img = build()
    img.save(out, "PNG", dpi=(TARGET_DPI, TARGET_DPI))
    rendered = (img.width * 72 / TARGET_DPI, img.height * 72 / TARGET_DPI)
    print(f"wrote {out}  {img.width}x{img.height}px  dpi={TARGET_DPI:.2f}")
    print(f"renders as {rendered[0]:.2f} x {rendered[1]:.2f} pt "
          f"(content area is {WINDOW_W_PT} x {WINDOW_H_PT} pt)")


if __name__ == "__main__":
    main()
