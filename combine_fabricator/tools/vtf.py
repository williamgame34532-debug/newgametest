"""Tiny VTF reader: highest mip of DXT1/DXT5/BGR888/BGRA8888/RGBA8888 -> PIL image (via DDS wrapper for DXT)."""
import struct, io
from PIL import Image

FMT = {0: 'RGBA8888', 1: 'ABGR8888', 2: 'RGB888', 3: 'BGR888', 12: 'BGRA8888', 13: 'DXT1', 15: 'DXT5', 14: 'DXT3'}

def _size(fmt, w, h):
    if fmt in ('DXT1',):
        return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * 8
    if fmt in ('DXT3', 'DXT5'):
        return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * 16
    return w * h * {'ABGR8888': 4, 'RGBA8888': 4, 'BGRA8888': 4, 'RGB888': 3, 'BGR888': 3}[fmt]

def load(path):
    d = open(path, 'rb').read()
    sig, vmaj, vmin, hsize, w, h, flags, frames, first = struct.unpack_from('<4sIIIHHIHH', d, 0)
    fmt_id, mips, lfmt, lw, lh = struct.unpack_from('<iBiBB', d, 0x34)  # after reflectivity+pad+bumpscale
    fmt = FMT.get(fmt_id)
    if fmt is None:
        raise ValueError('fmt %d' % fmt_id)
    # data layout: header, low-res image, then mips smallest->largest
    off = hsize
    if vmin >= 3:
        # resources
        nres, = struct.unpack_from('<I', d, 0x44)
        off = None
        for i in range(nres):
            tag, fl, val = struct.unpack_from('<3sBI', d, 0x50 + i * 8)
            if tag == b'\x30\x00\x00':
                off = val
        lowsz = 0
    else:
        lowsz = _size('DXT1', lw, lh) if lw else 0
        off = hsize + lowsz
    for m in range(mips - 1, 0, -1):
        off += _size(fmt, max(1, w >> m), max(1, h >> m)) * frames
    data = d[off:off + _size(fmt, w, h)]
    if fmt.startswith('DXT'):
        fourcc = fmt.encode()
        hdr = struct.pack('<4sIIIIIII44xII4sIIIIIIIIII', b'DDS ', 124, 0x1007 | 0x80000, h, w, len(data), 0, 1,
                          32, 4, fourcc, 0, 0, 0, 0, 0, 0x1000, 0, 0, 0, 0)
        return Image.open(io.BytesIO(hdr + data)).convert('RGBA')
    if fmt == 'BGR888':
        return Image.frombytes('RGB', (w, h), data, 'raw', 'BGR')
    if fmt == 'RGB888':
        return Image.frombytes('RGB', (w, h), data)
    if fmt == 'BGRA8888':
        return Image.frombytes('RGBA', (w, h), data, 'raw', 'BGRA')
    if fmt == 'ABGR8888':
        return Image.frombytes('RGBA', (w, h), data, 'raw', 'ABGR')
    return Image.frombytes('RGBA', (w, h), data)

if __name__ == '__main__':
    import sys
    for p in sys.argv[1:-1]:
        im = load(p); print(p, im.size)
        im.save(sys.argv[-1] + '/' + p.split('/')[-1].replace('.vtf', '.png'))
