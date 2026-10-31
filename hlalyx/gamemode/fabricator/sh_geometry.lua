-- Procedural geometry for the deployable parts of the fabricator (screen housing, grille, eyestalk,
-- weapon cradle, resin tray). The station MDL is a single static mesh with no moving parts, so these
-- mechanisms are built here and animated by sh_rig.lua.
--
-- Pure Lua: produces flat vertex arrays per material. cl_parts.lua turns them into IMesh objects;
-- the offline preview feeds the very same output into Blender, so what was checked there is what
-- the game draws. Triangles are emitted clockwise (Source front-face convention).
CFRework = CFRework or {}
local C = CFRework
local M = C.M
local G = {}
C.Geo = G

local sqrt, sin, cos, rad, abs, pi = math.sqrt, math.sin, math.cos, math.rad, math.abs, math.pi
local TEX = 1 / 24 -- metal texture repeats every 24 units

local B = {}
B.__index = B

function G.builder()
	return setmetatable({mats = {}, stack = {M.ident()}}, B)
end

function B:push(m) self.stack[#self.stack + 1] = M.mul(self.stack[#self.stack], m) end
function B:pop() self.stack[#self.stack] = nil end

local function out(list, x, y, z, nx, ny, nz, u, v)
	local n = #list
	list[n+1], list[n+2], list[n+3], list[n+4], list[n+5], list[n+6], list[n+7], list[n+8] = x, y, z, nx, ny, nz, u, v
end

local function boxuv(x, y, z, nx, ny, nz)
	local ax, ay, az = abs(nx), abs(ny), abs(nz)
	if ax >= ay and ax >= az then return y * TEX, -z * TEX end
	if ay >= az then return x * TEX, -z * TEX end
	return x * TEX, y * TEX
end

-- One triangle given counter-clockwise as seen from outside (a,b,c), optional per-vertex normals.
-- Stored clockwise for Source.
function B:tri(mat, a, b, c, na, nb, nc)
	local m = self.stack[#self.stack]
	local list = self.mats[mat]
	if not list then list = {} self.mats[mat] = list end
	local ax, ay, az = M.point(m, a[1], a[2], a[3])
	local bx, by, bz = M.point(m, b[1], b[2], b[3])
	local cx, cy, cz = M.point(m, c[1], c[2], c[3])
	local ux, uy, uz = bx-ax, by-ay, bz-az
	local vx, vy, vz = cx-ax, cy-ay, cz-az
	local fx, fy, fz = uy*vz-uz*vy, uz*vx-ux*vz, ux*vy-uy*vx
	local l = sqrt(fx*fx+fy*fy+fz*fz)
	if l < 1e-9 then return end
	fx, fy, fz = fx/l, fy/l, fz/l
	local function nrm(n)
		if not n then return fx, fy, fz end
		local x, y, z = M.dir(m, n[1], n[2], n[3])
		local k = sqrt(x*x+y*y+z*z)
		return x/k, y/k, z/k
	end
	local n1x, n1y, n1z = nrm(na)
	local n2x, n2y, n2z = nrm(nb)
	local n3x, n3y, n3z = nrm(nc)
	-- UV projection from the face normal so a quad never tears across two projections
	local u1, v1 = boxuv(ax, ay, az, fx, fy, fz)
	local u2, v2 = boxuv(bx, by, bz, fx, fy, fz)
	local u3, v3 = boxuv(cx, cy, cz, fx, fy, fz)
	out(list, ax, ay, az, n1x, n1y, n1z, u1, v1)
	out(list, cx, cy, cz, n3x, n3y, n3z, u3, v3)
	out(list, bx, by, bz, n2x, n2y, n2z, u2, v2)
end

function B:quad(mat, a, b, c, d, na, nb, nc, nd)
	self:tri(mat, a, b, c, na, nb, nc)
	self:tri(mat, a, c, d, na, nc, nd)
end

-- axis frames for extrusions: 2D (u,v) plus extrusion coordinate t, all right-handed
local FRAME = {
	x = function(u, v, t) return {t, u, v} end,
	y = function(u, v, t) return {v, t, u} end,
	z = function(u, v, t) return {u, v, t} end,
}
local AXISV = {x = {1,0,0}, y = {0,1,0}, z = {0,0,1}}

-- Extrude a convex polygon between t0 and t1 along `axis`.
-- The polygon is given in natural coordinates, counter-clockwise when plotted on those axes:
--   axis x: (y, z)   axis y: (x, z)   axis z: (x, y)
-- smooth: share normals around the sides (cylinders).
function B:prism(mat, poly, axis, t0, t1, smooth, capmat)
	if axis == 'y' then
		-- the right-handed frame for Y is (z, x): swap the coordinates and restore the winding
		local p = {}
		for i = #poly, 1, -1 do p[#p + 1] = {poly[i][2], poly[i][1]} end
		poly = p
	end
	local P = FRAME[axis]
	local A = AXISV[axis]
	local n = #poly
	local norms = {}
	for i = 1, n do
		local a, b = poly[i], poly[i % n + 1]
		local eu, ev = b[1]-a[1], b[2]-a[2]
		local l = sqrt(eu*eu+ev*ev)
		-- outward edge normal in 2D is (ev, -eu)
		norms[i] = {ev/l, -eu/l}
	end
	for i = 1, n do
		local j = i % n + 1
		local a, b = poly[i], poly[j]
		local na, nb
		if smooth then
			local p = norms[(i - 2) % n + 1]
			local q = norms[i]
			local r = norms[j]
			local s1u, s1v = p[1]+q[1], p[2]+q[2]
			local s2u, s2v = q[1]+r[1], q[2]+r[2]
			na = P(s1u, s1v, 0) nb = P(s2u, s2v, 0)
		end
		self:quad(mat, P(a[1], a[2], t0), P(b[1], b[2], t0), P(b[1], b[2], t1), P(a[1], a[2], t1), na, nb, nb, na)
	end
	capmat = capmat or mat
	for i = 2, n - 1 do
		self:tri(capmat, P(poly[1][1], poly[1][2], t1), P(poly[i][1], poly[i][2], t1), P(poly[i+1][1], poly[i+1][2], t1))
		self:tri(capmat, P(poly[1][1], poly[1][2], t0), P(poly[i+1][1], poly[i+1][2], t0), P(poly[i][1], poly[i][2], t0))
	end
end

function B:box(mat, x0, y0, z0, x1, y1, z1)
	self:prism(mat, {{x0, y0}, {x1, y0}, {x1, y1}, {x0, y1}}, 'z', z0, z1)
end

-- box with chamfered edges running along `axis` (c = chamfer size); (u,v) are natural coordinates
function B:cbox(mat, axis, u0, v0, u1, v1, t0, t1, c)
	self:prism(mat, {
		{u0 + c, v0}, {u1 - c, v0}, {u1, v0 + c}, {u1, v1 - c},
		{u1 - c, v1}, {u0 + c, v1}, {u0, v1 - c}, {u0, v0 + c},
	}, axis, t0, t1)
end

local function circle(cu, cv, r, seg)
	local p = {}
	for i = 0, seg - 1 do
		local a = i / seg * 2 * pi
		p[#p + 1] = {cu + cos(a) * r, cv + sin(a) * r}
	end
	return p
end
G.circle = circle

function B:cyl(mat, axis, cu, cv, r, t0, t1, seg, capmat)
	self:prism(mat, circle(cu, cv, r, seg or 16), axis, t0, t1, true, capmat)
end

-- torus around `axis` centered at (cu,cv,t)
function B:torus(mat, axis, cu, cv, t, R, r, segU, segV)
	local P = FRAME[axis]
	segU, segV = segU or 20, segV or 8
	local function pt(i, j)
		local a = i / segU * 2 * pi
		local b = j / segV * 2 * pi
		local ca, sa, cb, sb = cos(a), sin(a), cos(b), sin(b)
		local rr = R + r * cb
		return P(cu + ca * rr, cv + sa * rr, t + r * sb), P(ca * cb, sa * cb, sb)
	end
	for i = 0, segU - 1 do
		for j = 0, segV - 1 do
			local a, na = pt(i, j)
			local b, nb = pt(i + 1, j)
			local c, nc = pt(i + 1, j + 1)
			local d, nd = pt(i, j + 1)
			self:quad(mat, a, b, c, d, na, nb, nc, nd)
		end
	end
end

-- Flat ring sector ("band") in the XZ plane, extruded along Y. Angles: 0 = straight down (-Z),
-- growing toward +X. Used for the curved cradle ribs.
function B:band(mat, cx, cz, r0, r1, a0, a1, y0, y1, seg, sidemat)
	seg = seg or 12
	sidemat = sidemat or mat
	local function p(r, a) a = rad(a) return {cx + sin(a) * r, cz - cos(a) * r} end
	local function n(a) a = rad(a) return {sin(a), 0, -cos(a)} end
	for i = 0, seg - 1 do
		local aa = a0 + (a1 - a0) * i / seg
		local ab = a0 + (a1 - a0) * (i + 1) / seg
		local o1, o2 = p(r1, aa), p(r1, ab)
		local i1, i2 = p(r0, aa), p(r0, ab)
		-- outer surface (normal away from the centre)
		self:quad(sidemat, {o1[1], y1, o1[2]}, {o2[1], y1, o2[2]}, {o2[1], y0, o2[2]}, {o1[1], y0, o1[2]}, n(aa), n(ab), n(ab), n(aa))
		-- inner surface (normal toward the centre)
		local ia, ib = n(aa), n(ab)
		ia = {-ia[1], 0, -ia[3]} ib = {-ib[1], 0, -ib[3]}
		self:quad(sidemat, {i1[1], y0, i1[2]}, {i2[1], y0, i2[2]}, {i2[1], y1, i2[2]}, {i1[1], y1, i1[2]}, ia, ib, ib, ia)
		-- faces at y1 and y0
		self:quad(mat, {i1[1], y1, i1[2]}, {i2[1], y1, i2[2]}, {o2[1], y1, o2[2]}, {o1[1], y1, o1[2]})
		self:quad(mat, {o1[1], y0, o1[2]}, {o2[1], y0, o2[2]}, {i2[1], y0, i2[2]}, {i1[1], y0, i1[2]})
	end
	local function cap(a, flip)
		local o, i = p(r1, a), p(r0, a)
		if flip then
			self:quad(mat, {i[1], y1, i[2]}, {o[1], y1, o[2]}, {o[1], y0, o[2]}, {i[1], y0, i[2]})
		else
			self:quad(mat, {i[1], y0, i[2]}, {o[1], y0, o[2]}, {o[1], y1, o[2]}, {i[1], y1, i[2]})
		end
	end
	cap(a0, false)
	cap(a1, true)
end

-- Part definitions. Dimensions are in Hammer units, local frames documented per part.
-- Proportions and colours follow the Half-Life: Alyx reference screenshots:
--   brass  = the pale brushed-steel posts/frames, silver = grille rods, metal = dark painted parts.
---------------------------------------------------------------------------------------------------
local P = {}
G.defs = P

-- Inside-out box (faces point inward): dark niche behind a panel that opens, so the hull never
-- looks hollow through the opening. `open` lists the sides left out: 'x+','x-','y+','y-','z+','z-'.
function B:niche(mat, x0, y0, z0, x1, y1, z1, open)
	local skip = {}
	for _, s in ipairs(open or {}) do skip[s] = true end
	-- the corner lists below wind outward; passing them reversed turns every face inward
	local function q(s, a, b, c, d) if not skip[s] then self:quad(mat, a, d, c, b) end end
	q('x-', {x0, y0, z0}, {x0, y0, z1}, {x0, y1, z1}, {x0, y1, z0})
	q('x+', {x1, y0, z0}, {x1, y1, z0}, {x1, y1, z1}, {x1, y0, z1})
	q('y-', {x0, y0, z0}, {x1, y0, z0}, {x1, y0, z1}, {x0, y0, z1})
	q('y+', {x0, y1, z0}, {x0, y1, z1}, {x1, y1, z1}, {x1, y1, z0})
	q('z-', {x0, y0, z0}, {x0, y1, z0}, {x1, y1, z0}, {x1, y0, z0})
	q('z+', {x0, y0, z1}, {x1, y0, z1}, {x1, y1, z1}, {x0, y1, z1})
end

-- Screen housing (the station model has no display, so this one is built). Origin = hinge axis
-- along Y; at angle 0 the panel stands upright with the display facing +X; glass plane x = 0.
-- Real scale of the model: 18 x 9 display, the width of the resin magazine under it.
G.SCREEN_K = 4 / 3 -- the display is drawn at 18 x 9 and scaled to 24 x 12 (reference proportions)
local SK = G.SCREEN_K
G.SCREEN = {x = 0.04 * SK, y0 = -9.0 * SK, z0 = 10.4 * SK, w = 18.0 * SK, h = 9.0 * SK} -- 3D2D canvas, top-left corner
function P.screen(b)
	b:push({SK,0,0,0, 0,SK,0,0, 0,0,SK,0})
	b:cbox('metal', 'y', -0.9, 0.9, -0.15, 11.0, -9.4, 9.4, 0.3)          -- thin back plate
	b:cbox('metal', 'y', -1.6, 2.6, -0.8, 8.6, -6, 6, 0.3)                -- stiffener
	b:box('screen', -0.25, -9.1, 1.3, -0.01, 9.1, 10.5)                   -- glass
	b:box('metal', -0.25, -9.2, 10.5, 0.12, 9.2, 10.9)
	b:box('metal', -0.25, -9.2, 0.9, 0.12, 9.2, 1.3)
	-- left post: pale brushed steel, longer than the panel, cyan strip on its inner edge
	b:cbox('brass', 'z', -1.5, -10.9, 0.8, -9.1, -3.2, 11.9, 0.3)
	b:box('glow', 0.78, -9.55, 0.8, 0.86, -9.15, 11.2)
	b:box('brass', -1.7, -11.2, 11.0, 1.0, -8.9, 12.4)
	for i = 0, 5 do
		local z = -2.4 + i * 2.4
		b:box('dark', -1.1, -10.97, z, 0.5, -10.85, z + 0.3)
	end
	-- right post: same steel, bright white light low on its inner edge
	b:cbox('brass', 'z', -1.5, 9.1, 0.8, 10.9, -3.2, 11.6, 0.3)
	b:box('white', 0.78, 9.15, 1.2, 0.86, 9.55, 6.4)
	b:box('glow', 0.78, 9.15, 6.4, 0.84, 9.4, 10.6)
	b:box('brass', -1.7, 8.9, 10.8, 1.0, 11.2, 12.1)
	for i = 0, 5 do
		local z = -2.4 + i * 2.4
		b:box('dark', -1.1, 10.85, z, 0.5, 10.97, z + 0.3)
	end
	b:cyl('metal', 'y', -0.6, 0.3, 0.6, -9.1, 9.1, 12)                     -- hinge barrel
	-- two red diodes bottom-left under the glass (reference)
	b:box('red', 0.1, -8.4, 0.95, 0.2, -7.8, 1.2)
	b:box('red', 0.1, -7.4, 0.95, 0.2, -6.8, 1.2)
	b:pop()
end

-- Eyestalk, built (the model only has its socket cone). stalk origins = tube bottoms, head = lens centre.
local EYE = 0.62
function P.stalk1(b)
	b:cyl('metal', 'z', 0, 0, 1.5, 0, 0.8, 14)
	b:cyl('metal', 'z', 0, 0, 0.7, 0.8, 9.6, 10)
	b:cyl('brass', 'z', 0, 0, 0.95, 8.8, 9.8, 12)
	b:cyl('brass', 'z', 0, 0, 1.0, 3.0, 3.7, 12)
end
function P.stalk2(b)
	b:cyl('metal', 'z', 0, 0, 0.45, 0, 10.0, 8)
	b:cyl('metal', 'z', 0, 0, 0.7, 9.2, 10.4, 10)
end
function P.head(b)
	b:push(M.mul(M.ident(), {EYE,0,0,0, 0,EYE,0,0, 0,0,EYE,0}))
	b:cbox('metal', 'y', -2.6, -1.9, 0.9, 1.9, -2.0, 2.0, 0.7)
	b:cbox('metal', 'x', -1.4, -2.2, 1.4, 2.2, -3.2, -2.4, 0.5)
	b:torus('glow', 'x', 0, 0, 1.15, 1.55, 0.5, 24, 8)                    -- the big glowing ring lens
	b:cyl('dark', 'x', 0, 0, 1.12, 0.9, 1.2, 16)
	b:cyl('metal', 'x', 0, 0, 0.4, 1.1, 1.55, 10)
	b:cyl('red', 'x', 1.0, -0.6, 0.32, 0.85, 1.05, 8)                     -- red diode right of the lens
	b:cyl('metal', 'z', -0.4, 0, 0.3, 1.8, 3.2, 8)                        -- flat dish "hat" with spokes
	b:cyl('metal', 'z', -0.4, 0, 3.4, 3.2, 3.5, 24)
	b:torus('metal', 'z', -0.4, 0, 3.5, 3.4, 0.18, 28, 6)
	for i = 0, 5 do
		b:push(M.mul(M.T(-0.4, 0, 0), M.A(0, i * 60, 0)))
		b:box('brass', 0.3, -0.1, 3.5, 3.3, 0.1, 3.7)
		b:pop()
	end
	b:cyl('metal', 'z', 0, 0, 0.85, -2.7, -1.8, 12)
	b:pop()
end

-- Cyan ring lights at the mouths of the five upper resin cells (entity space; moves with 'cells').
G.CELLS = {}
for row, z in ipairs({36.2, 32.6}) do
	for i, x in ipairs({-0.6, 2.9, 6.4, 9.9, 13.35}) do
		G.CELLS[#G.CELLS + 1] = {x, -18.05, z}
	end
end
function P.cellglow(b)
	for i = 1, 5 do
		local c = G.CELLS[i]
		b:torus('glow', 'y', c[3], c[1], c[2], 1.42, 0.11, 18, 4)
	end
end

-- Cyan light on every rib of the cage (entity space; moves with 'cage'). Ribs are rings around the
-- X axis at Y 6.57, Z 33.27; the light runs on their front faces around the bottom of the trough.
function P.ribglow(b)
	for _, x in ipairs({1.96, 3.47, 4.98, 6.5, 8.01, 9.52}) do
		b:push(M.mul(M.T(x + 0.67, 0, 0), M.RZ(90)))
		b:band('glow', 6.57, 33.27, 6.05, 6.5, -118, 118, -0.03, 0.03, 20)
		b:pop()
	end
end

-- Dark niches behind the panels that open (entity space, static).
function P.niches(b)
	b:niche('dark', -0.5, -21.0, 27.5, 16.5, -1.8, 40.0, {'z+', 'x+'})     -- under the roof lid (cells)
	b:niche('dark', 3.0, -3.2, 19.2, 19.8, 22.8, 39.6, {'x+'})             -- behind the logo panel (cage)
	b:box('dark', 3.0, -3.2, 39.6, 17.0, 22.8, 39.8)                       -- its ceiling, seen from above too
end

local cache
function G.build()
	if cache then return cache end
	cache = {}
	for name, fn in pairs(P) do
		local b = G.builder()
		fn(b)
		cache[name] = b.mats
	end
	return cache
end

function G.stats()
	local s = {}
	for name, mats in pairs(G.build()) do
		local n = 0
		for _, list in pairs(mats) do n = n + #list / 24 end
		s[name] = n
	end
	return s
end
