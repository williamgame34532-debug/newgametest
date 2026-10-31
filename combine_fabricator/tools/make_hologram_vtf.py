"""Write the hologram scanline texture as an uncompressed VTF 7.2 (BGRA8888, full mip chain)."""
import struct, sys, math
from PIL import Image

def mip_chain(img):
    out = [img]
    while img.size[0] > 1 or img.size[1] > 1:
        img = img.resize((max(1, img.size[0] // 2), max(1, img.size[1] // 2)), Image.LANCZOS)
        out.append(img)
    return out

def write_vtf(path, img, flags=0x2000):  # EIGHTBITALPHA; wraps both ways so the lines can scroll
    img = img.convert('RGBA')
    w, h = img.size
    mips = mip_chain(img)
    header = struct.pack('<4sIIIHHIHH4x3f4xfIBIBBH', b'VTF\0', 7, 2, 80, w, h, flags, 1, 0,
                         0.5, 0.8, 0.9, 1.0, 12, len(mips), 0xFFFFFFFF & -1, 0, 0, 1)
    header = header.ljust(80, b'\0')
    data = b''
    for m in reversed(mips):  # smallest first
        r, g, b, a = m.split()
        data += Image.merge('RGBA', (b, g, r, a)).tobytes()
    open(path, 'wb').write(header + data)

if __name__ == '__main__':
    out = sys.argv[1]
    W = H = 128
    img = Image.new('RGBA', (W, H))
    px = img.load()
    for y in range(H):
        # thin bright scanlines every 8 px plus a faint base fill
        line = 1.0 if y % 8 in (0, 1) else (0.35 if y % 8 == 2 else 0.18)
        band = 0.25 * (0.5 + 0.5 * math.sin(y / H * math.pi * 2))
        v = min(1.0, line + band)
        for x in range(W):
            c = int(255 * v)
            px[x, y] = (c, c, c, 255)
    write_vtf(out, img)
    print('wrote', out)
