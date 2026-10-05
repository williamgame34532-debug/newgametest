local PANEL = {}

PANEL.holdTime = 16
PANEL.fadeTime = 2
PANEL.maxMessages = 150

local dataPath = "network/chat.txt"

local function DrawIconFile(path, x, y, size, color)
	local material = NETWORK.util.GetMaterial(path, "smooth")

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

local STAMP_FONT = "nwHudSmall"
local FREQ_FONT = "nwInvKey"
local AMBER = Color(240, 186, 74)

local PLATE_FILL = Color(10, 12, 15, 238)
local CARD_FILL = Color(12, 15, 19, 242)

local scratch = Color(0, 0, 0, 0)

local function RoundBox(radius, x, y, width, height, r, g, b, a)
	if (width < 1 or height < 1 or a <= 0) then
		return
	end

	radius = math.max(math.min(radius, math.floor(math.min(width, height) * 0.5)), 0)

	scratch.r, scratch.g, scratch.b, scratch.a = r, g, b, math.min(a, 255)

	draw.RoundedBox(radius, math.Round(x), math.Round(y), math.Round(width), math.Round(height),
		scratch)
end

local function Pill(x, y, width, height, r, g, b, a)
	RoundBox(math.floor(math.min(width, height) * 0.5), x, y, width, height, r, g, b, a)
end

local function RoundBorder(radius, x, y, width, height, r, g, b, a)
	if (width < 2 or height < 2 or a <= 0) then
		return
	end

	radius = math.min(radius, math.floor(math.min(width, height) * 0.5))

	NETWORK.util.DrawRoundedBorder(math.Round(x), math.Round(y), math.Round(width),
		math.Round(height), radius, 1, Color(r, g, b, a))
end

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.chat = self

	print("[Network] Чат: сборка " .. tostring(NETWORK.buildTag or "?"))

	self.messages = {}

	self.tabs = {
		{id = "all", name = "chatTabAll"}
	}
	self.tab = "all"
	self.tabReveal = {}

	self:LoadTabs()

	if (!NETWORK.chat.history or #NETWORK.chat.history == 0) then
		local saved = util.JSONToTable(file.Read("network/chathistory.txt", "DATA") or "")

		NETWORK.chat.history = istable(saved) and saved or {}
	end

	self.history = NETWORK.chat.history
	self.historyIndex = 0
	self.bActive = false
	self.alpha = 0
	self.scroll = 0
	self.total = 0

	self.padding = Sc(12)
	self.headerHeight = Sc(26)
	self.inputHeight = Sc(32)
	self.grip = Sc(16)
	self.minWidth = Sc(340)
	self.minHeight = Sc(180)

	self:SetSize(math.min(Sc(560), math.Round(ScrW() * 0.42)),
		math.min(Sc(300), math.Round(ScrH() * 0.45)))
	self:SetPos(Sc(28), ScrH() - Sc(150) - self:GetTall())

	self.channelLabel = self:Add("DPanel")
	self.channelLabel:SetVisible(false)

	self.channelLabel.Paint = function(panel, width, height)
		local color = self.labelColor or NETWORK.theme.text
		local inset = Sc(6)
		local alpha = self.alpha or 1
		local boxHeight = height - inset * 2
		local radius = math.floor(boxHeight * 0.5)

		RoundBox(radius, 0, inset, width, boxHeight, color.r, color.g, color.b, 40 * alpha)
		RoundBorder(radius, 0, inset, width, boxHeight, color.r, color.g, color.b, 150 * alpha)

		draw.SimpleText(self.labelText or "", "nwInvKey", math.Round(width * 0.5),
			math.Round(height * 0.5), ColorAlpha(color, 250 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	self.entry = self:Add("DTextEntry")
	self.entry:SetFont("nwChat")
	self.entry:SetDrawLanguageID(false)
	self.entry:SetPaintBackground(false)
	self.entry:SetTextColor(NETWORK.theme.text)
	self.entry:SetCursorColor(NETWORK.theme.combine)
	self.entry:SetHighlightColor(NETWORK.theme.combineDeep)
	self.entry:SetVisible(false)

	self.entry:SetTextInset(Sc(10), 0)
	self.entry.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local value = panel:GetValue()
		local alpha = self.alpha or 1

		local bIcon = false

		if (value == "") then
			local icon = Sc(14)

			bIcon = DrawIconFile("framework/icons/keyboard.png", Sc(6),
				math.Round((height - icon) * 0.5), icon,
				ColorAlpha(theme.textFaint, 200 * alpha))

			draw.SimpleText(L("chatPlaceholder"), "nwChat", bIcon and Sc(24) or Sc(10),
				math.Round(height * 0.5), ColorAlpha(theme.textFaint, 190 * alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		local inset = bIcon and Sc(24) or Sc(10)

		if (panel.nwInset != inset) then
			panel.nwInset = inset
			panel:SetTextInset(inset, 0)
		end

		local length = utf8.len(value) or #value
		local limit = NETWORK.chat.maxLength
		local centerY = math.Round(height * 0.5)
		local right = width - Sc(10)

		if (length > 0) then
			local counterColor = length > limit and theme.danger or
				(length > limit * 0.85 and theme.warning or theme.textFaint)
			local counter = length .. " / " .. limit

			draw.SimpleText(counter, STAMP_FONT, right, centerY, ColorAlpha(counterColor, 220 * alpha),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			surface.SetFont(STAMP_FONT)
			right = right - surface.GetTextSize(counter) - Sc(12)
		end

		local history = L("chatHintHistoryShort")

		if (history == "chatHintHistoryShort") then
			history = L("chatHintHistory")
		end

		local parts = {"Tab", " — " .. L("chatHintChannel") .. "  ·  ", "↑", " — " .. history}

		surface.SetFont("nwChatStamp")

		local widths, total = {}, 0

		for index = 1, #parts do
			widths[index] = surface.GetTextSize(parts[index])
			total = total + widths[index]
		end

		surface.SetFont("nwChat")

		local used = inset + (value == "" and surface.GetTextSize(L("chatPlaceholder")) or
			surface.GetTextSize(value)) + Sc(16)

		if (used + total <= right) then
			local hintX = right - total

			for index = 1, #parts do
				local bKey = index % 2 == 1

				draw.SimpleText(parts[index], "nwChatStamp", hintX, centerY,
					ColorAlpha(bKey and theme.textDim or theme.textFaint, (bKey and 220 or 180) * alpha),
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				hintX = hintX + widths[index]
			end
		end

		panel:DrawTextEntryText(theme.text, theme.combineDeep, theme.combine)
	end

	self.entry.Think = function(panel)

		self:UpdateChannelLabel(panel:GetValue())

		if (IsValid(self.channelLabel)) then
			self.channelLabel:SetVisible(self.bActive)
		end

		if (!self.bActive) then
			panel.bUpHeld = nil
			panel.bDownHeld = nil
			panel.bTabHeld = nil

			return
		end

		local bTab = input.IsKeyDown(KEY_TAB)

		if (bTab and !panel.bTabHeld) then
			self:CompleteOnce()
		end

		panel.bTabHeld = bTab
		panel.bUpHeld = nil
		panel.bDownHeld = nil

		local text = panel:GetValue()

		if (self.lastText != text) then
			if (self.lastText != nil and !self.bApplying) then
				self.hintIndex = nil
				self.hintOffset = 0
			end

			self.lastText = text
		end
	end

	self.entry.OnKeyCodeTyped = function(panel, key)
		if (key == KEY_ENTER or key == KEY_PAD_ENTER) then
			self:Submit(panel:GetValue())

			return true
		end

		if (key == KEY_ESCAPE) then
			self:SetActive(false)

			return true
		end

		if (key == KEY_TAB) then
			self:CompleteOnce()

			timer.Simple(0, function()
				if (IsValid(panel) and IsValid(self) and self.bActive) then
					panel:RequestFocus()
				end
			end)

			return true
		end

		if (key == KEY_UP) then
			self:CycleHistory(1)

			return true
		end

		if (key == KEY_DOWN) then
			self:CycleHistory(-1)

			return true
		end
	end

	self:LoadLayout()
	self:UpdateLayout()

	self:NoClipping(true)
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

PANEL.inputGap = 0
PANEL.previewHeight = 24

function PANEL:GetPlateHeight()
	return self:GetTall()
end

function PANEL:UpdateChannelLabel(text)
	local Sc = NETWORK.util.Scale
	local id = NETWORK.chat.Parse(LocalPlayer(), text or "")
	local class = NETWORK.chat.Get(id) or NETWORK.chat.Get("ic")
	local key = "chan_" .. tostring(id)
	local label = L(key)

	if (label == key) then
		label = tostring(id)
	end

	label = NETWORK.util.Upper(label)

	self.labelColor = class and class.color or NETWORK.theme.text

	if (self.labelText == label and (self.labelWidth or 0) > 0) then
		return
	end

	surface.SetFont("nwInvKey")

	self.labelText = label
	self.labelWidth = math.max(surface.GetTextSize(label) + Sc(24), Sc(56))

	self:UpdateLayout()
end

function PANEL:PerformLayout()
	self:UpdateLayout()
end

function PANEL:GetPreviewHeight()
	return NETWORK.util.Scale(self.previewHeight)
end

function PANEL:UpdateLayout()
	local Sc = NETWORK.util.Scale
	local width, height = self:GetSize()

	self.inputHeight = Sc(36)
	self.listX = self.padding + Sc(4)
	self.listY = Sc(44)
	self.listWidth = width - self.padding * 2 - Sc(14)
	self.listHeight = height - self.inputHeight - self:GetPreviewHeight() - self.listY - Sc(6)

	if (IsValid(self.entry)) then

		local labelBox = self.labelWidth or 0

		local labelX = Sc(12)
		local entryX = labelX + labelBox + Sc(4)

		if (IsValid(self.channelLabel)) then
			self.channelLabel:SetPos(labelX, height - self.inputHeight + Sc(2))
			self.channelLabel:SetSize(labelBox, self.inputHeight - Sc(4))
		end

		self.entry:SetPos(entryX, height - self.inputHeight + Sc(2))
		self.entry:SetSize(math.max(width - Sc(102) - entryX, Sc(40)), self.inputHeight - Sc(4))
	end
end

function PANEL:SaveLayout()
	local x, y = self:GetPos()
	local width, height = self:GetSize()

	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON({x = x, y = y, width = width, height = height}, true))
end

function PANEL:LoadLayout()
	local contents = file.Read(dataPath, "DATA")

	if (!contents) then
		return
	end

	local data = util.JSONToTable(contents)

	if (!istable(data)) then
		return
	end

	local width = math.Clamp(tonumber(data.width) or self:GetWide(), self.minWidth, ScrW())
	local height = math.Clamp(tonumber(data.height) or self:GetTall(), self.minHeight, ScrH())

	self:SetSize(width, height)
	self:SetPos(math.Clamp(tonumber(data.x) or 0, 0, ScrW() - width),
		math.Clamp(tonumber(data.y) or 0, 0, ScrH() - height))
end

function PANEL:Recount()
	self.total = 0

	for i = 1, #self.messages do
		self.total = self.total + self.messages[i].height
	end
end

local TAB_PATH = "network/chattabs.txt"

function PANEL:OpenTabCreator()
	if (IsValid(self.creator)) then
		self.creator:Remove()
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local accent = theme.combine
	local line = math.max(Sc(1), 1)
	local classes = NETWORK.chat.GetClasses()

	local pad = Sc(18)
	local frameWidth = Sc(380)
	local innerWidth = frameWidth - pad * 2
	local columns = 2
	local rows = math.ceil(#classes / columns)
	local chipHeight = Sc(30)
	local chipGap = Sc(4)
	local chipWidth = math.floor((innerWidth - chipGap * (columns - 1)) / columns)
	local entryY = Sc(46)
	local entryHeight = Sc(32)
	local labelY = entryY + entryHeight + Sc(12)
	local gridY = labelY + Sc(18)
	local gridHeight = math.max(rows * (chipHeight + chipGap) - chipGap, chipHeight)
	local buttonHeight = Sc(34)
	local footer = Sc(12) + buttonHeight + pad
	local maxHeight = math.Round(ScrH() * 0.7)
	local frameHeight = gridY + gridHeight + footer

	if (frameHeight > maxHeight) then
		frameHeight = maxHeight
		gridHeight = frameHeight - gridY - footer
	end

	local frame = vgui.Create("EditablePanel")

	frame:SetSize(frameWidth, frameHeight)
	frame:Center()
	frame:MakePopup()

	frame.alpha = 0
	frame.selected = {}

	frame:NoClipping(true)
	frame.Think = function(panel)
		panel.alpha = NETWORK.util.Approach(panel.alpha, 1, 8)
	end

	frame.Paint = function(panel, width, height)
		local alpha = NETWORK.util.EaseOut(panel.alpha)
		local S = NETWORK.style

		S.Card(0, 0, width, height, alpha, {
			radius = S.Radius("panel"),
			blur = false,
			accent = accent,
			fill = CARD_FILL
		})

		local icon = Sc(16)
		local titleY = Sc(24)
		local bIcon = DrawIconFile("framework/chat/ui_add.png", pad,
			titleY - math.Round(icon * 0.5), icon, ColorAlpha(accent, 240 * alpha))

		draw.SimpleText(L("chatTabNew"), "nwInvName", pad + (bIcon and icon + Sc(8) or 0), titleY,
			ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(NETWORK.util.Upper(L("chatTabChannels")), "nwInvKey", pad, labelY,
			ColorAlpha(theme.textFaint, 220 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		Pill(pad, gridY - Sc(5), innerWidth, line, 255, 255, 255, 14 * alpha)
	end

	local entry = NETWORK.gui.BindEntry(frame:Add("DTextEntry"))

	entry:SetPos(pad, entryY)
	entry:SetSize(innerWidth, entryHeight)
	entry:SetFont("nwChatSmall")
	entry:SetPaintBackground(false)
	entry:SetTextColor(theme.text)
	entry:SetCursorColor(accent)
	entry:SetTextInset(Sc(10), 0)

	entry.Paint = function(panel, width, height)
		local alpha = NETWORK.util.EaseOut(frame.alpha)
		local value = panel:GetValue()
		local radius = NETWORK.style.Radius("cell")

		RoundBox(radius, 0, 0, width, height, 0, 0, 0, 120 * alpha)

		if (panel:HasFocus()) then
			RoundBorder(radius, 0, 0, width, height, accent.r, accent.g, accent.b, 210 * alpha)
		else
			RoundBorder(radius, 0, 0, width, height, 255, 255, 255, 30 * alpha)
		end

		local bIcon = false

		if (value == "") then
			local icon = Sc(14)

			bIcon = DrawIconFile("framework/icons/keyboard.png", Sc(6),
				math.Round((height - icon) * 0.5), icon, ColorAlpha(theme.textFaint, 200 * alpha))

			draw.SimpleText(L("chatTabName"), "nwChatSmall", bIcon and Sc(24) or Sc(10),
				math.Round(height * 0.5), ColorAlpha(theme.textFaint, 200 * alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		local inset = bIcon and Sc(24) or Sc(10)

		if (panel.nwInset != inset) then
			panel.nwInset = inset
			panel:SetTextInset(inset, 0)
		end

		panel:DrawTextEntryText(theme.text, theme.combineDeep, accent)
	end

	local list = frame:Add("DScrollPanel")

	list:SetPos(pad, gridY)
	list:SetSize(innerWidth, gridHeight)

	local bar = list:GetVBar()

	if (IsValid(bar)) then
		bar:SetWide(Sc(4))
		bar:SetHideButtons(true)

		bar.Paint = function(panel, width, height)
			Pill(math.floor((width - line * 2) * 0.5), 0, line * 2, height, 255, 255, 255, 14)
		end
		bar.btnGrip.Paint = function(panel, width, height)
			Pill(math.floor((width - line * 3) * 0.5), 0, line * 3, height,
				accent.r, accent.g, accent.b, 170)
		end
		bar.btnUp.Paint = function() end
		bar.btnDown.Paint = function() end
	end

	local canvas = list:GetCanvas()

	canvas:SetTall(rows * (chipHeight + chipGap) - chipGap)

	for index, class in ipairs(classes) do
		local chip = list:Add("DButton")
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		local color = class.color or theme.text
		local iconPath = NETWORK.chat.GetIcon(class.id)
		local bTint = iconPath and NETWORK.chat.IsTintedIcon and NETWORK.chat.IsTintedIcon(iconPath)

		chip:SetPos(column * (chipWidth + chipGap), row * (chipHeight + chipGap))
		chip:SetSize(chipWidth, chipHeight)
		chip:SetText("")
		chip:SetCursor("hand")
		chip.Paint = function(panel, width, height)
			local alpha = NETWORK.util.EaseOut(frame.alpha)
			local bOn = frame.selected[class.id]
			local bHover = panel:IsHovered()
			local radius = NETWORK.style.Radius("cell")

			if (bOn) then
				RoundBox(radius, 0, 0, width, height, color.r, color.g, color.b, (bHover and 80 or 56) * alpha)
				RoundBorder(radius, 0, 0, width, height, color.r, color.g, color.b, 190 * alpha)
			else
				RoundBox(radius, 0, 0, width, height, 255, 255, 255, (bHover and 18 or 8) * alpha)
				RoundBorder(radius, 0, 0, width, height, 255, 255, 255, (bHover and 60 or 26) * alpha)
			end

			local icon = Sc(16)
			local iconX = Sc(8)
			local iconY = math.Round((height - icon) * 0.5)
			local tint = bTint and (bOn and color or theme.textDim) or Color(255, 255, 255)
			local bIcon = iconPath and DrawIconFile(iconPath, iconX, iconY, icon,
				ColorAlpha(tint, (bOn and 250 or 150) * alpha))

			if (!bIcon) then

				local letter = NETWORK.util.Upper(NETWORK.util.Sub(L(class.name or class.id), 1, 1))

				local chipRadius = NETWORK.style.Radius("chip")

				RoundBox(chipRadius, iconX, iconY, icon, icon, color.r, color.g, color.b, (bOn and 70 or 30) * alpha)
				RoundBorder(chipRadius, iconX, iconY, icon, icon, color.r, color.g, color.b,
					(bOn and 220 or 110) * alpha)

				draw.SimpleText(letter, "nwInvKey", iconX + math.Round(icon * 0.5),
					iconY + math.Round(icon * 0.5), ColorAlpha(color, (bOn and 250 or 160) * alpha),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			draw.SimpleText(L(class.name or class.id), "nwChatSmall", iconX + icon + Sc(8),
				math.Round(height * 0.5), ColorAlpha(bOn and theme.text or theme.textDim, 245 * alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		chip.DoClick = function()
			frame.selected[class.id] = !frame.selected[class.id] or nil

			NETWORK.sound.InvSelect()
		end
	end

	local buttonY = frameHeight - pad - buttonHeight
	local buttonWidth = math.floor((innerWidth - chipGap) * 0.5)

	local function MakeButton(x, label, iconPath, bPrimary)
		local button = frame:Add("DButton")

		button:SetPos(x, buttonY)
		button:SetSize(buttonWidth, buttonHeight)
		button:SetText("")
		button:SetCursor("hand")
		button.Paint = function(panel, width, height)
			local alpha = NETWORK.util.EaseOut(frame.alpha)
			local bHover = panel:IsHovered()
			local tone = bPrimary and accent or color_white
			local radius = NETWORK.style.Radius("cell")

			RoundBox(radius, 0, 0, width, height, tone.r, tone.g, tone.b,
				(bPrimary and (bHover and 90 or 50) or (bHover and 18 or 10)) * alpha)
			RoundBorder(radius, 0, 0, width, height, tone.r, tone.g, tone.b,
				(bPrimary and 200 or (bHover and 60 or 30)) * alpha)

			surface.SetFont("nwInvButton")

			local icon = Sc(14)
			local textWidth = surface.GetTextSize(label)
			local total = icon + Sc(6) + textWidth
			local startX = math.Round((width - total) * 0.5)
			local textColor = ColorAlpha((bPrimary or bHover) and theme.text or theme.textDim, 250 * alpha)
			local bIcon = DrawIconFile(iconPath, startX, math.Round((height - icon) * 0.5), icon,
				ColorAlpha(bPrimary and accent or theme.textDim, 240 * alpha))

			draw.SimpleText(label, "nwInvButton",
				bIcon and (startX + icon + Sc(6)) or math.Round(width * 0.5), math.Round(height * 0.5),
				textColor, bIcon and TEXT_ALIGN_LEFT or TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		return button
	end

	local confirm = MakeButton(pad, L("chatTabCreate"), "framework/icons/check_circle.png", true)

	confirm.DoClick = function()
		local label = string.Trim(entry:GetValue() or "")

		if (label == "" or !next(frame.selected)) then
			NETWORK.gui.Notify(L("chatTabEmpty"), theme.warning)

			return
		end

		self:AddTab(label, table.Copy(frame.selected))

		frame:Remove()
	end

	local cancel = MakeButton(pad + buttonWidth + chipGap, L("dialogCancel"), "framework/chat/ui_close.png", false)

	cancel.DoClick = function()
		NETWORK.sound.MenuPress()

		frame:Remove()
	end

	self.creator = frame
end

function PANEL:SaveTabs()
	local list = {}

	for _, tab in ipairs(self.tabs) do
		if (tab.bCustom) then
			list[#list + 1] = {label = tab.label, filter = tab.filter}
		end
	end

	file.CreateDir("network")
	file.Write(TAB_PATH, util.TableToJSON(list, true))
end

function PANEL:LoadTabs()
	local contents = file.Read(TAB_PATH, "DATA")
	local data = contents and util.JSONToTable(contents)

	if (!istable(data)) then
		return
	end

	for _, entry in ipairs(data) do
		if (isstring(entry.label) and istable(entry.filter)) then
			self:AddTab(entry.label, entry.filter, true)
		end
	end
end

function PANEL:AddTab(label, filter, bSilent)
	local id = "custom_" .. util.CRC(label .. tostring(SysTime()))

	self.tabs[#self.tabs + 1] = {
		id = id,
		label = label,
		filter = filter,
		bCustom = true
	}

	self.tabReveal[id] = 0

	if (!bSilent) then
		self:SaveTabs()
		self:SetTab(id)

		NETWORK.sound.MenuPress()
	end

	return id
end

function PANEL:RemoveTab(id)
	for index, tab in ipairs(self.tabs) do
		if (tab.id == id and tab.bCustom) then
			table.remove(self.tabs, index)

			self.tabReveal[id] = nil

			if (self.tab == id) then
				self:SetTab("all")
			end

			self:SaveTabs()

			return
		end
	end
end

function PANEL:SetTab(id)
	self.tab = id
	self:ClearSelection()

	for _, tab in ipairs(self.tabs or {}) do
		if (tab.id == id) then
			tab.unread = 0
		end
	end

	self:InvalidateLayout(true)
end

function PANEL:TabAccepts(id, message)
	local current = self.tab

	self.tab = id

	local bOk = self:PassesTab(message)

	self.tab = current

	return bOk
end

function PANEL:ClearMessages()
	self.messages = {}
	self:ClearSelection()
	self.scroll = 0
	self.total = 0

	self:InvalidateLayout(true)
end

function PANEL:GetTabLabel(tab)
	return tab.bCustom and tab.label or L(tab.name)
end

function PANEL:GetTabRects()
	local Sc = NETWORK.util.Scale
	local rects = {}

	local x = Sc(10) + Sc(26)

	surface.SetFont("nwSideNav")

	for index, tab in ipairs(self.tabs or {}) do
		local reveal = self.tabReveal[tab.id]

		if (reveal == nil) then
			reveal = 1
			self.tabReveal[tab.id] = 1
		end

		local width = math.Round((surface.GetTextSize(
			self:GetTabLabel(tab)) + Sc(24)) * reveal)

		rects[index] = {x = x, width = width, tab = tab, reveal = reveal}
		x = x + width + math.Round(Sc(4) * reveal)
	end

	local size = Sc(28)

	self.plusRect = {x = x, width = size, height = size}
	self.clearRect = {x = x + size + Sc(4), width = size, height = size}

	self.cmdRect = {x = x + (size + Sc(4)) * 2, width = size, height = size}

	return rects
end

function PANEL:PassesTab(message)
	local tab = self.tab or "all"

	if (tab == "all") then
		return true
	end

	for _, data in ipairs(self.tabs) do
		if (data.id == tab and data.bCustom) then
			return data.filter[message.class or message.id or ""] == true
		end
	end

	local class = message.class or message.id

	if (tab == "ooc") then
		return class == "ooc" or class == "looc"
	end

	return class != "ooc" and class != "looc" and class != "notice" and
		class != "join" and class != "leave"
end

function PANEL:AddPrompt(text, id, callback)
	self:AddMarkup(text, id or "notice")

	local message = self.messages[#self.messages]

	message.action = callback

	return message
end

local function ShadowMarkup(text)
	return "<color=0,0,0>" .. string.gsub(text, "<color=%d+,%d+,%d+>", "<color=0,0,0>") ..
		"</color>"
end

function PANEL:GetStampWidth()
	local Sc = NETWORK.util.Scale

	surface.SetFont(STAMP_FONT)

	return (surface.GetTextSize("00:00") or Sc(30)) + Sc(10)
end

function PANEL:WrapWidth(indent)
	local Sc = NETWORK.util.Scale

	return math.max(self.listWidth - (indent or 0) - self:GetStampWidth(), Sc(120))
end

function PANEL:GetChatFont()
	return NETWORK.fonts.GetChat and NETWORK.fonts.GetChat("nwChat") or "nwChat"
end

function PANEL:ParseLine(text, indent)
	return NETWORK.chat.Layout(text, self:WrapWidth(indent), self:GetChatFont())
end

function PANEL:Rebuild()
	local Sc = NETWORK.util.Scale

	for i = 1, #self.messages do
		local message = self.messages[i]

		message.object = self:ParseLine(message.text, message.indent)
		message.shadow = nil
		message.height = message.object:GetHeight() + Sc(6)
	end

	self:ClearSelection()

	self:Recount()
end

local TYPE_SPEED = 45

local function SubMarkup(text, count)
	local result = {}
	local shown = 0
	local index = 1
	local length = #text

	while (index <= length) do
		local char = string.sub(text, index, index)

		if (char == "<") then
			local close = string.find(text, ">", index, true)

			if (!close) then
				break
			end

			result[#result + 1] = string.sub(text, index, close)
			index = close + 1
		else
			if (shown >= count) then
				break
			end

			local byte = string.byte(text, index)
			local size = 1

			if (byte >= 240) then
				size = 4
			elseif (byte >= 224) then
				size = 3
			elseif (byte >= 192) then
				size = 2
			end

			result[#result + 1] = string.sub(text, index, index + size - 1)
			index = index + size
			shown = shown + 1
		end
	end

	return table.concat(result), shown
end

function PANEL:AddMarkup(text, id, speaker, name)

	local icon = NETWORK.chat.GetLineIcon and NETWORK.chat.GetLineIcon(id)
	local bIcons = NETWORK.chat.IconsEnabled and NETWORK.chat.IconsEnabled()
	local iconIndent = bIcons and NETWORK.util.Scale(26) or 0
	local indent = iconIndent
	local shadow = nil

	local plain = string.gsub(string.gsub(text, "<[^>]+>", ""), "&lt;", "<")

	local freq

	if (id == "radio") then
		local head, value, rest = string.match(text, "^(<font=[^>]*><color=[^>]*>)%[([^%]<>]+)%] (.*)$")

		if (head and value and utf8.len(value) and utf8.len(value) <= 8) then
			freq = value
			text = head .. rest

			surface.SetFont(FREQ_FONT)

			indent = indent + surface.GetTextSize(freq) + NETWORK.util.Scale(14) + NETWORK.util.Scale(6)
		end
	end

	local object = self:ParseLine(text, indent)

	self.messages[#self.messages + 1] = {
		text = text,
		plain = plain,

		visible = utf8.len(plain) or #plain,
		typed = 0,
		typeTime = CurTime(),
		object = object,
		shadow = shadow,
		stamp = os.date("%H:%M"),
		height = object:GetHeight() + NETWORK.util.Scale(4),
		time = CurTime(),
		id = id,
		class = id,
		icon = icon,
		indent = indent,
		iconIndent = iconIndent,
		freq = freq,
		speaker = (IsValid(speaker) and speaker:IsPlayer()) and speaker or nil,
		steamID = (IsValid(speaker) and speaker:IsPlayer()) and speaker:SteamID64() or nil,
		name = name
	}

	while (#self.messages > self.maxMessages) do
		table.remove(self.messages, 1)

		if (self.selection) then
			self.selection.a.index = self.selection.a.index - 1
			self.selection.b.index = self.selection.b.index - 1

			if (self.selection.a.index < 1 and self.selection.b.index < 1) then
				self:ClearSelection()
			else
				self.selection.a.index = math.max(self.selection.a.index, 1)
				self.selection.b.index = math.max(self.selection.b.index, 1)
			end
		end
	end

	local last = self.messages[#self.messages]

	if (!self:PassesTab(last)) then
		for _, tab in ipairs(self.tabs or {}) do
			if (tab.id != self.tab and tab.id != "all" and self:TabAccepts(tab.id, last)) then
				tab.unread = (tab.unread or 0) + 1
			end
		end
	end

	self:Recount()

	if (self.scroll > 0) then
		self.scroll = math.min(self.scroll + self.messages[#self.messages].height,
			math.max(self.total - self.listHeight, 0))
	end
end

function PANEL:CycleHistory(step)

	if ((self.nextHistoryCycle or 0) > RealTime()) then
		return
	end

	self.nextHistoryCycle = RealTime() + 0.12

	self.history = NETWORK.chat.history or self.history

	if (#self.history == 0) then
		return
	end

	self.historyIndex = math.Clamp(self.historyIndex + step, 0, #self.history)

	if (self.historyIndex == 0) then
		self.entry:SetValue("")

		return
	end

	local text = self.history[#self.history - self.historyIndex + 1] or ""

	self.bApplying = true
	self.entry:SetValue(text)
	self.entry:SetCaretPos(string.len(text))
	self.lastText = text

	timer.Simple(0, function()
		if (IsValid(self) and IsValid(self.entry)) then
			self.bApplying = nil

			self.entry:SetCaretPos(string.len(self.entry:GetValue()))
		end
	end)
end

NETWORK.chat.tabCycle = {"ic", "me", "whisper", "yell", "radio", "looc", "ooc"}

function PANEL:CycleChannel()
	local value = self.entry:GetValue()
	local id, rest = NETWORK.chat.Parse(LocalPlayer(), value)
	local cycle = NETWORK.chat.tabCycle
	local index = 1

	for position, entry in ipairs(cycle) do
		if (entry == id) then
			index = position

			break
		end
	end

	for step = 1, #cycle do
		local candidate = cycle[(index + step - 1) % #cycle + 1]
		local class = NETWORK.chat.Get(candidate)

		if (class) then
			local prefix = candidate == "ic" and "" or
				((istable(class.prefix) and class.prefix[1] or class.prefix or "") .. " ")

			local newValue = prefix .. (rest or "")

			timer.Simple(0, function()
				if (!IsValid(self) or !IsValid(self.entry)) then
					return
				end

				self.entry:SetText(newValue)
				self.entry:SetCaretPos(#newValue)
				self.entry:RequestFocus()
			end)

			NETWORK.sound.Hover()

			return
		end
	end
end

function PANEL:CompleteOnce()
	if ((RealTime() - (self.lastComplete or 0)) < 0.08) then
		return
	end

	self.lastComplete = RealTime()

	self:Complete()
end

function PANEL:Complete()
	local value = self.entry:GetValue()
	local trimmed = string.Trim(value)

	if (trimmed == "") then
		self.hintIndex = nil
		self.hintOffset = 0

		self:FillEntry("/")

		timer.Simple(0.06, function()
			if (IsValid(self) and self.bActive) then
				self:UpdateHints()
			end
		end)

		return
	end

	local bCommand = string.sub(trimmed, 1, 1) == "/" and #trimmed > 1

	if (trimmed == "/") then
		local hints = self:GetHints()

		if (hints and #hints > 0) then
			self.hintIndex = ((self.hintIndex or 0) % #hints) + 1
			self:ApplyHint(hints[self.hintIndex])
		end

		return
	end

	if (bCommand) then
		local id, rest = NETWORK.chat.Parse(LocalPlayer(), value)

		bCommand = id == "ic" or string.Trim(rest or "") != ""
	end

	if (!bCommand) then
		return self:CycleChannel()
	end

	local hints = self:GetHints()

	if (!hints or #hints == 0) then
		return self:CycleChannel()
	end

	self.hintIndex = ((self.hintIndex or 0) % #hints) + 1

	self:ApplyHint(hints[self.hintIndex])
end

function PANEL:Submit(text)
	text = string.Trim(text or "")

	if (text != "") then

		if (self.history[#self.history] != text) then
			self.history[#self.history + 1] = text
		end

		while (#self.history > 50) do
			table.remove(self.history, 1)
		end

		NETWORK.chat.history = self.history

		file.CreateDir("network")
		file.Write("network/chathistory.txt", util.TableToJSON(self.history))

		NETWORK.chat.Say(text)
	end

	self:SetActive(false)
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE or key == KEY_BACKQUOTE) then
		self:SetActive(false)
	end
end

hook.Add("PlayerBindPress", "nwChatTab", function(client, bind, bPressed)
	local panel = NETWORK.gui.chat

	if (IsValid(panel) and panel.bActive and string.find(bind, "showscores", 1, true)) then
		return true
	end
end)

hook.Add("Think", "nwChatClose", function()
	local panel = NETWORK.gui.chat

	if (!IsValid(panel) or !panel.bActive) then
		return
	end

	if (input.IsKeyDown(KEY_ESCAPE) or input.IsKeyDown(KEY_BACKQUOTE)) then
		panel:SetActive(false)
	end
end)

function PANEL:SetActive(bActive)
	if (self.bActive == bActive) then
		return
	end

	self.bActive = bActive
	self.historyIndex = 0
	self.hintIndex = nil
	self.hintOffset = 0
	self.lastText = nil
	self.dragging = nil
	self.resizing = nil

	if (!bActive and IsValid(self.hintPanel)) then
		self.hintPanel:Remove()

		self.hintPanel = nil
	end

	if (!bActive and IsValid(self.commandPanel)) then
		self.commandPanel:Remove()

		self.commandPanel = nil
	end

	if (!bActive and IsValid(NETWORK.gui.chatMenu)) then
		NETWORK.gui.chatMenu:Remove()
	end

	self.entry:SetVisible(bActive)
	self:SetMouseInputEnabled(bActive)
	self:SetKeyboardInputEnabled(bActive)

	if (!bActive) then
		self:UpdateTyping()
	end

	if (bActive) then
		self.scroll = 0

		self:MakePopup()
		self.entry:SetValue("")
		self.entry:RequestFocus()

		self:UpdateChannelLabel("")

		if (IsValid(self.channelLabel)) then
			self.channelLabel:SetVisible(true)
		end

		NETWORK.sound.ChatOpen()

		hook.Run("StartChat")
	else
		self.entry:SetValue("")
		self.entry:KillFocus()
		self:MouseCapture(false)

		if (IsValid(self.voiceQuick)) then
			self.voiceQuick:Remove()
			self.voiceQuick = nil
		end

		gui.EnableScreenClicker(false)

		NETWORK.sound.ChatSend()

		hook.Run("FinishChat")
	end
end

local VOICE = {}

function VOICE:Init()
	self.category = 1
	self.offset = 0
	self.alpha = 0
	self.chips = {}
	self.startTime = CurTime()

	self:SetMouseInputEnabled(true)
	self:SetKeyboardInputEnabled(false)
	self:SetZPos(32000)
end

function VOICE:Setup(chat)
	local Sc = NETWORK.util.Scale
	local client = LocalPlayer()

	self.chat = chat
	self.categories = {}

	for _, id in ipairs(NETWORK.voice.categoryOrder or {}) do
		local lines = NETWORK.voice.GetByCategory(id, client)

		if (#lines > 0) then
			local name = NETWORK.voice.categories and NETWORK.voice.categories[id]

			self.categories[#self.categories + 1] = {
				id = id,
				name = istable(name) and name.name or name or id,
				lines = lines
			}
		end
	end

	if (#self.categories == 0) then
		self:Remove()

		return false
	end

	local width = math.min(ScrW() - Sc(80), Sc(1100))

	self:SetSize(width, Sc(64))
	self:SetPos(math.Round((ScrW() - width) * 0.5), ScrH() - Sc(84))

	return true
end

function VOICE:GetLines()
	local category = self.categories[self.category] or self.categories[1]

	return category and category.lines or {}, category
end

function VOICE:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 8)

	local chat = self.chat

	if (!IsValid(chat) or !chat.bActive) then
		self:Remove()
	end
end

function VOICE:OnMouseWheeled(delta)
	local lines = self:GetLines()

	self.offset = math.Clamp(self.offset - delta, 0, math.max(#lines - 1, 0))
end

function VOICE:OnMousePressed(code)
	local x, y = self:CursorPos()

	if (code == MOUSE_RIGHT) then
		self.category = self.category % #self.categories + 1
		self.offset = 0
		NETWORK.sound.TabPress()

		return
	end

	for _, rect in ipairs(self.tabRects or {}) do
		if (x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height) then
			self.category = rect.index
			self.offset = 0
			NETWORK.sound.TabPress()

			return
		end
	end

	for _, chip in ipairs(self.chips) do
		if (x >= chip.x and x <= chip.x + chip.width and y >= chip.y and y <= chip.y + chip.height) then
			local chat = self.chat

			if (IsValid(chat) and IsValid(chat.entry)) then
				local text = string.Trim(chat.entry:GetText() or "")
				local prefix = NETWORK.voice.prefix or ";"

				if (text != "") then
					text = text .. prefix
				end

				chat.entry:SetText(text .. chip.id)
				chat.entry:SetCaretPos(string.len(chat.entry:GetText()))
				chat.entry:RequestFocus()
			end

			NETWORK.sound.Click()

			return
		end
	end
end

function VOICE:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = util.EaseOut(self.alpha)
	local line = math.max(Sc(1), 1)
	local cursorX, cursorY = self:CursorPos()
	local caret = theme.combine

	util.DrawBlurRounded(self, 0, 0, width, height, 2, 5 * alpha)

	surface.SetDrawColor(0, 0, 0, 190 * alpha)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(caret.r, caret.g, caret.b, 90 * alpha)
	surface.DrawOutlinedRect(0, 0, width, height, line)

	local material = util.GetMaterial("framework/icons/record_voice_over.png", "smooth")
	local x = Sc(10)

	if (material and !material:IsError()) then
		surface.SetMaterial(material)
		surface.SetDrawColor(caret.r, caret.g, caret.b, 230 * alpha)
		surface.DrawTexturedRect(x, Sc(8), Sc(16), Sc(16))
	end

	x = x + Sc(22)
	self.tabRects = {}

	surface.SetFont("nwInvKey")

	for index, category in ipairs(self.categories) do
		local label = util.Upper(L(category.name))
		local tabWidth = surface.GetTextSize(label) + Sc(14)
		local bActive = index == self.category
		local rect = {x = x, y = Sc(6), width = tabWidth, height = Sc(20), index = index}
		local bHover = cursorX >= rect.x and cursorX <= rect.x + rect.width and
			cursorY >= rect.y and cursorY <= rect.y + rect.height

		self.tabRects[#self.tabRects + 1] = rect

		if (bActive) then
			surface.SetDrawColor(caret.r, caret.g, caret.b, 70 * alpha)
			surface.DrawRect(rect.x, rect.y, rect.width, rect.height)
			surface.SetDrawColor(caret.r, caret.g, caret.b, 200 * alpha)
			surface.DrawOutlinedRect(rect.x, rect.y, rect.width, rect.height, line)
		elseif (bHover) then
			surface.SetDrawColor(255, 255, 255, 18 * alpha)
			surface.DrawRect(rect.x, rect.y, rect.width, rect.height)
		end

		draw.SimpleText(label, "nwInvKey", rect.x + math.Round(rect.width * 0.5),
			rect.y + math.Round(rect.height * 0.5),
			ColorAlpha((bActive or bHover) and theme.text or theme.textDim, 240 * alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		x = x + tabWidth + Sc(4)
	end

	draw.SimpleText(L("voiceQuickHint"), "nwHudSmall", width - Sc(10), Sc(16),
		ColorAlpha(theme.textFaint, 200 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	local lines = self:GetLines()
	local chipY = Sc(30)
	local chipHeight = Sc(26)
	local chipX = Sc(10)

	self.chips = {}

	surface.SetFont("nwLabel")

	for index = self.offset + 1, #lines do
		local data = lines[index]
		local text = data.text or ""

		if (utf8.len(text) and utf8.len(text) > 30) then
			text = utf8.sub and utf8.sub(text, 1, 30) .. "…" or string.sub(text, 1, 60) .. "…"
		end

		surface.SetFont("nwInvKey")

		local codeWidth = surface.GetTextSize(data.id)

		surface.SetFont("nwLabel")

		local textWidth = surface.GetTextSize(text)
		local chipWidth = codeWidth + textWidth + Sc(26)

		if (chipX + chipWidth > width - Sc(10)) then
			break
		end

		local rect = {x = chipX, y = chipY, width = chipWidth, height = chipHeight, id = data.id}
		local bHover = cursorX >= rect.x and cursorX <= rect.x + rect.width and
			cursorY >= rect.y and cursorY <= rect.y + rect.height
		local reveal = util.EaseOut(util.Stagger(self.startTime, 0.02 * (index - self.offset), 0.3))

		self.chips[#self.chips + 1] = rect

		surface.SetDrawColor(255, 255, 255, (bHover and 26 or 10) * alpha * reveal)
		surface.DrawRect(rect.x, rect.y, rect.width, rect.height)
		surface.SetDrawColor(caret.r, caret.g, caret.b, (bHover and 200 or 70) * alpha * reveal)
		surface.DrawOutlinedRect(rect.x, rect.y, rect.width, rect.height, line)

		draw.SimpleText(data.id, "nwInvKey", rect.x + Sc(8), rect.y + math.Round(chipHeight * 0.5),
			ColorAlpha(caret, 250 * alpha * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(text, "nwLabel", rect.x + Sc(8) + codeWidth + Sc(8),
			rect.y + math.Round(chipHeight * 0.5),
			ColorAlpha(bHover and theme.text or theme.textDim, 230 * alpha * reveal),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		chipX = chipX + chipWidth + Sc(6)
	end

	if (self.offset > 0 or #lines > #self.chips + self.offset) then
		draw.SimpleText(string.format("%d–%d / %d", self.offset + 1, self.offset + #self.chips, #lines),
			"nwHudSmall", width - Sc(10), chipY + math.Round(chipHeight * 0.5),
			ColorAlpha(theme.textFaint, 200 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwVoiceQuick", VOICE, "EditablePanel")

function PANEL:OpenVoiceQuick()
	if (IsValid(self.voiceQuick)) then
		self.voiceQuick:Remove()
	end

	if (!NETWORK.voice or !NETWORK.voice.GetByCategory) then
		return
	end

	local panel = vgui.Create("nwVoiceQuick")

	if (panel:Setup(self)) then
		self.voiceQuick = panel
	end
end

function PANEL:GetActive()
	return self.bActive
end

function PANEL:GetZone(x, y)
	local width, height = self:GetSize()

	if (x >= width - self.grip and y >= height - self.grip) then
		return "resize"
	end

	if (y <= self.headerHeight) then
		return "drag"
	end
end

function PANEL:OnCursorMoved(x, y)
	if (self.dragging or self.resizing) then
		return
	end

	local zone = self:GetZone(x, y)

	self:SetCursor(zone == "resize" and "sizenwse" or zone == "drag" and "sizeall" or
		(self.bActive and self:InList(x, y)) and "beam" or "arrow")
end

local MENU = {}

function MENU:Init()
	self.rows = {}
	self.alpha = 0

	self:SetMouseInputEnabled(true)
	self:SetKeyboardInputEnabled(false)
	self:SetZPos(32500)

	self:NoClipping(true)
end

function MENU:Setup(message, text, chat)
	local Sc = NETWORK.util.Scale

	self.message = message
	self.chat = chat
	self.color = IsValid(message.speaker) and NETWORK.chat.GetSpeakerColor(message.speaker) or
		NETWORK.theme.combine

	self.rows = {
		{label = L("chatMenuProfile"), glyph = "person", run = function()
			gui.OpenURL("https://steamcommunity.com/profiles/" .. message.steamID)
		end},
		{label = L("chatMenuCopyName"), glyph = "list", run = function()
			SetClipboardText(message.name or "")
			NETWORK.gui.Notify(L("chatCopied"), NETWORK.theme.accentSoft)
		end},
		{label = L("chatMenuCopy"), glyph = "list", run = function()
			SetClipboardText(text or "")
			NETWORK.gui.Notify(L("chatCopied"), NETWORK.theme.accentSoft)
		end},
		{label = L("chatMenuReport"), glyph = "cross", bDanger = true, run = function()
			if (IsValid(chat) and IsValid(chat.entry)) then
				chat.entry:SetText("@" .. (message.name or "") .. " ")
				chat.entry:SetCaretPos(string.len(chat.entry:GetText()))
				chat.entry:RequestFocus()
			end
		end}
	}

	if (IsValid(chat) and chat.HasSelection and chat:HasSelection()) then
		table.insert(self.rows, 1, {label = L("chatMenuCopySelection"), glyph = "list",
			run = function()
				if (IsValid(chat)) then
					chat:CopySelection()
				end
			end})
	end

	surface.SetFont("nwInvBody")

	local width = Sc(200)

	for _, row in ipairs(self.rows) do
		width = math.max(width, surface.GetTextSize(row.label) + Sc(56))
	end

	self:SetSize(width, Sc(44) + #self.rows * Sc(30) + Sc(8))

	local parent = self:GetParent()
	local x, y = gui.MousePos()
	local maxX, maxY = ScrW(), ScrH()

	if (IsValid(parent) and parent != vgui.GetWorldPanel()) then
		x, y = parent:CursorPos()
		maxX, maxY = parent:GetWide(), parent:GetTall()
	end

	self:SetPos(math.Clamp(x + Sc(4), 0, math.max(maxX - self:GetWide(), 0)),
		math.Clamp(y + Sc(4), 0, math.max(maxY - self:GetTall(), 0)))
end

function MENU:RowAt(y)
	local Sc = NETWORK.util.Scale
	local index = math.floor((y - Sc(44)) / Sc(30)) + 1

	return self.rows[index] and index or nil
end

function MENU:OnMousePressed(code)
	if (code != MOUSE_LEFT) then
		return self:Remove()
	end

	local _, y = self:CursorPos()
	local index = self:RowAt(y)

	if (index) then
		NETWORK.sound.Click()

		self.rows[index].run()
	end

	self:Remove()
end

function MENU:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 12)

	if ((input.IsMouseDown(MOUSE_LEFT) or input.IsMouseDown(MOUSE_RIGHT)) and !self:IsHovered()) then
		if (self.bArmed) then
			self:Remove()
		end
	else
		self.bArmed = true
	end
end

function MENU:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = util.EaseOut(self.alpha)
	local line = math.max(Sc(1), 1)
	local _, cursorY = self:CursorPos()
	local hovered = self:IsHovered() and self:RowAt(cursorY) or nil
	local S = NETWORK.style

	S.Card(0, 0, width, height, alpha, {
		radius = S.Radius("card"),
		blur = false,
		accent = self.color,
		fill = CARD_FILL,
		border = S.lineStrong
	})

	local shownName = NETWORK.chat.GetShownName and
		NETWORK.chat.GetShownName(self.message.class, self.message.speaker, self.message.name) or
		self.message.name

	draw.SimpleText(util.TruncateWidth(shownName or "", "nwInvBody", width - Sc(24)),
		"nwInvBody", Sc(12), Sc(16), ColorAlpha(theme.text, 250 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(util.Upper(L("chatName" .. (self.message.class or "ic"))), "nwInvKey",
		Sc(12), Sc(32), ColorAlpha(self.color, 220 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	Pill(Sc(10), Sc(42), width - Sc(20), line, 255, 255, 255, 16 * alpha)

	local rowRadius = S.Radius("cell")

	for index, row in ipairs(self.rows) do
		local y = Sc(44) + (index - 1) * Sc(30)
		local color = row.bDanger and theme.danger or theme.text
		local bHover = hovered == index

		if (bHover) then
			RoundBox(rowRadius, Sc(6), y + Sc(2), width - Sc(12), Sc(26), color.r, color.g, color.b, 24 * alpha)
			Pill(Sc(9), y + Sc(8), math.max(Sc(2), 2), Sc(14), color.r, color.g, color.b, 220 * alpha)
		end

		NETWORK.gui.DrawGlyph(row.glyph, Sc(18), y + Sc(8), Sc(14),
			ColorAlpha(row.bDanger and theme.danger or theme.textDim, (170 + 80 * (bHover and 1 or 0)) * alpha))

		draw.SimpleText(row.label, "nwInvBody", Sc(42), y + Sc(15),
			ColorAlpha(bHover and color or theme.textDim, 245 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwChatMenu", MENU, "EditablePanel")

function PANEL:ClearSelection()
	self.selection = nil
	self.selecting = nil
end

function PANEL:HasSelection()
	local selection = self.selection

	return selection != nil and (selection.a.index != selection.b.index or
		selection.a.char != selection.b.char)
end

function PANEL:HitChar(x, y)
	local Sc = NETWORK.util.Scale
	local best, bestDistance

	for _, rect in ipairs(self.messageRects or {}) do
		local distance = 0

		if (y < rect.y) then
			distance = rect.y - y
		elseif (y > rect.y + rect.height) then
			distance = y - rect.y - rect.height
		end

		if (!best or distance < bestDistance) then
			best = rect
			bestDistance = distance
		end
	end

	if (!best or !best.message or !best.message.object) then
		return
	end

	local message = best.message
	local index

	for i, entry in ipairs(self.messages) do
		if (entry == message) then
			index = i

			break
		end
	end

	if (!index) then
		return
	end

	local originX = best.x + Sc(6) + (message.indent or 0)
	local localY = y - best.y

	if (y < best.y) then
		localY = 0
	elseif (y > best.y + best.height) then
		localY = best.height
	end

	return {index = index, char = message.object:CharAt(x - originX, localY)}
end

local function SelectionOrder(a, b)
	if (a.index < b.index or (a.index == b.index and a.char <= b.char)) then
		return a, b
	end

	return b, a
end

function PANEL:GetSelectionRange(index, object)
	if (!self:HasSelection()) then
		return
	end

	local first, last = SelectionOrder(self.selection.a, self.selection.b)

	if (index < first.index or index > last.index) then
		return
	end

	local from = index == first.index and first.char or 1
	local to = index == last.index and last.char or (object.count + 1)

	if (from >= to) then
		return
	end

	return {from, to}
end

function PANEL:GetSelectedText()
	if (!self:HasSelection()) then
		return ""
	end

	local first, last = SelectionOrder(self.selection.a, self.selection.b)
	local parts = {}

	for index = first.index, last.index do
		local message = self.messages[index]

		if (message and message.object and self:PassesTab(message)) then
			local from = index == first.index and first.char or 1
			local to = index == last.index and last.char or (message.object.count + 1)
			local text = message.object:GetText(from, to)

			if (text != "") then
				parts[#parts + 1] = text
			end
		end
	end

	return table.concat(parts, "\n")
end

function PANEL:CopySelection()
	local text = self:GetSelectedText()

	if (text == "") then
		return false
	end

	SetClipboardText(text)
	NETWORK.gui.Notify(L("chatSelectionCopied"), NETWORK.theme.accentSoft)

	return true
end

function PANEL:InList(x, y)
	return x >= self.listX - NETWORK.util.Scale(8) and x <= self.listX + self.listWidth and
		y >= self.listY and y <= self.listY + self.listHeight
end

function PANEL:OpenSpeakerMenu()
	local _, y = self:CursorPos()

	for _, rect in ipairs(self.messageRects or {}) do
		if (y >= rect.y and y <= rect.y + rect.height) then
			local message = rect.message

			if (!message or !message.steamID) then
				return false
			end

			if (IsValid(NETWORK.gui.chatMenu)) then
				NETWORK.gui.chatMenu:Remove()
			end

			local menu = vgui.Create("nwChatMenu", self)

			menu:Setup(message, rect.text, self)

			NETWORK.gui.chatMenu = menu

			return true
		end
	end

	return false
end

function PANEL:CopyUnderCursor()
	local _, y = self:CursorPos()

	for _, rect in ipairs(self.messageRects or {}) do
		if (y >= rect.y and y <= rect.y + rect.height) then
			SetClipboardText(rect.text)

			NETWORK.gui.Notify(L("chatCopied"), NETWORK.theme.accentSoft)

			return true
		end
	end

	return false
end

function PANEL:OnMousePressed(code)
	if (!self.bActive) then
		return
	end

	local x, y = self:CursorPos()

	if (code == MOUSE_RIGHT or code == MOUSE_MIDDLE) then

		local tabY = NETWORK.util.Scale(6)
		local tabHeight = NETWORK.util.Scale(28)

		if (y >= tabY and y <= tabY + tabHeight) then
			local rects = self:GetTabRects()

	for _, rect in ipairs(rects) do
				if (x >= rect.x and x <= rect.x + rect.width and
					rect.tab.bCustom) then
					self:RemoveTab(rect.tab.id)
					NETWORK.sound.TabPress()

					return
				end
			end
		end

		if (code == MOUSE_RIGHT and self:OpenSpeakerMenu()) then
			return
		end

		if (self:HasSelection() and self:CopySelection()) then
			return
		end

		self:CopyUnderCursor()

		return
	end

	if (code != MOUSE_LEFT) then
		return
	end

	local function Inside(rect)
		return rect and x >= rect.x and x <= rect.x + rect.width and
			y >= rect.y and y <= rect.y + rect.height
	end

	if (Inside(self.sendRect)) then
		if (IsValid(self.entry)) then
			self:Submit(self.entry:GetText())
			self.entry:SetText("")
		end

		return
	end

	if (Inside(self.downRect)) then
		self.scroll = 0
		NETWORK.sound.Click()

		return
	end

	if (self.langRect and x >= self.langRect.x and x <= self.langRect.x + self.langRect.width and
		y >= self.langRect.y and y <= self.langRect.y + self.langRect.height) then
		local current = NETWORK.lang.GetCurrent and NETWORK.lang.GetCurrent() or "ru"

		RunConsoleCommand("network_language", current == "ru" and "en" or "ru")
		NETWORK.sound.Click()

		return
	end

	if (self.actionRects) then
		for _, rect in ipairs(self.actionRects) do
			if (x >= rect.x and x <= rect.x + rect.width and
				y >= rect.y and y <= rect.y + rect.height) then
				local message = rect.message

				if (message.action) then
					local callback = message.action

					message.action = nil

					callback(message)
				end

				return
			end
		end
	end

	local tabY = NETWORK.util.Scale(6)
	local tabHeight = NETWORK.util.Scale(28)

	if (y >= tabY and y <= tabY + tabHeight) then
		for _, rect in ipairs(self:GetTabRects()) do
			if (x >= rect.x and x <= rect.x + rect.width) then
				self:SetTab(rect.tab.id)
				NETWORK.sound.TabPress()

				return
			end
		end

		if (self.plusRect and x >= self.plusRect.x and
			x <= self.plusRect.x + self.plusRect.width) then
			self:OpenTabCreator()

			return
		end

		if (self.clearRect and x >= self.clearRect.x and
			x <= self.clearRect.x + self.clearRect.width) then
			self:ClearMessages()
			NETWORK.sound.TabPress()

			return
		end

		if (self.cmdRect and x >= self.cmdRect.x and
			x <= self.cmdRect.x + self.cmdRect.width) then
			self:ToggleCommands()
			NETWORK.sound.TabPress()

			return
		end
	end

	local zone = self:GetZone(x, y)

	if (zone == "resize") then
		self.resizing = true
	elseif (zone == "drag") then
		self.dragging = {x, y}
	elseif (self:InList(x, y)) then

		local hit = self:HitChar(x, y)

		self:ClearSelection()

		if (hit) then
			self.selecting = true
			self.selection = {a = hit, b = {index = hit.index, char = hit.char}}
		end
	else
		return
	end

	self:MouseCapture(true)
end

function PANEL:OnMouseReleased()
	if (self.selecting) then
		self.selecting = nil

		if (!self:HasSelection()) then
			self:ClearSelection()
		end

		self:MouseCapture(false)

		return
	end

	if (self.dragging or self.resizing) then
		if (self.resizing) then
			self:Rebuild()
		end

		self:SaveLayout()
	end

	self.dragging = nil
	self.resizing = nil

	self:MouseCapture(false)
end

function PANEL:OnMouseWheeled(delta)
	if (!self.bActive) then
		return
	end

	if (IsValid(self.hintPanel) and self.hintPanel:IsHovered() and self:ScrollHints(delta)) then
		return
	end

	self.scroll = math.Clamp(self.scroll + delta * NETWORK.util.Scale(48), 0,
		math.max(self.total - self.listHeight, 0))
end

function PANEL:UpdateTyping()
	local id = ""

	if (self.bActive) then
		id = NETWORK.chat.GetTypingClass(self.entry:GetValue()) or ""
	end

	if (self.typing == id) then
		return
	end

	self.typing = id

	net.Start("nwChatTyping")
		net.WriteString(id)
	net.SendToServer()
end

function PANEL:Think()
	if (IsValid(self.channelLabel) and self.channelLabel:IsVisible() != self.bActive) then
		self.channelLabel:SetVisible(self.bActive)
	end

	for id, value in pairs(self.tabReveal) do
		if (value < 1) then
			self.tabReveal[id] = NETWORK.util.Approach(value, 1, 5)
		end
	end

	self.alpha = NETWORK.util.Approach(self.alpha, self.bActive and 1 or 0, 12)

	self:UpdateTyping()
	self:UpdateHints()
	self:PollHintClick()
	self:UpdateCommands()
	self:PollCommandClick()

	if (self.selecting) then
		if (!input.IsMouseDown(MOUSE_LEFT)) then
			self:OnMouseReleased()
		else
			local x, y = self:CursorPos()
			local hit = self:HitChar(x, y)

			if (hit and self.selection) then
				self.selection.b = hit
			end
		end
	end

	if (self.bActive and self:HasSelection() and
		(input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)) and
		input.IsKeyDown(KEY_C)) then
		if (!self.copyHeld) then
			self.copyHeld = true
			self:CopySelection()
		end
	else
		self.copyHeld = false
	end

	if (self.dragging) then
		local mouseX, mouseY = gui.MousePos()

		self:SetPos(math.Clamp(mouseX - self.dragging[1], 0, ScrW() - self:GetWide()),
			math.Clamp(mouseY - self.dragging[2], 0, ScrH() - self:GetTall()))

		return
	end

	if (self.resizing) then
		local mouseX, mouseY = gui.MousePos()
		local x, y = self:GetPos()

		self:SetSize(math.Clamp(mouseX - x, self.minWidth, ScrW() - x),
			math.Clamp(mouseY - y, self.minHeight, ScrH() - y))
		self:UpdateLayout()

		return
	end

	if (self.bActive and IsValid(self.entry) and !self.entry:HasFocus() and
		!IsValid(NETWORK.gui.chatMenu)) then
		self.entry:RequestFocus()
	end
end

function PANEL:GetArgumentHints()
	local text = self.entry:GetValue()

	if (string.sub(text, 1, 1) != "/") then
		return
	end

	local parts = string.Explode(" ", text)
	local command = NETWORK.command.Get(string.sub(parts[1] or "", 2))

	if (!command or !command.usage) then
		return
	end

	local slots = {}

	for token in string.gmatch(command.usage, "[<%[]([^>%]]+)[>%]]") do
		slots[#slots + 1] = NETWORK.util.Lower(token)
	end

	local index = #parts - 1

	if (index < 1) then
		return
	end

	local slot = slots[index]

	if (!slot) then
		return
	end

	local typed = NETWORK.util.Lower(parts[#parts] or "")
	local hints = {}

	if (string.find(slot, "игрок") or string.find(slot, "player")) then
		local viewer = LocalPlayer()

		for _, target in ipairs(player.GetAll()) do

			if (target != viewer and !viewer:IsAdmin() and !viewer:IsRecognised(target)) then
				continue
			end

			local name = target:GetCharacterName()

			if (typed != "" and !string.find(NETWORK.util.Lower(name), typed, 1, true)) then
				continue
			end

			local factionID = target:GetCharacterFaction()
			local faction = factionID and NETWORK.factions.Get(factionID)

			hints[#hints + 1] = {
				value = name,
				prefix = name,
				label = faction and L(faction.name) or target:SteamName(),
				color = faction and faction.color or NETWORK.theme.accentSoft,
				bArgument = true
			}
		end
	elseif (string.find(slot, "предмет") or string.find(slot, "item")) then
		for _, base in ipairs(NETWORK.item.GetAll()) do
			if (typed != "" and !string.find(NETWORK.util.Lower(base.name), typed, 1, true) and
				!string.find(base.id, typed, 1, true)) then
				continue
			end

			hints[#hints + 1] = {
				value = base.id,
				prefix = base.id,
				label = base.name,
				color = NETWORK.inventory.GetRarity(base.rarity).color,
				bArgument = true
			}
		end
	elseif (string.find(slot, "фракц") or string.find(slot, "faction")) then
		for id, faction in pairs(NETWORK.factions.stored or {}) do
			if (typed != "" and !string.find(id, typed, 1, true)) then
				continue
			end

			hints[#hints + 1] = {
				value = id,
				prefix = id,
				label = L(faction.name),
				color = faction.color,
				bArgument = true
			}
		end
	end

	table.sort(hints, function(a, b)
		return a.prefix < b.prefix
	end)

	while (#hints > 60) do
		table.remove(hints)
	end

	return hints
end

function PANEL:GetHints()
	if (!self.bActive) then
		return
	end

	local text = self.entry:GetValue()

	if (string.sub(text, 1, 1) != "/") then
		return
	end

	if (string.find(text, " ")) then
		return self:GetArgumentHints()
	end

	local lower = NETWORK.util.Lower(text)
	local hints = {}
	local seen = {}

	for _, entry in ipairs(NETWORK.chat.GetPrefixes()) do
		if (string.sub(entry.prefix, 1, string.len(lower)) == lower and !seen[entry.prefix]) then
			seen[entry.prefix] = true

			hints[#hints + 1] = {
				prefix = entry.prefix,
				color = entry.class.color,
				label = L("chatName" .. entry.class.id)
			}
		end
	end

	for id, command in pairs(NETWORK.command.stored) do
		local prefix = "/" .. id

		if (string.sub(prefix, 1, string.len(lower)) == lower and !seen[prefix]) then
			if (command.adminOnly and !LocalPlayer():IsAdmin()) then
				continue
			end

			seen[prefix] = true

			hints[#hints + 1] = {
				prefix = prefix,
				color = command.adminOnly and NETWORK.theme.value or
					NETWORK.theme.accentSoft,
				label = command.usage and string.gsub(command.usage, "^/%S+%s*", "") or
					L("chatCommand")
			}
		end
	end

	table.sort(hints, function(a, b)
		return a.prefix < b.prefix
	end)

	while (#hints > 60) do
		table.remove(hints)
	end

	return hints
end

NETWORK.chat.hintRows = 10

function PANEL:GetHintWindow()
	local hints = self:GetHints()

	if (!hints or #hints == 0) then
		return
	end

	local rows = NETWORK.chat.hintRows
	local maximum = math.max(#hints - rows, 0)

	self.hintOffset = math.Clamp(math.Round(self.hintOffset or 0), 0, maximum)

	if (self.hintIndex) then
		if (self.hintIndex <= self.hintOffset) then
			self.hintOffset = self.hintIndex - 1
		elseif (self.hintIndex > self.hintOffset + rows) then
			self.hintOffset = self.hintIndex - rows
		end

		self.hintOffset = math.Clamp(self.hintOffset, 0, maximum)
	end

	local window = {}

	for index = self.hintOffset + 1, math.min(self.hintOffset + rows, #hints) do
		window[#window + 1] = hints[index]
	end

	return window, #hints, self.hintOffset, maximum
end

function PANEL:ScrollHints(delta)
	local _, total = self:GetHintWindow()

	if (!total or total <= NETWORK.chat.hintRows) then
		return false
	end

	self.hintOffset = (self.hintOffset or 0) - delta

	return true
end

function PANEL:ApplyHint(hint)
	if (!hint) then
		return
	end

	self.bApplying = true

	timer.Simple(0, function()
		if (IsValid(self)) then
			self.bApplying = nil
		end
	end)

	if (hint.bArgument) then
		local text = self.entry:GetValue()
		local parts = string.Explode(" ", text)

		parts[#parts] = string.find(hint.value, " ") and
			("\"" .. hint.value .. "\"") or hint.value

		self:FillEntry(table.concat(parts, " ") .. " ")

		NETWORK.sound.Click()

		return
	end

	self:FillEntry(hint.prefix .. " ")

	NETWORK.sound.Click()
end

function PANEL:FillEntry(text)
	if (!IsValid(self.entry)) then
		return
	end

	if (!self.bActive) then
		self:SetActive(true)
	end

	self:MakePopup()

	self.entry:SetVisible(true)
	self.entry:RequestFocus()
	self.entry:SetValue(text)
	self.entry:SetCaretPos(string.len(text))

	for _, delay in ipairs({0, 0.05}) do
		timer.Simple(delay, function()
			if (!IsValid(self) or !IsValid(self.entry) or !self.bActive) then
				return
			end

			self:MakePopup()
			self.entry:RequestFocus()

			if (self.entry:GetValue() != text) then
				self.entry:SetValue(text)
			end

			self.entry:SetCaretPos(string.len(self.entry:GetValue()))
			self.lastText = self.entry:GetValue()
		end)
	end

	self.hintIndex = nil
	self.hintOffset = 0
	self.lastText = text
end

local HINTS = {}

function HINTS:Init()
	self:SetMouseInputEnabled(true)
	self:SetKeyboardInputEnabled(false)
	self:SetPaintedManually(false)
	self:NoClipping(true)
	self:SetCursor("hand")

	self.rows = {}
end

function HINTS:SetChat(chat)
	self.chat = chat
end

function HINTS:GetChat()
	return IsValid(self.chat) and self.chat or nil
end

function HINTS:GetRowAt(x, y)
	for _, rect in ipairs(self.rows) do
		if (x >= rect.x and x <= rect.x + rect.width and
			y >= rect.y and y <= rect.y + rect.height) then
			return rect
		end
	end
end

function HINTS:OnMousePressed(code)

	local chat = self:GetChat()

	if (chat and IsValid(chat.entry)) then
		timer.Simple(0, function()
			if (IsValid(chat) and IsValid(chat.entry) and chat.bActive) then
				chat.entry:RequestFocus()
				chat.entry:SetCaretPos(string.len(chat.entry:GetValue()))
			end
		end)
	end
end

function HINTS:OnMouseWheeled(delta)
	local chat = self:GetChat()

	if (chat) then
		chat:ScrollHints(delta)
	end
end

function HINTS:Paint(width, height)
	local chat = self:GetChat()

	if (!chat) then
		return
	end

	local hints, total, offset, maximum = chat:GetHintWindow()

	self.rows = {}

	if (!hints or #hints == 0) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = chat.alpha
	local rowHeight = Sc(28)
	local headerHeight = Sc(26)
	local cut = Sc(12)
	local mouseX, mouseY = self:CursorPos()

	local S = NETWORK.style

	S.Card(0, 0, width, height, alpha, {
		radius = S.Radius("card"),
		blur = false,
		accent = false,
		fill = CARD_FILL
	})

	local caption = util.Upper(L("chatCommands"))

	util.DrawTextSpaced(caption, "nwHudSmall", Sc(16), headerHeight * 0.5,
		ColorAlpha(theme.text, 240 * alpha), Sc(4), TEXT_ALIGN_CENTER)

	local tabHint = util.Upper(L("chatTabHint"))
	local tabWidth = util.TextSpacedSize(tabHint, "nwHudSmall", Sc(2))

	util.DrawTextSpaced(tabHint, "nwHudSmall", width - Sc(16) - tabWidth,
		headerHeight * 0.5, ColorAlpha(theme.textFaint, 215 * alpha), Sc(2),
		TEXT_ALIGN_CENTER)

	if (total > #hints) then
		local railHeight = height - headerHeight - Sc(14)
		local grip = math.max(railHeight * (#hints / total), Sc(20))
		local travel = (railHeight - grip) * (offset / math.max(maximum, 1))

		Pill(width - Sc(7), headerHeight + Sc(6), math.max(Sc(3), 3), railHeight,
			theme.line.r, theme.line.g, theme.line.b, 40 * alpha)
		Pill(width - Sc(7), headerHeight + Sc(6) + travel, math.max(Sc(3), 3), grip,
			theme.accent.r, theme.accent.g, theme.accent.b, 200 * alpha)
	end

	surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 30 * alpha)
	surface.DrawRect(Sc(14), headerHeight, width - Sc(28), 1)

	for i = 1, #hints do
		local hint = hints[i]
		local rowY = headerHeight + Sc(5) + (i - 1) * rowHeight
		local center = rowY + rowHeight * 0.5 - Sc(2)
		local color = hint.color
		local rect = {
			x = Sc(8),
			y = rowY,
			width = width - Sc(16),
			height = rowHeight - Sc(3),
			hint = hint
		}

		self.rows[#self.rows + 1] = rect

		local bHover = mouseX >= rect.x and mouseX <= rect.x + rect.width and
			mouseY >= rect.y and mouseY <= rect.y + rect.height
		local bActive = chat.hintIndex == i + offset

		hint.lit = NETWORK.util.Approach(hint.lit or 0,
			(bHover or bActive) and 1 or 0, 14)

		if (hint.lit > 0.01) then
			RoundBox(S.Radius("cell"), rect.x, rect.y, rect.width, rect.height,
				color.r, color.g, color.b, (bHover and 44 or 28) * hint.lit * alpha)
		end

		Pill(rect.x + Sc(3), rowY + Sc(5), math.max(Sc(3), 2), rowHeight - Sc(13),
			color.r, color.g, color.b, (150 + 100 * hint.lit) * alpha)

		draw.SimpleText(hint.prefix, "nwChatSmall",
			rect.x + Sc(16) + math.Round(hint.lit * Sc(3)), center,
			ColorAlpha(color, 253 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(hint.label, "nwChatSmall", width - Sc(18), center,
			ColorAlpha(theme.textDim, 228 * alpha), TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwChatHints", HINTS, "EditablePanel")

function PANEL:PollHintClick()
	local bDown = input.IsMouseDown(MOUSE_LEFT)
	local bPressed = bDown and !self.bHintMouseDown

	self.bHintMouseDown = bDown

	if (!bPressed or !self.bActive or !IsValid(self.hintPanel)) then
		return
	end

	local mouseX, mouseY = gui.MousePos()
	local panelX, panelY = self.hintPanel:GetPos()
	local rect = self.hintPanel:GetRowAt(mouseX - panelX, mouseY - panelY)

	if (rect) then
		self:ApplyHint(rect.hint)
	end
end

function PANEL:ToggleCommands()
	self:SetCommands(!self.bCommands)
end

function PANEL:SetCommands(bOpen)
	self.bCommands = bOpen and true or false

	if (!self.bCommands) then
		if (IsValid(self.commandPanel)) then
			self.commandPanel:Remove()
		end

		self.commandPanel = nil

		return
	end

	if (!IsValid(self.commandPanel)) then
		local panel = vgui.Create("nwChatCommands")

		panel:SetChat(self)
		panel:SetMouseInputEnabled(true)
		panel:SetKeyboardInputEnabled(false)
		panel:SetZPos(32000)

		self.commandPanel = panel
	end

	self.commandPanel:Refresh(true)
end

function PANEL:UpdateCommands()
	if (!self.bCommands or !self.bActive) then
		if (IsValid(self.commandPanel)) then
			self.commandPanel:Remove()

			self.commandPanel = nil
		end

		return
	end

	if (!IsValid(self.commandPanel)) then
		return self:SetCommands(true)
	end

	local Sc = NETWORK.util.Scale
	local width, height = self:GetSize()
	local boxWidth = Sc(360)
	local boxHeight = math.max(self:GetPlateHeight(), Sc(200))
	local x, y = self:LocalToScreen(width + Sc(14), height - boxHeight)

	if (x + boxWidth > ScrW()) then
		x = select(1, self:LocalToScreen(0, 0)) - boxWidth - Sc(14)
	end

	self.commandPanel:SetSize(boxWidth, boxHeight)
	self.commandPanel:SetPos(math.Clamp(x, 0, ScrW() - boxWidth),
		math.Clamp(y, 0, ScrH() - boxHeight))
end

function PANEL:PollCommandClick()
	local bDown = input.IsMouseDown(MOUSE_LEFT)
	local bPressed = bDown and !self.bCommandMouseDown

	self.bCommandMouseDown = bDown

	if (!bPressed or !self.bActive or !IsValid(self.commandPanel)) then
		return
	end

	local mouseX, mouseY = gui.MousePos()
	local panelX, panelY = self.commandPanel:GetPos()
	local rect = self.commandPanel:GetRowAt(mouseX - panelX, mouseY - panelY)

	if (!rect or !rect.entry) then
		return
	end

	self:FillEntry(rect.entry.prefix .. " ")
	self.commandPanel:Refresh(true)

	NETWORK.sound.Click()
end

function PANEL:UpdateHints()
	local hints = self.bActive and !self.bCommands and self:GetHintWindow()

	if (!hints or #hints == 0) then
		if (IsValid(self.hintPanel)) then
			self.hintPanel:Remove()
		end

		self.hintPanel = nil

		return
	end

	if (!IsValid(self.hintPanel)) then
		local panel = vgui.Create("nwChatHints")

		panel:SetChat(self)

		panel:SetMouseInputEnabled(true)
		panel:SetKeyboardInputEnabled(false)
		panel:SetZPos(32000)

		self.hintPanel = panel
	end

	local Sc = NETWORK.util.Scale
	local width, height = self:GetSize()
	local boxWidth = Sc(330)
	local boxHeight = Sc(26) + #hints * Sc(28) + Sc(10)
	local x, y = self:LocalToScreen(width + Sc(14), height - boxHeight)

	if (x + boxWidth > ScrW()) then
		x = select(1, self:LocalToScreen(0, 0)) - boxWidth - Sc(14)
	end

	self.hintPanel:SetSize(boxWidth, boxHeight)
	self.hintPanel:SetPos(math.Clamp(x, 0, ScrW() - boxWidth),
		math.Clamp(y, 0, ScrH() - boxHeight))
end

function PANEL:GetActiveClass()
	if (!IsValid(self.entry)) then
		return
	end

	local text = self.entry:GetValue() or ""

	if (string.sub(text, 1, 1) != "/") then
		return NETWORK.chat.Get and NETWORK.chat.Get("ic")
	end

	local word = string.match(text, "^(/%a+)")

	if (!word) then
		return
	end

	for _, entry in ipairs(NETWORK.chat.GetPrefixes()) do
		if (entry.prefix == NETWORK.util.Lower(word)) then
			return entry.class
		end
	end
end

function PANEL:PaintPlate(width, height)
	if (self.alpha < 0.01 or !self.bActive) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha
	local line = math.max(Sc(1), 1)

	local class = self.GetActiveClass and self:GetActiveClass()
	local caret = (class and class.color) or theme.combine

	local S = NETWORK.style
	local plateRadius = S.Radius("panel")
	local cellRadius = S.Radius("cell")

	S.Card(0, 0, width, height, alpha, {
		radius = plateRadius,
		blur = false,
		accent = caret,
		fill = PLATE_FILL
	})

	local tabY = Sc(6)
	local tabHeight = Sc(28)
	local cursorX, cursorY = self:CursorPos()

	local function IsOver(rect)
		return cursorX >= rect.x and cursorX <= rect.x + rect.width and
			cursorY >= tabY and cursorY <= tabY + tabHeight
	end

	local function DrawIcon(name, x, y, size, color)
		return DrawIconFile("framework/chat/ui_" .. name .. ".png", x, y, size, color)
	end

	do
		local iconSize = Sc(16)

		DrawIcon("forum", Sc(12), tabY + math.Round((tabHeight - iconSize) * 0.5), iconSize,
			ColorAlpha(caret, 210 * alpha))
	end

	local function DrawTabButton(rect, mode)
		if (!rect) then
			return
		end

		local bCross = mode == "cross"
		local bSlash = mode == "slash"
		local bHover = IsOver(rect)
		local bLit = bSlash and self.bCommands

		if (bLit) then
			RoundBox(cellRadius, rect.x, tabY, rect.width, tabHeight, caret.r, caret.g, caret.b, 46 * alpha)
			RoundBorder(cellRadius, rect.x, tabY, rect.width, tabHeight, caret.r, caret.g, caret.b, 150 * alpha)
		else
			RoundBox(cellRadius, rect.x, tabY, rect.width, tabHeight, 255, 255, 255, (bHover and 22 or 6) * alpha)
		end

		local centerX = rect.x + math.Round(rect.width * 0.5)
		local centerY = tabY + math.Round(tabHeight * 0.5)
		local arm = Sc(5)
		local color = ColorAlpha(bLit and caret or (bHover and theme.text or theme.textDim), 250 * alpha)
		local iconSize = Sc(16)
		local iconName = bSlash and "code" or bCross and "clear" or "add"

		if (DrawIcon(iconName, centerX - math.Round(iconSize * 0.5),
			centerY - math.Round(iconSize * 0.5), iconSize, color)) then
			return
		end

		if (bSlash) then
			draw.SimpleText("/", "nwHud", centerX, centerY,
				color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		elseif (bCross) then
			util.DrawThickLine(centerX - arm, centerY - arm, centerX + arm,
				centerY + arm, line, color)
			util.DrawThickLine(centerX + arm, centerY - arm, centerX - arm,
				centerY + arm, line, color)
		else
			surface.SetDrawColor(color.r, color.g, color.b, color.a)
			surface.DrawRect(centerX - arm, centerY - math.floor(line * 0.5), arm * 2, line)
			surface.DrawRect(centerX - math.floor(line * 0.5), centerY - arm, line, arm * 2)
		end
	end

	DrawTabButton(self.plusRect, "plus")
	DrawTabButton(self.clearRect, "cross")
	DrawTabButton(self.cmdRect, "slash")

	local underline = math.max(Sc(2), 2)
	local accent = theme.combine

	surface.SetFont("nwSideNav")

	for _, rect in ipairs(self:GetTabRects()) do
		local bActive = self.tab == rect.tab.id
		local bHover = IsOver(rect)
		local label = self:GetTabLabel(rect.tab)
		local labelWidth = surface.GetTextSize(label)
		local centerX = rect.x + math.Round(rect.width * 0.5)
		local reveal = rect.reveal or 1

		if (bHover and !bActive) then
			RoundBox(cellRadius, rect.x, tabY + Sc(2), rect.width, tabHeight - Sc(4),
				255, 255, 255, 12 * alpha * reveal)
		end

		draw.SimpleText(label, "nwSideNav", centerX, tabY + math.Round(tabHeight * 0.5) - Sc(1),
			ColorAlpha(bActive and theme.text or (bHover and theme.text or theme.textDim),
				(bActive and 250 or 225) * alpha * reveal),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		if (bActive) then
			local lineWidth = math.min(labelWidth + Sc(6), rect.width)

			Pill(centerX - math.Round(lineWidth * 0.5), tabY + tabHeight - underline - Sc(1),
				lineWidth, underline, accent.r, accent.g, accent.b, 240 * alpha * reveal)
		end

		local unread = rect.tab.unread or 0

		if (!bActive and unread > 0) then
			local dot = math.max(Sc(6), 4)
			local dotX = math.min(centerX + math.Round(labelWidth * 0.5) + Sc(3), rect.x + rect.width - dot)

			RoundBox(math.floor(dot * 0.5), dotX, tabY + Sc(6), dot, dot,
				AMBER.r, AMBER.g, AMBER.b, 245 * alpha * reveal)
		end
	end

	Pill(plateRadius, tabY + tabHeight + Sc(5), width - plateRadius * 2, line,
		255, 255, 255, 14 * alpha)

	if (self.total > self.listHeight) then
		local fraction = self.listHeight / self.total
		local barHeight = math.max(self.listHeight * fraction, Sc(20))
		local offset = self.scroll / math.max(self.total - self.listHeight, 1)

		local barWidth = math.max(Sc(3), 3)
		local barX = width - Sc(9)
		local barY = self.listY + (self.listHeight - barHeight) * (1 - offset)

		Pill(barX, self.listY, barWidth, self.listHeight, 255, 255, 255, 12 * alpha)
		Pill(barX, barY, barWidth, barHeight, caret.r, caret.g, caret.b, 190 * alpha)
	end

	if (self.scroll > 0) then
		local size = Sc(26)
		local buttonX = width - Sc(18) - size
		local buttonY = self.listY + self.listHeight - size - Sc(6)
		local bHover = cursorX >= buttonX and cursorX <= buttonX + size and
			cursorY >= buttonY and cursorY <= buttonY + size
		local radius = math.floor(size * 0.5)

		self.downRect = {x = buttonX, y = buttonY, width = size, height = size}

		RoundBox(radius, buttonX, buttonY, size, size, 12, 15, 19, 235 * alpha)
		RoundBorder(radius, buttonX, buttonY, size, size, caret.r, caret.g, caret.b,
			(bHover and 200 or 110) * alpha)

		DrawIcon("down", buttonX + Sc(5), buttonY + Sc(5), size - Sc(10),
			ColorAlpha(bHover and theme.text or caret, 240 * alpha))
	else
		self.downRect = nil
	end

	for i = 0, 2 do
		local size = math.max(Sc(2), 2)

		RoundBox(math.floor(size * 0.5), width - Sc(9) - i * Sc(5), height - Sc(9) + i * Sc(2),
			size, size, 255, 255, 255, (100 - i * 28) * alpha)
	end

	local inputY = height - self.inputHeight
	local bFocus = IsValid(self.entry) and self.entry:HasFocus()

	Pill(plateRadius, inputY, width - plateRadius * 2, line,
		bFocus and caret.r or 255, bFocus and caret.g or 255, bFocus and caret.b or 255,
		(bFocus and 90 or 16) * alpha)

	local badgeWidth = Sc(52)

	local badgeHeight = self.inputHeight - Sc(14)
	local badgeX = width - Sc(12) - badgeWidth
	local badgeY = inputY + Sc(5)
	local badgeRadius = math.floor(badgeHeight * 0.5)
	local current = NETWORK.lang.GetCurrent and NETWORK.lang.GetCurrent() or "ru"
	local bLangHover = cursorX >= badgeX and cursorX <= badgeX + badgeWidth and
		cursorY >= badgeY and cursorY <= badgeY + badgeHeight

	self.langRect = {x = badgeX, y = badgeY, width = badgeWidth, height = badgeHeight}

	RoundBox(badgeRadius, badgeX, badgeY, badgeWidth, badgeHeight, 255, 255, 255,
		(bLangHover and 24 or 10) * alpha)
	RoundBorder(badgeRadius, badgeX, badgeY, badgeWidth, badgeHeight, 255, 255, 255,
		(bLangHover and 70 or 30) * alpha)

	local langIcon = Sc(14)
	local bLangIcon = DrawIcon("translate", badgeX + Sc(7), badgeY + math.Round((badgeHeight - langIcon) * 0.5),
		langIcon, ColorAlpha(theme.textDim, 220 * alpha))

	draw.SimpleText(util.Upper(current), "nwInvKey",
		bLangIcon and (badgeX + badgeWidth - Sc(9)) or (badgeX + math.Round(badgeWidth * 0.5)),
		badgeY + math.Round(badgeHeight * 0.5), ColorAlpha(bLangHover and theme.text or theme.textDim, 240 * alpha),
		bLangIcon and TEXT_ALIGN_RIGHT or TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local sendSize = badgeHeight
	local sendX = badgeX - Sc(6) - sendSize
	local bText = IsValid(self.entry) and string.Trim(self.entry:GetText() or "") != ""
	local bSendHover = cursorX >= sendX and cursorX <= sendX + sendSize and
		cursorY >= badgeY and cursorY <= badgeY + badgeHeight

	self.sendRect = {x = sendX, y = badgeY, width = sendSize, height = sendSize}

	RoundBox(badgeRadius, sendX, badgeY, sendSize, sendSize, caret.r, caret.g, caret.b,
		((bText or bSendHover) and 56 or 12) * alpha)
	RoundBorder(badgeRadius, sendX, badgeY, sendSize, sendSize, caret.r, caret.g, caret.b,
		(bText and 160 or 50) * alpha)

	DrawIcon("send", sendX + Sc(5), badgeY + Sc(5), sendSize - Sc(10),
		ColorAlpha(bText and theme.text or theme.textDim, (bText and 250 or 140) * alpha))

	self:PaintPreview(width, inputY - self:GetPreviewHeight(), self:GetPreviewHeight(), caret)
end

function PANEL:PaintPreview(width, y, height, caret)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local alpha = self.alpha
	local text = IsValid(self.entry) and self.entry:GetValue() or ""
	local centerY = y + math.Round(height * 0.5)
	local line = math.max(Sc(1), 1)

	surface.SetFont("nwChatSmall")

	local command

	if (string.sub(text, 1, 1) == "/") then
		local name = string.match(text, "^/(%S+)")

		command = name and NETWORK.command.Get(name)

		if (command and !string.find(text, " ")) then

			command = nil
		end
	end

	if (!command) then
		local id = NETWORK.chat.Parse(LocalPlayer(), text)
		local class = NETWORK.chat.Get(id)

		local hints = {
			{key = "Esc", text = L("chatHintClose")}
		}

		if (class and class.radius) then
			hints[#hints + 1] = {text = L("chatHintRadius", math.Round(class.radius / 40))}
		end

		local x = Sc(14)
		local keyHeight = height - Sc(8)
		local keyY = y + Sc(4)

		for _, hint in ipairs(hints) do
			local keyWidth = 0

			if (hint.key) then
				surface.SetFont("nwChatStamp")
				keyWidth = surface.GetTextSize(hint.key) + Sc(8)
			end

			surface.SetFont("nwChatStamp")

			local textWidth = surface.GetTextSize(hint.text)
			local total = keyWidth + (hint.key and Sc(5) or 0) + textWidth

			if (x + total > width - Sc(14)) then
				break
			end

			if (hint.key) then
				local keyRadius = NETWORK.style.Radius("chip")

				RoundBox(keyRadius, x, keyY, keyWidth, keyHeight, 255, 255, 255, 10 * alpha)
				RoundBorder(keyRadius, x, keyY, keyWidth, keyHeight, 255, 255, 255, 46 * alpha)

				draw.SimpleText(hint.key, "nwChatStamp", x + math.Round(keyWidth * 0.5), centerY,
					ColorAlpha(theme.textDim, 240 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				x = x + keyWidth + Sc(5)
			end

			draw.SimpleText(hint.text, "nwChatStamp", x, centerY,
				ColorAlpha(theme.textFaint, 200 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			x = x + textWidth + Sc(14)
		end

		return
	end

	local parts = string.Explode(" ", text)
	local given = #parts - 1
	local boxes = {{label = "/" .. (command.id or string.match(text, "^/(%S+)")), state = "name"}}

	for token in string.gmatch(command.usage or "", "([<%[][^>%]]+[>%]])") do
		boxes[#boxes + 1] = {
			label = token,
			bOptional = string.sub(token, 1, 1) == "[",
			state = "arg"
		}
	end

	local x = Sc(14)
	local boxHeight = height - Sc(6)
	local boxY = y + Sc(3)

	for index, box in ipairs(boxes) do
		local textWidth = surface.GetTextSize(box.label)
		local boxWidth = textWidth + Sc(12)
		local argIndex = index - 1
		local bFilled = box.state == "name" or argIndex < given or
			(argIndex == given and (parts[#parts] or "") != "")

		if (x + boxWidth > width - Sc(14)) then
			break
		end

		local boxRadius = NETWORK.style.Radius("chip")

		if (bFilled) then
			RoundBox(boxRadius, x, boxY, boxWidth, boxHeight, caret.r, caret.g, caret.b,
				(box.bOptional and 150 or 215) * alpha)

			draw.SimpleText(box.label, "nwChatSmall", x + Sc(6), centerY,
				Color(10, 12, 14, 255 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		else
			draw.SimpleText(box.label, "nwChatSmall", x + Sc(6), centerY,
				ColorAlpha(box.bOptional and theme.textFaint or theme.textDim, 235 * alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		RoundBorder(boxRadius, x, boxY, boxWidth, boxHeight, caret.r, caret.g, caret.b,
			(box.bOptional and !bFilled and 70 or 120) * alpha)

		if (box.state == "arg" and argIndex == given) then
			Pill(x + boxRadius, boxY + boxHeight, boxWidth - boxRadius * 2, math.max(Sc(2), 2),
				caret.r, caret.g, caret.b, 240 * alpha)
		end

		x = x + boxWidth + Sc(6)
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale

	self:PaintPlate(width, height)

	local x = self.listX
	local y = self.listY + self.listHeight + self.scroll
	local screenX, screenY = self:LocalToScreen(0, self.listY)
	local cursorX, cursorY = self:CursorPos()

	self.messageRects = {}
	self.actionRects = {}

	local activeClass = self.bActive and self.GetActiveClass and self:GetActiveClass()
	local activeId = activeClass and activeClass.id
	local lowerClass
	local line = math.max(Sc(1), 1)

	local stampWidth = self:GetStampWidth()
	local bodyX = x + stampWidth
	local rowRadius = NETWORK.style.Radius("cell")
	local rail = math.max(Sc(2), 2)
	local stampColor = NETWORK.theme.textFaint
	local accent = NETWORK.theme.combine
	local menu = NETWORK.gui.chatMenu
	local menuMessage = IsValid(menu) and menu:GetParent() == self and menu.message or nil
	local lineHeight = draw.GetFontHeight(self:GetChatFont())

	render.SetScissorRect(screenX, screenY, screenX + width, screenY + self.listHeight, true)

	for i = #self.messages, 1, -1 do
		local message = self.messages[i]

		if (!self:PassesTab(message)) then
			continue
		end

		y = y - message.height

		if (y + message.height < self.listY) then
			break
		end

		local alpha = 255

		if (!self.bActive) then
			local age = CurTime() - message.time

			if (age > self.holdTime + self.fadeTime) then
				break
			end

			if (age > self.holdTime) then
				alpha = 255 * (1 - (age - self.holdTime) / self.fadeTime)
			end
		end

		alpha = math.max(alpha, 255 * self.alpha)

		if (alpha > 1) then
			do
				self.messageRects[#self.messageRects + 1] = {
					x = bodyX - Sc(6),
					y = y,
					width = self.listWidth - stampWidth,
					height = message.height,
					text = message.plain or "",
					message = message
				}

			end

			local classTable = NETWORK.chat.Get(message.class or message.id or "ic")
			local barColor = classTable and classTable.color or NETWORK.theme.textFaint

			local firstLine = message.object and message.object.lines and message.object.lines[1]
			local firstHeight = firstLine and firstLine.height or lineHeight

			if ((message.iconIndent or message.indent) > 0) then
				local material = message.icon and NETWORK.util.GetMaterial(message.icon, "smooth")
				local size = Sc(20)
				local x = bodyX
				local iconY = y + math.max(math.Round((math.min(firstHeight,
					message.height) - size) * 0.5), 0) + Sc(1)

				if (material and !material:IsError()) then
					local bTint = NETWORK.chat.IsTintedIcon and NETWORK.chat.IsTintedIcon(message.icon)
					local tint = bTint and barColor or color_white

					surface.SetMaterial(material)
					surface.SetDrawColor(0, 0, 0, alpha * 0.6)
					surface.DrawTexturedRect(x + 1, iconY + 1, size, size)
					surface.SetDrawColor(tint.r, tint.g, tint.b, alpha)
					surface.DrawTexturedRect(x, iconY, size, size)
				else
					local label = NETWORK.util.Upper(NETWORK.util.Sub(L("chatName" ..
						(message.class or message.id or "ic")), 1, 1))

					RoundBox(NETWORK.style.Radius("chip"), x, iconY, size, size,
						barColor.r, barColor.g, barColor.b, alpha * 0.25)

					draw.SimpleText(label, "nwInvKey", x + math.Round(size * 0.5),
						iconY + math.Round(size * 0.5), ColorAlpha(barColor, alpha),
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end

			local object = message.object
			local shadow = message.shadow

			if (i == #self.messages and message.typed and
				message.typed < (message.visible or 0)) then
				local typed = math.floor((CurTime() - message.typeTime) *
					TYPE_SPEED)

				message.typed = math.min(typed, message.visible)

				if (message.typed < message.visible) then
					if (message.typedAt != message.typed) then
						message.typedAt = message.typed

						local partial = SubMarkup(message.text, message.typed)

						message.typedObject = self:ParseLine(partial, message.indent)
					end

					object = message.typedObject or object
				end
			end

			local messageClass = message.class or message.id

			if (lowerClass != nil and lowerClass != messageClass) then
				Pill(x - Sc(4), y + message.height - line, self.listWidth + Sc(2), line,
					255, 255, 255, 6 * alpha / 255)
			end

			lowerClass = messageClass

			local range = self:GetSelectionRange(i, object)
			local rowX = x - Sc(8)
			local rowWidth = self.listWidth + Sc(10)
			local railX = rowX + Sc(2)
			local railY = y + Sc(3)
			local railHeight = message.height - Sc(6)
			local bHover = self.bActive and cursorX >= x - Sc(12) and cursorX <= x + self.listWidth and
				cursorY >= y and cursorY <= y + message.height

			if (self.bActive and (range or menuMessage == message)) then
				RoundBox(rowRadius, rowX, y, rowWidth, message.height,
					accent.r, accent.g, accent.b, 26 * self.alpha)
				Pill(railX, railY, rail, railHeight, accent.r, accent.g, accent.b, 230 * self.alpha)
			elseif (bHover) then
				RoundBox(rowRadius, rowX, y, rowWidth, message.height,
					barColor.r, barColor.g, barColor.b, 16 * self.alpha)
				Pill(railX, railY, rail, railHeight, barColor.r, barColor.g, barColor.b, 200 * self.alpha)
			elseif (activeId and activeId == messageClass) then
				Pill(railX, railY, rail, railHeight, barColor.r, barColor.g, barColor.b, 60 * self.alpha)
			end

			if (message.stamp) then
				local stampAlpha = (self.bActive and 170 or 120) * alpha / 255

				draw.SimpleText(message.stamp, STAMP_FONT, x + 1, y + firstHeight - Sc(1) + 1,
					ColorAlpha(color_black, stampAlpha * 0.8), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(message.stamp, STAMP_FONT, x, y + firstHeight - Sc(1),
					ColorAlpha(stampColor, stampAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			end

			if (message.freq) then
				local chipX = bodyX + (message.iconIndent or 0)
				local chipHeight = math.min(draw.GetFontHeight(FREQ_FONT) + Sc(4), firstHeight)
				local chipY = y + math.max(math.Round((firstHeight - chipHeight) * 0.5), 0) + Sc(1)
				local chipWidth = (message.indent or 0) - (message.iconIndent or 0) - Sc(6)
				local chipRadius = math.floor(chipHeight * 0.5)

				RoundBox(chipRadius, chipX, chipY, chipWidth, chipHeight,
					barColor.r, barColor.g, barColor.b, 40 * alpha / 255)
				RoundBorder(chipRadius, chipX, chipY, chipWidth, chipHeight,
					barColor.r, barColor.g, barColor.b, 130 * alpha / 255)

				draw.SimpleText(message.freq, FREQ_FONT, chipX + math.Round(chipWidth * 0.5),
					chipY + math.Round(chipHeight * 0.5), ColorAlpha(barColor, alpha),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			local textX = bodyX + (message.indent or 0)

			if (range) then
				object:DrawSelection(textX, y, range[1], range[2],
					ColorAlpha(accent, 90 * self.alpha), NETWORK.style.Radius("chip"))
			end

			object:Draw(textX, y, alpha, true)

			if (message.action) then
				self.actionRects = self.actionRects or {}

				self.actionRects[#self.actionRects + 1] = {
					x = x,
					y = y,
					width = self.listWidth,
					height = message.height,
					message = message
				}
			end
		end
	end

	render.SetScissorRect(0, 0, 0, 0, false)
end

function PANEL:RebuildMessages()
	for _, message in ipairs(self.messages) do
		message.object = self:ParseLine(message.text, message.indent)
		message.shadow = nil
		message.height = message.object:GetHeight() + NETWORK.util.Scale(4)
		message.typedObject = nil
		message.typedShadow = nil
		message.typedAt = nil
		message.typed = message.visible
	end

	self:InvalidateLayout(true)
end

local function RefreshChat()
	if (IsValid(NETWORK.gui.chat)) then
		NETWORK.gui.chat:RebuildMessages()
	end
end

cvars.AddChangeCallback("network_chat_font", RefreshChat, "nwChatboxFont")
cvars.AddChangeCallback("network_chat_size", RefreshChat, "nwChatboxSize")

function PANEL:OnRemove()
	if (IsValid(self.hintPanel)) then
		self.hintPanel:Remove()
	end

	if (IsValid(self.commandPanel)) then
		self.commandPanel:Remove()
	end

	self.hintPanel = nil
	self.commandPanel = nil
end

vgui.Register("nwChatbox", PANEL, "EditablePanel")

concommand.Add("network_chat_reset", function()
	file.Delete(dataPath)

	NETWORK.chat.Create()
end)
