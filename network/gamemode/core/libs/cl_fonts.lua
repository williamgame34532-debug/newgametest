NETWORK.fonts = NETWORK.fonts or {}

NETWORK.fonts.chains = {
	display = {"Russo One", "Play", "Bahnschrift SemiBold Condensed", "Roboto Condensed", "Arial"},
	body = {"Fira Sans Condensed", "PT Sans Narrow", "Bahnschrift", "Roboto Condensed", "Arial"},
	button = {"Play", "Russo One", "Bahnschrift Condensed", "Roboto Condensed", "Arial"},

	notice = {"Fira Sans Condensed", "Bahnschrift", "Roboto Condensed", "Ubuntu", "Arial"},

	chat = {"Fira Sans Condensed", "Play", "Bahnschrift", "Roboto Condensed", "Ubuntu", "Arial"},

	label = {"Fira Sans Condensed", "Bahnschrift Condensed", "PT Sans Narrow",
		"Ubuntu Condensed", "Arial"},

	mono = {"IBM Plex Mono", "PT Mono", "Consolas", "Courier New"}
}

local function Available(name)
	surface.CreateFont("nwProbeTarget", {font = name, size = 42, weight = 500})
	surface.CreateFont("nwProbeMissing", {font = "__nw_missing_font__", size = 42,
		weight = 500})
	surface.CreateFont("nwProbeTahoma", {font = "Tahoma", size = 42, weight = 500})

	local sample = "AWgqilm Ущий 8250"

	surface.SetFont("nwProbeTarget")

	local targetWidth, targetHeight = surface.GetTextSize(sample)

	surface.SetFont("nwProbeMissing")

	local missingWidth, missingHeight = surface.GetTextSize(sample)

	surface.SetFont("nwProbeTahoma")

	local tahomaWidth, tahomaHeight = surface.GetTextSize(sample)

	if (name != "Tahoma" and targetWidth == tahomaWidth and targetHeight == tahomaHeight) then
		return false
	end

	return targetWidth != missingWidth or targetHeight != missingHeight
end

function NETWORK.fonts.Resolve(chain)
	for _, name in ipairs(chain) do
		if (Available(name)) then
			return name
		end
	end

	return chain[#chain]
end

function NETWORK.fonts.Detect()
	NETWORK.fonts.display = NETWORK.fonts.Resolve(NETWORK.fonts.chains.display)
	NETWORK.fonts.displayLight = NETWORK.fonts.display
	NETWORK.fonts.body = NETWORK.fonts.Resolve(NETWORK.fonts.chains.body)
	NETWORK.fonts.button = NETWORK.fonts.Resolve(NETWORK.fonts.chains.button)
	NETWORK.fonts.notice = NETWORK.fonts.Resolve(NETWORK.fonts.chains.notice)
	NETWORK.fonts.chat = NETWORK.fonts.Resolve(NETWORK.fonts.chains.chat)
	NETWORK.fonts.label = NETWORK.fonts.Resolve(NETWORK.fonts.chains.label)

	NETWORK.fonts.mono = NETWORK.fonts.Resolve(NETWORK.fonts.chains.mono)
end

NETWORK.fonts.Detect()

NETWORK.fonts.chatFaces = {
	{id = "chat", label = "fontChatRound"},
	{id = "body", label = "fontChatBody"},
	{id = "notice", label = "fontChatNotice"},
	{id = "button", label = "fontChatTech"},
	{id = "label", label = "fontChatNarrow"},
	{id = "mono", label = "fontChatMono"}
}

local chatFaceConVar = CreateClientConVar("network_chat_font", "chat", true,
	false, "Гарнитура чата")
local chatSizeConVar = CreateClientConVar("network_chat_size", "18", true,
	false, "Размер шрифта чата")

local function CreateFonts()
	local chatFace = NETWORK.fonts[chatFaceConVar:GetString()] or
		NETWORK.fonts.chat
	local chatSize = math.Clamp(chatSizeConVar:GetInt(), 12, 30)

	local Sc = NETWORK.util.Scale

	NETWORK.fonts.Detect()
	local display = NETWORK.fonts.display
	local displayLight = NETWORK.fonts.displayLight
	local body = NETWORK.fonts.body
	local mono = NETWORK.fonts.mono
	local label = NETWORK.fonts.label or body

	local fonts = {
		nwBrand = {font = display, size = 108, weight = 600},
		nwBrandGlow = {font = display, size = 108, weight = 600, blursize = 15},
		nwSchema = {font = displayLight, size = 22, weight = 300},

		nwMenuGhost = {font = display, size = 92, weight = 800},
		nwMenuSub = {font = body, size = 14, weight = 500},

		nwMenuItem = {font = NETWORK.fonts.notice, size = 23, weight = 700},
		nwMenuItemSmall = {font = NETWORK.fonts.notice, size = 15, weight = 600},

		nwMenuSection = {font = NETWORK.fonts.notice, size = 18, weight = 700},
		nwMenuMeta = {font = body, size = 12, weight = 500},
		nwMenuClock = {font = displayLight, size = 34, weight = 300},
		nwMenuName = {font = display, size = 21, weight = 800},
		nwMenuFaction = {font = body, size = 13, weight = 600},
		nwTagline = {font = body, size = 17, weight = 500},
		nwButton = {font = NETWORK.fonts.button, size = 19, weight = 600},
		nwButtonSub = {font = mono, size = 12, weight = 400},
		nwAmmo = {font = NETWORK.fonts.display, size = 46, weight = 700},

		nwHudValue = {font = display, size = 28, weight = 700},
		nwHudName = {font = display, size = 26, weight = 600},
		nwHud = {font = mono, size = 13, weight = 500},

		nwHudLabel = {font = display, size = 13, weight = 600},
		nwHudLabelSmall = {font = NETWORK.fonts.button, size = 11, weight = 600},
		nwHudPlayer = {font = display, size = 21, weight = 700},
		nwHudSmall = {font = mono, size = 11, weight = 500},
		nwHeader = {font = displayLight, size = 38, weight = 300},
		nwTitle = {font = display, size = 34, weight = 600},
		nwTab = {font = NETWORK.fonts.button, size = 16, weight = 600},
		nwField = {font = body, size = 17, weight = 500},
		nwSectionLabel = {font = display, size = 14, weight = 600},
		nwNotice = {font = NETWORK.fonts.notice, size = 14, weight = 500},
		nwTag = {font = display, size = 20, weight = 600},
		nwTagSub = {font = mono, size = 12, weight = 500},
		nwTagDesc = {font = body, size = 14, weight = 400},
		nwTagDescBold = {font = body, size = 14, weight = 800},
		nwTagDescItalic = {font = body, size = 14, weight = 400, italic = true},
		nwChatBold = {font = NETWORK.fonts.chat, size = 18, weight = 900},
		nwChat = {font = NETWORK.fonts.chat, size = 18, weight = 500},
		nwChatSmall = {font = NETWORK.fonts.chat, size = 16, weight = 500},
		nwChatBig = {font = NETWORK.fonts.chat, size = 23, weight = 700},
		nwChatItalic = {font = NETWORK.fonts.chat, size = 18, weight = 500, italic = true},
		nwNoticeBig = {font = NETWORK.fonts.notice, size = 22, weight = 600},
		nwNoticeSmall = {font = NETWORK.fonts.notice, size = 16, weight = 500},
		nwTipTitle = {font = body, size = 21, weight = 600},
		nwTipBody = {font = body, size = 17, weight = 500},

		nwTermCombine = {font = "Combine Alphabet", size = 42, weight = 400},
		nwTermTitle = {font = display, size = 30, weight = 600},
		nwTermBrand = {font = display, size = 20, weight = 800},
		nwTermNav = {font = body, size = 14, weight = 700},
		nwTermTile = {font = mono, size = 13, weight = 800},
		nwTermCaption = {font = body, size = 14, weight = 500},
		nwTermButton = {font = display, size = 24, weight = 600},
		nwTermBody = {font = body, size = 20, weight = 500},
		nwTipBodyBold = {font = body, size = 17, weight = 900},
		nwTipBodyItalic = {font = body, size = 17, weight = 500, italic = true},
		nwWeaponSelect = {font = display, size = 26, weight = 600},
		nwBubble = {font = body, size = 19, weight = 600},
		nwBubbleSmall = {font = body, size = 16, weight = 500},
		nwBubbleBig = {font = body, size = 25, weight = 800},
		nwBubbleBold = {font = body, size = 19, weight = 900},
		nwBubbleItalic = {font = body, size = 19, weight = 600, italic = true},

		nwCreateTitle = {font = display, size = 96, weight = 800},
		nwDeathTitle = {font = display, size = 64, weight = 800},
		nwCreateHeader = {font = display, size = 27, weight = 800},
		nwCreateHeaderSmall = {font = display, size = 18, weight = 800},
		nwCreateBody = {font = body, size = 15, weight = 500},
		nwCreateBodyBold = {font = body, size = 15, weight = 800},
		nwCreateField = {font = body, size = 26, weight = 500},
		nwCreateButton = {font = NETWORK.fonts.button, size = 14, weight = 800, italic = true},
		nwCreateGlyph = {font = "Arial", size = 44, weight = 400},
		nwCreateValue = {font = display, size = 20, weight = 700},

		nwSideBrand = {font = display, size = 18, weight = 800},
		nwSideSub = {font = mono, size = 11, weight = 500},
		nwSideNav = {font = NETWORK.fonts.button, size = 15, weight = 700},
		nwSideClock = {font = display, size = 22, weight = 800},
		nwInvHeader = {font = display, size = 14, weight = 800},
		nwInvTitle = {font = display, size = 24, weight = 800},
		nwInvName = {font = body, size = 14, weight = 800},
		nwInvSub = {font = mono, size = 11, weight = 600},
		nwInvBody = {font = body, size = 14, weight = 500},
		nwInvBodyBold = {font = body, size = 14, weight = 800},
		nwInvBodyItalic = {font = body, size = 14, weight = 500, italic = true},
		nwInvButton = {font = NETWORK.fonts.button, size = 13, weight = 800},
		nwInvKey = {font = mono, size = 11, weight = 800},
		nwInvStat = {font = body, size = 12, weight = 700},
		nwInvBadge = {font = body, size = 12, weight = 800},
		nwInvCount = {font = display, size = 17, weight = 800},
		nwTipHead = {font = display, size = 14, weight = 800},
		nwRadialLabel = {font = body, size = 18, weight = 600},
		nwTkHeader = {font = NETWORK.fonts.button, size = 13, weight = 700},
		nwTkTab = {font = NETWORK.fonts.button, size = 15, weight = 700},
		nwTkBack = {font = display, size = 24, weight = 600},
		nwTkCell = {font = body, size = 11, weight = 700},
		nwTkCount = {font = body, size = 12, weight = 800},
		nwTkBrand = {font = NETWORK.fonts.button, size = 15, weight = 700},
		nwTkFoot = {font = NETWORK.fonts.button, size = 13, weight = 700},
		nwTkStat = {font = display, size = 22, weight = 600},
		nwTkStatSmall = {font = body, size = 11, weight = 600},

		nwStatusLabel = {font = label, size = 15, weight = 600},
		nwStatusDesc = {font = label, size = 13, weight = 400},
		nwLabel = {font = label, size = 13, weight = 500},
		nwLabelBold = {font = label, size = 13, weight = 800},
		nwChatStamp = {font = label, size = 12, weight = 500},

		nwSkillLevel = {font = display, size = 30, weight = 800},
		nwSkillName = {font = display, size = 15, weight = 800},

		nwCreditName = {font = display, size = 18, weight = 800},
		nwCreditRole = {font = label, size = 13, weight = 600},
		nwCreditAbout = {font = body, size = 14, weight = 400}
	}

	for name, data in pairs(fonts) do
		surface.CreateFont(name, {
			font = data.font,
			size = Sc(data.size),
			weight = data.weight,
			italic = data.italic,
			blursize = data.blursize and Sc(data.blursize) or nil,
			extended = true,
			antialias = true
		})
	end
end

CreateFonts()

NETWORK.fonts.chatCache = NETWORK.fonts.chatCache or {}

local chatVariants = {
	nwChat = {delta = 0, weight = 500},
	nwChatBold = {delta = 0, weight = 900},
	nwChatSmall = {delta = -2, weight = 500},
	nwChatBig = {delta = 5, weight = 700},
	nwChatItalic = {delta = 0, weight = 500, italic = true}
}

function NETWORK.fonts.GetChat(base)
	local data = chatVariants[base]

	if (!data) then
		return base
	end

	local face = chatFaceConVar:GetString()
	local size = math.Clamp(chatSizeConVar:GetInt(), 12, 30)
	local name = base .. "_" .. face .. "_" .. size

	if (NETWORK.fonts.chatCache[name]) then
		return name
	end

	surface.CreateFont(name, {
		font = NETWORK.fonts[face] or NETWORK.fonts.chat,
		size = NETWORK.util.Scale(size + data.delta),
		weight = data.weight,
		italic = data.italic,
		extended = true,
		antialias = true
	})

	NETWORK.fonts.chatCache[name] = true

	return name
end

hook.Add("OnScreenSizeChanged", "nwChatFonts", function()
	NETWORK.fonts.chatCache = {}
end)

hook.Add("OnScreenSizeChanged", "nwFonts", CreateFonts)

concommand.Add("network_reloadfonts", CreateFonts)

concommand.Add("network_fonts", function()
	NETWORK.util.Print("Основной: " .. tostring(NETWORK.fonts.display))
	NETWORK.util.Print("Текст: " .. tostring(NETWORK.fonts.body))
	NETWORK.util.Print("Кнопки: " .. tostring(NETWORK.fonts.button))
	NETWORK.util.Print("Уведомления: " .. tostring(NETWORK.fonts.notice))
	NETWORK.util.Print("Чат: " .. tostring(NETWORK.fonts.chat))
	NETWORK.util.Print("Подписи: " .. tostring(NETWORK.fonts.label))
	NETWORK.util.Print("Моно: " .. tostring(NETWORK.fonts.mono))
end)
