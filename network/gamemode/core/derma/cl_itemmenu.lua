local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self.buttons = {}
	self.alpha = 0
	self.rowHeight = Sc(34)
	self.width = Sc(176)
	self.padding = Sc(4)
	self.openTime = CurTime()

	self:SetSize(self.width, self.padding * 2)
	self:MakePopup()
	self:SetKeyboardInputEnabled(false)
end

function PANEL:SetWidth(width)
	self.width = width

	self:SetSize(self.width, self.padding * 2 + #self.buttons * self.rowHeight)

	for i = 1, #self.buttons do
		self.buttons[i]:SetWide(self.width)
	end
end

function PANEL:AddOption(label, callback, color, glyph, children)
	local Sc = NETWORK.util.Scale
	local index = #self.buttons + 1
	local button = self:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button:SetSize(self.width, self.rowHeight)
	button:SetPos(0, self.padding + (index - 1) * self.rowHeight)
	button.hover = 0
	button.children = children
	button.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover, (panel:IsHovered() or
			IsValid(panel.submenu)) and 1 or 0, 14)

		if (panel.children and panel:IsHovered() and !IsValid(panel.submenu)) then
			self:OpenSubmenu(panel)
		end
	end
	button.Paint = function(panel, width, height)
		local palette = NETWORK.theme.inv
		local tint = color or palette.text
		local hover = NETWORK.util.EaseInOut(panel.hover)
		local middle = math.Round(height * 0.5)

		if (hover > 0.01) then
			local accent = palette.accent
			local rail = math.max(Sc(3), 2)
			local railHeight = math.Round((height - Sc(14)) * hover)

			draw.RoundedBox(math.max(Sc(5), 3), Sc(4), Sc(1), width - Sc(8),
				height - Sc(2), Color(255, 255, 255, 16 * hover * self.alpha))

			if (railHeight >= rail) then
				draw.RoundedBox(math.floor(rail * 0.5), Sc(7),
					middle - math.floor(railHeight * 0.5), rail, railHeight,
					Color(accent.r, accent.g, accent.b, 235 * hover * self.alpha))
			end
		end

		local glyphSize = Sc(13)

		NETWORK.gui.DrawGlyph(glyph or "dot", Sc(16), middle - math.Round(glyphSize * 0.5), glyphSize,
			ColorAlpha(palette.accentSoft, (200 + 55 * hover) * self.alpha))

		draw.SimpleText(label, "nwInvBody", Sc(38), middle,
			ColorAlpha(tint, (215 + 40 * hover) * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (panel.children) then
			NETWORK.gui.DrawGlyph("chevron", width - Sc(22), middle - Sc(6), Sc(12),
				ColorAlpha(palette.textDim, 230 * self.alpha))
		end
	end
	button.DoClick = function(panel)
		if (panel.children) then
			self:OpenSubmenu(panel)

			return
		end

		NETWORK.sound.InvSelect()

		if (callback) then
			callback()
		end

		self:CloseAll()
	end

	self.buttons[index] = button

	self:SetSize(self.width, self.padding * 2 + index * self.rowHeight)

	return button
end

function PANEL:AddSubmenu(label, entries, glyph, color)
	return self:AddOption(label, nil, color, glyph, entries)
end

function PANEL:OpenSubmenu(button)
	self:CloseSubmenus()

	local submenu = vgui.Create("nwItemMenu")

	submenu.parentMenu = self

	for _, entry in ipairs(button.children) do
		submenu:AddOption(entry.label, entry.callback, entry.color, entry.glyph or "dot")
	end

	local x, y = self:LocalToScreen(self:GetWide() + NETWORK.util.Scale(2), select(2, button:GetPos()))

	if (x + submenu:GetWide() > ScrW()) then
		x = select(1, self:LocalToScreen(0, 0)) - submenu:GetWide() - NETWORK.util.Scale(2)
	end

	submenu:SetPos(x, math.min(y, ScrH() - submenu:GetTall() - 4))

	button.submenu = submenu
	self.submenu = submenu
end

function PANEL:CloseSubmenus()
	if (IsValid(self.submenu)) then
		self.submenu:Remove()
	end

	self.submenu = nil
end

function PANEL:GetRoot()
	local menu = self

	while (IsValid(menu.parentMenu)) do
		menu = menu.parentMenu
	end

	return menu
end

function PANEL:CloseAll()
	self:GetRoot():Remove()
end

function PANEL:IsInside(x, y)
	local panelX, panelY = self:LocalToScreen(0, 0)

	if (x >= panelX and y >= panelY and x <= panelX + self:GetWide() and
		y <= panelY + self:GetTall()) then
		return true
	end

	if (IsValid(self.submenu)) then
		return self.submenu:IsInside(x, y)
	end

	return false
end

function PANEL:OpenAt(x, y)
	self:SetPos(math.min(x, ScrW() - self:GetWide() - 4),
		math.min(y, ScrH() - self:GetTall() - 4))
end

function PANEL:OnRemove()
	self:CloseSubmenus()
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 16)

	self:MoveToFront()

	if (IsValid(self.submenu)) then
		self.submenu:MoveToFront()
	end

	if (IsValid(self.parentMenu)) then
		return
	end

	if (CurTime() - self.openTime < 0.25) then
		return
	end

	if (!input.IsMouseDown(MOUSE_LEFT) and !input.IsMouseDown(MOUSE_RIGHT)) then
		return
	end

	if (!self:IsInside(gui.MousePos())) then
		self:Remove()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local palette = NETWORK.theme.inv
	local S = NETWORK.style

	if (S and S.Card) then
		S.Card(0, 0, width, height, self.alpha, {
			radius = S.Radius("card"),
			panel = self,
			shadow = false,
			fill = Color(9, 12, 15, 236)
		})

		return
	end

	local radius = math.max(Sc(8), 5)

	NETWORK.util.DrawBlurRounded(self, 0, 0, width, height, radius, 4 * self.alpha)

	draw.RoundedBox(radius, 0, 0, width, height, Color(9, 12, 15, 236 * self.alpha))

	NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, 1,
		Color(palette.line.r, palette.line.g, palette.line.b, 90 * self.alpha))
end

vgui.Register("nwItemMenu", PANEL, "EditablePanel")

function NETWORK.gui.OpenItemMenu(slot)
	if (IsValid(NETWORK.gui.itemMenu)) then
		NETWORK.gui.itemMenu:Remove()
	end

	local item = slot:GetItem()

	if (!item) then
		return
	end

	local palette = NETWORK.theme.inv
	local menu = vgui.Create("nwItemMenu")
	local source = slot:GetSource()

	if ((item.amount or 1) > 1) then
		menu:AddSubmenu(L("invSplitTitle"), {
			{label = L("invSplitOne"), glyph = "split", callback = function()
				NETWORK.gui.RequestSplit(source, 1)
			end},
			{label = L("invSplitHalf"), glyph = "split", callback = function()
				NETWORK.gui.RequestSplit(source, math.floor((item.amount or 1) * 0.5))
			end},
			{label = L("invSplitAsk"), glyph = "split", callback = function()
				Derma_StringRequest(L("invSplitTitle"), L("invSplitPrompt"), "1",
					function(text)
						local amount = math.Clamp(math.Round(tonumber(text) or 1), 1,
							(item.amount or 1) - 1)

						NETWORK.gui.RequestSplit(source, amount)
					end)
			end}
		}, "split")
	end

	if (NETWORK.item.CanUse(item)) then
		menu:AddOption(L(NETWORK.item.GetUseLabel(item)), function()
			NETWORK.inventory.Use(source)
		end, palette.text, "plus")
	end

	if (NETWORK.item.GetEquipSlot(item) and source.list == "items") then
		menu:AddOption(L("itemEquip"), function()
			NETWORK.inventory.Equip(source.index)
		end, palette.text, "up")
	end

	if (source.list == "equipped") then
		menu:AddOption(L("itemUnequip"), function()
			NETWORK.inventory.Unequip(source.slot)
		end, palette.text, "minus")

		local base = NETWORK.item.Get(item.id)
		local entries = {}
		local seen = {}

		local function Send(group, delta)
			net.Start("nwItemBodygroup")
				net.WriteString(source.slot)
				net.WriteUInt(group, 6)
				net.WriteInt(delta, 4)
			net.SendToServer()
		end

		for group in pairs(base and base.bodygroups or {}) do
			local id = tonumber(group)

			if (id and !seen[id]) then
				seen[id] = true

				local name = LocalPlayer():GetBodygroupName(id)

				entries[#entries + 1] = {
					label = L("itemBodygroupNext", (name and name != "" and name or tostring(id))),
					glyph = "chevron",
					callback = function()
						Send(id, 1)
					end
				}
			end
		end

		entries[#entries + 1] = {label = L("itemBodygroupOther"), glyph = "sliders", callback = function()
			Derma_StringRequest(L("itemBodygroups"), L("itemBodygroupAsk"), "1", function(text)
				local id = math.Clamp(math.Round(tonumber(text) or 1), 0, 63)

				Send(id, 1)
			end)
		end}

		menu:AddSubmenu(L("itemBodygroups"), entries, "sliders")
	end

	if (source.list == "items" and NETWORK.shop and
		NETWORK.shop.CanSell(item) and
		NETWORK.business and NETWORK.business.IsOwner and
		NETWORK.business.IsOwner(LocalPlayer())) then
		menu:AddOption(L("shopSell"), function()
			NETWORK.shop.BeginPlacing(source.index, item)
		end, palette.positive, "up")
	end

	menu:AddOption(L("itemDrop"), function()
		NETWORK.inventory.Drop(source)
	end, palette.accentSoft, "down")

	menu:OpenAt(gui.MouseX() + NETWORK.util.Scale(4), gui.MouseY() + NETWORK.util.Scale(4))

	NETWORK.gui.itemMenu = menu

	return menu
end
