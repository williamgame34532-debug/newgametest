AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Терминал изолятора"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "User")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_jailterminal")
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
		self:SetModel(NETWORK.jail.GetModel())
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

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

		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.4

		if (!NETWORK.jail.CanUse(activator, self)) then
			self:EmitSound("buttons/combine_button_locked.wav", 60)

			return
		end

		NETWORK.jail.Open(activator, self)
	end

	function ENT:Think()
		local user = self:GetUser()

		if (IsValid(user) and !NETWORK.jail.CanUse(user, self)) then
			NETWORK.jail.Close(user)
		end

		self:NextThink(CurTime() + 0.3)

		return true
	end

	function ENT:OnRemove()
		local user = self:GetUser()

		if (IsValid(user)) then
			NETWORK.jail.Close(user)
		end
	end
else
	function ENT:Draw()
		self:DrawModel()
	end
end
