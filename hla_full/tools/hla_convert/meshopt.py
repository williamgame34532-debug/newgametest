# meshoptimizer index/vertex buffer decoders (codec versions 0/1), Python + numpy.
import numpy as np


def _vbyte(data, pos):
    lead = data[pos]; pos += 1
    if lead < 128:
        return lead, pos
    result = lead & 127
    shift = 7
    for _ in range(4):
        g = data[pos]; pos += 1
        result |= (g & 127) << shift
        shift += 7
        if g < 128:
            break
    return result, pos


def decode_index_buffer(count, isize, buf):
    assert count % 3 == 0
    assert buf[0] & 0xF0 == 0xE0
    version = buf[0] & 0x0F
    doff = 1 + count // 3
    code = buf[1:doff]
    data = buf[doff:]
    safe_end = len(data) - 16
    aux = data[safe_end:]
    ef = [(0, 0)] * 16
    vf = [0] * 16
    efo = 0
    vfo = 0
    nxt = 0
    last = 0
    fecmax = 13 if version >= 1 else 15
    pos = 0
    out = np.empty(count, dtype=np.uint32)
    w = 0
    M = 0xFFFFFFFF

    def dec_index(last, pos):
        v, pos = _vbyte(data, pos)
        d = ((v >> 1) ^ (-(v & 1))) & M
        return (last + d) & M, pos

    for codetri in code:
        if codetri < 0xF0:
            fe = codetri >> 4
            a, b = ef[(efo - 1 - fe) & 15]
            fec = codetri & 15
            if fec < fecmax:
                cf = vf[(vfo - 1 - fec) & 15]
                c = nxt if fec == 0 else cf
                if fec == 0:
                    nxt += 1
                vf[vfo] = c
                vfo = (vfo + (1 if fec == 0 else 0)) & 15
            else:
                if fec != 15:
                    c = (last + fec * 2 - 27) & M
                else:
                    c, pos = dec_index(last, pos)
                last = c
                vf[vfo] = c; vfo = (vfo + 1) & 15
            ef[efo] = (c, b); efo = (efo + 1) & 15
            ef[efo] = (a, c); efo = (efo + 1) & 15
            out[w] = a; out[w + 1] = b; out[w + 2] = c; w += 3
        elif codetri < 0xFE:
            codeaux = aux[codetri & 15]
            feb = codeaux >> 4
            fec = codeaux & 15
            a = nxt; nxt += 1
            bf = vf[(vfo - feb) & 15]
            b = nxt if feb == 0 else bf
            if feb == 0: nxt += 1
            cf = vf[(vfo - fec) & 15]
            c = nxt if fec == 0 else cf
            if fec == 0: nxt += 1
            out[w] = a; out[w + 1] = b; out[w + 2] = c; w += 3
            vf[vfo] = a; vfo = (vfo + 1) & 15
            vf[vfo] = b; vfo = (vfo + (1 if feb == 0 else 0)) & 15
            vf[vfo] = c; vfo = (vfo + (1 if fec == 0 else 0)) & 15
            ef[efo] = (b, a); efo = (efo + 1) & 15
            ef[efo] = (c, b); efo = (efo + 1) & 15
            ef[efo] = (a, c); efo = (efo + 1) & 15
        else:
            codeaux = data[pos]; pos += 1
            fea = 0 if codetri == 0xFE else 15
            feb = codeaux >> 4
            fec = codeaux & 15
            if codeaux == 0:
                nxt = 0
            if fea == 0:
                a = nxt; nxt += 1
            else:
                a = 0
            if feb == 0:
                b = nxt; nxt += 1
            else:
                b = vf[(vfo - feb) & 15]
            if fec == 0:
                c = nxt; nxt += 1
            else:
                c = vf[(vfo - fec) & 15]
            if fea == 15:
                a, pos = dec_index(last, pos); last = a
            if feb == 15:
                b, pos = dec_index(last, pos); last = b
            if fec == 15:
                c, pos = dec_index(last, pos); last = c
            out[w] = a; out[w + 1] = b; out[w + 2] = c; w += 3
            vf[vfo] = a; vfo = (vfo + 1) & 15
            vf[vfo] = b; vfo = (vfo + (1 if feb in (0, 15) else 0)) & 15
            vf[vfo] = c; vfo = (vfo + (1 if fec in (0, 15) else 0)) & 15
            ef[efo] = (b, a); efo = (efo + 1) & 15
            ef[efo] = (c, b); efo = (efo + 1) & 15
            ef[efo] = (a, c); efo = (efo + 1) & 15
    assert pos == safe_end, (pos, safe_end)
    return out


BITS_V0 = [0, 2, 4, 8]
BITS_V1 = [0, 1, 2, 4, 8]
GROUP = 16


def _rev8(b):
    return int('{:08b}'.format(b)[::-1], 2)


def _decode_group(data, p, bits, dst, d0):
    if bits == 0:
        dst[d0:d0 + 16] = 0
        return p
    if bits == 8:
        dst[d0:d0 + 16] = np.frombuffer(data, np.uint8, 16, p)
        return p + 16
    nb = 16 * bits // 8
    dv = p + nb
    k = 0
    mask = (1 << bits) - 1
    per = 8 // bits
    for byte_i in range(nb):
        b = data[p + byte_i]
        if bits == 1:
            b = _rev8(b)
        for _ in range(per):
            enc = (b >> (8 - bits)) & mask
            b = (b << bits) & 0xFF
            if enc == mask:
                dst[d0 + k] = data[dv]; dv += 1
            else:
                dst[d0 + k] = enc
            k += 1
    return dv


def _decode_bytes(data, p, dst, d0, length, bits_table):
    hsize = (length // GROUP + 3) // 4
    header = data[p:p + hsize]
    p += hsize
    for i in range(0, length, GROUP):
        ho = i // GROUP
        bk = (header[ho // 4] >> ((ho % 4) * 2)) & 3
        p = _decode_group(data, p, bits_table[bk], dst, d0 + i)
    return p


def _rotl(v, r):
    r &= 31
    if r == 0:
        return v
    return ((v << np.uint32(r)) | (v >> np.uint32(32 - r))) & np.uint32(0xFFFFFFFF)


def decode_vertex_buffer(count, vsize, buf):
    assert buf[0] & 0xF0 == 0xA0
    version = buf[0] & 0x0F
    data = bytes(buf[1:])
    tail = vsize + (0 if version == 0 else vsize // 4)
    tailmin = 32 if version == 0 else 24
    tailpad = max(tail, tailmin)
    last = np.frombuffer(data, np.uint8, vsize, len(data) - tail).copy()
    channels = None if version == 0 else data[len(data) - tail + vsize: len(data) - tail + vsize + vsize // 4]
    block = min((8192 // vsize) & ~15, 256)
    out = np.empty((count, vsize), np.uint8)
    p = 0
    vo = 0
    buffer = np.zeros(256 * 4, np.uint8)
    while vo < count:
        n = min(block, count - vo)
        n_al = (n + 15) & ~15
        csize = 0 if version == 0 else vsize // 4
        control = data[p:p + csize]
        p += csize
        for k in range(0, vsize, 4):
            cb = 0 if version == 0 else control[k // 4]
            for j in range(4):
                ctrl = (cb >> (j * 2)) & 3
                if ctrl == 3:
                    buffer[j * n:j * n + n] = np.frombuffer(data, np.uint8, n, p); p += n
                elif ctrl == 2:
                    buffer[j * n:j * n + n] = 0
                else:
                    tbl = BITS_V0 if version == 0 else BITS_V1[ctrl:]
                    tmp = np.zeros(n_al, np.uint8)
                    p = _decode_bytes(data, p, tmp, 0, n_al, tbl)
                    buffer[j * n:j * n + n] = tmp[:n]
            ch = 0 if version == 0 else channels[k // 4]
            kind = ch & 3
            if kind == 0:   # 4 independent byte streams, delta + zigzag8
                for j in range(4):
                    v = buffer[j * n:j * n + n].astype(np.int64)
                    d = ((-(v & 1)) ^ (v >> 1)) & 0xFF
                    col = (np.cumsum(d) + int(last[k + j])) & 0xFF
                    out[vo:vo + n, k + j] = col
            elif kind == 1:  # 2 x 16-bit streams
                for h in range(2):
                    lo = buffer[(2 * h) * n:(2 * h) * n + n].astype(np.int64)
                    hi = buffer[(2 * h + 1) * n:(2 * h + 1) * n + n].astype(np.int64)
                    v = lo | (hi << 8)
                    d = ((-(v & 1)) ^ (v >> 1)) & 0xFFFF
                    p0 = int(last[k + 2 * h]) | (int(last[k + 2 * h + 1]) << 8)
                    col = (np.cumsum(d) + p0) & 0xFFFF
                    out[vo:vo + n, k + 2 * h] = col & 0xFF
                    out[vo:vo + n, k + 2 * h + 1] = col >> 8
            elif kind == 2:  # 32-bit xor with rotation
                rot = (32 - (ch >> 4)) & 31
                v = (buffer[0:n].astype(np.uint32) | (buffer[n:2 * n].astype(np.uint32) << np.uint32(8)) |
                     (buffer[2 * n:3 * n].astype(np.uint32) << np.uint32(16)) | (buffer[3 * n:4 * n].astype(np.uint32) << np.uint32(24)))
                v = _rotl(v, rot)
                p0 = np.uint32(int(last[k]) | (int(last[k + 1]) << 8) | (int(last[k + 2]) << 16) | (int(last[k + 3]) << 24))
                col = np.bitwise_xor.accumulate(np.concatenate([[p0], v]).astype(np.uint32))[1:]
                for j in range(4):
                    out[vo:vo + n, k + j] = (col >> np.uint32(8 * j)) & 0xFF
            else:
                raise ValueError('channel')
        last[:] = out[vo + n - 1]
        vo += n
    assert len(data) - p == tailpad, (len(data) - p, tailpad)
    return out
