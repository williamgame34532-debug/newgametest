"""Tiny helper for painting Minecraft box-UV textures (skins, mob textures, armor).

Every box part is described as (u, v, w, h, d) exactly like in Minecraft's
CubeListBuilder.texOffs(u, v).addBox(.., w, h, d). Faces are addressed by name
and painted in face-local coordinates, so the skin code reads like a design doc.
"""
import random
from PIL import Image

PLAYER_PARTS = {
    'head': (0, 0, 8, 8, 8), 'hat': (32, 0, 8, 8, 8),
    'body': (16, 16, 8, 12, 4), 'jacket': (16, 32, 8, 12, 4),
    'rarm': (40, 16, 4, 12, 4), 'rsleeve': (40, 32, 4, 12, 4),
    'larm': (32, 48, 4, 12, 4), 'lsleeve': (48, 48, 4, 12, 4),
    'rleg': (0, 16, 4, 12, 4), 'rpants': (0, 32, 4, 12, 4),
    'lleg': (16, 48, 4, 12, 4), 'lpants': (0, 48, 4, 12, 4),
}

SIDES = ('right', 'front', 'left', 'back')


def hexc(c, a=255):
    if isinstance(c, tuple):
        return c if len(c) == 4 else (*c, a)
    c = c.lstrip('#')
    if len(c) == 3:
        c = ''.join(ch * 2 for ch in c)
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), a)


def shade(c, f):
    r, g, b, a = hexc(c)
    return (max(0, min(255, int(r * f))), max(0, min(255, int(g * f))), max(0, min(255, int(b * f))), a)


def face_rect(part, face):
    u, v, w, h, d = part
    return {
        'top': (u + d, v, w, d),
        'bottom': (u + d + w, v, w, d),
        'right': (u, v + d, d, h),
        'front': (u + d, v + d, w, h),
        'left': (u + d + w, v + d, d, h),
        'back': (u + 2 * d + w, v + d, w, h),
    }[face]


class Painter:
    def __init__(self, w=64, h=64, parts=None, seed=1):
        self.img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        self.px = self.img.load()
        self.parts = parts or PLAYER_PARTS
        self.rng = random.Random(seed)

    def _part(self, p):
        return self.parts[p] if isinstance(p, str) else p

    def _put(self, x, y, c, noise):
        c = hexc(c)
        if noise:
            f = 1 + self.rng.uniform(-noise, noise)
            c = shade(c, f)
        if 0 <= x < self.img.width and 0 <= y < self.img.height:
            self.px[x, y] = c

    def fill(self, part, color, faces=('top', 'bottom') + SIDES, noise=0.06):
        part = self._part(part)
        for f in faces:
            fx, fy, fw, fh = face_rect(part, f)
            for y in range(fh):
                for x in range(fw):
                    self._put(fx + x, fy + y, color, noise)

    def rect(self, part, face, x0, y0, x1, y1, color, noise=0.05):
        """Inclusive rectangle in face-local pixels."""
        part = self._part(part)
        fx, fy, fw, fh = face_rect(part, face)
        for y in range(max(0, y0), min(fh - 1, y1) + 1):
            for x in range(max(0, x0), min(fw - 1, x1) + 1):
                self._put(fx + x, fy + y, color, noise)

    def dot(self, part, face, x, y, color, noise=0.0):
        self.rect(part, face, x, y, x, y, color, noise)

    def band(self, part, y0, y1, color, noise=0.05, faces=SIDES):
        """Horizontal band wrapping around the side faces of a box."""
        part = self._part(part)
        for f in faces:
            fx, fy, fw, fh = face_rect(part, f)
            self.rect(part, f, 0, y0, fw - 1, y1, color, noise)

    def clear(self, part, faces=('top', 'bottom') + SIDES):
        part = self._part(part)
        for f in faces:
            fx, fy, fw, fh = face_rect(part, f)
            for y in range(fh):
                for x in range(fw):
                    self.px[fx + x, fy + y] = (0, 0, 0, 0)

    def save(self, path):
        self.img.save(path)
