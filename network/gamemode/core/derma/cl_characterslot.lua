local PANEL = {}

PANEL.previewBias = -0.06
PANEL.previewMargin = 1.18

PANEL.descriptionLines = 3

PANEL.hoverGrow = 0.012
PANEL.hoverLift = 5
PANEL.bracketInset = 3
PANEL.bracketLength = 12

function PANEL:Init()
	self:SetText("")
	self:SetCursor("hand")
	self:NoClipping(true)

	self.character = nil
	self.bSelected = false
	self.slotIndex = 1

	self.hover = 0
	self.press = 0
	self.reveal = 0
	self.exit = 0
	self.select = 0
	self.outline = 0
	self.revealDelay = 0
	self.startTime = CurTime()
	self.bExiting = false
	self.spin = math.random(0, 359)
	self.sweep = 0
end

function PANEL:SetSlotIndex(index)
	self.slotIndex = index
end

function PANEL:SetCharacter(character)
	local Sc = NETWORK.util.Scale

	if (self.character and character and self.character:GetID() == character:GetID()) then
		return
	end

	self.character = character

	if (IsValid(self.model)) then
		self.model:Remove()

		self.model = nil
	end

	if (!character) then
		self.cachedName = nil
		self.description = nil
		self.lines = nil

		return
	end

	self.cachedName = NETWORK.util.Upper(character:GetName())
	self.description = character:GetDescription()
	self.wrapWidth = nil

	self.model = self:Add("DModelPanel")
	self.model:SetModel(character:GetModel())
	self.model:SetFOV(34)
	self.model:SetMouseInputEnabled(false)
	self.model.LayoutEntity = function(panel, entity)
		entity:SetAngles(Angle(0, RealTime() * 14 % 360, 0))
	end

	local entity = self.model:GetEntity()

	if (IsValid(entity) and self.character and
		self.character:GetID() == LocalPlayer():GetCharacterID()) then
		NETWORK.util.ApplyAppearance(self.model, LocalPlayer())
	end

	if (IsValid(entity)) then

		entity:SetModelScale(character:GetScale(), 0)

		local sequence = entity:LookupSequence("idle_all_01")

		if (sequence > 0) then
			entity:ResetSequence(sequence)
		end
	end

	self:InvalidateLayout(true)
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	if (IsValid(self.model)) then

		self.model:SetSize(width - Sc(20), math.Round(height * 0.80))
		self.model:SetPos(Sc(10), Sc(4))

		NETWORK.util.FrameModelPanel(self.model, NETWORK.creation.GetFrameUnits(),
			PANEL.previewBias, PANEL.previewMargin)
	end

	self.wrapWidth = nil
end

function PANEL:GetCharacter()
	return self.character
end

function PANEL:SetSelected(bSelected)
	self.bSelected = tobool(bSelected)
end

function PANEL:SetRevealDelay(delay)
	self.revealDelay = delay
end

function PANEL:SetExiting(bExiting)
	self.bExiting = bExiting
end

function PANEL:OnCursorEntered()
	if (self:GetDisabled()) then
		return
	end

	NETWORK.sound.Hover()
end

function PANEL:OnMousePressed(code)
	if (self:GetDisabled() or self.bExiting) then
		return
	end

	self.press = 1

	NETWORK.sound.Click()

	if (code == MOUSE_LEFT and self.DoClick) then
		self:DoClick(self)
	end
end

function PANEL:Think()
	local util = NETWORK.util
	local bHovered = self:IsHovered() and !self:GetDisabled() and !self.bExiting
	local bLit = bHovered or self.bSelected

	self.hover = util.Approach(self.hover, bHovered and 1 or 0, bHovered and 5 or 8)
	self.select = util.Approach(self.select, self.bSelected and 1 or 0, 7)
	self.outline = util.Approach(self.outline, bLit and 1 or 0, bLit and 4 or 12)
	self.press = util.Approach(self.press, 0, 5)
	self.reveal = util.Stagger(self.startTime, self.revealDelay, 0.9)
	self.exit = util.Approach(self.exit, self.bExiting and 1 or 0, 7)
	self.spin = (self.spin + FrameTime() * (7 + 26 * self.hover)) % 360

	if (bHovered) then
		self.sweep = math.min(self.sweep + FrameTime() * 1.1, 1)
	else
		self.sweep = 0
	end

	if (IsValid(self.model)) then
		self.model:SetAlpha(math.Round(util.EaseOut(self.reveal) * (1 - self.exit) * 255))
	end
end

function PANEL:PaintEmpty(x, y, w, h, reveal, hover)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local centerX = math.Round(x + w * 0.5)
	local centerY = math.Round(y + h * 0.46)
	local arm = Sc(15) + math.Round(hover * Sc(3))
	local thickness = math.max(Sc(2), 2)
	local color = ColorAlpha(theme.textDim, (120 + 120 * hover) * reveal)

	surface.SetDrawColor(color.r, color.g, color.b, color.a)
	surface.DrawRect(centerX - math.Round(thickness * 0.5), centerY - arm, thickness, arm * 2)
	surface.DrawRect(centerX - arm, centerY - math.Round(thickness * 0.5), arm * 2, thickness)

	local text = util.Upper(L("emptySlot"))
	local textWidth = util.TextSpacedSize(text, "nwMenuMeta", Sc(4))

	util.DrawTextSpaced(text, "nwMenuMeta", math.Round(centerX - textWidth * 0.5),
		centerY + Sc(44), ColorAlpha(theme.textFaint, (170 + 85 * hover) * reveal),
		Sc(4), TEXT_ALIGN_CENTER)
end

function PANEL:PaintCharacter(x, y, w, h, reveal, hover)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local baseY = y + h - Sc(58)

	NETWORK.util.DrawVGradient(x, y + math.Round(h * 0.55), w, math.Round(h * 0.45),
		ColorAlpha(color_black, 0), ColorAlpha(color_black, 190 * reveal), 16)

	surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b,
		(120 + 120 * hover) * reveal)
	surface.DrawRect(x + Sc(18), baseY - Sc(12), math.Round(Sc(24) + Sc(20) * hover),
		math.max(Sc(2), 2))

	draw.SimpleText(self.cachedName or "", "nwMenuName", x + Sc(18), baseY,
		ColorAlpha(theme.text, (230 + 25 * hover) * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	local faction = self.character and self.character:GetFactionName() or nil

	if (faction) then
		draw.SimpleText(faction, "nwMenuFaction", x + Sc(18), baseY + Sc(24),
			ColorAlpha(theme.textDim, (185 + 50 * hover) * reveal),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local exit = util.EaseInOut(self.exit)
	local reveal = util.EaseOut(self.reveal) * (1 - exit)

	if (reveal < 0.01) then
		return
	end

	local hover = util.EaseInOut(math.max(self.hover, self.select))
	local chosen = util.EaseInOut(self.select)
	local lift = math.Round(Sc(PANEL.hoverLift) * hover)
	local x = 0
	local y = -lift + math.Round((1 - reveal) * Sc(26)) + math.Round(exit * Sc(24))
	local w = width
	local h = height

	local radius = math.max(Sc(8), 4)

	draw.RoundedBox(radius, x + Sc(2), y + Sc(5) + lift, w, h, Color(0, 0, 0, 80 * reveal))

	draw.RoundedBox(radius, x, y, w, h, Color(8, 9, 10, (200 + 30 * hover) * reveal))

	if (chosen > 0.01) then
		draw.RoundedBox(radius, x, y, w, h, ColorAlpha(theme.combine, 30 * chosen * reveal))
	end

	local edge = self.bSelected and theme.combine or Color(255, 255, 255)

	util.DrawRoundedBorder(x, y, w, h, radius, math.max(Sc(1), 1),
		ColorAlpha(edge, (26 + 40 * hover + 170 * chosen) * reveal))

	if (self.character) then
		self:PaintCharacter(x, y, w, h, reveal, hover)
	else
		self:PaintEmpty(x, y, w, h, reveal, hover)
	end

	if (self.press > 0.01) then
		surface.SetDrawColor(255, 255, 255, 22 * self.press)
		surface.DrawRect(x, y, w, h)
	end
end

vgui.Register("nwCharacterSlot", PANEL, "DButton")
