"""Minimal Source MDL v48 + VVD + VTX reader (LOD0 only). Returns per-mesh triangle lists."""
import struct, os

def _s(d, off):
    return d[off:d.index(b'\0', off)].decode('latin1')

def load(mdl_path):
    base = mdl_path[:-4]
    d = open(mdl_path, 'rb').read()
    h = struct.unpack_from('<40i', d, 152)
    ntex, texi = h[13], h[14]
    nbp, bpi = h[20], h[21]
    textures = []
    for i in range(ntex):
        o = texi + i * 64
        ni, = struct.unpack_from('<i', d, o)
        textures.append(_s(d, o + ni))
    skin_i = h[19]
    nskinref = h[17]
    skins = list(struct.unpack_from('<%dh' % nskinref, d, skin_i))

    vvd = open(base + '.vvd', 'rb').read()
    (ident, ver, chk, nlods) = struct.unpack_from('<4sii i', vvd, 0)
    lodverts = struct.unpack_from('<8i', vvd, 16)
    nfix, fixstart, vstart, tstart = struct.unpack_from('<4i', vvd, 48)
    raw = []
    for i in range(lodverts[0]):
        o = vstart + i * 48
        pos = struct.unpack_from('<3f', vvd, o + 16)
        nrm = struct.unpack_from('<3f', vvd, o + 28)
        uv = struct.unpack_from('<2f', vvd, o + 40)
        raw.append((pos, nrm, uv))
    if nfix:
        verts = []
        for i in range(nfix):
            lod, src, num = struct.unpack_from('<3i', vvd, fixstart + i * 12)
            if lod >= 0:
                verts.extend(raw[src:src + num])
    else:
        verts = raw

    vtxp = base + '.dx90.vtx'
    x = open(vtxp, 'rb').read()
    (_v, _vc, _mbs, _mbt, _mbv, _chk, _nl, _mro, xnbp, xbpo) = struct.unpack_from('<iiHHiiiiii', x, 0)

    meshes = []  # list of dict(bodypart, model, material, tris=[(v0,v1,v2)])
    for b in range(nbp):
        bo = bpi + b * 16
        bni, nm, _base, mi = struct.unpack_from('<4i', d, bo)
        bname = _s(d, bo + bni)
        xbo = xbpo + b * 8
        xnm, xmo = struct.unpack_from('<2i', x, xbo)
        for m in range(nm):
            mo = bo + mi + m * 148
            mname = d[mo:mo + 64].split(b'\0')[0].decode('latin1')
            _typ, _rad, nmesh, meshi, nv, vindex = struct.unpack_from('<ifiiii', d, mo + 64)
            model_vbase = vindex // 48
            xm = xbo + xmo + m * 8
            xnlod, xlodo = struct.unpack_from('<2i', x, xm)
            xl = xm + xlodo  # LOD0
            xnmesh, xmesho = struct.unpack_from('<2i', x, xl)
            for k in range(nmesh):
                mso = mo + meshi + k * 116
                mat, _mi, mnv, mvoff = struct.unpack_from('<4i', d, mso)
                xms = xl + xmesho + k * 9
                nsg, sgo = struct.unpack_from('<2i', x, xms)
                tris = []
                for g in range(nsg):
                    sg = xms + sgo + g * 25
                    nverts, vo, nind, io, nstr, so = struct.unpack_from('<6i', x, sg)
                    vmap = []
                    for vi in range(nverts):
                        orig, = struct.unpack_from('<H', x, sg + vo + vi * 9 + 4)
                        vmap.append(model_vbase + mvoff + orig)
                    idx = struct.unpack_from('<%dH' % nind, x, sg + io)
                    for t in range(0, nind, 3):
                        tris.append((vmap[idx[t]], vmap[idx[t + 1]], vmap[idx[t + 2]]))
                meshes.append(dict(bodypart=bname, model=mname, material=textures[skins[mat]] if mat < len(skins) else str(mat), tris=tris))
    return dict(verts=verts, meshes=meshes, textures=textures)

if __name__ == '__main__':
    import sys
    r = load(sys.argv[1])
    print('verts', len(r['verts']))
    for m in r['meshes']:
        print(m['bodypart'], m['model'], m['material'], len(m['tris']))
