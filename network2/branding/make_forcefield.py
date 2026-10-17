"""The force field of the Alliance (entities/entities/nw_forcefield.lua): its glass of light.
The look aimed at: a wall of thin glowing mist, brightest where it meets the ground and the posts,
the light rising from the bottom in soft streaks. Three layers, grey (the colour of the mode comes
from the vertex colour: blue - CID cards, orange - the staff of the Alliance, red - units only):
    materials/network2/forcefield/mist_a     the mist, from the HL2 shield noise (comshieldwall_close),
                                             the contrast pushed so it is mostly dark (additive: clear)
                                             with wisps
    materials/network2/forcefield/mist_b     a second, softer mist from comshieldwall (it scrolls the
                                             other way: the two together drift like smoke)
    materials/network2/forcefield/edge       not tiled: the glow at the bottom and at the two posts,
                                             rising streaks, a faint line along the top
VMTs: UnlitGeneric, additive, both sides, vertex colour; the mists scroll (TextureScroll), the edge
breathes a little (Sine on $alpha).
Source textures: the archive of the server (needs/materials/effects/combineshield).
Usage: python make_forcefield.py <the folder with effects/combineshield/*.vtf> <network2 folder>"""
import os, sys
import numpy as np
from PIL import Image, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
import vtf

SRC, ROOT = sys.argv[1], sys.argv[2]
OUT = os.path.join(ROOT, "content", "materials", "network2", "forcefield")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(907)


def grey(a):
    return a[..., :3].astype(float).mean(2) / 255


def save(name, level, size=512):
    level = np.clip(level, 0, 1)
    img = Image.fromarray((level * 255).astype(np.uint8)).resize((size, size), Image.LANCZOS)
    v = np.asarray(img)
    rgba = np.dstack([v, v, v, np.full_like(v, 255)])
    vtf.write(os.path.join(OUT, name + ".vtf"), rgba)


# the mists: tileable noise from the HL2 shield, pushed dark with bright wisps
close = grey(vtf.read(os.path.join(SRC, "comshieldwall_close.vtf")))
wall = grey(vtf.read(os.path.join(SRC, "comshieldwall.vtf")))
mist_a = np.clip((close - 0.3) / 0.5, 0, 1) ** 2.2 * 0.8
mist_b = np.asarray(Image.fromarray((wall * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6)),
                    float) / 255
mist_b = np.clip((mist_b - mist_b.mean() + 0.18) / 0.5, 0, 1) ** 1.4 * 0.55
save("mist_a", mist_a)
save("mist_b", mist_b)

# the edge glow (u across the field 0..1, v from the top 0 to the bottom 1)
S = 512
v, u = np.mgrid[0:S, 0:S].astype(float) / (S - 1)
bottom = np.exp(-(1 - v) / 0.07) * 0.95 + np.exp(-(1 - v) / 0.28) * 0.35
sides = np.exp(-np.minimum(u, 1 - u) / 0.035) * 0.9 + np.exp(-np.minimum(u, 1 - u) / 0.16) * 0.25
top = np.exp(-v / 0.015) * 0.25
# streaks rising from the bottom: vertical noise stretched up, fading with the height
streak = rng.random((6, 40))
streak = np.asarray(Image.fromarray((streak * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC), float) / 255
streak = np.clip(streak - 0.45, 0, 1) * 1.6 * np.exp(-(1 - v) / 0.35)
edge = bottom + sides * (0.6 + 0.4 * v) + top + streak * 0.3
edge = np.asarray(Image.fromarray((np.clip(edge, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5)),
                  float) / 255
save("edge", edge)

VMT_MIST = """"UnlitGeneric"
{{
	"$basetexture" "network2/forcefield/{name}"
	"$additive" "1"
	"$nocull" "1"
	"$nodecal" "1"
	"$vertexcolor" "1"
	"$vertexalpha" "1"
	"$translucent" "1"

	"Proxies"
	{{
		"TextureScroll"
		{{
			"texturescrollvar" "$basetexturetransform"
			"texturescrollrate" "{rate}"
			"texturescrollangle" "{angle}"
		}}
	}}
}}
"""
VMT_EDGE = """"UnlitGeneric"
{
	"$basetexture" "network2/forcefield/edge"
	"$additive" "1"
	"$nocull" "1"
	"$nodecal" "1"
	"$vertexcolor" "1"
	"$vertexalpha" "1"
	"$translucent" "1"

	"Proxies"
	{
		"Sine"
		{
			"sineperiod" "2.6"
			"sinemin" "0.82"
			"sinemax" "1"
			"resultVar" "$alpha"
		}
	}
}
"""
open(os.path.join(OUT, "mist_a.vmt"), "w").write(VMT_MIST.format(name="mist_a", rate="0.035", angle="78"))
open(os.path.join(OUT, "mist_b.vmt"), "w").write(VMT_MIST.format(name="mist_b", rate="0.02", angle="-100"))
open(os.path.join(OUT, "edge.vmt"), "w").write(VMT_EDGE)

# a preview: the field over a dark street, blue
prev = np.zeros((360, 640, 3))
pa = np.asarray(Image.fromarray((mist_a * 255).astype(np.uint8)).resize((640, 360)), float) / 255
pb = np.asarray(Image.fromarray((mist_b * 255).astype(np.uint8)).resize((640, 360)), float) / 255
pe = np.asarray(Image.fromarray((np.clip(edge, 0, 1) * 255).astype(np.uint8)).resize((640, 360)), float) / 255
blue = np.array([70, 165, 255]) / 255
light = (pa * 0.55 + pb * 0.5 + pe) [..., None] * blue
street = np.dstack([np.full((360, 640), 0.10), np.full((360, 640), 0.11), np.full((360, 640), 0.13)])
Image.fromarray((np.clip(street + light, 0, 1) * 255).astype(np.uint8)).save(os.path.join(ROOT, "branding", "out",
                                                                                        "forcefield_preview.png"))
print("force field written")
