# Half-Life: Alyx menu logo (logo_text_face_holo / logo_text_body_holo): meshes, morph frames
# (vertex animation cache driven by the 'animcycle' flex controller), letter bones and sequences.
import sys, os, struct
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from kv3 import read_resource, kv3
from mbuf import read_mbuf
from meshopt import decode_index_buffer, decode_vertex_buffer
from vtex import read_vtex
from anim import build
from skin import qmat


def buffer_bytes(buf, is_vertex):
    if not buf['needs_decode']:
        return np.frombuffer(buf['raw'], np.uint8).reshape(buf['count'], buf['esize']) if is_vertex else buf['raw']
    if is_vertex:
        return decode_vertex_buffer(buf['count'], buf['esize'], buf['raw'])
    return decode_index_buffer(buf['count'], buf['esize'], buf['raw'])


def load(path, morph_dir, mesh_index=0):
    b, bl = read_resource(path)
    K = {n: kv3(b, *bl[n][0]) for n in ['DATA', 'ASEQ', 'AGRP', 'ANIM']}
    md = kv3(b, *bl['MDAT'][mesh_index])
    mb = read_mbuf(b, bl['MBUF'][mesh_index][0])
    mr = kv3(b, *bl['MRPH'][mesh_index])
    remap = np.array(K['DATA']['m_remappingTable'], np.int64)
    starts = list(K['DATA']['m_remappingTableStarts'])
    rstart = int(starts[mesh_index]) if mesh_index < len(starts) else 0
    parts = []
    vbase = 0
    for dc in md['m_sceneObjects'][0]['m_drawCalls']:
        vbi = dc['m_vertexBuffers'][0]['m_hBuffer']
        ibi = dc['m_indexBuffer']['m_hBuffer']
        v = buffer_bytes(mb['vb'][vbi], True)
        ib = mb['ib'][ibi]
        idx = buffer_bytes(ib, False)
        idx = np.frombuffer(idx, np.uint16 if ib['esize'] == 2 else np.uint32) if isinstance(idx, (bytes, bytearray)) else idx
        s, c = dc['m_nStartIndex'], dc['m_nIndexCount']
        tri = np.asarray(idx[s:s + c], np.int64).reshape(-1, 3) + dc['m_nBaseVertex']
        pos = np.frombuffer(v[:, 0:12].tobytes(), np.float32).reshape(-1, 3).astype(float)
        bone = remap[rstart + v[:, 20].astype(np.int64)] if remap.size else np.zeros(len(v), np.int64)
        parts.append({'material': dc['m_material'].split('/')[-1].replace('.vmat', ''), 'pos': pos, 'tri': tri,
                      'bone': bone, 'morph0': vbase})
        vbase += dc['m_nVertexCount']
    # morph frames: per frame a delta per morph vertex (vertex id = running vertex index over draw calls)
    tex = np.asarray(read_vtex(os.path.join(morph_dir, os.path.basename(mr['m_pTextureAtlas']) + '_c')).convert('RGBA'), float)
    th, tw = tex.shape[:2]
    W, H = mr['m_nWidth'], mr['m_nHeight']
    names = [f['m_szFacs'] for f in mr['m_FlexDesc']]
    frames = np.zeros((len(names), W * H, 3))
    for md_ in mr['m_morphDatas']:
        nm = md_.get('m_name') or ''
        if nm not in names:
            continue
        fi = names.index(nm)
        for rect in md_.get('m_morphRectDatas') or []:
            pw = int(round(rect['m_flUWidthSrc'] * tw)); ph = int(round(rect['m_flVHeightSrc'] * th))
            bd = rect['m_bundleDatas'][0]  # position bundle
            u = int(round(bd['m_flULeftSrc'] * tw)); vv = int(round(bd['m_flVTopSrc'] * th))
            rng = np.array(bd['m_ranges'], float); off = np.array(bd['m_offsets'], float)
            blk = tex[vv:vv + ph, u:u + pw] / 255.0 * rng + off
            for r in range(ph):
                di = r + rect['m_nYTopDst']
                if di < 0 or di >= H:
                    continue
                for cc in range(pw):
                    dj = cc + rect['m_nXLeftDst']
                    if 0 <= dj < W:
                        frames[fi, di * W + dj] = blk[r, cc, :3]
    names_, parents, bP, bQ, anims = build(K)
    return {'parts': parts, 'frames': frames, 'parents': parents, 'bP': bP, 'bQ': bQ, 'anims': anims,
            'bones': names_, 'ctrl': [c['m_szName'] for c in mr['m_FlexControllers']]}


def globals_(parents, P, Q):
    G = np.zeros((len(parents), 4, 4))
    for i in range(len(parents)):
        L = np.eye(4); L[:3, :3] = qmat(Q[i]); L[:3, 3] = P[i]
        G[i] = L if parents[i] < 0 else G[parents[i]] @ L
    return G


def pose(L, seq, f):
    """World positions of every part at frame f of a sequence."""
    a = L['anims'][seq]
    F = a['F'][f]
    cyc = F.get(L['ctrl'][0], 0.0)
    wgt = F.get(L['ctrl'][1], 1.0)
    n = len(L['frames'])
    x = np.clip(cyc, 0, 1) * (n - 1)
    i0 = int(np.floor(x)); i1 = min(n - 1, i0 + 1); t = x - i0
    delta = (L['frames'][i0] * (1 - t) + L['frames'][i1] * t) * wgt
    Gb = globals_(L['parents'], L['bP'], L['bQ'])
    G = globals_(L['parents'], a['P'][f], a['Q'][f])
    S = G @ np.linalg.inv(Gb)
    out = []
    for p in L['parts']:
        k = np.arange(len(p['pos'])) + p['morph0']
        d = delta[np.clip(k, 0, len(delta) - 1)] * (k < len(delta))[:, None]
        q = np.c_[p['pos'] + d, np.ones(len(p['pos']))]
        w = np.einsum('nij,nj->ni', S[p['bone']], q)[:, :3]
        out.append(w)
    return out, cyc, wgt
