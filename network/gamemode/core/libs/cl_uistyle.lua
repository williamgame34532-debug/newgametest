NETWORK.style = NETWORK.style or {}

local S = NETWORK.style

function S.Sc(value)
	return NETWORK.util.Scale(value)
end

function S.Radius(kind)
	local Sc = NETWORK.util.Scale

	-- PDA style: near-square plates with hairline borders.
	if (kind == "panel") then
		return math.max(Sc(4), 2)
	elseif (kind == "cell") then
		return math.max(Sc(2), 2)
	elseif (kind == "chip") then
		return math.max(Sc(2), 2)
	end

	return math.max(Sc(3), 2)
end

S.fill = Color(10, 22, 36)
S.fillSoft = Color(15, 31, 49)
S.line = Color(104, 150, 196, 56)
S.lineStrong = Color(104, 150, 196, 110)

function S.Accent()
	return NETWORK.theme.combine or Color(86, 150, 226)
end

function S.Shadow(x, y, width, height, radius, alpha, spread)
	spread = spread or math.max(S.Sc(10), 6)

	for i = 1, 4 do
		local grow = math.Round(spread * i / 4)

		draw.RoundedBox(radius + grow, x - grow, y - grow + math.Round(grow * 0.6),
			width + grow * 2, height + grow * 2, Color(0, 0, 0, 34 * alpha / i))
	end
end

function S.Card(x, y, width, height, alpha, options)
	options = options or {}
	alpha = math.Clamp(alpha or 1, 0, 1)

	if (width < 2 or height < 2 or alpha <= 0.004) then
		return
	end

	x, y, width, height = math.Round(x), math.Round(y), math.Round(width), math.Round(height)

	local radius = options.radius or S.Radius("card")
	local accent = options.accent or S.Accent()
	local fill = options.fill or S.fill
	local border = options.border or S.line
	local glow = math.Clamp(options.glow or 0, 0, 1)

	if (options.shadow != false) then
		S.Shadow(x, y, width, height, radius, alpha)
	end

	if (options.blur != false) then
		if (IsValid(options.panel)) then
			NETWORK.util.DrawBlurRounded(options.panel, x, y, width, height, radius, 4 * alpha)
		else
			NETWORK.util.DrawBlurScreen(x, y, width, height, 4 * alpha)
		end
	end

	draw.RoundedBox(radius, x, y, width, height,
		Color(fill.r, fill.g, fill.b, (fill.a != 255 and fill.a or 232) * alpha))

	local r = Lerp(glow, border.r, accent.r)
	local g = Lerp(glow, border.g, accent.g)
	local b = Lerp(glow, border.b, accent.b)
	local a = Lerp(glow, border.a or 40, 200)

	NETWORK.util.DrawRoundedBorder(x, y, width, height, radius, 1, Color(r, g, b, a * alpha))

	if (options.accent != false) then
		local inset = radius
		local lineWidth = width - inset * 2
		local steps = 12

		for i = 0, steps - 1 do
			local fraction = i / (steps - 1)
			local strength = 1 - math.abs(fraction - 0.5) * 2

			surface.SetDrawColor(accent.r, accent.g, accent.b,
				(options.accent and 200 or 60) * strength * alpha)
			surface.DrawRect(x + inset + math.floor(lineWidth * i / steps), y,
				math.ceil(lineWidth / steps), 1)
		end
	end
end

function S.Chip(text, font, x, y, color, alpha, options)
	options = options or {}
	alpha = alpha or 1

	surface.SetFont(font)

	local textWidth, textHeight = surface.GetTextSize(text)
	local padX = options.padX or math.max(S.Sc(7), 4)
	local padY = options.padY or math.max(S.Sc(3), 2)
	local width = textWidth + padX * 2
	local height = textHeight + padY * 2
	local radius = S.Radius("chip")

	if (options.alignRight) then
		x = x - width
	end

	draw.RoundedBox(radius, x, y, width, height,
		Color(color.r, color.g, color.b, (options.fill or 34) * alpha))
	NETWORK.util.DrawRoundedBorder(x, y, width, height, radius, 1,
		Color(color.r, color.g, color.b, (options.border or 120) * alpha))

	draw.SimpleText(text, font, x + padX, y + padY, ColorAlpha(color, 250 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	return width, height
end

function S.Unfold(fraction)
	fraction = math.Clamp(fraction, 0, 1)

	local widthPart = math.Clamp(fraction / 0.4, 0, 1)
	local heightPart = math.Clamp((fraction - 0.3) / 0.7, 0, 1)

	return NETWORK.util.EaseOut(widthPart), NETWORK.util.EaseOut(heightPart)
end

function S.Leader(ax, ay, x, y, width, height, color, alpha, progress)
	alpha = math.Clamp(alpha or 1, 0, 1)
	progress = math.Clamp(progress or 1, 0, 1)

	if (alpha <= 0.01 or !ax or !ay) then
		return false
	end

	if (ax > x and ax < x + width and ay > y and ay < y + height) then
		return false
	end

	local radius = S.Radius("card")

	local endX = math.Clamp(ax, x + radius, x + width - radius)
	local endY = math.Clamp(ay, y + radius, y + height - radius)
	local bLeft, bRight = ax <= x, ax >= x + width
	local bAbove, bBelow = ay <= y, ay >= y + height
	local corner = math.Round(radius * 0.29)

	if (bLeft) then endX = x elseif (bRight) then endX = x + width end
	if (bAbove) then endY = y elseif (bBelow) then endY = y + height end

	if ((bLeft or bRight) and (bAbove or bBelow)) then
		endX = bLeft and (x + corner) or (x + width - corner)
		endY = bAbove and (y + corner) or (y + height - corner)
	end

	local dx, dy = endX - ax, endY - ay

	if (dx * dx + dy * dy < S.Sc(14) ^ 2) then
		return false
	end

	local tipX = math.Round(ax + dx * progress)
	local tipY = math.Round(ay + dy * progress)
	local a = 200 * alpha

	surface.SetDrawColor(0, 0, 0, 90 * alpha)
	surface.DrawLine(ax + 1, ay + 1, tipX + 1, tipY + 1)

	surface.SetDrawColor(color.r, color.g, color.b, a)
	surface.DrawLine(ax, ay, tipX, tipY)

	if (S.Sc(2) >= 3) then
		if (math.abs(dx) > math.abs(dy)) then
			surface.DrawLine(ax, ay + 1, tipX, tipY + 1)
		else
			surface.DrawLine(ax + 1, ay, tipX + 1, tipY)
		end
	end

	local dot = math.max(S.Sc(3), 2)

	NETWORK.util.DrawCircle(ax, ay, dot + math.max(S.Sc(3), 2), Color(color.r, color.g, color.b, 40 * alpha))
	NETWORK.util.DrawCircle(ax, ay, dot, Color(color.r, color.g, color.b, 240 * alpha))

	return true
end

function S.PushClip(x, y, width, height)
	render.SetScissorRect(math.Round(x), math.Round(y), math.Round(x + width),
		math.Round(y + height), true)
end

function S.PopClip()
	render.SetScissorRect(0, 0, 0, 0, false)
end

-- PDA-style building blocks ---------------------------------------------------------------------
-- Shared by the main menu, the character screens, the inventory and the tooltip so every plate
-- in the gamemode has the same navy fill, hairline frame and accent corner ticks.

S.fontCache = S.fontCache or {}

function S.Font(face, size, weight)
	local scaled = NETWORK.util.Scale(size)
	local name = "nwPda_" .. face .. "_" .. scaled .. "_" .. (weight or 500)

	if (!S.fontCache[name]) then
		local faces = NETWORK.fonts or {}

		surface.CreateFont(name, {
			font = faces[face] or faces.body or "Arial",
			size = scaled,
			weight = weight or 500,
			extended = true,
			antialias = true
		})

		S.fontCache[name] = true
	end

	return name
end

function S.Pda()
	return NETWORK.theme.pda or {
		bg = Color(10, 22, 36), bg2 = Color(15, 31, 49), deep = Color(7, 15, 25),
		line = Color(44, 70, 96), lineSoft = Color(27, 45, 64), text = Color(228, 238, 246),
		muted = Color(122, 146, 168), faint = Color(84, 106, 128), accent = Color(104, 170, 228),
		good = Color(110, 200, 150), warn = Color(232, 176, 86), bad = Color(230, 92, 84)
	}
end

function S.Ticks(x, y, width, height, size, color, thickness)
	thickness = thickness or 1

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

-- options: accent (Color), band (header height), title (band caption), right (band right text),
--          fill (Color), stripe (bool, left accent stripe), ticks (bool, default true)
function S.Plate(x, y, width, height, alpha, options)
	options = options or {}
	alpha = math.Clamp(alpha or 1, 0, 1)

	if (width < 2 or height < 2 or alpha <= 0.004) then
		return
	end

	local P = S.Pda()
	local accent = options.accent or P.accent
	local fill = options.fill or P.bg

	x, y, width, height = math.Round(x), math.Round(y), math.Round(width), math.Round(height)

	surface.SetDrawColor(fill.r, fill.g, fill.b, (options.fillAlpha or 236) * alpha)
	surface.DrawRect(x, y, width, height)

	local band = options.band

	if (band and band > 0) then
		surface.SetDrawColor(P.bg2.r, P.bg2.g, P.bg2.b, 250 * alpha)
		surface.DrawRect(x, y, width, band)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 80 * alpha)
		surface.DrawRect(x, y + band, width, 1)

		local font = options.font or S.Font("label", 12, 700)
		local pad = options.pad or S.Sc(14)

		if (options.title) then
			draw.SimpleText(NETWORK.util.Upper(options.title), font, x + pad, y + math.Round(band * 0.5),
				ColorAlpha(P.muted, 240 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		if (options.right) then
			draw.SimpleText(NETWORK.util.Upper(options.right), font, x + width - pad,
				y + math.Round(band * 0.5), ColorAlpha(options.rightColor or accent, 240 * alpha),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	surface.SetDrawColor(P.line.r, P.line.g, P.line.b, 210 * alpha)
	surface.DrawOutlinedRect(x, y, width, height, 1)

	if (options.stripe) then
		surface.SetDrawColor(accent.r, accent.g, accent.b, 235 * alpha)
		surface.DrawRect(x, y, math.max(S.Sc(3), 2), height)
	end

	if (options.ticks != false) then
		S.Ticks(x, y, width, height, options.tick or S.Sc(10), ColorAlpha(accent, 220 * alpha))
	end
end

function S.Grid(x, y, width, height, step, alpha)
	local P = S.Pda()

	surface.SetDrawColor(P.line.r, P.line.g, P.line.b, 22 * alpha)

	for gx = x + step, x + width - 1, step do
		surface.DrawRect(gx, y, 1, height)
	end

	for gy = y + step, y + height - 1, step do
		surface.DrawRect(x, gy, width, 1)
	end
end

-- PDA button paint for nwMenuButton panels. options: danger, primary, small
function S.Button(panel, width, height, alpha, options)
	options = options or {}

	local P = S.Pda()
	local util = NETWORK.util
	local Sc = util.Scale
	local reveal = util.EaseOut(util.Stagger(panel.startTime or 0, panel.revealDelay or 0, 0.6))

	alpha = (alpha or 1) * reveal * (1 - util.EaseInOut(panel.exit or 0))

	if (alpha < 0.01) then
		return
	end

	local hover = util.EaseInOut(panel.hover or 0)
	local accent = (options.danger or panel.bDanger) and P.bad or P.accent
	local fill = options.primary and accent or P.deep

	surface.SetDrawColor(fill.r, fill.g, fill.b, (options.primary and (50 + 50 * hover) or 210) * alpha)
	surface.DrawRect(0, 0, width, height)

	if (hover > 0.01 and !options.primary) then
		surface.SetDrawColor(accent.r, accent.g, accent.b, 30 * hover * alpha)
		surface.DrawRect(0, 0, width, height)
	end

	local frame = options.primary and accent or P.line

	surface.SetDrawColor(frame.r, frame.g, frame.b, (options.primary and 230 or (150 + 80 * hover)) * alpha)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	if (hover > 0.4 or options.primary) then
		S.Ticks(0, 0, width, height, Sc(6), ColorAlpha(accent, 255 * alpha))
	end

	local font = options.small and S.Font("label", 13, 700) or S.Font("button", 18, 700)
	local color = (options.danger or panel.bDanger) and P.bad or P.text

	draw.SimpleText(panel.label or "", font, math.Round(width * 0.5), math.Round(height * 0.5),
		ColorAlpha(color, (210 + 45 * hover) * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
