local GRADIENT_DOWN = Material("vgui/gradient-d")
local GRADIENT_UP = Material("vgui/gradient-u")

function NETWORK.gui.DrawSurface(x, y, width, height, alpha, options)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util

	alpha = alpha or 1
	options = options or {}

	if (width < 2 or height < 2 or alpha <= 0.004) then
		return
	end

	local radius = options.radius or math.max(Sc(8), 5)
	local base = options.base or Color(11, 12, 14)
	local lift = options.lift or 1

	if (options.panel) then
		util.DrawBlurRect(options.panel, x, y, width, height,
			(options.blur or 4) * alpha)
	end

	if (lift > 0) then
		local spread = math.Round(Sc(16) * lift)

		util.DrawGlow(x - spread, y - math.Round(spread * 0.6),
			width + spread * 2, height + spread * 2,
			Color(0, 0, 0, 120 * alpha * lift))
	end

	draw.RoundedBox(radius, x, y, width, height,
		Color(base.r, base.g, base.b, (options.baseAlpha or 222) * alpha))

	if (options.accent) then
		local bar = math.max(Sc(3), 2)
		local barHeight = math.Round(height * (options.accentSize or 0.55))

		draw.RoundedBox(bar, x, y + math.Round((height - barHeight) * 0.5), bar,
			barHeight, ColorAlpha(options.accent,
				(options.accentAlpha or 240) * alpha))
	end
end

function NETWORK.gui.DrawBlackGlass(panel, x, y, width, height, alpha, radius)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util

	alpha = alpha or 1
	radius = radius or Sc(14)

	if (alpha <= 0.005 or width < 2 or height < 2) then
		return
	end

	draw.RoundedBox(radius, x + Sc(2), y + Sc(4), width, height,
		Color(0, 0, 0, 80 * alpha))

	util.DrawBlurRounded(panel, x, y, width, height, radius, 5 * alpha)

	draw.RoundedBox(radius, x, y, width, height, Color(0, 0, 0, 200 * alpha))

	util.DrawRoundedBorder(x, y, width, height, radius, 1,
		Color(255, 255, 255, 28 * alpha))
end

function NETWORK.gui.DrawPlate(x, y, width, height, alpha, tint, options)
	options = options or {}

	NETWORK.gui.DrawSurface(x, y, width, height, alpha or 1, {
		base = options.base,
		baseAlpha = options.baseAlpha,
		accent = tint,
		lift = options.lift or 0.75
	})

	if (tint) then
		surface.SetDrawColor(tint.r, tint.g, tint.b,
			(options.tintAlpha or 14) * (alpha or 1))
		surface.DrawRect(x, y, width, height)
	end
end

function NETWORK.gui.DrawCorner(x, y, size, color, alpha)
	draw.NoTexture()
	surface.SetDrawColor(color.r, color.g, color.b, (color.a or 255) * (alpha or 1))
	surface.DrawPoly({
		{x = x, y = y},
		{x = x + size, y = y},
		{x = x, y = y + size}
	})
end

function NETWORK.gui.DrawButtonFace(x, y, width, height, hover, bPrimary, alpha,
	bDisabled)
	local palette = NETWORK.theme.inv
	local theme = NETWORK.theme

	alpha = alpha or 1

	NETWORK.gui.DrawSurface(x, y, width, height, alpha, {
		radius = math.max(NETWORK.util.Scale(6), 4),
		base = bPrimary and Color(28, 24, 18) or Color(16, 17, 19),
		baseAlpha = (bDisabled and 160 or 214) + 20 * hover,
		sheen = 14 + 16 * hover,
		edge = 16 + 20 * hover,
		lift = bDisabled and 0 or (0.35 + 0.4 * hover),
		accent = bPrimary and theme.combine or nil
	})

	if (bDisabled) then
		return ColorAlpha(palette.textFaint, 200 * alpha)
	end

	return Color(
		Lerp(hover, palette.textDim.r, palette.text.r),
		Lerp(hover, palette.textDim.g, palette.text.g),
		Lerp(hover, palette.textDim.b, palette.text.b),
		250 * alpha
	)
end

local TAB = {}

function TAB:Init()
	self:SetText("")
	self:SetCursor("hand")

	self.label = ""
	self.glyph = nil
	self.bActive = false
	self.bSecondary = false
	self.hover = 0
	self.active = 0
	self.reveal = 0
	self.revealDelay = 0
	self.startTime = CurTime()
	self.fontName = "nwSideNav"
end

function TAB:SetLabel(text)
	self.label = text or ""
end

function TAB:SetGlyph(glyph)
	self.glyph = glyph
end

function TAB:SetIcon(path)
	self.iconPath = path
	self.iconMaterial = path and NETWORK.util.GetMaterial(path, "smooth") or nil
end

function TAB:SetActive(bActive)
	self.bActive = tobool(bActive)
end

function TAB:SetSecondary(bSecondary)
	self.bSecondary = tobool(bSecondary)
end

function TAB:SetFontName(name)
	self.fontName = name or "nwSideNav"
end

function TAB:SetRevealDelay(delay)
	self.revealDelay = delay
end

function TAB:GetLabelWidth()
	surface.SetFont(self.fontName)

	return (surface.GetTextSize(self.label))
end

function TAB:OnCursorEntered()
	NETWORK.sound.TabHover()
end

function TAB:OnMousePressed(code)
	NETWORK.sound.TabPress()

	if (code == MOUSE_LEFT and self.DoClick) then
		self:DoClick(self)
	end
end

function TAB:Think()
	local util = NETWORK.util

	self.hover = util.Approach(self.hover, self:IsHovered() and 1 or 0, 10)
	self.active = util.Approach(self.active, self.bActive and 1 or 0, 10)
	self.reveal = util.EaseOut(util.Stagger(self.startTime, self.revealDelay, 0.4))
end

function NETWORK.gui.DrawGlyph(glyph, x, y, size, color)
	local Sc = NETWORK.util.Scale
	local half = math.Round(size * 0.5)
	local thin = math.max(Sc(2), 2)

	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)

	if (glyph == "grid") then
		local cell = math.floor((size - Sc(2)) * 0.5)

		surface.DrawRect(x, y, cell, cell)
		surface.DrawRect(x + cell + Sc(2), y, cell, cell)
		surface.DrawRect(x, y + cell + Sc(2), cell, cell)
		surface.DrawRect(x + cell + Sc(2), y + cell + Sc(2), cell, cell)
	elseif (glyph == "meal") then

		NETWORK.util.DrawCircle(x + half, y + math.Round(size * 0.45),
			math.Round(size * 0.32), color)

		surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
		surface.DrawRect(x + math.Round(size * 0.1), y + math.Round(size * 0.68),
			size - math.Round(size * 0.2), thin)
	elseif (glyph == "drop") then

		NETWORK.util.DrawCircle(x + half, y + math.Round(size * 0.62),
			math.Round(size * 0.3), color)

		draw.NoTexture()
		surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
		surface.DrawPoly({
			{x = x + half, y = y + math.Round(size * 0.08)},
			{x = x + half + math.Round(size * 0.3), y = y + math.Round(size * 0.66)},
			{x = x + half - math.Round(size * 0.3), y = y + math.Round(size * 0.66)}
		})
	elseif (glyph == "spark") then

		draw.NoTexture()
		surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
		surface.DrawPoly({
			{x = x + math.Round(size * 0.6), y = y},
			{x = x + math.Round(size * 0.2), y = y + math.Round(size * 0.55)},
			{x = x + half, y = y + math.Round(size * 0.55)},
			{x = x + math.Round(size * 0.4), y = y + size},
			{x = x + math.Round(size * 0.8), y = y + math.Round(size * 0.45)},
			{x = x + half, y = y + math.Round(size * 0.45)}
		})
	elseif (glyph == "cross") then

		surface.DrawRect(x + half - math.floor(thin * 0.5), y, thin, size)
		surface.DrawRect(x, y + half - math.floor(thin * 0.5), size, thin)
	elseif (glyph == "hand") then

		for index = 0, 3 do
			surface.DrawRect(x + index * math.Round(size * 0.26),
				y + math.Round(size * 0.12), math.max(thin, 2), math.Round(size * 0.5))
		end

		draw.RoundedBox(math.Round(size * 0.2), x, y + math.Round(size * 0.55),
			size, math.Round(size * 0.4), color)
	elseif (glyph == "cuffs") then

		NETWORK.util.DrawRing(x + math.Round(size * 0.3), y + half,
			math.Round(size * 0.26), thin, color, 16)
		NETWORK.util.DrawRing(x + math.Round(size * 0.7), y + half,
			math.Round(size * 0.26), thin, color, 16)
	elseif (glyph == "person") then
		NETWORK.util.DrawCircle(x + half, y + math.Round(size * 0.3), math.Round(size * 0.24), color)
		draw.RoundedBoxEx(math.Round(size * 0.25), x + math.Round(size * 0.12), y + math.Round(size * 0.58),
			size - math.Round(size * 0.24), math.Round(size * 0.42), color, true, true, false, false)
	elseif (glyph == "list") then
		for i = 0, 2 do
			surface.DrawRect(x, y + i * math.Round(size * 0.38), math.Round(size * 0.22), thin)
			surface.DrawRect(x + math.Round(size * 0.32), y + i * math.Round(size * 0.38),
				size - math.Round(size * 0.32), thin)
		end
	elseif (glyph == "group") then
		NETWORK.util.DrawCircle(x + math.Round(size * 0.3), y + math.Round(size * 0.32), math.Round(size * 0.18), color)
		NETWORK.util.DrawCircle(x + math.Round(size * 0.72), y + math.Round(size * 0.32), math.Round(size * 0.18), color)
		draw.RoundedBoxEx(math.Round(size * 0.2), x, y + math.Round(size * 0.58), size, math.Round(size * 0.42),
			color, true, true, false, false)
	elseif (glyph == "gear") then
		NETWORK.util.DrawRing(x + half, y + half, math.Round(size * 0.3), math.max(Sc(3), 2), color, 24, 1)

		for i = 0, 3 do
			local angle = math.rad(i * 90)
			local px = x + half + math.cos(angle) * size * 0.42
			local py = y + half + math.sin(angle) * size * 0.42

			surface.DrawRect(math.Round(px - thin), math.Round(py - thin), thin * 2, thin * 2)
		end
	elseif (glyph == "sliders") then
		for i = 0, 2 do
			local lineY = y + math.Round(size * 0.18) + i * math.Round(size * 0.32)
			local knob = x + math.Round(size * (0.2 + (i % 2) * 0.5))

			surface.DrawRect(x, lineY, size, 1)
			surface.DrawRect(knob, lineY - Sc(3), Sc(4), Sc(7))
		end
	elseif (glyph == "shield") then
		draw.RoundedBoxEx(math.Round(size * 0.3), x + math.Round(size * 0.12), y, size - math.Round(size * 0.24),
			size, color, false, false, true, true)
	elseif (glyph == "back") then
		NETWORK.util.DrawThickLine(x + math.Round(size * 0.15), y + half, x + size, y + half, thin, color)
		NETWORK.util.DrawThickLine(x + math.Round(size * 0.15), y + half, x + half, y + math.Round(size * 0.15), thin, color)
		NETWORK.util.DrawThickLine(x + math.Round(size * 0.15), y + half, x + half, y + size - math.Round(size * 0.15), thin, color)
	elseif (glyph == "eye") then
		NETWORK.util.DrawRing(x + half, y + half, math.Round(size * 0.42), math.max(Sc(2), 1), color, 24, 1)
		NETWORK.util.DrawCircle(x + half, y + half, math.Round(size * 0.18), color)
	elseif (glyph == "plus") then
		surface.DrawRect(x + half - thin * 0.5, y + Sc(1), thin, size - Sc(2))
		surface.DrawRect(x + Sc(1), y + half - thin * 0.5, size - Sc(2), thin)
	elseif (glyph == "minus") then
		surface.DrawRect(x + Sc(1), y + half - thin * 0.5, size - Sc(2), thin)
	elseif (glyph == "down") then
		surface.DrawRect(x + half - thin * 0.5, y, thin, math.Round(size * 0.62))
		NETWORK.util.DrawThickLine(x + math.Round(size * 0.2), y + math.Round(size * 0.42), x + half, y + math.Round(size * 0.7), thin, color)
		NETWORK.util.DrawThickLine(x + size - math.Round(size * 0.2), y + math.Round(size * 0.42), x + half, y + math.Round(size * 0.7), thin, color)
		surface.DrawRect(x, y + size - thin, size, thin)
	elseif (glyph == "up") then
		surface.DrawRect(x + half - thin * 0.5, y + math.Round(size * 0.3), thin, math.Round(size * 0.55))
		NETWORK.util.DrawThickLine(x + math.Round(size * 0.2), y + math.Round(size * 0.5), x + half, y + math.Round(size * 0.2), thin, color)
		NETWORK.util.DrawThickLine(x + size - math.Round(size * 0.2), y + math.Round(size * 0.5), x + half, y + math.Round(size * 0.2), thin, color)
	elseif (glyph == "chevron") then
		NETWORK.util.DrawThickLine(x + math.Round(size * 0.3), y + math.Round(size * 0.2), x + math.Round(size * 0.7), y + half, thin, color)
		NETWORK.util.DrawThickLine(x + math.Round(size * 0.3), y + size - math.Round(size * 0.2), x + math.Round(size * 0.7), y + half, thin, color)
	elseif (glyph == "split") then
		surface.DrawRect(x, y + Sc(2), math.Round(size * 0.42), size - Sc(4))
		surface.DrawRect(x + size - math.Round(size * 0.42), y + Sc(2), math.Round(size * 0.42), size - Sc(4))
	elseif (glyph == "weight") then
		draw.RoundedBoxEx(math.Round(size * 0.15), x, y + math.Round(size * 0.3), size, size - math.Round(size * 0.3),
			color, false, false, true, true)
		NETWORK.util.DrawRing(x + half, y + math.Round(size * 0.2), math.Round(size * 0.16), thin, color, 16, 1)
	elseif (glyph == "helmet") then
		draw.RoundedBoxEx(math.Round(size * 0.4), x + math.Round(size * 0.08), y + math.Round(size * 0.1),
			size - math.Round(size * 0.16), math.Round(size * 0.6), color, true, true, false, false)
		surface.DrawRect(x, y + math.Round(size * 0.72), size, math.max(math.Round(size * 0.14), 2))
	elseif (glyph == "hat") then
		draw.RoundedBoxEx(math.Round(size * 0.35), x + math.Round(size * 0.16), y + math.Round(size * 0.18),
			size - math.Round(size * 0.32), math.Round(size * 0.5), color, true, true, false, false)
		surface.DrawRect(x, y + math.Round(size * 0.62), size, math.max(math.Round(size * 0.12), 2))
	elseif (glyph == "glasses") then
		local lens = math.Round(size * 0.26)

		NETWORK.util.DrawRing(x + lens, y + half, lens, thin, color, 20, 1)
		NETWORK.util.DrawRing(x + size - lens, y + half, lens, thin, color, 20, 1)
		surface.DrawRect(x + lens + math.Round(lens * 0.6), y + half - math.Round(thin * 0.5),
			size - (lens + math.Round(lens * 0.6)) * 2, thin)
	elseif (glyph == "mask") then
		draw.RoundedBox(math.Round(size * 0.25), x + math.Round(size * 0.08), y + math.Round(size * 0.28),
			size - math.Round(size * 0.16), math.Round(size * 0.48), color)
		NETWORK.util.DrawCircle(x + half, y + math.Round(size * 0.78), math.Round(size * 0.16), color)
	elseif (glyph == "shirt") then
		surface.DrawRect(x + math.Round(size * 0.28), y + math.Round(size * 0.12),
			size - math.Round(size * 0.56), math.Round(size * 0.14))
		draw.RoundedBoxEx(math.Round(size * 0.12), x + math.Round(size * 0.2), y + math.Round(size * 0.22),
			size - math.Round(size * 0.4), size - math.Round(size * 0.22), color, false, false, true, true)
		surface.DrawRect(x, y + math.Round(size * 0.22), math.Round(size * 0.16), math.Round(size * 0.4))
		surface.DrawRect(x + size - math.Round(size * 0.16), y + math.Round(size * 0.22),
			math.Round(size * 0.16), math.Round(size * 0.4))
	elseif (glyph == "vest") then
		draw.RoundedBoxEx(math.Round(size * 0.12), x + math.Round(size * 0.16), y + math.Round(size * 0.1),
			size - math.Round(size * 0.32), size - math.Round(size * 0.14), color, false, false, true, true)
		surface.SetDrawColor(0, 0, 0, 160)
		surface.DrawRect(x + half - math.max(math.Round(thin * 0.5), 1), y + math.Round(size * 0.2),
			thin, size - math.Round(size * 0.34))
		surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	elseif (glyph == "gloves") then
		draw.RoundedBoxEx(math.Round(size * 0.28), x + math.Round(size * 0.2), y,
			size - math.Round(size * 0.4), math.Round(size * 0.66), color, true, true, false, false)
		draw.RoundedBox(math.Round(size * 0.12), x + math.Round(size * 0.62), y + math.Round(size * 0.3),
			math.Round(size * 0.3), math.Round(size * 0.22), color)
		surface.DrawRect(x + math.Round(size * 0.2), y + math.Round(size * 0.7),
			size - math.Round(size * 0.4), math.Round(size * 0.18))
	elseif (glyph == "pants") then
		surface.DrawRect(x + math.Round(size * 0.18), y, size - math.Round(size * 0.36),
			math.Round(size * 0.24))
		surface.DrawRect(x + math.Round(size * 0.18), y + math.Round(size * 0.24),
			math.Round(size * 0.26), size - math.Round(size * 0.24))
		surface.DrawRect(x + size - math.Round(size * 0.18) - math.Round(size * 0.26),
			y + math.Round(size * 0.24), math.Round(size * 0.26), size - math.Round(size * 0.24))
	elseif (glyph == "boot") then
		surface.DrawRect(x + math.Round(size * 0.2), y, math.Round(size * 0.3), size)
		draw.RoundedBoxEx(math.Round(size * 0.15), x + math.Round(size * 0.2), y + math.Round(size * 0.66),
			size - math.Round(size * 0.24), math.Round(size * 0.34), color, false, true, false, true)
	elseif (glyph == "backpack") then
		draw.RoundedBox(math.Round(size * 0.2), x + math.Round(size * 0.1), y + math.Round(size * 0.08),
			size - math.Round(size * 0.2), size - math.Round(size * 0.12), color)
		surface.SetDrawColor(0, 0, 0, 160)
		surface.DrawRect(x + math.Round(size * 0.1), y + math.Round(size * 0.52), size - math.Round(size * 0.2),
			math.max(math.Round(size * 0.08), 1))
		surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
		surface.DrawRect(x + math.Round(size * 0.3), y, math.Round(size * 0.12), math.Round(size * 0.12))
		surface.DrawRect(x + size - math.Round(size * 0.42), y, math.Round(size * 0.12), math.Round(size * 0.12))
	elseif (glyph == "radio") then
		draw.RoundedBox(math.Round(size * 0.12), x + math.Round(size * 0.2), y + math.Round(size * 0.3),
			size - math.Round(size * 0.4), size - math.Round(size * 0.3), color)
		NETWORK.util.DrawThickLine(x + math.Round(size * 0.3), y + math.Round(size * 0.3),
			x + math.Round(size * 0.66), y, thin, color)
	elseif (glyph == "watch") then
		surface.DrawRect(x + math.Round(size * 0.34), y, size - math.Round(size * 0.68), size)
		NETWORK.util.DrawCircle(x + half, y + half, math.Round(size * 0.34), color)
		surface.SetDrawColor(0, 0, 0, 200)
		NETWORK.util.DrawCircle(x + half, y + half, math.Round(size * 0.18), Color(0, 0, 0, 190))
		surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	elseif (glyph == "light") then
		draw.RoundedBox(math.Round(size * 0.1), x, y + math.Round(size * 0.34),
			math.Round(size * 0.52), math.Round(size * 0.32), color)
		draw.NoTexture()
		surface.DrawPoly({
			{x = x + math.Round(size * 0.52), y = y + math.Round(size * 0.34)},
			{x = x + size, y = y + math.Round(size * 0.14)},
			{x = x + size, y = y + math.Round(size * 0.86)},
			{x = x + math.Round(size * 0.52), y = y + math.Round(size * 0.66)}
		})
	elseif (glyph == "rifle") then
		surface.DrawRect(x, y + math.Round(size * 0.38), size, math.Round(size * 0.16))
		surface.DrawRect(x + math.Round(size * 0.66), y + math.Round(size * 0.54),
			math.Round(size * 0.14), math.Round(size * 0.3))
		surface.DrawRect(x + math.Round(size * 0.3), y + math.Round(size * 0.54),
			math.Round(size * 0.12), math.Round(size * 0.22))
		surface.DrawRect(x + math.Round(size * 0.38), y + math.Round(size * 0.24),
			math.Round(size * 0.1), math.Round(size * 0.14))
	elseif (glyph == "pistol") then
		surface.DrawRect(x + math.Round(size * 0.1), y + math.Round(size * 0.28), size - math.Round(size * 0.2),
			math.Round(size * 0.2))
		surface.DrawRect(x + math.Round(size * 0.52), y + math.Round(size * 0.48),
			math.Round(size * 0.18), math.Round(size * 0.34))
	elseif (glyph == "knife") then
		NETWORK.util.DrawThickLine(x + math.Round(size * 0.14), y + size - math.Round(size * 0.14),
			x + size - math.Round(size * 0.2), y + math.Round(size * 0.2), thin * 2, color)
		NETWORK.util.DrawThickLine(x + math.Round(size * 0.1), y + size - math.Round(size * 0.32),
			x + math.Round(size * 0.32), y + size - math.Round(size * 0.1), thin, color)
	elseif (glyph == "stack") then
		local layer = math.max(math.Round(size * 0.22), 2)
		local gapY = math.max(math.Round(size * 0.1), 1)

		for i = 0, 2 do
			local inset = (2 - i) * math.Round(size * 0.12)

			surface.DrawRect(x + inset, y + i * (layer + gapY), size - inset * 2, layer)
		end
	elseif (glyph == "coin") then
		NETWORK.util.DrawRing(x + half, y + half, math.Round(size * 0.42), thin, color, 24, 1)
		NETWORK.util.DrawCircle(x + half, y + half, math.Round(size * 0.16), color)
	else
		NETWORK.util.DrawCircle(x + half, y + half, math.Round(size * 0.22), color)
	end
end

function TAB:GetPreferredWidth()
	local Sc = NETWORK.util.Scale

	return self:GetLabelWidth() + Sc(28) + (self.iconMaterial and Sc(24) or 0)
end

function TAB:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local reveal = self.reveal

	if (reveal < 0.01) then
		return
	end

	local hover = util.EaseInOut(self.hover)
	local active = util.EaseInOut(self.active)
	local accent = theme.combine
	local radius = math.max(Sc(6), 4)
	local y = math.Round((1 - reveal) * -Sc(6))

	if (hover > 0.01) then
		draw.RoundedBox(radius, 0, y, width, height,
			Color(255, 255, 255, 12 * hover * (1 - active) * reveal))
	end

	if (active > 0.01) then
		draw.RoundedBox(radius, 0, y, width, height,
			ColorAlpha(accent, 34 * active * reveal))

		util.DrawRoundedBorder(0, y, width, height, radius, math.max(Sc(1), 1),
			ColorAlpha(accent, 200 * active * reveal))
	end

	local lit = math.max(hover, active)
	local dimColor = self.bSecondary and theme.textFaint or theme.textDim
	local color = Color(
		Lerp(lit, dimColor.r, theme.text.r),
		Lerp(lit, dimColor.g, theme.text.g),
		Lerp(lit, dimColor.b, theme.text.b),
		255 * reveal
	)

	local material = self.iconMaterial

	if (material and !material:IsError()) then

		local iconSize = Sc(16)
		local iconX = Sc(14)

		surface.SetDrawColor(color.r, color.g, color.b, color.a)
		surface.SetMaterial(material)
		surface.DrawTexturedRect(iconX, y + math.Round((height - iconSize) * 0.5),
			iconSize, iconSize)

		draw.SimpleText(self.label, self.fontName, iconX + iconSize + Sc(8),
			y + math.Round(height * 0.5), color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	draw.SimpleText(self.label, self.fontName, math.Round(width * 0.5),
		y + math.Round(height * 0.5), color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("nwTabButton", TAB, "DButton")

local ROW = {}

function ROW:Init()
	self.title = ""
	self.description = ""
	self.hover = 0
	self.reveal = 0
	self.revealDelay = 0
	self.startTime = CurTime()
end

function ROW:Setup(title, description)
	self.title = NETWORK.util.Upper(title)
	self.description = description or ""
end

function ROW:SetRevealDelay(delay)
	self.revealDelay = delay
end

function ROW:SetControl(panel)
	self.control = panel
end

function ROW:Think()
	local util = NETWORK.util

	self.hover = util.Approach(self.hover, self:IsHovered() and 1 or 0, 9)
	self.reveal = util.EaseOut(util.Stagger(self.startTime, self.revealDelay, 0.55))

	if (IsValid(self.control)) then
		self.control:SetAlpha(math.Round(self.reveal * 255))
	end
end

function ROW:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local reveal = self.reveal

	if (reveal < 0.01) then
		return
	end

	local hover = util.EaseInOut(self.hover)
	local x = math.Round((1 - reveal) * Sc(20))

	surface.SetDrawColor(theme.plate.r, theme.plate.g, theme.plate.b, (90 + 55 * hover) * reveal)
	surface.DrawRect(x, 0, width, height)

	surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, (80 + 130 * hover) * reveal)
	surface.DrawRect(x, 0, math.max(Sc(2), 1), height)

	util.DrawTextSpaced(self.title, "nwField", x + Sc(20), math.Round(height * 0.5) - Sc(9),
		ColorAlpha(theme.text, (220 + 35 * hover) * reveal), Sc(2), TEXT_ALIGN_CENTER)

	draw.SimpleText(self.description, "nwHudSmall", x + Sc(20), math.Round(height * 0.5) + Sc(12),
		ColorAlpha(theme.textDim, (150 + 60 * hover) * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("nwSettingRow", ROW, "DPanel")

local TOGGLE = {}

function TOGGLE:Init()
	self:SetText("")
	self:SetCursor("hand")

	self.state = 0
	self.hover = 0
	self.convar = nil
end

function TOGGLE:SetConVar(name)
	self.convar = name
	self.state = self:GetState() and 1 or 0
end

function TOGGLE:GetState()
	if (!self.convar) then
		return false
	end

	local convar = GetConVar(self.convar)

	return convar and convar:GetBool() or false
end

function TOGGLE:OnCursorEntered()
	NETWORK.sound.Hover()
end

function TOGGLE:OnMousePressed(code)
	if (code != MOUSE_LEFT or !self.convar) then
		return
	end

	RunConsoleCommand(self.convar, self:GetState() and "0" or "1")
	NETWORK.sound.Click()
end

function TOGGLE:Think()
	local util = NETWORK.util

	self.hover = util.Approach(self.hover, self:IsHovered() and 1 or 0, 10)
	self.state = util.Approach(self.state, self:GetState() and 1 or 0, 12)
end

function TOGGLE:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local state = util.EaseInOut(self.state)
	local hover = util.EaseInOut(self.hover)
	local trackHeight = Sc(24)
	local trackWidth = Sc(58)
	local trackX = width - trackWidth
	local trackY = math.Round((height - trackHeight) * 0.5)
	local radius = trackHeight * 0.5

	util.DrawCircle(trackX + radius, trackY + radius, radius,
		ColorAlpha(theme.plateBright, 220))
	util.DrawCircle(trackX + trackWidth - radius, trackY + radius, radius,
		ColorAlpha(theme.plateBright, 220))

	surface.SetDrawColor(theme.plateBright.r, theme.plateBright.g, theme.plateBright.b, 220)
	surface.DrawRect(trackX + radius, trackY, trackWidth - trackHeight, trackHeight)

	if (state > 0.01) then
		local fill = ColorAlpha(theme.accentDeep, 235 * state)

		util.DrawCircle(trackX + radius, trackY + radius, radius, fill)
		util.DrawCircle(trackX + trackWidth - radius, trackY + radius, radius, fill)

		surface.SetDrawColor(fill.r, fill.g, fill.b, fill.a)
		surface.DrawRect(trackX + radius, trackY, trackWidth - trackHeight, trackHeight)
	end

	local knobX = trackX + radius + (trackWidth - trackHeight) * state
	local knobColor = Color(
		Lerp(state, theme.textDim.r, theme.accentSoft.r),
		Lerp(state, theme.textDim.g, theme.accentSoft.g),
		Lerp(state, theme.textDim.b, theme.accentSoft.b),
		255
	)

	util.DrawCircle(knobX, trackY + radius, radius - Sc(4) + Sc(1) * hover, knobColor)
	util.DrawRing(trackX + radius, trackY + radius, radius, math.max(Sc(1), 1),
		ColorAlpha(theme.line, 30 + 40 * hover), 32, 1)
end

vgui.Register("nwToggle", TOGGLE, "DButton")

local CHOICE = {}

function CHOICE:Init()
	self:SetText("")
	self:SetCursor("hand")

	self.options = {}
	self.hover = 0
	self.shift = 0
	self.convar = nil
end

function CHOICE:SetConVar(name)
	self.convar = name
end

function CHOICE:SetOptions(options)
	self.options = options
end

function CHOICE:GetIndex()
	if (!self.convar) then
		return 1
	end

	local convar = GetConVar(self.convar)
	local value = convar and convar:GetString() or ""

	for i = 1, #self.options do
		if (self.options[i].value == value) then
			return i
		end
	end

	return 1
end

function CHOICE:Cycle(step)
	if (!self.convar or #self.options == 0) then
		return
	end

	local index = (self:GetIndex() - 1 + step) % #self.options + 1

	RunConsoleCommand(self.convar, self.options[index].value)

	self.shift = step

	NETWORK.sound.Click()
end

function CHOICE:OnCursorEntered()
	NETWORK.sound.Hover()
end

function CHOICE:OnMousePressed(code)
	self:Cycle(code == MOUSE_RIGHT and -1 or 1)
end

function CHOICE:Think()
	local util = NETWORK.util

	self.hover = util.Approach(self.hover, self:IsHovered() and 1 or 0, 10)
	self.shift = util.Approach(self.shift, 0, 9)
end

function CHOICE:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local hover = util.EaseInOut(self.hover)
	local option = self.options[self:GetIndex()]
	local label = option and util.Upper(L(option.label)) or "-"
	local cut = Sc(10)

	util.DrawAngledBox(0, 0, width, height, cut, ColorAlpha(theme.plateBright, 160 + 60 * hover))
	util.DrawAngledOutline(0, 0, width, height, cut, math.max(Sc(2), 1),
		ColorAlpha(theme.accent, 60 + 120 * hover))

	local textWidth = util.TextSpacedSize(label, "nwTab", Sc(3))
	local offset = math.Round(self.shift * Sc(10))

	util.DrawTextSpaced(label, "nwTab", math.Round((width - textWidth) * 0.5) - offset,
		math.Round(height * 0.5), ColorAlpha(theme.text, 245), Sc(3), TEXT_ALIGN_CENTER)

	local arrow = ColorAlpha(theme.accent, 120 + 135 * hover)

	util.DrawThickLine(Sc(20), math.Round(height * 0.5) - Sc(5), Sc(14),
		math.Round(height * 0.5), math.max(Sc(2), 1), arrow)
	util.DrawThickLine(Sc(14), math.Round(height * 0.5), Sc(20),
		math.Round(height * 0.5) + Sc(5), math.max(Sc(2), 1), arrow)

	util.DrawThickLine(width - Sc(20), math.Round(height * 0.5) - Sc(5), width - Sc(14),
		math.Round(height * 0.5), math.max(Sc(2), 1), arrow)
	util.DrawThickLine(width - Sc(14), math.Round(height * 0.5), width - Sc(20),
		math.Round(height * 0.5) + Sc(5), math.max(Sc(2), 1), arrow)
end

vgui.Register("nwChoice", CHOICE, "DButton")

NETWORK.gui.modelBudget = NETWORK.gui.modelBudget or {frame = -1, used = 0, limit = 20}

function NETWORK.gui.TakeModelBudget(panel)
	local budget = NETWORK.gui.modelBudget
	local frame = FrameNumber()

	if (budget.frame != frame) then
		budget.frame = frame
		budget.used = 0

		if (FrameTime() > 1 / 40) then
			budget.limit = math.max(budget.limit - 1, 10)
		elseif (FrameTime() < 1 / 90) then
			budget.limit = math.min(budget.limit + 1, 28)
		end
	end

	if (panel.nwModelSkipped) then
		panel.nwModelSkipped = nil
		budget.used = budget.used + 1

		return true
	end

	if (budget.used >= budget.limit) then
		panel.nwModelSkipped = true

		return false
	end

	budget.used = budget.used + 1

	return true
end

function NETWORK.gui.DrawHoloScreen(panel, x, y, width, height, alpha, color)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local time = RealTime()

	color = color or Color(96, 226, 236)

	for index = 1, 6 do
		local spread = index * Sc(4)

		surface.SetDrawColor(color.r, color.g, color.b, (26 - index * 4) * alpha)
		surface.DrawRect(x - spread, y - spread, width + spread * 2, height + spread * 2)
	end

	util.DrawBlurRounded(panel, x, y, width, height, 2, 4 * alpha)

	surface.SetDrawColor(math.Round(color.r * 0.08), math.Round(color.g * 0.16),
		math.Round(color.b * 0.18), 225 * alpha)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(color.r, color.g, color.b, 34 * alpha)
	surface.DrawRect(x, y, width, height)

	util.DrawVGradient(x, y, width, math.Round(height * 0.35), ColorAlpha(color, 44 * alpha),
		ColorAlpha(color, 0))
	util.DrawVGradient(x, y + math.Round(height * 0.75), width, math.Round(height * 0.25),
		ColorAlpha(color, 0), ColorAlpha(color, 26 * alpha))

	util.DrawScanlines(x, y, width, height, 40 * alpha, math.max(Sc(3), 3))

	local sweep = y + ((time * 0.12) % 1) * height

	util.DrawVGradient(x, math.Round(sweep) - Sc(24), width, Sc(24), ColorAlpha(color, 0),
		ColorAlpha(color, 30 * alpha))

	surface.SetDrawColor(color.r, color.g, color.b, 200 * alpha)
	surface.DrawOutlinedRect(x, y, width, height, math.max(Sc(1), 1))

	local tick = Sc(18)
	local thick = math.max(Sc(2), 2)

	surface.DrawRect(x, y, tick, thick)
	surface.DrawRect(x, y, thick, tick)
	surface.DrawRect(x + width - tick, y, tick, thick)
	surface.DrawRect(x + width - thick, y, thick, tick)
	surface.DrawRect(x, y + height - thick, tick, thick)
	surface.DrawRect(x, y + height - tick, thick, tick)
	surface.DrawRect(x + width - tick, y + height - thick, tick, thick)
	surface.DrawRect(x + width - thick, y + height - tick, thick, tick)
end
