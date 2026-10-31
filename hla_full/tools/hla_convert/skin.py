import numpy as np, pickle, struct


def qmat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def globals_(parents, P, Q):
    n = len(parents)
    G = np.zeros((n, 4, 4))
    for i in range(n):
        L = np.eye(4); L[:3, :3] = qmat(Q[i]); L[:3, 3] = P[i]
        G[i] = L if parents[i] < 0 else G[parents[i]] @ L
    return G


def load_mesh(K, npz):
    d = np.load(npz)
    v, idx = d['v'], d['idx']
    pos = np.frombuffer(v[:, 0:12].tobytes(), np.float32).reshape(-1, 3).astype(np.float64)
    uv = np.frombuffer(v[:, 12:20].tobytes(), np.float32).reshape(-1, 2).astype(np.float64)
    nrm = np.frombuffer(v[:, 20:32].tobytes(), np.float32).reshape(-1, 3).astype(np.float64)
    bi = v[:, 48:52].astype(np.int64)
    bw = v[:, 52:56].astype(np.float64) / 255.0
    remap = np.array(K['DATA']['m_remappingTable'], np.int64)
    start = int(K['DATA']['m_remappingTableStarts'][0])
    bones = remap[start + bi]
    mats = []
    for dc in K['MDAT']['m_sceneObjects'][0]['m_drawCalls']:
        s, c = dc['m_nStartIndex'], dc['m_nIndexCount']
        mats.append((dc['m_material'].split('/')[-1].replace('.vmat', ''), idx[s:s + c].reshape(-1, 3)))
    return {'pos': pos, 'uv': uv, 'nrm': nrm, 'bones': bones, 'w': bw, 'mats': mats}


def skin(mesh, parents, bindG, P, Q):
    G = globals_(parents, P, Q)
    S = G @ np.linalg.inv(bindG)
    out = np.zeros_like(mesh['pos'])
    ph = np.c_[mesh['pos'], np.ones(len(mesh['pos']))]
    for k in range(4):
        w = mesh['w'][:, k]
        m = w > 0
        if not m.any():
            continue
        Sk = S[mesh['bones'][m, k]]
        out[m] += w[m, None] * np.einsum('nij,nj->ni', Sk, ph[m])[:, :3]
    return out
