#!/usr/bin/env python3
"""Generates all Hide & Hunt block/item textures (16x16) with Pillow.

Run from anywhere:  python3 mods/hideandhunt/tools/gen_textures.py
Writes into src/main/resources/assets/hideandhunt/textures/{block,item}.
"""
import math
import os
import random
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src', 'main', 'resources', 'assets', 'hideandhunt', 'textures')
BLOCK = os.path.join(ROOT, 'block')
ITEM = os.path.join(ROOT, 'item')
os.makedirs(BLOCK, exist_ok=True)
os.makedirs(ITEM, exist_ok=True)

rnd = random.Random(1337)

# ------------------------------------------------------------------ colour helpers

def clamp(v):
    return max(0, min(255, int(round(v))))


def mix(a, b, t):
    return tuple(clamp(a[i] + (b[i] - a[i]) * t) for i in range(3)) + ((255,) if len(a) == 3 else (clamp(a[3] + (b[3] - a[3]) * t),))


def shade(c, f):
    """f < 1 darkens, f > 1 lightens towards white."""
    if f <= 1:
        return tuple(clamp(x * f) for x in c[:3]) + (255,)
    t = f - 1
    return tuple(clamp(x + (255 - x) * t) for x in c[:3]) + (255,)


def ramp(base):
    """6-tone palette from deep shadow to highlight."""
    return [shade(base, 0.28), shade(base, 0.45), shade(base, 0.68), shade(base, 0.9), shade(base, 1.0), shade(base, 1.35), shade(base, 1.7)]


GREEN = (60, 230, 110)
RED = (235, 60, 50)
PURPLE = (170, 90, 255)
GOLD = (255, 190, 40)
CYAN = (50, 200, 255)
GREY = (150, 150, 165)

METAL = ramp((96, 98, 112))  # dark frame metal
STONE = ramp((70, 72, 86))

# ------------------------------------------------------------------ icons
ICONS = {
    'eye': [
        "...####...",
        ".##....##.",
        "#...oo...#",
        "#..oooo..#",
        "#...oo...#",
        ".##....##.",
        "...####...",
    ],
    # small 7-wide variants authored for the 10x10 button caps (inner area 4..11)
    'cap_cross': [
        "..###..",
        ".#...#.",
        "#..#..#",
        "#.###.#",
        "#..#..#",
        ".#...#.",
        "..###..",
    ],
    'cap_eye': [
        "..####..",
        ".#.oo.#.",
        "#.oooo.#",
        ".#.oo.#.",
        "..####..",
    ],
    'cross': [
        "....#....",
        "..#####..",
        ".#..#..#.",
        ".#.....#.",
        "####o####",
        ".#.....#.",
        ".#..#..#.",
        "..#####..",
        "....#....",
    ],
    'house': [
        "....#....",
        "...###...",
        "..#####..",
        ".#######.",
        "..#####..",
        "..##.##..",
        "..##.##..",
    ],
    'question': [
        ".####.",
        "##..##",
        "....##",
        "...##.",
        "..##..",
        "......",
        "..##..",
    ],
    'play': [
        "#.....",
        "###...",
        "#####.",
        "######",
        "#####.",
        "###...",
        "#.....",
    ],
    'x': [
        "#....#",
        "##..##",
        ".####.",
        "..##..",
        ".####.",
        "##..##",
        "#....#",
    ],
    'sword': [
        ".....##",
        "....###",
        "...###.",
        "#.###..",
        ".###...",
        ".##....",
        "#.#....",
    ],
}


def draw_icon(img, name, cx, cy, color, shadow=None, accent=None, outline=None, clip=(0, 0, 16, 16)):
    rows = ICONS[name]
    h, w = len(rows), len(rows[0])
    x0, y0 = cx - w // 2, cy - h // 2
    px = img.load()
    if outline is not None:
        # 1px dark outline around every icon pixel (keeps light icons readable on bright caps)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == '.':
                    continue
                for oy in (-1, 0, 1):
                    for ox in (-1, 0, 1):
                        tx, ty = x + ox, y + oy
                        if 0 <= tx < w and 0 <= ty < h and rows[ty][tx] != '.':
                            continue
                        sx, sy = x0 + tx, y0 + ty
                        if clip[0] <= sx < clip[2] and clip[1] <= sy < clip[3]:
                            px[sx, sy] = outline
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == '.':
                continue
            if shadow is not None and ch == '#':
                sx, sy = x0 + x + 1, y0 + y + 1
                if 0 <= sx < img.width and 0 <= sy < img.height and (y + 1 >= h or x + 1 >= w or rows[y + 1][x + 1] == '.'):
                    px[sx, sy] = shadow
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == '.':
                continue
            c = accent if (ch == 'o' and accent is not None) else color
            px[x0 + x, y0 + y] = c


def new():
    return Image.new('RGBA', (16, 16), (0, 0, 0, 255))


def noise_fill(img, box, pal, lo=2, hi=4):
    px = img.load()
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        for x in range(x0, x1):
            px[x, y] = pal[rnd.randint(lo, hi)]


def bevel(img, box, light, dark):
    px = img.load()
    x0, y0, x1, y1 = box
    for x in range(x0, x1):
        px[x, y0] = light
        px[x, y1 - 1] = dark
    for y in range(y0, y1):
        px[x0, y] = light
        px[x1 - 1, y] = dark


# ------------------------------------------------------------------ pads

def pad_top(color, icon, name):
    img = new()
    pal = ramp(color)
    px = img.load()
    # metal frame
    noise_fill(img, (0, 0, 16, 16), METAL, 2, 3)
    bevel(img, (0, 0, 16, 16), METAL[5], METAL[0])
    bevel(img, (1, 1, 15, 15), METAL[4], METAL[1])
    # rivets
    for (x, y) in [(1, 1), (14, 1), (1, 14), (14, 14)]:
        px[x, y] = METAL[6]
    # glowing inner panel (radial gradient)
    for y in range(2, 14):
        for x in range(2, 14):
            d = math.hypot(x - 7.5, y - 7.5) / 7.8
            t = max(0.0, 1.0 - d)
            c = mix(pal[3], pal[6], t * t)
            # subtle scan grid
            if (x + y) % 4 == 0:
                c = mix(c, pal[2], 0.25)
            px[x, y] = c
    # inner lip shadow
    for i in range(2, 14):
        px[i, 2] = mix(px[i, 2], pal[1], 0.55)
        px[2, i] = mix(px[2, i], pal[1], 0.45)
        px[i, 13] = mix(px[i, 13], pal[6], 0.35)
        px[13, i] = mix(px[13, i], pal[6], 0.25)
    draw_icon(img, icon, 8, 8, (255, 255, 255, 255), shadow=pal[1], accent=pal[2])
    img.save(os.path.join(BLOCK, name + '_top.png'))

    side = new()
    noise_fill(side, (0, 0, 16, 16), METAL, 1, 3)
    sp = side.load()
    for x in range(16):
        sp[x, 14] = pal[6] if x % 3 else pal[4]
        sp[x, 15] = METAL[0]
        sp[x, 13] = METAL[4]
    side.save(os.path.join(BLOCK, name + '_side.png'))


def pad_bottom():
    img = new()
    noise_fill(img, (0, 0, 16, 16), METAL, 0, 2)
    bevel(img, (0, 0, 16, 16), METAL[3], METAL[0])
    img.save(os.path.join(BLOCK, 'pad_bottom.png'))


# ------------------------------------------------------------------ pedestal buttons

def pedestal_side(color, name, icon_pattern=None):
    """Column side (rows 5..13) + plinth (rows 14..15)."""
    pal = ramp(color)
    img = new()
    px = img.load()
    noise_fill(img, (0, 0, 16, 16), STONE, 2, 4)
    # vertical shading of column: lighter at top
    for y in range(16):
        for x in range(16):
            f = 1.08 - (y / 16) * 0.25 - (0.08 if x in (1, 14) else 0)
            px[x, y] = shade(px[x, y], f)
    # column top lip
    for x in range(16):
        px[x, 5] = STONE[6]
        px[x, 6] = STONE[5]
    # coloured light strip
    for x in range(1, 15):
        px[x, 8] = pal[5] if x % 2 else pal[4]
        px[x, 9] = pal[3]
        px[x, 12] = pal[2]
    # emblem panel
    for y in range(9, 12):
        for x in range(5, 11):
            px[x, y] = pal[1]
    if icon_pattern == 'question':
        for (x, y) in [(6, 10), (9, 10)]:
            px[x, y] = (255, 240, 170, 255)
        px[7, 10] = pal[6]
        px[8, 10] = pal[6]
    else:
        for x in range(6, 10):
            px[x, 10] = pal[6]
    # side rivets
    for (x, y) in [(2, 7), (13, 7), (2, 12), (13, 12)]:
        px[x, y] = STONE[6]
    # plinth
    for x in range(16):
        px[x, 13] = STONE[0]
        px[x, 14] = METAL[5] if x % 4 else METAL[6]
        px[x, 15] = METAL[1]
    img.save(os.path.join(BLOCK, name + '_side.png'))


def pedestal_top_bottom():
    img = new()
    px = img.load()
    noise_fill(img, (0, 0, 16, 16), STONE, 3, 5)
    bevel(img, (0, 0, 16, 16), STONE[6], STONE[1])
    bevel(img, (1, 1, 15, 15), STONE[5], STONE[2])
    # recessed ring where the cap sits
    for y in range(2, 14):
        for x in range(2, 14):
            if 2 <= x <= 13 and 2 <= y <= 13 and (x in (2, 13) or y in (2, 13)):
                px[x, y] = STONE[0]
    for y in range(3, 13):
        for x in range(3, 13):
            px[x, y] = METAL[1]
    img.save(os.path.join(BLOCK, 'pedestal_top.png'))

    b = new()
    noise_fill(b, (0, 0, 16, 16), METAL, 0, 2)
    bevel(b, (0, 0, 16, 16), METAL[3], METAL[0])
    b.save(os.path.join(BLOCK, 'pedestal_bottom.png'))


def cap(color, icon, name, icon_color=(255, 255, 255, 255), outline=None):
    """Button face: authored inside the 10x10 area (3..12) that the model maps with UV 3..13."""
    pal = ramp(color)
    img = new()
    px = img.load()
    for y in range(16):
        for x in range(16):
            px[x, y] = pal[2]  # outside the used area (never visible)
    # glossy dome
    for y in range(3, 13):
        for x in range(3, 13):
            dx, dy = x - 7.5, y - 7.5
            d = math.hypot(dx, dy) / 5.2
            light = max(0.0, 1 - math.hypot(dx + 2.2, dy + 2.2) / 5.0)
            c = mix(pal[3], pal[2], min(1, d))
            c = mix(c, pal[5], light * 0.8)
            px[x, y] = c
    # own bevel: light top/left edge, dark bottom/right edge, corners blended
    for i in range(3, 13):
        px[i, 3] = pal[6]
        px[3, i] = pal[5]
        px[i, 12] = pal[0]
        px[12, i] = pal[1]
    px[3, 3] = shade(pal[6], 1.15)
    px[12, 3] = pal[3]
    px[3, 12] = pal[2]
    px[12, 12] = pal[0]
    # specular highlight
    px[5, 5] = (255, 255, 255, 255)
    px[6, 5] = shade(pal[6], 1.2)
    px[5, 6] = shade(pal[6], 1.2)
    draw_icon(img, icon, 8, 8, icon_color, shadow=None if outline else pal[0], accent=pal[0], outline=outline, clip=(4, 4, 12, 12))
    img.save(os.path.join(BLOCK, name + '_cap.png'))

    side = new()
    sp = side.load()
    for y in range(16):
        for x in range(16):
            sp[x, y] = pal[3] if y < 14 else pal[1]
            if y == 13:
                sp[x, y] = pal[5]
            if y == 15:
                sp[x, y] = pal[0]
            if x % 5 == 0 and y >= 13:
                sp[x, y] = pal[2]
    side.save(os.path.join(BLOCK, name + '_cap_side.png'))


# ------------------------------------------------------------------ item

def tablet():
    img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    px = img.load()
    body = ramp((60, 62, 78))
    for y in range(1, 15):
        for x in range(2, 14):
            if (x, y) in [(2, 1), (13, 1), (2, 14), (13, 14)]:
                continue
            px[x, y] = body[3]
    for y in range(1, 15):
        px[2, y] = body[5] if 1 < y < 14 else px[2, y]
        px[13, y] = body[1] if 1 < y < 14 else px[13, y]
    for x in range(3, 13):
        px[x, 1] = body[5]
        px[x, 14] = body[0]
    # screen
    g, r = ramp(GREEN), ramp(RED)
    for y in range(3, 12):
        for x in range(4, 12):
            if x < 8:
                c = mix(g[2], g[4], (11 - y) / 9)
            else:
                c = mix(r[2], r[4], (11 - y) / 9)
            px[x, y] = c
    # divider + star
    for y in range(3, 12):
        px[8, y] = (255, 220, 90, 255) if y % 2 else (200, 150, 40, 255)
    for (x, y) in [(5, 5), (6, 6), (5, 7)]:
        px[x, y] = (230, 255, 230, 255)
    for (x, y) in [(10, 5), (10, 7), (9, 6), (11, 6), (10, 6)]:
        px[x, y] = (255, 230, 230, 255)
    # screen glare
    px[4, 3] = (255, 255, 255, 200)
    px[5, 3] = (255, 255, 255, 140)
    # home button
    px[7, 13] = body[6]
    px[8, 13] = body[6]
    img.save(os.path.join(ITEM, 'game_master_tablet.png'))


if __name__ == '__main__':
    pad_top(GREEN, 'eye', 'hider_pad')
    pad_top(RED, 'cross', 'hunter_pad')
    pad_top(PURPLE, 'house', 'lobby_pad')
    pad_bottom()
    pedestal_top_bottom()
    for name, color, icon in [('hider_button', GREEN, 'cap_eye'), ('hunter_button', RED, 'cap_cross'),
                              ('leave_button', GREY, 'x'), ('randomizer_button', GOLD, 'question'),
                              ('start_button', CYAN, 'play')]:
        pedestal_side(color, name, 'question' if name == 'randomizer_button' else None)
        if name == 'randomizer_button':
            cap(color, icon, name, icon_color=(255, 255, 255, 255), outline=(60, 34, 0, 255))
        else:
            cap(color, icon, name)
    tablet()
    print('textures written to', os.path.abspath(ROOT))
