-- The dropship flight (see sv_dropship): a smooth curve through the points at a steady speed, the nose along
-- the way, banking into the turns, the engines heard from afar and up close.
local D = {}
HLA.DropshipCL = D
local MODEL = 'models/combine_dropship.mdl'
local CONTAINER = 'models/combine_dropship_container.mdl'
local SND_FAR = 'npc/combine_gunship/dropship_engine_distant_loop1.wav'
local SND_NEAR = 'npc/combine_gunship/dropship_engine_near_loop1.wav'
local flights = {}

local function has(snd) return file.Exists('sound/' .. snd, 'GAME') end

-- Catmull-Rom through the points, sampled; the length along it for a steady speed
local function buildPath(pts)
	local out, dist = {pts[1]}, {0}
	local n = #pts
	for i = 1, n - 1 do
		local p0, p1, p2, p3 = pts[math.max(1, i - 1)], pts[i], pts[i + 1], pts[math.min(n, i + 2)]
		local steps = math.Clamp(math.ceil(p1:Distance(p2) / 64), 4, 64)
		for k = 1, steps do
			local t = k / steps
			local t2, t3 = t * t, t * t * t
			local v = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
			dist[#dist + 1] = dist[#dist] + v:Distance(out[#out])
			out[#out + 1] = v
		end
	end
	return out, dist
end

local function at(f, d)
	local pts, dist = f.pts, f.dist
	local i = f.seg or 1
	while i < #pts - 1 and dist[i + 1] < d do i = i + 1 end
	f.seg = i
	local seg = math.max(dist[i + 1] - dist[i], 0.001)
	local k = math.Clamp((d - dist[i]) / seg, 0, 1)
	return LerpVector(k, pts[i], pts[i + 1]), (pts[i + 1] - pts[i]):GetNormalized()
end

local function remove(f)
	if IsValid(f.ship) then f.ship:Remove() end
	if IsValid(f.box) then f.box:Remove() end
	if f.far then f.far:Stop() end
	if f.near then f.near:Stop() end
end

net.Receive('hla_dropship', function()
	local start = net.ReadFloat()
	local container = net.ReadBool()
	local speed = net.ReadUInt(12)
	local pts = {}
	for i = 1, net.ReadUInt(7) do pts[i] = net.ReadVector() end
	if #pts < 2 or not util.IsValidModel(MODEL) then return end
	local f = {start = start, speed = speed}
	f.pts, f.dist = buildPath(pts)
	f.len = f.dist[#f.dist]
	f.ship = ClientsideModel(MODEL, RENDERGROUP_OPAQUE)
	if not IsValid(f.ship) then return end
	f.ship:SetRenderBounds(Vector(-600, -600, -600), Vector(600, 600, 600))
	local seq = f.ship:LookupSequence(container and 'cargo_idle' or 'idle')
	if not seq or seq < 0 then seq = f.ship:LookupSequence('idle') end
	if seq and seq >= 0 then f.ship:ResetSequence(seq) end
	if container and util.IsValidModel(CONTAINER) then
		f.box = ClientsideModel(CONTAINER, RENDERGROUP_OPAQUE)
		if IsValid(f.box) then f.box:SetRenderBounds(Vector(-600, -600, -600), Vector(600, 600, 600)) end
	end
	if has(SND_FAR) then f.far = CreateSound(f.ship, SND_FAR) f.far:SetSoundLevel(140) f.far:PlayEx(0, 100) end
	if has(SND_NEAR) then f.near = CreateSound(f.ship, SND_NEAR) f.near:SetSoundLevel(100) f.near:PlayEx(0, 100) end
	f.yaw = nil
	flights[#flights + 1] = f
end)

hook.Add('Think', 'HLADropshipFly', function()
	if #flights == 0 then return end
	local eye = EyePos()
	for i = #flights, 1, -1 do
		local f = flights[i]
		local d = (CurTime() - f.start) * f.speed
		if d >= f.len or not IsValid(f.ship) then
			remove(f)
			table.remove(flights, i)
		else
			local pos, dir = at(f, math.max(d, 0))
			local ang = dir:Angle()
			-- the turn rate gives the bank, the climb a little pitch
			local yaw = ang.y
			local turn = f.yaw and math.AngleDifference(yaw, f.yaw) / math.max(FrameTime(), 0.001) or 0
			f.yaw = yaw
			f.roll = Lerp(math.min(FrameTime() * 2, 1), f.roll or 0, math.Clamp(turn * 0.35, -28, 28))
			local pitch = math.Clamp(math.NormalizeAngle(ang.p) * 0.5, -12, 12) + 4
			local a = Angle(pitch, yaw, f.roll)
			-- a soft hover bob
			pos = pos + Vector(0, 0, math.sin(CurTime() * 1.3 + i) * 6)
			f.ship:SetPos(pos)
			f.ship:SetAngles(a)
			f.ship:FrameAdvance()
			if IsValid(f.box) then f.box:SetPos(pos) f.box:SetAngles(a) end
			local dd = pos:Distance(eye)
			if f.far then f.far:ChangeVolume(math.Clamp(1 - dd / 9000, 0.15, 1), 0) end
			if f.near then f.near:ChangeVolume(math.Clamp(1 - dd / 2500, 0, 1), 0) end
		end
	end
end)

hook.Add('ShutDown', 'HLADropship', function() for _, f in ipairs(flights) do remove(f) end end)
