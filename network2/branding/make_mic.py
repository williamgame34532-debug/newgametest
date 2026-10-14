"""The voice microphone (cl_voice.lua) -> content/materials/network2/ui/mic_*.png, 256 px, white:
    mic_frame   the capsule outline with grille lines, the cradle arc, the stem and the foot
    mic_fill    the inside of the capsule (drawn clipped from the bottom: how loud the voice is)
    mic_wave    one sound wave arc (drawn on both sides, growing and fading with the voice)
python make_mic.py <out dir>"""
import os, sys
from PIL import Image, ImageDraw

OUT = sys.argv[1]
SS = 4
S = 256 * SS


def save(im, name):
    im.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


W = 14 * SS  # line width
cx = S // 2
top, bottom = 24 * SS, 150 * SS
half = 34 * SS

# frame
im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.rounded_rectangle([cx - half, top, cx + half, bottom], half, outline=(255, 255, 255, 255), width=W)
# grille: three short lines in the upper half
for i, y in enumerate((58, 76, 94)):
    y *= SS
    inset = (half - W) * (0.55 if i == 0 else 0.62)
    d.line([cx - inset, y, cx + inset, y], fill=(255, 255, 255, 170), width=int(W * 0.55))
# cradle arc
r = 58 * SS
d.arc([cx - r, 92 * SS - r + 30 * SS, cx + r, 92 * SS + r + 30 * SS], 0, 180, fill=(255, 255, 255, 255), width=W)
# stem and foot
d.line([cx, 180 * SS, cx, 214 * SS], fill=(255, 255, 255, 255), width=W)
d.rounded_rectangle([cx - 36 * SS, 210 * SS, cx + 36 * SS, 210 * SS + W], W // 2, fill=(255, 255, 255, 255))
save(im, "mic_frame")

# fill: the inside of the capsule
im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
g = W + 6 * SS
d.rounded_rectangle([cx - half + g, top + g, cx + half - g, bottom - g], half - g, fill=(255, 255, 255, 255))
save(im, "mic_fill")

# a wave: a short arc on the right (mirrored when drawn on the left)
im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
r = 70 * SS
d.arc([cx - r, 88 * SS - r, cx + r, 88 * SS + r], -38, 38, fill=(255, 255, 255, 255), width=int(W * 0.8))
save(im, "mic_wave")
print("mic")
