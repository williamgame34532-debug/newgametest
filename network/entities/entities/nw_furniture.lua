AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Мебель жильца"
ENT.Category = "Network"
ENT.Spawnable = false

local FALLBACK = "models/props_c17/FurnitureChair001a.mdl"

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "FurnModel")
	self:NetworkVar("String", 1, "Kind")
	self:NetworkVar("String", 2, "OwnerChar")

	self:NetworkVar("String", 3, "FurnitureID")
	self:NetworkVar("Bool", 0, "Locked")
end

local function CatalogueModel(id)
	local shop = scripted_ents.GetStored("nw_furnitureshop")
	local catalogue = shop and shop.t and shop.t.Catalogue

	for _, entry in ipairs(catalogue or {}) do
		if (entry.id == id) then
			return entry.model
		end
	end
end

if (SERVER) then
	function ENT:Initialize()
		local model = self:GetFurnModel()

		if (model == "" and self:GetFurnitureID() != "") then
			model = CatalogueModel(self:GetFurnitureID()) or ""

			if (model != "") then
				self:SetFurnModel(model)
			end
		end

		self:SetModel(model != "" and model or FALLBACK)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then

			physics:EnableMotion(!self:GetLocked() and self:GetKind() == "")
			physics:Wake()
		end
	end

	function ENT:Apply()
		local model = self:GetFurnModel()

		if (model == "" and self:GetFurnitureID() != "") then
			model = CatalogueModel(self:GetFurnitureID()) or ""
		end

		if (model != "" and self:GetModel() != model) then
			self:SetModel(model)
			self:PhysicsInit(SOLID_VPHYSICS)
			self:SetMoveType(MOVETYPE_VPHYSICS)
			self:SetSolid(SOLID_VPHYSICS)
		end

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(!self:GetLocked() and self:GetKind() == "")
		end
	end

	function ENT:SetLockedEx(bLocked)
		self:SetLocked(bLocked == true)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(!bLocked)

			if (bLocked) then
				physics:Sleep()
			else
				physics:Wake()
			end
		end
	end

	function ENT:PhysgunPickup()
		return false
	end

	function ENT:OnTakeDamage()
	end
else
	function ENT:Draw()
		self:DrawModel()
	end
end
