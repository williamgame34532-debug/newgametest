-- A talking NPC: E starts the dialogue (cl_npc.lua). Admins spawn it from the spawn menu
-- (Entities → network2) and change everything in the dialogue → Редактировать: name, look,
-- lines and answers, the shop, the quests (sh_npc.lua). NPCs are saved with the map (sv_npc.lua).
-- The head turns to the player standing close.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "NPC (диалоги, торговля)"
ENT.Category = "network2"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.AutomaticFrameAdvance = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "NPCName")
	self:NetworkVar("String", 1, "IdleName")
end

-- the idle: the chosen sequence, or the model's own
function ENT:PlayIdle()
	local name = self:GetIdleName() != "" and self:GetIdleName()
	local sequence = name and self:LookupSequence(name) or -1

	if (!sequence or sequence < 0) then
		sequence = self:SelectWeightedSequence(ACT_IDLE)
	end

	if (sequence and sequence >= 0 and self:GetSequence() != sequence) then
		self:ResetSequence(sequence)
	end
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace, class)
		if (!trace.Hit) then
			return
		end

		local entity = ents.Create(class)

		entity:SetPos(trace.HitPos)
		entity:SetAngles(Angle(0, client:EyeAngles().y + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self.nwConfig = self.nwConfig or NW.npc.Default()
		self.nwUID = self.nwUID or string.format("%x%x", os.time(), math.random(0, 0xffffff))

		self:Apply()
		self:SetUseType(SIMPLE_USE)
		NW.npcs.Changed()
	end

	function ENT:Apply()
		local config = self.nwConfig

		self:SetModel(util.IsValidModel(config.model) and config.model or "models/humans/group01/male_07.mdl")
		self:SetSkin(config.skin or 0)
		self:SetNPCName(config.name or "NPC")
		self:SetIdleName(config.sequence or "")
		self:SetSolid(SOLID_BBOX)
		self:SetCollisionBounds(Vector(-14, -14, 0), Vector(14, 14, 72))
		self:SetMoveType(MOVETYPE_NONE)
		self:PlayIdle()
	end

	function ENT:Use(activator)
		if (IsValid(activator) and activator:IsPlayer() and activator:Alive() and activator:GetCharacterID() != 0) then
			NW.npcs.Talk(activator, self)
		end
	end

	function ENT:Think()
		self:PlayIdle()
		self:NextThink(CurTime())

		return true
	end

	function ENT:OnRemove()
		NW.npcs.Changed()
	end
else
	function ENT:Draw()
		self:DrawModel()
	end

	-- the head follows you when you are close
	function ENT:Think()
		local client = LocalPlayer()
		local yaw, pitch = 0, 0

		if (IsValid(client) and client:GetPos():DistToSqr(self:GetPos()) < 220 * 220) then
			local head = self:GetPos() + Vector(0, 0, 64)
			local to = (client:EyePos() - head):Angle()

			yaw = math.Clamp(math.NormalizeAngle(to.y - self:GetAngles().y), -60, 60)
			pitch = math.Clamp(math.NormalizeAngle(to.p), -30, 30)
		end

		self.nwYaw = Lerp(FrameTime() * 4, self.nwYaw or 0, yaw)
		self.nwPitch = Lerp(FrameTime() * 4, self.nwPitch or 0, pitch)
		self:SetPoseParameter("head_yaw", self.nwYaw)
		self:SetPoseParameter("head_pitch", self.nwPitch)
		self:InvalidateBoneCache()
		self:SetNextClientThink(CurTime())

		return true
	end
end
