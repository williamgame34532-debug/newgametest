AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Контейнер"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.ContainerType = "crate"

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "ContainerID")
	self:NetworkVar("String", 1, "ContainerName")
	self:NetworkVar("String", 2, "ContainerDescription")
	self:NetworkVar("Int", 0, "ContainerSlots")

	self:NetworkVar("Int", 1, "ContainerRefill")

	self:NetworkVar("String", 3, "LockItem")
	self:NetworkVar("String", 4, "LockCode")
end

function ENT:GetDisplayName()
	local name = self:GetContainerName()

	if (name != "") then
		return name
	end

	local data = NETWORK.container.Get(self:GetContainerID())

	return data and data.name or "?"
end

function ENT:GetDisplayDescription()
	local description = self:GetContainerDescription()

	if (description != "") then
		return description
	end

	local data = NETWORK.container.Get(self:GetContainerID())

	return data and data.description or ""
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_container")

		entity:SetPos(trace.HitPos + trace.HitNormal * 8)
		entity:SetAngles(Angle(0, (client:GetPos() - trace.HitPos):Angle().y, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		local data = NETWORK.container.Get(self.ContainerType)

		self:SetContainerID(data.id)
		self:SetContainerSlots(data.slots)
		self:SetModel(NETWORK.container.SafeModel(self.model or data.model))
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
		end

		self.items = self.items or {}
		self.viewers = {}

		if (!self.bRolled) then
			self.bRolled = true

			for index, item in ipairs(NETWORK.container.Roll(data.id)) do
				if (index > data.slots) then
					break
				end

				self.items[index] = item
			end
		end
	end

	function ENT:KeyValue(key, value)
		if (string.lower(key) == "containertype") then
			self.ContainerType = value
		end
	end

	function ENT:Rebuild(id)
		local data = NETWORK.container.Get(id)

		self.ContainerType = data.id
		self.model = data.model
		self.bRolled = false
		self.items = {}

		self:SetContainerID(data.id)
		self:SetContainerSlots(data.slots)
		self:SetModel(NETWORK.container.SafeModel(data.model))
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
		end

		for index, item in ipairs(NETWORK.container.Roll(data.id)) do
			if (index > data.slots) then
				break
			end

			self.items[index] = item
		end

		self.bRolled = true

		NETWORK.container.Sync(self)
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer() or !activator:HasCharacter()) then
			return
		end

		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.4

		if (NETWORK.ration and NETWORK.ration.QuickTake and NETWORK.ration.QuickTake(activator, self)) then
			return
		end

		NETWORK.container.Begin(activator, self)
	end

	function ENT:OnRemove()
		for client in pairs(self.viewers or {}) do
			if (IsValid(client)) then
				NETWORK.container.Close(client)
			end
		end
	end
else
	function ENT:Draw()
		self:DrawModel()
	end
end
