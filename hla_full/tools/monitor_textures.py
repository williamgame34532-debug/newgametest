"""Textures for the HL:A monitor shader port (hla_monitor_ps30): scanlines, film grain, jitter noise.
python tools/monitor_textures.py <content addon dir>  -> materials/hla/monitor/*.vtf
(The originals from HL:A can replace them: extract the vmat of a monitor with tools/hla_convert/vpk.py.)"""
import os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'hla_convert'))
from vtex import write_vtf

def textures(seed=7):
    rng = np.random.default_rng(seed)
    # scanlines: 4-pixel period, bright line, soft falloff
    scan = np.array([1.0, 0.97, 0.80, 0.70])[:, None].repeat(4, 1)
    # film grain: soft value noise around 0.5
    g = rng.normal(0.5, 0.18, (256, 256)).clip(0, 1)
    # jitter: rows of noise near 0.5 (no shift), a few strong bands that tear the lines
    j = 0.5 + rng.normal(0, 0.04, (16, 256))
    for _ in range(10):
        c = rng.integers(0, 256); w = rng.integers(2, 6); a = rng.uniform(-0.45, 0.45)
        j[:, c:c + w] += a
    j = j.clip(0, 1)
    return {'scanlines': scan, 'grain': g, 'jitter': j}

def to_img(a):
    v = (np.asarray(a) * 255).astype(np.uint8)
    return Image.fromarray(np.stack([v, v, v], -1), 'RGB')

if __name__ == '__main__':
    out = os.path.join(sys.argv[1], 'materials/hla/monitor')
    os.makedirs(out, exist_ok=True)
    for name, a in textures().items():
        write_vtf(os.path.join(out, name + '.vtf'), to_img(a), 'BGR888', flags=0)
        print('wrote', name, np.asarray(a).shape)
