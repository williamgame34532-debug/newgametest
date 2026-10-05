AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Гражданский терминал"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()

	self:NetworkVar("Bool", 0, "Alarm")
	self:NetworkVar("String", 0, "AlarmReason")
	self:NetworkVar("Entity", 0, "User")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_terminal")

		local angles = trace.HitNormal:Angle()

		angles.p = 0
		angles.r = 0

		entity:SetPos(trace.HitPos + trace.HitNormal * 8)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel(NETWORK.terminal.model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetAlarm(false)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
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

		if (!NETWORK.terminal.IsUsable(activator, self)) then
			return
		end

		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.4

		if (self:GetAlarm()) then
			if (!NETWORK.factions.IsAlliance(activator)) then
				self:EmitSound(NETWORK.terminal.sounds.denied, 65)

				return
			end

			self:SetAlarm(false)
			self:SetAlarmReason("")
			self:EmitSound(NETWORK.terminal.sounds.select, 65)

			return
		end

		if (!NETWORK.terminal.CanOpen(activator)) then
			self:EmitSound(NETWORK.terminal.sounds.denied, 65)

			NETWORK.chat.Notice(activator, "termAllianceDenied")

			return
		end

		if (IsValid(self:GetUser()) and self:GetUser() != activator) then
			self:EmitSound(NETWORK.terminal.sounds.denied, 65)

			return
		end

		NETWORK.terminal.Open(activator, self)
	end

	function ENT:Think()
		local user = self:GetUser()

		if (IsValid(user) and !NETWORK.terminal.IsUsable(user, self)) then
			NETWORK.terminal.Close(user)
		end

		self:NextThink(CurTime() + 0.25)

		return true
	end

	function ENT:OnRemove()
		local user = self:GetUser()

		if (IsValid(user)) then
			NETWORK.terminal.Close(user)
		end
	end
else
	function ENT:Initialize()
		self.loop = CreateSound(self, NETWORK.terminal.sounds.loop)
	end

	function ENT:OnRemove()
		if (self.loop) then
			self.loop:Stop()
		end
	end

	function ENT:Think()
		if (!self.loop) then
			return
		end

		local client = LocalPlayer()
		local bIdle = !IsValid(self:GetUser()) and IsValid(client) and
			client:GetPos():Distance(self:GetPos()) < 500

		if (bIdle and !self.bPlaying) then
			self.bPlaying = true

			self.loop:PlayEx(0.4, 100)
		elseif (!bIdle and self.bPlaying) then
			self.bPlaying = false

			self.loop:Stop()
		end
	end

	function ENT:Draw()
		self:DrawModel()

		NETWORK.terminal.DrawScreen(self)
	end
end
