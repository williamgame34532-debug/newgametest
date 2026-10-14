"""Backgrounds of the death / unconscious screens -> content/materials/network2/ui/
    death_bg.png    dark smoke with a cold red glow low in the middle, grain, a heavy vignette
    knock_bg.png    the same smoke, colder (blue-grey) and darker - "eyes closed"
    python make_death_bg.py <content/materials/network2>"""
import os, sys
import numpy as np
from PIL import Image

OUT = sys.argv[1]
W, H = 1024, 576
rng = np.random.default_rng(7)


def smoke():
    total = np.zeros((H, W))
    amp = 1.0
    for size in (4, 8, 16, 32, 64, 128):
        small = rng.random((size * H // W + 2, size + 2))
        big = np.array(Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)) / 255.0
        total += big * amp
        amp *= 0.55
    total -= total.min()
    return total / total.max()


def make(name, tint, glow):
    s = smoke()
    y, x = np.mgrid[0:H, 0:W]
    nx, ny = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
    vignette = np.clip(1 - (nx ** 2 * 0.7 + ny ** 2 * 1.1), 0, 1) ** 1.6
    light = np.exp(-((nx / 0.8) ** 2 + ((ny - 0.55) / 0.5) ** 2)) * glow
    value = (0.05 + s ** 2.2 * 0.22) * vignette + light * (0.25 + s * 0.35)
    grain = rng.normal(0, 0.012, (H, W))
    rgb = np.stack([np.clip(value * t + grain, 0, 1) for t in tint], -1)
    Image.fromarray((rgb * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "ui", name))


make("death_bg.png", (1.0, 0.42, 0.40), 0.55)
make("knock_bg.png", (0.55, 0.62, 0.74), 0.25)
print("ok")
