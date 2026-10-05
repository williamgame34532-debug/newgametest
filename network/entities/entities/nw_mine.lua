AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Мина Альянса"
ENT.Category = "Network"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.armTime = 3
ENT.radius = 150
ENT.damage = 110
ENT.fuse = 0.8

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Armed")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_combine/combine_mine01.mdl")
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
			physics:EnableMotion(false)
		end

		self.armAt = CurTime() + self.armTime

		self:EmitSound("npc/roller/mine/rmine_deploy1.wav", 60, 100)
	end

	function ENT:IsHostile(client)
		if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
			return false
		end

		if (client == self.nwOwner or NETWORK.factions.IsAlliance(client)) then
			return false
		end

		return true
	end

	function ENT:Trigger(target)
		if (self.bTriggered) then
			return
		end

		self.bTriggered = true

		self:EmitSound("npc/roller/mine/rmine_predetonate.wav", 75, 100)

		hook.Run("NetworkMineTriggered", self, target)

		timer.Simple(self.fuse, function()
			if (IsValid(self)) then
				self:Detonate()
			end
		end)
	end

	function ENT:Detonate()
		local position = self:GetPos() + Vector(0, 0, 8)
		local effect = EffectData()

		effect:SetOrigin(position)

		util.Effect("Explosion", effect, true, true)
		util.BlastDamage(self, IsValid(self.nwOwner) and self.nwOwner or self,
			position, self.radius, self.damage)

		self:Remove()
	end

	function ENT:Think()
		if (self.bTriggered) then
			return
		end

		if (!self:GetArmed()) then
			if (CurTime() >= self.armAt) then
				self:SetArmed(true)
				self:EmitSound("npc/roller/mine/rmine_chirp_answer1.wav", 60, 100)
			end

			self:NextThink(CurTime() + 0.25)

			return true
		end

		for _, client in ipairs(player.GetAll()) do
			if (!self:IsHostile(client)) then
				continue
			end

			if (client:GetPos():Distance(self:GetPos()) <= self.radius * 0.5) then
				self:Trigger(client)

				break
			end
		end

		self:NextThink(CurTime() + 0.25)

		return true
	end

	function ENT:OnTakeDamage(info)
		if (self.bTriggered) then
			return
		end

		self:Trigger(info:GetAttacker())
	end
else
	local GLOW = Material("sprites/light_glow02_add")

	function ENT:Draw()
		self:DrawModel()

		if (!self:GetArmed()) then
			return
		end

		local blink = math.abs(math.sin(CurTime() * 2))

		render.SetMaterial(GLOW)
		render.DrawSprite(self:GetPos() + self:GetUp() * 6, 12, 12,
			Color(235, 70, 60, 160 * blink))
	end
end
