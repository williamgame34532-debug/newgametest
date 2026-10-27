#!/usr/bin/env python3
"""Generates the Mod Critic logo shown in Forge's mod list (src/main/resources/modcritic_logo.png).
A gold star over a dark rounded panel with a small coloured bar chart (one bar per criterion)."""
import math, os
from PIL import Image, ImageDraw, ImageFilter

S = 4  # supersampling
W, H = 256, 128
img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# panel with vertical gradient
panel = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
pd = ImageDraw.Draw(panel)
for y in range(H * S):
    t = y / (H * S)
    c = (int(26 - 12 * t), int(26 - 12 * t), int(44 - 20 * t), 240)
    pd.line([(0, y), (W * S, y)], fill=c)
mask = Image.new("L", (W * S, H * S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, W * S - 1, H * S - 1], radius=18 * S, fill=255)
img.paste(panel, (0, 0), mask)
d.rounded_rectangle([S, S, W * S - S - 1, H * S - S - 1], radius=17 * S, outline=(255, 201, 74, 200), width=2 * S)

# star with glow
cx, cy, r1, r2 = 64 * S, 64 * S, 46 * S, 19 * S
pts = []
for k in range(10):
    a = -math.pi / 2 + k * math.pi / 5
    r = r1 if k % 2 == 0 else r2
    pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
ImageDraw.Draw(glow).polygon(pts, fill=(255, 190, 40, 170))
glow = glow.filter(ImageFilter.GaussianBlur(9 * S))
img = Image.alpha_composite(img, glow)
d = ImageDraw.Draw(img)
# star body: shaded halves for a bevelled look
d.polygon(pts, fill=(255, 196, 40, 255))
for k in range(10):
    a, b = pts[k], pts[(k + 1) % 10]
    shade = [(255, 236, 150), (255, 214, 90), (235, 160, 20), (200, 125, 10), (225, 150, 15)][k // 2]
    d.polygon([(cx, cy), a, b], fill=shade + (255,))
d.polygon(pts, outline=(110, 60, 0, 255), width=2 * S)

# bar chart, one bar per criterion (colours match the in-game criteria)
colors = [(242, 201, 76), (155, 107, 224), (79, 195, 106), (69, 176, 234),
          (232, 111, 168), (238, 150, 60), (53, 211, 192), (232, 90, 90)]
values = [0.8, 0.95, 0.7, 0.85, 0.6, 0.75, 0.9, 0.65]
x0, base, bw, gap, maxh = 126 * S, 108 * S, 12 * S, 3 * S, 80 * S
for i, (c, v) in enumerate(zip(colors, values)):
    x = x0 + i * (bw + gap)
    top = base - int(maxh * v)
    d.rounded_rectangle([x, top, x + bw, base], radius=3 * S, fill=c + (255,))
    light = tuple(min(255, int(ch * 1.3 + 30)) for ch in c)
    d.rectangle([x + S, top + S, x + 3 * S, base - 2 * S], fill=light + (255,))
    dark = tuple(int(ch * 0.6) for ch in c)
    d.rectangle([x + bw - 3 * S, top + 2 * S, x + bw - S, base], fill=dark + (255,))
d.line([(x0 - 4 * S, base + 2 * S), (x0 + 8 * (bw + gap), base + 2 * S)], fill=(200, 200, 230, 200), width=2 * S)

img = img.resize((W, H), Image.LANCZOS)
out = os.path.join(os.path.dirname(__file__), "..", "src", "main", "resources", "modcritic_logo.png")
img.save(out)
print("wrote", os.path.abspath(out))
