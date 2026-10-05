NETWORK.vort = NETWORK.vort or {}

NETWORK.vort.voiceLines = {
	{id = "call", name = "vortVoiceCall", sound = "framework/vo/vort/vortigese03.wav"},
	{id = "answer", name = "vortVoiceAnswer", sound = "framework/vo/vort/vortigese04.wav"},
	{id = "warn", name = "vortVoiceWarn", sound = "framework/vo/vort/vortigese05.wav"},
	{id = "calm", name = "vortVoiceCalm", sound = "framework/vo/vort/calm.wav"},
	{id = "prevail", name = "vortVoicePrevail", sound = "framework/vo/vort/prevail.wav"}
}

local VORT = NETWORK.vort

VORT.voice = {

	power = {
		"framework/vo/vort/vortigese12.wav",
		"framework/vo/vort/vortigese11.wav",
		"framework/vo/vort/vortigese09.wav"
	},

	kill = {
		"framework/vo/vort/calm.wav",
		"framework/vo/vort/prevail.wav",
		"framework/vo/vort/troubleus.wav"
	},

	speech = {
		"framework/vo/vort/vortigese03.wav",
		"framework/vo/vort/vortigese04.wav",
		"framework/vo/vort/vortigese05.wav"
	}
}

function VORT.PlayVoice(client, set, level, pitch)
	local list = VORT.voice[set]

	if (!IsValid(client) or !list or #list == 0) then
		return
	end

	client:EmitSound(list[math.random(#list)], level or 75,
		pitch or math.random(96, 104), 1, CHAN_VOICE)
end

NETWORK.chat.Register("vchat", {
	prefix = {"/vchat", "/vort", "/вчат"},
	format = "chatVort",
	color = Color(140, 255, 150),
	font = "nwChatBig",
	bGlobal = true,
	bSolidColor = true,
	bRealName = true,
	order = 40,

	CanHear = function(class, speaker, listener)
		return VORT.IsVort(listener)
	end,
	OnCanUse = function(class, client)
		return VORT.IsVort(client)
	end,
	OnChatAdd = nil
})

if (CLIENT) then
	return
end

hook.Add("NetworkVortPower", "nwVortVoice", function(client)
	VORT.PlayVoice(client, "power", 80)
end)

hook.Add("PlayerDeath", "nwVortVoice", function(victim, inflictor, attacker)
	if (!IsValid(attacker) or !attacker:IsPlayer() or attacker == victim) then
		return
	end

	if (!VORT.IsVort(attacker) or !attacker:Alive()) then
		return
	end

	timer.Simple(0.6, function()
		if (IsValid(attacker)) then
			VORT.PlayVoice(attacker, "kill", 80, math.random(94, 102))
		end
	end)
end)

VORT.painSounds = {
	"framework/vo/vort/vortigese11.wav",
	"framework/vo/vort/vortigese07.wav",
	"framework/vo/vort/vortigese03.wav"
}

function VORT.PlayPain(client)
	if (!IsValid(client)) then
		return
	end

	client:EmitSound(VORT.painSounds[math.random(#VORT.painSounds)], 75,
		math.random(94, 106), 1, CHAN_VOICE)
end

hook.Add("PlayerPainSound", "nwVortVoice", function(client)
	if (!VORT.IsVort(client)) then
		return
	end

	VORT.PlayPain(client)

	return false
end)

hook.Add("PlayerDeathSound", "nwVortVoice", function(client)

	if (IsValid(client) and VORT.IsVort(client)) then
		VORT.PlayPain(client)

		return true
	end
end)

hook.Add("PlayerFootstep", "nwVortVoice", function(client, position, foot,
	sound, volume)
	if (!VORT.IsVort(client)) then
		return
	end

	client:EmitSound("npc/vort/vort_foot" .. math.random(1, 4) .. ".wav", 70,
		math.random(96, 104), volume * (client:GetVelocity():Length() > 200
		and 0.5 or 0.4))

	return true
end)

util.AddNetworkString("nwVortChat")
util.AddNetworkString("nwVortVoice")

net.Receive("nwVortVoice", function(_, client)
	if (!VORT.IsVort(client) or !client:Alive()) then
		return
	end

	if ((client.nwVortVoiceNext or 0) > CurTime()) then
		return
	end

	client.nwVortVoiceNext = CurTime() + 3

	local index = net.ReadUInt(4)
	local line = NETWORK.vort.voiceLines[index]

	if (!line) then
		return
	end

	client:EmitSound(line.sound, 80, math.random(96, 104), 1, CHAN_VOICE)

	local listeners = {}

	for _, listener in ipairs(player.GetAll()) do
		if (VORT.IsVort(listener) and listener:HasCharacter() and
			listener != client) then
			listeners[#listeners + 1] = listener
		end
	end

	if (#listeners > 0) then
		net.Start("nwChatMessage")
			net.WriteString("vchat")
			net.WriteEntity(client)
			net.WriteString(client:GetCharacterName())
			net.WriteString(L(line.name))
		net.Send(listeners)
	end
end)

function VORT.SendChat(speaker, text)
	text = NETWORK.util.Sanitise(text, NETWORK.chat.maxLength)

	if (text == "" or !text:find("%S")) then
		return
	end

	local listeners = {}

	for _, listener in ipairs(player.GetAll()) do
		if (VORT.IsVort(listener) and listener:HasCharacter()) then
			listeners[#listeners + 1] = listener
		end
	end

	if (#listeners > 0) then
		net.Start("nwChatMessage")
			net.WriteString("vchat")
			net.WriteEntity(speaker)
			net.WriteString(speaker:GetCharacterName())
			net.WriteString(text)
		net.Send(listeners)
	end

	NETWORK.chat.Log(speaker, "vchat", text)

	VORT.PlayVoice(speaker, "speech", 75)
end

hook.Add("NetworkPlayerChat", "nwVortChat", function(client, class, text)
	if (!class or class.id != "vchat") then
		return
	end

	if (!VORT.IsVort(client)) then
		NETWORK.notice.Send(client, "vchatNotVort", "warn")

		return false
	end

	VORT.SendChat(client, text)

	return false
end)

NETWORK.command.Register("vchat", {
	description = "cmdVchat",
	usage = "/vchat <текст>",
	OnRun = function(command, client, arguments)
		if (!VORT.IsVort(client)) then
			return NETWORK.notice.Send(client, "vchatNotVort", "warn")
		end

		VORT.SendChat(client, table.concat(arguments, " "))
	end
})
