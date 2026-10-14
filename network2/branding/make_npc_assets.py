"""NPC (dialogue, trade, quests) interface plates -> content/materials/network2/ui/npc/
    panel.png         the dialogue panel: dark glass, lighter top, faint rim, a gold edge on top (9-slice, corner 14)
    answer.png        an answer row (corner 8)
    answer_hover.png  the answer under the cursor: warm gold tint and rim
    card.png          a trade / quest card (corner 10)
    plate.png         the name plate under the name (corner 6, gold)
    shade.png         the bottom shade behind the dialogue (vertical gradient, stretched)
    python make_npc_assets.py <content/materials/network2>"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw

OUT = os.path.join(sys.argv[1], "ui", "npc")
os.makedirs(OUT, exist_ok=True)
SS = 4


def plate(s, r, fill, rim, top=0.0, edge=None):
    big = Image.new("RGBA", (s * SS, s * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.rounded_rectangle([0, 0, s * SS - 1, s * SS - 1], r * SS, fill=fill)
    d.rounded_rectangle([SS / 2, SS / 2, s * SS - 1 - SS / 2, s * SS - 1 - SS / 2], r * SS, outline=rim, width=SS)
    im = np.asarray(big.resize((s, s), Image.LANCZOS)).astype(np.float32)
    inside = im[..., 3:4] > 0
    if top:
        y = np.linspace(1, 0, s)[:, None]
        glow = np.clip(y * 2.2 - 1.2, 0, 1) * top
        im[..., :3] = im[..., :3] + glow[..., None] * 255 * inside
    if edge:
        # a thin coloured line along the top edge, fading at the corners
        x = np.linspace(-1, 1, s)
        fade = np.clip((1 - np.abs(x)) * 4, 0, 1)
        for row in range(1, 3):
            im[row, :, :3] = im[row, :, :3] * (1 - fade[:, None]) + np.array(edge[:3]) * fade[:, None]
            im[row, :, 3] = np.maximum(im[row, :, 3], edge[3] * fade)
    return Image.fromarray(np.clip(im, 0, 255).astype(np.uint8), "RGBA")


plate(128, 14, (11, 13, 16, 232), (255, 255, 255, 22), 0.05, (232, 196, 72, 230)).save(os.path.join(OUT, "panel.png"))
plate(64, 8, (255, 255, 255, 9), (255, 255, 255, 20)).save(os.path.join(OUT, "answer.png"))
plate(64, 8, (232, 196, 72, 38), (232, 196, 72, 150), 0.04).save(os.path.join(OUT, "answer_hover.png"))
plate(64, 10, (20, 23, 27, 242), (255, 255, 255, 20), 0.06).save(os.path.join(OUT, "card.png"))
plate(32, 6, (232, 196, 72, 255), (255, 236, 170, 255), 0.1).save(os.path.join(OUT, "plate.png"))

h = 256
a = (np.linspace(0, 1, h) ** 1.6 * 230).astype(np.uint8)
shade = np.zeros((h, 4, 4), np.uint8)
shade[..., 3] = a[:, None]
Image.fromarray(shade, "RGBA").save(os.path.join(OUT, "shade.png"))
print("ok")
