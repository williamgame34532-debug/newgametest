local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self:SetTall(Sc(54))
	self:SetCursor("hand")

	self.min = 0
	self.max = 1
	self.value = 0.5
	self.display = 0.5
	self.hover = 0
	self.bDragging = false
	self.suffix = ""
end

function PANEL:SetRange(min, max)
	self.min = min
	self.max = max
end

function PANEL:SetSuffix(suffix)
	self.suffix = suffix
end

function PANEL:SetValue(value)
	local previous = self.value

	self.value = math.Clamp(math.Round(value), self.min, self.max)

	if (previous != self.value and self.OnValueChanged) then
		self:OnValueChanged(self.value)
	end
end

function PANEL:GetValue()
	return self.value
end

function PANEL:GetFraction()
	return (self.value - self.min) / math.max(self.max - self.min, 1)
end

function PANEL:UpdateFromCursor()
	local x = self:CursorPos()
	local Sc = NETWORK.util.Scale
	local track = self:GetWide() - Sc(20)
	local fraction = math.Clamp((x - Sc(10)) / math.max(track, 1), 0, 1)

	self:SetValue(self.min + fraction * (self.max - self.min))
end

function PANEL:OnMousePressed()
	self.bDragging = true

	self:UpdateFromCursor()
	self:MouseCapture(true)

	NETWORK.sound.Hover()
end

function PANEL:OnMouseReleased()
	self.bDragging = false

	self:MouseCapture(false)
end

function PANEL:Think()
	local util = NETWORK.util

	if (self.bDragging) then
		self:UpdateFromCursor()
	end

	self.hover = util.Approach(self.hover, (self:IsHovered() or self.bDragging) and 1 or 0, 9)
	self.display = util.Approach(self.display, self:GetFraction(), 12)
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local hover = util.EaseInOut(self.hover)
	local trackX = Sc(10)
	local trackWidth = width - Sc(20)
	local trackY = math.Round(height * 0.62)
	local knobX = trackX + trackWidth * self.display

	surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 40)
	surface.DrawRect(trackX, trackY, trackWidth, math.max(Sc(2), 1))

	surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 180 + 60 * hover)
	surface.DrawRect(trackX, trackY, math.Round(trackWidth * self.display), math.max(Sc(2), 1))

	for i = 0, 10 do
		local tickX = trackX + trackWidth * (i / 10)
		local tall = i % 5 == 0 and Sc(9) or Sc(5)

		surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 45)
		surface.DrawRect(math.Round(tickX), trackY + Sc(6), math.max(Sc(1), 1), tall)
	end

	util.DrawCircle(knobX, trackY + Sc(1), Sc(9) + Sc(3) * hover,
		ColorAlpha(theme.background, 245))
	util.DrawRing(knobX, trackY + Sc(1), Sc(9) + Sc(3) * hover, math.max(Sc(2), 1),
		ColorAlpha(theme.accent, 255), 32, 1)
	util.DrawCircle(knobX, trackY + Sc(1), Sc(3) + Sc(2) * hover, ColorAlpha(theme.accentSoft, 255))

	local text = self.value .. self.suffix

	draw.SimpleText(text, "nwField", math.Round(knobX), trackY - Sc(22),
		ColorAlpha(theme.text, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(self.min .. self.suffix, "nwHudSmall", trackX, trackY - Sc(20),
		ColorAlpha(theme.textFaint, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(self.max .. self.suffix, "nwHudSmall", trackX + trackWidth, trackY - Sc(20),
		ColorAlpha(theme.textFaint, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

vgui.Register("nwSlider", PANEL, "DPanel")
