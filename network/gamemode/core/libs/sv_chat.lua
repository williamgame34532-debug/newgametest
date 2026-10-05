util.AddNetworkString("nwChatMessage")
util.AddNetworkString("nwVoiceRadio")
util.AddNetworkString("nwChatSay")
util.AddNetworkString("nwChatTyping")

net.Receive("nwChatTyping", function(_, client)
	local id = net.ReadString()

	if (id != "" and !NETWORK.chat.Get(id)) then
		id = ""
	end

	local previous = client:GetNWString("nwTyping", "")

	client:SetNWString("nwTyping", id)

	if (id == previous or id == "") then
		return
	end

	if (id == "radio") then
		if ((client.nwNextRadioOn or 0) < CurTime()) then
			client.nwNextRadioOn = CurTime() + 2

			local sounds = NETWORK.factions.IsAlliance(client) and NETWORK.chat.radioOnRadio or
				(NETWORK.chat.radioVoice or NETWORK.chat.radioOnRadio)

			client:EmitSound(sounds[math.random(#sounds)], 60, math.random(98, 102))
		end

		return
	end

	if (!NETWORK.factions.IsAlliance(client)) then

		if (id == "cwur" and NETWORK.factions.IsCWU(client) and
			(client.nwNextRadioOn or 0) < CurTime()) then
			client.nwNextRadioOn = CurTime() + 2

			client:EmitSound("buttons/blip1.wav", 55, 130, 0.5)
		end

		return
	end

	if ((client.nwNextRadioOn or 0) > CurTime()) then
		return
	end

	client.nwNextRadioOn = CurTime() + 2

	local chatClass = NETWORK.chat.classes[id]
	local sounds = (chatClass and chatClass.bRadio) and
		NETWORK.chat.radioOnRadio or NETWORK.chat.radioOn

	client:EmitSound(sounds[math.random(#sounds)], 70, math.random(98, 102))
end)

hook.Add("PlayerDisconnected", "nwChatTyping", function(client)
	client:SetNWString("nwTyping", "")
end)

function NETWORK.chat.SendRadioVoice(speaker, class, sound)
	if (!class or !class.bRadio or !class.OnCanUse) then
		return
	end

	local listeners = {}

	for _, listener in ipairs(player.GetAll()) do
		if (listener == speaker or !listener:HasCharacter()) then
			continue
		end

		local bOn = class.OnRadioListener and class:OnRadioListener(speaker, listener) or
			(!class.OnRadioListener and class:OnCanUse(listener))

		if (bOn) then
			listeners[#listeners + 1] = listener
		end
	end

	if (#listeners == 0) then
		return
	end

	net.Start("nwVoiceRadio")
		net.WriteString(sound)
	net.Send(listeners)
end

function NETWORK.chat.Notice(client, text)
	if (!IsValid(client)) then
		return
	end

	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(text)
	net.Send(client)
end

local function Broadcast(text)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(text)
	net.Broadcast()
end

local function Gateway(id, text)
	net.Start("nwChatMessage")
		net.WriteString(id)
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(text)
	net.Broadcast()
end

hook.Add("PlayerInitialSpawn", "nwChatGateway", function(client)
	Gateway("join", L("chatJoined", client:Nick()))
end)

hook.Add("PlayerDisconnected", "nwChatGateway", function(client)
	if (!IsValid(client)) then
		return
	end

	Gateway("leave", L("chatLeft", client:Nick()))
end)

NETWORK.chat.history = NETWORK.chat.history or {}
NETWORK.chat.historyMax = 300

function NETWORK.chat.Log(speaker, id, text)
	local name = IsValid(speaker) and speaker:IsPlayer() and
		(speaker:GetCharacterName() .. " (" .. speaker:SteamID() .. ")") or "СЕРВЕР"

	MsgN(string.format("[ЧАТ][%s] %s: %s", id, name, text))

	NETWORK.chat.history[#NETWORK.chat.history + 1] = {
		time = os.date("%H:%M:%S"),
		id = id,
		name = name,
		text = text,
		position = IsValid(speaker) and speaker:IsPlayer() and
			speaker:GetPos() or nil
	}

	while (#NETWORK.chat.history > NETWORK.chat.historyMax) do
		table.remove(NETWORK.chat.history, 1)
	end
end

NETWORK.command.Register("chatlog", {
	description = "cmdChatLog",
	usage = "/chatlog [строк] [имя или тип]",
	example = "/chatlog 40 looc",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		local count = math.Clamp(math.Round(tonumber(arguments[1]) or 30), 1, 200)
		local filter = string.lower(arguments[2] or "")
		local matched = {}

		for index = #NETWORK.chat.history, 1, -1 do
			local entry = NETWORK.chat.history[index]

			if (filter == "" or entry.id == filter or
				string.find(string.lower(entry.name), filter, 1, true)) then
				table.insert(matched, 1, entry)

				if (#matched >= count) then
					break
				end
			end
		end

		if (#matched == 0) then
			return NETWORK.chat.Notice(client, "chatLogEmpty")
		end

		client:PrintMessage(HUD_PRINTCONSOLE,
			"=== ЖУРНАЛ ЧАТА (" .. #matched .. ") ===")

		for _, entry in ipairs(matched) do
			client:PrintMessage(HUD_PRINTCONSOLE, string.format(
				"[%s][%s] %s: %s", entry.time, entry.id, entry.name, entry.text))
		end

		NETWORK.chat.Notice(client, "chatLogPrinted")
	end
})

function NETWORK.chat.Send(speaker, id, text)
	NETWORK.chat.Log(speaker, id, text)

	local class = NETWORK.chat.Get(id)
	local receivers = {}

	for _, listener in ipairs(player.GetAll()) do
		if (NETWORK.chat.CanHear(class, speaker, listener)) then
			receivers[#receivers + 1] = listener
		end
	end

	if (#receivers == 0) then
		return
	end

	net.Start("nwChatMessage")
		net.WriteString(class.id)
		net.WriteEntity(speaker)
		net.WriteString(IsValid(speaker) and speaker:GetCharacterName() or "")
		net.WriteString(text)
	net.Send(receivers)

	hook.Run("NetworkChatSent", speaker, class.id, text, receivers)

	NETWORK.chat.PlayGesture(speaker, class.id)
end

util.AddNetworkString("nwChatGesture")

function NETWORK.chat.PlayGesture(speaker, classID)
	if (!IsValid(speaker) or !speaker:Alive() or !NETWORK.chat.gestureClasses[classID]) then
		return
	end

	local chance = NETWORK.config.Get("chatGestureChance") or 35

	if (chance <= 0 or math.random(100) > chance) then
		return
	end

	local velocity = speaker:GetVelocity()

	if (velocity.x * velocity.x + velocity.y * velocity.y > 400) then
		return
	end

	local name = NETWORK.chat.gestures[math.random(#NETWORK.chat.gestures)]
	local sequence = speaker:LookupSequence(name)

	if (!sequence or sequence < 0) then
		return
	end

	speaker:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, sequence, 0, true)

	net.Start("nwChatGesture")
		net.WriteEntity(speaker)
		net.WriteString(name)
	net.SendPVS(speaker:GetPos())
end

function NETWORK.chat.Broadcast(id, text)
	net.Start("nwChatMessage")
		net.WriteString(id)
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(text)
	net.Broadcast()
end

function NETWORK.chat.Handle(client, text)
	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	text = NETWORK.util.Sanitise(text, NETWORK.chat.maxLength)

	if (text == "" or !text:find("%S")) then
		return
	end

	if (NETWORK.command.Parse(client, text)) then
		return
	end

	local id, message = NETWORK.chat.Parse(client, text)

	if (message == "") then
		return
	end

	if (client:Alive() and NETWORK.medical and NETWORK.medical.IsSilenced(client) and
		!NETWORK.medical.silentAllowed[id]) then
		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString("chatDowned")
		net.Send(client)

		return
	end

	if (!client:Alive() and !NETWORK.chat.Get(id).bDead) then
		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString("chatDead")
		net.Send(client)

		return
	end

	local voices = NETWORK.voice.Parse(message)

	if (voices) then
		for _, part in ipairs(voices) do
			if (part.data) then

				part.data = NETWORK.voice.Resolve(client, part.data)

				if (!part.data) then
					voices = nil

					break
				end
			end
		end
	end

	if (voices and NETWORK.voice.classes[id]) then
		local texts = {}
		local delay = 0

		for _, part in ipairs(voices) do
			if (!part.data) then
				texts[#texts + 1] = part.text

				continue
			end

			texts[#texts + 1] = part.data.text

			local sound = NETWORK.voice.GetSound(client, part.data)

			if (sound) then
				local volume = id == "whisper" and 55 or (id == "yell" and 90 or 75)

				timer.Simple(delay, function()
					if (!IsValid(client)) then
						return
					end

					client:EmitSound(sound, volume, 100)

					NETWORK.chat.SendRadioVoice(client, class, sound)
				end)

				delay = delay + 1.6
			end
		end

		message = table.concat(texts, " ")
	end

	message = NETWORK.chat.Format(message)

	if (id == "ic" or id == "yell" or id == "whisper") then
		NETWORK.dialogue.Gesture(client)
	end

	local class = NETWORK.chat.Get(id)

	if (class.bFormat != false) then
		message = NETWORK.util.Upper(NETWORK.util.Sub(message, 1, 1)) ..
			NETWORK.util.Sub(message, 2)

		local last = NETWORK.util.Sub(message, -1)

		if (last != "." and last != "!" and last != "?" and last != "," and last != "…") then
			message = message .. "."
		end
	end

	local bAllowed, reason = NETWORK.chat.CanUse(client, class)

	if (!bAllowed) then
		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(reason or "radioNoAccess")
		net.Send(client)

		return
	end

	if ((class.delay or 0) > 0) then
		client.nwChatDelay = client.nwChatDelay or {}

		local ready = client.nwChatDelay[class.id] or 0

		if (ready > CurTime()) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString(L("chatWait", math.ceil(ready - CurTime())))
			net.Send(client)

			return
		end

		client.nwChatDelay[class.id] = CurTime() + class.delay
	end

	if (hook.Run("NetworkPlayerCanChat", client, class, message) == false) then
		return
	end

	local override = hook.Run("NetworkPlayerChat", client, class, message)

	if (override == false) then
		return
	end

	NETWORK.chat.Send(client, id, message)

	if (class.bRadio) then
		client:SetNWString("nwTyping", "")

		local sounds = NETWORK.chat.radioOff

		client:EmitSound(sounds[math.random(#sounds)], 70, math.random(98, 102))
	end
end

hook.Add("PlayerSay", "nwChat", function(client, text)
	if ((client.nwNextChat or 0) > CurTime()) then
		return ""
	end

	client.nwNextChat = CurTime() + NETWORK.chat.cooldown

	NETWORK.chat.Handle(client, text)

	return ""
end)

net.Receive("nwChatSay", function(_, client)
	local text = net.ReadString()

	if ((client.nwNextChat or 0) > CurTime()) then
		return
	end

	local id = NETWORK.chat.Parse(client, NETWORK.util.Sanitise(text, NETWORK.chat.maxLength))

	if (id == "ooc" and (client.nwNextOOC or 0) > CurTime()) then
		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString("oocWait")
		net.Send(client)

		return
	end

	if (id == "ooc") then
		client.nwNextOOC = CurTime() + 5
	end

	client.nwNextChat = CurTime() + NETWORK.chat.cooldown

	NETWORK.chat.Handle(client, text)
end)

util.AddNetworkString("nwChatSpy")

hook.Add("NetworkChatSent", "nwChatSpy", function(client, id, text, receivers)
	local line = string.format("[%s] %s: %s", id,
		IsValid(client) and client:GetCharacterName() or "?", text)

	for _, admin in ipairs(player.GetAll()) do
		if (admin:IsAdmin() and !table.HasValue(receivers or {}, admin)) then
			net.Start("nwChatSpy")
				net.WriteString(line)
			net.Send(admin)
		end
	end
end)

local gestures = {
	ic = ACT_GMOD_GESTURE_ITEM_GIVE,
	whisper = ACT_GMOD_GESTURE_ITEM_DROP,
	yell = ACT_GMOD_GESTURE_BECON,
	radio = ACT_GMOD_GESTURE_ITEM_PLACE
}

hook.Add("NetworkChatSent", "nwChatGesture", function(speaker, id, text)
	local act = gestures[id]

	if (!act or !IsValid(speaker) or !speaker:Alive()) then
		return
	end

	if (speaker:GetNWBool("nwTied", false) or
		speaker:GetNWBool("nwAiming", false)) then
		return
	end

	speaker:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, act, true)

	local repeats = math.min(math.floor(#text / 40), 3)

	for index = 1, repeats do
		timer.Simple(index * 1.1, function()
			if (IsValid(speaker) and speaker:Alive()) then
				speaker:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD,
					act, true)
			end
		end)
	end
end)

for _, path in pairs(NETWORK.chat.icons or {}) do
	resource.AddFile("materials/" .. path)
end

for _, name in ipairs({"add", "close", "translate", "send", "down", "forum", "clear", "code",
	"history", "tune", "copy", "select", "mic", "volume", "chat", "settings"}) do
	resource.AddFile("materials/framework/chat/ui_" .. name .. ".png")
end

for _, name in ipairs({"bleeding", "fracture", "hunger", "thirst", "tired", "tied", "searched",
	"radio", "sick", "sleep", "heart", "warning", "wounded", "pharmacy", "flash", "watch",
	"antenna", "eye", "hail", "gavel", "build", "chat", "lock_open", "battery_low",
	"battery_full", "hourglass", "person", "search", "lightbulb", "nightlight", "report",
	"security", "wifi", "broken", "coffee", "dining", "thumb_down", "accessibility",
	"cold", "wet", "rain", "thermostat", "cuffed"}) do
	resource.AddFile("materials/framework/status/" .. name .. ".png")
end
