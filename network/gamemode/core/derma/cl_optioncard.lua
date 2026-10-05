local PANEL = {}

function PANEL:Init()
	self:SetText("")
	self:SetCursor("hand")

	self.title = ""
	self.description = ""
	self.lines = {}
	self.bSelected = false

	self.hover = 0
	self.select = 0
	self.outline = 0
	self.reveal = 0
	self.revealDelay = 0
	self.startTime = CurTime()
end

function PANEL:Setup(data)
	self.title = NETWORK.util.Upper(L(data.name))
	self.description = L(data.description or "")
	self.lines = data.items or {}
end

function PANEL:SetRevealDelay(delay)
	self.revealDelay = delay
end

function PANEL:SetSelected(bSelected)
	self.bSelected = tobool(bSelected)
end

function PANEL:OnCursorEntered()
	NETWORK.sound.Hover()
end

function PANEL:OnMousePressed(code)
	NETWORK.sound.Click()

	if (code == MOUSE_LEFT and self.DoClick) then
		self:DoClick(self)
	end
end

function PANEL:Think()
	local util = NETWORK.util
	local target = (self.bSelected or self:IsHovered()) and 1 or 0

	self.hover = util.Approach(self.hover, self:IsHovered() and 1 or 0, 8)
	self.select = util.Approach(self.select, self.bSelected and 1 or 0, 8)
	self.outline = util.Approach(self.outline, target, target > 0 and 4 or 12)
	self.reveal = util.EaseOut(util.Stagger(self.startTime, self.revealDelay, 0.7))
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local S = NETWORK.style
	local accent = S.Accent()
	local reveal = self.reveal

	if (reveal < 0.01) then
		return
	end

	local hover = util.EaseInOut(self.hover)
	local select = util.EaseInOut(self.select)
	local lift = math.Round(Sc(6) * math.max(hover, select))

	local shadowRoom = math.max(Sc(8), 4)
	local x = 0
	local y = -lift + math.Round((1 - reveal) * Sc(24))
	local radius = S.Radius("card")

	S.Card(x, y, width, height - shadowRoom, reveal, {
		blur = false,
		shadow = false,
		radius = radius,
		accent = select > 0.5 and accent or nil,
		glow = math.max(util.EaseInOut(self.outline) * 0.8, select)
	})

	if (select > 0.01) then
		draw.RoundedBox(radius, x, y, width, height - shadowRoom,
			ColorAlpha(accent, 26 * select * reveal))

		local rail = math.max(Sc(3), 2)
		local railHeight = math.Round((height - shadowRoom - Sc(28)) * select)

		draw.RoundedBox(math.floor(rail * 0.5), x + Sc(6),
			y + math.Round((height - shadowRoom - railHeight) * 0.5), rail, railHeight,
			ColorAlpha(accent, 240 * reveal))
	end

	util.DrawTextSpaced(self.title, "nwField", x + Sc(20), y + Sc(28),
		ColorAlpha(theme.text, 245 * reveal), Sc(3), TEXT_ALIGN_CENTER)

	if (self.description != "") then
		draw.SimpleText(self.description, "nwStatusDesc", x + Sc(20), y + Sc(50),
			ColorAlpha(theme.textDim, 215 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local lineY = y + Sc(78)
	local dot = math.max(Sc(5), 4)

	for i = 1, #self.lines do

		draw.RoundedBox(math.floor(dot * 0.5), x + Sc(20), lineY - math.floor(dot * 0.5), dot, dot,
			ColorAlpha(accent, (120 + 100 * select) * reveal))

		draw.SimpleText(self.lines[i], "nwHudSmall", x + Sc(34), lineY,
			ColorAlpha(theme.textDim, (185 + 60 * select) * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		lineY = lineY + Sc(21)
	end
end

vgui.Register("nwOptionCard", PANEL, "DButton")
