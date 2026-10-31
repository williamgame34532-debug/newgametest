# Source 2 MBUF/VBIB on-disk buffers.
import struct


def read_mbuf(b, off):
    vo, vc, io, ic = struct.unpack_from('<4I', b, off)
    out = {'vb': [], 'ib': []}

    def one(p, is_vertex):
        cnt, size = struct.unpack_from('<Ii', b, p)
        esize = size & 0x3FFFFFF
        meshopt = (size & 0x4000000) == 0
        zstd = (size & 0x8000000) != 0
        refA = p + 8
        aoff, acnt = struct.unpack_from('<II', b, refA)
        refB = refA + 8
        doff, tot = struct.unpack_from('<Ii', b, refB)
        attrs = []
        a = refA + aoff
        for i in range(acnt):
            name = b[a:b.index(b'\0', a)].decode().upper()
            si, fmt, ofs, slot, stype, step = struct.unpack_from('<iIIiIi', b, a + 32)
            attrs.append({'name': name, 'index': si, 'format': fmt, 'offset': ofs})
            a += 32 + 24
        data = b[refB + doff: refB + doff + tot]
        return {'count': cnt, 'esize': esize, 'meshopt': meshopt, 'zstd': zstd, 'attrs': attrs, 'raw': data,
                'needs_decode': cnt * esize > tot}, refB + 8

    p = off + vo
    for i in range(vc):
        buf, p = one(p, True)
        out['vb'].append(buf)
    p = off + 8 + io
    for i in range(ic):
        buf, p = one(p, False)
        out['ib'].append(buf)
    return out
