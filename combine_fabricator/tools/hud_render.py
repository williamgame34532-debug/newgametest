"""Preview the gamemode HUD (cl_hud.lua) over a background image with PIL."""
import sys, json
from PIL import Image, ImageDraw, ImageFont
from lupa import luajit21
out, bg, st = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
W, H = 1920, 1080
FONT = '/home/user/newgametest/hla_fabricator_content/resource/fonts/RobotoCondensed-%s.ttf'
s = H / 1080
F = {'hla_label': ImageFont.truetype(FONT % 'Bold', int(24 * s)), 'hla_value': ImageFont.truetype(FONT % 'Regular', int(40 * s)),
     'hla_big': ImageFont.truetype(FONT % 'Regular', int(86 * s)), 'hla_small': ImageFont.truetype(FONT % 'Regular', int(40 * s)),
     'hla_wep': ImageFont.truetype(FONT % 'Bold', int(34 * s))}
img = Image.open(bg).convert('RGB').resize((W, H)); dr = ImageDraw.Draw(img, 'RGBA')
def col(c): return (int(c[1]), int(c[2]), int(c[3]), int(c[4]) if len(c) >= 4 else 255)
def rect(x, y, w, h, c): dr.rectangle([x, y, x + w - 1, y + h - 1], fill=col(c))
def size(t, f): b = F[f].getbbox(t); return b[2] - b[0], F[f].size
def text(t, f, x, y, c, ax=0, ay=0):
    fo = F[f]; w = fo.getlength(t); h = fo.size
    dr.text((x - (w / 2 if ax == 1 else w if ax == 2 else 0), y - (h / 2 if ay == 1 else h if ay == 2 else 0) - h * 0.1), t, font=fo, fill=col(c))
L = luajit21.LuaRuntime(unpack_returned_tuples=True)
L.execute('math.Clamp = function(x,a,b) return math.min(math.max(x,a),b) end')
L.execute(open('/home/user/newgametest/hlalyx/gamemode/cl_hud.lua', encoding='utf-8').read())
D = L.table(rect=rect, size=size, text=text)
def tolua(v):
    if isinstance(v, dict): return L.table_from({k: tolua(x) for k, x in v.items()})
    if isinstance(v, list): return L.table_from([tolua(x) for x in v])
    return v
st.update(w=W, h=H)
L.eval('HLA.Hud.Draw')(D, tolua(st))
img.save(out); print('ok')
