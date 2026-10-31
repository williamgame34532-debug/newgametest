# Minimal Source 2 resource + binary KV3 reader (versions 1..5), written for this conversion.
import struct, io
import lz4.block
import numpy as np

GUID = {}

def read_resource(path):
    b = open(path, 'rb').read()
    size, hv, ver, bo, bc = struct.unpack_from('<IHHII', b, 0)
    base = 8 + bo
    blocks = {}
    for i in range(bc):
        o = base + i * 12
        t = b[o:o + 4].decode('latin1')
        off, sz = struct.unpack_from('<II', b, o + 4)
        blocks.setdefault(t, []).append((o + 4 + off, sz))
    return b, blocks


class Lane:
    def __init__(self, data):
        self.d = data
        self.p = 0

    def take(self, n):
        v = self.d[self.p:self.p + n]
        self.p += n
        return v


def align(o, a):
    return (o + a - 1) // a * a


def read_strings(buf, off, count):
    out = []
    for _ in range(count):
        e = buf.index(b'\0', off)
        out.append(buf[off:e].decode('utf-8', 'replace'))
        off = e + 1
    return out, off


def kv3(b, off, size):
    end = off + size
    magic = struct.unpack_from('<I', b, off)[0]
    if magic == 0x03564B56:
        raise NotImplementedError('legacy VKV3')
    version = magic & 0xFF
    assert magic & 0xFFFFFF00 == 0x4B563300, hex(magic)
    p = off + 4
    p += 16  # format guid
    comp = struct.unpack_from('<I', b, p)[0]; p += 4
    H = {}
    if version == 1:
        H['c1'], H['c4'], H['c8'], H['unc'] = struct.unpack_from('<4i', b, p); p += 16
        H['ctot'] = end - p
        H['types'] = 0; H['blocks'] = 0; H['blobs'] = 0; H['frame'] = 0
    else:
        dict_id, H['frame'] = struct.unpack_from('<HH', b, p); p += 4
        H['c1'], H['c4'], H['c8'], H['types'] = struct.unpack_from('<4i', b, p); p += 16
        p += 4  # counts objects/arrays (u16 x2)
        H['unc'], H['ctot'], H['blocks'], H['blobs'] = struct.unpack_from('<4i', b, p); p += 16
    H['c2'] = 0
    if version >= 4:
        H['c2'], H['blocksizes'] = struct.unpack_from('<2i', b, p); p += 8
    if version >= 5:
        (H['u1'], H['cb1'], H['u2'], H['cb2'], H['c1b'], H['c2b'], H['c4b'], H['c8b'],
         _, H['objb'], _, _) = struct.unpack_from('<12i', b, p); p += 48
    else:
        H['cb1'] = H['ctot']; H['u1'] = H['unc']

    zd = None
    def decomp(n_unc, n_comp):
        nonlocal p, zd
        if comp == 0:
            out = b[p:p + n_unc]; p += n_unc; return out
        if comp == 1:
            out = lz4.block.decompress(b[p:p + n_comp], uncompressed_size=n_unc); p += n_comp; return out
        if comp == 2:
            import zstandard
            zd = zd or zstandard.ZstdDecompressor()
            out = zd.decompressobj().decompress(b[p:p + n_comp]); p += n_comp; return out
        raise ValueError(comp)

    size1 = H['u1'] + (H['blobs'] if (version < 5 and comp == 2) else 0)
    raw1 = decomp(size1, H['cb1'])
    buf1 = raw1[:H['u1']]
    o = 0
    lanes = {}
    def lane(name, count, width, buf, start):
        nonlocal o
        if count > 0:
            o = align(o, width) if width > 1 else o
            lanes_local = buf[o:o + count * width]; o += count * width
            return lanes_local
        return b''
    o = 0
    L1 = {}
    L1[1] = lane('1', H['c1'], 1, buf1, 0)
    L1[2] = lane('2', H['c2'], 2, buf1, 0)
    L1[4] = lane('4', H['c4'], 4, buf1, 0)
    if H['c8'] > 0:
        L1[8] = lane('8', H['c8'], 8, buf1, 0)
    else:
        L1[8] = b''
        if version < 5:
            o = align(o, 8)
    nstr = struct.unpack_from('<i', L1[4], 0)[0]
    L1[4] = L1[4][4:]
    blob_sizes_buf = None
    if version >= 5:
        lane1 = Lane(L1[1])
        strings, used = read_strings(L1[1], 0, nstr)
        lane1.p = used
        aux = {1: lane1, 2: Lane(L1[2]), 4: Lane(L1[4]), 8: Lane(L1[8])}
        raw2 = decomp(H['u2'], H['cb2'])
        objlen = Lane(raw2[:H['objb'] * 4])
        o = H['objb'] * 4
        L2 = {}
        for w, key in ((1, 'c1b'), (2, 'c2b'), (4, 'c4b'), (8, 'c8b')):
            n = H[key]
            if n > 0:
                if w > 1: o = align(o, w)
                L2[w] = raw2[o:o + n * w]; o += n * w
            else:
                L2[w] = b''
        types = raw2[o:o + H['types']]; o += H['types']
        main = {w: Lane(L2[w]) for w in (1, 2, 4, 8)}
        if H['blocks'] > 0:
            blob_sizes_buf = raw2[o:]
    else:
        strings, o2 = read_strings(buf1, o, nstr)
        if version == 1:
            tl = H['unc'] - o2 - 4
        else:
            tl = H['types'] - o2 + o
        types = buf1[o2:o2 + tl]
        o2 += tl
        main = {w: Lane(L1[w]) for w in (1, 2, 4, 8)}
        aux = main
        objlen = None
        if H['blocks'] > 0:
            blob_sizes_buf = buf1[o2:]

    blobs = []
    if H['blocks'] > 0:
        n = H['blocks']
        lens = struct.unpack_from('<%di' % n, blob_sizes_buf, 0)
        q = n * 4 + 4
        if comp == 0:
            for ln in lens:
                blobs.append(b[p:p + ln]); p += ln
        elif comp == 1:
            # chained LZ4 frames of up to frame size
            hist = b''
            for ln in lens:
                out = b''
                while len(out) < ln:
                    cl = struct.unpack_from('<H', blob_sizes_buf, q)[0]; q += 2
                    chunk = b[p:p + cl]; p += cl
                    dec = lz4.block.decompress(chunk, uncompressed_size=min(H['frame'], ln - len(out)),
                                               dict=hist[-65536:]) if hist else \
                        lz4.block.decompress(chunk, uncompressed_size=min(H['frame'], ln - len(out)))
                    out += dec
                    hist += dec
                blobs.append(out)
        else:
            if version >= 5:
                import zstandard
                data = zstandard.ZstdDecompressor().decompressobj().decompress(b[p:end])
            else:
                data = raw1[H['u1']:]
            q2 = 0
            for ln in lens:
                blobs.append(data[q2:q2 + ln]); q2 += ln

    st = {'t': 0, 'blob': 0}

    def rtype():
        d = types[st['t']]; st['t'] += 1
        if version >= 3:
            if d & 0x80: st['t'] += 1
            if d & 0x40: st['t'] += 1
            d &= 0x3F
        else:
            if d & 0x80: st['t'] += 1
            d &= 0x7F
        return d

    def rl(lane, fmt, w):
        return struct.unpack(fmt, lane.take(w))[0]

    PACK = {2: ('B', 1), 22: ('b', 1), 23: ('B', 1), 20: ('h', 2), 21: ('H', 2), 11: ('i', 4), 12: ('I', 4),
            19: ('f', 4), 3: ('q', 8), 4: ('Q', 8), 5: ('d', 8)}
    NP = {'B': np.uint8, 'b': np.int8, 'h': np.int16, 'H': np.uint16, 'i': np.int32, 'I': np.uint32,
          'f': np.float32, 'q': np.int64, 'Q': np.uint64, 'd': np.float64}

    def value(t, ln):
        if t == 1: return None
        if t == 13: return True
        if t == 14: return False
        if t == 15: return 0
        if t == 16: return 1
        if t == 17: return 0.0
        if t == 18: return 1.0
        if t == 26: return 0
        if t == 27: return 1
        if t == 2: return ln[1].take(1)[0] != 0
        if t == 22: return rl(ln[1], '<b', 1)
        if t == 23: return ln[1].take(1)[0]
        if t == 20: return rl(ln[2], '<h', 2)
        if t == 21: return rl(ln[2], '<H', 2)
        if t == 11: return rl(ln[4], '<i', 4)
        if t == 12: return rl(ln[4], '<I', 4)
        if t == 19: return rl(ln[4], '<f', 4)
        if t == 3: return rl(ln[8], '<q', 8)
        if t == 4: return rl(ln[8], '<Q', 8)
        if t == 5: return rl(ln[8], '<d', 8)
        if t == 6:
            i = rl(main[4], '<i', 4)
            return strings[i] if 0 <= i < len(strings) else ''
        if t == 7:
            if version < 2:
                n = rl(main[4], '<i', 4)
                return bytes(main[1].take(n)) if n > 0 else b''
            v = blobs[st['blob']]; st['blob'] += 1; return v
        if t == 8:
            n = rl(main[4], '<i', 4)
            return [value(rtype(), main) for _ in range(n)]
        if t in (10, 24, 25):
            n = rl(main[4], '<i', 4) if t == 10 else main[1].take(1)[0]
            sub = rtype()
            el = aux if t == 25 else main
            if sub in PACK:
                f, w = PACK[sub]
                return np.frombuffer(el[w].take(n * w), dtype=NP[f]).copy()
            return [value(sub, el) for _ in range(n)]
        if t == 9:
            n = rl(objlen, '<i', 4) if version >= 5 else rl(main[4], '<i', 4)
            d = {}
            for _ in range(n):
                tt = rtype()
                name_i = rl(main[4], '<i', 4)
                name = strings[name_i] if 0 <= name_i < len(strings) else ''
                d[name] = value(tt, main)
            return d
        raise ValueError('kv3 type %d' % t)

    # NOTE: in the object loop the name is read before the value type for v>=? -- VRF reads type first,
    # then the name from the 4-byte lane, then the value; kept in that order above.
    return value(rtype(), main)


def dump(v, ind=0, maxlist=6, depth=6):
    sp = '  ' * ind
    if depth == 0:
        return sp + '...'
    if isinstance(v, dict):
        return '\n'.join(sp + str(k) + (':\n' + dump(x, ind + 1, maxlist, depth - 1) if isinstance(x, (dict, list)) else ': ' + short(x)) for k, x in v.items())
    if isinstance(v, list):
        out = [sp + '[%d]' % len(v)]
        for x in v[:maxlist]:
            out.append(dump(x, ind + 1, maxlist, depth - 1) if isinstance(x, (dict, list)) else sp + '  ' + short(x))
        return '\n'.join(out)
    return sp + short(v)


def short(x):
    if isinstance(x, np.ndarray):
        return 'array[%d %s] %s' % (len(x), x.dtype, np.array2string(x[:8], precision=3))
    if isinstance(x, (bytes, bytearray)):
        return 'blob[%d]' % len(x)
    return repr(x)
