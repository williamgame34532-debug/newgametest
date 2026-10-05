AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Медицинский компьютер"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "User")
	self:NetworkVar("String", 0, "PassHash")
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_medcomputer")

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().yaw + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel("models/props_lab/monitor01a.mdl")
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:PhysicsInit(SOLID_VPHYSICS)
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:HasCharacter()) then
			return
		end

		if (!NETWORK.meddb.CanUse(activator)) then
			self:EmitSound(NETWORK.sound.computer.deny, 60, 70)

			return
		end

		self:EmitSound(NETWORK.sound.ComputerKeys(), 60, 100)

		NETWORK.comppass.Request(activator, self, function()
			if (!IsValid(self) or !IsValid(activator)) then
				return
			end

			timer.Simple(0.35, function()
				if (IsValid(self)) then
					self:EmitSound(NETWORK.sound.computer.enter, 60, 100)
				end
			end)

			net.Start("nwMedComputer")
			net.Send(activator)
		end)
	end

	return
end

function ENT:Draw()
	self:DrawModel()
end
