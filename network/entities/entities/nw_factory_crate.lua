AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Заводской ящик"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

ENT.RenderGroup = RENDERGROUP_BOTH

ENT.WorkTime = 5
ENT.Cooldown = 8

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "WorkEnd")
	self:NetworkVar("Float", 1, "ReadyAt")
end

if (SERVER) then

	if (!NETWORK.FactoryProgress) then
		util.AddNetworkString("nwFactoryProgress")

		function NETWORK.FactoryProgress(client, label, duration)
			net.Start("nwFactoryProgress")
				net.WriteString(label)
				net.WriteFloat(duration)
			net.Send(client)
		end
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_factory_crate")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		local model = "models/props_junk/wood_crate002a.mdl"

		util.PrecacheModel(model)
		self:SetModel(model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)
	end

	function ENT:ClearStaleClock()
		if (self:GetReadyAt() > CurTime() + self.Cooldown + 1) then
			self:SetReadyAt(0)
		end

		if (!IsValid(self.worker) and self:GetWorkEnd() != 0) then
			self.worker = nil

			self:SetWorkEnd(0)
		end
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:HasCharacter()) then
			return
		end

		self:ClearStaleClock()

		if (self:GetReadyAt() > CurTime()) then
			return NETWORK.chat.Notice(client, "factoryCrateCooldown")
		end

		if (IsValid(self.worker)) then
			return
		end

		if (NETWORK.schedule and NETWORK.schedule.IsFactoryShift and
			!NETWORK.schedule.IsFactoryShift()) then
			return NETWORK.chat.Notice(client, "factoryClosed")
		end

		self.worker = client
		self.workEnd = CurTime() + self.WorkTime

		self:SetWorkEnd(self.workEnd)
		self:EmitSound("physics/wood/wood_crate_impact_hard4.wav", 70)

		NETWORK.FactoryProgress(client, "factoryUnpacking", self.WorkTime)
		NETWORK.chat.Notice(client, "factoryUnpackStart")
	end

	function ENT:Think()
		local worker = self.worker

		if (IsValid(worker)) then

			if (!worker:Alive() or
				worker:GetPos():Distance(self:GetPos()) > 120) then
				self.worker = nil

				self:SetWorkEnd(0)
				NETWORK.chat.Notice(worker, "factoryUnpackFail")
			elseif (CurTime() >= (self.workEnd or 0)) then
				self.worker = nil

				self:SetWorkEnd(0)
				self:SetReadyAt(CurTime() + self.Cooldown)
				self:EmitSound("physics/cardboard/cardboard_box_break2.wav", 70)

				NETWORK.item.Spawn("factory_box", self:GetPos() +
					self:GetUp() * (self:OBBMaxs().z + 14))

				NETWORK.chat.Notice(worker, "factoryUnpackDone")
			end
		else
			self:ClearStaleClock()
		end

		self:NextThink(CurTime() + 0.1)

		return true
	end
else
	function ENT:Draw()
		self:DrawModel()
	end

	local COLOR_READY = Color(226, 236, 246, 235)
	local COLOR_WORK = Color(120, 200, 255, 240)
	local COLOR_WAIT = Color(240, 186, 74, 235)

	function ENT:DrawTranslucent()
		local F = NETWORK.factory

		if (!F or !F.DrawPlate or !F.InRange(self, 600)) then
			return
		end

		local now = CurTime()
		local workEnd, readyAt = self:GetWorkEnd(), self:GetReadyAt()
		local title, subtitle, color, progress, hint

		if (workEnd > now) then
			title, color = L("factoryUnpacking"), COLOR_WORK
			progress = 1 - math.Clamp((workEnd - now) / self.WorkTime, 0, 1)
		elseif (readyAt > now and readyAt - now <= self.Cooldown + 1) then
			title, color = L("factoryCrateCooldown"), COLOR_WAIT
			progress = 1 - math.Clamp((readyAt - now) / self.Cooldown, 0, 1)
		else
			title, color = L("entFactoryCrate"), COLOR_READY
			hint = L("factoryHintCrate")
		end

		if (NETWORK.schedule and NETWORK.schedule.IsFactoryShift and
			!NETWORK.schedule.IsFactoryShift()) then
			subtitle = L("factoryClosed")
			hint = nil
		end

		cam.Start3D2D(self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 14), F.FaceAngles(), 0.08)
			F.DrawPlate(title, subtitle, color, progress, 300, hint)
		cam.End3D2D()
	end
end
