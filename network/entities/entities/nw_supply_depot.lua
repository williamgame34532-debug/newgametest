AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Склад ГСР (поставки)"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = false

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_supply_depot")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel("models/props_wasteland/controlroom_storagecloset001a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end

		self:SetUseType(SIMPLE_USE)
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer() or !activator:HasCharacter()) then
			return
		end

		if ((activator.nwNextDepotUse or 0) > CurTime()) then
			return
		end

		activator.nwNextDepotUse = CurTime() + 0.8

		NETWORK.supply.UseDepot(activator, self)
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
			local text = NETWORK.util.Upper(L("supplyDepotLabel"))
			local pending = GetGlobalInt("nwSupplyPending", 0)
			local sub = pending > 0 and L("supplyDepotPending", pending) or L("supplyDepotEmpty")

			surface.SetFont("nwChat")

			local width = math.max(surface.GetTextSize(text), 220) + 48

			draw.RoundedBox(12, -width * 0.5, -28, width, 64, Color(8, 9, 11, 215))
			draw.RoundedBox(3, -width * 0.5, 32, width, 4, Color(240, 178, 70))
			draw.SimpleText(text, "nwChat", 0, -10, NETWORK.theme.text, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
			draw.SimpleText(sub, "nwHudSmall", 0, 14, pending > 0 and Color(240, 178, 70) or
				NETWORK.theme.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end
