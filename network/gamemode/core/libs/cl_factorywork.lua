local WORK = NETWORK.factorywork

local GOOD = Color(108, 220, 150)
local WARN = Color(232, 190, 96)

local function Palette(panel)
	return NETWORK.cmbterm.GetPalette(panel.entity)
end

local function Kind(entity)
	return IsValid(entity) and entity:GetClass() == "nw_cwuterminal" and "cwu" or "alliance"
end

local function Box(palette, x, y, width, height, color, fill, border, radius)
	radius = math.min(radius or NETWORK.style.Radius("card"), math.floor(math.min(width, height) * 0.5))

	draw.RoundedBox(radius, x, y, width, height, ColorAlpha(color, fill))

	if (border > 0) then
		NETWORK.util.DrawRoundedBorder(x, y, width, height, radius, 1, ColorAlpha(color, border))
	end
end

local function Bar(x, y, width, fraction, color, alpha)
	local height = math.max(NETWORK.util.Scale(4), 3)
	local radius = math.floor(height * 0.5)

	draw.RoundedBox(radius, x, y, width, height, ColorAlpha(color, 34 * alpha))
	draw.RoundedBox(radius, x, y, math.max(math.Round(width * math.Clamp(fraction, 0, 1)), height),
		height, ColorAlpha(color, 240 * alpha))
end

local function Text(text, font, x, y, color, alignX)
	draw.SimpleText(text, font, x, y, color, alignX or TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

local function PaintWorker(entry, x, y, width, height, palette, alpha)
	local Sc = NETWORK.util.Scale
	local nu = NETWORK.util
	local accent = palette.accent
	local bActive = entry.bOnline and entry.bWorker

	local stateColor, stateKey

	if (!entry.bOnline) then
		stateColor, stateKey = palette.dim, "factoryStateOffline"
	elseif (!entry.bWorker) then
		stateColor, stateKey = palette.dim, "factoryStateOffDuty"
	elseif (entry.bDone) then
		stateColor, stateKey = GOOD, "factoryStateDone"
	else
		stateColor, stateKey = accent, "factoryStateWorking"
	end

	Box(palette, x, y, width, height, accent, (bActive and 16 or 7) * alpha,
		(bActive and 120 or 50) * alpha, NETWORK.style.Radius("panel"))

	local pad = Sc(14)
	local inner = width - pad * 2

	Text(nu.TruncateWidth(entry.name, "nwTermBody", inner - Sc(120)), "nwTermBody",
		x + pad, y + Sc(18), ColorAlpha(palette.text, 250 * alpha))

	Text("#" .. (entry.cid != "" and entry.cid or "-----"), "nwHudSmall", x + pad,
		y + Sc(38), ColorAlpha(palette.dim, 235 * alpha))

	NETWORK.style.Chip(nu.Upper(L(stateKey)), "nwHudSmall", x + width - pad, y + Sc(10),
		stateColor, alpha, {alignRight = true})

	local numbersY = y + Sc(70)
	local half = math.floor(inner * 0.5)

	Text(nu.Upper(L("factoryMade")), "nwHudSmall", x + pad, numbersY - Sc(8),
		ColorAlpha(palette.dim, 235 * alpha))
	Text(tostring(entry.shiftMade), "nwTermTitle", x + pad, numbersY + Sc(16),
		ColorAlpha(palette.text, 250 * alpha))

	Text(nu.Upper(L("factoryDelivered")), "nwHudSmall", x + pad + half, numbersY - Sc(8),
		ColorAlpha(palette.dim, 235 * alpha))
	Text(tostring(entry.shiftDelivered), "nwTermTitle", x + pad + half, numbersY + Sc(16),
		ColorAlpha(palette.text, 250 * alpha))

	local quotaY = y + Sc(112)

	Text(nu.Upper(L("factoryQuotaState", entry.quotas, WORK.quotas)), "nwHudSmall",
		x + pad, quotaY, ColorAlpha(entry.bDone and GOOD or palette.dim, 240 * alpha))

	Text(entry.bDone and nu.Upper(L("factoryQuotaPassed")) or
		nu.Upper(L("factoryQuotaPending")), "nwHudSmall", x + width - pad, quotaY,
		ColorAlpha(entry.bDone and GOOD or WARN, 240 * alpha), TEXT_ALIGN_RIGHT)

	local gap = Sc(6)
	local segment = math.floor((inner - gap * (WORK.quotas - 1)) / WORK.quotas)

	for index = 1, WORK.quotas do
		local bFilled = index <= entry.quotas
		local color = bFilled and GOOD or accent

		Box(palette, x + pad + (index - 1) * (segment + gap), quotaY + Sc(12), segment,
			Sc(10), color, (bFilled and 200 or 26) * alpha, 0, Sc(5))
	end

	local boxY = y + Sc(150)
	local boxCount = entry.bDone and WORK.boxSize or entry.box

	Text(nu.Upper(L("factoryBoxState", boxCount, WORK.boxSize)), "nwHudSmall", x + pad,
		boxY, ColorAlpha(palette.dim, 235 * alpha))

	local cell = Sc(14)
	local cellGap = Sc(5)
	local cellsX = x + width - pad - (WORK.boxSize * cell + (WORK.boxSize - 1) * cellGap)

	for index = 1, WORK.boxSize do
		local bFilled = index <= boxCount

		Box(palette, cellsX + (index - 1) * (cell + cellGap), boxY - math.Round(cell * 0.5),
			cell, cell, bFilled and accent or palette.dim, (bFilled and 210 or 30) * alpha,
			(bFilled and 0 or 90) * alpha, NETWORK.style.Radius("chip"))
	end

	Bar(x + pad, y + height - Sc(32), inner, WORK.GetProgress(entry),
		entry.bDone and GOOD or accent, alpha)

	Text(L("factoryTotalsV2", entry.made, entry.delivered, entry.shifts, entry.earned or 0),
		"nwHudSmall", x + pad, y + height - Sc(14), ColorAlpha(palette.dim, 225 * alpha))
end

NETWORK.cmbterm.RegisterExtension("factory", {
	name = "cmbNavFactory",
	glyph = "stack",
	caption = "cmbTileFactory",
	access = function(client, entity)
		if (Kind(entity) == "cwu") then
			return NETWORK.factions.IsCWU(client) or NETWORK.factions.IsAlliance(client) or
				client:IsAdmin()
		end

		return NETWORK.factions.IsAlliance(client)
	end,
	Build = function(panel, x, y, width, bottom)
	end,
	Paint = function(panel, x, y, width, bottom, alpha)
		local Sc = NETWORK.util.Scale
		local nu = NETWORK.util
		local data = panel:GetData()
		local palette = Palette(panel)
		local summary = data.summary or {}
		local list = data.list or {}

		local closedText = data.bOpen == false and nu.Upper(L("factoryPlantClosed")) or
			nu.Upper(L("factoryPlantOpen"))

		NETWORK.style.Chip(closedText, "nwHudSmall", x, y - Sc(4),
			data.bOpen == false and WARN or GOOD, alpha)

		Text(L("factorySummary", summary.working or 0, summary.closed or 0,
			summary.made or 0, summary.delivered or 0, summary.quotas or 0), "nwHudSmall",
			x + width, y + Sc(4), ColorAlpha(palette.text, 230 * alpha), TEXT_ALIGN_RIGHT)

		local top = y + Sc(24)

		if (#list == 0) then
			Text(L("factoryNoWorkers"), "nwTermBody", x, top + Sc(20),
				ColorAlpha(palette.dim, 230 * alpha))

			return
		end

		local columns = width >= Sc(1100) and 4 or (width >= Sc(760) and 3 or 2)
		local gap = Sc(12)
		local cardWidth = math.floor((width - gap * (columns - 1)) / columns)
		local cardHeight = Sc(206)
		local shown = 0

		for index, entry in ipairs(list) do
			local column = (index - 1) % columns
			local row = math.floor((index - 1) / columns)
			local cardY = top + row * (cardHeight + gap)

			if (cardY + cardHeight > bottom) then
				break
			end

			PaintWorker(entry, x + column * (cardWidth + gap), cardY, cardWidth, cardHeight,
				palette, alpha)

			shown = shown + 1
		end

		local hidden = (data.total or #list) - shown

		if (hidden > 0) then
			Text(L("factoryMoreWorkers", hidden), "nwHudSmall", x + width, bottom + Sc(10),
				ColorAlpha(palette.dim, 225 * alpha), TEXT_ALIGN_RIGHT)
		end
	end
})
