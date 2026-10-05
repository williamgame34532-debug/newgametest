local P = NETWORK.pmenu

local function DrawPulseGlyph(x, y, size, color)
	local Sc = NETWORK.util.Scale
	local thick = math.max(Sc(2), 2)
	local middle = y + size * 0.55
	local points = {
		{0, 0}, {0.28, 0}, {0.38, -0.35}, {0.5, 0.4}, {0.6, -0.15}, {0.7, 0}, {1, 0}
	}

	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]

		NETWORK.util.DrawThickLine(x + a[1] * size, middle + a[2] * size,
			x + b[1] * size, middle + b[2] * size, thick, color)
	end
end

local function DrawGlyph(glyph, x, y, size, color)
	if (glyph == "pulse") then
		return DrawPulseGlyph(x, y, size, color)
	end

	if (glyph == "number") then
		return
	end

	NETWORK.gui.DrawGlyph(glyph, x, y, size, color)
end

local function DrawIconFile(path, x, y, size, color, fallback)
	local material = NETWORK.util.GetMaterial(path, "smooth")

	if ((!material or material:IsError()) and fallback) then
		material = NETWORK.util.GetMaterial(fallback, "smooth")
	end

	if (!material or material:IsError()) then
		return false
	end

	surface.SetMaterial(material)
	surface.SetDrawColor(0, 0, 0, (color.a or 255) * 0.5)
	surface.DrawTexturedRect(x + 1, y + 1, size, size)
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	surface.DrawTexturedRect(x, y, size, size)

	return true
end

local SECTIONS = {
	{id = "talk", name = "pmSectionTalk",
		items = {"tokens", "recognise", "documents", "lendkey"}},
	{id = "service", name = "pmSectionService",
		items = {"search", "treat", "pulse", "lead", "release", "untie", "bodybag"}}
}

local PANEL = {}

PANEL.rowHeight = 26
PANEL.width = 240
PANEL.subWidth = 168

function PANEL:Init()
	NETWORK.gui.playerMenu = self

	self.alpha = 0
	self.born = RealTime()
	self.switched = RealTime()
	self.mode = "root"
	self.hovered = nil
	self.hover = {}
	self.rects = {}
	self.bMoved = false
	self.bClosing = false
	self.useKey = input.GetKeyCode(input.LookupBinding("+use") or "e")
	self.bUseDown = input.IsKeyDown(self.useKey)

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetKeyboardInputEnabled(true)

	local Sc = NETWORK.util.Scale

	self.cardX = math.Round(ScrW() * 0.5 - Sc(PANEL.width) * 0.5)
	self.cardY = math.Round(ScrH() * 0.5 - Sc(60))

	input.SetCursorPos(self.cardX + Sc(40), self.cardY + Sc(90))

	surface.PlaySound("ui/buttonrollover.wav")
end

function PANEL:Setup(target, kind, options)
	self.target = target
	self.kind = kind
	self.options = options or {}
end

function PANEL:OnRemove()
	if (NETWORK.gui.playerMenu == self) then
		NETWORK.gui.playerMenu = nil
	end
end

function PANEL:GetDocuments()
	local list = {}
	local items = NETWORK.inventory.state and NETWORK.inventory.state.items or {}

	for index, item in pairs(items) do
		if (P.IsDocument(item)) then
			list[#list + 1] = {index = index, item = item}
		end
	end

	table.sort(list, function(a, b)
		return a.index < b.index
	end)

	return list
end

function PANEL:GetSubItems()
	local items = {}

	if (self.mode == "tokens") then
		for _, amount in ipairs(P.tokenQuick) do
			items[#items + 1] = {
				id = "amount",
				amount = amount,
				label = NETWORK.currency.Format(amount),
				glyph = "coin",
				icon = "framework/interact/coins.png",
				iconOld = "framework/icons/paid.png",
				bSub = true,
				bDisabled = LocalPlayer():GetTokens() < amount
			}
		end

		items[#items + 1] = {id = "custom", label = L("pmTokensCustom"), glyph = "sliders",
			icon = "framework/interact/pencil.png", iconOld = "framework/icons/edit.png",
			bSub = true}
	elseif (self.mode == "documents") then
		for index, entry in ipairs(self:GetDocuments()) do
			if (index > 8) then
				break
			end

			items[#items + 1] = {
				id = "document",
				index = entry.index,
				label = NETWORK.item.GetName(entry.item),
				glyph = "list",
				icon = "framework/interact/id_card.png",
				iconOld = "framework/icons/assignment.png",
				bSub = true
			}
		end

		if (#items == 0) then
			items[1] = {id = "none", label = L("pmNoDocuments"), glyph = "list",
				icon = "framework/interact/id_card.png",
				iconOld = "framework/icons/assignment.png", bSub = true, bDisabled = true}
		end
	elseif (self.mode == "lendkey") then

		local client = LocalPlayer()

		for _, entry in ipairs(NETWORK.door.GetOwned(client:SteamID64())) do
			if (#items >= 8) then
				break
			end

			if (!NETWORK.door.CanLend(entry.data)) then
				continue
			end

			items[#items + 1] = {
				id = "lenddoor",
				key = entry.key,
				label = NETWORK.door.GetTitle(entry.data) .. "  ·  " ..
					L("doorLendMinutes", P.lendMinutes),
				glyph = "split",
				icon = entry.data.type == "business" and "framework/interact/shop.png" or
					"framework/interact/house.png",
				iconOld = entry.data.type == "business" and "framework/icons/storefront.png" or
					"framework/icons/home.png",
				bSub = true
			}
		end

		if (#items == 0) then
			items[1] = {id = "none", label = L("keysNoDoors"), glyph = "split",
				icon = "framework/interact/key.png", iconOld = "framework/icons/key.png",
				bSub = true, bDisabled = true}
		end
	end

	for number, item in ipairs(items) do
		item.number = number
	end

	return items
end

function PANEL:GetSections()
	local sections = {}
	local number = 0

	local function Add(section, item)
		number = number + 1
		item.number = number
		section.items[#section.items + 1] = item
	end

	local available = {}

	for _, id in ipairs(self.options or {}) do
		available[id] = true
	end

	for _, data in ipairs(SECTIONS) do
		local section = {name = L(data.name), items = {}}

		for _, id in ipairs(data.items) do
			local option = P.options[id]

			if (available[id] and option) then
				Add(section, {id = id, label = L(option.label), glyph = option.glyph,
					icon = option.icon, iconOld = option.iconOld, hint = L(option.label .. "Hint"),
					bOpen = (id == "tokens" or id == "documents" or id == "lendkey") and
						self.mode == id})
			end
		end

		if (#section.items > 0) then
			sections[#sections + 1] = section
		end
	end

	return sections
end

function PANEL:GetItems()
	local items = {}

	if (self.mode != "root") then
		return self:GetSubItems()
	end

	for _, section in ipairs(self:GetSections()) do
		for _, item in ipairs(section.items) do
			items[#items + 1] = item
		end
	end

	return items
end

function PANEL:Layout()
	local Sc = NETWORK.util.Scale
	local rowHeight = Sc(PANEL.rowHeight)
	local sections = self:GetSections()
	local rects = {}
	local y = self.cardY + Sc(58)

	for _, section in ipairs(sections) do
		section.y = y
		y = y + Sc(22)

		for _, item in ipairs(section.items) do
			rects[#rects + 1] = {x = self.cardX + Sc(6), y = y,
				width = Sc(PANEL.width) - Sc(12), height = rowHeight, item = item}

			y = y + rowHeight
		end

		y = y + Sc(8)
	end

	if (IsValid(self.entry)) then
		y = y + Sc(40)
	end

	self.sections = sections
	self.cardHeight = y - self.cardY + Sc(6)

	self.subRect = nil

	if (self.mode != "root") then
		local anchorY = self.cardY + Sc(58)

		for _, rect in ipairs(rects) do
			if (rect.item.id == self.mode) then
				anchorY = rect.y

				break
			end
		end

		local items = self:GetSubItems()
		local subX = self.cardX + Sc(PANEL.width) + Sc(10)
		local subWidth = Sc(PANEL.subWidth)
		local subHeight = Sc(30)
		local subY = anchorY

		for _, item in ipairs(items) do
			rects[#rects + 1] = {x = subX, y = subY, width = subWidth, height = subHeight,
				item = item, bSub = true}

			subY = subY + subHeight + Sc(4)
		end

		self.subRect = {x = subX, y = anchorY, width = subWidth, height = subY - anchorY}
	end

	self.rects = rects

	return rects
end

function PANEL:SetMode(mode)
	self.mode = mode
	self.switched = RealTime()
	self.hovered = nil
	self.hover = {}

	if (IsValid(self.entry)) then
		self.entry:Remove()
	end

	surface.PlaySound("buttons/lightswitch2.wav")
end

function PANEL:Send(action, argument)
	if (!IsValid(self.target)) then
		return
	end

	net.Start("nwPMenuAction")
		net.WriteString(action)
		net.WriteEntity(self.target)
		net.WriteString(argument or "")
	net.SendToServer()
end

function PANEL:OpenAmountEntry()
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme

	if (IsValid(self.entry)) then
		self.entry:Remove()
	end

	local entry = self:Add("DTextEntry")

	entry:SetSize(Sc(PANEL.width) - Sc(24), Sc(30))
	entry:SetFont("nwInvBody")
	entry:SetNumeric(true)
	entry:SetUpdateOnType(true)
	entry:SetPaintBackground(false)
	entry:SetDrawLanguageID(false)
	entry:SetTextColor(theme.text)
	entry:SetCursorColor(theme.combine)
	entry:SetTextInset(Sc(10), 0)
	entry:SetPlaceholderText("0")
	entry.OnEnter = function(panel)
		local amount = math.floor(tonumber(panel:GetValue()) or 0)

		if (amount <= 0) then
			surface.PlaySound("buttons/button10.wav")

			return
		end

		self:Send("tokens", tostring(amount))
		self:Close()
	end
	entry.Paint = function(panel, width, height)

		surface.SetDrawColor(10, 11, 13, 230)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(panel:IsEditing() and ColorAlpha(theme.combine, 210) or
			Color(255, 255, 255, 30))
		surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(1), 1))

		panel:DrawTextEntryText(theme.text, theme.combineDeep, theme.combine)
	end

	entry:RequestFocus()

	self.entry = entry
end

function PANEL:Activate(item)
	if (!item or self.bClosing) then
		return
	end

	if (item.bDisabled) then
		surface.PlaySound("buttons/button10.wav")

		return
	end

	if (item.id == "back") then
		return self:SetMode("root")
	end

	if (item.bSub) then
		if (item.id == "custom") then
			surface.PlaySound("buttons/lightswitch2.wav")

			return self:OpenAmountEntry()
		end

		if (item.id == "amount") then
			self:Send("tokens", tostring(item.amount))

			return self:Close(true)
		end

		if (item.id == "document") then
			self:Send("documents", tostring(item.index))

			return self:Close(true)
		end

		if (item.id == "lenddoor") then

			self:Send("lendkey", item.key .. "|" .. tostring(P.lendMinutes))

			return self:Close(true)
		end

		return
	end

	if (item.id == "tokens" or item.id == "documents" or item.id == "lendkey") then
		return self:SetMode(self.mode == item.id and "root" or item.id)
	end

	if (item.id == "bodybag") then

		local target = self.target

		if (IsValid(target) and target:IsPlayer()) then
			local ragdoll = target:GetNWEntity("nwRagdollEntity", NULL)

			if (IsValid(ragdoll)) then
				target = ragdoll
			end
		end

		net.Start("nwBodybagPack")
			net.WriteEntity(target)
		net.SendToServer()

		return self:Close(true)
	end

	self:Send(item.id)
	self:Close(true)
end

function PANEL:Close(bChosen)
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	if (bChosen) then
		surface.PlaySound("buttons/button15.wav")
	end

	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

function PANEL:Back()
	if (IsValid(self.entry)) then
		self.entry:Remove()

		return
	end

	if (self.mode != "root") then
		return self:SetMode("root")
	end

	self:Close()
end

function PANEL:IsTargetValid()
	local target = self.target
	local client = LocalPlayer()

	if (!IsValid(target) or !IsValid(client) or !client:Alive()) then
		return false
	end

	if (self.kind == "player" and (!target:Alive() or !target:HasCharacter())) then
		return false
	end

	local position = target:GetPos()

	if (self.kind == "player" and target:IsDowned()) then
		position = target:GetNWEntity("nwRagdollEntity"):GetPos()
	end

	return client:GetPos():Distance(position) <= P.range + 90
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1,
		self.bClosing and 16 or 12)

	if (self.bClosing) then
		if (self.alpha < 0.02) then
			self:Remove()
		end

		return
	end

	if (!self:IsTargetValid()) then
		return self:Close()
	end

	local rects = self:Layout()
	local mouseX, mouseY = gui.MousePos()

	if (math.abs(mouseX - (self.lastMouseX or mouseX)) > 2 or
		math.abs(mouseY - (self.lastMouseY or mouseY)) > 2) then
		self.bMoved = true
	end

	self.lastMouseX = mouseX
	self.lastMouseY = mouseY
	self.hovered = nil

	if (!IsValid(self.entry)) then
		for index, rect in ipairs(rects) do
			if (mouseX >= rect.x and mouseX <= rect.x + rect.width and
				mouseY >= rect.y and mouseY <= rect.y + rect.height) then
				self.hovered = index

				break
			end
		end
	end

	if (self.hovered != self.lastHovered) then
		self.lastHovered = self.hovered

		if (self.hovered) then
			surface.PlaySound("ui/buttonrollover.wav")
		end
	end

	for index = 1, #rects do
		self.hover[index] = NETWORK.util.Approach(self.hover[index] or 0,
			index == self.hovered and 1 or 0, 16)
	end

	if (IsValid(self.entry)) then
		local Sc = NETWORK.util.Scale

		self.entry:SetPos(self.cardX + Sc(12), self.cardY + self.cardHeight - Sc(44))
	end

	local bDown = input.IsKeyDown(self.useKey)

	if (self.bUseDown and !bDown) then
		self.bUseDown = false

		if (self.bMoved and self.hovered and !IsValid(self.entry)) then
			self:Activate(rects[self.hovered].item)
		end
	end
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_RIGHT) then
		return self:Back()
	end

	if (code != MOUSE_LEFT) then
		return
	end

	if (!self.hovered) then
		local mouseX, mouseY = gui.MousePos()
		local Sc = NETWORK.util.Scale

		local sub = self.subRect
		local bInSub = sub and mouseX >= sub.x and mouseX <= sub.x + sub.width and
			mouseY >= sub.y and mouseY <= sub.y + sub.height

		if (!IsValid(self.entry) and !bInSub and (mouseX < self.cardX or
			mouseX > self.cardX + Sc(PANEL.width) or mouseY < self.cardY or
			mouseY > self.cardY + (self.cardHeight or 0))) then
			self:Close()
		end

		return
	end

	local rect = self.rects[self.hovered]

	if (rect) then
		self:Activate(rect.item)
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		return self:Back()
	end

	if (key >= KEY_1 and key <= KEY_9 and !IsValid(self.entry)) then
		local item = self:GetItems()[key - KEY_1 + 1]

		if (item) then
			self:Activate(item)
		end
	end
end

function PANEL:GetStatus()
	local theme = NETWORK.theme
	local target = self.target

	if (IsValid(target) and target:IsPlayer() and NETWORK.restraint and
		NETWORK.restraint.IsTied and NETWORK.restraint.IsTied(target)) then
		return L("pmStatusTied"), theme.warning
	end

	return "", theme.combine
end

function PANEL:GetStatusOld()
	local theme = NETWORK.theme
	local target = self.target

	if (self.kind == "corpse") then
		return L("pmStatusDead"), theme.danger
	end

	if (target:IsCritical()) then
		return L("pmStatusCritical"), theme.danger
	end

	if (target:IsUnconscious() or target:IsDowned()) then
		return L("pmStatusDown"), theme.warning
	end

	if (NETWORK.restraint.IsTied(target)) then
		return L("pmStatusTied"), theme.warning
	end

	return L("pmStatusAwake"), theme.positive
end

function PANEL:GetName()
	local target = self.target

	if (self.kind == "corpse") then
		local owner = target:GetNWEntity("nwCorpseOwner", NULL)
		local name = target:GetNWString("nwCorpseName", "")

		if (IsValid(owner) and owner:IsPlayer() and !LocalPlayer():IsRecognised(owner)) then
			return L("pmUnknownBody")
		end

		return name != "" and name or L("pmUnknownBody")
	end

	return target:GetRecognisedName()
end

function PANEL:GetSubline()
	local parts = {}
	local target = self.target

	if (self.kind == "player" and target.GetCharacterFaction) then
		local faction = target:GetCharacterFaction()

		if (faction) then
			parts[#parts + 1] = NETWORK.factions.GetName(faction)
		end
	end

	local status = self:GetStatus()

	parts[#parts + 1] = status

	local client = LocalPlayer()

	if (IsValid(client) and IsValid(target)) then
		local metres = math.max(math.Round(client:GetPos():Distance(target:GetPos()) / 40), 1)

		parts[#parts + 1] = L("pmDistance", metres)
	end

	return table.concat(parts, "  ·  ")
end

function PANEL:PaintKey(number, rightX, rowY, rowHeight, hover, reveal)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local box = Sc(14)
	local keyX = rightX - box
	local keyY = rowY + math.Round((rowHeight - box) * 0.5)

	surface.SetDrawColor(255, 255, 255, (30 + 60 * hover) * reveal)
	surface.DrawOutlinedRect(keyX, keyY, box, box, math.max(Sc(1), 1))

	draw.SimpleText(tostring(number), "nwInvKey", keyX + math.Round(box * 0.5),
		keyY + math.Round(box * 0.5), ColorAlpha(theme.textFaint, (150 + 80 * hover) * reveal),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:Paint(width, height)
	if (!IsValid(self.target)) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local alpha = self.alpha
	local rects = self.rects or self:Layout()
	local cardX, cardY = self.cardX, self.cardY
	local cardWidth = Sc(PANEL.width)
	local cardHeight = self.cardHeight or Sc(120)
	local line = math.max(Sc(1), 1)
	local appear = util.EaseOut(math.Clamp((RealTime() - self.born) / 0.22, 0, 1))
	local modeReveal = util.EaseOut(math.Clamp((RealTime() - self.switched) / 0.18, 0, 1))
	local lift = math.Round((1 - appear) * Sc(8))

	cardY = cardY + lift

	surface.SetDrawColor(0, 0, 0, 60 * alpha)
	surface.DrawRect(0, 0, width, height)

	local status, statusColor = self:GetStatus()

	util.DrawBlurRect(self, cardX, cardY, cardWidth, cardHeight, 4 * alpha)

	surface.SetDrawColor(0, 0, 0, 215 * alpha)
	surface.DrawRect(cardX, cardY, cardWidth, cardHeight)

	surface.SetDrawColor(statusColor.r, statusColor.g, statusColor.b, 140 * alpha)
	surface.DrawOutlinedRect(cardX, cardY, cardWidth, cardHeight, line)

	surface.SetDrawColor(statusColor.r, statusColor.g, statusColor.b, 240 * alpha)
	surface.DrawRect(cardX, cardY, cardWidth, math.max(Sc(2), 2))

	local name = util.TruncateWidth(self:GetName(), "nwInvName", cardWidth - Sc(28))

	surface.SetDrawColor(statusColor.r, statusColor.g, statusColor.b, 230 * alpha)
	surface.DrawRect(cardX + Sc(6), cardY + Sc(14), math.max(Sc(3), 2), Sc(30))

	draw.SimpleText(name, "nwInvName", cardX + Sc(16), cardY + Sc(20),
		ColorAlpha(theme.text, 252 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(util.TruncateWidth(self:GetSubline(), "nwInvKey", cardWidth - Sc(28)),
		"nwInvKey", cardX + Sc(16), cardY + Sc(38), ColorAlpha(theme.textFaint, 235 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 14 * alpha)
	surface.DrawRect(cardX + Sc(12), cardY + Sc(52), cardWidth - Sc(24), line)

	for _, section in ipairs(self.sections or {}) do
		local sectionText = util.Upper(section.name)
		local sectionY = section.y + lift + Sc(11)

		surface.SetFont("nwInvKey")

		local sectionWidth = surface.GetTextSize(sectionText)
		local ruleX = cardX + Sc(16) + sectionWidth + Sc(8)

		draw.SimpleText(sectionText, "nwInvKey", cardX + Sc(16), sectionY,
			ColorAlpha(theme.textFaint, 200 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(255, 255, 255, 14 * alpha)
		surface.DrawRect(ruleX, sectionY, math.max(cardX + cardWidth - Sc(12) - ruleX, 0), line)
	end

	for index, rect in ipairs(rects) do
		local item = rect.item
		local hover = util.EaseInOut(self.hover[index] or 0)
		local rowY = rect.y + lift
		local reveal = rect.bSub and alpha * modeReveal or alpha

		if (rect.bSub) then

			local slide = math.Round((1 - modeReveal) * Sc(10))
			local bx = rect.x - slide
			local tint = theme.combine
			local fillAlpha = item.bDisabled and 120 or 220

			surface.SetDrawColor(10, 11, 13, fillAlpha * reveal)
			surface.DrawRect(bx, rowY, rect.width, rect.height)

			if (hover > 0.01 and !item.bDisabled) then
				surface.SetDrawColor(tint.r, tint.g, tint.b, 30 * hover * reveal)
				surface.DrawRect(bx, rowY, rect.width, rect.height)
			end

			surface.SetDrawColor(hover > 0.01 and !item.bDisabled and
				ColorAlpha(tint, (60 + 170 * hover) * reveal) or Color(255, 255, 255, 30 * reveal))
			surface.DrawOutlinedRect(bx, rowY, rect.width, rect.height, line)

			local subColor = item.bDisabled and ColorAlpha(theme.textFaint, 150 * reveal) or
				ColorAlpha(hover > 0.5 and tint or theme.textDim, 240 * reveal)
			local subIcon = Sc(14)

			if (!(item.icon and DrawIconFile(item.icon, bx + Sc(8),
				rowY + math.Round((rect.height - subIcon) * 0.5), subIcon, subColor,
				item.iconOld))) then
				local subGlyph = Sc(13)

				DrawGlyph(item.glyph or "dot", bx + Sc(9),
					rowY + math.Round((rect.height - subGlyph) * 0.5), subGlyph, subColor)
			end

			draw.SimpleText(util.TruncateWidth(item.label, "nwInvBody", rect.width - Sc(52)),
				"nwInvBody", bx + Sc(28), rowY + math.Round(rect.height * 0.5),
				item.bDisabled and ColorAlpha(theme.textFaint, 170 * reveal) or
				ColorAlpha(hover > 0.5 and theme.text or theme.textDim, 250 * reveal),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if (item.number and item.number <= 9) then
				self:PaintKey(item.number, bx + rect.width - Sc(6), rowY, rect.height, hover,
					reveal)
			end

			continue
		end

		if (item.bOpen) then

			surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b, 22 * alpha)
			surface.DrawRect(rect.x, rowY, rect.width, rect.height)
			surface.SetDrawColor(ColorAlpha(theme.combine, 200 * alpha))
			surface.DrawRect(rect.x + rect.width, rowY + math.Round(rect.height * 0.5) - 1,
				Sc(10), line)
		end

		if (hover > 0.01 and !item.bDisabled) then
			surface.SetDrawColor(255, 255, 255, 14 * hover * reveal)
			surface.DrawRect(rect.x, rowY, rect.width, rect.height)

			surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b,
				240 * hover * reveal)
			surface.DrawRect(rect.x, rowY, math.max(Sc(2), 2), rect.height)
		end

		local glyphColor = item.bDisabled and ColorAlpha(theme.textFaint, 160 * reveal) or
			ColorAlpha(Color(
				Lerp(hover, theme.textDim.r, theme.combine.r),
				Lerp(hover, theme.textDim.g, theme.combine.g),
				Lerp(hover, theme.textDim.b, theme.combine.b)), 245 * reveal)
		local iconSize = Sc(16)

		if (!(item.icon and DrawIconFile(item.icon, rect.x + Sc(9),
			rowY + math.Round((rect.height - iconSize) * 0.5), iconSize, glyphColor,
			item.iconOld))) then
			local glyphSize = Sc(14)

			DrawGlyph(item.glyph or "dot", rect.x + Sc(10),
				rowY + math.Round((rect.height - glyphSize) * 0.5), glyphSize, glyphColor)
		end

		local labelColor = item.bDisabled and ColorAlpha(theme.textFaint, 180 * reveal) or
			ColorAlpha(Color(
				Lerp(hover, theme.textDim.r, theme.text.r),
				Lerp(hover, theme.textDim.g, theme.text.g),
				Lerp(hover, theme.textDim.b, theme.text.b)), 250 * reveal)

		draw.SimpleText(util.TruncateWidth(item.label, "nwInvBody", rect.width - Sc(70)),
			"nwInvBody", rect.x + Sc(32), rowY + math.Round(rect.height * 0.5), labelColor,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (item.number and item.number <= 9) then
			self:PaintKey(item.number, rect.x + rect.width - Sc(8), rowY, rect.height, hover,
				reveal)
		end
	end

	if (IsValid(self.entry)) then
		draw.SimpleText(L("pmTokensHave", NETWORK.currency.Format(LocalPlayer():GetTokens())),
			"nwInvKey", cardX + Sc(16), cardY + cardHeight - Sc(54),
			ColorAlpha(theme.textFaint, 220 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local hovered = self.hovered and rects[self.hovered] and rects[self.hovered].item
	local footer = hovered and hovered.hint and !string.find(hovered.hint, "Hint$") and
		hovered.hint or L("pmFooter")

	util.DrawSimpleTextShadow(footer, "nwHudSmall", cardX, cardY + cardHeight + Sc(14),
		ColorAlpha(theme.textDim, 210 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER,
		math.max(Sc(1), 1))
end

vgui.Register("nwPlayerMenu", PANEL, "EditablePanel")

net.Receive("nwPMenuOpen", function()
	local target = net.ReadEntity()
	local kind = net.ReadString()
	local options = NETWORK.util.ReadTable()

	if (!IsValid(target)) then
		return
	end

	if (IsValid(NETWORK.gui.playerMenu)) then
		NETWORK.gui.playerMenu:Remove()
	end

	if (NETWORK.gui.IsWindowOpen and NETWORK.gui.IsWindowOpen()) then
		return
	end

	vgui.Create("nwPlayerMenu"):Setup(target, kind, options)
end)

local intro

net.Receive("nwPMenuIntro", function()
	intro = {
		entity = net.ReadEntity(),
		name = net.ReadString(),
		time = RealTime()
	}

	surface.PlaySound("buttons/blip1.wav")
end)

local function ReplyIntro(bAccept)
	intro = nil

	net.Start("nwPMenuIntroReply")
		net.WriteBool(bAccept)
	net.SendToServer()
end

hook.Add("Think", "nwPlayerMenuIntro", function()
	if (!intro) then
		return
	end

	if (RealTime() - intro.time > P.introTime) then
		intro = nil

		return
	end

	if (NETWORK.prompt.IsBlocked() or IsValid(NETWORK.gui.playerMenu)) then
		return
	end

	if (NETWORK.prompt.AcceptDown()) then
		ReplyIntro(true)
	elseif (NETWORK.prompt.DeclineDown()) then
		ReplyIntro(false)
	end
end)

hook.Add("HUDPaint", "nwPlayerMenuIntro", function()
	if (!intro or NETWORK.hud.IsHidden()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local age = RealTime() - intro.time
	local alpha = math.Clamp(age / 0.25, 0, 1) *
		math.Clamp((P.introTime - age) / 0.5, 0, 1)
	local title = L("pmIntroTitle", intro.name)
	local hint = L("pmIntroHint", NETWORK.prompt.AcceptLabel(),
		NETWORK.prompt.DeclineLabel())

	surface.SetFont("nwField")

	local titleWidth = surface.GetTextSize(title)

	surface.SetFont("nwHudSmall")

	local hintWidth = surface.GetTextSize(hint)
	local width = math.max(titleWidth, hintWidth) + Sc(40)
	local height = Sc(62)
	local x = math.Round((ScrW() - width) * 0.5)
	local y = math.Round(ScrH() * 0.68) + math.Round((1 - alpha) * Sc(10))

	NETWORK.util.DrawBlurScreen(x, y, width, height, 4 * alpha)

	draw.RoundedBox(math.max(Sc(8), 4), x, y, width, height, Color(8, 9, 11, 220 * alpha))
	draw.RoundedBox(math.max(Sc(3), 2), x, y + Sc(12), math.max(Sc(3), 2),
		height - Sc(24), ColorAlpha(theme.combine, 240 * alpha))

	draw.SimpleText(title, "nwField", x + Sc(20), y + Sc(20),
		ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(hint, "nwHudSmall", x + Sc(20), y + Sc(42),
		ColorAlpha(theme.textDim, 240 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local fraction = 1 - math.Clamp(age / P.introTime, 0, 1)

	surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b, 160 * alpha)
	surface.DrawRect(x + Sc(12), y + height - 2, math.Round((width - Sc(24)) * fraction), 2)
end)
