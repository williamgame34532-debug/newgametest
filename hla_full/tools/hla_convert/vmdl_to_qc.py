"""Half-Life: Alyx model (.vmdl_c) -> Source 1 model source for Garry's Mod: SMD meshes with the
skeleton, every animation as a sequence, attachments, collision box, QC, and the materials as
VMT + VTF (DXT) in a content addon.

  python vmdl_to_qc.py <model.vmdl_c> <root of extracted HL:A files> <modelsrc out dir>
                       <content addon dir> <model path, e.g. hla/health_charger/charger.mdl>
                       [--mass 50] [--static]

Then compile <out>/<name>.qc with studiomdl (compile.bat next to it).
"""
import math
import os
import sys

import numpy as np

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import vmesh
import vtf_out
from anim import build
from kv3 import read_resource, kv3
from skin import qmat
from vtex import read_vtex


def f6(v):
    return '%.6f' % (0.0 if abs(v) < 5e-7 else v)


def euler(q):
    M = qmat(q)
    y = math.asin(max(-1.0, min(1.0, -M[2, 0])))
    if abs(M[2, 0]) < 0.999999:
        return math.atan2(M[2, 1], M[2, 2]), y, math.atan2(M[1, 0], M[0, 0])
    return math.atan2(-M[1, 2], M[1, 1]), y, 0.0


def qangle(q):
    x, y, z = euler(q)
    return math.degrees(y), math.degrees(z), math.degrees(x)


# ---------------------------------------------------------------------------------------------
# materials
def find(root, ref):
    ref = ref.replace('\\', '/')
    for c in (ref + '_c', ref):
        p = os.path.join(root, c)
        if os.path.exists(p):
            return p


def texture(root, ref, out_dir, name, **kw):
    p = find(root, ref) if ref else None
    if not p:
        return None
    dst = os.path.join(out_dir, name + '.vtf')
    if not os.path.exists(dst):
        vtf_out.write(dst, read_vtex(p), **kw)
    return name


def convert_material(root, ref, content, matdir):
    name = os.path.basename(ref).replace('.vmat', '')
    out_dir = os.path.join(content, 'materials', matdir)
    os.makedirs(out_dir, exist_ok=True)
    vmt_path = os.path.join(out_dir, name + '.vmt')
    p = find(root, ref)
    if not p:
        open(vmt_path, 'w').write('"VertexLitGeneric"\n{\n\t"$basetexture" "dev/dev_measuregeneric01b"\n}\n')
        return name, False
    b, bl = read_resource(p)
    d = kv3(b, *bl['DATA'][0])
    shader = d.get('m_shaderName', '')
    tex = {t['m_name']: t.get('m_pValue') for t in d.get('m_textureParams', [])}
    ints = {t['m_name']: t['m_nValue'] for t in d.get('m_intParams', [])}
    fl = {t['m_name']: t['m_flValue'] for t in d.get('m_floatParams', [])}
    vec = {t['m_name']: [float(c) for c in t['m_value']] for t in d.get('m_vectorParams', [])}
    base = matdir.replace('\\', '/') + '/'
    L = []
    if 'hologram' in shader:
        c = vec.get('g_vHologramColor', [0.3, 0.7, 1, 1])
        t = texture(root, tex.get('g_tColor'), out_dir, name + '_color')
        L = ['"UnlitGeneric"', '{', '\t"$basetexture" "%s"' % (base + t if t else 'vgui/white'),
             '\t"$color2" "[%.3f %.3f %.3f]"' % (c[0] * 3, c[1] * 3, c[2] * 3), '\t"$additive" "1"', '\t"$nocull" "1"', '\t"$model" "1"', '}']
    else:
        glass = 'glass' in shader
        col = texture(root, tex.get('g_tColor'), out_dir, name + '_color', alpha=True if glass else False)
        nrm = texture(root, tex.get('g_tNormal'), out_dir, name + '_normal', alpha=False, normal=True)
        L = ['"VertexLitGeneric"', '{', '\t"$basetexture" "%s"' % (base + col if col else 'vgui/white')]
        if nrm:
            L.append('\t"$bumpmap" "%s"' % (base + nrm))
        tint = vec.get('g_vColorTint', [1, 1, 1])
        if glass:
            gt = vec.get('GlassTintColor', [1, 1, 1])
            c = [tint[i] * gt[i] for i in range(3)]
            op = fl.get('g_flOpacityScale', 0.5)
            em = vec.get('g_vEmissiveColor', [0, 0, 0, 0])
            L += ['\t"$translucent" "1"', '\t"$alpha" "%.3f"' % max(0.25, min(1.0, op if op > 0 else 0.6)),
                  '\t"$color2" "[%.3f %.3f %.3f]"' % tuple(c), '\t"$phong" "1"', '\t"$phongboost" "2"', '\t"$phongexponent" "40"']
            if ints.get('F_RENDER_BACKFACES'):
                L.append('\t"$nocull" "1"')
            if em and max(em[:3]) > 0.2 and op == 0:
                L += ['\t"$selfillum" "1"', '\t"$selfillumtint" "[%.3f %.3f %.3f]"' % (em[0], em[1], em[2])]
        else:
            L += ['\t"$color2" "[%.3f %.3f %.3f]"' % (tint[0], tint[1], tint[2]), '\t"$phong" "1"',
                  '\t"$phongboost" "%.2f"' % (0.6 if 'skin' in shader else 1.0), '\t"$phongexponent" "20"',
                  '\t"$phongfresnelranges" "[0.3 0.6 1]"']
        if ints.get('F_SELF_ILLUM'):
            mask_ref = tex.get('g_tSelfIllumMask')
            if not mask_ref:  # foliage/pipes keep the glow in a separate *_selfillum texture next to the colour
                cref = tex.get('g_tColor') or ''
                guess = [k for k in os.listdir(os.path.dirname(find(root, cref) or '.') or '.') if 'selfillum' in k and k.split('_selfillum')[0] in os.path.basename(cref)]
                mask_ref = (os.path.dirname(cref) + '/' + guess[0][:-2]) if guess else None
            mask = texture(root, mask_ref, out_dir, name + '_illum', alpha=False) if mask_ref else None
            st = vec.get('g_vSelfIllumTint', [1, 1, 1])
            br = fl.get('g_flSelfIllumBrightness', 1.0) * fl.get('g_flSelfIllumOverallScale', 1.0)
            L += ['\t"$selfillum" "1"', '\t"$selfillumtint" "[%.3f %.3f %.3f]"' % (st[0] * br, st[1] * br, st[2] * br)]
            if mask:
                L.append('\t"$selfillummask" "%s"' % (base + mask))
        L.append('}')
    open(vmt_path, 'w').write('\n'.join(L) + '\n')
    return name, True


# ---------------------------------------------------------------------------------------------
def main(args):
    flags = [a for a in args if a.startswith('--')]
    vals = [a for a in args if not a.startswith('--')]
    path, root, out, content, mdlpath = vals[:5]
    mass = 50.0
    for i, a in enumerate(args):
        if a == '--mass':
            mass = float(args[i + 1])
    static = '--static' in flags
    name = os.path.splitext(os.path.basename(mdlpath))[0]
    matdir = 'models/' + os.path.dirname(mdlpath)
    os.makedirs(os.path.join(out, 'anims'), exist_ok=True)

    K, dcs = vmesh.load(path)
    sk = K['DATA'].get('m_modelSkeleton') or {}
    names = list(sk.get('m_boneName', []))
    if names:
        parents = list(sk['m_nParent'])
        bP = np.array([np.array(p, float) for p in sk['m_bonePosParent']])
        bQ = np.array([np.array(q, float) for q in sk['m_boneRotParent']])
    else:
        names, parents, bP, bQ = ['root'], [-1], np.zeros((1, 3)), np.array([[0, 0, 0, 1.0]])
    N = len(names)

    def nodes():
        return ['version 1', 'nodes'] + ['%d "%s" %d' % (i, n, parents[i]) for i, n in enumerate(names)] + ['end']

    def frame(t, P, Q):
        out_ = ['time %d' % t]
        for i in range(N):
            x, y, z = euler(Q[i])
            out_.append('%d %s %s %s %s %s %s' % (i, f6(P[i][0]), f6(P[i][1]), f6(P[i][2]), f6(x), f6(y), f6(z)))
        return out_

    # materials
    matnames = {}
    for dc in dcs:
        if dc['material'] not in matnames:
            matnames[dc['material']] = convert_material(root, dc['material'], content, matdir)[0]

    # reference meshes (one SMD per ~18k triangles)
    refs, cur, count = [], [], 0
    allpos = []

    def flush():
        if not cur:
            return
        fn = 'ref_%02d.smd' % len(refs)
        open(os.path.join(out, fn), 'w').write('\n'.join(nodes() + ['skeleton'] + frame(0, bP, bQ) + ['end', 'triangles'] + cur + ['end']) + '\n')
        refs.append(fn)

    for dc in dcs:
        P, Nn, UV, T, B, W = dc['pos'], dc['nrm'], dc['uv'], dc['tri'], dc['bones'], dc['weights']
        allpos.append(P)
        mname = matnames[dc['material']]
        for t in T:
            if count >= 18000:
                flush()
                cur, count = [], 0
            cur.append(mname)
            for v in t:
                order = np.argsort(-W[v])[:3]
                ws = W[v][order]
                keep = ws > 0.001
                if not keep.any():
                    keep[0] = True
                    ws = np.array([1.0, 0, 0])
                bb, ww = B[v][order][keep], ws[keep] / ws[keep].sum()
                links = ' '.join('%d %.5f' % (int(bi), float(x)) for bi, x in zip(bb, ww))
                p, n, uv = P[v], Nn[v], UV[v]
                cur.append('%d %s %s %s %s %s %s %s %s %d %s' % (int(bb[0]), f6(p[0]), f6(p[1]), f6(p[2]), f6(n[0]), f6(n[1]), f6(n[2]),
                                                                f6(uv[0]), f6(1.0 - uv[1]), len(bb), links))
            count += 1
    flush()

    # collision: a box around the bind pose
    allp = np.concatenate(allpos)
    lo, hi = allp.min(0), allp.max(0)
    c = [[lo[0], lo[1], lo[2]], [hi[0], lo[1], lo[2]], [hi[0], hi[1], lo[2]], [lo[0], hi[1], lo[2]],
         [lo[0], lo[1], hi[2]], [hi[0], lo[1], hi[2]], [hi[0], hi[1], hi[2]], [lo[0], hi[1], hi[2]]]
    faces = [(0, 2, 1), (0, 3, 2), (4, 5, 6), (4, 6, 7), (0, 1, 5), (0, 5, 4), (1, 2, 6), (1, 6, 5), (2, 3, 7), (2, 7, 6), (3, 0, 4), (3, 4, 7)]
    Lp = nodes() + ['skeleton'] + frame(0, bP, bQ) + ['end', 'triangles']
    for f in faces:
        a, b_, cc = [np.array(c[i]) for i in f]
        n = np.cross(b_ - a, cc - a)
        n /= np.linalg.norm(n) or 1
        Lp.append('phys')
        for p in (a, b_, cc):
            Lp.append('0 %s %s %s %s %s %s 0 0 1 0 1' % (f6(p[0]), f6(p[1]), f6(p[2]), f6(n[0]), f6(n[1]), f6(n[2])))
    Lp.append('end')
    open(os.path.join(out, 'phys.smd'), 'w').write('\n'.join(Lp) + '\n')

    # animations
    seqs = []
    if 'ANIM' in K and 'AGRP' in K and len(names) > 1:
        _n, _p, _bp, _bq, anims = build(K)
        for an, a in anims.items():
            seq = an.lstrip('@')
            if 'delta' in seq or 'overlay' in seq:
                continue
            fn = seq.replace('/', '_')
            Ls = nodes() + ['skeleton']
            for f in range(len(a['P'])):
                Ls += frame(f, a['P'][f], a['Q'][f])
            Ls.append('end')
            open(os.path.join(out, 'anims', fn + '.smd'), 'w').write('\n'.join(Ls) + '\n')
            seqs.append((seq, fn, max(1, int(round(a['fps']))), bool(a['loop']), len(a['P'])))

    # attachments
    att = []
    for a in K['MDAT'].get('m_attachments', []):
        v = a['value']
        bone = (v.get('m_influenceNames') or [''])[0] or names[0]
        o = v['m_vInfluenceOffsets'][0]
        p_, y_, r_ = qangle(v['m_vInfluenceRotations'][0])
        att.append('$attachment "%s" "%s" %.4f %.4f %.4f rotate %.3f %.3f %.3f' % (a['key'], bone, o[0], o[1], o[2], p_, y_, r_))

    qc = ['// %s, converted from Half-Life: Alyx (tools/hla_convert/vmdl_to_qc.py)' % os.path.basename(path),
          '$modelname "%s"' % mdlpath, '$cdmaterials "%s/"' % matdir, '$surfaceprop "metal"', '']
    if static:
        qc.insert(3, '$staticprop')
    for i, fn in enumerate(refs):
        qc.append('$model "part%02d" "%s"' % (i, fn))
    qc += [''] + att + ['', '$collisionmodel "phys.smd"', '{', '\t$mass %.1f' % mass, '\t$concave' if False else '', '}', '']
    if not seqs:
        qc.append('$sequence "idle" "%s" fps 30' % refs[0])
    for seq, fn, fps, loop, nf in seqs:
        qc.append('$sequence "%s" "anims/%s.smd" fps %d%s' % (seq, fn, fps, ' loop' if loop else ''))
    open(os.path.join(out, name + '.qc'), 'w').write('\n'.join(q for q in qc if q is not None) + '\n')
    print('%s: %d bones, %d triangles in %d parts, %d sequences, %d attachments, %d materials' % (
        name, N, sum(len(d['tri']) for d in dcs), len(refs), len(seqs), len(att), len(matnames)))
    for seq, fn, fps, loop, nf in seqs:
        print('   %-40s %3d frames @%d%s' % (seq, nf, fps, ' loop' if loop else ''))


if __name__ == '__main__':
    if len(sys.argv) < 6:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1:])
