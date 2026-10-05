AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Камера жилого блока"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "CamName")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_housing_camera")

		entity:SetPos(trace.HitPos + trace.HitNormal * 6)
		entity:SetAngles(Angle(20, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel("models/dav0r/camera.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end

		timer.Simple(0, function()
			if (!IsValid(self) or self:GetCamName() != "") then
				return
			end

			local zone = NETWORK.zone and NETWORK.zone.At(self:GetPos())

			self:SetCamName(zone and zone.name != "" and zone.name or "Камера")
		end)
	end
else
	function ENT:Draw()
		self:DrawModel()

		if (math.floor(RealTime() * 1.5) % 2 == 0) then
			render.SetColorMaterial()
			render.DrawSphere(self:GetPos() + self:GetForward() * 6 + self:GetUp() * 3, 0.8, 8, 8,
				Color(230, 40, 40))
		end
	end
end
