"""Preview: station.mdl split into hull + model parts (cl_partmap.lua signatures, matched exactly like
the game will) + built parts, posed by the addon's own sh_rig.lua. Optional UI png on the display.
usage: preview2.py out_prefix 'state json' 'views' [ui.png]"""
import sys, json, math, os
import bpy, mathutils
from lupa import luajit21
sys.path.insert(0, '/tmp/bscripts'); import srcmdl
ADDON = '/home/user/newgametest/combine_fabricator/lua/cf_rework/'
outp, state, views = sys.argv[1], json.loads(sys.argv[2]), sys.argv[3].split(';')
ui = sys.argv[4] if len(sys.argv) > 4 else None
L = luajit21.LuaRuntime(unpack_returned_tuples=True)
for f in ('sh_math.lua', 'sh_geometry.lua', 'sh_rig.lua', 'cl_partmap.lua'):
    L.execute(open(ADDON + f).read())
geo = L.eval('CFRework.Geo.build()')
pose = L.eval('CFRework.Rig.Pose')(L.table_from(state))
PM = L.eval('CFRework.PartMap')

# --- split the model exactly like the runtime: union-find on positions quantized to 1/100
r = srcmdl.load('/tmp/u/fab/combine_fabricator/models/cf_rework/station.mdl'); V = r['verts']
q = lambda x: math.floor(x * 100 + 0.5)
alltris = [(m['material'], t) for m in r['meshes'] for t in m['tris']]
parent = {}
def find(a):
    while parent[a] != a:
        parent[a] = parent[parent[a]]; a = parent[a]
    return a
keys = []
for mat, t in alltris:
    ks = [tuple(q(c) for c in V[i][0]) for i in t]
    for k in ks: parent.setdefault(k, k)
    for k in ks[1:]:
        a, b = find(ks[0]), find(k)
        if a != b: parent[b] = a
    keys.append(ks[0])
comp = {}
for ti, (mat, t) in enumerate(alltris):
    d = comp.setdefault(find(keys[ti]), [0, 0.0, 0.0, 0.0])
    d[0] += 1
    for i in t:
        for k in range(3): d[k + 1] += V[i][0][k]
lookup = {}
for name in PM.keys():
    lst = PM[name]
    for i in range(1, len(lst) + 1):
        e = lst[i]
        lookup.setdefault(int(e[1]), []).append((e[2], e[3], e[4], name))
partof = {}
matched = 0
for root, d in comp.items():
    n = d[0]; c = (d[1] / (3 * n), d[2] / (3 * n), d[3] / (3 * n))
    for (x, y, z, name) in lookup.get(n, []):
        if abs(x - c[0]) < 0.02 and abs(y - c[1]) < 0.02 and abs(z - c[2]) < 0.02:
            partof[root] = name; matched += 1; break
print('matched components', matched)

bpy.ops.wm.read_factory_settings(use_empty=True); sc = bpy.context.scene
def texmat(name):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; b = nt.nodes['Principled BSDF']
    tx = nt.nodes.new('ShaderNodeTexImage'); tx.image = bpy.data.images.load('/tmp/u/tex/%s.png' % name)
    mix = nt.nodes.new('ShaderNodeMixRGB'); mix.blend_type = 'MULTIPLY'; mix.inputs[0].default_value = 1
    mix.inputs[2].default_value = (0.42, 0.45, 0.48, 1)
    nt.links.new(tx.outputs['Color'], mix.inputs[1]); nt.links.new(mix.outputs[0], b.inputs['Base Color'])
    b.inputs['Metallic'].default_value = 0.3; b.inputs['Roughness'].default_value = 0.55
    return m
TEXM = {}
buckets = {}
for ti, (mat, t) in enumerate(alltris):
    part = partof.get(find(keys[ti]), 'hull')
    if os.environ.get('NOPARTS'): part = 'hull'
    buckets.setdefault((part, mat), []).append(t)
def tomat(m):
    return mathutils.Matrix(((m[1], m[2], m[3], m[4]), (m[5], m[6], m[7], m[8]), (m[9], m[10], m[11], m[12]), (0, 0, 0, 1)))
for (part, mat), tl in buckets.items():
    used = sorted({i for t in tl for i in t}); rm = {g: k for k, g in enumerate(used)}
    me = bpy.data.meshes.new(part + mat)
    me.from_pydata([(-V[g][0][1], V[g][0][0], V[g][0][2]) for g in used], [], [(rm[a], rm[c], rm[b]) for a, b, c in tl])
    uvl = me.uv_layers.new()
    for p in me.polygons:
        for li in p.loop_indices:
            u, v = V[used[me.loops[li].vertex_index]][2]; uvl.data[li].uv = (u, 1 - v)
    if mat not in TEXM: TEXM[mat] = texmat(mat)
    me.materials.append(TEXM[mat])
    ob = bpy.data.objects.new(part + mat, me); sc.collection.objects.link(ob)
    if part != 'hull': ob.matrix_world = tomat(pose[part])

def mkmat(name, col, emit=0.0, rough=0.5, metal=0.4):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = col; b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    if emit: b.inputs['Emission Color'].default_value = col; b.inputs['Emission Strength'].default_value = emit
    return m
MATS = {'metal': mkmat('metal', (0.075, 0.085, 0.095, 1)), 'steel': mkmat('steel', (0.2, 0.215, 0.23, 1), rough=.35, metal=.7),
        'brass': mkmat('brass', (0.40, 0.36, 0.30, 1), rough=.35, metal=.85), 'silver': mkmat('silver', (.62, .64, .66, 1), rough=.3, metal=.9),
        'dark': mkmat('dark', (0.01, 0.012, 0.014, 1), rough=.8, metal=0), 'glow': mkmat('glow', (0.18, 0.85, 0.95, 1), emit=6),
        'white': mkmat('white', (0.9, 0.97, 1, 1), emit=10), 'red': mkmat('red', (1, 0.08, 0.05, 1), emit=8),
        'screen': mkmat('screen', (0.01, 0.025, 0.03, 1), rough=.2, metal=0)}
for name in geo.keys():
    if os.environ.get('NOBUILT'): continue
    mats = geo[name]
    for mname in list(mats.keys()):
        lst = mats[mname]; n = len(lst) // 8
        verts = [(lst[i * 8 + 1], lst[i * 8 + 2], lst[i * 8 + 3]) for i in range(n)]
        me = bpy.data.meshes.new(name + mname); me.from_pydata(verts, [], [(t, t + 2, t + 1) for t in range(0, n, 3)])
        me.materials.append(MATS[mname]); ob = bpy.data.objects.new(me.name, me); sc.collection.objects.link(ob)
        ob.matrix_world = tomat(pose[name])

if ui:
    fr = L.eval('CFRework.Rig.ScreenFrame')(pose); S = L.eval('CFRework.Geo.SCREEN')
    o, rr, dd = fr[0], fr[1], fr[2]
    O = mathutils.Vector((o[1], o[2], o[3])); Rv = mathutils.Vector((rr[1], rr[2], rr[3])); Dv = mathutils.Vector((dd[1], dd[2], dd[3]))
    vs = [O, O + Rv * S.w, O + Rv * S.w + Dv * S.h, O + Dv * S.h]
    me = bpy.data.meshes.new('ui'); me.from_pydata([tuple(v) for v in vs], [], [(0, 1, 2, 3)]); uv = me.uv_layers.new()
    for li, (u, v) in enumerate([(0, 1), (1, 1), (1, 0), (0, 0)]): uv.data[li].uv = (u, v)
    m = bpy.data.materials.new('ui'); m.use_nodes = True; nt = m.node_tree
    em = nt.nodes.new('ShaderNodeEmission'); tx = nt.nodes.new('ShaderNodeTexImage'); tx.image = bpy.data.images.load(ui)
    nt.links.new(tx.outputs['Color'], em.inputs['Color']); em.inputs['Strength'].default_value = 1.4
    nt.links.new(em.outputs[0], nt.nodes['Material Output'].inputs['Surface']); me.materials.append(m)
    sc.collection.objects.link(bpy.data.objects.new('ui', me))

# emulate Source back-face culling: back faces are fully transparent
for m in bpy.data.materials:
    if not m.use_nodes or m.name == 'ui': continue
    nt = m.node_tree; outn = nt.nodes['Material Output']; src = outn.inputs['Surface'].links[0].from_socket
    geo_n = nt.nodes.new('ShaderNodeNewGeometry'); tr = nt.nodes.new('ShaderNodeBsdfTransparent'); mix = nt.nodes.new('ShaderNodeMixShader')
    nt.links.new(geo_n.outputs['Backfacing'], mix.inputs[0]); nt.links.new(src, mix.inputs[1]); nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], outn.inputs['Surface'])
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = int(os.environ.get('SAMPLES', 24)); sc.cycles.use_denoising = False
sc.render.resolution_x, sc.render.resolution_y = int(os.environ.get('RW', 960)), int(os.environ.get('RH', 640))
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs[0].default_value = (0.05, 0.11, 0.12, 1)
sun = bpy.data.lights.new('sun', 'SUN'); sun.energy = 2.2; sun.color = (0.75, 0.95, 1.0)
so = bpy.data.objects.new('sun', sun); sc.collection.objects.link(so); so.rotation_euler = (math.radians(45), math.radians(-20), math.radians(70))
fill = bpy.data.lights.new('fill', 'AREA'); fill.energy = 3000; fill.size = 80
fo = bpy.data.objects.new('fill', fill); sc.collection.objects.link(fo); fo.location = (120, -40, 120)
fo.rotation_euler = (mathutils.Vector((0, 0, 30)) - fo.location).to_track_quat('-Z', 'Y').to_euler()
cam = bpy.data.cameras.new('cam'); co = bpy.data.objects.new('cam', cam); sc.collection.objects.link(co); sc.camera = co
for v in views:
    name, c, t, lens = v.split(':')
    c = mathutils.Vector(map(float, c.split(','))); t = mathutils.Vector(map(float, t.split(',')))
    cam.lens = float(lens); co.location = c; co.rotation_euler = (t - c).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = '%s_%s.png' % (outp, name); bpy.ops.render.render(write_still=True)
