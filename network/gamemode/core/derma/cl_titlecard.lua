local PANEL = {}

NETWORK.gui.titleTime = 4.6

function PANEL:Init()
	NETWORK.gui.title = self

	self.startTime = RealTime()
	self.bClosing = false

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)

	surface.PlaySound("buttons/combine_button5.wav")
end

function PANEL:OnRemove()
	if (NETWORK.gui.title == self) then
		NETWORK.gui.title = nil
	end
end

function PANEL:Skip()
	if (self.bClosing) then
		return
	end

	self.bClosing = true
	self.closeTime = RealTime()
end

function PANEL:Think()
	self:MoveToFront()

	local age = RealTime() - self.startTime

	if (!self.bClosing and (input.IsKeyDown(KEY_ESCAPE) or input.IsKeyDown(KEY_SPACE) or
		input.IsMouseDown(MOUSE_LEFT)) and age > 0.4) then
		self:Skip()
	end

	if (age > NETWORK.gui.titleTime + 0.6 or
		(self.bClosing and RealTime() - self.closeTime > 0.5)) then
		self:Remove()
	end
end

function PANEL:GetBody()
	local age = RealTime() - self.startTime
	local total = NETWORK.gui.titleTime
	local body = math.Clamp(age / 0.6, 0, 1)

	if (self.bClosing) then
		return body * (1 - math.Clamp((RealTime() - self.closeTime) / 0.5, 0, 1))
	end

	return body * (1 - math.Clamp((age - (total - 0.6)) / 0.6, 0, 1))
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local age = RealTime() - self.startTime
	local body = util.EaseInOut(self:GetBody())
	local client = LocalPlayer()

	if (body <= 0.01) then
		return
	end

	util.DrawBlur(self, 6 * body)

	surface.SetDrawColor(0, 0, 0, 150 * body)
	surface.DrawRect(0, 0, width, height)

	local bars = math.Round(height * 0.16 * body)

	surface.SetDrawColor(0, 0, 0, 250)
	surface.DrawRect(0, 0, width, bars)
	surface.DrawRect(0, height - bars, width, bars)

	local accent = theme.combine
	local inset = Sc(30)
	local tick = Sc(26)
	local thick = math.max(Sc(2), 2)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 200 * body)
	surface.DrawRect(inset, bars + inset, tick, thick)
	surface.DrawRect(inset, bars + inset, thick, tick)
	surface.DrawRect(width - inset - tick, bars + inset, tick, thick)
	surface.DrawRect(width - inset - thick, bars + inset, thick, tick)
	surface.DrawRect(inset, height - bars - inset - thick, tick, thick)
	surface.DrawRect(inset, height - bars - inset - tick, thick, tick)
	surface.DrawRect(width - inset - tick, height - bars - inset - thick, tick, thick)
	surface.DrawRect(width - inset - thick, height - bars - inset - tick, thick, tick)

	local scanY = bars + ((age * 0.22) % 1) * (height - bars * 2)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 40 * body)
	surface.DrawRect(0, math.Round(scanY), width, math.max(Sc(2), 2))

	local text = util.Upper(L("titleCity"))
	local length = utf8.len(text) or #text
	local typed = math.min(math.floor(math.max(age - 0.35, 0) * 14), length)
	local visible = utf8.sub and utf8.sub(text, 1, typed) or string.sub(text, 1, typed)
	local centerX = math.Round(width * 0.5)
	local centerY = math.Round(height * 0.44)
	local spacing = Sc(12)
	local fullWidth = util.TextSpacedSize(text, "nwSchema", spacing)

	util.DrawTextSpaced(visible, "nwSchema", centerX - math.Round(fullWidth * 0.5), centerY,
		ColorAlpha(theme.text, 255 * body), spacing, TEXT_ALIGN_CENTER)

	if (typed < length and math.floor(age * 6) % 2 == 0) then
		local caretX = centerX - math.Round(fullWidth * 0.5) +
			util.TextSpacedSize(visible, "nwSchema", spacing)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 230 * body)
		surface.DrawRect(caretX + Sc(4), centerY - Sc(16), Sc(3), Sc(32))
	end

	local rule = math.Round(fullWidth * 0.7 * math.Clamp((age - 0.5) / 0.8, 0, 1))

	surface.SetDrawColor(accent.r, accent.g, accent.b, 220 * body)
	surface.DrawRect(centerX - math.Round(rule * 0.5), centerY + Sc(38), rule, math.max(Sc(2), 2))

	local sub = math.Clamp((age - 1.3) / 0.6, 0, 1) * body

	if (sub > 0.01 and IsValid(client) and client:HasCharacter()) then
		local faction = NETWORK.factions.Get(client:GetCharacterFaction())
		local parts = {util.Upper(client:GetCharacterName() or "")}

		if (faction) then
			parts[#parts + 1] = util.Upper(L(faction.name))
		end

		if (NETWORK.time and NETWORK.time.GetFormatted) then
			parts[#parts + 1] = tostring(NETWORK.time.GetFormatted())
		else
			parts[#parts + 1] = os.date("%d.%m.%Y")
		end

		local line = table.concat(parts, "   ·   ")
		local lineWidth = util.TextSpacedSize(line, "nwHudLabelSmall", Sc(3))

		util.DrawTextSpaced(line, "nwHudLabelSmall", centerX - math.Round(lineWidth * 0.5),
			centerY + Sc(62) + math.Round((1 - sub) * Sc(8)),
			ColorAlpha(faction and faction.color or theme.textDim, 235 * sub), Sc(3),
			TEXT_ALIGN_CENTER)
	end

	local skip = util.Upper(L("introSkip"))
	local skipWidth = util.TextSpacedSize(skip, "nwHudSmall", Sc(3))

	util.DrawTextSpaced(skip, "nwHudSmall", centerX - math.Round(skipWidth * 0.5),
		height - bars - Sc(28), ColorAlpha(theme.textFaint, 160 * body), Sc(3),
		TEXT_ALIGN_CENTER)

	draw.SimpleText("<:: " .. util.Upper(L("introFeed")) .. " ::>", "nwHudSmall",
		centerX, bars + inset + Sc(4), ColorAlpha(accent, 200 * body), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)
end

vgui.Register("nwTitleCard", PANEL, "EditablePanel")

function NETWORK.gui.OpenTitleCard()
	if (IsValid(NETWORK.gui.title)) then
		return
	end

	return vgui.Create("nwTitleCard")
end

hook.Add("NetworkCharacterLoaded", "nwTitleCard", function()
	timer.Simple(1.2, function()
		if (!IsValid(NETWORK.gui.welcome) and !IsValid(NETWORK.gui.menu)) then
			NETWORK.gui.OpenTitleCard()
		end
	end)
end)

concommand.Add("network_intro_test", function()
	NETWORK.gui.OpenTitleCard()
end, nil, "Показать интро входа в город")

NETWORK.arrival = NETWORK.arrival or {}

local A = NETWORK.arrival

A.seen = A.seen or {}

A.classStories = {
	refugee = "Refugee",
	rebel = "Rebel",
	loyalist = "Loyalist",
	council = "Admin",
	administration = "Admin",
	worker_factory = "Factory",
	medic = "Medic",
	mechanic = "Mechanic",
	cwuhead = "CWUHead",
	cmd = "Cmd",
	ordinal = "Ordinal",
	vorthigh = "VortHigh"
}

A.factionStories = {
	citizen = "Citizen",
	worker = "Worker",
	cp = "CP",
	cmb = "OTA",
	combine = "OTA",
	disinfector = "Disinfector",
	vortigaunt = "Vort"
}

A.typeSpeed = 34
A.linePause = 0.32
A.groupPause = 0.55

local function Exists(key)
	return NETWORK.lang.Exists and NETWORK.lang.Exists(key)
end

function A.GetStoryID(client)
	local classID = client:GetNWString("nwClass", "")
	local faction = client:GetCharacterFaction() or ""

	for _, id in ipairs({A.classStories[classID] or false,
		A.factionStories[faction] or false, "Default"}) do
		if (id and Exists("arrival" .. id .. "Title")) then
			return id
		end
	end
end

local function SplitLines(text)
	local result = {}

	for _, line in ipairs(string.Explode("\n", text or "")) do
		line = string.Trim(line)

		if (line != "") then
			result[#result + 1] = line
		end
	end

	return result
end

function A.Build(client)
	local id = A.GetStoryID(client)

	if (!id) then
		return
	end

	local prefix = "arrival" .. id
	local faction = NETWORK.factions.Get(client:GetCharacterFaction())
	local class = NETWORK.classes.Get(client:GetNWString("nwClass", ""))
	local role = (class and class.name and L(class.name)) or
		(faction and L(faction.name)) or ""
	local city = L("titleCity")

	return {
		color = faction and faction.color or NETWORK.theme.accent,
		role = NETWORK.util.Upper(role),
		title = L(prefix .. "Title"),
		name = L("arrivalName", client:GetCharacterName() or ""),
		thought = L(prefix .. "Thought"),
		groups = {
			SplitLines(L(prefix .. "Lines", city)),
			SplitLines(L(prefix .. "Steps", city))
		},
		last = L(prefix .. "Last")
	}
end

A.blockers = {"title", "intro", "menu", "creation", "tabMenu", "welcome",
	"inventory", "terminal"}

function A.IsBlocked()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return true
	end

	if (gui.IsGameUIVisible()) then
		return true
	end

	for _, key in ipairs(A.blockers) do
		local panel = NETWORK.gui[key]

		if (IsValid(panel) and panel:IsVisible()) then
			return true
		end
	end

	if (NETWORK.cutscene and NETWORK.cutscene.IsPlaying and
		NETWORK.cutscene.IsPlaying()) then
		return true
	end

	return false
end

local PANEL = {}

function PANEL:Init()
	self.clock = 0
	self.visible = 0
	self.bClosing = false
	self.closeFade = 1

	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

function PANEL:OnRemove()
	if (NETWORK.gui.arrival == self) then
		NETWORK.gui.arrival = nil
	end
end

function PANEL:Layout(story, bCompact)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local rows = {}
	local pad = Sc(18)
	local width = math.Clamp(Sc(400), math.min(300, ScrW() - Sc(32)),
		math.max(math.Round(ScrW() * 0.4), 300))
	local inner = width - pad * 2 - Sc(10)
	local lineFont = bCompact and "nwTagDesc" or "nwTipBody"
	local lineStep = bCompact and Sc(19) or Sc(23)
	local y = pad
	local time = 0.95

	surface.SetFont(lineFont)

	local prefix = "> "
	local prefixWidth = surface.GetTextSize(prefix)

	local function Add(text, font, step, kind, gap, bPrefixed)
		y = y + (gap or 0)

		local wrapWidth = bPrefixed and (inner - prefixWidth) or inner
		local pieces = util.WrapText(text, font, wrapWidth, 3)

		for index, piece in ipairs(pieces) do
			local row = {
				text = piece,
				font = font,
				kind = kind,
				y = y,
				indent = bPrefixed and prefixWidth or 0,
				prefix = bPrefixed and index == 1,
				start = time,
				length = util.Length(piece)
			}

			row.duration = row.length / A.typeSpeed
			time = time + row.duration

			rows[#rows + 1] = row
			y = y + step
		end

		time = time + A.linePause
	end

	local header = {
		role = {y = y},
		title = {y = y + Sc(16)},
		name = {y = y + Sc(16) + Sc(34)}
	}

	y = header.name.y + Sc(24)

	Add(story.thought, bCompact and "nwTagDescItalic" or "nwTipBodyItalic",
		lineStep, "thought", Sc(6), false)

	for groupIndex, group in ipairs(story.groups) do
		for lineIndex, line in ipairs(group) do
			Add(line, lineFont, lineStep, "line",
				lineIndex == 1 and Sc(groupIndex == 1 and 8 or 10) or 0, true)
		end

		time = time + A.groupPause
	end

	if (story.last and story.last != "") then
		Add(story.last, lineFont, lineStep, "last", Sc(10), true)
	end

	local footerY = y + Sc(8)
	local height = footerY + Sc(14) + pad

	return {
		rows = rows,
		header = header,
		width = width,
		height = height,
		pad = pad,
		footerY = footerY,
		typedEnd = time
	}
end

function PANEL:SetStory(story)
	local Sc = NETWORK.util.Scale

	self.story = story

	local x = Sc(22)
	local y = Sc(182)

	local limit = ScrH() - Sc(150) - math.min(Sc(300), math.Round(ScrH() * 0.45))
	local chat = NETWORK.gui.chat

	if (IsValid(chat)) then
		local chatX, chatY = chat:GetPos()

		if (chatX < x + Sc(420)) then
			limit = chatY
		else
			limit = ScrH() - Sc(40)
		end
	end

	limit = limit - Sc(14)

	local layout = self:Layout(story, false)

	if (y + layout.height > limit) then
		layout = self:Layout(story, true)
	end

	if (y + layout.height > limit) then
		y = math.max(Sc(16), limit - layout.height)
	end

	self.layout = layout

	local margin = Sc(16)

	self.margin = margin
	self:SetPos(x - margin, y - margin)
	self:SetSize(layout.width + margin * 2, layout.height + margin * 2)

	local chars = 0

	for _, row in ipairs(layout.rows) do
		chars = chars + row.length
	end

	self.hold = math.Clamp(chars / 36, 5, 9)
	self.total = layout.typedEnd + self.hold
end

function PANEL:Close()
	self.bClosing = true
end

function PANEL:Think()
	local bBlocked = A.IsBlocked()

	self.visible = NETWORK.util.Approach(self.visible, bBlocked and 0 or 1, 5)

	if (!bBlocked) then
		self.clock = self.clock + FrameTime()
	end

	if (!self.bClosing and !bBlocked and self.clock > 0.6 and
		input.IsKeyDown(KEY_BACKSPACE) and !IsValid(vgui.GetKeyboardFocus())) then
		self:Close()
	end

	if (!self.bClosing and self.total and self.clock > self.total) then
		self:Close()
	end

	if (self.bClosing) then
		self.closeFade = NETWORK.util.Approach(self.closeFade, 0, 1.4)

		if (self.closeFade <= 0.01) then
			self:Remove()
		end
	end
end

function PANEL:Paint(width, height)
	local layout = self.layout
	local story = self.story

	if (!layout or !story) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local S = NETWORK.style
	local theme = NETWORK.theme
	local alpha = self.visible * util.EaseInOut(self.closeFade)

	if (alpha <= 0.01) then
		return
	end

	local clock = self.clock
	local color = story.color or theme.accent
	local m = self.margin
	local widthPart, heightPart = S.Unfold(clock / 0.7)
	local cardWidth = math.Round(layout.width * widthPart)
	local cardHeight = math.max(math.Round(layout.height * heightPart), Sc(3))

	S.Card(m, m, cardWidth, cardHeight, alpha, {
		accent = color,
		panel = self,
		radius = S.Radius("card")
	})

	if (heightPart < 0.7) then
		return
	end

	local textAlpha = alpha * math.Clamp((heightPart - 0.7) / 0.3, 0, 1)
	local pad = layout.pad
	local left = m + pad + Sc(10)

	surface.SetDrawColor(color.r, color.g, color.b, 230 * textAlpha)
	surface.DrawRect(m + pad, m + pad + Sc(2), math.max(Sc(3), 2),
		layout.header.name.y - pad + Sc(8))

	local function Reveal(delay)
		return util.EaseOut(math.Clamp((clock - delay) / 0.45, 0, 1))
	end

	local header = layout.header
	local role = Reveal(0.45)
	local title = Reveal(0.6)
	local name = Reveal(0.75)

	if (story.role != "") then
		util.DrawTextSpaced(story.role, "nwHudLabelSmall", left,
			m + header.role.y + math.Round((1 - role) * Sc(6)),
			ColorAlpha(color, 235 * role * textAlpha), Sc(3), TEXT_ALIGN_TOP)
	end

	util.DrawSimpleTextShadow(story.title, "nwCreateHeader", left,
		m + header.title.y + math.Round((1 - title) * Sc(6)),
		ColorAlpha(theme.text, 250 * title * textAlpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP)

	draw.SimpleText(story.name, "nwTipBody", left,
		m + header.name.y + math.Round((1 - name) * Sc(6)),
		ColorAlpha(theme.textDim, 235 * name * textAlpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP)

	for _, row in ipairs(layout.rows) do
		local age = clock - row.start

		if (age <= 0) then
			break
		end

		local shown = math.min(math.floor(age * A.typeSpeed) + 1, row.length)
		local fade = util.EaseOut(math.Clamp(age / 0.3, 0, 1)) * textAlpha
		local text = shown >= row.length and row.text or util.Sub(row.text, 1, shown)
		local rowColor = theme.text

		if (row.kind == "thought") then
			rowColor = color
		elseif (row.kind == "last") then
			rowColor = theme.textFaint
		end

		local x = left + row.indent
		local y = m + row.y

		if (row.prefix) then
			draw.SimpleText("> ", row.font, left, y,
				ColorAlpha(row.kind == "last" and theme.textFaint or color,
					220 * fade), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		util.DrawSimpleTextShadow(text, row.font, x, y,
			ColorAlpha(rowColor, 240 * fade), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		if (shown < row.length and math.floor(clock * 8) % 2 == 0) then
			surface.SetFont(row.font)

			local typedWidth, typedHeight = surface.GetTextSize(text)

			surface.SetDrawColor(color.r, color.g, color.b, 220 * fade)
			surface.DrawRect(x + typedWidth + Sc(2), y + math.Round(typedHeight * 0.15),
				math.max(Sc(2), 1), math.Round(typedHeight * 0.7))
		end
	end

	local hint = Reveal(1.2) * textAlpha

	if (hint > 0.01) then
		util.DrawTextSpaced(util.Upper(L("arrivalSkip")), "nwHudSmall", left,
			m + layout.footerY, ColorAlpha(theme.textFaint, 150 * hint), Sc(2),
			TEXT_ALIGN_TOP)
	end
end

vgui.Register("nwArrivalCard", PANEL, "EditablePanel")

function A.Open(bForce)
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	local story = A.Build(client)

	if (!story) then
		return
	end

	if (IsValid(NETWORK.gui.arrival)) then
		if (!bForce) then
			return
		end

		NETWORK.gui.arrival:Remove()
	end

	local panel = vgui.Create("nwArrivalCard")

	panel:SetStory(story)

	NETWORK.gui.arrival = panel

	return panel
end

hook.Add("NetworkCharacterLoaded", "nwArrivalCard", function(client, character)
	local id = IsValid(client) and client.GetCharacterID and client:GetCharacterID() or 0

	if (id <= 0 or A.seen[id]) then
		A.pending = nil

		return
	end

	A.pending = {id = id, time = RealTime()}
end)

hook.Add("NetworkCharacterUnloaded", "nwArrivalCard", function()
	A.pending = nil

	if (IsValid(NETWORK.gui.arrival)) then
		NETWORK.gui.arrival:Close()
	end
end)

hook.Add("Think", "nwArrivalCard", function()
	local pending = A.pending

	if (!pending or !NETWORK.util.Throttle("arrival.queue", 0.25)) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or client:GetCharacterID() != pending.id) then
		A.pending = nil

		return
	end

	if (RealTime() - pending.time < 2.5 or A.IsBlocked()) then
		return
	end

	A.pending = nil
	A.seen[pending.id] = true

	A.Open()
end)

concommand.Add("network_arrival_test", function()
	A.Open(true)
end, nil, "Показать карточку «первые шаги» ещё раз")
