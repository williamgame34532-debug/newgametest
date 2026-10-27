"""Entity textures, painted per box face following the UV layout parsed from the Java models.

Art rules: every box is shaded as a solid form (top-light / bottom-dark gradient, lit top face, dark underside,
1px darker rim) with low-amplitude noise; palettes span near-black recesses to near-white highlights; details
(sockets, teeth, stitches, ribs, veins, nails) are drawn on top as crisp pixel shapes. Emissive details go into
the matching *_eyes.png (rendered full-bright by the EyesLayer)."""
import os
import random

from texlib import (Canvas, Palette, parse_model, faces, check_overlaps, shade_face, veins, stitches_h, stitches_v,
                    cracks, spots, lighten, hexc, SIDES)

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.join(HERE, '..', 'src', 'main', 'java', 'com', 'williamgame', 'echoesofsleep', 'client', 'model')
OUT = os.path.join(HERE, '..', 'src', 'main', 'resources', 'assets', 'echoesofsleep', 'textures', 'entity')

# ---------------------------------------------------------------------------------------------- palettes
CORPSE = Palette('#1c1418', '#3a2c2e', '#5e4c4a', '#866f68', '#a99086', '#c8afa2', '#e0cbbd', '#f3e6da')
ZOMBIE = Palette('#0c150a', '#1f3219', '#304a26', '#466434', '#5f7f45', '#7c9a58', '#9bb672', '#bcd394')
BONE = Palette('#2a2219', '#4d4232', '#76684f', '#a19272', '#c8bb9a', '#e6dcc0', '#fbf5e4')
BONEW = Palette('#5a5244', '#8a8274', '#b3ab9a', '#d9d2c3', '#ece4d2', '#f8eedc', '#fff4e0')
FLESH = Palette('#140204', '#3d070c', '#650f16', '#8f1d22', '#b53530', '#d65a4c', '#ee8a78')
CHITIN = Palette('#030305', '#0b0a10', '#16141d', '#24202e', '#342e42', '#4a4259', '#686078')
SLEEP = Palette('#120f0e', '#2a2522', '#4a433d', '#7a716a', '#a89f95', '#cfc7bb', '#e9e3d8', '#fbf7ef')
DARKTORSO = Palette('#060505', '#0e0c0b', '#1a1715', '#2a2522', '#3a332f', '#4d4440', '#605652')
SICK = Palette('#12161b', '#1d2228', '#2f3640', '#454e5a', '#5d6773', '#76808b', '#9099a3', '#b4bcc4')
ROBE = Palette('#120b07', '#1f140d', '#2e1f15', '#45301f', '#5c412b', '#735337', '#8b6646', '#a37b57')
TROUSER = Palette('#0a080a', '#151116', '#211b22', '#2e262f', '#3c323d', '#4b404c')
MOTHER = Palette('#0c0e13', '#1a1d25', '#2b303b', '#434a57', '#626a77', '#858c97', '#a9aeb6', '#cfd2d6', '#ecedee')
PORCELAIN = Palette('#3a3540', '#5e5763', '#857d88', '#aaa3ab', '#cbc5ca', '#e3dfe1', '#f6f3f2', '#ffffff')
VOID = Palette('#030106', '#0a0512', '#140b22', '#211335', '#311d4b', '#452a66', '#5c3a86')
OBSIDIAN = Palette('#040208', '#0c0814', '#161022', '#221a33', '#322646', '#46385e')
SLATE = Palette('#07060a', '#110e15', '#1c1822', '#2a2432', '#3b3346', '#4f455d', '#675b78')
SCLERA = Palette('#4a3632', '#7e6a64', '#b3a39b', '#d8cdc4', '#efe8e0', '#fffaf4')
GOLD = Palette('#3d2a06', '#6e4b0c', '#a3741a', '#cfa03a', '#ecc95e', '#fbe9a0', '#fffbe0')
HAIR = Palette('#030304', '#09090b', '#121115', '#1c1a20', '#29262e', '#3a3640')

BLACK = (6, 4, 6)
MOUTH = (34, 4, 8)
TOOTH = hexc('#efe6cf')
TOOTH_D = hexc('#b9ab8c')
NAIL = hexc('#2b2018')
VEIN = hexc('#4b2a5e')


class Job:
    def __init__(self, name, cls, tw, th, seed):
        self.name = name
        self.boxes = parse_model(os.path.join(MODELS, cls + '.java'))
        probs = check_overlaps(self.boxes, tw, th)
        if probs:
            raise SystemExit('UV problems in %s: %s' % (name, probs))
        self.cv = Canvas(tw, th)
        self.eyes = Canvas(tw, th)
        self.rng = random.Random(seed)

    def each(self):
        for part, u, v, w, h, d in self.boxes:
            yield part, faces(u, v, w, h, d), (w, h, d)

    def find(self, part, index=0):
        n = 0
        for p, u, v, w, h, d in self.boxes:
            if p == part:
                if n == index:
                    return faces(u, v, w, h, d)
                n += 1
        raise KeyError(part)

    def count(self, part):
        return sum(1 for b in self.boxes if b[0] == part)

    def save(self):
        os.makedirs(OUT, exist_ok=True)
        self.cv.save(os.path.join(OUT, self.name + '.png'))
        self.eyes.save(os.path.join(OUT, self.name + '_eyes.png'))


def paint(job, fs, pal, **kw):
    for fname, rect in fs.items():
        shade_face(job.cv, rect, pal, job.rng, fname, **kw)


def fill(cv, rect, col):
    x0, y0, w, h = rect
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            cv.put(x, y, col)


def hline(cv, x0, x1, y, col):
    for x in range(x0, x1):
        cv.put(x, y, col)


def teeth_row(cv, x0, x1, y, every=1):
    for i, x in enumerate(range(x0, x1)):
        cv.put(x, y, TOOTH if i % (every + 1) == 0 else MOUTH)


def nails(job, fs, rows=2, top=False):
    """Dark nail bed and a pale nail edge at the end of a finger segment."""
    for fname in SIDES:
        x0, y0, w, h = fs[fname]
        ys = list(range(y0, y0 + rows)) if top else list(range(y0 + h - rows, y0 + h))
        for i, y in enumerate(ys):
            for x in range(x0, x0 + w):
                edge = (i == 0) if top else (i == len(ys) - 1)
                job.cv.put(x, y, hexc('#c9bea4') if edge and fname == 'front' else NAIL)
    end = fs['top'] if top else fs['bottom']
    fill(job.cv, end, hexc('#3a2c22'))


def socket(job, x, y, w, h, glow=None, glow_dim=None, depth=True):
    """A sunken eye socket: black hole with a darkened ring around it (2px deep look)."""
    if depth:
        for yy in range(y - 1, y + h + 1):
            for xx in range(x - 1, x + w + 1):
                job.cv.darken(xx, yy, 0.62)
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            job.cv.put(xx, yy, BLACK)
    if glow:
        gx, gy = x + w // 2, y + h // 2
        job.eyes.put(gx, gy, glow)
        if glow_dim:
            job.eyes.put(gx, gy - 1, glow_dim)


def curve_bars(job, fs):
    """Rib bars: bright in the middle, falling into shadow toward both ends so they read as curved bone."""
    for fname in ('front', 'back', 'top', 'bottom'):
        x0, y0, w, h = fs[fname]
        for x in range(w):
            t = abs((x + 0.5) / w - 0.5) * 2
            for y in range(h):
                job.cv.darken(x0 + x, y0 + y, 1.0 - 0.55 * t ** 1.6)
                if t < 0.25 and fname in ('front', 'top'):
                    lighten(job.cv, x0 + x, y0 + y, 0.25)


def darken_toward_end(job, fs, start=0.0, strength=0.5):
    """Extremities darken towards the hands/feet (bottom rows of side faces, plus the underside)."""
    for fname in SIDES:
        x0, y0, w, h = fs[fname]
        for y in range(h):
            t = y / max(1, h - 1)
            if t < start:
                continue
            f = 1.0 - strength * (t - start) / max(0.01, 1 - start)
            for x in range(w):
                job.cv.darken(x0 + x, y0 + y, f)
    x0, y0, w, h = fs['bottom']
    for y in range(h):
        for x in range(w):
            job.cv.darken(x0 + x, y0 + y, 1.0 - strength)


# ================================================================================================== Stitcher
def stitcher():
    job = Job('stitcher', 'StitcherModel', 128, 128, 1001)
    r = job.rng
    for part, fs, dims in job.each():
        if part.startswith('spider'):
            paint(job, fs, CHITIN, base=0.42, grad=0.35)
            for fname, f in fs.items():
                x0, y0, w, h = f
                for y in range(h):  # bristly hairs catching the light
                    for x in range(w):
                        if r.random() < 0.13:
                            job.cv.put(x0 + x, y0 + y, hexc('#9a90aa') if r.random() < 0.5 else hexc('#6c6480'))
                if fname in SIDES and h > 3:  # red, swollen joints at both ends of each segment
                    for x in range(w):
                        job.cv.put(x0 + x, y0, hexc('#7a1418'))
                        job.cv.put(x0 + x, y0 + h - 1, hexc('#5a0c10'))
        elif part in ('ribs', 'spine', 'left_thigh', 'left_shin', 'left_foot', 'second_head', 'second_jaw'):
            paint(job, fs, BONE, base=0.62, grad=0.32)
            for f in fs.values():
                cracks(job.cv, f, hexc('#3b3226'), max(1, f[2] * f[3] // 22), r, 0.8)
        elif part in ('right_thigh', 'right_shin', 'right_foot', 'head', 'jaw', 'right_forearm'):
            paint(job, fs, ZOMBIE, base=0.5, grad=0.32)
            for f in fs.values():
                spots(job.cv, f, hexc('#1a240f'), f[2] * f[3] // 30 + 1, r, (0, 1), 0.55)
        elif part in ('right_hand',) or part.startswith('finger') or part.startswith('thumb'):
            paint(job, fs, CORPSE, base=0.48, grad=0.3)
            if part.endswith('tip'):
                nails(job, fs, rows=1)
        else:  # pelvis, torso, shoulders, neck, right_arm: pale corpse skin
            paint(job, fs, CORPSE, base=0.58, grad=0.34)
            for f in fs.values():
                if f[2] * f[3] > 20:
                    veins(job.cv, f, VEIN, f[2] * f[3] // 45 + 1, r, (3, 8), 0.45)
    # torso: three sewn-together panels (corpse / zombie / raw flesh around the exposed ribs)
    t = job.find('torso')
    fx, fy, fw, fh = t['front']
    for y in range(fy + 6, fy + fh):
        for x in range(fx + 1, fx + 6):
            job.cv.put(x, y, ZOMBIE.pick(0.62 - (y - fy) * 0.03 + r.random() * 0.08, x, y))
    for y in range(fy + 1, fy + 10):
        for x in range(fx + 1, fx + 5):
            job.cv.put(x, y, FLESH.pick(0.35 + r.random() * 0.12 - (y - fy) * 0.015, x, y))
    for x in range(fx + 1, fx + 5):  # shadows cast by the rib bars
        for k in (2, 4, 6, 8):
            job.cv.put(x, fy + k, FLESH.pick(0.08, x, k))
    stitches_h(job.cv, fx + 1, fx + fw - 1, fy + 6)
    stitches_v(job.cv, fx + 6, fy + 1, fy + fh - 1)
    bx, by, bw, bh = t['back']
    stitches_v(job.cv, bx + bw // 2, by + 1, by + bh - 1)
    stitches_h(job.cv, bx + 1, bx + bw - 1, by + bh // 2 + 2)
    for part in ('right_arm', 'right_forearm'):
        fs = job.find(part)
        for fname in SIDES:
            x0, y0, w, h = fs[fname]
            stitches_h(job.cv, x0, x0 + w, y0 + h // 2)
    s = job.find('shoulders')['front']
    stitches_v(job.cv, s[0] + 4, s[1] + 1, s[1] + s[3] - 1)
    stitches_v(job.cv, s[0] + 10, s[1] + 1, s[1] + s[3] - 1)
    # main head: zombie face with mismatched sunken sockets, sewn mouth and a scar
    hx, hy, hw, hh = job.find('head')['front']
    socket(job, hx + 1, hy + 2, 2, 2, hexc('#e8f86a'), hexc('#6f7a20'))
    socket(job, hx + 5, hy + 3, 1, 1, hexc('#f6ff9a'))
    hline(job.cv, hx + 1, hx + 7, hy + 6, CUT_COLOR)
    for x in range(hx + 2, hx + 7, 2):
        job.cv.put(x, hy + 5, THREAD_COLOR)
        job.cv.put(x, hy + 7, THREAD_COLOR)
    for k in range(4):
        job.cv.put(hx + 4 + k, hy + 1 + (k % 2), hexc('#3a1214'))
    teeth_row(job.cv, *job.find('jaw')['front'][0:1], job.find('jaw')['front'][0] + job.find('jaw')['front'][2], job.find('jaw')['front'][1], 1)
    fill(job.cv, job.find('jaw')['top'], MOUTH)
    fill(job.cv, job.find('head')['bottom'], MOUTH)
    # second skull: a cluster of spider eyes in the sockets
    sx, sy, sw, sh = job.find('second_head')['front']
    socket(job, sx + 1, sy + 2, 2, 2)
    socket(job, sx + 3, sy + 2, 2, 2)
    for (ex, ey, c) in ((1, 2, '#ff2a1a'), (2, 3, '#ff4a2a'), (3, 2, '#ff2a1a'), (4, 3, '#ff4a2a'), (2, 1, '#a0140e'), (3, 1, '#a0140e')):
        job.cv.put(sx + ex, sy + ey, hexc('#3a0606'))
        job.eyes.put(sx + ex, sy + ey, hexc(c))
    job.cv.put(sx + 2, sy + 4, BLACK)
    job.cv.put(sx + 3, sy + 4, BLACK)
    j2 = job.find('second_jaw')['front']
    teeth_row(job.cv, j2[0], j2[0] + j2[2], j2[1], 1)
    job.save()


CUT_COLOR = (12, 6, 6)
THREAD_COLOR = (239, 226, 192)


# ================================================================================================== Sleepless
def sleepless():
    job = Job('sleepless', 'SleeplessModel', 128, 128, 2002)
    r = job.rng
    for part, fs, dims in job.each():
        if part == 'ribs':
            paint(job, fs, BONEW, base=0.66, grad=0.25, noise=0.08)
            curve_bars(job, fs)
            for fname in SIDES:  # a shadow line on the underside of every rib bar
                x0, y0, w, h = fs[fname]
                for x in range(x0, x0 + w):
                    job.cv.darken(x, y0 + h - 1, 0.55)
        elif part == 'spine':
            paint(job, fs, BONEW, base=0.55, grad=0.3)
        elif part in ('torso', 'hips'):
            paint(job, fs, DARKTORSO, base=0.5, grad=0.3, noise=0.1)
        elif part in ('shoulders', 'neck'):
            paint(job, fs, SLEEP, base=0.5, grad=0.3)
        elif part in ('head', 'jaw'):
            paint(job, fs, SLEEP, base=0.72, grad=0.28)
        else:  # limbs: pale at the shoulder/hip, darkening toward hands and feet
            lvl = {'arm': 0.68, 'forearm': 0.52, 'hand': 0.32, 'thigh': 0.62, 'shin': 0.46, 'foot': 0.26}
            key = 'forearm' if 'forearm' in part else 'hand' if part.endswith('hand') else 'arm' if part.endswith('arm') \
                else 'thigh' if 'thigh' in part else 'shin' if 'shin' in part else 'foot' if 'foot' in part else 'hand'
            if 'finger' in part:
                top, bot = (0.3, 0.12) if part.endswith('tip') else (0.36, 0.28)
            else:
                top = lvl[key]
                bot = top - 0.2
            paint(job, fs, SLEEP, top=top, bottom=bot)
            if part.endswith('tip'):
                nails(job, fs, rows=2)
            for f in fs.values():
                if f[3] > 12:
                    veins(job.cv, f, VEIN, 1, r, (3, 6), 0.35)
    # torso: the dark chest where the pale ribs sit; the sternum shows through
    t = job.find('torso')
    fx, fy, fw, fh = t['front']
    for k in range(5):
        y = fy + 4 + k * 2
        for x in range(fx, fx + fw):
            job.cv.put(x, y, BONEW.pick(0.55, x, y))
            job.cv.put(x, y + 1, (8, 6, 6))  # shadow under each rib
    for y in range(fy + 2, fy + 14):
        job.cv.put(fx + fw // 2, y, BONEW.pick(0.7 if y % 2 else 0.5, 0, y))
    for side in ('left', 'right'):
        sx, sy, sw, sh = t[side]
        for k in range(5):
            for x in range(sx, sx + sw):
                job.cv.put(x, sy + 4 + k * 2, BONEW.pick(0.4, x, k))
    b = t['back']
    for y in range(b[1] + 1, b[1] + b[3] - 1, 2):
        job.cv.put(b[0] + b[2] // 2, y, BONEW.pick(0.6, 0, y))
    # the face: hollow cheeks, deep sockets with a pinprick of light, a stretched lip line full of teeth
    hx, hy, hw, hh = job.find('head')['front']
    for y in range(5, 7):
        job.cv.darken(hx, hy + y, 0.6)
        job.cv.darken(hx + hw - 1, hy + y, 0.6)
    for ex in (1, 3):
        socket(job, hx + ex, hy + 2, 1, 3)
        job.eyes.put(hx + ex, hy + 3, (255, 255, 255))
        job.cv.blend(hx + ex, hy + 5, (30, 22, 26), 0.6)  # a dark tear track
    for y in range(hy, hy + 2):
        job.cv.darken(hx + hw // 2, y, 0.75)
    hline(job.cv, hx, hx + hw, hy + 7, (20, 4, 6))
    teeth_row(job.cv, hx, hx + hw, hy + 8, 0)
    for x in range(hx, hx + hw):
        if (x - hx) % 2:
            job.cv.put(x, hy + 8, TOOTH_D)
    # jaw: a row of teeth along the top, a red-black mouth inside
    jf = job.find('jaw')['front']
    teeth_row(job.cv, jf[0], jf[0] + jf[2], jf[1], 0)
    hline(job.cv, jf[0], jf[0] + jf[2], jf[1] + 1, MOUTH)
    fill(job.cv, job.find('jaw')['top'], MOUTH)
    jt = job.find('jaw')['top']
    for x in range(jt[0], jt[0] + jt[2]):
        job.cv.put(x, jt[1] + jt[3] - 1, (90, 10, 16))
    fill(job.cv, job.find('head')['bottom'], (14, 2, 4))
    job.save()


# ================================================================================================== Hollow Villager
def hollow():
    job = Job('hollow_villager', 'HollowVillagerModel', 64, 64, 3003)
    r = job.rng
    for part, fs, dims in job.each():
        if part in ('head', 'nose', 'jaw', 'neck') or part.endswith('hand'):
            top = {'head': 0.98, 'nose': 0.9, 'jaw': 0.78, 'neck': 0.55}.get(part, 0.76)
            paint(job, fs, SICK, top=top, bottom=top - 0.26)
        elif part.endswith('leg'):
            paint(job, fs, TROUSER, base=0.42, grad=0.3)
        elif part.endswith('arm'):
            paint(job, fs, ROBE, base=0.42, grad=0.3)
        else:  # body / robe: villager cloth
            paint(job, fs, ROBE, base=0.55, grad=0.3)
    body = job.find('body')
    for fname in SIDES:  # darker belt
        x0, y0, w, h = body[fname]
        for x in range(x0, x0 + w):
            job.cv.put(x, y0 + 7, ROBE.pick(0.12, x, 7))
            job.cv.put(x, y0 + 8, ROBE.pick(0.2, x, 8))
    bx, by, bw, bh = body['front']
    for y in range(by + 1, by + 7):  # robe opening and a stain of old blood
        job.cv.darken(bx + bw // 2, y, 0.6)
    spots(job.cv, (bx + 1, by + 2, 3, 4), hexc('#3a0a0a'), 3, r, (0, 1), 0.7)
    robe = job.find('robe')
    for fname in SIDES:  # dark, frayed hem
        x0, y0, w, h = robe[fname]
        for x in range(x0, x0 + w):
            job.cv.put(x, y0 + h - 1, ROBE.pick(0.08, x, 0))
            if (x * 7) % 3 == 0:
                job.cv.put(x, y0 + h - 2, ROBE.pick(0.15, x, 1))
    for arm in ('right_arm', 'left_arm'):  # sleeve cuffs
        fs = job.find(arm)
        for fname in SIDES:
            x0, y0, w, h = fs[fname]
            hline(job.cv, x0, x0 + w, y0 + h - 2, ROBE.pick(0.15, 0, 0))
    # face: heavy brow, empty black sockets with pinpricks, a long black open mouth
    hx, hy, hw, hh = job.find('head')['front']
    hline(job.cv, hx + 1, hx + 7, hy + 2, SICK.pick(0.5, 0, 0))
    for x in (hx + 1, hx + 6):
        lighten(job.cv, x, hy + 5, 0.25)  # sharp cheekbones
    for ex in (1, 5):
        socket(job, hx + ex, hy + 3, 2, 2, depth=False)
        job.cv.darken(hx + ex - (1 if ex == 1 else -2), hy + 3, 0.8)
        job.eyes.put(hx + ex, hy + 4, (255, 236, 220))
        job.eyes.put(hx + ex + 1, hy + 4, (120, 90, 80))
        job.cv.blend(hx + ex, hy + 5, (16, 12, 16), 0.55)
    for x in range(hx + 1, hx + 7):
        job.cv.put(x, hy + hh - 1, BLACK)
    job.cv.put(hx + 1, hy + hh - 2, (20, 6, 8))
    job.cv.put(hx + 6, hy + hh - 2, (20, 6, 8))
    fill(job.cv, job.find('head')['bottom'], (8, 2, 4))
    jt = job.find('jaw')['top']
    fill(job.cv, jt, (12, 3, 5))
    for x in range(jt[0], jt[0] + jt[2]):
        job.cv.put(x, jt[1], (70, 12, 16))
    jf = job.find('jaw')['front']
    for i, x in enumerate(range(jf[0] + 1, jf[0] + jf[2] - 1)):
        job.cv.put(x, jf[1], TOOTH if i % 3 == 0 else (20, 4, 6))
    nf = job.find('nose')
    for fname in ('front',):
        x0, y0, w, h = nf[fname]
        job.cv.darken(x0, y0 + h - 1, 0.6)
        job.cv.darken(x0 + 1, y0 + h - 1, 0.6)
    job.save()


# ================================================================================================== Deep Mother
def deep_mother():
    job = Job('deep_mother', 'DeepMotherModel', 256, 256, 4004)
    r = job.rng
    for part, fs, dims in job.each():
        if part in ('ribs', 'spine'):
            paint(job, fs, BONEW, base=0.66, grad=0.3, noise=0.08)
            if part == 'ribs':
                curve_bars(job, fs)
            for fname in SIDES:
                x0, y0, w, h = fs[fname]
                for x in range(x0, x0 + w):
                    job.cv.darken(x, y0 + h - 1, 0.5)
        elif part.startswith('hair'):
            paint(job, fs, HAIR, base=0.38, grad=0.25, noise=0.15)
            for fname in SIDES:
                x0, y0, w, h = fs[fname]
                for x in range(x0, x0 + w):  # wet highlight strands
                    if (x + int(part[-1])) % 2 == 0:
                        for y in range(y0, y0 + h, 3):
                            job.cv.put(x, y, HAIR.pick(0.85, x, y))
        else:
            if 'finger' in part or 'thumb' in part:
                top, bot = (0.34, 0.2) if part.endswith('tip') else (0.42, 0.3)
            elif part.endswith('_hand'):
                top, bot = 0.45, 0.32
            elif 'forearm' in part:
                top, bot = 0.58, 0.44
            elif part.endswith('_arm'):
                top, bot = 0.7, 0.56
            elif part == 'head':
                top, bot = 0.78, 0.6
            elif part == 'jaw':
                top, bot = 0.62, 0.48
            else:
                top, bot = 0.66, 0.46
            paint(job, fs, MOTHER, top=top, bottom=bot)
            if part.endswith('_tip'):
                nails(job, fs, rows=2)
            if part.endswith('_arm') or 'forearm' in part:  # veins only around the joints
                for fname in SIDES:
                    x0, y0, w, h = fs[fname]
                    veins(job.cv, (x0, y0, w, 5), VEIN, 2, r, (2, 5), 0.55)
                    veins(job.cv, (x0, y0 + h - 5, w, 5), VEIN, 2, r, (2, 5), 0.55)
            if part.endswith('_hand'):
                for fname in ('front', 'top'):
                    x0, y0, w, h = fs[fname]
                    for x in range(x0 + 1, x0 + w, 2):  # knuckles
                        job.cv.darken(x, y0 + (h - 1 if fname == 'front' else 0), 0.55)
    # ribcage: a dark red cavity behind bone-white ribs and a sternum
    rc = job.find('ribcage')
    for fname in ('front', 'left', 'right'):
        x0, y0, w, h = rc[fname]
        for y in range(y0 + 1, y0 + h - 1):
            for x in range(x0 + 1, x0 + w - 1):
                job.cv.put(x, y, FLESH.pick(0.1 + 0.18 * ((y - y0) % 3 == 1), x, y))
        for y in range(y0 + 1, y0 + h - 1, 3):
            for x in range(x0 + 1, x0 + w - 1):
                job.cv.put(x, y, BONEW.pick(0.75, x, y))
                job.cv.put(x, y + 1, BONEW.pick(0.42, x, y))
                if y + 2 < y0 + h - 1:
                    job.cv.put(x, y + 2, (10, 2, 4))
    x0, y0, w, h = rc['front']
    for y in range(y0 + 1, y0 + h - 1):
        job.cv.put(x0 + w // 2 - 1, y, BONEW.pick(0.6, 0, y))
        job.cv.put(x0 + w // 2, y, BONEW.pick(0.8, 1, y))
    ab = job.find('abdomen')['front']
    for y in range(ab[1] + 2, ab[1] + ab[3] - 2):
        job.cv.darken(ab[0] + ab[2] // 2, y, 0.55)
    # skull face
    hx, hy, hw, hh = job.find('head')['front']
    for ex in (2, 7):
        socket(job, hx + ex, hy + 4, 3, 3)
        job.cv.put(hx + ex + 1, hy + 5, (40, 4, 8))
        job.eyes.put(hx + ex + 1, hy + 5, hexc('#e6f4ff'))
        job.eyes.put(hx + ex + 1, hy + 6, hexc('#2d4560'))
    for (ex, ey) in ((3, 1), (6, 1), (9, 2)):
        socket(job, hx + ex, hy + ey, 1, 1, depth=False)
        job.eyes.put(hx + ex, hy + ey, hexc('#ffcf8a'))
    for (x, y) in ((5, 8), (6, 8), (5, 9), (6, 9)):
        job.cv.put(hx + x, hy + y, BLACK)
    cracks(job.cv, (hx, hy, hw, 4), hexc('#2b2733'), 3, r)
    teeth_row(job.cv, hx + 1, hx + hw - 1, hy + hh - 1, 0)
    for x in range(hx + 1, hx + hw - 1, 2):
        job.cv.put(x, hy + hh - 2, TOOTH_D)
    fill(job.cv, job.find('head')['bottom'], MOUTH)
    jf = job.find('jaw')['front']
    teeth_row(job.cv, jf[0] + 1, jf[0] + jf[2] - 1, jf[1], 0)
    for x in range(jf[0] + 1, jf[0] + jf[2] - 1, 2):
        job.cv.put(x, jf[1] + 1, TOOTH_D)
    fill(job.cv, job.find('jaw')['top'], MOUTH)
    job.save()


# ================================================================================================== Mother Hand
def mother_hand():
    job = Job('mother_hand', 'MotherHandModel', 128, 128, 5005)
    r = job.rng
    for part, fs, dims in job.each():
        if part == 'spurs':
            paint(job, fs, BONEW, base=0.62, grad=0.35)
        elif part == 'forearm':
            # pale near the wrist (top), grey towards the elbow buried in the ground
            paint(job, fs, MOTHER, top=0.78, bottom=0.36)
            for fname in SIDES:
                x0, y0, w, h = fs[fname]
                veins(job.cv, (x0, y0, w, 8), VEIN, 2, r, (3, 6), 0.5)
                for y in range(y0 + h - 3, y0 + h):  # the torn end where it comes out of the stone
                    for x in range(x0, x0 + w):
                        job.cv.put(x, y, FLESH.pick(0.15 + 0.15 * (y - (y0 + h - 3)) * (r.random() < 0.6), x, y))
            fill(job.cv, fs['bottom'], (24, 2, 6))
            bx, by, bw, bh = fs['bottom']
            fill(job.cv, (bx + 2, by + 2, bw - 4, bh - 4), BONEW.pick(0.5, 0, 0))  # bone at the cut end
        elif part in ('wrist', 'palm'):
            paint(job, fs, MOTHER, top=0.8, bottom=0.62)
        else:
            tip = part.endswith('_tip')
            top, bot = (0.5, 0.66) if tip else (0.66, 0.72)  # fingers point up: knuckle end darker
            paint(job, fs, MOTHER, top=top, bottom=bot)
            for fname in SIDES:
                x0, y0, w, h = fs[fname]
                for x in range(x0, x0 + w):
                    job.cv.darken(x, y0 + h - 1, 0.62)  # knuckle crease
            if tip:
                nails(job, fs, rows=2, top=True)
    # an eye in the palm
    px, py, pw, ph = job.find('palm')['top']
    cx, cy = px + pw // 2, py + ph // 2
    for y in range(-1, 2):
        for x in range(-3, 3):
            if abs(x + 0.5) / 3.2 + abs(y) / 1.6 <= 1.0:
                job.cv.put(cx + x, cy + y, SCLERA.pick(0.8 - abs(x) * 0.08, cx + x, cy + y))
    for x in range(-4, 4):
        job.cv.darken(cx + x, cy - 2, 0.5)
        job.cv.darken(cx + x, cy + 2, 0.5)
    job.cv.put(cx - 1, cy, hexc('#a0711c'))
    job.cv.put(cx, cy, BLACK)
    job.eyes.put(cx - 1, cy, hexc('#ffb84a'))
    job.eyes.put(cx + 1, cy, hexc('#7a4d10'))
    job.save()


# ================================================================================================== The Dreamer
def dreamer():
    job = Job('the_dreamer', 'DreamerModel', 128, 128, 6006)
    r = job.rng

    def glow_cracks(rect, n):
        x0, y0, w, h = rect
        for _ in range(n):
            x, y = x0 + r.randrange(max(1, w)), y0 + r.randrange(max(1, h))
            for _ in range(r.randint(3, 7)):
                if x0 < x < x0 + w - 1 and y0 < y < y0 + h - 1:
                    job.cv.put(x, y, hexc('#2a0f3a'))
                    job.eyes.put(x, y, hexc('#8a3cff') if r.random() < 0.7 else hexc('#d0a0ff'))
                x += r.choice((-1, 0, 1))
                y += r.choice((-1, 1))

    for part, fs, dims in job.each():
        if part.startswith('strip') or part == 'pelvis':
            paint(job, fs, VOID, base=0.45, grad=0.35)
            for f in fs.values():
                spots(job.cv, f, hexc('#d8c8ff'), max(0, f[2] * f[3] // 28), r, (0, 0), 0.7)
            if part.startswith('strip'):
                for fname in ('front', 'back'):
                    x0, y0, w, h = fs[fname]
                    for x in range(x0, x0 + w):
                        job.cv.put(x, y0 + h - 3, GOLD.pick(0.7, x, 0))
                        for y in range(y0 + h - 2, y0 + h):
                            if r.random() < 0.45:
                                job.cv.put(x, y, (0, 0, 0), 0)
        elif part.startswith('tail'):
            paint(job, fs, BONE, base=0.4, grad=0.35)
        elif part.startswith('spike'):
            # dark bone / obsidian spikes whose tips burn
            paint(job, fs, OBSIDIAN, base=0.45, grad=0.4)
            for fname in SIDES:
                x0, y0, w, h = fs[fname]
                job.cv.put(x0, y0, hexc('#e8d0ff'))
                job.cv.put(x0, y0 + 1, hexc('#8a5ac0'))
                job.eyes.put(x0, y0, hexc('#d8a8ff'))
                job.eyes.put(x0, y0 + 1, hexc('#6a2aa0'))
            job.eyes.put(fs['top'][0], fs['top'][1], hexc('#ffffff'))
        elif part.startswith('orb'):
            paint(job, fs, SCLERA, base=0.72, grad=0.3)
            for f in fs.values():
                veins(job.cv, f, hexc('#8a1a1a'), 2, r, (2, 4), 0.7)
            f = fs['front']
            for (x, y) in ((1, 1), (2, 1), (1, 2), (2, 2)):
                job.cv.put(f[0] + x, f[1] + y, hexc('#5a2a8a'))
                job.eyes.put(f[0] + x, f[1] + y, hexc('#b070ff'))
            job.cv.put(f[0] + 2, f[1] + 1, BLACK)
            job.eyes.put(f[0] + 2, f[1] + 1, (0, 0, 0), 0)
        elif part == 'eyeball':
            paint(job, fs, SCLERA, base=0.78, grad=0.2, noise=0.06, rim=0.9)
            f = fs['front']
            veins(job.cv, f, hexc('#a01818'), 4, r, (2, 3), 0.8)
            cx, cy = f[0] + 3, f[1] + 3
            for y in range(-3, 3):
                for x in range(-3, 3):
                    dd = ((x + 0.5) ** 2 + (y + 0.5) ** 2) ** 0.5
                    if dd < 2.7:
                        c = GOLD.pick(0.95 - dd * 0.24, x, y)
                        if dd > 2.1:
                            c = hexc('#4a2a06')  # dark limbal ring
                        job.cv.put(cx + x, cy + y, c)
                        job.eyes.put(cx + x, cy + y, c if dd <= 2.1 else (60, 30, 0))
            for y in range(-3, 3):
                job.cv.put(cx, cy + y, BLACK)
                job.eyes.put(cx, cy + y, (0, 0, 0), 0)
            job.cv.put(cx - 2, cy - 2, (255, 255, 255))
        elif part in ('lid_top', 'lid_bottom', 'head', 'neck', 'chest', 'ribs'):
            paint(job, fs, PORCELAIN, base=0.66 if part != 'neck' else 0.5, grad=0.3)
            for f in fs.values():
                cracks(job.cv, f, hexc('#5a5260'), max(1, f[2] * f[3] // 35), r, 0.7)
        elif part.endswith(('f0', 'f1', 'f2')) or part.endswith('_hand'):
            # pale hands, fingertips stained dark
            paint(job, fs, PORCELAIN, top=0.62, bottom=0.42)
            if part.endswith(('f0', 'f1', 'f2')):
                for fname in SIDES:
                    x0, y0, w, h = fs[fname]
                    for y in range(y0 + h - 2, y0 + h):
                        for x in range(x0, x0 + w):
                            job.cv.put(x, y, SLATE.pick(0.2, x, y))
                fill(job.cv, fs['bottom'], SLATE.pick(0.1, 0, 0))
        else:  # the six arms: dark slate with a bright edge highlight
            paint(job, fs, SLATE, base=0.42, grad=0.35)
            for fname in SIDES:
                x0, y0, w, h = fs[fname]
                for y in range(y0 + 1, y0 + h - 1):
                    lighten(job.cv, x0, y, 0.28)
            for x in range(fs['top'][0], fs['top'][0] + fs['top'][2]):
                lighten(job.cv, x, fs['top'][1], 0.3)
    for side in SIDES:
        glow_cracks(job.find('chest')[side], 3)
    hf = job.find('head')['front']
    glow_cracks((hf[0], hf[1] + 6, hf[2], hf[3] - 6), 4)
    glow_cracks(job.find('head')['top'], 2)
    # a stitched-shut mouth
    for x in range(hf[0] + 3, hf[0] + 7):  # a thin, sealed mouth line
        job.cv.put(x, hf[1] + 9, (58, 48, 64))
    job.cv.put(hf[0] + 3, hf[1] + 8, (120, 108, 124))
    job.cv.put(hf[0] + 6, hf[1] + 8, (120, 108, 124))
    # the eye region behind the lids is a deep shadow so the gap reads as a slit of gold
    lt = job.find('lid_top')['front']
    for x in range(lt[0] + 1, lt[0] + lt[2] - 1):
        job.cv.put(x, lt[1] + lt[3] - 1, (34, 22, 40))
        if 2 <= x - lt[0] <= lt[2] - 3:
            job.eyes.put(x, lt[1] + lt[3] - 1, (120, 80, 10))  # gold light leaking through the closed lids
    lb = job.find('lid_bottom')['front']
    for x in range(lb[0] + 1, lb[0] + lb[2] - 1):
        job.cv.darken(x, lb[1], 0.75)
    for i in range(job.count('ribs')):
        rf = job.find('ribs', i)['front']
        for x in range(rf[0] + 1, rf[0] + rf[2] - 1, 3):
            job.eyes.put(x, rf[1] + 1, hexc('#40186a'))
    job.save()


# ================================================================================================== Doppelganger mask
def doppelganger_face():
    r = random.Random(7007)
    cv = Canvas(64, 64)
    eyes = Canvas(64, 64)
    fx, fy = 8, 8  # front face of an 8x8x8 box at texOffs(0, 0)
    for y in range(8):
        for x in range(8):
            edge = min(x, 7 - x)
            a = 248 if edge >= 1 else 205
            v = 16 + int(r.random() * 8) + (5 if (x + y) % 3 == 0 else 0)
            cv.put(fx + x, fy + y, (v, v - 3, v + 2), a)
    for x in range(8):  # wiped-off smear running down
        for y in range(r.randint(4, 8), 8):
            cv.put(fx + x, fy + y, (12, 8, 12), 255)
    for (x, y) in ((2, 4), (5, 4)):  # the faint dents where eyes were
        cv.put(fx + x, fy + y, (40, 34, 42), 255)
        cv.put(fx + x, fy + y - 1, (28, 24, 30), 255)
    for x in range(2, 6):  # the mouth is sewn shut
        cv.put(fx + x, fy + 6, (12, 6, 6), 255)
    for x in (2, 4):
        cv.put(fx + x, fy + 5, (239, 226, 192), 255)
        cv.put(fx + x, fy + 7, (190, 178, 150), 255)
    for y in range(8):
        for k in range(2):
            if r.random() < 0.6 - k * 0.25:
                cv.put(7 - k, fy + y, (14, 10, 14), 170 - k * 60)
                cv.put(16 + k, fy + y, (14, 10, 14), 170 - k * 60)
    eyes.put(fx + 2, fy + 4, (255, 255, 255))
    eyes.put(fx + 5, fy + 4, (255, 255, 255))
    eyes.put(fx + 2, fy + 3, (40, 40, 60))
    eyes.put(fx + 5, fy + 3, (40, 40, 60))
    os.makedirs(OUT, exist_ok=True)
    cv.save(os.path.join(OUT, 'echo_doppelganger_face.png'))
    eyes.save(os.path.join(OUT, 'echo_doppelganger_face_eyes.png'))


def run():
    stitcher()
    sleepless()
    hollow()
    deep_mother()
    mother_hand()
    dreamer()
    doppelganger_face()


if __name__ == '__main__':
    run()
