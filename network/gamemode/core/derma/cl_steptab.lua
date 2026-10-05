local TAB = {}

function TAB:Init()
	local Sc = NETWORK.util.Scale

	self:SetText("")
	self:SetCursor("hand")
	self:SetTall(Sc(46))

	self.label = ""
	self.index = 1
	self.bActive = false
	self.bDone = false

	self.hover = 0
	self.active = 0
	self.reveal = 0
	self.revealDelay = 0
	self.startTime = CurTime()
end

function TAB:Setup(index, label, icon)
	self.index = index
	self.label = NETWORK.util.Upper(label)

	if (icon) then
		self.icon = NETWORK.util.GetMaterial(icon, "smooth")
	end
end

function TAB:SetRevealDelay(delay)
	self.revealDelay = delay
end

function TAB:SetActive(bActive)
	self.bActive = tobool(bActive)
end

function TAB:SetDone(bDone)
	self.bDone = tobool(bDone)
end

function TAB:OnCursorEntered()
	NETWORK.sound.Hover()
end

function TAB:OnMousePressed(code)
	NETWORK.sound.Click()

	if (code == MOUSE_LEFT and self.DoClick) then
		self:DoClick(self)
	end
end

function TAB:Think()
	local util = NETWORK.util

	self.hover = util.Approach(self.hover, self:IsHovered() and 1 or 0, 9)
	self.active = util.Approach(self.active, self.bActive and 1 or 0, 9)
	self.reveal = util.EaseOut(util.Stagger(self.startTime, self.revealDelay, 0.6))
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
	local x = math.Round((1 - reveal) * -Sc(20))
	local bar = math.max(Sc(3), 2) + math.Round(active * Sc(3))

	surface.SetDrawColor(theme.plate.r, theme.plate.g, theme.plate.b,
		(85 + 55 * hover + 60 * active) * reveal)
	surface.DrawRect(x + bar, 0, width - bar, height)

	surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
		(70 + 100 * hover + 85 * active) * reveal)
	surface.DrawRect(x, 0, bar, height)

	if (active > 0.01) then
		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 26 * active * reveal)
		surface.DrawRect(x + bar, 0, math.Round((width - bar) * active), height)
	end

	local textColor = Color(
		Lerp(math.max(hover, active), theme.textDim.r, theme.text.r),
		Lerp(math.max(hover, active), theme.textDim.g, theme.text.g),
		Lerp(math.max(hover, active), theme.textDim.b, theme.text.b),
		255 * reveal
	)

	if (self.icon) then
		local iconSize = Sc(16)

		surface.SetDrawColor(255, 255, 255, (150 + 105 * math.max(hover, active)) * reveal)
		surface.SetMaterial(self.icon)
		surface.DrawTexturedRect(x + Sc(16), math.Round((height - iconSize) * 0.5), iconSize, iconSize)
	end

	util.DrawTextSpaced(self.label, "nwTab", x + Sc(44) + math.Round(active * Sc(5)),
		math.Round(height * 0.5), textColor, Sc(2), TEXT_ALIGN_CENTER)

	if (self.bDone) then
		local checkX = x + width - Sc(20)
		local checkY = math.Round(height * 0.5)

		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 210 * reveal)

		for offset = 0, math.max(Sc(2), 1) - 1 do
			surface.DrawLine(checkX - Sc(9), checkY + offset, checkX - Sc(4), checkY + Sc(5) + offset)
			surface.DrawLine(checkX - Sc(4), checkY + Sc(5) + offset, checkX + Sc(3), checkY - Sc(6) + offset)
		end
	end
end

vgui.Register("nwStepTab", TAB, "DButton")

local ACTION = {}

function ACTION:Init()
	local Sc = NETWORK.util.Scale

	self:SetText("")
	self:SetCursor("hand")
	self:SetTall(Sc(44))

	self.label = ""
	self.bPrimary = false

	self.hover = 0
	self.press = 0
	self.disabled = 0
end

function ACTION:SetLabel(text)
	self.label = NETWORK.util.Upper(text)
end

function ACTION:SetPrimary(bPrimary)
	self.bPrimary = tobool(bPrimary)
end

function ACTION:OnCursorEntered()
	if (self:GetDisabled()) then
		return
	end

	NETWORK.sound.Hover()
end

function ACTION:OnMousePressed(code)
	if (self:GetDisabled()) then
		NETWORK.sound.Play("hover3", 92, 0.5)

		return
	end

	self.press = 1

	NETWORK.sound.Click()

	if (code == MOUSE_LEFT and self.DoClick) then
		self:DoClick(self)
	end
end

function ACTION:Think()
	local util = NETWORK.util

	self.hover = util.Approach(self.hover, (self:IsHovered() and !self:GetDisabled()) and 1 or 0, 9)
	self.press = util.Approach(self.press, 0, 5)
	self.disabled = util.Approach(self.disabled, self:GetDisabled() and 1 or 0, 8)
end

function ACTION:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local hover = util.EaseInOut(self.hover)
	local disabled = self.disabled
	local alpha = 1 - disabled * 0.5
	local color = NETWORK.gui.DrawButtonFace(0, 0, width, height, hover, self.bPrimary, alpha,
		disabled > 0.5)

	if (self.press > 0.01) then
		local palette = NETWORK.theme.inv

		surface.SetDrawColor(palette.accentSoft.r, palette.accentSoft.g, palette.accentSoft.b,
			45 * self.press)
		surface.DrawRect(0, 0, width, height)
	end

	local textWidth = util.TextSpacedSize(self.label, "nwTab", Sc(3))

	util.DrawTextSpaced(self.label, "nwTab", math.Round((width - textWidth) * 0.5),
		math.Round(height * 0.5), color, Sc(3), TEXT_ALIGN_CENTER)
end

vgui.Register("nwActionButton", ACTION, "DButton")
