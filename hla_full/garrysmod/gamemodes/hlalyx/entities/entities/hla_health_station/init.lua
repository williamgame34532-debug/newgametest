AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include('shared.lua')

local ST = HLA.Station
local SND = 'hla/health_station/'

local function rnd(list) return SND .. list[math.random(#list)] end
local NEEDLES = {'combine_tech_needle_impacts_01.wav', 'combine_tech_needle_impacts_02.wav', 'combine_tech_needle_impacts_03.wav', 'combine_tech_needle_impacts_04.wav'}
local PAIN = {'health_station_grub_pain_01.mp3', 'health_station_grub_pain_02.mp3', 'health_station_grub_pain_03.mp3', 'health_station_grub_pain_04.mp3'}
local BREATH = {'health_station_grub_breath_01.mp3', 'health_station_grub_breath_02.mp3', 'health_station_grub_breath_03.mp3', 'health_station_grub_breath_04.mp3'}
local SLIDES = {'combine_tech_long_slide_sm_01.wav', 'combine_tech_long_slide_sm_02.wav', 'combine_tech_long_slide_sm_03.wav'}

-- always on a wall: aimed at the floor or the ceiling -> the wall straight ahead
function ENT:SpawnFunction(p, tr, class)
	if not tr.Hit then return end
	if math.abs(tr.HitNormal.z) > 0.3 then
		local fwd = Angle(0, p:EyeAngles().y, 0):Forward()
		tr = util.TraceLine({start = p:EyePos(), endpos = p:EyePos() + fwd * 400, filter = p, mask = MASK_SOLID_BRUSHONLY})
		if not tr.Hit or math.abs(tr.HitNormal.z) > 0.3 then
			p:ChatPrint('Станцию нужно ставить на стену: посмотри на стену.')
			return
		end
	end
	local n = Vector(tr.HitNormal.x, tr.HitNormal.y, 0):GetNormalized()
	local e = ents.Create(class)
	e:SetPos(tr.HitPos + n * 2)   -- the back of the case is at x = -1.6 (x1.25 scale)
	e:SetAngles(n:Angle())
	e:Spawn()
	e:Activate()
	return e
end

local function part(self, name, seq)
	local m = ents.Create('prop_dynamic')
	m:SetModel(ST.Dir .. name .. '.mdl')
	m:SetPos(self:GetPos())
	m:SetAngles(self:GetAngles())
	m:SetParent(self)
	m:SetKeyValue('DefaultAnim', seq)
	m:Spawn()
	m:SetSolid(SOLID_NONE)
	m:DrawShadow(false)
	self:DeleteOnRemove(m)
	return m
end

-- one-shot animation, then hold a stop pose (a one-frame looping sequence from the QC)
local function anim(m, seq, hold)
	if not IsValid(m) then return end
	m:Fire('SetDefaultAnimation', hold)
	m:Fire('SetAnimation', seq)
	m:Fire('SetPlaybackRate', '1')
end

-- a sequence frozen at a given point (gauge level, vial flush)
local function freeze(m, seq, f)
	if not IsValid(m) then return end
	local id = m:LookupSequence(seq)
	if not id or id < 0 then return end
	if m:GetSequence() ~= id then m:ResetSequence(id) end
	m:SetPlaybackRate(0)
	m:SetCycle(math.Clamp(f, 0, 0.995))
end

function ENT:Initialize()
	if not util.IsValidModel(ST.Dir .. 'charger.mdl') then
		local msg = '[HLA] Модели станции первой помощи не скомпилированы: modelsrc/health_station/compile.bat'
		ErrorNoHalt(msg .. '\n')
		for _, p in ipairs(player.GetAll()) do if p:IsAdmin() then p:ChatPrint(msg) end end
	end
	self:SetModel(ST.Dir .. 'charger.mdl')
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	local ph = self:GetPhysicsObject()
	if IsValid(ph) then ph:EnableMotion(false) end
	-- the case: 'deploy' opens the lid (needles out, the hand grip drops) — frame 0 is the closed station.
	-- Think drives it: open while someone heals, closed otherwise
	self:ResetSequence(self:LookupSequence('deploy'))
	self:SetPlaybackRate(0)
	self:SetCycle(0)
	self.OpenF = 0
	self.Internals = part(self, 'charger_internals', 'idle_retracted')
	self.Pad = part(self, 'charger_pad', 'rest')
	self:SetGauge(part(self, 'charger_gauge', 'drained'))
end

function ENT:UpdateGauge()
	local g = self:GetGauge()
	if not IsValid(g) then return end
	if not self:GetHasVial() then
		if g:GetSequence() ~= g:LookupSequence('drained') then g:ResetSequence(g:LookupSequence('drained')) end
		return
	end
	-- idle_full runs from full (frame 0) to empty (last frame): the level of the vial
	freeze(g, 'idle_full', 1 - self:GetCharge() / ST.VialHP)
end

-- from the inventory (sv_inventory.lua 'place')
function ENT:AcceptItem(p, id)
	if id ~= 'health_vial' or self:GetHasVial() then return false end
	local g = self:GetGauge()
	local v = ents.Create('prop_dynamic')
	v:SetModel(ST.Dir .. 'health_vial.mdl')
	local idle = 'health_vial_larva_idle_' .. math.random(1, 7) .. '_anim'
	v:SetKeyValue('DefaultAnim', idle)
	v:Spawn()
	v:SetSolid(SOLID_NONE)
	local pos, ang = self:VialSlot()
	v:SetPos(pos or self:WorldSpaceCenter())
	v:SetAngles(ang or self:GetAngles())
	v:SetParent(IsValid(g) and g or self)
	self:DeleteOnRemove(v)
	self.Vial = v
	self:SetVial(v)
	self.VialIdle = idle
	self:SetHasVial(true)
	self:SetCharge(ST.VialHP)
	anim(v, 'health_vial_deploy_anim', idle)
	self:UpdateGauge()
	self:EmitSound(SND .. 'combine_health_station_powerup_01.wav', 65)
	self:EmitSound(rnd(BREATH), 55)
	return true
end

function ENT:Eject(p)
	if not self:GetHasVial() then return end
	self:StopHeal()
	local v = self.Vial
	local pos, ang = IsValid(v) and v:GetPos() or self:WorldSpaceCenter(), IsValid(v) and v:GetAngles() or self:GetAngles()
	if IsValid(v) then v:Remove() end
	self.Vial = nil
	self:SetHasVial(false)
	self:SetCharge(0)
	-- the empty vial drops out and goes away later
	local d = ents.Create('prop_physics')
	d:SetModel(ST.Dir .. 'health_vial.mdl')
	d:SetPos(pos + self:GetForward() * 3)
	d:SetAngles(ang)
	d:Spawn()
	d:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	freeze(d, 'health_vial_larva_flush_finished_idle', 0)
	local ph = d:GetPhysicsObject()
	if IsValid(ph) then ph:Wake() ph:SetVelocity(self:GetForward() * 60 + Vector(0, 0, 40)) end
	SafeRemoveEntityDelayed(d, 20)
	self:UpdateGauge()
	self:EmitSound(rnd(SLIDES), 60)
end

-- holding E: needles prepare and pump (internals), the hand pad steps out, the larva is drained
function ENT:StartHeal(p)
	if IsValid(self:GetHealer()) or not self:GetHasVial() or self:GetCharge() <= 0 then return end
	if p:Health() >= p:GetMaxHealth() then return end
	self:SetHealer(p)
	self.HealAcc = 0
	self.HealSerial = (self.HealSerial or 0) + 1
	local serial = self.HealSerial
	anim(self.Internals, 'prepare_inject', 'inject_loop')
	anim(self.Pad, 'step01', 'extended')
	timer.Simple(0.7, function()
		if IsValid(self) and self.HealSerial == serial and IsValid(self:GetHealer()) then anim(self.Pad, 'step02', 'extended') end
	end)
	self:EmitSound(rnd(NEEDLES), 65)
	self:EmitSound(rnd(PAIN), 60)
	self.Loop = self.Loop or CreateSound(self, SND .. 'health_station_healing_lp_01.wav')
	self.Loop:Play()
	self.NextPain = CurTime() + 1.5
	freeze(self.Vial, 'health_vial_larva_flush_anim', 1 - self:GetCharge() / ST.VialHP)
end

function ENT:StopHeal()
	if not IsValid(self:GetHealer()) then return end
	self.HealSerial = (self.HealSerial or 0) + 1
	self:SetHealer(NULL)
	if self.Loop then self.Loop:Stop() end
	anim(self.Internals, 'retract', 'idle_retracted')
	anim(self.Pad, 'retract', 'rest')
	self:UpdateGauge()
	if not IsValid(self.Vial) then return end
	if self:GetCharge() <= 0 then
		self:EmitSound(SND .. 'health_station_grub_flush_01.mp3', 62)
		anim(self.Vial, 'health_vial_larva_flush_finished_idle', 'health_vial_larva_flush_finished_idle')
	else
		anim(self.Vial, self.VialIdle or 'health_vial_larva_idle_1_anim', self.VialIdle or 'health_vial_larva_idle_1_anim')
	end
end

local function aimsAt(p, self)
	local tr = p:GetEyeTrace()
	local e = tr.Entity
	return IsValid(e) and (e == self or e:GetParent() == self or (IsValid(e:GetParent()) and e:GetParent():GetParent() == self))
		and tr.HitPos:DistToSqr(p:EyePos()) < ST.UseRange * ST.UseRange
end
ENT.AimedBy = aimsAt

local OPEN_TIME = 1.6 -- seconds to open or close the case (deploy is 3.3 s in HL:A)

function ENT:Think()
	local want = IsValid(self:GetHealer()) and 1 or 0
	if self.OpenF ~= want then
		self.OpenF = math.Approach(self.OpenF or 0, want, FrameTime() / OPEN_TIME)
		self:SetPlaybackRate(0)
		self:SetCycle(self.OpenF)
	end
	local p = self:GetHealer()
	if IsValid(p) then
		if not p:Alive() or not p:KeyDown(IN_USE) or not aimsAt(p, self) or p:Health() >= p:GetMaxHealth() or self:GetCharge() <= 0 then
			self:StopHeal()
		else
			local dt = engine.TickInterval()
			self.HealAcc = (self.HealAcc or 0) + ST.HealRate * dt
			local whole = math.floor(self.HealAcc)
			if whole >= 1 then
				self.HealAcc = self.HealAcc - whole
				whole = math.min(whole, p:GetMaxHealth() - p:Health(), math.ceil(self:GetCharge()))
				p:SetHealth(p:Health() + whole)
				self:SetCharge(math.max(0, self:GetCharge() - whole))
			end
			freeze(self.Vial, 'health_vial_larva_flush_anim', 1 - self:GetCharge() / ST.VialHP)
			self:UpdateGauge()
			if CurTime() > (self.NextPain or 0) then
				self.NextPain = CurTime() + math.Rand(1.2, 2.2)
				self:EmitSound(rnd(PAIN), 55)
			end
		end
	end
	self:NextThink(CurTime())
	return true
end

function ENT:OnRemove()
	if self.Loop then self.Loop:Stop() end
end

-- E: tap on an empty vial ejects it, hold heals
hook.Add('KeyPress', 'HLAHealthStation', function(p, k)
	if k ~= IN_USE or not p:Alive() or p.HLAInMenu then return end
	for _, e in ipairs(ents.FindInSphere(p:EyePos(), HLA.Station.UseRange + 40)) do
		if e.IsHealthStation and aimsAt(p, e) then
			if e:GetHasVial() and e:GetCharge() <= 0 then e:Eject(p) else e:StartHeal(p) end
			return
		end
	end
end)

-- physgun: anyone allowed to move props can move the station freely, through walls too; dropped = frozen in place
hook.Add('OnPhysgunPickup', 'HLAHealthStation', function(p, e)
	if not e.IsHealthStation then return end
	local ph = e:GetPhysicsObject()
	if IsValid(ph) then ph:EnableCollisions(false) ph:EnableGravity(false) end
end)
hook.Add('PhysgunDrop', 'HLAHealthStation', function(p, e)
	if not e.IsHealthStation then return end
	local ph = e:GetPhysicsObject()
	if IsValid(ph) then ph:EnableCollisions(true) ph:EnableMotion(false) ph:Sleep() end
end)
