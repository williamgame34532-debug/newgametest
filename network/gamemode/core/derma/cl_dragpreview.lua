local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0
	self.size = Sc(76)

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

function PANEL:SetItem(item)
	self.item = item
	self.rarity = NETWORK.inventory.GetRarity(NETWORK.item.GetRarity(item))

	if (IsValid(self.icon)) then
		self.icon:Remove()
	end

	local inset = NETWORK.util.Scale(8)

	local itemWidth, itemHeight = NETWORK.item.GetSize(item)
	local grid = NETWORK.gui.grids[NETWORK.gui.drag and NETWORK.gui.drag.source.list or ""]
	local cell = grid and grid.cell or self.size
	local gap = grid and grid.gap or 0

	self.boxWidth = itemWidth * cell + (itemWidth - 1) * gap
	self.boxHeight = itemHeight * cell + (itemHeight - 1) * gap

	self.icon = self:Add("nwItemIcon")
	self.icon:SetItem(item)
	self.icon:SetMouseInputEnabled(false)
	self.icon:SetSize(self.boxWidth - inset * 2, self.boxHeight - inset * 2)
end

function PANEL:Think()
	local drag = NETWORK.gui.drag

	if (drag and input.IsKeyDown(KEY_R)) then
		if (!self.bRotateHeld and NETWORK.item.CanRotate(drag.item)) then
			self.bRotateHeld = true

			drag.item = table.Copy(drag.item)
			drag.item.rotated = !drag.item.rotated or nil

			self:SetItem(drag.item)

			NETWORK.sound.Click()
		end
	else
		self.bRotateHeld = false
	end

	self.alpha = NETWORK.util.Approach(self.alpha, 1, 16)

	self:MoveToFront()

	if (self:GetWide() != ScrW() or self:GetTall() != ScrH()) then
		self:SetSize(ScrW(), ScrH())
	end

	if (IsValid(self.icon)) then
		local inset = NETWORK.util.Scale(8)

		self.icon:SetPos(gui.MouseX() - (self.boxWidth or self.size) * 0.5 + inset,
			gui.MouseY() - (self.boxHeight or self.size) * 0.5 + inset)
		self.icon:SetAlphaValue(math.Round(self.alpha * 255))
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local color = self.rarity and self.rarity.color or NETWORK.theme.accent
	local drag = NETWORK.gui.drag
	local x, y = self:ScreenToLocal(gui.MouseX(), gui.MouseY())

	if (drag and IsValid(drag.panel)) then
		local screenX, screenY = drag.panel:LocalToScreen(drag.panel:GetWide() * 0.5,
			drag.panel:GetTall() * 0.5)
		local startX, startY = self:ScreenToLocal(screenX, screenY)
		local pulse = 0.65 + math.sin(RealTime() * 8) * 0.35

		util.DrawThickLine(startX, startY, x, y, math.max(Sc(2), 2),
			ColorAlpha(color, 210 * pulse * self.alpha))

		util.DrawCircle(startX, startY, math.max(Sc(4), 3),
			ColorAlpha(color, 215 * self.alpha))
	end

	local boxWidth = self.boxWidth or self.size
	local boxHeight = self.boxHeight or self.size
	local left = math.Round(x - boxWidth * 0.5)
	local top = math.Round(y - boxHeight * 0.5)
	local cut = math.max(Sc(9), 6)
	local alpha = self.alpha

	surface.SetDrawColor(0, 0, 0, 90 * alpha)
	surface.DrawRect(left + Sc(4), top + Sc(5), boxWidth, boxHeight)

	surface.SetDrawColor(6, 26, 33, 242 * alpha)
	surface.DrawRect(left, top, boxWidth, boxHeight - cut)
	surface.DrawRect(left, top + boxHeight - cut, boxWidth - cut, cut)

	draw.NoTexture()
	surface.SetDrawColor(6, 26, 33, 242 * alpha)
	surface.DrawPoly({
		{x = left + boxWidth - cut, y = top + boxHeight - cut},
		{x = left + boxWidth - cut, y = top + boxHeight},
		{x = left + boxWidth, y = top + boxHeight - cut}
	})

	surface.SetDrawColor(color.r, color.g, color.b, 26 * alpha)
	surface.DrawRect(left, top, boxWidth, boxHeight - cut)

	surface.SetDrawColor(color.r, color.g, color.b, 250 * alpha)
	surface.DrawRect(left, top, math.max(Sc(3), 2), boxHeight - cut)

	surface.SetDrawColor(color.r, color.g, color.b, 90 * alpha)
	surface.DrawRect(left, top, boxWidth, 1)
	surface.DrawRect(left + boxWidth - 1, top, 1, boxHeight - cut)
	surface.DrawRect(left, top + boxHeight - 1, boxWidth - cut, 1)

	util.DrawThickLine(left + boxWidth - cut, top + boxHeight, left + boxWidth,
		top + boxHeight - cut, math.max(Sc(1), 1),
		Color(color.r, color.g, color.b, 130 * alpha))

	if (drag and NETWORK.item.CanRotate(drag.item)) then
		draw.SimpleText("R", "nwHudSmall", left + boxWidth - Sc(9),
			top + boxHeight - Sc(9), ColorAlpha(color, 200 * alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwDragPreview", PANEL, "EditablePanel")

function NETWORK.gui.OpenDragPreview(item)
	NETWORK.gui.CloseDragPreview()

	if (!item) then
		return
	end

	NETWORK.gui.dragPreview = vgui.Create("nwDragPreview")
	NETWORK.gui.dragPreview:SetItem(item)

	return NETWORK.gui.dragPreview
end

function NETWORK.gui.CloseDragPreview()
	if (IsValid(NETWORK.gui.dragPreview)) then
		NETWORK.gui.dragPreview:Remove()
	end

	NETWORK.gui.dragPreview = nil
end
