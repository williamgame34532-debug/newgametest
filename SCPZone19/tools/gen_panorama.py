"""Renders the title-screen cubemap: a dim Zone-19 corridor with flickering
ceiling panels and a red emergency lamp. Pure numpy ray casting.

    python3 gen_panorama.py <scpcb_GFX_dir> <out_dir> [size]

Writes panorama_0..5.png in Minecraft's cubemap order
(0 front, 1 right, 2 back, 3 left, 4 up, 5 down).
"""
import sys

import numpy as np
from PIL import Image

HALF_W = 3.0      # corridor half width
CEIL = 4.2        # ceiling height
EYE = 1.7
LEN = 46.0        # corridor half length
LIGHT_STEP = 6.0


def load(path, scale=1.0):
    return np.asarray(Image.open(path).convert('RGB'), dtype=np.float32) / 255.0 * scale


def sample(tex, u, v):
    h, w, _ = tex.shape
    x = (np.mod(u, 1.0) * (w - 1)).astype(np.int32)
    y = (np.mod(v, 1.0) * (h - 1)).astype(np.int32)
    return tex[y, x]


def render_face(dirs, tex):
    n = dirs.shape[0]
    o = np.array([0.0, EYE, 0.0])
    d = dirs / np.linalg.norm(dirs, axis=1, keepdims=True)
    t = np.full(n, np.inf)
    kind = np.zeros(n, np.int32)
    with np.errstate(divide='ignore', invalid='ignore'):
        cand = [
            ((HALF_W - o[0]) / d[:, 0], 1),   # +x wall
            ((-HALF_W - o[0]) / d[:, 0], 2),  # -x wall
            ((0 - o[1]) / d[:, 1], 3),        # floor
            ((CEIL - o[1]) / d[:, 1], 4),     # ceiling
            ((-LEN - o[2]) / d[:, 2], 5),     # far end (front)
            ((LEN - o[2]) / d[:, 2], 6),      # far end (back)
        ]
    for tc, k in cand:
        ok = (tc > 1e-4) & (tc < t)
        t = np.where(ok, tc, t)
        kind = np.where(ok, k, kind)
    p = o + d * t[:, None]
    col = np.zeros((n, 3), np.float32)
    normal = np.zeros((n, 3), np.float32)

    m = kind == 1
    col[m] = sample(tex['wall'], p[m, 2] / 4.0, 1 - p[m, 1] / CEIL)
    normal[m] = (-1, 0, 0)
    m = kind == 2
    col[m] = sample(tex['wall'], p[m, 2] / 4.0, 1 - p[m, 1] / CEIL)
    normal[m] = (1, 0, 0)
    # hazard band and a door on the right wall
    band = ((kind == 1) | (kind == 2)) & (p[:, 1] < 0.35)
    stripe = (np.floor((p[:, 2] + p[:, 1]) * 3.0) % 2 == 0)
    col[band & stripe] = (0.75, 0.6, 0.1)
    col[band & ~stripe] = (0.07, 0.07, 0.07)
    door = (kind == 1) & (np.abs(p[:, 2] + 8.0) < 1.1) & (p[:, 1] < 2.6)
    col[door] = sample(tex['door'], (p[door, 2] + 9.1) / 2.2, 1 - p[door, 1] / 2.6)
    door2 = (kind == 2) & (np.abs(p[:, 2] - 14.0) < 1.1) & (p[:, 1] < 2.6)
    col[door2] = sample(tex['door'], (p[door2, 2] - 12.9) / 2.2, 1 - p[door2, 1] / 2.6)

    m = kind == 3
    col[m] = sample(tex['floor'], p[m, 0] / 3.0, p[m, 2] / 3.0)
    normal[m] = (0, 1, 0)
    m = kind == 4
    col[m] = sample(tex['ceil'], p[m, 0] / 3.0, p[m, 2] / 3.0)
    normal[m] = (0, -1, 0)
    zl = np.mod(p[:, 2], LIGHT_STEP) - LIGHT_STEP / 2
    panel = (kind == 4) & (np.abs(p[:, 0]) < 0.6) & (np.abs(zl) < 1.2)
    for m, n_ in ((kind == 5, (0, 0, 1)), (kind == 6, (0, 0, -1))):
        col[m] = sample(tex['heavy'], (p[m, 0] + HALF_W) / (2 * HALF_W), 1 - p[m, 1] / CEIL)
        normal[m] = n_

    # lighting: a row of ceiling panels, one dead, plus a red emergency lamp
    light = np.full((n, 3), 0.02, np.float32)
    for k in range(-8, 9):
        zc = k * LIGHT_STEP + LIGHT_STEP / 2
        if k in (1, -3):
            continue
        lp = np.array([0.0, CEIL - 0.15, zc])
        lv = lp - p
        dist2 = np.sum(lv * lv, axis=1) + 0.4
        ndl = np.clip(np.sum(normal * lv, axis=1) / np.sqrt(dist2), 0, 1)
        inten = 2.4 if k != 2 else 0.7
        light += (np.array([0.95, 0.97, 1.0]) * (inten * ndl / dist2)[:, None])
    rp = np.array([HALF_W - 0.1, 3.4, -14.0])
    lv = rp - p
    dist2 = np.sum(lv * lv, axis=1) + 0.2
    ndl = np.clip(np.sum(normal * lv, axis=1) / np.sqrt(dist2), 0, 1)
    light += np.array([1.0, 0.08, 0.05]) * (14.0 * ndl / dist2)[:, None]

    out = col * light
    lit_panel = panel & ~np.isin(np.round((p[:, 2] - LIGHT_STEP / 2) / LIGHT_STEP), [1, -3])
    out[lit_panel] = (0.95, 0.96, 0.93)
    lamp = (kind == 1) & (np.abs(p[:, 2] + 14.0) < 0.25) & (np.abs(p[:, 1] - 3.4) < 0.18)
    out[lamp] = (1.0, 0.15, 0.1)
    fog = np.exp(-t * 0.055)[:, None]
    out = out * fog + np.array([0.01, 0.01, 0.012]) * (1 - fog)
    out = out / (1 + out * 0.6)
    return np.clip(out ** (1 / 1.6), 0, 1)


def face_dirs(face, size):
    a = (np.arange(size) + 0.5) / size * 2 - 1
    A, B = np.meshgrid(a, a)
    one = np.ones_like(A)
    return {
        0: np.stack([A, -B, -one], -1),
        1: np.stack([one, -B, A], -1),
        2: np.stack([-A, -B, one], -1),
        3: np.stack([-one, -B, -A], -1),
        4: np.stack([A, one, B], -1),
        5: np.stack([A, -one, -B], -1),
    }[face].reshape(-1, 3)


def main():
    gfx, out = sys.argv[1], sys.argv[2]
    size = int(sys.argv[3]) if len(sys.argv) > 3 else 512
    tex = {
        'wall': load(f'{gfx}/map/concretewall.jpg', 1.2),
        'floor': load(f'{gfx}/map/tilefloor.jpg', 0.8),
        'ceil': load(f'{gfx}/map/metalpanels.jpg', 0.8),
        'door': load(f'{gfx}/map/door.jpg', 1.0),
        'heavy': load(f'{gfx}/map/containment_doors.jpg', 1.0),
    }
    rng = np.random.default_rng(19)
    for f in range(6):
        img = render_face(face_dirs(f, size), tex).reshape(size, size, 3)
        img = img + rng.normal(0, 0.012, img.shape)
        Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(f'{out}/panorama_{f}.png')


if __name__ == '__main__':
    main()
