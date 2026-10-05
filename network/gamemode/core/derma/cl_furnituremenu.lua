local PANEL = {}

PANEL.tabs = {
	{id = "furniture", name = "furnTabFurniture"},
	{id = "food", name = "furnTabFood"}
}

function PANEL:Init()
	NETWORK.gui.furniture = self

	self.alpha = 0
	self.rows = {}
	self.tab = "furniture"

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	local Sc = NETWORK.util.Scale

	self.scroll = self:Add("DScrollPanel")
	self.scroll.Paint = function() end

	local bar = self.scroll:GetVBar()

	bar:SetWide(Sc(4))
	bar:SetHideButtons(true)
	bar.Paint = function() end
	bar.btnGrip.Paint = function(_, width, height)
		draw.RoundedBox(Sc(2), 0, 0, width, height,
			ColorAlpha(NETWORK.theme.accent, 180))
	end
end

function PANEL:Setup(entity)
	self.entity = entity

	self:Rebuild()
end

function PANEL:GetEntries()
	local shop = scripted_ents.GetStored("nw_furnitureshop")
	local stored = shop and shop.t

	if (!stored) then
		return {}
	end

	if (self.tab == "food") then
		return stored.Food or {}
	end

	return stored.Catalogue or {}
end

function PANEL:Rebuild()
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme

	self.scroll:Clear()

	self.rows = {}

	for _, entry in ipairs(self:GetEntries()) do
		local row = self.scroll:Add("DButton")

		row:SetText("")
		row:SetCursor("hand")
		row:Dock(TOP)
		row:DockMargin(0, 0, Sc(8), Sc(6))
		row:SetTall(Sc(54))
		row.DoClick = function()
			surface.PlaySound("ui/buttonclick.wav")

			net.Start("nwFurnitureBuy")
				net.WriteEntity(self.entity)
				net.WriteString(entry.id)
			net.SendToServer()
		end
		row.Paint = function(panel, width, height)
			local hover = panel:IsHovered() and 1 or 0
			local client = LocalPlayer()
			local bAfford = IsValid(client) and
				client:GetTokens() >= entry.price

			surface.SetDrawColor(9, 14, 24, (232 + 14 * hover) * self.alpha)
			surface.DrawRect(0, 0, width, height)

			if (hover > 0) then
				surface.SetMaterial(NETWORK.util.GetMaterial("vgui/gradient-u"))
				surface.SetDrawColor(theme.accent.r, theme.accent.g,
					theme.accent.b, 30 * self.alpha)
				surface.DrawTexturedRect(0, 0, width, height)
			end

			surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
				(bAfford and 210 or 70) * self.alpha)
			surface.DrawRect(0, 0, math.max(Sc(3), 2), height)

			draw.SimpleText(L(entry.name), "nwChatSmall", Sc(18),
				math.Round(height * 0.5) - Sc(8),
				ColorAlpha(bAfford and theme.text or theme.textFaint,
				246 * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local base = NETWORK.item.Get(entry.id)
			local hint = (self.tab == "food" and base) and
				NETWORK.util.Sub(base.description or "", 1, 64) or
				L("furnCarryHint")

			draw.SimpleText(hint, "nwHudSmall", Sc(18),
				math.Round(height * 0.5) + Sc(11),
				ColorAlpha(theme.textFaint, 226 * self.alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(entry.price .. " " .. L("furnTokens"), "nwChatSmall",
				width - Sc(18), math.Round(height * 0.5),
				ColorAlpha(bAfford and theme.value or theme.danger,
				246 * self.alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		self.rows[#self.rows + 1] = row
	end
end

function PANEL:GetTabRects()
	local Sc = NETWORK.util.Scale
	local width = self:GetCardWidth()
	local x = math.Round((ScrW() - width) * 0.5) + Sc(24)
	local y = math.Round((ScrH() - self:GetCardHeight()) * 0.5) + Sc(74)
	local rects = {}
	local tabWidth = math.Round((width - Sc(48) - Sc(8)) / #self.tabs)

	for index, tab in ipairs(self.tabs) do
		rects[index] = {
			x = x + (index - 1) * (tabWidth + Sc(8)),
			y = y,
			width = tabWidth,
			height = Sc(32),
			tab = tab
		}
	end

	return rects
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_RIGHT) then
		return self:Remove()
	end

	if (code != MOUSE_LEFT) then
		return
	end

	local x, y = self:CursorPos()

	for _, rect in ipairs(self:GetTabRects()) do
		if (x >= rect.x and x <= rect.x + rect.width and
			y >= rect.y and y <= rect.y + rect.height) then
			if (self.tab != rect.tab.id) then
				self.tab = rect.tab.id

				self:Rebuild()

				surface.PlaySound("ui/buttonclick.wav")
			end

			return
		end
	end
end

function PANEL:GetCardWidth()
	return math.min(NETWORK.util.Scale(460), math.Round(ScrW() * 0.4))
end

function PANEL:GetCardHeight()
	return math.min(NETWORK.util.Scale(480), math.Round(ScrH() * 0.6))
end

function PANEL:PerformLayout()
	local Sc = NETWORK.util.Scale
	local width = self:GetCardWidth()
	local height = self:GetCardHeight()
	local x = math.Round((ScrW() - width) * 0.5)
	local y = math.Round((ScrH() - height) * 0.5)

	if (IsValid(self.scroll)) then
		self.scroll:SetPos(x + Sc(24), y + Sc(120))
		self.scroll:SetSize(width - Sc(48), height - Sc(144))
	end
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 10)

	if (!IsValid(self.entity)) then
		self:Remove()
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:OnRemove()
	if (NETWORK.gui.furniture == self) then
		NETWORK.gui.furniture = nil
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha

	util.DrawBlur(self, 4 * alpha, 0.3)

	surface.SetDrawColor(0, 0, 0, 196 * alpha)
	surface.DrawRect(0, 0, width, height)

	local cardWidth = self:GetCardWidth()
	local cardHeight = self:GetCardHeight()
	local x = math.Round((width - cardWidth) * 0.5)
	local y = math.Round((height - cardHeight) * 0.5)

	surface.SetDrawColor(5, 9, 17, 250 * alpha)
	surface.DrawRect(x, y, cardWidth, cardHeight)

	surface.SetMaterial(util.GetMaterial("vgui/gradient-u"))
	surface.SetDrawColor(theme.accentDeep.r, theme.accentDeep.g,
		theme.accentDeep.b, 46 * alpha)
	surface.DrawTexturedRect(x, y, cardWidth, math.Round(cardHeight * 0.5))

	surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
		200 * alpha)
	surface.DrawRect(x, y, cardWidth, math.max(Sc(2), 2))

	util.DrawTextSpaced(util.Upper(L("furnShopLabel")), "nwField",
		x + Sc(24), y + Sc(36), ColorAlpha(theme.text, 250 * alpha), Sc(3),
		TEXT_ALIGN_CENTER)

	draw.SimpleText(L("furnHint"), "nwHudSmall", x + Sc(24), y + Sc(58),
		ColorAlpha(theme.textFaint, 235 * alpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	local client = LocalPlayer()

	if (IsValid(client)) then
		draw.SimpleText(client:GetTokens() .. " " .. L("furnTokens"),
			"nwChatSmall", x + cardWidth - Sc(24), y + Sc(36),
			ColorAlpha(theme.value, 248 * alpha), TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)
	end

	local cursorX, cursorY = self:CursorPos()

	for _, rect in ipairs(self:GetTabRects()) do
		local bActive = self.tab == rect.tab.id
		local bHover = cursorX >= rect.x and cursorX <= rect.x + rect.width and
			cursorY >= rect.y and cursorY <= rect.y + rect.height

		surface.SetDrawColor(9, 15, 26,
			(bActive and 250 or (bHover and 220 or 180)) * alpha)
		surface.DrawRect(rect.x, rect.y, rect.width, rect.height)

		if (bActive) then
			surface.SetDrawColor(theme.accent.r, theme.accent.g,
				theme.accent.b, 240 * alpha)
			surface.DrawRect(rect.x, rect.y + rect.height - math.max(Sc(2), 2),
				rect.width, math.max(Sc(2), 2))
		end

		util.DrawTextSpaced(util.Upper(L(rect.tab.name)), "nwHudSmall",
			rect.x + rect.width * 0.5, rect.y + rect.height * 0.5,
			ColorAlpha(bActive and theme.text or theme.textFaint, 248 * alpha),
			Sc(3), TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwFurnitureMenu", PANEL, "EditablePanel")

net.Receive("nwFurnitureMenu", function()
	local entity = net.ReadEntity()

	NETWORK.gui.CloseWindows()

	if (IsValid(NETWORK.gui.furniture)) then
		NETWORK.gui.furniture:Remove()
	end

	local panel = vgui.Create("nwFurnitureMenu")

	panel:Setup(entity)
end)
