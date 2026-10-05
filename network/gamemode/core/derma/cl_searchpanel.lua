local function GetSlots(payload)
	local equipped = (payload or {}).equipped or {}
	local list = {}

	for _, group in ipairs(NETWORK.inventory.equipment) do
		for _, slot in ipairs(group.slots) do
			if (equipped[slot.id]) then
				list[#list + 1] = slot
			end
		end
	end

	return list
end

local function DrawIcon(path, x, y, size, color, alpha)
	local material = NETWORK.util.GetMaterial(path, "smooth")

	if (!material or material:IsError()) then
		return false
	end

	alpha = alpha or 1

	surface.SetMaterial(material)
	surface.SetDrawColor(0, 0, 0, 170 * alpha)
	surface.DrawTexturedRect(x + 1, y + 1, size, size)

	surface.SetDrawColor(color.r, color.g, color.b, (color.a or 255) * alpha)
	surface.DrawTexturedRect(x, y, size, size)

	return true
end

local function Chip(rightX, middle, icon, text, color, alpha)
	local Sc = NETWORK.util.Scale

	surface.SetFont("nwInvKey")

	local textWidth = surface.GetTextSize(text)
	local iconSize = Sc(14)
	local padX = Sc(8)
	local height = Sc(22)
	local width = padX * 2 + iconSize + Sc(6) + textWidth
	local x = rightX - width
	local y = middle - math.Round(height * 0.5)

	surface.SetDrawColor(255, 255, 255, 10 * alpha)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(color.r, color.g, color.b, 90 * alpha)
	surface.DrawOutlinedRect(x, y, width, height, 1)

	DrawIcon(icon, x + padX, middle - math.Round(iconSize * 0.5), iconSize, color, alpha)

	draw.SimpleText(text, "nwInvKey", x + padX + iconSize + Sc(6), middle,
		ColorAlpha(color, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	return x - Sc(8)
end

local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.search = self

	self.alpha = 0
	self.bClosing = false
	self.cell = Sc(62)
	self.gap = Sc(5)
	self.pad = Sc(24)
	self.colGap = Sc(24)
	self.headerHeight = Sc(60)
	self.titleBand = Sc(34)
	self.barHeight = Sc(36)
	self.actions = {}

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
end

function PANEL:GetBagRows()
	local slots = tonumber((self.payload or {}).storageSlots) or 0

	if (slots <= 0) then
		return 0
	end

	return math.ceil(slots / NETWORK.inventory.columns)
end

function PANEL:IsCorpse()
	local payload = self.payload or {}

	if (payload.bCorpse != nil) then
		return payload.bCorpse == true
	end

	return IsValid(self.target) and !self.target:IsPlayer()
end

function PANEL:Layout()
	local Sc = NETWORK.util.Scale
	local columns = NETWORK.inventory.columns
	local rows = NETWORK.inventory.rows
	local bagRows = self:GetBagRows()
	local equipCount = math.max(#GetSlots(self.payload), 1)

	local fixed = self.pad * 2 + self.colGap * 2
	local byWidth = math.floor((ScrW() - Sc(40) - fixed) / (columns * 3)) - self.gap

	local overhead = self.headerHeight + self.titleBand + Sc(16) + Sc(10) + self.barHeight +
		Sc(8) + Sc(22) + Sc(10) + Sc(40)
	local available = ScrH() - overhead
	local byHeight = math.floor(available / rows) - self.gap

	if (bagRows > 0) then
		local equipMin = equipCount * Sc(18) + Sc(30)

		byHeight = math.min(byHeight, math.floor((available - equipMin) / bagRows) - self.gap)
	end

	self.cell = math.max(math.min(Sc(62), byWidth, byHeight), Sc(36))

	local step = self.cell + self.gap

	self.gridWidth = columns * step - self.gap
	self.gridHeight = rows * step - self.gap
	self.equipWidth = self.gridWidth
	self.bagHeight = bagRows > 0 and (bagRows * step - self.gap) or 0

	local equipBudget = self.gridHeight - (bagRows > 0 and (self.bagHeight + Sc(30)) or 0)

	self.rowHeight = math.Clamp(math.floor(equipBudget / equipCount), Sc(18), Sc(26))
	self.equipHeight = self.rowHeight * equipCount
	self.rightHeight = self.equipHeight + (bagRows > 0 and (Sc(30) + self.bagHeight) or 0)
	self.contentHeight = math.max(self.gridHeight, self.rightHeight)

	self.frameWidth = self.pad * 2 + self.gridWidth * 3 + self.colGap * 2

	local bottom = self.headerHeight + self.titleBand + self.contentHeight + Sc(16)

	self.frameHeight = bottom + Sc(10) + self.barHeight + Sc(8) + Sc(22) + Sc(10)
	self.frameX = math.Round((ScrW() - self.frameWidth) * 0.5)
	self.frameY = math.Round((ScrH() - self.frameHeight) * 0.5)
	self.mineX = self.frameX + self.pad
	self.theirsX = self.mineX + self.gridWidth + self.colGap
	self.equipX = self.theirsX + self.gridWidth + self.colGap
	self.titleY = self.frameY + self.headerHeight + Sc(10)
	self.gridY = self.frameY + self.headerHeight + self.titleBand
	self.bagTitleY = self.gridY + self.equipHeight + Sc(8)
	self.bagY = self.gridY + self.equipHeight + Sc(30)
	self.bottomY = self.frameY + bottom
	self.barY = self.bottomY + Sc(10)
	self.hintY = self.barY + self.barHeight + Sc(8) + Sc(11)
end

function PANEL:GetGrid(bTheirs)
	local columns = NETWORK.inventory.columns
	local rows = NETWORK.inventory.rows

	return bTheirs and self.theirsX or self.mineX, self.gridY, self.gridWidth,
		self.gridHeight, columns, rows
end

local function MakeTakeSlot(panel, slot, list, index, slotID)
	slot.OnMousePressed = function(this, code)
		if (!this:GetItem()) then
			return
		end

		NETWORK.gui.ClearTooltip(this)

		if (code == MOUSE_RIGHT) then
			panel:OpenTheirMenu(this, list, index, slotID)

			return
		end

		if (code == MOUSE_LEFT) then
			panel:Take(list, index, slotID)
		end
	end
	slot.OnMouseReleased = function() end
end

function PANEL:BindTheirSlots()
	for _, child in ipairs(self:GetChildren()) do
		local index = tonumber(child.index)

		if (!NETWORK.gui.IsSearchList(child.list) or !index or index <= 0 or
			child.bSearchBound) then
			continue
		end

		child.bSearchBound = true

		local base = child.OnMousePressed

		child.OnMousePressed = function(this, code)
			if (code == MOUSE_RIGHT) then
				if (this:GetItem()) then
					NETWORK.gui.ClearTooltip(this)

					self:OpenTheirMenu(this)
				end

				return
			end

			if (code == MOUSE_LEFT and input.IsShiftDown()) then
				if (this:GetItem()) then
					NETWORK.gui.ClearTooltip(this)

					self:TakeSource(this:GetSource())
				end

				return
			end

			if (base) then
				return base(this, code)
			end
		end
	end
end

function PANEL:Rebuild()
	local Sc = NETWORK.util.Scale

	for _, child in ipairs(self:GetChildren()) do
		child:Remove()
	end

	self.actions = {}
	self.pack = nil

	NETWORK.gui.ClearGrids()

	self:Layout()

	local payload = self.payload or {}
	local columns = NETWORK.inventory.columns
	local rows = NETWORK.inventory.rows
	local bagRows = self:GetBagRows()

	NETWORK.gui.BuildGrid(self, "items", NETWORK.inventory.state.items, {
		x = self.mineX,
		y = self.gridY,
		cell = self.cell,
		gap = self.gap,
		columns = columns,
		rows = rows
	})

	NETWORK.gui.BuildGrid(self, "search", payload.items or {}, {
		x = self.theirsX,
		y = self.gridY,
		cell = self.cell,
		gap = self.gap,
		columns = columns,
		rows = rows,
		OnClick = function(index)
			self:Take("items", index)
		end
	})

	if (bagRows > 0) then
		NETWORK.gui.BuildGrid(self, "searchbag", payload.storage or {}, {
			x = self.equipX,
			y = self.bagY,
			cell = self.cell,
			gap = self.gap,
			columns = columns,
			rows = bagRows,
			OnClick = function(index)
				self:Take("storage", index)
			end
		})
	end

	self:BindTheirSlots()

	local equipped = payload.equipped or {}

	for position, data in ipairs(GetSlots(payload)) do
		local slot = self:Add("nwItemSlot")

		slot:SetSize(self.equipWidth, self.rowHeight)
		slot:SetPos(self.equipX, self.gridY + (position - 1) * self.rowHeight)
		slot:SetRow(true)
		slot:SetSlotName(L(data.name))
		slot:SetRevealDelay(0.05 + position * 0.02)
		slot:SetSource("search", 0, data.id)
		slot:SetItem(equipped[data.id])

		MakeTakeSlot(self, slot, "equipped", 0, data.id)
	end

	self:BuildActions()
end

function PANEL:BuildActions()
	local Sc = NETWORK.util.Scale

	for _, button in ipairs(self.actions or {}) do
		if (IsValid(button)) then
			button:Remove()
		end
	end

	self.actions = {}
	self.pack = nil

	if (!self.frameX) then
		return
	end

	local payload = self.payload or {}
	local bCorpse = self:IsCorpse()
	local client = LocalPlayer()

	local function Add(label, bPrimary, callback)
		local button = self:Add("nwActionButton")

		button:SetLabel(label)
		button:SetPrimary(bPrimary)
		button:SetSize(NETWORK.util.TextSpacedSize(button.label, "nwTab", Sc(3)) + Sc(36),
			self.barHeight)
		button.DoClick = callback

		self.actions[#self.actions + 1] = button

		return button
	end

	if (next(payload.items or {}) != nil) then
		Add(L("searchTakeAll"), true, function()
			self:TakeAll()
		end)
	end

	if (!bCorpse and (tonumber(payload.tokens) or 0) > 0) then
		Add(L("searchTokens"), false, function()
			self:AskTokens()
		end)
	end

	if (!bCorpse and payload.bTied and IsValid(client) and
		(NETWORK.factions.IsAlliance(client) or client:IsAdmin())) then
		Add(L("searchUntie"), false, function()
			self:Untie()
		end)
	end

	if (self:CanPack()) then
		self.pack = Add(L("bodybagPack"), false, function()
			self:Pack()
		end)
	end

	if (!IsValid(self.cornerClose)) then
		local corner = self:Add("DButton")

		corner:SetText("")
		corner:SetCursor("hand")
		corner.hover = 0
		corner.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 10)
		end
		corner.Paint = function(panel, width, height)
			local theme = NETWORK.theme
			local line = math.max(Sc(1), 1)

			surface.SetDrawColor(255, 255, 255, (8 + 20 * panel.hover) * 255 / 255)
			surface.DrawRect(0, 0, width, height)
			surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b, 80 + 120 * panel.hover)
			surface.DrawOutlinedRect(0, 0, width, height, line)

			local material = NETWORK.util.GetMaterial("framework/chat/ui_close.png", "smooth")

			if (material and !material:IsError()) then
				local size = Sc(14)

				surface.SetMaterial(material)
				surface.SetDrawColor(255, 255, 255, 220)
				surface.DrawTexturedRect(math.Round((width - size) * 0.5), math.Round((height - size) * 0.5), size, size)
			else
				draw.SimpleText("×", "nwInvName", math.Round(width * 0.5), math.Round(height * 0.5),
					theme.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
		corner.DoClick = function()
			self:Close()
		end

		self.cornerClose = corner
	end

	self.cornerClose:SetSize(Sc(26), Sc(26))
	self.cornerClose:SetPos(self.frameX + self.frameWidth - Sc(10) - Sc(26), self.frameY + Sc(10))

	local close = Add(L("containerClose"), false, function()
		self:Close()
	end)

	local x = self.mineX

	for _, button in ipairs(self.actions) do
		if (button == close) then
			continue
		end

		button:SetPos(x, self.barY)

		x = x + button:GetWide() + Sc(8)
	end

	close:SetPos(self.frameX + self.frameWidth - self.pad - close:GetWide(), self.barY)
end

function PANEL:OnRemove()
	if (NETWORK.gui.search == self) then
		NETWORK.gui.search = nil
	end

	for list, grid in pairs(NETWORK.gui.grids or {}) do
		if (grid.panel == self) then
			NETWORK.gui.grids[list] = nil
		end
	end
end

function PANEL:Setup(target, payload)
	self.target = target
	self.payload = payload

	self:Rebuild()
end

function PANEL:HasBodybag()
	local state = NETWORK.inventory.state

	for _, list in ipairs({"items", "storage"}) do
		for _, item in pairs(state[list] or {}) do
			if (istable(item) and item.id == "bodybag") then
				return true
			end
		end
	end

	return false
end

function PANEL:CanPack()
	local target = self.target

	if (!IsValid(target) or target:IsPlayer()) then
		return false
	end

	local class = target:GetClass()

	if (class != "prop_ragdoll" and class != "nw_ragdoll") then
		return false
	end

	return self:HasBodybag()
end

function PANEL:Pack()
	if (!IsValid(self.target)) then
		return
	end

	net.Start("nwBodybagPack")
		net.WriteEntity(self.target)
	net.SendToServer()

	self:Close()
end

function PANEL:SetPayload(payload)
	self.payload = payload

	self:Rebuild()
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	NETWORK.gui.drag = nil

	if (NETWORK.gui.CloseDragPreview) then
		NETWORK.gui.CloseDragPreview()
	end

	net.Start("nwSearchClose")
	net.SendToServer()

	self:SetMouseInputEnabled(false)
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE or key == KEY_TAB) then
		self:Close()
	end
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 12)

	self:SetAlpha(math.Round(self.alpha * 255))

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()

		return
	end

	if ((self.nextPackCheck or 0) < RealTime()) then
		self.nextPackCheck = RealTime() + 0.5

		if (self:CanPack() != IsValid(self.pack)) then
			self:BuildActions()
		end
	end
end

function PANEL:Take(list, index, slot)
	net.Start("nwSearchTake")
		net.WriteString(list)
		net.WriteUInt(index or 0, 16)
		net.WriteString(slot or "")
	net.SendToServer()

	surface.PlaySound("physics/cardboard/cardboard_box_impact_soft2.wav")
end

function PANEL:TakeSource(source)
	if (!source) then
		return
	end

	if (source.list == "searchbag") then
		return self:Take("storage", source.index)
	end

	if (source.slot and source.slot != "") then
		return self:Take("equipped", 0, source.slot)
	end

	self:Take("items", source.index)
end

function PANEL:TakeAll()
	net.Start("nwSearchTakeAll")
	net.SendToServer()
end

function PANEL:Drop(index)
	net.Start("nwSearchDrop")
		net.WriteUInt(index or 0, 16)
	net.SendToServer()

	surface.PlaySound("physics/cardboard/cardboard_box_impact_soft1.wav")
end

function PANEL:Untie()
	net.Start("nwSearchUntie")
	net.SendToServer()
end

function PANEL:AskTokens()
	local tokens = tonumber((self.payload or {}).tokens) or 0

	if (tokens <= 0) then
		return
	end

	NETWORK.gui.Prompt(L("searchTokens"), L("searchTokensPrompt"), tostring(tokens),
		function(text)
			local amount = math.floor(tonumber(text) or 0)

			if (amount <= 0) then
				return
			end

			net.Start("nwSearchTokens")
				net.WriteUInt(math.min(amount, 4294967295), 32)
			net.SendToServer()
		end)
end

function PANEL:OpenTheirMenu(slot, list, index, slotID)
	local item = slot:GetItem()

	if (!item) then
		return
	end

	local source = slot:GetSource()

	if (list) then
		source = {list = list == "storage" and "searchbag" or "search", index = index,
			slot = slotID}
	end

	local menu = NETWORK.gui.ContextMenu(NETWORK.theme.combine)

	menu:SetHeader(NETWORK.item.GetName(item),
		L(source.list == "searchbag" and "searchTheirBag" or
			((source.slot and source.slot != "") and "searchTheirGear" or "searchTheirItems")))

	menu:AddOption(L("searchTake"), function()
		self:TakeSource(source)
	end):SetGlyph("plus")

	if (source.list == "search" and (!source.slot or source.slot == "")) then
		menu:AddOption(L("searchDrop"), function()
			self:Drop(source.index)
		end):SetGlyph("minus"):SetDanger(true)
	end

	menu:Open()
end

function PANEL:Paint(width, height)
	if (!self.frameX) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = 1
	local x, y = self.frameX, self.frameY
	local accent = theme.combine
	local line = math.max(Sc(1), 1)
	local payload = self.payload or {}
	local bCorpse = self:IsCorpse()
	local slots = GetSlots(payload)
	local bagRows = self:GetBagRows()

	surface.SetDrawColor(0, 0, 0, 150 * alpha)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(10, 11, 13, 225 * alpha)
	surface.DrawRect(x, y, self.frameWidth, self.frameHeight)

	surface.SetDrawColor(255, 255, 255, 22 * alpha)
	surface.DrawOutlinedRect(x, y, self.frameWidth, self.frameHeight, line)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 200 * alpha)
	surface.DrawRect(x, y, self.frameWidth, math.max(Sc(2), 2))

	local middle = y + Sc(2) + math.Round(self.headerHeight * 0.5)
	local iconSize = Sc(26)
	local iconX = x + self.pad

	DrawIcon("framework/status/searched.png", iconX, middle - math.Round(iconSize * 0.5),
		iconSize, accent, alpha)

	local textX = iconX + iconSize + Sc(12)

	draw.SimpleText(util.Upper(L("searchTitle")), "nwInvKey", textX, middle - Sc(11),
		ColorAlpha(accent, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(util.TruncateWidth(payload.name or L("searchThem"), "nwInvTitle",
		math.Round(self.frameWidth * 0.45)), "nwInvTitle", textX, middle + Sc(8),
		ColorAlpha(theme.text, 252 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local chipX = x + self.frameWidth - self.pad

	chipX = Chip(chipX, middle, "framework/icons/backpack.png",
		L("searchCount", table.Count(payload.items or {})), theme.textDim, alpha)

	if (payload.bTied) then
		chipX = Chip(chipX, middle, "framework/status/tied.png", L("searchTied"),
			theme.danger, alpha)
	end

	if (!bCorpse) then
		chipX = Chip(chipX, middle, "framework/icons/paid.png",
			NETWORK.currency.Format(tonumber(payload.tokens) or 0), theme.warning, alpha)
	end

	surface.SetDrawColor(255, 255, 255, 14 * alpha)
	surface.DrawRect(x + self.pad, y + self.headerHeight, self.frameWidth - self.pad * 2, line)

	local function Title(titleX, titleY, titleWidth, text, count, total, color)
		color = color or accent

		draw.SimpleText(util.Upper(text), "nwInvKey", titleX, titleY,
			ColorAlpha(color, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (count and total) then
			draw.SimpleText(count .. " / " .. total, "nwInvSub", titleX + titleWidth, titleY,
				ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		surface.SetDrawColor(color.r, color.g, color.b, 110 * alpha)
		surface.DrawRect(titleX, titleY + Sc(14), titleWidth, line)
	end

	local columns = NETWORK.inventory.columns
	local rows = NETWORK.inventory.rows

	Title(self.mineX, self.titleY, self.gridWidth, L("searchMine"),
		table.Count(NETWORK.inventory.state.items or {}), NETWORK.inventory.GetSize(),
		theme.textFaint)
	Title(self.theirsX, self.titleY, self.gridWidth, L("searchTheirItems"),
		table.Count(payload.items or {}), columns * rows)
	Title(self.equipX, self.titleY, self.equipWidth, L("searchTheirGear"),
		#slots > 0 and #slots or nil, #slots > 0 and #slots or nil)

	if (#slots == 0) then
		draw.SimpleText(L("searchNoGear"), "nwHudSmall", self.equipX,
			self.gridY + math.Round(self.rowHeight * 0.5), ColorAlpha(theme.textFaint, 240 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	if (bagRows > 0) then
		Title(self.equipX, self.bagTitleY, self.equipWidth, L("searchTheirBag"),
			table.Count(payload.storage or {}), tonumber(payload.storageSlots) or 0)
	end

	local dividerX = self.theirsX - math.Round(self.colGap * 0.5)
	local arrowY = self.gridY + math.Round(self.gridHeight * 0.5)

	surface.SetDrawColor(255, 255, 255, 12 * alpha)
	surface.DrawRect(dividerX, self.gridY, line, self.contentHeight)

	draw.SimpleText("<", "nwInvTitle", dividerX, arrowY,
		ColorAlpha(accent, 240 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 14 * alpha)
	surface.DrawRect(x + self.pad, self.bottomY, self.frameWidth - self.pad * 2, line)

	local hint = L("searchHintNew")
	local hintIcon = Sc(14)

	surface.SetFont("nwHudSmall")

	local hintWidth = surface.GetTextSize(hint)
	local hintX = x + math.Round((self.frameWidth - hintWidth - hintIcon - Sc(8)) * 0.5)

	DrawIcon("framework/icons/info.png", hintX, self.hintY - math.Round(hintIcon * 0.5),
		hintIcon, theme.textDim, alpha)

	draw.SimpleText(hint, "nwHudSmall", hintX + hintIcon + Sc(8), self.hintY,
		ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("nwSearchPanel", PANEL, "EditablePanel")

function NETWORK.gui.IsSearchList(list)
	return list == "search" or list == "searchbag"
end

function NETWORK.gui.SearchItemAt(source)
	local panel = NETWORK.gui.search

	if (!IsValid(panel) or !source) then
		return
	end

	local payload = panel.payload or {}

	if (source.list == "searchbag") then
		return (payload.storage or {})[source.index]
	end

	if (source.slot and source.slot != "") then
		return (payload.equipped or {})[source.slot]
	end

	return (payload.items or {})[source.index]
end

function NETWORK.gui.SearchTake(source)
	local panel = NETWORK.gui.search

	if (!IsValid(panel) or panel.bClosing) then
		return
	end

	panel:TakeSource(source)
end

hook.Add("NetworkInventoryUpdated", "nwSearchPanel", function()
	local panel = NETWORK.gui.search

	if (IsValid(panel) and !panel.bClosing and !NETWORK.gui.drag) then
		panel:Rebuild()
	end
end)

net.Receive("nwSearchOpen", function()
	local target = net.ReadEntity()
	local payload = NETWORK.util.ReadTable()

	if (IsValid(NETWORK.gui.search)) then
		NETWORK.gui.search:Remove()
	end

	local panel = vgui.Create("nwSearchPanel")

	panel:Setup(target, payload)
end)

net.Receive("nwSearchSync", function()
	if (IsValid(NETWORK.gui.search)) then
		NETWORK.gui.search:SetPayload(NETWORK.util.ReadTable())
	end
end)

net.Receive("nwSearchClose", function()
	if (IsValid(NETWORK.gui.search)) then
		NETWORK.gui.search:Remove()
	end
end)
