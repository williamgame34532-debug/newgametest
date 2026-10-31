# Export the HL:A crafting station to Source 1 SMD + QC (studiomdl / Crowbar).
import sys, os, pickle, math
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from skin import load_mesh, globals_, qmat

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'build/modelsrc'
os.makedirs(OUT + '/anims', exist_ok=True)
K = pickle.load(open(ROOT + '/station_kv.pkl', 'rb'))
names, parents, bP, bQ, anims = pickle.load(open(ROOT + '/station_anims.pkl', 'rb'))
mesh = load_mesh(K, ROOT + '/station_mesh.npz')
N = len(names)


def euler_from_quat(q):
    """SMD rotation: M = Rz(z) Ry(y) Rx(x)."""
    M = qmat(q)
    y = math.asin(max(-1.0, min(1.0, -M[2, 0])))
    if abs(M[2, 0]) < 0.999999:
        x = math.atan2(M[2, 1], M[2, 2])
        z = math.atan2(M[1, 0], M[0, 0])
    else:
        x = math.atan2(-M[1, 2], M[1, 1])
        z = 0.0
    return x, y, z


def f6(v):
    return '%.6f' % (0.0 if abs(v) < 5e-7 else v)


def nodes_block():
    out = ['version 1', 'nodes']
    for i, n in enumerate(names):
        out.append('%d "%s" %d' % (i, n, parents[i]))
    out.append('end')
    return out


def frame_lines(t, P, Q):
    out = ['time %d' % t]
    for i in range(N):
        x, y, z = euler_from_quat(Q[i])
        out.append('%d %s %s %s %s %s %s' % (i, f6(P[i][0]), f6(P[i][1]), f6(P[i][2]), f6(x), f6(y), f6(z)))
    return out


def write_anim(name, P, Q):
    L = nodes_block() + ['skeleton']
    for f in range(len(P)):
        L += frame_lines(f, P[f], Q[f])
    L.append('end')
    open(OUT + '/anims/%s.smd' % name, 'w').write('\n'.join(L) + '\n')


# ---- reference meshes, split so each bodypart stays well under the studiomdl vertex limit
pos, nrm, uv, bones, w = mesh['pos'], mesh['nrm'], mesh['uv'], mesh['bones'], mesh['w']


def vert_line(v):
    order = np.argsort(-w[v])[:3]
    ws = w[v][order]
    keep = ws > 0.001
    bb, ww = bones[v][order][keep], ws[keep]
    ww = ww / ww.sum()
    links = ' '.join('%d %.5f' % (int(b), float(x)) for b, x in zip(bb, ww))
    p, n, t = pos[v], nrm[v], uv[v]
    return '%d %s %s %s %s %s %s %s %s %d %s' % (int(bb[0]), f6(p[0]), f6(p[1]), f6(p[2]), f6(n[0]), f6(n[1]), f6(n[2]),
                                               f6(t[0]), f6(1.0 - t[1]), len(bb), links)


parts = []
CHUNK = 18000
for mname, tris in mesh['mats']:
    for s in range(0, len(tris), CHUNK):
        parts.append((mname, tris[s:s + CHUNK]))
ref_names = []
for i, (mname, tris) in enumerate(parts):
    L = nodes_block() + ['skeleton'] + frame_lines(0, bP, bQ) + ['end', 'triangles']
    for t in tris:
        L.append(mname)
        # counter-clockwise as seen from the front, matching the vertex normals (as SMD expects)
        for v in t:
            L.append(vert_line(v))
    L.append('end')
    fn = 'ref_%02d.smd' % i
    open(OUT + '/' + fn, 'w').write('\n'.join(L) + '\n')
    ref_names.append(fn)
    print(fn, mname, len(tris), 'tris', len(np.unique(tris)), 'verts')

# ---- collision: one convex box around the folded hull
lo = pos.min(0) + np.array([3, 2, 0.5]); hi = pos.max(0) - np.array([3, 2, 4])
c = [[lo[0], lo[1], lo[2]], [hi[0], lo[1], lo[2]], [hi[0], hi[1], lo[2]], [lo[0], hi[1], lo[2]],
     [lo[0], lo[1], hi[2]], [hi[0], lo[1], hi[2]], [hi[0], hi[1], hi[2]], [lo[0], hi[1], hi[2]]]
faces = [(0, 2, 1), (0, 3, 2), (4, 5, 6), (4, 6, 7), (0, 1, 5), (0, 5, 4), (1, 2, 6), (1, 6, 5), (2, 3, 7), (2, 7, 6), (3, 0, 4), (3, 4, 7)]
root = names.index('station_root')
L = nodes_block() + ['skeleton'] + frame_lines(0, bP, bQ) + ['end', 'triangles']
for f in faces:
    a, b, cc = [np.array(c[i]) for i in f]
    n = np.cross(b - a, cc - a); n /= np.linalg.norm(n)
    L.append('phys')
    for p in (a, b, cc):
        L.append('%d %s %s %s %s %s %s 0 0 1 %d 1' % (root, f6(p[0]), f6(p[1]), f6(p[2]), f6(n[0]), f6(n[1]), f6(n[2]), root))
L.append('end')
open(OUT + '/phys.smd', 'w').write('\n'.join(L) + '\n')

# ---- animations
A = anims
seqs = []  # (sequence name, smd name, fps, loop, fadein)


def add(seq, P, Q, fps=30, loop=False, fade=0.2):
    write_anim(seq, P, Q)
    seqs.append((seq, seq, fps, loop, fade))


def last(a): return A[a]['P'][-1:], A[a]['Q'][-1:]
def first(a): return A[a]['P'][:1], A[a]['Q'][:1]
def rev(a): return A[a]['P'][::-1], A[a]['Q'][::-1]


add('dormant', *first('dormant'), loop=True)
add('eye_deploy', A['eye_deploy']['P'], A['eye_deploy']['Q'])
add('interface_deploy', A['interface_deploy']['P'], A['interface_deploy']['Q'])
add('menu_idle', *last('interface_deploy'), loop=True)
add('interface_retract', *rev('interface_deploy'))
add('eye_retract', A['eye_retract']['P'], A['eye_retract']['Q'])
add('hatch_open', A['printer_hatch_open']['P'], A['printer_hatch_open']['Q'])
add('hatch_close', *rev('printer_hatch_open'))
add('hatch_idle', *last('printer_hatch_open'), loop=True)
add('tray_deploy', A['@resin_tray_deploy']['P'], A['@resin_tray_deploy']['Q'], fade=0.35)
add('tray_retract', A['@resin_tray_retract']['P'], A['@resin_tray_retract']['Q'])
for k in range(10):
    add('tray_idle_%02d' % k, *first('resin_tray_idle_%02d' % k), loop=True)
for k in range(9):
    a = 'resin_tray_cycler_%02d_to_%02d' % (k, k + 1)
    add('tray_cycle_%02d' % (k + 1), A[a]['P'], A[a]['Q'], fade=0.1)
add('tray_cycle_00', A['resin_tray_cycler_00_to_09']['P'], A['resin_tray_cycler_00_to_09']['Q'], fade=0.1)  # 09 -> 00
add('bay_open', A['@print_bay_open']['P'], A['@print_bay_open']['Q'], fade=0.35)
add('bay_close', *rev('@print_bay_open'))
add('bay_idle', *first('@open_idle'), loop=True)
add('print', A['@print_bay_close_and_print']['P'], A['@print_bay_close_and_print']['Q'], fps=60)
add('print_done', *last('@print_bay_close_and_print'), loop=True)

# ---- attachments
def qangle(q):
    M = qmat(q)
    pitch = math.degrees(math.asin(max(-1, min(1, -M[2, 0]))))
    yaw = math.degrees(math.atan2(M[1, 0], M[0, 0]))
    roll = math.degrees(math.atan2(M[2, 1], M[2, 2]))
    return pitch, yaw, roll


att = []
for a in K['MDAT']['m_attachments']:
    v = a['value']
    bone = v['m_influenceNames'][0] or 'station_root'
    o = v['m_vInfluenceOffsets'][0]
    p, y, r = qangle(v['m_vInfluenceRotations'][0])
    att.append('$attachment "%s" "%s" %.4f %.4f %.4f rotate %.3f %.3f %.3f' % (a['key'], bone, o[0], o[1], o[2], p, y, r))

qc = ['// Combine fabricator from Half-Life: Alyx, converted for Garry\'s Mod (skeleton and animations kept).',
      '$modelname "cf_rework/hla_station.mdl"',
      '$cdmaterials "models/cf_rework/hla/"',
      '$surfaceprop "metal"', '$contents "solid"', '$illumposition 0 0 30', '']
for i, fn in enumerate(ref_names):
    qc.append('$model "part%02d" "%s"' % (i, fn))
qc += [''] + att + ['', '$collisionmodel "phys.smd"', '{', '\t$mass 400', '}', '']
for seq, fn, fps, loop, fade in seqs:
    qc.append('$sequence "%s" "anims/%s.smd" fps %d%s fadein %.2f fadeout %.2f' % (seq, fn, fps, ' loop' if loop else '', fade, fade))
open(OUT + '/hla_station.qc', 'w').write('\n'.join(qc) + '\n')
print(len(seqs), 'sequences,', len(att), 'attachments')
