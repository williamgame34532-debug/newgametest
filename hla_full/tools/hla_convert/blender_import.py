"""Import a Half-Life: Alyx model (.vmdl_c) into Blender: meshes, UVs, materials with their textures,
skeleton and skin weights. Uses the decoders of this folder (kv3, mbuf, meshopt, vtex).

  blender --background --python blender_import.py -- <model.vmdl_c> <root of extracted files> <out.blend>
  (or with the bpy module: python blender_import.py <model.vmdl_c> <root> <out.blend>)

<root> is the folder vpk.py extracted into (with --deps), so materials and textures are found there.
"""
import os
import sys
import numpy as np

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
from kv3 import read_resource, kv3
from mbuf import read_mbuf
from meshopt import decode_index_buffer, decode_vertex_buffer
from vtex import read_vtex

import bpy
import mathutils

# DXGI formats used by Source 2 vertex streams
F32x3, F32x2, F32x4, F16x2, U8x4, UN8x4, F16x4 = 6, 16, 2, 34, 30, 28, 10


def buffer(buf, is_vertex):
    if not buf['needs_decode']:
        if is_vertex:
            return np.frombuffer(buf['raw'], np.uint8)[:buf['count'] * buf['esize']].reshape(buf['count'], buf['esize'])
        return np.frombuffer(buf['raw'], np.uint16 if buf['esize'] == 2 else np.uint32)[:buf['count']]
    if is_vertex:
        return decode_vertex_buffer(buf['count'], buf['esize'], buf['raw'])
    out = decode_index_buffer(buf['count'], buf['esize'], buf['raw'])
    return np.frombuffer(out, np.uint16 if buf['esize'] == 2 else np.uint32) if isinstance(out, (bytes, bytearray)) else np.asarray(out)


def attr(v, buf, name, index=0):
    for a in buf['attrs']:
        if a['name'] == name and a['index'] == index:
            o, f = a['offset'], a['format']
            col = v[:, o:]
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
    return None


def find_file(root, ref):
    ref = ref.replace('\\', '/')
    for cand in (ref + '_c', ref):
        p = os.path.join(root, cand)
        if os.path.exists(p):
            return p


_mat_cache = {}


def material(root, ref, texdir):
    if ref in _mat_cache:
        return _mat_cache[ref]
    name = os.path.basename(ref).replace('.vmat', '')
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes['Principled BSDF']
    path = find_file(root, ref)
    if path:
        try:
            b, bl = read_resource(path)
            data = kv3(b, *bl['DATA'][0])
            for tp in data.get('m_textureParams', []):
                slot, tref = tp.get('m_name'), tp.get('m_pValue')
                if not tref:
                    continue
                tpath = find_file(root, tref)
                if not tpath:
                    continue
                png = os.path.join(texdir, os.path.basename(tref).replace('.vtex', '') + '.png')
                if not os.path.exists(png):
                    read_vtex(tpath).save(png)
                tex = m.node_tree.nodes.new('ShaderNodeTexImage')
                tex.image = bpy.data.images.load(png)
                if slot == 'g_tColor':
                    m.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
                elif slot in ('g_tSelfIllumMask', 'g_tSelfIllum'):
                    m.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Emission Color'])
                    bsdf.inputs['Emission Strength'].default_value = 2.0
                elif slot == 'g_tRoughness':
                    tex.image.colorspace_settings.name = 'Non-Color'
                    m.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Roughness'])
            for vp in data.get('m_vectorParams', []):
                if vp.get('m_name') == 'g_vColorTint':
                    c = vp.get('m_value')
                    if c is not None and len(c) >= 3 and not bsdf.inputs['Base Color'].is_linked:
                        bsdf.inputs['Base Color'].default_value = (float(c[0]), float(c[1]), float(c[2]), 1)
        except Exception as e:
            print('material', ref, 'failed:', e)
    _mat_cache[ref] = m
    return m


def skeleton(data):
    sk = data.get('m_modelSkeleton') or {}
    names = list(sk.get('m_boneName', []))
    parents = list(sk.get('m_nParent', []))
    pos = sk.get('m_bonePosParent', [])
    rot = sk.get('m_boneRotParent', [])
    G = []
    for i in range(len(names)):
        q = rot[i]
        M = mathutils.Quaternion((q[3], q[0], q[1], q[2])).to_matrix().to_4x4()
        M.translation = mathutils.Vector(pos[i])
        G.append(G[parents[i]] @ M if parents[i] >= 0 else M)
    return names, parents, G


def build(path, root, out):
    b, bl = read_resource(path)
    data = kv3(b, *bl['DATA'][0])
    texdir = os.path.join(os.path.dirname(out) or '.', 'textures')
    os.makedirs(texdir, exist_ok=True)
    names, parents, G = skeleton(data)
    remap = np.array(data.get('m_remappingTable', []), np.int64)
    starts = list(data.get('m_remappingTableStarts', []))

    arm = None
    if names:
        ad = bpy.data.armatures.new('skeleton')
        arm = bpy.data.objects.new('skeleton', ad)
        bpy.context.scene.collection.objects.link(arm)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode='EDIT')
        for i, n in enumerate(names):
            eb = ad.edit_bones.new(n)
            eb.head = G[i].translation
            eb.tail = G[i] @ mathutils.Vector((0, 1.0, 0))
            if parents[i] >= 0:
                eb.parent = ad.edit_bones[names[parents[i]]]
        bpy.ops.object.mode_set(mode='OBJECT')

    # embedded meshes: one MDAT + MBUF per mesh
    meshes = list(zip(bl.get('MDAT', []), bl.get('MBUF', [])))
    for mi, (mdat, mbuf_blk) in enumerate(meshes):
        md = kv3(b, *mdat)
        mb = read_mbuf(b, mbuf_blk[0])
        rstart = int(starts[mi]) if mi < len(starts) else 0
        for so in md.get('m_sceneObjects', []):
            for di, dc in enumerate(so.get('m_drawCalls', [])):
                vbuf = mb['vb'][dc['m_vertexBuffers'][0]['m_hBuffer']]
                ibuf = mb['ib'][dc['m_indexBuffer']['m_hBuffer']]
                v = buffer(vbuf, True)
                idx = buffer(ibuf, False)
                s, c = dc['m_nStartIndex'], dc['m_nIndexCount']
                tri = np.asarray(idx[s:s + c], np.int64).reshape(-1, 3) + dc.get('m_nBaseVertex', 0)
                used = np.unique(tri)
                remap_local = {g: k for k, g in enumerate(used)}
                pos = attr(v, vbuf, 'POSITION')[used]
                uv = attr(v, vbuf, 'TEXCOORD')
                me = bpy.data.meshes.new('mesh%d_%d' % (mi, di))
                me.from_pydata(pos.tolist(), [], [[remap_local[i] for i in t] for t in tri.tolist()])
                if uv is not None:
                    uvl = me.uv_layers.new()
                    uvs = uv[used]
                    for poly in me.polygons:
                        for li in poly.loop_indices:
                            u, w = uvs[me.loops[li].vertex_index]
                            uvl.data[li].uv = (u, 1 - w)
                me.materials.append(material(root, dc['m_material'], texdir))
                me.update()
                ob = bpy.data.objects.new(me.name, me)
                bpy.context.scene.collection.objects.link(ob)
                bi = attr(v, vbuf, 'BLENDINDICES')
                bw = attr(v, vbuf, 'BLENDWEIGHT')
                if arm is not None and bi is not None and remap.size:
                    bi = bi[used].astype(np.int64)
                    bw = bw[used] if bw is not None else np.tile([1, 0, 0, 0], (len(used), 1))
                    if bw.max() > 1.5:
                        bw = bw / 255.0
                    groups = {}
                    for k in range(len(used)):
                        for j in range(4):
                            w = float(bw[k, j]) if bw.shape[1] > j else 0.0
                            if w <= 0:
                                continue
                            bone = int(remap[rstart + int(bi[k, j])])
                            g = groups.get(bone)
                            if g is None:
                                g = ob.vertex_groups.new(name=names[bone])
                                groups[bone] = g
                            g.add([k], w, 'REPLACE')
                    mod = ob.modifiers.new('skeleton', 'ARMATURE')
                    mod.object = arm
                    ob.parent = arm
                print('mesh', mi, 'draw call', di, len(used), 'verts', len(tri), 'tris', dc['m_material'])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(out))
    print('saved', out)


if __name__ == '__main__':
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    build(*args[:3])
