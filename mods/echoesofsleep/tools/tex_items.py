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


def dawn_ingot():
    s = Sprite()
    top = Palette('#b8743a', '#e8a85a', '#ffd88a', '#fff2c8')
    front = Palette('#7a3b2a', '#b55a3a', '#e98a4e', '#ffb86a', '#ffd5a0')
    side = Palette('#5a2a22', '#8a3f2e', '#b8603a')
    s.poly([(2, 8), (5, 5), (13, 5), (10, 8)], lambda x, y: top.pick(0.4 + (8 - y) * 0.15, x, y))
    s.poly([(2, 8), (10, 8), (10, 11), (2, 11)], lambda x, y: front.pick(0.35 + (x - 2) * 0.05, x, y))
    s.poly([(10, 8), (13, 5), (13, 8), (10, 11)], lambda x, y: side.pick(0.5, x, y))
    for x in range(3, 10):  # the dawn line
        s.put(x, 9, hexc('#ff6f91') if x % 3 else hexc('#ffd1dc'))
    s.finish(hexc('#2a0f0a'))
    s.put(6, 6, (255, 255, 240))
    s.put(7, 6, (255, 250, 220))
    s.save(out('item', 'dawn_ingot'))


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


def dream_totem():
    s = Sprite()
    stone = Palette('#0a0612', '#1c1230', '#2e2050', '#45307a', '#5e4aa0')
    gold = Palette('#5a3a0a', '#a8761c', '#e8b84a', '#fff0a0')
    s.poly([(5, 3), (10, 3), (11, 5), (11, 13), (4, 13), (4, 5)], lambda x, y: stone.pick(0.35 + (x - 4) * -0.03 + (13 - y) * 0.03, x, y))
    s.poly([(6, 1), (9, 1), (10, 3), (5, 3)], lambda x, y: stone.pick(0.6, x, y))
    s.poly([(3, 13), (12, 13), (12, 14), (3, 14)], lambda x, y: gold.pick(0.5, x, y))
    for x in range(4, 12):
        s.put(x, 9, gold.pick(0.6 + (x % 2) * 0.2, x, 9))
    s.finish(hexc('#05020a'))
    for (x, y, c) in ((7, 6, '#b070ff'), (8, 6, '#b070ff'), (6, 6, '#4a2a7a'), (9, 6, '#4a2a7a'), (7, 5, '#3a1a5a'), (8, 7, '#3a1a5a')):
        s.put(x, y, hexc(c))
    s.put(7, 6, hexc('#ffe08a'))
    for y in range(10, 13):  # tear of light
        s.put(8, y, hexc('#7a50c0'))
    s.save(out('item', 'dream_totem'))


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


def dawn_blade():
    s = Sprite()
    blade = Palette('#8a5a3a', '#e8a070', '#ffd0a0', '#fff0d8', '#ffffff')
    for i in range(10):
        x, y = 5 + i, 10 - i
        s.put(x, y, blade.pick(0.55 + i * 0.04, x, y))
        s.put(x - 1, y, blade.pick(0.35 + i * 0.04, x - 1, y))
        if i < 9:
            s.put(x, y - 1 + 1, blade.pick(0.7 + i * 0.03, x, y))
    s.put(14, 1, blade.pick(0.95, 14, 1))
    s.put(15, 0, blade.pick(1.0, 15, 0))
    gold = Palette('#6a3a0a', '#c88a2a', '#ffd25a', '#fff2b0')
    for (x, y) in ((2, 9), (3, 10), (4, 11), (5, 12), (6, 13)):
        s.put(x, y, gold.pick(0.6, x, y))
    s.put(4, 10, gold.pick(0.95, 4, 10))
    grip = Palette('#2a1020', '#4a2040', '#6a3a5a')
    for (x, y) in ((3, 12), (2, 13)):
        s.put(x, y, grip.pick(0.5 + (x % 2) * 0.3, x, y))
    s.put(1, 14, gold.pick(0.8, 1, 14))
    s.finish(hexc('#2a0c08'))
    for i in range(2, 9, 2):
        s.put(5 + i, 10 - i, (255, 255, 255))
    s.put(4, 10, hexc('#ff7a5a'))  # a small rising sun on the guard
    s.save(out('item', 'dawn_blade'))


def echo_scythe():
    s = Sprite()
    bone = Palette('#4a3e2e', '#8a7a5e', '#c8b894', '#ece2c8')
    ghost = Palette('#1a1040', '#3a2a8a', '#5a6ae0', '#8ae0ff', '#e0fbff')
    s.line(2, 14, 11, 4, lambda x, y, t: bone.pick(0.4 + t * 0.4, x, y))
    for (x, y) in ((4, 12), (7, 9), (10, 6)):
        s.put(x, y, bone.pick(0.15, x, y))  # knuckles of the bone handle
    arc = [(11, 3), (10, 2), (9, 1), (8, 1), (7, 1), (6, 1), (5, 2), (4, 2), (3, 3), (2, 4), (2, 5), (1, 6)]
    for i, (x, y) in enumerate(arc):
        s.put(x, y, ghost.pick(0.85 - i * 0.04, x, y))
        if 1 <= i <= 9:
            s.put(x, y + 1, ghost.pick(0.55 - i * 0.03, x, y + 1))
    s.put(12, 3, ghost.pick(0.5, 12, 3))
    s.finish(hexc('#0a0618'))
    for i, (x, y) in enumerate(arc[2:9]):  # the ghost of the blade, a frame behind
        if not s.filled(x - 1, y + 3):
            s.put(x - 1, y + 3, hexc('#5a8ae0'), 110)
    s.put(8, 1, (255, 255, 255))
    s.save(out('item', 'echo_scythe'))


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
        '                ', '                ', '                ',
        '  oooo    oooo  ',
        '  ohbo    obso  ',
        '  ohbo    obso  ',
        '  ohbo    obso  ',
        ' oohbbo  obbsoo ',
        'ohhbbbo  obbbsso',
        'oeeeeeo  oeeeeeo',
        'ooooooo  ooooooo',
        '                '],
}
SETS = {
    'dreamcatcher': dict(o='#0d0b1f', h='#6a74c8', b='#343080', s='#1b1844', e='#c8d0ff', g='#7ff5ff', pal=Palette('#0d0b1f', '#1b1844', '#262260', '#343080', '#4a4ca4', '#6a74c8', '#9aa4e8')),
    'wakeful': dict(o='#3a2207', h='#fff1b0', b='#e0b84a', s='#a5741e', e='#ff8a5c', g='#fffbe0', pal=Palette('#3a2207', '#7a4e12', '#a5741e', '#cf9a32', '#e0b84a', '#f6d878', '#fff1b0')),
    'nightmare_eater': dict(o='#070205', h='#6a2a36', b='#2a1017', s='#150609', e='#d9cfb8', g='#ff2a3a', pal=Palette('#070205', '#150609', '#22090f', '#2a1017', '#401822', '#5a2430', '#7a3442')),
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
def armor_layers(set_name):
    st = SETS[set_name]
    pal = st['pal']
    rng = random.Random(len(set_name) * 977)
    accent, glow, emblem = hexc(st['e']), hexc(st['g']), hexc(st['e'])
    l1 = Canvas(64, 32)
    l2 = Canvas(64, 32)

    style = {'dreamcatcher': 'cloth', 'wakeful': 'gold', 'nightmare_eater': 'chitin'}[set_name]

    def surface(cv, rect, fname):
        """Bevelled armour plates: bright upper edge, dark lower edge, seams every few rows, rivets."""
        x0, y0, fw, fh = rect
        panel = 4 if fh >= 8 else max(2, fh)
        for y in range(fh):
            for x in range(fw):
                v = 0.66 - (y / max(1, fh - 1)) * 0.22 + (rng.random() - 0.5) * 0.08
                if fname == 'top':
                    v += 0.12
                if fname == 'bottom':
                    v -= 0.25
                if fname in ('left', 'right'):
                    v -= 0.08
                py = y % panel
                if py == 0:
                    v += 0.16
                if py == panel - 1:
                    v -= 0.22
                if x == 0:
                    v += 0.08
                if x == fw - 1:
                    v -= 0.15
                if style == 'cloth':
                    v += 0.07 if (x + y) % 2 else -0.03
                col = pal.pick(v, x0 + x, y0 + y, 0.3)
                if style == 'cloth' and (x + 2 * y) % 5 == 0 and py not in (0, panel - 1):
                    col = tuple(min(255, int(c * 1.25 + 12)) for c in col)  # silver thread weave
                if style == 'chitin' and py == panel - 1 and rng.random() < 0.55:
                    col = hexc('#7a0a18') if rng.random() < 0.7 else hexc('#c01a2c')  # crimson seams
                cv.put(x0 + x, y0 + y, col)
            if style == 'gold' and y % panel == 1 and fw >= 4:
                cv.put(x0 + 1, y0 + y, hexc('#fffbe8'))
                cv.put(x0 + fw - 2, y0 + y, hexc('#fff3c0'))
        if style == 'gold':  # polished glint
            for k in range(min(fw, fh) // 2):
                cv.put(x0 + 1 + k, y0 + 1 + k, hexc('#fffdf0'))

    def plate(cv, box, rows=None, keep=None):
        u, v, w, h, d = box
        for fname, rect in faces(u, v, w, h, d).items():
            surface(cv, rect, fname)
            if rows is not None and fname not in ('top', 'bottom'):
                x0, y0, fw, fh = rect
                for y in range(fh):
                    if not (rows[0] <= y < rows[1]):
                        for x in range(fw):
                            cv.put(x0 + x, y0 + y, (0, 0, 0), 0)
            if keep is not None and fname not in keep:
                x0, y0, fw, fh = rect
                for y in range(fh):
                    for x in range(fw):
                        cv.put(x0 + x, y0 + y, (0, 0, 0), 0)

    def trim_row(cv, rect, y, col):
        x0, y0, fw, fh = rect
        for x in range(x0, x0 + fw):
            cv.put(x, y0 + y, col if (x + y) % 2 else tuple(int(c * 0.8) for c in col))

    # ---------------------------------------------------------------- helmet
    head = faces(0, 0, 8, 8, 8)
    plate(l1, (0, 0, 8, 8, 8))
    fx, fy, fw, fh = head['front']
    for y in range(3, 7):  # face opening
        for x in range(1, 7):
            l1.put(fx + x, fy + y, (0, 0, 0), 0)
    for side in ('front', 'left', 'right', 'back'):
        trim_row(l1, head[side], 2, accent)
    if set_name == 'dreamcatcher':
        # a small dreamcatcher hoop on the forehead, feathers hanging past the ears
        for (x, y) in ((3, 0), (4, 0), (2, 1), (5, 1), (3, 2), (4, 2)):
            l1.put(fx + x, fy + y, emblem)
        l1.put(fx + 3, fy + 1, glow)
        l1.put(fx + 4, fy + 1, glow)
        for side in ('left', 'right'):
            x0, y0, w, h = head[side]
            for y in range(3, 8):
                l1.put(x0 + 3, y0 + y, hexc('#d8dcff') if y % 2 else hexc('#8a90c8'))
                l1.put(x0 + 4, y0 + y, hexc('#b0b8f0') if y < 7 else hexc('#ffffff'))
    elif set_name == 'wakeful':
        # a sunburst crest over the brow
        for (x, y) in ((3, 0), (4, 0), (2, 1), (5, 1), (1, 0), (6, 0)):
            l1.put(fx + x, fy + y, accent)
        l1.put(fx + 3, fy + 1, glow)
        l1.put(fx + 4, fy + 1, glow)
        tx, ty, tw, th = head['top']
        for i in range(8):
            l1.put(tx + i, ty + 3 + (i % 2), hexc('#fff6c8'))
            l1.put(tx + 3, ty + i, hexc('#fff6c8'))
    else:
        # the opening is a mouth: teeth above and below, eyes burning in the brow
        for x in range(1, 7):
            if x % 2:
                l1.put(fx + x, fy + 3, hexc('#e8dcc0'))
                l1.put(fx + x, fy + 6, hexc('#cfc2a4'))
        l1.put(fx + 2, fy + 1, glow)
        l1.put(fx + 5, fy + 1, glow)
        tx, ty, tw, th = head['top']
        for i in range(0, 8, 2):
            l1.put(tx + i, ty + 4, hexc('#d9cfb8'))  # bone ridge
    # ---------------------------------------------------------------- chestplate body + arms
    body = faces(16, 16, 8, 12, 4)
    plate(l1, (16, 16, 8, 12, 4))
    bx, by, bw, bh = body['front']
    for side in ('front', 'back', 'left', 'right'):
        trim_row(l1, body[side], bh - 2, accent)
        trim_row(l1, body[side], 0, tuple(int(c * 0.9) for c in hexc(st['h'])))
    cx, cy = bx + 3, by + 4
    if set_name == 'dreamcatcher':
        ring = [(1, -2), (2, -1), (2, 0), (2, 1), (1, 2), (0, 2), (-1, 1), (-1, 0), (-1, -1), (0, -2)]
        for dx, dy in ring:
            l1.put(cx + dx, cy + dy, emblem)
        for dx, dy in ((0, 0), (1, 1), (1, -1), (0, 1)):
            l1.put(cx + dx, cy + dy, hexc('#8a90d8'))
        l1.put(cx, cy, glow)
        l1.put(cx + 1, cy, glow)
        for y in range(3, 7):
            l1.put(cx - 1 + (y % 2), cy + y, hexc('#e0e4ff'))
            l1.put(cx + 2 - (y % 2), cy + y, hexc('#c0c6f0'))
    elif set_name == 'wakeful':
        for dx in range(-1, 3):
            for dy in range(-1, 2):
                l1.put(cx + dx, cy + dy, accent)
        l1.put(cx, cy, glow)
        l1.put(cx + 1, cy, glow)
        for (dx, dy) in ((-3, 0), (4, 0), (0, -3), (1, -3), (-2, -2), (3, -2), (-2, 2), (3, 2), (0, 3), (1, 3)):
            l1.put(cx + dx, cy + dy, hexc('#ffd27a'))
    else:
        for k in range(4):  # ribcage
            y = by + 2 + k * 2
            for x in range(bx + 1, bx + bw - 1):
                if x not in (cx, cx + 1):
                    l1.put(x, y, hexc('#d9cfb8') if (x + k) % 3 else hexc('#a89c80'))
        for y in range(by + 1, by + 10):
            l1.put(cx, y, hexc('#e8dcc0'))
            l1.put(cx + 1, y, hexc('#cfc2a4'))
        l1.put(cx, by + 5, glow)
        l1.put(cx + 1, by + 5, glow)
        l1.put(cx, by + 6, hexc('#a0101a'))
        l1.put(cx + 1, by + 6, hexc('#a0101a'))
    arm = (40, 16, 4, 12, 4)
    plate(l1, arm, rows=(0, 9))
    af = faces(*arm)
    for side in ('front', 'back', 'left', 'right'):
        trim_row(l1, af[side], 4, accent)
        trim_row(l1, af[side], 8, tuple(int(c * 0.7) for c in accent))
    if set_name == 'nightmare_eater':
        for side in ('right', 'front', 'back'):
            x0, y0, w, h = af[side]
            l1.put(x0 + 1, y0, hexc('#e8dcc0'))  # shoulder spikes
            l1.put(x0 + 2, y0, hexc('#e8dcc0'))
    # ---------------------------------------------------------------- boots (layer 1 legs, bottom rows)
    leg = (0, 16, 4, 12, 4)
    plate(l1, leg, rows=(7, 12))
    lf = faces(*leg)
    for side in ('front', 'back', 'left', 'right'):
        trim_row(l1, lf[side], 7, accent)
    if set_name == 'dreamcatcher':
        x0, y0, w, h = lf['right']
        for y in range(8, 11):
            l1.put(x0 + 1, y0 + y, hexc('#e0e4ff'))
    elif set_name == 'nightmare_eater':
        x0, y0, w, h = lf['front']
        for x in range(w):
            l1.put(x0 + x, y0 + 11, hexc('#e8dcc0') if x % 2 == 0 else hexc('#070205'))  # claws
    # ---------------------------------------------------------------- leggings (layer 2)
    plate(l2, (16, 16, 8, 12, 4), rows=(7, 12))
    b2 = faces(16, 16, 8, 12, 4)
    for side in ('front', 'back', 'left', 'right'):
        trim_row(l2, b2[side], 7, accent)
    x0, y0, w, h = b2['front']
    l2.put(x0 + 3, y0 + 7, glow)
    l2.put(x0 + 4, y0 + 7, glow)
    plate(l2, leg, rows=(0, 11))
    lf2 = faces(*leg)
    for side in ('front', 'back', 'left', 'right'):
        trim_row(l2, lf2[side], 5, accent)
        x0, y0, w, h = lf2[side]
        for y in range(1, 10, 3):
            l2.darken(x0 + w // 2, y0 + y, 0.7)
    l1.save(out('models/armor', f'{set_name}_layer_1'))
    l2.save(out('models/armor', f'{set_name}_layer_2'))


# =========================================================================== blocks
STONE = Palette('#4a4a4e', '#5e5e62', '#727276', '#88888b', '#9c9c9f')
DEEPSLATE = Palette('#1e1e24', '#2a2a31', '#36363d', '#45454c', '#55555c')
CRYSTAL = Palette('#1d0f3d', '#3a1f7a', '#5b3cc4', '#7b6cf0', '#8fd0ff', '#e0fbff')


def base_block(pal, seed, layered=False):
    rng = random.Random(seed)
    n = fbm(16, 16, rng, cells=(4, 2, 1))
    cv = Canvas(16, 16)
    for y in range(16):
        for x in range(16):
            v = n[y, x]
            if layered:
                v = v * 0.6 + (0.5 + 0.25 * math.sin(y * 1.7 + n[y, x] * 3)) * 0.4
            cv.put(x, y, pal.pick(v, x, y, 0.5))
    return cv, rng


def ore(name, pal, seed, layered):
    cv, rng = base_block(pal, seed, layered)
    clusters = [(3, 4), (10, 3), (6, 10), (12, 11), (2, 13)]
    for cx, cy in clusters:
        shape = [(0, 0), (1, 0), (0, 1), (1, -1), (-1, 1), (2, -1)]
        rng.shuffle(shape)
        for i, (dx, dy) in enumerate(shape[:rng.randint(3, 6)]):
            x, y = (cx + dx) % 16, (cy + dy) % 16
            cv.put(x, y, CRYSTAL.pick(0.35 + i * 0.1 + (0.2 if dy < 0 else 0), x, y))
        cv.put(cx, cy, CRYSTAL.pick(0.95, cx, cy))
        cv.darken((cx + 1) % 16, (cy + 1) % 16, 0.6)
    cv.save(out('block', name))


def ashen_grass():
    rng = random.Random(81)
    ash = Palette('#3a383a', '#504d4f', '#686466', '#827e7e', '#9c9897', '#b6b1ae')
    top = Canvas(16, 16)
    n = fbm(16, 16, rng, cells=(4, 2, 1))
    for y in range(16):
        for x in range(16):
            top.put(x, y, ash.pick(n[y, x], x, y))
    for _ in range(18):  # dead blades of grass
        x, y = rng.randrange(16), rng.randrange(16)
        top.put(x, y, ash.pick(0.1, x, y))
        top.put(x, (y + 1) % 16, ash.pick(0.25, x, y))
    for _ in range(6):  # embers
        top.put(rng.randrange(16), rng.randrange(16), hexc('#ff6a2a') if rng.random() < 0.4 else hexc('#5a1a10'))
    top.save(out('block', 'ashen_grass_top'))
    dirt = Palette('#3b2a1e', '#523a29', '#6b4c36', '#7f5c42', '#916a4d')
    side = Canvas(16, 16)
    n2 = fbm(16, 16, rng, cells=(4, 2, 1))
    for y in range(16):
        for x in range(16):
            side.put(x, y, dirt.pick(n2[y, x] * 0.8, x, y))
    for x in range(16):
        depth = 3 + rng.randint(0, 2) + (1 if x % 5 == 0 else 0)
        for y in range(depth):
            side.put(x, y, ash.pick(0.6 - y * 0.08 + rng.random() * 0.2, x, y))
    side.save(out('block', 'ashen_grass_side'))


def dreamrot():
    """Animated fleshy block: 4 frames of pulsing veins and blinking pustule eyes."""
    rng = random.Random(1337)
    flesh = Palette('#1e0510', '#3d0a1c', '#5e1428', '#7e2236', '#9e3646', '#c25660', '#e08a8a')
    n = fbm(16, 16, rng, cells=(5, 2, 1))
    veins = [(rng.randrange(16), rng.randrange(16)) for _ in range(5)]
    frames = Image.new('RGBA', (16, 64))
    for f in range(4):
        cv = Canvas(16, 16)
        pulse = math.sin(f / 4 * math.pi * 2) * 0.5 + 0.5
        for y in range(16):
            for x in range(16):
                v = n[y, x] * 0.8 + 0.1 + pulse * 0.08
                cv.put(x, y, flesh.pick(v, x, y))
        r2 = random.Random(5)
        for vx, vy in veins:
            x, y = vx, vy
            for _ in range(10):
                cv.put(x % 16, y % 16, hexc('#2a0a3a') if pulse < 0.5 else hexc('#4a1a5a'))
                x += r2.choice((-1, 0, 1))
                y += 1
        for i, (ex, ey) in enumerate(((4, 5), (11, 9), (7, 13))):
            open_ = (f + i) % 4 != 0
            cv.put(ex, ey, hexc('#f0e0c0') if open_ else hexc('#5e1428'))
            cv.put(ex + 1, ey, hexc('#f0e0c0') if open_ else hexc('#5e1428'))
            if open_:
                cv.put(ex + (f % 2), ey, hexc('#1a0005'))
            cv.darken(ex, ey + 1, 0.6)
            cv.darken(ex + 1, ey + 1, 0.6)
        frames.paste(Image.fromarray(cv.a, 'RGBA'), (0, f * 16))
    frames.save(out('block', 'dreamrot'))
    with open(out('block', 'dreamrot').replace('.png', '.png.mcmeta'), 'w') as fh:
        fh.write('{\n  "animation": {\n    "frametime": 6,\n    "interpolate": true\n  }\n}\n')


def weeping_leaves():
    rng = random.Random(4242)
    leaf = Palette('#0a0410', '#1a0a24', '#2a1238', '#3c1c4c', '#4e2a60', '#643a74')
    cv = Canvas(16, 16)
    n = fbm(16, 16, rng, cells=(3, 2, 1))
    for y in range(16):
        for x in range(16):
            if rng.random() < 0.2:
                continue  # holes
            cv.put(x, y, leaf.pick(n[y, x], x, y))
    for _ in range(7):  # dark red tears
        x, y = rng.randrange(16), rng.randrange(13)
        cv.put(x, y, hexc('#6a0a1a'))
        cv.put(x, y + 1, hexc('#9a1a2a'))
        cv.put(x, y + 2, hexc('#c83040'))
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
    ore('dream_shard_ore', STONE, 11, False)
    ore('deepslate_dream_shard_ore', DEEPSLATE, 12, True)
    ashen_grass()
    dreamrot()
    weeping_leaves()
    vignette()
    grain()


if __name__ == '__main__':
    run()
