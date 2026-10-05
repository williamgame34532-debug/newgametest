local PANEL = {}

function PANEL:Init()
	self:SetText("")
	self:SetCursor("hand")

	self.bSelected = false
	self.hover = 0
	self.select = 0
	self.outline = 0
	self.reveal = 0
	self.revealDelay = 0
	self.startTime = CurTime()
end

function PANEL:SetModelPath(path)
	self.path = path

	if (IsValid(self.model)) then
		self.model:Remove()
	end

	self.model = self:Add("DModelPanel")
	self.model:Dock(FILL)
	self.model:DockMargin(2, 2, 2, 2)
	self.model:SetModel(path)
	self.model:SetFOV(36)
	self.model:SetMouseInputEnabled(false)
	self.model:SetAnimated(false)
	self.model.LayoutEntity = function() end

	local entity = self.model:GetEntity()

	if (IsValid(entity)) then
		local mins, maxs = entity:GetRenderBounds()
		local center = (mins + maxs) * 0.5
		local size = maxs.z - mins.z

		entity:SetAngles(Angle(0, 30, 0))

		self.model:SetLookAt(Vector(center.x, center.y, maxs.z - size * 0.14))
		self.model:SetCamPos(Vector(size * 0.42, size * 0.24, maxs.z - size * 0.06))
	end
end

function PANEL:SetSelected(bSelected)
	self.bSelected = tobool(bSelected)
end

function PANEL:SetRevealDelay(delay)
	self.revealDelay = delay
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
	local bLit = self:IsHovered() or self.bSelected

	self.hover = util.Approach(self.hover, self:IsHovered() and 1 or 0, 9)
	self.select = util.Approach(self.select, self.bSelected and 1 or 0, 8)
	self.outline = util.Approach(self.outline, bLit and 1 or 0, bLit and 5 or 12)
	self.reveal = util.EaseOut(util.Stagger(self.startTime, self.revealDelay, 0.6))

	if (IsValid(self.model)) then
		self.model:SetAlpha(math.Round(self.reveal * 255))
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local reveal = self.reveal

	if (reveal < 0.01) then
		return
	end

	local hover = util.EaseInOut(math.max(self.hover, self.select))

	surface.SetDrawColor(theme.plate.r, theme.plate.g, theme.plate.b, (110 + 70 * hover) * reveal)
	surface.DrawRect(0, 0, width, height)

	if (self.select > 0.01) then
		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 26 * self.select * reveal)
		surface.DrawRect(0, 0, width, height)
	end
end

function PANEL:PaintOver(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local reveal = self.reveal

	if (reveal < 0.01) then
		return
	end

	local path = util.BuildCornerPath(0, 0, width, height, Sc(10))
	local color = self.bSelected and theme.accent or theme.line

	util.DrawPathProgress(path, 1, math.max(Sc(1), 1), ColorAlpha(theme.line, 30 * reveal))
	util.DrawPathProgress(path, util.EaseInOut(self.outline), math.max(Sc(2), 1),
		ColorAlpha(color, 245 * reveal), 1)

	if (self.select > 0.05) then
		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 235 * self.select * reveal)
		surface.DrawRect(0, height - math.max(Sc(3), 2), width, math.max(Sc(3), 2))
	end
end

vgui.Register("nwModelCard", PANEL, "DButton")
