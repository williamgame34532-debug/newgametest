local PANEL = {}

function PANEL:Init()
	local ScDefault = NETWORK.util.Scale

	self.frameWidth = ScDefault(1040)
	self.frameHeight = ScDefault(620)
	self.frameX = ScDefault(120)
	self.frameY = ScDefault(120)
	self.headerHeight = ScDefault(44)
	self.listWidth = ScDefault(320)
	local Sc = NETWORK.util.Scale

	NETWORK.gui.questLog = self

	self.alpha = 0
	self.reveal = 0
	self.bClosing = false
	self.selected = nil
	self.buttons = {}

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.list = self:Add("DScrollPanel")

	local bar = self.list:GetVBar()

	bar:SetWide(Sc(3))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(2), 0, 0, width, height, Color(255, 255, 255, 55))
	end

	self:Rebuild()
end

function PANEL:OnRemove()
	if (NETWORK.gui.questLog == self) then
		NETWORK.gui.questLog = nil
	end
end

function PANEL:GetQuests()
	local list = {}
	local active = NETWORK.quest.active or {}

	for id, state in pairs(active) do
		local data = NETWORK.quest.Get(id)

		if (data) then
			list[#list + 1] = {id = id, data = data, state = state}
		end
	end

	table.sort(list, function(a, b)
		return (a.data.name or a.id) < (b.data.name or b.id)
	end)

	return list
end

function PANEL:Rebuild()
	local Sc = NETWORK.util.Scale

	self.list:Clear()

	self.quests = self:GetQuests()

	if (!self.selected and self.quests[1]) then
		self.selected = self.quests[1].id
	end

	for index, entry in ipairs(self.quests) do
		local button = self.list:Add("DButton")
		local bComplete = NETWORK.quest.CanComplete and
			NETWORK.quest.CanComplete(LocalPlayer(), entry.id)

		button:Dock(TOP)
		button:DockMargin(0, 0, Sc(10), Sc(6))
		button:SetTall(Sc(52))
		button:SetText("")
		button:SetCursor("hand")
		button.hover = 0
		button.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
		end
		button.Paint = function(panel, width, height)
			local theme = NETWORK.theme
			local util = NETWORK.util
			local bActive = self.selected == entry.id
			local lit = math.max(panel.hover, bActive and 1 or 0)
			local color = bComplete and theme.positive or theme.accent

			surface.SetDrawColor(theme.plateDeep.r, theme.plateDeep.g, theme.plateDeep.b,
				(180 + 50 * lit) * self.alpha)
			surface.DrawRect(0, 0, width, height)

			util.DrawScanlines(0, 0, width, height, 18 * self.alpha)

			surface.SetDrawColor(color.r, color.g, color.b, (170 + 85 * lit) * self.alpha)
			surface.DrawRect(0, 0, math.max(Sc(3), 2), height)

			draw.SimpleText(entry.data.name or entry.id, "nwField", Sc(16), Sc(18),
				ColorAlpha(theme.text, 250 * self.alpha), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			draw.SimpleText(L(bComplete and "questReadyShort" or "questInProgress"),
				"nwHudSmall", Sc(16), Sc(36), ColorAlpha(color, 240 * self.alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			NETWORK.sound.Click()

			self.selected = entry.id
		end
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.frameWidth = math.min(Sc(1040), width - Sc(200))
	self.frameHeight = math.min(Sc(620), height - Sc(180))
	self.frameX = math.Round((width - self.frameWidth) * 0.5)
	self.frameY = math.Round((height - self.frameHeight) * 0.5)
	self.headerHeight = Sc(44)
	self.listWidth = Sc(320)

	self.list:SetPos(self.frameX + Sc(24), self.frameY + self.headerHeight + Sc(20))
	self.list:SetSize(self.listWidth, self.frameHeight - self.headerHeight - Sc(44))
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
	self.reveal = NETWORK.util.Approach(self.reveal, self.bClosing and 0 or 1, 8)

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE or key == KEY_H) then
		self:Close()
	end
end

function PANEL:OnMousePressed(code)
	local Sc = NETWORK.util.Scale
	local x, y = self:CursorPos()

	if (code == MOUSE_LEFT and x >= self.frameX + self.frameWidth - Sc(44) and
		y <= self.frameY + self.headerHeight) then
		NETWORK.sound.Click()

		self:Close()
	end
end

function PANEL:PaintDetails(x, y, width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha
	local entry

	for _, data in ipairs(self.quests or {}) do
		if (data.id == self.selected) then
			entry = data
		end
	end

	if (!entry) then
		draw.SimpleText(L("questLogEmpty"), "nwChat", x + math.Round(width * 0.5),
			y + math.Round(height * 0.5), ColorAlpha(theme.textFaint, 235 * alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		return
	end

	local quest = entry.data
	local cursorY = y + Sc(10)

	util.DrawTextSpaced(util.Upper(quest.name or entry.id), "nwTab", x, cursorY,
		ColorAlpha(theme.text, 252 * alpha), Sc(4), TEXT_ALIGN_CENTER)

	cursorY = cursorY + Sc(30)

	for _, line in ipairs(util.WrapText(quest.description or "", "nwChatSmall",
		width, 6)) do
		draw.SimpleText(line, "nwChatSmall", x, cursorY,
			ColorAlpha(theme.textDim, 240 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		cursorY = cursorY + Sc(20)
	end

	cursorY = cursorY + Sc(14)

	util.DrawTextSpaced(util.Upper(L("questObjectives")), "nwHudSmall", x, cursorY,
		ColorAlpha(theme.accentSoft, 245 * alpha), Sc(3), TEXT_ALIGN_CENTER)

	cursorY = cursorY + Sc(24)

	for index, objective in ipairs(quest.objectives or {}) do
		local text = NETWORK.quest.GetObjectiveText(objective, entry.state)
		local progress = (entry.state.progress or {})[index] or 0
		local bDone = progress >= (objective.amount or 1)

		surface.SetDrawColor(bDone and theme.positive.r or theme.textFaint.r,
			bDone and theme.positive.g or theme.textFaint.g,
			bDone and theme.positive.b or theme.textFaint.b, 245 * alpha)
		surface.DrawRect(x, cursorY - Sc(4), Sc(8), Sc(8))

		draw.SimpleText(text, "nwChatSmall", x + Sc(18), cursorY,
			ColorAlpha(bDone and theme.positive or theme.text, 245 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		cursorY = cursorY + Sc(22)
	end

	cursorY = cursorY + Sc(14)

	util.DrawTextSpaced(util.Upper(L("questRewards")), "nwHudSmall", x, cursorY,
		ColorAlpha(theme.accentSoft, 245 * alpha), Sc(3), TEXT_ALIGN_CENTER)

	cursorY = cursorY + Sc(24)

	local rewards = quest.rewards or {}

	for _, reward in ipairs(rewards.items or {}) do
		local base = NETWORK.item.Get(reward.id)

		draw.SimpleText((base and base.name or reward.id) .. "  x" ..
			(reward.amount or 1), "nwChatSmall", x + Sc(18), cursorY,
			ColorAlpha(theme.value, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		cursorY = cursorY + Sc(20)
	end

	if (rewards.trader and rewards.trader.id) then
		draw.SimpleText(L("questTraderReward") .. ": " .. rewards.trader.id .. " " ..
			(rewards.trader.level or 2), "nwChatSmall", x + Sc(18), cursorY,
			ColorAlpha(theme.value, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha
	local reveal = util.EaseInOut(self.reveal)

	surface.SetDrawColor(0, 0, 0, 150 * alpha)
	surface.DrawRect(0, 0, width, height)

	local frameWidth = math.Round(self.frameWidth * reveal)
	local x = math.Round(width * 0.5 - frameWidth * 0.5)
	local y = self.frameY

	util.DrawPanel(x, y, frameWidth, self.frameHeight, alpha, {bBrackets = true})

	if (reveal < 0.85) then
		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 235 * alpha)
		surface.DrawRect(x, y, math.max(Sc(2), 2), self.frameHeight)
		surface.DrawRect(x + frameWidth - math.max(Sc(2), 2), y, math.max(Sc(2), 2),
			self.frameHeight)

		return
	end

	util.DrawTitleBar(x, y, frameWidth, self.headerHeight, L("questLogTitle"), alpha)

	draw.SimpleText("×", "nwTab", x + frameWidth - Sc(22),
		y + math.Round(self.headerHeight * 0.5), ColorAlpha(theme.textDim, 250 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 60 * alpha)
	surface.DrawRect(x + Sc(24) + self.listWidth + Sc(20),
		y + self.headerHeight + Sc(20), math.max(Sc(1), 1),
		self.frameHeight - self.headerHeight - Sc(44))

	self:PaintDetails(x + Sc(24) + self.listWidth + Sc(44),
		y + self.headerHeight + Sc(24),
		frameWidth - self.listWidth - Sc(92),
		self.frameHeight - self.headerHeight - Sc(48))
end

vgui.Register("nwQuestLog", PANEL, "EditablePanel")

function NETWORK.gui.OpenQuestLog()
	if (IsValid(NETWORK.gui.questLog)) then
		NETWORK.gui.questLog:Close()

		return
	end

	if (!LocalPlayer():HasCharacter()) then
		return
	end

	NETWORK.gui.CloseWindows()

	return vgui.Create("nwQuestLog")
end

hook.Add("Think", "nwQuestLog", function()
	local bDown = input.IsKeyDown(KEY_H)

	if (bDown and !NETWORK.gui.questKeyHeld) then
		NETWORK.gui.questKeyHeld = true

		if (!vgui.CursorVisible() or IsValid(NETWORK.gui.questLog)) then
			NETWORK.gui.OpenQuestLog()
		end
	elseif (!bDown) then
		NETWORK.gui.questKeyHeld = false
	end
end)

concommand.Add("network_quests", function()
	NETWORK.gui.OpenQuestLog()
end)
