AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Торговое оборудование"
ENT.Category = "Network"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "FixModel")
	self:NetworkVar("String", 1, "Kind")
	self:NetworkVar("String", 2, "OwnerChar")
	self:NetworkVar("String", 3, "ShopName")
	self:NetworkVar("Bool", 0, "Open")
	self:NetworkVar("Int", 0, "ContainerSlots")
end

function ENT:GetContainerID()
	return "shop_" .. self:GetKind()
end

function ENT:GetDisplayName()
	return (self:GetShopName() != "" and self:GetShopName() or "Лавка") .. " — " ..
		((NETWORK.store.GetFixture(self:GetKind()) or {}).name or "оборудование")
end

function ENT:GetDisplayDescription()
	return self:GetOpen() and "Лавка открыта" or "Лавка закрыта"
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel(self:GetFixModel() != "" and self:GetFixModel() or
			"models/props_c17/FurnitureTable001a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end

		local fixture = NETWORK.store.GetFixture(self:GetKind())

		self.items = self.items or {}
		self.viewers = {}
		self:SetContainerSlots(fixture and fixture.slots or 0)
	end

	function ENT:PhysgunPickup()
		return false
	end

	function ENT:OnTakeDamage()
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer() or !activator:HasCharacter()) then
			return
		end

		local fixture = NETWORK.store.GetFixture(self:GetKind())

		if (!fixture or !fixture.slots) then
			return
		end

		local bOwner = self:GetOwnerChar() == tostring(activator:GetCharacterID())

		if (!bOwner and !self:GetOpen()) then
			return NETWORK.notice.Send(activator, "shopClosed", "warn")
		end

		self.items = self.items or {}
		self.viewers = self.viewers or {}

		NETWORK.container.Open(activator, self)
	end
else
	function ENT:Draw()
		self:DrawModel()

		local client = LocalPlayer()

		if (client:GetPos():DistToSqr(self:GetPos()) > 350 * 350) then
			return
		end

		local angles = client:EyeAngles()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		cam.Start3D2D(self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 12), angles, 0.1)
			NETWORK.factory.DrawPlate(self:GetShopName() != "" and self:GetShopName() or "Лавка",
				self:GetOpen() and "ОТКРЫТО" or "ЗАКРЫТО", self:GetOpen() and Color(150, 224, 170) or
				Color(220, 90, 80), nil, 240)
		cam.End3D2D()
	end
end
