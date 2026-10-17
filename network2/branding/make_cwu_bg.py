# The CWU terminal: the glass of the Alliance terminal turned amber (bg_cmb.png -> bg_cwu.png).
import sys
import numpy as np
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
im = np.asarray(Image.open(src).convert('RGB')).astype(np.float32) / 255
lum = im @ np.array([0.30, 0.55, 0.15], np.float32)
amber = np.array([1.0, 0.70, 0.22], np.float32)
out = np.clip(lum[..., None] * amber * 1.25 + (lum[..., None] ** 2.2) * 0.25, 0, 1)
Image.fromarray((out * 255).astype(np.uint8)).save(dst, optimize=True)
