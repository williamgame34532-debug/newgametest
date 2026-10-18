"""The splash of joining (cl_intro.lua): materials/network2/menu/splash.jpg, 1920x1080.
A dark slate room lit from above: a radial light, a faint hex grid of the Combine, the emblem in the middle
pressed into the wall - our own chunky Lambda in a hexagon with cut corners, tone
on tone: lit edges above, shadow below, a soft cast shadow - and the wordmark NETWORK under it, thin and
quiet. A vignette, a little grain.
    python make_splash.py <@iconify-json/game-icons package dir> <network2 folder>"""
import io, json, math, os, sys
import cairosvg
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

GI, ROOT = sys.argv[1], sys.argv[2]
W, H = 1920, 1080
rng = np.random.default_rng(11)

# the wall: a cold slate, lighter where the light falls
y, x = np.mgrid[0:H, 0:W].astype(np.float32)
d = np.sqrt(((x - W / 2) / (W * 0.55)) ** 2 + ((y - H * 0.36) / (H * 0.7)) ** 2)
light = np.clip(1 - d, 0, 1) ** 1.6
base = np.array([28, 32, 39], np.float32)
top = np.array([46, 52, 62], np.float32)
wall = base[None, None, :] + (top - base)[None, None, :] * light[..., None]
wall *= (1 - 0.18 * (y / H))[..., None]

# a faint hex grid
grid = Image.new("L", (W, H), 0)
g = ImageDraw.Draw(grid)
r = 46
for row in range(-1, int(H / (r * 1.5)) + 2):
    for col in range(-1, int(W / (r * math.sqrt(3))) + 2):
        cx = col * r * math.sqrt(3) + (row % 2) * r * math.sqrt(3) / 2
        cy = row * r * 1.5
        pts = [(cx + r * math.cos(math.radians(60 * i + 30)), cy + r * math.sin(math.radians(60 * i + 30))) for i in range(6)]
        g.polygon(pts, outline=255)
gridv = np.asarray(grid.filter(ImageFilter.GaussianBlur(0.6))).astype(np.float32) / 255
wall += gridv[..., None] * 5 * (0.3 + light[..., None])


def emblem_mask(size):
    """the hexagon with cut corners and the Lambda inside (white on black)"""
    m = Image.new("L", (size, size), 0)
    dr = ImageDraw.Draw(m)
    cx = cy = size / 2
    rr = size * 0.46
    pts = [(cx + rr * math.cos(math.radians(60 * i - 90)), cy + rr * math.sin(math.radians(60 * i - 90))) for i in range(6)]
    for i in range(6):
        a, b = pts[i], pts[(i + 1) % 6]
        dr.line([(a[0] + (b[0] - a[0]) * 0.1, a[1] + (b[1] - a[1]) * 0.1),
                 (a[0] + (b[0] - a[0]) * 0.9, a[1] + (b[1] - a[1]) * 0.9)], fill=255, width=int(size * 0.05))
    inner = [(cx + rr * 0.8 * math.cos(math.radians(60 * i - 90)), cy + rr * 0.8 * math.sin(math.radians(60 * i - 90)))
             for i in range(6)]
    dr.polygon(inner, outline=255, width=int(size * 0.012))
    # the Lambda: our own, chunky and cut straight
    box = size * 0.5
    ox, oy = cx - box / 2, cy - box / 2

    def P(points):
        dr.polygon([(ox + px * box, oy + py * box) for px, py in points], fill=255)

    P([(0.22, 0.04), (0.50, 0.04), (0.50, 0.17), (0.22, 0.17)])          # the hook on top
    P([(0.36, 0.04), (0.56, 0.04), (0.86, 0.86), (0.66, 0.86)])          # the long stroke
    P([(0.66, 0.78), (0.94, 0.70), (0.98, 0.84), (0.70, 0.94)])          # the foot
    P([(0.44, 0.44), (0.54, 0.62), (0.36, 0.94), (0.16, 0.94)])          # the short leg
    return m


size = 520
mask = emblem_mask(size)
ex, ey = W // 2 - size // 2, int(H * 0.42) - size // 2
full = Image.new("L", (W, H), 0)
full.paste(mask, (ex, ey))
m = np.asarray(full).astype(np.float32) / 255

# pressed into the wall: the cast shadow under, the lit upper edges, the darker lower edges, a flat face
shadow = np.asarray(full.filter(ImageFilter.GaussianBlur(18))).astype(np.float32) / 255
shadow = np.roll(shadow, 14, axis=0)
up = np.asarray(full.filter(ImageFilter.GaussianBlur(2))).astype(np.float32) / 255
edge_hi = np.clip(up - np.roll(up, 3, axis=0), 0, 1)
edge_lo = np.clip(up - np.roll(up, -3, axis=0), 0, 1)
wall *= (1 - 0.35 * shadow * (1 - m))[..., None]
face = np.array([40, 45, 54], np.float32) + 10 * light[..., None]
wall = wall * (1 - m[..., None]) + face * m[..., None]
wall += (edge_hi * 22)[..., None]
wall -= (edge_lo * 16)[..., None]

img = Image.fromarray(np.clip(wall, 0, 255).astype(np.uint8), "RGB")

# the wordmark: thin, wide spacing, quiet
dr = ImageDraw.Draw(img)
fontpath = "/usr/share/fonts/opentype/inter/Inter-Light.otf"
if not os.path.exists(fontpath):
    fontpath = "/usr/share/fonts/opentype/inter/Inter-Regular.otf"
font = ImageFont.truetype(fontpath, 54)
word = "N E T W O R K"
ww = font.getlength(word)
wy = ey + size + 40
dr.text((W / 2 - ww / 2 + 2, wy + 3), word, font=font, fill=(18, 20, 25))
dr.text((W / 2 - ww / 2, wy), word, font=font, fill=(92, 102, 116))
sub = ImageFont.truetype(fontpath, 22)
s2 = "H A L F - L I F E   R O L E P L A Y"
sw = sub.getlength(s2)
dr.text((W / 2 - sw / 2, wy + 78), s2, font=sub, fill=(70, 78, 90))
dr.line([(W / 2 - ww / 2, wy + 66), (W / 2 + ww / 2, wy + 66)], fill=(56, 62, 72), width=1)

# a vignette and a little grain
arr = np.asarray(img).astype(np.float32)
vd = np.sqrt(((x - W / 2) / (W / 2)) ** 2 + ((y - H / 2) / (H / 2)) ** 2)
arr *= np.clip(1.08 - 0.42 * vd ** 1.8, 0.45, 1)[..., None]
arr += rng.normal(0, 1.6, (H, W, 1))
out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
path = os.path.join(ROOT, "content", "materials", "network2", "menu", "splash.jpg")
out.save(path, quality=90, optimize=True)
print("splash written", os.path.getsize(path))
