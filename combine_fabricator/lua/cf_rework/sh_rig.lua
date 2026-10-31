-- Animation rig: turns the station's animation channels into a transform for every moving part.
-- Two kinds of parts:
--   model parts  pieces of station.mdl itself, folded inside the hull (see cl_partmap.lua):
--                lid (roof panel over the magazine), cells (10-cell resin magazine), rods (grille),
--                logo (front panel over the cage), cage (rib cage = weapon cradle)
--   built parts  what the model lacks: screen housing, eyestalk, light strips, dark niches
-- All matrices are entity-local (sh_math.lua). Shared and pure: the server uses the same transforms
-- for hit tests, the offline preview renders them in Blender.
--
-- Channels (0..1): deploy (wake-up), cradle (cage out), pull (cage draws the weapon in),
--                  tray (magazine presented for resin), lookP/lookY (eye aim, degrees)
CFRework = CFRework or {}
local C = CFRework
local M = C.M
local R = {}
C.Rig = R

local span, overshoot, lerp = M.span, M.overshoot, M.lerp

-- Mount points (entity space), measured on orthographic renders of station.mdl
R.HATCH = {14, -34, 43.6}      -- iris hatch on the left roof: eyestalk
R.HINGE = {3.0, -10.0, 44.2}   -- screen hinge, above the resin magazine
R.CAGE_AXIS = {6.57, 33.27}    -- Y, Z of the rib cage axis (runs along X)
R.CAGE_OUT = 17.0              -- how far the cage slides out of the front
R.WEAPON = {7.0, 6.57, 31.6}   -- where a weapon rests inside the cage (cage closed, entity space)

function R.Pose(s)
	local d = s.deploy or 0
	local out = {}

	-- roof lid over the magazine slides back and up, out of the way
	local lid = span(d, 0.04, 0.38)
	out.lid = M.T(-15.5 * lid, 0, 3.6 * span(d, 0.0, 0.18) + 0.4 * lid)

	-- resin magazine lifts into view under the screen; slides toward the player for loading
	local cells = span(d, 0.30, 0.62)
	local tray = span(s.tray or 0, 0, 1)
	out.cells = M.T(2.2 * tray, 0, 4.0 * cells + 1.2 * tray)
	out.cellglow = out.cells

	-- grille rods rise from under the magazine to stand behind the screen
	local g = span(d, 0.20, 0.70)
	out.rods = M.T(-1.5 * g, 0, 31.0 * g)

	-- eyestalk out of the iris hatch: lower tube, upper tube, then the head comes alive
	local e1 = span(d, 0.00, 0.28)
	local e2 = span(d, 0.12, 0.40)
	local z1 = R.HATCH[3] - 9.0 + 9.4 * e1
	local z2 = z1 + 0.4 + 8.6 * e2
	out.stalk1 = M.T(R.HATCH[1], R.HATCH[2], z1)
	out.stalk2 = M.T(R.HATCH[1], R.HATCH[2], z2)
	local alive = span(d, 0.30, 0.48)
	out.head = M.TA(R.HATCH[1], R.HATCH[2], z2 + 10.4 + 1.3,
		lerp(65, s.lookP or 0, alive), lerp(0, s.lookY or 0, alive), 0)

	-- screen unfolds from lying flat (-90) to a lectern tilt of 45 degrees, slight overshoot
	local so = overshoot(d, 0.42, 1.00)
	-- stowed it lies inside the hull under the roof lid; it rises as the lid clears
	local lift = span(d, 0.22, 0.48)
	out.screen = M.TA(R.HINGE[1], R.HINGE[2], R.HINGE[3] - 7.0 * (1 - lift), lerp(-90, -45, so), 0, 0)

	-- logo panel drops into the hull, then the rib cage slides out of the front
	local c = s.cradle or 0
	local drop = span(c, 0.0, 0.35)
	out.logo = M.T(-1.4 * drop, 0, -27.5 * drop)
	local slide = span(c, 0.25, 0.9) * (1 - 0.75 * span(s.pull or 0, 0, 1))
	out.cage = M.T(R.CAGE_OUT * slide, 0, 1.5 * slide)
	out.ribglow = out.cage

	out.niches = M.ident()
	return out
end

-- 3D2D canvas of the display: origin (top-left), right vector, down vector, normal (entity space)
function R.ScreenFrame(pose)
	local S = C.Geo.SCREEN
	local m = pose.screen
	local ox, oy, oz = M.point(m, S.x, S.y0, S.z0)
	local rx, ry, rz = M.dir(m, 0, 1, 0)
	local dx, dy, dz = M.dir(m, 0, 0, -1)
	local nx, ny, nz = M.dir(m, 1, 0, 0)
	return {ox, oy, oz}, {rx, ry, rz}, {dx, dy, dz}, {nx, ny, nz}
end

-- where the weapon rests (entity space)
function R.WeaponPoint(pose)
	local x, y, z = M.point(pose.cage, R.WEAPON[1], R.WEAPON[2], R.WEAPON[3])
	return {x, y, z}
end

-- mouth of resin cell i (1..10), entity space
function R.CellPoint(pose, i)
	local c = C.Geo.CELLS[i]
	local x, y, z = M.point(pose.cells, c[1], c[2], c[3])
	return {x, y, z}
end
