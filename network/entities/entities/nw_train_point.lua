AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Точка поезда (посылки)"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_train_point")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel("models/props_c17/streetsign004e.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetNoDraw(true)
	end
else
	function ENT:Draw()
		if (!LocalPlayer():IsAdmin()) then
			return
		end

		local angles = LocalPlayer():EyeAngles()

		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		cam.Start3D2D(self:GetPos() + Vector(0, 0, 40), angles, 0.1)
			draw.RoundedBox(6, -110, -16, 220, 32, Color(8, 9, 11, 220))
			draw.SimpleText("ТОЧКА ПОЕЗДА (посылки)", "nwChat", 0, 0, Color(240, 178, 70),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
