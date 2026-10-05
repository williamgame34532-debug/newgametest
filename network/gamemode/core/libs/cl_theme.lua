NETWORK.theme = NETWORK.theme or {}

NETWORK.theme.background = Color(6, 7, 8)
NETWORK.theme.plate = Color(13, 14, 16)
NETWORK.theme.plateBright = Color(21, 23, 25)
NETWORK.theme.plateDeep = Color(9, 10, 11)
NETWORK.theme.accent = Color(178, 184, 190)
NETWORK.theme.accentDeep = Color(88, 93, 99)
NETWORK.theme.accentSoft = Color(226, 230, 234)
NETWORK.theme.text = Color(232, 232, 230)
NETWORK.theme.textDim = Color(158, 160, 162)
NETWORK.theme.textFaint = Color(104, 106, 110)
NETWORK.theme.line = Color(74, 78, 83)
NETWORK.theme.value = Color(206, 210, 214)

NETWORK.theme.hover = Color(228, 176, 104)

NETWORK.theme.combine = Color(86, 150, 226)
NETWORK.theme.combineDeep = Color(40, 78, 128)
NETWORK.theme.combineSoft = Color(150, 196, 246)

NETWORK.theme.danger = Color(232, 84, 76)
NETWORK.theme.warning = Color(240, 186, 74)
NETWORK.theme.positive = Color(96, 224, 140)

-- PDA palette (navy plates, hairlines, uppercase captions): shared by the PDA, tooltips, the
-- inventory, the main menu and the character screens.
NETWORK.theme.pda = {
	bg = Color(10, 22, 36),
	bg2 = Color(15, 31, 49),
	deep = Color(7, 15, 25),
	line = Color(44, 70, 96),
	lineSoft = Color(27, 45, 64),
	text = Color(228, 238, 246),
	muted = Color(122, 146, 168),
	faint = Color(84, 106, 128),
	accent = Color(104, 170, 228),
	good = Color(110, 200, 150),
	warn = Color(232, 176, 86),
	bad = Color(230, 92, 84)
}

-- Инвентарь в стиле Escape from Tarkov: угольно-серые плиты, тонкие рамки,
-- светлая активная вкладка, штриховка пустых клеток.
NETWORK.theme.inv = {
	background = Color(11, 12, 13),
	panel = Color(19, 20, 21),
	panelBright = Color(31, 33, 34),
	cell = Color(24, 25, 26),
	cellTop = Color(14, 15, 16),
	cellBright = Color(44, 46, 47),
	line = Color(66, 69, 71),
	lineSoft = Color(40, 42, 44),
	accent = Color(196, 198, 188),
	accentDeep = Color(92, 95, 96),
	accentSoft = Color(224, 222, 210),
	text = Color(222, 220, 208),
	textDim = Color(150, 150, 140),
	textFaint = Color(104, 105, 100),
	select = Color(232, 228, 196),
	positive = Color(132, 186, 76),
	warning = Color(226, 178, 74),
	danger = Color(196, 58, 50)
}

NETWORK.theme.tk = {
	bg = Color(11, 12, 13),
	plate = Color(19, 20, 21),
	plateLight = Color(31, 33, 34),
	header = Color(42, 44, 45),
	line = Color(66, 69, 71),
	lineSoft = Color(40, 42, 44),
	hatch = Color(255, 255, 255, 9),
	text = Color(222, 220, 208),
	textDim = Color(150, 150, 140),
	textFaint = Color(104, 105, 100),
	active = Color(212, 212, 200),
	activeText = Color(16, 17, 18),
	good = Color(132, 186, 76),
	water = Color(88, 156, 214),
	energy = Color(226, 196, 86),
	bad = Color(176, 44, 38)
}

NETWORK.tk = NETWORK.tk or {}

local TK = NETWORK.tk

-- Диагональная штриховка, обрезанная по прямоугольнику (как в пустых клетках Tarkov).
function TK.Hatch(x, y, width, height, color, step)
	step = math.max(step or math.Round(NETWORK.util.Scale(7)), 3)

	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)

	local right = x + width
	local bottom = y + height

	for offset = -height, width, step do
		local startX, startY = x + offset, bottom
		local endX, endY = x + offset + height, y

		if (startX < x) then
			startY = startY - (x - startX)
			startX = x
		end

		if (endX > right) then
			endY = endY + (endX - right)
			endX = right
		end

		if (startX < endX) then
			surface.DrawLine(startX, startY, endX, endY)
		end
	end
end

-- Плита с тонкой рамкой.
function TK.Frame(x, y, width, height, alpha, fill, line)
	local palette = NETWORK.theme.tk

	fill = fill or palette.plate
	line = line or palette.line

	surface.SetDrawColor(fill.r, fill.g, fill.b, (fill.a or 235) * alpha)
	surface.DrawRect(x, y, width, height)
	surface.SetDrawColor(line.r, line.g, line.b, (line.a or 255) * alpha)
	surface.DrawOutlinedRect(x, y, width, height, 1)
end

-- Заголовок секции: плашка со скошенным правым краем и линия до конца ширины
-- («УШИ», «ГОЛОВА», «КАРМАНЫ» на скриншоте).
function TK.Header(x, y, width, height, caption, alpha, badgeText, badgeColor)
	local Sc = NETWORK.util.Scale
	local palette = NETWORK.theme.tk

	surface.SetFont("nwTkHeader")

	local textWidth = surface.GetTextSize(caption)
	local pad = Sc(8)
	local plateWidth = math.min(textWidth + pad * 2, width - height)
	local slant = math.Round(height * 0.75)

	draw.NoTexture()
	surface.SetDrawColor(palette.header.r, palette.header.g, palette.header.b, 240 * alpha)
	surface.DrawPoly({
		{x = x, y = y},
		{x = x + plateWidth, y = y},
		{x = x + plateWidth + slant, y = y + height},
		{x = x, y = y + height}
	})

	surface.SetDrawColor(palette.line.r, palette.line.g, palette.line.b, 200 * alpha)
	surface.DrawRect(x + plateWidth + slant, y + height - 1,
		math.max(width - plateWidth - slant, 0), 1)

	draw.SimpleText(caption, "nwTkHeader", x + pad, y + math.Round(height * 0.5),
		ColorAlpha(palette.text, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (badgeText) then
		draw.SimpleText(badgeText, "nwInvSub", x + width - Sc(2), y + math.Round(height * 0.5) - 1,
			ColorAlpha(badgeColor or palette.textDim, 245 * alpha), TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)
	end
end

TK.brandIcon = "logos/n-logo.png"
TK.brandText = "Network: HL-A Roleplay"

-- Подпись проекта справа снизу: иконка logos/n-logo.png + «Network: HL-A Roleplay».
function TK.GetBrandSize()
	local Sc = NETWORK.util.Scale

	surface.SetFont("nwTkBrand")

	local textWidth, textHeight = surface.GetTextSize(TK.brandText)
	local icon = math.Round(textHeight * 1.35)

	return icon + Sc(8) + textWidth, math.max(icon, textHeight)
end

function TK.DrawBrand(right, bottom, alpha)
	local Sc = NETWORK.util.Scale
	local width, height = TK.GetBrandSize()
	local x = right - width
	local y = bottom - height
	local icon = math.Round(height)
	local material = NETWORK.util.GetMaterial(TK.brandIcon, "smooth")
	local textX = x

	if (material and !material:IsError()) then
		surface.SetMaterial(material)
		surface.SetDrawColor(0, 0, 0, 140 * alpha)
		surface.DrawTexturedRect(x + 1, y + 2, icon, icon)
		surface.SetDrawColor(255, 255, 255, 240 * alpha)
		surface.DrawTexturedRect(x, y, icon, icon)
		draw.NoTexture()

		textX = x + icon + Sc(8)
	else
		textX = right - (width - icon - Sc(8))
	end

	draw.SimpleText(TK.brandText, "nwTkBrand", textX + 1, y + math.Round(height * 0.5) + 1,
		Color(0, 0, 0, 160 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(TK.brandText, "nwTkBrand", textX, y + math.Round(height * 0.5),
		Color(232, 230, 220, 240 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	return width, height
end

NETWORK.theme.inv.plate = NETWORK.theme.inv.panel
NETWORK.theme.inv.plateBright = NETWORK.theme.inv.panelBright
NETWORK.theme.inv.plateDeep = NETWORK.theme.inv.background
NETWORK.theme.inv.value = NETWORK.theme.inv.accent

NETWORK.theme.create = {
	background = Color(13, 14, 15),
	backdrop = Color(24, 26, 28),
	panel = Color(22, 24, 26),
	cell = Color(19, 20, 22),
	cellBright = Color(32, 35, 38),
	line = Color(74, 78, 83),
	lineSoft = Color(44, 47, 50),
	text = Color(232, 232, 230),
	textDim = Color(158, 160, 162),
	textFaint = Color(104, 106, 110),
	title = Color(214, 218, 222),
	select = Color(226, 230, 234),
	button = Color(18, 19, 21),
	error = Color(232, 84, 76),
	ok = Color(96, 224, 140)
}
