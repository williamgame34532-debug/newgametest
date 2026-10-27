"""Shared pixel-art helpers for the Echoes of Sleep texture generator (Pillow + numpy)."""
import math
import random
import re

import numpy as np
from PIL import Image


def hexc(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


class Palette:
    """Dark-to-light colour ramp; value 0..1 picks a tone (with ordered dithering between tones)."""

    BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5

    def __init__(self, *colors):
        self.c = [hexc(c) if isinstance(c, str) else c for c in colors]

    def pick(self, v, x=0, y=0, dither=0.6):
        n = len(self.c)
        f = max(0.0, min(0.9999, v)) * (n - 1)
        f += self.BAYER[y % 4][x % 4] * dither
        i = int(max(0, min(n - 1, round(f))))
        return self.c[i]


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), dtype=np.uint8)

    def put(self, x, y, rgb, alpha=255):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x, 0:3] = rgb[:3]
            self.a[y, x, 3] = alpha

    def get(self, x, y):
        return tuple(int(v) for v in self.a[y, x, 0:3])

    def blend(self, x, y, rgb, t, alpha=255):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            if self.a[y, x, 3] == 0:
                self.put(x, y, rgb, alpha)
                return
            old = self.a[y, x, 0:3].astype(float)
            self.a[y, x, 0:3] = (old * (1 - t) + np.array(rgb[:3], dtype=float) * t).astype(np.uint8)
            self.a[y, x, 3] = max(self.a[y, x, 3], alpha)

    def darken(self, x, y, f):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h and self.a[y, x, 3]:
            self.a[y, x, 0:3] = (self.a[y, x, 0:3].astype(float) * f).clip(0, 255).astype(np.uint8)

    def save(self, path):
        Image.fromarray(self.a, 'RGBA').save(path)


def value_noise(w, h, cell, rng):
    gw, gh = int(math.ceil(w / cell)) + 2, int(math.ceil(h / cell)) + 2
    grid = np.array([[rng.random() for _ in range(gw)] for _ in range(gh)])
    out = np.zeros((h, w))
    for y in range(h):
        for x in range(w):
            gx, gy = x / cell, y / cell
            x0, y0 = int(gx), int(gy)
            fx, fy = gx - x0, gy - y0
            fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
            a = grid[y0][x0] * (1 - fx) + grid[y0][x0 + 1] * fx
            b = grid[y0 + 1][x0] * (1 - fx) + grid[y0 + 1][x0 + 1] * fx
            out[y, x] = a * (1 - fy) + b * fy
    return out


def fbm(w, h, rng, cells=(6, 3, 1.5), weights=(0.5, 0.3, 0.2)):
    out = np.zeros((h, w))
    for c, wt in zip(cells, weights):
        out += value_noise(w, h, c, rng) * wt
    return out


# ---------------------------------------------------------------------------- model parsing
BOX_RE = re.compile(r'texOffs\((\d+),\s*(\d+)\)\.addBox\(([^;]*?)\)(?=\s*(?:\.texOffs|,\s*PartPose))', re.S)
PART_RE = re.compile(r'addOrReplaceChild\("(\w+)",\s*CubeListBuilder\.create\(\)(.*?)PartPose', re.S)


def parse_model(java_path):
    """Return [(part_name, u, v, w, h, d)] for every box in a Java model's createLayer."""
    src = open(java_path, encoding='utf-8').read()
    out = []
    for m in PART_RE.finditer(src):
        name, body = m.group(1), m.group(2) + 'PartPose'
        for b in re.finditer(r'texOffs\((\d+),\s*(\d+)\)\.addBox\(([^\n]*)', body):
            u, v = int(b.group(1)), int(b.group(2))
            args = b.group(3)
            nums = re.findall(r'-?\d+(?:\.\d+)?F?', args.split('new CubeDeformation')[0])
            vals = [float(n.rstrip('F')) for n in nums[:6]]
            if len(vals) < 6:
                continue
            w, h, d = (int(math.ceil(abs(x) - 1e-6)) for x in vals[3:6])
            out.append((name, u, v, w, h, d))
    return out


def faces(u, v, w, h, d):
    return {
        'top': (u + d, v, w, d), 'bottom': (u + d + w, v, w, d),
        'right': (u, v + d, d, h), 'front': (u + d, v + d, w, h),
        'left': (u + d + w, v + d, d, h), 'back': (u + 2 * d + w, v + d, w, h),
    }


def check_overlaps(boxes, tw, th):
    occ = {}
    problems = []
    for (name, u, v, w, h, d) in boxes:
        for fname, (x, y, fw, fh) in faces(u, v, w, h, d).items():
            for yy in range(y, y + fh):
                for xx in range(x, x + fw):
                    if not (0 <= xx < tw and 0 <= yy < th):
                        problems.append('%s out of texture' % name)
                        continue
                    key = (xx, yy)
                    if key in occ and occ[key][0] != name:
                        problems.append('%s overlaps %s at %s' % (name, occ[key][0], key))
                    occ[key] = (name, fname)
    return sorted(set(problems))[:10]


# ---------------------------------------------------------------------------- face shading
SIDES = ('front', 'back', 'left', 'right')


def shade_face(cv, rect, pal, rng, face, base=0.55, noise=0.12, ao=None, grad=0.3, cell=None, rim=0.75,
               top=None, bottom=None):
    """Paint one box face: low-amplitude noise over a strong top-light / bottom-dark gradient, a lit top face,
    a dark underside, slightly darker side faces, and a 1px darker rim so every box reads as a solid form.
    If top/bottom are given they override base+grad (value at the top row / bottom row of side faces)."""
    x0, y0, w, h = rect
    if w <= 0 or h <= 0:
        return
    n = fbm(w, h, rng, cells=(max(2, (cell or max(w, h) / 3)), 2, 1)) if (w > 1 or h > 1) else np.full((h, w), 0.5)
    t_val = top if top is not None else base + grad * 0.5
    b_val = bottom if bottom is not None else base - grad * 0.5
    for y in range(h):
        for x in range(w):
            if face in SIDES:
                f = y / (h - 1) if h > 1 else 0.5
                v = t_val + (b_val - t_val) * f
            elif face == 'top':
                v = t_val + 0.12
            else:
                v = b_val - 0.22
            if face in ('left', 'right'):
                v -= 0.06
            v += (n[y, x] - 0.5) * noise * 2
            cv.put(x0 + x, y0 + y, pal.pick(v, x0 + x, y0 + y, 0.35))
            if min(x, y, w - 1 - x, h - 1 - y) == 0 and (w > 2 and h > 2):
                cv.darken(x0 + x, y0 + y, rim)


def lighten(cv, x, y, f):
    x, y = int(x), int(y)
    if 0 <= x < cv.w and 0 <= y < cv.h and cv.a[y, x, 3]:
        c = cv.a[y, x, 0:3].astype(float)
        cv.a[y, x, 0:3] = (c + (255 - c) * f).clip(0, 255).astype(np.uint8)


def veins(cv, rect, color, count, rng, length=(4, 12), alpha=0.55):
    x0, y0, w, h = rect
    if w < 3 or h < 3:
        return
    for _ in range(count):
        x, y = x0 + rng.randrange(w), y0 + rng.randrange(h)
        dx, dy = rng.choice([(0, 1), (1, 1), (-1, 1), (1, 0)])
        for _ in range(rng.randint(*length)):
            if not (x0 <= x < x0 + w and y0 <= y < y0 + h):
                break
            cv.blend(x, y, color, alpha)
            if rng.random() < 0.35:
                dx = max(-1, min(1, dx + rng.choice((-1, 1))))
            x += dx
            y += dy if dy else rng.choice((0, 1))
            if rng.random() < 0.12:  # fork
                fx, fy = x, y
                for _ in range(rng.randint(2, 4)):
                    fx += rng.choice((-1, 1))
                    fy += 1
                    if x0 <= fx < x0 + w and y0 <= fy < y0 + h:
                        cv.blend(fx, fy, color, alpha * 0.7)


THREAD = (239, 226, 192)
CUT = (12, 6, 6)
INFLAMED = (150, 40, 36)


def stitches_h(cv, x0, x1, y, thread=THREAD, rng=None, spacing=3, inflame=True):
    """A horizontal sewn seam: 1px black cut, cream thread crossing it, inflamed red skin along it."""
    if inflame:
        for x in range(x0, x1):
            cv.blend(x, y - 2, INFLAMED, 0.25)
            cv.blend(x, y + 2, INFLAMED, 0.25)
            cv.blend(x, y - 1, INFLAMED, 0.45)
            cv.blend(x, y + 1, INFLAMED, 0.45)
    for x in range(x0, x1):
        cv.put(x, y, CUT)
    for x in range(x0 + 1, x1 - 1, spacing):
        cv.put(x, y - 1, thread)
        cv.put(x, y + 1, tuple(int(c * 0.8) for c in thread))
        cv.put(x, y, tuple(int(c * 0.9) for c in thread))


def stitches_v(cv, x, y0, y1, thread=THREAD, spacing=3, inflame=True):
    if inflame:
        for y in range(y0, y1):
            cv.blend(x - 2, y, INFLAMED, 0.25)
            cv.blend(x + 2, y, INFLAMED, 0.25)
            cv.blend(x - 1, y, INFLAMED, 0.45)
            cv.blend(x + 1, y, INFLAMED, 0.45)
    for y in range(y0, y1):
        cv.put(x, y, CUT)
    for y in range(y0 + 1, y1 - 1, spacing):
        cv.put(x - 1, y, thread)
        cv.put(x + 1, y, tuple(int(c * 0.8) for c in thread))
        cv.put(x, y, tuple(int(c * 0.9) for c in thread))


def cracks(cv, rect, color, count, rng, alpha=0.8):
    x0, y0, w, h = rect
    for _ in range(count):
        x, y = x0 + rng.randrange(max(1, w)), y0 + rng.randrange(max(1, h))
        for _ in range(rng.randint(3, 8)):
            if x0 <= x < x0 + w and y0 <= y < y0 + h:
                cv.blend(x, y, color, alpha)
            x += rng.choice((-1, 0, 1))
            y += rng.choice((-1, 1))


def spots(cv, rect, color, count, rng, radius=(1, 2), alpha=0.5):
    x0, y0, w, h = rect
    for _ in range(count):
        cx, cy = x0 + rng.randrange(max(1, w)), y0 + rng.randrange(max(1, h))
        r = rng.randint(*radius)
        for yy in range(cy - r, cy + r + 1):
            for xx in range(cx - r, cx + r + 1):
                if x0 <= xx < x0 + w and y0 <= yy < y0 + h and (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r + 0.5:
                    cv.blend(xx, yy, color, alpha)


def rot_gradient(cv, rect, color, strength, rng):
    """Decay creeping up from the bottom of a face."""
    x0, y0, w, h = rect
    for y in range(h):
        t = (y / max(1, h - 1)) ** 2 * strength
        for x in range(w):
            if rng.random() < t:
                cv.blend(x0 + x, y0 + y, color, 0.35 + 0.4 * t)


def outline_rect(cv, rect, f=0.7):
    x0, y0, w, h = rect
    for x in range(x0, x0 + w):
        cv.darken(x, y0, f)
        cv.darken(x, y0 + h - 1, f)
    for y in range(y0, y0 + h):
        cv.darken(x0, y, f)
        cv.darken(x0 + w - 1, y, f)
