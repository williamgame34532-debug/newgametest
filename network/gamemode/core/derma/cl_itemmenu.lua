local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self.buttons = {}
	self.alpha = 0
	self.rowHeight = Sc(30)
	self.width = Sc(200)
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
	button.bDanger = color != nil and color == NETWORK.theme.inv.danger
	button.Paint = function(panel, width, height)
		local palette = NETWORK.theme.tk
		local hover = NETWORK.util.EaseInOut(panel.hover)
		local middle = math.Round(height * 0.5)
		local inset = Sc(3)
		local idle = panel.bDanger and palette.text or (color or palette.text)
		local text = panel.bDanger and idle or Color(
			Lerp(hover, idle.r, palette.activeText.r),
			Lerp(hover, idle.g, palette.activeText.g),
			Lerp(hover, idle.b, palette.activeText.b))

		-- Строка как в Tarkov: тёмная плашка, при наведении светлеет; «Выбросить» — красная.
		if (panel.bDanger) then
			surface.SetDrawColor(palette.bad.r + 30 * hover, palette.bad.g + 10 * hover,
				palette.bad.b + 10 * hover, (150 + 90 * hover) * self.alpha)
		else
			surface.SetDrawColor(Lerp(hover, palette.plateLight.r, palette.active.r),
				Lerp(hover, palette.plateLight.g, palette.active.g),
				Lerp(hover, palette.plateLight.b, palette.active.b),
				(170 + 80 * hover) * self.alpha)
		end

		surface.DrawRect(inset, Sc(1), width - inset * 2, height - Sc(2))

		local glyphSize = Sc(13)

		NETWORK.gui.DrawGlyph(glyph or "dot", Sc(14), middle - math.Round(glyphSize * 0.5),
			glyphSize, ColorAlpha(text, (190 + 65 * hover) * self.alpha))

		draw.SimpleText(NETWORK.util.Upper(label), "nwTkHeader", Sc(36), middle,
			ColorAlpha(text, (215 + 40 * hover) * self.alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

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
	local palette = NETWORK.theme.tk

	surface.SetDrawColor(palette.plate.r, palette.plate.g, palette.plate.b, 248 * self.alpha)
	surface.DrawRect(0, 0, width, height)
	surface.SetDrawColor(palette.line.r, palette.line.g, palette.line.b, 255 * self.alpha)
	surface.DrawOutlinedRect(0, 0, width, height, 1)
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

	if (source.list == "equipped" and NETWORK.inventory.GetWeaponClass(item)) then
		if (NETWORK.inventory.IsInHands(item)) then
			menu:AddOption(L("itemHolster"), function()
				NETWORK.inventory.Holster()
			end, palette.text, "down")
		else
			menu:AddOption(L("itemDraw"), function()
				NETWORK.inventory.TakeInHands(item)
			end, palette.text, "up")
		end
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
	end, palette.danger, "down")

	menu:OpenAt(gui.MouseX() + NETWORK.util.Scale(4), gui.MouseY() + NETWORK.util.Scale(4))

	NETWORK.gui.itemMenu = menu

	return menu
end
