AddCSLuaFile()

-- A place where the infestation breaks out (sh_cwu.lua, the ICU of the CWU). Clean it is invisible
-- (admins with the physics gun or the tool gun see a mark). Now and then it grows (sv_cwu.lua): a
-- pulsing sickly-green growth on the ground with spores in the air; who stands in the spores without
-- a gas mask chokes (damage). The disinfection control of the CWU burns it out with a disinfector: E.

ENT.Type = "anim"
ENT.PrintName = "Очаг заражения (ГСР)"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

local RADIUS = 130

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Active")
	self:NetworkVar("Float", 0, "Since")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_infestation")

		entity:SetPos(trace.HitPos + Vector(0, 0, 2))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel("models/props_junk/PopCan01a.mdl")
		self:PhysicsInitBox(Vector(-RADIUS * 0.5, -RADIUS * 0.5, 0), Vector(RADIUS * 0.5, RADIUS * 0.5, 24))
		self:SetCollisionBounds(Vector(-RADIUS * 0.5, -RADIUS * 0.5, 0), Vector(RADIUS * 0.5, RADIUS * 0.5, 24))
		self:SetSolid(SOLID_BBOX)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:SetUseType(SIMPLE_USE)
		self:DrawShadow(false)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	function ENT:SetState(bActive)
		self:SetActive(bActive)
		self:SetSince(CurTime())

		if (self.loop) then
			self.loop:Stop()
			self.loop = nil
		end

		if (bActive) then
			self.loop = CreateSound(self, "ambient/levels/caves/cave_howl_loop1.wav")
			self.loop:SetSoundLevel(62)
			self.loop:PlayEx(0.25, 70)
		end
	end

	function ENT:Use(client)
		if (IsValid(client) and client:IsPlayer() and self:GetActive()) then
			NW.cwu.Disinfect(client, self)
		end
	end

	-- the spores: who breathes them without a gas mask
	function ENT:Think()
		if (self:GetActive()) then
			for _, client in ipairs(ents.FindInSphere(self:GetPos(), RADIUS)) do
				if (client:IsPlayer() and client:Alive() and !client:GetNW2Bool("nwObserver", false) and
					!NW.zones.Protected(client)) then
					local damage = DamageInfo()

					damage:SetDamage(3)
					damage:SetDamageType(DMG_NERVEGAS)
					damage:SetAttacker(self)
					damage:SetInflictor(self)
					client:TakeDamageInfo(damage)
					client:EmitSound("player/pl_pain" .. math.random(5, 7) .. ".wav", 60)
				end
			end
		end

		self:NextThink(CurTime() + 2)

		return true
	end

	function ENT:OnRemove()
		if (self.loop) then
			self.loop:Stop()
		end
	end

	timer.Simple(0, function()
		NW.persist.Register("nw_infestation")
	end)

	return
end

-- ------------------------------------------------------------------ client --
local BLOB = Material("particle/particle_glow_04_additive")
local MARK = Material("sprites/light_glow02_add")
local TOOLS = {weapon_physgun = true, gmod_tool = true}

function ENT:Initialize()
	self:SetRenderBounds(Vector(-RADIUS, -RADIUS, -10), Vector(RADIUS, RADIUS, 80))
	self.blobs = {}

	for i = 1, 14 do
		local angle = math.Rand(0, math.pi * 2)
		local distance = math.Rand(0, RADIUS * 0.55)

		self.blobs[i] = {offset = Vector(math.cos(angle) * distance, math.sin(angle) * distance, 2),
			size = math.Rand(18, 46), phase = math.Rand(0, 6)}
	end
end

function ENT:Draw()
end

function ENT:DrawTranslucent()
	local client = LocalPlayer()

	if (!self:GetActive()) then
		local weapon = client:GetActiveWeapon()

		if (client:IsAdmin() and (client:GetNW2Bool("nwObserver", false) or (IsValid(weapon) and TOOLS[weapon:GetClass()]))) then
			render.SetMaterial(MARK)
			render.DrawSprite(self:GetPos() + Vector(0, 0, 8), 24, 24, Color(120, 220, 90, 200))
		end

		return
	end

	local grow = math.Clamp((CurTime() - self:GetSince()) / 6, 0.15, 1)

	render.SetMaterial(BLOB)

	for _, blob in ipairs(self.blobs or {}) do
		local pulse = 0.8 + 0.2 * math.sin(CurTime() * 1.6 + blob.phase)
		local size = blob.size * grow * pulse

		render.DrawQuadEasy(self:GetPos() + blob.offset * grow, Vector(0, 0, 1), size, size,
			Color(120, 200, 60, 150), blob.phase * 40)
	end
end

function ENT:Think()
	if (!self:GetActive() or LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 1600 * 1600) then
		return
	end

	-- spores drifting up
	if ((self.nextSpore or 0) < CurTime()) then
		self.nextSpore = CurTime() + 0.12

		local emitter = ParticleEmitter(self:GetPos())

		if (emitter) then
			local spore = emitter:Add("particle/particle_smokegrenade",
				self:GetPos() + Vector(math.Rand(-RADIUS, RADIUS) * 0.5, math.Rand(-RADIUS, RADIUS) * 0.5, 6))

			if (spore) then
				spore:SetVelocity(Vector(math.Rand(-6, 6), math.Rand(-6, 6), math.Rand(8, 22)))
				spore:SetDieTime(math.Rand(2.5, 4))
				spore:SetStartAlpha(50)
				spore:SetEndAlpha(0)
				spore:SetStartSize(4)
				spore:SetEndSize(math.Rand(24, 40))
				spore:SetColor(140, 190, 90)
				spore:SetRoll(math.Rand(0, 360))
				spore:SetAirResistance(30)
			end

			emitter:Finish()
		end
	end

	local light = DynamicLight(self:EntIndex())

	if (light) then
		light.pos = self:GetPos() + Vector(0, 0, 20)
		light.r, light.g, light.b = 110, 200, 60
		light.brightness = 0.8 + 0.3 * math.sin(CurTime() * 1.6)
		light.decay = 1000
		light.size = 220
		light.dietime = CurTime() + 0.2
	end
end
