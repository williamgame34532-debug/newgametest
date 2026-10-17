"""The crafting table (entities/entities/nw_craft_table.lua, cl_craft.lua): the backdrop of its window.
    materials/network2/craft/bg_workshop.png   1600x900 - the wall of a workshop at night: a dark steel
        pegboard (rows of holes, brushed, scratched), a warm lamp hanging over the middle, the edge of
        a worn wooden workbench at the bottom, the corners falling into the dark
Own work (the texture sites are not reachable from the build machine).
Usage: python make_craft_assets.py <network2 folder>"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "content", "materials", "network2", "craft")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(77)

W, H = 1600, 900
y, x = np.mgrid[0:H, 0:W].astype(float)


def blur(a, r):
    img = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(r)), float) / 255


# brushed steel: horizontal streaks of noise
streak = rng.random((H, W // 40 + 1))
streak = np.asarray(Image.fromarray((streak * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), float) / 255
grain = rng.normal(0, 1, (H, W)) * 0.5 + 0.5
metal = 0.5 * streak + 0.2 * blur(grain, 0.6)
steel = np.array([46, 49, 52]) / 255
img = steel * (0.8 + 0.4 * metal)[..., None]

# the pegboard: holes every 40 px with a light lower rim (lit from above)
holes = Image.new("L", (W, H), 0)
rims = Image.new("L", (W, H), 0)
dh, dr = ImageDraw.Draw(holes), ImageDraw.Draw(rims)
bench = int(H * 0.8)
for hy in range(30, bench - 30, 40):
    for hx in range(30, W - 10, 40):
        dh.ellipse((hx - 5, hy - 5, hx + 5, hy + 5), fill=255)
        dr.arc((hx - 6, hy - 6, hx + 6, hy + 6), 20, 160, fill=255, width=2)
holes = blur(np.asarray(holes, float) / 255, 0.8)
rims = blur(np.asarray(rims, float) / 255, 0.6)
img *= (1 - holes * 0.85)[..., None]
img += rims[..., None] * 0.06

# scratches
scr = Image.new("L", (W, H), 0)
ds = ImageDraw.Draw(scr)
for _ in range(220):
    sx, sy = rng.uniform(0, W), rng.uniform(0, bench)
    length, angle = rng.uniform(20, 140), rng.uniform(-0.5, 0.5)
    ds.line((sx, sy, sx + np.cos(angle) * length, sy + np.sin(angle) * length), fill=int(rng.uniform(40, 120)), width=1)
img += blur(np.asarray(scr, float) / 255, 0.5)[..., None] * 0.05

# the workbench edge: worn wood with grain
wood = np.array([86, 58, 36]) / 255
grain_w = rng.random((H // 2, 10))
grain_w = np.asarray(Image.fromarray((grain_w * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), float) / 255
wood_tex = wood * (0.55 + 0.8 * grain_w ** 1.6)[..., None]
mask = (y >= bench).astype(float)
edge = np.exp(-np.abs(y - bench) / 3) * 0.35
img = img * (1 - mask[..., None]) + wood_tex * mask[..., None]
img += edge[..., None] * np.array([1.0, 0.8, 0.6])
img *= (1 - 0.45 * np.exp(-(y - bench) / 18) * mask)[..., None]  # the shadow under the lip

# the lamp: a warm cone over the middle, a hot spot on the bench
cone = np.exp(-(((x - W * 0.5) / (W * 0.33 + (y / H) * W * 0.12)) ** 2)) * np.exp(-(y / H) * 0.7)
spot = np.exp(-(((x - W * 0.5) / (W * 0.25)) ** 2 + ((y - H * 0.9) / (H * 0.12)) ** 2))
warm = np.array([1.0, 0.82, 0.58])
img = img * (0.35 + 1.05 * cone)[..., None] * (0.85 + 0.15 * warm) + (cone * 0.09 + spot * 0.22)[..., None] * warm

# the corners into the dark
vig = np.clip(1 - (((x - W / 2) / (W * 0.62)) ** 2 + ((y - H * 0.45) / (H * 0.75)) ** 2), 0, 1) ** 0.8
img *= (0.25 + 0.75 * vig)[..., None]

Image.fromarray(np.clip(img * 255, 0, 255).astype(np.uint8)).save(os.path.join(OUT, "bg_workshop.png"), optimize=True)
print("craft assets written")
