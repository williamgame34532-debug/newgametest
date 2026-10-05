AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Содержимое коробки"
ENT.Category = "Network"
ENT.Spawnable = false
ENT.PhysgunDisabled = true

ENT.RenderGroup = RENDERGROUP_BOTH

ENT.bNoPersist = true

ENT.Models = {
	["вода"] = "models/props_junk/garbage_plasticbottle003a.mdl",
	["сухпаёк"] = "models/props_junk/garbage_metalcan002a.mdl",
	["компоненты"] = "models/props_lab/box01a.mdl"
}

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "PartName")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_junk/garbage_metalcan002a.mdl")
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
			physics:SetMass(2)
		end
	end

	function ENT:Setup(name)
		self:SetPartName(name)

		local model = self.Models[name]

		if (model) then
			util.PrecacheModel(model)
			self:SetModel(model)
			self:PhysicsInit(SOLID_VPHYSICS)

			local physics = self:GetPhysicsObject()

			if (IsValid(physics)) then
				physics:Wake()
				physics:SetMass(2)
			end
		end
	end

	function ENT:PhysgunPickup()
		return false
	end

	function ENT:OnTakeDamage()
		return 0
	end
else
	function ENT:Draw()
		self:DrawModel()
	end

	local COLOR_PART = Color(120, 200, 255, 240)

	function ENT:DrawTranslucent()
		local F = NETWORK.factory

		if (!F or !F.DrawPlate or !F.InRange(self, 400)) then
			return
		end

		cam.Start3D2D(self:GetPos() + Vector(0, 0, 12), F.FaceAngles(), 0.06)
			F.DrawPlate(self:GetPartName(), nil, COLOR_PART, nil, 200)
		cam.End3D2D()
	end
end
