local PANEL = {}

PANEL.hoverScale = 0.16
PANEL.hoverShift = 10

function PANEL:Init()
	self:SetText("")
	self:SetCursor("hand")
	self:NoClipping(true)

	self.label = ""
	self.hover = 0
	self.press = 0
	self.exit = 0
	self.bExiting = false
	self.revealDelay = 0
	self.startTime = CurTime()
	self.bDanger = false
	self.align = "right"
	self.fontName = "nwMenuItem"
	self.bActive = false
end

function PANEL:SetActive(bActive)
	self.bActive = tobool(bActive)
end

function PANEL:SetAlign(align)
	self.align = align or "right"
end

function PANEL:SetFontName(name)
	self.fontName = name or "nwMenuItem"
end

function PANEL:SetLabel(text)
	self.label = NETWORK.util.Upper(text or "")
end

function PANEL:SetDanger(bDanger)
	self.bDanger = tobool(bDanger)
end

function PANEL:SetRevealDelay(delay)
	self.revealDelay = delay
end

function PANEL:SetExiting(bExiting)
	self.bExiting = tobool(bExiting)

	self:SetMouseInputEnabled(false)
end

function PANEL:OnCursorEntered()
	if (self:GetDisabled() or self.bExiting) then
		return
	end

	NETWORK.sound.MenuHover()
end

function PANEL:OnMousePressed(code)
	if (self:GetDisabled() or self.bExiting) then
		return
	end

	self.press = 1

	NETWORK.sound.MenuPress()

	if (code == MOUSE_LEFT and self.DoClick) then
		self:DoClick(self)
	end
end

function PANEL:Think()
	local util = NETWORK.util
	local bHovered = (self:IsHovered() or self.bActive) and !self:GetDisabled() and
		!self.bExiting

	self.hover = util.Approach(self.hover, bHovered and 1 or 0,
		bHovered and 7 or 5)
	self.press = util.Approach(self.press, 0, 5)
	self.exit = util.Approach(self.exit, self.bExiting and 1 or 0, 5)
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local reveal = util.EaseOut(util.Stagger(self.startTime, self.revealDelay or 0, 0.85))
	local exit = util.EaseInOut(self.exit)
	local alpha = reveal * (1 - exit)

	if (alpha < 0.01) then
		return
	end

	local hover = util.EaseInOut(self.hover)

	local scale = 1 + PANEL.hoverScale * hover - 0.05 * util.EaseOut(self.press)
	local shift = math.Round(Sc(PANEL.hoverShift) * hover +
		(1 - reveal) * Sc(30) + exit * Sc(44))
	local align = self.align
	local anchorX = width + shift
	local textAlign = TEXT_ALIGN_RIGHT

	if (align == "center") then
		anchorX = math.Round(width * 0.5)
		textAlign = TEXT_ALIGN_CENTER
	elseif (align == "left") then
		anchorX = shift
		textAlign = TEXT_ALIGN_LEFT
	end

	local anchorY = math.Round(height * 0.5)
	local screenX, screenY = self:LocalToScreen(anchorX, anchorY)

	local matrix = Matrix()

	matrix:Translate(Vector(screenX, screenY, 0))
	matrix:Scale(Vector(scale, scale, 1))
	matrix:Translate(Vector(-screenX, -screenY, 0))

	cam.PushModelMatrix(matrix, true)

	local base = self.bDanger and theme.danger or theme.text
	local target = self.bDanger and theme.danger or theme.combine
	local tint = Color(
		Lerp(hover, base.r, target.r),
		Lerp(hover, base.g, target.g),
		Lerp(hover, base.b, target.b)
	)
	local color = ColorAlpha(tint, (150 + 105 * hover) * alpha)

	draw.SimpleText(self.label, self.fontName, anchorX + 1, anchorY + 1,
		ColorAlpha(color_black, 150 * alpha), textAlign, TEXT_ALIGN_CENTER)

	draw.SimpleText(self.label, self.fontName, anchorX, anchorY,
		color, textAlign, TEXT_ALIGN_CENTER)

	cam.PopModelMatrix()

	if (hover > 0.01 and align == "right") then
		local mark = math.Round(Sc(14) * hover)

		surface.SetDrawColor(tint.r, tint.g, tint.b, 235 * hover * alpha)
		surface.DrawRect(width + shift + Sc(10), anchorY - math.max(Sc(1), 1),
			mark, math.max(Sc(2), 2))
	end
end

vgui.Register("nwMenuButton", PANEL, "DButton")
