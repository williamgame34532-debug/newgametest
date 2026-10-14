-- An item lying in the world (dropped from the inventory or spawned with nw_spawnitem). Looking
-- at it shows its name and description; E opens the small take panel (cl_inventory.lua).

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Предмет"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "ItemID")
end

function ENT:GetItem()
	return NW.items.Get(self:GetItemID())
end

if (SERVER) then
	function ENT:SetItem(id, data)
		local item = NW.items.Get(id)

		self:SetItemID(id)
		self.nwItemData = data or {}
		self:SetModel(item and item.model or "models/props_junk/cardboard_box004a.mdl")
	end

	function ENT:Initialize()
		if (self:GetModel() == "" or !util.IsValidModel(self:GetModel())) then
			self:SetModel("models/props_junk/cardboard_box004a.mdl")
		end

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

		local physics = self:GetPhysicsObject()

		-- models without a physics mesh get a box
		if (!IsValid(physics)) then
			local mins, maxs = self:GetModelBounds()

			self:PhysicsInitBox(mins, maxs)
			physics = self:GetPhysicsObject()
		end

		if (IsValid(physics)) then
			physics:Wake()
		end
	end

	function ENT:Use(activator)
		if (IsValid(activator) and activator:IsPlayer() and activator:GetCharacterID() != 0) then
			net.Start("nwItemOpen")
				net.WriteEntity(self)
			net.Send(activator)
		end
	end
else
	function ENT:Draw()
		self:DrawModel()
	end
end
