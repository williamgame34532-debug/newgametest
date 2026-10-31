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
        data += blk[:need]
    open(path, 'wb').write(hdr + data)
    return fmt, (w, h)
