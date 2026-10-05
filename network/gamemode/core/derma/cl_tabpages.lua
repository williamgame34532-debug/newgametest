local function Palette()
	return NETWORK.theme.inv
end

local function BuildSectionLabel(parent, text, x, y, width, options)
	local Sc = NETWORK.util.Scale
	local panel = parent:Add("DPanel")
	local caption = NETWORK.util.Upper(text)

	options = options or {}

	panel:SetSize(width, Sc(24))
	panel:SetPos(x, y)
	panel:SetMouseInputEnabled(false)
	panel.startTime = CurTime()
	panel.Paint = function(self, panelWidth, panelHeight)
		local util = NETWORK.util
		local reveal = util.EaseOut(util.Stagger(self.startTime, 0.04, 0.4))
		local badgeText, badgeColor

		if (options.badge) then
			badgeText, badgeColor = options.badge()
		end

		NETWORK.tk.Header(0, 0, panelWidth, panelHeight, caption, reveal, badgeText,
			badgeColor)
	end

	return panel
end

local function BuildPlate(parent, x, y, width, height)
	local plate = parent:Add("DPanel")

	plate:SetPos(x, y)
	plate:SetSize(width, height)
	plate:SetMouseInputEnabled(false)
	plate.startTime = CurTime()
	plate.Paint = function(self, panelWidth, panelHeight)
		local reveal = NETWORK.util.EaseOut(
			NETWORK.util.Stagger(self.startTime, 0, 0.35))

		NETWORK.tk.Frame(0, 0, panelWidth, panelHeight, reveal)
	end

	return plate
end

local BUTTON = {}

function BUTTON:Init()
	self:SetText("")
	self:SetCursor("hand")

	self.label = ""
	self.glyph = nil
	self.bPrimary = false
	self.hover = 0
end

function BUTTON:Setup(label, glyph, bPrimary)
	self.label = NETWORK.util.Upper(label)
	self.glyph = glyph
	self.bPrimary = tobool(bPrimary)
end

function BUTTON:OnCursorEntered()
	NETWORK.sound.Hover()
end

function BUTTON:OnMousePressed(code)
	NETWORK.sound.Click()

	if (code == MOUSE_LEFT and self.DoClick) then
		self:DoClick(self)
	end
end

function BUTTON:Think()
	self.hover = NETWORK.util.Approach(self.hover, self:IsHovered() and 1 or 0, 12)
end

function BUTTON:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local palette = NETWORK.theme.tk
	local hover = NETWORK.util.EaseInOut(self.hover)
	local bDisabled = self:GetDisabled()
	local alpha = bDisabled and 0.45 or 1
	local fill = palette.plateLight
	local line = palette.line

	surface.SetDrawColor(fill.r + 18 * hover, fill.g + 18 * hover, fill.b + 18 * hover,
		230 * alpha)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(line.r + 40 * hover, line.g + 40 * hover, line.b + 40 * hover,
		255 * alpha)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	if (self.bPrimary) then
		surface.SetDrawColor(palette.active.r, palette.active.g, palette.active.b, 230 * alpha)
		surface.DrawRect(0, 0, math.max(Sc(3), 2), height)
	end

	local text = Color(
		Lerp(hover, palette.textDim.r, palette.text.r),
		Lerp(hover, palette.textDim.g, palette.text.g),
		Lerp(hover, palette.textDim.b, palette.text.b),
		250 * alpha
	)

	if (self.glyph) then
		NETWORK.gui.DrawGlyph(self.glyph, Sc(12), math.Round((height - Sc(12)) * 0.5), Sc(12),
			ColorAlpha(text, 230 * alpha))
	end

	draw.SimpleText(self.label, "nwInvButton", self.glyph and Sc(32) or Sc(14),
		math.Round(height * 0.5), text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("nwInvButton", BUTTON, "DButton")

function NETWORK.gui.BuildGrid(parent, list, source, data)
	local Sc = NETWORK.util.Scale
	local cell = data.cell

	local cellWidth = data.cellWidth or cell
	local gap = data.gap
	local columns = data.columns
	local rows = data.rows
	local step = cell + gap
	local stepX = cellWidth + gap

	NETWORK.gui.RegisterGrid(list, {
		panel = parent,
		x = data.x,
		y = data.y,
		cell = cell,
		cellWidth = cellWidth,
		gap = gap,
		columns = columns,
		rows = rows
	})

	local background = parent:Add("DPanel")

	background:SetPos(data.x, data.y)
	background:SetSize(columns * stepX - gap, rows * step - gap)
	background:SetMouseInputEnabled(false)
	background.Paint = function(self, width, height)
		local palette = Palette()
		local drag = NETWORK.gui.drag
		local footprint = {}

		if (drag) then
			local hoverList, hoverIndex = NETWORK.gui.FindGridUnder(gui.MouseX(),
				gui.MouseY())

			if (hoverList == list and hoverIndex) then
				local itemWidth, itemHeight = NETWORK.item.GetSize(drag.item)
				local originX = (hoverIndex - 1) % columns
				local originY = math.floor((hoverIndex - 1) / columns)
				local bAllowed = NETWORK.gui.CanDropInto(drag,
					{list = list, index = hoverIndex})

				for offsetY = 0, itemHeight - 1 do
					for offsetX = 0, itemWidth - 1 do
						if (originX + offsetX < columns and originY + offsetY < rows) then
							footprint[(originY + offsetY) * columns +
								(originX + offsetX) + 1] = bAllowed
						end
					end
				end
			end
		end

		if (NETWORK.gui.DrawCellBackdrop) then
			NETWORK.gui.DrawCellBackdrop(columns, rows, cellWidth, cell, gap,
				Color(20, 21, 22, 220), Color(66, 69, 71, 255))
		end

		local radius = NETWORK.gui.CellRadius and NETWORK.gui.CellRadius() or
			math.max(Sc(6), 4)

		for index, state in pairs(footprint) do

			local column = (index - 1) % columns
			local row = math.floor((index - 1) / columns)

			if (row < rows) then
				local x = column * stepX
				local y = row * step
				local color = state and palette.positive or palette.danger

				draw.RoundedBox(radius, x, y, cellWidth, cell,
					Color(color.r, color.g, color.b, 50))

				NETWORK.util.DrawRoundedBorder(x, y, cellWidth, cell, radius, 1,
					Color(color.r, color.g, color.b, 210))
			end
		end
	end

	local order = 0

	for index, item in pairs(source or {}) do
		local width, height = NETWORK.item.GetSize(item)
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)

		order = order + 1

		local slot = parent:Add("nwItemSlot")

		slot:SetSize(width * stepX - gap, height * step - gap)
		slot:SetPos(data.x + column * stepX, data.y + row * step)
		slot:SetRevealDelay(0.02 + order * 0.012)
		slot:SetSource(list, index)
		slot:SetItem(item)
		slot.DoClick = function()
			if (data.OnClick) then
				data.OnClick(index, slot)
			end
		end
	end
end

local function SelectOrQuick(slot, quick)
	local source = slot:GetSource()
	local key = source.list .. ":" .. tostring(source.index) .. ":" .. tostring(source.slot)
	local now = RealTime()

	if (NETWORK.gui.lastClickKey == key and now - (NETWORK.gui.lastClickTime or 0) < 0.35) then
		NETWORK.gui.lastClickKey = nil

		if (quick) then
			quick()
		end

		return
	end

	NETWORK.gui.lastClickKey = key
	NETWORK.gui.lastClickTime = now

	NETWORK.gui.Select(source)
end

local function BuildKeyHints(parent, x, y, width, hints)
	local Sc = NETWORK.util.Scale
	local panel = parent:Add("DPanel")

	panel:SetPos(x, y)
	panel:SetSize(width, Sc(22))
	panel:SetMouseInputEnabled(false)
	panel.Paint = function(self, panelWidth, panelHeight)
		local palette = Palette()
		local cursor = 0
		local middle = math.Round(panelHeight * 0.5)

		for _, hint in ipairs(hints) do
			surface.SetFont("nwInvKey")

			local keyWidth = surface.GetTextSize(hint[1]) + Sc(12)

			draw.RoundedBox(math.max(Sc(4), 3), cursor, middle - Sc(9), keyWidth, Sc(18),
				Color(255, 255, 255, 16))

			draw.SimpleText(hint[1], "nwInvKey", cursor + math.Round(keyWidth * 0.5), middle,
				ColorAlpha(palette.text, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local label = NETWORK.util.Upper(hint[2])

			surface.SetFont("nwInvKey")

			local labelWidth = surface.GetTextSize(label)

			draw.SimpleText(label, "nwInvKey", cursor + keyWidth + Sc(8), middle,
				ColorAlpha(palette.textDim, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			cursor = cursor + keyWidth + labelWidth + Sc(22)
		end
	end

	return panel
end

local function BuildDetail(page, x, y, width, height)
	local Sc = NETWORK.util.Scale
	local holder = page:Add("DPanel")

	holder:SetPos(x, y)
	holder:SetSize(width, height)
	holder.Paint = function() end

	local selected = NETWORK.gui.selected
	local item = selected and NETWORK.gui.ItemAt(selected)

	if (!item) then
		if (selected) then
			NETWORK.gui.selected = nil
		end

		local wounds = holder:Add("nwWoundPanel")

		wounds:SetPos(0, 0)
		wounds:SetSize(width, height - Sc(50))

		local hint = holder:Add("DPanel")

		hint:SetPos(0, height - Sc(40))
		hint:SetSize(width, Sc(40))
		hint:SetMouseInputEnabled(false)
		hint.Paint = function(self, panelWidth, panelHeight)
			local palette = Palette()

			for index, line in ipairs(NETWORK.util.WrapText(L("invSelectHint"), "nwHudSmall",
				panelWidth, 2)) do
				draw.SimpleText(line, "nwHudSmall", math.Round(panelWidth * 0.5),
					Sc(10) + (index - 1) * Sc(15), ColorAlpha(palette.textFaint, 220),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		return holder
	end

	local base = NETWORK.item.Get(item.id) or {}
	local rarity = NETWORK.inventory.GetRarity(NETWORK.item.GetRarity(item))
	local name = NETWORK.item.GetName(item)
	local description = NETWORK.item.GetDescription(item)

	local stats = {}

	if ((base.protection or 0) > 0) then
		stats[#stats + 1] = {L("statArmour"), base.protection .. " / " .. base.protection, 1}
	end

	if ((base.hunger or 0) != 0) then
		stats[#stats + 1] = {L("statHunger"), "+" .. base.hunger, math.Clamp(base.hunger / 100, 0, 1)}
	end

	if ((base.thirst or 0) != 0) then
		stats[#stats + 1] = {L("statThirst"), "+" .. base.thirst, math.Clamp(base.thirst / 100, 0, 1)}
	end

	if ((base.healWound or 0) > 0) then
		stats[#stats + 1] = {L("invStatHeal"), "+" .. base.healWound,
			math.Clamp(base.healWound / NETWORK.wound.max, 0, 1)}
	end

	if ((base.storageSlots or 0) > 0) then
		stats[#stats + 1] = {L("invStatStorage"), tostring(base.storageSlots)}
	end

	if ((item.amount or 1) > 1) then
		stats[#stats + 1] = {L("invAmount"), tostring(item.amount) .. " / " ..
			NETWORK.item.GetMaxStack(item)}
	end

	local lines = NETWORK.util.WrapText(description, "nwInvBody", width - Sc(4), 12)
	local previewSize = math.min(width, math.Round(height * 0.34))

	local header = holder:Add("DPanel")

	header:SetPos(0, 0)
	header:SetSize(width, Sc(44))
	header:SetMouseInputEnabled(false)
	header.Paint = function(self, panelWidth, panelHeight)
		local palette = Palette()

		surface.SetDrawColor(rarity.color.r, rarity.color.g, rarity.color.b, 245)
		surface.DrawRect(0, Sc(4), Sc(3), Sc(14))

		local nameLines = NETWORK.util.WrapText(NETWORK.util.Upper(name), "nwInvName",
			panelWidth - Sc(12), 2)

		for index, line in ipairs(nameLines) do
			draw.SimpleText(line, "nwInvName", Sc(10), Sc(11) + (index - 1) * Sc(15),
				ColorAlpha(palette.text, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		draw.SimpleText(NETWORK.util.Upper(L(rarity.name)), "nwInvSub", Sc(10),
			Sc(11) + #nameLines * Sc(15), ColorAlpha(rarity.color, 245), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	local previewY = Sc(56)
	local preview = holder:Add("DPanel")

	preview:SetPos(0, previewY)
	preview:SetSize(width, previewSize)
	preview:SetMouseInputEnabled(false)

	preview.Paint = function(self, panelWidth, panelHeight)
		surface.SetDrawColor(0, 0, 0, 120)
		surface.DrawRect(0, 0, panelWidth, panelHeight)
	end

	local icon = holder:Add("nwItemIcon")

	icon:SetPos(Sc(10), previewY + Sc(10))
	icon:SetSize(width - Sc(20), previewSize - Sc(20))
	icon:SetMouseInputEnabled(false)
	icon:SetItem(item)

	local infoY = previewY + previewSize + Sc(10)
	local statHeight = Sc(26)
	local info = holder:Add("DPanel")

	info:SetPos(0, infoY)
	info:SetSize(width, Sc(28) + #stats * statHeight)
	info:SetMouseInputEnabled(false)
	info.Paint = function(self, panelWidth, panelHeight)
		local palette = Palette()
		local weight = string.format("%.0f", NETWORK.item.GetWeight(item) * 1000) ..
			" " .. L("invGrams")

		draw.SimpleText(NETWORK.util.Upper(L("invWeight")), "nwInvKey", 0, Sc(10),
			ColorAlpha(palette.textDim, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(weight, "nwInvStat", panelWidth, Sc(10),
			ColorAlpha(palette.text, 250), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		local y = Sc(34)

		for _, stat in ipairs(stats) do
			draw.SimpleText(NETWORK.util.Upper(stat[1]), "nwInvKey", 0, y,
				ColorAlpha(palette.textDim, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(stat[2], "nwInvStat", panelWidth, y, ColorAlpha(palette.text, 250),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			y = y + statHeight
		end
	end

	local buttonHeight = Sc(34)
	local actions = {}

	if (NETWORK.item.CanUse(item)) then
		actions[#actions + 1] = {L(NETWORK.item.GetUseLabel(item)), "plus", true, function()
			NETWORK.inventory.Use(selected)
		end}
	end

	if (NETWORK.item.GetEquipSlot(item) and selected.list == "items") then
		actions[#actions + 1] = {L("itemEquip"), "up", #actions == 0, function()
			NETWORK.inventory.Equip(selected.index)
		end}
	end

	if (selected.list == "equipped") then
		actions[#actions + 1] = {L("itemUnequip"), "minus", true, function()
			NETWORK.inventory.Unequip(selected.slot)
		end}
	end

	if (selected.list == "storage") then
		actions[#actions + 1] = {L("invTakeOut"), "up", #actions == 0, function()
			NETWORK.inventory.FromStorage(selected.index)
		end}
	end

	actions[#actions + 1] = {L("itemDrop"), "down", false, function()
		NETWORK.inventory.Drop(selected)
	end}

	local actionsHeight = #actions * (buttonHeight + Sc(6))
	local descriptionY = infoY + Sc(28) + #stats * statHeight + Sc(10)
	local descriptionHeight = math.max(height - descriptionY - actionsHeight - Sc(10), Sc(40))
	local text = holder:Add("DPanel")

	text:SetPos(0, descriptionY)
	text:SetSize(width, descriptionHeight)
	text:SetMouseInputEnabled(false)
	text.Paint = function(self, panelWidth, panelHeight)
		local palette = Palette()

		surface.SetDrawColor(palette.lineSoft.r, palette.lineSoft.g, palette.lineSoft.b, 200)
		surface.DrawRect(0, 0, panelWidth, 1)

		local maxLines = math.floor((panelHeight - Sc(14)) / Sc(19))

		for index, line in ipairs(lines) do
			if (index > maxLines) then
				break
			end

			draw.SimpleText(line, "nwInvBody", 0, Sc(18) + (index - 1) * Sc(19),
				ColorAlpha(palette.textDim, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	local buttonY = height - actionsHeight

	for _, action in ipairs(actions) do
		local button = holder:Add("nwInvButton")

		button:SetPos(0, buttonY)
		button:SetSize(width, buttonHeight)
		button:Setup(action[1], action[2], action[3])
		button.DoClick = action[4]

		buttonY = buttonY + buttonHeight + Sc(6)
	end

	return holder
end

local function BuildDetailWide(page, x, y, width, height)
	local Sc = NETWORK.util.Scale
	local holder = page:Add("DPanel")

	holder:SetPos(x, y)
	holder:SetSize(width, height)
	holder.Paint = function() end

	local selected = NETWORK.gui.selected
	local item = selected and NETWORK.gui.ItemAt(selected)

	if (!item) then
		return holder
	end

	local base = NETWORK.item.Get(item.id) or {}
	local rarity = NETWORK.inventory.GetRarity(NETWORK.item.GetRarity(item))
	local name = NETWORK.item.GetName(item)
	local stats = {
		{L("invWeight"), string.format("%.0f", NETWORK.item.GetWeight(item) * 1000) ..
			" " .. L("invGrams")}
	}

	local armour = NETWORK.gui.ArmourInfo and NETWORK.gui.ArmourInfo(item)

	if (armour) then
		stats[#stats + 1] = {L("invProtection"), NETWORK.gui.FormatPercent(armour.effective)}

		if (armour.condition) then
			stats[#stats + 1] = {L("invCondition"), NETWORK.gui.FormatPercent(armour.condition)}
		end
	end

	if ((base.hunger or 0) != 0) then
		stats[#stats + 1] = {L("statHunger"), "+" .. base.hunger}
	end

	if ((base.thirst or 0) != 0) then
		stats[#stats + 1] = {L("statThirst"), "+" .. base.thirst}
	end

	if (NETWORK.medical and NETWORK.medical.IsTreatment(item.id)) then
		local treatment = NETWORK.medical.GetTreatment(item.id)

		stats[#stats + 1] = {L("invStatApply"), treatment.time .. " " .. L("invSeconds")}
	end

	if ((base.storageSlots or 0) > 0) then
		stats[#stats + 1] = {L("invStatStorage"), tostring(base.storageSlots)}
	end

	if ((item.amount or 1) > 1) then
		stats[#stats + 1] = {L("invAmount"), tostring(item.amount) .. " / " ..
			NETWORK.item.GetMaxStack(item)}
	end

	local actions = {}

	if (NETWORK.item.CanUse(item)) then
		actions[#actions + 1] = {L(NETWORK.item.GetUseLabel(item)), "plus", true, function()
			NETWORK.inventory.Use(selected)
		end}
	end

	if (NETWORK.item.GetEquipSlot(item) and selected.list == "items") then
		actions[#actions + 1] = {L("itemEquip"), "up", #actions == 0, function()
			NETWORK.inventory.Equip(selected.index)
		end}
	end

	if (selected.list == "equipped") then
		actions[#actions + 1] = {L("itemUnequip"), "minus", true, function()
			NETWORK.inventory.Unequip(selected.slot)
		end}
	end

	if (selected.list == "storage") then
		actions[#actions + 1] = {L("invTakeOut"), "up", #actions == 0, function()
			NETWORK.inventory.FromStorage(selected.index)
		end}
	end

	actions[#actions + 1] = {L("itemDrop"), "down", false, function()
		NETWORK.inventory.Drop(selected)
	end}

	local buttonHeight = Sc(28)
	local buttonGap = Sc(4)
	local buttonsHeight = #actions * (buttonHeight + buttonGap)
	local contentHeight = height - buttonsHeight - Sc(8)
	local previewSize = math.Clamp(math.floor(width * 0.3), Sc(56), math.max(contentHeight, Sc(56)))

	local preview = holder:Add("DPanel")

	preview:SetPos(0, 0)
	preview:SetSize(previewSize, previewSize)
	preview:SetMouseInputEnabled(false)
	preview.Paint = function(self, panelWidth, panelHeight)
		draw.RoundedBox(math.max(Sc(6), 3), 0, 0, panelWidth, panelHeight,
			Color(0, 0, 0, 120))

		NETWORK.util.DrawVGradient(0, math.Round(panelHeight * 0.4), panelWidth,
			panelHeight - math.Round(panelHeight * 0.4), ColorAlpha(rarity.color, 0),
			ColorAlpha(rarity.color, 40))
	end

	local icon = holder:Add("nwItemIcon")

	icon:SetPos(Sc(8), Sc(8))
	icon:SetSize(previewSize - Sc(16), previewSize - Sc(16))
	icon:SetMouseInputEnabled(false)
	icon:SetItem(item)

	local textX = previewSize + Sc(14)
	local textWidth = width - textX
	local info = holder:Add("DPanel")

	info:SetPos(textX, 0)
	info:SetSize(textWidth, contentHeight)
	info:SetMouseInputEnabled(false)
	info.Paint = function(self, panelWidth, panelHeight)
		local palette = Palette()
		local nameLines = NETWORK.util.WrapText(NETWORK.util.Upper(name), "nwInvName",
			panelWidth, 2)
		local cursor = Sc(8)

		for _, line in ipairs(nameLines) do
			draw.SimpleText(line, "nwInvName", 0, cursor, ColorAlpha(palette.text, 250),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			cursor = cursor + Sc(16)
		end

		draw.SimpleText(NETWORK.util.Upper(L(rarity.name)), "nwInvSub", 0, cursor,
			ColorAlpha(rarity.color, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(20)

		for _, stat in ipairs(stats) do
			if (cursor > panelHeight - Sc(10)) then
				break
			end

			draw.SimpleText(NETWORK.util.Upper(stat[1]), "nwInvKey", 0, cursor,
				ColorAlpha(palette.textDim, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(stat[2], "nwInvStat", panelWidth, cursor,
				ColorAlpha(palette.text, 250), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			cursor = cursor + Sc(20)
		end

		cursor = cursor + Sc(4)

		local maxLines = math.floor((panelHeight - cursor) / Sc(17))

		if (maxLines <= 0) then
			return
		end

		for index, line in ipairs(NETWORK.util.WrapText(NETWORK.item.GetDescription(item),
			"nwInvBody", panelWidth, maxLines)) do
			draw.SimpleText(line, "nwInvBody", 0, cursor + (index - 1) * Sc(17),
				ColorAlpha(palette.textDim, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
	end

	for index, action in ipairs(actions) do
		local button = holder:Add("nwInvButton")

		button:SetPos(0, height - buttonsHeight + (index - 1) * (buttonHeight + buttonGap))
		button:SetSize(width, buttonHeight)
		button:Setup(action[1], action[2], action[3])
		button.DoClick = action[4]
	end

	return holder
end

local VITAL_COLORS = {
	hunger = Color(158, 142, 96),
	thirst = Color(92, 118, 144),
	blood = Color(152, 72, 70),
	armour = Color(84, 92, 150),
	pain = Color(164, 112, 72)
}

local function Stage(value, keys)
	if (value >= 75) then
		return keys[1]
	elseif (value >= 50) then
		return keys[2]
	elseif (value >= 25) then
		return keys[3]
	end

	return keys[4]
end

local function GetVitalRows(client)
	local rows = {}
	local hunger = client:GetHunger()
	local thirst = client:GetThirst()

	rows[#rows + 1] = {L(Stage(hunger, {"vitHunger1", "vitHunger2", "vitHunger3",
		"vitHunger4"})), hunger / 100, VITAL_COLORS.hunger}

	rows[#rows + 1] = {L(Stage(thirst, {"vitThirst1", "vitThirst2", "vitThirst3",
		"vitThirst4"})), thirst / 100, VITAL_COLORS.thirst}

	if (NETWORK.medical and client.GetBlood) then
		local _, class = NETWORK.medical.GetBloodClass(client:GetBlood())

		local label = client:GetBloodFraction() >= 0.99 and L("vitBloodOk") or L(class.name)

		rows[#rows + 1] = {label, client:GetBloodFraction(), VITAL_COLORS.blood}
	end

	local GetWorn = NETWORK.gui.GetWornProtection

	if (GetWorn) then
		local head = GetWorn(client, "helmet")
		local body = GetWorn(client, "armour")

		if (head > 0 or body > 0) then
			rows[#rows + 1] = {L("vitProtection", NETWORK.gui.FormatPercent(head),
				NETWORK.gui.FormatPercent(body)), math.max(head, body), VITAL_COLORS.armour}
		else
			rows[#rows + 1] = {L("vitNoProtection"), 0, VITAL_COLORS.armour}
		end
	end

	local pain = NETWORK.wound.GetPain(client)
	local painKey = NETWORK.wound.IsNumb(client) and "vitPainNumb" or
		(pain > 0 and "vitPain" or "vitNoPain")

	rows[#rows + 1] = {L(painKey), math.Clamp(pain / 60, 0, 1), VITAL_COLORS.pain}

	return rows
end

local function BuildVitals(parent, x, y, width, height)
	local Sc = NETWORK.util.Scale
	local panel = parent:Add("DPanel")

	panel:SetPos(x, y)
	panel:SetSize(width, height)
	panel:SetMouseInputEnabled(false)
	panel.Paint = function(self, panelWidth, panelHeight)
		local palette = Palette()
		local client = LocalPlayer()

		if (!IsValid(client)) then
			return
		end

		local body = NETWORK.medical and NETWORK.medical.body
		local bodyWidth = 0

		if (body and body.IsAvailable()) then
			local bx, by, bw, bh = body.GetRect(0, 0, math.Round(panelHeight * 0.45),
				panelHeight)
			local colors = {}
			local bleeds = client:GetBleedMap()

			for _, part in ipairs(NETWORK.wound.parts) do
				local value = NETWORK.wound.Get(client, part.id)
				local bleed = bleeds[part.id]

				if (bleed and !bleed.tq) then
					local pulse = 0.6 + math.abs(math.sin(RealTime() * 3)) * 0.4

					colors[part.id] = ColorAlpha(palette.danger, 235 * pulse)
				elseif (client:HasFracture(part.id)) then
					colors[part.id] = Color(178, 118, 232)
				elseif (value > 0) then
					local _, color = NETWORK.wound.GetSeverity(value)

					colors[part.id] = color
				end
			end

			body.Draw(bx, by, bw, bh, colors, 1)

			bodyWidth = bx + bw + Sc(18)
		end

		local rows = GetVitalRows(client)
		local barsX = bodyWidth
		local barsWidth = panelWidth - barsX
		local rowHeight = math.min(Sc(40), math.floor(panelHeight / #rows))
		local barHeight = math.max(Sc(6), 4)
		local top = math.Round((panelHeight - rowHeight * #rows) * 0.5)

		for index, row in ipairs(rows) do
			local rowY = top + (index - 1) * rowHeight
			local barY = rowY + rowHeight - barHeight - Sc(6)
			local color = row[3]

			draw.SimpleText(row[1], "nwField", barsX, barY - Sc(4),
				ColorAlpha(palette.text, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

			draw.RoundedBox(math.floor(barHeight * 0.5), barsX, barY, barsWidth, barHeight,
				Color(255, 255, 255, 16))

			local fill = math.Round(barsWidth * math.Clamp(row[2] or 0, 0, 1))

			if (fill >= barHeight) then
				draw.RoundedBox(math.floor(barHeight * 0.5), barsX, barY, fill, barHeight,
					ColorAlpha(color, 235))
			end
		end
	end

	return panel
end

local SLOT_GLYPHS = {
	helmet = "helmet",
	hat = "hat",
	glasses = "glasses",
	mask = "mask",
	jacket = "shirt",
	vest = "vest",
	armour = "shield",
	gloves = "gloves",
	pants = "pants",
	boots = "boot",
	backpack = "backpack",
	radio = "radio",
	cuffs = "minus",
	watch = "watch",
	light = "light",
	primary = "rifle",
	secondary = "pistol",
	melee = "knife"
}

local function BuildTag(parent, text, x, y, width, options)
	local Sc = NETWORK.util.Scale
	local panel = parent:Add("DPanel")
	local caption = NETWORK.util.Upper(text)

	options = options or {}

	panel:SetPos(x, y)
	panel:SetSize(width, Sc(22))
	panel:SetMouseInputEnabled(false)
	panel.startTime = CurTime()
	panel.Paint = function(self, panelWidth, panelHeight)
		local util = NETWORK.util
		local reveal = util.EaseOut(util.Stagger(self.startTime, 0.04, 0.4))
		local badgeText, badgeColor

		if (options.badge) then
			badgeText, badgeColor = options.badge()
		end

		NETWORK.tk.Header(0, 0, panelWidth, panelHeight, caption, reveal, badgeText,
			badgeColor)

		if (options.OnPaintOver and reveal > 0.01) then
			options.OnPaintOver(panel, panelWidth, panelHeight, reveal)
		end
	end

	return panel
end

local function BuildStats(parent, x, y, width, height)
	local Sc = NETWORK.util.Scale
	local panel = parent:Add("DPanel")

	panel:SetPos(x, y)
	panel:SetSize(width, height)
	panel:SetMouseInputEnabled(false)
	panel.Paint = function(self, panelWidth, panelHeight)
		local theme = NETWORK.theme
		local client = LocalPlayer()

		if (!IsValid(client)) then
			return
		end

		draw.RoundedBox(math.max(Sc(6), 3), 0, 0, panelWidth, panelHeight,
			Color(10, 11, 13, 190))

		local entries = {
			{"shield", tostring(client:GetLoyalty()) .. " " .. L("invLoyaltyShort"),
				theme.accentSoft},
			{"weight", string.format("%.1f", NETWORK.inventory.GetWeight()) ..
				L("invWeightUnit"), NETWORK.inventory.GetWeight() >
				NETWORK.inventory.maxWeight and theme.danger or theme.textDim}
		}

		local step = panelWidth / #entries
		local middle = math.Round(panelHeight * 0.5)
		local glyph = Sc(16)

		for index, entry in ipairs(entries) do
			local cellX = math.Round((index - 1) * step)

			surface.SetFont("nwInvStat")

			local textWidth = surface.GetTextSize(entry[2])
			local startX = cellX + math.Round((step - glyph - Sc(8) - textWidth) * 0.5)

			NETWORK.gui.DrawGlyph(entry[1], startX, middle - math.Round(glyph * 0.5),
				glyph, ColorAlpha(theme.combine, 235))

			draw.SimpleText(entry[2], "nwInvStat", startX + glyph + Sc(8), middle,
				ColorAlpha(entry[3], 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if (index > 1) then
				surface.SetDrawColor(255, 255, 255, 14)
				surface.DrawRect(cellX, Sc(8), 1, panelHeight - Sc(16))
			end
		end
	end

	return panel
end

local EQUIP_COLUMNS = {
	{group = "extra", name = "equipShortExtra"},
	{group = "head", name = "equipShortHead"},
	{group = "body", name = "equipShortBody"},
	{group = "legs", name = "equipShortLegs"}
}

local function GetGroup(id)
	for _, group in ipairs(NETWORK.inventory.equipment) do
		if (group.id == id) then
			return group
		end
	end
end

local function DrawStatBar(x, y, width, label, valueText, fraction, color, alpha)
	local Sc = NETWORK.util.Scale
	local palette = Palette()
	local barHeight = math.max(Sc(3), 2)
	local barY = y + Sc(16)

	draw.SimpleText(NETWORK.util.Upper(label), "nwInvKey", x, y + Sc(6),
		ColorAlpha(palette.textFaint, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (valueText) then
		draw.SimpleText(valueText, "nwInvSub", x + width, y + Sc(6),
			ColorAlpha(palette.textDim, 240 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	draw.RoundedBox(math.floor(barHeight * 0.5), x, barY, width, barHeight,
		Color(255, 255, 255, 16 * alpha))

	local fill = math.Round(width * math.Clamp(fraction or 0, 0, 1))

	if (fill >= barHeight) then
		draw.RoundedBox(math.floor(barHeight * 0.5), x, barY, fill, barHeight,
			ColorAlpha(color, 235 * alpha))
	end
end

local STAMINA_COLOR = Color(182, 155, 230)

local ARMOUR_COLOR = Color(150, 190, 235)

local function DrawMeter(x, y, width, rowHeight, labelWidth, label, valueText, fraction,
	color, alpha)
	local Sc = NETWORK.util.Scale
	local palette = Palette()
	local middle = y + math.Round(rowHeight * 0.5)
	local numberWidth = Sc(34)
	local barHeight = math.max(Sc(3), 2)
	local barRadius = math.floor(barHeight * 0.5)

	draw.SimpleText(label, "nwInvStat", x, middle, ColorAlpha(palette.textDim, 235 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(valueText, "nwInvSub", x + width, middle,
		ColorAlpha(palette.text, 245 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	local barX = x + labelWidth
	local barWidth = width - labelWidth - numberWidth

	if (barWidth < Sc(10)) then
		return
	end

	local barY = middle - barRadius

	draw.RoundedBox(barRadius, barX, barY, barWidth, barHeight,
		Color(255, 255, 255, 20 * alpha))

	local fill = math.Round(barWidth * math.Clamp(fraction or 0, 0, 1))

	if (fill >= barHeight) then
		draw.RoundedBox(barRadius, barX, barY, fill, barHeight,
			Color(color.r, color.g, color.b, 235 * alpha))
	end
end

local function DrawValueRow(x, y, width, label, valueText, alpha, color)
	local palette = Palette()

	draw.SimpleText(NETWORK.util.Upper(label), "nwInvKey", x, y,
		ColorAlpha(palette.textFaint, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(valueText, "nwInvSub", x + width, y,
		ColorAlpha(color or palette.text, 245 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

local EQUIP_ROWS = {"head", "body", "legs", "extra"}

local function BuildEquipRow(parent, data, x, y, width, height, order)
	local slot = parent:Add("nwItemSlot")

	slot:SetPos(x, y)
	slot:SetSize(width, height)
	slot:SetRow(true)
	slot:SetRevealDelay(0.06 + order * 0.015)
	slot:SetSlotName(L(data.name))
	slot:SetSource("equipped", 0, data.id)
	slot:SetItem(NETWORK.inventory.GetEquipped(data.id))
	slot.DoClick = function()
		SelectOrQuick(slot, function()
			NETWORK.inventory.Unequip(data.id)
		end)
	end

	local basePaintOver = slot.PaintOver

	slot.PaintOver = function(self, panelWidth, panelHeight)
		local item = self.item
		local drag = NETWORK.gui.drag
		local reveal = self.reveal or 0

		if (item and reveal >= 0.01 and !(drag and drag.panel == self) and
			NETWORK.gui.ArmourInfo and NETWORK.gui.RowSquare) then
			local info = NETWORK.gui.ArmourInfo(item)

			if (info) then
				local Sc = NETWORK.util.Scale
				local palette = Palette()
				local offset = math.Round((1 - reveal) * Sc(6))
				local squareX, _, square = NETWORK.gui.RowSquare(panelHeight)
				local labelY = offset + math.Round(panelHeight * 0.5) + Sc(9)
				local labelX = squareX + square + Sc(10)
				local text = "·  " .. self.protectionCaption ..
					" " .. NETWORK.gui.FormatPercent(info.effective)

				surface.SetFont("nwInvKey")

				local labelWidth = surface.GetTextSize(self.upperSlotName)
				local textWidth = surface.GetTextSize(text)

				surface.SetFont("nwInvSub")

				local conditionWidth = info.condition and surface.GetTextSize("100 %") or 0
				local limit = panelWidth - Sc(10) - conditionWidth - Sc(8)
				local textX = labelX + labelWidth + Sc(6)

				if (textX + textWidth <= limit) then
					local color = info.condition and info.condition <= 0 and palette.danger or
						NETWORK.theme.combine

					draw.SimpleText(text, "nwInvKey", textX, labelY,
						ColorAlpha(color, 235 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end
			end
		end

		if (basePaintOver) then
			basePaintOver(self, panelWidth, panelHeight)
		end
	end

	slot.upperSlotName = NETWORK.util.Upper(L(data.name))
	slot.protectionCaption = NETWORK.util.Upper(L("invProtectionShort"))

	return slot
end

local function StyleScrollBar(scroll)
	local Sc = NETWORK.util.Scale

	scroll.Paint = function() end
	scroll:GetVBar():SetWide(math.max(Sc(4), 3))
	scroll:GetVBar().Paint = function() end
	scroll:GetVBar().btnUp.Paint = function() end
	scroll:GetVBar().btnDown.Paint = function() end
	scroll:GetVBar().btnGrip.Paint = function(panel, panelWidth, panelHeight)
		draw.RoundedBox(2, 0, 0, panelWidth, panelHeight, Color(255, 255, 255, 60))
	end
end

-- Инвентарь: минималистичная раскладка в три колонки.
-- Слева — персонаж: модель, вокруг неё слоты одежды и брони, снизу снаряжение, показатели, статусы.
-- По центру — сумка-инвентарь и рюкзак. Справа — оружие и карточка выбранного предмета.
local MIN_LINE = Color(255, 255, 255, 18)

local function MinimalTitle(parent, text, x, y, width, badge)
	local Sc = NETWORK.util.Scale
	local panel = parent:Add("DPanel")
	local caption = NETWORK.util.Upper(text)

	panel:SetPos(x, y)
	panel:SetSize(width, Sc(26))
	panel:SetMouseInputEnabled(false)
	panel.startTime = CurTime()
	panel.Paint = function(self, w, h)
		local palette = Palette()
		local util = NETWORK.util
		local reveal = util.EaseOut(util.Stagger(self.startTime, 0.03, 0.35))

		util.DrawTextSpaced(caption, "nwInvKey", 0, h * 0.5 - Sc(2), ColorAlpha(palette.textDim, 235 * reveal),
			math.max(Sc(2), 1), TEXT_ALIGN_CENTER)

		if (badge) then
			local text, color = badge()

			if (text) then
				draw.SimpleText(text, "nwInvSub", w, h * 0.5 - Sc(2),
					ColorAlpha(color or palette.textFaint, 235 * reveal), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		surface.SetDrawColor(MIN_LINE.r, MIN_LINE.g, MIN_LINE.b, MIN_LINE.a * reveal)
		surface.DrawRect(0, h - 1, w * reveal, 1)
	end

	return panel
end

local function EquipTile(parent, data, x, y, size, order)
	local slot = parent:Add("nwItemSlot")

	slot:SetPos(x, y)
	slot:SetSize(size, size)
	slot:SetCompact(true)
	slot:SetRevealDelay(0.04 + order * 0.012)
	slot:SetSlotName(L(data.name))
	slot:SetSource("equipped", 0, data.id)
	slot:SetItem(NETWORK.inventory.GetEquipped(data.id))
	slot.DoClick = function()
		SelectOrQuick(slot, function()
			NETWORK.inventory.Unequip(data.id)
		end)
	end

	return slot
end

local function SlotData(id)
	for _, group in ipairs(NETWORK.inventory.equipment) do
		for _, data in ipairs(group.slots) do
			if (data.id == id) then
				return data
			end
		end
	end
end

local function CountCells(source)
	local used = 0

	for _, item in pairs(source or {}) do
		local itemWidth, itemHeight = NETWORK.item.GetSize(item)

		used = used + (itemWidth or 1) * (itemHeight or 1)
	end

	return used
end

local function BuildInventoryPage(page, menu)
	local Sc = NETWORK.util.Scale
	local W, H = page:GetWide(), page:GetTall()
	local columns, rows = NETWORK.inventory.columns, NETWORK.inventory.rows
	local container = NETWORK.inventory.GetContainer()
	local character = LocalPlayer():GetCharacter()
	local gutter = Sc(36)
	local leftW = math.Clamp(math.floor(W * 0.31), Sc(320), Sc(460))
	local rightW = math.Clamp(math.floor(W * 0.25), Sc(280), Sc(380))
	local centerX = leftW + gutter
	local centerW = W - leftW - rightW - gutter * 2
	local rightX = W - rightW
	local tabPage = page

	NETWORK.gui.ResetFilter()

	-- Тонкие разделители колонок вместо тяжёлых плит.
	local back = page:Add("DPanel")

	back:SetPos(0, 0)
	back:SetSize(W, H)
	back:SetMouseInputEnabled(false)
	back.Paint = function(_, w, h)
		surface.SetDrawColor(MIN_LINE)
		surface.DrawRect(leftW + gutter / 2, Sc(8), 1, h - Sc(16))
		surface.DrawRect(rightX - gutter / 2, Sc(8), 1, h - Sc(16))
	end

	-- ЛЕВАЯ КОЛОНКА ------------------------------------------------------------------------
	local identity = page:Add("DButton")

	identity:SetText("")
	identity:SetPos(0, 0)
	identity:SetSize(leftW, Sc(52))
	identity:SetCursor("hand")
	identity.DoClick = function()
		NETWORK.sound.Click()
		NETWORK.gui.OpenDescriptionEditor()
	end
	identity.Paint = function(self, w, h)
		local client = LocalPlayer()

		if (!IsValid(client)) then
			return
		end

		local palette = Palette()
		local util = NETWORK.util
		local faction = character and character:GetFactionTable()
		local line = util.Upper(faction and L(faction.name) or "")

		draw.SimpleText(util.TruncateWidth(client:GetCharacterName() or "", "nwInvTitle", w), "nwInvTitle", 0, Sc(14),
			palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		util.DrawTextSpaced(util.TruncateWidth(line, "nwInvKey", w), "nwInvKey", 0, Sc(38),
			ColorAlpha(faction and faction.color or palette.textDim, 230), math.max(Sc(2), 1), TEXT_ALIGN_CENTER)

		if (self:IsHovered()) then
			draw.SimpleText(util.Upper(L("descEditButton")), "nwInvKey", w, Sc(14), palette.textFaint,
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	local vitalsH = Sc(5 * 22 + 8)
	local statusH = Sc(44)
	local extraH = Sc(58)
	local modelTop = Sc(60)
	local modelH = H - modelTop - extraH - vitalsH - statusH - Sc(24)
	local sideSlots = {{"helmet", "hat", "glasses", "mask", "gloves"}, {"jacket", "vest", "armour", "pants", "boots"}}
	local tile = math.Clamp(math.floor((modelH - Sc(6) * 4) / 5), Sc(44), Sc(70))
	local modelX = tile + Sc(10)
	local modelW = leftW - (tile + Sc(10)) * 2

	-- модель персонажа
	local model = page:Add("DModelPanel")

	model:SetPos(modelX, modelTop)
	model:SetSize(modelW, modelH)
	model:SetModel(LocalPlayer():GetCharacterModel())
	model:SetFOV(26)
	model:SetCursor("hand")
	model.rotation = 15
	model.LayoutEntity = function(self, entity)
		self:RunAnimation()

		if (self.bDragging) then
			local x = gui.MouseX()

			self.rotation = self.rotation + (x - (self.lastX or x)) * 0.6
			self.lastX = x
		end

		entity:SetAngles(Angle(0, self.rotation % 360, 0))
	end
	model.OnMousePressed = function(self, code)
		if (code == MOUSE_LEFT) then
			self.bDragging = true
			self.lastX = gui.MouseX()
			self:MouseCapture(true)
		end
	end
	model.OnMouseReleased = function(self)
		self.bDragging = false
		self:MouseCapture(false)
	end
	model.PaintOver = function(self, w, h)
		local drag = NETWORK.gui.drag

		if (!drag or !self:IsHovered()) then
			return
		end

		local palette = Palette()
		local color = NETWORK.item.CanUse(drag.item) and palette.positive or palette.danger

		NETWORK.util.DrawRoundedBorder(0, 0, w, h, math.max(Sc(6), 4), math.max(Sc(2), 2),
			Color(color.r, color.g, color.b, 200))
	end

	NETWORK.gui.modelPanel = model

	local entity = model:GetEntity()

	if (IsValid(entity)) then
		NETWORK.util.ApplyAppearance(model, LocalPlayer())

		if (character) then
			entity:SetModelScale(character:GetScale(), 0)
		end

		local sequence = entity:LookupSequence("idle_all_01")

		if (sequence > 0) then
			entity:ResetSequence(sequence)
		end

		NETWORK.util.FrameModelPanel(model, NETWORK.creation.GetFrameUnits(), 0.04, 1.05)
	end

	-- слоты одежды и брони по бокам модели
	local order = 0
	local slotsH = tile * 5 + Sc(6) * 4
	local slotsY = modelTop + math.floor((modelH - slotsH) * 0.5)

	for side, list in ipairs(sideSlots) do
		local x = side == 1 and 0 or (leftW - tile)

		for index, id in ipairs(list) do
			local data = SlotData(id)

			if (data) then
				order = order + 1
				EquipTile(page, data, x, slotsY + (index - 1) * (tile + Sc(6)), tile, order)
			end
		end
	end

	-- снаряжение рядом под моделью
	local extra = {"backpack", "radio", "watch", "light", "cuffs"}
	local extraTile = math.min(math.floor((leftW - Sc(6) * (#extra - 1)) / #extra), extraH)
	local extraY = modelTop + modelH + Sc(8)

	for index, id in ipairs(extra) do
		local data = SlotData(id)

		if (data) then
			order = order + 1
			EquipTile(page, data, (index - 1) * (extraTile + Sc(6)), extraY, extraTile, order)
		end
	end

	-- показатели тонкими полосками
	local vitalsY = extraY + extraH + Sc(10)
	local meterLabels = {L("statHealth"), L("statHunger"), L("statThirst"), L("invStamina"), L("statArmour")}
	local labelW = 0

	surface.SetFont("nwInvStat")

	for _, label in ipairs(meterLabels) do
		labelW = math.max(labelW, (surface.GetTextSize(label)))
	end

	labelW = math.min(labelW + Sc(12), math.floor(leftW * 0.4))

	local vitals = page:Add("DPanel")

	vitals:SetPos(0, vitalsY)
	vitals:SetSize(leftW, vitalsH)
	vitals:SetMouseInputEnabled(false)
	vitals.startTime = CurTime()
	vitals.Paint = function(self, w, h)
		local client = LocalPlayer()

		if (!IsValid(client)) then
			return
		end

		local tk = NETWORK.theme.tk
		local reveal = NETWORK.util.EaseOut(NETWORK.util.Stagger(self.startTime, 0.1, 0.4))
		local step = Sc(22)
		local health = math.max(client:Health(), 0)
		local stamina = client.GetStaminaFraction and client:GetStaminaFraction() or 1
		local hunger = client.GetHunger and client:GetHunger() or 100
		local thirst = client.GetThirst and client:GetThirst() or 100
		local armour = math.max(client:Armor(), 0)
		local rowsData = {
			{tostring(math.Round(health)), health / math.max(client:GetMaxHealth(), 1), tk.good},
			{tostring(math.Round(hunger)), hunger / 100, NETWORK.theme.warning},
			{tostring(math.Round(thirst)), thirst / 100, tk.water},
			{tostring(math.Round(stamina * 100)), stamina, tk.energy},
			{tostring(armour), armour / math.max(client:GetMaxArmor(), 1), ARMOUR_COLOR}
		}

		for index, row in ipairs(rowsData) do
			DrawMeter(0, (index - 1) * step, w, step, labelW, meterLabels[index], row[1], row[2], row[3],
				reveal * ((index == 5 and armour <= 0) and 0.45 or 1))
		end
	end

	-- статусы
	local status = page:Add("DPanel")
	local statusIcon = Sc(26)

	status:SetPos(0, vitalsY + vitalsH + Sc(6))
	status:SetSize(leftW, statusH)
	status.icons = {}
	status.nextRefresh = 0
	status.Paint = function(self)
		if (#self.icons == 0) then
			local palette = Palette()

			draw.SimpleText(L("statusNone"), "nwInvSub", 0, statusH * 0.5, ColorAlpha(palette.textFaint, 200),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
	status.Think = function(self)
		if (RealTime() < self.nextRefresh) then
			return
		end

		self.nextRefresh = RealTime() + 1

		local client = LocalPlayer()

		if (!IsValid(client) or !NETWORK.status or !NETWORK.status.Active) then
			return
		end

		local list = NETWORK.status.Active(client)
		local signature = ""

		for _, entry in ipairs(list) do
			signature = signature .. entry.id .. ";"
		end

		if (signature == self.signature) then
			return
		end

		self.signature = signature

		for _, icon in ipairs(self.icons) do
			if (IsValid(icon)) then
				icon:Remove()
			end
		end

		self.icons = {}

		for index, entry in ipairs(list) do
			local icon = self:Add("DPanel")

			icon:SetSize(statusIcon, statusIcon)
			icon:SetPos((index - 1) * (statusIcon + Sc(8)), math.floor((statusH - statusIcon) * 0.5))
			icon.Paint = function(panel, w, h)
				local material = NETWORK.util.GetMaterial("framework/status/" .. entry.id .. ".png", "smooth")

				if (material and !material:IsError()) then
					surface.SetMaterial(material)
					surface.SetDrawColor(entry.color.r, entry.color.g, entry.color.b, panel:IsHovered() and 255 or 215)
					surface.DrawTexturedRect(0, 0, w, h)
				elseif (NETWORK.gui.DrawGlyph) then
					NETWORK.gui.DrawGlyph(entry.glyph, 0, 0, w, ColorAlpha(entry.color, 230))
				end
			end
			icon.OnCursorEntered = function(panel)
				local owner = LocalPlayer()
				local value = IsValid(owner) and NETWORK.status.Value and NETWORK.status.Value(owner, entry)

				NETWORK.gui.SetTooltip(panel, {
					title = L("status" .. entry.id),
					color = entry.color,
					lines = NETWORK.util.WrapText(L("status" .. entry.id .. "Desc"), "nwTipBody", Sc(360), 4),
					footer = value and {{label = L("statusValue"), value = value, color = entry.color}} or nil
				})
			end
			icon.OnCursorExited = function(panel)
				NETWORK.gui.ClearTooltip(panel)
			end

			self.icons[#self.icons + 1] = icon
		end
	end

	-- ЦЕНТР ----------------------------------------------------------------------------------
	local center = page:Add("DScrollPanel")

	center:SetPos(centerX, 0)
	center:SetSize(centerW, H)
	StyleScrollBar(center)

	local gap = Sc(8)
	local bagRows = container and math.ceil(NETWORK.item.GetStorageSlots(container) / columns) or 0
	local titleH = Sc(26)
	local available = H - titleH * 2 - Sc(40) - (bagRows > 0 and 0 or Sc(56))
	local cell = math.floor((centerW - gap * (columns - 1)) / columns)

	cell = math.Clamp(math.min(cell, math.floor(available / math.max(rows + bagRows, 1)) - gap), Sc(48), Sc(120))

	local gridW = cell * columns + gap * (columns - 1)
	local gridX = math.max(math.floor((centerW - gridW) * 0.5), 0)

	MinimalTitle(center, L("tabInventory"), gridX, 0, gridW, function()
		local current = NETWORK.inventory.GetWeight()
		local maximum = NETWORK.inventory.MaxWeightFor and NETWORK.inventory.MaxWeightFor(LocalPlayer()) or
			NETWORK.inventory.maxWeight
		local palette = Palette()
		local color = current > maximum and palette.danger or (current > maximum * 0.8 and palette.warning or nil)

		return string.format("%.1f / %g %s", current, maximum, L("invWeightUnit")), color
	end)

	local gridY = titleH + Sc(12)

	NETWORK.gui.BuildGrid(center, "items", NETWORK.inventory.state.items, {
		x = gridX, y = gridY, cell = cell, cellWidth = cell, gap = gap, columns = columns, rows = rows,
		OnClick = function(index, slot)
			SelectOrQuick(slot, function()
				local item = NETWORK.inventory.GetItem(index)

				if (!item) then
					return
				end

				if (NETWORK.item.GetEquipSlot(item)) then
					NETWORK.inventory.Equip(index)
				elseif (NETWORK.item.CanUse(item)) then
					NETWORK.inventory.Use({list = "items", index = index})
				end
			end)
		end
	})

	local cursorY = gridY + rows * (cell + gap) - gap + Sc(22)

	MinimalTitle(center, container and NETWORK.item.GetName(container) or L("invBag"), gridX, cursorY, gridW, function()
		if (!container) then
			return
		end

		return CountCells(NETWORK.inventory.state.storage) .. " / " .. NETWORK.item.GetStorageSlots(container)
	end)

	cursorY = cursorY + titleH + Sc(12)

	if (container) then
		NETWORK.gui.BuildGrid(center, "storage", NETWORK.inventory.state.storage, {
			x = gridX, y = cursorY, cell = cell, cellWidth = cell, gap = gap, columns = columns, rows = bagRows,
			OnClick = function(index, slot)
				SelectOrQuick(slot, function()
					NETWORK.inventory.FromStorage(index)
				end)
			end
		})

		cursorY = cursorY + bagRows * (cell + gap)
	else
		local empty = center:Add("DPanel")

		empty:SetPos(gridX, cursorY)
		empty:SetSize(gridW, Sc(56))
		empty:SetMouseInputEnabled(false)
		empty.Paint = function(_, w, h)
			local palette = Palette()

			NETWORK.util.DrawRoundedBorder(0, 0, w, h, math.max(Sc(6), 4), 1, Color(255, 255, 255, 22))
			draw.SimpleText(L("invNoBag"), "nwInvBody", w * 0.5, h * 0.5, ColorAlpha(palette.textFaint, 220),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		cursorY = cursorY + Sc(56)
	end

	center:GetCanvas():SetTall(cursorY + Sc(12))

	-- ПРАВАЯ КОЛОНКА ------------------------------------------------------------------------
	local weapons = GetGroup("weapons")
	local rowH = Sc(46)
	local y = 0

	MinimalTitle(page, L("equipShortWeapons"), rightX, y, rightW)
	y = y + titleH + Sc(10)

	for index, data in ipairs(weapons and weapons.slots or {}) do
		order = order + 1
		BuildEquipRow(page, data, rightX, y, rightW, rowH, order)
		y = y + rowH + Sc(6)
	end

	y = y + Sc(14)

	local detailY = y
	local buttonH = Sc(32)
	local detailH = H - detailY - buttonH - Sc(12)

	page.RebuildDetail = function()
		if (IsValid(page.detail)) then
			page.detail:Remove()
		end

		local selected = NETWORK.gui.selected

		if (selected and NETWORK.gui.ItemAt(selected)) then
			page.detail = BuildDetailWide(page, rightX, detailY, rightW, detailH)

			return
		end

		page.detail = page:Add("DPanel")
		page.detail:SetPos(rightX, detailY)
		page.detail:SetSize(rightW, detailH)
		page.detail:SetMouseInputEnabled(false)
		page.detail.Paint = function(_, w, h)
			local palette = Palette()

			NETWORK.util.DrawRoundedBorder(0, 0, w, Sc(120), math.max(Sc(6), 4), 1, Color(255, 255, 255, 16))

			for index, line in ipairs(NETWORK.util.WrapText(L("invSelectHint"), "nwInvSub", w - Sc(40), 3)) do
				draw.SimpleText(line, "nwInvSub", w * 0.5, Sc(48) + (index - 1) * Sc(16),
					ColorAlpha(palette.textFaint, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
	end

	page.RebuildDetail()
	tabPage.RebuildDetail = page.RebuildDetail

	local examine = page:Add("nwInvButton")

	examine:SetPos(rightX, H - buttonH)
	examine:SetSize(rightW, buttonH)
	examine:Setup(L("invExamine"), "plus", false)
	examine.DoClick = function()
		net.Start("nwMedSelf")
		net.SendToServer()

		menu:Close()
	end
end

NETWORK.gui.RegisterTab("inventory", {
	name = "tabInventory",
	order = 10,
	glyph = "grid",
	Build = function(page, menu)
		BuildInventoryPage(page, menu)
	end
})

hook.Add("NetworkInventorySelected", "nwTabDetail", function()
	local menu = NETWORK.gui.tabMenu

	if (IsValid(menu) and IsValid(menu.page) and menu.page.RebuildDetail) then
		menu.page.RebuildDetail()
	end
end)

NETWORK.gui.RegisterTab("character", {
	name = "tabCharacter",
	order = 20,
	glyph = "person",
	Build = function(page, menu)
		local Sc = NETWORK.util.Scale
		local width = page:GetWide()
		local height = page:GetTall()
		local character = LocalPlayer():GetCharacter()

		BuildSectionLabel(page, L("tabCharacter"), 0, 0, width)

		if (!character) then
			local empty = page:Add("DPanel")

			empty:SetSize(width, Sc(40))
			empty:SetPos(0, Sc(60))
			empty.Paint = function(self, panelWidth, panelHeight)
				draw.SimpleText(L("charNone"), "nwNotice", Sc(8), math.Round(panelHeight * 0.5),
					ColorAlpha(NETWORK.theme.inv.textDim, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			return
		end

		local modelWidth = math.Round(width * 0.26)
		local model = page:Add("DModelPanel")

		model:SetSize(modelWidth, height - Sc(70))
		model:SetPos(0, Sc(56))
		model:SetModel(LocalPlayer():GetCharacterModel())
		model:SetFOV(30)
		model:SetMouseInputEnabled(true)
		model:SetCursor("hand")
		model.rotation = 0
		model.LayoutEntity = function(self, entity)
			if (self.bDragging) then
				local x = gui.MouseX()

				self.rotation = self.rotation + (x - (self.lastX or x)) * 0.6
				self.lastX = x
			else
				self.rotation = self.rotation + FrameTime() * 8
			end

			entity:SetAngles(Angle(0, self.rotation % 360, 0))
		end
		model.OnMousePressed = function(self, code)
			if (code != MOUSE_LEFT) then
				return
			end

			self.bDragging = true
			self.lastX = gui.MouseX()

			self:MouseCapture(true)
		end
		model.OnMouseReleased = function(self)
			self.bDragging = false

			self:MouseCapture(false)
		end
		model.OnCursorEntered = function(self)
			local character = LocalPlayer():GetCharacter()

			if (!character) then
				return
			end

			NETWORK.gui.SetTooltip(self, {
				title = character:GetName(),
				subtitle = L("invModelHint"),
				lines = NETWORK.util.WrapText(character:GetDescription(), "nwChatSmall",
					Sc(320), 4),
				color = NETWORK.theme.inv.accent
			})
		end
		model.OnCursorExited = function(self)
			NETWORK.gui.ClearTooltip(self)
		end

		local entity = model:GetEntity()

		if (IsValid(entity)) then
			NETWORK.util.ApplyAppearance(model, LocalPlayer())

			entity:SetModelScale(character:GetScale(), 0)

			local sequence = entity:LookupSequence("idle_all_01")

			if (sequence > 0) then
				entity:ResetSequence(sequence)
			end

			NETWORK.util.FrameModelPanel(model, NETWORK.creation.GetFrameUnits(), 0.03, 1.12)
		end

		local infoX = modelWidth + Sc(46)
		local infoWidth = width - infoX
		local card = page:Add("DPanel")

		card:SetSize(infoWidth, height - Sc(70))
		card:SetPos(infoX, Sc(56))
		card.startTime = CurTime()
		card:SetMouseInputEnabled(false)

		local descriptionY = Sc(126)
		local edit = page:Add("DButton")

		edit:SetText("")
		edit:SetCursor("hand")
		edit:SetPos(infoX, Sc(56) + descriptionY - Sc(11))
		edit:SetSize(infoWidth - Sc(24), Sc(22))
		edit.DoClick = function()
			NETWORK.sound.Click()
			NETWORK.gui.OpenDescriptionEditor()
		end
		edit.Paint = function(button, buttonWidth, buttonHeight)
			local theme = NETWORK.theme.inv

			draw.SimpleText(NETWORK.util.Upper(L("descEditButton")), "nwHudSmall",
				buttonWidth, math.Round(buttonHeight * 0.5),
				ColorAlpha(button:IsHovered() and NETWORK.theme.combine or theme.textFaint,
					235), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		card.Paint = function(self, panelWidth, panelHeight)
			local palette = NETWORK.theme.inv
			local theme = NETWORK.theme
			local util = NETWORK.util
			local reveal = util.EaseOut(util.Stagger(self.startTime, 0.05, 0.5))
			local x = Sc(20) + math.Round((1 - reveal) * Sc(22))
			local faction = character:GetFactionTable()
			local color = faction and faction.color or theme.combine
			local radius = math.max(Sc(10), 6)

			draw.RoundedBox(radius, 0, 0, panelWidth, panelHeight, Color(8, 9, 10, 170 * reveal))

			util.DrawRoundedBorder(0, 0, panelWidth, panelHeight, radius, math.max(Sc(1), 1),
				Color(255, 255, 255, 24 * reveal))

			draw.RoundedBox(math.max(Sc(2), 2), Sc(8), Sc(18), math.max(Sc(3), 2), Sc(44),
				ColorAlpha(color, 240 * reveal))

			draw.SimpleText(character:GetName(), "nwInvTitle", x, Sc(30),
				ColorAlpha(palette.text, 252 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local classID = LocalPlayer():GetNWString("nwClass", "")
			local classTable = classID != "" and NETWORK.classes and NETWORK.classes.Get(classID)
			local line = util.Upper(character:GetFactionName())

			if (classTable and classTable.bCivilianHud) then
				line = util.Upper(L(classTable.name))
			elseif (classTable and classTable.name) then
				line = line .. "  ·  " .. util.Upper(L(classTable.name))
			end

			draw.SimpleText(line, "nwInvSub", x, Sc(54), ColorAlpha(theme.combine, 245 * reveal),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(string.format("#%06d", character:GetID()), "nwInvSub",
				panelWidth - Sc(20), Sc(30), ColorAlpha(palette.textDim, 235 * reveal),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			draw.SimpleText(util.Upper(L("statId")), "nwInvKey", panelWidth - Sc(20), Sc(52),
				ColorAlpha(palette.textFaint, 200 * reveal), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			surface.SetDrawColor(255, 255, 255, 14 * reveal)
			surface.DrawRect(Sc(20), Sc(80), panelWidth - Sc(40), 1)

			local descriptionY = Sc(126)

			draw.SimpleText(util.Upper(L("labelDescription")), "nwInvKey", x, descriptionY,
				ColorAlpha(palette.textFaint, 235 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local lines = util.WrapText(character:GetDescription(), "nwInvBody",
				panelWidth - Sc(60), 6)
			local lineY = descriptionY + Sc(26)

			for i = 1, #lines do
				draw.SimpleText(lines[i], "nwInvBody", x, lineY,
					ColorAlpha(palette.textDim, 235 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				lineY = lineY + Sc(20)
			end

			local skillY = lineY + Sc(26)

			draw.SimpleText(util.Upper(L("stepSkills")), "nwInvKey", x, skillY,
				ColorAlpha(palette.textFaint, 235 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			skillY = skillY + Sc(30)

			local config = NETWORK.creation
			local skills = NETWORK.skills
			local client = LocalPlayer()
			local maxLevel = skills and skills.maxLevel or config.skillMax
			local barWidth = math.min(Sc(280), panelWidth - Sc(240))

			for i = 1, #config.skills do
				local data = config.skills[i]
				local value = skills and skills.Get(client, data.id) or character:GetSkill(data.id)
				local earned = skills and skills.GetEarned(client, data.id) or 0
				local xp = skills and skills.GetXP(client, data.id) or 0
				local need = (skills and value < maxLevel) and skills.Need(value) or 0
				local rowReveal = util.EaseOut(util.Stagger(self.startTime, 0.1 + i * 0.04, 0.45))
				local barX = x + Sc(170)

				draw.SimpleText(L(data.name), "nwInvBody", x, skillY,
					ColorAlpha(palette.textDim, 235 * rowReveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				util.DrawProgressBar(barX, skillY - Sc(4), barWidth, math.max(Sc(4), 3),
					math.Clamp(value / math.max(maxLevel, 1), 0, 1), theme.combine, rowReveal)

				if (need > 0) then
					surface.SetDrawColor(255, 255, 255, 14 * rowReveal)
					surface.DrawRect(barX, skillY + Sc(3), barWidth, math.max(Sc(2), 1))
					surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b,
						120 * rowReveal)
					surface.DrawRect(barX, skillY + Sc(3),
						math.Round(barWidth * math.Clamp(xp / need, 0, 1)), math.max(Sc(2), 1))
				end

				local label = value .. " / " .. maxLevel

				if (earned > 0) then
					label = label .. "  +" .. earned
				end

				draw.SimpleText(label, "nwInvSub", barX + barWidth + Sc(14), skillY - Sc(2),
					ColorAlpha(palette.textDim, 240 * rowReveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				if (need > 0) then
					draw.SimpleText(xp .. " / " .. need, "nwHudSmall", barX + barWidth + Sc(14),
						skillY + Sc(10), ColorAlpha(palette.textFaint, 200 * rowReveal),
						TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end

				skillY = skillY + Sc(26)
			end

			if (skills) then
				draw.SimpleText(L("skillHintGrow"), "nwHudSmall", x, skillY + Sc(4),
					ColorAlpha(palette.textFaint, 190 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end
	end
})

NETWORK.gui.skillIcons = {
	strength = "fitness_center",
	agility = "directions_run",
	endurance = "shield",
	intellect = "psychology",
	medicine = "healing",
	charisma = "record_voice_over",
	crafting = "construction",
	stress = "military_tech"
}

NETWORK.gui.skillColors = {
	strength = Color(226, 108, 92),
	agility = Color(96, 210, 140),
	endurance = Color(240, 186, 74),
	intellect = Color(86, 150, 226),
	medicine = Color(92, 204, 214),
	charisma = Color(180, 128, 232),
	crafting = Color(232, 156, 72),
	stress = Color(150, 172, 196)
}

function NETWORK.gui.SkillColor(id)
	return NETWORK.gui.skillColors[id] or NETWORK.theme.combine
end

function NETWORK.gui.SkillIconPath(id)
	local name = NETWORK.gui.skillIcons[id]

	return name and ("framework/icons/" .. name .. ".png") or nil
end

function NETWORK.gui.DrawSkillIcon(id, x, y, size, color)
	local path = NETWORK.gui.SkillIconPath(id)
	local material = path and NETWORK.util.GetMaterial(path, "smooth")

	if (!material or material:IsError()) then
		return false
	end

	surface.SetMaterial(material)
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	surface.DrawTexturedRect(math.Round(x), math.Round(y), size, size)

	return true
end

function NETWORK.gui.DrawSkillFrame(x, y, width, height, color, alpha, hover)
	local Sc = NETWORK.util.Scale
	local palette = NETWORK.theme.inv
	local line = math.max(Sc(1), 1)
	local thread = math.max(Sc(3), 2)

	alpha = alpha or 1
	hover = hover or 0

	surface.SetDrawColor(palette.panel.r, palette.panel.g, palette.panel.b, (198 + 22 * hover) * alpha)
	surface.DrawRect(x, y, width, height)

	if (hover > 0.01) then
		surface.SetDrawColor(color.r, color.g, color.b, 12 * hover * alpha)
		surface.DrawRect(x, y, width, height)
	end

	local edge = palette.line
	local r = edge.r + (color.r - edge.r) * hover
	local g = edge.g + (color.g - edge.g) * hover
	local b = edge.b + (color.b - edge.b) * hover

	surface.SetDrawColor(r, g, b, (150 + 90 * hover) * alpha)
	surface.DrawRect(x, y, width, line)
	surface.DrawRect(x, y + height - line, width, line)
	surface.DrawRect(x, y, line, height)
	surface.DrawRect(x + width - line, y, line, height)

	surface.SetDrawColor(color.r, color.g, color.b, (205 + 50 * hover) * alpha)
	surface.DrawRect(x, y, thread, height)
end

function NETWORK.gui.DrawSkillTicks(x, y, width, value, earned, maxLevel, color, alpha)
	local Sc = NETWORK.util.Scale
	local gap = math.max(Sc(2), 1)
	local count = math.max(maxLevel or 1, 1)
	local tickWidth = math.max(math.floor((width - gap * (count - 1)) / count), 1)
	local tickHeight = math.max(Sc(4), 3)

	alpha = alpha or 1

	for i = 1, count do
		local left = x + (i - 1) * (tickWidth + gap)
		local bFilled = i <= value
		local bEarned = bFilled and i > value - (earned or 0)

		if (bEarned) then
			surface.SetDrawColor(color.r + (255 - color.r) * 0.45, color.g + (255 - color.g) * 0.45,
				color.b + (255 - color.b) * 0.45, 240 * alpha)
		elseif (bFilled) then
			surface.SetDrawColor(color.r, color.g, color.b, 235 * alpha)
		else
			surface.SetDrawColor(255, 255, 255, 24 * alpha)
		end

		surface.DrawRect(left, y, tickWidth, tickHeight)
	end
end

function NETWORK.gui.DrawSkillXP(x, y, width, xp, need, color, alpha)
	local Sc = NETWORK.util.Scale
	local thickness = math.max(Sc(3), 2)
	local fraction = (need or 0) > 0 and math.Clamp((xp or 0) / need, 0, 1) or 1

	alpha = alpha or 1

	surface.SetDrawColor(255, 255, 255, 16 * alpha)
	surface.DrawRect(x, y, width, thickness)

	surface.SetDrawColor(color.r, color.g, color.b, ((need or 0) > 0 and 220 or 120) * alpha)
	surface.DrawRect(x, y, math.Round(width * fraction), thickness)
end

local function SkillEffectKey(id)
	return "skillEffect" .. string.upper(string.sub(id, 1, 1)) .. string.sub(id, 2)
end

function NETWORK.gui.SkillTooltip(owner, data)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local client = LocalPlayer()
	local skills = NETWORK.skills

	if (!IsValid(client) or !skills or !data) then
		return NETWORK.gui.ClearTooltip(owner)
	end

	local maxLevel = skills.maxLevel or NETWORK.creation.skillMax or 10
	local value = skills.Get(client, data.id)
	local base = skills.GetBase(client, data.id)
	local earned = skills.GetEarned(client, data.id)
	local xp = skills.GetXP(client, data.id)
	local need = value < maxLevel and skills.Need(value) or 0
	local wrapWidth = Sc(380)
	local lines = {}

	local function Append(text)
		if (!isstring(text) or text == "") then
			return
		end

		for _, line in ipairs(util.WrapText(text, "nwTipBody", wrapWidth, 4)) do
			lines[#lines + 1] = line
		end
	end

	if (data.description and NETWORK.lang.Exists(data.description)) then
		Append(L(data.description))
	end

	if (NETWORK.lang.Exists(SkillEffectKey(data.id))) then
		Append(L(SkillEffectKey(data.id)))
	end

	lines[#lines + 1] = need > 0 and L("skillXpLabel", xp, need) or L("skillMaxLabel")

	local color = NETWORK.gui.SkillColor(data.id)

	NETWORK.gui.SetTooltip(owner, {
		title = L(data.name),
		subtitle = L("skillTipLevel", value, maxLevel),
		accent = color,
		icon = NETWORK.gui.SkillIconPath(data.id),
		lines = lines,
		footer = {
			{label = L("skillTipEarned"), value = "+" .. earned, color = color},
			{label = L("skillTipBase"), value = tostring(base)}
		}
	})
end

function NETWORK.gui.DrawSkillRow(x, y, width, height, data, reveal, alpha)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local client = LocalPlayer()
	local character = client:GetCharacter()
	local skills = NETWORK.skills
	local config = NETWORK.creation
	local maxLevel = skills and skills.maxLevel or config.skillMax

	reveal = reveal or 1
	alpha = (alpha or 1) * reveal

	if (!character or alpha <= 0.01) then
		return
	end

	local value = skills and skills.Get(client, data.id) or character:GetSkill(data.id)
	local earned = skills and skills.GetEarned(client, data.id) or 0
	local xp = skills and skills.GetXP(client, data.id) or 0
	local need = (skills and value < maxLevel) and skills.Need(value) or 0
	local color = NETWORK.gui.SkillColor(data.id)
	local palette = theme.inv
	local slide = math.Round((1 - reveal) * Sc(18))
	local frameHeight = height - Sc(6)
	local middle = y + math.Round(frameHeight * 0.5)
	local thread = math.max(Sc(3), 2)
	local pad = Sc(14)

	x = x + slide
	width = width - slide

	NETWORK.gui.DrawSkillFrame(x, y, width, frameHeight, color, alpha, 0)

	local levelX = x + width - pad

	draw.SimpleText(tostring(value), "nwSkillLevel", levelX, middle - Sc(2),
		ColorAlpha(color, 250 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	surface.SetFont("nwSkillLevel")

	local levelWidth = surface.GetTextSize(tostring(value))

	draw.SimpleText("/" .. maxLevel, "nwInvKey", levelX - levelWidth - Sc(6), middle + Sc(6),
		ColorAlpha(palette.textFaint, 220 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	draw.SimpleText(util.Upper(L("skillLvlShort")), "nwInvKey", levelX - levelWidth - Sc(6),
		middle - Sc(8), ColorAlpha(palette.textFaint, 220 * alpha), TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)

	local iconSize = Sc(22)
	local textX = x + thread + pad

	if (NETWORK.gui.DrawSkillIcon(data.id, textX, middle - math.Round(iconSize * 0.5), iconSize,
		ColorAlpha(color, 235 * alpha))) then
		textX = textX + iconSize + Sc(10)
	end

	local levelBlock = levelWidth + Sc(56)
	local barWidth = math.min(Sc(120), math.Round(width * 0.18))
	local barX = levelX - levelBlock - barWidth
	local textWidth = barX - textX - Sc(16)
	local effect = L(SkillEffectKey(data.id))

	local nameWidth = util.DrawTextSpaced(util.Upper(L(data.name)), "nwLabelBold", textX,
		middle - Sc(10), ColorAlpha(theme.text, 250 * alpha), Sc(2), TEXT_ALIGN_CENTER) or 0

	if (earned > 0) then
		draw.SimpleText("+" .. earned, "nwInvKey", textX + nameWidth + Sc(8), middle - Sc(10),
			ColorAlpha(color, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	surface.SetFont("nwLabel")

	if (surface.GetTextSize(effect) > textWidth) then
		effect = util.WrapText(effect, "nwLabel", textWidth, 1)[1] or effect
	end

	draw.SimpleText(effect, "nwLabel", textX, middle + Sc(9),
		ColorAlpha(palette.textDim, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	NETWORK.gui.DrawSkillTicks(barX, middle - Sc(9), barWidth, value, earned, maxLevel, color,
		alpha)

	if (need > 0) then
		draw.SimpleText(xp .. " / " .. need, "nwHudSmall", barX + barWidth, middle + Sc(8),
			ColorAlpha(palette.textDim, 220 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	else
		draw.SimpleText(util.Upper(L("skillMaxLabel")), "nwHudSmall", barX + barWidth,
			middle + Sc(8), ColorAlpha(color, 230 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	NETWORK.gui.DrawSkillXP(x + thread, y + frameHeight - math.max(Sc(3), 2), width - thread, xp,
		need, color, alpha)
end

NETWORK.gui.skillRowHeight = 72

local function SkillSummary(client)
	local skills = NETWORK.skills
	local config = NETWORK.creation
	local maxLevel = skills and skills.maxLevel or config.skillMax
	local summary = {levels = 0, cap = #config.skills * maxLevel, earned = 0, next = nil,
		nextFraction = 0}

	for _, data in ipairs(config.skills) do
		local value = skills and skills.Get(client, data.id) or 0
		local need = (skills and value < maxLevel) and skills.Need(value) or 0

		summary.levels = summary.levels + value
		summary.earned = summary.earned + (skills and skills.GetEarned(client, data.id) or 0)

		if (need > 0) then
			local fraction = math.Clamp((skills.GetXP(client, data.id) or 0) / need, 0, 1)

			if (!summary.next or fraction > summary.nextFraction) then
				summary.next = data
				summary.nextFraction = fraction
			end
		end
	end

	return summary
end

NETWORK.gui.RegisterTab("skills", {
	name = "tabSkills",
	order = 22,
	glyph = "sliders",
	Build = function(page, menu)
		local Sc = NETWORK.util.Scale
		local width = page:GetWide()
		local height = page:GetTall()
		local client = LocalPlayer()
		local character = client:GetCharacter()

		BuildSectionLabel(page, L("tabSkills"), 0, 0, width)

		if (!character) then
			return
		end

		local bInstant = (NETWORK.gui.instantUntil or 0) > CurTime()
		local gridWidth = math.min(width, Sc(1280))
		local gap = Sc(10)
		local stripHeight = Sc(68)
		local top = Sc(44)
		local strip = page:Add("DPanel")

		strip:SetPos(0, top)
		strip:SetSize(gridWidth, stripHeight)
		strip:SetMouseInputEnabled(false)
		strip.startTime = CurTime()
		strip.Paint = function(self, panelWidth, panelHeight)
			local util = NETWORK.util
			local theme = NETWORK.theme
			local palette = theme.inv
			local reveal = bInstant and 1 or util.EaseOut(util.Stagger(self.startTime, 0.02, 0.45))

			if (reveal < 0.01 or !NETWORK.gui.DrawSkillFrame) then
				return
			end

			local pad = Sc(18)
			local x = math.Round((1 - reveal) * Sc(16))

			util.DrawBlurRect(self, x, 0, panelWidth - x, panelHeight, 3 * reveal)
			NETWORK.gui.DrawSkillFrame(x, 0, panelWidth - x, panelHeight, theme.combine, reveal, 0)

			local summary = SkillSummary(client)
			local blockWidth = math.min(Sc(170), math.floor(panelWidth * 0.16))
			local blockX = x + panelWidth - pad
			local blocks = {
				{label = L("skillsSumLevels"), value = summary.levels .. " / " .. summary.cap,
					color = theme.text},
				{label = L("skillsSumEarned"), value = "+" .. summary.earned, color = theme.combine},
				{label = L("skillsSumNext"),
					value = summary.next and (L(summary.next.name) .. "  " ..
						math.floor(summary.nextFraction * 100) .. "%") or L("skillsSumMaxed"),
					color = summary.next and NETWORK.gui.SkillColor(summary.next.id) or theme.combine}
			}

			for i = #blocks, 1, -1 do
				local block = blocks[i]

				draw.SimpleText(util.Upper(block.label), "nwInvKey", blockX, Sc(22),
					ColorAlpha(palette.textFaint, 230 * reveal), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				draw.SimpleText(block.value, "nwInvCount", blockX, Sc(44),
					ColorAlpha(block.color, 245 * reveal), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

				blockX = blockX - blockWidth

				surface.SetDrawColor(palette.line.r, palette.line.g, palette.line.b, 120 * reveal)
				surface.DrawRect(blockX + Sc(14), Sc(16), math.max(Sc(1), 1), panelHeight - Sc(32))
			end

			local textWidth = blockX - x - pad - Sc(10)

			draw.SimpleText(character:GetName(), "nwInvTitle", x + pad, Sc(22),
				ColorAlpha(theme.text, 250 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local hint = util.WrapText(L("skillsTabHint"), "nwInvSub", textWidth, 1)[1] or ""

			draw.SimpleText(hint, "nwInvSub", x + pad, Sc(46),
				ColorAlpha(palette.textDim, 225 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		local config = NETWORK.creation
		local count = #config.skills
		local columns = gridWidth >= Sc(960) and 3 or 2
		local rows = math.ceil(count / columns)
		local tileWidth = math.floor((gridWidth - gap * (columns - 1)) / columns)
		local gridY = top + stripHeight + gap
		local free = height - gridY - gap * (rows - 1)
		local tileHeight = math.Clamp(math.floor(free / math.max(rows, 1)), Sc(96), Sc(124))

		for i, data in ipairs(config.skills) do
			local column = (i - 1) % columns
			local row = math.floor((i - 1) / columns)
			local tile = page:Add("nwSkillTile")

			tile:SetPos(column * (tileWidth + gap), gridY + row * (tileHeight + gap))
			tile:SetSize(tileWidth, tileHeight)
			tile:Setup(data)
			tile:SetRevealDelay(0.08 + (row * columns + column) * 0.05)
		end
	end
})

hook.Add("NetworkSkillsUpdated", "nwTabSkills", function()
	local menu = NETWORK.gui.tabMenu

	if (IsValid(menu) and menu.activeTab == "skills") then
		NETWORK.gui.instantUntil = CurTime() + 0.2

		menu:RefreshTab(true)

		NETWORK.gui.instantUntil = 0
	end
end)

NETWORK.gui.RegisterTab("players", {
	name = "tabPlayers",
	order = 25,
	glyph = "group",
	Build = function(page, menu)
		local Sc = NETWORK.util.Scale
		local width = page:GetWide()
		local height = page:GetTall()
		local listWidth = math.min(width, Sc(1100))
		local x = math.Round((width - listWidth) * 0.5)

		local header = page:Add("DPanel")

		header:SetPos(x, 0)
		header:SetSize(listWidth, Sc(54))
		header.Paint = function(self, panelWidth, panelHeight)
			local theme = NETWORK.theme
			local online = 0

			for _, client in ipairs(player.GetAll()) do
				if (client:HasCharacter()) then
					online = online + 1
				end
			end

			draw.SimpleText(GetHostName(), "nwInvTitle", 0, Sc(16),
				ColorAlpha(theme.text, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(NETWORK.util.Upper(game.GetMap()), "nwInvSub", 0, Sc(40),
				ColorAlpha(theme.textDim, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(player.GetCount() .. " / " .. game.MaxPlayers(), "nwInvTitle",
				panelWidth, Sc(16), ColorAlpha(theme.combine, 250), TEXT_ALIGN_RIGHT,
				TEXT_ALIGN_CENTER)

			draw.SimpleText(NETWORK.util.Upper(L("playersInGame", online)), "nwInvSub",
				panelWidth, Sc(40), ColorAlpha(theme.textDim, 230), TEXT_ALIGN_RIGHT,
				TEXT_ALIGN_CENTER)
		end

		local board = page:Add("nwScoreboard")

		board:SetPos(x, Sc(70))
		board:SetSize(listWidth, height - Sc(70))
	end
})

NETWORK.gui.RegisterTab("settings", {
	name = "tabSettings",
	order = 30,
	glyph = "gear",
	Build = function(page, menu)
		local list = page:Add("nwSettingsList")

		list:Dock(FILL)

		local entries = {}

		for _, data in ipairs(NETWORK.option.GetEntries()) do

			if (isfunction(data.IsHidden) and data.IsHidden()) then
				continue
			end

			entries[#entries + 1] = {
				id = data.id,
				name = data.name,
				description = data.description,
				category = data.category,
				type = data.type,
				min = data.min,
				max = data.max,
				decimals = data.decimals,
				options = data.options,
				get = function()
					return NETWORK.option.Get(data.id)
				end,
				set = function(value)
					NETWORK.option.Set(data.id, value)
				end
			}
		end

		list:SetSource(NETWORK.option.GetCategories(), entries)
	end
})

NETWORK.gui.RegisterTab("config", {
	name = "tabConfig",
	order = 40,
	glyph = "sliders",
	access = function()
		return IsValid(LocalPlayer()) and LocalPlayer():IsAdmin()
	end,
	Build = function(page, menu)
		local list = page:Add("nwSettingsList")

		list:Dock(FILL)

		local bReadOnly = !LocalPlayer():IsSuperAdmin()
		local entries = {}

		for _, data in ipairs(NETWORK.config.GetEntries()) do
			entries[#entries + 1] = {
				id = data.id,
				name = data.name,
				description = data.description,
				category = data.category,
				type = data.type,
				min = data.min,
				max = data.max,
				decimals = data.decimals,
				options = data.options,
				readOnly = bReadOnly,
				get = function()
					return NETWORK.config.Get(data.id)
				end,
				set = function(value)
					NETWORK.config.Request(data.id, value)
				end
			}
		end

		list.presetsButton:SetVisible(false)
		list:SetSource(NETWORK.config.GetCategories(), entries)
	end
})

hook.Add("NetworkInventoryUpdated", "nwTabInventory", function()
	local menu = NETWORK.gui.tabMenu

	if (IsValid(menu) and menu.activeTab == "inventory") then
		NETWORK.gui.instantUntil = CurTime() + 0.2

		menu:RefreshTab(true)

		NETWORK.gui.instantUntil = 0
	end
end)
