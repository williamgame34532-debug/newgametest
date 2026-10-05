local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.trade = self

	self.alpha = 0
	self.bClosing = false
	self.rows = {}
	self.selected = nil
	self.columnX = Sc(60)
	self.columnY = Sc(150)
	self.columnWidth = Sc(420)
	self.columnHeight = Sc(400)
	self.rightX = Sc(540)

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.left = self:Add("DScrollPanel")
	self.right = self:Add("DScrollPanel")

	for _, scroll in ipairs({self.left, self.right}) do
		local bar = scroll:GetVBar()

		bar:SetWide(Sc(4))
		bar.Paint = function() end
		bar.btnUp.Paint = function() end
		bar.btnDown.Paint = function() end
		bar.btnGrip.Paint = function(panel, width, height)
			draw.RoundedBox(Sc(2), 0, 0, width, height, Color(255, 255, 255, 60))
		end
	end

	self.action = self:Add("nwActionButton")
	self.action:SetPrimary(true)
	self.action:SetLabel(L("tradeSelect"))
	self.action.DoClick = function()
		if (!self.selected) then
			return
		end

		NETWORK.trade.Request(self.selected.side == "sell" and "buy" or "sell",
			self.selected.index)
	end

	self.close = self:Add("nwActionButton")
	self.close:SetLabel(L("containerClose"))
	self.close.DoClick = function()
		self:Close()
	end
end

function PANEL:OnRemove()
	if (NETWORK.gui.trade == self) then
		NETWORK.gui.trade = nil
	end
end

function PANEL:Setup(entity)
	self.entity = entity

	self:Rebuild()
end

function PANEL:Row(parent, entry, index, side, order)
	local Sc = NETWORK.util.Scale
	local base = NETWORK.item.Get(entry.id)
	local button = parent:Add("DButton")

	button:Dock(TOP)
	button:DockMargin(0, 0, Sc(14), Sc(6))
	button:SetTall(Sc(66))
	button:SetText("")
	button:SetCursor("hand")
	button.hover = 0
	button.reveal = 0
	button.startTime = CurTime()
	button.revealDelay = 0.05 + (order or index or 1) * 0.05

	local icon = button:Add("nwItemIcon")

	icon:SetPos(Sc(16), Sc(9))
	icon:SetSize(Sc(48), Sc(48))
	icon:SetMouseInputEnabled(false)
	icon:SetItem({id = entry.id, model = base and base.model, amount = 1})
	icon:SetAlpha(0)

	button.icon = icon
	button.Think = function(panel)
		local util = NETWORK.util

		panel.hover = util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
		panel.reveal = util.EaseOut(util.Stagger(panel.startTime, panel.revealDelay, 0.4))

		if (IsValid(panel.icon)) then
			panel.icon:SetPos(Sc(16) + math.Round((1 - panel.reveal) * Sc(24)), Sc(9))
			panel.icon:SetAlpha(math.Round(255 * panel.reveal))
		end
	end
	button.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local reveal = panel.reveal

		if (reveal < 0.01) then
			return
		end

		local rarity = NETWORK.inventory.GetRarity(base and base.rarity or "common")
		local bSelected = self.selected and self.selected.side == side and
			self.selected.index == index
		local bOut = side == "sell" and !NETWORK.trade.HasStock(entry)
		local lit = math.max(panel.hover, bSelected and 1 or 0)
		local fade = bOut and 0.45 or 1
		local alpha = self.alpha * reveal
		local slide = math.Round((1 - reveal) * Sc(24))

		surface.SetDrawColor(9, 12, 16, (206 + 34 * lit) * alpha)
		surface.DrawRect(slide, 0, width - slide, height)

		surface.SetDrawColor(255, 255, 255, (10 + 12 * lit) * alpha)
		surface.DrawOutlinedRect(slide, 0, width - slide, height, 1)

		if (bSelected) then
			surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b,
				200 * alpha)
			surface.DrawOutlinedRect(slide, 0, width - slide, height, 1)
		end

		surface.SetDrawColor(rarity.color.r, rarity.color.g, rarity.color.b,
			(180 + 75 * lit) * alpha * fade)
		surface.DrawRect(slide, 0, math.max(Sc(2), 2), height)

		local textX = Sc(74) + slide
		local rightX = width - Sc(16)

		draw.SimpleText(base and base.name or entry.id, "nwInvName", textX,
			Sc(20), ColorAlpha(theme.text, 245 * alpha * fade), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		local price = NETWORK.trade.Describe(entry)

		draw.SimpleText(price, "nwInvKey", rightX, Sc(20),
			ColorAlpha(theme.combine, 250 * alpha * fade), TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)

		local note = side == "sell" and L("tradeSells") or L("tradeBuys")

		if ((entry.amount or 1) > 1) then
			note = note .. "  x" .. entry.amount
		end

		draw.SimpleText(note, "nwLabel", textX, Sc(42),
			ColorAlpha(theme.textFaint, 230 * alpha * fade), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		if (side == "sell") then
			local text, colour

			if (!NETWORK.trade.IsLimited(entry)) then
				text, colour = L("tradeUnlimited"), theme.textFaint
			elseif (bOut) then
				text, colour = L("tradeSoldOut"), theme.danger
			else
				text = L("tradeStockLeft") .. ": " .. entry.stock
				colour = entry.stock <= 2 and theme.warning or Color(120, 220, 140)
			end

			draw.SimpleText(text, "nwHudSmall", rightX, Sc(42),
				ColorAlpha(colour, 235 * alpha), TEXT_ALIGN_RIGHT,
				TEXT_ALIGN_CENTER)
		end

		if (side == "buy") then
			local have = 0

			for _, list in ipairs({NETWORK.inventory.state.items,
				NETWORK.inventory.state.storage}) do
				for _, item in pairs(list) do
					if (item.id == entry.id) then
						have = have + (item.amount or 1)
					end
				end
			end

			draw.SimpleText(have .. " / " .. (entry.amount or 1), "nwHudSmall",
				rightX, Sc(42),
				ColorAlpha(have >= (entry.amount or 1) and Color(120, 220, 140) or
					theme.textFaint, 230 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end
	button.DoClick = function()
		if (side == "sell" and !NETWORK.trade.HasStock(entry)) then
			surface.PlaySound("buttons/button10.wav")

			return
		end

		NETWORK.sound.Click()

		self.selected = {side = side, index = index, entry = entry}

		self.action:SetLabel(side == "sell" and L("tradeBuy") or L("tradeSell"))
	end

	return button
end

function PANEL:Rebuild()
	self.left:Clear()
	self.right:Clear()

	local selected = self.selected

	self.selected = nil

	local leftCount, rightCount = 0, 0

	for order, entry in ipairs(NETWORK.trade.offers) do

		local index = entry.index or order

		if (entry.side == "sell") then
			leftCount = leftCount + 1

			self:Row(self.left, entry, index, "sell", leftCount)
		else
			rightCount = rightCount + 1

			self:Row(self.right, entry, index, "buy", rightCount)
		end

		if (selected and selected.index == index and selected.side == entry.side) then
			self.selected = {side = entry.side, index = index, entry = entry}
		end
	end

	if (!self.selected and IsValid(self.action)) then
		self.action:SetLabel(L("tradeSelect"))
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale
	local columnWidth = Sc(420)
	local gap = Sc(60)
	local totalWidth = columnWidth * 2 + gap
	local x = math.Round((width - totalWidth) * 0.5)
	local y = Sc(150)
	local columnHeight = height - y - Sc(150)

	self.columnX = x
	self.columnWidth = columnWidth
	self.columnY = y
	self.columnHeight = columnHeight
	self.rightX = x + columnWidth + gap

	self.left:SetPos(x, y)
	self.left:SetSize(columnWidth, columnHeight)

	self.right:SetPos(self.rightX, y)
	self.right:SetSize(columnWidth, columnHeight)

	self.action:SetSize(Sc(240), Sc(46))
	self.action:SetPos(math.Round(width * 0.5) - Sc(250), y + columnHeight + Sc(26))

	self.close:SetSize(Sc(240), Sc(46))
	self.close:SetPos(math.Round(width * 0.5) + Sc(10), y + columnHeight + Sc(26))
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	NETWORK.trade.Request("close")

	self:SetMouseInputEnabled(false)
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 11)

	self:SetAlpha(math.Round(self.alpha * 255))

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Close()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha

	self.columnX = self.columnX or Sc(60)
	self.columnY = self.columnY or Sc(150)
	self.columnWidth = self.columnWidth or Sc(420)
	self.columnHeight = self.columnHeight or Sc(400)
	self.rightX = self.rightX or Sc(540)

	util.DrawBlur(self, 6 * alpha, 0.25)

	surface.SetDrawColor(6, 9, 14, 205 * alpha)
	surface.DrawRect(0, 0, width, height)

	local centerX = math.Round(width * 0.5)
	local name = IsValid(self.entity) and self.entity:GetDisplayName() or "?"
	local title = util.Upper(name)
	local titleWidth = util.TextSpacedSize(title, "nwSchema", Sc(7))

	util.DrawTextSpaced(title, "nwSchema", centerX - math.Round(titleWidth * 0.5), Sc(62),
		ColorAlpha(theme.text, 252 * alpha), Sc(7), TEXT_ALIGN_CENTER)

	local description = IsValid(self.entity) and self.entity:GetTraderDescription() or ""

	if (description != "") then
		local lines = util.WrapText(description, "nwHudSmall", Sc(700), 2)
		local lineY = Sc(86)

		for i = 1, #lines do
			draw.SimpleText(lines[i], "nwHudSmall", centerX, lineY,
				ColorAlpha(theme.textDim, 225 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			lineY = lineY + Sc(16)
		end
	end

	for _, columnX in ipairs({self.columnX, self.rightX}) do
		local plateX = columnX - Sc(12)
		local plateY = self.columnY - Sc(10)
		local plateWidth = self.columnWidth + Sc(10)
		local plateHeight = self.columnHeight + Sc(20)

		surface.SetDrawColor(5, 8, 11, 168 * alpha)
		surface.DrawRect(plateX, plateY, plateWidth, plateHeight)

		surface.SetDrawColor(255, 255, 255, 12 * alpha)
		surface.DrawOutlinedRect(plateX, plateY, plateWidth, plateHeight, 1)

		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 200 * alpha)
		surface.DrawRect(plateX, plateY, Sc(22), math.max(Sc(2), 2))
		surface.DrawRect(plateX, plateY, math.max(Sc(2), 2), Sc(12))
	end

	local iconSize = Sc(16)
	local headerY = self.columnY - Sc(22)

	for _, header in ipairs({
		{x = self.columnX, key = "tradeGoods", icon = "framework/icons/shopping_cart.png"},
		{x = self.rightX, key = "tradeYours", icon = "framework/icons/paid.png"}
	}) do
		local material = util.GetMaterial(header.icon, "smooth")

		if (material and !material:IsError()) then
			surface.SetDrawColor(theme.accentSoft.r, theme.accentSoft.g, theme.accentSoft.b,
				240 * alpha)
			surface.SetMaterial(material)
			surface.DrawTexturedRect(header.x, headerY - math.Round(iconSize * 0.5),
				iconSize, iconSize)
		end

		util.DrawTextSpaced(util.Upper(L(header.key)), "nwSectionLabel",
			header.x + iconSize + Sc(8), headerY,
			ColorAlpha(theme.accentSoft, 240 * alpha), Sc(4), TEXT_ALIGN_CENTER)
	end

	surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 40 * alpha)
	surface.DrawRect(self.columnX + self.columnWidth + Sc(29), self.columnY,
		math.max(Sc(2), 1), self.columnHeight)

	local levelText = L("tradeLevel") .. " " .. (NETWORK.trade.level or 1) .. " / " ..
		NETWORK.trade.maxLevel

	util.DrawSimpleTextShadow(levelText, "nwChatSmall", centerX, self.columnY - Sc(52),
		ColorAlpha(Color(240, 200, 90), 245 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
		math.max(Sc(2), 1))

	local tokens = NETWORK.currency.Format(LocalPlayer():GetTokens())

	util.DrawSimpleTextShadow(tokens, "nwField", centerX, self.columnY + self.columnHeight +
		Sc(80), ColorAlpha(Color(240, 200, 90), 250 * alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER, math.max(Sc(2), 1))

	if (self.selected) then
		local base = NETWORK.item.Get(self.selected.entry.id)
		local line = (base and base.name or self.selected.entry.id) .. "  ·  " ..
			NETWORK.trade.Describe(self.selected.entry)

		util.DrawSimpleTextShadow(line, "nwHudSmall", centerX,
			self.columnY + self.columnHeight + Sc(102),
			ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER, math.max(Sc(2), 1))
	end
end

vgui.Register("nwTradePanel", PANEL, "EditablePanel")

function NETWORK.gui.OpenTrade(entity)
	NETWORK.gui.CloseWindows()

	local panel = vgui.Create("nwTradePanel")

	panel:Setup(entity)

	return panel
end

function NETWORK.gui.CloseTrade()
	if (IsValid(NETWORK.gui.trade)) then
		NETWORK.gui.trade:Remove()
	end

	NETWORK.gui.trade = nil
end
