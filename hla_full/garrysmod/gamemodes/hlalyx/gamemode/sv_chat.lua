-- Chat (server): every message goes only to players in range of the speaker (see sh_chat.lua).
local CH = HLA.Chat
local V = HLA.Voice

concommand.Add('hla_voicelines', function(p)
	local list = {}
	for _, l in ipairs(V.Lines) do list[#list + 1] = l.text end
	local out = 'Войслайны (напишите фразу или её начало в чат, Tab — дополнить, несколько — через запятую):\n' .. table.concat(list, '\n') .. '\n'
	if IsValid(p) then
		for i = 1, #out, 200 do p:PrintMessage(HUD_PRINTCONSOLE, string.sub(out, i, i + 199)) end
		p:ChatPrint('Список войслайнов — в консоли (~)')
	else print(out) end
end)

util.AddNetworkString('hla_chat')

-- kind: mode id; muffled: heard but not understood. The speaker is a player or any entity with a name
-- (story NPCs: hla_npc), name overrides the shown name.
local function speakerName(e, name)
	if name then return name end
	if not IsValid(e) then return '' end
	return e:GetNWString('hla_name', e:IsPlayer() and e:Nick() or '')
end

local function deliver(to, speaker, mode, text, muffled, name, radioSounds)
	net.Start('hla_chat')
	net.WriteUInt(mode.id, 4)
	net.WriteEntity(speaker)
	net.WriteString(speakerName(speaker, name))
	net.WriteBool(muffled)
	if not muffled then net.WriteString(text) end
	if mode.radio then net.WriteString(radioSounds or '') end -- voicelines over the air: «a.wav;b.wav»
	net.Send(to)
end

-- p: the speaker (a player, or an entity when opts.name is given); opts.name, opts.radio (clicks for a non-player)
function CH.Say(p, key, text, opts)
	opts = opts or {}
	local mode = CH.Modes[key]
	if not mode or text == '' or not IsValid(p) then return end
	text = utf8.len(text) and utf8.len(text) > CH.MaxLen and string.sub(text, 1, utf8.offset(text, CH.MaxLen + 1) - 1) or text
	local vo
	if not mode.action and not mode.env then
		local shown, lines = V.Parse(text)
		if shown then
			text, vo = shown, {}
			for _, l in ipairs(lines) do vo[#vo + 1] = 'hla/vo/grunt/' .. l.files[math.random(#l.files)] .. '.wav' end
		end
	end
	-- radios: no distance, no voicelines from the mask — the words go over the air
	if mode.radio then
		local to = {}
		if mode.radio == 'tac' then
			for _, o in ipairs(player.GetAll()) do if not o.HLAInMenu then to[#to + 1] = o end end
		else
			local sq = HLA.Squads and HLA.Squads.Of(p)
			if not sq then
				if p:IsPlayer() then p:ChatPrint('Рация отряда: вы не в отряде (вступите в отряд у терминала)') end
				return
			end
			for _, m in ipairs(sq.members) do if IsValid(m) then to[#to + 1] = m end end
		end
		-- voicelines work on the radio too: everyone on the channel hears them through the radio,
		-- the ones standing next to the unit also hear them from its mask
		local seq
		local shown, lines = V.Parse(text)
		if shown then
			text, seq = shown, {}
			for _, l in ipairs(lines) do seq[#seq + 1] = 'hla/vo/grunt/' .. l.files[math.random(#l.files)] .. '.wav' end
			local at = 0.15
			for _, snd in ipairs(seq) do
				timer.Simple(at, function() if IsValid(p) and (not p:IsPlayer() or p:Alive()) then p:EmitSound(snd, 60, 100, 0.6, CHAN_VOICE) end end)
				at = at + math.Clamp(SoundDuration(snd), 0.3, 12) + 0.15
			end
		end
		deliver(to, p, mode, text, false, opts.name, seq and table.concat(seq, ';') or '')
		MsgN(string.format('[рация %s] %s: %s', mode.radio, speakerName(p, opts.name), text))
		return
	end
	local clear, muffled = {}, {}
	local origin = p:IsPlayer() and p:EyePos() or (p:WorldSpaceCenter() + Vector(0, 0, 24))
	local r2, m2 = mode.range * mode.range, (mode.range * CH.Muffle) ^ 2
	for _, o in ipairs(player.GetAll()) do
		if o == p then
			clear[#clear + 1] = o
		elseif not o.HLAInMenu then
			local d = o:EyePos():DistToSqr(origin)
			if d <= r2 then clear[#clear + 1] = o
			elseif d <= m2 and not mode.action and not mode.env and mode.key ~= 'w' then muffled[#muffled + 1] = o end
		end
	end
	deliver(clear, p, mode, text, false, opts.name)
	-- those a little further hear nothing in the chat (no «говорит что-то неразборчиво» lines)
	-- the unit's radio clicks when it speaks out loud
	local level = mode.key == 'y' and 85 or mode.key == 'w' and 55 or 72
	local voLen
	if vo then
		-- the voicelines one after another, from the unit's mask (between the radio clicks)
		local at = 0.12
		for _, snd in ipairs(vo) do
			timer.Simple(at, function() if IsValid(p) and (not p:IsPlayer() or p:Alive()) then p:EmitSound(snd, level, 100, 1, CHAN_VOICE) end end)
			at = at + math.Clamp(SoundDuration(snd), 0.3, 12) + 0.15
		end
		voLen = at
	end
	if not mode.action and not mode.env and mode.key ~= 'w' and (opts.radio or (p:IsPlayer() and HLA.IsUnit and HLA.IsUnit(p))) then
		p:EmitSound('npc/combine_soldier/vo/on' .. math.random(1, 2) .. '.wav', mode.key == 'y' and 75 or 62, 100, 0.55)
		local len = voLen and math.Clamp(voLen + 0.1, 0.6, 40) or math.Clamp(#text * 0.035, 0.6, 3)
		timer.Simple(len, function()
			if IsValid(p) then p:EmitSound('npc/combine_soldier/vo/off' .. math.random(1, 3) .. '.wav', mode.key == 'y' and 75 or 62, 100, 0.55) end
		end)
	end
	MsgN(string.format('[чат %s] %s (%s): %s', mode.key, speakerName(p, opts.name), p:IsPlayer() and p:Nick() or p:GetClass(), text))
	return voLen
end

-- the chat box sends by net: longer than the «say» command allows
util.AddNetworkString('hla_say')
net.Receive('hla_say', function(_, p)
	local text = string.Trim(net.ReadString() or '')
	if text == '' or p.HLAInMenu then return end
	local key, body = CH.Parse(text)
	if body ~= '' and (p.HLAChatNext or 0) <= CurTime() then
		p.HLAChatNext = CurTime() + 0.4
		CH.Say(p, key, body)
	end
end)

hook.Add('PlayerSay', 'HLAChat', function(p, text)
	-- commands of admin addons («!menu» and the like) are left to them
	if string.sub(text, 1, 1) == '!' then return end
	if p.HLAInMenu then return '' end
	local key, body = CH.Parse(text)
	if body ~= '' and (p.HLAChatNext or 0) <= CurTime() then
		p.HLAChatNext = CurTime() + 0.4
		CH.Say(p, key, body)
	end
	return ''
end)

-- the atmosphere lines, to each player at their own time
CreateConVar('hla_chat_ambient', '1', {FCVAR_ARCHIVE}, 'Atmosphere lines in the chat (0/1)')
timer.Create('HLAChatAmbient', 15, 0, function()
	if not GetConVar('hla_chat_ambient'):GetBool() then return end
	for _, p in ipairs(player.GetAll()) do
		if p:Alive() and not p.HLAInMenu then
			p.HLAAmbientAt = p.HLAAmbientAt or (CurTime() + math.random(CH.AmbientEvery[1], CH.AmbientEvery[2]))
			if CurTime() >= p.HLAAmbientAt then
				p.HLAAmbientAt = CurTime() + math.random(CH.AmbientEvery[1], CH.AmbientEvery[2])
				net.Start('hla_chat')
				net.WriteUInt(0, 4) -- 0 = atmosphere
				net.WriteEntity(NULL)
				net.WriteString('')
				net.WriteBool(false)
				net.WriteString(CH.Ambient[math.random(#CH.Ambient)])
				net.Send(p)
			end
		end
	end
end)

---------------------------------------------------------------------------------------------------
-- the city dispatcher: a line to everyone in the game, «// ДИСПЕТЧЕР — …» in red, with its sound
-- the sound of an announcement: one path or a chain «a.wav;b.wav;…». Radio voice parts get their measured
-- length («path|seconds»), so the client plays the chain without gaps or overlaps.
function CH.SoundChain(snd)
	local out = {}
	for part in string.gmatch(snd or '', '[^;]+') do
		part = string.Trim(part)
		local id = string.match(part, '^hla/radiovoice/(.+)%.wav$')
		local l = id and HLA.RadioVoiceByID and HLA.RadioVoiceByID[id]
		out[#out + 1] = part .. '|' .. (l and l.dur or 0)
	end
	return table.concat(out, ';')
end

-- who speaks: the radio voice (radiovoice) is the dispatcher, the city broadcast (cityvoice) is Overwatch
-- to: a list of players (default: everyone in the game)
function CH.Dispatch(text, sound, who, to)
	if not text or text == '' then return end
	who = who or ((sound and string.find(sound, 'radiovoice', 1, true)) and 'ДИСПЕТЧЕР' or 'ОВЕРВОТЧ')
	if not to then
		to = {}
		for _, o in ipairs(player.GetAll()) do if not o.HLAInMenu then to[#to + 1] = o end end
	end
	if #to == 0 then return end
	net.Start('hla_chat')
	net.WriteUInt(CH.DISPATCH, 4)
	net.WriteEntity(NULL)
	net.WriteString(who)
	net.WriteBool(false)
	net.WriteString(text)
	net.WriteString(CH.SoundChain(sound))
	net.Send(to)
	MsgN('[' .. who .. '] ' .. text)
end

---------------------------------------------------------------------------------------------------
-- voice: by default only those near hear it (in the world, from the unit); with H held it goes over the
-- squad radio — the squad hears it anywhere (not in 3D), those next to the speaker still hear it too
util.AddNetworkString('hla_radio')
net.Receive('hla_radio', function(_, p)
	local on = net.ReadBool()
	p.HLARadio = on
	p:SetNW2Bool('hla_radio', on)
end)

CreateConVar('hla_voice_range', '900', {FCVAR_ARCHIVE}, 'How far normal voice is heard (units, ~17 m)')
local function sameSquad(a, b)
	local SQ = HLA.Squads
	local sa = SQ and SQ.Of(a)
	return sa ~= nil and sa == SQ.Of(b)
end

function GM:PlayerCanHearPlayersVoice(listener, talker)
	if talker.HLAInMenu or listener.HLAInMenu then return false, false end
	-- the dead talk among the dead (spectators)
	if not talker:Alive() then return not listener:Alive(), false end
	if talker.HLARadio and sameSquad(listener, talker) then return true, false end
	local range = GetConVar('hla_voice_range'):GetFloat()
	if listener:GetPos():DistToSqr(talker:GetPos()) <= range * range then return true, true end
	return false, false
end

hook.Add('Initialize', 'HLAVoice', function() RunConsoleCommand('sv_voiceenable', '1') end)
