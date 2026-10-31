# Builds the textures of the HL:A style main menu into the hla_menu_content addon (VTF + VMT).
#   python tools/menu_textures.py garrysmod/addons/hla_menu_content
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'hla_convert'))
from vtex import write_vtf

OUT = sys.argv[1]
MAT = os.path.join(OUT, 'materials', 'hla', 'ui')
os.makedirs(MAT, exist_ok=True)
rng = np.random.default_rng(7)
GOLD = np.array([236, 178, 62], float)


def save(name, rgba, vmt_extra=''):
    img = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), 'RGBA')
    write_vtf(os.path.join(MAT, name + '.vtf'), img, 'BGRA8888', flags=0x0004 | 0x0008 | 0x2000)  # clamp s/t, eightbitalpha
    open(os.path.join(MAT, name + '.vmt'), 'w').write(
        '"UnlitGeneric"\n{\n\t"$basetexture" "hla/ui/%s"\n\t"$vertexcolor" "1"\n\t"$vertexalpha" "1"\n'
        '\t"$translucent" "1"\n\t"$nocull" "1"\n\t"$ignorez" "0"%s\n}\n' % (name, vmt_extra))


def grain(h, w, amount):
    return rng.normal(0, amount, (h, w))


# panel background: warm amber-brown like the HL:A menu, a soft lighter band near the top,
# a gentle glow in the middle and fine paper grain; no hard scanlines
h, w = 512, 512
y = np.linspace(0, 1, h)[:, None]
x = np.linspace(-1, 1, w)[None, :]
lum = 0.46 - 0.16 * y + 0.06 * np.exp(-((y - 0.12) / 0.08) ** 2) + 0.07 * np.exp(-(x ** 2 * 1.1 + ((y - 0.45) * 1.8) ** 2))
lum = lum + np.asarray(Image.fromarray((grain(h, w, 1) * 40 + 128).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)), float) / 255 * 0.05 - 0.025
lum = lum * np.clip(1 - np.maximum(np.abs(x) - 0.86, 0) * 2.2, 0.8, 1)
rgb = np.stack([lum * 255 * 0.86, lum * 255 * 0.64, lum * 255 * 0.26], -1)
save('panel_bg', np.concatenate([rgb, np.full((h, w, 1), 222.0)], -1))

# header bar: flat warm gold, slightly lighter at the top, soft grain, darker lip
h, w = 32, 512
lum = 1.0 - 0.10 * np.linspace(0, 1, h)[:, None] + grain(h, w, 0.015)
lum[-2:] *= 0.7
rgb = np.array([238, 196, 98], float)[None, None, :] * lum[..., None]
save('header', np.concatenate([rgb, np.full((h, w, 1), 255.0)], -1))

# hovered row: soft light-gold band (as the selected OPTIONS row), feathered top and bottom
h, w = 64, 512
xx = np.linspace(0, 1, w)[None, :]
yy = np.linspace(-1, 1, h)[:, None]
lum = (0.86 + 0.10 * xx) * (1 - 0.10 * yy ** 2) + grain(h, w, 0.012)
rgb = np.array([214, 168, 82], float)[None, None, :] * lum[..., None]
alpha = 215 * np.clip((1 - np.abs(yy) ** 6) * 1.25, 0, 1) * np.ones_like(xx)
save('row_hover', np.concatenate([rgb, alpha[..., None]], -1))

# separator line: faint, fades out at both ends
h, w = 4, 512
xx = np.linspace(-1, 1, w)[None, :]
alpha = 95 * np.clip(1.3 - np.abs(xx) ** 3 * 1.3, 0, 1) * np.array([[0.3], [1], [1], [0.3]])
save('line', np.concatenate([np.ones((h, w, 3)) * np.array([214, 168, 82]), alpha[..., None]], -1))


def shape(size, draw_fn, blur=0.6):
    im = Image.new('L', (size * 4, size * 4), 0)
    draw_fn(ImageDraw.Draw(im), size * 4)
    im = im.resize((size, size), Image.LANCZOS).filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(im, float)
    return np.concatenate([np.ones((size, size, 3)) * 255, a[..., None]], -1)


# small corner triangle marker (bottom-right pointing, like HL:A row ends)
save('marker', shape(32, lambda d, s: d.polygon([(s * 0.95, s * 0.2), (s * 0.95, s * 0.95), (s * 0.2, s * 0.95)], fill=255)))
# option dots
save('dot', shape(16, lambda d, s: d.rectangle([s * 0.15, s * 0.15, s * 0.85, s * 0.85], fill=255), 0.3))


# arrow boxes: thin frame with a notched chevron (left / right)
def arrow_box(left):
    def fn(d, s):
        t = s * 0.035
        d.rectangle([t, t, s - t, s - t], outline=255, width=int(s * 0.03))
        cx = s * 0.5
        if left:
            pts = [(cx + s * 0.12, s * 0.3), (cx - s * 0.12, s * 0.5), (cx + s * 0.12, s * 0.7), (cx + s * 0.04, s * 0.5)]
        else:
            pts = [(cx - s * 0.12, s * 0.3), (cx + s * 0.12, s * 0.5), (cx - s * 0.12, s * 0.7), (cx - s * 0.04, s * 0.5)]
        d.polygon(pts, fill=255)
    return fn


save('arrow_l', shape(64, arrow_box(True), 0.4))
save('arrow_r', shape(64, arrow_box(False), 0.4))

# toggle (on/off switch like HL:A): a bar with a knob
save('toggle', shape(64, lambda d, s: (d.rectangle([s * 0.1, s * 0.46, s * 0.9, s * 0.54], fill=200),
                                      d.rectangle([s * 0.44, s * 0.25, s * 0.56, s * 0.75], fill=255)), 0.4))

# corner bracket of a panel frame (top-left; rotate for the others)
save('corner', shape(64, lambda d, s: (d.rectangle([0, 0, s * 0.08, s * 0.9], fill=255), d.rectangle([0, 0, s * 0.9, s * 0.08], fill=255)), 0.3))

# boxed button (BACK): dark fill, thin gold frame
h, w = 64, 256
fill = np.concatenate([np.stack([np.full((h, w), 92.0), np.full((h, w), 68.0), np.full((h, w), 26.0)], -1), np.full((h, w, 1), 190.0)], -1)
frame = np.zeros((h, w), bool); frame[:3] = frame[-3:] = True; frame[:, :3] = frame[:, -3:] = True
fill[frame, :3] = np.array([226, 182, 96]); fill[frame, 3] = 235
save('button', fill)

# text field: underline and a faint fill
h, w = 64, 512
field = np.zeros((h, w, 4)); field[..., :3] = GOLD * 0.5; field[..., 3] = 40
field[-4:, :, :3] = GOLD; field[-4:, :, 3] = 230
save('field', field)

# dust mote for the floating particles
s = 32
yy, xx = np.mgrid[-1:1:complex(0, s), -1:1:complex(0, s)]
a = np.clip(1 - np.sqrt(xx ** 2 + yy ** 2), 0, 1) ** 2 * 255
save('dust', np.concatenate([np.ones((s, s, 3)) * 255, a[..., None]], -1), '\n\t"$additive" "1"')

# screen vignette: transparent centre, smooth dark edges (tinted by the HUD: black, or red when hurt)
s = 512
yy, xx = np.mgrid[-1:1:complex(0, s), -1:1:complex(0, s)]
r = np.sqrt((xx * 0.92) ** 2 + (yy * 1.08) ** 2)
a = np.clip((r - 0.55) / 0.75, 0, 1)
a = a * a * (3 - 2 * a) * 255
save('vignette', np.concatenate([np.ones((s, s, 3)) * 255, a[..., None]], -1))

# scanline overlay for panels and the fade in/out flash
h, w = 64, 64
a = np.where(np.arange(h)[:, None] % 4 < 1, 12.0, 0.0) * np.ones((1, w))
save('scanlines', np.concatenate([np.ones((h, w, 3)) * 255, a[..., None]], -1))
print('textures:', sorted(f for f in os.listdir(MAT) if f.endswith('.vtf')))
