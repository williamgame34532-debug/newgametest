"""Render the addon's cl_ui.lua offline with PIL (same Lua, adapter implemented in Python).
usage: ui_render.py out.png 'ctx json'"""
import sys, json
from PIL import Image, ImageDraw, ImageFont
from lupa import luajit21
ADDON = '/home/user/newgametest/combine_fabricator/'
out, ctx = sys.argv[1], json.loads(sys.argv[2])
FONT = ADDON + 'resource/fonts/RobotoCondensed-%s.ttf'
SIZES = {'cfr_hdr': (26, 'Bold'), 'cfr_xs': (14, 'Regular'), 'cfr_xxs': (11, 'Regular'), 'cfr_s': (17, 'Bold'),
         'cfr_m': (22, 'Bold'), 'cfr_row': (21, 'Bold'), 'cfr_l': (32, 'Bold'), 'cfr_num': (42, 'Bold')}
F = {k: ImageFont.truetype(FONT % w, s) for k, (s, w) in SIZES.items()}
SS = 2  # supersample
img = Image.new('RGB', (1024 * SS, 512 * SS), (0, 0, 0))
dr = ImageDraw.Draw(img, 'RGBA')
FS = {k: ImageFont.truetype(FONT % w, s * SS) for k, (s, w) in SIZES.items()}
def col(c): return (int(c[1]), int(c[2]), int(c[3]), int(c[4]) if len(c) >= 4 else 255)
def rect(x, y, w, h, c):
    if w <= 0 or h <= 0: return
    dr.rectangle([x * SS, y * SS, (x + w) * SS - 1, (y + h) * SS - 1], fill=col(c))
def outline(x, y, w, h, c, t=1):
    t = t or 1
    for (a, b, cw, ch) in ((x, y, w, t), (x, y + h - t, w, t), (x, y, t, h), (x + w - t, y, t, h)): rect(a, b, cw, ch, c)
def line(x1, y1, x2, y2, c): dr.line([x1 * SS, y1 * SS, x2 * SS, y2 * SS], fill=col(c), width=SS)
def poly(pts, c):
    p = [(pts[i][1] * SS, pts[i][2] * SS) for i in range(1, len(pts) + 1)]
    dr.polygon(p, fill=col(c))
def size(s, font):
    b = F[font].getbbox(s); return b[2] - b[0], F[font].size
def text(s, font, x, y, c, ax=0, ay=0):
    f = FS[font]; w = f.getlength(s); h = F[font].size * SS
    X = x * SS - (w / 2 if ax == 1 else (w if ax == 2 else 0))
    Y = y * SS - (h / 2 if ay == 1 else (h if ay == 2 else 0))
    dr.text((X, Y - h * 0.08), s, font=f, fill=col(c))
L = luajit21.LuaRuntime(unpack_returned_tuples=True)
for f in ('sh_config.lua', 'sh_layout.lua', 'cl_ui.lua'):
    L.execute(open(ADDON + 'lua/cf_rework/' + f, encoding='utf-8').read())
D = L.table(rect=rect, outline=outline, line=line, poly=poly, size=size, text=text)
def tolua(v):
    if isinstance(v, dict): return L.table_from({k: tolua(x) for k, x in v.items()})
    if isinstance(v, list): return L.table_from([tolua(x) for x in v])
    return v
c = tolua(ctx)
L.eval('CFRework.UI.Draw')(D, c)
img = img.resize((1024, 512), Image.LANCZOS).convert('RGB')
img.save(out)
print('ok', out)
