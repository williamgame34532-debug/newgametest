"""The key plate of the prompts -> content/materials/network2/ui/key.png (128 px).
The shape is Kenney's "keyboard_any" (Input Prompts, CC0, kenney.nl) with its letters filled in;
over it our own dark keycap: a darker lower lip (the key stands up a little), a lighter top face
with a soft gradient, a thin light rim on the top face. The game writes the letter on it.
python make_key.py <kenney keyboard_any.png> <out file>"""
import sys
from collections import deque
import numpy as np
from PIL import Image, ImageFilter

SRC, OUT = sys.argv[1], sys.argv[2]
S = 128

alpha = np.asarray(Image.open(SRC).convert("RGBA").resize((S, S), Image.LANCZOS))[..., 3] > 40

# the silhouette: transparent pixels not reachable from the border are holes (the letters)
outside = np.zeros_like(alpha)
queue = deque()
for x in range(S):
    for y in (0, S - 1):
        for p in ((y, x), (x, y)):
            if not alpha[p] and not outside[p]:
                outside[p] = True
                queue.append(p)
while queue:
    y, x = queue.popleft()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ny, nx = y + dy, x + dx
        if 0 <= ny < S and 0 <= nx < S and not alpha[ny, nx] and not outside[ny, nx]:
            outside[ny, nx] = True
            queue.append((ny, nx))
shape = ~outside

mask = Image.fromarray((shape * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
m = np.asarray(mask).astype(np.float32) / 255

# the top face: the shape moved up and shrunk a little
face = Image.fromarray((shape * 255).astype(np.uint8)).resize((S - 10, S - 14), Image.LANCZOS)
top = Image.new("L", (S, S), 0)
top.paste(face, (5, 3))
t = np.asarray(top.filter(ImageFilter.GaussianBlur(0.6))).astype(np.float32) / 255

yy = np.linspace(0, 1, S)[:, None] * np.ones((1, S))
lip = np.array([14, 15, 17], np.float32)
face_top, face_bottom = np.array([52, 55, 60], np.float32), np.array([34, 36, 40], np.float32)
face_col = face_top * (1 - yy[..., None]) + face_bottom * yy[..., None]

rgb = lip * (1 - t[..., None]) + face_col * t[..., None]

# a thin light rim on the top face
inner = Image.fromarray((t * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5))
rim = np.clip(t - np.asarray(inner).astype(np.float32) / 255, 0, 1)
rgb = rgb + rim[..., None] * np.array([70, 72, 76])

a = np.clip(m * 240, 0, 255)
Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a]).astype(np.uint8), "RGBA").save(OUT)
print("key")
