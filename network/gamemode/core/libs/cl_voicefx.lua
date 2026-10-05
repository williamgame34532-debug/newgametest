local convar = CreateClientConVar("network_voice_effect", "1", true, false,
	"Обрабатывать мой голос (рация, вокодер Альянса)")
local version = CreateClientConVar("network_voice_version", "1", true, false,
	"Версия голоса Альянса (1 или 2), для ГО и грунта")

local function Send()
	if (!IsValid(LocalPlayer())) then
		return
	end

	net.Start("nwVoiceFxSetting")
		net.WriteBool(convar:GetBool())
		net.WriteUInt(math.Clamp(version:GetInt(), 1, 2), 2)
	net.SendToServer()
end

cvars.AddChangeCallback("network_voice_effect", function()
	timer.Create("nwVoiceFxSetting", 0.5, 1, Send)
end, "nwVoiceFx")

cvars.AddChangeCallback("network_voice_version", function()
	timer.Create("nwVoiceFxSetting", 0.5, 1, Send)
end, "nwVoiceFxVersion")

hook.Add("InitPostEntity", "nwVoiceFx", function()
	timer.Simple(5, Send)
end)

hook.Add("NetworkCharacterLoaded", "nwVoiceFx", function()
	timer.Simple(2, Send)
end)

function NETWORK.voicefx.GetLabel(client)
	local effect = IsValid(client) and client:GetNWInt("nwVoiceFx", 0) or 0

	if (NETWORK.voicefx.IsCombineEffect(effect)) then
		return L("voicefxVocoder")
	elseif (effect == NETWORK.voicefx.RADIO or effect == NETWORK.voicefx.CWU) then
		return L("voicefxRadio")
	end
end
