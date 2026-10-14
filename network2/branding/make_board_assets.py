"""Own materials of the TAB board -> content/materials/network2/ui/
    board_sheet.png  512x512 tileable sheet: near-black graphite with fine film grain and faint
                     horizontal fibres (drawn tiled, 1:1, over the whole board)
    board_edge.png   256x8 the board's right edge: a hard light line, then a soft shadow
                     that falls onto the screen
    board_menu.png   9-slice context menu (64 px, corner 2): flat graphite, 1 px light border
    python make_board_assets.py <out dir>"""
import os, sys
import numpy as np
from PIL import Image, ImageFilter

OUT = sys.argv[1]
rng = np.random.default_rng(7)

# sheet: grain + soft fibres, tileable (noise blurred with wrap-around)
S = 512
grain = rng.normal(0, 1, (S, S))
fibre = rng.normal(0, 1, (S, 1)) * np.ones((1, S))
pad = np.pad(fibre, ((8, 8), (0, 0)), mode="wrap")
fibre = np.asarray(Image.fromarray(((pad - pad.min()) / np.ptp(pad) * 255).astype(np.uint8))
                   .filter(ImageFilter.GaussianBlur(1.2)))[8:-8].astype(np.float32) / 255 - 0.5
base = np.array([14, 15, 16], np.float32)
lum = grain * 2.2 + fibre * 5
rgb = base[None, None, :] + lum[..., None] * np.array([1, 1, 1.05])
a = np.full((S, S), 228, np.float32)
Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a]).astype(np.uint8), "RGBA").save(
    os.path.join(OUT, "board_sheet.png"))

# edge: 1..2 px light line at the left of the strip, then shadow falling off to the right
W = 256
x = np.arange(W, dtype=np.float32)
alpha = np.where(x < 2, 120, 200 * np.exp(-(np.maximum(x - 2, 0) / 70.0) ** 1.3))
rgb = np.where(x[:, None] < 2, np.array([235, 235, 230]), np.array([0, 0, 0])).astype(np.float32)
strip = np.dstack([np.repeat(rgb[None], 8, 0), np.repeat(alpha[None], 8, 0)])
Image.fromarray(np.clip(strip, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "board_edge.png"))

# menu
M = 64
m = np.zeros((M, M, 4), np.float32)
m[..., :3] = (16, 17, 18)
m[..., 3] = 248
border = np.zeros((M, M), bool)
border[[0, -1], :] = True
border[:, [0, -1]] = True
m[border, :3] = (190, 190, 186)
m[border, 3] = 255
Image.fromarray(m.astype(np.uint8), "RGBA").save(os.path.join(OUT, "board_menu.png"))
print("board assets")
