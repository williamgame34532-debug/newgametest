AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include('shared.lua')

-- HLA.Chat / HLA.Voice are looked up when used (the gamemode files may load after the entities)

-- the radio chatter while it stands: voicelines whose sounds are idle_* (hla_vo_content)
local CHATTER
local function chatter()
	if CHATTER then return CHATTER end
	CHATTER = {}
	local V = HLA.Voice
	for _, l in ipairs(V and V.Lines or {}) do
		if string.find(l.files[1] or '', '^idle_') then CHATTER[#CHATTER + 1] = l end
	end
	return CHATTER
end

-- n: one entry of the story config (sh_story.lua): name, model, weapon, lines, chatter, idles
function ENT:ApplyConfig(n)
	self.Cfg = n
	local mdl = n.model ~= '' and n.model or HLA.Story.NPCModels[1].model
	if not util.IsValidModel(mdl) then mdl = 'models/combine_soldier.mdl' end
	self:SetModel(mdl)
	self:SetNWString('hla_name', n.name ~= '' and n.name or 'ЮНИТ')
	self:SetWeapon(n.weapon or '')
	if self.Idles then self:PickIdles() self:NextIdle() end
end

function ENT:Initialize()
	if not self.Cfg then self:ApplyConfig({name = '', model = '', weapon = '', lines = {}}) end
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionBounds(Vector(-13, -13, 0), Vector(13, 13, 72))
	self:SetMoveType(MOVETYPE_NONE)
	self:SetUseType(SIMPLE_USE)
	self.Home = self:GetAngles().y
	self.Talked = {}
	self:PickIdles()
	self:NextIdle()
	self.NextChatter = CurTime() + math.random(20, 50)
end

-- idle sequences of the model: those set in the editor (names, comma separated) or every idle one it has
local IDLE_ACTS = {ACT_IDLE = true, ACT_IDLE_ANGRY = true, ACT_IDLE_RELAXED = true, ACT_IDLE_STIMULATED = true,
	ACT_IDLE_SMG1 = true, ACT_IDLE_ANGRY_SMG1 = true, ACT_IDLE_RIFLE = true, ACT_IDLE_SMG1_RELAXED = true,
	ACT_IDLE_SMG1_STIMULATED = true, ACT_IDLE_AR2 = true, ACT_IDLE_ANGRY_AR2 = true, ACT_IDLE_AR2_RELAXED = true,
	ACT_IDLE_SHOTGUN_RELAXED = true, ACT_IDLE_SHOTGUN_STIMULATED = true, ACT_IDLE_PISTOL = true, ACT_IDLE_ANGRY_PISTOL = true}
function ENT:PickIdles()
	local list = {}
	local want = self.Cfg and self.Cfg.idles or ''
	for name in string.gmatch(want, '[^,%s]+') do
		local id = self:LookupSequence(name)
		if id and id >= 0 then list[#list + 1] = id end
	end
	if #list == 0 then
		local armed = (self.Cfg and self.Cfg.weapon or '') ~= ''
		for i = 0, self:GetSequenceCount() - 1 do
			local act = self:GetSequenceActivityName(i) or ''
			local name = string.lower(self:GetSequenceName(i) or '')
			local ok = IDLE_ACTS[act] or (string.find(name, 'idle', 1, true) and not string.find(name, 'to', 1, true)
				and not string.find(name, 'crouch', 1, true) and not string.find(name, 'aim', 1, true))
			-- armed units: the weapon idles first; the plain ones only when there are no others
			if ok then
				local weaponIdle = string.find(act, 'SMG1', 1, true) or string.find(act, 'AR2', 1, true) or string.find(act, 'RIFLE', 1, true)
					or string.find(name, 'smg', 1, true) or string.find(name, 'rifle', 1, true) or string.find(name, 'ar2', 1, true)
				if armed == (weaponIdle and true or false) then list[#list + 1] = i end
			end
		end
		if #list == 0 then
			for i = 0, self:GetSequenceCount() - 1 do
				if IDLE_ACTS[self:GetSequenceActivityName(i) or ''] then list[#list + 1] = i end
			end
		end
	end
	if #list == 0 then list = {0} end
	self.Idles = list
end

function ENT:NextIdle()
	local list = self.Idles
	local seq = list[math.random(#list)]
	if #list > 1 and seq == self:GetSequence() then seq = list[(table.KeyFromValue(list, seq) % #list) + 1] end
	self:ResetSequence(seq)
	self:SetCycle(0)
	self:SetPlaybackRate(1)
	local len = self:SequenceDuration(seq)
	self.IdleUntil = CurTime() + math.max(len, 1) * math.random(2, 4) * (len < 3 and 1.5 or 1)
	if not self:GetSequenceInfo(seq) or len <= 0 then self.IdleUntil = CurTime() + 8 end
end

function ENT:Think()
	local now = CurTime()
	if now >= (self.IdleUntil or 0) then self:NextIdle() end
	-- turn to the one it talks to, then back to its own direction
	local yaw = self.FaceUntil and now < self.FaceUntil and self.FaceYaw or self.Home
	if yaw then
		local cur = self:GetAngles()
		local d = math.AngleDifference(yaw, cur.y)
		if math.abs(d) > 0.5 then self:SetAngles(Angle(0, cur.y + d * math.min(1, FrameTime() * 4), 0)) end
	end
	-- radio chatter when someone is around
	if self.Cfg and self.Cfg.chatter ~= false and now >= (self.NextChatter or 0) then
		self.NextChatter = now + math.random(35, 80)
		local near = false
		for _, p in ipairs(player.GetAll()) do
			if p:GetPos():DistToSqr(self:GetPos()) < 700 * 700 then near = true break end
		end
		local list = chatter()
		if near and #list > 0 then
			local l = list[math.random(#list)]
			self:EmitSound('npc/combine_soldier/vo/on' .. math.random(1, 2) .. '.wav', 60, 100, 0.5)
			local snd = 'hla/vo/grunt/' .. l.files[math.random(#l.files)] .. '.wav'
			timer.Simple(0.15, function() if IsValid(self) then self:EmitSound(snd, 62, 100, 0.8, CHAN_VOICE) end end)
		end
	end
	self:NextThink(now)
	return true
end

-- E: the next of its lines for this player
function ENT:Use(p)
	if not IsValid(p) or not p:IsPlayer() then return end
	if (self.BusyUntil or 0) > CurTime() then return end
	local lines = {}
	for _, l in ipairs(self.Cfg and self.Cfg.lines or {}) do
		if string.Trim(l) ~= '' then lines[#lines + 1] = string.Trim(l) end
	end
	if #lines == 0 then return end
	local key = p:SteamID64() .. ':' .. tostring(p.HLACharID or 0)
	local n = (self.Talked[key] or 0) + 1
	self.Talked[key] = n
	local text = lines[math.min(n, #lines)]
	self.FaceYaw = (p:GetPos() - self:GetPos()):Angle().y
	self.FaceUntil = CurTime() + 8
	local len = HLA.Chat.Say(self, 'say', text, {name = self:GetNWString('hla_name', 'ЮНИТ'), radio = true})
	self.BusyUntil = CurTime() + math.Clamp(len or (utf8.len(text) or #text) * 0.05, 1, 15)
	self.NextChatter = math.max(self.NextChatter or 0, CurTime() + 20)
end

-- the editor changed this NPC (C + click, or the NPC tab)
net.Receive('hla_npc_edit', function(_, p)
	if not HLA.CanEdit(p) then return end
	local e = net.ReadEntity()
	local n = net.ReadTable()
	if not IsValid(e) or not e.IsHLANPC or not istable(n) then return end
	local S = HLA.Story
	local cfg = S.Config.npcs[e.HLAIndex or 0]
	if not cfg then return end
	cfg.name = tostring(n.name or cfg.name)
	cfg.model = tostring(n.model or cfg.model)
	cfg.weapon = tostring(n.weapon or '')
	cfg.idles = tostring(n.idles or '')
	cfg.chatter = n.chatter ~= false
	cfg.lines = {}
	for _, l in ipairs(istable(n.lines) and n.lines or {}) do cfg.lines[#cfg.lines + 1] = tostring(l) end
	e:ApplyConfig(cfg)
	e.Talked = {}
	S.Save()
	p:ChatPrint('[HLA] NPC «' .. cfg.name .. '» сохранён')
end)
util.AddNetworkString('hla_npc_edit')

-- removed by the remover / undo: it leaves the map's story config too
-- (not when the story respawns its NPCs, cleans up the map or the server shuts down)
function ENT:OnRemove()
	local S = HLA.Story
	if self.HLARespawning or not S or not S.Config or S.Cleaning then return end
	local i = self.HLAIndex
	if not i or S.Config.npcs[i] ~= self.Cfg then return end
	table.remove(S.Config.npcs, i)
	for _, e in ipairs(ents.FindByClass('hla_npc*')) do
		if e ~= self and e.HLAIndex and e.HLAIndex > i then e.HLAIndex = e.HLAIndex - 1 end
	end
	S.Save()
end
