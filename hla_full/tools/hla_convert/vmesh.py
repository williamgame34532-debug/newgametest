"""Source 2 model meshes (embedded MDAT + MBUF): positions, normals, UVs, bones per vertex.
Shared by blender_import.py and vmdl_to_qc.py (no Blender dependency)."""
import numpy as np
from kv3 import read_resource, kv3
from mbuf import read_mbuf
from meshopt import decode_index_buffer, decode_vertex_buffer

# DXGI formats used by Source 2 vertex streams
F32x4, F32x3, F32x2, F16x4, U8x4, UN8x4, F16x2 = 2, 6, 16, 10, 30, 28, 34


def buffer(buf, is_vertex):
    if not buf['needs_decode']:
        if is_vertex:
            return np.frombuffer(buf['raw'], np.uint8)[:buf['count'] * buf['esize']].reshape(buf['count'], buf['esize'])
        return np.frombuffer(buf['raw'], np.uint16 if buf['esize'] == 2 else np.uint32)[:buf['count']]
    if is_vertex:
        return decode_vertex_buffer(buf['count'], buf['esize'], buf['raw'])
    out = decode_index_buffer(buf['count'], buf['esize'], buf['raw'])
    return np.frombuffer(out, np.uint16 if buf['esize'] == 2 else np.uint32) if isinstance(out, (bytes, bytearray)) else np.asarray(out)


def raw_attr(v, buf, name, index=0):
    for a in buf['attrs']:
        if a['name'] == name and a['index'] == index:
            return a['format'], np.ascontiguousarray(v[:, a['offset']:])
    return None, None


def attr(v, buf, name, index=0):
    f, col = raw_attr(v, buf, name, index)
    if f is None:
        return None
    if f == F32x3:
        return np.frombuffer(np.ascontiguousarray(col[:, :12]).tobytes(), np.float32).reshape(-1, 3)
    if f == F32x2:
        return np.frombuffer(np.ascontiguousarray(col[:, :8]).tobytes(), np.float32).reshape(-1, 2)
    if f == F32x4:
        return np.frombuffer(np.ascontiguousarray(col[:, :16]).tobytes(), np.float32).reshape(-1, 4)
    if f == F16x2:
        return np.frombuffer(np.ascontiguousarray(col[:, :4]).tobytes(), np.float16).reshape(-1, 2).astype(np.float32)
    if f == F16x4:
        return np.frombuffer(np.ascontiguousarray(col[:, :8]).tobytes(), np.float16).reshape(-1, 4).astype(np.float32)
    if f in (U8x4, UN8x4):
        return np.ascontiguousarray(col[:, :4]).astype(np.float32) / (255.0 if f == UN8x4 else 1.0)
    return None


def decompress_normals(b):
    """Source 2 compressed normal (first two bytes of an R8G8B8A8 NORMAL), vectorised."""
    x = b[:, 0].astype(np.float64) - 128.0
    y = b[:, 1].astype(np.float64) - 128.0
    zsb = (x < 0).astype(np.float64)
    tsb = (y < 0).astype(np.float64)
    zs = -(2 * zsb - 1)
    ts = -(2 * tsb - 1)
    x = x * zs - zsb
    y = y * ts - tsb
    x -= 64
    y -= 64
    xsb = (x < 0).astype(np.float64)
    ysb = (y < 0).astype(np.float64)
    xs = -(2 * xsb - 1)
    ys = -(2 * ysb - 1)
    x = (x * xs - xsb) / 63.0
    y = (y * ys - ysb) / 63.0
    z = 1.0 - x - y
    inv = 1.0 / np.sqrt(x * x + y * y + z * z)
    return np.stack([x * inv * xs, y * inv * ys, z * inv * zs], 1)


def normals(v, buf, pos, tri):
    f, col = raw_attr(v, buf, 'NORMAL')
    if f == F32x3:
        return np.frombuffer(col[:, :12].tobytes(), np.float32).reshape(-1, 3).astype(np.float64)
    if f in (UN8x4, U8x4):
        return decompress_normals(col[:, :2])
    # fall back: smooth normals from the faces
    n = np.zeros_like(pos, dtype=np.float64)
    a, b, c = pos[tri[:, 0]], pos[tri[:, 1]], pos[tri[:, 2]]
    fn = np.cross(b - a, c - a)
    for k in range(3):
        np.add.at(n, tri[:, k], fn)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
    return n


def load(path):
    """-> (K dict of KV blocks, list of draw calls {material, pos, nrm, uv, tri, bones, weights})"""
    b, bl = read_resource(path)
    K = {}
    for name in ('DATA', 'ASEQ', 'AGRP', 'ANIM'):
        if name in bl:
            K[name] = kv3(b, *bl[name][0])
    mdats = [kv3(b, *m) for m in bl.get('MDAT', [])]
    K['MDAT'] = mdats[0] if mdats else {}
    remap = np.array(K['DATA'].get('m_remappingTable', []), np.int64)
    starts = list(K['DATA'].get('m_remappingTableStarts', []))
    out = []
    for mi, (md, mbb) in enumerate(zip(mdats, bl.get('MBUF', []))):
        mb = read_mbuf(b, mbb[0])
        rstart = int(starts[mi]) if mi < len(starts) else 0
        for so in md.get('m_sceneObjects', []):
            for dc in so.get('m_drawCalls', []):
                vbuf = mb['vb'][dc['m_vertexBuffers'][0]['m_hBuffer']]
                ibuf = mb['ib'][dc['m_indexBuffer']['m_hBuffer']]
                v = buffer(vbuf, True)
                idx = buffer(ibuf, False)
                s, c = dc['m_nStartIndex'], dc['m_nIndexCount']
                tri = np.asarray(idx[s:s + c], np.int64).reshape(-1, 3) + dc.get('m_nBaseVertex', 0)
                used = np.unique(tri)
                lut = np.full(len(v), -1, np.int64)
                lut[used] = np.arange(len(used))
                pos = attr(v, vbuf, 'POSITION')[used].astype(np.float64)
                ltri = lut[tri]
                nrm = normals(v[used], vbuf, pos, ltri)
                uv = attr(v, vbuf, 'TEXCOORD')
                uv = uv[used] if uv is not None else np.zeros((len(used), 2))
                bi = attr(v, vbuf, 'BLENDINDICES')
                bw = attr(v, vbuf, 'BLENDWEIGHT')
                if bi is not None and remap.size:
                    bi = bi[used].astype(np.int64)
                    bones = remap[rstart + bi]
                    if bw is not None:
                        w = bw[used].astype(np.float64)
                        if w.max() > 1.5:
                            w /= 255.0
                    else:
                        w = np.zeros((len(used), 4))
                        w[:, 0] = 1.0  # rigid: the first index carries the vertex
                else:
                    bones = np.zeros((len(used), 4), np.int64)
                    w = np.zeros((len(used), 4))
                    w[:, 0] = 1.0
                out.append({'material': dc['m_material'], 'pos': pos, 'nrm': nrm, 'uv': uv, 'tri': ltri,
                            'bones': bones, 'weights': w})
    return K, out
