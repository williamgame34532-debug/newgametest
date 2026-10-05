-- Service PDA interface. From the CWU terminal it opens as a stand-alone tablet in the centre of the
-- screen; with the PDA weapon in hand it is rendered onto the screen of the device (see "КПК в руке").
local C = NETWORK.city

C.responses = C.responses or {}

local THEMES = {
	alliance = {
		bg = Color(9, 12, 16), bg2 = Color(17, 21, 27), line = Color(56, 64, 74), text = Color(226, 230, 234),
		muted = Color(128, 138, 150), accent = Color(140, 185, 225), good = Color(110, 200, 150),
		warn = Color(232, 176, 86), bad = Color(230, 92, 84),
		tag = "C24 // CIVIL PROTECTION", lockTitle = "C24 // ГРАЖДАНСКАЯ ОБОРОНА"
	},
	cwu = {
		bg = Color(13, 12, 10), bg2 = Color(23, 21, 18), line = Color(74, 68, 58), text = Color(236, 232, 222),
		muted = Color(156, 148, 130), accent = Color(220, 180, 110), good = Color(132, 196, 120),
		warn = Color(232, 150, 80), bad = Color(226, 96, 80),
		tag = "ГСР // CWU SERVICE PAD", lockTitle = "ГСР // СЛУЖЕБНЫЙ ТЕРМИНАЛ"
	}
}

function C.Theme(client)
	return C.IsCWU(client or LocalPlayer()) and THEMES.cwu or THEMES.alliance
end

function C.Request(action, payload)
	net.Start("nwCityRequest")
		net.WriteString(action)
		NETWORK.util.WriteTable(payload or {})
	net.SendToServer()
end

local Upper = function(text)
	return NETWORK.util.Upper(tostring(text or ""))
end

-- Fonts ---------------------------------------------------------------------------------------
local FONT_SPEC = {
	status = {"mono", 12, 600}, caption = {"label", 12, 700}, value = {"body", 17, 600},
	body = {"body", 16, 500}, small = {"body", 13, 500}, title = {"body", 27, 700},
	big = {"body", 34, 700}, tile = {"body", 17, 700}, button = {"body", 14, 700}
}

C.fontBucket = C.fontBucket or {}

local function BuildFonts(scale)
	local bucket = math.Clamp(math.Round(scale * 20) / 20, 0.6, 1.8)

	if (!C.fontBucket[bucket]) then
		for role, spec in pairs(FONT_SPEC) do
			local face = NETWORK.fonts and NETWORK.fonts[spec[1]] or "Fira Sans Condensed"

			surface.CreateFont("nwPDA_" .. role .. "_" .. bucket * 100, {
				font = face, size = math.max(10, math.Round(spec[2] * bucket)), weight = spec[3], extended = true
			})
		end

		C.fontBucket[bucket] = true
	end

	C.fontScale = bucket
end

local function F(role)
	return "nwPDA_" .. role .. "_" .. (C.fontScale or 1) * 100
end

local function S(value)
	return math.Round(value * (C.fontScale or 1))
end

-- Widgets -------------------------------------------------------------------------------------
local UI = {}

C.UI = UI

local function Theme()
	return IsValid(C.frame) and C.frame.theme or C.Theme(LocalPlayer())
end

function UI.Text(parent, text, font, color, margin)
	local label = parent:Add("DLabel")

	label:Dock(TOP)
	label:DockMargin(0, 0, 0, margin or S(6))
	label:SetFont(font or F("body"))
	label:SetTextColor(color or Theme().text)
	label:SetText(tostring(text or ""))
	label:SetWrap(true)
	label:SetAutoStretchVertical(true)

	return label
end

function UI.Field(parent, caption, value, color, underline)
	local theme = Theme()
	local row = parent:Add("DPanel")

	row:Dock(TOP)
	row:SetTall(S(44))
	row:DockMargin(0, 0, 0, S(2))
	row.Paint = function(_, w, h)
		draw.SimpleText(Upper(caption), F("caption"), 0, S(4), theme.muted)
		draw.SimpleText(tostring(value == nil and "—" or value), F("value"), 0, S(19), color or theme.text)

		local line = underline or theme.line

		surface.SetDrawColor(line.r, line.g, line.b, underline and 230 or 150)
		surface.DrawRect(0, h - (underline and 2 or 1), w, underline and 2 or 1)
	end

	return row
end

function UI.Section(parent, title, right)
	local theme = Theme()
	local row = parent:Add("DPanel")

	row:Dock(TOP)
	row:SetTall(S(30))
	row:DockMargin(0, S(10), 0, S(2))
	row.Paint = function(_, w, h)
		draw.SimpleText(Upper(title), F("caption"), 0, h / 2, theme.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (right) then
			draw.SimpleText(Upper(right), F("caption"), w, h / 2, theme.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	return row
end

local function PaintChip(panel, w, h, label, color, bFilled)
	local theme = Theme()
	local accent = color or theme.accent
	local hover = panel:IsHovered() and 1 or 0

	if (panel.Depressed) then
		hover = 1.6
	end

	surface.SetDrawColor(accent.r, accent.g, accent.b, (bFilled and 38 or 0) + 26 * hover)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(accent.r, accent.g, accent.b, 120 + 110 * math.min(hover, 1))
	surface.DrawOutlinedRect(0, 0, w, h, 1)
	draw.SimpleText(Upper(label), F("button"), w / 2, h / 2, hover > 0 and theme.text or accent,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function UI.Button(parent, label, callback, options)
	options = options or {}

	local button = parent:Add("DButton")

	button:SetText("")
	button:Dock(options.dock or TOP)
	button:SetTall(S(options.height or 34))
	button:DockMargin(0, 0, 0, S(options.gap or 8))
	button.Paint = function(this, w, h)
		PaintChip(this, w, h, label, options.color, options.filled)
	end
	button.DoClick = function()
		surface.PlaySound("buttons/lightswitch2.wav")
		callback()
	end

	return button
end

function UI.ChipRow(parent, chips, height)
	local row = parent:Add("DPanel")

	row:Dock(TOP)
	row:SetTall(S(height or 32))
	row:DockMargin(0, 0, 0, S(8))
	row.Paint = function() end
	row.PerformLayout = function(this, w, h)
		local gap = S(6)
		local width = (w - gap * (#this.chips - 1)) / #this.chips

		for index, chip in ipairs(this.chips) do
			chip:SetPos(math.Round((index - 1) * (width + gap)), 0)
			chip:SetSize(math.Round(width), h)
		end
	end
	row.chips = {}

	for _, entry in ipairs(chips) do
		local chip = row:Add("DButton")

		chip:SetText("")
		chip.Paint = function(this, w, h)
			PaintChip(this, w, h, entry[1], entry[3])
		end
		chip.DoClick = function()
			surface.PlaySound("buttons/lightswitch2.wav")
			entry[2]()
		end

		row.chips[#row.chips + 1] = chip
	end

	return row
end

function UI.Entry(parent, hint, numeric)
	local theme = Theme()
	local entry = parent:Add("DTextEntry")

	entry:Dock(TOP)
	entry:SetTall(S(34))
	entry:DockMargin(0, 0, 0, S(8))
	entry:SetFont(F("body"))
	entry:SetPlaceholderText(hint)
	entry:SetPlaceholderColor(theme.muted)
	entry:SetTextColor(theme.text)
	entry:SetCursorColor(theme.accent)
	entry:SetHighlightColor(ColorAlpha(theme.accent, 90))
	entry:SetDrawLanguageID(false)
	entry:SetPaintBackground(false)
	entry:SetNumeric(numeric or false)
	entry.Paint = function(this, w, h)
		surface.SetDrawColor(theme.bg2.r, theme.bg2.g, theme.bg2.b, 255)
		surface.DrawRect(0, 0, w, h)

		local line = this:HasFocus() and theme.accent or theme.line

		surface.SetDrawColor(line.r, line.g, line.b, 220)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		this:DrawTextEntryText(theme.text, ColorAlpha(theme.accent, 90), theme.accent)

		if (this:GetValue() == "" and !this:HasFocus()) then
			draw.SimpleText(hint, F("body"), S(10), h / 2, theme.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
	entry:SetTextInset(S(10), 0)

	return entry
end

-- Small vector glyphs for the home screen tiles.
local GLYPHS = {}

function GLYPHS.profile(x, y, s, c)
	draw.RoundedBox(s * 0.22, x + s * 0.32, y + s * 0.08, s * 0.36, s * 0.36, c)
	draw.RoundedBoxEx(s * 0.2, x + s * 0.14, y + s * 0.52, s * 0.72, s * 0.38, c, true, true, false, false)
end

function GLYPHS.cameras(x, y, s, c)
	draw.RoundedBox(s * 0.08, x + s * 0.06, y + s * 0.26, s * 0.64, s * 0.48, c)

	draw.NoTexture()
	surface.SetDrawColor(c)
	surface.DrawPoly({{x = x + s * 0.72, y = y + s * 0.5}, {x = x + s * 0.96, y = y + s * 0.3}, {x = x + s * 0.96, y = y + s * 0.7}})
end

function GLYPHS.logs(x, y, s, c)
	for i = 0, 3 do
		draw.RoundedBox(2, x + s * 0.1, y + s * (0.16 + i * 0.2), s * (i == 3 and 0.5 or 0.8), s * 0.1, c)
	end
end

function GLYPHS.database(x, y, s, c)
	for i = 0, 2 do
		draw.RoundedBox(s * 0.12, x + s * 0.12, y + s * (0.1 + i * 0.28), s * 0.76, s * 0.22, c)
	end
end

function GLYPHS.housing(x, y, s, c)
	draw.NoTexture()
	surface.SetDrawColor(c)
	surface.DrawPoly({{x = x + s * 0.5, y = y + s * 0.06}, {x = x + s * 0.94, y = y + s * 0.46}, {x = x + s * 0.06, y = y + s * 0.46}})
	draw.RoundedBox(0, x + s * 0.18, y + s * 0.46, s * 0.64, s * 0.46, c)
end

function GLYPHS.production(x, y, s, c)
	draw.RoundedBox(s * 0.1, x + s * 0.1, y + s * 0.1, s * 0.8, s * 0.8, c)
	draw.RoundedBox(s * 0.06, x + s * 0.32, y + s * 0.32, s * 0.36, s * 0.36, Theme().bg)
end

function UI.Tile(parent, glyph, title, caption, callback)
	local theme = Theme()
	local tile = parent:Add("DButton")

	tile:SetText("")
	tile.Paint = function(this, w, h)
		local hover = this:IsHovered() and 1 or 0

		surface.SetDrawColor(theme.bg2.r, theme.bg2.g, theme.bg2.b, 255)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 14 + 26 * hover)
		surface.DrawRect(0, 0, w, h)

		local border = hover > 0 and theme.accent or theme.line

		surface.SetDrawColor(border.r, border.g, border.b, 230)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 255)
		surface.DrawRect(0, 0, S(3), h)

		local size = S(26)

		if (GLYPHS[glyph]) then
			GLYPHS[glyph](S(14), S(14), size, ColorAlpha(theme.accent, 235))
		end

		draw.SimpleText(Upper(title), F("tile"), S(14), h - S(40), theme.text)
		draw.SimpleText(caption, F("small"), S(14), h - S(20), theme.muted)
	end
	tile.DoClick = function()
		surface.PlaySound("buttons/lightswitch2.wav")
		callback()
	end

	return tile
end

-- Frame / chrome ------------------------------------------------------------------------------
local function Body(frame)
	if (IsValid(frame.body)) then
		frame.body:Remove()
	end

	local body = frame.screen:Add("DScrollPanel")

	body:Dock(FILL)
	body:DockMargin(S(22), S(4), S(22), S(6))

	local bar = body:GetVBar()

	bar:SetWide(S(4))
	bar:SetHideButtons(true)
	bar.Paint = function() end
	bar.btnGrip.Paint = function(_, w, h)
		local theme = Theme()

		draw.RoundedBox(2, 0, 0, w, h, ColorAlpha(theme.accent, 120))
	end

	if (frame.bEmbedded) then
		body:DockMargin(S(18), S(6), S(18), S(8))
		body.Paint = function(_, w, h)
			local theme = Theme()

			surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 160)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end
		body:GetCanvas():DockPadding(S(12), S(10), S(12), S(10))
	end

	frame.body = body

	return body
end

-- Новый интерфейс горизонтального КПК ------------------------------------------------------
local PAGE_HINTS = {
	home = "Служебный терминал C24. Выберите раздел.",
	profile = "Служебный профиль и записи в личном деле.",
	cameras = "Камеры наблюдения C24 в зоне доступа.",
	feed = "Прямая трансляция с выбранной камеры.",
	logs = "Последние действия в журнале ГСР.",
	database = "Поиск гражданина по CID или имени.",
	record = "Карточка гражданина из базы CID.",
	housing = "Реестр жилья и адреса граждан.",
	production = "Сборка у терминала ГСР."
}

local TAB_OF = {feed = "cameras", record = "database"}

function C.GetApps(client)
	local apps = {{"home", "Главная"}, {"profile", "Дело"}, {"cameras", "Камеры"}, {"logs", "Журнал"}}

	if (C.IsAlliance(client)) then
		apps[#apps + 1] = {"database", "База CID"}
		apps[#apps + 1] = {"housing", "Жильё"}
	end

	if (IsValid(C.frame) and C.frame.terminal and C.IsCWU(client)) then
		apps[#apps + 1] = {"production", "Производство"}
	end

	return apps
end

local function DrawSignal(x, y, theme)
	for i = 0, 3 do
		local barH = S(3 + i * 2)

		surface.SetDrawColor(i < 3 and theme.text or theme.muted)
		surface.DrawRect(x + i * S(5), y - barH, S(3), barH)
	end
end

local function DrawBattery(x, y, theme)
	surface.SetDrawColor(theme.muted)
	surface.DrawOutlinedRect(x, y - S(5), S(20), S(10), 1)
	surface.DrawRect(x + S(20), y - S(2), S(2), S(4))
	surface.SetDrawColor(theme.text)
	surface.DrawRect(x + S(2), y - S(3), S(13), S(6))
end

local function NewChrome(screen, frame, theme)
	-- шапка
	local head = screen:Add("DPanel")

	head:Dock(TOP)
	head:SetTall(S(50))
	head:DockMargin(S(18), S(12), S(18), 0)
	head.Paint = function(this, w, h)
		local mid = h / 2
		local tag = C.IsCWU(LocalPlayer()) and "ГСР" or "C24"

		surface.SetFont(F("status"))

		local tw = surface.GetTextSize(tag) + S(16)

		surface.SetDrawColor(theme.muted)
		surface.DrawOutlinedRect(0, mid - S(12), tw, S(24), 1)
		draw.SimpleText(tag, F("status"), tw / 2, mid, theme.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local titleX = tw + S(14)

		if (IsValid(frame.backButton) and frame.backButton:IsVisible()) then
			titleX = titleX + frame.backButton:GetWide() + S(10)
		end

		draw.SimpleText(Upper(frame.title or ""), F("title"), titleX, mid, theme.text, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		-- справа: статус, время, связь, батарея (крестик закрытия — отдельная кнопка)
		local right = w - S(40)

		DrawBattery(right - S(24), mid, theme)
		DrawSignal(right - S(52), mid + S(5), theme)
		draw.SimpleText(os.date("%H:%M"), F("status"), right - S(62), mid, theme.text, TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)
		draw.SimpleText("СЕТЬ // УЧТЁН", F("status"), right - S(120), mid, theme.muted, TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)
	end

	local back = head:Add("DButton")

	back:SetText("")
	back:SetSize(S(84), S(24))
	back.Think = function(this)
		this:SetVisible(#frame.history > 0)

		surface.SetFont(F("status"))

		local tag = C.IsCWU(LocalPlayer()) and "ГСР" or "C24"

		this:SetPos(surface.GetTextSize(tag) + S(16) + S(14), (head:GetTall() - this:GetTall()) / 2)
	end
	back.Paint = function(this, w, h)
		PaintChip(this, w, h, "< НАЗАД", theme.text)
	end
	back.DoClick = function()
		C.Back()
	end

	frame.backButton = back

	local close = head:Add("DButton")

	close:SetText("")
	close:SetSize(S(26), S(26))
	close.Paint = function(this, w, h)
		local color = this:IsHovered() and theme.text or theme.muted

		surface.SetDrawColor(color)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		surface.DrawLine(S(8), S(8), w - S(8), h - S(8))
		surface.DrawLine(w - S(8), S(8), S(8), h - S(8))
	end
	close.DoClick = function()
		frame:Close()
	end
	head.PerformLayout = function(this, w, h)
		close:SetPos(w - close:GetWide(), (h - close:GetTall()) / 2)
	end

	-- вкладки
	local tabs = screen:Add("DPanel")

	tabs:Dock(TOP)
	tabs:SetTall(S(38))
	tabs:DockMargin(S(18), S(6), S(18), 0)
	tabs.Paint = function(_, w, h)
		surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 200)
		surface.DrawRect(0, h - 1, w, 1)
	end

	local x = 0

	for _, app in ipairs(C.GetApps(LocalPlayer())) do
		local button = tabs:Add("DButton")
		local label = Upper(app[2])

		surface.SetFont(F("button"))

		local bw = surface.GetTextSize(label) + S(34)

		button:SetText("")
		button:SetPos(x, 0)
		button:SetSize(bw, S(37))
		button.Paint = function(this, w, h)
			local page = frame.page and (TAB_OF[frame.page] or frame.page)
			local bActive = page == app[1]

			if (bActive) then
				surface.SetDrawColor(theme.bg2.r + 18, theme.bg2.g + 18, theme.bg2.b + 18, 255)
				surface.DrawRect(0, S(3), w, h - S(3))
				surface.SetDrawColor(theme.text)
				surface.DrawRect(0, h - S(2), w, S(2))
			elseif (this:IsHovered()) then
				surface.SetDrawColor(255, 255, 255, 10)
				surface.DrawRect(0, S(3), w, h - S(3))
			end

			draw.SimpleText(label, F("button"), w / 2, h / 2 + S(1), bActive and theme.text or theme.muted,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			surface.PlaySound("buttons/lightswitch2.wav")
			frame.history = {}
			C.Open(app[1], true)
		end

		x = x + bw + S(4)
	end

	-- пояснение к разделу
	local hint = screen:Add("DPanel")

	hint:Dock(TOP)
	hint:SetTall(S(24))
	hint:DockMargin(S(18), S(4), S(18), 0)
	hint.Paint = function(_, w, h)
		draw.SimpleText(PAGE_HINTS[frame.page or ""] or "", F("small"), 0, h / 2, theme.muted, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	-- служебная строка
	local footer = screen:Add("DPanel")

	footer:Dock(BOTTOM)
	footer:SetTall(S(28))
	footer:DockMargin(S(18), 0, S(18), S(8))
	footer.Paint = function(_, w, h)
		local text = C.IsCWU(LocalPlayer()) and "ГРАЖДАНСКАЯ АДМИНИСТРАЦИЯ // КАНАЛ ПРОТОКОЛИРУЕТСЯ" or
			"ГРАЖДАНСКАЯ ОБОРОНА // КАНАЛ ЗАЩИЩЁН"

		draw.SimpleText(text, F("status"), 0, h / 2, theme.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(theme.muted)

		for i = 0, 5 do
			local hx = w - S(54) + i * S(8)

			surface.DrawLine(hx + S(4), h / 2 - S(5), hx, h / 2 + S(5))
		end
	end
end


local function StatusBar(screen, theme)
	local bar = screen:Add("DPanel")

	bar:Dock(TOP)
	bar:SetTall(S(28))
	bar.Paint = function(_, w, h)
		draw.SimpleText(theme.tag, F("status"), S(16), h / 2, theme.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(os.date("%H:%M"), F("status"), w - S(16), h / 2, theme.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		-- battery + signal
		local bx = w - S(84)

		surface.SetDrawColor(theme.muted)
		surface.DrawOutlinedRect(bx, h / 2 - S(5), S(18), S(10), 1)
		surface.DrawRect(bx + S(18), h / 2 - S(2), S(2), S(4))
		surface.SetDrawColor(theme.good)
		surface.DrawRect(bx + S(2), h / 2 - S(3), S(11), S(6))

		for i = 0, 3 do
			local barH = S(3 + i * 2)

			surface.SetDrawColor(i < 3 and theme.text or theme.muted)
			surface.DrawRect(bx - S(32) + i * S(5), h / 2 + S(5) - barH, S(3), barH)
		end

		surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 200)
		surface.DrawRect(0, h - 1, w, 1)
	end
end

local function Header(screen, frame, theme)
	local header = screen:Add("DPanel")

	header:Dock(TOP)
	header:SetTall(S(78))
	header:DockMargin(S(22), S(10), S(22), S(4))
	header.Paint = function(_, w, h)
		draw.SimpleText(Upper(frame.title or ""), F("title"), 0, h - S(8), theme.text, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_BOTTOM)
		surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 255)
		surface.DrawRect(0, h - 2, w, 2)
	end

	local back = header:Add("DButton")

	back:SetText("")
	back:SetPos(0, 0)
	back:SetSize(S(84), S(26))
	back.Paint = function(this, w, h)
		if (#frame.history == 0) then
			return
		end

		PaintChip(this, w, h, "< Назад", theme.text)
	end
	back.DoClick = function()
		C.Back()
	end

	frame.backButton = back
end

local function Footer(screen, theme)
	local footer = screen:Add("DPanel")

	footer:Dock(BOTTOM)
	footer:SetTall(S(24))
	footer.Paint = function(_, w, h)
		surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 160)
		surface.DrawRect(S(22), 0, w - S(44), 1)
		local frame = C.frame

		if (IsValid(frame) and frame.bEmbedded) then
			draw.SimpleText(Upper(theme.tag), F("status"), w / 2, h / 2, theme.muted, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)

			return
		end

		draw.SimpleText("ЛКМ — ВЫБОР   ·   R — ЗАКРЫТЬ", F("status"), w / 2, h / 2, theme.muted,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

local function PaintScreen(panel, w, h, theme)
	surface.SetDrawColor(theme.bg)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(255, 255, 255, 4)

	for y = 0, h, 3 do
		surface.DrawRect(0, y, w, 1)
	end
end

-- Рамка экрана с крестиками сверху и снизу, как на служебных планшетах.
local function PaintEmbeddedScreen(panel, w, h, theme)
	PaintScreen(panel, w, h, theme)

	local m = S(8)

	surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 220)
	surface.DrawOutlinedRect(m, m, w - m * 2, h - m * 2, 1)

	for _, y in ipairs({m, h - m}) do
		surface.DrawRect(w / 2 - S(8), y, S(17), 1)
		surface.DrawRect(w / 2, y - S(8), 1, S(17))
	end
end

-- Stand-alone tablet bezel (terminal mode, no view model).
local function PaintBezel(frame, w, h)
	local m = frame.margin

	draw.RoundedBox(S(18), 0, 0, w, h, Color(24, 26, 28))
	draw.RoundedBox(S(14), S(8), S(8), w - S(16), h - S(16), Color(44, 47, 51))

	for _, corner in ipairs({{0, 0}, {w - S(56), 0}, {0, h - S(56)}, {w - S(56), h - S(56)}}) do
		draw.RoundedBox(S(18), corner[1], corner[2], S(56), S(56), Color(22, 24, 26))
	end

	draw.RoundedBox(S(4), m - S(4), m - S(4), w - m * 2 + S(8), h - m * 2 - frame.chin + S(8), Color(7, 10, 13))
	draw.SimpleText("C24  |  SYSTEMS", F("status"), m + S(4), h - frame.chin / 2 - m / 2, Color(120, 126, 132),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function C.Show(page, terminal)
	if (IsValid(C.frame)) then
		C.frame:Remove()
	end

	local theme = C.Theme(LocalPlayer())
	local frame = vgui.Create("EditablePanel")

	C.frame = frame
	frame.terminal = terminal or false
	frame.theme = theme
	frame.history = {}
	frame.title = ""

	local screenH = math.min(ScrH() - 120, 780)

	-- В руке меню рисуется прямо на экране КПК: панель стоит невидимой там же,
	-- где её копия в текстуре, поэтому мышь попадает в кнопки как обычно.
	frame.bEmbedded = !terminal and C.CanEmbed()

	if (frame.bEmbedded) then
		local rect = C.EmbedRect()

		BuildFonts(rect.h / (rect.bLandscape and 640 or 700))

		frame.margin = 0
		frame.chin = 0
		frame:SetSize(rect.w, rect.h)
		frame:SetPos(rect.x, rect.y)
		frame.Paint = function() end
		frame:SetPaintedManually(true)
		frame.bFocused = true
	else
		BuildFonts(screenH / 700)

		frame.margin = S(34)
		frame.chin = S(40)
		frame:SetSize(math.Round(screenH * 0.737) + frame.margin * 2, math.Round(screenH) + frame.margin * 2 + frame.chin)
		frame:Center()
		frame.Paint = PaintBezel
	end

	frame:MakePopup()
	frame:SetKeyboardInputEnabled(true)
	frame:SetCursor("blank")

	local screen = frame:Add("DPanel")

	screen:Dock(FILL)
	screen:DockMargin(frame.margin, frame.margin, frame.margin, frame.margin + frame.chin)

	screen.Paint = function(this, w, h)
		if (frame.bEmbedded) then
			PaintEmbeddedScreen(this, w, h, theme)
		else
			PaintScreen(this, w, h, theme)
		end
	end
	frame.screen = screen

	if (frame.bEmbedded) then
		NewChrome(screen, frame, theme)
	else
		StatusBar(screen, theme)
		Header(screen, frame, theme)
		Footer(screen, theme)
	end

	frame.Close = function(this)
		this:Remove()
	end
	frame.OnRemove = function(this)
		if (this.bEmbedded) then
			gui.EnableScreenClicker(false)

			timer.Simple(0, C.SyncRaise)
		end

		C.feed = nil
		C.Request("close")
	end
	frame.OnKeyCodePressed = function(this, key)
		if (key == KEY_R or key == KEY_Q) then
			this:Close()
		elseif (key == KEY_BACKSPACE) then
			C.Back()
		end
	end
	frame.Think = function(this)
		if (!LocalPlayer():Alive()) then
			this:Close()

			return
		end

		if (this.bEmbedded) then
			if (!C.InHand()) then
				this:Close()

				return
			end

			if (!this.bFocused) then
				return
			end

			-- Системная стрелка не нужна: курсор рисуется на экране КПК.
			local hovered = vgui.GetHoveredPanel()

			if (IsValid(hovered) and hovered != this.nwBlankCursor and hovered:HasParent(this)) then
				hovered:SetCursor("blank")
				this.nwBlankCursor = hovered
			end

			-- Курсор не уходит с экрана КПК.
			local x, y = this:GetPos()
			local cx, cy = input.GetCursorPos()
			local nx = math.Clamp(cx, x + 1, x + this:GetWide() - 2)
			local ny = math.Clamp(cy, y + 1, y + this:GetTall() - 2)

			if (nx != cx or ny != cy) then
				input.SetCursorPos(nx, ny)
			end
		end
	end
	frame.PaintOver = function(this)
		if (this.bEmbedded and !this.bFocused) then
			return
		end

		local t = RealTime()

		-- Нажатая кнопка коротко подсвечивается.
		local pressed = C.pressedPanel

		if (IsValid(pressed) and C.pressedAt and t - C.pressedAt < 0.25) then
			local k = 1 - (t - C.pressedAt) / 0.25
			local px, py = this:ScreenToLocal(pressed:LocalToScreen(0, 0))

			surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 70 * k)
			surface.DrawRect(px, py, pressed:GetWide(), pressed:GetTall())
			surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 220 * k)
			surface.DrawOutlinedRect(px, py, pressed:GetWide(), pressed:GetTall(), 2)
		end

		-- Волна от точки клика.
		if (C.rippleAt and t - C.rippleAt < 0.4) then
			local k = (t - C.rippleAt) / 0.4

			NETWORK.util.DrawCircleOutline(C.rippleX, C.rippleY, S(6) + S(34) * k,
				ColorAlpha(theme.accent, 230 * (1 - k)), 2)
		end

		if (this.bEmbedded and !this.bFocused) then
			return
		end

		-- Собственный курсор КПК: стрелка с обводкой, при клике чуть сжимается.
		local x, y = this:CursorPos()

		if (x > 0 and y > 0 and x < this:GetWide() and y < this:GetTall()) then
			local click = C.rippleAt and math.Clamp(1 - (t - C.rippleAt) / 0.15, 0, 1) or 0
			local size = S(18) * (1 - click * 0.2)
			local arrow = {
				{x = x, y = y},
				{x = x + size * 0.72, y = y + size * 0.62},
				{x = x + size * 0.36, y = y + size * 0.66},
				{x = x + size * 0.56, y = y + size * 1.02},
				{x = x + size * 0.42, y = y + size * 1.08},
				{x = x + size * 0.22, y = y + size * 0.72},
				{x = x, y = y + size * 0.92}
			}
			-- DrawPoly рисует только выпуклые фигуры: голова-треугольник + хвост.
			local head = {arrow[1], arrow[2], arrow[7]}
			local tail = {arrow[3], arrow[4], arrow[5], arrow[6]}

			local function Shift(poly)
				local out = {}

				for index, point in ipairs(poly) do
					out[index] = {x = point.x + 1, y = point.y + 1}
				end

				return out
			end

			draw.NoTexture()
			surface.SetDrawColor(0, 0, 0, 200)
			surface.DrawPoly(Shift(head))
			surface.DrawPoly(Shift(tail))
			surface.SetDrawColor(theme.text.r, theme.text.g, theme.text.b, 250)
			surface.DrawPoly(head)
			surface.DrawPoly(tail)
			surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 255)

			for index = 1, #arrow do
				local a, b = arrow[index], arrow[index % #arrow + 1]

				surface.DrawLine(a.x, a.y, b.x, b.y)
			end
		end
	end

	C.Open(page or "home", true)

	if (frame.bEmbedded) then
		timer.Simple(0, C.SyncRaise)
	end
end

-- Navigation ----------------------------------------------------------------------------------
local PAGES = {}

C.pages = PAGES

function C.Open(page, bRoot, payload)
	local frame = C.frame

	if (!IsValid(frame)) then
		return
	end

	if (!bRoot and frame.page) then
		table.insert(frame.history, {page = frame.page, payload = frame.payload})
	end

	frame.page = page
	frame.payload = payload
	C.feed = nil
	C.transitionAt = RealTime()

	local def = PAGES[page]

	if (!def) then
		return
	end

	frame.title = def.title
	Body(frame)

	if (def.request) then
		UI.Text(frame.body, "Загрузка…", F("small"), Theme().muted)
		C.Request(def.request, payload or {})
	elseif (def.Build) then
		def.Build(frame.body, payload)
	end
end

function C.Back()
	local frame = C.frame

	if (!IsValid(frame) or #frame.history == 0) then
		return
	end

	local last = table.remove(frame.history)

	C.Open(last.page, true, last.payload)
end

function C.Rebuild()
	local frame = C.frame

	if (!IsValid(frame) or !frame.page) then
		return
	end

	local def = PAGES[frame.page]

	Body(frame)

	local data = def and def.reply and C.responses[def.reply]

	if (data and def.Draw) then
		def.Draw(frame.body, data)
	elseif (def and def.Build) then
		def.Build(frame.body, frame.payload)
	end
end

local function HousingText(housing)
	if (!housing or (housing.address or "") == "") then
		return "Не зарегистрирован", nil
	end

	local theme = Theme()

	if (housing.kind == "purchase") then
		return housing.address .. "  ·  собственность", theme.good
	end

	return housing.address .. "  ·  временное", theme.text
end

-- Pages ---------------------------------------------------------------------------------------
PAGES.home = {title = "Главная", request = "profile", reply = "profile"}

function PAGES.home.Draw(body, data)
	local theme = Theme()
	local client = LocalPlayer()
	local card = body:Add("DPanel")

	card:Dock(TOP)
	card:SetTall(S(92))
	card:DockMargin(0, S(4), 0, S(14))
	card.Paint = function(_, w, h)
		surface.SetDrawColor(theme.bg2)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(theme.line)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText(Upper(data.name), F("big"), S(14), S(10), theme.text)
		draw.SimpleText(Upper((data.faction or "") .. "  ·  CID " .. tostring(data.cid or "—")), F("caption"),
			S(14), S(52), theme.muted)
		draw.SimpleText(Upper(data.class or ""), F("caption"), S(14), S(68), theme.accent)
		draw.SimpleText(Upper(data.status or ""), F("caption"), w - S(14), S(14), theme.good, TEXT_ALIGN_RIGHT)
	end

	local apps = {
		{"profile", "Личное дело", "Служебный профиль", function() C.Open("profile") end},
		{"cameras", "Камеры С24", "Наблюдение", function() C.Open("cameras") end},
		{"logs", "Журнал ГСР", "Последние действия", function() C.Open("logs") end}
	}

	if (C.IsAlliance(client)) then
		apps[#apps + 1] = {"database", "База CID", "Поиск гражданина", function() C.Open("database") end}
		apps[#apps + 1] = {"housing", "Реестр жилья", "Адреса граждан", function() C.Open("housing") end}
	end

	if (IsValid(C.frame) and C.frame.terminal and C.IsCWU(client)) then
		apps[#apps + 1] = {"production", "Производство", "Сборка у терминала", function() C.Open("production") end}
	end

	local grid = body:Add("DPanel")

	grid:Dock(TOP)
	grid.Paint = function() end

	local tiles = {}

	for _, app in ipairs(apps) do
		tiles[#tiles + 1] = UI.Tile(grid, app[1], app[2], app[3], app[4])
	end

	grid.PerformLayout = function(this, w)
		local cols = (IsValid(C.frame) and C.frame.bEmbedded) and 3 or 2
		local gap = S(10)
		local tw = (w - gap * (cols - 1)) / cols
		local th = S(96)

		for index, tile in ipairs(tiles) do
			local col, row = (index - 1) % cols, math.floor((index - 1) / cols)

			tile:SetPos(math.Round(col * (tw + gap)), row * (th + gap))
			tile:SetSize(math.Round(tw), th)
		end

		this:SetTall(math.ceil(#tiles / cols) * (th + gap))
	end
end

PAGES.profile = {title = "Личное дело", request = "profile", reply = "profile"}

function PAGES.profile.Draw(body, data)
	local theme = Theme()

	UI.Text(body, Upper(data.name), F("value"), theme.text, S(10))
	UI.Field(body, "Подразделение", data.faction)
	UI.Field(body, "Должность", data.class)
	UI.Field(body, "Служебный CID", data.cid)
	UI.Field(body, "Очки лояльности", data.loyalty)

	local housing, color = HousingText(data.housing)

	UI.Field(body, "Адрес проживания", housing, color)

	if (data.housing and (data.housing.debt or 0) > 0) then
		UI.Field(body, "Налоговый долг", data.housing.debt .. " т.", theme.warn)
	end

	UI.Field(body, "Статус", data.status, theme.accent, theme.accent)

	local notes = data.notes or {}

	UI.Section(body, "Записи в деле", "Всего: " .. #notes)

	if (#notes == 0) then
		UI.Text(body, "Записей нет", F("body"), theme.muted)
	end

	for index = #notes, math.max(#notes - 9, 1), -1 do
		local note = notes[index]

		UI.Text(body, (isnumber(note.time) and os.date("%d.%m %H:%M", note.time) or tostring(note.time or "")) ..
			"  ·  " .. (note.author or "?"), F("caption"), theme.muted, 0)
		UI.Text(body, note.text, F("body"), theme.text, S(8))
	end
end

PAGES.database = {title = "База CID"}

function PAGES.database.Build(body, payload)
	local entry = UI.Entry(body, "CID гражданина: 5 цифр", true)

	UI.Button(body, "Найти гражданина", function()
		C.Open("record", false, {cid = entry:GetValue()})
	end, {filled = true})
	UI.Text(body, "Карточка показывает лояльность, документы и зарегистрированный адрес проживания. " ..
		"Адрес можно отметить на карте.", F("small"), Theme().muted)

	timer.Simple(0, function()
		if (IsValid(entry)) then
			entry:RequestFocus()
		end
	end)
end

PAGES.record = {title = "Карточка CID", request = "record", reply = "record"}

function PAGES.record.Draw(body, data)
	local theme = Theme()

	if (data.error) then
		UI.Text(body, data.error, F("body"), theme.warn)
		UI.Button(body, "Новый поиск", function() C.Back() end)

		return
	end

	UI.Text(body, Upper(data.name) .. "  //  CID " .. data.cid, F("value"), theme.accent, S(10))
	UI.Field(body, "Статус", data.status, data.bOnline and theme.good or theme.muted)
	UI.Field(body, "Лояльность", tostring(data.loyalty) .. "  ·  " .. tostring(data.band or ""))
	UI.Field(body, "Фракция", data.faction)

	local housing, color = HousingText(data.housing)

	UI.Field(body, "Адрес проживания", housing, color)

	if (data.housing and (data.housing.address or "") != "") then
		UI.Button(body, "Отметить адрес на карте", function()
			C.Request("mark", {cid = data.cid})
		end, {color = theme.accent, filled = true})
	end

	if (data.housing and (data.housing.debt or 0) > 0) then
		UI.Field(body, "Налоговый долг", data.housing.debt .. " т.  ·  неоплат: " .. (data.housing.unpaid or 0), theme.warn)
	end

	local cards = data.cards or {}

	UI.Section(body, "Документы", "Карт: " .. #cards)

	for _, card in ipairs(cards) do
		UI.Text(body, card.serial .. "  ·  " .. (card.bValid and "ДЕЙСТВИТЕЛЬНА" or "ОТОЗВАНА"), F("small"),
			card.bValid and theme.text or theme.bad, S(2))
	end

	UI.Section(body, "Лояльность и записи")

	local reason = UI.Entry(body, "Причина / текст записи")

	UI.ChipRow(body, {
		{"+1 ОЛ", function() C.Request("loyalty", {cid = data.cid, delta = 1, text = reason:GetValue()}) end, theme.good},
		{"+5 ОЛ", function() C.Request("loyalty", {cid = data.cid, delta = 5, text = reason:GetValue()}) end, theme.good},
		{"−1 ОЛ", function() C.Request("loyalty", {cid = data.cid, delta = -1, text = reason:GetValue()}) end, theme.bad},
		{"−5 ОЛ", function() C.Request("loyalty", {cid = data.cid, delta = -5, text = reason:GetValue()}) end, theme.bad}
	})
	UI.Button(body, "Добавить запись в дело", function()
		C.Request("note", {cid = data.cid, text = reason:GetValue()})
	end)

	local notes = data.notes or {}

	UI.Section(body, "Записи в деле", "Всего: " .. #notes)

	if (#notes == 0) then
		UI.Text(body, "Записей нет", F("body"), theme.muted)
	end

	for index = #notes, 1, -1 do
		local note = notes[index]

		UI.Text(body, tostring(note.time or "") .. "  ·  " .. (note.author or "?"), F("caption"), theme.muted, 0)
		UI.Text(body, note.text, F("body"), theme.text, S(8))
	end
end

PAGES.housing = {title = "Реестр жилья", request = "housing", reply = "housing"}

function PAGES.housing.Draw(body, data)
	local theme = Theme()
	local list = data.list or {}

	UI.Text(body, "Собственники квартир зарегистрированы постоянно; временные жильцы — по терминалу.",
		F("small"), theme.muted, S(10))

	if (#list == 0) then
		UI.Text(body, "Зарегистрированных жильцов нет.", F("body"), theme.muted)
	end

	for _, row in ipairs(list) do
		local button = body:Add("DButton")

		button:SetText("")
		button:Dock(TOP)
		button:SetTall(S(54))
		button:DockMargin(0, 0, 0, S(6))
		button.Paint = function(this, w, h)
			local hover = this:IsHovered()

			surface.SetDrawColor(theme.bg2)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(hover and theme.accent or theme.line)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(row.address, F("value"), S(12), S(8), theme.text)
			draw.SimpleText(Upper(row.name .. "  ·  CID " .. row.cid .. (row.online and "  ·  в сети" or "")),
				F("caption"), S(12), S(32), theme.muted)

			local kind = row.kind == "purchase" and "СОБСТВ." or "ВРЕМ."

			draw.SimpleText(kind, F("caption"), w - S(12), S(10), row.kind == "purchase" and theme.good or theme.muted,
				TEXT_ALIGN_RIGHT)

			if ((row.debt or 0) > 0) then
				draw.SimpleText("ДОЛГ " .. row.debt .. " Т.", F("caption"), w - S(12), S(32), theme.warn, TEXT_ALIGN_RIGHT)
			elseif (hover) then
				draw.SimpleText("ОТМЕТИТЬ", F("caption"), w - S(12), S(32), theme.accent, TEXT_ALIGN_RIGHT)
			end
		end
		button.DoClick = function()
			surface.PlaySound("buttons/lightswitch2.wav")
			C.Request("mark", {char = row.char})
		end
	end
end

PAGES.logs = {title = "Журнал ГСР", request = "logs", reply = "logs"}

function PAGES.logs.Draw(body, data)
	local theme = Theme()
	local list = data.list or {}

	if (#list == 0) then
		UI.Text(body, "Записей нет", F("body"), theme.muted)
	end

	for _, entry in ipairs(list) do
		local time = isnumber(entry.time) and os.date("%d.%m %H:%M", entry.time) or tostring(entry.time)

		UI.Text(body, time .. "  ·  " .. Upper(entry.name), F("caption"), theme.muted, 0)
		UI.Text(body, L(entry.action) .. (entry.target and entry.target != "" and ("  ·  " .. L(entry.target)) or ""),
			F("body"), theme.text, S(8))
	end
end

PAGES.cameras = {title = "Камеры С24", request = "cameras", reply = "cameras"}

function PAGES.cameras.Draw(body, data)
	local theme = Theme()
	local list = data.list or {}

	if (#list == 0) then
		UI.Text(body, "Нет доступных камер.", F("body"), theme.muted)
	end

	for _, row in ipairs(list) do
		local button = body:Add("DButton")

		button:SetText("")
		button:Dock(TOP)
		button:SetTall(S(48))
		button:DockMargin(0, 0, 0, S(6))
		button.Paint = function(this, w, h)
			surface.SetDrawColor(theme.bg2)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(this:IsHovered() and theme.accent or theme.line)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
			draw.SimpleText(row.name, F("value"), S(12), S(7), theme.text)

			local frac = math.Clamp((row.hp or 0) / 20, 0, 1)
			local color = frac > 0.5 and theme.good or (frac > 0.25 and theme.warn or theme.bad)

			surface.SetDrawColor(theme.line)
			surface.DrawRect(S(12), h - S(12), w - S(24), S(3))
			surface.SetDrawColor(color)
			surface.DrawRect(S(12), h - S(12), (w - S(24)) * frac, S(3))
			draw.SimpleText(row.hp .. "/20", F("caption"), w - S(12), S(9), color, TEXT_ALIGN_RIGHT)
		end
		button.DoClick = function()
			surface.PlaySound("buttons/lightswitch2.wav")
			C.Request("watch", {index = row.index})
		end
	end
end

local cameraRT = GetRenderTarget("nwC24PDAFeed", 768, 512)
local cameraMat = CreateMaterial("nwC24PDAFeedMat", "UnlitGeneric", {["$basetexture"] = cameraRT:GetName()})

C.feed = nil

hook.Add("PreRender", "nwC24Feed", function()
	if (C.rendering or !C.feed or !IsValid(C.frame)) then
		return
	end

	local e = Entity(C.feed.index)

	if (!IsValid(e) or e:GetClass() != "nw_c24_camera" or e:GetIntegrity() <= 0) then
		C.feed = nil

		return
	end

	if ((C.nextRender or 0) > RealTime()) then
		return
	end

	C.nextRender = RealTime() + 0.066
	C.rendering = true

	render.PushRenderTarget(cameraRT)
		render.Clear(3, 8, 12, 255, true, true)
		render.RenderView({origin = e:GetPos() + e:GetForward() * 9, angles = e:GetAngles(), x = 0, y = 0, w = 768,
			h = 512, fov = 70, drawviewmodel = false, drawhud = false})
	render.PopRenderTarget()

	C.rendering = false

	if ((C.nextHeartbeat or 0) < RealTime()) then
		C.nextHeartbeat = RealTime() + 5
		C.Request("watch", {index = e:EntIndex()})
	end
end)

PAGES.feed = {title = "Трансляция", reply = "watch"}

function PAGES.feed.Draw(body, data)
	local theme = Theme()

	C.feed = data

	local feed = body:Add("DPanel")

	feed:Dock(TOP)
	feed:DockMargin(0, 0, 0, S(10))
	feed.PerformLayout = function(this, w)
		this:SetTall(math.Round(w * 512 / 768))
	end
	feed.Paint = function(_, w, h)
		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(cameraMat)
		surface.DrawTexturedRect(0, 0, w, h)

		local blink = math.floor(RealTime() * 2) % 2 == 0

		draw.SimpleText((blink and "● " or "  ") .. "LIVE  ·  C24", F("status"), S(10), S(8), theme.bad)
		surface.SetDrawColor(theme.accent)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	UI.Field(body, "Камера", data.name)
	UI.Field(body, "Прочность", tostring(data.hp) .. " / 20", data.hp > 10 and theme.good or theme.warn)
end

PAGES.production = {title = "Производство"}

function PAGES.production.Build(body)
	for _, craft in ipairs({
		{"Камера С24", "10 металла · 2 проводки · 1 смола", "craft_camera"},
		{"Паёк II", "3 неоткрытых пайка I", "ration2"},
		{"Паёк III", "5 неоткрытых пайков I", "ration3"},
		{"КПК ГСР", "4 металла · 2 проводки · 1 смола", "craft_pda"}
	}) do
		UI.Field(body, craft[2], craft[1])
		UI.Button(body, "Собрать: " .. craft[1], function() C.Request(craft[3]) end, {filled = true})
	end
end

-- КПК в руке --------------------------------------------------------------------------------
local inHandConVar = CreateClientConVar("network_pda_inhand", "1", true, false,
	"Показывать меню КПК на экране устройства в руках")

C.kpkModel = "models/network/kpk.mdl"

function C.InHand()
	local client = LocalPlayer()
	local weapon = IsValid(client) and client:GetActiveWeapon()

	return IsValid(weapon) and weapon:GetClass() == "weapon_nw_pda"
end

function C.CanEmbed()
	return inHandConVar:GetBool() and C.InHand()
end

function C.HasKPKModel()
	if (C.bKPKChecked == nil) then
		C.bKPKChecked = util.IsValidModel(C.kpkModel)
	end

	return C.bKPKChecked
end

-- Углы экрана в локальных координатах устройства: TL, TR, BR, BL и смещение по нормали.
-- kpk.mdl — горизонтальный 2:1, экран смотрит в +Z; запасной меш C24 — вертикальный, в +X.
function C.IsLandscape()
	if (C.bLandscape == nil) then
		C.bLandscape = C.HasKPKModel() or file.Exists("models/weapons/c_kpk.mdl", "GAME")
	end

	return C.bLandscape
end

-- Экран горизонтального планшета: 10.4 x 6.5, центр смещён вверх на 0.35.
C.screenAspect = 10.4 / 6.5

function C.ScreenCorners()
	if (C.IsLandscape()) then
		local z = 1.29

		z = 1.03

		return {Vector(-5.2, 3.6, z), Vector(5.2, 3.6, z), Vector(5.2, -2.9, z), Vector(-5.2, -2.9, z)},
			Vector(0, 0, 0.02), true
	end

	local x = 0.86

	return {Vector(x, -4.56, 6.635), Vector(x, 4.56, 6.635), Vector(x, 4.56, -6.135), Vector(x, -4.56, -6.135)},
		Vector(0.02, 0, 0), false
end

-- Где на мониторе стоит (невидимая) панель меню и какой кусок текстуры уходит на экран.
function C.EmbedRect()
	local _, _, bLandscape = C.ScreenCorners()
	local w, h

	if (bLandscape) then
		-- Экран планшета 16:10.
		h = math.Round(math.min(ScrH() * 0.72, 700))
		w = math.min(math.Round(h * C.screenAspect), math.Round(ScrW() * 0.94))
		h = math.Round(w / C.screenAspect)
	else
		h = math.min(ScrH() - 120, 780)
		w = math.Round(h * (9.12 / 12.77))
	end

	return {x = math.Round((ScrW() - w) * 0.5), y = math.Round((ScrH() - h) * 0.5), w = w, h = h,
		bLandscape = bLandscape}
end

local screenRT = GetRenderTargetEx("nwPDAScreenRT", ScrW(), ScrH(), RT_SIZE_FULL_FRAME_BUFFER,
	MATERIAL_RT_DEPTH_NONE, 2, 0, IMAGE_FORMAT_RGBA8888)
local screenMat = CreateMaterial("nwPDAScreenMat", "UnlitGeneric", {
	["$basetexture"] = screenRT:GetName()
})

-- Тот же экран как материал модели: подменяем материал стекла (pda_screen) у вьюмодели
-- и своей модели в мире. UV стекла и так растянуты на весь экран, поэтому меню встаёт
-- ровно в рамку, а пальцы оказываются поверх него. Нужный кусок текстуры задаёт
-- $basetexturetransform.
local screenModelMat = CreateMaterial("nwPDAScreenModelMat", "UnlitGeneric", {
	["$basetexture"] = screenRT:GetName(),
	["$model"] = "1",
	["$nofog"] = "1"
})

-- Экран без освещения на полной яркости с HDR/свечением выцветает — приглушаем.
local screenBrightness = CreateClientConVar("network_pda_brightness", "0.62", true, false,
	"Яркость экрана КПК в руках (0.2–1)")

function C.UpdateScreenTransform()
	local rect = C.EmbedRect()
	local frame = C.frame

	if (IsValid(frame) and frame.bEmbedded) then
		local fx, fy = frame:GetPos()

		rect = {x = fx, y = fy, w = frame:GetWide(), h = frame:GetTall()}
	end

	local m = Matrix()

	m:Translate(Vector(rect.x / ScrW(), rect.y / ScrH(), 0))
	m:Scale(Vector(rect.w / ScrW(), rect.h / ScrH(), 1))

	screenModelMat:SetMatrix("$basetexturetransform", m)

	local k = math.Clamp(screenBrightness:GetFloat(), 0.2, 1)

	screenModelMat:SetVector("$color", Vector(k, k, k))
end

function C.ApplyScreenMaterial(entity)
	if (!IsValid(entity)) then
		return false
	end

	if (entity.nwScreenModel != entity:GetModel()) then
		entity.nwScreenModel = entity:GetModel()
		entity.nwScreenIndex = nil

		for index, name in ipairs(entity:GetMaterials() or {}) do
			if (string.find(string.lower(name), "pda_screen", 1, true)) then
				entity.nwScreenIndex = index - 1

				break
			end
		end
	end

	if (!entity.nwScreenIndex) then
		return false
	end

	C.UpdateScreenTransform()
	entity:SetSubMaterial(entity.nwScreenIndex, "!nwPDAScreenModelMat")

	return true
end

function C.ClearScreenMaterial(entity)
	if (IsValid(entity) and entity.nwScreenIndex) then
		entity:SetSubMaterial(entity.nwScreenIndex, nil)
	end
end

-- Экран, пока меню ещё не пришло с сервера: шапка, «радар» и подсказка.
local function DrawStandby(rect)
	local theme = C.Theme(LocalPlayer())
	local x, y, w, h = rect.x, rect.y, rect.w, rect.h
	local t = RealTime()

	surface.SetDrawColor(theme.bg)
	surface.DrawRect(x, y, w, h)

	-- шапка
	surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 200)
	surface.DrawRect(x, y + 30, w, 1)
	draw.SimpleText(Upper(theme.tag), "nwPDAStandbySmall", x + 16, y + 15, theme.accent,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(os.date("%H:%M"), "nwPDAStandbySmall", x + w - 16, y + 15, theme.text,
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	-- вращающиеся дуги поиска сети
	local cx, cy = x + w / 2, y + h / 2 - 6
	local r = math.min(w, h) * 0.2

	for i = 0, 2 do
		local start = (t * (60 + i * 35) + i * 120) % 360

		NETWORK.util.DrawArc(cx, cy, r + i * 10, 2, 0.22, ColorAlpha(theme.accent, 200 - i * 50), 32, start)
	end

	local pulse = 0.5 + math.abs(math.sin(t * 2)) * 0.5

	NETWORK.util.DrawCircle(cx, cy, 5 + pulse * 3, ColorAlpha(theme.accent, 220))

	local dots = string.rep(".", math.floor(t * 2) % 4)

	draw.SimpleText("ПОДКЛЮЧЕНИЕ К СЕТИ" .. dots, "nwPDAStandbySmall", cx, cy + r + 40, theme.muted,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- Эффекты экрана поверх интерфейса: загрузка, смена страниц, развёртка, виньетка.
local function DrawScreenFX(rect)
	local theme = C.Theme(LocalPlayer())
	local x, y, w, h = rect.x, rect.y, rect.w, rect.h
	local t = RealTime()

	-- бегущая полоса развёртки
	local band = y + ((t * 0.35) % 1) * (h + 60) - 30

	for i = 0, 29 do
		surface.SetDrawColor(255, 255, 255, 5 * (1 - math.abs(i - 15) / 15))
		surface.DrawRect(x, band + i, w, 1)
	end

	-- виньетка по краям
	for i = 0, 11 do
		local a = (12 - i) * 5

		surface.SetDrawColor(0, 0, 0, a)
		surface.DrawOutlinedRect(x + i, y + i, w - i * 2, h - i * 2, 1)
	end

	-- смена страницы: вспышка и шторка сверху вниз
	local tr = C.transitionAt and (t - C.transitionAt) / 0.28 or 1

	if (tr < 1) then
		surface.SetDrawColor(theme.bg.r, theme.bg.g, theme.bg.b, 255 * (1 - tr))
		surface.DrawRect(x, y + h * tr, w, h * (1 - tr))
		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 220 * (1 - tr))
		surface.DrawRect(x, y + h * tr, w, 2)
	end

	-- выключение экрана при убирании: картинка схлопывается в линию
	local off = C.offAt and (t - C.offAt) / 0.35 or 99

	if (off < 1.5) then
		local k = math.Clamp(off, 0, 1)
		local keep = h * (1 - k) * 0.5

		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(x, y, w, h / 2 - keep)
		surface.DrawRect(x, y + h / 2 + keep, w, h / 2 - keep)
		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 255 * (1 - math.Clamp(off - 1, 0, 0.5) * 2))
		surface.DrawRect(x + w * 0.5 * k * 0.8, y + h / 2 - 1, w * (1 - k * 0.8), 2)
	end

	-- загрузка при доставании КПК
	local boot = C.bootAt and (t - C.bootAt) or 99

	if (boot < 1.6) then
		local fade = boot > 1.25 and (1 - (boot - 1.25) / 0.35) or 1

		surface.SetDrawColor(4, 6, 8, 255 * fade)
		surface.DrawRect(x, y, w, h)

		if (boot > 0.12) then
			local a = 255 * fade
			local cx, cy = x + w / 2, y + h / 2

			-- «включение» экрана: горизонтальная линия раскрывается
			local open = math.Clamp((boot - 0.12) / 0.2, 0, 1)

			surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, a * (1 - open * 0.7))
			surface.DrawRect(cx - w * 0.5 * open, cy - 1, w * open, 2)

			if (boot > 0.3) then
				draw.SimpleText(Upper(theme.tag), "nwPDAStandbySmall", cx, cy - 34, ColorAlpha(theme.text, a),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				local progress = math.Clamp((boot - 0.35) / 0.85, 0, 1)
				local bw = w * 0.4

				surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, a)
				surface.DrawOutlinedRect(cx - bw / 2, cy + 16, bw, 8, 1)
				surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, a)
				surface.DrawRect(cx - bw / 2 + 2, cy + 18, (bw - 4) * progress, 4)

				local stage = progress < 0.4 and "ЗАГРУЗКА ЯДРА" or progress < 0.8 and "ПРОВЕРКА ДОСТУПА" or
					"ПОДКЛЮЧЕНИЕ К СЕТИ"

				draw.SimpleText(stage, "nwPDAStandbySmall", cx, cy + 44, ColorAlpha(theme.muted, a),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
	end
end

hook.Add("PreRender", "nwPDAScreen", function()
	if (C.rendering or !C.InHand()) then
		return
	end

	local rect = C.EmbedRect()

	if (C.standbyFontH != rect.h) then
		C.standbyFontH = rect.h

		local face = NETWORK.fonts and NETWORK.fonts.display or "Russo One"

		surface.CreateFont("nwPDAStandbyBig", {font = face, size = math.Round(rect.h * 0.36),
			weight = 800, extended = true})
		surface.CreateFont("nwPDAStandbySmall", {font = NETWORK.fonts and NETWORK.fonts.mono or "Consolas",
			size = math.max(12, math.Round(rect.h * 0.045)), weight = 600, extended = true})
	end

	render.PushRenderTarget(screenRT)
		render.Clear(0, 0, 0, 255, true, true)
		cam.Start2D()
			local frame = C.frame

			if (IsValid(frame) and frame.bEmbedded) then
				frame:PaintManual()
			else
				DrawStandby(rect)
			end

			DrawScreenFX(rect)
		cam.End2D()
	render.PopRenderTarget()
end)

-- Вызывается из weapon_nw_pda:PostDrawViewModel — рисует КПК и живой экран на нём.
function C.DrawDevice(pos, ang, scale, weapon)
	if (C.HasKPKModel()) then
		if (!IsValid(C.vmDevice)) then
			C.vmDevice = ClientsideModel(C.kpkModel, RENDERGROUP_VIEWMODEL)

			if (IsValid(C.vmDevice)) then
				C.vmDevice:SetNoDraw(true)
			end
		end

		if (IsValid(C.vmDevice)) then
			if (C.vmDevice.nwScale != scale) then
				C.vmDevice.nwScale = scale
				C.vmDevice:SetModelScale(scale, 0)
			end

			-- studiomdl поворачивает модель на 90° вокруг Z: ширина — локальная Y, верх экрана — -X.
			C.vmDevice:SetRenderOrigin(pos)
			C.vmDevice:SetRenderAngles(ang:Right():AngleEx(ang:Up()))
			C.vmDevice:SetupBones()
			C.vmDevice:DrawModel()
		end
	elseif (NETWORK.cityModels) then
		NETWORK.cityModels.Draw("pda_", pos, ang, scale, 0)
	end

	local corners, lift = C.ScreenCorners()
	local world = {}

	for index = 1, 4 do
		world[index] = LocalToWorld((corners[index] + lift) * scale, angle_zero, pos, ang)
	end

	C.DrawScreenQuad(world)
end

-- Живой экран КПК на четырёх мировых точках: верх-лево, верх-право, низ-право, низ-лево.
function C.DrawScreenQuad(world)
	local rect = C.EmbedRect()
	local frame = C.frame

	if (IsValid(frame) and frame.bEmbedded) then
		local fx, fy = frame:GetPos()

		rect = {x = fx, y = fy, w = frame:GetWide(), h = frame:GetTall()}
	end

	-- Слой меню приподнят над стеклом модели, иначе он мерцает вместе с её текстурой.
	local normal = (world[2] - world[1]):Cross(world[4] - world[1])

	if (normal:LengthSqr() > 0) then
		normal:Normalize()

		local center = (world[1] + world[3]) * 0.5

		if (normal:Dot(EyePos() - center) < 0) then
			normal = -normal
		end

		local lifted = {}

		for index = 1, 4 do
			lifted[index] = world[index] + normal * 0.05
		end

		world = lifted
	end
	local u0, v0 = rect.x / ScrW(), rect.y / ScrH()
	local u1, v1 = (rect.x + rect.w) / ScrW(), (rect.y + rect.h) / ScrH()
	local uv = {{u0, v0}, {u1, v0}, {u1, v1}, {u0, v1}}

	render.SetMaterial(screenMat)
	mesh.Begin(MATERIAL_QUADS, 1)

	for index = 1, 4 do
		mesh.Position(world[index])
		mesh.TexCoord(0, uv[index][1], uv[index][2])
		mesh.Color(255, 255, 255, 255)
		mesh.AdvanceVertex()
	end

	mesh.End()
end

-- ПКМ: мышь в игру (осмотреться, ходить) и обратно в КПК. Меню на экране остаётся.
-- КПК в руках поднимается к лицу, когда мышь в меню, и опускается, когда мышь в игре.
function C.SyncRaise()
	local client = LocalPlayer()
	local weapon = IsValid(client) and client:GetActiveWeapon()

	if (IsValid(weapon) and weapon.SetRaised) then
		local frame = C.frame

		weapon:SetRaised(IsValid(frame) and frame.bEmbedded and frame.bFocused == true)
	end
end

function C.SetFocus(bFocus)
	local frame = C.frame

	if (!IsValid(frame) or !frame.bEmbedded or frame.bFocused == bFocus) then
		return
	end

	frame.bFocused = bFocus

	if (bFocus) then
		-- MakePopup сам не включает обратно выключенный ввод мыши — включаем явно.
		frame:SetMouseInputEnabled(true)
		frame:SetKeyboardInputEnabled(true)
		frame:MakePopup()
		gui.EnableScreenClicker(true)

		local x, y = frame:GetPos()

		input.SetCursorPos(x + frame:GetWide() / 2, y + frame:GetTall() / 2)
	else
		frame:SetMouseInputEnabled(false)
		frame:SetKeyboardInputEnabled(false)
		gui.EnableScreenClicker(false)
	end

	surface.PlaySound("buttons/lightswitch2.wav")
	C.SyncRaise()
end

-- Каждый клик по меню — анимация нажатия пальцем.
hook.Add("VGUIMousePressed", "nwPDAPress", function(panel, code)
	local frame = C.frame

	if (!IsValid(frame) or !frame.bEmbedded or !IsValid(panel)) then
		return
	end

	if (panel != frame and !panel:HasParent(frame)) then
		return
	end

	if (code == MOUSE_RIGHT) then
		C.SetFocus(false)

		return
	end

	C.rippleX, C.rippleY = frame:CursorPos()
	C.rippleAt = RealTime()
	C.pressedPanel = panel != frame and panel or nil
	C.pressedAt = RealTime()

	local weapon = LocalPlayer():GetActiveWeapon()

	if (IsValid(weapon) and weapon.Press) then
		weapon:Press()
	end

	if ((C.nextPress or 0) > RealTime()) then
		return
	end

	C.nextPress = RealTime() + 0.2
	C.pressAt = RealTime()
end)

-- Network -------------------------------------------------------------------------------------
net.Receive("nwPDAOpen", function()
	local bBackground = net.ReadBool()

	if (IsValid(C.frame) and C.frame.bEmbedded) then
		if (!bBackground) then
			C.SetFocus(true)
		end

		return
	end

	C.Show("home", false)

	-- Интерфейс сразу на экране КПК, а мышь остаётся в игре до ЛКМ/ПКМ.
	if (bBackground) then
		C.SetFocus(false)
	end
end)

net.Receive("nwCityReply", function()
	local kind = net.ReadString()
	local data = NETWORK.util.ReadTable()
	local frame = C.frame

	C.responses[kind] = data

	if (!IsValid(frame)) then
		return
	end

	if (kind == "watch") then
		if (!C.feed or C.feed.index != data.index or frame.page != "feed") then
			C.Open("feed", false)
			Body(frame)
			PAGES.feed.Draw(frame.body, data)
		else
			C.feed = data
		end

		return
	end

	local def = PAGES[frame.page]

	if (def and def.reply == kind and def.Draw) then
		Body(frame)
		def.Draw(frame.body, data)
	end
end)

concommand.Add("network_c24_cameras", function()
	C.Show("cameras", false)
end)

NETWORK.cmbterm.RegisterExtension("c24_cameras", {
	name = "Камеры С24", glyph = "eye", caption = "Монтаж, наблюдение и снабжение",
	access = function(p, e)
		return IsValid(e) and e:GetClass() == "nw_cwuterminal"
	end,
	Build = function(panel, x, y, w, bottom)
		panel:AddAction("Открыть камеры С24 и производство", x, y, w, 44, function()
			C.Show("home", true)
		end)
	end
})

-- Context-menu property must be registered on both realms.
properties.Add("nw_factory_breaker_model", {
	MenuLabel = "Модель электрощитка", Order = 990, MenuIcon = "icon16/brick_edit.png",
	Filter = function(_, e, p)
		return IsValid(e) and e:GetClass() == "nw_breaker" and p:IsAdmin()
	end,
	Action = function(self, e)
		Derma_StringRequest("Электрощиток", "Путь к модели:", e:GetModel(), function(model)
			self:MsgStart()
				net.WriteEntity(e)
				net.WriteString(model)
			self:MsgEnd()
		end)
	end
})
