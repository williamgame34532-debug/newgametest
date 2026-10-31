"""Preview the gamemode HUD (hlalyx/gamemode/cl_hud.lua) with PIL. usage: out bg WxH 'state json'"""
import sys, json
from PIL import Image, ImageDraw, ImageFont
from lupa import luajit21
out, bg, res, st = sys.argv[1], sys.argv[2], sys.argv[3], json.loads(sys.argv[4])
W, H = map(int, res.split('x'))
FONT = '/home/user/newgametest/hla_fabricator_content/resource/fonts/RobotoCondensed-%s.ttf'
s = min(W / 1920, H / 1080) * 0.66
F = {'hla_label': ImageFont.truetype(FONT % 'Bold', max(10, int(26 * s))), 'hla_value': ImageFont.truetype(FONT % 'Light' if False else FONT % 'Regular', max(14, int(44 * s))),
     'hla_big': ImageFont.truetype(FONT % 'Regular', max(20, int(92 * s))), 'hla_small': ImageFont.truetype(FONT % 'Regular', max(12, int(42 * s))),
     'hla_wep': ImageFont.truetype(FONT % 'Bold', max(16, int(30 * s)))}
img = Image.open(bg).convert('RGB').resize((W, H)); dr = ImageDraw.Draw(img, 'RGBA')
def col(c): return (int(c[1]), int(c[2]), int(c[3]), int(c[4]) if len(c) >= 4 else 255)
def rect(x, y, w, h, c): dr.rectangle([x, y, x + max(w, 1) - 1, y + max(h, 1) - 1], fill=col(c))
def size(t, f): b = F[f].getbbox(t); return b[2] - b[0], F[f].size
def text(t, f, x, y, c, ax=0, ay=0):
    fo = F[f]; w = fo.getlength(t); h = fo.size
    dr.text((x - (w / 2 if ax == 1 else w if ax == 2 else 0), y - (h / 2 if ay == 1 else h if ay == 2 else 0) - h * 0.1), t, font=fo, fill=col(c))
def vignette(c):
    r, g, b, a = col(c); d = int(H * 0.28)
    ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); px = ov.load()
    import math
    for y in range(0, H, 2):
        for x in range(0, W, 2):
            e = min(x, y, W - 1 - x, H - 1 - y)
            if e < d:
                k = int(a * (1 - e / d))
                for dx in (0, 1):
                    for dy in (0, 1):
                        if x + dx < W and y + dy < H: px[x + dx, y + dy] = (r, g, b, k)
    img.paste(Image.alpha_composite(img.convert('RGBA'), ov).convert('RGB'))
L = luajit21.LuaRuntime(unpack_returned_tuples=True)
L.execute('math.Clamp = function(x,a,b) return math.min(math.max(x,a),b) end file = {Exists = function() return false end}')
L.execute(open('/home/user/newgametest/hlalyx/gamemode/cl_hud.lua', encoding='utf-8').read())
D = L.table(rect=rect, size=size, text=text, vignette=vignette)
def tolua(v):
    if isinstance(v, dict): return L.table_from({k: tolua(x) for k, x in v.items()})
    if isinstance(v, list): return L.table_from([tolua(x) for x in v])
    return v
st.update(w=W, h=H, scale=s)
L.eval('HLA.Hud.Draw')(D, tolua(st))
img.save(out); print('ok', out)
