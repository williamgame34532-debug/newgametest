# Independent SMD reader: rebuilds skinned positions the way studiomdl interprets the files.
import sys, math, glob
import numpy as np


def rot(x, y, z):
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    # Source AngleMatrix(QAngle(pitch=y, yaw=z, roll=x))
    return np.array([[cy * cz, sx * sy * cz - cx * sz, cx * sy * cz + sx * sz],
                     [cy * sz, sx * sy * sz + cx * cz, cx * sy * sz - sx * cz],
                     [-sy, sx * cy, cx * cy]])


def read(path):
    nodes, frames, tris = {}, [], []
    sec = None
    cur = None
    lines = open(path).read().splitlines()
    i = 0
    while i < len(lines):
        l = lines[i].strip(); i += 1
        if l in ('nodes', 'skeleton', 'triangles'):
            sec = l; continue
        if l == 'end':
            sec = None; continue
        if sec == 'nodes':
            a = l.split('"'); nodes[int(a[0])] = (a[1], int(a[2]))
        elif sec == 'skeleton':
            if l.startswith('time'):
                cur = {}; frames.append(cur)
            else:
                v = l.split(); cur[int(v[0])] = list(map(float, v[1:]))
        elif sec == 'triangles':
            mat = l
            vs = []
            for k in range(3):
                v = lines[i].split(); i += 1
                p = list(map(float, v[1:4]))
                n = int(v[9]); links = [(int(v[10 + 2 * j]), float(v[11 + 2 * j])) for j in range(n)]
                vs.append((p, links))
            tris.append((mat, vs))
    return nodes, frames, tris


def world(nodes, fr):
    G = {}
    for b in sorted(nodes):
        x = fr[b]; L = np.eye(4); L[:3, :3] = rot(*x[3:6]); L[:3, 3] = x[:3]
        p = nodes[b][1]
        G[b] = L if p < 0 else G[p] @ L
    return G


if __name__ == '__main__':
    d = sys.argv[1]
    nodes, ref, _ = read(d + '/ref_00.smd')
    bind = world(nodes, ref[0])
    inv = {b: np.linalg.inv(m) for b, m in bind.items()}
    out = {}
    for anim, f in [a.split(':') for a in sys.argv[2].split(',')]:
        _, frames, _ = read(d + '/anims/%s.smd' % anim)
        G = world(nodes, frames[int(f)])
        S = {b: G[b] @ inv[b] for b in G}
        pts = []
        for fn in sorted(glob.glob(d + '/ref_*.smd')):
            _, _, tris = read(fn)
            for mat, vs in tris:
                for p, links in vs:
                    q = np.zeros(3)
                    for b, w in links:
                        q += w * (S[b] @ np.r_[p, 1])[:3]
                    pts.append(q)
        out[anim + ':' + f] = np.array(pts)
        print(anim, f, len(pts))
    np.savez(sys.argv[3], **{k.replace(':', '_'): v for k, v in out.items()})
