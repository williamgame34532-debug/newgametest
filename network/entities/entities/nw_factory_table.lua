AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Заводской стол"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.RenderGroup = RENDERGROUP_BOTH

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_factory_table")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		local model = "models/props_c17/furnituretable002a.mdl"

		util.PrecacheModel(model)
		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:HasCharacter()) then
			return
		end

		if (NETWORK.schedule and NETWORK.schedule.IsFactoryShift and
			!NETWORK.schedule.IsFactoryShift()) then
			return NETWORK.chat.Notice(client, "factoryClosedShift")
		end

		for _, entity in ipairs(ents.FindInSphere(self:GetPos(), 90)) do
			local bBox = entity:GetClass() == "nw_factory_box" or
				(entity:GetClass() == "nw_item" and
				(entity.nwItemID or (entity.GetItemID and entity:GetItemID())) ==
				"factory_box")

			if (bBox) then
				NETWORK.factory.OpenBox(client, entity)

				return
			end
		end

		NETWORK.chat.Notice(client, "factoryNeedBox")
	end
else
	function ENT:Draw()
		self:DrawModel()
	end

	local COLOR_TABLE = Color(226, 236, 246, 235)
	local COLOR_READY = Color(120, 200, 255, 240)

	function ENT:DrawTranslucent()
		local F = NETWORK.factory

		if (!F or !F.DrawPlate or !F.InRange(self, 600)) then
			return
		end

		if ((self.nwNextScan or 0) < RealTime()) then
			self.nwNextScan = RealTime() + 0.5
			self.nwHasBox = false

			for _, entity in ipairs(ents.FindInSphere(self:GetPos(), 90)) do
				if (entity:GetClass() == "nw_factory_box" or (entity:GetClass() == "nw_item" and
					entity.GetItemID and entity:GetItemID() == "factory_box")) then
					self.nwHasBox = true

					break
				end
			end
		end

		local bBox = self.nwHasBox

		cam.Start3D2D(self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 22), F.FaceAngles(), 0.08)
			F.DrawPlate(L("entFactoryTable"), !bBox and L("factoryNeedBox") or nil,
				bBox and COLOR_READY or COLOR_TABLE, nil, 320,
				L(bBox and "factoryHintTable" or "factoryHintTableEmpty"))
		cam.End3D2D()
	end
end
