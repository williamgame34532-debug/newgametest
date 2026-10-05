NETWORK.chat = NETWORK.chat or {}
NETWORK.chat.classes = NETWORK.chat.classes or {}
NETWORK.chat.order = NETWORK.chat.order or {}

NETWORK.chat.maxLength = 320
NETWORK.chat.cooldown = 0.35

function NETWORK.chat.Register(id, data)
	data.id = id
	data.prefix = data.prefix or {}
	data.color = data.color or Color(226, 238, 248)
	data.font = data.font or "nwChat"
	data.radius = data.radius or 280
	data.order = data.order or (#NETWORK.chat.order + 1) * 10

	if (!NETWORK.chat.classes[id]) then
		NETWORK.chat.order[#NETWORK.chat.order + 1] = id
	end

	NETWORK.chat.classes[id] = data
	NETWORK.chat.prefixCache = nil

	return data
end

local CHAT_ICONS = "framework/chat/"

NETWORK.chat.icons = {
	ic = CHAT_ICONS .. "md_ic.png",
	whisper = CHAT_ICONS .. "md_whisper.png",
	yell = CHAT_ICONS .. "md_yell.png",
	radiocp = CHAT_ICONS .. "md_radio_cp.png",
	radiotac = CHAT_ICONS .. "md_radio_cp.png",
	squadc = CHAT_ICONS .. "md_radio_squad.png",
	radiota = CHAT_ICONS .. "md_radio_ota.png",
	radio = CHAT_ICONS .. "md_radio.png",
	notice = CHAT_ICONS .. "md_notice.png",
	announce = CHAT_ICONS .. "md_announce.png",
	cityannounce = CHAT_ICONS .. "md_announce.png",
	dispatch = CHAT_ICONS .. "md_dispatch.png",
	center = CHAT_ICONS .. "md_center.png",
	report = CHAT_ICONS .. "md_report.png",
	admin = CHAT_ICONS .. "md_admin.png",
	join = CHAT_ICONS .. "md_join.png",
	leave = CHAT_ICONS .. "md_leave.png",
	vchat = CHAT_ICONS .. "md_mic.png",

	me = CHAT_ICONS .. "md_me.png",
	it = CHAT_ICONS .. "md_it.png",
	ooc = CHAT_ICONS .. "md_ooc.png",
	looc = CHAT_ICONS .. "md_looc.png",
	pm = CHAT_ICONS .. "md_pm.png",
	pmOut = CHAT_ICONS .. "md_pm_out.png",
	advert = CHAT_ICONS .. "md_advert.png",
	cwur = CHAT_ICONS .. "md_cwur.png"
}

NETWORK.chat.tintedIcons = {
	[CHAT_ICONS .. "ic_chat.png"] = true,
	[CHAT_ICONS .. "w_chat.png"] = true,
	[CHAT_ICONS .. "yell_chat.png"] = true,
	[CHAT_ICONS .. "radio.png"] = true,
	[CHAT_ICONS .. "radio_cp.png"] = true,
	[CHAT_ICONS .. "radio_ota.png"] = true,
	[CHAT_ICONS .. "radio_squad.png"] = true,
	[CHAT_ICONS .. "other.png"] = true
}

for _, path in pairs(NETWORK.chat.icons) do
	if (string.find(path, "/md_", 1, true)) then
		NETWORK.chat.tintedIcons[path] = true
	end
end

function NETWORK.chat.IsTintedIcon(path)
	return NETWORK.chat.tintedIcons[path] == true
end

NETWORK.chat.gestures = {"g_fist_l", "g_lhandease", "g_look_small", "g_medurgent_mid"}
NETWORK.chat.gestureClasses = {ic = true, yell = true, whisper = true}

function NETWORK.chat.GetIcon(id)
	return NETWORK.chat.icons[id or ""]
end

function NETWORK.chat.GetClasses()
	local list = {}

	for _, id in ipairs(NETWORK.chat.order) do
		local class = NETWORK.chat.classes[id]

		if (class) then
			list[#list + 1] = class
		end
	end

	return list
end

function NETWORK.chat.GetPrefixes()
	if (NETWORK.chat.prefixCache) then
		return NETWORK.chat.prefixCache
	end

	local list = {}

	for _, id in ipairs(NETWORK.chat.order) do
		local class = NETWORK.chat.classes[id]

		for _, prefix in ipairs(class.prefix) do
			list[#list + 1] = {
				prefix = NETWORK.util.Lower(prefix),
				length = string.len(prefix),
				class = class
			}
		end
	end

	table.sort(list, function(a, b)
		if (a.length == b.length) then
			return a.class.order < b.class.order
		end

		return a.length > b.length
	end)

	NETWORK.chat.prefixCache = list

	return list
end

function NETWORK.chat.Get(id)
	return NETWORK.chat.classes[id] or NETWORK.chat.classes.ic
end

function NETWORK.chat.GetAll()
	local list = {}

	for _, id in ipairs(NETWORK.chat.order) do
		list[#list + 1] = NETWORK.chat.classes[id]
	end

	table.sort(list, function(a, b)
		return a.order < b.order
	end)

	return list
end

function NETWORK.chat.Parse(client, text)
	local lower = NETWORK.util.Lower(text)

	for _, entry in ipairs(NETWORK.chat.GetPrefixes()) do
		local length = entry.length

		if (string.sub(lower, 1, length + 1) == entry.prefix .. " ") then
			return entry.class.id, string.Trim(string.sub(text, length + 2))
		end

		if (entry.class.bNoSpaceAfter and string.sub(lower, 1, length) == entry.prefix) then
			return entry.class.id, string.Trim(string.sub(text, length + 1))
		end
	end

	return "ic", string.Trim(text)
end

function NETWORK.chat.GetTypingClass(text)
	if (text == "") then
		return "ic"
	end

	if (string.sub(text, 1, 1) == "/") then
		local space = string.find(text, " ")
		local name = string.sub(text, 2, space and space - 1 or nil)

		if (NETWORK.command.Get(name)) then
			return
		end
	end

	local id = NETWORK.chat.Parse(nil, text)
	local class = NETWORK.chat.Get(id)

	if (!class or !class.bBubble) then
		return
	end

	return id
end

function NETWORK.chat.Format(text)
	text = string.Trim(text)

	if (text == "") then
		return text
	end

	local first = NETWORK.util.Sub(text, 1, 1)

	text = NETWORK.util.Upper(first) .. NETWORK.util.Sub(text, 2)

	local last = NETWORK.util.Sub(text, -1)

	if (last != "." and last != "!" and last != "?" and last != "…" and last != ")" and
		last != "\"") then
		text = text .. "."
	end

	return text
end

function NETWORK.chat.CanHear(class, speaker, listener)
	if (!IsValid(speaker) or !IsValid(listener)) then
		return false
	end

	if (class.CanHear) then
		return class:CanHear(speaker, listener) != false
	end

	if (class.bGlobal) then
		return true
	end

	if (!listener:HasCharacter()) then
		return false
	end

	return speaker:GetPos():DistToSqr(listener:GetPos()) <= class.radius * class.radius
end

NETWORK.chat.Register("ic", {
	bBubble = true,
	format = "chatIC",
	color = Color(226, 238, 248),
	font = "nwChat",
	radius = 280,
	order = 10
})

NETWORK.chat.Register("whisper", {
	bBubble = true,
	prefix = {"/w", "/whisp", "/whisper"},
	bNoSpaceAfter = true,
	format = "chatWhisper",
	color = Color(132, 152, 172),
	font = "nwChatSmall",
	radius = 110,
	order = 20
})

NETWORK.chat.Register("yell", {
	bBubble = true,
	prefix = {"/y", "/yell"},
	bNoSpaceAfter = true,
	format = "chatYell",
	color = Color(255, 138, 108),
	font = "nwChatBig",
	radius = 640,
	order = 30
})

NETWORK.chat.Register("me", {
	bBubble = true,
	prefix = {"/me", "/action"},
	format = "chatMe",
	color = Color(186, 142, 255),
	font = "nwChatItalic",
	radius = 280,
	order = 40
})

NETWORK.chat.Register("it", {
	prefix = {"/it", "/env"},
	format = "chatIt",
	bNoName = true,
	color = Color(158, 128, 220),
	font = "nwChatItalic",
	radius = 280,
	order = 50
})

NETWORK.chat.Register("looc", {
	prefix = {"//", "/looc"},
	bNoSpaceAfter = true,
	format = "chatLOOC",
	color = Color(240, 190, 84),
	font = "nwChatSmall",
	radius = 320,
	order = 60
})

NETWORK.chat.Register("pm", {
	prefix = {},
	format = "chatPM",
	color = Color(196, 140, 240),
	font = "nwChat",
	bGlobal = true,

	bRealName = true,
	order = 80
})

NETWORK.chat.Register("pmOut", {
	prefix = {},
	format = "chatPMOut",
	color = Color(196, 140, 240),
	font = "nwChat",
	bGlobal = true,
	bRealName = true,
	order = 81
})

NETWORK.chat.Register("advert", {
	prefix = {},
	format = "chatAdvert",
	color = Color(240, 200, 90),
	font = "nwChat",
	bGlobal = true,
	order = 75
})

local RADIO_RANGE = 320

local RADIO_PATH = "framework/cmb/radio/"

NETWORK.chat.radioOn = {
	RADIO_PATH .. "on1.wav",
	RADIO_PATH .. "on2.wav",
	RADIO_PATH .. "on3.wav",
	RADIO_PATH .. "on4.wav"
}

NETWORK.chat.radioOnRadio = {
	RADIO_PATH .. "on5.wav",
	RADIO_PATH .. "on6.wav",
	RADIO_PATH .. "on7.wav"
}

NETWORK.chat.radioOff = {
	RADIO_PATH .. "off1.wav",
	RADIO_PATH .. "off2.wav",
	RADIO_PATH .. "off3.wav",
	RADIO_PATH .. "off4.wav",
	RADIO_PATH .. "off5.wav",
	RADIO_PATH .. "off6.wav",
	RADIO_PATH .. "off7.wav",
	RADIO_PATH .. "off8.wav",
	RADIO_PATH .. "off9.wav"
}

NETWORK.chat.Register("radiocp", {
	bBubble = true,
	prefix = {"/cp", "/rcp"},
	format = "chatRadioCP",
	color = Color(96, 186, 255),
	font = "nwChat",
	radius = RADIO_RANGE,
	order = 15,

	bSolidColor = true,
	bRadio = true,

	CanHear = function(class, speaker, listener)
		if (!listener:HasCharacter()) then
			return false
		end

		if (class:OnCanUse(listener)) then
			return true
		end

		return speaker:GetPos():DistToSqr(listener:GetPos()) <=
			class.radius * class.radius
	end,
	OnCanUse = function(class, client)
		return NETWORK.factions.HasRadio(client, "radiocp")
	end
})

NETWORK.chat.Register("radiotac", {
	bBubble = true,
	prefix = {"/tac", "/rtac"},
	format = "chatRadioTAC",
	color = Color(150, 214, 170),
	font = "nwChat",
	radius = RADIO_RANGE,
	order = 17,
	bSolidColor = true,
	bRadio = true,
	CanHear = function(class, speaker, listener)
		if (!listener:HasCharacter()) then
			return false
		end

		if (class:OnCanUse(listener)) then
			return true
		end

		return speaker:GetPos():DistToSqr(listener:GetPos()) <=
			class.radius * class.radius
	end,
	OnCanUse = function(class, client)
		return NETWORK.factions.HasRadio(client, "radiotac")
	end
})

NETWORK.chat.Register("squadc", {
	bBubble = true,
	prefix = {"/squadc", "/sq"},
	format = "chatRadioSquad",
	color = Color(120, 226, 150),
	font = "nwChat",
	radius = RADIO_RANGE,
	order = 17,
	bSolidColor = true,
	bRadio = true,
	CanHear = function(class, speaker, listener)
		if (!listener:HasCharacter()) then
			return false
		end

		if (class:OnRadioListener(speaker, listener)) then
			return true
		end

		return speaker:GetPos():DistToSqr(listener:GetPos()) <=
			class.radius * class.radius
	end,

	OnRadioListener = function(class, speaker, listener)
		local squad = speaker:GetNWString("nwSquad", "")

		return squad != "" and listener:GetNWString("nwSquad", "") == squad
	end,
	OnCanUse = function(class, client)
		if (client:GetNWString("nwSquad", "") == "") then
			return false, "squadNone"
		end

		return true
	end
})

NETWORK.chat.Register("announce", {
	format = "chatAnnounce",
	color = Color(228, 76, 68),
	font = "nwChat",
	order = 19,
	bNoName = true,
	bSolidColor = true
})

NETWORK.chat.Register("radiota", {
	bBubble = true,
	prefix = {"/ota", "/rota"},
	format = "chatRadioOTA",
	color = Color(232, 84, 76),
	font = "nwChat",
	radius = RADIO_RANGE,
	order = 16,
	bSolidColor = true,
	bRadio = true,
	CanHear = function(class, speaker, listener)
		if (!listener:HasCharacter()) then
			return false
		end

		if (class:OnCanUse(listener)) then
			return true
		end

		return speaker:GetPos():DistToSqr(listener:GetPos()) <=
			class.radius * class.radius
	end,
	OnCanUse = function(class, client)
		return NETWORK.factions.HasRadio(client, "radiota")
	end
})

function NETWORK.chat.CanUse(client, class)
	if (!class or !class.OnCanUse) then
		return true
	end

	if (!IsValid(client) or !client:HasCharacter()) then
		return false, "radioNoAccess"
	end

	local bCan, reason = class:OnCanUse(client)

	if (bCan == false) then
		return false, reason or "radioNoAccess"
	end

	return true
end

NETWORK.chat.Register("dispatch", {
	format = "chatDispatch",
	color = Color(232, 72, 66),
	font = "nwChat",
	bGlobal = true,
	bNoName = true,
	order = 5
})

NETWORK.chat.Register("center", {
	format = "chatCenter",
	color = Color(86, 150, 226),
	font = "nwChat",
	bGlobal = true,
	bNoName = true,
	order = 6
})

NETWORK.chat.Register("join", {
	format = "chatJoin",
	color = Color(120, 190, 140),
	font = "nwChatSmall",
	bGlobal = true,
	bNoName = true,
	order = 90
})

NETWORK.chat.Register("leave", {
	format = "chatJoin",
	color = Color(150, 150, 160),
	font = "nwChatSmall",
	bGlobal = true,
	bNoName = true,
	order = 91
})

NETWORK.chat.Register("report", {
	prefix = {"@"},
	bNoSpaceAfter = true,
	bDead = true,
	format = "chatReport",
	color = Color(240, 96, 96),
	font = "nwChat",
	bRealName = true,
	order = 72,
	CanHear = function(class, speaker, listener)
		return listener == speaker or listener:IsAdmin()
	end
})

NETWORK.chat.Register("admin", {
	prefix = {"/achat", "/adminchat"},
	bDead = true,
	format = "chatAdmin",
	color = Color(214, 150, 70),
	font = "nwChat",
	bRealName = true,
	order = 73,
	CanHear = function(class, speaker, listener)
		return listener:IsAdmin()
	end,
	CanSay = function(class, speaker)
		return speaker:IsAdmin()
	end
})

NETWORK.chat.Register("ooc", {
	prefix = {"/ooc"},
	bDead = true,
	format = "chatOOC",
	color = Color(255, 132, 62),
	font = "nwChat",
	bGlobal = true,
	order = 70,
	delay = 5,

	bRealName = true
})

NETWORK.chat.Register("cwur", {
	bRadio = true,
	prefix = {"/cwur"},
	format = "chatCWUR",
	color = Color(240, 196, 84),
	bSolidColor = true,
	font = "nwChat",
	order = 46,
	CanHear = function(class, speaker, listener)
		return NETWORK.factions.IsCWU(listener) or
			NETWORK.factions.IsAlliance(listener)
	end,
	CanSay = function(class, speaker)
		return NETWORK.factions.IsCWU(speaker) or
			NETWORK.factions.IsAlliance(speaker)
	end
})
