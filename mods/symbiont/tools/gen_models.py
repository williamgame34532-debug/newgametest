#!/usr/bin/env python3
"""Generates GeneratedModels.java + per-form entity textures from creatures.py.

Run from anywhere:  python3 mods/symbiont/tools/gen_models.py
Every box gets its own UV island; the painter paints each of the 6 faces of
each box (top, bottom, sides, front, back) with shading, outlines and the
material pattern, so the texture always matches the model's texOffs layout.
"""
import colorsys
import math
import os
import random
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import creatures  # noqa: E402

ROOT = os.path.dirname(HERE)
TEX_DIR = os.path.join(ROOT, "src/main/resources/assets/symbiont/textures/entity")
JAVA_OUT = os.path.join(ROOT, "src/main/java/com/williamgame/symbiont/client/model/GeneratedModels.java")


# ------------------------------------------------------------------ colour helpers
def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(round(v))))


def tone(rgb, k):
    """k in roughly [-3, 3]: negative = darker + cooler/more saturated, positive = lighter + warmer."""
    r, g, b = [c / 255.0 for c in rgb]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if k < 0:
        v = v * (1 + 0.13 * k)
        s = min(1.0, s * (1 - 0.05 * k))
        h = (h + 0.012 * k) % 1.0  # hue shift for shadows
    else:
        v = min(1.0, v + (1 - v) * 0.16 * k + 0.035 * k)
        s = s * (1 - 0.07 * k)
        h = (h - 0.006 * k) % 1.0
    r, g, b = colorsys.hsv_to_rgb(h, max(0, s), max(0, v))
    return (clamp(r * 255), clamp(g * 255), clamp(b * 255))


def mix(a, b, t):
    return tuple(clamp(a[i] * (1 - t) + b[i] * t) for i in range(3))


# ------------------------------------------------------------------ UV packing
def footprint(b):
    return (2 * b.d + 2 * b.w, b.d + b.h)


def pack(creature):
    boxes = [b for p in creature.parts for b in p.boxes]
    best = None
    for W in (32, 64, 128, 256):
        if any(max(1, footprint(b)[0]) > W for b in boxes):
            continue
        order = sorted(boxes, key=lambda b: (-footprint(b)[1], -footprint(b)[0]))
        x = y = shelf = 0
        placed = []
        for b in order:
            fw, fh = footprint(b)
            fw, fh = max(fw, 1), max(fh, 1)
            if x + fw > W:
                x = 0
                y += shelf
                shelf = 0
            placed.append((b, x, y))
            x += fw
            shelf = max(shelf, fh)
        used_h = y + shelf
        H = 16
        while H < used_h:
            H *= 2
        if H > 256:
            continue
        score = (W * H, abs(W - H))
        if best is None or score < best[0]:
            best = (score, W, H, placed)
    _, W, H, placed = best
    for b, u, v in placed:
        b.u, b.v = u, v
    return W, H


# ------------------------------------------------------------------ painting
FACE_LIGHT = {"top": 1, "front": 0, "right": -0.5, "left": -0.5, "back": -1, "bottom": -2}


def face_rects(b):
    u, v, w, h, d = b.u, b.v, b.w, b.h, b.d
    return {
        "top": (u + d, v, w, d),
        "bottom": (u + d + w, v, w, d),
        "right": (u, v + d, d, h),
        "front": (u + d, v + d, w, h),
        "left": (u + d + w, v + d, d, h),
        "back": (u + d + w + d, v + d, w, h),
    }


class Painter:
    def __init__(self, W, H, seed):
        self.img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.rng = random.Random(seed)

    def put(self, x, y, rgb, glow=False):
        if 0 <= x < self.img.width and 0 <= y < self.img.height:
            self.img.putpixel((x, y), rgb + (255,))
            if glow:
                self.glow.putpixel((x, y), rgb + (255,))

    def paint_box(self, b, m):
        base = hex2rgb(m["base"])
        sec = hex2rgb(m["sec"])
        kind = m["kind"]
        rects = face_rects(b)
        spots = []
        nspots = m.get("spots", 3)
        if kind in ("skin", "face", "fur") and nspots:
            area = (b.w * b.h + b.w * b.d + b.h * b.d)
            for _ in range(max(1, int(nspots * area / 40.0))):
                spots.append((self.rng.choice(["top", "front", "left", "right", "back"]),
                              self.rng.random(), self.rng.random(), self.rng.choice([1, 1, 2])))
        for fname, (fx, fy, fw, fh) in rects.items():
            if fw <= 0 or fh <= 0:
                continue
            light = FACE_LIGHT[fname]
            for j in range(fh):
                for i in range(fw):
                    col, glow = self.pixel(kind, m, base, sec, fname, i, j, fw, fh, light, b, spots)
                    self.put(fx + i, fy + j, col, glow)
            if kind == "face" and fname == "front":
                self.face_features(m, base, fx, fy, fw, fh)
            if kind == "eye" and fname == "front":
                self.eye_front(m, base, sec, fx, fy, fw, fh)

    # pattern per material kind ---------------------------------------
    def pixel(self, kind, m, base, sec, fname, i, j, fw, fh, light, b, spots):
        rng = self.rng
        glow = bool(m.get("glow"))
        edge = (i == 0 or j == 0 or i == fw - 1 or j == fh - 1) and fw >= 3 and fh >= 3
        vert = 0.0 if fh <= 1 else (j / (fh - 1))  # 0 top .. 1 bottom
        k = light
        if fname not in ("top", "bottom"):
            k += 0.8 - 1.4 * vert
        if kind in ("skin", "face", "fur"):
            if kind == "face" and m.get("kind2") == "rock":
                return self.pixel("rock", m, base, sec, fname, i, j, fw, fh, light, b, spots)
            k += rng.choice([0, 0, 0, 0.35, -0.35])
            if kind == "fur":
                k += 0.6 if (i + (j // 2)) % 3 == 0 else (-0.4 if (i * 7 + j) % 5 == 0 else 0)
            col = tone(base, k)
            for (sf, sx, sy, sr) in spots:
                if sf == fname:
                    cx, cy = sx * (fw - 1), sy * (fh - 1)
                    if abs(i - cx) + abs(j - cy) < sr:
                        col = tone(sec, k * 0.6)
                        if m.get("spot_glow"):
                            return col, True
            if fname == "bottom":
                col = mix(col, tone(base, 2), 0.25)
            if edge:
                col = tone(col, -0.9)
            return col, glow
        if kind == "rock":
            n = rng.random()
            k += -0.7 if n < 0.08 else (0.6 if n > 0.93 else 0)
            k += 0.35 if ((i // 2) + (j // 3)) % 3 == 0 else 0
            col = tone(base, k)
            if (i * 3 + j * 5) % 13 == 0:
                col = mix(col, tone(sec, k), 0.6)
            if (i + 2 * j) % 11 == 0 and rng.random() < 0.3:
                col = tone(sec, -1.4)
            if edge:
                col = tone(col, -1)
            return col, glow
        if kind == "shell":
            band = j % 3
            k += {0: 1.0, 1: 0.0, 2: -0.9}[band] if fname not in ("top", "bottom") else (0.4 if i % 3 == 0 else 0)
            k += rng.choice([0, 0, 0.3, -0.3])
            col = tone(base, k)
            if rng.random() < 0.08:
                col = tone(sec, k)
            if edge:
                col = tone(col, -1.1)
            return col, glow
        if kind == "armor":
            col = tone(base, k + (0.8 if j == 0 else 0) + rng.choice([0, 0, 0.2, -0.2]))
            if m.get("rivet") and fw >= 4 and fh >= 3 and (i in (1, fw - 2)) and (j in (1, fh - 2)):
                return hex2rgb(m["rivet"]), True
            if edge:
                col = tone(sec, k - 0.5)
            return col, glow
        if kind == "crystal":
            stripe = ((i + j) // 2) % 3
            col = tone(base, k + [1.4, 0.2, -0.9][stripe])
            if (i + j) % 5 == 0:
                col = mix(col, sec, 0.6)
            if i == 1 and j == 1 or (fw <= 2 and j == 0 and i == 0):
                col = sec
            if edge:
                col = tone(col, -0.7)
            return col, True if glow else False
        if kind == "core":
            cx, cy = (fw - 1) / 2.0, (fh - 1) / 2.0
            r = math.hypot(i - cx, j - cy) / max(1.0, max(cx, cy) + 0.5)
            col = mix(sec, base, min(1, r * 1.3))
            if r > 0.85:
                col = tone(base, -1.2)
            return col, glow
        if kind == "eye":
            col = tone(base, (light * 0.3) + (0.3 if j == 0 else 0))
            return col, glow and m.get("dark", False)
        if kind == "bone":
            t = vert if fname not in ("top", "bottom") else 0.5
            col = mix(tone(base, k * 0.5 + 0.6), tone(sec, -0.5), t)
            if j % 3 == 2 and fh > 3:
                col = tone(col, -0.8)
            if edge:
                col = tone(col, -0.8)
            return col, glow
        if kind == "blade":
            hi = (i == 0) or (j == 0)
            col = tone(base, k + (2.0 if hi else 0) - (1.2 if i == fw - 1 else 0))
            col = mix(col, sec, 0.35 * vert)
            return col, glow
        if kind == "leaf":
            long_axis_h = fh >= fw
            mid = (fw // 2 == i) if long_axis_h else (fh // 2 == j)
            col = tone(base, k + rng.choice([0, 0, 0.3, -0.3]))
            if mid:
                col = mix(col, sec, 0.65)
            elif (i + j) % 4 == 0:
                col = mix(col, sec, 0.25)
            if edge:
                col = tone(col, -1.0)
            return col, glow
        if kind == "petal":
            cx, cy = (fw - 1) / 2.0, (fh - 1) / 2.0
            r = math.hypot(i - cx, j - cy) / max(1.0, max(cx, cy))
            col = mix(sec, base, min(1.0, 0.25 + r))
            col = tone(col, light * 0.5)
            if edge:
                col = tone(col, -0.6)
            return col, glow
        if kind == "wood":
            col = tone(base, k + (0.7 if i % 3 == 0 else (-0.5 if i % 3 == 2 else 0)))
            if rng.random() < 0.07:
                col = tone(sec, -1)
            if edge:
                col = tone(col, -0.8)
            return col, glow
        if kind == "moss":
            n = rng.random()
            col = tone(base, k + (1.2 if n > 0.82 else (-1.0 if n < 0.18 else 0)))
            if n < 0.08:
                col = tone(sec, -0.5)
            if fname == "top" and rng.random() < 0.05:
                col = rng.choice([(255, 170, 205), (255, 230, 110), (240, 240, 255)])
            if edge and fname != "top":
                col = tone(col, -0.9)
            return col, glow
        if kind == "membrane":
            col = mix(tone(base, k * 0.6 + 0.5), sec, 0.15 * (1 - vert))
            if fname in ("top", "bottom"):
                if (i % 4 == 0) or ((i + j) % 7 == 0):
                    col = tone(base, -1.4)
                elif (i + 2 * j) % 9 == 1:
                    col = mix(col, (255, 255, 255), 0.35)
            if edge:
                col = tone(base, -1.8)
            return col, glow
        return tone(base, k), glow

    def face_features(self, m, base, fx, fy, fw, fh):
        mouth = m.get("mouth", "smile")
        dark = tone(hex2rgb(m["sec"]), -2.6)
        cx = fx + fw // 2
        my = fy + int(fh * 0.72)
        if mouth == "smile" and fw >= 4:
            self.put(cx - 2, my - 1, dark)
            self.put(cx - 1, my, dark)
            self.put(cx, my, dark)
            self.put(cx + 1, my - 1, dark)
            if fw % 2 == 1:
                self.put(cx, my, dark)
        elif mouth == "fangs" and fw >= 5:
            for x in range(cx - 2, cx + 2):
                self.put(x, my, dark)
            self.put(cx - 2, my + 1, (245, 238, 225))
            self.put(cx + 1, my + 1, (245, 238, 225))
        if m.get("blush") and fw >= 6:
            bl = hex2rgb(m["blush"])
            for x in (fx + 1, fx + fw - 2):
                self.put(x, my - 1, mix(tone(base, 0), bl, 0.75))

    def eye_front(self, m, base, sec, fx, fy, fw, fh):
        iris = hex2rgb(m.get("iris", m["sec"]))
        pupil = sec
        glow = bool(m.get("glow"))
        if m.get("dark"):
            # dark beady eye with a glowing highlight
            for j in range(fh):
                for i in range(fw):
                    self.put(fx + i, fy + j, tone(base, 0), False)
            self.put(fx, fy, (255, 255, 255), glow)
            if fw >= 2 and fh >= 2:
                self.put(fx + fw - 1, fy + fh - 1, iris, glow)
            return
        if fw == 1 and fh == 1:
            self.put(fx, fy, iris, glow)
            return
        for j in range(fh):
            for i in range(fw):
                lower = j >= fh // 3
                if lower:
                    col = pupil if (j > fh // 2 or fh <= 2) else iris
                    self.put(fx + i, fy + j, col, glow and col == iris)
                else:
                    self.put(fx + i, fy + j, tone(base, 0.5), False)
        # iris ring on the lowest row for big eyes
        if fh >= 3:
            for i in range(fw):
                self.put(fx + i, fy + fh - 1, iris, glow)
        # sparkle
        self.put(fx, fy + max(0, fh // 3), (255, 255, 255), glow)


def paint(creature, W, H):
    P = Painter(W, H, hash(creature.id) & 0xFFFF)
    P.rng.seed(sum(ord(ch) for ch in creature.id) * 7919)
    for part in creature.parts:
        for b in part.boxes:
            P.paint_box(b, creature.mats[b.mat])
    return P.img, P.glow


# ------------------------------------------------------------------ java emission
def jf(v):
    s = ("%.4f" % v).rstrip("0").rstrip(".")
    if s in ("-0", ""):
        s = "0"
    return s + "F"


def jname(n):
    return "p_" + n


def emit_java(results):
    out = []
    out.append("// GENERATED by tools/gen_models.py from tools/creatures.py - do not edit by hand.")
    out.append("package com.williamgame.symbiont.client.model;")
    out.append("")
    out.append("import net.minecraft.client.model.geom.PartPose;")
    out.append("import net.minecraft.client.model.geom.builders.CubeDeformation;")
    out.append("import net.minecraft.client.model.geom.builders.CubeListBuilder;")
    out.append("import net.minecraft.client.model.geom.builders.LayerDefinition;")
    out.append("import net.minecraft.client.model.geom.builders.MeshDefinition;")
    out.append("import net.minecraft.client.model.geom.builders.PartDefinition;")
    out.append("")
    out.append("@SuppressWarnings(\"unused\")")
    out.append("public final class GeneratedModels {")
    out.append("    private GeneratedModels() {}")
    out.append("")
    # dispatcher
    out.append("    public static LayerDefinition create(String form) {")
    out.append("        switch (form) {")
    for c, W, H in results:
        out.append("            case \"%s\": return %s();" % (c.id, c.id))
    out.append("            default: return hatchling();")
    out.append("        }")
    out.append("    }")
    out.append("")
    out.append("    /** Rows: {name, parent ('' = root), role, side, index}. Parents always come before children. */")
    out.append("    public static String[][] parts(String form) {")
    out.append("        switch (form) {")
    for c, W, H in results:
        out.append("            case \"%s\": return PARTS_%s;" % (c.id, c.id.upper()))
    out.append("            default: return PARTS_HATCHLING;")
    out.append("        }")
    out.append("    }")
    out.append("")
    for c, W, H in results:
        out.append("    private static final String[][] PARTS_%s = {" % c.id.upper())
        for p in c.parts:
            out.append("        {\"%s\", \"%s\", \"%s\", \"%d\", \"%d\"}," % (p.name, p.parent or "", p.role, p.side, p.index))
        out.append("    };")
        out.append("")
    for c, W, H in results:
        out.append("    public static LayerDefinition %s() {" % c.id)
        out.append("        MeshDefinition mesh = new MeshDefinition();")
        out.append("        PartDefinition root = mesh.getRoot();")
        for p in c.parts:
            cl = "CubeListBuilder.create()"
            for b in p.boxes:
                cl += ".texOffs(%d, %d)" % (b.u, b.v)
                if b.infl:
                    cl += ".addBox(%s, %s, %s, %s, %s, %s, new CubeDeformation(%s))" % (
                        jf(b.x), jf(b.y), jf(b.z), jf(b.w), jf(b.h), jf(b.d), jf(b.infl))
                else:
                    cl += ".addBox(%s, %s, %s, %s, %s, %s)" % (jf(b.x), jf(b.y), jf(b.z), jf(b.w), jf(b.h), jf(b.d))
            px, py, pz = p.pivot
            rx, ry, rz = p.rot
            pose = "PartPose.offsetAndRotation(%s, %s, %s, %s, %s, %s)" % (jf(px), jf(py), jf(pz), jf(rx), jf(ry), jf(rz))
            parent = "root" if p.parent is None else jname(p.parent)
            out.append("        PartDefinition %s = %s.addOrReplaceChild(\"%s\", %s, %s);" % (jname(p.name), parent, p.name, cl, pose))
        out.append("        return LayerDefinition.create(mesh, %d, %d);" % (W, H))
        out.append("    }")
        out.append("")
    out.append("}")
    return "\n".join(out) + "\n"


def main():
    os.makedirs(TEX_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(JAVA_OUT), exist_ok=True)
    results = []
    for fn in creatures.ALL:
        c = fn()
        W, H = pack(c)
        img, glow = paint(c, W, H)
        img.save(os.path.join(TEX_DIR, c.id + ".png"))
        glow.save(os.path.join(TEX_DIR, c.id + "_glow.png"))
        nboxes = sum(len(p.boxes) for p in c.parts)
        print("%-12s parts=%3d boxes=%3d tex=%dx%d" % (c.id, len(c.parts), nboxes, W, H))
        results.append((c, W, H))
    with open(JAVA_OUT, "w") as f:
        f.write(emit_java(results))
    print("wrote", JAVA_OUT)


if __name__ == "__main__":
    main()
