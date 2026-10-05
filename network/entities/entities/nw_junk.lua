AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Куча мусора"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "JunkModel")
	self:NetworkVar("Bool", 0, "Searched")
	self:NetworkVar("Int", 0, "MinItems")
	self:NetworkVar("Int", 1, "MaxItems")

	self:NetworkVar("Int", 2, "Refill")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_junk")

		entity:SetPos(trace.HitPos + Vector(0, 0, 8))
		entity:SetAngles(Angle(0, client:EyeAngles().y + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel(NETWORK.junk.GetModel(self:GetJunkModel()))
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
			physics:EnableMotion(false)
		end

		if (self:GetMinItems() < 1) then
			self:SetMinItems(1)
			self:SetMaxItems(2)
		end

		if (!istable(self.loot)) then
			self.loot = table.Copy(NETWORK.junk.defaultLoot)
		end
	end

	function ENT:Apply()
		self:SetModel(NETWORK.junk.GetModel(self:GetJunkModel()))
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer() or !activator:HasCharacter()) then
			return
		end

		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.4

		NETWORK.junk.Begin(activator, self)
	end
else
	function ENT:Draw()
		self:DrawModel()
	end
end
