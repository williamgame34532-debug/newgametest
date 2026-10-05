local PANEL = {}

local pages = {
	{id = "work", label = "workTermShift"},
	{id = "totals", label = "workTermTotals"},
	{id = "exit", label = "termExit"}
}

local function Theme()
	return NETWORK.terminal.palette
end

function PANEL:Init()

	if (!self.navItems) then
		self.BaseClass.Init(self)
	end

	self.brandKey = "workTermBrand"
	self.subtitleKey = "workTermSubtitle"
	self.emblem = "W"
	self.navGlyphs = {work = "gear", totals = "list", exit = "back"}

	self:BuildNav()
	self:OpenPage("work")
end

function PANEL:GetNavPages()
	return pages
end

function PANEL:Setup(entity, data)
	self.entity = entity
	self.data = data or {}

	self:OpenPage(self.page == "root" and "work" or self.page)
end

function PANEL:GetWork()
	return self.data and self.data.work or {}
end

function PANEL:GetWorkLayout()
	local Sc = NETWORK.util.Scale
	local x = self:GetContentX() + Sc(34)
	local width = self:GetContentWidth() - Sc(68)
	local top = self:GetPageTop()
	local bottom = self:GetPageBottom()

	return {
		x = x,
		width = width,
		top = top,
		status = top + Sc(6),
		steps = top + Sc(112),
		quotas = top + Sc(238),
		tiles = top + Sc(318),
		bottom = bottom
	}
end

function PANEL:BuildWork()
end

function PANEL:BuildTotals()
end

local function Card(x, y, width, height, color, alpha, strength, radius)
	radius = radius or NETWORK.style.Radius("card")
	strength = strength or 0

	draw.RoundedBox(radius, x, y, width, height, ColorAlpha(color, (12 + 22 * strength) * alpha))
	NETWORK.util.DrawRoundedBorder(x, y, width, height, radius, 1,
		ColorAlpha(color, (50 + 130 * strength) * alpha))
end

local function Bar(x, y, width, fraction, color, alpha)
	local Sc = NETWORK.util.Scale
	local height = math.max(Sc(4), 3)
	local radius = math.floor(height * 0.5)

	draw.RoundedBox(radius, x, y, width, height, ColorAlpha(color, 34 * alpha))
	draw.RoundedBox(radius, x, y, math.max(math.Round(width * math.Clamp(fraction, 0, 1)), height),
		height, ColorAlpha(color, 240 * alpha))
end

local function Tile(x, y, width, height, label, value, color, alpha)
	local Sc = NETWORK.util.Scale
	local theme = Theme()

	Card(x, y, width, height, theme.accent, alpha, 0)

	draw.SimpleText(NETWORK.util.Upper(label), "nwInvKey", x + Sc(16), y + Sc(20),
		ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(tostring(value), "nwTermTitle", x + Sc(16),
		y + math.Round(height * 0.5) + Sc(10), ColorAlpha(color or theme.value, 250 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

local function Tiles(x, y, width, height, entries, alpha)
	local Sc = NETWORK.util.Scale
	local gap = Sc(12)
	local count = #entries
	local tileWidth = math.floor((width - gap * (count - 1)) / count)

	for index, entry in ipairs(entries) do
		Tile(x + (index - 1) * (tileWidth + gap), y, tileWidth, height, entry[1], entry[2],
			entry[3], alpha)
	end
end

local wrapCache = {}

local function Wrapped(text, font, width, lines)
	local key = text .. "\0" .. font .. "\0" .. width

	if (!wrapCache[key]) then
		wrapCache[key] = NETWORK.util.WrapText(text, font, width, lines)
	end

	return wrapCache[key]
end

function PANEL:PaintSteps(x, y, width, height, work, alpha)
	local Sc = NETWORK.util.Scale
	local theme = Theme()
	local WORK = NETWORK.factorywork
	local count = #WORK.steps
	local gap = Sc(12)
	local arrow = Sc(14)
	local cardWidth = math.floor((width - (gap * 2 + arrow) * (count - 1)) / count)

	draw.SimpleText(NETWORK.util.Upper(L("workTermHowTo")), "nwInvKey", x, y - Sc(12),
		ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	for index, entry in ipairs(WORK.steps) do
		local cardX = x + (index - 1) * (cardWidth + gap * 2 + arrow)
		local color = work.bDone and theme.positive or theme.accent

		Card(cardX, y, cardWidth, height, color, alpha, 0.15)

		local circle = Sc(26)
		local circleX = cardX + Sc(12) + math.floor(circle * 0.5)
		local circleY = y + Sc(10) + math.floor(circle * 0.5)

		NETWORK.util.DrawCircle(circleX, circleY, math.floor(circle * 0.5),
			ColorAlpha(color, 60 * alpha))

		draw.SimpleText(tostring(index), "nwInvKey", circleX, circleY,
			ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText(NETWORK.util.Upper(L(entry.short)), "nwTermNav",
			circleX + math.floor(circle * 0.5) + Sc(10), circleY,
			ColorAlpha(theme.text, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local lines = Wrapped(L(entry.text), "nwTermCaption", cardWidth - Sc(24), 3)

		for line, text in ipairs(lines) do
			draw.SimpleText(text, "nwTermCaption", cardX + Sc(12),
				y + Sc(44) + (line - 1) * Sc(17), ColorAlpha(theme.textDim, 235 * alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		if (index < count) then
			draw.SimpleText("›", "nwTermTitle", cardX + cardWidth + gap + math.floor(arrow * 0.5),
				y + math.Round(height * 0.5), ColorAlpha(theme.textFaint, 230 * alpha),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

function PANEL:PaintWorkPage(alpha)
	local Sc = NETWORK.util.Scale
	local S = NETWORK.style
	local theme = Theme()
	local work = self:GetWork()
	local layout = self:GetWorkLayout()
	local WORK = NETWORK.factorywork
	local x, width = layout.x, layout.width

	self:PaintHeader(L("workTermShift"), alpha)

	if (!work.bWorker) then
		Card(x, layout.status, width, Sc(84), theme.danger, alpha, 0.4)

		draw.SimpleText(NETWORK.util.Upper(L("workTermNotWorker")), "nwTermTitle",
			x + math.Round(width * 0.5), layout.status + Sc(30),
			ColorAlpha(theme.danger, 245 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText(L("workTermNotWorkerHint"), "nwTermCaption",
			x + math.Round(width * 0.5), layout.status + Sc(60),
			ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		self:PaintSteps(x, layout.status + Sc(130), width, Sc(104), work, alpha)

		return
	end

	local pad = Sc(22)
	local statusHeight = Sc(90)
	local stateColor = work.bDone and theme.positive or
		(work.bOpen == false and theme.warning or theme.accent)
	local stateKey = work.bDone and "workStateDone" or
		(work.bOpen == false and "factoryPlantClosed" or "workStateActive")

	Card(x, layout.status, width, statusHeight, stateColor, alpha, 0.45, S.Radius("panel"))

	S.Chip(NETWORK.util.Upper(L(stateKey)), "nwInvKey", x + pad, layout.status + Sc(14),
		stateColor, alpha)

	local hint

	if (work.bDone) then
		hint = L("workTermDoneHintV2")
	elseif (work.bOpen == false) then
		hint = L("workTermClosedHint")
	else
		hint = L("workTermActiveHint", WORK.boxSize)
	end

	draw.SimpleText(hint, "nwTermBody", x + pad, layout.status + Sc(50),
		ColorAlpha(theme.text, 240 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local fraction = WORK.GetProgress({bDone = work.bDone, quotas = work.quotas, box = work.box})

	draw.SimpleText(math.Round(fraction * 100) .. "%", "nwTermTitle", x + width - pad,
		layout.status + Sc(34), ColorAlpha(theme.value, 250 * alpha),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	Bar(x + pad, layout.status + statusHeight - Sc(16), width - pad * 2, fraction, stateColor, alpha)

	self:PaintSteps(x, layout.steps, width, Sc(104), work, alpha)

	local half = math.floor((width - Sc(24)) * 0.5)
	local rowY = layout.quotas
	local segmentHeight = Sc(40)
	local quotas = work.quotas or 0
	local boxCount = work.bDone and WORK.boxSize or (work.box or 0)

	draw.SimpleText(NETWORK.util.Upper(L("workTermQuotas", quotas, WORK.quotas)), "nwInvKey",
		x, rowY, ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local gap = Sc(8)
	local segmentWidth = math.floor((half - gap * (WORK.quotas - 1)) / WORK.quotas)

	for index = 1, WORK.quotas do
		local segmentX = x + (index - 1) * (segmentWidth + gap)
		local bFilled = index <= quotas
		local bCurrent = !work.bDone and index == quotas + 1

		Card(segmentX, rowY + Sc(14), segmentWidth, segmentHeight,
			bFilled and theme.positive or theme.accent, alpha,
			bFilled and 1 or (bCurrent and 0.45 or 0), S.Radius("cell"))

		draw.SimpleText(L("workTermQuotaN", index), "nwTermNav",
			segmentX + math.Round(segmentWidth * 0.5), rowY + Sc(14) + math.Round(segmentHeight * 0.5),
			ColorAlpha(bFilled and theme.text or (bCurrent and theme.value or theme.textFaint),
			245 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local boxX = x + half + Sc(24)

	draw.SimpleText(NETWORK.util.Upper(L("workTermBox", boxCount, WORK.boxSize)), "nwInvKey",
		boxX, rowY, ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local cellWidth = math.floor((half - gap * (WORK.boxSize - 1)) / WORK.boxSize)

	for index = 1, WORK.boxSize do
		local cellX = boxX + (index - 1) * (cellWidth + gap)
		local bFilled = index <= boxCount

		Card(cellX, rowY + Sc(14), cellWidth, segmentHeight,
			bFilled and theme.positive or theme.accent, alpha, bFilled and 1 or 0, S.Radius("cell"))

		if (bFilled) then
			local glyph = Sc(18)

			NETWORK.gui.DrawGlyph("stack", cellX + math.floor((cellWidth - glyph) * 0.5),
				rowY + Sc(14) + math.floor((segmentHeight - glyph) * 0.5), glyph,
				ColorAlpha(theme.text, 240 * alpha))
		end
	end

	local left = work.bDone and 0 or
		(WORK.boxSize * WORK.quotas - quotas * WORK.boxSize - (work.box or 0))

	Tiles(x, layout.tiles, width, Sc(84), {
		{L("workTermShiftMade"), work.shiftMade or 0},
		{L("workTermShiftDelivered"), work.shiftDelivered or 0},
		{L("workTermShiftLeft"), left, theme.warning},
		{L("workTermShiftEarned"), L("workTermEarnedValue", work.shiftEarned or 0,
			work.shiftPoints or 0), theme.positive}
	}, alpha)

	if (work.bDone) then
		local noteY = layout.tiles + Sc(100)
		local noteHeight = Sc(46)

		if (noteY + noteHeight <= layout.bottom) then
			Card(x, noteY, width, noteHeight, theme.positive, alpha, 0.5,
				math.floor(noteHeight * 0.5))

			draw.SimpleText(L("workTermRecruiter"), "nwTermNav", x + math.Round(width * 0.5),
				noteY + math.Round(noteHeight * 0.5), ColorAlpha(theme.text, 245 * alpha),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

function PANEL:PaintTotalsPage(alpha)
	local Sc = NETWORK.util.Scale
	local theme = Theme()
	local work = self:GetWork()
	local top = self:PaintHeader(L("workTermTotals"), alpha)
	local x = self:GetContentX() + Sc(34)
	local width = self:GetContentWidth() - Sc(68)

	Tiles(x, top + Sc(10), width, Sc(100), {
		{L("workTermTotalMade"), work.made or 0},
		{L("workTermTotalDelivered"), work.delivered or 0},
		{L("workTermTotalShifts"), work.shifts or 0, theme.positive},
		{L("workTermTotalEarned"), work.earned or 0, theme.positive}
	}, alpha)

	local y = top + Sc(136)
	local cardHeight = Sc(64)

	for index, key in ipairs({"workTermRule1", "workTermRule2", "workTermRule3V2"}) do
		local lines = Wrapped(L(key, NETWORK.factorywork.boxSize, NETWORK.factorywork.quotas),
			"nwTermBody", width - Sc(80), 2)

		Card(x, y, width, cardHeight, theme.accent, alpha, 0.1)

		NETWORK.util.DrawCircle(x + Sc(30), y + math.Round(cardHeight * 0.5), Sc(13),
			ColorAlpha(theme.accent, 60 * alpha))

		draw.SimpleText(tostring(index), "nwInvKey", x + Sc(30), y + math.Round(cardHeight * 0.5),
			ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local textY = y + math.Round((cardHeight - #lines * Sc(24)) * 0.5)

		for line, text in ipairs(lines) do
			draw.SimpleText(text, "nwTermBody", x + Sc(58), textY + (line - 1) * Sc(24),
				ColorAlpha(theme.text, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		y = y + cardHeight + Sc(10)
	end
end

vgui.Register("nwWorkTerminalMenu", PANEL, "nwTerminalMenu")

NETWORK.terminal.panels = NETWORK.terminal.panels or {}
NETWORK.terminal.panels.nw_workterminal = "nwWorkTerminalMenu"
