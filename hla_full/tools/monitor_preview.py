# numpy twin of shadersrc/hla_monitor_ps30.hlsl, to preview the effect on a screen image
import sys, numpy as np
from PIL import Image
sys.path.insert(0,'/home/user/newgametest/hla_full/tools'); import monitor_textures as mt
T = mt.textures()
def samp(a, u, v):  # wrap, nearest-bilinear-ish
    h, w = a.shape[:2]
    x = (np.mod(u, 1) * w).astype(int) % w; y = (np.mod(v, 1) * h).astype(int) % h
    return a[y, x]
def run(img, t, C0=(0, 0.6, 0.04, 0.12), C1=(0.12, 0.0, -0.12, 128), C2=(0.95, 1.0, 1.0, 0.4), C3=(0.0,)):
    base = np.asarray(img.convert('RGB'), float) / 255; H, W = base.shape[:2]
    v, u = np.mgrid[0:H, 0:W]; u = (u + .5) / W; v = (v + .5) / H
    jy = v * 2 + t * C0[1]
    jit = np.stack([samp(T['jitter'], jy, .125) - 1, samp(T['jitter'], jy, .375), samp(T['jitter'], jy, .625) + 1], -1)
    shift = jit * np.array(C1[:3]) * 0.01
    col = np.stack([samp(base[..., c], u + shift[..., c], v) for c in range(3)], -1)
    col *= samp(T['scanlines'], u, v * C1[3] + t * C3[0])[..., None] * np.array(C2[:3])
    d = np.stack([u * 2 - 1, v * 2 - 1], -1) * np.array([0.55, 0.75])
    col *= np.clip(1 - (d ** 2).sum(-1) * C2[3], 0, 1)[..., None]
    contrast = 0.75 + 0.25 * np.sin(t * 13) * np.sin(t * 3.7)
    grain = samp(T['grain'], u + t * 19.2, v + t * 7.1) - 0.5
    col *= (grain * C0[3] * contrast * 2 + 1)[..., None]
    return Image.fromarray((col.clip(0, 1) * 255).astype(np.uint8))
src = Image.open(sys.argv[1])
a = run(src, 1.7); b = run(src, 4.2)
c = Image.new('RGB', (src.width, src.height * 2 + 0)); 
top = src.convert('RGB').crop((0, 0, src.width, src.height // 2)); 
out = Image.new('RGB', (src.width * 2, src.height)); out.paste(src.convert('RGB'), (0, 0)); out.paste(a, (src.width, 0))
out.save(sys.argv[2]); a.crop((0, 0, 512, 256)).resize((1024, 512), Image.NEAREST).save(sys.argv[2].replace('.png', '_zoom.png'))
