util.AddNetworkString("nwVoiceFxSetting")

local V = NETWORK.voicefx

V.bLoaded = V.bLoaded or false
V.applied = V.applied or {}
V.params = V.params or {}

local enabled = CreateConVar("network_voicefx_enabled", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY},
	"Обработка голоса через gm_8bit (0 — выключить целиком)")

local dualPass = CreateConVar("network_voice_dualpass", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY},
	"Рация в два прохода gm_8bit: 1 — рядом чистый голос, на частоте обработанный; 0 — один поток всем")

function V.DualPassEnabled()
	return dualPass:GetBool()
end

local paramsPath = "network/voicefx.txt"

V.paramList = {
	"cpPitch", "cpDrive", "cpCompRatio", "cpGain",
	"cp2Drive", "cp2AmHz", "cp2AmWet", "cp2NoiseVl", "cp2TrackVl", "cp2Gain",
	"grunt2Pitch", "grunt2RingHz", "grunt2RingMix", "grunt2Drive", "grunt2Hp", "grunt2Noise", "grunt2Gain",
	"soldierPitch", "soldierDrive", "soldierDrive2", "soldierLimGain", "soldierGain",
	"gruntPitch", "gruntPhaserHz", "gruntLimGain", "gruntGain",
	"whPitch", "whAm1", "whAm2", "whAm3", "whAmWet", "whSmearHz", "whSmearMs", "whRoomGain", "whLimGain", "whGain",
	"supPitch", "supAm1", "supAm2", "supAmWet", "supSubPitch", "supBass", "supLimGain", "supGain",
	"ordRadarHz", "ordRadarLevel", "ordVocLp", "ordAmHz", "ordDryMix", "ordVocMix", "ordLimGain", "ordGain",
	"cwuLow", "cwuHigh", "cwuAmHz", "cwuAmDepth", "cwuPeakDb", "cwuDrive", "cwuNoise", "cwuGain",
	"radioLow", "radioHigh", "radioPeakHz", "radioPeakDb", "radioDrive", "radioCompThreshold",
	"radioCompRatio", "radioNoise", "radioCrackle", "radioGain", "limiterCeil",

	"cpDry", "cp2Dry", "soldierDry", "gruntDry", "grunt2Dry", "whDry", "supDry",
	"ordDry", "cwuDry", "clarityHz", "clarityDb",

	"ordPitch"
}

V.defaults = {
	cpDry = 0.48, cp2Dry = 0.48, soldierDry = 0.5, gruntDry = 0.5, grunt2Dry = 0.5,
	whDry = 0.58, supDry = 0.52, ordDry = 0.5, cwuDry = 0.3,
	clarityHz = 2400, clarityDb = 7,
	cpDrive = 12, cpGain = 1.15,
	soldierDrive = 18, soldierLimGain = 5, soldierGain = 1.15,
	gruntLimGain = 5, gruntGain = 1.15, grunt2Drive = 1.3, grunt2Gain = 1.1,
	whGain = 1.1, supGain = 1.1,
	ordVocLp = 2400, ordVocMix = 0.5, ordRadarLevel = 0.22, ordGain = 1.1, ordPitch = -3
}

V.defaultsVersion = 2
V.defaultsReset = {
	[2] = {"ordPitch"}
}

local function Module()
	if (V.bLoaded and istable(eightbit)) then
		return eightbit
	end
end

function V.LoadParams()
	local raw = file.Read(paramsPath, "DATA")

	V.params = raw and util.JSONToTable(raw) or {}

	local version = tonumber(V.params._version) or 1

	if (version < V.defaultsVersion) then
		for step = version + 1, V.defaultsVersion do
			for _, key in ipairs(V.defaultsReset[step] or {}) do
				V.params[key] = nil
			end
		end

		V.params._version = V.defaultsVersion
		V.SaveParams()
	end
end

function V.SaveParams()
	file.CreateDir("network")
	file.Write(paramsPath, util.TableToJSON(V.params, true))
end

function V.ApplyParameters()
	local module = Module()

	if (!module or !module.SetParam) then
		return
	end

	for key, value in pairs(V.defaults) do
		if (V.params[key] == nil) then
			module.SetParam(key, value)
		end
	end

	for key, value in pairs(V.params) do
		if (key != "_version") then
			module.SetParam(key, tonumber(value) or 0)
		end
	end
end

function V.SetParam(key, value)
	if (!table.HasValue(V.paramList, key)) then
		return false
	end

	V.params[key] = tonumber(value) or 0
	V.SaveParams()
	V.ApplyParameters()

	return true
end

function V.Load()
	if (V.bLoaded) then
		return true
	end

	local bOk, err = pcall(require, "eightbit")

	if (!bOk or !istable(eightbit)) then
		NETWORK.util.PrintWarning(
			"gm_8bit не найден: обработка голоса (рация, шлем Альянса) выключена.\n" ..
			"   Положите сборку из gm_8bit_builds.zip в garrysmod/lua/bin/ как\n" ..
			"   gmsv_eightbit_win32.dll / win64 / linux / linux64 (по серверу).\n" ..
			"   Причина: " .. tostring(err))

		return false
	end

	V.bLoaded = true

	if ((eightbit.VERSION or 0) < 4) then
		NETWORK.util.PrintWarning("gm_8bit: старая сборка модуля (нет пресетов Альянса и двух проходов). " ..
			"Замените файл в lua/bin на сборку из gm_8bit_builds.zip.")
	else
		NETWORK.util.Print("gm_8bit подключён (сборка Network v" .. eightbit.VERSION .. "): эффекты голоса включены.")
	end

	V.LoadParams()
	V.ApplyParameters()

	return true
end

hook.Add("Initialize", "nwVoiceFx", function()
	V.Load()
end)

local function ToModuleEffect(effect)
	local module = Module()

	if (!module) then
		return 0
	end

	if ((module.VERSION or 0) >= 11) then
		return effect
	end

	if (effect == V.CP2) then effect = V.CP end
	if (effect == V.GRUNT2) then effect = V.GRUNT end

	if ((module.VERSION or 0) >= 9) then
		return effect
	end

	if ((module.VERSION or 0) >= 7) then
		return effect == V.CWU and V.RADIO or effect
	end

	if ((module.VERSION or 0) >= 6) then
		if (effect == V.CWU) then return V.RADIO end
		return effect == V.SOLDIER and V.CP or effect
	end

	if ((module.VERSION or 0) >= 3) then
		if (effect == V.WALLHAMMER or effect == V.SUPPRESSOR) then
			return V.GRUNT
		end

		return effect == V.SOLDIER and V.CP or effect
	end

	if ((module.VERSION or 0) < 6 and (effect == V.WALLHAMMER or effect == V.SUPPRESSOR)) then
		return V.GRUNT
	end

	if (V.IsCombineEffect(effect)) then
		return module.EFF_BITCRUSH or 1
	elseif (effect == V.RADIO) then
		return module.EFF_DESAMPLE or 2
	end

	return 0
end

function V.Update(client, bForce)
	if (!IsValid(client) or !client:IsPlayer()) then
		return
	end

	local effect, bDual = V.NONE, false

	if (enabled:GetBool()) then
		effect, bDual = V.Resolve(client)
	end

	if (bDual and !dualPass:GetBool()) then
		bDual = false
	end

	local userID = client:UserID()

	client:SetNWInt("nwVoiceFx", effect)

	local module = Module()

	if (!module) then
		return
	end

	local key = effect .. (bDual and "d" or "")

	if (!bForce and V.applied[userID] == key) then
		return
	end

	V.applied[userID] = key

	local bOk, err = pcall(module.EnableEffect, userID, ToModuleEffect(effect), bDual)

	if (!bOk) then
		ErrorNoHalt("[Network] gm_8bit EnableEffect: " .. tostring(err) .. "\n")
	end
end

timer.Create("nwVoiceFxSpeaking", 0.15, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local bSpeaking = client:IsSpeaking()

		if (bSpeaking != (client.nwWasSpeaking or false)) then
			client.nwWasSpeaking = bSpeaking

			if (bSpeaking) then
				V.Update(client)

				hook.Run("NetworkVoiceStarted", client)
			else
				hook.Run("NetworkVoiceEnded", client)
			end
		end
	end
end)

timer.Create("nwVoiceFxNear", 0.2, 0, function()
	local module = Module()

	if (!module or !module.SetNear or !dualPass:GetBool()) then
		return
	end

	for _, speaker in ipairs(player.GetAll()) do
		local key = V.applied[speaker:UserID()]

		if (!key or !string.find(key, "d", 1, true)) then
			continue
		end

		local range = NETWORK.act.GetVoiceRange and NETWORK.act.GetVoiceRange(speaker) or 512
		local origin = speaker:GetPos()

		for _, listener in ipairs(player.GetAll()) do
			if (listener != speaker) then
				module.SetNear(speaker:UserID(), listener:UserID(),
					listener:GetPos():DistToSqr(origin) <= range * range)
			end
		end
	end
end)

cvars.AddChangeCallback("network_voice_dualpass", function()
	local module = Module()

	for _, client in ipairs(player.GetAll()) do
		if (module and module.ClearNear and !dualPass:GetBool()) then
			module.ClearNear(client:UserID())
		end

		V.Update(client, true)
	end
end, "nwVoiceFxDualPass")

hook.Add("PlayerDisconnected", "nwVoiceFxNear", function(client)
	local module = Module()

	if (module and module.ClearNear) then
		module.ClearNear(client:UserID())
	end
end)

timer.Create("nwVoiceFx", 1, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (client:IsSpeaking() or V.applied[client:UserID()] != nil) then
			V.Update(client)
		end
	end
end)

hook.Add("NetworkCharacterLoaded", "nwVoiceFx", function(client)
	timer.Simple(1, function()
		if (IsValid(client)) then
			V.Update(client, true)
		end
	end)
end)

hook.Add("NetworkFactionTransferred", "nwVoiceFx", function(client)
	timer.Simple(0, function()
		if (IsValid(client)) then
			V.Update(client)
		end
	end)
end)

hook.Add("NetworkClassAssigned", "nwVoiceFx", function(client)
	timer.Simple(0, function()
		if (IsValid(client)) then
			V.Update(client)
		end
	end)
end)

hook.Add("PlayerDisconnected", "nwVoiceFx", function(client)
	V.applied[client:UserID()] = nil
end)

net.Receive("nwVoiceFxSetting", function(_, client)
	local bOff = !net.ReadBool()
	local version = net.ReadUInt(2)

	if ((client.nwNextVoiceFxSetting or 0) > CurTime()) then
		return
	end

	client.nwNextVoiceFxSetting = CurTime() + 1

	client:SetNWBool("nwVoiceFxOff", bOff)
	client:SetNWInt("nwVoiceVersion", math.Clamp(version or 1, 1, 2))

	V.Update(client)
end)

hook.Add("NetworkConfigChanged", "nwVoiceFxVersion", function(id)
	if (id == "voiceVersion2") then
		for _, client in ipairs(player.GetAll()) do
			V.Update(client)
		end
	end
end)

hook.Add("NetworkChatSent", "nwVoiceFxRadio", function(speaker, classID, text, receivers)
	if (classID != "radio" or !IsValid(speaker)) then
		return
	end

	local targets = table.Copy(receivers)

	if (!table.HasValue(targets, speaker)) then
		targets[#targets + 1] = speaker
	end

	for _, target in ipairs(targets) do
		net.Start("nwVoiceRadio")
			net.WriteString(V.PickRadioSound(target))
		net.Send(target)
	end
end)

concommand.Add("voicefx_set", function(client, _, arguments)
	if (IsValid(client) and !client:IsAdmin()) then
		return
	end

	local key, value = arguments[1], tonumber(arguments[2])

	if (!key or !value) then
		return print("voicefx_set <параметр> <число>. Список: voicefx_list")
	end

	if (V.SetParam(key, value)) then
		print("voicefx: " .. key .. " = " .. value)
	else
		print("voicefx: нет параметра " .. key .. ". Список: voicefx_list")
	end
end)

concommand.Add("voicefx_list", function(client)
	if (IsValid(client) and !client:IsAdmin()) then
		return
	end

	for _, key in ipairs(V.paramList) do
		print(string.format("  %-20s %s", key, V.params[key] and tostring(V.params[key]) or "(по умолчанию)"))
	end
end)

NETWORK.command.Register("voicefxset", {
	adminOnly = true,
	description = "cmdVoicefxset",
	usage = "/voicefxset <параметр> <число>",
	OnRun = function(command, client, arguments)
		local key, value = arguments[1], tonumber(arguments[2])

		if (!key or !value) then
			return NETWORK.notice.Send(client, "voicefxParams", "info", table.concat(V.paramList, ", "))
		end

		if (V.SetParam(key, value)) then
			NETWORK.notice.Send(client, "voicefxParamSet", "good", key, value)
		else
			NETWORK.notice.Send(client, "voicefxParams", "warn", table.concat(V.paramList, ", "))
		end
	end
})

NETWORK.command.Register("voicefx", {
	adminOnly = true,
	description = "cmdVoicefx",
	usage = "/voicefx",
	OnRun = function(command, client)
		if (!V.bLoaded) then
			V.Load()
		end

		NETWORK.notice.Send(client, V.bLoaded and "voicefxLoaded" or "voicefxMissing",
			V.bLoaded and "good" or "warn", enabled:GetBool() and "1" or "0",
			V.bLoaded and tostring(eightbit.VERSION or 1) or "-")

		if (V.bLoaded and eightbit.HearingHooked) then
			local bHooked, index = eightbit.HearingHooked()

			NETWORK.notice.Send(client, "voicefxHearing", bHooked and "good" or "warn",
				bHooked and "1" or "0", tostring(index))
		end

		for _, other in ipairs(player.GetAll()) do
			if (other:HasCharacter()) then
				local effect, bDual = V.Resolve(other)

				NETWORK.notice.Send(client, "voicefxPlayer", "info", other:GetCharacterName(),
					effect, (bDual and dualPass:GetBool()) and "2" or "1")
			end
		end
	end
})
