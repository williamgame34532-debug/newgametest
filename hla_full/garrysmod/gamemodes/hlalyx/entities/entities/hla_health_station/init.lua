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

function ENT:SpawnFunction(p, tr, class)
	if not tr.Hit then return end
	local e = ents.Create(class)
	local n = tr.HitNormal
	local ang = (math.abs(n.z) > 0.7) and Angle(0, p:EyeAngles().y + 180, 0) or n:Angle()
	ang.p = 0
	e:SetPos(tr.HitPos + n * 1.6 + (math.abs(n.z) > 0.7 and Vector(0, 0, 50) or vector_origin))
	e:SetAngles(ang)
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
	m:SetKeyValue('DefaultAnim', seq or '')
	m:Spawn()
	m:SetSolid(SOLID_NONE)
	m:DrawShadow(false)
	self:DeleteOnRemove(m)
	return m
end

local function anim(m, seq, after)
	if not IsValid(m) then return end
	if after then m:Fire('SetDefaultAnimation', after) end
	m:Fire('SetAnimation', seq)
end

function ENT:Initialize()
	if not util.IsValidModel(ST.Dir .. 'charger.mdl') then
		local msg = '[HLA] Модели станции первой помощи не скомпилированы: modelsrc/health_station/compile.bat'
		ErrorNoHalt(msg .. '\n')
		for _, p in ipairs(player.GetAll()) do if p:IsAdmin() then p:ChatPrint(msg) end end
	end
	self:SetModel(ST.Dir .. 'charger.mdl')
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)
	local ph = self:GetPhysicsObject()
	if IsValid(ph) then ph:EnableMotion(false) end
	self:ResetSequence(self:LookupSequence('idle'))
	self.Internals = part(self, 'charger_internals', 'idle_retracted')
	self.Pad = part(self, 'charger_pad', 'retract')
	self:SetGauge(part(self, 'charger_gauge', 'empty'))
end

-- from the inventory (sv_inventory.lua 'place')
function ENT:AcceptItem(p, id)
	if id ~= 'health_vial' or self:GetHasVial() then return false end
	local g = self:GetGauge()
	local v = ents.Create('prop_dynamic')
	v:SetModel(ST.Dir .. 'health_vial.mdl')
	v:SetKeyValue('DefaultAnim', 'health_vial_larva_idle_' .. math.random(1, 7) .. '_anim')
	v:Spawn()
	v:SetSolid(SOLID_NONE)
	local att = IsValid(g) and g:LookupAttachment('health_vial_attach') or 0
	v:SetParent(IsValid(g) and g or self, att > 0 and att or nil)
	v:SetLocalPos(vector_origin)
	v:SetLocalAngles(angle_zero)
	self:DeleteOnRemove(v)
	self.Vial = v
	self:SetHasVial(true)
	self:SetCharge(ST.VialHP)
	anim(v, 'health_vial_deploy_anim', 'health_vial_larva_idle_' .. math.random(1, 7) .. '_anim')
	anim(self, 'deploy')
	anim(g, 'idle_full', 'idle_full')
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
	-- the empty vial drops out and breaks away later
	local d = ents.Create('prop_physics')
	d:SetModel(ST.Dir .. 'health_vial.mdl')
	d:SetPos(pos + self:GetForward() * 3)
	d:SetAngles(ang)
	d:Spawn()
	d:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	d:Fire('SetAnimation', 'health_vial_larva_flush_finished_idle')
	local ph = d:GetPhysicsObject()
	if IsValid(ph) then ph:Wake() ph:SetVelocity(self:GetForward() * 60 + Vector(0, 0, 40)) end
	SafeRemoveEntityDelayed(d, 20)
	anim(self:GetGauge(), 'empty', 'empty')
	self:EmitSound(rnd(SLIDES), 60)
end

function ENT:StartHeal(p)
	if IsValid(self:GetHealer()) or not self:GetHasVial() or self:GetCharge() <= 0 then return end
	if p:Health() >= p:GetMaxHealth() then return end
	self:SetHealer(p)
	self.HealAcc = 0
	anim(self, 'prepare_inject', 'inject_loop')
	anim(self.Internals, 'prepare_inject', 'inject_loop')
	anim(self.Pad, 'step01', 'step02')
	anim(self:GetGauge(), 'charging', 'charging')
	self:EmitSound(rnd(NEEDLES), 65)
	self:EmitSound(rnd(PAIN), 60)
	self.Loop = self.Loop or CreateSound(self, SND .. 'health_station_healing_lp_01.wav')
	self.Loop:Play()
	self.NextPain = CurTime() + 1.5
	if IsValid(self.Vial) then self.Vial:Fire('SetAnimation', 'health_vial_larva_flush_anim') self.Vial:Fire('SetPlaybackRate', '0') end
end

function ENT:StopHeal()
	if not IsValid(self:GetHealer()) and not self.Loop then return end
	self:SetHealer(NULL)
	if self.Loop then self.Loop:Stop() end
	anim(self, 'retract', 'idle')
	anim(self.Internals, 'retract', 'idle_retracted')
	anim(self.Pad, 'retract', 'retract')
	anim(self:GetGauge(), self:GetCharge() > 0 and 'idle_full' or 'empty', self:GetCharge() > 0 and 'idle_full' or 'empty')
	if self:GetCharge() <= 0 then
		self:EmitSound(SND .. 'health_station_grub_flush_01.mp3', 62)
		if IsValid(self.Vial) then self.Vial:Fire('SetDefaultAnimation', 'health_vial_larva_flush_finished_idle') self.Vial:Fire('SetAnimation', 'health_vial_larva_flush_finished_idle') end
	end
end

local function aimsAt(p, self)
	local tr = p:GetEyeTrace()
	local e = tr.Entity
	return IsValid(e) and (e == self or e:GetParent() == self or (IsValid(e:GetParent()) and e:GetParent():GetParent() == self))
		and tr.HitPos:DistToSqr(p:EyePos()) < ST.UseRange * ST.UseRange
end
ENT.AimedBy = aimsAt

function ENT:Think()
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
			if IsValid(self.Vial) then self.Vial:SetCycle(1 - self:GetCharge() / ST.VialHP) end
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
