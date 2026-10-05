AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ловушка"
ENT.Category = "Network"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.PhysgunDisabled = true
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.models = {"models/props_junk/popcan01a.mdl"}
ENT.maxHealth = 40
ENT.armTime = 2
ENT.thinkRate = 0.1

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Armed")
	self:NetworkVar("Bool", 1, "Sprung")
	self:NetworkVar("Int", 0, "OwnerChar")
	self:NetworkVar("Vector", 0, "WireEnd")
	self:NetworkVar("Entity", 0, "Victim")
end

function ENT:PickModel()
	for _, model in ipairs(self.models or {}) do
		if (util.IsValidModel(model)) then
			return model
		end
	end

	return "models/props_junk/popcan01a.mdl"
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel(self:PickModel())
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end

		self.nwTrapHP = self.maxHealth
		self.armAt = CurTime() + self.armTime

		if (self.nwOwnerChar) then
			self:SetOwnerChar(self.nwOwnerChar)
		end

		self:OnTrapInit()
	end

	function ENT:OnTrapInit()
	end

	function ENT:OnArmed()
	end

	function ENT:TrapThink()
	end

	function ENT:Think()
		if (!self:GetArmed() and !self:GetSprung()) then
			if (CurTime() >= (self.armAt or 0)) then
				self:SetArmed(true)
				self:OnArmed()
			end
		elseif (!self.bExploding) then
			self:TrapThink()
		end

		self:NextThink(CurTime() + self.thinkRate)

		return true
	end

	function ENT:Use(activator)
		NETWORK.trap.Use(activator, self)
	end

	function ENT:IsTarget(entity)
		return NETWORK.trap.IsLiving(entity) and !NETWORK.trap.IsRebelSide(entity)
	end

	function ENT:OnDestroyed(info)
		local effect = EffectData()

		effect:SetOrigin(self:WorldSpaceCenter())
		effect:SetMagnitude(1)
		effect:SetScale(1)
		effect:SetRadius(2)

		util.Effect("Sparks", effect, true, true)

		self:EmitSound("physics/metal/metal_box_break" .. math.random(1, 2) .. ".wav", 65)
		self:Remove()
	end

	function ENT:OnTakeDamage(info)
		if (self.bDestroyed or self.bExploding) then
			return
		end

		self.nwTrapHP = (self.nwTrapHP or self.maxHealth) - info:GetDamage()

		if (self.nwTrapHP > 0) then
			return
		end

		self.bDestroyed = true

		NETWORK.trap.Log(self:GetClass() .. " уничтожена (" ..
			NETWORK.trap.Name(info:GetAttacker()) .. ")", self:GetPos())

		self:OnDestroyed(info)
	end

	function ENT:Blast(position, radius, damage)
		if (self.bExploding) then
			return
		end

		self.bExploding = true

		NETWORK.trap.Explode(self, position or self:WorldSpaceCenter(), radius, damage)
		NETWORK.trap.Log(self:GetClass() .. " взорвалась (владелец: " ..
			NETWORK.trap.Name(self.nwOwner) .. ")", self:GetPos())

		self:Remove()
	end
else
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:DrawTranslucent()
	end
end
