"""Item icons, block textures, armor layers and HUD overlays for Echoes of Sleep."""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw

from texlib import Canvas, Palette, hexc, faces, shade_face, value_noise, fbm

HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(HERE, '..', 'src', 'main', 'resources', 'assets', 'echoesofsleep', 'textures')


def out(sub, name):
    d = os.path.join(TEX, sub)
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, name + '.png')


# =========================================================================== sprite helpers
class Sprite:
    """16x16 icon: draw coloured shapes, then auto-outline and auto-shade (light from the top-left)."""

    def __init__(self, size=16):
        self.n = size
        self.c = np.zeros((size, size, 4), dtype=np.uint8)

    def put(self, x, y, col, a=255):
        if 0 <= x < self.n and 0 <= y < self.n:
            self.c[y, x, :3] = col[:3]
            self.c[y, x, 3] = a

    def filled(self, x, y):
        return 0 <= x < self.n and 0 <= y < self.n and self.c[y, x, 3] > 0

    def poly(self, pts, colfn):
        im = Image.new('L', (self.n, self.n), 0)
        ImageDraw.Draw(im).polygon(pts, fill=255)
        m = np.array(im)
        for y in range(self.n):
            for x in range(self.n):
                if m[y, x]:
                    self.put(x, y, colfn(x, y))

    def line(self, x0, y0, x1, y1, colfn, width=1):
        steps = max(abs(x1 - x0), abs(y1 - y0)) * 2 + 1
        for i in range(steps + 1):
            t = i / steps
            x, y = round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)
            for dx in range(width):
                self.put(x + dx, y, colfn(x + dx, y, t))

    def finish(self, outline, light=1.18, dark=0.72):
        n = self.n
        base = self.c.copy()
        filled = base[:, :, 3] > 0
        for y in range(n):
            for x in range(n):
                if not filled[y, x]:
                    continue
                up = y > 0 and filled[y - 1, x]
                left = x > 0 and filled[y, x - 1]
                down = y < n - 1 and filled[y + 1, x]
                right = x < n - 1 and filled[y, x + 1]
                f = 1.0
                if not up or not left:
                    f = light
                elif not down or not right:
                    f = dark
                if f != 1.0:
                    self.c[y, x, :3] = np.clip(base[y, x, :3] * f, 0, 255)
        for y in range(n):
            for x in range(n):
                if filled[y, x]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < n and 0 <= yy < n and filled[yy, xx]:
                        self.c[y, x, :3] = outline
                        self.c[y, x, 3] = 255
                        break

    def save(self, path):
        Image.fromarray(self.c, 'RGBA').save(path)


def grad(pal, lo=0.0, hi=1.0):
    p = Palette(*pal)
    return lambda x, y, t=None: p.pick(lo + (hi - lo) * (1 - (x + (15 - y)) / 30.0 if t is None else t), x, y, 0.4)


# =========================================================================== items
def dream_shard():
    s = Sprite()
    pal = Palette('#1d0f3d', '#3a1f7a', '#5b3cc4', '#7b6cf0', '#8fd0ff', '#d8f6ff')
    s.poly([(6, 14), (4, 10), (9, 1), (12, 3), (11, 9), (8, 14)], lambda x, y: pal.pick(0.25 + (14 - y) / 16 * 0.6, x, y))
    s.poly([(10, 14), (11, 10), (14, 7), (14, 12)], lambda x, y: pal.pick(0.3 + (14 - y) / 12 * 0.4, x, y))
    for (x, y) in ((8, 3), (8, 4), (7, 5), (7, 6), (7, 7), (6, 8), (6, 9)):
        s.put(x, y, pal.pick(0.92, x, y))
    s.finish(hexc('#0b0518'))
    for (x, y) in ((9, 2), (12, 9), (5, 11)):
        s.put(x, y, (255, 255, 255))
    s.save(out('item', 'dream_shard'))


def nightmare_heart():
    s = Sprite()
    pal = Palette('#14030a', '#3a0814', '#6a0f22', '#9a1a2e', '#c8303c', '#ef6a5a')
    cx = 7.5

    def col(x, y):
        d = math.hypot(x - 6, y - 7)
        return pal.pick(0.75 - d * 0.08, x, y)
    s.poly([(2, 6), (4, 3), (7, 4), (7.5, 5), (8, 4), (11, 3), (13, 6), (12, 10), (7.5, 14), (3, 10)], col)
    s.poly([(5, 1), (7, 1), (7, 4), (5, 4)], lambda x, y: pal.pick(0.3, x, y))
    s.poly([(9, 0), (11, 0), (11, 3), (9, 3)], lambda x, y: pal.pick(0.45, x, y))
    s.finish(hexc('#080104'))
    for (x, y) in ((4, 6), (5, 7), (5, 8), (6, 9), (9, 6), (10, 7), (10, 8), (8, 10)):
        s.put(x, y, hexc('#4a1f6a'))  # violet veins
    for y in range(5, 12):  # a stitched seam down the middle
        s.put(7, y, hexc('#2a0510'))
        if y % 2:
            s.put(6, y, hexc('#b8a080'))
            s.put(8, y, hexc('#8a7060'))
    s.put(5, 5, hexc('#ffb0a0'))
    s.save(out('item', 'nightmare_heart'))


def dawn_tincture():
    s = Sprite()
    glass = Palette('#5a6a8a', '#9ab0d0', '#d8e8ff')
    liquid = Palette('#8a2a3a', '#d8503a', '#ff9a4a', '#ffd27a', '#fff2c0')
    s.poly([(6, 1), (9, 1), (9, 3), (6, 3)], lambda x, y: hexc('#7a5a3a') if (x + y) % 2 else hexc('#9a7a52'))
    s.poly([(7, 3), (8, 3), (8, 5), (7, 5)], lambda x, y: glass.pick(0.5, x, y))
    im = Image.new('L', (16, 16), 0)
    ImageDraw.Draw(im).ellipse((3, 5, 12, 14), fill=255)
    m = np.array(im)
    for y in range(16):
        for x in range(16):
            if m[y, x]:
                if y >= 8:
                    s.put(x, y, liquid.pick(0.85 - (y - 8) * 0.11 + (0.1 if x < 7 else 0), x, y))
                else:
                    s.put(x, y, glass.pick(0.55, x, y), 170)
    s.finish(hexc('#1a1420'))
    s.put(5, 7, (255, 255, 255))
    s.put(5, 8, (240, 240, 255))
    for (x, y) in ((7, 10), (9, 12)):
        s.put(x, y, hexc('#fffbe0'))
    s.save(out('item', 'dawn_tincture'))


def outline_only(s, col):
    """Dark 1px outline around the sprite, no automatic shading (for hand-shaded icons)."""
    n = s.n
    filled = s.c[:, :, 3] > 0
    for y in range(n):
        for x in range(n):
            if filled[y, x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < n and 0 <= yy < n and filled[yy, xx] and s.c[yy, xx, 3] == 255:
                    s.c[y, x, :3] = col
                    s.c[y, x, 3] = 255
                    break


def dawn_ingot():
    s = Sprite()
    top = Palette('#f8d040', '#ffe46a', '#fff1a0', '#fffad8')
    front = Palette('#a86808', '#c98a10', '#e8b020', '#f8cc48', '#ffe2a0', '#ffeee6')
    side = Palette('#6e3e06', '#8a5208', '#a86a10')
    # a metallic bar: thin top facet, golden front that warms into pale dawn at its right end
    s.poly([(1, 9), (4, 6), (14, 6), (11, 9)], lambda x, y: top.pick(0.3 + (x - 1) * 0.05, x, y, 0.3))
    s.poly([(1, 9), (11, 9), (11, 11), (1, 11)], lambda x, y: front.pick(0.25 + (x - 1) * 0.075 - (y - 9) * 0.12, x, y, 0.3))
    s.poly([(11, 9), (14, 6), (14, 8), (11, 11)], lambda x, y: side.pick(0.6 - (y - 6) * 0.08, x, y, 0.3))
    for x in range(4, 14):
        if s.filled(x, 6):
            s.put(x, 6, hexc('#fffef0'))
    outline_only(s, hexc('#3e2204'))
    s.put(1, 11, hexc('#f2a49a'))  # a touch of dawn-pink rim light
    s.put(2, 12, hexc('#e8807a'))
    for x in (3, 4):
        s.put(x, 9, (255, 255, 240))  # specular glint on the front edge
    s.save(out('item', 'dawn_ingot'))

def dream_totem():
    s = Sprite()
    stone = Palette('#0a0612', '#160e26', '#24183c', '#352656', '#4a3874', '#625096')
    gold = Palette('#5a3a0a', '#a8761c', '#e8b84a', '#fff0a0')
    # head (rounded), carved face, narrow neck, body, gold band, base
    s.poly([(5, 2), (10, 2), (11, 3), (11, 7), (10, 8), (5, 8), (4, 7), (4, 3)], lambda x, y: stone.pick(0.75 - (x - 4) * 0.06 - (y - 2) * 0.03, x, y, 0.3))
    s.poly([(6, 8), (9, 8), (9, 9), (6, 9)], lambda x, y: stone.pick(0.3, x, y))
    s.poly([(4, 9), (11, 9), (12, 13), (3, 13)], lambda x, y: stone.pick(0.65 - (x - 3) * 0.05 - (y - 9) * 0.04, x, y, 0.3))
    s.poly([(2, 13), (13, 13), (13, 14), (2, 14)], lambda x, y: gold.pick(0.55 - (x - 2) * 0.03, x, y))
    for x in range(4, 12):
        s.put(x, 11, gold.pick(0.75 if x < 8 else 0.45, x, 11))
    outline_only(s, hexc('#05020a'))
    for (x, y) in ((5, 5), (6, 5), (9, 5), (10, 5)):  # carved slit eyes
        s.put(x, y, hexc('#05020a'))
    for x in range(6, 10):  # carved mouth
        s.put(x, 7, hexc('#0a0412'))
    s.put(7, 3, hexc('#fff0ff'))  # the glowing third eye on top
    s.put(8, 3, hexc('#c080ff'))
    s.put(7, 2, hexc('#7a40c0'))
    s.put(8, 2, hexc('#7a40c0'))
    s.put(4, 4, hexc('#7a6aa8'))
    s.save(out('item', 'dream_totem'))


def _blade_mask(x0, y0, x1, y1, w0, w1):
    """Pixels of a tapered diagonal band; returns {(x, y): (t along, side)}"""
    res = {}
    ax, ay = x1 - x0, y1 - y0
    L = math.hypot(ax, ay)
    ux, uy = ax / L, ay / L
    for y in range(16):
        for x in range(16):
            px, py = x + 0.5 - x0, y + 0.5 - y0
            t = (px * ux + py * uy) / L
            d = px * -uy + py * ux
            if 0 <= t <= 1:
                hw = w0 + (w1 - w0) * t
                if abs(d) <= hw:
                    res[(x, y)] = (t, d)
    return res


def dawn_blade():
    s = Sprite()
    blade = Palette('#c0802a', '#e8a840', '#ffd070', '#ffe8b0', '#fff6e0', '#ffffff')
    for (x, y), (t, d) in _blade_mask(4.6, 11.4, 14.6, 1.4, 1.35, 0.55).items():
        v = 0.3 + t * 0.7
        if d < -0.35:
            v += 0.25  # bright cutting edge (upper-left side)
        elif d > 0.45:
            v -= 0.22  # shaded back of the blade
        s.put(x, y, blade.pick(v, x, y, 0.2))
    gold = Palette('#6a3a0a', '#b07a22', '#f3c45a', '#fff2b0')
    for i, (x, y) in enumerate(((1, 9), (2, 10), (3, 11), (4, 12), (5, 13), (2, 9), (5, 12), (3, 10), (6, 13))):
        s.put(x, y, gold.pick(0.75 if i < 5 else 0.45, x, y))
    for (x, y) in ((3, 12), (2, 13)):
        s.put(x, y, hexc('#4a2040'))
    s.put(3, 13, hexc('#2a1024'))
    s.put(1, 14, gold.pick(0.8, 1, 14))
    s.put(0, 15, gold.pick(0.4, 0, 15))
    outline_only(s, hexc('#2a1006'))
    s.put(3, 11, hexc('#ff4a7a'))  # the gem in the crossguard
    s.put(4, 11, hexc('#ffb0c8'))
    for i in range(3, 10, 3):
        x, y = 5 + i, 10 - i
        s.put(x - 1, y, (255, 255, 255))
    s.put(14, 1, (255, 255, 255))
    s.save(out('item', 'dawn_blade'))


def echo_scythe():
    s = Sprite()
    blade = Palette('#0a1a4a', '#12307a', '#1a52b0', '#2a86d8', '#5ac4f0', '#a8ecff', '#ffffff')
    bone = Palette('#4a3e2e', '#8a7a5e', '#c8b894', '#ece2c8')
    # 2px bone handle, segmented
    for (x, y), (t, d) in _blade_mask(1.5, 15.0, 11.5, 4.0, 0.95, 0.95).items():
        seg = int(t * 12) % 4 == 0
        s.put(x, y, bone.pick(0.15 if seg else (0.85 if d < 0 else 0.5), x, y, 0.2))
    # crescent blade: inside the outer circle, outside the inner one, above the handle head
    pix = []
    for y in range(16):
        for x in range(16):
            cx, cy = x + 0.5, y + 0.5
            d1 = math.hypot(cx - 7.0, cy - 8.0)
            d2 = math.hypot(cx - 7.6, cy - 10.6)
            if d1 <= 7.0 and d2 >= 7.3 and cy <= 7.5 and cx <= 12.5:
                pix.append((x, y, 7.0 - d1))
    for x, y, edge in pix:  # ghost afterimage one frame behind
        if not s.filled(x - 1, y + 1):
            s.put(x - 1, y + 1, hexc('#6ab8ff'), 90)
    for x, y, edge in pix:
        v = 0.85 - edge * 0.3
        s.put(x, y, blade.pick(v, x, y, 0.2))
    outline_only(s, hexc('#050a1e'))
    for x, y, edge in pix:
        if edge < 0.7:
            s.put(x, y, hexc('#e8fbff'))  # bright cutting edge
    s.put(11, 3, bone.pick(0.9, 11, 3))
    s.save(out('item', 'echo_scythe'))



def insomnia_lantern():
    s = Sprite()
    iron = Palette('#1a1a22', '#33333f', '#55556a', '#8a8aa0')
    flame = Palette('#0a4a5a', '#1a9ab0', '#5ae0f0', '#c8fbff', '#ffffff')
    s.poly([(7, 0), (8, 0), (8, 1), (7, 1)], lambda x, y: iron.pick(0.6, x, y))
    s.poly([(5, 2), (10, 2), (11, 4), (4, 4)], lambda x, y: iron.pick(0.5, x, y))
    s.poly([(4, 4), (11, 4), (11, 12), (4, 12)], lambda x, y: flame.pick(0.15, x, y))
    for y in range(5, 12):
        for x in range(5, 11):
            d = math.hypot((x - 7.5) * 1.3, (y - 8.5) * 0.8)
            s.put(x, y, flame.pick(0.95 - d * 0.22, x, y))
    s.poly([(4, 12), (11, 12), (11, 14), (4, 14)], lambda x, y: iron.pick(0.45, x, y))
    for y in range(4, 13):
        s.put(4, y, iron.pick(0.55, 4, y))
        s.put(11, y, iron.pick(0.35, 11, y))
    s.finish(hexc('#08080c'))
    for (x, y, c) in ((7, 8, '#04121a'), (8, 8, '#04121a'), (6, 8, '#2ab0c0'), (9, 8, '#2ab0c0')):
        s.put(x, y, hexc(c))  # an open eye in the flame
    s.save(out('item', 'insomnia_lantern'))


def lullaby_staff():
    s = Sprite()
    wood = Palette('#1a0a24', '#3a1a4a', '#5a2e6e', '#7a4a8e')
    moon = Palette('#8a6a1a', '#d8b04a', '#fff0a0', '#fffde8')
    s.line(2, 14, 10, 6, lambda x, y, t: wood.pick(0.4 + t * 0.3, x, y))
    im = Image.new('L', (16, 16), 0)
    d = ImageDraw.Draw(im)
    d.ellipse((9, 0, 15, 6), fill=255)
    d.ellipse((11, 0, 16, 4), fill=0)
    m = np.array(im)
    for y in range(16):
        for x in range(16):
            if m[y, x]:
                s.put(x, y, moon.pick(0.4 + (6 - y) * 0.09, x, y))
    s.finish(hexc('#0a0410'))
    for (x, y, c) in ((13, 6, '#9ad8ff'), (14, 7, '#9ad8ff'), (14, 8, '#5aa0e0'), (12, 8, '#9ad8ff'), (12, 9, '#9ad8ff'), (11, 9, '#5aa0e0')):
        s.put(x, y, hexc(c))  # a drifting note
    s.put(10, 3, (255, 255, 255))
    s.save(out('item', 'lullaby_staff'))


# =========================================================================== armor icons
ICON = {
    'helmet': [
        '                ', '                ', '                ',
        '    oooooooo    ',
        '   ohhhhbbbbo   ',
        '  ohhbbbeebbso  ',
        '  ohbbbeggebso  ',
        '  ohbbbbeebbso  ',
        '  obbbbbbbbbso  ',
        '  obbsoooosbso  ',
        '  obso    osbo  ',
        '  osso    osso  ',
        '  oooo    oooo  ',
        '                ', '                ', '                '],
    'chestplate': [
        '                ',
        '  ooo      ooo  ',
        ' ohhbo    obbso ',
        'ohhbbboooobbbbso',
        'ohbbbbbbbbbbbbso',
        'ohbbbbbeebbbbbso',
        'oobbbbeggebbbsoo',
        ' obbbbbeebbbbso ',
        ' obbbbbbbbbbbso ',
        ' obbbbbbbbbbbso ',
        ' obbbbbbbbbbbso ',
        ' obbbbbbbbbbsso ',
        ' osssssssssssso ',
        ' oooooooooooooo ',
        '                ', '                '],
    'leggings': [
        '                ', '                ',
        '  oooooooooooo  ',
        '  ohbbbeebbbso  ',
        '  ohbbbbbbbbso  ',
        '  ohbbbsobbbso  ',
        '  ohbbso obbso  ',
        '  ohbbo  obbso  ',
        '  ohbbo  obbso  ',
        '  ohbso  obsso  ',
        '  ohbso  obsso  ',
        '  ohbso  obsso  ',
        '  oeeeo  oeeeo  ',
        '  ooooo  ooooo  ',
        '                ', '                '],
    'boots': [
        '                ', '                ', '                ', '                ',
        '                ',
        '  ooooo  ooooo  ',
        '  oeeeo  oeeeo  ',
        '  ohbso  ohbso  ',
        '  ohbso  ohbso  ',
        '  ohbso  ohbso  ',
        ' oohbso  ohbsoo ',
        'ohhhbso  ohbbsso',
        'ohbbbso  ohbbbso',
        'oeeeeeo  oeeeeeo',
        'ooooooo  ooooooo',
        '                '],
}
SETS = {
    'dreamcatcher': dict(o='#0d0b1f', h='#6a74c8', b='#343080', s='#1b1844', e='#c8d0ff', g='#7ff5ff', pal=Palette('#0d0b1f', '#1b1844', '#262260', '#343080', '#4a4ca4', '#6a74c8', '#9aa4e8')),
    'wakeful': dict(o='#3a2207', h='#fff1b0', b='#e0b84a', s='#a5741e', e='#ff8a5c', g='#fffbe0', pal=Palette('#3a2207', '#7a4e12', '#a5741e', '#cf9a32', '#e0b84a', '#f6d878', '#fff1b0')),
    'nightmare_eater': dict(o='#0c0306', h='#a24c5c', b='#541c28', s='#2a0c14', e='#e6dcc4', g='#ff3040', pal=Palette('#1c070c', '#2a0c14', '#3c121c', '#541c28', '#6c2836', '#883848', '#a24c5c')),
}


def armor_icon(set_name, piece):
    st = SETS[set_name]
    img = np.zeros((16, 16, 4), dtype=np.uint8)
    rng = random.Random(hash((set_name, piece)) & 0xffff)
    for y, row in enumerate(ICON[piece]):
        for x, ch in enumerate(row):
            if ch == ' ':
                continue
            col = hexc(st[ch]) if ch in st else hexc(st['b'])
            if ch == 'b':
                col = st['pal'].pick(0.5 + (rng.random() - 0.5) * 0.25, x, y)
            img[y, x, :3] = col
            img[y, x, 3] = 255
    # set-specific details
    if set_name == 'dreamcatcher':
        for (x, y) in {'helmet': [(3, 11), (12, 11), (3, 12), (12, 12)], 'chestplate': [(2, 3), (13, 3), (7, 10), (8, 11)],
                       'leggings': [(4, 6), (11, 6)], 'boots': [(3, 10), (12, 10)]}[piece]:
            img[y, x, :3] = hexc('#e8f0ff')  # beads / feather tips
    elif set_name == 'wakeful':
        for (x, y) in {'helmet': [(7, 3), (8, 3)], 'chestplate': [(5, 5), (10, 5), (7, 8), (8, 8)],
                       'leggings': [(7, 4)], 'boots': [(2, 12), (13, 12)]}[piece]:
            img[y, x, :3] = hexc('#ff6f91')  # dawn rays
    else:
        rows = {'helmet': [(4, 9), (6, 9), (9, 9), (11, 9)], 'chestplate': [(4, 4), (11, 4), (5, 9), (10, 9), (6, 11), (9, 11)],
                'leggings': [(4, 12), (11, 12)], 'boots': [(1, 13), (3, 13), (12, 13), (14, 13)]}[piece]
        for (x, y) in rows:
            img[y, x, :3] = hexc('#e8dcc0')  # teeth / bone studs
    Image.fromarray(img, 'RGBA').save(out('item', f'{set_name}_{piece}'))


# =========================================================================== armor layers (64x32)
ARMOR_PAL = {
    'dreamcatcher': Palette('#0a0820', '#141235', '#1f1c4f', '#2c2a6c', '#3d3d8c', '#5458ae', '#7a82cc', '#a8b2ea'),
    'wakeful': Palette('#4a2a06', '#7a4a0c', '#a8701a', '#d09a2c', '#eabf4a', '#f8dc78', '#fff0b0', '#fffbe8'),
    'nightmare_eater': Palette('#16050a', '#280a12', '#3c121c', '#541c28', '#6c2836', '#883848', '#a24c5c', '#bc6676'),
}
ACCENT = {'dreamcatcher': hexc('#d8e0ff'), 'wakeful': hexc('#ff7a5a'), 'nightmare_eater': hexc('#e6dcc4')}
GLOW = {'dreamcatcher': hexc('#7ff5ff'), 'wakeful': hexc('#fffbe8'), 'nightmare_eater': hexc('#ff3040')}
CLEAR = (0, 0, 0)


def armor_layers(set_name):
    pal = ARMOR_PAL[set_name]
    acc, glow = ACCENT[set_name], GLOW[set_name]
    rng = random.Random(len(set_name) * 977)
    l1, l2 = Canvas(64, 32), Canvas(64, 32)
    gold = set_name == 'wakeful'

    def plate(cv, rect, top=0.72, bottom=0.42, seams=(), rivets=True, rows=None):
        """A bevelled plate: light top/left edge, dark bottom/right edge, 1px seams with a highlight under them."""
        x0, y0, w, h = rect
        for y in range(h):
            if rows is not None and not (rows[0] <= y < rows[1]):
                for x in range(w):
                    cv.put(x0 + x, y0 + y, CLEAR, 0)
                continue
            for x in range(w):
                f = y / max(1, h - 1)
                v = top + (bottom - top) * f + (rng.random() - 0.5) * (0.05 if gold else 0.09)
                if gold:  # polished: a bright diagonal sheen band
                    v += 0.16 * max(0.0, 1 - abs((x - y * 0.4) - w * 0.25) / 1.5)
                cv.put(x0 + x, y0 + y, pal.pick(v, x0 + x, y0 + y, 0.25))
        lo, hi = (rows if rows else (0, h))
        for x in range(w):
            lighten(cv, x0 + x, y0 + lo, 0.3)
            cv.darken(x0 + x, y0 + hi - 1, 0.55)
        for y in range(lo, hi):
            lighten(cv, x0, y0 + y, 0.15)
            cv.darken(x0 + w - 1, y0 + y, 0.65)
        for sy in seams:
            if lo <= sy < hi:
                for x in range(w):
                    cv.darken(x0 + x, y0 + sy, 0.62)
                    if sy + 1 < hi:
                        lighten(cv, x0 + x, y0 + sy + 1, 0.15)
                if rivets and w >= 4:
                    for rx in (1, w - 2):
                        cv.put(x0 + rx, y0 + sy - 1, pal.pick(0.98, 0, 0))
                        cv.darken(x0 + rx, y0 + sy, 0.3)

    def plates(cv, box, **kw):
        fs = faces(*box)
        for fname, rect in fs.items():
            if fname in ('top', 'bottom'):
                if kw.get('rows') is not None and fname == 'top' and kw['rows'][0] > 0:
                    for y in range(rect[3]):
                        for x in range(rect[2]):
                            cv.put(rect[0] + x, rect[1] + y, CLEAR, 0)
                    continue
                plate(cv, rect, top=0.7, bottom=0.55, rivets=False)
            else:
                plate(cv, rect, **kw)
        return fs

    def lighten(cv, x, y, f):
        if 0 <= x < cv.w and 0 <= y < cv.h and cv.a[y, x, 3]:
            c = cv.a[y, x, 0:3].astype(float)
            cv.a[y, x, 0:3] = (c + (255 - c) * f).clip(0, 255).astype(np.uint8)

    # ------------------------------------------------------------ helmet: brow ridge, visor opening, cheek plates
    head = plates(l1, (0, 0, 8, 8, 8), seams=(), rivets=False)
    fx, fy, fw, fh = head['front']
    for x in range(fw):
        lighten(l1, fx + x, fy + 1, 0.35)  # raised brow ridge
        l1.darken(fx + x, fy + 2, 0.5)
    for y in range(3, 7):
        for x in range(1, 7):
            l1.put(fx + x, fy + y, CLEAR, 0)
    tx, ty, tw, th = head['top']
    for y in range(th):  # crest down the middle of the helmet
        l1.put(tx + 3, ty + y, pal.pick(0.95, 0, y))
        l1.put(tx + 4, ty + y, pal.pick(0.55, 1, y))
    if set_name == 'dreamcatcher':
        for (x, y) in ((3, 0), (4, 0), (2, 1), (5, 1)):
            l1.put(fx + x, fy + y, acc)
        l1.put(fx + 3, fy + 1, glow)
        l1.put(fx + 4, fy + 1, glow)
        for side in ('left', 'right'):  # feathers hanging past the ears
            x0, y0, w, h = head[side]
            for y in range(3, 8):
                l1.put(x0 + 3, y0 + y, hexc('#f0f2ff') if y % 2 else hexc('#b8bce0'))
                l1.put(x0 + 4, y0 + y, hexc('#7880b0'))
            l1.put(x0 + 3, y0 + 2, acc)
    elif set_name == 'wakeful':
        for (x, y) in ((3, 0), (4, 0), (2, 0), (5, 0), (1, 1), (6, 1)):  # sunburst crest on the brow
            l1.put(fx + x, fy + y, acc if (x + y) % 2 else hexc('#ffb08a'))
        l1.put(fx + 3, fy + 1, glow)
        l1.put(fx + 4, fy + 1, glow)
        for x in (0, 7):
            for y in range(3, 7):
                l1.put(fx + x, fy + y, pal.pick(0.9, x, y))  # polished cheek guards
    else:
        for x in range(1, 7):  # the visor is a mouth: teeth above and below
            if x % 2:
                l1.put(fx + x, fy + 3, hexc('#f0e6d0'))
                l1.put(fx + x, fy + 6, hexc('#d8cdb2'))
            else:
                l1.put(fx + x, fy + 3, CLEAR, 0)
        l1.put(fx + 2, fy + 1, glow)
        l1.put(fx + 5, fy + 1, glow)
        for side in ('left', 'right'):  # jaw hinges
            x0, y0, w, h = head[side]
            for y in range(4, 8):
                l1.put(x0 + (w - 2 if side == 'right' else 1), y0 + y, hexc('#e6dcc4'))
    # ------------------------------------------------------------ chestplate: breastplate, segmented abdomen, belt
    body = plates(l1, (16, 16, 8, 12, 4), seams=(7,))
    bx, by, bw, bh = body['front']
    cx, cy = bx + 3, by + 3
    if set_name == 'dreamcatcher':
        ring = [(0, -3), (1, -3), (2, -2), (2, -1), (2, 0), (2, 1), (1, 2), (0, 2), (-1, 1), (-1, 0), (-1, -1), (-1, -2)]
        for dx, dy in ring:
            l1.put(cx + dx, cy + dy, acc)
        for dx, dy in ((0, -1), (1, 0), (0, 1), (1, -1)):
            l1.put(cx + dx, cy + dy, hexc('#8a92d8'))
        l1.put(cx, cy, glow)
        l1.put(cx + 1, cy - 1, glow)
        for y in range(3, 6):  # beads and feathers hanging from the hoop
            l1.put(cx - 1, cy + y, hexc('#f0f2ff') if y % 2 else hexc('#9aa0d0'))
            l1.put(cx + 2, cy + y, hexc('#d0d4f8') if y % 2 else hexc('#7880b0'))
    elif set_name == 'wakeful':
        for dx in range(0, 2):
            for dy in range(0, 2):
                l1.put(cx + dx, cy + dy, glow)
        rays = [(-2, 0), (3, 0), (-2, 1), (3, 1), (0, -2), (1, -2), (0, 3), (1, 3), (-1, -1), (2, -1), (-1, 2), (2, 2), (-3, -2), (4, -2), (-3, 3), (4, 3)]
        for i, (dx, dy) in enumerate(rays):
            l1.put(cx + dx, cy + dy, acc if i < 12 else hexc('#ffb08a'))
    else:
        for k in range(3):  # ribcage over a burning core
            y = by + 1 + k * 2
            for x in range(bx + 1, bx + bw - 1):
                if x not in (cx, cx + 1):
                    l1.put(x, y, hexc('#ece2ca') if (x - bx) % 6 not in (0, 5) else hexc('#b8ac90'))
        for y in range(by + 1, by + 7):
            l1.put(cx, y, hexc('#f4ead4'))
            l1.put(cx + 1, y, hexc('#d0c4a8'))
        l1.put(cx, by + 4, glow)
        l1.put(cx + 1, by + 4, glow)
    for side in ('front', 'back', 'left', 'right'):  # belt
        x0, y0, w, h = body[side]
        for x in range(w):
            l1.put(x0 + x, y0 + h - 1, acc if x % 3 else glow if set_name != 'wakeful' else hexc('#ffd27a'))
    # ------------------------------------------------------------ arms: pauldron + bracer
    arm = plates(l1, (40, 16, 4, 12, 4), seams=(4,), rows=(0, 9), rivets=False)
    for side in ('front', 'back', 'left', 'right'):
        x0, y0, w, h = arm[side]
        for x in range(w):
            lighten(l1, x0 + x, y0 + 1, 0.3)  # rounded pauldron
            l1.put(x0 + x, y0 + 8, acc if set_name != 'nightmare_eater' else hexc('#ff3040'))
    if set_name == 'nightmare_eater':
        for side in ('front', 'back', 'right'):
            x0, y0, w, h = arm[side]
            l1.put(x0 + 1, y0, hexc('#f0e6d0'))  # shoulder spikes
            l1.put(x0 + 2, y0, hexc('#f0e6d0'))
    # ------------------------------------------------------------ boots (layer 1 legs, rows 7-11)
    boot = plates(l1, (0, 16, 4, 12, 4), seams=(), rows=(7, 12))
    x0, y0, w, h = boot['front']
    for x in range(w):
        lighten(l1, x0 + x, y0 + 10, 0.3)  # toe cap
        l1.put(x0 + x, y0 + 7, acc)
    if set_name == 'nightmare_eater':
        for x in range(w):
            l1.put(x0 + x, y0 + 11, hexc('#f0e6d0') if x % 2 == 0 else hexc('#16050a'))
    # ------------------------------------------------------------ leggings (layer 2): faulds + thigh, knee, shin
    waist = plates(l2, (16, 16, 8, 12, 4), seams=(), rows=(7, 12))
    for side in ('front', 'back', 'left', 'right'):
        x0, y0, w, h = waist[side]
        for x in range(w):
            l2.put(x0 + x, y0 + 7, acc if x % 2 else glow)
    legs = plates(l2, (0, 16, 4, 12, 4), seams=(4,), rows=(0, 11), rivets=False)
    for side in ('front', 'left', 'right'):
        x0, y0, w, h = legs[side]
        for x in range(w):
            lighten(l2, x0 + x, y0 + 5, 0.35)  # raised knee plate
        if side == 'front':
            l2.put(x0 + 1, y0 + 5, glow)
            l2.put(x0 + 2, y0 + 5, glow)
    if set_name == 'dreamcatcher':
        for side in ('left', 'right'):  # feathers tied to the thighs
            x0, y0, w, h = legs[side]
            for y in range(1, 6):
                l2.put(x0 + 1, y0 + y, hexc('#f0f2ff') if y % 2 else hexc('#b8bce0'))
                l2.put(x0 + 2, y0 + y, hexc('#7880b0'))
            l2.put(x0 + 1, y0 + 6, acc)
    l1.save(out('models/armor', f'{set_name}_layer_1'))
    l2.save(out('models/armor', f'{set_name}_layer_2'))


# =========================================================================== blocks
STONE = Palette('#5e5e5e', '#6a6a6a', '#747474', '#7f7f7f', '#8a8a8a', '#969696')
DEEPSLATE = Palette('#1f1f25', '#29292f', '#323239', '#3c3c44', '#47474f', '#53535b')
CRYSTAL = Palette('#1b0c3a', '#33186e', '#5232b0', '#7462e6', '#8fb8ff', '#c8f2ff', '#ffffff')


def stone_base(seed):
    """Vanilla-like stone: soft low-contrast blotches around #7f7f7f."""
    rng = random.Random(seed)
    n = fbm(16, 16, rng, cells=(3, 2, 1), weights=(0.5, 0.3, 0.2))
    cv = Canvas(16, 16)
    for y in range(16):
        for x in range(16):
            cv.put(x, y, STONE.pick(0.25 + n[y, x] * 0.6, x, y, 0.3))
    return cv, rng


def deepslate_base(seed):
    """Deepslate: dark, with horizontal strata."""
    rng = random.Random(seed)
    n = fbm(16, 16, rng, cells=(4, 2, 1))
    band = [rng.random() for _ in range(16)]
    cv = Canvas(16, 16)
    for y in range(16):
        for x in range(16):
            v = 0.35 + (band[y] - 0.5) * 0.35 + (n[y, x] - 0.5) * 0.25
            cv.put(x, y, DEEPSLATE.pick(v, x, y, 0.25))
        if band[y] < 0.25:  # thin dark seams between layers
            for x in range(16):
                if rng.random() < 0.7:
                    cv.darken(x, y, 0.8)
    return cv, rng


CLUSTERS = [
    [(0, 0), (1, 0), (0, 1)],
    [(0, 0), (1, -1), (1, 0), (2, -1), (0, 1)],
    [(0, 0), (0, -1), (1, -2), (1, -1), (2, -2), (-1, 1), (0, 1)],
    [(0, 0), (1, 0)],
    [(0, 0), (1, 1), (0, 1), (1, 0), (2, 1), (2, 0)],
]


def ore(name, base, seed):
    cv, rng = base(seed)
    spots = [(3, 4), (11, 2), (6, 10), (12, 11), (1, 13)]
    for i, (cx, cy) in enumerate(spots):
        shape = CLUSTERS[(i + seed) % len(CLUSTERS)]
        for (dx, dy) in shape:  # shadow first, down-right
            cv.darken((cx + dx + 1) % 16, (cy + dy + 1) % 16, 0.55)
        for (dx, dy) in shape:
            x, y = (cx + dx) % 16, (cy + dy) % 16
            v = 0.55 - (dx + dy) * 0.08 + rng.random() * 0.1
            cv.put(x, y, CRYSTAL.pick(v, x, y, 0.2))
        tx, ty = (cx + shape[-1][0]) % 16, (cy + shape[-1][1]) % 16
        cv.put(cx % 16, cy % 16, CRYSTAL.pick(0.95, 0, 0))
        cv.put(tx, ty, CRYSTAL.pick(0.3, 0, 0))
    cv.save(out('block', name))


DIRT = Palette('#4a3221', '#593d29', '#6c4b31', '#79553a', '#866043', '#966c4a', '#a8794f')
ASH = Palette('#2c2a2c', '#3c393b', '#504d4f', '#686466', '#827e7e', '#9c9897', '#b8b3b0', '#d0cbc6')


def ashen_grass():
    rng = random.Random(81)
    top = Canvas(16, 16)
    n = fbm(16, 16, rng, cells=(3, 2, 1))
    for y in range(16):
        for x in range(16):
            top.put(x, y, ASH.pick(0.3 + n[y, x] * 0.55, x, y, 0.3))
    for _ in range(14):  # dead, burnt blades lying flat
        x, y = rng.randrange(16), rng.randrange(15)
        top.put(x, y, ASH.pick(0.1, x, y))
        top.put(x, y + 1, ASH.pick(0.22, x, y))
        top.put(x, (y + 2) % 16, ASH.pick(0.8, x, y))
    for _ in range(5):  # still-glowing embers
        x, y = rng.randrange(16), rng.randrange(16)
        top.put(x, y, hexc('#ff7a2a') if rng.random() < 0.5 else hexc('#c8401a'))
    top.save(out('block', 'ashen_grass_top'))
    side = Canvas(16, 16)
    n2 = fbm(16, 16, rng, cells=(3, 2, 1))
    for y in range(16):
        for x in range(16):
            side.put(x, y, DIRT.pick(0.2 + n2[y, x] * 0.6, x, y, 0.3))
    for x in range(16):  # ash crust with uneven drips running down
        depth = 2 + rng.randint(0, 1)
        if rng.random() < 0.35:
            depth += rng.randint(2, 5)
        for y in range(depth):
            v = 0.72 - y * 0.09 + rng.random() * 0.08
            side.put(x, y, ASH.pick(v, x, y, 0.2))
        side.darken(x, depth, 0.7)
    side.save(out('block', 'ashen_grass_side'))


def dreamrot():
    """Animated fleshy block: pulsing flesh, dark vein lines, eyes that slowly open and blink."""
    rng = random.Random(1337)
    flesh = Palette('#1a040c', '#330818', '#4e1024', '#6a1a32', '#882844', '#a63c56', '#c8606e', '#e8949a')
    n = fbm(16, 16, rng, cells=(4, 2, 1))
    veins = []
    for _ in range(5):
        x, y = rng.randrange(16), rng.randrange(16)
        line = []
        for _ in range(14):
            line.append((x % 16, y % 16))
            x += rng.choice((-1, 0, 1, 1))
            y += rng.choice((0, 1, 1))
        veins.append(line)
    eyes = [(3, 3, 0), (11, 5, 1), (6, 11, 2), (13, 13, 3), (1, 8, 1)]
    frames = Image.new('RGBA', (16, 64))
    for f in range(4):
        cv = Canvas(16, 16)
        pulse = math.sin(f / 4 * math.pi * 2) * 0.5 + 0.5
        for y in range(16):
            for x in range(16):
                cv.put(x, y, flesh.pick(0.25 + n[y, x] * 0.5 + pulse * 0.08, x, y, 0.3))
        for line in veins:
            for (x, y) in line:
                cv.put(x, y, hexc('#14020a') if pulse < 0.5 else hexc('#24040e'))
                cv.put((x + 1) % 16, y, flesh.pick(0.6 + pulse * 0.2, x, y))  # swollen highlight beside the vein
        for (ex, ey, phase) in eyes:
            closed = (f + phase) % 4 == 3
            if closed:
                cv.put(ex, ey, flesh.pick(0.2, 0, 0))
                cv.put(ex + 1, ey, flesh.pick(0.2, 0, 0))
            else:
                cv.put(ex, ey, hexc('#efe2c8'))
                cv.put(ex + 1, ey, hexc('#efe2c8'))
                cv.put(ex + (1 if (f + phase) % 2 else 0), ey, hexc('#1a0005'))
            cv.darken(ex, ey - 1, 0.55)
            cv.darken(ex + 1, ey - 1, 0.55)
            cv.darken(ex, ey + 1, 0.7)
            cv.darken(ex + 1, ey + 1, 0.7)
        frames.paste(Image.fromarray(cv.a, 'RGBA'), (0, f * 16))
    frames.save(out('block', 'dreamrot'))
    with open(out('block', 'dreamrot').replace('.png', '.png.mcmeta'), 'w') as fh:
        fh.write('{\n  "animation": {\n    "frametime": 10,\n    "interpolate": true\n  }\n}\n')


def weeping_leaves():
    rng = random.Random(4242)
    leaf = Palette('#07030c', '#12081c', '#1e0f2c', '#2c183e', '#3c2452', '#4e3268', '#62427e')
    cv = Canvas(16, 16)
    for _ in range(26):  # clumps of small leaves, lit from the top-left
        cx, cy = rng.randrange(16), rng.randrange(16)
        w, h = rng.choice(((2, 2), (3, 2), (2, 3), (3, 3)))
        for dy in range(h):
            for dx in range(w):
                x, y = (cx + dx) % 16, (cy + dy) % 16
                v = 0.65 - dx * 0.12 - dy * 0.14 + rng.random() * 0.1
                cv.put(x, y, leaf.pick(v, x, y, 0.2))
        cv.put(cx % 16, cy % 16, leaf.pick(0.95, 0, 0))
    for _ in range(5):  # red tears running down from the leaves
        x, y = rng.randrange(16), rng.randrange(11)
        for k, c in enumerate(('#4a0612', '#7a0c1c', '#a8182a', '#d83040')):
            cv.put(x, y + k, hexc(c))
    cv.save(out('block', 'weeping_leaves'))


# =========================================================================== HUD
def vignette():
    s = 256
    a = np.zeros((s, s, 4), dtype=np.uint8)
    for y in range(s):
        for x in range(s):
            d = math.hypot((x - s / 2) / (s / 2), (y - s / 2) / (s / 2))
            t = max(0.0, min(1.0, (d - 0.45) / 0.75))
            a[y, x] = (255, 255, 255, int((t ** 1.6) * 255))
    Image.fromarray(a, 'RGBA').save(out('misc', 'dream_vignette'))


def grain():
    rng = np.random.default_rng(99)
    s = 128
    v = rng.integers(0, 255, (s, s))
    a = np.zeros((s, s, 4), dtype=np.uint8)
    a[:, :, 0] = v
    a[:, :, 1] = v
    a[:, :, 2] = v
    a[:, :, 3] = np.where(rng.random((s, s)) < 0.45, 255, 0)
    Image.fromarray(a, 'RGBA').save(out('misc', 'dream_grain'))


def run():
    dream_shard()
    dawn_ingot()
    nightmare_heart()
    dawn_tincture()
    dream_totem()
    insomnia_lantern()
    dawn_blade()
    echo_scythe()
    lullaby_staff()
    for st in SETS:
        for piece in ICON:
            armor_icon(st, piece)
        armor_layers(st)
    ore('dream_shard_ore', stone_base, 11)
    ore('deepslate_dream_shard_ore', deepslate_base, 12)
    ashen_grass()
    dreamrot()
    weeping_leaves()
    vignette()
    grain()


if __name__ == '__main__':
    run()
