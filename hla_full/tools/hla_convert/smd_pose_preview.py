"""Check converted SMDs the way studiomdl reads them: skin the reference SMD with frames of an animation
SMD and render it in Blender. Several models (e.g. the parts of the health station) can be posed together.

  python smd_pose_preview.py out.png "<ref.smd>|<anim.smd>|<frame>" ["<ref.smd>|<anim.smd>|<frame>" ...] [--cam x,y,z:tx,ty,tz]
"""
import math
import sys
import numpy as np
import bpy
import mathutils


def rot(x, y, z):
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rz @ Ry @ Rx


def read(path):
    L = open(path).read().split('\n')
    i = L.index('nodes') + 1
    parents = []
    while L[i] != 'end':
        parents.append(int(L[i].rsplit(' ', 1)[1]))
        i += 1
    frames, tris = [], []
    i = L.index('skeleton') + 1
    cur = None
    while L[i] != 'end':
        if L[i].startswith('time'):
            cur = {}
            frames.append(cur)
        else:
            v = L[i].split()
            cur[int(v[0])] = [float(x) for x in v[1:7]]
        i += 1
    if 'triangles' in L:
        i = L.index('triangles') + 1
        while i < len(L) and L[i] != 'end':
            mat = L[i]
            vs = []
            for k in range(3):
                v = L[i + 1 + k].split()
                n = int(v[9])
                links = [(int(v[10 + 2 * j]), float(v[11 + 2 * j])) for j in range(n)]
                vs.append((np.array([float(x) for x in v[1:4]]), links))
            tris.append((mat, vs))
            i += 4
    return parents, frames, tris


def globals_(parents, fr):
    G = [None] * len(parents)
    for b in range(len(parents)):
        x = fr[b]
        M = np.eye(4)
        M[:3, :3] = rot(x[3], x[4], x[5])
        M[:3, 3] = x[:3]
        G[b] = M if parents[b] < 0 else G[parents[b]] @ M
    return G


def posed(ref, anim, f):
    parents, rf, tris = read(ref)
    _p, af, _t = read(anim) if anim else (None, rf, None)
    bind = globals_(parents, rf[0])
    pose = globals_(parents, af[min(f, len(af) - 1)] if anim else rf[0])
    S = [pose[i] @ np.linalg.inv(bind[i]) for i in range(len(parents))]
    verts, faces, mats = [], [], []
    for mat, vs in tris:
        base = len(verts)
        for p, links in vs:
            q = np.zeros(3)
            for b, w in links:
                q += w * (S[b] @ np.append(p, 1))[:3]
            verts.append(q)
        faces.append((base, base + 1, base + 2))
        mats.append(mat)
    return verts, faces, mats


def main(argv):
    out = argv[0]
    cam = None
    jobs = []
    for a in argv[1:]:
        if a.startswith('--cam'):
            cam = a.split(' ', 1)[1] if ' ' in a else None
        elif a.startswith('cam='):
            cam = a[4:]
        else:
            jobs.append(a)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    palette = {}
    allv = []
    for j in jobs:
        ref, anim, f = j.split('|')
        v, fcs, mats = posed(ref, anim or None, int(f))
        allv += v
        me = bpy.data.meshes.new('m')
        me.from_pydata([tuple(x) for x in v], [], fcs)
        for mname in sorted(set(mats)):
            if mname not in palette:
                h = (hash(mname) % 1000) / 1000.0
                m = bpy.data.materials.new(mname)
                m.use_nodes = True
                import colorsys
                m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = colorsys.hsv_to_rgb(h, 0.35, 0.85) + (1,)
                palette[mname] = m
            me.materials.append(palette[mname])
        idx = {m.name: i for i, m in enumerate(me.materials)}
        for poly, mname in zip(me.polygons, mats):
            poly.material_index = idx[palette[mname].name]
        sc.collection.objects.link(bpy.data.objects.new('o', me))
    A = np.array(allv)
    lo, hi = A.min(0), A.max(0)
    ctr = mathutils.Vector((lo + hi) / 2)
    R = float(np.linalg.norm(hi - lo))
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 16
    sc.render.resolution_x, sc.render.resolution_y = 700, 600
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs[0].default_value = (0.3, 0.32, 0.35, 1)
    s = bpy.data.lights.new('s', 'SUN'); s.energy = 3
    so = bpy.data.objects.new('s', s); sc.collection.objects.link(so); so.rotation_euler = (0.8, 0.2, 0.9)
    c = bpy.data.cameras.new('c'); co = bpy.data.objects.new('c', c); sc.collection.objects.link(co); sc.camera = co
    if cam:
        p, t = cam.split(':')
        co.location = mathutils.Vector([float(x) for x in p.split(',')])
        tgt = mathutils.Vector([float(x) for x in t.split(',')])
    else:
        co.location = ctr + mathutils.Vector((1, -0.6, 0.35)).normalized() * R * 1.1
        tgt = ctr
    co.rotation_euler = (tgt - co.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    main(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
