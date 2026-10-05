AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Компьютер администрации"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "PassHash")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_admin_computer")

		entity:SetPos(trace.HitPos + trace.HitNormal * 2)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel("models/props_lab/monitor02.mdl")
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
		if (self:GetNWBool("nwBroken", false)) then
			self:EmitSound("framework/cmb/forcefield/sparkle" .. math.random(4) .. ".mp3", 60, 110)

			if (IsValid(activator) and activator:IsPlayer()) then
				NETWORK.chat.Notice(activator, "empTerminalBroken")
			end

			return
		end

		if (!IsValid(activator) or !activator:IsPlayer()) then
			return
		end

		self:EmitSound(NETWORK.sound.ComputerKeys(), 60, 100)

		if ((activator.nwNextCompUse or 0) > CurTime()) then
			return
		end

		activator.nwNextCompUse = CurTime() + 1

		if (!NETWORK.admincomp.CanUse(activator, self)) then
			return NETWORK.notice.Send(activator, "adminCompDenied", "bad")
		end

		NETWORK.comppass.Request(activator, self, function()
			if (IsValid(self) and IsValid(activator)) then
				NETWORK.admincomp.Open(activator, self)
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

		local angles = self:GetAngles()

		angles:RotateAroundAxis(angles:Up(), 90)
		angles:RotateAroundAxis(angles:Forward(), 90)

		cam.Start3D2D(self:LocalToWorld(Vector(9.6, 0, 18)), angles, 0.05)
			draw.RoundedBox(12, -150, -110, 300, 210, Color(18, 32, 48, 200))
			draw.SimpleText("C24 ADMIN", "nwChat", 0, -30, Color(140, 190, 230),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			if (math.floor(RealTime() * 2) % 2 == 0) then
				draw.RoundedBox(0, -8, 10, 16, 4, Color(140, 190, 230))
			end
		cam.End3D2D()
	end
end
