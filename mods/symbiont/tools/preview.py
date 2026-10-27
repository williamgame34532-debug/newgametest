#!/usr/bin/env python3
"""Software preview of the generated creatures (same cube UV mapping and part transform
order as Minecraft's ModelPart: translate(pivot) then rotationZYX(z, y, x)).

    python3 tools/preview.py out.png
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import creatures  # noqa: E402
import gen_models  # noqa: E402


def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def trans(x, y, z):
    return [[1, 0, 0, x], [0, 1, 0, y], [0, 0, 1, z], [0, 0, 0, 1]]


def rx(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0, 0], [0, c, -s, 0], [0, s, c, 0], [0, 0, 0, 1]]


def ry(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s, 0], [0, 1, 0, 0], [-s, 0, c, 0], [0, 0, 0, 1]]


def rz(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0, 0], [s, c, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]


def apply(m, p):
    x, y, z = p
    return tuple(m[i][0] * x + m[i][1] * y + m[i][2] * z + m[i][3] for i in range(3))


def box_quads(b):
    x0, y0, z0 = b.x - b.infl, b.y - b.infl, b.z - b.infl
    x1, y1, z1 = b.x + b.w + b.infl, b.y + b.h + b.infl, b.z + b.d + b.infl
    v = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    u, vv, w, h, d = b.u, b.v, b.w, b.h, b.d
    u0, u1, u2, u3, u4, u5 = u, u + d, u + d + w, u + d + w + w, u + d + w + d, u + d + w + d + w
    v0, v1, v2 = vv, vv + d, vv + d + h
    return [
        ([v[5], v[4], v[0], v[1]], (u1, v0, u2, v1)),
        ([v[2], v[3], v[7], v[6]], (u2, v1, u3, v0)),
        ([v[0], v[4], v[7], v[3]], (u0, v1, u1, v2)),
        ([v[1], v[0], v[3], v[2]], (u1, v1, u2, v2)),
        ([v[5], v[1], v[2], v[6]], (u2, v1, u4, v2)),
        ([v[4], v[5], v[6], v[7]], (u4, v1, u5, v2)),
    ]


def render(c, tex, yaw, pitch, size=360, scale=7.0):
    mats = {}
    parts = {p.name: p for p in c.parts}

    def world(p):
        if p.name in mats:
            return mats[p.name]
        m = trans(*p.pivot)
        m = matmul(m, matmul(rz(p.rot[2]), matmul(ry(p.rot[1]), rx(p.rot[0]))))
        if p.parent:
            m = matmul(world(parts[p.parent]), m)
        mats[p.name] = m
        return m

    view = matmul(rx(pitch), ry(yaw))
    tris = []
    W, H = tex.size
    px = tex.load()
    for p in c.parts:
        m = matmul(view, world(p))
        for b in p.boxes:
            for verts, (ua, va, ub, vb) in box_quads(b):
                V = [apply(m, q) for q in verts]
                # position(u,v) = V1 + (V0-V1)*(u-ua)/(ub-ua) + (V2-V1)*(v-va)/(vb-va)
                du, dv = ub - ua, vb - va
                if du == 0 or dv == 0:
                    continue
                e1 = [V[0][i] - V[1][i] for i in range(3)]
                e2 = [V[2][i] - V[1][i] for i in range(3)]
                nz = e1[0] * e2[1] - e1[1] * e2[0]
                for tu in range(int(min(ua, ub)), int(max(ua, ub))):
                    for tv in range(int(min(va, vb)), int(max(va, vb))):
                        if not (0 <= tu < W and 0 <= tv < H):
                            continue
                        col = px[tu, tv]
                        if col[3] == 0:
                            continue
                        cs = []
                        for (uu, vv2) in ((tu, tv), (tu + 1, tv), (tu + 1, tv + 1), (tu, tv + 1)):
                            a, bb = (uu - ua) / du, (vv2 - va) / dv
                            cs.append(tuple(V[1][i] + e1[i] * a + e2[i] * bb for i in range(3)))
                        z = sum(q[2] for q in cs) / 4
                        tris.append((z, cs, col, nz))
    img = Image.new("RGBA", (size, size), (40, 44, 52, 255))
    d = ImageDraw.Draw(img)
    tris.sort(key=lambda t: -t[0])
    cx, cy = size / 2, size * 0.25
    for z, cs, col, nz in tris:
        shade = 1.0
        d.polygon([(cx + q[0] * scale, cy + q[1] * scale) for q in cs], fill=(int(col[0] * shade), int(col[1] * shade), int(col[2] * shade), 255))
    # ground line (model y=24 before rotation is approximate after pitch)
    return img


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "preview.png"
    rows = []
    for fn in creatures.ALL:
        c = fn()
        gen_models.pack(c)
        tex = Image.open(os.path.join(gen_models.TEX_DIR, c.id + ".png")).convert("RGBA")
        views = [render(c, tex, math.radians(a), math.radians(p)) for a, p in ((30, -20), (90, 0), (200, -25))]
        row = Image.new("RGBA", (360 * 3, 360))
        for i, v in enumerate(views):
            row.paste(v, (360 * i, 0))
        ImageDraw.Draw(row).text((5, 5), c.id, fill=(255, 255, 255, 255))
        rows.append(row)
    sheet = Image.new("RGBA", (360 * 3, 360 * len(rows)))
    for i, r in enumerate(rows):
        sheet.paste(r, (0, 360 * i))
    sheet.save(out)
    print("saved", out)


if __name__ == "__main__":
    main()
