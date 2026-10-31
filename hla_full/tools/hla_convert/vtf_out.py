"""Write Source 1 VTF 7.2 textures with DXT1/DXT5 compression and a full mip chain (Pillow does the DXT)."""
import io
import struct
from PIL import Image

FMT = {'DXT1': 13, 'DXT5': 15}
FLAG_TRILINEAR, FLAG_CLAMPS, FLAG_CLAMPT, FLAG_NORMAL, FLAG_ONEBITALPHA, FLAG_EIGHTBITALPHA = 0x2, 0x4, 0x8, 0x80, 0x1000, 0x2000


def _dxt(img, fmt):
    b = io.BytesIO()
    img.save(b, 'DDS', pixel_format=fmt)
    d = b.getvalue()
    off = 128 + (20 if d[84:88] == b'DX10' else 0)
    return d[off:]


def _fix_dxt1(data):
    """Pillow may emit DXT1 blocks in 3-colour mode (c0 <= c1), where index 3 is transparent black.
    Source draws that as black specks, so rewrite them as 4-colour blocks (c0 > c1)."""
    import numpy as np
    b = np.frombuffer(data, dtype='<u2').reshape(-1, 4).copy()
    c0, c1 = b[:, 0].copy(), b[:, 1].copy()
    bad = c0 <= c1
    if not bad.any():
        return data
    idx = b[:, 2].astype(np.uint32) | (b[:, 3].astype(np.uint32) << 16)
    sel = np.arange(16, dtype=np.uint32) * 2
    ix = (idx[:, None] >> sel) & 3                       # 16 indices per block
    # 3-colour palette: 0=c0 1=c1 2=mid 3=black. New 4-colour palette after swapping (c0'=c1, c1'=c0):
    # 0=c1 1=c0 2=2/3c1+1/3c0 3=1/3c1+2/3c0. mid -> 2, black -> the darker endpoint
    lum0 = ((c0 >> 11) & 31) * 2 + ((c0 >> 5) & 63) + (c0 & 31) * 2
    lum1 = ((c1 >> 11) & 31) * 2 + ((c1 >> 5) & 63) + (c1 & 31) * 2
    dark = np.where(lum1 <= lum0, 0, 1)                  # new index of the darker colour (c1 is new 0)
    remap = np.stack([np.ones_like(dark), np.zeros_like(dark), np.full_like(dark, 2), dark], 1)  # old 0,1,2,3 -> new
    new = np.take_along_axis(remap, ix.astype(np.int64), 1).astype(np.uint32)
    eq = c0 == c1                                        # solid blocks: one colour, nudge c0 above c1
    nc0, nc1 = c1.copy(), c0.copy()
    nc0[eq] = np.where(c0[eq] < 0xFFFF, c0[eq] + 1, c0[eq])
    nc1[eq] = np.where(c0[eq] < 0xFFFF, c0[eq], c0[eq] - 1)
    new[eq] = np.where(c0[eq] < 0xFFFF, 1, 0)[:, None]   # index of the original colour
    packed = (new << sel).sum(1).astype(np.uint32)
    b[bad, 0], b[bad, 1] = nc0[bad], nc1[bad]
    b[bad, 2], b[bad, 3] = (packed[bad] & 0xFFFF), (packed[bad] >> 16)
    return b.tobytes()


def _pad4(img):
    w, h = img.size
    if w % 4 == 0 and h % 4 == 0:
        return img
    c = Image.new(img.mode, ((w + 3) // 4 * 4, (h + 3) // 4 * 4))
    c.paste(img, (0, 0))
    return c


def write(path, img, alpha=None, normal=False, max_size=2048):
    """alpha None = decide from the image (any pixel below 250 -> DXT5)."""
    img = img.convert('RGBA')
    w, h = img.size
    while max(w, h) > max_size:
        w, h = max(1, w // 2), max(1, h // 2)
    if (w, h) != img.size:
        img = img.resize((w, h), Image.LANCZOS)
    if normal:
        # Source 2 normal maps keep only X/Y (R/G); Source 1 needs Z in blue -> rebuild it
        import numpy as np
        a = np.asarray(img).astype(np.float32) / 255.0
        x, y = a[..., 0] * 2 - 1, a[..., 1] * 2 - 1
        z = np.sqrt(np.clip(1 - x * x - y * y, 0, 1))
        a[..., 2] = z * 0.5 + 0.5
        a[..., 3] = 1
        img = Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA')
        alpha = False
    if alpha is None:
        alpha = img.getchannel('A').getextrema()[0] < 250
    fmt = 'DXT5' if alpha else 'DXT1'
    mips = []
    m = img
    while True:
        mips.append(m)
        if m.size == (1, 1):
            break
        m = m.resize((max(1, m.size[0] // 2), max(1, m.size[1] // 2)), Image.LANCZOS)
    flags = FLAG_TRILINEAR | (FLAG_EIGHTBITALPHA if alpha else 0) | (FLAG_NORMAL if normal else 0)
    hdr = struct.pack('<4sII I HH I HH 4x 3f 4x f I B i BB H', b'VTF\0', 7, 2, 80, w, h, flags, 1, 0,
                      0.5, 0.5, 0.5, 1.0, FMT[fmt], len(mips), -1, 0, 0, 1)
    hdr = hdr.ljust(80, b'\0')
    data = b''
    for m in reversed(mips):
        q = _pad4(m) if fmt else m
        if m.size[0] < 4 or m.size[1] < 4:
            q = _pad4(m)
        blk = _dxt(q.convert('RGBA' if alpha else 'RGB'), fmt)
        bw, bh = max(1, (m.size[0] + 3) // 4), max(1, (m.size[1] + 3) // 4)
        need = bw * bh * (16 if alpha else 8)
        data += _fix_dxt1(blk[:need]) if fmt == 'DXT1' else blk[:need]
    open(path, 'wb').write(hdr + data)
    return fmt, (w, h)
