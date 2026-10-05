AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Терминал Альянса"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "User")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_cmbterminal")
		local angles = trace.HitNormal:Angle()

		angles.p = 0
		angles.r = 0

		entity:SetPos(trace.HitPos)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel(NETWORK.cmbterm.model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		timer.Simple(0.1, function()
			if (IsValid(self) and !self:GetNWBool("nwBroken")) then
				NETWORK.cmbterm.StartLoop(self)
			end
		end)
	end

	function ENT:OnRemove()
		if (self.nwLoop) then
			self.nwLoop:Stop()
		end
	end

	function ENT:Use(activator)
		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.4

		if (self:GetNWBool("nwSabotaged", false)) then
			self:EmitSound("buttons/combine_button_locked.wav", 60)

			if (IsValid(activator) and activator:IsPlayer()) then
				NETWORK.notice.Send(activator, "rebelSysErrorNotice", "bad")
			end

			return
		end

		if (!NETWORK.cmbterm.CanUse(activator, self)) then
			self:EmitSound("buttons/combine_button_locked.wav", 60)

			return
		end

		NETWORK.cmbterm.Open(activator, self)
	end

	function ENT:Think()
		local user = self:GetUser()

		if (IsValid(user) and (!NETWORK.cmbterm.CanUse(user, self) or
			self:GetNWBool("nwSabotaged", false))) then
			NETWORK.cmbterm.Close(user)
		end

		self:NextThink(CurTime() + 0.3)

		return true
	end

	function ENT:OnRemove()
		local user = self:GetUser()

		if (IsValid(user)) then
			NETWORK.cmbterm.Close(user)
		end
	end
else
	function ENT:Initialize()
		self.loop = CreateSound(self, NETWORK.cmbterm.sounds.loop)
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
			client:GetPos():Distance(self:GetPos()) < 600

		if (bIdle and !self.bPlaying) then
			self.bPlaying = true

			self.loop:PlayEx(0.35, 100)
		elseif (!bIdle and self.bPlaying) then
			self.bPlaying = false

			self.loop:Stop()
		end
	end

	function ENT:Draw()
		self:DrawModel()
	end
end
