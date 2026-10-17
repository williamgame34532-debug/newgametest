"""Valve texture files, as much as the branding scripts need:
    read(path)                  -> RGBA numpy array (H, W, 4) of the largest mip; formats BGR888, BGRA8888,
                                   RGBA8888, DXT1, DXT5 (DXT is decoded through Pillow's DDS reader)
    write(path, rgba, flags)    -> VTF 7.2, DXT5 with the whole mip chain (a small numpy block encoder:
                                   the colour endpoints are the ends of the block along its main axis,
                                   the alpha endpoints its min and max)
Flags: 0x0004 clamp S, 0x0008 clamp T, 0x2000 eight bit alpha, 0x0100 no mips (not used here)."""
import io, struct
import numpy as np
from PIL import Image

FMT_RGBA8888, FMT_BGR888, FMT_BGRA8888, FMT_DXT1, FMT_DXT5 = 0, 3, 12, 13, 15


def _mip_sizes(w, h, count):
    out = []
    for i in range(count):
        out.append((max(1, w >> i), max(1, h >> i)))
    return out


def _size(fmt, w, h):
    if fmt in (FMT_DXT1,):
        return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * 8
    if fmt in (FMT_DXT5,):
        return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * 16
    if fmt in (FMT_BGR888,):
        return w * h * 3
    return w * h * 4


def _dds(fourcc, w, h, data):
    header = struct.pack("<4sIIIIII", b"DDS ", 124, 0x1 | 0x2 | 0x4 | 0x1000 | 0x80000, h, w, len(data), 0)
    header += struct.pack("<I", 1) + b"\0" * 44
    header += struct.pack("<II4sIIIII", 32, 0x4, fourcc, 0, 0, 0, 0, 0)
    header += struct.pack("<IIIII", 0x1000, 0, 0, 0, 0)
    return header + data


def read(path):
    raw = open(path, "rb").read()
    v1, v2, header = struct.unpack("<III", raw[4:16])
    w, h = struct.unpack("<HH", raw[16:20])
    frames = struct.unpack("<H", raw[24:26])[0]
    fmt, mips, lfmt, lw, lh = struct.unpack("<iBiBB", raw[52:63])
    # resources (7.3+) are not handled: the data follows the header and the low-res image
    offset = header + (_size(lfmt, lw, lh) if lfmt >= 0 and lw else 0)
    # mips go from the smallest to the largest; each mip holds all frames
    sizes = _mip_sizes(w, h, mips)
    for (mw, mh) in reversed(sizes[1:]):
        offset += _size(fmt, mw, mh) * frames
    data = raw[offset:offset + _size(fmt, w, h)]
    if fmt == FMT_DXT1:
        return np.asarray(Image.open(io.BytesIO(_dds(b"DXT1", w, h, data))).convert("RGBA"))
    if fmt == FMT_DXT5:
        return np.asarray(Image.open(io.BytesIO(_dds(b"DXT5", w, h, data))).convert("RGBA"))
    a = np.frombuffer(data, np.uint8)
    if fmt == FMT_BGR888:
        a = a.reshape(h, w, 3)[..., ::-1]
        return np.dstack([a, np.full((h, w), 255, np.uint8)])
    if fmt == FMT_BGRA8888:
        a = a.reshape(h, w, 4)
        return a[..., [2, 1, 0, 3]].copy()
    if fmt == FMT_RGBA8888:
        return a.reshape(h, w, 4).copy()
    raise ValueError("format %d is not supported" % fmt)


# ------------------------------------------------------------------ DXT5 --
def _565(c):
    c = np.clip(np.round(c), 0, 255).astype(np.int32)
    return ((c[..., 0] >> 3) << 11) | ((c[..., 1] >> 2) << 5) | (c[..., 2] >> 3)


def _from565(v):
    r = ((v >> 11) & 31) * 255 / 31
    g = ((v >> 5) & 63) * 255 / 63
    b = (v & 31) * 255 / 31
    return np.stack([r, g, b], -1)


def _encode_dxt5(rgba):
    h, w = rgba.shape[:2]
    ph, pw = (h + 3) // 4 * 4, (w + 3) // 4 * 4
    img = np.zeros((ph, pw, 4), np.float64)
    img[:h, :w] = rgba
    if ph > h:
        img[h:, :w] = rgba[-1:, :, :]
    if pw > w:
        img[:, w:] = img[:, w - 1:w]
    blocks = img.reshape(ph // 4, 4, pw // 4, 4, 4).transpose(0, 2, 1, 3, 4).reshape(-1, 16, 4)
    n = blocks.shape[0]

    # alpha: 8 levels between max and min
    a = blocks[..., 3]
    a0 = np.round(a.max(1)).astype(np.int32)
    a1 = np.round(a.min(1)).astype(np.int32)
    same = a0 == a1
    a0 = np.where(same & (a0 < 255), a0 + 1, a0)
    a1 = np.where(same & (a0 >= 255), a1 - 1, a1)
    a1 = np.clip(a1, 0, 255)
    levels = np.stack([a0, a1] + [((7 - i) * a0 + i * a1) / 7 for i in range(1, 7)], 1)
    aidx = np.abs(a[:, :, None] - levels[:, None, :]).argmin(2).astype(np.uint64)
    abits = np.zeros(n, np.uint64)
    for i in range(16):
        abits |= aidx[:, i] << np.uint64(3 * i)

    # colour: the ends of the block along its main axis
    c = blocks[..., :3]
    mean = c.mean(1, keepdims=True)
    centred = c - mean
    cov = np.einsum("nki,nkj->nij", centred, centred)
    axis = np.ones((n, 3)) / np.sqrt(3)
    for _ in range(6):
        axis = np.einsum("nij,nj->ni", cov, axis)
        norm = np.linalg.norm(axis, axis=1, keepdims=True)
        axis = np.where(norm > 1e-9, axis / np.maximum(norm, 1e-9), np.ones((n, 3)) / np.sqrt(3))
    proj = np.einsum("nki,ni->nk", centred, axis)
    lo = mean[:, 0] + axis * proj.min(1, keepdims=True)
    hi = mean[:, 0] + axis * proj.max(1, keepdims=True)
    c0, c1 = _565(hi), _565(lo)
    swap = c0 < c1
    c0, c1 = np.where(swap, c1, c0), np.where(swap, c0, c1)
    # equal endpoints: the 4 colour mode still works with c0 > c1 only; nudge
    eq = c0 == c1
    c0 = np.where(eq & (c0 < 0xFFFF), c0 + 1, c0)
    c1 = np.where(eq & (c0 >= 0xFFFF), c1 - 1, c1)
    p0, p1 = _from565(c0), _from565(c1)
    palette = np.stack([p0, p1, (2 * p0 + p1) / 3, (p0 + 2 * p1) / 3], 1)
    cidx = ((c[:, :, None, :] - palette[:, None, :, :]) ** 2).sum(3).argmin(2).astype(np.uint32)
    cbits = np.zeros(n, np.uint32)
    for i in range(16):
        cbits |= cidx[:, i] << np.uint32(2 * i)

    out = bytearray()
    for i in range(n):
        out += struct.pack("<BB", a0[i], a1[i])
        out += int(abits[i]).to_bytes(6, "little")
        out += struct.pack("<HHI", int(c0[i]), int(c1[i]), int(cbits[i]))
    return bytes(out)


def write(path, rgba, flags=0x2000):
    rgba = np.asarray(rgba, np.uint8)
    h, w = rgba.shape[:2]
    count = 1
    while (w >> count) >= 1 and (h >> count) >= 1 and count < 16:
        count += 1
    mips = []
    img = Image.fromarray(rgba, "RGBA")
    for (mw, mh) in _mip_sizes(w, h, count):
        mips.append(np.asarray(img.resize((mw, mh), Image.LANCZOS) if (mw, mh) != (w, h) else img))
    header_size = 80
    header = struct.pack("<4sIIIHHIHH", b"VTF\0", 7, 2, header_size, w, h, flags, 1, 0)
    header += b"\0" * 4 + struct.pack("<fff", 0.5, 0.5, 0.5) + b"\0" * 4 + struct.pack("<f", 1.0)
    header += struct.pack("<iBiBB", FMT_DXT5, count, -1, 0, 0)
    header += struct.pack("<H", 1)
    header += b"\0" * (header_size - len(header))
    body = b"".join(_encode_dxt5(m) for m in reversed(mips))
    open(path, "wb").write(header + body)
