"""Entity textures: painted per box face, following the UV layout parsed from the Java models."""
import os
import random

from texlib import (Canvas, Palette, parse_model, faces, check_overlaps, shade_face, veins, stitches_h, stitches_v,
                    cracks, spots, rot_gradient, outline_rect, hexc)

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.join(HERE, '..', 'src', 'main', 'java', 'com', 'williamgame', 'echoesofsleep', 'client', 'model')
OUT = os.path.join(HERE, '..', 'src', 'main', 'resources', 'assets', 'echoesofsleep', 'textures', 'entity')

PALE = Palette('#3b3440', '#5e5560', '#837a7c', '#a69d97', '#c4bbb0', '#dcd3c6', '#ece6da')
SLEEP = Palette('#3a3840', '#5f5c63', '#8a8682', '#b1aca2', '#cdc8bd', '#e3ded4', '#f5f2ec')
ZOMBIE = Palette('#1d2b1a', '#2f4429', '#44603a', '#5b7a4b', '#749059', '#8ea86a')
BONE = Palette('#3a3226', '#625543', '#8c7d64', '#b2a487', '#d2c7aa', '#ebe3cc')
FLESH = Palette('#2a0608', '#4f0c10', '#781a1c', '#9c2f2b', '#bf4c43', '#d97264')
CHITIN = Palette('#07070a', '#121218', '#1e1d26', '#2d2b38', '#403c4d', '#5a5468')
ROBE = Palette('#1e140e', '#33231a', '#4b3427', '#634635', '#7a5944', '#906b52')
TROUSER = Palette('#120f12', '#1f1a1f', '#2d262c', '#3c3339', '#4b4047', '#5a4d54')
VSKIN = Palette('#3a2b25', '#57423a', '#76594e', '#8f7064', '#a7877a', '#bea091')
MOTHER = Palette('#262a33', '#434855', '#666b78', '#8b8f99', '#adb0b6', '#cfcfd0', '#e6e3dd')
PORCELAIN = Palette('#4b4550', '#79717c', '#a39ba3', '#c7c0c4', '#e1dbdc', '#f4f0ee')
VOID = Palette('#06030a', '#0f0818', '#1a0f29', '#28173d', '#3a2254', '#4f2f6e')
GOLD = Palette('#3d2a06', '#6e4b0c', '#a3741a', '#cfa03a', '#ecc95e', '#fbe9a0')
HAIR = Palette('#050506', '#0d0d10', '#18171c', '#24222a', '#33303a', '#423e4a')
SLATE = Palette('#0c0a10', '#1a1620', '#2a2432', '#3b3346', '#4d435a', '#62566f')
SCLERA = Palette('#6e5f5a', '#a59690', '#cfc5bd', '#e9e2da', '#f8f4ee')

VEIN_BLUE = hexc('#3c3f6e')
VEIN_VIOLET = hexc('#4a2a55')
ROT = hexc('#3a2d24')
BLOOD = hexc('#4a0a0c')
BLACK = (8, 6, 8)
NAIL = hexc('#2b2420')


class Job:
    def __init__(self, name, tw, th, seed):
        self.name = name
        self.boxes = parse_model(os.path.join(MODELS, name_to_class(name) + '.java'))
        probs = check_overlaps(self.boxes, tw, th)
        if probs:
            raise SystemExit('UV problems in %s: %s' % (name, probs))
        self.cv = Canvas(tw, th)
        self.eyes = Canvas(tw, th)
        self.rng = random.Random(seed)

    def each(self):
        for i, (part, u, v, w, h, d) in enumerate(self.boxes):
            yield part, i, faces(u, v, w, h, d), (w, h, d)

    def find(self, part, index=0):
        n = 0
        for p, u, v, w, h, d in self.boxes:
            if p == part:
                if n == index:
                    return faces(u, v, w, h, d)
                n += 1
        raise KeyError(part)

    def save(self):
        os.makedirs(OUT, exist_ok=True)
        self.cv.save(os.path.join(OUT, self.name + '.png'))
        self.eyes.save(os.path.join(OUT, self.name + '_eyes.png'))


def name_to_class(name):
    return {'stitcher': 'StitcherModel', 'sleepless': 'SleeplessModel', 'hollow_villager': 'HollowVillagerModel',
            'deep_mother': 'DeepMotherModel', 'mother_hand': 'MotherHandModel', 'the_dreamer': 'DreamerModel'}[name]


def paint(job, fs, pal, **kw):
    for fname, rect in fs.items():
        shade_face(job.cv, rect, pal, job.rng, fname, **kw)


def glow(cv, x, y, core, halo=None):
    cv.put(x, y, core)
    if halo:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if cv.a[y + dy, x + dx, 3] == 0 if 0 <= y + dy < cv.h and 0 <= x + dx < cv.w else False:
                cv.put(x + dx, y + dy, halo)


def nails(job, fs, rows=2, top=False):
    """Darkened, cracked nail at the end of a finger segment (bottom rows, or top rows for upward fingers)."""
    for fname in ('front', 'back', 'left', 'right'):
        x0, y0, w, h = fs[fname]
        rng = range(y0, y0 + rows) if top else range(y0 + h - rows, y0 + h)
        for y in rng:
            for x in range(x0, x0 + w):
                job.cv.put(x, y, NAIL if (x + y) % 3 else hexc('#4d4038'))
    end = fs['top'] if top else fs['bottom']
    for x in range(end[0], end[0] + end[2]):
        for y in range(end[1], end[1] + end[3]):
            job.cv.put(x, y, NAIL)


# =============================================================================== Stitcher
def stitcher():
    job = Job('stitcher', 128, 128, 1001)
    r = job.rng
    for part, i, fs, (w, h, d) in job.each():
        if part.startswith('spider'):
            paint(job, fs, CHITIN, base=0.5, noise=0.3)
            for f in fs.values():
                spots(job.cv, f, hexc('#6b6080'), max(1, f[2] * f[3] // 10), r, (0, 0), 0.6)  # bristles
            if part.endswith('_a'):
                stitches_h(job.cv, fs['front'][0], fs['front'][0] + fs['front'][2], fs['front'][1] + 1)
        elif part in ('ribs', 'spine', 'left_thigh', 'left_shin', 'left_foot', 'second_head', 'second_jaw'):
            paint(job, fs, BONE, base=0.62, noise=0.28)
            for f in fs.values():
                cracks(job.cv, f, hexc('#4a3f30'), max(1, f[2] * f[3] // 18), r, 0.7)
        elif part in ('right_thigh', 'right_shin', 'right_foot', 'head', 'jaw', 'right_forearm'):
            paint(job, fs, ZOMBIE, base=0.5)
            for f in fs.values():
                spots(job.cv, f, ROT, f[2] * f[3] // 25 + 1, r, (0, 1), 0.6)
                rot_gradient(job.cv, f, ROT, 0.5, r)
        elif part in ('right_hand',) or part.startswith('finger') or part.startswith('thumb'):
            paint(job, fs, PALE, base=0.5)
            if part.endswith('tip'):
                nails(job, fs, rows=1)
        else:  # pelvis, torso, shoulders, neck, right_arm: patchwork of pale and raw flesh
            paint(job, fs, PALE, base=0.55)
            for fname, f in fs.items():
                veins(job.cv, f, VEIN_BLUE, max(1, f[2] * f[3] // 30), r)
                rot_gradient(job.cv, f, ROT, 0.35, r)
    # torso: big patchwork panels sewn together
    t = job.find('torso')
    fx, fy, fw, fh = t['front']
    for y in range(fy + 6, fy + fh):
        for x in range(fx, fx + 6):
            job.cv.put(x, y, ZOMBIE.pick(0.45 + r.random() * 0.3, x, y))
    for y in range(fy, fy + 6):
        for x in range(fx + 7, fx + fw):
            job.cv.put(x, y, FLESH.pick(0.4 + r.random() * 0.35, x, y))
    stitches_h(job.cv, fx, fx + fw, fy + 6)
    stitches_v(job.cv, fx + 6, fy + 6, fy + fh)
    stitches_v(job.cv, fx + 7, fy, fy + 6)
    bx, by, bw, bh = t['back']
    stitches_v(job.cv, bx + bw // 2, by, by + bh)
    stitches_h(job.cv, bx, bx + bw, by + bh // 2 + 2)
    # exposed gut behind the ribs
    for y in range(fy + 3, fy + 10):
        for x in range(fx, fx + 5):
            job.cv.put(x, y, FLESH.pick(0.25 + r.random() * 0.3, x, y))
    # arm and shoulder scars
    for part in ('right_arm', 'right_forearm'):
        fs = job.find(part)
        for fname in ('front', 'back', 'left', 'right'):
            x0, y0, w, h = fs[fname]
            stitches_h(job.cv, x0, x0 + w, y0 + h // 2)
    s = job.find('shoulders')
    sx, sy, sw, sh = s['front']
    stitches_v(job.cv, sx + 5, sy, sy + sh)
    stitches_v(job.cv, sx + 11, sy, sy + sh)
    # main head: zombie face, mismatched sockets, sewn mouth, a scar across
    hd = job.find('head')['front']
    hx, hy = hd[0], hd[1]
    for (ex, ey, ew, eh) in ((1, 2, 3, 2), (5, 3, 1, 1)):
        for y in range(eh):
            for x in range(ew):
                job.cv.put(hx + ex + x, hy + ey + y, BLACK)
    glow(job.eyes, hx + 2, hy + 3, hexc('#e4f25a'))
    glow(job.eyes, hx + 1, hy + 3, hexc('#7f8a24'))
    glow(job.eyes, hx + 5, hy + 3, hexc('#f6ff9a'))
    stitches_h(job.cv, hx + 1, hx + 7, hy + 6)
    for k in range(5):
        job.cv.darken(hx + 2 + k, hy + 1 + k // 2, 0.55)
    # jaw teeth
    jf = job.find('jaw')['front']
    for x in range(jf[0], jf[0] + jf[2]):
        job.cv.put(x, jf[1], BONE.pick(0.8, x, 0) if x % 2 else BLACK)
    jt = job.find('jaw')['top']
    paint(job, {'top': jt}, FLESH, base=0.3)
    hb = job.find('head')['bottom']
    paint(job, {'bottom': hb}, FLESH, base=0.35)
    # second head: skull sockets with red pin-pricks
    sf = job.find('second_head')['front']
    for ex in (1, 4):
        for y in range(2, 4):
            job.cv.put(sf[0] + ex, sf[1] + y, BLACK)
        job.eyes.put(sf[0] + ex, sf[1] + 3, hexc('#ff3020'))
    job.cv.put(sf[0] + 2, sf[1] + 4, BLACK)
    job.cv.put(sf[0] + 3, sf[1] + 4, BLACK)
    sj = job.find('second_jaw')['front']
    for x in range(sj[0], sj[0] + sj[2]):
        job.cv.put(x, sj[1], BLACK if x % 2 == 0 else BONE.pick(0.9, x, 1))
    job.save()


# =============================================================================== Sleepless
def sleepless():
    job = Job('sleepless', 128, 128, 2002)
    r = job.rng
    for part, i, fs, (w, h, d) in job.each():
        if part in ('ribs', 'spine'):
            paint(job, fs, SLEEP, base=0.82, noise=0.15, ao=0.3)
        else:
            paint(job, fs, SLEEP, base=0.6, noise=0.25, grad=0.16)
            for f in fs.values():
                if f[2] * f[3] > 12:
                    veins(job.cv, f, VEIN_VIOLET, f[2] * f[3] // 40 + 1, r, (3, 9), 0.4)
            if 'finger' in part or part.endswith('foot'):
                # frostbitten black extremities
                for fname, f in fs.items():
                    x0, y0, fw, fh = f
                    for y in range(fh):
                        t = y / max(1, fh - 1)
                        for x in range(fw):
                            if part.endswith('tip') or fname == 'bottom' or t > 0.5:
                                job.cv.blend(x0 + x, y0 + y, hexc('#15121c'), 0.35 + 0.6 * t if 'tip' in part else 0.3)
                if part.endswith('tip'):
                    nails(job, fs, rows=2)
    # torso: deep shadows between ribs, sternum ridge
    t = job.find('torso')['front']
    for k in range(0, t[3], 2):
        for x in range(t[0], t[0] + t[2]):
            job.cv.darken(x, t[1] + k, 0.72)
    for y in range(t[1], t[1] + t[3]):
        job.cv.put(t[0] + t[2] // 2, y, SLEEP.pick(0.85, 0, y))
    back = job.find('torso')['back']
    for y in range(back[1], back[1] + back[3], 2):
        job.cv.put(back[0] + back[2] // 2, y, BONE.pick(0.8, 0, y))
    # head: long face with two tall empty sockets weeping black
    hf = job.find('head')['front']
    hx, hy = hf[0], hf[1]
    for ex in (1, 3):
        for y in range(2, 5):
            job.cv.put(hx + ex, hy + y, BLACK)
        for y in range(5, 9):
            if r.random() < 0.8:
                job.cv.blend(hx + ex, hy + y, (20, 16, 24), 0.75 - (y - 5) * 0.12)
        job.eyes.put(hx + ex, hy + 3, (250, 250, 255))
        job.eyes.put(hx + ex, hy + 2, (60, 60, 80))
    for x in range(hx, hx + 5):
        job.cv.darken(x, hy, 0.6)
    top = job.find('head')['top']
    for y in range(top[1], top[1] + top[3]):  # a sunken, veined scalp
        job.cv.darken(top[0] + top[2] // 2, y, 0.8)
    # jaw: a long row of teeth; the inside of the mouth is black
    jf = job.find('jaw')['front']
    for x in range(jf[0], jf[0] + jf[2]):
        job.cv.put(x, jf[1], BONE.pick(0.9, x, 0))
        job.cv.put(x, jf[1] + 1, BONE.pick(0.6, x, 1) if x % 2 else (40, 8, 12))
    for name in ('top',):
        f = job.find('jaw')[name]
        paint(job, {name: f}, FLESH, base=0.15, noise=0.2)
    paint(job, {'bottom': job.find('head')['bottom']}, FLESH, base=0.12, noise=0.2)
    job.save()


# =============================================================================== Hollow Villager
def hollow():
    job = Job('hollow_villager', 64, 64, 3003)
    r = job.rng
    for part, i, fs, dims in job.each():
        if part in ('head', 'nose', 'jaw') or part.endswith('hand'):
            paint(job, fs, VSKIN, base=0.5, noise=0.28)
            for f in fs.values():
                spots(job.cv, f, hexc('#4c3a33'), f[2] * f[3] // 20 + 1, r, (0, 1), 0.5)
        elif part.endswith('leg'):
            paint(job, fs, TROUSER, base=0.5)
        elif part.endswith('arm'):
            paint(job, fs, ROBE, base=0.32, noise=0.3, ao=0.3)
            for f in fs.values():
                rot_gradient(job.cv, f, (14, 9, 7), 0.5, r)
        else:
            paint(job, fs, ROBE, base=0.5, noise=0.3)
            for f in fs.values():
                rot_gradient(job.cv, f, (20, 12, 9), 0.6, r)
                spots(job.cv, f, (30, 8, 8), max(1, f[2] * f[3] // 60), r, (1, 2), 0.45)
    hf = job.find('head')['front']
    hx, hy = hf[0], hf[1]
    for x in range(1, 7):
        job.cv.put(hx + x, hy + 2, VSKIN.pick(0.08, x, 2))  # unibrow
    for ex in (1, 5):
        for x in range(2):
            job.cv.put(hx + ex + x, hy + 3, BLACK)
            job.cv.put(hx + ex + x, hy + 4, (25, 14, 14))
        for y in range(5, 8):
            if r.random() < 0.85:
                job.cv.blend(hx + ex + (y % 2), hy + y, (18, 6, 8), 0.8)
        job.eyes.put(hx + ex, hy + 3, (90, 10, 10))
    paint(job, {'bottom': job.find('head')['bottom']}, FLESH, base=0.15)
    jt = job.find('jaw')['top']
    paint(job, {'top': jt}, FLESH, base=0.25)
    for x in range(jt[0], jt[0] + jt[2]):
        job.cv.put(x, jt[1] + jt[3] - 1, BONE.pick(0.75, x, 0) if x % 2 else (30, 10, 10))
    jf = job.find('jaw')['front']
    for x in range(jf[0], jf[0] + jf[2]):
        job.cv.put(x, jf[1], BONE.pick(0.8, x, 0) if x % 3 else (30, 10, 10))
    b = job.find('body')['front']
    for y in range(b[1], b[1] + b[3]):
        job.cv.darken(b[0] + b[2] // 2, y, 0.6)
    for x in range(b[0], b[0] + b[2]):
        job.cv.put(x, b[1] + 7, ROBE.pick(0.15, x, 7))
    spots(job.cv, (b[0] + 1, b[1] + 2, 5, 5), BLOOD, 3, r, (1, 2), 0.7)
    job.save()


# =============================================================================== Deep Mother
def deep_mother():
    job = Job('deep_mother', 256, 256, 4004)
    r = job.rng
    for part, i, fs, dims in job.each():
        if part in ('ribs', 'spine'):
            paint(job, fs, BONE, base=0.6)
            for f in fs.values():
                cracks(job.cv, f, hexc('#3b3226'), max(1, f[2] * f[3] // 20), r)
        elif part.startswith('hair'):
            paint(job, fs, HAIR, base=0.45, noise=0.4, ao=0.05)
            for f in fs.values():
                for x in range(f[0], f[0] + f[2]):
                    if r.random() < 0.5:
                        for y in range(f[1], f[1] + f[3]):
                            job.cv.darken(x, y, 0.8)
        else:
            paint(job, fs, MOTHER, base=0.55, noise=0.3)
            for f in fs.values():
                if f[2] * f[3] > 16:
                    veins(job.cv, f, VEIN_VIOLET, f[2] * f[3] // 35 + 1, r, (4, 14), 0.5)
                rot_gradient(job.cv, f, hexc('#2c2733'), 0.35, r)
            if part.endswith('_tip') or part.endswith('thumb_tip'):
                nails(job, fs, rows=2)
            if part.endswith('_hand'):
                for f in fs.values():
                    rot_gradient(job.cv, f, hexc('#1d1a24'), 0.5, r)
    # ribcage: ridges of bone pressing through the skin
    for side in ('front', 'back', 'left', 'right'):
        f = job.find('ribcage')[side]
        for y in range(f[1] + 1, f[1] + f[3], 3):
            for x in range(f[0], f[0] + f[2]):
                job.cv.blend(x, y, BONE.pick(0.75, x, y), 0.6)
                job.cv.darken(x, y + 1, 0.6)
    f = job.find('ribcage')['front']
    for y in range(f[1], f[1] + f[3]):
        job.cv.put(f[0] + f[2] // 2, y, BONE.pick(0.65, 0, y))
        job.cv.put(f[0] + f[2] // 2 - 1, y, BONE.pick(0.5, 1, y))
    a = job.find('abdomen')['front']
    for y in range(a[1] + 2, a[1] + a[3]):
        job.cv.darken(a[0] + a[2] // 2, y, 0.55)  # sunken navel line
    # skull face
    hf = job.find('head')['front']
    hx, hy = hf[0], hf[1]
    for (ex, ey) in ((2, 4), (7, 4)):
        for y in range(3):
            for x in range(3):
                job.cv.put(hx + ex + x, hy + ey + y, BLACK)
        job.eyes.put(hx + ex + 1, hy + ey + 1, hexc('#dff0ff'))
        job.eyes.put(hx + ex + 1, hy + ey + 2, hexc('#3d5670'))
    for (ex, ey) in ((3, 1), (6, 0), (9, 2)):
        job.cv.put(hx + ex, hy + ey, BLACK)
        job.eyes.put(hx + ex, hy + ey, hexc('#ffcf8a'))
    for (x, y) in ((5, 8), (6, 8), (5, 9), (6, 9)):
        job.cv.put(hx + x, hy + y, (20, 16, 22))
    cracks(job.cv, hf, hexc('#2b2733'), 5, r)
    for x in range(hx, hx + hf[2]):
        job.cv.put(x, hy + hf[3] - 1, BONE.pick(0.85, x, 0) if x % 2 else BLACK)
    paint(job, {'bottom': job.find('head')['bottom']}, FLESH, base=0.2)
    jf = job.find('jaw')['front']
    for x in range(jf[0], jf[0] + jf[2]):
        job.cv.put(x, jf[1], BONE.pick(0.85, x, 0))
        if x % 2:
            job.cv.put(x, jf[1] + 1, BONE.pick(0.7, x, 1))
    paint(job, {'top': job.find('jaw')['top']}, FLESH, base=0.25)
    job.save()


# =============================================================================== Mother Hand
def mother_hand():
    job = Job('mother_hand', 128, 128, 5005)
    r = job.rng
    for part, i, fs, dims in job.each():
        if part == 'spurs':
            paint(job, fs, BONE, base=0.65)
        else:
            paint(job, fs, MOTHER, base=0.55, noise=0.3)
            for f in fs.values():
                if f[2] * f[3] > 16:
                    veins(job.cv, f, VEIN_VIOLET, f[2] * f[3] // 30 + 1, r, (4, 14), 0.55)
            if part.endswith('_tip'):
                nails(job, fs, rows=2, top=True)
    fa = job.find('forearm')
    for side in ('front', 'back', 'left', 'right'):
        rot_gradient(job.cv, fa[side], hexc('#1a1820'), 0.9, r)  # stained by the earth it came from
    # an eye in the palm
    pt = job.find('palm')['top']
    px, py, pw, ph = pt
    cx, cy = px + pw // 2, py + ph // 2
    for y in range(-1, 2):
        for x in range(-3, 3):
            if abs(x + 0.5) / 3.2 + abs(y) / 1.6 <= 1.0:
                job.cv.put(cx + x, cy + y, SCLERA.pick(0.7 - abs(x) * 0.08, cx + x, cy + y))
    for x in range(-4, 4):
        job.cv.darken(cx + x, cy - 2, 0.6)
        job.cv.darken(cx + x, cy + 2, 0.6)
    job.cv.put(cx - 1, cy, hexc('#a0711c'))
    job.cv.put(cx, cy, BLACK)
    job.eyes.put(cx - 1, cy, hexc('#ffb84a'))
    job.eyes.put(cx + 1, cy, hexc('#7a4d10'))
    job.eyes.put(cx, cy - 1, hexc('#5a3a0a'))
    job.save()


# =============================================================================== The Dreamer
def dreamer():
    job = Job('the_dreamer', 128, 128, 6006)
    r = job.rng

    def glow_cracks(rect, n):
        x0, y0, w, h = rect
        for _ in range(n):
            x, y = x0 + r.randrange(max(1, w)), y0 + r.randrange(max(1, h))
            for _ in range(r.randint(3, 7)):
                if x0 <= x < x0 + w and y0 <= y < y0 + h:
                    job.cv.put(x, y, hexc('#2a0f3a'))
                    job.eyes.put(x, y, hexc('#8a3cff') if r.random() < 0.7 else hexc('#c78bff'))
                x += r.choice((-1, 0, 1))
                y += r.choice((-1, 1))

    for part, i, fs, dims in job.each():
        if part.startswith('strip') or part == 'pelvis':
            paint(job, fs, VOID, base=0.5, noise=0.35)
            for f in fs.values():
                spots(job.cv, f, hexc('#c9b6ff'), max(0, f[2] * f[3] // 25), r, (0, 0), 0.6)  # stars in the cloth
            if part.startswith('strip'):
                for fname in ('front', 'back'):
                    x0, y0, w, h = fs[fname]
                    for x in range(x0, x0 + w):
                        job.cv.put(x, y0 + h - 3, GOLD.pick(0.6, x, 0))
                        # tattered, ragged ends
                        for y in range(y0 + h - 2, y0 + h):
                            if r.random() < 0.45:
                                job.cv.put(x, y, (0, 0, 0), 0)
        elif part.startswith('tail'):
            paint(job, fs, BONE, base=0.35)
        elif part.startswith('spike'):
            paint(job, fs, GOLD, base=0.55, noise=0.25)
            f = fs['front']
            job.eyes.put(f[0], f[1], hexc('#ffe08a'))
        elif part.startswith('orb'):
            paint(job, fs, SCLERA, base=0.75, noise=0.2)
            for f in fs.values():
                veins(job.cv, f, hexc('#8a1a1a'), 2, r, (2, 4), 0.6)
            f = fs['front']
            for (x, y) in ((1, 1), (2, 1), (1, 2), (2, 2)):
                job.cv.put(f[0] + x, f[1] + y, hexc('#5a2a8a'))
                job.eyes.put(f[0] + x, f[1] + y, hexc('#b070ff'))
            job.cv.put(f[0] + 2, f[1] + 2, BLACK)
            job.eyes.put(f[0] + 2, f[1] + 2, (0, 0, 0), 0)
        elif part == 'eyeball':
            paint(job, fs, SCLERA, base=0.7, noise=0.2)
            f = fs['front']
            cx, cy = f[0] + 3, f[1] + 3
            for y in range(-3, 3):
                for x in range(-3, 3):
                    dd = ((x + 0.5) ** 2 + (y + 0.5) ** 2) ** 0.5
                    if dd < 2.6:
                        c = GOLD.pick(0.85 - dd * 0.2, x, y)
                        job.cv.put(cx + x, cy + y, c)
                        job.eyes.put(cx + x, cy + y, c)
            for y in range(-3, 3):
                job.cv.put(cx, cy + y, BLACK)
                job.cv.put(cx - 1, cy + y, BLACK) if abs(y + 0.5) < 1.5 else None
                job.eyes.put(cx, cy + y, (0, 0, 0), 0)
            veins(job.cv, (f[0], f[1], 6, 6), hexc('#9a1c1c'), 2, r, (1, 2), 0.7)
        elif part in ('lid_top', 'lid_bottom', 'head', 'neck', 'chest', 'ribs'):
            paint(job, fs, PORCELAIN, base=0.6, noise=0.22)
            for f in fs.values():
                cracks(job.cv, f, hexc('#5a5260'), max(1, f[2] * f[3] // 30), r, 0.6)
        else:  # arms, hands, fingers
            paint(job, fs, SLATE, base=0.5, noise=0.3)
            if part.endswith(('f0', 'f1', 'f2')):
                for f in fs.values():
                    rot_gradient(job.cv, f, (5, 3, 8), 1.0, r)
    # glowing cracks across chest and head
    for side in ('front', 'back', 'left', 'right'):
        glow_cracks(job.find('chest')[side], 3)
    hf = job.find('head')['front']
    glow_cracks((hf[0], hf[1] + 6, hf[2], hf[3] - 6), 4)
    glow_cracks(job.find('head')['top'], 2)
    for y in range(hf[1] + 9, hf[1] + 10):
        stitches_h(job.cv, hf[0] + 2, hf[0] + 8, y, thread=(40, 30, 10))
    # lids: dark lash lines where they meet
    lt = job.find('lid_top')['front']
    for x in range(lt[0] + 1, lt[0] + lt[2] - 1):
        job.cv.put(x, lt[1] + lt[3] - 1, (70, 52, 78))
        if x % 2:
            job.cv.put(x, lt[1] + lt[3] - 2, (110, 96, 112))  # lashes
    for side in ('front', 'top'):
        f = job.find('lid_top')[side]
        cracks(job.cv, f, hexc('#5a5260'), 1, r)
    # ribs glow faintly between the bars
    for i in range(5):
        rf = job.find('ribs', i)['front']
        for x in range(rf[0], rf[0] + rf[2], 3):
            job.eyes.put(x, rf[1], hexc('#40186a'))
    job.save()


def run():
    stitcher()
    sleepless()
    hollow()
    deep_mother()
    mother_hand()
    dreamer()
    doppelganger_face()


# =============================================================================== Doppelganger mask
def doppelganger_face():
    r = random.Random(7007)
    cv = Canvas(64, 64)
    eyes = Canvas(64, 64)
    fx, fy = 8, 8  # front face of an 8x8x8 box at texOffs(0, 0)
    for y in range(8):
        for x in range(8):
            edge = min(x, 7 - x)
            a = 245 if edge >= 1 else 200
            v = 18 + int(r.random() * 10) + (6 if (x + y) % 3 == 0 else 0)
            cv.put(fx + x, fy + y, (v, v - 3, v + 2), a)
    # smeared, as if the face had been wiped off with a wet hand
    for x in range(8):
        for y in range(r.randint(4, 8), 8):
            cv.put(fx + x, fy + y, (14, 10, 14), 255 if r.random() < 0.8 else 200)
    for (x, y) in ((2, 4), (5, 4)):
        cv.put(fx + x, fy + y, (34, 30, 36), 255)
    # the mouth is sewn shut
    for x in range(2, 6):
        cv.put(fx + x, fy + 6, (60, 52, 50), 255)
    for x in (2, 4):
        cv.put(fx + x, fy + 5, (120, 100, 96), 255)
        cv.put(fx + x, fy + 7, (120, 100, 96), 255)
    # the smear wraps a little around the sides
    for y in range(8):
        for k in range(2):
            if r.random() < 0.6 - k * 0.25:
                cv.put(0 + 7 - k, fy + y, (16, 12, 16), 170 - k * 60)   # right side, front edge
                cv.put(16 + k, fy + y, (16, 12, 16), 170 - k * 60)      # left side, front edge
    eyes.put(fx + 2, fy + 4, (255, 255, 255))
    eyes.put(fx + 5, fy + 4, (255, 255, 255))
    eyes.put(fx + 2, fy + 3, (40, 40, 60))
    eyes.put(fx + 5, fy + 3, (40, 40, 60))
    os.makedirs(OUT, exist_ok=True)
    cv.save(os.path.join(OUT, 'echo_doppelganger_face.png'))
    eyes.save(os.path.join(OUT, 'echo_doppelganger_face_eyes.png'))


if __name__ == '__main__':
    run()
