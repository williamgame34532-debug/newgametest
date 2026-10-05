AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Компьютер главы ГСР"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "PassHash")
	self:NetworkVar("String", 1, "OwnerName")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_cwu_computer")

		entity:SetPos(trace.HitPos + trace.HitNormal * 2)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel("models/props_lab/monitor01a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer() or !activator:HasCharacter()) then
			return
		end

		if (self:GetNWBool("nwBroken", false)) then
			self:EmitSound("framework/cmb/forcefield/sparkle" .. math.random(4) .. ".mp3", 60, 110)

			return NETWORK.chat.Notice(activator, "empTerminalBroken")
		end

		if ((activator.nwNextCompUse or 0) > CurTime()) then
			return
		end

		activator.nwNextCompUse = CurTime() + 1

		local AC = NETWORK.admincomp

		if (self:GetOwnerName() == "") then
			if (activator:GetNWString("nwClass", "") != AC.cwuClass and !activator:IsAdmin()) then
				self:EmitSound(NETWORK.sound.computer.deny, 60, 70)

				return NETWORK.notice.Send(activator, "cwuCompNoOwner", "warn")
			end

			self:SetOwnerName(activator:GetCharacterName())

			NETWORK.entities.Save()
			NETWORK.notice.Send(activator, "cwuCompBound", "good")
		end

		if (!AC.CanUse(activator, self)) then
			self:EmitSound(NETWORK.sound.computer.deny, 60, 70)

			return NETWORK.notice.Send(activator, "cwuCompDenied", "bad")
		end

		self:EmitSound(NETWORK.sound.ComputerKeys(), 60, 100)

		NETWORK.comppass.Request(activator, self, function()
			if (IsValid(self) and IsValid(activator)) then
				AC.Open(activator, self)
			end
		end)
	end
else
	function ENT:Draw()
		self:DrawModel()

		local client = LocalPlayer()

		if (!IsValid(client) or client:GetPos():DistToSqr(self:GetPos()) > 300 * 300) then
			return
		end

		local mins, maxs = self:OBBMins(), self:OBBMaxs()
		local center = self:OBBCenter()
		local screenWidth = (maxs.y - mins.y) * 0.72
		local screenHeight = (maxs.z - mins.z) * 0.6
		local scale = screenWidth / 300
		local angles = self:GetAngles()

		angles:RotateAroundAxis(angles:Up(), 90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		local owner = self:GetOwnerName()
		local boxHeight = math.Round(screenHeight / scale)

		cam.Start3D2D(self:LocalToWorld(Vector(maxs.x + 0.4, center.y, center.z + (maxs.z - mins.z) * 0.14)),
			angles, scale)
			draw.RoundedBox(8, -150, -math.Round(boxHeight * 0.5), 300, boxHeight, Color(20, 28, 24, 225))
			surface.SetDrawColor(214, 190, 96, 90)
			surface.DrawOutlinedRect(-150, -math.Round(boxHeight * 0.5), 300, boxHeight, 2)
			draw.SimpleText("CWU HEAD", "nwChat", 0, -math.Round(boxHeight * 0.22), Color(214, 190, 96),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(owner != "" and owner or L("cwuCompFree"), "nwInvKey", 0,
				math.Round(boxHeight * 0.08), Color(200, 200, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			if (math.floor(RealTime() * 2) % 2 == 0) then
				draw.RoundedBox(0, -8, math.Round(boxHeight * 0.28), 16, 4, Color(214, 190, 96))
			end
		cam.End3D2D()
	end
end
