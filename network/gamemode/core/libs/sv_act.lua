util.AddNetworkString("nwActGesture")
util.AddNetworkString("nwActPlay")
util.AddNetworkString("nwActReset")
util.AddNetworkString("nwActRun")
util.AddNetworkString("nwActMood")
util.AddNetworkString("nwActWalk")
util.AddNetworkString("nwActVoice")
util.AddNetworkString("nwActRadio")

local function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

function NETWORK.act.IsAgainstWall(client)
	local start = client:GetPos() + Vector(0, 0, 40)

	return util.TraceLine({
		start = start,
		endpos = start - client:GetAngles():Forward() * 34,
		filter = client
	}).Hit
end

function NETWORK.act.ResetGestures(client)
	if (!IsValid(client)) then
		return
	end

	client:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)

	net.Start("nwActReset")
		net.WriteEntity(client)
	net.Broadcast()
end

function NETWORK.act.Release(client)
	if (!IsValid(client)) then
		return
	end

	client.nwAct = nil
	client.nwActExiting = nil
	client.nwActSequence = nil

	client:SetNWBool("nwActing", false)
	client:LeaveSequence()
end

function NETWORK.act.Stop(client, bInstant)
	local act = client.nwAct

	if (!act) then

		if (client.nwActSequence and !client.nwActExiting) then
			NETWORK.act.Release(client)
		end

		return
	end

	if (client.nwActExiting) then
		return
	end

	client.nwAct = nil

	client:SetNWBool("nwActing", false)

	if (act.exit and !bInstant and client:LookupSequence(act.exit) > 0) then
		client.nwActExiting = true

		client:ForceSequence(act.exit, function()
			NETWORK.act.Release(client)
		end)

		return
	end

	NETWORK.act.Release(client)
end

function NETWORK.act.Play(client, data)
	if (!data or !IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return
	end

	if ((client.nwNextAct or 0) > CurTime()) then
		return
	end

	client.nwNextAct = CurTime() + 0.6

	if (client.nwAct or client.nwActExiting) then
		return NETWORK.act.Stop(client)
	end

	if (client:InVehicle() or !client:OnGround()) then
		return Notice(client, "actNotNow")
	end

	if (data.check == "wall" and !NETWORK.act.IsAgainstWall(client)) then
		return Notice(client, "actNeedWall")
	end

	if (!NETWORK.act.HasSequence(client, data)) then
		return Notice(client, "actNoSequence")
	end

	if (data.weapon) then
		local weapon = client:GetActiveWeapon()

		if (!IsValid(weapon) or weapon:GetClass() != data.weapon) then
			return Notice(client, "actNeedWeapon")
		end
	end

	if (hook.Run("NetworkCanUseAct", client, data) == false) then
		return
	end

	local name = NETWORK.act.ResolveSequence(client, data)

	if (!name) then
		return Notice(client, "actNoSequence")
	end

	client.nwAct = data
	client.nwActSequence = true

	client:SetNWBool("nwActing", true)

	if (data.hold) then

		client:ForceSequence(name, function()
			if (IsValid(client) and client.nwAct == data and
				client:LookupSequence(data.hold) > 0) then
				client:ForceSequence(data.hold, nil, 0)
			end
		end)
	elseif (data.bLoop) then
		client:ForceSequence(name, nil, 0)
	else

		client:ForceSequence(name, function()
			NETWORK.act.Release(client)
		end)
	end
end

net.Receive("nwActGesture", function(_, client)
	local index = net.ReadUInt(8)
	local data = NETWORK.act.GetGestures(client)[index]

	if (!data or !client:Alive() or !client:HasCharacter()) then
		return
	end

	if ((client.nwNextGesture or 0) > CurTime()) then
		return
	end

	client.nwNextGesture = CurTime() + 0.5

	local name = NETWORK.act.ResolveSequence(client, data)

	if (!name) then
		return Notice(client, "actNoSequence")
	end

	client:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM,
		client:LookupSequence(name), 0, true)

	net.Start("nwActPlay")
		net.WriteEntity(client)
		net.WriteUInt(index, 8)
	net.SendPVS(client:GetPos())
end)

net.Receive("nwActRun", function(_, client)
	local index = net.ReadUInt(8)

	NETWORK.act.Play(client, NETWORK.act.GetActs(client)[index])
end)

net.Receive("nwActMood", function(_, client)
	local index = net.ReadUInt(4)
	local mood = NETWORK.act.moods[index]

	if (!mood or !client:HasCharacter() or !NETWORK.act.HasMood(client)) then
		return
	end

	client:SetNWInt("nwMood", index)

	NETWORK.act.ResetGestures(client)
end)

net.Receive("nwActWalk", function(_, client)
	local index = net.ReadUInt(4)

	if (!NETWORK.act.walks[index] or !client:HasCharacter() or
		!NETWORK.act.HasWalk(client)) then
		return
	end

	client:SetNWInt("nwWalk", index)
end)

net.Receive("nwActVoice", function(_, client)
	local index = net.ReadUInt(4)

	if (!NETWORK.act.voiceModes[index] or !client:HasCharacter()) then
		return
	end

	client:SetNWInt("nwVoiceMode", index)
end)

net.Receive("nwActRadio", function(_, client)
	if (!client:HasCharacter() or !NETWORK.act.CanUseRadio(client)) then
		return
	end

	if ((client.nwNextRadio or 0) > CurTime()) then
		return
	end

	client.nwNextRadio = CurTime() + 0.3

	local bOn = !NETWORK.act.IsRadioOn(client)

	client:SetNWBool("nwRadio", bOn)

	Notice(client, bOn and "radioOn" or "radioOff")
end)

function NETWORK.act.SharesRadio(speaker, listener)
	if (!NETWORK.act.IsRadioOn(speaker)) then
		return false
	end

	local squad = speaker:GetNWString("nwSquad", "")

	return squad != "" and listener:GetNWString("nwSquad", "") == squad
end

local function CanHear(listener, speaker)

	if (speaker:GetNWBool("nwHidden", false) and !listener:IsAdmin()) then
		return false
	end

	if (NETWORK.medical and NETWORK.medical.IsSilenced(speaker)) then
		return false
	end

	local bRadio = false
	local canRadio = speaker:HasCharacter() and listener:HasCharacter() and speaker:Alive() and listener:Alive()

	if (canRadio and speaker:IsCombine() and listener:IsCombine() and
		speaker:GetCharacterFaction() == listener:GetCharacterFaction() and
		speaker:GetInfoNum("network_builtin_radio_tx", 1) == 1 and
		listener:GetInfoNum("network_builtin_radio_rx", 1) == 1 and !listener.nwRadioMute) then
		bRadio = true
	elseif (canRadio and NETWORK.act.SharesRadio(speaker, listener) and !listener.nwRadioMute and
		(!speaker:IsCombine() or speaker:GetInfoNum("network_builtin_radio_tx", 1) == 1) and
		(!listener:IsCombine() or listener:GetInfoNum("network_builtin_radio_rx", 1) == 1)) then
		bRadio = true
	elseif (canRadio and NETWORK.radio and NETWORK.radio.CanHearVoice and
		NETWORK.radio.CanHearVoice(listener, speaker)) then
		bRadio = true
	end

	if (bRadio and !speaker:GetNWBool("nwVoiceRadio", false)) then

		speaker:SetNWBool("nwVoiceRadio", true)
	end

	local range = NETWORK.act.GetVoiceRange(speaker) or 512
	local bNear = listener:GetPos():DistToSqr(speaker:GetPos()) <= range * range

	if (bNear) then
		return true, true
	end

	if (bRadio) then
		return true, false
	end

	return false, true
end

local function TraceHandler(err)
	return debug.traceback(tostring(err), 2)
end

NETWORK.act.CanHear = CanHear

hook.Add("PlayerCanHearPlayersVoice", "nwVoice", function(listener, speaker)
	if (!IsValid(listener) or !IsValid(speaker)) then
		return
	end

	local bOk, canHear, b3D = xpcall(CanHear, TraceHandler, listener, speaker)

	if (!bOk) then
		NETWORK.act.lastVoiceError = tostring(canHear)

		if ((NETWORK.act.nextVoiceError or 0) < CurTime()) then
			NETWORK.act.nextVoiceError = CurTime() + 5

			ErrorNoHalt("[Network] Ошибка расчёта слышимости войса (" ..
				tostring(listener) .. " слушает " .. tostring(speaker) .. "): " ..
				tostring(canHear) .. "\n")
		end

		local bRadioOk, bRadio = pcall(function()
			return NETWORK.radio and NETWORK.radio.CanHearVoice and
				NETWORK.radio.CanHearVoice(listener, speaker) or false
		end)

		if (bRadioOk and bRadio) then
			return true, false
		end

		return listener:GetPos():DistToSqr(speaker:GetPos()) <= 262144, true
	end

	return canHear, b3D
end)

hook.Add("NetworkVoiceEnded", "nwVoiceRadio", function(client)
	if (IsValid(client) and client:GetNWBool("nwVoiceRadio", false)) then
		client:SetNWBool("nwVoiceRadio", false)
	end
end)

hook.Remove("PlayerCanHearPlayersVoice", "nwAct")
hook.Remove("PlayerCanHearPlayersVoice", "nwNoclipHide")

local function RadioState(client)
	local R = NETWORK.radio
	local freq = R and R.GetFreq(client) or ""
	local bItem = R and R.FindItem and R.FindItem(client) != nil

	return string.format("частота %s, передача %s, эфир %s, рация %s",
		freq != "" and freq or "нет",
		(R and R.IsTransmitting(client)) and "ВКЛ" or "выкл",
		client.nwRadioMute and "ЗАГЛУШЁН" or "слышен",
		bItem and "есть" or "НЕТ")
end

local function ModuleState()
	local V = NETWORK.voicefx
	local bLoaded = V and V.bLoaded and istable(eightbit)
	local dual = GetConVar("network_voice_dualpass")

	return string.format("gm_8bit %s | два прохода: %s",
		bLoaded and ("v" .. tostring(eightbit.VERSION or "?")) or "НЕ загружен",
		(dual and dual:GetBool()) and "ВКЛ" or "выкл (один поток всем)")
end

NETWORK.command.Register("voicedebug", {
	description = "cmdVoicedebug",
	usage = "/voicedebug",
	adminOnly = true,
	OnRun = function(command, client)
		Notice(client, ModuleState())
		Notice(client, "Я: " .. RadioState(client))

		if (NETWORK.act.lastVoiceError) then
			Notice(client, "Последняя ошибка CanHear: " ..
				string.sub(NETWORK.act.lastVoiceError, 1, 200))
		end

		for _, other in ipairs(player.GetAll()) do
			if (other == client) then
				continue
			end

			local bOk, canHear, b3D = pcall(CanHear, client, other)
			local distance = math.Round(client:GetPos():Distance(other:GetPos()))
			local range = NETWORK.act.GetVoiceRange(other) or 512
			local bRadio = NETWORK.radio and NETWORK.radio.CanHearVoice and
				NETWORK.radio.CanHearVoice(client, other) or false

			Notice(client, string.format("%s: %s | %s | %d/%d юн. | %s | по рации: %s",
				other:Nick(),
				!bOk and ("ОШИБКА: " .. tostring(canHear)) or
					(canHear and "слышно" or "НЕ слышно"),
				b3D == false and "рация (2D)" or (distance <= range and "рядом (3D)" or "далеко (3D)"),
				distance, range,
				RadioState(other),
				bRadio and "да" or "нет"))
		end
	end
})

NETWORK.command.Register("radiodebug", {
	description = "cmdRadiodebug",
	usage = "/radiodebug",
	aliases = {"rdebug"},
	OnRun = function(command, client)
		local R = NETWORK.radio

		Notice(client, "Я: " .. RadioState(client) .. " | " .. ModuleState())

		if (!R or R.GetFreq(client) == "") then
			return
		end

		local count = 0

		for _, other in ipairs(player.GetAll()) do
			if (other == client or !R.SameFreq(client, other)) then
				continue
			end

			count = count + 1

			local bOkOut, bHearsMe, b3DOut = pcall(CanHear, other, client)
			local bOkIn, bIHear, b3DIn = pcall(CanHear, client, other)

			Notice(client, string.format("%s: слышит меня — %s%s; я слышу — %s%s; %s",
				other:Nick(),
				!bOkOut and "ОШИБКА" or (bHearsMe and "да" or "НЕТ"),
				(bOkOut and bHearsMe) and (b3DOut == false and " (рация)" or " (рядом)") or
					(bOkOut and !R.IsTransmitting(client) and " — передача выкл" or ""),
				!bOkIn and "ОШИБКА" or (bIHear and "да" or "НЕТ"),
				(bOkIn and bIHear) and (b3DIn == false and " (рация)" or " (рядом)") or
					(bOkIn and !R.IsTransmitting(other) and " — у него передача выкл" or ""),
				RadioState(other)))
		end

		if (count == 0) then
			Notice(client, "На частоте " .. R.GetFreq(client) .. " больше никого нет")
		end
	end
})

local EXIT_KEYS = {
	[IN_JUMP] = true,
	[IN_FORWARD] = true,
	[IN_BACK] = true,
	[IN_MOVELEFT] = true,
	[IN_MOVERIGHT] = true
}

hook.Add("KeyPress", "nwAct", function(client, key)
	if (!EXIT_KEYS[key]) then
		return
	end

	if (client.nwAct) then
		return NETWORK.act.Stop(client)
	end

	if (client.nwActExiting or client.nwActSequence) then
		NETWORK.act.Release(client)
	end
end)

hook.Add("PlayerDeath", "nwAct", function(client)
	NETWORK.act.Release(client)
end)

hook.Add("PlayerSpawn", "nwActReset", function(client)
	NETWORK.act.Release(client)
	NETWORK.act.ResetGestures(client)
end)

hook.Add("PlayerSwitchWeapon", "nwAct", function(client)
	NETWORK.act.ResetGestures(client)
end)

hook.Add("Think", "nwActRadioState", function()
	if ((NETWORK.act.nextRadioScan or 0) > CurTime()) then
		return
	end

	NETWORK.act.nextRadioScan = CurTime() + 2

	for _, client in ipairs(player.GetAll()) do
		if (client:HasCharacter()) then
			client:SetNWBool("nwHasRadio", NETWORK.act.CanUseRadio(client))
		end
	end
end)

hook.Add("NetworkCharacterLoaded", "nwAct", function(client)
	client:SetNWInt("nwMood", 1)
	client:SetNWInt("nwWalk", 1)
	client:SetNWInt("nwVoiceMode", 2)
	client:SetNWBool("nwRadio", false)
	client:SetNWBool("nwActing", false)
end)

util.AddNetworkString("nwRadioMute")

net.Receive("nwRadioMute", function(_, client)
	client.nwRadioMute = net.ReadBool()
end)
