local function StyleScroll(scroll)
	local Sc = NETWORK.util.Scale
	local bar = scroll:GetVBar()

	bar:SetWide(Sc(4))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(2), 0, 0, width, height, Color(255, 255, 255, 70))
	end
end

local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.escape = self

	self.alpha = 0
	self.bClosing = false
	self.startTime = CurTime()
	self.buttons = {}
	self.sections = {}
	self.pane = nil
	self.paneShow = 0
	self.current = nil

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self:AddSection("escapeResume", function()
		self:Close()
	end)

	self:AddSection("escapeCharacters", function()
		self:Close()

		timer.Simple(0.2, function()
			NETWORK.gui.OpenMainMenu()
		end)
	end)

	self:AddSection("escapeSkills", nil, "skills")
	self:AddSection("escapeHelp", nil, "help")
	self:AddSection("escapeBinds", nil, "binds")
	self:AddSection("escapeSettings", nil, "settings")

	self:AddSection("escapeGame", function()
		self:Close()

		NETWORK.gui.bAllowPause = true

		timer.Simple(0.1, function()
			gui.ActivateGameUI()
		end)
	end)

	self:AddSection("escapeDisconnect", function()
		self:Close()

		timer.Simple(0.35, function()
			RunConsoleCommand("disconnect")
		end)
	end, nil, true)
end

function PANEL:OnRemove()
	if (NETWORK.gui.escape == self) then
		NETWORK.gui.escape = nil
	end
end

function PANEL:AddSection(key, action, page, bDanger)
	local index = #self.sections + 1
	local button = self:Add("nwMenuButton")

	button:SetLabel(L(key))
	button:SetAlign("left")
	button:SetFontName("nwMenuSection")
	button:SetRevealDelay(0.05 + index * 0.05)
	button:SetDanger(bDanger)
	button.DoClick = function()
		if (page) then
			self:OpenPage(page)

			return
		end

		action()
	end

	self.sections[index] = {key = key, page = page, button = button}
	self.buttons[index] = button

	self:InvalidateLayout(true)

	return button
end

function PANEL:OpenPage(id)
	if (self.current == id) then
		self:ClosePage()

		return
	end

	if (IsValid(self.pane)) then
		self.pane:Remove()
	end

	self.current = id
	self.lastPage = id

	self:UpdateActive()

	local pane = self:Add("EditablePanel")

	self.pane = pane

	local builder = self["BuildPage" .. string.upper(string.sub(id, 1, 1)) ..
		string.sub(id, 2)]

	self:InvalidateLayout(true)

	if (isfunction(builder)) then
		builder(self, pane)
	end

	self:InvalidateLayout(true)
end

function PANEL:UpdateActive()
	for _, section in ipairs(self.sections) do
		if (IsValid(section.button)) then
			section.button:SetActive(section.page != nil and
				section.page == self.current)
		end
	end
end

function PANEL:ClosePage()
	self.current = nil

	self:UpdateActive()

	if (IsValid(self.pane)) then
		local pane = self.pane

		pane:SetMouseInputEnabled(false)

		timer.Simple(0.35, function()
			if (IsValid(pane)) then
				pane:Remove()
			end
		end)
	end

	self.pane = nil
end

function PANEL:Measure()
	local Sc = NETWORK.util.Scale
	local widest = Sc(200)

	surface.SetFont("nwMenuSection")

	for _, section in ipairs(self.sections) do
		local width = surface.GetTextSize(NETWORK.util.Upper(L(section.key)))

		widest = math.max(widest, width)
	end

	return math.min(widest + Sc(44), Sc(360))
end

function PANEL:GetHeaderBottom()
	local Sc = NETWORK.util.Scale

	surface.SetFont("nwMenuGhost")

	local _, titleHeight = surface.GetTextSize("NETWORK")

	return math.min(Sc(64), math.Round(self:GetTall() * 0.07)) + titleHeight +
		Sc(46)
end

function PANEL:GetPaneRect()
	local Sc = NETWORK.util.Scale
	local width, height = self:GetSize()
	local margin = math.min(Sc(56), math.Round(width * 0.05))
	local columnX = self.listX or margin
	local columnWidth = self.columnWidth or Sc(300)

	local paneX = columnX + columnWidth + Sc(40)
	local paneWidth = width - margin - paneX

	local minimum = math.min(Sc(760), math.Round(width * 0.54))

	if (paneWidth < minimum) then
		paneWidth = minimum
		paneX = width - margin - paneWidth
	end

	local top = self:GetHeaderBottom()

	return paneX, top, paneWidth, height - top - margin
end

function PANEL:PerformLayout(width, height)
	if (!self.buttons) then
		return
	end

	local Sc = NETWORK.util.Scale
	local rowHeight = Sc(50)
	local margin = math.min(Sc(56), math.Round(width * 0.05))
	local total = #self.buttons * rowHeight
	local top = self:GetHeaderBottom()

	self.columnWidth = self:Measure()
	self.listX = margin + Sc(20)

	self.listY = math.max(top + math.Round((height - top - margin - total) * 0.5),
		top + Sc(10))
	self.listHeight = total

	for i = 1, #self.buttons do
		self.buttons[i]:SetSize(self.columnWidth, rowHeight)
		self.buttons[i]:SetPos(self.listX, self.listY + (i - 1) * rowHeight)
	end

	if (IsValid(self.pane)) then
		local paneX, paneY, paneWidth, paneHeight = self:GetPaneRect()

		self.pane:SetPos(paneX, paneY)
		self.pane:SetSize(paneWidth, paneHeight)
	end
end

function PANEL:BuildPageHelp(pane)
	local Sc = NETWORK.util.Scale

	pane.category = pane.category or "commands"
	pane.tabs = {}

	for index, data in ipairs(NETWORK.help.categories) do
		local button = pane:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button.hover = 0
		button.data = data
		button.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover,
				panel:IsHovered() and 1 or 0, 10)
		end
		button.OnCursorEntered = function()
			NETWORK.sound.TabHover()
		end
		button.Paint = function(panel, width, height)
			local theme = NETWORK.theme
			local bActive = pane.category == data.id
			local strength = math.max(NETWORK.util.EaseInOut(panel.hover),
				bActive and 1 or 0)
			local radius = math.max(Sc(6), 4)

			draw.RoundedBox(radius, 0, 0, width, height,
				Color(255, 255, 255, (8 + 16 * strength) * self.alpha))

			if (bActive) then
				draw.RoundedBox(radius, 0, height - math.max(Sc(2), 2), width,
					math.max(Sc(2), 2),
					ColorAlpha(theme.combine, 245 * self.alpha))
			end

			draw.SimpleText(NETWORK.util.Upper(L(data.name)),
				"nwHudLabelSmall", math.Round(width * 0.5),
				math.Round(height * 0.5),
				ColorAlpha(strength > 0.1 and theme.text or theme.textDim,
					250 * self.alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			NETWORK.sound.TabPress()

			pane.category = data.id

			self:FillHelp(pane)
			pane:InvalidateLayout(true)
		end

		pane.tabs[index] = button
	end

	pane.search = NETWORK.gui.BindEntry(pane:Add("DTextEntry"))
	pane.search:SetFont("nwChatSmall")
	pane.search:SetPaintBackground(false)
	pane.search:SetUpdateOnType(true)
	pane.search:SetTextColor(NETWORK.theme.text)
	pane.search:SetCursorColor(NETWORK.theme.combine)
	pane.search.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(8), 0, 0, width, height,
			Color(255, 255, 255, panel:HasFocus() and 22 or 12))

		if (panel:GetValue() == "") then
			draw.SimpleText(L("helpSearch"), "nwChatSmall", Sc(12),
				math.Round(height * 0.5),
				ColorAlpha(NETWORK.theme.textFaint, 200),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.accentDeep,
			NETWORK.theme.combine)
	end
	pane.search.OnValueChange = function()
		self:FillHelp(pane)
	end

	pane.list = pane:Add("DScrollPanel")

	StyleScroll(pane.list)

	pane.PerformLayout = function(panel, width, height)
		local tabWidth = math.floor((width - Sc(52) -
			Sc(6) * (#panel.tabs - 1)) / math.max(#panel.tabs, 1))
		local tabX = Sc(26)

		for _, button in ipairs(panel.tabs) do
			button:SetSize(tabWidth, Sc(30))
			button:SetPos(tabX, Sc(62))

			tabX = tabX + tabWidth + Sc(6)
		end

		local bSearch = panel.category == "commands" or
			panel.category == "phrases"

		panel.search:SetVisible(bSearch)
		panel.search:SetPos(Sc(26), Sc(102))
		panel.search:SetSize(width - Sc(52), Sc(34))

		local listY = bSearch and Sc(146) or Sc(104)

		panel.list:SetPos(Sc(26), listY)
		panel.list:SetSize(width - Sc(52), height - listY - Sc(20))
	end

	self:FillHelp(pane)
end

function PANEL:AddHelpRow(pane, title, note, body, color, callback)
	local Sc = NETWORK.util.Scale
	local lines = body and body != "" and
		NETWORK.util.WrapText(body, "nwChatSmall", pane.list:GetWide() - Sc(28), 4)
		or {}
	local row = pane.list:Add(callback and "DButton" or "DPanel")

	row:Dock(TOP)
	row:DockMargin(0, 0, 0, Sc(6))
	row:SetTall(Sc(30) + #lines * Sc(16))

	if (callback) then
		row:SetText("")
		row:SetCursor("hand")
		row.DoClick = callback
	end

	row.hover = 0
	row.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover,
			panel:IsHovered() and 1 or 0, 10)
	end
	row.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local hover = NETWORK.util.EaseInOut(panel.hover)

		draw.RoundedBox(Sc(6), 0, 0, width, height,
			Color(255, 255, 255, (8 + 10 * hover) * self.alpha))

		draw.SimpleText(title, "nwHudLabel", Sc(14), Sc(15),
			ColorAlpha(color or theme.text, 250 * self.alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (note and note != "") then
			draw.SimpleText(note, "nwHudLabelSmall", width - Sc(14), Sc(15),
				ColorAlpha(theme.textFaint, 230 * self.alpha),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		for index, line in ipairs(lines) do
			draw.SimpleText(line, "nwChatSmall", Sc(14),
				Sc(32) + (index - 1) * Sc(16),
				ColorAlpha(theme.textDim, 225 * self.alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	return row
end

function PANEL:AddCreditRow(pane, index, entry)
	local Sc = NETWORK.util.Scale
	local about = entry.about or ""
	local lines = about != "" and
		NETWORK.util.WrapText(about, "nwCreditAbout", math.Round(pane.list:GetWide() * 0.45), 3)
		or {}
	local row = pane.list:Add("DPanel")

	row:Dock(TOP)
	row:DockMargin(0, 0, 0, Sc(6))
	row:SetTall(math.max(Sc(54), Sc(16) + #lines * Sc(17) + Sc(12)))

	row.hover = 0
	row.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover,
			panel:IsHovered() and 1 or 0, 10)
	end
	row.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local hover = NETWORK.util.EaseInOut(panel.hover)
		local alpha = self.alpha

		draw.RoundedBox(Sc(6), 0, 0, width, height,
			Color(255, 255, 255, (8 + 10 * hover) * alpha))

		surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b,
			(120 + 100 * hover) * alpha)
		surface.DrawRect(0, Sc(10), math.max(Sc(2), 2), height - Sc(20))

		draw.SimpleText(string.format("%02d", index), "nwInvKey", Sc(16), Sc(18),
			ColorAlpha(theme.textFaint, 200 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(entry.name or "?", "nwCreditName", Sc(48), Sc(18),
			ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (entry.role and entry.role != "") then
			draw.SimpleText(NETWORK.util.Upper(entry.role), "nwCreditRole", Sc(48), Sc(38),
				ColorAlpha(theme.combine, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		for lineIndex, line in ipairs(lines) do
			draw.SimpleText(line, "nwCreditAbout", width - Sc(14),
				Sc(18) + (lineIndex - 1) * Sc(17),
				ColorAlpha(theme.textDim, 225 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	return row
end

function PANEL:BuildPageSkills(pane)
	local Sc = NETWORK.util.Scale

	pane.list = pane:Add("DScrollPanel")

	StyleScroll(pane.list)

	local hint = pane.list:Add("DPanel")

	hint:Dock(TOP)
	hint:DockMargin(0, 0, 0, Sc(10))
	hint:SetTall(Sc(20))
	hint.Paint = function(panel, width, height)
		draw.SimpleText(L("skillsTabHint"), "nwLabel", 0, math.Round(height * 0.5),
			ColorAlpha(NETWORK.theme.textDim, 235 * self.alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	local config = NETWORK.creation
	local rowHeight = Sc(NETWORK.gui.skillRowHeight or 72)

	for index, data in ipairs(config.skills) do
		local row = pane.list:Add("DPanel")

		row:Dock(TOP)
		row:SetTall(rowHeight)
		row.hover = 0
		row.startTime = CurTime()
		row.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
		end
		row.Paint = function(panel, width, height)
			if (!NETWORK.gui.DrawSkillRow) then
				return
			end

			local util = NETWORK.util
			local reveal = util.EaseOut(util.Stagger(panel.startTime, 0.05 + index * 0.05, 0.45))
			local hover = util.EaseOut(panel.hover)

			if (hover > 0.01) then
				surface.SetDrawColor(255, 255, 255, 12 * hover * reveal * self.alpha)
				surface.DrawRect(0, 0, width, height - Sc(6))
			end

			NETWORK.gui.DrawSkillRow(0, 0, width, height, data, reveal, self.alpha)
		end
		row.OnCursorEntered = function(panel)
			if (NETWORK.gui.SkillTooltip) then
				NETWORK.gui.SkillTooltip(panel, data)
			end
		end
		row.OnCursorExited = function(panel)
			NETWORK.gui.ClearTooltip(panel)
		end
	end

	pane.PerformLayout = function(panel, width, height)
		panel.list:SetPos(Sc(26), Sc(64))
		panel.list:SetSize(width - Sc(52), height - Sc(64) - Sc(20))
	end
end

function PANEL:FillHelp(pane)
	if (!IsValid(pane) or !IsValid(pane.list)) then
		return
	end

	pane.list:Clear()

	local client = LocalPlayer()
	local filter = IsValid(pane.search) and
		string.lower(pane.search:GetValue() or "") or ""
	local category = pane.category

	if (category == "commands") then

		for _, entry in ipairs(NETWORK.chat.GetPrefixes()) do
			local name = L("chatName" .. entry.class.id)

			if (filter == "" or string.find(string.lower(name .. " " ..
				entry.prefix), filter, 1, true)) then
				self:AddHelpRow(pane, name, entry.prefix,
					L("chatRadius") .. ": " .. (entry.class.radius or "—"),
					entry.class.color)
			end
		end

		for _, data in ipairs(NETWORK.command.GetAll()) do
			if (data.adminOnly and !client:IsAdmin()) then
				continue
			end

			local usage = data.usage or ("/" .. data.id)
			local description = data.description and L(data.description) or ""

			if (filter != "" and !string.find(string.lower(usage .. " " ..
				description), filter, 1, true)) then
				continue
			end

			self:AddHelpRow(pane, usage,
				data.adminOnly and L("helpAdmin") or "", description,
				data.adminOnly and NETWORK.theme.warning or nil)
		end

		return
	end

	if (category == "phrases") then
		for _, id in ipairs(NETWORK.voice.categoryOrder) do
			for _, data in ipairs(NETWORK.voice.GetByCategory(id, client)) do
				if (filter != "" and
					!string.find(string.lower(data.text), filter, 1, true) and
					!string.find(string.lower(data.id), filter, 1, true)) then
					continue
				end

				self:AddHelpRow(pane, data.id,
					data.sound and L("voiceHasSound") or "", data.text, nil,
					function()
						SetClipboardText(data.id)

						NETWORK.gui.Notify(L("voiceCopied"),
							NETWORK.theme.combine)
					end)
			end
		end

		return
	end

	if (category == "credits") then
		local credits = NETWORK.credits and NETWORK.credits.list or {}

		if (#credits == 0) then
			self:AddHelpRow(pane, L("helpSoon"), nil, L("helpSoonBody"))
		end

		for index, entry in ipairs(credits) do
			self:AddCreditRow(pane, index, entry)
		end

		if (NETWORK.credits and NETWORK.credits.IsOwner and
			NETWORK.credits.IsOwner(client)) then
			self:AddHelpRow(pane, L("creditsOwnerHint"), nil, L("creditsOwnerHelp"),
				NETWORK.theme.combine)
		end

		return
	end

	if (category == "repair") then
		self:AddHelpRow(pane, L("helpRepairTitle"), nil, L("helpRepairBody"))

		local row = self:AddHelpRow(pane, L("helpRepairButton"), nil,
			L("helpRepairConfirm"), NETWORK.theme.combine, function()
				net.Start("nwInventoryRepair")
				net.SendToServer()

				NETWORK.gui.Notify(L("helpRepairButton"), NETWORK.theme.combine)
			end)

		return
	end

	self:AddHelpRow(pane, L("helpSoon"), nil, L("helpSoonBody"))
end

function PANEL:BuildPageBinds(pane)
	local Sc = NETWORK.util.Scale

	pane.list = pane:Add("DScrollPanel")

	StyleScroll(pane.list)

	pane.PerformLayout = function(panel, width, height)
		panel.list:SetPos(Sc(26), Sc(62))
		panel.list:SetSize(width - Sc(52), height - Sc(86))
	end

	local cards = {}
	local columns = 2
	local cardHeight = Sc(62)
	local gap = Sc(10)

	for index, data in ipairs(NETWORK.bind.GetAll()) do
		local card = pane.list:Add("DButton")

		card:SetText("")
		card:SetCursor("hand")
		card.column = (index - 1) % columns
		card.row = math.floor((index - 1) / columns)
		card.hover = 0
		card.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
		end
		card.Paint = function(panel, width, height)
			local theme = NETWORK.theme
			local util = NETWORK.util
			local bWaiting = panel.bWaiting
			local key = NETWORK.bind.GetKey(data)
			local lit = math.max(panel.hover, bWaiting and 1 or 0)
			local radius = math.max(Sc(6), 4)

			draw.SimpleText(L(data.name or data.id), "nwInvKey", 0, Sc(8),
				ColorAlpha(theme.textFaint, 235 * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local boxY = Sc(20)
			local boxHeight = height - boxY - Sc(4)
			local boxWidth = width - Sc(36)
			local pulse = bWaiting and (0.5 + math.abs(math.sin(RealTime() * 4)) * 0.5) or 1

			draw.RoundedBox(radius, 0, boxY, boxWidth, boxHeight, Color(12, 13, 15, 230 * self.alpha))

			if (bWaiting) then
				draw.RoundedBox(radius, 0, boxY, boxWidth, boxHeight,
					ColorAlpha(theme.combine, 30 * pulse * self.alpha))
			elseif (lit > 0.01) then
				draw.RoundedBox(radius, 0, boxY, boxWidth, boxHeight,
					Color(255, 255, 255, 10 * lit * self.alpha))
			end

			util.DrawRoundedBorder(0, boxY, boxWidth, boxHeight, radius, math.max(Sc(1), 1),
				bWaiting and ColorAlpha(theme.combine, 220 * pulse * self.alpha) or
				Color(255, 255, 255, (26 + 40 * lit) * self.alpha))

			local name = bWaiting and L("bindPressKey") or NETWORK.bind.GetKeyName(key)
			local textColour = (key > KEY_NONE or bWaiting) and theme.text or theme.textFaint

			draw.SimpleText(name, "nwHud", math.Round(boxWidth * 0.5), boxY + math.Round(boxHeight * 0.5),
				ColorAlpha(textColour, 250 * self.alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		card.DoClick = function(panel)
			NETWORK.sound.MenuPress()

			if (IsValid(self.capture)) then
				self.capture.bWaiting = false
			end

			panel.bWaiting = true

			self.capture = panel
			self.captureData = data
		end
		card.OnRemove = function(panel)
			if (self.capture == panel) then
				self.capture = nil
			end
		end

		local clear = card:Add("DButton")

		clear:SetText("")
		clear:SetCursor("hand")
		clear.Paint = function(panel, width, height)
			local theme = NETWORK.theme
			local colour = panel:IsHovered() and theme.danger or theme.textFaint
			local inset = Sc(9)

			NETWORK.util.DrawThickLine(inset, inset, width - inset, height - inset,
				math.max(Sc(1), 1), ColorAlpha(colour, 240 * self.alpha))
			NETWORK.util.DrawThickLine(width - inset, inset, inset, height - inset,
				math.max(Sc(1), 1), ColorAlpha(colour, 240 * self.alpha))
		end
		clear.DoClick = function()
			NETWORK.bind.SetKey(data, KEY_NONE)

			card.bWaiting = false

			if (self.capture == card) then
				self.capture = nil
			end

			surface.PlaySound("buttons/button19.wav")
		end

		card.PerformLayout = function(panel, width, height)
			clear:SetSize(Sc(28), Sc(28))
			clear:SetPos(width - Sc(30), Sc(20) + math.Round((height - Sc(24) - Sc(28)) * 0.5))
		end

		cards[#cards + 1] = card
	end

	pane.list.PerformLayout = function(panel, width, height)
		local cardWidth = math.floor((width - Sc(16) - gap * (columns - 1)) / columns)

		for _, card in ipairs(cards) do
			if (IsValid(card)) then
				card:SetSize(cardWidth, cardHeight)
				card:SetPos(card.column * (cardWidth + gap), card.row * (cardHeight + gap))
			end
		end

		panel:GetCanvas():SetTall(math.ceil(#cards / columns) * (cardHeight + gap))
	end

	pane.list:InvalidateLayout(true)
end

function PANEL:BuildPageSettings(pane)
	local Sc = NETWORK.util.Scale
	local tab = NETWORK.gui.tabs and NETWORK.gui.tabs.settings

	if (!tab or !tab.Build) then
		return
	end

	local holder = pane:Add("EditablePanel")

	pane.PerformLayout = function(panel, width, height)
		holder:SetPos(Sc(20), Sc(62))
		holder:SetSize(width - Sc(40), height - Sc(82))
	end

	tab.Build(holder, self)
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 10)
	self.paneShow = NETWORK.util.Approach(self.paneShow,
		(self.current and !self.bClosing) and 1 or 0, 9)

	if (IsValid(self.pane)) then
		local paneX, paneY = self:GetPaneRect()
		local slide = math.Round((1 - NETWORK.util.EaseOut(self.paneShow)) *
			NETWORK.util.Scale(60))

		self.pane:SetPos(paneX + slide, paneY)
		self.pane:SetAlpha(math.Round(self.paneShow * self.alpha * 255))
	end

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()
	end
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	self:SetMouseInputEnabled(false)

	for _, button in ipairs(self.buttons) do
		button:SetMouseInputEnabled(false)

		if (button.SetExiting) then
			button:SetExiting(true)
		end
	end

	if (IsValid(self.pane)) then
		self.pane:SetMouseInputEnabled(false)
	end

	gui.EnableScreenClicker(false)
end

function PANEL:OnKeyCodePressed(key)

	if (IsValid(self.capture)) then
		local panel = self.capture

		self.capture = nil
		panel.bWaiting = false

		if (key != KEY_ESCAPE and self.captureData) then
			NETWORK.bind.Assign(self.captureData, key)
		end

		return
	end

	if (key != KEY_ESCAPE) then
		return
	end

	if (self.current) then
		self:ClosePage()

		return
	end

	self:Close()
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha

	util.DrawBlur(self, 6 * alpha, 0.25)

	surface.SetDrawColor(0, 0, 0, 185 * alpha)
	surface.DrawRect(0, 0, width, height)

	util.DrawVignette(0, 0, width, height,
		math.Round(math.min(width, height) * 0.5), 150 * alpha)

	if (self.listX and self.listY and self.columnWidth) then
		local Sc2 = Sc
		local x = self.listX - Sc2(24)
		local y = self.listY - Sc2(18)
		local w = self.columnWidth + Sc2(48)
		local h = (self.listHeight or 0) + Sc2(36)
		local radius = math.max(Sc2(10), 6)

		util.DrawBlurRounded(self, x, y, w, h, radius, 4 * alpha)
		draw.RoundedBox(radius, x, y, w, h, Color(8, 9, 10, 214 * alpha))
		util.DrawRoundedBorder(x, y, w, h, radius, math.max(Sc2(1), 1),
			Color(255, 255, 255, 26 * alpha))

		for index, section in ipairs(self.sections or {}) do
			if (section.page and section.page == self.current) then
				surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b, 230 * alpha)
				surface.DrawRect(x + Sc2(8), self.listY + (index - 1) * Sc2(50) + Sc2(14),
					math.max(Sc2(3), 2), Sc2(22))
			end
		end
	end

	self:PaintBrand(width, height)
	self:PaintPane(width, height)

	util.DrawSimpleTextShadow(NETWORK.version .. "  ·  " .. (NETWORK.build or "?"),
		"nwHudLabelSmall", width - Sc(28), height - Sc(24),
		ColorAlpha(theme.textFaint, 200 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

function PANEL:PaintBrand(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha
	local x = self.listX or Sc(88)
	local y = math.min(Sc(64), math.Round(height * 0.07))

	surface.SetFont("nwMenuGhost")

	local titleWidth, titleHeight = surface.GetTextSize("NETWORK")
	local mark = math.Round(titleHeight * 0.62)
	local textX = x
	local logo = util.GetMaterial("logos/n-logo.png", "smooth")

	if (logo and !logo:IsError()) then
		surface.SetDrawColor(255, 255, 255, 245 * alpha)
		surface.SetMaterial(logo)
		surface.DrawTexturedRect(x, y + math.Round((titleHeight - mark) * 0.5),
			mark, mark)

		textX = x + mark + Sc(16)
	end

	util.DrawSimpleTextShadow("NETWORK", "nwMenuGhost", textX, y,
		ColorAlpha(theme.text, 150 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2)

	local lineY = y + titleHeight - Sc(4)

	surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 150 * alpha)
	surface.DrawRect(x, lineY, math.Round((textX - x + titleWidth) * alpha), 1)

	util.DrawTextSpacedShadow(util.Upper(L("tagline")), "nwMenuSub", x,
		lineY + Sc(16), ColorAlpha(theme.combine, 225 * alpha), Sc(3),
		TEXT_ALIGN_CENTER)

	local client = LocalPlayer()

	if (IsValid(client) and client:HasCharacter()) then
		util.DrawTextSpacedShadow(util.Upper(client:GetCharacterName()),
			"nwHudLabelSmall", x, (self.listY or 0) + (self.listHeight or 0) + Sc(30),
			ColorAlpha(theme.textDim, 220 * alpha), Sc(3), TEXT_ALIGN_CENTER)
	end
end

function PANEL:PaintPane(width, height)
	if (self.paneShow < 0.01) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local show = util.EaseOut(self.paneShow) * self.alpha
	local x, y, paneWidth, paneHeight = self:GetPaneRect()

	x = x + math.Round((1 - util.EaseOut(self.paneShow)) * Sc(60))

	local radius = math.max(Sc(10), 6)

	util.DrawBlurRounded(self, x, y, paneWidth, paneHeight, radius, 4 * show)

	draw.RoundedBox(radius, x, y, paneWidth, paneHeight, Color(8, 9, 10, 226 * show))

	util.DrawRoundedBorder(x, y, paneWidth, paneHeight, radius, math.max(Sc(1), 1),
		Color(255, 255, 255, 26 * show))

	local id = self.current or self.lastPage or "help"
	local title = util.Upper(L("escape" .. string.upper(string.sub(id, 1, 1)) ..
		string.sub(id, 2)))

	draw.SimpleText(title, "nwInvKey", x + Sc(20), y + Sc(28),
		ColorAlpha(theme.textFaint, 250 * show), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b, 220 * show)
	surface.DrawRect(x + Sc(20), y + Sc(40), math.Round(Sc(28) * show),
		math.max(Sc(2), 2))
end

vgui.Register("nwEscapeMenu", PANEL, "EditablePanel")

function NETWORK.gui.OpenEscapeMenu()
	if (!NETWORK.gui.CanOpenMenus()) then
		return
	end

	if (IsValid(NETWORK.gui.escape)) then
		NETWORK.gui.escape:Close()

		return
	end

	NETWORK.gui.CloseWindows()

	return vgui.Create("nwEscapeMenu")
end

function GM:OnPauseMenuShow()
	if (NETWORK.gui.bAllowPause) then
		NETWORK.gui.bAllowPause = false

		return true
	end

	if (IsValid(NETWORK.gui.container)) then
		NETWORK.gui.container:Close()

		return false
	end

	if (IsValid(NETWORK.gui.shopPanel)) then
		NETWORK.gui.shopPanel:Close()

		return false
	end

	if (IsValid(NETWORK.gui.chat) and NETWORK.gui.chat:GetActive()) then
		NETWORK.gui.chat:SetActive(false)

		return false
	end

	if (IsValid(NETWORK.gui.tabMenu)) then
		NETWORK.gui.tabMenu:Close()

		return false
	end

	NETWORK.gui.OpenEscapeMenu()

	return false
end
