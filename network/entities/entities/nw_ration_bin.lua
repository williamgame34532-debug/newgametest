AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "nw_container"
ENT.PrintName = "Приёмник пайков"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.ContainerType = "ration_bin"

ENT.RenderGroup = RENDERGROUP_BOTH

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_ration_bin")

		entity:SetPos(trace.HitPos + trace.HitNormal * 8)
		entity:SetAngles(Angle(0, (client:GetPos() - trace.HitPos):Angle().y, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self.BaseClass.Initialize(self)

		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end
else

	local COLOR_BIN = Color(226, 236, 246, 235)
	local COLOR_WORK = Color(236, 190, 96, 240)

	function ENT:DrawTranslucent()
		local F = NETWORK.factory
		local client = LocalPlayer()

		if (!F or !F.DrawPlate or !IsValid(client) or
			!F.InRange(self, NETWORK.ration.range * 2)) then
			return
		end

		local done = NETWORK.ration.GetDelivered()
		local quota = NETWORK.ration.quota
		local color = done >= quota and NETWORK.theme.positive or COLOR_BIN
		local subtitle = L("rationBinCount", done, quota)
		local hint

		local WORK = NETWORK.factorywork

		if (WORK and WORK.IsWorker(client)) then
			local own = WORK.GetOwn(client)

			color = own.bDone and NETWORK.theme.positive or COLOR_WORK
			subtitle = own.bDone and L("workBinDone") or
				L("workBinLine", own.box, WORK.boxSize, own.quotas, WORK.quotas)
			hint = !own.bDone and L("factoryHintBin") or nil
		end

		cam.Start3D2D(self:GetPos() + self:GetUp() * (self:OBBMaxs().z + 10), F.FaceAngles(), 0.08)
			F.DrawPlate(L("rationBinTitle"), subtitle, color, math.Clamp(done / math.max(quota, 1), 0, 1),
				340, hint)
		cam.End3D2D()
	end
end
