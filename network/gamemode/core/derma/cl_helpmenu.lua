NETWORK.gui.help = NETWORK.gui.help or nil

NETWORK.help = NETWORK.help or {}

NETWORK.help.categories = {
	{id = "credits", name = "helpCredits"},
	{id = "repair", name = "helpRepair"},
	{id = "phrases", name = "helpPhrases"},
	{id = "commands", name = "helpCommands"}
}

local PANEL = {}

function PANEL:Init()
	local ScDefault = NETWORK.util.Scale

	self.listX = ScDefault(420)
	self.sideWidth = ScDefault(280)
	local Sc = NETWORK.util.Scale

	NETWORK.gui.help = self

	self.alpha = 0
	self.bClosing = false
	self.category = "commands"
	self.buttons = {}

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
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

	for index, data in ipairs(NETWORK.help.categories) do
		local button = self:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button.hover = 0
		button.index = index
		button.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
		end
		button.Paint = function(panel, width, height)
			local theme = NETWORK.theme
			local util = NETWORK.util
			local bActive = self.category == data.id
			local lit = math.max(panel.hover, bActive and 1 or 0)

			local radius = math.max(Sc(6), 4)

			if (bActive) then
				draw.RoundedBox(radius, 0, 0, width, height,
					ColorAlpha(theme.combine, 34 * self.alpha))
				util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
					ColorAlpha(theme.combine, 200 * self.alpha))
			elseif (panel.hover > 0.01) then
				draw.RoundedBox(radius, 0, 0, width, height,
					Color(255, 255, 255, 12 * panel.hover * self.alpha))
			end

			draw.SimpleText(L(data.name), "nwSideNav", Sc(16), math.Round(height * 0.5),
				ColorAlpha(bActive and theme.text or theme.textDim,
				(bActive and 250 or 215) * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			NETWORK.sound.Click()

			self.category = data.id

			self:InvalidateLayout(true)
			self:Rebuild()
		end

		self.buttons[index] = button
	end

	self.search = NETWORK.gui.BindEntry(self:Add("DTextEntry"))
	self.search:SetFont("nwInvBody")
	self.search:SetPaintBackground(false)
	self.search:SetUpdateOnType(true)
	self.search:SetTextColor(NETWORK.theme.text)
	self.search:SetCursorColor(NETWORK.theme.combine)
	self.search:SetTextInset(Sc(12), 0)
	self.search.Paint = function(panel, width, height)
		local Sc = NETWORK.util.Scale
		local radius = math.max(Sc(6), 4)

		draw.RoundedBox(radius, 0, 0, width, height, Color(10, 11, 13, 230))

		NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
			panel:HasFocus() and ColorAlpha(NETWORK.theme.combine, 210) or
			Color(255, 255, 255, 30))

		if (panel:GetValue() == "") then
			draw.SimpleText(L("helpSearch"), "nwInvBody", Sc(12),
				math.Round(height * 0.5), ColorAlpha(NETWORK.theme.textFaint, 200),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.combineDeep,
			NETWORK.theme.combine)
	end
	self.search.OnValueChange = function()
		self:Rebuild()
	end

	self.close = self:Add("nwActionButton")
	self.close:SetLabel(L("containerClose"))
	self.close.DoClick = function()
		self:Close()
	end

	self:Rebuild()
end

function PANEL:OnRemove()
	if (NETWORK.gui.help == self) then
		NETWORK.gui.help = nil
	end
end

function PANEL:AddEntry(title, subtitle, body, color)
	local Sc = NETWORK.util.Scale
	local panel = self.list:Add("DPanel")
	local lines = body != "" and NETWORK.util.WrapText(body, "nwChatSmall",
		self.list:GetWide() - Sc(60), 3) or {}

	panel:Dock(TOP)
	panel:DockMargin(0, 0, Sc(16), Sc(8))
	panel:SetTall(Sc(46) + #lines * Sc(20))
	panel.hover = 0
	panel.Think = function(this)
		this.hover = NETWORK.util.Approach(this.hover, this:IsHovered() and 1 or 0, 12)
	end
	panel.Paint = function(this, width, height)
		local theme = NETWORK.theme
		local util = NETWORK.util
		local tint = color or theme.accent
		local lit = this.hover

		local radius = math.max(Sc(6), 4)

		draw.RoundedBox(radius, 0, 0, width, height, Color(12, 13, 15, (200 + 20 * lit) * self.alpha))

		util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
			Color(255, 255, 255, (26 + 30 * lit) * self.alpha))

		draw.RoundedBox(math.max(Sc(2), 2), Sc(6), Sc(10), math.max(Sc(3), 2), height - Sc(20),
			ColorAlpha(tint, (170 + 85 * lit) * self.alpha))

		draw.SimpleText(title, "nwInvName", Sc(20), Sc(21),
			ColorAlpha(theme.text, 250 * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (subtitle != "") then
			draw.SimpleText(subtitle, "nwInvKey", width - Sc(16), Sc(20),
				ColorAlpha(tint, 240 * self.alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		local y = Sc(44)

		for i = 1, #lines do
			draw.SimpleText(lines[i], "nwInvBody", Sc(20), y,
				ColorAlpha(theme.textDim, 240 * self.alpha), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			y = y + Sc(20)
		end
	end

	return panel
end

function PANEL:AddHeader(text)
	local Sc = NETWORK.util.Scale
	local panel = self.list:Add("DPanel")

	panel:Dock(TOP)
	panel:DockMargin(0, Sc(16), Sc(16), Sc(6))
	panel:SetTall(Sc(26))
	panel.Paint = function(this, width, height)
		local theme = NETWORK.theme
		local util = NETWORK.util
		local caption = util.Upper(text)

		draw.SimpleText(caption, "nwInvKey", 0, math.Round(height * 0.5),
			ColorAlpha(theme.textFaint, 250 * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(255, 255, 255, 14 * self.alpha)
		surface.DrawRect(0, height - 1, width, 1)
	end
end

function PANEL:Rebuild()
	self.list:Clear()

	if (self.category == "commands") then
		local client = LocalPlayer()

		self:AddHeader(L("helpChatTypes"))

		for _, entry in ipairs(NETWORK.chat.GetPrefixes()) do
			self:AddEntry(L("chatName" .. entry.class.id), entry.prefix,
				L("chatRadius") .. ": " .. (entry.class.radius or "—"), entry.class.color)
		end

		self:AddHeader(L("helpCommandList"))

		for _, data in ipairs(NETWORK.command.GetAll()) do
			if (data.adminOnly and !client:IsAdmin()) then
				continue
			end

			self:AddEntry(data.usage, data.adminOnly and L("helpAdmin") or "",
				L(data.description), data.adminOnly and Color(240, 200, 90) or nil)
		end

		return
	end

	if (self.category == "repair") then
		local Sc = NETWORK.util.Scale

		self:AddEntry(L("helpRepairTitle"), nil, L("helpRepairBody"))

		local button = self.list:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button:Dock(TOP)
		button:DockMargin(0, Sc(6), Sc(16), Sc(6))
		button:SetTall(Sc(46))
		button.armed = 0
		button.DoClick = function(panel)
			if (panel.armed == 0) then
				panel.armed = CurTime() + 0.6

				NETWORK.sound.Click()

				return
			end

			if (CurTime() < panel.armed) then
				return
			end

			panel.armed = 0

			net.Start("nwInventoryRepair")
			net.SendToServer()

			self:Close()
		end
		button.Paint = function(panel, width, height)
			local theme = NETWORK.theme
			local bArmed = panel.armed != 0
			local hover = panel:IsHovered() and 1 or 0
			local base = bArmed and theme.danger or theme.accent

			draw.RoundedBox(math.max(Sc(6), 4), 0, 0, width, height,
				Color(base.r, base.g, base.b, (26 + 24 * hover) * self.alpha))

			draw.SimpleText(NETWORK.util.Upper(L(bArmed and "helpRepairConfirm" or
				"helpRepairButton")), "nwField", math.Round(width * 0.5),
				math.Round(height * 0.5), ColorAlpha(bArmed and theme.danger or
				theme.text, 250 * self.alpha), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end

		return
	end

	if (self.category == "phrases") then
		local client = LocalPlayer()
		local filter = NETWORK.util.Lower(self.search:GetValue())

		for _, id in ipairs(NETWORK.voice.categoryOrder) do
			local category = NETWORK.voice.categories[id]
			local lines = NETWORK.voice.GetByCategory(id, client)
			local bHeader = false

			for _, data in ipairs(lines) do
				if (filter != "" and
					!string.find(NETWORK.util.Lower(data.text), filter, 1, true) and
					!string.find(data.id, filter, 1, true)) then
					continue
				end

				if (!bHeader) then
					bHeader = true

					self:AddHeader(L(category.name))
				end

				local entry = self:AddEntry(data.id,
					data.sound and L("voiceHasSound") or "", data.text)

				entry:SetCursor("hand")
				entry.OnMousePressed = function()
					SetClipboardText(data.id)

					NETWORK.gui.Notify(L("voiceCopied"), NETWORK.theme.accentSoft)

					NETWORK.sound.Click()
				end
			end
		end

		return
	end

	self:AddHeader(L("helpCredits"))

	local credits = NETWORK.credits and NETWORK.credits.list or {}

	if (#credits == 0) then
		self:AddEntry(L("helpSoon"), "", L("helpSoonBody"))
	else
		for index, entry in ipairs(credits) do
			self:AddEntry(entry.name or "?", entry.role or "",
				entry.about or "")
		end
	end

	if (NETWORK.credits and NETWORK.credits.IsOwner(LocalPlayer())) then
		self:AddEntry(L("creditsOwnerHint"), "", L("creditsOwnerHelp"))
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.sideWidth = Sc(280)
	self.listX = math.Round(width * 0.5 - Sc(220))

	self.search:SetPos(self.listX, Sc(132))
	self.search:SetSize(Sc(700), Sc(34))
	self.search:SetVisible(self.category == "phrases" or self.category == "commands")

	local offset = self.search:IsVisible() and Sc(44) or 0

	self.list:SetPos(self.listX, Sc(132) + offset)
	self.list:SetSize(Sc(700), height - Sc(232) - offset)

	for index, button in ipairs(self.buttons) do
		button:SetSize(self.sideWidth - Sc(40), Sc(44))
		button:SetPos(self.listX - self.sideWidth, Sc(132) + (index - 1) * Sc(52))
	end

	self.close:SetSize(Sc(220), Sc(44))
	self.close:SetPos(math.Round((width - Sc(220)) * 0.5), height - Sc(76))
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

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

	util.DrawBlur(self, 4 * alpha, 0.25)

	surface.SetDrawColor(3, 4, 6, 170 * alpha)
	surface.DrawRect(0, 0, width, height)

	local frameX = self.listX - self.sideWidth - Sc(20)
	local frameWidth = self.sideWidth + Sc(760)
	local frameY = Sc(60)
	local frameHeight = height - Sc(120)
	local radius = math.max(Sc(10), 6)

	draw.RoundedBox(radius, frameX, frameY, frameWidth, frameHeight, Color(8, 9, 10, 226 * alpha))

	util.DrawRoundedBorder(frameX, frameY, frameWidth, frameHeight, radius, math.max(Sc(1), 1),
		Color(255, 255, 255, 26 * alpha))

	draw.SimpleText(util.Upper(L("helpTitle")), "nwInvKey", frameX + Sc(20), frameY + Sc(22),
		ColorAlpha(theme.textFaint, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 14 * alpha)
	surface.DrawRect(frameX + Sc(20), frameY + Sc(44), frameWidth - Sc(40), 1)
	surface.DrawRect(self.listX - Sc(24), frameY + Sc(56), 1, frameHeight - Sc(90))
end

vgui.Register("nwHelpMenu", PANEL, "EditablePanel")

function NETWORK.gui.OpenHelp()
	if (IsValid(NETWORK.gui.help)) then
		NETWORK.gui.help:Close()

		return
	end

	NETWORK.gui.CloseWindows()

	return vgui.Create("nwHelpMenu")
end

concommand.Add("network_help", function()
	NETWORK.gui.OpenHelp()
end)
