AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Терминал ГСР"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "User")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_cwuterminal")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel(NETWORK.cmbterm.model)
		self:SetSkin(1)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)

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
		if (!IsValid(activator) or !activator:HasCharacter()) then
			return
		end

		if (!NETWORK.factions.IsCWU(activator) and
			!NETWORK.factions.IsAlliance(activator) and
			activator:GetNWString("nwClass", "") != "mechanic") then
			self:EmitSound("buttons/combine_button_locked.wav")

			return
		end

		local user = self:GetUser()

		if (IsValid(user) and user != activator) then
			return
		end

		NETWORK.cmbterm.Open(activator, self)
	end
else
	function ENT:Draw()
		self:DrawModel()
	end
end
