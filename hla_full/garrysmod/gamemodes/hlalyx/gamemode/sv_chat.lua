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

-- kind: mode id; muffled: heard but not understood
local function deliver(to, speaker, mode, text, muffled)
	net.Start('hla_chat')
	net.WriteUInt(mode.id, 4)
	net.WriteEntity(speaker)
	net.WriteString(speaker:GetNWString('hla_name', speaker:Nick()))
	net.WriteBool(muffled)
	if not muffled then net.WriteString(text) end
	net.Send(to)
end

function CH.Say(p, key, text)
	local mode = CH.Modes[key]
	if not mode or text == '' then return end
	text = utf8.len(text) and utf8.len(text) > CH.MaxLen and string.sub(text, 1, utf8.offset(text, CH.MaxLen + 1) - 1) or text
	local vo
	if not mode.action and not mode.env then
		local shown, lines = V.Parse(text)
		if shown then
			text, vo = shown, {}
			for _, l in ipairs(lines) do vo[#vo + 1] = 'hla/vo/grunt/' .. l.files[math.random(#l.files)] .. '.wav' end
		end
	end
	local clear, muffled = {}, {}
	local origin = p:EyePos()
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
	deliver(clear, p, mode, text, false)
	if #muffled > 0 then deliver(muffled, p, mode, '', true) end
	-- the unit's radio clicks when it speaks out loud
	local level = mode.key == 'y' and 85 or mode.key == 'w' and 55 or 72
	local voLen
	if vo then
		-- the voicelines one after another, from the unit's mask (between the radio clicks)
		local at = 0.12
		for _, snd in ipairs(vo) do
			timer.Simple(at, function() if IsValid(p) and p:Alive() then p:EmitSound(snd, level, 100, 1, CHAN_VOICE) end end)
			at = at + math.Clamp(SoundDuration(snd), 0.3, 12) + 0.15
		end
		voLen = at
	end
	if not mode.action and not mode.env and mode.key ~= 'w' and HLA.IsUnit and HLA.IsUnit(p) then
		p:EmitSound('npc/combine_soldier/vo/on' .. math.random(1, 2) .. '.wav', mode.key == 'y' and 75 or 62, 100, 0.55)
		local len = voLen and math.Clamp(voLen + 0.1, 0.6, 40) or math.Clamp(#text * 0.035, 0.6, 3)
		timer.Simple(len, function()
			if IsValid(p) then p:EmitSound('npc/combine_soldier/vo/off' .. math.random(1, 3) .. '.wav', mode.key == 'y' and 75 or 62, 100, 0.55) end
		end)
	end
	MsgN(string.format('[чат %s] %s (%s): %s', mode.key, p:GetNWString('hla_name', ''), p:Nick(), text))
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
