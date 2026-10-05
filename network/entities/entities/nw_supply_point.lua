AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Точка приёма поставок"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = false

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_supply_point")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel("models/props_combine/combine_interface001.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end
else
	function ENT:Draw()
		self:DrawModel()

		local client = LocalPlayer()

		if (!IsValid(client) or client:GetPos():DistToSqr(self:GetPos()) > 400 * 400) then
			return
		end

		local _, maxs = self:GetRotatedAABB(self:OBBMins(), self:OBBMaxs())
		local angles = (self:GetPos() - EyePos()):Angle()

		angles.p = 0
		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		cam.Start3D2D(self:GetPos() + Vector(0, 0, maxs.z + 12), angles, 0.1)
			local text = NETWORK.util.Upper(L("supplyPointLabel"))

			surface.SetFont("nwChat")

			local width = surface.GetTextSize(text) + 48

			draw.RoundedBox(10, -width * 0.5, -22, width, 44, Color(8, 9, 11, 215))
			draw.RoundedBox(3, -width * 0.5, 18, width, 4, Color(72, 196, 236))
			draw.SimpleText(text, "nwChat", 0, -2, NETWORK.theme.text, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
