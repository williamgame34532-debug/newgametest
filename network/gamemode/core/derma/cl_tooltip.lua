local PANEL = {}

PANEL.alpha = 0

local tipOffset = CreateClientConVar("network_tooltip_offset", "28", true, false,
	"На сколько подсказка опущена ниже курсора")

local tipSide = CreateClientConVar("network_tooltip_side", "0", true, false,
	"На сколько подсказка сдвинута правее курсора")

local function MigrateLayout()
	if (cookie.GetNumber("nwTipLayout", 0) >= 1) then
		return
	end

	cookie.Set("nwTipLayout", "1")

	if (tipOffset:GetInt() == 46) then
		RunConsoleCommand("network_tooltip_offset", "28")
	end

	if (tipSide:GetInt() == 40) then
		RunConsoleCommand("network_tooltip_side", "0")
	end
end

NETWORK.option.Register("network_tooltip_side", {
	name = "optTipSide",
	description = "optTipSideDesc",
	category = "interface",
	type = "number",
	convar = "network_tooltip_side",
	min = 0,
	max = 200,
	decimals = 0
})

NETWORK.option.Register("network_tooltip_offset", {
	name = "optTipOffset",
	description = "optTipOffsetDesc",
	category = "interface",
	type = "number",
	convar = "network_tooltip_offset",
	min = 0,
	max = 120,
	decimals = 0
})

NETWORK.gui.tooltip = NETWORK.gui.tooltip or {}

local OPEN_TIME = 0.26
local CLOSE_TIME = 0.15

local BASE_WIDTH = 360

local fontSpecs = {
	name = {face = "body", size = 21, weight = 700},
	cap = {face = "label", size = 11, weight = 700},
	mono = {face = "mono", size = 15, weight = 600},
	key = {face = "mono", size = 10, weight = 700}
}

local fontCache = {}

local function TipFont(kind)
	local spec = fontSpecs[kind]
	local size = NETWORK.util.Scale(spec.size)
	local name = "nwTip_" .. kind .. "_" .. size

	if (!fontCache[name]) then
		local faces = NETWORK.fonts or {}

		surface.CreateFont(name, {
			font = faces[spec.face] or faces.body or "Arial",
			size = size,
			weight = spec.weight,
			extended = true,
			antialias = true
		})

		fontCache[name] = true
	end

	return name
end

NETWORK.gui.TipFont = TipFont

local function TextWidth(font, text)
	surface.SetFont(font)

	local width, height = surface.GetTextSize(text or "")

	return width, height
end

local function GetIcon(path)
	if (!path or path == "") then
		return
	end

	local material = NETWORK.util.GetMaterial(path, "smooth")

	if (!material or material:IsError()) then
		return
	end

	return material
end

function PANEL:Init()
	self.alpha = 0
	self.progress = 0

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

function PANEL:Think()
	local data = NETWORK.gui.tooltip.data

	local owner = NETWORK.gui.tooltip.owner

	if (owner and (!IsValid(owner) or !owner:IsVisible() or !owner:IsHovered())) then
		NETWORK.gui.tooltip.owner = nil
		NETWORK.gui.tooltip.data = nil

		data = nil
	end

	if (IsValid(NETWORK.gui.itemMenu) or NETWORK.gui.drag) then
		NETWORK.gui.tooltip.owner = nil
		NETWORK.gui.tooltip.data = nil

		data = nil
	end

	local delta = RealFrameTime()

	if (data) then
		owner = NETWORK.gui.tooltip.owner

		if (self.lastOwner != owner and (self.progress or 0) > 0.4) then
			self.progress = 0.4
		end

		self.lastOwner = owner
		self.data = data
		self.lines = data.lines or {}
		self.bOpen = true
		self.progress = math.min((self.progress or 0) + delta / OPEN_TIME, 1)
	else
		self.bOpen = false
		self.progress = math.max((self.progress or 0) - delta / CLOSE_TIME, 0)

		if (self.progress <= 0) then
			self.data = nil
			self.lastOwner = nil
		end
	end

	self.alpha = self.progress

	if (self:GetWide() != ScrW() or self:GetTall() != ScrH()) then
		self:SetSize(ScrW(), ScrH())
	end

	self:MoveToFront()
end

-- Layout ----------------------------------------------------------------------------------------
-- The tooltip is a PDA-style plate: a header band (type caption + title + icon tile), body text,
-- meter bars (freshness / condition / charges), a grid of stat cells and a key-hint strip. Every
-- tooltip in the gamemode goes through the same data table, so all of them get this look:
--   title, subtitle, caption, color, accent, icon, lines, bars, footer, freshness, hints

local function TipPalette()
	local P = NETWORK.theme.pda or {}

	return {
		fill = P.bg or Color(10, 22, 36),
		band = P.bg2 or Color(15, 31, 49),
		deep = P.deep or Color(7, 15, 25),
		line = P.line or Color(44, 70, 96),
		text = P.text or Color(228, 238, 246),
		muted = P.muted or Color(122, 146, 168),
		faint = P.faint or Color(84, 106, 128),
		accent = P.accent or Color(104, 170, 228)
	}
end

NETWORK.gui.TipPalette = TipPalette

function PANEL:GetLayout(data)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local scaleKey = Sc(1000)

	if (self.layout and self.layoutData == data and self.layoutScale == scaleKey) then
		return self.layout
	end

	local layout = {}
	local lines = data.lines or {}
	local footer = data.footer or {}
	local hints = istable(data.hints) and #data.hints > 0 and data.hints or nil
	local bars = {}

	for _, bar in ipairs(istable(data.bars) and data.bars or {}) do
		bars[#bars + 1] = bar
	end

	if (istable(data.freshness)) then
		local fresh = data.freshness

		table.insert(bars, 1, {
			label = fresh.title,
			text = fresh.label,
			fraction = fresh.fraction,
			color = fresh.color
		})
	end

	local caption = (data.caption and data.caption != "") and util.Upper(data.caption) or nil
	local subtitle = (data.subtitle and data.subtitle != "") and util.Upper(data.subtitle) or nil

	if (!caption and subtitle) then
		caption, subtitle = subtitle, nil
	end

	layout.fontName = TipFont("name")
	layout.fontCap = TipFont("cap")
	layout.fontMono = TipFont("mono")
	layout.fontKey = TipFont("key")

	layout.stripe = math.max(Sc(3), 2)
	layout.padL = Sc(18)
	layout.padR = Sc(16)
	layout.padT = Sc(11)
	layout.padB = Sc(12)
	layout.icon = GetIcon(data.icon)
	layout.glyph = layout.icon and Sc(34) or 0
	layout.glyphGap = layout.icon and Sc(12) or 0
	layout.lineHeight = Sc(19)
	layout.lines = lines
	layout.bars = bars
	layout.hints = hints
	layout.caption = caption
	layout.subtitle = subtitle
	layout.title = data.title or ""

	local baseWidth = Sc(BASE_WIDTH)
	local titleWidth, titleHeight = TextWidth(layout.fontName, layout.title)
	local capWidth, capHeight = TextWidth(layout.fontCap, (caption or "") .. "   " .. (subtitle or ""))

	layout.titleHeight = titleHeight
	layout.capHeight = capHeight

	local widest = layout.glyph + layout.glyphGap + math.max(titleWidth, capWidth)

	surface.SetFont("nwTipBody")

	for i = 1, #lines do
		widest = math.max(widest, surface.GetTextSize(lines[i]))
	end

	-- Stat cells: equal-width boxes, at most three per row.
	local cells = {}
	local cellWidest = 0

	for index, entry in ipairs(footer) do
		local label = util.Upper(entry.label or "")
		local value = tostring(entry.value or "")

		cells[index] = {label = label, value = value, color = entry.color}
		cellWidest = math.max(cellWidest, TextWidth(layout.fontCap, label),
			TextWidth(layout.fontMono, value))
	end

	layout.cells = cells
	layout.cellGap = Sc(6)
	layout.cellPad = Sc(8)
	layout.cellsPerRow = math.min(#cells, 3)

	if (layout.cellsPerRow > 0) then
		widest = math.max(widest, (cellWidest + layout.cellPad * 2) * layout.cellsPerRow +
			layout.cellGap * (layout.cellsPerRow - 1))
	end

	-- Key hints.
	local keyPad = math.max(Sc(5), 3)
	local hintGap = Sc(14)
	local hintWidth = 0

	if (hints) then
		layout.hintItems = {}

		for index, hint in ipairs(hints) do
			local key = util.Upper(tostring(hint.key or ""))
			local text = util.Upper(tostring(hint.text or ""))
			local keyWidth = TextWidth(layout.fontKey, key) + keyPad * 2
			local textWidth = TextWidth(layout.fontCap, text)

			layout.hintItems[index] = {key = key, text = text, keyWidth = keyWidth, textWidth = textWidth}

			hintWidth = hintWidth + keyWidth + Sc(6) + textWidth + (index > 1 and hintGap or 0)
		end

		layout.hintGap = hintGap
		widest = math.max(widest, hintWidth)
	end

	layout.width = math.Round(math.max(baseWidth, widest + layout.padL + layout.padR))
	layout.inner = layout.width - layout.padL - layout.padR

	-- Vertical stack.
	local y = layout.padT

	layout.headerY = y

	local textBlock = titleHeight + (caption and (capHeight + Sc(2)) or 0)

	layout.headerHeight = math.max(layout.glyph, textBlock)
	y = y + layout.headerHeight + Sc(10)
	layout.bandHeight = y

	local bAny = false

	local function Section(height, gap)
		y = y + (bAny and (gap or Sc(10)) or Sc(10))
		bAny = true

		local top = y

		y = y + height

		return top
	end

	if (#lines > 0) then
		layout.linesY = Section(#lines * layout.lineHeight)
	end

	if (#bars > 0) then
		layout.barHeight = Sc(24)
		layout.barsY = Section(#bars * layout.barHeight + (#bars - 1) * Sc(4))
	end

	if (#cells > 0) then
		local rows = math.ceil(#cells / layout.cellsPerRow)
		local monoHeight = select(2, TextWidth(layout.fontMono, "0"))

		layout.cellHeight = capHeight + monoHeight + Sc(4) + Sc(7) * 2
		layout.cellsY = Section(rows * layout.cellHeight + (rows - 1) * layout.cellGap)
		layout.cellWidth = math.floor((layout.inner - layout.cellGap * (layout.cellsPerRow - 1)) /
			layout.cellsPerRow)
	end

	if (bAny) then
		y = y + layout.padB
	end

	if (hints) then
		layout.hintHeight = Sc(18)
		layout.hintsY = y
		y = y + layout.hintHeight + Sc(8) * 2
	end

	layout.height = math.Round(y)

	self.layout = layout
	self.layoutData = data
	self.layoutScale = scaleKey

	return layout
end

-- Painting --------------------------------------------------------------------------------------

local function Ticks(x, y, width, height, size, color)
	surface.SetDrawColor(color.r, color.g, color.b, color.a)

	surface.DrawRect(x, y, size, 1)
	surface.DrawRect(x, y, 1, size)
	surface.DrawRect(x + width - size, y, size, 1)
	surface.DrawRect(x + width - 1, y, 1, size)
	surface.DrawRect(x, y + height - 1, size, 1)
	surface.DrawRect(x, y + height - size, 1, size)
	surface.DrawRect(x + width - size, y + height - 1, size, 1)
	surface.DrawRect(x + width - 1, y + height - size, 1, size)
end

local function Meter(x, y, width, height, fraction, color, alpha)
	local Sc = NETWORK.util.Scale
	local segments = 20
	local gap = math.max(Sc(2), 1)
	local segment = (width - gap * (segments - 1)) / segments
	local lit = fraction * segments

	for i = 0, segments - 1 do
		local sx = math.Round(x + i * (segment + gap))
		local sw = math.Round(x + (i + 1) * (segment + gap) - gap) - sx
		local fill = math.Clamp(lit - i, 0, 1)

		surface.SetDrawColor(255, 255, 255, 14 * alpha)
		surface.DrawRect(sx, y, sw, height)

		if (fill > 0) then
			surface.SetDrawColor(color.r, color.g, color.b, (70 + 170 * fill) * alpha)
			surface.DrawRect(sx, y, sw, height)
		end
	end
end

function PANEL:PaintContent(data, layout, x, y, alpha)
	local Sc = NETWORK.util.Scale
	local P = TipPalette()
	local color = data.color or P.accent
	local accent = data.accent or color
	local left = x + layout.padL
	local right = x + layout.width - layout.padR

	-- Header: icon tile, caption line, title.
	local headerY = y + layout.headerY
	local textX = left

	if (layout.icon) then
		local glyph = layout.glyph
		local iconSize = Sc(20)
		local tileY = headerY + math.Round((layout.headerHeight - glyph) * 0.5)
		local offset = math.Round((glyph - iconSize) * 0.5)

		surface.SetDrawColor(color.r, color.g, color.b, 26 * alpha)
		surface.DrawRect(left, tileY, glyph, glyph)
		surface.SetDrawColor(color.r, color.g, color.b, 70 * alpha)
		surface.DrawOutlinedRect(left, tileY, glyph, glyph, 1)
		Ticks(left - 1, tileY - 1, glyph + 2, glyph + 2, Sc(5),
			Color(color.r, color.g, color.b, 230 * alpha))

		surface.SetMaterial(layout.icon)
		surface.SetDrawColor(color.r, color.g, color.b, 245 * alpha)
		surface.DrawTexturedRect(left + offset, tileY + offset, iconSize, iconSize)

		textX = left + glyph + layout.glyphGap
	end

	local textBlock = layout.titleHeight + (layout.caption and (layout.capHeight + Sc(2)) or 0)
	local textY = headerY + math.Round((layout.headerHeight - textBlock) * 0.5)

	if (layout.caption) then
		draw.SimpleText(layout.caption, layout.fontCap, textX, textY,
			ColorAlpha(P.muted, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		if (layout.subtitle) then
			local capWidth = TextWidth(layout.fontCap, layout.caption)

			draw.SimpleText("·  " .. layout.subtitle, layout.fontCap, textX + capWidth + Sc(6), textY,
				ColorAlpha(accent, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		textY = textY + layout.capHeight + Sc(2)
	end

	draw.SimpleText(layout.title, layout.fontName, textX, textY,
		ColorAlpha(P.text, 252 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	-- Body text.
	if (layout.linesY) then
		local lineY = y + layout.linesY
		local lineHeight = layout.lineHeight
		local textColor = ColorAlpha(Color(196, 210, 222), 238 * alpha)

		for i = 1, #layout.lines do
			NETWORK.util.DrawStyledText(layout.lines[i], {"nwTipBody", "nwTipBodyBold", "nwTipBodyItalic"},
				left, lineY + math.Round(lineHeight * 0.5), textColor,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			lineY = lineY + lineHeight
		end
	end

	-- Meter bars.
	if (layout.barsY) then
		local barY = y + layout.barsY

		for _, bar in ipairs(layout.bars) do
			local barColor = bar.color or P.accent
			local fraction = math.Clamp(tonumber(bar.fraction) or 0, 0, 1)
			local label = NETWORK.util.Upper(bar.label or "")
			local labelWidth = TextWidth(layout.fontCap, label)

			draw.SimpleText(label, layout.fontCap, left, barY,
				ColorAlpha(P.muted, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			if (bar.text and bar.text != "") then
				draw.SimpleText(NETWORK.util.Upper(bar.text), layout.fontCap, left + labelWidth + Sc(8),
					barY, ColorAlpha(barColor, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			end

			draw.SimpleText(bar.value or (math.Round(fraction * 100) .. "%"), layout.fontCap, right,
				barY, ColorAlpha(barColor, 250 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

			Meter(left, barY + layout.capHeight + Sc(4), layout.inner, math.max(Sc(5), 3),
				fraction, barColor, alpha)

			barY = barY + layout.barHeight + Sc(4)
		end
	end

	-- Stat cells.
	if (layout.cellsY) then
		local perRow = layout.cellsPerRow

		for index, cell in ipairs(layout.cells) do
			local column = (index - 1) % perRow
			local row = math.floor((index - 1) / perRow)
			local cellX = left + column * (layout.cellWidth + layout.cellGap)
			local cellY = y + layout.cellsY + row * (layout.cellHeight + layout.cellGap)
			local cellWidth = (column == perRow - 1) and (right - cellX) or layout.cellWidth

			surface.SetDrawColor(P.deep.r, P.deep.g, P.deep.b, 210 * alpha)
			surface.DrawRect(cellX, cellY, cellWidth, layout.cellHeight)
			surface.SetDrawColor(P.line.r, P.line.g, P.line.b, 150 * alpha)
			surface.DrawOutlinedRect(cellX, cellY, cellWidth, layout.cellHeight, 1)

			local valueColor = cell.color or P.text

			surface.SetDrawColor(valueColor.r, valueColor.g, valueColor.b, 200 * alpha)
			surface.DrawRect(cellX, cellY, math.max(Sc(2), 2), layout.cellHeight)

			draw.SimpleText(cell.label, layout.fontCap, cellX + layout.cellPad, cellY + Sc(7),
				ColorAlpha(P.faint, 240 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(cell.value, layout.fontMono, cellX + layout.cellPad,
				cellY + Sc(7) + layout.capHeight + Sc(4),
				ColorAlpha(valueColor, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
	end

	-- Key hints strip.
	if (layout.hintsY) then
		local hintY = y + layout.hintsY + Sc(8)
		local hintX = left
		local keyHeight = layout.hintHeight
		local hintMid = hintY + math.Round(keyHeight * 0.5)

		for _, hint in ipairs(layout.hintItems) do
			surface.SetDrawColor(P.line.r, P.line.g, P.line.b, 90 * alpha)
			surface.DrawRect(hintX, hintY, hint.keyWidth, keyHeight)
			surface.SetDrawColor(P.muted.r, P.muted.g, P.muted.b, 120 * alpha)
			surface.DrawOutlinedRect(hintX, hintY, hint.keyWidth, keyHeight, 1)

			draw.SimpleText(hint.key, layout.fontKey, hintX + math.Round(hint.keyWidth * 0.5),
				hintMid, ColorAlpha(P.text, 240 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			hintX = hintX + hint.keyWidth + Sc(6)

			draw.SimpleText(hint.text, layout.fontCap, hintX, hintMid,
				ColorAlpha(P.muted, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			hintX = hintX + hint.textWidth + layout.hintGap
		end
	end
end

function PANEL:PaintPlate(data, layout, cardX, cardY, cardWidth, cardHeight, alpha)
	local Sc = NETWORK.util.Scale
	local P = TipPalette()
	local color = data.accent or data.color or P.accent

	surface.SetDrawColor(P.fill.r, P.fill.g, P.fill.b, 244 * alpha)
	surface.DrawRect(cardX, cardY, cardWidth, cardHeight)

	-- Header band with a fine scanline texture and an accent hairline under it.
	local band = math.min(layout.bandHeight, cardHeight)

	surface.SetDrawColor(P.band.r, P.band.g, P.band.b, 250 * alpha)
	surface.DrawRect(cardX, cardY, cardWidth, band)

	for lineY = cardY + 2, cardY + band - 2, math.max(Sc(3), 2) do
		surface.SetDrawColor(255, 255, 255, 5 * alpha)
		surface.DrawRect(cardX, lineY, cardWidth, 1)
	end

	if (band < cardHeight) then
		surface.SetDrawColor(color.r, color.g, color.b, 90 * alpha)
		surface.DrawRect(cardX, cardY + band, cardWidth, 1)
	end

	-- Hint strip at the bottom.
	if (layout.hintsY and layout.hintsY < cardHeight) then
		surface.SetDrawColor(P.deep.r, P.deep.g, P.deep.b, 250 * alpha)
		surface.DrawRect(cardX, cardY + layout.hintsY, cardWidth, cardHeight - layout.hintsY)
		surface.SetDrawColor(P.line.r, P.line.g, P.line.b, 140 * alpha)
		surface.DrawRect(cardX, cardY + layout.hintsY, cardWidth, 1)
	end

	surface.SetDrawColor(P.line.r, P.line.g, P.line.b, 210 * alpha)
	surface.DrawOutlinedRect(cardX, cardY, cardWidth, cardHeight, 1)

	-- Category stripe and corner ticks.
	surface.SetDrawColor(color.r, color.g, color.b, 240 * alpha)
	surface.DrawRect(cardX, cardY, layout.stripe, cardHeight)

	Ticks(cardX, cardY, cardWidth, cardHeight, Sc(8), Color(color.r, color.g, color.b, 210 * alpha))
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local S = NETWORK.style
	local data = self.data
	local progress = self.progress or 0

	if (!data or progress <= 0.001 or !S or !S.Unfold) then
		return
	end

	local layout = self:GetLayout(data)
	local boxWidth = layout.width
	local boxHeight = layout.height

	if (self.bOpen or !self.tipX) then
		local margin = Sc(8)
		local mouseX, mouseY = gui.MouseX(), gui.MouseY()
		local offset = Sc(math.Clamp(tipOffset:GetInt(), 0, 120))
		local side = Sc(math.Clamp(tipSide:GetInt(), 0, 200))
		local x = mouseX + side - Sc(16)
		local y = mouseY + offset
		local bAbove = false

		if (y + boxHeight > height - margin) then
			y = mouseY - Sc(10) - boxHeight
			bAbove = true
		end

		self.tipX = math.Round(math.Clamp(x, margin, math.max(width - boxWidth - margin, margin)))
		self.tipY = math.Round(math.Clamp(y, margin, math.max(height - boxHeight - margin, margin)))
		self.bAbove = bAbove
	end

	local x, y = self.tipX, self.tipY
	local widthPart, heightPart = S.Unfold(progress)

	local alpha = self.bOpen and math.Clamp(progress * 5, 0, 1) or
		math.Clamp(progress / 0.5, 0, 1)
	local outline = data.accent or data.color or TipPalette().accent
	local lineHeight = math.max(Sc(2), 2)
	local cardWidth = math.max(math.Round(boxWidth * widthPart), 2)
	local cardX = x
	local cardHeight = math.Round(boxHeight * heightPart)

	if (cardHeight < lineHeight * 3) then
		local lineY = self.bAbove and (y + boxHeight - lineHeight) or y

		surface.SetDrawColor(outline.r, outline.g, outline.b, 235 * alpha)
		surface.DrawRect(cardX, lineY, cardWidth, lineHeight)

		return
	end

	local cardY = self.bAbove and (y + boxHeight - cardHeight) or y

	if (S.Shadow) then
		S.Shadow(cardX, cardY, cardWidth, cardHeight, 0, alpha)
	end

	if (NETWORK.util.DrawBlurScreen) then
		NETWORK.util.DrawBlurScreen(cardX, cardY, cardWidth, cardHeight, 4 * alpha)
	end

	self:PaintPlate(data, layout, cardX, cardY, cardWidth, cardHeight, alpha)

	local textAlpha = math.Clamp((heightPart - 0.7) / 0.3, 0, 1) * alpha

	if (textAlpha <= 0.01) then
		return
	end

	S.PushClip(cardX, cardY, cardWidth, cardHeight)
	self:PaintContent(data, layout, x, y, textAlpha)
	S.PopClip()
end


vgui.Register("nwTooltip", PANEL, "EditablePanel")

function NETWORK.gui.tooltip.Ensure()
	if (!IsValid(NETWORK.gui.tooltip.panel)) then
		MigrateLayout()

		NETWORK.gui.tooltip.panel = vgui.Create("nwTooltip")
	end

	return NETWORK.gui.tooltip.panel
end

function NETWORK.gui.SetTooltip(owner, data)
	if (!data or IsValid(NETWORK.gui.itemMenu) or NETWORK.gui.drag) then
		return NETWORK.gui.ClearTooltip(owner)
	end

	NETWORK.gui.tooltip.owner = owner
	NETWORK.gui.tooltip.data = data

	NETWORK.gui.tooltip.Ensure()
end

function NETWORK.gui.ClearTooltip(owner)
	if (owner and NETWORK.gui.tooltip.owner != owner) then
		return
	end

	NETWORK.gui.tooltip.owner = nil
	NETWORK.gui.tooltip.data = nil
end

function NETWORK.gui.GetConditionText(item)

	local base = item and NETWORK.item.Get(item.id)
	local maxUses = item and (tonumber(item.maxUses) or (base and tonumber(base.maxUses)))
	local uses = item and tonumber(item.uses)

	if (!uses or !maxUses or maxUses <= 1) then
		return nil
	end

	local ratio = math.Clamp(uses / maxUses, 0, 1)

	if (ratio >= 0.9) then
		return L("invCondNew")
	elseif (ratio >= 0.5) then
		return L("invCondGood")
	elseif (ratio >= 0.2) then
		return L("invCondWorn")
	end

	return L("invCondBad")
end

function NETWORK.gui.ArmourInfo(item)
	local base = istable(item) and NETWORK.item.Get(item.id)
	local protection = base and tonumber(base.protection) or 0

	if (protection <= 0) then
		return nil
	end

	local maxUses = tonumber(base.maxUses)
	local condition

	if (maxUses and maxUses > 1) then
		condition = math.Clamp((tonumber(item.uses) or maxUses) / maxUses, 0, 1)
	end

	local effective = protection

	if (condition) then
		effective = protection * math.sqrt(condition) * (condition > 0 and 1 or 0)
	end

	return {
		base = protection,
		effective = effective,
		condition = condition,
		slot = base.equipSlot
	}
end

function NETWORK.gui.GetWornProtection(client, slot)
	local item = NETWORK.inventory.GetEquipped and NETWORK.inventory.GetEquipped(slot)
	local info = item and NETWORK.gui.ArmourInfo(item)
	local protection = info and info.effective or 0
	local innate = (NETWORK.toughness and NETWORK.toughness.GetInnateProtection and
		IsValid(client)) and (NETWORK.toughness.GetInnateProtection(client, slot) or 0) or 0

	return math.max(protection, innate), info
end

function NETWORK.gui.ConditionColor(ratio)
	local theme = NETWORK.theme

	if (ratio > 0.5) then
		return theme.positive
	elseif (ratio > 0.2) then
		return theme.warning
	end

	return theme.danger
end

function NETWORK.gui.FormatPercent(fraction)
	return math.Round(math.Clamp(fraction or 0, 0, 1) * 100) .. "%"
end

local function IsItemSlot(owner)
	return IsValid(owner) and (owner.ClassName == "nwItemSlot" or
		(isfunction(owner.GetSource) and isfunction(owner.SetSlotName)))
end

function NETWORK.gui.GetItemHints(owner, item)
	if (!item or !IsItemSlot(owner)) then
		return nil
	end

	local source = isfunction(owner.GetSource) and owner:GetSource() or {}
	local hints = {
		{key = L("invKeyLMB"), text = L("menuTake")},
		{key = L("invKeyRMB"), text = L("invHintMenu")}
	}

	local shift

	if (NETWORK.gui.IsSearchList and NETWORK.gui.IsSearchList(source.list)) then
		shift = owner.bSearchBound and "searchTake" or nil
	elseif (source.list == "storage") then
		shift = "searchTake"
	elseif (source.list == "equipped") then
		shift = "itemUnequip"
	elseif (NETWORK.inventory.GetContainer and NETWORK.inventory.GetContainer()) then
		shift = "invHintShift"
	elseif (NETWORK.item.GetEquipSlot and NETWORK.item.GetEquipSlot(item)) then
		shift = "itemEquip"
	end

	if (shift) then
		hints[#hints + 1] = {key = "Shift", text = L(shift)}
	end

	return hints
end

local CATEGORY_COLORS = {
	medical = "positive",
	weapon = "danger",
	contraband = "danger",
	ammo = "danger",
	service = "combine",
	key = "combine",
	documents = "combine",
	armour = "combineSoft",
	clothing = "combineSoft",
	food = "warning",
	rations = "warning",
	module = "combine",
	factory = "warning"
}

function NETWORK.gui.CategoryColor(category)
	local key = CATEGORY_COLORS[category]

	return key and NETWORK.theme[key] or (NETWORK.theme.pda and NETWORK.theme.pda.accent) or
		NETWORK.theme.text
end

function NETWORK.gui.CategoryCaption(category, base)
	if (base and base.bContraband) then
		return L("tipCatContraband")
	end

	local key = "tipCat_" .. tostring(category or "misc")
	local text = L(key)

	if (text == key or !text or text == "") then
		return L("tipCat_misc")
	end

	return text
end

function NETWORK.gui.SetItemTooltip(owner, item, fallback)
	if (!item) then
		if (!fallback) then
			return NETWORK.gui.ClearTooltip(owner)
		end

		return NETWORK.gui.SetTooltip(owner, {
			title = fallback,
			caption = L("tipCatSlot"),
			subtitle = L("invEmptySlot"),
			color = NETWORK.theme.inv.textFaint
		})
	end

	local rarity = NETWORK.inventory.GetRarity(NETWORK.item.GetRarity(item))

	local base = NETWORK.item.Get(item.uniqueID or item.id or "")
	local category = (base and base.category) or item.category or "misc"

	local color = NETWORK.gui.CategoryColor(category)

	if (base and base.bContraband) then
		color = NETWORK.theme.danger
	end

	local icons = {
		clothing = "masks",
		armour = "shield",
		container = "backpack",
		medical = "healing",
		food = "restaurant",
		rations = "restaurant",
		weapon = "warning",
		ammo = "military_tech",
		junk = "delete",
		documents = "assignment",
		module = "developer_board",
		factory = "factory",
		misc = "info"
	}

	local icon = "framework/icons/" .. (icons[category] or "info") .. ".png"

	local Sc = NETWORK.util.Scale
	local lines = {}
	local description = NETWORK.item.GetDescription(item)
	local name = NETWORK.item.GetName(item)
	local wrapWidth = Sc(BASE_WIDTH) - Sc(22) - Sc(16)

	if (description != "") then
		for _, line in ipairs(NETWORK.util.WrapText(description, "nwTipBody",
			wrapWidth, 8)) do
			lines[#lines + 1] = line
		end
	end

	local tag, id = NETWORK.item.GetTag(item)

	if (id != "drop") then
		lines[#lines + 1] = L(tag.name)
	end

	local bSpoils = NETWORK.spoil and base and NETWORK.spoil.CanSpoil(base)
	local freshness

	if (bSpoils) then
		local spoilStage = NETWORK.spoil.GetStage(item)

		freshness = {
			title = L("spoilTip"),
			label = L(NETWORK.spoil.GetLabel(item)),
			fraction = 1 - math.Clamp(NETWORK.spoil.Get(item) / 100, 0, 1),
			color = NETWORK.spoil.GetColor(spoilStage)
		}
	end

	local bars = {}
	local footer = {
		{label = L("invWeight"), value = string.format("%.0f",
			NETWORK.item.GetWeight(item) * 1000) .. " " .. L("invGrams")}
	}

	local armour = NETWORK.gui.ArmourInfo(item)
	local condition = NETWORK.gui.GetConditionText(item)

	if (armour) then
		local zone = armour.slot == "helmet" and "invProtectsHead" or "invProtectsBody"

		lines[#lines + 1] = L(zone)

		if (armour.condition and armour.condition <= 0) then
			lines[#lines + 1] = L("invArmourBroken")
		end

		local value = NETWORK.gui.FormatPercent(armour.effective)

		if (armour.effective < armour.base - 0.005) then
			value = value .. " / " .. NETWORK.gui.FormatPercent(armour.base)
		end

		footer[#footer + 1] = {label = L("invProtection"), value = value,
			color = NETWORK.theme.combine}

		if (armour.condition) then
			bars[#bars + 1] = {label = L("invCondition"), fraction = armour.condition,
				color = NETWORK.gui.ConditionColor(armour.condition)}
		end
	elseif (condition) then
		local maxUses = tonumber(item.maxUses) or (base and tonumber(base.maxUses)) or 1
		local ratio = math.Clamp((tonumber(item.uses) or maxUses) / maxUses, 0, 1)

		bars[#bars + 1] = {label = L("invCondition"), text = condition, fraction = ratio,
			color = NETWORK.gui.ConditionColor(ratio)}
	end

	if (base and isfunction(base.GetTooltipBars)) then
		for _, bar in ipairs(base:GetTooltipBars(item) or {}) do
			bars[#bars + 1] = bar
		end
	end

	if (base) then
		if (tonumber(base.hunger) and base.hunger > 0) then
			footer[#footer + 1] = {label = L("tipHunger"), value = "+" .. base.hunger,
				color = NETWORK.theme.warning}
		end

		if (tonumber(base.thirst) and base.thirst > 0) then
			footer[#footer + 1] = {label = L("tipThirst"), value = "+" .. base.thirst,
				color = NETWORK.theme.combineSoft}
		end

		if (tonumber(base.ammoAmount)) then
			footer[#footer + 1] = {label = L("tipRounds"), value = tostring(base.ammoAmount),
				color = NETWORK.theme.danger}
		end

		if (tonumber(base.storageSlots)) then
			footer[#footer + 1] = {label = L("tipSlots"), value = tostring(base.storageSlots)}
		end
	end

	if ((item.amount or 1) > 1) then
		footer[#footer + 1] = {label = L("invAmount"), value = tostring(item.amount)}
	end

	if (base and base.price and base.price > 0) then
		footer[#footer + 1] = {label = L("invPrice"), value = tostring(base.price)}
	end

	NETWORK.gui.SetTooltip(owner, {
		title = name,
		caption = NETWORK.gui.CategoryCaption(category, base),
		subtitle = rarity.id != "common" and L(rarity.name) or nil,
		color = color,

		accent = rarity.id != "common" and rarity.color or nil,
		icon = icon,
		lines = lines,
		bars = bars,
		footer = footer,
		freshness = freshness,
		hints = NETWORK.gui.GetItemHints(owner, item)
	})
end

hook.Add("OnReloaded", "nwTooltipReset", function()
	if (IsValid(NETWORK.gui.tooltip.panel)) then
		NETWORK.gui.tooltip.panel:Remove()
	end

	NETWORK.gui.tooltip.panel = nil
	NETWORK.gui.tooltip.data = nil
	NETWORK.gui.tooltip.owner = nil
end)
