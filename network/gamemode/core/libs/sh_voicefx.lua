NETWORK.voicefx = NETWORK.voicefx or {}

NETWORK.voicefx.NONE = 0
NETWORK.voicefx.RADIO = 4
NETWORK.voicefx.CP = 5
NETWORK.voicefx.GRUNT = 6
NETWORK.voicefx.ORDINAL = 7
NETWORK.voicefx.WALLHAMMER = 8
NETWORK.voicefx.SUPPRESSOR = 9
NETWORK.voicefx.SOLDIER = 10
NETWORK.voicefx.CWU = 11
NETWORK.voicefx.CP2 = 12
NETWORK.voicefx.GRUNT2 = 13
NETWORK.voicefx.VOCODER = 5

NETWORK.chat.radioVoice = {
	"framework/vo/radio.mp3",
	"framework/vo/radio2.mp3"
}

function NETWORK.voicefx.PickRadioSound(client)
	local sounds = NETWORK.chat.radioVoice

	if (IsValid(client) and NETWORK.factions.IsAlliance(client)) then
		sounds = NETWORK.chat.radioOnRadio or sounds
	end

	return sounds[math.random(#sounds)]
end

function NETWORK.voicefx.Version2Allowed()
	return NETWORK.config and NETWORK.config.Get and NETWORK.config.Get("voiceVersion2") != false
end

function NETWORK.voicefx.IsCombineEffect(effect)
	return effect == NETWORK.voicefx.CP or effect == NETWORK.voicefx.GRUNT or
		effect == NETWORK.voicefx.ORDINAL or effect == NETWORK.voicefx.WALLHAMMER or
		effect == NETWORK.voicefx.SUPPRESSOR or effect == NETWORK.voicefx.SOLDIER or
		effect == NETWORK.voicefx.CP2 or effect == NETWORK.voicefx.GRUNT2
end

function NETWORK.voicefx.IsTransmitting(client)
	return NETWORK.radio != nil and NETWORK.radio.IsTransmitting != nil and
		NETWORK.radio.IsTransmitting(client) == true
end

function NETWORK.voicefx.IsOnRadio(client)
	if (NETWORK.radio and NETWORK.radio.IsTransmitting and NETWORK.radio.IsTransmitting(client)) then
		return true
	end

	if (NETWORK.act and NETWORK.act.IsRadioOn and NETWORK.act.IsRadioOn(client)) then
		return true
	end

	return false
end

function NETWORK.voicefx.Resolve(client)
	local V = NETWORK.voicefx

	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
		return V.NONE, false
	end

	if (client:GetNWBool("nwVoiceFxOff", false)) then
		return V.NONE, false
	end

	if (NETWORK.factions.IsAlliance(client)) then
		local faction = client:GetCharacterFaction()

		local bV2 = V.Version2Allowed() and client:GetNWInt("nwVoiceVersion", 1) == 2

		if (faction == "cp") then
			return bV2 and V.CP2 or V.CP, false
		end

		local class = client:GetNWString("nwClass", "")

		if (class == "ordinal") then
			return V.ORDINAL, false
		elseif (class == "wallhammer") then
			return V.WALLHAMMER, false
		elseif (class == "suppressor") then
			return V.SUPPRESSOR, false
		elseif (class == "soldier" or class == "soldier_elite") then
			return V.SOLDIER, false
		end

		return bV2 and V.GRUNT2 or V.GRUNT, false
	end

	local class = client:GetNWString("nwClass", "")

	if (class == "administration" or class == "cwuhead") then
		return V.NONE, false
	end

	if (client.IsCWUMember and client:IsCWUMember()) then
		if (V.IsTransmitting(client)) then
			return V.RADIO, true
		end

		return V.NONE, false
	end

	if (V.IsOnRadio(client)) then
		return V.RADIO, true
	end

	return V.NONE, false
end

if (CLIENT) then
	NETWORK.option.RegisterCategory("voice", "optCatVoice", 45)

	NETWORK.option.Register("voiceEffect", {
		name = "settingVoiceEffect",
		description = "settingVoiceEffectDesc",
		category = "voice",
		type = "bool",
		convar = "network_voice_effect",
		default = true
	})

	NETWORK.option.Register("voiceVersion", {
		name = "settingVoiceVersion",
		description = "settingVoiceVersionDesc",
		category = "voice",
		type = "choice",
		convar = "network_voice_version",
		options = {
			{value = "1", label = "voiceVersion1"},
			{value = "2", label = "voiceVersion2"}
		},
		IsHidden = function()
			return !NETWORK.voicefx.Version2Allowed()
		end
	})
end
