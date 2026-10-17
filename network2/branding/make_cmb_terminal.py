"""The Alliance terminal (entities/entities/nw_cmb_terminal.lua, cl_cmbterminal.lua): its screen.
    materials/network2/cmb/bg_cmb.png     1280x720 - the dark teal glass of the Combine command
        screen: scan lines, slow bands of light, a faint grid, the edges falling into the dark
    materials/network2/cmb/hatch.png      64x64 - fine diagonal hatching laid over the lit bars
Own work. Usage: python make_cmb_terminal.py <network2 folder>"""
import os, sys
import numpy as np
from PIL import Image, ImageFilter

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "content", "materials", "network2", "cmb")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(2401)

W, H = 1280, 720
y, x = np.mgrid[0:H, 0:W].astype(float)

base = np.array([6, 18, 26], float)
glow = np.array([26, 78, 98], float)

# the light: a soft wide glow in the middle, a little higher than the centre
light = np.exp(-(((x - W * 0.5) / (W * 0.55)) ** 2 + ((y - H * 0.45) / (H * 0.7)) ** 2)) * 0.55

# slow bands of light going down the glass
bands = 0.025 * np.sin(y / H * np.pi * 5 + 0.6) + 0.015 * np.sin(y / H * np.pi * 31 + 2.0)

# scan lines: every third row a little darker
scan = np.where((y.astype(int) % 3) == 0, -0.05, 0.0)

# a faint grid of the command screen
grid = ((x.astype(int) % 64) == 0) | ((y.astype(int) % 64) == 0)
grid = grid.astype(float) * 0.035

# noise
noise = rng.normal(0, 0.012, (H, W))

level = np.clip(light + bands + scan + grid + noise, 0, 1)
img = base + level[..., None] * glow

# the edges fall into the dark
edge = np.clip(np.minimum(np.minimum(x, W - 1 - x) / (W * 0.18), np.minimum(y, H - 1 - y) / (H * 0.22)), 0, 1)
img *= (0.45 + 0.55 * edge ** 0.7)[..., None]

Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.4)).save(
    os.path.join(OUT, "bg_cmb.png"), optimize=True)

# the hatching over lit bars (white, translucent stripes at 45 degrees)
S = 64
hy, hx = np.mgrid[0:S, 0:S]
stripe = (((hx + hy) % 8) < 2).astype(float)
hatch = np.zeros((S, S, 4), np.uint8)
hatch[..., :3] = 255
hatch[..., 3] = (stripe * 40).astype(np.uint8)
Image.fromarray(hatch, "RGBA").save(os.path.join(OUT, "hatch.png"))
print("cmb terminal assets written")
