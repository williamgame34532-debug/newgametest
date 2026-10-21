AddCSLuaFile()

-- Стол комплектации заказов (sh_exports.lua): E - the goods carried go into the oldest open state order of
-- that kind; the full order comes out as «Посылка госзаказа». Over it - the board of the orders. The model: the C menu.

ENT.Type = "anim"
ENT.PrintName = "Стол комплектации заказов"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.Model = "models/props_wasteland/controlroom_desk001a.mdl"

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create(self.ClassName)
		local angles = (client:GetPos() - trace.HitPos):Angle()

		angles.p, angles.r = 0, 0
		entity:SetPos(trace.HitPos)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		local model = self.nwModel or self.Model

		self:SetModel(util.IsValidModel(model) and model or "models/props_junk/wood_crate001a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	function ENT:Use(client)
		if (IsValid(client) and client:IsPlayer() and client:GetCharacterID() != 0) then
			NW.exports.Bench(client, self)
		end
	end

	return
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:DrawTranslucent()
	NW.exports.DrawBoard(self, "bench")
end
