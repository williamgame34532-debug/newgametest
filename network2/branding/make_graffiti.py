"""The graffiti of the Resistance (sh_rebels.lua, entities/entities/nw_graffiti.lua):
    materials/network2/fx/graffiti_lambda.png   the Lambda in a ring, sprayed: soft edges, the overspray,
                                                drips running down (256 px, alpha)
The Lambda: game-icons.net "lambda" (CC BY 3.0, Lorc, Delapouite and contributors).
    python make_graffiti.py <@iconify-json/game-icons package dir> <network2 folder>"""
import io, json, os, sys
import cairosvg
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

GI, ROOT = sys.argv[1], sys.argv[2]
OUT = os.path.join(ROOT, "content", "materials", "network2", "fx")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(17)
S = 256

icons = json.load(open(os.path.join(GI, "icons.json")))
size = icons.get("width", 512)
body = icons["icons"]["lambda"]["body"].replace("currentColor", "#ffffff")
svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}">{body}</svg>'
shape = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=150, output_height=150))).split()[3]

mask = Image.new("L", (S, S), 0)
mask.paste(shape, ((S - 150) // 2, (S - 150) // 2 - 6), shape)
draw = ImageDraw.Draw(mask)
draw.ellipse((22, 16, S - 22, S - 28), outline=255, width=13)

# drips: from the lowest painted points down
a = np.asarray(mask).astype(np.float32) / 255
for _ in range(9):
    x = int(rng.integers(40, S - 40))
    column = np.nonzero(a[:, x] > 0.5)[0]
    if len(column) == 0:
        continue
    y0, length = column.max(), int(rng.integers(8, 34))
    width = int(rng.integers(2, 4))
    a[y0:min(S, y0 + length), x - width // 2:x + width // 2 + 1] = 1
    a[min(S - 1, y0 + length - 2):min(S, y0 + length + 2), x - width:x + width + 1] = 1

# the spray: soft edge, overspray dust, uneven cover
soft = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.6))).astype(np.float32) / 255
halo = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(7))).astype(np.float32) / 255
dust = (rng.random((S, S)) < halo * 0.35).astype(np.float32) * 0.6
cover = 0.82 + 0.18 * rng.random((S, S))
alpha = np.clip(soft * cover + dust * (1 - soft), 0, 1)

rgb = np.zeros((S, S, 3), np.float32)
rgb[..., 0], rgb[..., 1], rgb[..., 2] = 236, 120, 40
rgb *= (0.85 + 0.15 * rng.random((S, S)))[..., None]
im = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8)
Image.fromarray(im, "RGBA").save(os.path.join(OUT, "graffiti_lambda.png"), optimize=True)
print("graffiti written")
