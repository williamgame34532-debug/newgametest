local rarityStyle = CreateClientConVar("network_rarity", "full", true, false,
	"Фон редкости в ячейках: full / minimal / off")

local PANEL = {}

NETWORK.gui.itemSlots = NETWORK.gui.itemSlots or {}
NETWORK.gui.grids = NETWORK.gui.grids or {}
NETWORK.gui.drag = NETWORK.gui.drag or nil
NETWORK.gui.sweep = NETWORK.gui.sweep or nil

function NETWORK.gui.StopSweep()
	NETWORK.gui.sweep = nil

	if (NETWORK.gui.CloseDragPreview) then
		NETWORK.gui.CloseDragPreview()
	end
end

local function IsSearchList(list)
	return NETWORK.gui.IsSearchList != nil and NETWORK.gui.IsSearchList(list)
end

function NETWORK.gui.ItemAt(source)
	if (source.list == "container") then
		return NETWORK.container.GetItem(source.index)
	end

	if (IsSearchList(source.list)) then
		return NETWORK.gui.SearchItemAt and NETWORK.gui.SearchItemAt(source)
	end

	return NETWORK.inventory.At(NETWORK.inventory.state, source.list, source.index,
		source.slot)
end

function NETWORK.gui.RequestSplit(source, amount, target)
	NETWORK.sound.InvStack()

	if (source.list == "container" or (target and target.list == "container")) then
		NETWORK.container.Split(source, amount, target)

		return
	end

	NETWORK.inventory.Split(source, amount, target)
end

function NETWORK.gui.SweepInto(list, index)
	local sweep = NETWORK.gui.sweep

	if (!sweep or (sweep.nextAction or 0) > RealTime()) then
		return
	end

	if (sweep.source.list == list and sweep.source.index == index) then
		return
	end

	if (!sweep.bLeftOrigin) then
		return
	end

	local key = list .. ":" .. index

	if (sweep.visited[key]) then
		return
	end

	sweep.visited[key] = true
	sweep.nextAction = RealTime() + 0.09

	if (IsValid(NETWORK.gui.itemMenu)) then
		NETWORK.gui.itemMenu:Remove()
	end

	if (sweep.mode == "split") then
		local item = NETWORK.gui.ItemAt(sweep.source)

		if (!item or (item.amount or 1) <= 1) then
			NETWORK.gui.StopSweep()
			NETWORK.gui.CloseDragPreview()

			NETWORK.gui.drag = nil

			NETWORK.sound.InvStack()
			NETWORK.gui.Notify(L(item and "invSweepDone" or "invSweepGone"),
				NETWORK.theme.textDim)

			return
		end

		NETWORK.gui.RequestSplit(sweep.source, 1, {list = list, index = index})
	end
end

function NETWORK.gui.SweepTransfer(panel)
	local sweep = NETWORK.gui.sweep

	if (!sweep or sweep.mode != "transfer" or !IsValid(panel) or !panel.item) then
		return
	end

	if ((sweep.nextAction or 0) > RealTime()) then
		return
	end

	local key = panel.list .. ":" .. tostring(panel.index) .. tostring(panel.slot)

	if (sweep.visited[key]) then
		return
	end

	sweep.visited[key] = true
	sweep.nextAction = RealTime() + 0.09

	NETWORK.sound.InvMove()

	if (panel.DoClick) then
		panel:DoClick(panel)
	end
end

function NETWORK.gui.RegisterGrid(list, data)
	data.list = list

	NETWORK.gui.grids[list] = data
end

function NETWORK.gui.ClearGrids()
	NETWORK.gui.grids = {}
end

function NETWORK.gui.GetGridCell(list, x, y)
	local grid = NETWORK.gui.grids[list]

	if (!grid or !IsValid(grid.panel)) then
		return
	end

	local originX, originY = grid.panel:LocalToScreen(grid.x, grid.y)
	local step = grid.cell + grid.gap
	local stepX = (grid.cellWidth or grid.cell) + grid.gap
	local column = math.floor((x - originX) / stepX)
	local row = math.floor((y - originY) / step)

	if (column < 0 or row < 0 or column >= grid.columns or row >= grid.rows) then
		return
	end

	return row * grid.columns + column + 1
end

function NETWORK.gui.FindGridUnder(x, y)
	for list, grid in pairs(NETWORK.gui.grids) do
		local index = NETWORK.gui.GetGridCell(list, x, y)

		if (index) then
			return list, index, grid
		end
	end
end

function PANEL:Init()
	self:SetText("")
	self:SetCursor("hand")

	self.item = nil
	self.hover = 0
	self.reveal = 0
	self.revealDelay = 0
	self.glow = 0
	self.startTime = CurTime()
	self.cut = 8
	self.list = "items"

	if ((NETWORK.gui.instantUntil or 0) > CurTime()) then
		self.bInstant = true
		self.reveal = 1
		self.glow = 1
	end

	NETWORK.gui.itemSlots[self] = true
end

function PANEL:OnRemove()
	NETWORK.gui.itemSlots[self] = nil

	NETWORK.gui.ClearTooltip(self)

	local drag = NETWORK.gui.drag

	if (drag and drag.panel == self) then
		NETWORK.gui.drag = nil
	end
end

function PANEL:SetCut(cut)
	self.cut = cut
end

function PANEL:SetRevealDelay(delay)
	if (self.bInstant) then
		return
	end

	self.revealDelay = 0
end

function PANEL:SetSlotName(text)
	self.slotName = text
end

function PANEL:SetRow(bState)
	self.bRow = tobool(bState)
end

PANEL.SetLabelled = PANEL.SetRow

function PANEL:SetCompact(bState)
	self.bCompact = tobool(bState)
end

function PANEL:SetGlyph(glyph)
	self.glyph = glyph
end

function PANEL:IsSelected()
	local selected = NETWORK.gui.selected

	if (!selected or !self.item) then
		return false
	end

	return selected.list == self.list and selected.index == self.index and
		selected.slot == self.slot
end

function NETWORK.gui.Select(source)
	NETWORK.gui.selected = source and {list = source.list, index = source.index,
		slot = source.slot} or nil

	hook.Run("NetworkInventorySelected", NETWORK.gui.selected)
end

function PANEL:SetSource(list, index, slot)
	self.list = list
	self.index = index
	self.slot = slot
end

function PANEL:GetSource()
	return {list = self.list, index = self.index, slot = self.slot}
end

function PANEL:SetItem(item)
	self.item = item

	if (IsValid(self.icon)) then
		self.icon:Remove()

		self.icon = nil
	end

	if (!item) then
		return
	end

	local model = NETWORK.item.GetModel(item)

	if (model) then
		self.icon = self:Add("nwItemIcon")
		self.icon:SetMouseInputEnabled(false)
		self.icon:SetTooltip(nil)

		self.icon:SetItem(item)
		self.icon:SetAlphaValue(math.Round(self.reveal * 255))
	end

	self.rarity = NETWORK.inventory.GetRarity(NETWORK.item.GetRarity(item))
end

function PANEL:GetItem()
	return self.item
end

function PANEL:PerformLayout(width, height)
	if (!IsValid(self.icon)) then
		return
	end

	local inset = NETWORK.util.Scale(8)

	if (self.bCompact) then
		local size = math.min(width, height) - inset * 2

		self.icon:SetSize(size, size)
		self.icon:SetPos(math.Round((width - size) * 0.5), math.Round((height - size) * 0.5) - inset * 0.5)

		return
	end

	if (self.bRow) then
		local squareX, squareY, square = NETWORK.gui.RowSquare(height)
		local pad = math.max(NETWORK.util.Scale(3), 2)

		self.icon:SetSize(square - pad * 2, square - pad * 2)
		self.icon:SetPos(squareX + pad, squareY + pad)

		return
	end

	self.icon:SetSize(width - inset * 2, height - inset * 2)
	self.icon:SetPos(inset, inset)
end

function PANEL:PaintOver(width, height)
	if (NETWORK.gui.grids[self.list]) then
		return
	end

	local drop = self:GetDropState()

	if (drop == nil or self.reveal < 0.01) then
		return
	end

	local state = drop and Color(96, 232, 138) or Color(232, 92, 92)
	local radius = NETWORK.gui.CellRadius()

	draw.RoundedBox(radius, 0, 0, width, height, Color(state.r, state.g, state.b, 45))

	NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, 1,
		Color(state.r, state.g, state.b, 220))
end

function PANEL:OnCursorEntered()
	if (NETWORK.gui.sweep) then
		NETWORK.gui.SweepTransfer(self)
	end

	if (IsValid(NETWORK.gui.itemMenu) or NETWORK.gui.drag) then
		return
	end

	if (self.item) then
		NETWORK.sound.InvSelect()
	end

	NETWORK.gui.SetItemTooltip(self, self.item, self.slotName)
end

function PANEL:OnCursorExited()
	NETWORK.gui.ClearTooltip(self)
end

function PANEL:OnKeyCodePressed(key)
	if (key != KEY_R or !self.item) then
		return
	end

	if (!NETWORK.item.CanRotate(self.item)) then
		return
	end

	NETWORK.sound.InvMove()

	NETWORK.inventory.Rotate(self:GetSource())
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_RIGHT and self.item) then
		NETWORK.gui.ClearTooltip(self)
		NETWORK.gui.OpenItemMenu(self)

		if ((self.item.amount or 1) > 1) then
			NETWORK.gui.sweep = {
				mode = "split",
				source = self:GetSource(),
				visited = {},
				startTime = RealTime()
			}

			self:MouseCapture(true)
		end

		return
	end

	if (code != MOUSE_LEFT or !self.item) then
		return
	end

	if (input.IsShiftDown()) then
		local source = self:GetSource()

		if (source.list == "storage") then
			NETWORK.inventory.FromStorage(source.index)
		elseif (source.list == "equipped") then
			NETWORK.inventory.Unequip(source.slot)
		elseif (NETWORK.inventory.GetContainer()) then
			NETWORK.inventory.ToStorage(source.index)
		else
			NETWORK.inventory.Equip(source.index)
		end

		NETWORK.sound.InvMove()
		NETWORK.gui.ClearTooltip(self)

		return
	end

	if (NETWORK.gui.sweep) then
		return
	end

	NETWORK.gui.drag = {
		panel = self,
		item = self.item,
		bRotated = self.item.rotated,
		source = self:GetSource(),
		startX = gui.MouseX(),
		startY = gui.MouseY()
	}

	do
		local base = NETWORK.item.Get(self.item.id)

		if (base and base.contents) then
			NETWORK.gui.drag.holdUse = RealTime() + 0.55
		end
	end

	NETWORK.sound.InvMove()

	NETWORK.gui.OpenDragPreview(self.item)

	NETWORK.gui.ClearTooltip()
	NETWORK.gui.ClearTooltip(self)

	self:MouseCapture(true)
end

function PANEL:GetHovered()
	local x, y = gui.MousePos()
	local best, bestArea

	for panel in pairs(NETWORK.gui.itemSlots) do
		if (!IsValid(panel)) then
			NETWORK.gui.itemSlots[panel] = nil

			continue
		end

		if (!panel:IsVisible()) then
			continue
		end

		local px, py = panel:LocalToScreen(0, 0)
		local width, height = panel:GetWide(), panel:GetTall()

		if (x < px or y < py or x > px + width or y > py + height) then
			continue
		end

		local area = width * height

		if (!bestArea or area < bestArea) then
			best = panel
			bestArea = area
		end
	end

	return best
end

function PANEL:OnMouseReleased(code)
	self:MouseCapture(false)

	local sweep = NETWORK.gui.sweep

	if (sweep) then
		NETWORK.gui.StopSweep()

		return
	end

	local drag = NETWORK.gui.drag

	NETWORK.gui.drag = nil

	NETWORK.gui.CloseDragPreview()

	if (drag and drag.panel == self and code == MOUSE_LEFT) then
		local model = NETWORK.gui.modelPanel

		if (IsValid(model) and model:IsHovered()) then
			local base = NETWORK.item.Get(drag.item.id)

			if (base and (NETWORK.item.CanUse(drag.item))) then
				NETWORK.sound.InvMove()

				NETWORK.inventory.Use(drag.source)

				return
			end
		end

		local list, index = NETWORK.gui.FindGridUnder(gui.MouseX(), gui.MouseY())

		if (list) then
			local distance = math.abs(gui.MouseX() - drag.startX) +
				math.abs(gui.MouseY() - drag.startY)

			if (list == drag.source.list and index == drag.source.index and
				distance < NETWORK.util.Scale(8)) then

				NETWORK.sound.InvSelect()

				if (self.DoClick) then
					self:DoClick(self)
				end

				return
			end

			if (!NETWORK.gui.CanDropInto(drag, {list = list, index = index})) then
				NETWORK.sound.Play("hover3", 92, 0.5)

				return
			end

			NETWORK.sound.InvMove()

			local bRotate = drag.bRotated != drag.item.rotated

			if (IsSearchList(drag.source.list)) then
				NETWORK.gui.SearchTake(drag.source)

				return
			end

			if (drag.source.list == "container" or list == "container") then
				NETWORK.container.Move(drag.source, {list = list, index = index}, bRotate)
			else
				NETWORK.inventory.Move(drag.source, {list = list, index = index}, bRotate)
			end

			return
		end
	end

	if (code != MOUSE_LEFT or !drag or drag.panel != self) then
		return
	end

	local target = self:GetHovered()
	local distance = math.abs(gui.MouseX() - drag.startX) + math.abs(gui.MouseY() - drag.startY)

	if ((!target or target == self) and distance < NETWORK.util.Scale(8)) then
		NETWORK.sound.InvSelect()

		if (self.DoClick) then
			self:DoClick(self)
		end

		return
	end

	if (!IsValid(target)) then
		if (drag.source.list == "container" or IsValid(NETWORK.gui.container) or
			IsSearchList(drag.source.list)) then
			return
		end

		surface.PlaySound("physics/cardboard/cardboard_box_impact_soft1.wav")

		NETWORK.inventory.Drop(drag.source)

		return
	end

	if (target == self) then
		return
	end

	if (!NETWORK.gui.CanDropInto(drag, target)) then
		NETWORK.sound.Play("hover3", 92, 0.5)

		if (target.list == "equipped") then
			NETWORK.gui.InventoryNotice(L("invWrongSlot"), NETWORK.theme.danger)
		else
			NETWORK.gui.InventoryNotice(L("invNoRoom"), NETWORK.theme.danger)
		end

		return
	end

	NETWORK.sound.InvMove()

	if (target.list == "equipped") then
		NETWORK.gui.InventoryNotice(L("invEquipped",
			NETWORK.item.GetName(drag.item)), NETWORK.theme.positive)
	end

	if (IsSearchList(drag.source.list)) then
		NETWORK.gui.SearchTake(drag.source)
	elseif (target.list == "wound") then
		NETWORK.wound.RequestHeal(target.slot, drag.source.index)
	elseif (drag.source.list == "container" or target.list == "container") then
		NETWORK.container.Move(drag.source, target:GetSource())
	else
		NETWORK.inventory.Move(drag.source, target:GetSource())
	end
end

function PANEL:Think()
	local sweep = NETWORK.gui.sweep

	if (sweep and sweep.mode == "split") then
		local list, index = NETWORK.gui.FindGridUnder(gui.MouseX(), gui.MouseY())

		if (list and index) then
			if (list != sweep.source.list or index != sweep.source.index) then
				sweep.bLeftOrigin = true
			end

			NETWORK.gui.SweepInto(list, index)
		end
	end

	local util = NETWORK.util

	self.hover = util.Approach(self.hover, self:IsHovered() and 1 or 0, 11)

	if (!self.bInstant) then
		self.reveal = util.Approach(self.reveal, 1, 14)
	end

	self.glow = self.bInstant and (self.item and 1 or 0) or
		util.Approach(self.glow, self.item and 1 or 0, 8)

	if (IsValid(self.icon)) then

		self.icon:SetAlphaValue(math.Round(self.reveal * 255))
	end
end

function PANEL:GetDropState()
	local drag = NETWORK.gui.drag

	if (!drag or drag.panel == self) then
		return
	end

	return NETWORK.gui.CanDropInto(drag, self)
end

function NETWORK.gui.GetListGrid(list)
	if (list == "container") then
		local columns = NETWORK.inventory.columns

		return columns, math.ceil(NETWORK.container.GetSlots() / columns)
	end

	if (list == "storage") then
		local container = NETWORK.inventory.GetContainer()
		local columns = NETWORK.inventory.columns

		return columns, math.ceil(NETWORK.item.GetStorageSlots(container or {}) / columns)
	end

	return NETWORK.inventory.columns, NETWORK.inventory.rows
end

function NETWORK.gui.CanDropInto(drag, target)

	if (IsSearchList(target.list)) then
		return false
	end

	do
		local base = NETWORK.item.Get(drag.item.id)

		if (base and base.category == "food" and target.list and
			target.index) then
			local state = target.list == "container" and
				NETWORK.container.state or NETWORK.inventory.state
			local under = state and state[target.list == "container" and
				"items" or target.list]
			local slotItem = under and under[target.index]

			if (istable(slotItem)) then
				local slotBase = NETWORK.item.Get(slotItem.id)

				if (slotBase and (slotBase.contents or
					slotItem.id == "ration_empty")) then
					return true
				end
			end
		end
	end

	if (target.list == "wound") then
		local base = NETWORK.item.Get(drag.item.id)
		local bMedical = NETWORK.medical and NETWORK.medical.IsTreatment(drag.item.id)

		if (!base or (!bMedical and (base.healWound or 0) <= 0)) then
			return false
		end

		if (drag.source.list != "items") then
			return false
		end

		if (bMedical) then
			return NETWORK.medical.PartNeedsCare(LocalPlayer(), target.slot)
		end

		return NETWORK.wound.Get(LocalPlayer(), target.slot) > 0
	end

	if (target.list == "container" or drag.source.list == "container") then
		local list = target.list == "container" and NETWORK.container.state.items or
			NETWORK.inventory.state.items
		local columns, rows = NETWORK.gui.GetListGrid(target.list)

		if (target.list == "equipped") then
			return NETWORK.item.GetEquipSlot(drag.item) == target.slot
		end

		if (NETWORK.inventory.Fits(list, columns, rows, drag.item, target.index,
			drag.source.list == target.list and drag.source.index or nil)) then
			return true
		end

		local _, count = NETWORK.inventory.GetOverlapping(list, columns, rows, drag.item,
			target.index, drag.source.list == target.list and drag.source.index or nil)

		return count == 1
	end

	if (target.list == "items" or target.list == "storage") then
		local state = NETWORK.inventory.state
		local list = state[target.list]
		local columns, rows = NETWORK.gui.GetListGrid(target.list)
		local ignore = drag.source.list == target.list and drag.source.index or nil

		if (target.list == "storage") then
			local container = NETWORK.inventory.GetContainer()

			if (!container or !NETWORK.item.CanStore(container, drag.item)) then
				return false
			end
		end

		if (NETWORK.inventory.Fits(list, columns, rows, drag.item, target.index, ignore)) then
			return true
		end

		local _, count = NETWORK.inventory.GetOverlapping(list, columns, rows, drag.item,
			target.index, ignore)

		return count == 1
	end

	return NETWORK.inventory.CanDrop(drag.item, target.list, target.index, target.slot,
		drag.source.list)
end

local SLOT_GLYPHS = {
	helmet = "helmet",
	hat = "hat",
	glasses = "glasses",
	mask = "mask",
	jacket = "shirt",
	vest = "vest",
	armour = "vest",
	gloves = "gloves",
	pants = "pants",
	boots = "boot",
	backpack = "backpack",
	radio = "radio",
	watch = "watch",
	light = "light",
	cuffs = "cuffs",
	primary = "rifle",
	secondary = "pistol",
	melee = "knife"
}

local function GetSlotGlyph(panel)
	return panel.glyph or (panel.slot and SLOT_GLYPHS[panel.slot]) or nil
end

local slotIcons = {}

function NETWORK.gui.GetSlotIcon(slot)
	if (!isstring(slot) or slot == "") then
		return
	end

	local cached = slotIcons[slot]

	if (cached == nil) then
		local material = Material("framework/slots/" .. slot .. ".png", "smooth mips")

		cached = (material and !material:IsError()) and material or false
		slotIcons[slot] = cached
	end

	return cached or nil
end

local function DrawSlotGlyph(glyph, x, y, size, color, slot)
	if (size < 4) then
		return
	end

	local icon = NETWORK.gui.GetSlotIcon(slot)

	if (icon) then
		surface.SetMaterial(icon)
		surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
		surface.DrawTexturedRect(x, y, size, size)

		return
	end

	if (!glyph or !NETWORK.gui.DrawGlyph) then
		return
	end

	NETWORK.gui.DrawGlyph(glyph, x, y, size, color)
end

local function Mix(from, to, fraction)
	return Color(
		Lerp(fraction, from.r, to.r),
		Lerp(fraction, from.g, to.g),
		Lerp(fraction, from.b, to.b)
	)
end

function NETWORK.gui.CellRadius()
	local S = NETWORK.style

	if (S and S.Radius) then
		return S.Radius("cell")
	end

	return math.max(NETWORK.util.Scale(6), 4)
end

local function ChipRadius()
	local S = NETWORK.style

	if (S and S.Radius) then
		return S.Radius("chip")
	end

	return math.max(NETWORK.util.Scale(4), 3)
end

function NETWORK.gui.RowSquare(height)
	local Sc = NETWORK.util.Scale
	local size = math.max(math.min(Sc(38), height - Sc(8)), 8)
	local x = Sc(5)
	local y = math.Round((height - size) * 0.5)

	return x, y, size
end

local function GetCondition(item, bTouchedOnly)
	if (!item) then
		return
	end

	local base = NETWORK.item.Get(item.id)
	local maxUses = tonumber(item.maxUses) or (base and tonumber(base.maxUses))

	if (!maxUses or maxUses <= 1) then
		return
	end

	local uses = tonumber(item.uses)

	if (!uses) then
		if (bTouchedOnly) then
			return
		end

		uses = maxUses
	end

	return math.Clamp(uses / maxUses, 0, 1)
end

local function ConditionColor(palette, ratio)
	if (ratio > 0.5) then
		return palette.positive
	elseif (ratio > 0.2) then
		return palette.warning
	end

	return palette.danger
end

local function CornerInset(radius, row)
	if (row >= radius) then
		return 0
	end

	local offset = radius - row - 0.5

	return math.ceil(radius - math.sqrt(math.max(radius * radius - offset * offset, 0)))
end

local function DrawAmountChip(text, right, bottom, alpha, palette)
	local Sc = NETWORK.util.Scale

	text = "×" .. text

	surface.SetFont("nwInvSub")

	local textWidth, textHeight = surface.GetTextSize(text)
	local padX = math.max(Sc(4), 2)
	local x = right - textWidth - padX * 2
	local y = bottom - textHeight

	surface.SetDrawColor(7, 15, 25, 220 * alpha)
	surface.DrawRect(x, y, textWidth + padX * 2, textHeight)

	draw.SimpleText(text, "nwInvSub", x + padX, y, ColorAlpha(palette.text, 245 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

local function CellArt(cellWidth, cell)
	if (cellWidth != cell or !NETWORK.util.GetTexture) then
		return
	end

	local size = cell / NETWORK.util.ScaleF(1)
	local best = CELL_SIZES[1]

	for _, candidate in ipairs(CELL_SIZES) do
		if (math.abs(candidate - size) < math.abs(best - size)) then
			best = candidate
		end
	end

	local fillArt = NETWORK.util.GetTexture("framework/pattern/cell" .. best .. ".png",
		"smooth mips")
	local lineArt = NETWORK.util.GetTexture("framework/pattern/cellline" .. best .. ".png",
		"smooth mips")

	if (fillArt and lineArt) then
		return fillArt, lineArt
	end
end

function NETWORK.gui.DrawCellArt(kind, x, y, width, height, color)
	local fillArt, lineArt = CellArt(width, height)
	local material = kind == "line" and lineArt or fillArt

	if (!material) then
		return false
	end

	surface.SetMaterial(material)
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	surface.DrawTexturedRect(x, y, width, height)
	draw.NoTexture()

	return true
end

function NETWORK.gui.DrawCellBackdrop(columns, rows, cellWidth, cell, gap, fill, border)
	local radius = NETWORK.gui.CellRadius()
	local stepX = cellWidth + gap
	local stepY = cell + gap
	local fillArt, lineArt = CellArt(cellWidth, cell)

	if (fillArt) then
		surface.SetMaterial(fillArt)
		surface.SetDrawColor(fill.r, fill.g, fill.b, fill.a or 255)

		for row = 0, rows - 1 do
			for column = 0, columns - 1 do
				surface.DrawTexturedRect(column * stepX, row * stepY, cellWidth, cell)
			end
		end

		if ((border.a or 255) > 0) then
			surface.SetMaterial(lineArt)
			surface.SetDrawColor(border.r, border.g, border.b, border.a or 255)

			for row = 0, rows - 1 do
				for column = 0, columns - 1 do
					surface.DrawTexturedRect(column * stepX, row * stepY, cellWidth, cell)
				end
			end
		end

		draw.NoTexture()

		return
	end

	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			draw.RoundedBox(radius, column * stepX, row * stepY, cellWidth, cell, fill)
		end
	end

	if ((border.a or 255) <= 0) then
		return
	end

	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(255)
	render.SetStencilTestMask(255)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)

	render.OverrideColorWriteEnable(true, false)

	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			draw.RoundedBox(math.max(radius - 1, 0), column * stepX + 1, row * stepY + 1,
				cellWidth - 2, cell - 2, color_white)
		end
	end

	render.OverrideColorWriteEnable(false, false)

	render.SetStencilPassOperation(STENCIL_KEEP)
	render.SetStencilCompareFunction(STENCIL_NOTEQUAL)

	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			draw.RoundedBox(radius, column * stepX, row * stepY, cellWidth, cell, border)
		end
	end

	render.SetStencilEnable(false)
end

local CELL_GLASS = Color(9, 12, 15)

local CELL_LINE = Color(150, 196, 220)

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local palette = NETWORK.theme.inv
	local util = NETWORK.util
	local reveal = self.reveal

	if (reveal < 0.01) then
		return
	end

	local drag = NETWORK.gui.drag
	local hover = util.EaseInOut(self.hover)
	local y = math.Round((1 - reveal) * Sc(6))

	local dim = NETWORK.gui.GetFilterDim and
		NETWORK.gui.GetFilterDim(self.item) or 1

	if (dim < 1) then
		reveal = reveal * dim
	end

	local bItem = self.item != nil
	local rarity = (bItem and self.rarity) and self.rarity.color or palette.accent
	local bBeingDragged = drag and drag.panel == self
	local bSelected = self:IsSelected()
	local bFilled = bItem and !bBeingDragged
	local bRare = self.rarity and self.rarity.id != "common"
	local style = GetConVar("network_simple_inventory"):GetBool() and "minimal" or rarityStyle:GetString()
	local line = math.max(Sc(1), 1)
	local accent = palette.accent
	local select = palette.select
	local glyph = GetSlotGlyph(self)
	local radius = NETWORK.gui.CellRadius()

	if (self.bRow) then
		local label = util.Upper(self.slotName or "")
		local squareX, squareY, square = NETWORK.gui.RowSquare(height)
		local chip = math.min(ChipRadius(), math.floor(square * 0.5))
		local middle = y + math.Round(height * 0.5)

		squareY = squareY + y

		draw.RoundedBox(radius, 0, y, width, height,
			Color(CELL_GLASS.r, CELL_GLASS.g, CELL_GLASS.b, 150 * reveal))

		if (bSelected or bFilled) then
			draw.RoundedBox(radius, 0, y, width, height,
				Color(accent.r, accent.g, accent.b, (bSelected and 34 or 15) * reveal))
		end

		if (hover > 0.01 and !bSelected) then
			draw.RoundedBox(radius, 0, y, width, height,
				Color(255, 255, 255, 7 * hover * reveal))
		end

		local border = CELL_LINE
		local borderAlpha = 40

		if (bSelected) then
			border = select
			borderAlpha = 230
		elseif (bFilled) then
			border = accent
			borderAlpha = 140
		end

		if (hover > 0.01 and !bSelected) then
			border = Mix(border, accent, hover)
			borderAlpha = borderAlpha + (200 - borderAlpha) * hover
		end

		util.DrawRoundedBorder(0, y, width, height, radius, line,
			Color(border.r, border.g, border.b, borderAlpha * reveal))

		if (bSelected) then
			util.DrawRoundedBorder(line, y + line, width - line * 2, height - line * 2,
				math.max(radius - line, 0), line,
				Color(select.r, select.g, select.b, 80 * reveal))
		end

		draw.RoundedBox(chip, squareX, squareY, square, square,
			Color(0, 0, 0, 80 * reveal))

		draw.RoundedBox(chip, squareX, squareY, square, square,
			Color(CELL_LINE.r, CELL_LINE.g, CELL_LINE.b, (34 + 50 * hover) * reveal))
		draw.RoundedBox(math.max(chip - 1, 0), squareX + 1, squareY + 1, square - 2,
			square - 2, Color(6, 8, 10, 235 * reveal))

		if (!bItem) then
			local glyphSize = math.Round(square * 0.66)

			DrawSlotGlyph(glyph, squareX + math.Round((square - glyphSize) * 0.5),
				squareY + math.Round((square - glyphSize) * 0.5), glyphSize,
				ColorAlpha(palette.textFaint, (150 + 70 * hover) * reveal), self.slot)
		end

		if (IsValid(self.icon)) then
			self.icon:SetAlphaValue(bBeingDragged and 35 or math.Round(reveal * 255))
		end

		local textX = squareX + square + Sc(10)
		local nameY = middle - Sc(7)
		local labelY = middle + Sc(9)

		draw.SimpleText(label, "nwInvKey", textX, labelY,
			ColorAlpha(bSelected and palette.textDim or palette.textFaint,
				(220 + 30 * hover) * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (bBeingDragged) then
			return
		end

		if (!bItem) then
			if (self.slot == "light" and NETWORK.factions.IsAlliance(LocalPlayer())) then
				local size = Sc(5)
				local cx = width - Sc(14)
				local cross = ColorAlpha(palette.danger, 200 * reveal)

				util.DrawThickLine(cx - size, middle - size, cx + size, middle + size, line, cross)
				util.DrawThickLine(cx + size, middle - size, cx - size, middle + size, line, cross)
			end

			draw.SimpleText(L("invEmptySlot"), "nwInvBody", textX, nameY,
				ColorAlpha(palette.textFaint, 190 * reveal), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			return
		end

		local rightEdge = width - Sc(10)
		local ratio = GetCondition(self.item)

		if (ratio) then
			local text = math.Round(ratio * 100) .. " %"

			surface.SetFont("nwInvSub")

			local conditionWidth = surface.GetTextSize(text)

			draw.SimpleText(text, "nwInvSub", rightEdge, middle,
				ColorAlpha(ConditionColor(palette, ratio), 240 * reveal),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			rightEdge = rightEdge - conditionWidth - Sc(8)
		end

		local suffix = (self.item.amount or 1) > 1 and (" ×" .. self.item.amount) or ""
		local name = util.TruncateWidth(NETWORK.item.GetName(self.item) .. suffix,
			"nwInvBodyBold", math.max(rightEdge - textX, Sc(20)))

		draw.SimpleText(name, "nwInvBodyBold", textX, nameY,
			ColorAlpha(palette.text, 250 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	-- Simplified flat cell: one plate, one hairline, an accent frame on hover/selection.
	local P = NETWORK.theme.pda or {}
	local plate = bFilled and (P.bg2 or CELL_GLASS) or (P.deep or CELL_GLASS)

	surface.SetDrawColor(plate.r, plate.g, plate.b, (bFilled and 225 or 170) * reveal)
	surface.DrawRect(0, y, width, height)

	if (hover > 0.01 or bSelected) then
		local tint = bSelected and select or accent

		surface.SetDrawColor(tint.r, tint.g, tint.b, (bSelected and 36 or 18 * hover) * reveal)
		surface.DrawRect(0, y, width, height)
	end

	local border = P.line or CELL_LINE
	local borderAlpha = bFilled and 200 or 120

	if (hover > 0.01) then
		border = Mix(border, accent, hover)
		borderAlpha = borderAlpha + (255 - borderAlpha) * hover
	end

	if (bSelected) then
		border = select
		borderAlpha = 255
	end

	surface.SetDrawColor(border.r, border.g, border.b, math.min(borderAlpha, 255) * reveal)
	surface.DrawOutlinedRect(0, y, width, height, line)

	if (bSelected or hover > 0.5) then
		local tick = math.max(Sc(6), 4)
		local tint = bSelected and select or accent

		surface.SetDrawColor(tint.r, tint.g, tint.b, 255 * reveal)
		surface.DrawRect(0, y, tick, line * 2)
		surface.DrawRect(0, y, line * 2, tick)
		surface.DrawRect(width - tick, y + height - line * 2, tick, line * 2)
		surface.DrawRect(width - line * 2, y + height - tick, line * 2, tick)
	end

	local threadTop = y + line

	if (bFilled and style != "off") then
		local base = NETWORK.item.Get(self.item.id)
		local category = base and base.category or ""
		local tint = bRare and rarity or (NETWORK.inventory.categoryColors and
			NETWORK.inventory.categoryColors[category])

		if (tint) then
			local thick = math.max(Sc(2), 2)

			surface.SetDrawColor(tint.r, tint.g, tint.b, (style == "minimal" and 150 or 225) * reveal)
			surface.DrawRect(line, threadTop, width - line * 2, thick)

			threadTop = threadTop + thick
		end
	end

	local bContraband = bFilled and NETWORK.item.IsContraband and
		NETWORK.factions.IsAlliance(LocalPlayer()) and
		NETWORK.item.IsContraband(self.item)

	if (bContraband) then
		local mark = math.max(Sc(2), 2)
		local markTop = math.max(threadTop + Sc(3), y + radius)
		local markHeight = (y + height - radius) - markTop

		if (markHeight > mark) then
			draw.RoundedBox(math.floor(mark * 0.5), width - line - mark - 1, markTop, mark,
				markHeight, ColorAlpha(palette.danger, 225 * reveal))
		end
	end

	if (bFilled and NETWORK.spoil and self.item.data) then
		local base = NETWORK.item.Get(self.item.id)
		local stage = NETWORK.spoil.CanSpoil(base) and
			NETWORK.spoil.GetStage(self.item) or 0

		if (stage >= 2) then
			local side = math.max(Sc(9), 6)
			local right = width - Sc(4) - (bContraband and (math.max(Sc(2), 2) + Sc(3)) or 0)
			local top = threadTop + Sc(3)
			local tint = NETWORK.spoil.GetColor(stage)

			surface.SetDrawColor(tint.r, tint.g, tint.b, 235 * reveal)
			draw.NoTexture()
			surface.DrawPoly({
				{x = right - side, y = top},
				{x = right, y = top},
				{x = right, y = top + side}
			})
		end
	end

	local chipBottom = y + height - line - Sc(3)
	local wear = bFilled and GetCondition(self.item, true)

	if (wear) then
		local barHeight = math.max(Sc(2), 2)
		local bar = ConditionColor(palette, wear)
		local barX = math.max(Sc(5), math.ceil(radius * 0.7))
		local barY = chipBottom - barHeight
		local barWidth = width - barX * 2
		local barRadius = math.floor(barHeight * 0.5)

		if (barWidth > barHeight) then
			draw.RoundedBox(barRadius, barX, barY, barWidth, barHeight,
				Color(255, 255, 255, 20 * reveal))

			local fill = math.Round(barWidth * wear)

			if (fill >= barHeight) then
				draw.RoundedBox(barRadius, barX, barY, fill, barHeight,
					Color(bar.r, bar.g, bar.b, 240 * reveal))
			end
		end

		chipBottom = barY - Sc(2)
	end

	if (self.slot == "light" and !bItem and
		NETWORK.factions.IsAlliance(LocalPlayer())) then
		local inset = Sc(12)
		local thick = math.max(Sc(2), 2)
		local cross = ColorAlpha(palette.danger, 170 * reveal)

		util.DrawThickLine(inset, y + inset, width - inset,
			y + height - inset, thick, cross)
		util.DrawThickLine(width - inset, y + inset, inset,
			y + height - inset, thick, cross)
	end

	if (self.bCompact) then
		local label = util.Upper(self.slotName or "")
		local labelY = y + height - Sc(9)

		if (!bItem) then
			local glyphSize = math.Clamp(math.floor(math.min(width, height) * 0.34), 8, Sc(26))

			DrawSlotGlyph(glyph, math.Round((width - glyphSize) * 0.5),
				math.Round(y + (height - Sc(14) - glyphSize) * 0.5), glyphSize,
				ColorAlpha(palette.textFaint, (150 + 70 * hover) * reveal), self.slot)

			draw.SimpleText(label, "nwInvKey", math.Round(width * 0.5), labelY,
				ColorAlpha(palette.textFaint, (190 + 40 * hover) * reveal),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			draw.SimpleText(label, "nwInvKey", math.Round(width * 0.5), labelY,
				ColorAlpha(palette.textDim, 225 * reveal), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end
	end

	if (!bItem or bBeingDragged) then
		if (IsValid(self.icon)) then
			self.icon:SetAlphaValue(bBeingDragged and 35 or math.Round(reveal * 255))
		end

		return
	end

	if (!self.bCompact) then
		local tag, id = NETWORK.item.GetTag(self.item)

		if (id != "drop" and tag and tag.color) then
			local dot = math.max(Sc(4), 3)

			draw.RoundedBox(math.floor(dot * 0.5), Sc(5), threadTop + Sc(3), dot, dot,
				Color(tag.color.r, tag.color.g, tag.color.b, 235 * reveal))
		end
	end

	if ((self.item.amount or 1) > 1) then
		DrawAmountChip(tostring(self.item.amount), width - line - Sc(3), chipBottom,
			reveal, palette)
	end
end

vgui.Register("nwItemSlot", PANEL, "DButton")

NETWORK.gui.notice = NETWORK.gui.notice or nil

function NETWORK.gui.InventoryNotice(text, color)
	NETWORK.gui.notice = {
		text = text,
		color = color or NETWORK.theme.accent,
		time = RealTime()
	}
end

local function DrawNotice(x, y, width, height)
	local notice = NETWORK.gui.notice

	if (!notice) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local age = RealTime() - notice.time
	local hold = 4

	if (age > hold + 0.4) then
		NETWORK.gui.notice = nil

		return
	end

	local alpha = math.Clamp(age / 0.25, 0, 1) *
		(1 - math.Clamp((age - hold) / 0.4, 0, 1))
	local slide = (1 - math.Clamp(age / 0.25, 0, 1)) * Sc(10)
	local centerX = math.Round(x + width * 0.5)
	local noticeY = math.Round(y + height) - Sc(6) + slide

	surface.SetFont("nwField")

	local textWidth = surface.GetTextSize(notice.text)
	local boxWidth = textWidth + Sc(52)

	local boxX = math.Round(centerX - boxWidth * 0.5)
	local boxY = noticeY - Sc(15)
	local boxHeight = Sc(30)
	local radius = NETWORK.gui.CellRadius()
	local rail = math.max(Sc(3), 2)

	draw.RoundedBox(radius, boxX, boxY, boxWidth, boxHeight, Color(10, 13, 17, 240 * alpha))

	util.DrawRoundedBorder(boxX, boxY, boxWidth, boxHeight, radius, 1,
		Color(notice.color.r, notice.color.g, notice.color.b, 70 * alpha))

	draw.RoundedBox(math.floor(rail * 0.5), boxX + Sc(8), boxY + Sc(8), rail,
		boxHeight - Sc(16), Color(notice.color.r, notice.color.g, notice.color.b, 250 * alpha))

	util.DrawSimpleTextShadow(notice.text, "nwField", centerX, noticeY,
		ColorAlpha(notice.color, 250 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
		math.max(Sc(2), 1))
end

hook.Add("NetworkDrawTabOverlay", "nwInventoryNotice", DrawNotice)

hook.Add("HUDPaint", "nwInventoryNotice", function()
	if (IsValid(NETWORK.gui.tabMenu) or NETWORK.hud.IsHidden()) then
		return
	end

	local Sc = NETWORK.util.Scale

	DrawNotice(0, ScrH() - Sc(150), ScrW(), 0)
end)

hook.Add("Think", "nwRationHold", function()
	local drag = NETWORK.gui.drag

	if (!drag or !drag.holdUse or RealTime() < drag.holdUse) then
		return
	end

	local moved = math.abs(gui.MouseX() - drag.startX) +
		math.abs(gui.MouseY() - drag.startY)

	if (moved >= NETWORK.util.Scale(8)) then
		drag.holdUse = nil

		return
	end

	NETWORK.gui.drag = nil

	NETWORK.gui.CloseDragPreview()

	if (IsValid(drag.panel)) then
		drag.panel:MouseCapture(false)
	end

	NETWORK.sound.InvMove()
	NETWORK.inventory.Use(drag.source)
end)
