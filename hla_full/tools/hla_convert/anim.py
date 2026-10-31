# Source 2 compressed animation decoding (embedded ANIM/AGRP blocks) -> local bone pos/quat per frame.
import struct
import numpy as np

C = np.sin(np.pi / 4) / 16384.0


def read_quat(b, o):
    i1 = b[o] + ((b[o + 1] & 63) << 8)
    i2 = b[o + 2] + ((b[o + 3] & 63) << 8)
    i3 = b[o + 4] + ((b[o + 5] & 63) << 8)
    s1 = b[o + 1] & 128; s2 = b[o + 3] & 128; s3 = b[o + 5] & 128
    x = C * (i1 - 16384) if (b[o + 1] & 64) == 0 else C * i1
    y = C * (i2 - 16384) if (b[o + 3] & 64) == 0 else C * i2
    z = C * (i3 - 16384) if (b[o + 5] & 64) == 0 else C * i3
    w = np.sqrt(max(0.0, 1 - x * x - y * y - z * z))
    if s3:
        w = -w
    if s1:
        return (y, z, w, x) if s2 else (z, w, x, y)
    return (w, x, y, z) if s2 else (x, y, z, w)


def half3(b, o):
    return np.frombuffer(b, np.float16, 3, o).astype(np.float64)


class Segment:
    def __init__(self, seg, decoder_names, channels):
        c = bytes(seg['m_container'])
        self.dec = decoder_names[struct.unpack_from('<h', c, 0)[0]]
        n = struct.unpack_from('<h', c, 4)[0]
        self.n = n
        elems = struct.unpack_from('<%dh' % n, c, 8)
        self.data = c[8 + 2 * n:]
        ch = channels[seg['m_nLocalChannel']]
        self.attr = ch['attr']
        pos = {}
        for i in range(len(elems) - 1, -1, -1):
            if elems[i] >= 0:
                pos[elems[i]] = i
        self.wanted = []  # (element position in segment, bone index)
        for bone, el in enumerate(ch['remap']):
            if el in pos:
                self.wanted.append((pos[el], bone))
        for key, el in ch.get('named', {}).items():
            if el in pos:
                self.wanted.append((pos[el], key))

    def read(self, f, P, Q, F=None):
        d, n = self.data, self.n
        a = self.attr
        for e, bone in self.wanted:
            if self.dec == 'CCompressedStaticFullVector3':
                v = np.frombuffer(d, np.float32, 3, e * 12)
            elif self.dec == 'CCompressedStaticVector3':
                v = half3(d, e * 6)
            elif self.dec == 'CCompressedFullVector3':
                v = np.frombuffer(d, np.float32, 3, (f * n + e) * 12)
            elif self.dec == 'CCompressedAnimVector3':
                v = half3(d, (f * n + e) * 6)
            elif self.dec == 'CCompressedDeltaVector3':
                base = np.frombuffer(d, np.float32, 3, e * 12).astype(np.float64)
                v = base + half3(d, n * 12 + (f * n + e) * 6)
            elif self.dec == 'CCompressedStaticQuaternion':
                v = read_quat(d, e * 6)
            elif self.dec == 'CCompressedAnimQuaternion':
                v = read_quat(d, (f * n + e) * 6)
            elif self.dec == 'CCompressedFullQuaternion':
                v = np.frombuffer(d, np.float32, 4, (f * n + e) * 16)
            elif self.dec == 'CCompressedStaticFloat':
                v = struct.unpack_from('<f', d, e * 4)[0]
            elif self.dec == 'CCompressedFullFloat':
                v = struct.unpack_from('<f', d, (f * n + e) * 4)[0]
            else:
                return
            if a == 'data':
                if F is not None: F[bone] = v
                continue
            if a == 'Position':
                P[bone] = v
            elif a == 'Angle':
                Q[bone] = v


def build(K):
    sk = K['DATA']['m_modelSkeleton']
    names = list(sk['m_boneName'])
    idx = {n.lower(): i for i, n in enumerate(names)}
    bindP = np.array([np.array(p, float) for p in sk['m_bonePosParent']])
    bindQ = np.array([np.array(q, float) for q in sk['m_boneRotParent']])
    agrp = K['AGRP']['m_decodeKey']
    channels = []
    for ch in agrp['m_dataChannelArray']:
        remap = [-1] * len(names)
        for nm, el in zip(ch['m_szElementNameArray'], ch['m_nElementIndexArray']):
            i = idx.get(nm.lower())
            if i is not None and remap[i] == -1:
                remap[i] = int(el)
        named = {}
        if ch['m_szChannelClass'] != 'BoneChannel':
            named = {nm: int(el) for nm, el in zip(ch['m_szElementNameArray'], ch['m_nElementIndexArray'])}
            remap = []
        channels.append({'attr': ch['m_szVariableName'], 'remap': remap, 'named': named})
    A = K['ANIM']
    dnames = [d['m_szName'] for d in A['m_decoderArray']]
    segs = [Segment(s, dnames, channels) for s in A['m_segmentArray']]
    anims = {}
    for a in A['m_animArray']:
        pd = a['m_pData']
        nf = pd['m_nFrames']
        blocks = [(fb['m_nStartFrame'], fb['m_nEndFrame'], list(fb['m_segmentIndexArray'])) for fb in pd['m_frameblockArray']]
        P = np.repeat(bindP[None], nf, 0)
        Q = np.repeat(bindQ[None], nf, 0)
        Fl = [dict() for _ in range(nf)]
        for f in range(nf):
            for s0, s1, si in blocks:
                if s0 <= f <= s1:
                    for i in si:
                        segs[i].read(f - s0, P[f], Q[f], Fl[f])
        anims[a['m_name']] = {'fps': a['fps'], 'P': P, 'Q': Q, 'F': Fl, 'loop': a['m_flags']['m_bLooping']}
    return names, list(sk['m_nParent']), bindP, bindQ, anims
