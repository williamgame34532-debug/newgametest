local CATEGORY_ICONS = {
	performance = "developer_board",
	interface = "settings_input_component",
	view = "visibility",
	legs = "directions_run",
	thirdperson = "person",
	hud = "info",
	general = "list"
}

local function GetCategoryIcon(id)
	return NETWORK.util.GetMaterial("framework/icons/" .. (CATEGORY_ICONS[id] or "list") ..
		".png", "smooth")
end

local function DrawIcon(material, x, y, size, color)
	if (!material or material:IsError()) then
		return
	end

	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	surface.SetMaterial(material)
	surface.DrawTexturedRect(x, y, size, size)
end

local function FormatNumber(value, decimals)
	value = tonumber(value) or 0

	if ((decimals or 0) <= 0) then
		return tostring(math.Round(value))
	end

	return string.format("%." .. decimals .. "f", value)
end

local function FormatValue(entry, raw)
	if (raw == nil) then
		return "-"
	end

	if (entry.type == "bool") then
		local bValue = isstring(raw) and (raw != "0" and raw != "false" and raw != "") or
			tobool(raw)

		return L(bValue and "settingsOn" or "settingsOff")
	elseif (entry.type == "number") then
		return FormatNumber(raw, entry.decimals)
	elseif (entry.type == "choice") then
		for _, option in ipairs(entry.options or {}) do
			if (tostring(option.value) == tostring(raw)) then
				return L(option.label)
			end
		end
	end

	return tostring(raw)
end

local function GetHint(entry)
	if (entry.type == "bool") then
		return L("optHintBool")
	elseif (entry.type == "number") then
		return L("optHintRange", FormatNumber(entry.min or 0, entry.decimals),
			FormatNumber(entry.max or 1, entry.decimals))
	elseif (entry.type == "choice") then
		local labels = {}

		for _, option in ipairs(entry.options or {}) do
			labels[#labels + 1] = L(option.label)
		end

		return L("optHintChoice", table.concat(labels, " / "))
	end

	return ""
end

local function GetDescription(entry)
	if (entry.description and NETWORK.lang.Exists(entry.description)) then
		local text = L(entry.description)

		if (text != "") then
			return text
		end
	end

	return GetHint(entry)
end

local function GetMeta(entry)
	local meta = NETWORK.option.stored and NETWORK.option.stored[entry.id]

	if (meta and meta.name == entry.name) then
		return meta
	end

	meta = NETWORK.config and NETWORK.config.stored and NETWORK.config.stored[entry.id]

	if (meta and meta.name == entry.name) then
		return meta
	end
end

local function GetDefault(entry)
	local meta = GetMeta(entry)

	if (!meta) then
		return
	end

	if (meta.default != nil) then
		return meta.default
	end

	local convar = meta.convar and GetConVar(meta.convar)

	if (convar) then
		return convar:GetDefault()
	end
end

local ANIM_TOGGLE = 0.15

local function ValueKey(entry, value)
	if (entry.type == "number") then
		return FormatNumber(value, entry.decimals)
	elseif (entry.type == "bool") then
		return tostring(tobool(value))
	end

	return tostring(value)
end

local TOGGLE = {}

function TOGGLE:Init()
	self:SetText("")
	self:SetCursor("hand")

	self.state = 0
	self.hover = 0
end

function TOGGLE:Setup(getter, setter, bReadOnly)
	self.getter = getter
	self.setter = setter
	self.bReadOnly = bReadOnly
	self.state = getter() and 1 or 0
end

function TOGGLE:OnMousePressed(code)
	if (code != MOUSE_LEFT or self.bReadOnly) then
		return
	end

	self.setter(!self.getter())

	NETWORK.sound.Click()
end

function TOGGLE:Think()
	self.hover = NETWORK.util.Approach(self.hover, self:IsHovered() and 1 or 0, 10)
	self.state = math.Approach(self.state, self.getter() and 1 or 0,
		FrameTime() / ANIM_TOGGLE)
end

function TOGGLE:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local S = NETWORK.style
	local accent = S.Accent()
	local state = util.EaseInOut(math.Clamp(self.state, 0, 1))
	local hover = self.hover
	local fade = self.bReadOnly and 0.5 or 1
	local trackHeight = math.max(Sc(20), 12)
	local trackWidth = math.max(Sc(40), 24)
	local x = width - trackWidth
	local y = math.Round((height - trackHeight) * 0.5)
	local radius = math.floor(trackHeight * 0.5)

	draw.RoundedBox(radius, x, y, trackWidth, trackHeight, Color(0, 0, 0, 110 * fade))

	if (state > 0.01) then
		draw.RoundedBox(radius, x, y, trackWidth, trackHeight,
			ColorAlpha(accent, (70 + 40 * hover) * state * fade))
	end

	local line = S.lineStrong

	util.DrawRoundedBorder(x, y, trackWidth, trackHeight, radius, 1,
		Color(Lerp(state, line.r, accent.r), Lerp(state, line.g, accent.g),
			Lerp(state, line.b, accent.b), (Lerp(state, line.a, 170) + 30 * hover) * fade))

	local pad = math.max(Sc(4), 3)
	local knob = trackHeight - pad * 2
	local knobX = math.Round(x + pad + (trackWidth - pad * 2 - knob) * state)
	local off = theme.textFaint

	draw.RoundedBox(math.floor(knob * 0.5), knobX, y + pad, knob, knob,
		Color(Lerp(state, off.r, accent.r + (255 - accent.r) * 0.35),
			Lerp(state, off.g, accent.g + (255 - accent.g) * 0.35),
			Lerp(state, off.b, accent.b + (255 - accent.b) * 0.35), 250 * fade))
end

vgui.Register("nwOptToggle", TOGGLE, "DButton")

local SLIDER = {}

function SLIDER:Init()
	self:SetCursor("hand")

	self.display = 0
	self.hover = 0
	self.bDragging = false
end

function SLIDER:Setup(getter, setter, min, max, decimals, bReadOnly)
	self.getter = getter
	self.setter = setter
	self.min = min or 0
	self.max = max or 1
	self.decimals = decimals or 0
	self.bReadOnly = bReadOnly
	self.display = self:GetFraction()
end

function SLIDER:GetFraction()
	return math.Clamp((self.getter() - self.min) / math.max(self.max - self.min, 0.0001), 0, 1)
end

function SLIDER:UpdateFromCursor()
	local x = self:CursorPos()
	local Sc = NETWORK.util.Scale
	local track = self:GetWide() - Sc(70)
	local fraction = math.Clamp(x / math.max(track, 1), 0, 1)
	local value = self.min + fraction * (self.max - self.min)

	if (self.decimals <= 0) then
		value = math.Round(value)
	else
		value = math.Round(value, self.decimals)
	end

	self.setter(value)
end

function SLIDER:OnMousePressed()
	if (self.bReadOnly) then
		return
	end

	self.bDragging = true

	self:UpdateFromCursor()
	self:MouseCapture(true)
end

function SLIDER:OnMouseReleased()
	self.bDragging = false

	self:MouseCapture(false)
end

function SLIDER:Think()
	if (self.bDragging) then
		self:UpdateFromCursor()
	end

	self.hover = NETWORK.util.Approach(self.hover,
		(self:IsHovered() or self.bDragging) and 1 or 0, 10)
	self.display = NETWORK.util.Approach(self.display, self:GetFraction(), 12)
end

function SLIDER:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local S = NETWORK.style
	local accent = S.Accent()
	local fade = self.bReadOnly and 0.5 or 1
	local track = width - Sc(70)
	local thick = math.max(Sc(4), 3)
	local middle = math.Round(height * 0.5)
	local y = middle - math.floor(thick * 0.5)
	local value = self.getter()
	local fill = math.Round(track * self.display)
	local radius = math.floor(thick * 0.5)

	draw.RoundedBox(radius, 0, y, track, thick, Color(255, 255, 255, 22 * fade))

	if (fill > thick) then
		draw.RoundedBox(radius, 0, y, fill, thick, ColorAlpha(accent, 235 * fade))
	end

	local knob = math.max(Sc(12), 8) + math.Round(self.hover * Sc(2))
	local knobX = math.Clamp(fill - math.Round(knob * 0.5), 0, math.max(track - knob, 0))
	local knobY = middle - math.Round(knob * 0.5)

	if (self.hover > 0.01) then
		local ring = knob + math.max(Sc(6), 4)

		draw.RoundedBox(math.floor(ring * 0.5), knobX - math.Round((ring - knob) * 0.5),
			middle - math.Round(ring * 0.5), ring, ring, ColorAlpha(accent, 50 * self.hover * fade))
	end

	draw.RoundedBox(math.floor(knob * 0.5), knobX, knobY, knob, knob,
		ColorAlpha(theme.text, 250 * fade))

	local text = self.decimals <= 0 and tostring(math.Round(value)) or
		string.format("%." .. self.decimals .. "f", value)

	draw.SimpleText(text, "nwHud", width, middle, ColorAlpha(theme.text, 245 * fade),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

vgui.Register("nwOptSlider", SLIDER, "DPanel")

local CHOICE = {}
local CHOICE_FONT = "nwInvStat"

function CHOICE:Init()
	self:SetText("")
	self:SetCursor("hand")

	self.hover = 0
	self.bSegmented = false
	self.segWidths = {}
end

function CHOICE:Setup(getter, setter, options, bReadOnly)
	self.getter = getter
	self.setter = setter
	self.options = options or {}
	self.bReadOnly = bReadOnly
end

function CHOICE:Measure()
	local Sc = NETWORK.util.Scale
	local pad = math.max(Sc(11), 6)
	local total = 0

	surface.SetFont(CHOICE_FONT)

	for i = 1, #self.options do
		local textWidth = surface.GetTextSize(L(self.options[i].label))

		self.segWidths[i] = textWidth + pad * 2
		total = total + self.segWidths[i]
	end

	return total
end

function CHOICE:GetIndex()
	local value = self.getter()

	for i = 1, #self.options do
		if (self.options[i].value == value) then
			return i
		end
	end

	return 1
end

function CHOICE:GetSegmentAt(x)
	local total = 0

	for i = 1, #self.options do
		total = total + (self.segWidths[i] or 1)
	end

	local scale = self:GetWide() / math.max(total, 1)
	local cursor = 0

	for i = 1, #self.options do
		cursor = cursor + (self.segWidths[i] or 1) * scale

		if (x < cursor) then
			return i
		end
	end

	return #self.options
end

function CHOICE:OnMousePressed(code)
	if (self.bReadOnly or #self.options == 0) then
		return
	end

	local index

	if (self.bSegmented and code == MOUSE_LEFT) then
		index = self:GetSegmentAt(self:CursorPos())
	else
		local step = code == MOUSE_RIGHT and -1 or 1

		index = (self:GetIndex() - 1 + step) % #self.options + 1
	end

	self.setter(self.options[index].value)

	NETWORK.sound.Click()
end

function CHOICE:Think()
	self.hover = NETWORK.util.Approach(self.hover, self:IsHovered() and 1 or 0, 10)
end

function CHOICE:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local S = NETWORK.style
	local accent = S.Accent()
	local fade = self.bReadOnly and 0.5 or 1
	local hover = self.hover
	local boxHeight = math.min(height, math.max(Sc(26), 16))
	local y = math.Round((height - boxHeight) * 0.5)
	local radius = math.floor(boxHeight * 0.5)
	local current = self:GetIndex()
	local middle = y + math.Round(boxHeight * 0.5)

	draw.RoundedBox(radius, 0, y, width, boxHeight, Color(0, 0, 0, 90 * fade))

	if (!self.bSegmented) then
		local option = self.options[current]

		draw.SimpleText(option and L(option.label) or "-", CHOICE_FONT, math.Round(width * 0.5),
			middle, ColorAlpha(theme.text, 245 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		if (#self.options > 1) then
			local color = ColorAlpha(hover > 0.5 and theme.text or theme.textFaint, 235 * fade)

			draw.SimpleText("‹", CHOICE_FONT, radius, middle, color, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
			draw.SimpleText("›", CHOICE_FONT, width - radius, middle, color, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end

		NETWORK.util.DrawRoundedBorder(0, y, width, boxHeight, radius, 1,
			ColorAlpha(S.lineStrong, (S.lineStrong.a + 50 * hover) * fade))

		return
	end

	local total = 0

	for i = 1, #self.options do
		total = total + (self.segWidths[i] or 1)
	end

	local scale = width / math.max(total, 1)
	local hovered = hover > 0.01 and self:IsHovered() and self:GetSegmentAt(self:CursorPos())
	local cursor = 0
	local count = #self.options

	for i = 1, count do
		local segX = math.Round(cursor)
		local segRight = (i == count) and width or math.Round(cursor + (self.segWidths[i] or 1) * scale)
		local segWidth = segRight - segX
		local bFirst, bLast = i == 1, i == count

		if (i == current) then
			draw.RoundedBoxEx(radius, segX, y, segWidth, boxHeight,
				ColorAlpha(accent, 70 * fade), bFirst, bLast, bFirst, bLast)
		elseif (i == hovered and !self.bReadOnly) then
			draw.RoundedBoxEx(radius, segX, y, segWidth, boxHeight,
				Color(255, 255, 255, 12 * hover), bFirst, bLast, bFirst, bLast)
		end

		if (!bFirst) then
			surface.SetDrawColor(S.lineStrong.r, S.lineStrong.g, S.lineStrong.b,
				S.lineStrong.a * fade)
			surface.DrawRect(segX, y + 1, 1, boxHeight - 2)
		end

		draw.SimpleText(L(self.options[i].label), CHOICE_FONT,
			segX + math.Round(segWidth * 0.5), middle,
			ColorAlpha(i == current and theme.text or theme.textDim, 245 * fade),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		cursor = cursor + (self.segWidths[i] or 1) * scale
	end

	NETWORK.util.DrawRoundedBorder(0, y, width, boxHeight, radius, 1,
		ColorAlpha(S.lineStrong, (S.lineStrong.a + 40 * hover) * fade))
end

vgui.Register("nwOptChoice", CHOICE, "DButton")

local ROW = {}

function ROW:Init()
	self.hover = 0
	self.reveal = 0
	self.revealDelay = 0
	self.startTime = CurTime()
end

function ROW:Setup(entry, list)
	local Sc = NETWORK.util.Scale

	self.entry = entry
	self.list = list
	self.label = L(entry.name)
	self.description = GetDescription(entry)

	if (entry.type == "bool") then
		self.control = self:Add("nwOptToggle")
		self.control:Setup(entry.get, entry.set, entry.readOnly)
		self.control:SetSize(Sc(60), Sc(30))
	elseif (entry.type == "number") then
		self.control = self:Add("nwOptSlider")
		self.control:Setup(entry.get, entry.set, entry.min, entry.max, entry.decimals,
			entry.readOnly)
		self.control:SetSize(Sc(260), Sc(30))
	elseif (entry.type == "string") then
		self.control = self:Add("nwOptText")
		self.control:Setup(entry.get, entry.set, entry.readOnly)
		self.control:SetSize(Sc(320), Sc(30))
	else
		self.control = self:Add("nwOptChoice")
		self.control:Setup(entry.get, entry.set, entry.options, entry.readOnly)

		local count = #(entry.options or {})
		local needed = self.control:Measure()

		if (count >= 2 and count <= 5 and needed <= Sc(380)) then
			self.control.bSegmented = true
			self.control:SetSize(math.max(needed, Sc(120)), Sc(30))
		else
			self.control:SetSize(Sc(200), Sc(30))
		end
	end
end

function ROW:PerformLayout(width, height)
	if (IsValid(self.control)) then
		self.control:SetPos(width - self.control:GetWide() - NETWORK.util.Scale(14),
			math.Round((height - self.control:GetTall()) * 0.5))
	end
end

function ROW:SetRevealDelay(delay)
	self.revealDelay = delay
end

function ROW:OnCursorEntered()
	if (IsValid(self.list) and self.entry) then
		self.list:SetDescription(L(self.entry.name), GetDescription(self.entry), self.entry)
	end
end

function ROW:Think()
	local util = NETWORK.util

	self.hover = util.Approach(self.hover, self:IsHovered() and 1 or 0, 10)
	self.reveal = util.EaseOut(util.Stagger(self.startTime, self.revealDelay, 0.4))

	if (IsValid(self.control)) then
		self.control:SetAlpha(math.Round(self.reveal * 255))
	end
end

function ROW:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local S = NETWORK.style
	local util = NETWORK.util
	local reveal = self.reveal

	if (reveal < 0.01) then
		return
	end

	local hover = util.EaseInOut(self.hover)

	if (hover > 0.01) then
		draw.RoundedBox(S.Radius("cell"), 0, 0, width, height,
			Color(255, 255, 255, 9 * hover * reveal))
	end

	surface.SetDrawColor(S.line.r, S.line.g, S.line.b, S.line.a * 0.6 * reveal)
	surface.DrawRect(Sc(10), height - 1, width - Sc(20), 1)

	local bReadOnly = self.entry and self.entry.readOnly

	if (bReadOnly) then
		local rail = math.max(Sc(3), 2)
		local railHeight = math.Round(height * 0.5)

		draw.RoundedBox(math.floor(rail * 0.5), Sc(4), math.Round((height - railHeight) * 0.5),
			rail, railHeight, ColorAlpha(theme.warning, 220 * reveal))
	end

	local description = self.description or ""
	local bHasDescription = description != ""
	local textX = Sc(14) + math.Round((1 - reveal) * Sc(14))
	local controlWidth = IsValid(self.control) and self.control:GetWide() or 0
	local maxWidth = math.max(width - textX - controlWidth - Sc(30), Sc(40))
	local bChanged = IsValid(self.list) and self.list.IsChanged and self.list:IsChanged(self.entry)
	local chipText = bChanged and L("settingsChanged") or nil
	local chipWidth = 0

	if (chipText) then
		surface.SetFont("nwInvKey")
		chipWidth = surface.GetTextSize(chipText) + math.max(Sc(5), 3) * 2 + Sc(8)
	end

	local nameY = bHasDescription and math.Round(height * 0.5) - Sc(9) or math.Round(height * 0.5)
	local name = util.TruncateWidth(self.label, "nwCreateBodyBold",
		math.max(maxWidth - chipWidth, Sc(30)))

	draw.SimpleText(name, "nwCreateBodyBold", textX, nameY,
		ColorAlpha(theme.text, (225 + 30 * hover) * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (chipText) then
		surface.SetFont("nwCreateBodyBold")

		local nameWidth = surface.GetTextSize(name)
		local padY = math.max(Sc(2), 1)

		surface.SetFont("nwInvKey")

		local _, chipTextHeight = surface.GetTextSize(chipText)

		S.Chip(chipText, "nwInvKey", textX + nameWidth + Sc(8),
			nameY - math.Round(chipTextHeight * 0.5) - padY, theme.warning, reveal,
			{padX = math.max(Sc(5), 3), padY = padY})
	end

	if (bHasDescription) then
		draw.SimpleText(util.TruncateWidth(description, "nwStatusDesc", maxWidth),
			"nwStatusDesc", textX, math.Round(height * 0.5) + Sc(10),
			ColorAlpha(theme.textDim, 215 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwOptRow", ROW, "DPanel")

local TEXT = {}

function TEXT:Init()
	self:SetFont("nwField")
	self:SetDrawLanguageID(false)
	self:SetPaintBackground(false)
	self:SetTextColor(NETWORK.theme.text)
	self:SetCursorColor(NETWORK.theme.combine)
	self:SetHighlightColor(NETWORK.theme.combineDeep)
	self:SetUpdateOnType(false)
end

function TEXT:Setup(getter, setter, bReadOnly)
	self.getter = getter
	self.setter = setter
	self.bReadOnly = bReadOnly

	self:SetValue(tostring(getter() or ""))
	self:SetEditable(!bReadOnly)
end

function TEXT:Commit()
	if (self.bReadOnly or !self.setter) then
		return
	end

	local value = self:GetValue()

	if (value != tostring(self.getter() or "")) then
		self.setter(value)

		NETWORK.sound.Click()
	end
end

function TEXT:OnEnter()
	self:Commit()
end

function TEXT:OnLoseFocus()
	self:Commit()
end

function TEXT:Think()
	if (!self:HasFocus() and !self.bEditing) then
		local current = tostring(self.getter and self.getter() or "")

		if (self:GetValue() != current) then
			self:SetValue(current)
		end
	end
end

function TEXT:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme

	local radius = NETWORK.style.Radius("cell")
	local line = NETWORK.style.lineStrong

	draw.RoundedBox(radius, 0, Sc(3), width, height - Sc(6), Color(0, 0, 0, 110))
	NETWORK.util.DrawRoundedBorder(0, Sc(3), width, height - Sc(6), radius, 1,
		self:HasFocus() and ColorAlpha(theme.combine, 190) or line)

	self:DrawTextEntryText(theme.text, theme.combineDeep, theme.combine)
end

vgui.Register("nwOptText", TEXT, "DTextEntry")

local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self.category = nil
	self.entries = {}
	self.categories = {}
	self.initial = {}
	self.searchText = {}
	self.counts = {}
	self.title = ""
	self.body = ""
	self.sideWidth = Sc(220)
	self.infoWidth = Sc(250)

	self.sidebar = self:Add("DScrollPanel")

	self.search = NETWORK.gui.BindEntry(self:Add("DTextEntry"))
	self.list = self:Add("DScrollPanel")

	self.presetsButton = self:Add("DButton")
	self.presetsButton:SetText("Предустановки")
	self.presetsButton.DoClick = function() NETWORK.option.presets.Open() end
	self.search:SetFont("nwField")
	self.search:SetPaintBackground(false)
	self.search:SetTextColor(NETWORK.theme.inv.text)
	self.search:SetCursorColor(NETWORK.theme.combine)
	self.search:SetUpdateOnType(true)

	self.search.Paint = function(panel, width, height)
		local theme = NETWORK.theme

		if (panel:GetValue() == "") then
			draw.SimpleText(L("settingsSearch"), "nwField", Sc(2), math.Round(height * 0.5),
				ColorAlpha(theme.textFaint, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		panel:DrawTextEntryText(theme.text, theme.combineDeep or theme.combine, theme.combine)
	end
	self.search.OnValueChange = function()
		self:Rebuild()
	end

	for _, scroll in ipairs({self.sidebar, self.list}) do
		local bar = scroll:GetVBar()

		bar:SetWide(Sc(4))
		bar.Paint = function() end
		bar.btnUp.Paint = function() end
		bar.btnDown.Paint = function() end
		bar.btnGrip.Paint = function(panel, width, height)
			draw.RoundedBox(math.floor(width * 0.5), 0, 0, width, height, Color(255, 255, 255, 60))
		end
	end
end

function PANEL:SetSource(categories, entries)
	self.categories = categories or {}
	self.entries = entries or {}
	self.initial = {}
	self.searchText = {}

	for _, entry in ipairs(self.entries) do
		if (entry.get) then
			self.initial[entry] = ValueKey(entry, entry.get())
		end

		local description = GetDescription(entry)
		local raw = entry.description and NETWORK.lang.Exists(entry.description) and
			L(entry.description) or ""

		self.searchText[entry] = NETWORK.util.Lower(L(entry.name) .. "\n" .. description ..
			"\n" .. raw)
	end

	self:BuildSidebar()
	self:Rebuild()
end

function PANEL:IsChanged(entry)
	local initial = entry and self.initial[entry]

	if (initial == nil or !entry.get) then
		return false
	end

	return ValueKey(entry, entry.get()) != initial
end

function PANEL:SetDescription(title, body, entry)
	self.title = title
	self.body = body
	self.bodyLines = nil
	self.infoEntry = entry
end

function PANEL:GetSearchBox()
	local Sc = NETWORK.util.Scale
	local x = self.sideWidth + Sc(20)

	return x, 0, self:GetWide() - x - self.infoWidth - Sc(28), math.max(Sc(36), 22)
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.sideWidth = Sc(220)
	self.infoWidth = Sc(250)

	self.sidebar:SetPos(0, 0)
	self.sidebar:SetSize(self.sideWidth, height)

	local x, y, boxWidth, boxHeight = self:GetSearchBox()
	local iconArea = math.Round(boxHeight * 0.5) + Sc(22)

	self.search:SetPos(x + iconArea, y)
	local presetWidth = self.presetsButton:IsVisible() and math.min(Sc(130), boxWidth * 0.4) or 0
	self.presetsButton:SetPos(x + boxWidth - presetWidth, y)
	self.presetsButton:SetSize(presetWidth, boxHeight)
	self.search:SetSize(math.max(boxWidth - iconArea - presetWidth - Sc(14), Sc(40)), boxHeight)

	self.list:SetPos(x, boxHeight + Sc(12))
	self.list:SetSize(boxWidth, height - boxHeight - Sc(12))
end

function PANEL:BuildSidebar()
	local Sc = NETWORK.util.Scale

	self.sidebar:Clear()

	local list = {{id = nil, name = "settingsAll"}}

	for _, category in ipairs(self.categories) do
		list[#list + 1] = category
	end

	for i = 1, #list do
		local category = list[i]
		local button = self.sidebar:Add("DButton")

		button:Dock(TOP)
		button:DockMargin(Sc(6), 0, Sc(12), Sc(3))
		button:SetTall(Sc(38))
		button:SetText("")
		button:SetCursor("hand")
		button.hover = 0
		button.active = 0
		button.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 10)
			panel.active = NETWORK.util.Approach(panel.active,
				self.category == category.id and 1 or 0, 12)
		end

		button.Paint = function(panel, width, height)
			local theme = NETWORK.theme
			local S = NETWORK.style
			local accent = S.Accent()
			local radius = S.Radius("cell")
			local active = panel.active
			local bActive = self.category == category.id
			local count = self.counts[category.id or "*"] or 0
			local bEmpty = count == 0 and !bActive
			local fade = bEmpty and 0.45 or 1

			if (panel.hover > 0.01) then
				draw.RoundedBox(radius, 0, 0, width, height,
					Color(255, 255, 255, 9 * panel.hover))
			end

			if (active > 0.01) then
				draw.RoundedBox(radius, 0, 0, width, height, ColorAlpha(accent, 38 * active))

				local rail = math.max(Sc(3), 2)
				local railHeight = math.Round((height - Sc(14)) * active)

				draw.RoundedBox(math.floor(rail * 0.5), Sc(3),
					math.Round((height - railHeight) * 0.5), rail, railHeight,
					ColorAlpha(accent, 245 * active))
			end

			local color = ColorAlpha(bActive and theme.text or theme.textDim, 245 * fade)
			local iconSize = Sc(16)
			local textX = Sc(16) + iconSize + Sc(10)

			DrawIcon(GetCategoryIcon(category.id), Sc(16),
				math.Round((height - iconSize) * 0.5), iconSize,
				bActive and ColorAlpha(accent, 255) or color)

			local countText = tostring(count)

			surface.SetFont("nwInvKey")

			local countWidth = surface.GetTextSize(countText)

			draw.SimpleText(countText, "nwInvKey", width - Sc(12), math.Round(height * 0.5),
				ColorAlpha(bActive and theme.textDim or theme.textFaint, 235 * fade),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			draw.SimpleText(NETWORK.util.TruncateWidth(L(category.name), "nwField",
				width - textX - countWidth - Sc(20)), "nwField", textX, math.Round(height * 0.5),
				color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			self.category = category.id

			self:Rebuild()

			NETWORK.sound.Click()
		end
	end
end

function PANEL:MatchesFilter(entry, filter)
	if (filter == "") then
		return true
	end

	local text = self.searchText[entry] or NETWORK.util.Lower(L(entry.name))

	return string.find(text, filter, 1, true) != nil
end

function PANEL:Rebuild()
	local Sc = NETWORK.util.Scale
	local filter = NETWORK.util.Lower(string.Trim(self.search:GetValue() or ""))

	self.list:Clear()

	local grouped = {}
	local order = {}

	self.counts = {["*"] = 0}

	for _, entry in ipairs(self.entries) do
		if (!self:MatchesFilter(entry, filter)) then
			continue
		end

		self.counts["*"] = self.counts["*"] + 1

		if (entry.category != nil) then
			self.counts[entry.category] = (self.counts[entry.category] or 0) + 1
		end

		if (self.category and entry.category != self.category) then
			continue
		end

		if (!grouped[entry.category]) then
			grouped[entry.category] = {}
			order[#order + 1] = entry.category
		end

		local group = grouped[entry.category]

		group[#group + 1] = entry
	end

	if (#order == 0) then
		local empty = self.list:Add("DPanel")

		empty:Dock(TOP)
		empty:DockMargin(0, Sc(24), Sc(14), 0)
		empty:SetTall(Sc(40))
		empty.Paint = function(panel, width, height)
			draw.SimpleText(L("settingsNoResults"), "nwField", math.Round(width * 0.5),
				math.Round(height * 0.5), ColorAlpha(NETWORK.theme.textFaint, 230),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		return
	end

	local delay = 0

	for _, id in ipairs(order) do
		local name = id

		for _, category in ipairs(self.categories) do
			if (category.id == id) then
				name = category.name

				break
			end
		end

		local header = self.list:Add("DPanel")

		header:Dock(TOP)
		header:DockMargin(0, Sc(12), Sc(14), Sc(2))
		header:SetTall(Sc(26))
		header.Paint = function(panel, width, height)
			local theme = NETWORK.theme
			local S = NETWORK.style
			local color = ColorAlpha(theme.textFaint, 235)
			local iconSize = Sc(14)
			local middle = math.Round(height * 0.5)

			DrawIcon(GetCategoryIcon(id), Sc(14), middle - math.Round(iconSize * 0.5),
				iconSize, ColorAlpha(S.Accent(), 200))

			local textWidth = NETWORK.util.DrawTextSpaced(NETWORK.util.Upper(L(name)),
				"nwHudSmall", Sc(14) + iconSize + Sc(8), middle, color, Sc(3),
				TEXT_ALIGN_CENTER) or 0

			local lineX = Sc(14) + iconSize + Sc(8) + math.Round(tonumber(textWidth) or 0) + Sc(12)

			if (lineX < width - Sc(14)) then
				surface.SetDrawColor(S.line.r, S.line.g, S.line.b, S.line.a)
				surface.DrawRect(lineX, middle, width - Sc(14) - lineX, 1)
			end
		end

		for _, entry in ipairs(grouped[id]) do
			delay = delay + 1

			local row = self.list:Add("nwOptRow")

			row:Dock(TOP)
			row:DockMargin(0, 0, Sc(14), Sc(2))

			local bDescribed = GetDescription(entry) != ""

			row:SetTall(bDescribed and Sc(56) or Sc(44))
			row:SetWide(self.list:GetWide() - Sc(14))
			row:Setup(entry, self)
			row:SetRevealDelay(0.02 + delay * 0.02)
		end
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local S = NETWORK.style
	local util = NETWORK.util
	local accent = S.Accent()

	self.infoWidth = self.infoWidth or Sc(250)
	self.sideWidth = self.sideWidth or Sc(220)

	surface.SetDrawColor(S.line.r, S.line.g, S.line.b, S.line.a)
	surface.DrawRect(self.sideWidth + Sc(6), 0, 1, height)

	local searchX, searchY, searchWidth, searchHeight = self:GetSearchBox()
	local searchRadius = math.floor(searchHeight * 0.5)
	local bFocus = IsValid(self.search) and self.search:HasFocus()

	draw.RoundedBox(searchRadius, searchX, searchY, searchWidth, searchHeight,
		Color(0, 0, 0, bFocus and 120 or 90))
	util.DrawRoundedBorder(searchX, searchY, searchWidth, searchHeight, searchRadius, 1,
		bFocus and ColorAlpha(accent, 190) or S.lineStrong)

	local searchIcon = util.GetMaterial("framework/status/search.png", "smooth")
	local iconSize = Sc(16)

	DrawIcon(searchIcon, searchX + searchRadius, searchY + math.Round((searchHeight - iconSize) * 0.5),
		iconSize, bFocus and accent or theme.textFaint)

	local cardX = width - self.infoWidth - Sc(8)

	S.Card(cardX, 0, self.infoWidth + Sc(8), height, 1, {blur = false, shadow = false,
		fill = Color(S.fill.r, S.fill.g, S.fill.b, 120), radius = S.Radius("panel")})

	local x = cardX + Sc(16)
	local infoWidth = self.infoWidth - Sc(24)

	util.DrawTextSpaced(util.Upper(self.title != "" and self.title or L("settingsHint")),
		"nwSectionLabel", x, Sc(22), ColorAlpha(theme.combineSoft or accent, 252), Sc(3),
		TEXT_ALIGN_CENTER)

	local body = self.body != "" and self.body or L("settingsHintBody")

	if (self.bodyLines == nil or self.bodyText != body) then
		self.bodyLines = util.WrapText(body, "nwChatSmall", infoWidth, 8)
		self.bodyText = body
	end

	local y = Sc(48)

	for i = 1, #self.bodyLines do
		draw.SimpleText(self.bodyLines[i], "nwChatSmall", x, y,
			ColorAlpha(theme.textDim, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		y = y + Sc(20)
	end

	local entry = self.infoEntry

	if (!entry) then
		return
	end

	local maxWidth = infoWidth
	local current = entry.get and FormatValue(entry, entry.get()) or nil
	local default = GetDefault(entry)

	y = y + Sc(8)

	surface.SetDrawColor(S.line.r, S.line.g, S.line.b, S.line.a)
	surface.DrawRect(x, y, maxWidth, 1)

	y = y + Sc(16)

	local rows = {}

	if (current != nil) then
		rows[#rows + 1] = {L("settingsCurrent"), current, self:IsChanged(entry) and theme.warning or
			theme.text}
	end

	if (default != nil) then
		rows[#rows + 1] = {L("settingsDefault"), FormatValue(entry, default), theme.textDim}
	end

	for _, row in ipairs(rows) do
		local label = util.Upper(row[1])

		surface.SetFont("nwHudSmall")

		local labelWidth = surface.GetTextSize(label)
		local valueX = x + labelWidth + Sc(8)

		draw.SimpleText(label, "nwHudSmall", x, y, ColorAlpha(theme.textFaint, 220),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(util.TruncateWidth(row[2], "nwChatSmall",
			math.max(maxWidth - labelWidth - Sc(8), Sc(30))), "nwChatSmall", valueX, y,
			ColorAlpha(row[3], 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		y = y + Sc(20)
	end

	local meta = GetMeta(entry)

	if (meta and meta.convar) then
		draw.SimpleText(util.TruncateWidth(meta.convar, "nwHudSmall", maxWidth), "nwHudSmall",
			x, y, ColorAlpha(theme.textFaint, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwSettingsList", PANEL, "DPanel")
