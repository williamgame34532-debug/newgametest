"""Low-health blood overlay -> content/materials/network2/ui/blood_overlay.png (1024 px):
clear in the middle, thick dark-red blood creeping in from the edges, uneven (fractal noise),
clotted darker spots, a few runs down from the top. Drawn over the screen, stronger the lower
the health. python make_blood.py <out file>"""
import sys
import numpy as np
from PIL import Image, ImageFilter

OUT = sys.argv[1]
S = 1024
rng = np.random.default_rng(11)


def noise(scale):
    small = rng.random((S // scale + 2, S // scale + 2)).astype(np.float32)
    im = Image.fromarray((small * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC)
    return np.asarray(im).astype(np.float32) / 255


fractal = sum(noise(s) * w for s, w in [(256, 0.5), (128, 0.28), (64, 0.22)])
yy, xx = np.mgrid[0:S, 0:S].astype(np.float32) / (S - 1) * 2 - 1
r = np.sqrt((xx * 0.92) ** 2 + (yy * 1.05) ** 2)

# how far the blood reaches: uneven edge
edge = r + (fractal - 0.5) * 0.55
a = np.clip((edge - 0.72) / 0.42, 0, 1) ** 1.3

# runs from the top
runs = np.zeros((S, S), np.float32)
for _ in range(7):
    x = rng.integers(0, S)
    length = rng.integers(S // 8, S // 3)
    width = rng.integers(2, 5)
    runs[:length, max(0, x - width):x + width] = np.linspace(1, 0, length)[:, None] ** 1.5
runs = np.asarray(Image.fromarray((runs * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))) / 255
a = np.clip(np.maximum(a, runs * 0.9 * (1 - np.clip(r - 0.2, 0, 1) * 0)) , 0, 1)

# colour: dark red, darker clots
clot = np.clip((noise(80) - 0.5) * 2.5, 0, 1)
red = np.stack([150 - 70 * clot, 8 + 4 * clot, 10 + 0 * clot], -1)
red = red * (0.75 + 0.25 * fractal[..., None])
alpha = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5))).astype(
    np.float32) * 0.96
img = np.dstack([np.clip(red, 0, 255), alpha]).astype(np.uint8)
Image.fromarray(img, "RGBA").save(OUT)
print("blood overlay")
