local muteCWUR = CreateClientConVar("network_mute_cwur", "0", true, false,
	"Скрывать рацию ГСР (/cwur)")

local chatIcons = CreateClientConVar("network_chat_icons_v2", "1", true, false,
	"Значки типов чата перед сообщениями")

NETWORK.chat = NETWORK.chat or {}

NETWORK.chat.clientColors = {
	me = Color(178, 152, 236),
	it = Color(204, 178, 116),
	ooc = Color(150, 156, 164),
	looc = Color(128, 134, 142)
}

function NETWORK.chat.ApplyClientPalette()
	local classes = NETWORK.chat.classes

	if (!classes) then
		return
	end

	for id, color in pairs(NETWORK.chat.clientColors) do
		local class = classes[id]

		if (class and class.color != color) then
			class.color = color
		end
	end
end

local muteRadioVoice = CreateClientConVar("network_mute_radio", "0", true,
	false, "Не слышать голос по рации")

local function SendRadioMute()
	net.Start("nwRadioMute")
		net.WriteBool(muteRadioVoice:GetBool())
	net.SendToServer()
end

cvars.AddChangeCallback("network_mute_radio", function()
	SendRadioMute()
end, "nwRadioMute")

hook.Add("InitPostEntity", "nwRadioMute", function()
	timer.Simple(2, SendRadioMute)
end)

function NETWORK.chat.ApplyStyles(text, baseFont)
	local result = text
	local bold = NETWORK.fonts.GetChat("nwChatBold")
	local italic = NETWORK.fonts.GetChat("nwChatItalic")

	baseFont = NETWORK.fonts.GetChat(baseFont)

	result = string.gsub(result, "%*%*(.-)%*%*", function(inner)
		if (inner == "") then
			return "**" .. inner .. "**"
		end

		return "<font=" .. bold .. ">" .. inner .. "</font><font=" .. baseFont .. ">"
	end)

	result = string.gsub(result, "%*(.-)%*", function(inner)
		if (inner == "") then
			return "*" .. inner .. "*"
		end

		return "<font=" .. italic .. ">" .. inner .. "</font><font=" .. baseFont .. ">"
	end)

	return result
end

local function Escape(text)
	text = string.gsub(text, "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")

	return text
end

local function Tag(color)
	return string.format("<color=%d,%d,%d>", color.r, color.g, color.b)
end

function NETWORK.chat.GetSpeakerColor(speaker)
	if (!IsValid(speaker)) then
		return NETWORK.theme.text
	end

	if (speaker:IsPlayer() and !LocalPlayer():KnowsRoleOf(speaker)) then
		return NETWORK.recognition.strangerColor
	end

	local factionID = speaker:GetCharacterFaction()
	local faction = factionID and NETWORK.factions.Get(factionID)

	return faction and faction.color or NETWORK.theme.text
end

NETWORK.chat.addressRange = 200
NETWORK.chat.addressDot = 0.94
NETWORK.chat.addressClasses = {ic = true, whisper = true, yell = true}

function NETWORK.chat.IsAddressed(id, speaker)
	if (!NETWORK.chat.addressClasses[id]) then
		return false
	end

	local client = LocalPlayer()

	if (!IsValid(speaker) or !IsValid(client) or speaker == client or
		!speaker:IsPlayer()) then
		return false
	end

	local origin = speaker:EyePos()
	local offset = client:EyePos() - origin
	local distance = offset:Length()

	if (distance > NETWORK.chat.addressRange or distance < 1) then
		return false
	end

	offset:Normalize()

	return offset:Dot(speaker:EyeAngles():Forward()) >= NETWORK.chat.addressDot
end

function NETWORK.chat.IconsEnabled()
	return chatIcons:GetBool()
end

function NETWORK.chat.GetLineIcon(id)
	if (!chatIcons:GetBool()) then
		return
	end

	return NETWORK.chat.GetIcon(id)
end

NETWORK.chat.allianceWrapped = {ic = true, whisper = true, yell = true}

function NETWORK.chat.WrapAlliance(id, speaker, text)
	if (!NETWORK.chat.allianceWrapped[id]) then
		return text
	end

	if (!IsValid(speaker) or !speaker:IsPlayer() or
		!speaker:HasCharacter()) then
		return text
	end

	if (!NETWORK.factions.IsAlliance(speaker)) then
		return text
	end

	return "<:: " .. text .. " ::>"
end

function NETWORK.chat.BuildMarkup(id, speaker, name, text)
	NETWORK.chat.ApplyClientPalette()

	local class = NETWORK.chat.Get(id)
	local template = L(class.format)

	if (id == "radio" and NETWORK.radio and IsValid(speaker)) then
		local freq = NETWORK.radio.GetFreq(speaker)

		template = "[" .. (freq != "" and freq or "—") .. "] " .. template
	end

	text = NETWORK.chat.WrapAlliance(id, speaker, text)
	local open = "<font=" .. NETWORK.fonts.GetChat(class.font) .. ">"
	local body = NETWORK.chat.ApplyStyles(Escape(text), class.font)

	if (id == "cp" and IsValid(speaker) and speaker:IsPlayer() and
		speaker != LocalPlayer()) then
		local squad = speaker:GetNWString("nwSquad", "")

		if (squad != "" and
			LocalPlayer():GetNWString("nwSquad", "") == squad) then
			class = table.Copy(class)
			class.color = Color(class.color.r * 0.62, class.color.g * 0.62,
				class.color.b * 0.62)
		end
	end

	local prefix = ""

	if (NETWORK.chat.IsAddressed(id, speaker)) then
		prefix = "<font=" .. NETWORK.fonts.GetChat("nwChatBold") .. ">" ..
			Tag(NETWORK.theme.value) ..
			L("chatToYou") .. " </color></font>"
	end

	if (class.bNoName) then
		return prefix .. open .. Tag(class.color) ..
			string.format(template, body) .. "</color></font>"
	end

	local before, after = string.match(template, "^(.-)%%s(.*)$")

	if (!before) then
		return open .. Tag(class.color) .. body .. "</color></font>"
	end

	local client = LocalPlayer()

	if (!class.bRealName and IsValid(speaker) and speaker:IsPlayer() and
		!client:IsRecognised(speaker)) then
		name = speaker:GetUnknownName()
	end

	local tail = string.Explode("%s", Escape(after), false)

	local nameColor = class.bSolidColor and class.color or
		NETWORK.chat.GetSpeakerColor(speaker)

	local result = prefix .. open .. Tag(class.color) .. Escape(before) .. "</color>" ..
		Tag(nameColor) .. Escape(name or "") .. "</color>" ..
		Tag(class.color)

	local speechColor

	if (!class.bSolidColor and (id == "ic" or id == "yell" or id == "whisper")) then
		speechColor = NETWORK.chat.GetSpeechColor(speaker, id)
	end

	local bodyOpen = class.bSolidColor and Tag(class.color) or
		(speechColor and Tag(speechColor) or "")
	local bodyClose = (class.bSolidColor or speechColor) and "</color>" or ""

	for index = 1, #tail do
		result = result .. tail[index]

		if (index < #tail) then
			result = result .. "</color>" .. bodyOpen .. body .. bodyClose .. Tag(class.color)
		end
	end

	return result .. "</color></font>"
end

function NETWORK.chat.Echo(id, name, text, class)
	local line = NETWORK.util.StripStyles(text)
	local template = class and class.format and L(class.format) or nil

	if (template and string.find(template, "%%s")) then
		line = string.format(template, name or "", line)
	elseif (name and name != "") then
		line = name .. ": " .. line
	end

	local color = class and class.color or NETWORK.theme.accentSoft

	MsgC(Color(120, 130, 145), os.date("[%H:%M:%S] "), color, line, "\n")
end

function NETWORK.chat.GetSpeechColor(speaker, id)
	local base = NETWORK.theme.text

	if (IsValid(speaker) and speaker:IsPlayer() and speaker:HasCharacter()) then
		local faction = NETWORK.factions.Get(speaker:GetCharacterFaction())

		if (!LocalPlayer():KnowsRoleOf(speaker)) then
			base = NETWORK.recognition.strangerColor
		elseif (faction and faction.color) then
			base = faction.color
		end
	end

	if (id == "yell") then
		return Color(
			math.min(base.r + (255 - base.r) * 0.35, 255),
			math.min(base.g + (255 - base.g) * 0.35, 255),
			math.min(base.b + (255 - base.b) * 0.35, 255))
	end

	if (id == "whisper") then
		return Color(base.r * 0.6, base.g * 0.6, base.b * 0.6)
	end

	return base
end

function NETWORK.chat.GetShownName(id, speaker, name)
	local class = NETWORK.chat.Get(id)

	if (class and !class.bRealName and IsValid(speaker) and speaker:IsPlayer() and
		IsValid(LocalPlayer()) and !LocalPlayer():IsRecognised(speaker)) then
		return speaker:GetUnknownName()
	end

	return name
end

function NETWORK.chat.Add(id, speaker, name, text)
	NETWORK.sound.Chat(id)

	NETWORK.chat.Echo(id, NETWORK.chat.GetShownName(id, speaker, name), text, NETWORK.chat.Get(id))

	if (!IsValid(NETWORK.gui.chat)) then
		NETWORK.chat.Create()
	end

	if (!IsValid(NETWORK.gui.chat)) then
		return
	end

	NETWORK.gui.chat:AddMarkup(NETWORK.chat.BuildMarkup(id, speaker, name, text), id,
		speaker, name)

	hook.Run("NetworkChatAdded", id, speaker, name, text)
end

function NETWORK.chat.Notify(text, color)
	MsgC(Color(120, 130, 145), os.date("[%H:%M:%S] "),
		color or NETWORK.theme.accentSoft, NETWORK.util.StripStyles(text), "\n")

	if (!IsValid(NETWORK.gui.chat)) then
		NETWORK.chat.Create()
	end

	if (!IsValid(NETWORK.gui.chat)) then
		return
	end

	color = color or NETWORK.theme.accentSoft

	NETWORK.gui.chat:AddMarkup("<font=" .. NETWORK.fonts.GetChat("nwChat") ..
		">" .. Tag(color) .. Escape(text) .. "</color></font>", "notice")
end

function NETWORK.chat.Create()
	NETWORK.chat.ApplyClientPalette()

	if (IsValid(NETWORK.gui.chat)) then
		NETWORK.gui.chat:Remove()
	end

	NETWORK.gui.chat = vgui.Create("nwChatbox")

	return NETWORK.gui.chat
end

function NETWORK.chat.Say(text)
	surface.PlaySound("buttons/lightswitch2.wav")

	net.Start("nwChatSay")
		net.WriteString(string.sub(text, 1, NETWORK.chat.maxLength * 2))
	net.SendToServer()
end

net.Receive("nwVoiceRadio", function()
	local sound = net.ReadString()

	if (sound == "") then
		return
	end

	surface.PlaySound(sound)
end)

local needsEmotes = CreateClientConVar("network_needs_emotes", "1", true,
	false, "Показывать реплики о голоде и жажде")

net.Receive("nwChatGesture", function()
	local speaker = net.ReadEntity()
	local name = net.ReadString()

	if (!IsValid(speaker) or !speaker:IsPlayer()) then
		return
	end

	local sequence = speaker:LookupSequence(name)

	if (sequence and sequence >= 0) then
		speaker:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, sequence, 0, true)

		if (speaker == LocalPlayer() and NETWORK.legs and NETWORK.legs.Gesture) then
			NETWORK.legs:Gesture(GESTURE_SLOT_CUSTOM, name)
		end
	end
end)

net.Receive("nwChatMessage", function()
	local id = net.ReadString()
	local speaker = net.ReadEntity()
	local name = net.ReadString()
	local text = net.ReadString()

	if (id == "cwur" and muteCWUR:GetBool()) then
		return
	end

	if (id == "notice") then
		NETWORK.gui.Notify(L(text), NETWORK.theme.danger)

		return
	end

	if (NETWORK.needs and NETWORK.needs.IsEmote(text)) then
		if (!needsEmotes:GetBool()) then
			return
		end

		text = NETWORK.needs.StripMark(text)
	end

	NETWORK.chat.Add(id, speaker, name, text)

	hook.Run("NetworkChatMessage", id, speaker, name, text)
end)

chat.nwAddText = chat.nwAddText or chat.AddText

function chat.AddText(...)
	local parts = {...}
	local color = NETWORK.theme.text
	local text = ""

	for _, value in ipairs(parts) do
		if (IsColor(value)) then
			color = value
		elseif (isstring(value)) then
			text = text .. value
		elseif (isentity(value) and value:IsPlayer()) then
			text = text .. value:GetCharacterName()
		end
	end

	if (text != "") then
		NETWORK.chat.Notify(text, color)
	end

	MsgN(text)
end

hook.Add("PlayerBindPress", "nwChat", function(client, bind, pressed)
	if (!pressed or !string.find(string.lower(bind), "messagemode")) then
		return
	end

	if (!IsValid(NETWORK.gui.chat)) then
		NETWORK.chat.Create()
	end

	if (IsValid(NETWORK.gui.chat)) then
		NETWORK.gui.chat:SetActive(true)
	end

	return true
end)

hook.Add("InitPostEntity", "nwChat", function()
	NETWORK.chat.Create()
end)

hook.Add("OnScreenSizeChanged", "nwChat", function()
	NETWORK.chat.Create()
end)

concommand.Add("network_chat_reload", function()
	NETWORK.chat.Create()
end)

net.Receive("nwChatSpy", function()
	MsgC(Color(150, 150, 160), os.date("[%H:%M:%S] "),
		Color(200, 170, 90), "[SPY] ", color_white, net.ReadString(), "\n")
end)
