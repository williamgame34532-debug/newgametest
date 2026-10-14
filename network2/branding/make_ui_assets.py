"""UI assets of the character menus -> content/materials/network2/ui/
    icons/*.png   white icons (Tabler Icons, MIT, https://tabler.io/icons), 128 px
    panel.png     9-slice panel: rounded, translucent dark grey, thin light rim (corner 24 px)
    button.png    9-slice button: rounded (corner 16 px), darker
    outline.png   9-slice white rim for the selected / hovered state (corner 16 px)
    card_shade.png vertical shade for the character cards (transparent -> dark at the bottom)
    python make_ui_assets.py <tabler icons package dir> <out dir>"""
import os, sys, io
import cairosvg
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

TABLER, OUT = sys.argv[1], sys.argv[2]
ICONS = {
    "male": "gender-male", "female": "gender-female", "strength": "barbell", "endurance": "run",
    "medicine": "first-aid-kit", "engineering": "tool", "stealth": "spy", "speech": "messages",
    "plus": "plus", "trash": "trash", "play": "player-play", "back": "arrow-left", "faction": "id-badge-2",
    "user": "user", "height": "ruler-measure", "skin": "shirt", "check": "check", "chat": "message-circle",
    "resize": "arrows-diagonal",
}
os.makedirs(os.path.join(OUT, "icons"), exist_ok=True)
for name, src in ICONS.items():
    svg = open(os.path.join(TABLER, "icons", "outline", src + ".svg")).read()
    svg = svg.replace('stroke="currentColor"', 'stroke="#ffffff"').replace('stroke-width="2"', 'stroke-width="1.6"')
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=128, output_height=128)
    Image.open(io.BytesIO(png)).convert("RGBA").save(os.path.join(OUT, "icons", name + ".png"))


def rounded(size, radius, fill, rim=None, rim_w=2, ss=4):
    S = size * ss
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if fill:
        d.rounded_rectangle([0, 0, S - 1, S - 1], radius * ss, fill=fill)
    if rim:
        d.rounded_rectangle([rim_w * ss / 2, rim_w * ss / 2, S - 1 - rim_w * ss / 2, S - 1 - rim_w * ss / 2],
                            radius * ss, outline=rim, width=rim_w * ss)
    return im.resize((size, size), Image.LANCZOS)


rounded(128, 24, (34, 37, 42, 150), (255, 255, 255, 34), 2).save(os.path.join(OUT, "panel.png"))
# chat: darker glass, faint rim; the tab above it
rounded(128, 20, (11, 13, 16, 205), (255, 255, 255, 20), 2).save(os.path.join(OUT, "chat_panel.png"))
rounded(64, 14, (16, 18, 22, 225), (255, 255, 255, 30), 2).save(os.path.join(OUT, "chat_tab.png"))
rounded(64, 16, (22, 25, 29, 205), (255, 255, 255, 26), 2).save(os.path.join(OUT, "button.png"))
rounded(64, 16, None, (255, 255, 255, 235), 2).save(os.path.join(OUT, "outline.png"))
h = 256
a = (np.clip((np.linspace(0, 1, h) - 0.35) / 0.65, 0, 1) ** 1.4 * 235).astype(np.uint8)
shade = np.zeros((h, 4, 4), np.uint8)
shade[..., 0:3] = (8, 10, 12)
shade[..., 3] = a[:, None]
Image.fromarray(shade, "RGBA").save(os.path.join(OUT, "card_shade.png"))
print("icons", len(ICONS))
