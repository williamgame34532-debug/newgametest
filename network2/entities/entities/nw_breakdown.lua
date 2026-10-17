AddCSLuaFile()

-- A place where the city breaks (sh_cwu.lua): a pipe, a power box or a panel of the Combine. Now and
-- then it breaks by itself (sv_cwu.lua): the pipe hisses with steam, the box sparks, the panel
-- flickers and crackles; the CWU sees it at its terminal and on the HUD. A worker of the CWU with a
-- toolkit fixes it: E (the time shrinks with Инженерия). Admins: Alt + E - the next kind.

ENT.Type = "anim"
ENT.PrintName = "Точка поломки (ГСР)"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Kinds = {
	{id = "pipe", name = "Утечка в трубе", model = "models/props_pipes/valve002.mdl"},
	{id = "power", name = "Электрощит", model = "models/props_lab/powerbox01a.mdl"},
	{id = "panel", name = "Панель Альянса", model = "models/props_combine/combine_interface002.mdl"}
}

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Broken")
	self:NetworkVar("Int", 0, "Kind")
	self:NetworkVar("Float", 0, "BrokenSince")
end

function ENT:KindData()
	return self.Kinds[math.Clamp(self:GetKind(), 1, #self.Kinds)]
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_breakdown")

		entity:SetPos(trace.HitPos + trace.HitNormal * 4)
		entity:SetAngles(trace.HitNormal:Angle())
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetKind(math.max(1, self:GetKind()))
		self:ApplyModel()
		self:SetUseType(SIMPLE_USE)
	end

	function ENT:ApplyModel()
		local model = self.nwModel or self:KindData().model

		self:SetModel(util.IsValidModel(model) and model or "models/props_lab/powerbox01a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	function ENT:SetState(bBroken)
		self:SetBroken(bBroken)
		self:SetBrokenSince(CurTime())

		if (self.loop) then
			self.loop:Stop()
			self.loop = nil
		end

		if (bBroken) then
			local kind = self:KindData().id
			local sound = kind == "pipe" and "ambient/gas/steam2.wav" or "ambient/energy/electric_loop.wav"

			self.loop = CreateSound(self, sound)
			self.loop:SetSoundLevel(68)
			self.loop:PlayEx(kind == "pipe" and 0.5 or 0.3, 100)
		end
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:IsPlayer()) then
			return
		end

		-- admins: Alt + E - the kind
		if (client:IsAdmin() and client:KeyDown(IN_WALK)) then
			self:SetKind(self:GetKind() % #self.Kinds + 1)
			self.nwModel = nil
			self:ApplyModel()
			NW.Notify(client, "Тип поломки: " .. self:KindData().name)
			NW.persist.Save("nw_breakdown")

			return
		end

		NW.cwu.Repair(client, self)
	end

	function ENT:OnRemove()
		if (self.loop) then
			self.loop:Stop()
		end
	end

	-- sparks of a broken box and panel now and then
	function ENT:Think()
		if (self:GetBroken() and self:KindData().id != "pipe" and math.random() < 0.35) then
			local effect = EffectData()

			effect:SetOrigin(self:WorldSpaceCenter() + VectorRand() * 6)
			effect:SetNormal(self:GetForward())
			effect:SetMagnitude(2)
			effect:SetScale(1)
			effect:SetRadius(3)
			util.Effect("ElectricSpark", effect, true, true)

			if (math.random() < 0.4) then
				self:EmitSound("ambient/energy/spark" .. math.random(1, 6) .. ".wav", 62, math.random(95, 110))
			end
		end

		self:NextThink(CurTime() + math.Rand(0.4, 1.2))

		return true
	end

	timer.Simple(0, function()
		NW.persist.Register("nw_breakdown", {
			Save = function(entity)
				return {kind = entity:GetKind(), model = entity.nwModel}
			end,
			Load = function(entity, data)
				entity:SetKind(tonumber(data.kind) or 1)
				entity.nwModel = data.model
				entity:ApplyModel()
			end
		})
	end)

	return
end

-- ------------------------------------------------------------------ client --
function ENT:Draw()
	self:DrawModel()
end

function ENT:Think()
	if (!self:GetBroken() or LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 1500 * 1500) then
		return
	end

	local kind = self:KindData().id

	-- the steam of a pipe
	if (kind == "pipe" and (self.nextPuff or 0) < CurTime()) then
		self.nextPuff = CurTime() + 0.06

		local emitter = ParticleEmitter(self:GetPos())

		if (emitter) then
			local puff = emitter:Add("particle/particle_smokegrenade", self:WorldSpaceCenter())

			if (puff) then
				puff:SetVelocity(self:GetForward() * math.Rand(60, 120) + VectorRand() * 20 + Vector(0, 0, 30))
				puff:SetDieTime(math.Rand(1.2, 2))
				puff:SetStartAlpha(70)
				puff:SetEndAlpha(0)
				puff:SetStartSize(4)
				puff:SetEndSize(math.Rand(28, 44))
				puff:SetRoll(math.Rand(0, 360))
				puff:SetRollDelta(math.Rand(-1, 1))
				puff:SetColor(220, 224, 228)
				puff:SetAirResistance(80)
			end

			emitter:Finish()
		end
	end

	-- the flicker of a box or a panel
	if (kind != "pipe") then
		local light = DynamicLight(self:EntIndex())

		if (light and math.random() < 0.6) then
			light.pos = self:WorldSpaceCenter() + self:GetForward() * 10
			light.r, light.g, light.b = 140, 190, 255
			light.brightness = math.Rand(0.5, 2)
			light.decay = 2000
			light.size = 110
			light.dietime = CurTime() + 0.1
		end
	end
end
