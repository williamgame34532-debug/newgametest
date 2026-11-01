AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include('shared.lua')

local POST = 'hla_forcefield_post'

local function hasPosts(self)
	return file.Exists(self.PostModel, 'GAME')
end

-- a post of the field. place = {edge, ang}: its inner edge at «edge», facing like the field «ang»;
-- or place = {pos, ang, raw = true}: exactly there (loaded from the map save)
local function makePost(field, side, place, s)
	local e = ents.Create(POST)
	if not IsValid(e) then return end
	e:SetSide(side)
	e:SetScale(s)
	e:SetPos(place[1])
	e:SetAngles(place[2])
	e:Spawn()
	e:Activate()
	if not place.raw then e:PlaceAt(place[1], place[2]) end
	e:SetField(field)
	return e
end

-- the field with its two posts (see makePost for L and R)
local function createWithPosts(L, R, scale, on)
	local f = ents.Create('hla_forcefield')
	if not IsValid(f) then return end
	f:SetPos(L[1])
	f:SetAngles(L[2])
	f:SetPosts(true)
	f.PostsSet = true
	f:Spawn()
	f:Activate()
	f:SetPostL(makePost(f, -1, L, scale))
	f:SetPostR(makePost(f, 1, R, scale))
	f:Follow(true)
	f:Switch(on ~= false, true)
	return f
end
ENT.CreateWithPosts = createWithPosts

function ENT:SpawnFunction(p, tr, cls)
	if not tr.Hit then return end
	local yaw = p:EyeAngles().y
	local ang = Angle(0, yaw, 0)
	local right = ang:Right()
	local MASK = MASK_SOLID_BRUSHONLY
	local down = util.TraceLine({start = tr.HitPos + tr.HitNormal * 4 + Vector(0, 0, 8), endpos = tr.HitPos - Vector(0, 0, 200), mask = MASK})
	local floor = down.HitPos
	local mid = floor + Vector(0, 0, 40)
	local l = util.TraceLine({start = mid, endpos = mid - right * 320, mask = MASK})
	local r = util.TraceLine({start = mid, endpos = mid + right * 320, mask = MASK})
	local up = util.TraceLine({start = floor + Vector(0, 0, 4), endpos = floor + Vector(0, 0, 260), mask = MASK})
	local w, center = 128, floor
	if l.Hit and r.Hit then
		w = l.HitPos:Distance(r.HitPos) - 2
		center = (l.HitPos + r.HitPos) / 2
		center.z = floor.z
	end
	local ceiling = up.Hit and (up.HitPos.z - floor.z - 1) or 1000
	if hasPosts(self) then
		-- posts 128 .. 192 high (lower only under a lower ceiling), standing inside the opening at its
		-- walls; the field between them. The left post is at local -Y (to the right of the view).
		local h = math.min(math.max(math.min(ceiling, self.DefaultHeight), self.MinHeight), ceiling, self.MaxHeight)
		local s = h / self.PostHeight
		local fw = math.max(24, w - self.PostWidth * s * 2)
		return createWithPosts({center + right * (fw / 2), ang}, {center - right * (fw / 2), ang}, s, true)
	end
	local e = ents.Create(cls)
	e:SetPos(center)
	e:SetAngles(ang)
	e:SetPosts(false)
	e.PostsSet = true
	e:SetWidth(math.Clamp(w, 24, 512))
	e:SetHeight(math.Clamp(math.min(ceiling, 112), 48, 256))
	e:Spawn()
	e:Activate()
	e:Switch(true, true)
	return e
end

function ENT:Initialize()
	self:SetModel('models/hunter/plates/plate.mdl')
	self:DrawShadow(false)
	if self:GetWidth() <= 0 then self:SetWidth(128) end
	if self:GetHeight() <= 0 then self:SetHeight(112) end
	self:Rebuild()
end

-- the solid field: a frozen physics slab (people and props do not pass while it is on)
function ENT:Rebuild()
	local mn, mx = self:Box()
	self:PhysicsInitBox(mn, mx)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetCollisionBounds(mn, mx)
	local ph = self:GetPhysicsObject()
	if IsValid(ph) then ph:SetMass(500) ph:EnableMotion(false) end
	self:ApplySolid()
end

-- off: people and props pass, the physgun and E still find it
function ENT:ApplySolid()
	self:SetCollisionGroup(self:GetOn() and COLLISION_GROUP_NONE or COLLISION_GROUP_DEBRIS)
end

-- with posts: the field stands between the inner edges of the two posts, wherever they are moved
function ENT:Follow(force)
	local L, R = self:GetPostL(), self:GetPostR()
	if not IsValid(L) or not IsValid(R) then
		if self.Followed then self:Remove() end -- a post was removed: the whole field goes
		return
	end
	self.Followed = true
	local a, b = L:InnerPoint(), R:InnerPoint()
	local flat = Vector(b.x - a.x, b.y - a.y, 0)
	local w = flat:Length()
	if w < 4 then return end
	local ph = math.min(L:PostHeightNow(), R:PostHeightNow())
	local pos = (a + b) * 0.5
	local fb, ft = self:FieldFracs()
	pos.z = math.min(a.z, b.z) + ph * fb
	local ang = Angle(0, flat:Angle().y - 90, 0) -- local +Y from the left post to the right one
	local h = ph * math.max(ft - fb, 0.05)
	local cur = self:GetAngles()
	local level = math.abs(cur.p) < 0.1 and math.abs(cur.r) < 0.1
	if not force and level and pos:DistToSqr(self:GetPos()) < 0.25 and math.abs(math.AngleDifference(ang.y, cur.y)) < 0.2
		and math.abs(w - self:GetWidth()) < 0.5 and math.abs(h - self:GetHeight()) < 0.5 then return end
	-- while a post is in the physgun the field only follows it with its look (10 times a second) and
	-- lets everything through; its solid body is built once, when the post is let go
	local carried = L.HLACarried or R.HLACarried
	if carried and not force then
		if (self.NextFollow or 0) > CurTime() then return end
		self.NextFollow = CurTime() + 0.1
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	end
	self:SetPos(pos)
	self:SetAngles(ang)
	self:SetWidth(w)
	self:SetHeight(h)
	if carried and not force then return end
	self:Rebuild()
end

-- turn the whole field with both posts around the middle of the field
function ENT:TurnAll(deg)
	local c = self:GetPos()
	for _, e in ipairs({self:GetPostL(), self:GetPostR()}) do
		if IsValid(e) then
			local rel = e:GetPos() - c
			rel:Rotate(Angle(0, deg, 0))
			local ang = e:GetAngles()
			ang:RotateAroundAxis(Vector(0, 0, 1), deg)
			e:SetPos(c + rel)
			e:SetAngles(ang)
			local ph = e:GetPhysicsObject()
			if IsValid(ph) then ph:EnableMotion(false) ph:Sleep() end
		end
	end
	if not self:GetPosts() then
		local ang = self:GetAngles()
		ang:RotateAroundAxis(Vector(0, 0, 1), deg)
		self:SetAngles(ang)
		self:Rebuild()
	end
	self:Follow(true)
end

-- the posts back to how a new field stands: facing along the field (the right one turned 180°)
function ENT:ResetPosts()
	local L, R = self:GetPostL(), self:GetPostR()
	if not IsValid(L) or not IsValid(R) then return end
	local a, b = L:InnerPoint(), R:InnerPoint()
	local flat = Vector(b.x - a.x, b.y - a.y, 0)
	local ang = Angle(0, flat:Angle().y - 90, 0)
	L:PlaceAt(a, ang)
	R:PlaceAt(b, ang)
	for _, e in ipairs({L, R}) do
		local ph = e:GetPhysicsObject()
		if IsValid(ph) then ph:EnableMotion(false) ph:Sleep() end
	end
	self:Follow(true)
end

function ENT:Switch(on, quiet)
	self:SetOn(on)
	self:SetSwitched(CurTime())
	self:ApplySolid()
	-- the lights of the posts: blue while on, red while off
	for _, e in ipairs({self:GetPostL(), self:GetPostR()}) do
		if IsValid(e) then e:SetLit(on) end
	end
	if not quiet then
		local s = self:Sound(on and 'start' or 'stop')
		if s then self:EmitSound(s, 75) end
	end
	if self.Loop then self.Loop:Stop() self.Loop = nil end
	if self.Hum then self.Hum:Stop() self.Hum = nil end
	if on then
		local s = self:Sound('loop')
		if s then
			self.Loop = CreateSound(self, s)
			self.Loop:SetSoundLevel(68)
			self.Loop:PlayEx(0.7, 100)
		end
		-- a low drone under it (HL:A content only)
		local hum = self:Sound('hum')
		if hum then
			self.Hum = CreateSound(self, hum)
			self.Hum:SetSoundLevel(60)
			self.Hum:PlayEx(0.35, 100)
		end
	end
end

function ENT:OnRemove()
	if self.Buzz then self.Buzz:Stop() end
	if self.Loop then self.Loop:Stop() end
	if self.Hum then self.Hum:Stop() end
	for _, e in ipairs({self:GetPostL(), self:GetPostR()}) do
		if IsValid(e) then e:Remove() end
	end
end

-- follow the posts; touching the field: pushed back with a crackle
function ENT:Think()
	if self:GetPosts() then
		self:Follow()
	else
		-- a field without posts stays level (a tilted one — old saves, physics — is put upright)
		local a = self:GetAngles()
		if (math.abs(a.p) > 0.1 or math.abs(a.r) > 0.1) and not self:IsPlayerHolding() then
			self:SetAngles(self:UprightAngles())
			self:Rebuild()
		end
	end
	local touching = 0
	if IsValid(self) and self:GetOn() then
		local mn, mx = self:FieldBox()
		mn, mx = mn - Vector(18, 0, 0), mx + Vector(18, 0, 0)
		for _, p in ipairs(player.GetAll()) do
			if p:Alive() and p:GetPos():DistToSqr(self:GetPos()) < (self:GetWidth() + 200) ^ 2 then
				local lp = self:WorldToLocal(p:GetPos() + Vector(0, 0, 36))
				if lp.x > mn.x and lp.x < mx.x and lp.y > mn.y and lp.y < mx.y and lp.z > mn.z - 40 and lp.z < mx.z then
					touching = touching + 1
					local side = lp.x >= 0 and 1 or -1
					p:SetVelocity(self:GetForward() * side * 220 + Vector(0, 0, 60) - p:GetVelocity() * 0.5)
					if (p.HLAFieldZap or 0) < CurTime() then
						p.HLAFieldZap = CurTime() + 0.6
						local s = self:Sound('touch')
						if s then self:EmitSound(s, 70, math.random(95, 105)) end
						local fx = EffectData()
						fx:SetOrigin(self:LocalToWorld(Vector(0, lp.y, math.Clamp(lp.z, 8, self:GetHeight() - 8))))
						fx:SetNormal(self:GetForward() * side)
						fx:SetMagnitude(1) fx:SetScale(1) fx:SetRadius(4)
						util.Effect('ElectricSpark', fx)
						p:ViewPunch(Angle(-3, math.Rand(-2, 2), 0))
					end
				end
			end
		end
	end
	-- the buzz while someone presses against the field (as in ix_forcefield)
	if touching > 0 then
		if not self.Buzz then
			self.Buzz = CreateSound(self, 'ambient/machines/combine_shield_touch_loop1.wav')
			self.Buzz:SetSoundLevel(70)
		end
		if not self.Buzz:IsPlaying() then self.Buzz:PlayEx(0.8, 100) end
		self.BuzzUntil = CurTime() + 0.3
	elseif self.Buzz and self.Buzz:IsPlaying() and CurTime() > (self.BuzzUntil or 0) then
		self.Buzz:FadeOut(0.5)
	end
	self:NextThink(CurTime() + 0.05)
	return true
end

-- E on the field: the player's look ray against the plane of the field (works on and off)
local function aimedField(p)
	local eye, dir = p:EyePos(), p:GetAimVector()
	local wall = util.TraceLine({start = eye, endpos = eye + dir * 200, filter = p, mask = MASK_SOLID_BRUSHONLY})
	local best, bestD
	for _, e in ipairs(ents.FindByClass('hla_forcefield')) do
		local hit = util.IntersectRayWithPlane(eye, dir, e:GetPos(), e:GetForward())
		if hit then
			local d = hit:Distance(eye)
			local lp = e:WorldToLocal(hit)
			if d <= e.UseRange and d <= wall.Fraction * 200 + 2 and math.abs(lp.y) <= e:GetWidth() / 2 and lp.z >= 0 and lp.z <= e:GetHeight()
				and (not bestD or d < bestD) then
				best, bestD = e, d
			end
		end
	end
	return best
end

-- the field you look at, also when looking at one of its posts
local function aimedAny(p)
	local f = aimedField(p)
	if IsValid(f) then return f end
	local e = p:GetEyeTrace().Entity
	if IsValid(e) and e:GetClass() == POST and IsValid(e:GetField()) then return e:GetField() end
end

-- the physgun (admins): the posts move and turn freely, the field follows them; a field without
-- HL:A posts moves itself. Let go — it freezes where it is. (High priority where ULib is installed,
-- so prop protection addons do not refuse ones loaded from the map save, which have no owner.)
hook.Add('PhysgunPickup', 'HLAForceField', function(p, e)
	if not IsValid(e) then return end
	local c = e:GetClass()
	if c == POST or (c == 'hla_forcefield' and not e:GetPosts()) then
		if not p:IsAdmin() then p:ChatPrint('Силовое поле двигают физганом только админы') return false end
		return true
	elseif c == 'hla_forcefield' then
		return false -- the field follows its posts: take a post
	end
end, HOOK_HIGH)
hook.Add('OnPhysgunPickup', 'HLAForceField', function(p, e)
	if IsValid(e) and e:GetClass() == POST then e.HLACarried = true end
end)
hook.Add('PhysgunDrop', 'HLAForceField', function(p, e)
	if not IsValid(e) or (e:GetClass() ~= POST and e:GetClass() ~= 'hla_forcefield') then return end
	if e:GetClass() == POST then
		e.HLACarried = nil
		-- the post stands up straight again (only its turn is kept), around its inner edge, so the
		-- field is never tilted or twisted by how the post was held
		local ip = e:InnerPoint()
		local ang = Angle(0, e:GetAngles().y, 0)
		e:SetAngles(ang)
		e:SetPos(ip - LocalToWorld(e.Inner * e:GetScale(), angle_zero, vector_origin, ang))
	end
	local ph = e:GetPhysicsObject()
	if IsValid(ph) then ph:EnableMotion(false) ph:Sleep() end
	if e:GetClass() == POST and IsValid(e:GetField()) then e:GetField():Follow(true) end
end)
hook.Add('OnPhysgunReload', 'HLAForceField', function(_, p)
	local e = p:GetEyeTrace().Entity
	if IsValid(e) and (e:GetClass() == 'hla_forcefield' or e:GetClass() == POST) then return false end -- R does not unfreeze it
end)

hook.Add('KeyPress', 'HLAForceField', function(p, key)
	if key ~= IN_USE or not p:Alive() or p.HLAInMenu then return end
	local e = aimedField(p)
	if not IsValid(e) or (e.NextSwitch or 0) > CurTime() then return end
	if hook.Run('HLAForceFieldCanSwitch', p, e) == false then return end
	e.NextSwitch = CurTime() + 1
	e:Switch(not e:GetOn())
end)

---------------------------------------------------------------------------------------------------
-- fields placed by admins are remembered per map (posts: their own places and turns)
local function path() return 'hlalyx/forcefields_' .. game.GetMap() .. '.txt' end
local function v3(v) return {v.x, v.y, v.z} end
local function load()
	for _, s in ipairs(util.JSONToTable(file.Read(path(), 'DATA') or '') or {}) do
		if s.L and s.R then
			local f = createWithPosts({Vector(s.L[1][1], s.L[1][2], s.L[1][3]), Angle(s.L[2][1], s.L[2][2], s.L[2][3]), raw = true},
				{Vector(s.R[1][1], s.R[1][2], s.R[1][3]), Angle(s.R[2][1], s.R[2][2], s.R[2][3]), raw = true}, s.scale or 1, s.on)
			if IsValid(f) then
				f:SetBottomF(s.bottom or 0) f:SetTopF(s.top or 0) f:SetMat(s.mat or 0) f:Follow(true)
				if IsValid(f:GetPostL()) then f:GetPostL():SetSkinMode(s.skinL or 0) end
				if IsValid(f:GetPostR()) then f:GetPostR():SetSkinMode(s.skinR or 0) end
			end
		elseif s[1] then
			local e = ents.Create('hla_forcefield')
			if IsValid(e) then
				e:SetPos(Vector(s[1], s[2], s[3])) e:SetAngles(Angle(s[9] or 0, s[4], s[10] or 0))
				e:SetWidth(s[5]) e:SetHeight(s[6])
				e:SetPosts(false) e.PostsSet = true
				e:Spawn() e:Activate()
				e:Switch(s[7] ~= false, true)
			end
		end
	end
end
hook.Add('InitPostEntity', 'HLAForceFields', load)
hook.Add('PostCleanupMap', 'HLAForceFields', load)

concommand.Add('hla_save_forcefields', function(p)
	if IsValid(p) and not p:IsAdmin() then return end
	local list = {}
	for _, e in ipairs(ents.FindByClass('hla_forcefield')) do
		local L, R = e:GetPostL(), e:GetPostR()
		if IsValid(L) and IsValid(R) then
			local la, ra = L:GetAngles(), R:GetAngles()
			list[#list + 1] = {L = {v3(L:GetPos()), {la.p, la.y, la.r}}, R = {v3(R:GetPos()), {ra.p, ra.y, ra.r}}, scale = L:GetScale(), on = e:GetOn(),
				skinL = L:GetSkinMode(), skinR = R:GetSkinMode(), bottom = e:GetBottomF(), top = e:GetTopF(), mat = e:GetMat()}
		else
			local pos, ang = e:GetPos(), e:GetAngles()
			list[#list + 1] = {pos.x, pos.y, pos.z, ang.y, e:GetWidth(), e:GetHeight(), e:GetOn(), false, ang.p, ang.r}
		end
	end
	file.CreateDir('hlalyx')
	file.Write(path(), util.TableToJSON(list))
	local msg = 'Сохранено силовых полей: ' .. #list
	if IsValid(p) then p:ChatPrint(msg) else print(msg) end
end)
concommand.Add('hla_clear_forcefields', function(p)
	if IsValid(p) and not p:IsAdmin() then return end
	file.Delete(path())
	if IsValid(p) then p:ChatPrint('Сохранённые силовые поля для карты удалены') end
end)
-- admin: height of the posts of the field you look at (128 .. 192): hla_forcefield_size <height>
-- (a field without HL:A posts: hla_forcefield_size <width> <height>)
concommand.Add('hla_forcefield_size', function(p, _, a)
	if not IsValid(p) or not p:IsAdmin() then return end
	local e = aimedAny(p)
	if not IsValid(e) then p:ChatPrint('Посмотрите на силовое поле или его стойку') return end
	if e:GetPosts() then
		local h = math.Clamp(tonumber(a[1]) or 160, 64, 256)
		for _, post in ipairs({e:GetPostL(), e:GetPostR()}) do
			if IsValid(post) then post:SetScale(h / e.PostHeight) post:Setup() end
		end
		e:Follow(true)
	else
		e:SetWidth(math.Clamp(tonumber(a[1]) or e:GetWidth(), 16, 1024))
		e:SetHeight(math.Clamp(tonumber(a[2]) or e:GetHeight(), 32, 256))
		e:Rebuild()
	end
end)

---------------------------------------------------------------------------------------------------
-- the settings menu of the adjuster (admins): every change comes here and is checked
util.AddNetworkString('hla_ff_set')
local function movePosts(f, delta)
	for _, e in ipairs({f:GetPostL(), f:GetPostR()}) do
		if IsValid(e) then
			e:SetPos(e:GetPos() + delta)
			local ph = e:GetPhysicsObject()
			if IsValid(ph) then ph:EnableMotion(false) ph:Sleep() end
		end
	end
	if not f:GetPosts() then f:SetPos(f:GetPos() + delta) f:Rebuild() end
	f:Follow(true)
end

net.Receive('hla_ff_set', function(_, p)
	if not IsValid(p) or not p:IsAdmin() then return end
	local f = net.ReadEntity()
	local what = net.ReadString()
	if IsValid(f) and f:GetClass() == POST then f = f:GetField() end
	if not IsValid(f) or f:GetClass() ~= 'hla_forcefield' then return end
	if f:GetPos():DistToSqr(p:GetPos()) > 2000 * 2000 then return end
	local L, R = f:GetPostL(), f:GetPostR()
	if what == 'height' then
		local h = math.Clamp(net.ReadFloat(), 48, 320)
		for _, e in ipairs({L, R}) do if IsValid(e) then e:SetScale(h / f.PostHeight) e:Setup() end end
		if not f:GetPosts() then f:SetHeight(h) f:Rebuild() end
	elseif what == 'bottom' then f:SetBottomF(math.Clamp(net.ReadFloat(), 0.001, 0.6))
	elseif what == 'top' then f:SetTopF(math.Clamp(net.ReadFloat(), 0.3, 1.2))
	elseif what == 'width' then
		local w = math.Clamp(net.ReadFloat(), 16, 1500)
		if IsValid(L) and IsValid(R) then
			local a, b = L:InnerPoint(), R:InnerPoint()
			local dir = Vector(b.x - a.x, b.y - a.y, 0):GetNormalized()
			R:SetPos(R:GetPos() + (a + dir * w - b) * Vector(1, 1, 0))
			local ph = R:GetPhysicsObject()
			if IsValid(ph) then ph:EnableMotion(false) ph:Sleep() end
		else
			f:SetWidth(w) f:Rebuild()
		end
	elseif what == 'move' then
		-- along the field's own axes: x across the field, y along it, z up
		local d = net.ReadVector()
		movePosts(f, f:GetForward() * d.x + f:GetRight() * -d.y + Vector(0, 0, d.z))
	elseif what == 'turn' then f:TurnAll(math.Clamp(net.ReadFloat(), -180, 180))
	elseif what == 'turnpost' then
		local side, deg = net.ReadInt(3), math.Clamp(net.ReadFloat(), -180, 180)
		local e = side < 0 and L or R
		if IsValid(e) then e:TurnAroundInner(deg) end
	elseif what == 'skin' then
		local side, mode = net.ReadInt(3), net.ReadUInt(3) % 4
		for _, e in ipairs({L, R}) do
			if IsValid(e) and (side == 0 or (side < 0 and e == L) or (side > 0 and e == R)) then e:SetSkinMode(mode) end
		end
	elseif what == 'mat' then f:SetMat(net.ReadUInt(3) % 4)
	elseif what == 'on' then f:Switch(net.ReadBool())
	elseif what == 'reset' then f:ResetPosts()
	elseif what == 'remove' then f:Remove() return
	elseif what == 'save' then p:ConCommand('hla_save_forcefields') return
	end
	f:Follow(true)
end)

-- the field itself is not taken by the physgun / gravity gun when it has posts (it moves with them);
-- a field without posts can be carried, and is put level again when let go
hook.Add('PhysgunPickup', 'HLAForceFieldLevel', function(p, e)
	if e.IsHLAForceField and e:GetPosts() then return false end
end)
hook.Add('GravGunPickupAllowed', 'HLAForceFieldLevel', function(p, e)
	if e.IsHLAForceField then return false end
end)
hook.Add('PhysgunDrop', 'HLAForceFieldLevel', function(p, e)
	if not e.IsHLAForceField then return end
	e:SetAngles(e:UprightAngles())
	local ph = e:GetPhysicsObject()
	if IsValid(ph) then ph:EnableMotion(false) end
	e:Rebuild()
end)
