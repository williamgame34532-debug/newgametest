# Read a Source 2 .vtex_c mip 0 (DXT1/DXT5/BC4/BGRA) and write simple Source 1 VTF files.
import struct, io
import numpy as np
import lz4.block
from PIL import Image
from kv3 import read_resource

# Source 2 VTEX formats: 1 DXT1, 2 DXT5, 4 RGBA8888, 19 BC6H, 20 BC7, 21 ATI2N (BC5), 27 ATI1N (BC4), 28 BGRA8888
BLOCK = {1: 8, 2: 16, 27: 8, 19: 16, 20: 16, 21: 16}
DXGI = {19: 95, 20: 98, 21: 83}  # BC6H_UF16, BC7_UNORM, BC5_UNORM (decoded by Pillow through a DX10 DDS header)


def mip_size(fmt, w, h):
    if fmt in BLOCK:
        return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * BLOCK[fmt]
    if fmt in (4, 28):
        return w * h * 4
    if fmt == 3:  # I8
        return w * h
    raise ValueError(fmt)


def read_vtex(path):
    b, bl = read_resource(path)
    o, s = bl['DATA'][0]
    w, h, d = struct.unpack_from('<HHH', b, o + 20)
    fmt, mips = b[o + 26], b[o + 27]
    eo, ec = struct.unpack_from('<II', b, o + 32)
    p = o + 32 + eo
    comp = None
    for i in range(ec):
        t, off, sz = struct.unpack_from('<III', b, p)
        if t == 4:
            q = p + 4 + off
            method, moff, n = struct.unpack_from('<III', b, q)
            comp = (method, struct.unpack_from('<%di' % n, b, q + 4 + moff))
        p += 12
    pos = o + s
    data = None
    for m in range(mips - 1, -1, -1):
        mw, mh = max(1, w >> m), max(1, h >> m)
        size = mip_size(fmt, mw, mh)
        csize = comp[1][m] if comp else size
        if csize < size:
            raw = lz4.block.decompress(b[pos:pos + csize], uncompressed_size=size)
            pos += csize
        else:
            raw = b[pos:pos + size]; pos += size
        if m == 0:
            data = raw
    return decode(fmt, w, h, data)


def _dds_dx10(dxgi, w, h, data):
    hdr = b'DDS ' + struct.pack('<7I', 124, 0x1 | 0x2 | 0x4 | 0x1000 | 0x80000, h, w, len(data), 0, 1) + b'\0' * 44
    hdr += struct.pack('<2I4s5I', 32, 0x4, b'DX10', 0, 0, 0, 0, 0) + struct.pack('<5I', 0x1000, 0, 0, 0, 0)
    hdr += struct.pack('<5I', dxgi, 3, 0, 1, 0)  # format, 2D texture, misc, array size, misc2
    return Image.open(io.BytesIO(hdr + data))


def decode(fmt, w, h, data):
    if fmt in DXGI:
        img = _dds_dx10(DXGI[fmt], w, h, data)
        if fmt == 21:  # BC5 normal map: rebuild blue from red/green
            a = np.asarray(img.convert('RGB'), np.float32) / 255.0
            x, y = a[..., 0] * 2 - 1, a[..., 1] * 2 - 1
            z = np.sqrt(np.clip(1 - x * x - y * y, 0, 1))
            a[..., 2] = z * 0.5 + 0.5
            return Image.fromarray((a * 255).astype(np.uint8), 'RGB').convert('RGBA')
        return img.convert('RGBA')
    if fmt in (1, 2):
        fourcc = b'DXT1' if fmt == 1 else b'DXT5'
        hdr = b'DDS ' + struct.pack('<7I', 124, 0x1 | 0x2 | 0x4 | 0x1000 | 0x80000, h, w, len(data), 0, 1) + b'\0' * 44
        hdr += struct.pack('<2I4s5I', 32, 0x4, fourcc, 0, 0, 0, 0, 0) + struct.pack('<5I', 0x1000, 0, 0, 0, 0)
        return Image.open(io.BytesIO(hdr + data)).convert('RGBA')
    if fmt == 27:  # BC4 single channel
        blocks = np.frombuffer(data, np.uint8).reshape(-1, 8)
        r0 = blocks[:, 0].astype(np.int32); r1 = blocks[:, 1].astype(np.int32)
        bits = np.zeros(len(blocks), np.uint64)
        for i in range(6):
            bits |= blocks[:, 2 + i].astype(np.uint64) << np.uint64(8 * i)
        pal = np.zeros((len(blocks), 8), np.int32)
        pal[:, 0] = r0; pal[:, 1] = r1
        big = r0 > r1
        for i in range(2, 8):
            pal[:, i] = np.where(big, ((8 - i) * r0 + (i - 1) * r1) // 7, 0)
        for i in range(2, 6):
            pal[:, i] = np.where(big, pal[:, i], ((6 - i) * r0 + (i - 1) * r1) // 5)
        pal[:, 6] = np.where(big, pal[:, 6], 0); pal[:, 7] = np.where(big, pal[:, 7], 255)
        idx = np.stack([((bits >> np.uint64(3 * k)) & np.uint64(7)).astype(np.int32) for k in range(16)], 1)
        px = np.take_along_axis(pal, idx, 1).astype(np.uint8).reshape(h // 4, w // 4, 4, 4)
        img = px.transpose(0, 2, 1, 3).reshape(h, w)
        return Image.fromarray(img, 'L').convert('RGBA')
    if fmt == 28:
        a = np.frombuffer(data, np.uint8).reshape(h, w, 4)[:, :, [2, 1, 0, 3]]
        return Image.fromarray(a, 'RGBA')
    if fmt == 4:
        return Image.frombytes('RGBA', (w, h), data)
    if fmt == 3:
        return Image.frombytes('L', (w, h), data).convert('RGBA')
    raise ValueError(fmt)


def write_vtf(path, img, fmt='BGR888', flags=0x0100 | 0x0004 | 0x0008):
    """Uncompressed VTF 7.2 with a full mip chain. flags: trilinear | clamps | clampt by default off below."""
    img = img.convert('RGBA')
    w, h = img.size
    ids = {'BGR888': 3, 'BGRA8888': 12, 'I8': 5}
    mips = []
    m = img
    while True:
        mips.append(m)
        if m.size == (1, 1):
            break
        m = m.resize((max(1, m.size[0] // 2), max(1, m.size[1] // 2)), Image.LANCZOS)
    hdr = struct.pack('<4sII I HH I HH 4x 3f 4x f i B i BB H', b'VTF\0', 7, 2, 80, w, h, flags, 1, 0,
                      0.5, 0.5, 0.5, 1.0, ids[fmt], len(mips), -1, 0, 0, 1)
    hdr += b'\0' * (80 - len(hdr))
    body = b''
    for m in reversed(mips):
        a = np.asarray(m)
        if fmt == 'BGR888':
            body += a[:, :, [2, 1, 0]].tobytes()
        elif fmt == 'BGRA8888':
            body += a[:, :, [2, 1, 0, 3]].tobytes()
        else:
            body += np.asarray(m.convert('L')).tobytes()
    open(path, 'wb').write(hdr + body)
