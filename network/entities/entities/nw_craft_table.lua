AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Стол крафта"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.DefaultModel = "models/props_c17/FurnitureTable001a.mdl"

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "Title")
	self:NetworkVar("String", 1, "CraftModel")
	self:NetworkVar("String", 2, "Recipes")

	if (SERVER) then
		self:NetworkVarNotify("CraftModel", function(entity, _, old, new)
			if (old != new) then
				timer.Simple(0, function()
					if (IsValid(entity)) then
						entity:ApplyModel()
					end
				end)
			end
		end)
	end
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_craft_table")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:ApplyModel()
		self:SetUseType(SIMPLE_USE)
	end

	function ENT:ApplyModel()
		local model = self:GetCraftModel()

		if (model == "" or !util.IsValidModel(model)) then
			model = self.DefaultModel
		end

		if (self:GetModel() == model and IsValid(self:GetPhysicsObject())) then
			return
		end

		self:SetModel(model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)

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

		NETWORK.craft.Open(activator, self)
	end
else
	function ENT:Draw()
		self:DrawModel()

		local client = LocalPlayer()

		if (client:GetPos():DistToSqr(self:GetPos()) > 300 * 300) then
			return
		end

		local angles = client:EyeAngles()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		cam.Start3D2D(self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 12), angles, 0.1)
			NETWORK.factory.DrawPlate(NETWORK.craft.GetDisplayName(self),
				L("craftHint"), Color(120, 200, 255), nil, 220)
		cam.End3D2D()
	end
end
