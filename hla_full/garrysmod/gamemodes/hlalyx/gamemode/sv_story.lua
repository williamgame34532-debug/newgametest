local S = HLA.Story
local CH = HLA.Chat

util.AddNetworkString('hla_story_cfg')
util.AddNetworkString('hla_story_save')
util.AddNetworkString('hla_story_do')
util.AddNetworkString('hla_story_card')
util.AddNetworkString('hla_vote')
util.AddNetworkString('hla_story_msg')

file.CreateDir('hla/story')
local function path() return 'hla/story/' .. game.GetMap() .. '.json' end

function S.Load()
	S.Config = S.Normalize(util.JSONToTable(file.Read(path(), 'DATA') or '') or nil)
	S.Apply()
end

function S.Save()
	file.Write(path(), util.TableToJSON(S.Config, true))
end

local function vec(t) return Vector(t[1] or 0, t[2] or 0, t[3] or 0) end

local function participants()
	local out = {}
	for _, p in ipairs(player.GetAll()) do
		if not p.HLAInMenu and p.HLACharID then out[#out + 1] = p end
	end
	return out
end
S.Participants = participants

local function setGoals(list)
	local out = {}
	for _, g in ipairs(list or {}) do
		if istable(g.p) then out[#out + 1] = {p = g.p, name = tostring(g.name or '')} end
	end
	SetGlobal2String('hla_goals', #out > 0 and util.TableToJSON(out) or '')
end
S.SetGoals = setGoals

local function setState(st, mode)
	if st ~= S.STORY then setGoals(nil) end
	SetGlobal2String('hla_state', st)
	if mode then SetGlobal2String('hla_mode', mode) end
	S.StateAt = CurTime()
end

local function msgAll(text, sub)
	net.Start('hla_story_msg') net.WriteString(text) net.WriteString(sub or '') net.Broadcast()
end

local function pickSpawn(list, taken)
	if not list or #list == 0 then return end
	local best, bestD
	for i, sp in ipairs(list) do
		if not taken[i] then
			local pos = vec(sp.p)
			local d = math.huge
			for _, o in ipairs(player.GetAll()) do
				if o:Alive() and not o.HLAInMenu then d = math.min(d, o:GetPos():DistToSqr(pos)) end
			end
			if not bestD or d > bestD then best, bestD = i, d end
		end
	end
	if not best then best = math.random(#list) end
	taken[best] = true
	return list[best]
end

local function spawnList(p)
	local c = S.Config
	if S.State() == S.PVP then
		if S.Mode() == 'teams' then
			local l = p:Team() == S.TEAM2 and c.pvp.spawns.t2 or c.pvp.spawns.t1
			if #l > 0 then return l end
		end
		if #c.pvp.spawns.ffa > 0 then return c.pvp.spawns.ffa end
	end
	local ch = c.chapters[S.Chapter or 1] or c.chapters[1]
	return ch and ch.spawns
end

function S.Respawn(p, taken)
	p.HLAOut = false
	p:UnSpectate()
	local sp = pickSpawn(spawnList(p), taken or {})
	p.HLASpawnAt = sp
	p:Spawn()
end

hook.Add('PlayerSpawn', 'HLAStorySpawn', function(p)
	local sp = p.HLASpawnAt
	if not sp and not p.HLAInMenu and S.Config then
		local l = spawnList(p)
		if l and #l > 0 and not S.InRound() then sp = l[math.random(#l)] end
	end
	p.HLASpawnAt = nil
	if not sp then return end
	timer.Simple(0, function()
		if not IsValid(p) or not p:Alive() then return end
		p:SetPos(vec(sp.p) + Vector(0, 0, 4))
		p:SetEyeAngles(Angle(0, sp.y or 0, 0))
		p:SetVelocity(-p:GetVelocity())
	end)
end)

local function aliveOthers(p)
	local out = {}
	for _, o in ipairs(participants()) do
		if o ~= p and o:Alive() and not o.HLAOut then out[#out + 1] = o end
	end
	return out
end

function S.Spectate(p, step)
	local list = aliveOthers(p)
	if #list == 0 then
		p:Spectate(OBS_MODE_ROAMING)
		return
	end
	local cur = p:GetObserverTarget()
	local idx = 0
	for i, o in ipairs(list) do if o == cur then idx = i end end
	idx = (idx - 1 + (step or 1)) % #list + 1
	local mode = p:GetObserverMode()
	if mode ~= OBS_MODE_CHASE and mode ~= OBS_MODE_IN_EYE then mode = OBS_MODE_CHASE end
	p:Spectate(mode)
	p:SpectateEntity(list[idx])
end

local function makeOut(p)
	p.HLAOut = true
	if p:Alive() then p:KillSilent() end
	timer.Simple(2, function()
		if IsValid(p) and p.HLAOut and not p:Alive() then S.Spectate(p, 1) end
	end)
end
S.MakeOut = makeOut

hook.Add('PlayerDeath', 'HLAStoryOut', function(p)
	if S.InRound() and not p.HLAInMenu then
		p.HLAOut = true
		timer.Simple(2.5, function()
			if IsValid(p) and p.HLAOut and not p:Alive() then S.Spectate(p, 1) end
		end)
	end
end)

hook.Add('PlayerDeathThink', 'HLAStoryOut', function(p)
	if p.HLAOut and S.InRound() then return false end
end)

hook.Add('KeyPress', 'HLASpectate', function(p, key)
	if p:Alive() or not p.HLAOut then return end
	if key == IN_ATTACK then S.Spectate(p, 1)
	elseif key == IN_ATTACK2 then S.Spectate(p, -1)
	elseif key == IN_JUMP then
		local m = p:GetObserverMode()
		if m == OBS_MODE_CHASE then p:Spectate(OBS_MODE_IN_EYE)
		elseif m == OBS_MODE_IN_EYE then p:Spectate(OBS_MODE_ROAMING)
		else S.Spectate(p, 0) p:Spectate(OBS_MODE_CHASE) end
	end
end)

hook.Add('HLAPlayerEnteredGame', 'HLAStoryLate', function(p)
	S.Card(p)
	if S.InRound() and not p.HLAJoinedRound then
		timer.Simple(0.2, function() if IsValid(p) then makeOut(p) end end)
	end
end)

hook.Add('PlayerShouldTakeDamage', 'HLAStoryPvP', function(victim, attacker)
	if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end
	local st, mode = S.State(), S.Mode()
	if st == S.PVP then
		if mode == 'teams' and victim:Team() == attacker:Team() and not S.Config.pvp.friendly then return false end
		return true
	end
	if st == S.STORY and not S.Config.settings.storyFriendlyFire then return false end
end)

function S.Card(to)
	local c = S.Config
	if not c then return end
	local ch = c.chapters[S.InRound() and S.State() == S.STORY and (S.Chapter or 1) or 1]
	net.Start('hla_story_card')
	if S.State() == S.PVP then
		net.WriteString('ПВП')
		net.WriteString(S.Mode() == 'teams' and 'ПО КОМАНДАМ' or 'КАЖДЫЙ САМ ЗА СЕБЯ')
		net.WriteString(S.Mode() == 'teams' and (c.pvp.team1 .. '  ::  ' .. c.pvp.team2) or '')
	else
		net.WriteString(ch and ch.title or '')
		net.WriteString(ch and ch.name or '')
		net.WriteString(ch and ch.sub or '')
	end
	net.WriteFloat(c.settings.cardTime or 7)
	if to then net.Send(to) else net.Broadcast() end
end

local function dispatchID(id)
	if not id or id == '' then return end
	local text, snd = S.DispatchText(S.Config, id)
	if text then CH.Dispatch(text, snd) end
end
S.DispatchID = dispatchID

function S.StartChapter(n)
	local c = S.Config
	S.Chapter = math.Clamp(n, 1, #c.chapters)
	SetGlobal2Int('hla_chapter', S.Chapter)
	SetGlobal2String('hla_chapter_title', c.chapters[S.Chapter].title .. ': ' .. c.chapters[S.Chapter].name)
	setGoals(c.chapters[S.Chapter].goals)
	S.AllDeadAt = nil
	local taken = {}
	for _, p in ipairs(participants()) do
		p.HLAJoinedRound = true
		S.Respawn(p, taken)
	end
	S.Card()
	local d = c.chapters[S.Chapter].dispatch
	if d and d ~= '' then timer.Simple(2, function() dispatchID(d) end) end
end

local function resetPlayers()
	for _, p in ipairs(player.GetAll()) do
		p.HLAJoinedRound = false
		if p:Team() == S.TEAM1 or p:Team() == S.TEAM2 then p:SetTeam(TEAM_UNASSIGNED) end
		if p.HLAOut then
			p.HLAOut = false
			if not p.HLAInMenu then S.Respawn(p) end
		end
	end
end

function S.StartVote()
	if #participants() < 1 then return end
	S.Votes = {}
	for i = 1, #S.CHOICES do SetGlobal2Int('hla_vote_' .. i, 0) end
	SetGlobal2Float('hla_vote_end', CurTime() + math.max(5, S.Config.settings.voteTime or 20))
	setState(S.VOTE)
	for _, p in ipairs(player.GetAll()) do p:EmitSound('buttons/blip1.wav', 0, 100, 0.4) end
end

function S.StartRound(mode)
	local c = S.Config
	resetPlayers()
	if mode == 'story' then
		setState(S.STORY, 'story')
		S.StartChapter(1)
		return
	end
	setState(S.PVP, mode)
	SetGlobal2Float('hla_round_end', CurTime() + math.max(1, c.pvp.time or 10) * 60)
	SetGlobal2String('hla_team1', c.pvp.team1)
	SetGlobal2String('hla_team2', c.pvp.team2)
	local list = participants()
	for i = #list, 2, -1 do local j = math.random(i) list[i], list[j] = list[j], list[i] end
	for i, p in ipairs(list) do
		p:SetTeam(mode == 'teams' and (i % 2 == 1 and S.TEAM1 or S.TEAM2) or TEAM_UNASSIGNED)
		p:SetFrags(0) p:SetDeaths(0)
	end
	local taken1, taken2 = {}, {}
	for _, p in ipairs(list) do
		p.HLAJoinedRound = true
		S.Respawn(p, p:Team() == S.TEAM2 and taken2 or taken1)
	end
	S.Card()
end

function S.EndRound(text, sub)
	setState(S.END)
	msgAll(text, sub)
	timer.Create('HLAStoryEnd', 10, 1, function()
		setState(S.WAIT, '')
		resetPlayers()
	end)
end

function S.Stop()
	timer.Remove('HLAStoryEnd')
	setState(S.WAIT, '')
	resetPlayers()
end

local function tally()
	local best, bestN = 1, -1
	for i = 1, #S.CHOICES do
		local n = GetGlobal2Int('hla_vote_' .. i, 0)
		if n > bestN then best, bestN = i, n end
	end
	return S.CHOICES[best].id
end

net.Receive('hla_vote', function(_, p)
	local i = net.ReadUInt(3)
	if S.State() ~= S.VOTE or p.HLAInMenu or not S.CHOICES[i] then return end
	S.Votes = S.Votes or {}
	S.Votes[p] = i
	local counts = {}
	for v, c in pairs(S.Votes) do if IsValid(v) then counts[c] = (counts[c] or 0) + 1 end end
	for k = 1, #S.CHOICES do SetGlobal2Int('hla_vote_' .. k, counts[k] or 0) end
	p:SetNW2Int('hla_my_vote', i)
end)

local function aliveIn(list)
	local n = 0
	for _, p in ipairs(list) do if p:Alive() and not p.HLAOut then n = n + 1 end end
	return n
end

timer.Create('HLAStoryTick', 0.5, 0, function()
	if not S.Config then return end
	local st = S.State()
	local list = participants()
	local need = math.max(1, S.Config.settings.minPlayers or 2)
	if st == S.WAIT then
		if #list >= need and CurTime() - (S.StateAt or 0) > 5 then S.StartVote() end
	elseif st == S.VOTE then
		if #list < need then setState(S.WAIT) return end
		if CurTime() >= GetGlobal2Float('hla_vote_end', 0) then
			for _, p in ipairs(player.GetAll()) do p:SetNW2Int('hla_my_vote', 0) end
			S.StartRound(tally())
		end
	elseif st == S.STORY then
		if #list == 0 then S.Stop() return end
		local ch = S.Config.chapters[S.Chapter or 1]
		if ch and ch.trigger then
			for _, p in ipairs(list) do
				if p:Alive() and not p.HLAOut and S.Inside(ch.trigger, p:GetPos()) then
					if (S.Chapter or 1) >= #S.Config.chapters then
						S.EndRound('СЮЖЕТ ЗАВЕРШЁН', ch.title .. ': ' .. ch.name)
					else
						S.StartChapter((S.Chapter or 1) + 1)
					end
					return
				end
			end
		end
		if aliveIn(list) == 0 then
			S.AllDeadAt = S.AllDeadAt or CurTime()
			if CurTime() - S.AllDeadAt > 6 then
				msgAll('ОТРЯД ПОТЕРЯН', 'глава начинается заново')
				S.StartChapter(S.Chapter or 1)
			end
		else
			S.AllDeadAt = nil
		end
	elseif st == S.PVP then
		local inRound = {}
		for _, p in ipairs(list) do if p.HLAJoinedRound then inRound[#inRound + 1] = p end end
		if #inRound < 2 then S.EndRound('РАУНД ОСТАНОВЛЕН', 'недостаточно игроков') return end
		local timeUp = CurTime() >= GetGlobal2Float('hla_round_end', 0)
		if S.Mode() == 'teams' then
			local a, b = {}, {}
			for _, p in ipairs(inRound) do if p:Team() == S.TEAM2 then b[#b + 1] = p else a[#a + 1] = p end end
			local na, nb = aliveIn(a), aliveIn(b)
			if na == 0 or nb == 0 or timeUp then
				local win = na > nb and S.Config.pvp.team1 or nb > na and S.Config.pvp.team2 or nil
				S.EndRound(win and ('ПОБЕДА: ' .. win) or 'НИЧЬЯ', timeUp and 'время вышло' or '')
			end
		else
			local alive = {}
			for _, p in ipairs(inRound) do if p:Alive() and not p.HLAOut then alive[#alive + 1] = p end end
			if #alive <= 1 or timeUp then
				local best = alive[1]
				if timeUp then
					for _, p in ipairs(inRound) do if not best or p:Frags() > best:Frags() then best = p end end
				end
				S.EndRound(IsValid(best) and ('ПОБЕДА: ' .. best:GetNWString('hla_name', best:Nick())) or 'НИЧЬЯ', timeUp and 'время вышло' or '')
			end
		end
	end
end)

local function callout(attacker, playerVictim)
	if not S.Config.settings.killCallout or not IsValid(attacker) or not attacker:IsPlayer() then return end
	if (attacker.HLACalloutAt or 0) > CurTime() then return end
	attacker.HLACalloutAt = CurTime() + 4
	local list = playerVictim and S.Config.settings.killLinesPlayer or S.Config.settings.killLines
	if not list or #list == 0 then return end
	local line = list[math.random(#list)]
	timer.Simple(0.7, function()
		if IsValid(attacker) and attacker:Alive() and not attacker.HLAInMenu then CH.Say(attacker, 'say', line) end
	end)
end
hook.Add('OnNPCKilled', 'HLAKillCallout', function(npc, attacker) callout(attacker, false) end)
hook.Add('PlayerDeath', 'HLAKillCallout', function(victim, _, attacker)
	if attacker ~= victim then callout(attacker, true) end
end)

local DIGITS = {['0'] = 'zero', ['1'] = 'one', ['2'] = 'two', ['3'] = 'three', ['4'] = 'four', ['5'] = 'five',
	['6'] = 'six', ['7'] = 'seven', ['8'] = 'eight', ['9'] = 'nine'}
hook.Add('PlayerDeath', 'HLADispatchDeath', function(p)
	if p.HLAInMenu or not p.HLACharID then return end
	if (p.HLADeathCallAt or 0) > CurTime() then return end
	p.HLADeathCallAt = CurTime() + 5
	local name = p:GetNWString('hla_name', '')
	local num = string.match(name, '(%d+)%s*$') or ''
	local rv = HLA.RadioVoicePath
	local seq = {rv('on3'), rv('lostbiosignalforunit')}
	for d in string.gmatch(num, '%d') do seq[#seq + 1] = rv(DIGITS[d]) end
	seq[#seq + 1] = rv('off2')
	p:EmitSound('hla/death/die_' .. math.random(1, 2) .. '.wav', 80, math.random(96, 104), 1, CHAN_VOICE)
	local text = 'Потерян биосигнал юнита' .. (num ~= '' and (' ' .. num) or '') .. '.'
	timer.Simple(1.2, function() CH.Dispatch(text, table.concat(seq, ';'), 'ДИСПЕТЧЕР') end)
end)

timer.Create('HLADispatcher', 15, 0, function()
	local d = S.Config and S.Config.dispatch
	if not d or (d.every or 0) <= 0 or #d.pool == 0 then return end
	S.NextDispatch = S.NextDispatch or CurTime() + d.every * 60
	if CurTime() < S.NextDispatch then return end
	S.NextDispatch = CurTime() + d.every * 60 * math.Rand(0.8, 1.2)
	dispatchID(d.pool[math.random(#d.pool)])
end)

function S.SpawnNPCs()
	for _, e in ipairs(ents.FindByClass('hla_npc*')) do e.HLARespawning = true e:Remove() end
	for i, n in ipairs(S.Config.npcs) do
		local e = ents.Create('hla_npc')
		if IsValid(e) then
			e:SetPos(vec(n.pos))
			e:SetAngles(Angle(0, n.yaw or 0, 0))
			e.HLAIndex = i
			e:ApplyConfig(n)
			e:Spawn()
			e:Activate()
		end
	end
end

function S.Apply()
	SetGlobal2String('hla_team1', S.Config.pvp.team1)
	SetGlobal2String('hla_team2', S.Config.pvp.team2)
	SetGlobal2Int('hla_min_players', math.max(1, S.Config.settings.minPlayers or 2))
	SetGlobal2Int('hla_vote_time', math.max(5, S.Config.settings.voteTime or 20))
	local zones = {}
	for _, z in ipairs(S.Config.zones or {}) do
		if z.a and z.b and isstring(z.name) then zones[#zones + 1] = {name = z.name, a = z.a, b = z.b} end
	end
	SetGlobal2String('hla_zones', util.TableToJSON(zones))
	S.SpawnNPCs()
end

CreateConVar('hla_steady_lights', '1', {FCVAR_ARCHIVE}, 'Flickering map lights burn steady (0/1)')
local FLICKER_FX = {[kRenderFxStrobeSlow or 9] = true, [kRenderFxStrobeFast or 10] = true, [kRenderFxStrobeFaster or 11] = true,
	[kRenderFxFlickerSlow or 12] = true, [kRenderFxFlickerFast or 13] = true, [kRenderFxHologram or 16] = true, [kRenderFxPulseSlow or 1] = true,
	[kRenderFxPulseFast or 2] = true, [kRenderFxPulseSlowWide or 3] = true, [kRenderFxPulseFastWide or 4] = true}
local function steadyPattern(e)
	local kv = e:GetKeyValues()
	local pat = kv and kv.pattern
	if not isstring(pat) or #pat < 2 or not string.find(pat, '[^' .. string.sub(pat, 1, 1) .. ']') then return end
	local top = 'a'
	for c in string.gmatch(pat, '%a') do if c > top then top = c end end
	return top < 'm' and top or 'm'
end
local function steadyLights(withLamps)
	if not GetConVar('hla_steady_lights'):GetBool() then return end
	for i = 1, 12 do engine.LightStyle(i, 'm') end
	if withLamps then
		for _, e in ipairs(ents.FindByClass('light*')) do
			local p = steadyPattern(e)
			if p and not e:HasSpawnFlags(1) then e:Fire('SetPattern', p) end
		end
	end
	for _, cls in ipairs({'env_sprite', 'env_sprite_oriented', 'env_glow', 'env_lightglow'}) do
		for _, e in ipairs(ents.FindByClass(cls)) do
			if FLICKER_FX[e:GetRenderFX()] then e:SetRenderFX(kRenderFxNone or 0) end
		end
	end
end
hook.Add('InitPostEntity', 'HLASteadyLights', function() steadyLights(true) timer.Simple(3, function() steadyLights(false) end) end)
hook.Add('PostCleanupMap', 'HLASteadyLights', function() steadyLights(true) timer.Simple(3, function() steadyLights(false) end) end)
local cvSteady = GetConVar('hla_steady_lights')
hook.Add('AcceptInput', 'HLASteadyLights', function(e, input)
	if string.sub(e:GetClass(), 1, 5) ~= 'light' then return end
	local i = string.lower(input)
	if (i ~= 'turnon' and i ~= 'toggle') or not cvSteady:GetBool() then return end
	local p = steadyPattern(e)
	if p then timer.Simple(0, function() if IsValid(e) then e:Fire('SetPattern', p) end end) end
end)

hook.Add('InitPostEntity', 'HLAStory', function()
	S.Load()
	setState(S.WAIT, '')
	RunConsoleCommand('mp_show_voice_icons', '0')
end)
hook.Add('PreCleanupMap', 'HLAStory', function() S.Cleaning = true end)
hook.Add('PostCleanupMap', 'HLAStory', function() S.Cleaning = false if S.Config then S.SpawnNPCs() end end)
hook.Add('ShutDown', 'HLAStory', function() S.Cleaning = true end)

function S.PlaceNPC(p, tr, label)
	if not tr.Hit or not IsValid(p) or not HLA.CanEdit(p) or not S.Config then return end
	local pick
	for _, c in ipairs(S.NPCModels) do
		if c.label == label and util.IsValidModel(c.model) then pick = c break end
	end
	if not pick then
		for _, c in ipairs(S.NPCModels) do if c.label == label then pick = c break end end
		p:ChatPrint('[HLA] Модель «' .. label .. '» не установлена: впишите путь в её настройках (C + клик по NPC)')
	end
	local pos = tr.HitPos
	local yaw = math.Round((p:GetPos() - pos):Angle().y, 1)
	local n = {pos = {math.Round(pos.x, 1), math.Round(pos.y, 1), math.Round(pos.z, 1)}, yaw = yaw,
		name = 'ЭХО-' .. math.random(100, 999), model = pick.model, weapon = pick.weapon,
		lines = {'', '', ''}, chatter = true, idles = ''}
	table.insert(S.Config.npcs, n)
	S.Save()
	local e = ents.Create('hla_npc')
	if not IsValid(e) then return end
	e:SetPos(pos)
	e:SetAngles(Angle(0, yaw, 0))
	e.HLAIndex = #S.Config.npcs
	e:ApplyConfig(n)
	e:Spawn()
	e:Activate()
	p:ChatPrint('[HLA] ' .. n.name .. ' поставлен. Реплики: зажмите C и кликните по нему.')
	return e
end

local function sendConfig(p)
	local data = util.Compress(util.TableToJSON(S.Config))
	net.Start('hla_story_cfg')
	net.WriteUInt(#data, 32)
	net.WriteData(data, #data)
	net.Send(p)
end
S.SendConfig = sendConfig

net.Receive('hla_story_save', function(_, p)
	if not HLA.CanEdit(p) then return end
	local len = net.ReadUInt(32)
	if len <= 0 or len > 4 * 1024 * 1024 then return end
	local t = util.JSONToTable(util.Decompress(net.ReadData(len)) or '')
	if not istable(t) then p:ChatPrint('[HLA] Не удалось прочитать настройки') return end
	S.Config = S.Normalize(t)
	S.Save()
	S.Apply()
	p:ChatPrint('[HLA] Настройки сюжета сохранены для ' .. game.GetMap())
end)

net.Receive('hla_story_do', function(_, p)
	if not HLA.CanEdit(p) then return end
	local what = net.ReadString()
	local arg = net.ReadString()
	if what == 'get' then sendConfig(p)
	elseif what == 'vote' then S.Stop() S.StartVote()
	elseif what == 'start' then S.StartRound(arg ~= '' and arg or 'story')
	elseif what == 'stop' then S.Stop() msgAll('РАУНД ОСТАНОВЛЕН', 'администратор')
	elseif what == 'chapter' then
		if S.State() ~= S.STORY then setState(S.STORY, 'story') resetPlayers() end
		S.StartChapter(tonumber(arg) or 1)
	elseif what == 'dropship' then if HLA.Dropship then HLA.Dropship.Fly() end
	elseif what == 'dispatch' then dispatchID(arg)
	elseif what == 'dispatch_text' then CH.Dispatch(arg, '')
	elseif what == 'dispatch_chain' then
		local t = util.JSONToTable(arg)
		if istable(t) and isstring(t.text) and isstring(t.snd) then CH.Dispatch(t.text, t.snd) end
	end
end)

concommand.Add('hla_round', function(p, _, a)
	if IsValid(p) and not HLA.CanEdit(p) then return end
	local w = a[1] or ''
	if w == 'stop' then S.Stop() elseif w == 'vote' then S.Stop() S.StartVote() elseif w ~= '' then S.StartRound(w) end
end)
