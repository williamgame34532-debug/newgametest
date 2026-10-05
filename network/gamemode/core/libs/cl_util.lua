NETWORK.util = NETWORK.util or {}

local materialCache = {}
local charCache = {}
local spacedCache = {}

local uiScale = CreateClientConVar("network_uiscale", "1", true, false,
	"Множитель размера интерфейса")

local scaleFactor

local function GetFactor()
	if (scaleFactor) then
		return scaleFactor
	end

	local factor = ScrH() / 1080

	local ratio = ScrW() / ScrH()

	if (ratio < 1.7) then
		factor = factor * math.max(ratio / 1.7, 0.78)
	end

	factor = math.Clamp(factor, 0.82, 1.75) *
		math.Clamp(uiScale:GetFloat(), 0.75, 1.35)

	scaleFactor = factor

	return factor
end

function NETWORK.util.Scale(value)
	return math.Round(value * GetFactor())
end

function NETWORK.util.ScaleF(value)
	return value * GetFactor()
end

cvars.AddChangeCallback("network_uiscale", function()
	scaleFactor = nil

	timer.Simple(0, function()
		RunConsoleCommand("network_reloadfonts")
	end)
end, "nwUIScale")

hook.Add("OnScreenSizeChanged", "nwUIScale", function()
	scaleFactor = nil
end)

local errorMaterial

function NETWORK.util.GetMaterial(path, parameters)

	if (!isstring(path) or path == "") then
		errorMaterial = errorMaterial or Material("error")

		return errorMaterial
	end

	materialCache[path] = materialCache[path] or Material(path, parameters)

	return materialCache[path]
end

local function GetCharWidth(font, char)
	local fontCache = charCache[font]

	if (!fontCache) then
		fontCache = {}
		charCache[font] = fontCache
	end

	local width = fontCache[char]

	if (!width) then
		surface.SetFont(font)

		width = surface.GetTextSize(char)
		fontCache[char] = width
	end

	return width
end

function NETWORK.util.TextSpacedSize(text, font, spacing)
	local key = font .. "|" .. spacing .. "|" .. text
	local cached = spacedCache[key]

	if (cached) then
		return cached[1], cached[2]
	end

	surface.SetFont(font)

	local _, height = surface.GetTextSize("A")
	local width = 0

	for _, code in utf8.codes(text) do
		width = width + GetCharWidth(font, utf8.char(code)) + spacing
	end

	width = math.max(width - spacing, 0)
	spacedCache[key] = {width, height}

	return width, height
end

function NETWORK.util.DrawTextSpaced(text, font, x, y, color, spacing, alignY)
	surface.SetFont(font)
	surface.SetTextColor(color.r, color.g, color.b, color.a or 255)

	local _, height = surface.GetTextSize("A")
	local drawY = y

	if (alignY == TEXT_ALIGN_CENTER) then
		drawY = y - height * 0.5
	elseif (alignY == TEXT_ALIGN_BOTTOM) then
		drawY = y - height
	end

	drawY = math.Round(drawY)

	local cursor = x

	local bOk = pcall(function()
		for _, code in utf8.codes(text) do
			local char = utf8.char(code)

			surface.SetTextPos(math.Round(cursor), drawY)
			surface.DrawText(char)

			cursor = cursor + GetCharWidth(font, char) + spacing
		end
	end)

	if (!bOk) then
		surface.SetTextPos(math.Round(x), drawY)
		surface.DrawText(text)
	end

	return math.max(cursor - spacing - x, 0)
end

local wrapCache = {}

function NETWORK.util.WrapText(text, font, maxWidth, maxLines)
	if (!isstring(text) or text == "" or maxWidth <= 0) then
		return {}
	end

	maxLines = maxLines or 3

	local key = font .. "|" .. math.Round(maxWidth) .. "|" .. maxLines .. "|" .. text
	local cached = wrapCache[key]

	if (cached) then
		return cached
	end

	surface.SetFont(font)

	local lines = {}

	local function Fits(value)
		return surface.GetTextSize(value) <= maxWidth
	end

	for _, paragraph in ipairs(string.Explode("\n", text)) do
		local current = ""

		for _, word in ipairs(string.Explode(" ", paragraph)) do
			if (word == "") then
				continue
			end

			local candidate = current == "" and word or (current .. " " .. word)

			if (Fits(candidate)) then
				current = candidate

				continue
			end

			if (current != "") then
				lines[#lines + 1] = current
				current = ""
			end

			while (!Fits(word) and NETWORK.util.Length(word) > 1) do
				local cut = NETWORK.util.Length(word)

				while (cut > 1 and !Fits(NETWORK.util.Sub(word, 1, cut))) do
					cut = cut - 1
				end

				lines[#lines + 1] = NETWORK.util.Sub(word, 1, cut)
				word = NETWORK.util.Sub(word, cut + 1)
			end

			current = word
		end

		if (current != "") then
			lines[#lines + 1] = current
		end
	end

	if (#lines > maxLines) then
		local last = lines[maxLines] or ""

		while (last != "" and !Fits(last .. "…")) do
			last = NETWORK.util.Sub(last, 1, NETWORK.util.Length(last) - 1)
		end

		lines[maxLines] = string.TrimRight(last) .. "…"

		for i = #lines, maxLines + 1, -1 do
			lines[i] = nil
		end
	end

	wrapCache[key] = lines

	return lines
end

function NETWORK.util.DrawTextSpacedShadow(text, font, x, y, color, spacing, alignY, offset)
	offset = offset or 1

	NETWORK.util.DrawTextSpaced(text, font, x + offset, y + offset,
		Color(0, 0, 0, (color.a or 255) * 0.75), spacing, alignY)

	return NETWORK.util.DrawTextSpaced(text, font, x, y, color, spacing, alignY)
end

function NETWORK.util.DrawSimpleTextShadow(text, font, x, y, color, alignX, alignY, offset)
	offset = offset or 1

	draw.SimpleText(text, font, x + offset, y + offset,
		Color(0, 0, 0, (color.a or 255) * 0.45), alignX, alignY)

	return draw.SimpleText(text, font, x, y, color, alignX, alignY)
end

hook.Add("OnScreenSizeChanged", "nwTextCache", function()
	charCache = {}
	spacedCache = {}
	wrapCache = {}
end)

local function DrawPolyOriented(points, color)
	local area = 0

	for i = 1, #points do
		local a = points[i]
		local b = points[i % #points + 1]

		area = area + (b.x - a.x) * (b.y + a.y)
	end

	draw.NoTexture()
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)

	if (area >= 0) then
		surface.DrawPoly(points)
	else
		local reversed = {}

		for i = #points, 1, -1 do
			reversed[#reversed + 1] = points[i]
		end

		surface.DrawPoly(reversed)
	end
end

local lineMaterial = Material("vgui/white")

function NETWORK.util.DrawThickLine(x1, y1, x2, y2, thickness, color)
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)

	if (length < 0.0001) then
		return
	end

	if (thickness <= 1.5) then
		surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
		surface.DrawLine(x1, y1, x2, y2)

		return
	end

	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	surface.SetMaterial(lineMaterial)
	surface.DrawTexturedRectRotated((x1 + x2) * 0.5, (y1 + y2) * 0.5, length, thickness,
		-math.deg(math.atan2(dy, dx)))
end

function NETWORK.util.DrawThickLineLegacy(x1, y1, x2, y2, thickness, color)
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)

	if (length < 0.0001) then
		return
	end

	local half = thickness * 0.5
	local nx = -dy / length * half
	local ny = dx / length * half

	DrawPolyOriented({
		{x = x1 + nx, y = y1 + ny},
		{x = x2 + nx, y = y2 + ny},
		{x = x2 - nx, y = y2 - ny},
		{x = x1 - nx, y = y1 - ny}
	}, color)
end

function NETWORK.util.DrawAngledBox(x, y, width, height, cut, color)
	if (width <= 0 or height <= 0) then
		return
	end

	cut = math.min(cut, width * 0.5, height * 0.5)

	DrawPolyOriented({
		{x = x + cut, y = y},
		{x = x + width, y = y},
		{x = x + width, y = y + height - cut},
		{x = x + width - cut, y = y + height},
		{x = x, y = y + height},
		{x = x, y = y + cut}
	}, color)
end

function NETWORK.util.DrawAngledOutline(x, y, width, height, cut, thickness, color)
	if (width <= 0 or height <= 0) then
		return
	end

	cut = math.min(cut, width * 0.5, height * 0.5)

	local points = {
		{x + cut, y},
		{x + width, y},
		{x + width, y + height - cut},
		{x + width - cut, y + height},
		{x, y + height},
		{x, y + cut}
	}

	for i = 1, #points do
		local a = points[i]
		local b = points[i % #points + 1]

		NETWORK.util.DrawThickLine(a[1], a[2], b[1], b[2], thickness, color)
	end
end

function NETWORK.util.DrawBracket(x, y, width, height, thickness, length, color)
	length = math.max(math.Round(length), 0)

	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	surface.DrawRect(x, y, length, thickness)
	surface.DrawRect(x, y, thickness, length)
	surface.DrawRect(x + width - length, y, length, thickness)
	surface.DrawRect(x + width - thickness, y, thickness, length)
	surface.DrawRect(x, y + height - thickness, length, thickness)
	surface.DrawRect(x, y + height - length, thickness, length)
	surface.DrawRect(x + width - length, y + height - thickness, length, thickness)
	surface.DrawRect(x + width - thickness, y + height - length, thickness, length)
end

function NETWORK.util.DrawCircle(x, y, radius, color)
	local size = math.max(math.Round(radius * 2), 2)

	draw.RoundedBox(math.ceil(size * 0.5), math.Round(x - size * 0.5),
		math.Round(y - size * 0.5), size, size, color)
end

function NETWORK.util.DrawCircleOutline(x, y, radius, color, thickness)
	thickness = math.max(math.Round(thickness or 2), 1)

	local size = math.max(math.Round(radius * 2), 2)
	local inner = math.max(size - thickness * 2, 1)

	draw.NoTexture()

	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)

	draw.RoundedBox(math.ceil(size * 0.5), math.Round(x - size * 0.5),
		math.Round(y - size * 0.5), size, size, color)

	draw.RoundedBox(math.ceil(inner * 0.5), math.Round(x - inner * 0.5),
		math.Round(y - inner * 0.5), inner, inner, Color(8, 12, 18, color.a or 255))
end

local textureFailed = {}

function NETWORK.util.GetTexture(path, parameters)
	if (textureFailed[path]) then
		return
	end

	local material = NETWORK.util.GetMaterial(path, parameters or "noclamp")

	if (!material or material:IsError()) then
		textureFailed[path] = true

		return
	end

	return material
end

function NETWORK.util.DrawTiled(material, x, y, width, height, tileWidth, tileHeight, offsetX,
	offsetY)
	if (width <= 0 or height <= 0) then
		return
	end

	local textureWidth = math.max(material:Width(), 1)
	local textureHeight = math.max(material:Height(), 1)

	tileWidth = tileWidth or textureWidth
	tileHeight = tileHeight or textureHeight

	local u0 = -(offsetX or 0) / tileWidth
	local v0 = -(offsetY or 0) / tileHeight
	local u1 = u0 + width / tileWidth
	local v1 = v0 + height / tileHeight
	local du = 0.5 / textureWidth
	local dv = 0.5 / textureHeight

	surface.SetMaterial(material)
	surface.DrawTexturedRectUV(x, y, width, height,
		(u0 - du) / (1 - 2 * du), (v0 - dv) / (1 - 2 * dv),
		(u1 - du) / (1 - 2 * du), (v1 - dv) / (1 - 2 * dv))
end

function NETWORK.util.DrawScanlines(x, y, width, height, alpha, step, color)
	step = math.max(math.Round(step or 3), 1)
	color = color or color_black

	surface.SetDrawColor(color.r, color.g, color.b, alpha or 26)

	local material = step >= 2 and step <= 6 and
		NETWORK.util.GetTexture("framework/pattern/scan" .. step .. ".png")

	if (material) then
		NETWORK.util.DrawTiled(material, x, y, width, height)
		draw.NoTexture()

		return
	end

	for line = 0, height - 1, step do
		surface.DrawRect(x, y + line, width, 1)
	end
end

function NETWORK.util.DrawBrackets(x, y, width, height, size, thickness, color)
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)

	surface.DrawRect(x, y, size, thickness)
	surface.DrawRect(x, y, thickness, size)

	surface.DrawRect(x + width - size, y, size, thickness)
	surface.DrawRect(x + width - thickness, y, thickness, size)

	surface.DrawRect(x, y + height - thickness, size, thickness)
	surface.DrawRect(x, y + height - size, thickness, size)

	surface.DrawRect(x + width - size, y + height - thickness, size, thickness)
	surface.DrawRect(x + width - thickness, y + height - size, thickness, size)
end

function NETWORK.util.DrawPanel(x, y, width, height, alpha, options)
	options = options or {}

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme

	local color = options.color or theme.plateDeep
	local border = options.border or theme.accent
	local thickness = options.thickness or math.max(Sc(1), 1)

	alpha = alpha or 1

	if (options.panel) then
		NETWORK.util.DrawBlurRect(options.panel, x, y, width, height,
			(options.blur or 4) * alpha)
	end

	surface.SetDrawColor(color.r, color.g, color.b, (options.opacity or 218) * alpha)
	surface.DrawRect(x, y, width, height)

	if (options.bScanlines != false) then
		NETWORK.util.DrawScanlines(x, y, width, height, 22 * alpha)
	end

	if (options.bEdge != false) then
		surface.SetDrawColor(border.r, border.g, border.b,
			(options.borderAlpha or 190) * alpha)
		surface.DrawOutlinedRect(x, y, width, height, thickness)
	end

	if (options.bBrackets) then
		NETWORK.util.DrawBrackets(x, y, width, height, Sc(options.bracketSize or 16),
			math.max(Sc(2), 2), ColorAlpha(border, 250 * alpha))
	end

	if (options.bLeftBar) then
		surface.SetDrawColor(border.r, border.g, border.b, 250 * alpha)
		surface.DrawRect(x, y, math.max(Sc(3), 2), height)
	end
end

function NETWORK.util.DrawTitleBar(x, y, width, height, text, alpha, options)
	options = options or {}

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local border = options.border or theme.accent

	alpha = alpha or 1

	surface.SetDrawColor(theme.plateBright.r, theme.plateBright.g, theme.plateBright.b,
		235 * alpha)
	surface.DrawRect(x, y, width, height)

	NETWORK.util.DrawScanlines(x, y, width, height, 24 * alpha)

	surface.SetDrawColor(border.r, border.g, border.b, 250 * alpha)
	surface.DrawRect(x, y + height - math.max(Sc(2), 1), width, math.max(Sc(2), 1))

	NETWORK.util.DrawTextSpaced(NETWORK.util.Upper(text), options.font or "nwTab",
		x + Sc(16), y + math.Round(height * 0.5),
		ColorAlpha(options.textColor or theme.accentSoft, 252 * alpha), Sc(4),
		TEXT_ALIGN_CENTER)
end

function NETWORK.util.DrawField(x, y, width, height, label, alpha, options)
	options = options or {}

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local border = options.border or theme.accent

	alpha = alpha or 1

	surface.SetDrawColor(theme.plateDeep.r, theme.plateDeep.g, theme.plateDeep.b,
		(options.opacity or 225) * alpha)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(border.r, border.g, border.b, (options.borderAlpha or 120) * alpha)
	surface.DrawOutlinedRect(x, y, width, height, math.max(Sc(1), 1))

	if (!label or label == "") then
		return
	end

	surface.SetFont("nwHudSmall")

	local textWidth = surface.GetTextSize(NETWORK.util.Upper(label))

	surface.SetDrawColor(theme.plateBright.r, theme.plateBright.g, theme.plateBright.b,
		250 * alpha)
	surface.DrawRect(x, y, textWidth + Sc(14), Sc(15))

	surface.SetDrawColor(border.r, border.g, border.b, 200 * alpha)
	surface.DrawRect(x, y, textWidth + Sc(14), math.max(Sc(1), 1))

	draw.SimpleText(NETWORK.util.Upper(label), "nwHudSmall", x + Sc(7), y + Sc(8),
		ColorAlpha(theme.accentSoft, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function NETWORK.util.DrawRoundedOutline(x, y, width, height, radius, color, thickness)
	thickness = thickness or 1

	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)

	surface.DrawRect(x + radius, y, width - radius * 2, thickness)
	surface.DrawRect(x + radius, y + height - thickness, width - radius * 2, thickness)
	surface.DrawRect(x, y + radius, thickness, height - radius * 2)
	surface.DrawRect(x + width - thickness, y + radius, thickness, height - radius * 2)

	local segments = 6

	for _, corner in ipairs({
		{x + radius, y + radius, 180, 270},
		{x + width - radius, y + radius, 270, 360},
		{x + width - radius, y + height - radius, 0, 90},
		{x + radius, y + height - radius, 90, 180}
	}) do
		local previousX, previousY

		for i = 0, segments do
			local angle = math.rad(Lerp(i / segments, corner[3], corner[4]))
			local pointX = corner[1] + math.cos(angle) * radius
			local pointY = corner[2] + math.sin(angle) * radius

			if (previousX) then
				NETWORK.util.DrawThickLine(previousX, previousY, pointX, pointY, thickness,
					color)
			end

			previousX, previousY = pointX, pointY
		end
	end
end

function NETWORK.util.DrawArc(x, y, radius, thickness, fraction, color, segments, startAngle)
	fraction = math.Clamp(fraction or 1, 0, 1)
	startAngle = startAngle or -90

	if (fraction <= 0.0001) then
		return
	end

	segments = segments or 96

	local inner = radius - thickness * 0.5
	local outer = radius + thickness * 0.5
	local total = segments * fraction
	local count = math.ceil(total)

	for i = 0, count - 1 do
		local first = i / segments
		local second = math.min((i + 1) / segments, fraction)
		local a = math.rad(first * 360 + startAngle)
		local b = math.rad(second * 360 + startAngle)

		DrawPolyOriented({
			{x = x + math.cos(a) * outer, y = y + math.sin(a) * outer},
			{x = x + math.cos(b) * outer, y = y + math.sin(b) * outer},
			{x = x + math.cos(b) * inner, y = y + math.sin(b) * inner},
			{x = x + math.cos(a) * inner, y = y + math.sin(a) * inner}
		}, color)
	end
end

function NETWORK.util.TruncateWidth(text, font, maximum)
	if (!isstring(text) or text == "") then
		return ""
	end

	surface.SetFont(font)

	if (surface.GetTextSize(text) <= maximum) then
		return text
	end

	local length = utf8.len(text) or #text

	for count = length - 1, 1, -1 do
		local offset = utf8.offset(text, count + 1)
		local part = offset and string.sub(text, 1, offset - 1) or text

		if (surface.GetTextSize(part .. "...") <= maximum) then
			return part .. "..."
		end
	end

	return "..."
end

function NETWORK.util.DrawProgressBar(x, y, width, height, fraction, color, alpha)
	alpha = alpha == nil and 1 or alpha
	fraction = math.Clamp(fraction or 0, 0, 1)

	if (alpha <= 0.005 or width <= 0 or height <= 0) then
		return
	end

	x, y = math.Round(x), math.Round(y)
	width, height = math.Round(width), math.Round(height)
	color = color or NETWORK.theme.combine

	local radius = math.max(math.floor(height * 0.5), 1)

	draw.RoundedBox(radius, x, y, width, height, Color(255, 255, 255, 16 * alpha))

	local fill = math.Round(width * fraction)

	if (fill <= 0) then
		return
	end

	if (fill < radius * 2) then
		surface.SetDrawColor(color.r, color.g, color.b, 235 * alpha)
		surface.DrawRect(x, y, math.max(fill, 2), height)

		return
	end

	draw.RoundedBox(radius, x, y, fill, height, ColorAlpha(color, 235 * alpha))
end

function NETWORK.util.DrawProgressRing(x, y, radius, thickness, fraction, color, alpha)
	alpha = alpha == nil and 1 or alpha
	fraction = math.Clamp(fraction or 0, 0, 1)

	if (alpha <= 0.005) then
		return
	end

	color = color or NETWORK.theme.accent

	NETWORK.util.DrawRing(x, y, radius, thickness,
		Color(4, 7, 12, 215 * alpha), 64, 1)
	NETWORK.util.DrawRing(x, y, radius, thickness,
		ColorAlpha(color, 40 * alpha), 64, 1)

	if (fraction > 0.001) then
		NETWORK.util.DrawRing(x, y, radius, thickness,
			ColorAlpha(color, 245 * alpha), 64, fraction)

		local angle = math.rad(fraction * 360 - 90)

		NETWORK.util.DrawCircle(x + math.cos(angle) * radius,
			y + math.sin(angle) * radius, math.max(thickness * 0.6, 2),
			Color(235, 245, 255, 235 * alpha))
	end
end

function NETWORK.util.DrawRing(x, y, radius, thickness, color, segments, fraction)
	segments = segments or 64
	fraction = fraction or 1

	local count = math.max(math.Round(segments * fraction), 1)

	for i = 0, count - 1 do
		local a = math.rad(i / segments * 360 - 90)
		local b = math.rad((i + 1) / segments * 360 - 90)

		NETWORK.util.DrawThickLine(
			x + math.cos(a) * radius, y + math.sin(a) * radius,
			x + math.cos(b) * radius, y + math.sin(b) * radius,
			thickness, color)
	end
end

function NETWORK.util.DrawDashedRing(x, y, radius, thickness, color, dashes, gap, rotation)
	local step = 360 / dashes

	for i = 0, dashes - 1 do
		local start = rotation + i * step
		local finish = start + step * (1 - gap)
		local segments = math.max(math.Round(step * 0.25), 2)

		for j = 0, segments - 1 do
			local a = math.rad(Lerp(j / segments, start, finish))
			local b = math.rad(Lerp((j + 1) / segments, start, finish))

			NETWORK.util.DrawThickLine(
				x + math.cos(a) * radius, y + math.sin(a) * radius,
				x + math.cos(b) * radius, y + math.sin(b) * radius,
				thickness, color)
		end
	end
end

function NETWORK.util.BuildCornerPath(x, y, width, height, cut)
	return {
		{x + cut, y},
		{x + width - cut, y},
		{x + width, y + cut},
		{x + width, y + height - cut},
		{x + width - cut, y + height},
		{x + cut, y + height},
		{x, y + height - cut},
		{x, y + cut}
	}
end

function NETWORK.util.DrawCornerBox(x, y, width, height, cut, color)
	local path = NETWORK.util.BuildCornerPath(x, y, width, height, cut)
	local points = {}

	for i = 1, #path do
		points[i] = {x = path[i][1], y = path[i][2]}
	end

	DrawPolyOriented(points, color)
end

local function MeasurePath(path, startIndex)
	local count = #path
	local lengths = {}
	local total = 0

	for i = 0, count - 1 do
		local a = path[(startIndex - 1 + i) % count + 1]
		local b = path[(startIndex + i) % count + 1]
		local length = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)

		lengths[i + 1] = length
		total = total + length
	end

	return lengths, total
end

function NETWORK.util.DrawPathProgress(path, fraction, thickness, color, startIndex)
	fraction = math.Clamp(fraction, 0, 1)

	if (fraction <= 0) then
		return
	end

	startIndex = startIndex or 1

	local count = #path
	local lengths, total = MeasurePath(path, startIndex)
	local remaining = total * fraction

	for i = 0, count - 1 do
		if (remaining <= 0) then
			break
		end

		local a = path[(startIndex - 1 + i) % count + 1]
		local b = path[(startIndex + i) % count + 1]
		local length = lengths[i + 1]
		local part = math.min(remaining / math.max(length, 0.001), 1)

		NETWORK.util.DrawThickLine(a[1], a[2],
			a[1] + (b[1] - a[1]) * part, a[2] + (b[2] - a[2]) * part, thickness, color)

		remaining = remaining - length
	end
end

function NETWORK.util.GetPathPoint(path, fraction, startIndex)
	fraction = math.Clamp(fraction, 0, 1)
	startIndex = startIndex or 1

	local count = #path
	local lengths, total = MeasurePath(path, startIndex)
	local remaining = total * fraction

	for i = 0, count - 1 do
		local a = path[(startIndex - 1 + i) % count + 1]
		local b = path[(startIndex + i) % count + 1]
		local length = lengths[i + 1]

		if (remaining <= length) then
			local part = remaining / math.max(length, 0.001)

			return a[1] + (b[1] - a[1]) * part, a[2] + (b[2] - a[2]) * part
		end

		remaining = remaining - length
	end

	local last = path[startIndex]

	return last[1], last[2]
end

function NETWORK.util.ApplyAppearance(panel, source)
	if (!IsValid(panel)) then
		return
	end

	local entity = panel.GetEntity and panel:GetEntity() or panel

	if (!IsValid(entity) or !IsValid(source)) then
		return
	end

	entity:SetSkin(source:GetSkin())

	for _, data in pairs(source:GetBodyGroups() or {}) do
		entity:SetBodygroup(data.id, source:GetBodygroup(data.id))
	end

	for index = 0, 15 do
		entity:SetSubMaterial(index, source:GetSubMaterial(index))
	end
end

function NETWORK.util.FrameModelPanel(panel, frameUnits, bias, margin)
	if (!IsValid(panel)) then
		return
	end

	local entity = panel:GetEntity()

	if (!IsValid(entity)) then
		return
	end

	local width, height = panel:GetSize()

	if (width <= 0 or height <= 0) then
		return
	end

	local mins, maxs = entity:GetModelBounds()

	if (!mins or !maxs) then
		return
	end

	local scale = entity:GetModelScale() or 1
	local bottom = mins.z * scale
	local centerX = (mins.x + maxs.x) * 0.5 * scale
	local centerY = (mins.y + maxs.y) * 0.5 * scale

	frameUnits = (frameUnits or (maxs.z - mins.z) * scale) * (margin or 1.12)

	local aspect = width / height
	local horizontal = math.rad(panel:GetFOV() or 34)
	local vertical = 2 * math.atan(math.tan(horizontal * 0.5) / math.max(aspect, 0.0001))
	local distance = (frameUnits * 0.5) / math.max(math.tan(vertical * 0.5), 0.0001)
	local look = bottom + frameUnits * (0.5 + (bias or 0))

	panel:SetLookAt(Vector(centerX, centerY, look))
	panel:SetCamPos(Vector(centerX + distance, centerY, look))
end

local blurMaterial = Material("pp/blurscreen")

local blurQuality = CreateClientConVar("network_blur", "1", true, false,
	"Размытие фона в меню: 0 выкл, 1 экономно, 2 полностью")

local blurBudget = 1

NETWORK.util.blurDepth = 0

function NETWORK.util.PushBlurBlock()
	NETWORK.util.blurDepth = (NETWORK.util.blurDepth or 0) + 1
end

function NETWORK.util.PopBlurBlock()
	NETWORK.util.blurDepth = math.max((NETWORK.util.blurDepth or 0) - 1, 0)
end

function NETWORK.util.DrawBlur(panel, amount, passes)
	amount = amount or 5

	if (amount <= 0.05) then
		return
	end

	local quality = blurQuality:GetInt()

	blurBudget = blurBudget * 0.95 + FrameTime() * 0.05

	local bUnsafe = (NETWORK.util.blurDepth or 0) > 0 or blurMaterial:IsError()

	if (quality <= 0 or bUnsafe or blurBudget > 1 / 40) then

		local x, y = panel:LocalToScreen(0, 0)

		surface.SetDrawColor(0, 0, 0, math.Clamp(amount * 14, 0, 170))
		surface.DrawRect(-x, -y, ScrW(), ScrH())

		return
	end

	surface.SetMaterial(blurMaterial)
	surface.SetDrawColor(255, 255, 255)

	local x, y = panel:LocalToScreen(0, 0)
	local count = quality >= 2 and 3 or 2

	for index = 1, count do
		blurMaterial:SetFloat("$blur", (index / count) * amount)
		blurMaterial:Recompute()

		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
	end
end

function NETWORK.util.DrawBlurScreen(x, y, width, height, amount)
	if (width < 2 or height < 2 or (amount or 0) <= 0.05) then
		return
	end

	render.SetScissorRect(math.Round(x), math.Round(y),
		math.Round(x + width), math.Round(y + height), true)

	NETWORK.util.DrawBlur(vgui.GetWorldPanel(), amount)

	render.SetScissorRect(0, 0, 0, 0, false)
end

function NETWORK.util.DrawBlurRect(panel, x, y, width, height, amount)
	if (width < 2 or height < 2) then
		return
	end

	if (!IsValid(panel)) then
		return NETWORK.util.DrawBlurScreen(x, y, width, height, amount)
	end

	local screenX, screenY = panel:LocalToScreen(math.Round(x), math.Round(y))

	render.SetScissorRect(screenX, screenY, screenX + math.Round(width),
		screenY + math.Round(height), true)

	NETWORK.util.DrawBlur(panel, amount or 4)

	render.SetScissorRect(0, 0, 0, 0, false)
end

local function BeginStencilShape(x, y, width, height, radius)
	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(255)
	render.SetStencilTestMask(255)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)

	render.OverrideColorWriteEnable(true, false)
	draw.RoundedBox(radius, x, y, width, height, color_white)
	render.OverrideColorWriteEnable(false, false)

	render.SetStencilPassOperation(STENCIL_KEEP)
end

function NETWORK.util.DrawBlurRounded(panel, x, y, width, height, radius, amount)
	if (width < 2 or height < 2 or (amount or 0) <= 0.01) then
		return
	end

	BeginStencilShape(x, y, width, height, radius)

	render.SetStencilCompareFunction(STENCIL_EQUAL)

	NETWORK.util.DrawBlurRect(panel, x, y, width, height, amount)

	render.SetStencilEnable(false)
end

function NETWORK.util.DrawRoundedBorder(x, y, width, height, radius, thickness, color)
	if (width < 2 or height < 2 or (color.a or 255) <= 0) then
		return
	end

	thickness = math.max(thickness or 1, 1)

	BeginStencilShape(x + thickness, y + thickness, width - thickness * 2,
		height - thickness * 2, math.max(radius - thickness, 0))

	render.SetStencilCompareFunction(STENCIL_NOTEQUAL)

	draw.RoundedBox(radius, x, y, width, height, color)

	render.SetStencilEnable(false)
end

function NETWORK.util.DrawGlass(panel, x, y, width, height, alpha, options)
	options = options or {}
	alpha = alpha or 1

	if (width < 2 or height < 2 or alpha <= 0.004) then
		return
	end

	local Sc = NETWORK.util.Scale
	local radius = options.radius or math.max(Sc(8), 5)
	local base = options.base or Color(10, 11, 13)

	NETWORK.util.DrawBlurRect(panel, x, y, width, height,
		(options.blur or 4) * alpha)

	draw.RoundedBox(radius, x, y, width, height,
		Color(base.r, base.g, base.b, (options.opacity or 214) * alpha))

	if (options.accent) then
		local bar = math.max(Sc(3), 2)
		local barHeight = math.Round(height * (options.accentSize or 0.55))

		draw.RoundedBox(bar, x, y + math.Round((height - barHeight) * 0.5), bar,
			barHeight, ColorAlpha(options.accent,
				(options.accentAlpha or 235) * alpha))
	end
end

function NETWORK.util.Approach(current, target, speed)
	return Lerp(math.Clamp(FrameTime() * (speed or 10), 0, 1), current, target)
end

function NETWORK.util.Stagger(startTime, delay, duration)
	return math.Clamp((CurTime() - startTime - delay) / (duration or 0.5), 0, 1)
end

function NETWORK.util.EaseOut(fraction)
	return 1 - (1 - fraction) ^ 4
end

function NETWORK.util.EaseInOut(fraction)
	return fraction < 0.5 and 8 * fraction ^ 4 or 1 - ((-2 * fraction + 2) ^ 4) * 0.5
end

function NETWORK.util.EaseOutBack(fraction)
	local c1 = 1.70158
	local c3 = c1 + 1

	return 1 + c3 * (fraction - 1) ^ 3 + c1 * (fraction - 1) ^ 2
end

local styleCache = {}

function NETWORK.util.ParseStyles(text)
	if (!isstring(text) or text == "") then
		return {}
	end

	local cached = styleCache[text]

	if (cached) then
		return cached
	end

	local runs = {}
	local index = 1

	while (index <= #text) do
		local boldStart, boldFinish, boldInner = string.find(text, "%*%*(.-)%*%*", index)
		local italicStart, italicFinish, italicInner = string.find(text, "%*(.-)%*", index)

		local start, finish, content, style

		if (boldStart and (!italicStart or boldStart <= italicStart)) then
			start, finish, content, style = boldStart, boldFinish, boldInner, "bold"
		elseif (italicStart) then
			start, finish, content, style = italicStart, italicFinish, italicInner, "italic"
		end

		if (!start or content == "") then
			runs[#runs + 1] = {text = string.sub(text, index), style = ""}

			break
		end

		if (start > index) then
			runs[#runs + 1] = {text = string.sub(text, index, start - 1), style = ""}
		end

		runs[#runs + 1] = {text = content, style = style}

		index = finish + 1
	end

	styleCache[text] = runs

	return runs
end

function NETWORK.util.StripStyles(text)
	if (!isstring(text)) then
		return ""
	end

	text = string.gsub(text, "%*%*(.-)%*%*", "%1")
	text = string.gsub(text, "%*(.-)%*", "%1")

	return text
end

function NETWORK.util.StyledTextSize(text, fonts)
	local width, height = 0, 0

	for _, run in ipairs(NETWORK.util.ParseStyles(text)) do
		surface.SetFont(fonts[run.style == "" and 1 or run.style == "bold" and 2 or 3] or
			fonts[1])

		local runWidth, runHeight = surface.GetTextSize(run.text)

		width = width + runWidth
		height = math.max(height, runHeight)
	end

	return width, height
end

function NETWORK.util.DrawStyledText(text, fonts, x, y, color, alignX, alignY, shadow)
	local runs = NETWORK.util.ParseStyles(text)

	if (#runs == 0) then
		return
	end

	local total = NETWORK.util.StyledTextSize(text, fonts)
	local cursor = x

	if (alignX == TEXT_ALIGN_CENTER) then
		cursor = x - total * 0.5
	elseif (alignX == TEXT_ALIGN_RIGHT) then
		cursor = x - total
	end

	for _, run in ipairs(runs) do
		local font = fonts[run.style == "" and 1 or run.style == "bold" and 2 or 3] or
			fonts[1]

		if (shadow) then
			NETWORK.util.DrawSimpleTextShadow(run.text, font, cursor, y, color,
				TEXT_ALIGN_LEFT, alignY or TEXT_ALIGN_CENTER, shadow)
		else
			draw.SimpleText(run.text, font, cursor, y, color, TEXT_ALIGN_LEFT,
				alignY or TEXT_ALIGN_CENTER)
		end

		surface.SetFont(font)

		cursor = cursor + surface.GetTextSize(run.text)
	end
end

local gradientDown = Material("gui/gradient_down")
local gradientUp = Material("gui/gradient_up")
local gradientRight = Material("gui/gradient")

local function Blend(material, x, y, width, height, color)
	local alpha = color.a or 255

	surface.SetMaterial(material)

	surface.SetDrawColor(color.r, color.g, color.b, alpha * 0.65)
	surface.DrawTexturedRect(x, y, width, height)

	surface.SetDrawColor(color.r, color.g, color.b, alpha * 0.5)
	surface.DrawTexturedRect(x, y + 1, width, height)
end

local function IsSolid(color)
	return (color.a or 255) >= 250
end

function NETWORK.util.DrawVGradient(x, y, width, height, top, bottom)
	if (width < 1 or height < 1) then
		return
	end

	if (IsSolid(top) and IsSolid(bottom)) then
		surface.SetDrawColor(bottom.r, bottom.g, bottom.b, 255)
		surface.DrawRect(x, y, width, height)

		Blend(gradientDown, x, y, width, height, top)

		return
	end

	Blend(gradientDown, x, y, width, height, top)
	Blend(gradientUp, x, y, width, height, bottom)
end

function NETWORK.util.DrawHGradient(x, y, width, height, left, right)
	if (width < 1 or height < 1) then
		return
	end

	if (IsSolid(left) and IsSolid(right)) then
		surface.SetDrawColor(right.r, right.g, right.b, 255)
		surface.DrawRect(x, y, width, height)

		Blend(gradientRight, x, y, width, height, left)

		return
	end

	Blend(gradientRight, x, y, width, height, left)

	surface.SetDrawColor(right.r, right.g, right.b, right.a or 255)
	surface.SetMaterial(gradientRight)
	surface.DrawTexturedRectUV(x, y, width, height, 1, 0, 0, 1)
end

local gradientCenter = Material("gui/center_gradient")

function NETWORK.util.DrawGlow(x, y, width, height, color)
	if (width < 2 or height < 2) then
		return
	end

	Blend(gradientCenter, x, y, width, height, color)
end

local lightLayers = {
	{scale = 2.05, weight = 0.16},
	{scale = 1.45, weight = 0.2},
	{scale = 1.0, weight = 0.24},
	{scale = 0.66, weight = 0.24},
	{scale = 0.4, weight = 0.22}
}

function NETWORK.util.DrawSoftLight(centerX, centerY, width, height, color, strength)
	strength = strength or 60

	for _, layer in ipairs(lightLayers) do
		local layerWidth = math.Round(width * layer.scale)
		local layerHeight = math.Round(height * layer.scale)

		NETWORK.util.DrawGlow(
			centerX - math.Round(layerWidth * 0.5),
			centerY - math.Round(layerHeight * 0.5),
			layerWidth, layerHeight,
			ColorAlpha(color, strength * layer.weight))
	end
end

function NETWORK.util.DrawVignette(x, y, width, height, size, strength, color)
	color = color or color_black

	local band = math.min(size, math.floor(math.min(width, height) * 0.5))

	if (band < 2) then
		return
	end

	local edge = ColorAlpha(color, strength or 200)
	local clear = ColorAlpha(color, 0)

	NETWORK.util.DrawVGradient(x, y, width, band, edge, clear)
	NETWORK.util.DrawVGradient(x, y + height - band, width, band, clear, edge)
	NETWORK.util.DrawHGradient(x, y, band, height, edge, clear)
	NETWORK.util.DrawHGradient(x + width - band, y, band, height, clear, edge)
end

function NETWORK.util.DrawSpread(x, y, width, height, color, bVertical)
	if (width < 2 or height < 2) then
		return
	end

	if (bVertical) then
		local half = math.floor(height * 0.5)

		Blend(gradientUp, x, y, width, half, color)
		Blend(gradientDown, x, y + half, width, height - half, color)

		return
	end

	local half = math.floor(width * 0.5)

	Blend(gradientRight, x + half, y, width - half, height, color)

	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	surface.SetMaterial(gradientRight)
	surface.DrawTexturedRectUV(x, y, half, height, 1, 0, 0, 1)
end

local chromeCache = {}

function NETWORK.util.DrawChrome(x, y, width, height, color, alpha)
	if (width < 8 or height < 8) then
		return
	end

	local key = math.Round(width) .. "x" .. math.Round(height) .. ":" ..
		color.r .. "," .. color.g .. "," .. color.b
	local entry = chromeCache[key]

	if (!entry) then

		local texture = GetRenderTargetEx("nwChrome" .. key,
			math.Round(width), math.Round(height), RT_SIZE_NO_CHANGE,
			MATERIAL_RT_DEPTH_NONE, 1, 0, IMAGE_FORMAT_BGRA8888)

		local material = CreateMaterial("nwChromeMat" .. key, "UnlitGeneric", {
			["$basetexture"] = texture:GetName(),
			["$translucent"] = 1,
			["$vertexalpha"] = 1,
			["$vertexcolor"] = 1
		})

		render.PushRenderTarget(texture)
			render.Clear(0, 0, 0, 0, true, true)

			cam.Start2D()
				surface.SetDrawColor(color.r, color.g, color.b, 26)

				for line = 0, width - 1, NETWORK.util.Scale(40) do
					surface.DrawRect(line, 0, 1, height)
				end

				for line = 0, height - 1, NETWORK.util.Scale(40) do
					surface.DrawRect(0, line, width, 1)
				end

				surface.SetDrawColor(0, 0, 0, 60)

				for line = 0, height - 1, math.max(NETWORK.util.Scale(3), 3) do
					surface.DrawRect(0, line, width, 1)
				end
			cam.End2D()
		render.PopRenderTarget()

		entry = {texture = texture, material = material}
		chromeCache[key] = entry
	end

	surface.SetMaterial(entry.material)
	surface.SetDrawColor(255, 255, 255, alpha or 255)
	surface.DrawTexturedRect(x, y, width, height)
end

hook.Add("OnScreenSizeChanged", "nwChromeCache", function()
	chromeCache = {}
end)

NETWORK.gui = NETWORK.gui or {}
NETWORK.gui.bNewCharacterUI = false
