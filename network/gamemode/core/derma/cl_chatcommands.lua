local PANEL = {}

PANEL.rowHeight = 30

function PANEL:Init()
	self:SetMouseInputEnabled(true)
	self:SetKeyboardInputEnabled(false)
	self:NoClipping(true)
	self:SetCursor("hand")

	self.rows = {}
	self.offset = 0
	self.list = {}
	self.listText = nil
end

function PANEL:SetChat(chat)
	self.chat = chat
end

function PANEL:GetChat()
	return IsValid(self.chat) and self.chat or nil
end

function PANEL:Build(filter)
	local client = LocalPlayer()
	local bAdmin = IsValid(client) and client:IsAdmin()
	local list = {}
	local seen = {}

	filter = NETWORK.util.Lower(string.Trim(filter or ""))

	if (string.sub(filter, 1, 1) == "/") then
		filter = string.sub(filter, 2)
	end

	filter = string.match(filter, "^(%S*)") or ""

	local function Fits(prefix, label)
		if (filter == "") then
			return true
		end

		return string.find(NETWORK.util.Lower(prefix), filter, 1, true) != nil or
			string.find(NETWORK.util.Lower(label or ""), filter, 1, true) != nil
	end

	for _, entry in ipairs(NETWORK.chat.GetPrefixes()) do
		local label = L("chatName" .. entry.class.id)

		if (!seen[entry.prefix] and Fits(entry.prefix, label)) then
			seen[entry.prefix] = true

			list[#list + 1] = {
				prefix = entry.prefix,
				label = label,
				color = entry.class.color,
				group = "chatCmdSpeech",
				order = 1
			}
		end
	end

	for id, command in pairs(NETWORK.command.stored or {}) do
		local prefix = "/" .. id

		if (seen[prefix] or (command.adminOnly and !bAdmin)) then
			continue
		end

		local label = command.description and L(command.description) or ""

		if (label == command.description) then
			label = ""
		end

		if (label == "" and command.usage) then
			label = string.gsub(command.usage, "^/%S+%s*", "")
		end

		if (!Fits(prefix, label)) then
			continue
		end

		seen[prefix] = true

		list[#list + 1] = {
			prefix = prefix,
			label = label != "" and label or L("chatCommand"),
			usage = command.usage,
			color = command.adminOnly and NETWORK.theme.value or NETWORK.theme.accentSoft,
			group = command.adminOnly and "chatCmdAdmin" or "chatCmdCommon",
			order = command.adminOnly and 3 or 2
		}
	end

	table.sort(list, function(a, b)
		if (a.order != b.order) then
			return a.order < b.order
		end

		return a.prefix < b.prefix
	end)

	return list
end

function PANEL:Refresh(bForce)
	local chat = self:GetChat()
	local text = chat and IsValid(chat.entry) and chat.entry:GetValue() or ""

	if (!bForce and self.listText == text) then
		return
	end

	self.listText = text
	self.list = self:Build(text)
	self.offset = 0
end

function PANEL:Rows()
	local Sc = NETWORK.util.Scale

	return math.max(math.floor((self:GetTall() - Sc(46)) / Sc(self.rowHeight)), 1)
end

function PANEL:GetRowAt(x, y)
	for _, rect in ipairs(self.rows) do
		if (x >= rect.x and x <= rect.x + rect.width and
			y >= rect.y and y <= rect.y + rect.height) then
			return rect
		end
	end
end

function PANEL:OnMouseWheeled(delta)
	local maximum = math.max(#self.list - self:Rows(), 0)

	self.offset = math.Clamp(self.offset - delta, 0, maximum)

	return true
end

function PANEL:OnMousePressed()
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

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local radius = math.max(Sc(10), 6)

	self:Refresh()

	self.rows = {}

	util.DrawBlurRounded(self, 0, 0, width, height, radius, 4)

	draw.RoundedBox(radius, 0, 0, width, height, Color(8, 9, 10, 215))

	util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
		Color(255, 255, 255, 20))

	draw.SimpleText(util.Upper(L("chatCmdTitle")), "nwSideNav", Sc(14), Sc(14),
		theme.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(#self.list, "nwHudSmall", width - Sc(14), Sc(14),
		theme.textFaint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 18)
	surface.DrawRect(Sc(12), Sc(28), width - Sc(24), 1)

	local rows = self:Rows()
	local maximum = math.max(#self.list - rows, 0)

	self.offset = math.Clamp(self.offset, 0, maximum)

	local rowHeight = Sc(self.rowHeight)
	local y = Sc(34)
	local cursorX, cursorY = self:CursorPos()
	local group

	for index = self.offset + 1, math.min(self.offset + rows, #self.list) do
		local entry = self.list[index]
		local bHover = cursorX >= 0 and cursorX <= width and
			cursorY >= y and cursorY <= y + rowHeight

		if (entry.group != group) then
			group = entry.group

			draw.SimpleText(util.Upper(L(group)), "nwHudSmall", Sc(14),
				y + Sc(2), theme.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		self.rows[#self.rows + 1] = {
			x = 0,
			y = y,
			width = width,
			height = rowHeight,
			entry = entry
		}

		if (bHover) then
			draw.RoundedBox(math.max(Sc(5), 3), Sc(8), y + Sc(1), width - Sc(16),
				rowHeight - Sc(3), ColorAlpha(entry.color or theme.combine, 26))
		end

		draw.SimpleText(entry.prefix, "nwHud", Sc(16), y + math.Round(rowHeight * 0.5),
			entry.color or theme.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local label = entry.label or ""

		surface.SetFont("nwHudSmall")

		local space = width - Sc(30) - select(1, surface.GetTextSize(entry.prefix)) - Sc(14)

		while (label != "" and select(1, surface.GetTextSize(label)) > space) do
			label = string.sub(label, 1, string.len(label) - 2)
		end

		draw.SimpleText(label, "nwHudSmall", width - Sc(14),
			y + math.Round(rowHeight * 0.5), bHover and theme.text or theme.textDim,
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		y = y + rowHeight
	end

	if (#self.list == 0) then
		draw.SimpleText(L("chatCmdEmpty"), "nwHudSmall", math.Round(width * 0.5),
			math.Round(height * 0.5), theme.textFaint, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end

	if (maximum > 0) then
		local track = height - Sc(44)
		local barHeight = math.max(track * (rows / #self.list), Sc(20))
		local travel = (track - barHeight) * (self.offset / maximum)
		local barWidth = math.max(Sc(3), 2)

		draw.RoundedBox(math.floor(barWidth * 0.5), width - Sc(7), Sc(34), barWidth,
			track, Color(255, 255, 255, 12))
		draw.RoundedBox(math.floor(barWidth * 0.5), width - Sc(7), Sc(34) + travel,
			barWidth, barHeight, ColorAlpha(theme.combine, 170))
	end
end

vgui.Register("nwChatCommands", PANEL, "EditablePanel")
