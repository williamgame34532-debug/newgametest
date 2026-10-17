AddCSLuaFile()

-- The terminal of the Alliance (models/hla_prop/combine_terminal.mdl). E: the unit leans to the
-- screen (harassfront1) and the command screen opens (cl_cmbterminal.lua): the index, the
-- formations (squads), the personnel, the calls of the civic terminals, the announcements of the
-- city. One user at a time; the others get the refusal. Strangers get the refusal too.
-- nw_cwu_terminal is the same machine with skin 1 for the Civil Workers' Union (sv_cwu.lua).

ENT.Type = "anim"
ENT.PrintName = "Терминал Альянса"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.AutomaticFrameAdvance = true

ENT.TerminalModel = "models/hla_prop/combine_terminal.mdl"
ENT.FallbackModel = "models/props_combine/combine_interface001.mdl"
ENT.TerminalSkin = 0
ENT.TerminalKind = "cmb"

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "User")
	self:NetworkVar("Bool", 0, "Broken")
end

-- who may use it (the Alliance here; the CWU terminal changes it)
function ENT:CanUse(client)
	return NW.zones.IsAlliance(client)
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		local angles = (client:GetPos() - trace.HitPos):Angle()

		angles.p, angles.r = 0, 0

		local entity = ents.Create(self.ClassName)

		entity:SetPos(trace.HitPos)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel(util.IsValidModel(self.TerminalModel) and self.TerminalModel or self.FallbackModel)
		self:SetSkin(self.TerminalSkin)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end

	-- the unit leans to the screen: the sequence on the terminal if it has one, on the player as a
	-- gesture (the Civil Protection models have harassfront1)
	function ENT:Lean(client)
		local sequence = self:LookupSequence("harassfront1")

		if (sequence and sequence > 0) then
			self:ResetSequence(sequence)
			self:SetCycle(0)
			self:SetPlaybackRate(1)
		end

		net.Start("nwCmbTerminalLean")
			net.WriteEntity(client)
		net.SendPVS(client:GetPos())
	end

	function ENT:Use(client)
		if (!IsValid(client) or !client:IsPlayer() or (self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.6

		if (self:GetBroken()) then
			self:EmitSound("ambient/energy/spark" .. math.random(1, 6) .. ".wav", 60)

			return NW.Notify(client, "Терминал не работает")
		end

		if (!self:CanUse(client)) then
			self:EmitSound("buttons/combine_button_locked.wav", 60)

			return NW.Notify(client, "Доступ запрещён")
		end

		local user = self:GetUser()

		if (IsValid(user) and user != client and user:Alive() and user:GetPos():DistToSqr(self:GetPos()) < 160 * 160) then
			self:EmitSound("buttons/combine_button_locked.wav", 60)

			return NW.Notify(client, "Терминал занят: " .. user:Nick())
		end

		self:SetUser(client)
		self:Lean(client)
		self:EmitSound("network2/cmbterminal/combine_tech_startup_0" .. math.random(1, 3) .. ".wav", 62)

		net.Start("nwCmbTerminalOpen")
			net.WriteEntity(self)
			net.WriteString(self.TerminalKind)
		net.Send(client)
	end

	function ENT:Think()
		local user = self:GetUser()

		if (IsValid(user) and (!user:Alive() or user:GetPos():DistToSqr(self:GetPos()) > 200 * 200)) then
			self:SetUser(NULL)
		end

		self:NextThink(CurTime() + 0.5)

		return true
	end

	return
end

-- ------------------------------------------------------------------ client --
function ENT:Initialize()
	self.hum = CreateSound(self, "ambient/machines/combine_terminal_idle1.wav")
end

function ENT:OnRemove()
	if (self.hum) then
		self.hum:Stop()
	end
end

-- a quiet hum when someone is close
function ENT:Think()
	local near = IsValid(LocalPlayer()) and LocalPlayer():GetPos():DistToSqr(self:GetPos()) < 400 * 400 and
		!self:GetBroken()

	if (self.hum) then
		if (near and !self.humming) then
			self.hum:PlayEx(0.25, 100)
			self.humming = true
		elseif (!near and self.humming) then
			self.hum:FadeOut(0.5)
			self.humming = false
		end
	end
end

function ENT:Draw()
	self:DrawModel()
end
