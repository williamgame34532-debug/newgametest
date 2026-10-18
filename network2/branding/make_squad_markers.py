"""The markers of the leader of a squad (sh_squadmarks.lua) -> materials/network2/squad/marker_<kind>.png
A frame of the Combine - a hexagon with cut corners and a thin inner ring, a notch at the bottom pointing at
the place - and the sign inside (Tabler Icons, MIT): move (an arrow down), attack (a crosshair), look (an
eye), danger (a triangle). White on transparent, 128 px, tinted when drawn.
    python make_squad_markers.py <@tabler/icons package dir> <network2 folder>"""
import io, math, os, sys
import cairosvg
from PIL import Image, ImageDraw, ImageFilter

TABLER, ROOT = sys.argv[1], sys.argv[2]
OUT = os.path.join(ROOT, "content", "materials", "network2", "squad")
SS, S = 4, 128
N = S * SS

KINDS = {"move": "arrow-big-down", "attack": "crosshair", "look": "eye", "danger": "alert-triangle"}


def hexagon(cx, cy, r):
    return [(cx + r * math.cos(math.radians(60 * i - 90)), cy + r * math.sin(math.radians(60 * i - 90))) for i in range(6)]


for kind, src in KINDS.items():
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy, r = N / 2, N * 0.45, N * 0.4
    white = (255, 255, 255, 255)

    # the dark plate inside, so the sign reads on anything
    d.polygon(hexagon(cx, cy, r * 0.92), fill=(0, 0, 0, 110))
    # the frame: a thick hexagon, the corners cut by short gaps
    pts = hexagon(cx, cy, r)
    for i in range(6):
        a, b = pts[i], pts[(i + 1) % 6]
        ax, ay = a[0] + (b[0] - a[0]) * 0.12, a[1] + (b[1] - a[1]) * 0.12
        bx, by = a[0] + (b[0] - a[0]) * 0.88, a[1] + (b[1] - a[1]) * 0.88
        d.line([(ax, ay), (bx, by)], fill=white, width=int(N * 0.05))
    # the thin inner ring
    d.polygon(hexagon(cx, cy, r * 0.78), outline=(255, 255, 255, 140), width=int(N * 0.012))
    # the notch pointing down at the place
    d.polygon([(cx - N * 0.07, cy + r * 0.98), (cx + N * 0.07, cy + r * 0.98), (cx, cy + r * 1.22)], fill=white)

    svg = open(os.path.join(TABLER, "icons", "outline", src + ".svg")).read()
    svg = svg.replace('stroke="currentColor"', 'stroke="#ffffff"').replace('stroke-width="2"', 'stroke-width="2.4"')
    size = int(r * 0.95)
    sign = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=size, output_height=size)))
    im.alpha_composite(sign.convert("RGBA"), (int(cx - size / 2), int(cy - size / 2)))

    # a soft glow under it all
    glow = im.split()[3].filter(ImageFilter.GaussianBlur(SS * 3)).point(lambda v: int(v * 0.5))
    base = Image.new("RGBA", (N, N), (255, 255, 255, 0))
    base.putalpha(glow)
    out = Image.alpha_composite(base, im).resize((S, S), Image.LANCZOS)
    out.save(os.path.join(OUT, "marker_" + kind + ".png"))
print("markers written")
