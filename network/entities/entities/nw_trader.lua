AddCSLuaFile()

ENT.Base = "base_ai"
ENT.Type = "ai"
ENT.PrintName = "Торговец"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.PhysgunDisabled = true
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "NPCName")
	self:NetworkVar("String", 1, "NPCModel")
	self:NetworkVar("String", 2, "NPCSequence")
	self:NetworkVar("String", 3, "Dialogue")
	self:NetworkVar("String", 4, "TraderDescription")
	self:NetworkVar("String", 5, "TraderID")

	self:NetworkVar("String", 6, "Factions")

	self:NetworkVar("String", 7, "UnlockItem")
	self:NetworkVar("Int", 0, "UnlockAmount")

	self:NetworkVar("Int", 1, "Restock")
	self:NetworkVar("Int", 2, "RestockAmount")
end

function ENT:GetDisplayName()
	local name = self:GetNPCName()

	return name != "" and name or "Торговец"
end

if (SERVER) then

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("nw_trader")

		entity:SetPos(trace.HitPos + trace.HitNormal * 2)
		entity:SetAngles(Angle(0, (client:GetPos() - trace.HitPos):Angle().y, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		local faction = NETWORK.factions.GetDefault()
		local models = faction and faction.models or {}

		if (self:GetNPCModel() == "") then
			self:SetNPCModel(models[math.random(#models)] or
				"models/humans/group01/male_02.mdl")
		end

		self.offers = self.offers or {}

		self:Apply()
	end

	function ENT:Apply()
		local model = self:GetNPCModel()

		if (!util.IsValidModel(model)) then
			model = "models/humans/group01/male_02.mdl"
		end

		local body = NETWORK.entities and NETWORK.entities.CollectBody and
			string.lower(self:GetModel() or "") == string.lower(model) and
			NETWORK.entities.CollectBody(self)

		self:SetModel(model)

		if (body) then
			NETWORK.entities.ApplyBody(self, body)
		end

		self:SetHullType(HULL_HUMAN)
		self:SetHullSizeNormal()
		self:SetSolid(SOLID_BBOX)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(SIMPLE_USE)
		self:CapabilitiesClear()
		self:SetNPCState(NPC_STATE_IDLE)
		self:SetMaxYawSpeed(0)
		self:AddFlags(FL_NPC)
		self:SetMaxHealth(1000)
		self:SetHealth(1000)
		self:DropToFloor()

		self.baseAngles = self.baseAngles or self:GetAngles()
		self.targetYaw = self.baseAngles.y

		self.baseSequence = self:LookupSequence(self:GetNPCSequence() != "" and
			self:GetNPCSequence() or "idle_all_01")

		if (!self.baseSequence or self.baseSequence <= 0) then
			self.baseSequence = self:LookupSequence("idle_subtle")
		end

		if (self.baseSequence and self.baseSequence > 0) then
			self:ResetSequence(self.baseSequence)
			self:SetCycle(0)
		end
	end

	function ENT:SelectSchedule()
		self:SetSchedule(SCHED_IDLE_STAND)
	end

	function ENT:OnTakeDamage()
		return 0
	end

	function ENT:PlayGesture(name)
		local sequence = self:LookupSequence(name)

		if (sequence and sequence > 0) then
			self:AddGestureSequence(sequence, true)
		end
	end

	function ENT:FaceEntity(target)
		if (NETWORK.npcface) then
			return NETWORK.npcface.Face(self, target)
		end

		if (!IsValid(target)) then
			return
		end

		local direction = target:GetPos() - self:GetPos()

		direction.z = 0

		self.targetYaw = direction:Angle().y
	end

	function ENT:RestoreAngles(target)
		if (NETWORK.npcface) then
			return NETWORK.npcface.Release(self, target)
		end

		self.targetYaw = (self.baseAngles or self:GetAngles()).y
	end

	function ENT:UpdateYaw()
		if (NETWORK.npcface) then
			return NETWORK.npcface.Think(self)
		end
	end

	function ENT:Think()
		if (self.baseSequence and self.baseSequence > 0 and
			self:GetSequence() != self.baseSequence) then
			self:ResetSequence(self.baseSequence)
		end

		self:UpdateYaw()

		self:NextThink(CurTime() + 0.05)

		return true
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer() or !activator:HasCharacter()) then
			return
		end

		if ((self.nextUse or 0) > CurTime()) then
			return
		end

		self.nextUse = CurTime() + 0.5

		if (!NETWORK.dialogue.EntityAllows(self, activator)) then
			self:EmitSound("buttons/button2.wav", 55)

			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("tradeWrongFaction")
			net.Send(activator)

			return
		end

		if (self:GetDialogue() != "" and NETWORK.dialogue.Get(self:GetDialogue())) then
			NETWORK.dialogue.Start(activator, self)

			return
		end

		NETWORK.trade.Open(activator, self)
	end
else
	function ENT:Draw()
		if (NETWORK.npclook) then
			NETWORK.npclook.Update(self)
		end

		self:DrawModel()
	end
end
