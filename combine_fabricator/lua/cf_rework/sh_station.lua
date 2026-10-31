-- Shared station helpers: networked animation channels, pose at a given time and what the player
-- is looking at (screen pixel / resin cells / print chamber). Server and client run the same code.
CFRework = CFRework or {}
local C = CFRework
local M = C.M

local CHANNELS = {'deploy', 'cradle', 'tray'}
C.ChannelNames = CHANNELS

function C.SetupChannelVars(ent, firstFloat)
	local i = firstFloat
	for _, name in ipairs(CHANNELS) do
		ent:NetworkVar('Float', i, name .. 'From') i = i + 1
		ent:NetworkVar('Float', i, name .. 'To') i = i + 1
		ent:NetworkVar('Float', i, name .. 'Start') i = i + 1
	end
	return i
end

-- current value of a channel: linear travel at C.Channels[name] seconds per full stroke
function C.Chan(ent, name, t)
	local from, to = ent['Get' .. name .. 'From'](ent), ent['Get' .. name .. 'To'](ent)
	if from == to then return to end
	local dur = (C.Channels[name] or 1) * math.abs(to - from)
	local f = math.Clamp(((t or CurTime()) - ent['Get' .. name .. 'Start'](ent)) / dur, 0, 1)
	return from + (to - from) * f
end

function C.Moving(ent, t)
	for _, name in ipairs(CHANNELS) do
		local v = C.Chan(ent, name, t)
		if v ~= ent['Get' .. name .. 'To'](ent) then return true end
	end
	return false
end

function C.PoseOf(ent, t, look)
	local s = {}
	for _, name in ipairs(CHANNELS) do s[name] = C.Chan(ent, name, t) end
	if look then s.lookP, s.lookY = look[1], look[2] end
	return C.Rig.Pose(s)
end

local function V(t) return Vector(t[1], t[2], t[3]) end
local function Wp(ent, t) return ent:LocalToWorld(V(t)) end
local function Wd(ent, t) return ent:LocalToWorld(V(t)) - ent:GetPos() end

-- world-space screen frame: origin, right, down, normal, 3D2D angle and scale
function C.ScreenWorld(ent, pose)
	local o, r, d, n = C.Rig.ScreenFrame(pose)
	local origin, right, down, normal = Wp(ent, o), Wd(ent, r), Wd(ent, d), Wd(ent, n)
	return origin, right, down, normal, right:AngleEx(normal), C.Geo.SCREEN.w / C.Layout.W
end

-- canvas pixel under the player's crosshair, or nil
function C.HitScreen(ent, ply, pose)
	if not IsValid(ply) then return end
	pose = pose or C.PoseOf(ent)
	if C.Chan(ent, 'deploy') < 0.97 then return end
	local origin, right, down, normal, _, scale = C.ScreenWorld(ent, pose)
	local eye, dir = ply:EyePos(), ply:GetAimVector()
	if eye:DistToSqr(origin) > C.UseRange * C.UseRange then return end
	if dir:Dot(normal) >= -0.05 or (eye - origin):Dot(normal) <= 0 then return end
	local hit = util.IntersectRayWithPlane(eye, dir, origin, normal)
	if not hit then return end
	local rel = hit - origin
	local x, y = rel:Dot(right) / scale, rel:Dot(down) / scale
	if x < 0 or y < 0 or x > C.Layout.W or y > C.Layout.H then return end
	return x, y, hit
end

-- ray against a sphere: distance along the aim, or nil
local function raySphere(eye, dir, center, radius)
	local oc = center - eye
	local t = oc:Dot(dir)
	if t < 0 then return end
	local d2 = oc:LengthSqr() - t * t
	if d2 > radius * radius then return end
	return t
end

function C.CellsCenter(ent, pose)
	local x, y, z = M.point(pose.cells, 6.4, -10.5, 34.5)
	return ent:LocalToWorld(Vector(x, y, z))
end

function C.ItemPoint(ent, pose)
	return Wp(ent, C.Rig.WeaponPoint(pose))
end

-- which physical part the player aims at: 'cells' (resin magazine) or 'chamber' (rib cage)
function C.HitPart(ent, ply, pose)
	if not IsValid(ply) then return end
	pose = pose or C.PoseOf(ent)
	local eye, dir = ply:EyePos(), ply:GetAimVector()
	local best, bestT
	local function try(name, center, radius)
		local t = raySphere(eye, dir, center, radius)
		if t and t < C.UseRange and (not bestT or t < bestT) then best, bestT = name, t end
	end
	try('cells', C.CellsCenter(ent, pose), 9.5)
	if C.Chan(ent, 'cradle') > 0.5 then try('chamber', C.ItemPoint(ent, pose), 10) end
	return best
end
