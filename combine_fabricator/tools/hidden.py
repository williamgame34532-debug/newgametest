"""Find connected components of the station, test visibility from outside with rays, cluster hidden ones.
Writes /tmp/u/comps_all.json with per-component info (entity space)."""
import sys, json, math
import bpy
sys.path.insert(0, '/tmp/bscripts')
import srcmdl
from mathutils import Vector
from mathutils.bvhtree import BVHTree

r = srcmdl.load('/tmp/u/fab/combine_fabricator/models/cf_rework/station.mdl')
V = r['verts']
def ent(p): return (-p[1], p[0], p[2])  # raw -> entity (yaw 90)

# triangles with material, in game order
tris = []
for mi, m in enumerate(r['meshes']):
    for t in m['tris']:
        tris.append((m['material'], t))
# union-find on quantized positions (same rule as the Lua side will use)
def key(p): return (round(p[0] * 100), round(p[1] * 100), round(p[2] * 100))
parent = {}
def find(a):
    while parent[a] != a:
        parent[a] = parent[parent[a]]; a = parent[a]
    return a
def union(a, b):
    a, b = find(a), find(b)
    if a != b: parent[b] = a
tkeys = []
for mat, (a, b, c) in tris:
    ks = [key(V[i][0]) for i in (a, b, c)]
    for k in ks: parent.setdefault(k, k)
    union(ks[0], ks[1]); union(ks[0], ks[2])
    tkeys.append(ks[0])
comp_of = {}
comps = []
tri_comp = []
for ti, k in enumerate(tkeys):
    root = find(k)
    if root not in comp_of:
        comp_of[root] = len(comps); comps.append([])
    cid = comp_of[root]; comps[cid].append(ti); tri_comp.append(cid)
print('components', len(comps))

allv = []; allf = []
for ti, (mat, t) in enumerate(tris):
    base = len(allv)
    for i in t: allv.append(Vector(ent(V[i][0])))
    allf.append((base, base + 1, base + 2))
bvh = BVHTree.FromPolygons(allv, allf, epsilon=0.0)

dirs = []
for i in range(60):  # fibonacci sphere
    z = 1 - 2 * (i + 0.5) / 60; rr = math.sqrt(1 - z * z); a = i * 2.39996
    dirs.append(Vector((math.cos(a) * rr, math.sin(a) * rr, z)))
out = []
for cid, tl in enumerate(comps):
    pts = []
    for ti in tl:
        f = allf[ti]; pts.extend(allv[j] for j in f)
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    cen = sum(pts, Vector()) / len(pts)
    # sample a few triangle centroids, count how many rays escape to infinity
    samples = [ (allv[allf[ti][0]] + allv[allf[ti][1]] + allv[allf[ti][2]]) / 3 for ti in tl[:: max(1, len(tl) // 6)] ][:6]
    esc = 0; tot = 0
    own = set(tl)
    for s in samples:
        for d in dirs:
            o = s + d * 0.05; tot += 1
            hit = None; start = o
            for _ in range(6):
                loc, nrm, idx, dist = bvh.ray_cast(start, d, 500)
                if loc is None: break
                if idx in own:
                    start = loc + d * 0.02; continue
                hit = idx; break
            if hit is None: esc += 1
    mats = sorted({tris[ti][0][-30:-25] for ti in tl})
    out.append(dict(id=cid, n=len(tl), lo=list(lo), hi=list(hi), c=list(cen), vis=esc / tot, mats=mats))
json.dump(out, open('/tmp/u/comps_all.json', 'w'))
json.dump(tri_comp, open('/tmp/u/tri_comp.json', 'w'))
hidden = [c for c in out if c['vis'] < 0.02]
print('hidden', len(hidden), 'tris', sum(c['n'] for c in hidden), 'of', len(tris))
