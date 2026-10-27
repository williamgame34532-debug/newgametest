"""Creature geometry for the Symbiont mod.

Every form is described here once.  gen_models.py turns these descriptions into
  * src/main/java/com/williamgame/symbiont/client/model/GeneratedModels.java  (LayerDefinitions + part tables)
  * src/main/resources/assets/symbiont/textures/entity/<form>.png             (painted per UV box)
  * src/main/resources/assets/symbiont/textures/entity/<form>_glow.png        (emissive layer)

Coordinates are Minecraft model units (1/16 block), Y points DOWN, the ground is y=24.
The front of a creature faces -Z.  "_l" parts sit on +X, "_r" parts on -X.

Roles drive the procedural animation in SymbiontModel.java:
  body, body2, neck, head, jaw, eye, ear, antenna, leg, shin, arm, fore, wing, wing2,
  tail, tentacle, crystal, leaf, fin, orb, shell, static
"""
import math

PI = math.pi


class Box:
    def __init__(self, x, y, z, w, h, d, mat, infl=0.0):
        self.x, self.y, self.z = x, y, z
        self.w, self.h, self.d = int(w), int(h), int(d)
        assert self.w == w and self.h == h and self.d == d, "box sizes must be integers"
        self.mat = mat
        self.infl = infl
        self.u = self.v = 0


class Part:
    def __init__(self, name, parent, pivot, rot, role, side, index, boxes):
        self.name, self.parent = name, parent
        self.pivot, self.rot = pivot, rot
        self.role, self.side, self.index = role, side, index
        self.boxes = boxes


class Creature:
    def __init__(self, fid, mats):
        self.id = fid
        self.mats = mats
        self.parts = []
        self.names = set()

    def p(self, name, parent=None, pivot=(0, 0, 0), rot=(0, 0, 0), role="static", side=0, index=0, boxes=()):
        if isinstance(side, (list, tuple)):
            boxes, side, index = side, 0, 0
        elif isinstance(index, (list, tuple)):
            boxes, index = index, 0
        assert name not in self.names, name
        self.names.add(name)
        if parent is not None:
            assert parent in self.names, (name, parent)
        self.parts.append(Part(name, parent, pivot, rot, role, side, index, [Box(*b) for b in boxes]))
        return name

    def sym(self, name, parent, pivot, rot, role, index, boxes, mirror_parent=True):
        """Create a left (+X) and right (-X) copy.  `boxes` are given for the LEFT side."""
        for s, suf in ((1, "_l"), (-1, "_r")):
            px, py, pz = pivot
            rx, ry, rz = rot
            bb = []
            for (x, y, z, w, h, d, m, *rest) in boxes:
                if s > 0:
                    bb.append((x, y, z, w, h, d, m, *rest))
                else:
                    bb.append((-x - w, y, z, w, h, d, m, *rest))
            par = parent
            if parent is not None and mirror_parent and parent.endswith("$"):
                par = parent[:-1] + suf
            self.p(name + suf, par, (px * s, py, pz), (rx, ry * s, rz * s), role, s, index, bb)


def mat(kind, base, sec=None, glow=False, **kw):
    d = dict(kind=kind, base=base, sec=sec or base, glow=glow)
    d.update(kw)
    return d


# ---------------------------------------------------------------- Hatchling
def hatchling():
    c = Creature("hatchling", {
        "skin": mat("skin", "#b9a3e3", "#7fd6c9"),
        "face": mat("face", "#b9a3e3", "#7fd6c9", mouth="smile", blush="#f2a7c9"),
        "belly": mat("skin", "#ece2fb", "#d8c9f4", spots=0),
        "eye": mat("eye", "#f6f2ff", "#2a1840", iris="#6a4fc0"),
        "stalk": mat("skin", "#9b84d0", "#8a72bf", spots=0),
        "bulb": mat("core", "#7ff0e0", "#e8fffb", glow=True),
        "foot": mat("skin", "#8a72bf", "#6f59a6", spots=0),
        "shellbit": mat("shell", "#f3ead8", "#d6c7a8"),
    })
    c.p("body", None, (0, 23, 0), role="body", boxes=[
        (-3.5, -7, -3.5, 7, 7, 7, "face"),
        (-2.5, -3.5, -3.8, 5, 3, 1, "belly"),
        (-1.5, -8, -1.5, 3, 1, 3, "skin"),
    ])
    c.p("eggcap", "body", (0, -8, 0), (0.15, 0, -0.2), "shell", boxes=[(-2, -1, -2, 4, 1, 4, "shellbit")])
    c.sym("eye", "body", (1.7, -4.6, -3.4), (0, 0, 0), "eye", 0, [(-1, -1.5, -0.6, 2, 3, 1, "eye")])
    c.sym("antenna", "body", (1.5, -7.3, 0), (-0.25, 0, 0.35), "antenna", 0, [(-0.5, -4, -0.5, 1, 4, 1, "stalk")])
    c.sym("bulb", "antenna$", (0, -4, 0), (0, 0, 0), "crystal", 0, [(-1, -2, -1, 2, 2, 2, "bulb")])
    c.sym("leg_f", None, (2, 22, -2), (0, 0, 0), "leg", 0, [(-1, 0, -1.5, 2, 2, 3, "foot")])
    c.sym("leg_b", None, (2, 22, 2), (0, 0, 0), "leg", 2, [(-1, 0, -1.5, 2, 2, 3, "foot")])
    c.p("tail1", "body", (0, -2, 3.3), (0.4, 0, 0), "tail", 0, [(-1, -1, 0, 2, 2, 2, "skin")])
    c.p("tail2", "tail1", (0, 0, 2), (0.3, 0, 0), "tail", 1, [(-0.5, -0.5, 0, 1, 1, 2, "stalk")])
    c.p("tail3", "tail2", (0, 0, 2), (0, 0, 0), "crystal", 1, [(-1, -1, 0, 2, 2, 2, "bulb")])
    return c


# ---------------------------------------------------------------- Miner
def miner1():
    c = Creature("miner_1", {
        "skin": mat("skin", "#c9a27e", "#a07a5a"),
        "face": mat("face", "#c9a27e", "#a07a5a", mouth="smile", blush="#e59a86"),
        "shell": mat("shell", "#7d6b5d", "#5a4a40"),
        "rock": mat("rock", "#8a7a6c", "#5d4f45"),
        "eye": mat("eye", "#fff1c4", "#3b2410", iris="#ff9d2e", glow=True),
        "crystal": mat("crystal", "#ffb347", "#fff0b0", glow=True),
        "claw": mat("bone", "#efe2cc", "#b8a68c"),
        "snout": mat("skin", "#e0b896", "#b98f6c", spots=0),
    })
    c.p("body", None, (0, 20, 0), role="body", boxes=[(-3.5, -3, -4.5, 7, 6, 9, "skin")])
    for i in range(4):
        c.p("shell%d" % i, "body", (0, -2.6, -3.4 + i * 2.3), (0.08 * (i - 1.5), 0, 0), "shell", 0, i,
            [(-4, -1.5, -1.3, 8, 3, 3, "shell")])
    c.p("crystal_0", "shell1", (0, -1.5, 0), (0.25, 0.4, 0.15), "crystal", 0, 0, [(-1, -3, -1, 2, 3, 2, "crystal")])
    c.p("crystal_1", "shell2", (1.6, -1.5, 0.5), (-0.3, 0, 0.45), "crystal", 0, 1, [(-0.5, -2, -0.5, 1, 2, 1, "crystal")])
    c.p("crystal_2", "shell2", (-1.8, -1.4, 0), (0.2, 0, -0.5), "crystal", 0, 2, [(-0.5, -2, -0.5, 1, 2, 1, "crystal")])
    c.p("head", "body", (0, -0.2, -4.4), role="head", boxes=[
        (-2.5, -2.5, -3.5, 5, 4, 4, "face"),
        (-1, -0.5, -5, 2, 2, 2, "snout"),
        (-3, -3, -1.2, 6, 2, 2, "shell"),
    ])
    c.sym("eye", "head", (1.4, -1.2, -3.4), (0, 0, 0), "eye", 0, [(-1, -1, -0.5, 2, 2, 1, "eye")])
    c.sym("ear", "head", (2.3, -2.2, -1.5), (0, 0, 0.5), "ear", 0, [(-0.5, -2, -0.5, 1, 2, 1, "skin")])
    for nm, z, idx in (("leg_f", -3, 0), ("leg_b", 3, 2)):
        c.sym(nm, None, (2.6, 22, z), (0, 0, 0), "leg", idx, [(-1, 0, -1, 2, 2, 2, "skin")])
        c.sym("claw" + nm[3:], nm + "$", (0, 1.5, -1), (0, 0, 0), "static", idx, [(-1, -0.5, -1, 2, 1, 1, "claw")])
    c.p("tail1", "body", (0, 0.5, 4.4), (-0.2, 0, 0), "tail", 0, 0, [(-1.5, -1.5, 0, 3, 3, 2, "shell")])
    c.p("tail2", "tail1", (0, 0, 2), (0.2, 0, 0), "tail", 0, 1, [(-1, -1, 0, 2, 2, 2, "rock")])
    c.p("tail3", "tail2", (0, 0, 2), (0.2, 0, 0), "tail", 0, 2, [(-0.5, -0.5, 0, 1, 1, 2, "crystal")])
    return c


def miner2():
    c = Creature("miner_2", {
        "fur": mat("fur", "#6e5444", "#4c382c"),
        "face": mat("face", "#7d6150", "#5a4334", mouth="none", blush=None),
        "plate": mat("shell", "#857463", "#5b4c40"),
        "crystal": mat("crystal", "#ffa63a", "#fff3b8", glow=True),
        "crystal2": mat("crystal", "#5ad7ff", "#e0fbff", glow=True),
        "claw": mat("bone", "#f0e6d4", "#a8957a"),
        "snout": mat("skin", "#e3a99a", "#c2847a", spots=0),
        "eye": mat("eye", "#1b120c", "#ffb340", iris="#ffcf6a", glow=True, dark=True),
        "skin": mat("skin", "#9b7a63", "#7a5c48"),
    })
    c.p("body", None, (0, 17.5, 0), role="body", boxes=[(-4, -3.5, -6, 8, 7, 12, "fur")])
    for i, z in enumerate((-4, 0, 4)):
        c.p("plate%d" % i, "body", (0, -3.4, z), (0.06 * (i - 1), 0, 0), "shell", 0, i, [(-4.5, -1.5, -1.8, 9, 3, 4, "plate")])
    c.p("crystal_0", "plate0", (0.5, -1.5, 0), (0.3, 0.3, 0.2), "crystal", 0, 0, [(-1, -4, -1, 2, 4, 2, "crystal")])
    c.p("crystal_1", "plate1", (1.8, -1.4, 0.3), (-0.2, 0, 0.5), "crystal", 0, 1, [(-0.5, -3, -0.5, 1, 3, 1, "crystal2")])
    c.p("crystal_2", "plate1", (-1.5, -1.5, -0.4), (0.1, 0.5, -0.35), "crystal", 0, 2, [(-1, -3, -1, 2, 3, 2, "crystal")])
    c.p("crystal_3", "plate2", (0, -1.4, 0.5), (-0.35, 0, 0.1), "crystal", 0, 3, [(-1, -3, -1, 2, 3, 2, "crystal2")])
    c.p("head", "body", (0, -0.5, -6), role="head", boxes=[
        (-3, -3, -4, 6, 5, 4, "face"),
        (-1.5, -1, -6, 3, 3, 2, "snout"),
    ])
    c.sym("eye", "head", (1.9, -1.8, -3.9), (0, 0, 0), "eye", 0, [(-1, -1, -0.5, 2, 2, 1, "eye")])
    c.sym("eyeb", "head", (1.2, -3.2, -3.6), (0, 0, 0), "eye", 1, [(-0.5, -0.5, -0.5, 1, 1, 1, "eye")])
    c.sym("jaw", "head", (1.2, 1.3, -5.5), (0, -0.35, 0), "jaw", 0, [(-0.5, 0, -2.5, 1, 1, 3, "claw")])
    c.sym("antenna", "head", (1.4, -2.8, -2.5), (-0.6, 0, 0.35), "antenna", 0, [(-0.5, -4, -0.5, 1, 4, 1, "skin")])
    c.sym("antip", "antenna$", (0, -4, 0), (0.5, 0, 0), "crystal", 0, [(-0.5, -2, -0.5, 1, 2, 1, "crystal")])
    c.sym("arm", "body", (3.8, 1, -4.4), (-0.35, 0, -0.25), "arm", 0, [(-1, -1, -1.5, 3, 5, 3, "fur")])
    c.sym("fore", "arm$", (0.5, 4, 0), (-0.3, 0, 0), "fore", 0, [(-1.5, 0, -2, 3, 2, 3, "skin")])
    for k in range(3):
        c.sym("dig%d" % k, "fore$", (-1 + k, 2, -1.5), (-0.5, 0, 0), "static", k,
              [(-0.5, 0, -0.5, 1, 3, 1, "claw")])
    for nm, z, idx in (("leg_m", 0.5, 1), ("leg_b", 4.5, 2)):
        c.sym(nm, None, (3.6, 20, z), (0, 0, -0.25), "leg", idx, [(-1, 0, -1, 2, 3, 2, "fur")])
        c.sym("shin" + nm[3:], nm + "$", (0, 3, 0), (0, 0, 0.25), "shin", idx, [(-1, 0, -1.5, 2, 1, 3, "claw")])
    c.p("tail1", "body", (0, -0.5, 6), (-0.25, 0, 0), "tail", 0, 0, [(-1.5, -1.5, 0, 3, 3, 3, "plate")])
    c.p("tail2", "tail1", (0, 0, 3), (0.2, 0, 0), "tail", 0, 1, [(-1, -1, 0, 2, 2, 3, "fur")])
    c.p("tail3", "tail2", (0, 0, 3), (0.2, 0, 0), "tail", 0, 2, [(-1, -1, 0, 2, 2, 2, "crystal")])
    return c


def miner3():
    c = Creature("miner_3", {
        "rock": mat("rock", "#6f6a72", "#45404a"),
        "rock2": mat("rock", "#857c6f", "#5a5148"),
        "belly": mat("skin", "#b49a83", "#957b66", spots=0),
        "face": mat("face", "#7a7480", "#4d4752", mouth="none", blush=None, kind2="rock"),
        "crystal": mat("crystal", "#ff9b2f", "#fff0a8", glow=True),
        "crystal2": mat("crystal", "#b06cff", "#f0dcff", glow=True),
        "crystal3": mat("crystal", "#40e0ff", "#e8ffff", glow=True),
        "core": mat("core", "#ffcc55", "#fffbe0", glow=True),
        "eye": mat("eye", "#200f05", "#ffb030", iris="#ffe07a", glow=True, dark=True),
        "claw": mat("bone", "#e6dccb", "#9d8f7b"),
    })
    c.p("body", None, (0, 13, 0), role="body", boxes=[
        (-6, -5, -8, 12, 10, 16, "rock"),
        (-5, 3.5, -7, 10, 2, 14, "belly"),
    ])
    c.p("core", "body", (0, 0.5, -8), role="crystal", index=5, boxes=[(-2, -2, -1, 4, 4, 1, "core")])
    spots = [(-3, -5, -4, 0.3, 0.2, -0.3, (2, 5, 2), "crystal"), (2.5, -5, -2, -0.2, 0.4, 0.35, (3, 7, 3), "crystal2"),
             (-1, -5, 2, 0.15, 0.8, -0.1, (2, 6, 2), "crystal3"), (3, -5, 4.5, -0.3, 0, 0.4, (2, 4, 2), "crystal"),
             (-3.5, -5, 5.5, 0.35, 0.3, -0.45, (2, 5, 2), "crystal2"), (0.5, -5, -6.5, 0.4, 0, 0.1, (2, 3, 2), "crystal3")]
    for i, (x, y, z, rx, ry, rz, (w, h, d), m) in enumerate(spots):
        c.p("crystal_%d" % i, "body", (x, y, z), (rx, ry, rz), "crystal", 0, i, [(-w / 2, -h, -d / 2, w, h, d, m)])
    c.p("neck", "body", (0, -1, -8), (0.15, 0, 0), "neck", 0, 0, [(-3, -3, -3, 6, 6, 4, "rock2")])
    c.p("head", "neck", (0, 0, -3), role="head", boxes=[
        (-4, -3, -6, 8, 6, 6, "face"),
        (-4.5, -4, -6.5, 9, 2, 3, "rock"),
    ])
    c.p("jaw", "head", (0, 2.5, -1), role="jaw", boxes=[(-3.5, 0, -5, 7, 2, 5, "rock2")])
    c.sym("tusk", "jaw", (2.8, 0, -4.5), (0.6, 0, 0.2), "static", 0, [(-0.5, -3, -0.5, 1, 3, 1, "claw")])
    c.p("horn", "head", (0, -3.5, -4.5), (0.7, 0, 0), "crystal", 0, 6, [(-1, -5, -1, 2, 5, 2, "crystal")])
    c.sym("eye", "head", (2.4, -1.2, -6), (0, 0, 0), "eye", 0, [(-1, -1, -0.5, 2, 2, 1, "eye")])
    c.sym("eyeb", "head", (3.2, 0.8, -5.6), (0, 0, 0), "eye", 1, [(-0.5, -0.5, -0.5, 1, 1, 1, "eye")])
    for nm, x, z, idx in (("leg_f", 4.5, -5, 0), ("leg_b", 4.5, 5, 2)):
        c.sym(nm, None, (x, 17, z), (0, 0, 0), "leg", idx, [(-2, 0, -2, 4, 4, 4, "rock")])
        c.sym("shin" + nm[3:], nm + "$", (0, 4, 0), (0, 0, 0), "shin", idx, [(-2, 0, -2, 4, 3, 4, "rock2")])
        c.sym("toe" + nm[3:], "shin" + nm[3:] + "$", (0, 2, -2), (0, 0, 0), "static", idx,
              [(-2, 0, -1, 1, 1, 1, "claw"), (-0.5, 0, -1, 1, 1, 1, "claw"), (1, 0, -1, 1, 1, 1, "claw")])
    c.p("tail1", "body", (0, -2, 8), (-0.3, 0, 0), "tail", 0, 0, [(-2.5, -2.5, 0, 5, 5, 4, "rock")])
    c.p("tail2", "tail1", (0, 0, 4), (0.2, 0, 0), "tail", 0, 1, [(-2, -2, 0, 4, 4, 4, "rock2")])
    c.p("tail3", "tail2", (0, 0, 4), (0.2, 0, 0), "tail", 0, 2, [(-1.5, -1.5, 0, 3, 3, 3, "rock")])
    c.p("tail4", "tail3", (0, 0, 3), (0.15, 0, 0), "tail", 0, 3, [(-1, -1, 0, 2, 2, 3, "rock2")])
    c.p("crystal_t", "tail4", (0, -0.5, 2), (-0.6, 0, 0), "crystal", 0, 7, [(-1.5, -4, -1.5, 3, 4, 3, "crystal3")])
    return c


# ---------------------------------------------------------------- Warrior
def warrior1():
    c = Creature("warrior_1", {
        "skin": mat("skin", "#b8323a", "#7a1d26", spots=1),
        "face": mat("face", "#c23a40", "#7a1d26", mouth="fangs", blush=None),
        "belly": mat("skin", "#e7766c", "#c95a52", spots=0),
        "dark": mat("armor", "#2f2227", "#191215"),
        "horn": mat("bone", "#f1e4cf", "#9c8a72"),
        "blade": mat("blade", "#d9dde3", "#7d8590"),
        "eye": mat("eye", "#ffe36b", "#1a0a00", iris="#ff7b00", glow=True),
    })
    c.p("body", None, (0, 15, 0), role="body", boxes=[
        (-3, -6, -2, 6, 7, 4, "skin"),
        (-2, -5, -2.5, 4, 5, 1, "belly"),
    ])
    c.p("head", "body", (0, -6, 0), role="head", boxes=[(-3.5, -6, -3.5, 7, 6, 7, "face")])
    c.p("jaw", "head", (0, -0.6, -1), role="jaw", boxes=[(-2.5, 0, -2.6, 5, 1, 3, "dark")])
    c.sym("horn", "head", (2.4, -5.6, 0), (-0.3, 0, 0.45), "static", 0, [(-1, -2, -1, 2, 2, 2, "horn")])
    c.sym("horntip", "horn$", (0, -2, 0), (-0.4, 0, -0.25), "static", 0, [(-0.5, -3, -0.5, 1, 3, 1, "horn")])
    c.sym("ear", "head", (3.4, -3.2, 0), (0, -0.3, 0.3), "ear", 0, [(0, -1, -0.5, 3, 2, 1, "skin")])
    c.sym("eye", "head", (1.6, -3.2, -3.5), (0, 0, 0), "eye", 0, [(-1, -1, -0.5, 2, 2, 1, "eye")])
    for i in range(3):
        c.p("spike_%d" % i, "body", (0, -5 + i * 2, 2), (-0.7, 0, 0), "static", 0, i, [(-0.5, -0.5, 0, 1, 1, 2, "horn")])
    c.sym("arm", "body", (3.4, -5, 0), (0, 0, -0.15), "arm", 0, [(0, -1, -1, 2, 5, 2, "skin")])
    c.sym("fore", "arm$", (1, 5, 0), (-0.25, 0, 0), "fore", 0, [(-1, 0, -1, 2, 3, 2, "dark")])
    c.sym("blade", "fore$", (0, 2.5, 0), (-0.9, 0, 0), "static", 0, [(-0.5, 0, -0.5, 1, 5, 1, "blade")])
    c.sym("leg", None, (1.5, 16, 0), (0, 0, 0), "leg", 0, [(-1, 0, -1, 2, 5, 2, "skin")])
    c.sym("shin", "leg$", (0, 5, 0), (0, 0, 0), "shin", 0, [(-1, 0, -1.5, 2, 3, 3, "dark")])
    c.p("tail1", "body", (0, 0, 2), (0.7, 0, 0), "tail", 0, 0, [(-1, -1, 0, 2, 2, 3, "skin")])
    c.p("tail2", "tail1", (0, 0, 3), (-0.3, 0, 0), "tail", 0, 1, [(-0.5, -0.5, 0, 1, 1, 3, "skin")])
    c.p("tail3", "tail2", (0, 0, 3), (0, 0, 0), "tail", 0, 2, [(-1, -1, 0, 2, 2, 2, "horn")])
    return c


def warrior2():
    c = Creature("warrior_2", {
        "skin": mat("skin", "#9d2430", "#5c121b", spots=1),
        "face": mat("face", "#a62a35", "#5c121b", mouth="none", blush=None),
        "dark": mat("armor", "#2a1d22", "#140d10"),
        "bone": mat("bone", "#efe0c9", "#93806a"),
        "blade": mat("blade", "#e0e4ea", "#717a86"),
        "eye": mat("eye", "#ffe45c", "#250800", iris="#ff5a00", glow=True),
        "mark": mat("core", "#ff4b2b", "#ffd0a0", glow=True),
    })
    c.p("body", None, (0, 13, 0), role="body", boxes=[
        (-4, -4, -7, 8, 8, 14, "skin"),
        (-3.5, 0.5, -7.5, 7, 4, 6, "dark"),
    ])
    c.p("rune", "body", (0, -1, -7.6), role="crystal", index=2, boxes=[(-1, -1, 0, 2, 2, 0, "mark")])
    for i in range(5):
        c.p("spike_%d" % i, "body", (0, -4, -5 + i * 2.6), (-0.6, 0, 0), "static", 0, i,
            [(-0.5, -3 + (i % 2), -0.5, 1, 3 - (i % 2), 2, "bone")])
    c.p("neck", "body", (0, -2, -7), (-0.35, 0, 0), "neck", 0, 0, [(-2.5, -2.5, -4, 5, 5, 4, "skin")])
    c.p("head", "neck", (0, -0.5, -4), (0.35, 0, 0), "head", boxes=[
        (-3.5, -3, -6, 7, 5, 6, "face"),
        (-2.5, -1.5, -9, 5, 3, 3, "skin"),
    ])
    c.p("jaw", "head", (0, 2, -1), role="jaw", boxes=[(-2.5, 0, -7.5, 5, 2, 7, "dark")])
    for i in range(4):
        x = -2 + i * 1.33
        c.p("tooth_%d" % i, "jaw", (x, 0, -7), role="static", index=i, boxes=[(-0.5, -1, -0.5, 1, 1, 1, "bone")])
    c.sym("horn", "head", (2.5, -2.8, -1), (0.55, 0.3, 0), "static", 0, [(-0.5, -0.5, 0, 1, 1, 6, "bone")])
    c.sym("eye", "head", (2, -1.5, -6), (0, 0, 0), "eye", 0, [(-1, -1, -0.5, 2, 2, 1, "eye")])
    c.sym("arm", "body", (4, 1, -5), (0, 0, 0), "arm", 0, [(-1, -1, -1.5, 3, 6, 3, "skin")])
    c.sym("fore", "arm$", (0.5, 5, 0), (0, 0, 0), "fore", 0, [(-1, 0, -1, 2, 5, 2, "dark")])
    c.sym("blade", "fore$", (1, 1, 0), (0.35, 0, 0), "static", 0, [(-0.5, -6, -0.5, 1, 7, 2, "blade")])
    c.sym("leg", None, (3, 16, 5), (0, 0, 0), "leg", 2, [(-1.5, -1, -2, 3, 6, 4, "skin")])
    c.sym("shin", "leg$", (0, 5, 1), (0, 0, 0), "shin", 2, [(-1, 0, -1, 2, 3, 2, "dark")])
    c.sym("claw", "shin$", (0, 2, -1), (0, 0, 0), "static", 2, [(-1, 0, -1.5, 2, 1, 2, "bone")])
    c.p("tail1", "body", (0, -2, 7), (-0.25, 0, 0), "tail", 0, 0, [(-2, -2, 0, 4, 4, 4, "skin")])
    c.p("tail2", "tail1", (0, 0, 4), (0.1, 0, 0), "tail", 0, 1, [(-1.5, -1.5, 0, 3, 3, 4, "skin")])
    c.p("tail3", "tail2", (0, 0, 4), (0.1, 0, 0), "tail", 0, 2, [(-1, -1, 0, 2, 2, 4, "dark")])
    c.p("tail4", "tail3", (0, 0, 4), (0.1, 0, 0), "tail", 0, 3, [(-0.5, -2, 0, 1, 4, 4, "blade")])
    return c


def warrior3():
    c = Creature("warrior_3", {
        "skin": mat("skin", "#8f1d2b", "#561018", spots=1),
        "face": mat("face", "#9a2432", "#561018", mouth="none", blush=None),
        "dark": mat("armor", "#2c1f26", "#120c10"),
        "armor": mat("armor", "#5b1622", "#2c0a10", rivet="#ffb35c"),
        "bone": mat("bone", "#f2e5d0", "#8c7a63"),
        "blade": mat("blade", "#e6eaf0", "#6a7480"),
        "eye": mat("eye", "#ffef7a", "#2a0600", iris="#ff4800", glow=True),
        "core": mat("core", "#ff3d2a", "#ffe0b0", glow=True),
    })
    c.p("body", None, (0, 4, 0), role="body", boxes=[
        (-5, -10, -3, 10, 10, 6, "skin"),
        (-4.5, -9.5, -3.6, 9, 5, 1, "armor"),
    ])
    c.p("heart", "body", (0, -7, -3.7), role="crystal", index=3, boxes=[(-1, -1, -0.5, 2, 2, 1, "core")])
    c.p("abdomen", "body", (0, 0, 0), role="body2", boxes=[(-3.5, 0, -2.5, 7, 4, 5, "dark")])
    c.sym("pauldron", "body", (5, -9, 0), (0, 0, -0.3), "static", 0, [(-1, -2, -2.5, 4, 3, 5, "armor")])
    c.sym("spike", "pauldron$", (2, -2, 0), (0, 0, 0.5), "static", 0, [(-0.5, -4, -0.5, 1, 4, 1, "bone")])
    c.p("head", "body", (0, -10, 0), role="head", boxes=[(-3, -6, -3.5, 6, 6, 6, "face")])
    for i in range(3):
        c.p("crest_%d" % i, "head", (0, -6, -2 + i * 2), (-0.5 - 0.15 * i, 0, 0), "fin", 0, i,
            [(-0.5, -4 + i, 0, 1, 4 - i, 2, "bone")])
    c.sym("jaw", "head", (1.5, -0.5, -3.2), (0, -0.25, 0), "jaw", 0, [(-1, 0, -1.5, 2, 3, 2, "dark")])
    c.sym("eye", "head", (1.6, -3.6, -3.5), (0, 0, 0), "eye", 0, [(-1, -1, -0.5, 2, 2, 1, "eye")])
    c.sym("eyeb", "head", (1.3, -5.2, -3.3), (0, 0, 0), "eye", 1, [(-0.5, -0.5, -0.5, 1, 1, 1, "eye")])
    c.sym("arm", "body", (5.5, -8, 0), (0, 0, -0.15), "arm", 0, [(0, -1.5, -1.5, 3, 8, 3, "skin")])
    c.sym("fore", "arm$", (1.5, 6.5, 0), (-0.35, 0, 0), "fore", 0, [(-1, 0, -1, 2, 7, 2, "dark")])
    c.sym("blade", "fore$", (0, 6, 0), (-0.5, 0, 0), "static", 0, [(-0.5, -1, -1, 1, 9, 2, "blade")])
    c.sym("arm2", "body", (4.6, -3, 0.5), (0.3, 0, -0.35), "arm", 1, [(0, -1, -1, 2, 6, 2, "skin")])
    c.sym("fore2", "arm2$", (1, 5.5, 0), (-0.5, 0, 0), "fore", 1, [(-1, 0, -1, 2, 5, 2, "dark")])
    c.sym("talon2", "fore2$", (0, 5, 0), (0, 0, 0), "static", 1, [(-1, 0, -1, 2, 2, 1, "bone")])
    c.sym("leg", None, (2.5, 8, 0), (-0.25, 0, 0), "leg", 0, [(-1.5, 0, -2, 3, 7, 4, "skin")])
    c.sym("shin", "leg$", (0, 7, 0), (0.5, 0, 0), "shin", 0, [(-1, 0, -1, 2, 6, 2, "dark")])
    c.sym("foot", "shin$", (0, 6, 0), (-0.25, 0, 0), "static", 0, [(-1.5, 0, -3, 3, 2, 4, "armor")])
    c.p("tail1", "abdomen", (0, 2, 2.5), (-0.6, 0, 0), "tail", 0, 0, [(-1.5, -1.5, 0, 3, 3, 5, "skin")])
    c.p("tail2", "tail1", (0, 0, 5), (0.25, 0, 0), "tail", 0, 1, [(-1, -1, 0, 2, 2, 5, "dark")])
    c.p("tail3", "tail2", (0, 0, 5), (0.1, 0, 0), "tail", 0, 2, [(-0.5, -2.5, 0, 1, 5, 4, "blade")])
    return c


# ---------------------------------------------------------------- Farmer
def farmer1():
    c = Creature("farmer_1", {
        "skin": mat("skin", "#7cc46a", "#4f8f45"),
        "face": mat("face", "#82c970", "#4f8f45", mouth="smile", blush="#f59bb0"),
        "belly": mat("skin", "#d6efb0", "#b9dc8e", spots=0),
        "leaf": mat("leaf", "#5fb84f", "#a7e07a"),
        "petal": mat("petal", "#ff9ccf", "#ffe066"),
        "root": mat("wood", "#8a6a45", "#5f4630"),
        "eye": mat("eye", "#fffbe8", "#1d2b14", iris="#3f7a2a"),
    })
    c.p("body", None, (0, 22, 0), role="body", boxes=[
        (-3, -7, -2.5, 6, 7, 5, "face"),
        (-2, -3.5, -2.8, 4, 3, 1, "belly"),
    ])
    c.p("leaf_0", "body", (0, -7, 0), (0.1, 0, 0), "leaf", 0, 0, [(-0.5, -3, -0.5, 1, 3, 1, "leaf")])
    c.p("leaf_1", "leaf_0", (0, -3, 0), (0, 0, 0.5), "leaf", 1, 1, [(0, -0.5, -1.5, 4, 1, 3, "leaf")])
    c.p("leaf_2", "leaf_0", (0, -3, 0), (0, 0, -0.5), "leaf", -1, 2, [(-4, -0.5, -1.5, 4, 1, 3, "leaf")])
    c.p("petal_0", "body", (2.2, -6.2, 1.2), (0.3, 0.3, 0.4), "leaf", 0, 3, [(-1, -1, -1, 2, 2, 2, "petal")])
    c.sym("eye", "body", (1.4, -4.7, -2.4), (0, 0, 0), "eye", 0, [(-1, -1.5, -0.6, 2, 3, 1, "eye")])
    c.sym("arm", "body", (3, -3.2, 0), (0, 0, -0.3), "arm", 0, [(0, 0, -1, 1, 3, 2, "skin")])
    c.sym("leg", None, (1.5, 22, 0), (0, 0, 0), "leg", 0, [(-1, 0, -1.5, 2, 2, 3, "root")])
    c.p("tail1", "body", (0, -1.5, 2.4), (0.6, 0, 0), "tail", 0, 0, [(-0.5, -0.5, 0, 1, 1, 3, "root")])
    c.p("tail2", "tail1", (0, 0, 3), (-0.6, 0, 0), "leaf", 0, 4, [(-1, -0.5, 0, 2, 1, 2, "leaf")])
    return c


def farmer2():
    c = Creature("farmer_2", {
        "skin": mat("skin", "#a7845d", "#7a5f41"),
        "face": mat("face", "#b08b62", "#7a5f41", mouth="smile", blush="#e89a8a"),
        "moss": mat("moss", "#4f9a3c", "#2f6a28"),
        "shell": mat("shell", "#6b5a3e", "#4a3d2a"),
        "leaf": mat("leaf", "#62b84e", "#a9e27c"),
        "petal": mat("petal", "#ffd34d", "#ff8a3d"),
        "petal2": mat("petal", "#c58bff", "#ffffff"),
        "cap": mat("skin", "#d9473f", "#fff3e0", spots=6),
        "stem": mat("skin", "#f1e6cf", "#d8c9aa", spots=0),
        "eye": mat("eye", "#1f1a12", "#ffffff", iris="#5a4630", dark=True),
        "snout": mat("skin", "#c9a37a", "#a07f5b", spots=0),
    })
    c.p("body", None, (0, 18, 0), role="body", boxes=[(-5, -3, -6, 10, 5, 12, "skin")])
    c.p("shell", "body", (0, -3, 0), role="shell", boxes=[
        (-6, -4, -7, 12, 4, 14, "moss"),
        (-6.5, -0.5, -7.5, 13, 1, 15, "shell"),
    ])
    tufts = [(-3, -4, -4), (3.5, -4, -2), (-1, -4, 3), (4, -4, 5), (-4.5, -4, 4.5)]
    for i, (x, y, z) in enumerate(tufts):
        c.p("leaf_%d" % i, "shell", (x, y, z), (0.2 * ((i % 3) - 1), 0.5 * i, 0.15), "leaf", 0, i,
            [(-1.5, -2, -0.5, 3, 2, 1, "leaf")])
    c.p("stem_0", "shell", (1, -4, -4), (0, 0, 0.1), "leaf", 0, 5, [(-0.5, -3, -0.5, 1, 3, 1, "leaf")])
    c.p("petal_0", "stem_0", (0, -3, 0), (0, 0.7, 0), "leaf", 0, 6, [(-1.5, -1, -1.5, 3, 1, 3, "petal"), (-0.5, -2, -0.5, 1, 1, 1, "petal")])
    c.p("stem_1", "shell", (-2.5, -4, 1), (0, 0, -0.15), "leaf", 0, 7, [(-0.5, -4, -0.5, 1, 4, 1, "leaf")])
    c.p("petal_1", "stem_1", (0, -4, 0), (0, 0.3, 0), "leaf", 0, 8, [(-1.5, -1, -1.5, 3, 1, 3, "petal2"), (-0.5, -2, -0.5, 1, 1, 1, "petal2")])
    c.p("mush", "shell", (3, -4, 2.5), role="static", boxes=[(-0.5, -2, -0.5, 1, 2, 1, "stem"), (-1.5, -3, -1.5, 3, 1, 3, "cap")])
    for i, (x, z) in enumerate(((-6.3, -3), (6.3, -1), (-6.3, 3), (6.3, 4))):
        c.p("tent_%d" % i, "shell", (x, 0, z), (0, 0, 0), "tentacle", 0, i, [(-0.5, 0, -0.5, 1, 3, 1, "leaf")])
    c.p("head", "body", (0, 0, -6), role="head", boxes=[
        (-3, -3, -4, 6, 5, 4, "face"),
        (-1.5, -0.5, -5, 3, 2, 1, "snout"),
    ])
    c.sym("eye", "head", (1.8, -1.6, -3.9), (0, 0, 0), "eye", 0, [(-0.5, -0.5, -0.5, 1, 1, 1, "eye")])
    c.sym("ear", "head", (2.8, -2.8, -1.5), (0, 0, 0.7), "ear", 0, [(0, -0.5, -1.5, 3, 1, 3, "leaf")])
    for nm, z, idx in (("leg_f", -4, 0), ("leg_b", 4, 2)):
        c.sym(nm, None, (3.5, 20, z), (0, 0, 0), "leg", idx, [(-1.5, 0, -1.5, 3, 4, 3, "skin")])
    c.p("tail1", "body", (0, -1, 6), (0.4, 0, 0), "tail", 0, 0, [(-1, -1, 0, 2, 2, 2, "skin")])
    c.p("tail2", "tail1", (0, 0, 2), (0.2, 0, 0), "leaf", 0, 9, [(-1.5, -0.5, 0, 3, 1, 3, "leaf")])
    return c


def farmer3():
    c = Creature("farmer_3", {
        "skin": mat("fur", "#c9b28a", "#9c8562"),
        "face": mat("face", "#d1ba92", "#9c8562", mouth="smile", blush="#f0a090"),
        "moss": mat("moss", "#4c9a40", "#2a6526"),
        "wood": mat("wood", "#7a5a3a", "#523b25"),
        "leaf": mat("leaf", "#5cb24a", "#b4e98a"),
        "petal": mat("petal", "#ffb7d9", "#fff6a8"),
        "petal2": mat("petal", "#ffffff", "#ffd84a"),
        "hoof": mat("bone", "#4a3a2c", "#2a2018"),
        "eye": mat("eye", "#1e2a14", "#ffffff", iris="#4f7f2a", dark=True),
        "orb": mat("core", "#f8ff9a", "#ffffff", glow=True),
        "snout": mat("skin", "#e8d6b4", "#c7b08c", spots=0),
    })
    c.p("body", None, (0, 10, 0), role="body", boxes=[(-5, -4, -9, 10, 8, 18, "skin")])
    c.p("moss", "body", (0, -4, 0), role="shell", boxes=[(-5.5, -1.5, -8, 11, 2, 16, "moss")])
    for i, (x, z, m) in enumerate(((-2.5, -5, "petal"), (2.5, -1, "petal2"), (-1.5, 3, "petal"), (3, 6, "petal"))):
        c.p("petal_%d" % i, "moss", (x, -1.5, z), (0.2, 0.6 * i, 0.15 * (i - 1.5)), "leaf", 0, i,
            [(-1.5, -1, -1.5, 3, 1, 3, m), (-0.5, -2, -0.5, 1, 1, 1, "petal2")])
    for i, (x, z) in enumerate(((-5.5, -5), (5.5, -2), (-5.5, 2), (5.5, 5))):
        c.p("tent_%d" % i, "body", (x, -4, z), (0, 0, 0), "tentacle", 0, i, [(-0.5, 0, -0.5, 1, 5, 1, "leaf")])
    c.p("neck", "body", (0, -2, -8), (0.45, 0, 0), "neck", 0, 0, [(-2, -8, -2, 4, 8, 4, "skin")])
    c.p("neck2", "neck", (0, -8, 0), (-0.15, 0, 0), "neck", 0, 1, [(-1.5, -6, -1.5, 3, 6, 3, "skin")])
    c.p("head", "neck2", (0, -6, 0), (-0.3, 0, 0), "head", boxes=[
        (-2.5, -3, -5, 5, 4, 6, "face"),
        (-1.5, -1.5, -7, 3, 3, 2, "snout"),
    ])
    c.sym("eye", "head", (1.9, -1.8, -4.2), (0, 0, 0), "eye", 0, [(-0.5, -0.5, -0.5, 1, 1, 1, "eye")])
    c.sym("ear", "head", (2.3, -2.5, -1), (0, 0, -0.9), "ear", 0, [(0, -0.5, -1, 3, 1, 2, "leaf")])
    c.sym("antler", "head", (1.3, -3, -2), (0, 0, 0.35), "leaf", 0, [(-0.5, -5, -0.5, 1, 5, 1, "wood")])
    c.sym("antlerb", "antler$", (0, -3, 0), (0, 0, 0.8), "leaf", 1, [(-0.5, -3, -0.5, 1, 3, 1, "wood")])
    c.sym("blossom", "antler$", (0, -5, 0), (0, 0.6, 0), "leaf", 2, [(-1, -2, -1, 2, 2, 2, "petal")])
    c.sym("bud", "antlerb$", (0, -3, 0), (0, 0.3, 0), "leaf", 3, [(-1, -1, -1, 2, 1, 2, "leaf")])
    for nm, z, idx in (("leg_f", -6, 0), ("leg_b", 6, 2)):
        c.sym(nm, None, (3.5, 13, z), (0, 0, 0), "leg", idx, [(-1.5, 0, -1.5, 3, 6, 3, "skin")])
        c.sym("shin" + nm[3:], nm + "$", (0, 6, 0), (0, 0, 0), "shin", idx, [(-1, 0, -1, 2, 4, 2, "skin")])
        c.sym("hoof" + nm[3:], "shin" + nm[3:] + "$", (0, 4, 0), (0, 0, 0), "static", idx, [(-1.5, 0, -1.5, 3, 1, 3, "hoof")])
    c.p("tail1", "body", (0, -2, 9), (-0.7, 0, 0), "tail", 0, 0, [(-1, -1, 0, 2, 2, 3, "skin")])
    c.p("tail2", "tail1", (0, 0, 3), (0.2, 0, 0), "tail", 0, 1, [(-2, -0.5, 0, 4, 1, 4, "leaf")])
    c.p("tail3", "tail2", (0, 0, 4), (0.2, 0, 0), "tail", 0, 2, [(-1.5, -0.5, 0, 3, 1, 3, "leaf")])
    for i in range(3):
        c.p("orb_%d" % i, None, (0, 2.5 - i, 3 * (i - 1)), role="orb", index=i, boxes=[(-1, -1, -1, 2, 2, 2, "orb")])
    return c


# ---------------------------------------------------------------- Explorer
def explorer1():
    c = Creature("explorer_1", {
        "fur": mat("fur", "#9fd3f0", "#5c9ed1"),
        "face": mat("face", "#a6d8f3", "#5c9ed1", mouth="smile", blush="#ffb0c8"),
        "belly": mat("skin", "#f2fbff", "#d6eefa", spots=0),
        "membrane": mat("membrane", "#7ec8ff", "#ffe08a"),
        "inner": mat("skin", "#ffc4d8", "#f39bb9", spots=0),
        "gold": mat("core", "#ffd56b", "#fff6cf", glow=True),
        "eye": mat("eye", "#ffffff", "#10233f", iris="#2f7fd6"),
        "tip": mat("fur", "#ffffff", "#d8eefb"),
    })
    c.p("body", None, (0, 21, 0), role="body", boxes=[
        (-2.5, -3, -3.5, 5, 4, 7, "fur"),
        (-2, -0.5, -3, 4, 2, 6, "belly"),
    ])
    c.p("head", "body", (0, -2, -3.5), role="head", boxes=[(-3, -4, -3.5, 6, 5, 5, "face")])
    c.sym("ear", "head", (2, -3.6, -1), (0, 0, 0.3), "ear", 0, [(-1, -4, -0.5, 3, 4, 1, "fur")])
    c.sym("earin", "ear$", (0.5, -1.5, -0.6), (0, 0, 0), "static", 0, [(-1, -2, -0.1, 2, 2, 0, "inner")])
    c.sym("eye", "head", (1.5, -2.2, -3.4), (0, 0, 0), "eye", 0, [(-1, -1.5, -0.6, 2, 3, 1, "eye")])
    c.p("antenna_0", "head", (0, -4, -1), (-0.4, 0, 0), "antenna", 0, 0, [(-0.5, -3, -0.5, 1, 3, 1, "fur")])
    c.p("antip", "antenna_0", (0, -3, 0), role="crystal", boxes=[(-1, -2, -1, 2, 2, 2, "gold")])
    c.sym("wing", "body", (2.5, -1.5, 0), (0, 0, 0.15), "wing", 0, [(0, -0.5, -3, 5, 1, 6, "membrane")])
    c.sym("wingb", "wing$", (5, 0, 0), (0, 0, 0.1), "wing2", 0, [(0, -0.5, -2, 3, 1, 4, "membrane")])
    for nm, z, idx in (("leg_f", -2.5, 0), ("leg_b", 2.5, 2)):
        c.sym(nm, None, (1.5, 22, z), (0, 0, 0), "leg", idx, [(-0.5, 0, -0.5, 1, 2, 1, "fur")])
    c.p("tail1", "body", (0, -1.5, 3.5), (-0.5, 0, 0), "tail", 0, 0, [(-1.5, -1.5, 0, 3, 3, 4, "fur")])
    c.p("tail2", "tail1", (0, 0, 4), (-0.3, 0, 0), "tail", 0, 1, [(-1, -1, 0, 2, 2, 3, "tip")])
    return c


def explorer2():
    c = Creature("explorer_2", {
        "skin": mat("skin", "#3f6fc4", "#88d6ff", spot_glow=True, spots=10),
        "face": mat("face", "#4677cc", "#88d6ff", mouth="smile", blush=None),
        "belly": mat("skin", "#dfefff", "#bcd8f6", spots=0),
        "membrane": mat("membrane", "#5aa7ef", "#b8f0ff"),
        "fin": mat("membrane", "#ffd36b", "#fff1c0"),
        "glow": mat("core", "#9ff3ff", "#ffffff", glow=True),
        "eye": mat("eye", "#ffffff", "#0b1a33", iris="#25c3ff", glow=True),
    })
    c.p("body", None, (0, 15, 0), role="body", boxes=[
        (-3.5, -2.5, -5, 7, 4, 10, "skin"),
        (-3, 1, -4.5, 6, 1, 9, "belly"),
    ])
    c.p("head", "body", (0, -0.5, -5), role="head", boxes=[(-3, -2.5, -4, 6, 4, 4, "face")])
    c.sym("eye", "head", (1.8, -1, -4), (0, 0, 0), "eye", 0, [(-1, -1, -0.5, 2, 2, 1, "eye")])
    c.sym("fin", "head", (2.6, 1, -3.4), (0.4, 0, 0.2), "fin", 0, [(-0.5, -1, -3, 1, 2, 3, "fin")])
    c.sym("antenna", "head", (1.5, -2.5, -2), (-0.7, 0, 0.4), "antenna", 0, [(-0.5, -5, -0.5, 1, 5, 1, "skin")])
    c.sym("antip", "antenna$", (0, -5, 0), (0, 0, 0), "crystal", 0, [(-1, -1, -1, 2, 2, 2, "glow")])
    c.sym("wing", "body", (3.5, -1, 0), (0, 0, 0.1), "wing", 0, [(0, -0.5, -4, 7, 1, 8, "membrane")])
    c.sym("wingb", "wing$", (7, 0, 0), (0, 0, 0.1), "wing2", 0, [(0, -0.5, -3, 5, 1, 6, "membrane")])
    c.sym("leg", "body", (1.5, 1.5, 2), (0.6, 0, 0), "leg", 2, [(-0.5, 0, -0.5, 1, 3, 1, "skin")])
    c.p("tail1", "body", (0, -0.5, 5), (0, 0, 0), "tail", 0, 0, [(-1, -1, 0, 2, 2, 4, "skin")])
    for i in range(2, 5):
        c.p("tail%d" % i, "tail%d" % (i - 1), (0, 0, 4), (0, 0, 0), "tail", 0, i - 1, [(-0.5, -0.5, 0, 1, 1, 4, "skin")])
    c.p("tailfin", "tail4", (0, 0, 4), role="fin", index=3, boxes=[(-2, -0.5, 0, 4, 1, 3, "fin")])
    return c


def explorer3():
    c = Creature("explorer_3", {
        "fur": mat("fur", "#e8f2ff", "#9fb8de"),
        "face": mat("face", "#eef5ff", "#9fb8de", mouth="none", blush=None),
        "dark": mat("fur", "#2d4f8f", "#1a3263"),
        "membrane": mat("membrane", "#4f8fe8", "#c8ecff"),
        "membrane2": mat("membrane", "#7a6cf0", "#e4dcff"),
        "gold": mat("blade", "#ffd35a", "#b8862a"),
        "beak": mat("bone", "#ffcf5c", "#c98a22"),
        "eye": mat("eye", "#fff3c0", "#1b1030", iris="#ffb000", glow=True),
        "glow": mat("core", "#b9f6ff", "#ffffff", glow=True),
    })
    c.p("body", None, (0, 10, 0), role="body", boxes=[
        (-4.5, -4, -7, 9, 8, 14, "fur"),
        (-4, -4.5, -6, 8, 1, 12, "dark"),
    ])
    c.p("neck", "body", (0, -2, -7), (0.7, 0, 0), "neck", 0, 0, [(-2, -6, -2, 4, 6, 4, "fur")])
    c.p("neck2", "neck", (0, -6, 0), (-0.3, 0, 0), "neck", 0, 1, [(-1.5, -5, -1.5, 3, 5, 3, "fur")])
    c.p("head", "neck2", (0, -5, 0), (-0.4, 0, 0), "head", boxes=[
        (-2.5, -3, -4, 5, 4, 5, "face"),
        (-1, -1.5, -6.5, 2, 2, 3, "beak"),
    ])
    c.sym("eye", "head", (2, -1.8, -3.4), (0, 0, 0), "eye", 0, [(-0.5, -1, -0.5, 1, 2, 1, "eye")])
    for i in range(3):
        c.p("crest_%d" % i, "head", (0, -3, -2 + i * 1.6), (-0.9 - 0.25 * i, 0, 0), "fin", 0, i,
            [(-0.5, -5 + i, 0, 1, 5 - i, 2, "dark" if i % 2 else "gold")])
    c.sym("antenna", "head", (1.5, -2.5, -3), (-0.9, 0, 0.6), "antenna", 0, [(-0.5, -6, -0.5, 1, 6, 1, "dark")])
    c.sym("antip", "antenna$", (0, -6, 0), (0, 0, 0), "crystal", 0, [(-1, -1, -1, 2, 2, 2, "glow")])
    c.sym("wing", "body", (4.5, -3, -3), (0, 0, 0.1), "wing", 0, [(0, -0.5, -4, 9, 1, 8, "membrane"), (0, -1.5, -4.5, 9, 1, 1, "gold")])
    c.sym("wingb", "wing$", (9, 0, 0), (0, 0, 0.1), "wing2", 0, [(0, -0.5, -3, 7, 1, 6, "membrane"), (0, -1.5, -3.5, 7, 1, 1, "gold")])
    c.sym("wingc", "body", (4.5, -2, 4), (0, 0, 0.2), "wing", 1, [(0, -0.5, -2, 6, 1, 5, "membrane2")])
    c.sym("wingd", "wingc$", (6, 0, 0), (0, 0, 0.1), "wing2", 1, [(0, -0.5, -1.5, 4, 1, 3, "membrane2")])
    c.sym("leg", "body", (2, 3, 2), (0.4, 0, 0), "leg", 2, [(-1, 0, -1, 2, 5, 2, "dark")])
    c.sym("shin", "leg$", (0, 5, 0), (0.4, 0, 0), "shin", 2, [(-0.5, 0, -0.5, 1, 4, 1, "beak")])
    c.p("tail1", "body", (0, -2, 7), (-0.2, 0, 0), "tail", 0, 0, [(-2, -2, 0, 4, 4, 5, "fur")])
    c.p("tail2", "tail1", (0, 0, 5), (0.05, 0, 0), "tail", 0, 1, [(-1.5, -1.5, 0, 3, 3, 5, "dark")])
    c.p("tail3", "tail2", (0, 0, 5), (0.05, 0, 0), "tail", 0, 2, [(-1, -1, 0, 2, 2, 5, "fur")])
    c.p("tail4", "tail3", (0, 0, 5), (0.05, 0, 0), "tail", 0, 3, [(-0.5, -0.5, 0, 1, 1, 5, "dark")])
    c.p("tailfin", "tail4", (0, 0, 5), role="fin", index=4, boxes=[(-3, -0.5, -1, 6, 1, 5, "membrane"), (-0.5, -1, -0.5, 1, 1, 5, "gold")])
    return c


ALL = [hatchling, miner1, miner2, miner3, warrior1, warrior2, warrior3, farmer1, farmer2, farmer3,
       explorer1, explorer2, explorer3]
