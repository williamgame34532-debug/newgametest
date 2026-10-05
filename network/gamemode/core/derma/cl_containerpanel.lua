local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.container = self

	self.alpha = 0
	self.bClosing = false
	self.columns = NETWORK.inventory.columns
	self.cell = Sc(78)
	self.gap = Sc(6)
	self.frameWidth = Sc(1180)
	self.frameHeight = Sc(700)
	self.frameX = Sc(100)
	self.frameY = Sc(100)
	self.headerHeight = Sc(66)
	self.halfWidth = Sc(590)
	self.leftX = Sc(140)
	self.rightX = Sc(730)
	self.gridY = Sc(190)

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
end

function PANEL:Setup(entity)
	self.entity = entity

	self:Rebuild()
end

function PANEL:OnRemove()
	NETWORK.gui.ClearGrids()

	NETWORK.gui.container = nil
end

function PANEL:Layout()
	local Sc = NETWORK.util.Scale
	local width, height = ScrW(), ScrH()

	self.frameWidth = width - Sc(60)
	self.frameHeight = height - Sc(60)
	self.frameX = math.Round((width - self.frameWidth) * 0.5)
	self.frameY = math.Round((height - self.frameHeight) * 0.5)
	self.headerHeight = Sc(54)

	local pad = Sc(24)
	local gapColumn = Sc(28)
	local rest = self.frameWidth - pad * 2 - gapColumn

	self.leftWidth = math.Round(rest * 0.5)
	self.middleWidth = rest - self.leftWidth

	self.leftX = self.frameX + pad
	self.rightX = self.leftX + self.leftWidth + gapColumn
	self.gridY = self.frameY + self.headerHeight + Sc(40)
	self.bottomY = self.frameY + self.frameHeight - Sc(64)

	local rows = math.max(NETWORK.inventory.rows or 1,
		math.ceil(NETWORK.container.GetSlots() / self.columns), 1)
	local byWidth = math.floor((self.leftWidth - self.gap * (self.columns - 1)) / self.columns)
	local byHeight = math.floor((self.bottomY - self.gridY - Sc(10) - self.gap * (rows - 1)) / rows)

	self.cell = math.max(math.min(Sc(96), byWidth, byHeight), Sc(44))
end

function PANEL:Rebuild()
	local Sc = NETWORK.util.Scale

	for _, panel in ipairs(self:GetChildren()) do
		panel:Remove()
	end

	NETWORK.gui.ClearGrids()

	self:Layout()

	local columns = self.columns
	local containerRows = math.max(math.ceil(NETWORK.container.GetSlots() / columns), 1)

	NETWORK.gui.BuildGrid(self, "container", NETWORK.container.state.items, {
		x = self.rightX,
		y = self.gridY,
		cell = self.cell,
		gap = self.gap,
		columns = columns,
		rows = containerRows,
		OnClick = function(index)
			local item = NETWORK.container.GetItem(index)
			local free = item and NETWORK.inventory.FindSpot(NETWORK.inventory.state.items,
				columns, NETWORK.inventory.rows, item)

			if (free) then
				NETWORK.container.Move({list = "container", index = index},
					{list = "items", index = free})
			end
		end
	})

	NETWORK.gui.BuildGrid(self, "items", NETWORK.inventory.state.items, {
		x = self.leftX,
		y = self.gridY,
		cell = self.cell,
		gap = self.gap,
		columns = columns,
		rows = NETWORK.inventory.rows,
		OnClick = function(index)
			local item = NETWORK.inventory.GetItem(index)
			local free = item and NETWORK.inventory.FindSpot(NETWORK.container.state.items,
				columns, containerRows, item)

			if (free) then
				NETWORK.container.Move({list = "items", index = index},
					{list = "container", index = free})
			end
		end
	})

	self.action = self:Add("nwActionButton")
	self.action:SetPrimary(true)
	self.action:SetLabel(L("containerSwap"))
	self.action:SetSize(Sc(220), Sc(38))
	self.action:SetPos(self.rightX, self.bottomY + Sc(14))
	self.action.DoClick = function()
		NETWORK.container.Swap()
	end

	self.close = self:Add("nwActionButton")
	self.close:SetLabel(L("containerClose"))
	self.close:SetSize(Sc(220), Sc(38))
	self.close:SetPos(self.rightX + Sc(232), self.bottomY + Sc(14))
	self.close.DoClick = function()
		self:Close()
	end
end

function PANEL:Think()
	if (input.IsMouseDown(MOUSE_LEFT)) then
		if (!self.bHold) then
			self.bHold = true
			self.holdTime = RealTime()
		elseif (!NETWORK.gui.sweep and !NETWORK.gui.drag and
			RealTime() - self.holdTime > 0.25) then
			NETWORK.gui.sweep = {
				mode = "transfer",
				visited = {},
				startTime = RealTime()
			}
		end
	else
		self.bHold = false

		if (NETWORK.gui.sweep and NETWORK.gui.sweep.mode == "transfer") then
			NETWORK.gui.StopSweep()
		end
	end

	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 12)

	self:SetAlpha(math.Round(self.alpha * 255))

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()
	end
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	NETWORK.gui.drag = nil

	NETWORK.gui.CloseDragPreview()
	NETWORK.container.Request("close")

	self:SetMouseInputEnabled(false)
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
	local x, y = self.frameX, self.frameY
	local accent = theme.combine
	local line = math.max(Sc(1), 1)

	util.DrawBlur(self, 4 * alpha)

	surface.SetDrawColor(0, 0, 0, 150 * alpha)
	surface.DrawRect(0, 0, width, height)

	local S = NETWORK.style
	local radius = (S and S.Radius) and S.Radius("panel") or math.max(Sc(12), 6)

	if (S and S.Card) then
		S.Card(x, y, self.frameWidth, self.frameHeight, alpha, {
			radius = radius,
			blur = false,
			fill = Color(9, 13, 16, 228)
		})
	else
		draw.RoundedBox(radius, x, y, self.frameWidth, self.frameHeight,
			Color(9, 13, 16, 228 * alpha))
	end

	NETWORK.util.DrawScanlines(x + 1, y + radius, self.frameWidth - 2,
		self.frameHeight - radius * 2, 5 * alpha, math.max(Sc(3), 3), color_white)

	local name = IsValid(self.entity) and self.entity:GetDisplayName() or "?"
	local description = IsValid(self.entity) and self.entity:GetDisplayDescription() or ""

	draw.SimpleText(util.Upper(name), "nwInvTitle", x + Sc(24), y + Sc(30),
		ColorAlpha(theme.text, 252 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (description != "") then
		draw.SimpleText(util.TruncateWidth(description, "nwHudSmall", self.frameWidth - Sc(400)),
			"nwHudSmall", x + self.frameWidth - Sc(24), y + Sc(30),
			ColorAlpha(theme.textFaint, 230 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	local function Title(titleX, titleWidth, text, count, total)
		local titleY = y + self.headerHeight + Sc(8)
		local lineRight = titleX + titleWidth
		local caption = util.TruncateWidth(util.Upper(text), "nwInvKey",
			math.max(titleWidth - Sc(90), Sc(40)))
		local captionWidth = util.DrawTextSpaced(caption, "nwInvKey", titleX, titleY,
			ColorAlpha(theme.textFaint, 240 * alpha), math.max(Sc(2), 1), TEXT_ALIGN_CENTER)

		if (count and total) then
			local badge = count .. " / " .. total

			surface.SetFont("nwInvSub")

			lineRight = lineRight - surface.GetTextSize(badge) - Sc(10)

			draw.SimpleText(badge, "nwInvSub", titleX + titleWidth, titleY,
				ColorAlpha(accent, 245 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		local lineX = titleX + captionWidth + Sc(10)

		if (lineRight > lineX) then
			surface.SetDrawColor(150, 196, 220, 40 * alpha)
			surface.DrawRect(lineX, titleY, lineRight - lineX, line)
		end
	end

	Title(self.leftX, self.leftWidth, L("invYours"),
		table.Count(NETWORK.inventory.state.items or {}), NETWORK.inventory.GetSize())
	Title(self.rightX, self.middleWidth, name,
		table.Count(NETWORK.container.state.items or {}), NETWORK.container.GetSlots())

	draw.SimpleText(L("containerHintYours"), "nwHudSmall", self.leftX, self.bottomY + Sc(33),
		ColorAlpha(theme.textFaint, 200 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local dividerX = self.rightX - math.Round(Sc(28) * 0.5)
	local arrowY = self.gridY + math.Round((self.bottomY - self.gridY) * 0.5)

	surface.SetDrawColor(150, 196, 220, 30 * alpha)
	surface.DrawRect(dividerX, self.gridY, line, self.bottomY - self.gridY - Sc(10))

	draw.SimpleText(">", "nwInvTitle", dividerX, arrowY - Sc(12),
		ColorAlpha(accent, 240 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("<", "nwInvTitle", dividerX, arrowY + Sc(12),
		ColorAlpha(theme.textFaint, 220 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(150, 196, 220, 30 * alpha)
	surface.DrawRect(x + Sc(24), self.bottomY, self.frameWidth - Sc(48), line)
end

vgui.Register("nwContainerPanel", PANEL, "EditablePanel")

function NETWORK.gui.OpenContainer(entity)
	NETWORK.gui.CloseWindows()

	local panel = vgui.Create("nwContainerPanel")

	panel:Setup(entity)

	return panel
end

function NETWORK.gui.CloseContainer()
	if (IsValid(NETWORK.gui.container)) then
		NETWORK.gui.container:Remove()
	end

	NETWORK.gui.container = nil
end

local function RefreshContainer()
	if (!IsValid(NETWORK.gui.container)) then
		return
	end

	NETWORK.gui.instantUntil = CurTime() + 0.2

	NETWORK.gui.container:Rebuild()

	NETWORK.gui.instantUntil = 0
end

hook.Add("NetworkContainerUpdated", "nwContainer", RefreshContainer)
hook.Add("NetworkInventoryUpdated", "nwContainerInventory", RefreshContainer)

local CONFIG = {}

function CONFIG:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0

	self:SetSize(math.min(Sc(460), math.Round(ScrW() * 0.5)),
		math.min(Sc(372), math.Round(ScrH() * 0.66)))
	self:Center()
	self:MakePopup()

	self.name = self:Add("DTextEntry")
	self.description = self:Add("DTextEntry")
	self.refill = self:Add("DTextEntry")

	for _, entry in ipairs({self.name, self.description, self.refill}) do
		entry:SetFont("nwChatSmall")
		entry:SetPaintBackground(false)
		entry:SetDrawLanguageID(false)
		entry:SetTextColor(NETWORK.theme.text)
		entry:SetCursorColor(NETWORK.theme.combine)
		entry:SetTextInset(Sc(8), 0)
		entry.Paint = function(panel, width, height)
			local radius = math.max(Sc(6), 4)

			draw.RoundedBox(radius, 0, 0, width, height, Color(10, 11, 13, 230))

			NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
				panel:HasFocus() and ColorAlpha(NETWORK.theme.combine, 210) or
				Color(255, 255, 255, 30))

			panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.combineDeep,
				NETWORK.theme.combine)
		end
	end

	self.description:SetMultiline(true)

	self.save = self:Add("nwActionButton")
	self.save:SetLabel(L("zoneSave"))
	self.save:SetPrimary(true)
	self.save.DoClick = function()
		if (IsValid(self.entity)) then
			NETWORK.container.SendConfig(self.entity, self.name:GetValue(),
				self.description:GetValue(), self.refill:GetValue())
		end

		self:Remove()
	end
end

function CONFIG:Setup(entity)
	self.entity = entity

	self.name:SetValue(entity:GetContainerName())
	self.description:SetValue(entity:GetContainerDescription())
	self.refill:SetValue(entity:GetContainerRefill())
end

function CONFIG:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.name:SetPos(Sc(20), Sc(74))
	self.name:SetSize(width - Sc(40), Sc(34))

	self.description:SetPos(Sc(20), Sc(140))
	self.description:SetSize(width - Sc(40), Sc(84))

	self.refill:SetPos(Sc(20), Sc(258))
	self.refill:SetSize(width - Sc(40), Sc(34))

	self.save:SetPos(Sc(20), height - Sc(56))
	self.save:SetSize(width - Sc(40), Sc(40))
end

function CONFIG:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 12)
end

function CONFIG:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function CONFIG:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util

	util.DrawBlur(self, 5 * self.alpha, 0.3)

	NETWORK.gui.DrawSurface(0, 0, width, height, self.alpha, {
		radius = Sc(12),
		base = Color(12, 13, 16),
		baseAlpha = 248,
		lift = 1
	})

	util.DrawTextSpaced(util.Upper(L("containerConfig")), "nwTab", Sc(20), Sc(28),
		ColorAlpha(theme.text, 250 * self.alpha), Sc(4), TEXT_ALIGN_CENTER)

	draw.SimpleText(L("zoneName"), "nwChatSmall", Sc(20), Sc(60),
		ColorAlpha(theme.textDim, 230 * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(L("labelDescription"), "nwChatSmall", Sc(20), Sc(126),
		ColorAlpha(theme.textDim, 230 * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(L("containerRefill"), "nwChatSmall", Sc(20), Sc(244),
		ColorAlpha(theme.textDim, 230 * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local refill = IsValid(self.entity) and self.entity:GetContainerRefill() or 0

	draw.SimpleText(refill > 0 and L("containerRefillOn", refill) or
		L("containerRefillOff"), "nwHudSmall", width - Sc(20), Sc(244),
		ColorAlpha(refill > 0 and theme.combine or theme.textFaint,
		230 * self.alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

vgui.Register("nwContainerConfig", CONFIG, "EditablePanel")

function NETWORK.gui.OpenContainerConfig(entity)
	if (!IsValid(entity)) then
		return
	end

	local panel = vgui.Create("nwContainerConfig")

	panel:Setup(entity)

	return panel
end

local LOOT = {}

function LOOT:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0
	self.items = {}

	self:SetSize(math.min(Sc(520), math.Round(ScrW() * 0.5)),
		math.min(Sc(560), math.Round(ScrH() * 0.78)))
	self:Center()
	self:MakePopup()

	self.list = self:Add("DScrollPanel")

	local bar = self.list:GetVBar()

	bar:SetWide(Sc(4))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(2), 0, 0, width, height, Color(255, 255, 255, 60))
	end

	self.save = self:Add("nwActionButton")
	self.save:SetLabel(L("zoneSave"))
	self.save:SetPrimary(true)
	self.save.DoClick = function()
		if (IsValid(self.entity)) then
			NETWORK.container.SendLoot(self.entity, self.items)
		end

		self:Remove()
	end
end

function LOOT:Setup(entity)
	local Sc = NETWORK.util.Scale

	self.entity = entity
	self.items = {}

	for _, item in pairs(NETWORK.container.state.items) do
		self.items[item.id] = (self.items[item.id] or 0) + 1
	end

	self.list:Clear()

	for _, base in ipairs(NETWORK.item.GetAll()) do
		local id = base.id
		local row = self.list:Add("DPanel")

		row:Dock(TOP)
		row:DockMargin(0, 0, Sc(14), Sc(3))
		row:SetTall(Sc(34))
		row.Paint = function(panel, width, height)
			local rarity = NETWORK.inventory.GetRarity(base.rarity)

			draw.RoundedBox(Sc(2), Sc(4), Sc(9), math.max(Sc(3), 2), height - Sc(18),
				ColorAlpha(rarity.color, 235))

			draw.SimpleText(base.name, "nwChatSmall", Sc(16), math.Round(height * 0.5),
				ColorAlpha(NETWORK.theme.text, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(tostring(self.items[id] or 0), "nwField", width - Sc(96),
				math.Round(height * 0.5), ColorAlpha(NETWORK.theme.combine, 245),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		local function Button(label, callback, offset)
			local button = row:Add("DButton")

			button:SetText("")
			button:SetCursor("hand")
			button:SetSize(Sc(26), Sc(26))
			button.hover = 0
			button.Think = function(panel)
				panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
			end
			button.Paint = function(panel, width, height)
				draw.RoundedBox(Sc(6), 0, 0, width, height,
					Color(255, 255, 255, 14 + 18 * panel.hover))

				draw.SimpleText(label, "nwChatSmall", math.Round(width * 0.5),
					math.Round(height * 0.5), ColorAlpha(NETWORK.theme.text, 235),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			button.DoClick = callback

			row.PerformLayout = function(panel, width, height)
				for index, child in ipairs(panel:GetChildren()) do
					child:SetPos(width - Sc(64) + (index - 1) * Sc(30), Sc(4))
				end
			end

			return button
		end

		Button("-", function()
			self.items[id] = math.max((self.items[id] or 0) - 1, 0)

			if (self.items[id] == 0) then
				self.items[id] = nil
			end
		end)

		Button("+", function()
			self.items[id] = (self.items[id] or 0) + 1
		end)
	end
end

function LOOT:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.list:SetPos(Sc(16), Sc(56))
	self.list:SetSize(width - Sc(32), height - Sc(116))

	self.save:SetPos(Sc(16), height - Sc(52))
	self.save:SetSize(width - Sc(32), Sc(40))
end

function LOOT:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 12)
end

function LOOT:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function LOOT:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util

	util.DrawBlur(self, 5 * self.alpha, 0.3)

	NETWORK.gui.DrawSurface(0, 0, width, height, self.alpha, {
		radius = Sc(12),
		base = Color(12, 13, 16),
		baseAlpha = 248,
		lift = 1
	})

	util.DrawTextSpaced(util.Upper(L("containerLoot")), "nwTab", Sc(20), Sc(28),
		ColorAlpha(NETWORK.theme.text, 250 * self.alpha), Sc(4), TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 12 * self.alpha)
	surface.DrawRect(Sc(14), Sc(48), width - Sc(28), 1)
end

vgui.Register("nwContainerLoot", LOOT, "EditablePanel")

function NETWORK.gui.OpenContainerLoot(entity)
	if (!IsValid(entity)) then
		return
	end

	local panel = vgui.Create("nwContainerLoot")

	panel:Setup(entity)

	return panel
end

local PICKER = {}

function PICKER:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0
	self.rows = {}

	self:SetSize(math.min(Sc(440), math.Round(ScrW() * 0.5)),
		math.min(Sc(520), math.Round(ScrH() * 0.78)))
	self:Center()
	self:MakePopup()

	self.search = self:Add("DTextEntry")
	self.search:SetFont("nwChatSmall")
	self.search:SetPaintBackground(false)
	self.search:SetDrawLanguageID(false)
	self.search:SetUpdateOnType(true)
	self.search:SetPlaceholderText(L("containerPickerSearch"))
	self.search.Paint = function(panel, width, height)
		local radius = math.max(Sc(6), 4)

		draw.RoundedBox(radius, 0, 0, width, height, Color(10, 11, 13, 235))

		NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, 1,
			panel:HasFocus() and ColorAlpha(NETWORK.theme.combine, 210) or
			Color(255, 255, 255, 30))

		if (panel:GetValue() == "") then
			draw.SimpleText(panel:GetPlaceholderText() or "", "nwChatSmall", Sc(8),
				math.Round(height * 0.5), ColorAlpha(NETWORK.theme.textFaint, 220),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.combineDeep,
			NETWORK.theme.combine)
	end
	self.search.OnValueChange = function(_, value)
		self:Filter(value)
	end

	self.list = self:Add("DScrollPanel")

	local bar = self.list:GetVBar()

	bar:SetWide(Sc(4))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(panel, width, height)
		draw.RoundedBox(math.floor(width * 0.5), 0, 0, width, height, Color(255, 255, 255, 60))
	end
end

function PICKER:AddRow(id, name, bCurrent)
	local Sc = NETWORK.util.Scale
	local row = self.list:Add("DButton")

	row:SetText("")
	row:SetCursor("hand")
	row:Dock(TOP)
	row:DockMargin(0, 0, Sc(8), Sc(2))
	row:SetTall(Sc(30))
	row.hover = 0
	row.search = string.lower(id .. " " .. name)
	row.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 14)
	end
	row.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local radius = math.max(Sc(6), 4)
		local rail = math.max(Sc(3), 2)

		draw.RoundedBox(radius, 0, 0, width, height, Color(255, 255, 255, 8 + 16 * panel.hover))

		if (bCurrent) then
			draw.RoundedBox(math.floor(rail * 0.5), Sc(4), Sc(6), rail, height - Sc(12),
				Color(theme.combine.r, theme.combine.g, theme.combine.b, 235))
		end

		draw.SimpleText(name, "nwChatSmall", Sc(12), math.Round(height * 0.5),
			ColorAlpha(theme.text, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(id, "nwHudSmall", width - Sc(10), math.Round(height * 0.5),
			ColorAlpha(theme.textFaint, 230), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	row.DoClick = function()
		local callback = self.callback

		self:Remove()

		if (callback) then
			callback(id)
		end
	end

	self.rows[#self.rows + 1] = row
end

function PICKER:Setup(title, current, callback)
	self.title = title or ""
	self.callback = callback

	self:AddRow("", L("containerPickerNone"), (current or "") == "")

	for _, base in ipairs(NETWORK.item.GetAll()) do
		self:AddRow(base.id, base.name or base.id, base.id == current)
	end

	self.search:RequestFocus()
end

function PICKER:Filter(text)
	text = string.lower(string.Trim(text or ""))

	for _, row in ipairs(self.rows) do
		row:SetVisible(text == "" or string.find(row.search, text, 1, true) != nil)
	end

	self.list:InvalidateLayout(true)
	self.list:GetCanvas():InvalidateLayout(true)
end

function PICKER:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.search:SetPos(Sc(16), Sc(56))
	self.search:SetSize(width - Sc(32), Sc(32))

	self.list:SetPos(Sc(16), Sc(98))
	self.list:SetSize(width - Sc(32), height - Sc(114))
end

function PICKER:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 12)
end

function PICKER:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PICKER:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme

	local S = NETWORK.style

	if (S and S.Card) then
		S.Card(0, 0, width, height, self.alpha, {
			radius = S.Radius("panel"),
			panel = self,
			shadow = false,
			accent = theme.combine,
			fill = Color(12, 13, 16, 248)
		})
	else
		util.DrawBlur(self, 5 * self.alpha, 0.3)

		draw.RoundedBox(math.max(Sc(12), 6), 0, 0, width, height,
			Color(12, 13, 16, 248 * self.alpha))
	end

	util.DrawTextSpaced(util.Upper(self.title or ""), "nwTab", Sc(20), Sc(28),
		ColorAlpha(theme.text, 250 * self.alpha), Sc(4), TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 12 * self.alpha)
	surface.DrawRect(Sc(14), Sc(46), width - Sc(28), 1)
end

vgui.Register("nwItemPicker", PICKER, "EditablePanel")

function NETWORK.gui.OpenItemPicker(title, current, callback)
	if (IsValid(NETWORK.gui.itemPicker)) then
		NETWORK.gui.itemPicker:Remove()
	end

	local panel = vgui.Create("nwItemPicker")

	panel:Setup(title, current, callback)

	NETWORK.gui.itemPicker = panel

	return panel
end
