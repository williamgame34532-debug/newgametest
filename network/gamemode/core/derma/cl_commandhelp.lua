local PANEL = {}

function PANEL:Init()
	NETWORK.gui.commandHelp = self

	self.open = 0
	self.alpha = 0
	self.filter = "all"
	self.search = ""
	self.list = {}
	self.rows = {}
	self.controls = {}

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme

	self.close = self:Add("DButton")
	self.close:SetText("")
	self.close:SetCursor("hand")
	self.close.DoClick = function()
		self:Remove()
	end
	self.close.Paint = function(panel, width, height)
		local colour = panel:IsHovered() and theme.danger or theme.accent
		local inset = Sc(12)
		local thickness = math.max(Sc(2), 2)

		NETWORK.util.DrawThickLine(inset, inset, width - inset, height - inset,
			thickness, colour)
		NETWORK.util.DrawThickLine(width - inset, inset, inset, height - inset,
			thickness, colour)
	end

	self.searchEntry = self:Add("DTextEntry")
	self.searchEntry:SetFont("nwChat")
	self.searchEntry:SetDrawLanguageID(false)
	self.searchEntry:SetAllowNonAsciiCharacters(true)
	self.searchEntry:SetPaintBackground(false)
	self.searchEntry:SetTextColor(theme.text)
	self.searchEntry:SetCursorColor(theme.accent)
	self.searchEntry:SetHighlightColor(theme.accentDeep)
	self.searchEntry:SetUpdateOnType(true)
	self.searchEntry.OnValueChange = function(_, value)
		self.search = string.lower(string.Trim(value or ""))

		self:Rebuild()
	end
	self.searchEntry.Paint = function(this, width, height)
		surface.SetDrawColor(theme.plate.r, theme.plate.g, theme.plate.b, 240)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 140)
		surface.DrawOutlinedRect(0, 0, width, height, 1)

		if (this:GetValue() == "" and !this:HasFocus()) then
			draw.SimpleText(L("helpCmdSearch"), "nwChat", Sc(10),
				math.Round(height * 0.5), theme.textFaint, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
		end

		this:DrawTextEntryText(theme.text, theme.accentDeep, theme.accent)
	end

	for _, entry in ipairs({
		{id = "all", label = "helpCmdAll"},
		{id = "admin", label = "helpCmdAdmin"},
		{id = "player", label = "helpCmdPlayer"}
	}) do
		local button = self:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button.filterID = entry.id
		button.DoClick = function()
			surface.PlaySound(NETWORK.terminal.sounds.select)

			self.filter = entry.id

			self:Rebuild()
		end
		button.OnCursorEntered = function()
			surface.PlaySound(NETWORK.terminal.sounds.hover)
		end

		button.Paint = function(panel, width, height)
			local bActive = self.filter == entry.id
			local strength = math.max(panel:IsHovered() and 1 or 0,
				bActive and 1 or 0)
			local radius = math.max(Sc(6), 4)

			draw.RoundedBox(radius, 0, 0, width, height,
				Color(255, 255, 255, 10 + 16 * strength))

			if (bActive) then
				draw.RoundedBox(radius, 0, height - math.max(Sc(2), 2), width,
					math.max(Sc(2), 2), ColorAlpha(theme.hover, 245))
			end

			draw.SimpleText(NETWORK.util.Upper(L(entry.label)),
				"nwHudLabelSmall", math.Round(width * 0.5),
				math.Round(height * 0.5),
				ColorAlpha(strength > 0 and theme.text or theme.textDim, 250),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		self.controls[#self.controls + 1] = button
	end

	self.scroll = self:Add("DScrollPanel")
	self.scroll.Paint = function() end

	local bar = self.scroll:GetVBar()

	bar:SetWide(Sc(6))
	bar:SetHideButtons(true)
	bar.Paint = function() end
	bar.btnGrip.Paint = function(_, width, height)
		draw.RoundedBox(math.max(Sc(3), 2), 0, 0, width, height,
			Color(255, 255, 255, 80))
	end
end

local GUIDES = {
	{id = "guide_rebel", title = "helpGuideRebelTitle", body = "helpGuideRebelBody"},
	{id = "guide_citizen", title = "helpGuideCitizenTitle", body = "helpGuideCitizenBody"},
	{id = "guide_cwu", title = "helpGuideCWUTitle", body = "helpGuideCWUBody"},
	{id = "guide_alliance", title = "helpGuideAllianceTitle", body = "helpGuideAllianceBody"}
}

function PANEL:Setup(list)
	self.list = {}

	for _, guide in ipairs(GUIDES) do
		self.list[#self.list + 1] = {
			id = guide.id,
			bGuide = true,
			title = L(guide.title),
			usage = L("helpGuideUsage"),
			description = guide.body,
			example = "",
			bAdmin = false
		}
	end

	for _, entry in ipairs(istable(list) and list or {}) do
		self.list[#self.list + 1] = entry
	end

	self:Rebuild()
end

function PANEL:OnRemove()
	if (NETWORK.gui.commandHelp == self) then
		NETWORK.gui.commandHelp = nil
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_RIGHT) then
		self:Remove()
	end
end

function PANEL:GetFrameWidth()
	return math.Round(math.min(ScrW() * 0.6, NETWORK.util.Scale(960)))
end

function PANEL:GetFrameHeight()
	return math.Round(math.min(ScrH() * 0.8, NETWORK.util.Scale(700)))
end

function PANEL:GetFrameX()
	return math.Round((ScrW() - self:GetFrameWidth()) * 0.5)
end

function PANEL:GetFrameY()
	return math.Round((ScrH() - self:GetFrameHeight()) * 0.5)
end

function PANEL:GetBarHeight()
	return NETWORK.util.Scale(62)
end

function PANEL:PerformLayout()
	local Sc = NETWORK.util.Scale
	local x = self:GetFrameX()
	local y = self:GetFrameY()
	local width = self:GetFrameWidth()
	local height = self:GetFrameHeight()
	local inner = x + Sc(24)
	local innerWidth = width - Sc(48)
	local top = y + self:GetBarHeight() + Sc(16)

	if (IsValid(self.close)) then
		self.close:SetSize(Sc(44), Sc(44))
		self.close:SetPos(x + width - Sc(54), y + Sc(9))
	end

	local filterWidth = Sc(118)
	local gap = Sc(8)
	local searchWidth = innerWidth - (#self.controls * (filterWidth + gap))

	if (IsValid(self.searchEntry)) then
		self.searchEntry:SetPos(inner, top)
		self.searchEntry:SetSize(searchWidth, Sc(34))
	end

	for index, button in ipairs(self.controls) do
		button:SetPos(inner + searchWidth + gap +
			(index - 1) * (filterWidth + gap), top)
		button:SetSize(filterWidth, Sc(34))
	end

	if (IsValid(self.scroll)) then
		self.scroll:SetPos(inner, top + Sc(34) + Sc(14))
		self.scroll:SetSize(innerWidth,
			y + height - Sc(24) - (top + Sc(34) + Sc(14)))
	end
end

function PANEL:Matches(data)
	if (self.filter == "admin" and !data.bAdmin) then
		return false
	end

	if (self.filter == "player" and data.bAdmin) then
		return false
	end

	if (self.search == "") then
		return true
	end

	local description = L(data.description)
	local haystack = string.lower(data.id .. " " .. (data.usage or "") .. " " ..
		(description or ""))

	return string.find(haystack, self.search, 1, true) != nil
end

function PANEL:Rebuild()
	if (!IsValid(self.scroll)) then
		return
	end

	self.scroll:Clear()
	self.rows = {}

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local count = 0

	for _, data in ipairs(self.list) do
		if (!self:Matches(data)) then
			continue
		end

		count = count + 1

		local description = L(data.description)

		if (description == "") then
			description = data.description
		end

		local row = self.scroll:Add("DButton")

		row:SetText("")
		row:SetCursor("hand")
		row:Dock(TOP)
		row:DockMargin(0, 0, Sc(8), Sc(6))
		row:SetTall(data.bGuide and Sc(118) or Sc(60))
		row.DoClick = function()
			surface.PlaySound(NETWORK.terminal.sounds.select)
			SetClipboardText(data.bGuide and description or (data.usage or ("/" .. data.id)))

			row.flash = CurTime() + 0.4
		end
		row.OnCursorEntered = function()
			surface.PlaySound(NETWORK.terminal.sounds.hover)
		end
		row.Paint = function(panel, width, height)
			local hover = panel:IsHovered() and 1 or 0
			local flash = math.max(((panel.flash or 0) - CurTime()) / 0.4, 0)
			local strength = math.max(hover, flash)

			surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
				6 + 18 * strength)
			surface.DrawRect(0, 0, width, height)

			surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
				70 + 150 * strength)
			surface.DrawOutlinedRect(0, 0, width, height, 1)

			local leftWidth = math.Round(width * 0.34)

			draw.SimpleText(data.bGuide and data.title or ("/" .. data.id), "nwTag", Sc(14), Sc(9),
				ColorAlpha(theme.value, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			draw.SimpleText(data.usage or "", "nwHudSmall", Sc(14),
				height - Sc(9), ColorAlpha(theme.textDim, 235), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_BOTTOM)

			local textX = leftWidth + Sc(12)
			local textWidth = width - textX - Sc(90)
			local lineY = Sc(9)

			for _, line in ipairs(NETWORK.util.WrapText(description or "",
				"nwTagDesc", textWidth, data.bGuide and 6 or 2)) do
				draw.SimpleText(line, "nwTagDesc", textX, lineY,
					ColorAlpha(theme.text, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

				lineY = lineY + Sc(18)
			end

			if (data.example and data.example != "") then
				draw.SimpleText(NETWORK.util.Upper(L("helpCmdExample")) ..
					": " .. data.example, "nwHudSmall", textX, height - Sc(9),
					ColorAlpha(theme.textFaint, 235), TEXT_ALIGN_LEFT,
					TEXT_ALIGN_BOTTOM)
			end

			if (data.bAdmin) then
				local label = NETWORK.util.Upper(L("helpCmdAdminBadge"))

				surface.SetFont("nwHudSmall")

				local labelWidth = surface.GetTextSize(label)
				local badgeWidth = labelWidth + Sc(14)

				surface.SetDrawColor(theme.danger.r, theme.danger.g,
					theme.danger.b, 160)
				surface.DrawOutlinedRect(width - badgeWidth - Sc(12), Sc(9),
					badgeWidth, Sc(18), 1)

				draw.SimpleText(label, "nwHudSmall",
					width - badgeWidth - Sc(12) + math.Round(badgeWidth * 0.5),
					Sc(9) + Sc(9), ColorAlpha(theme.danger, 245),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		self.rows[#self.rows + 1] = row
	end

	self.count = count
end

function PANEL:Think()
	local util = NETWORK.util

	self.alpha = util.Approach(self.alpha, 1, 6)
	self.open = util.Approach(self.open, 1, 4)

	if (!vgui.CursorVisible()) then
		self:MakePopup()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha

	util.DrawBlur(self, 5 * alpha, 0.25)

	surface.SetDrawColor(3, 4, 6, 200 * alpha)
	surface.DrawRect(0, 0, width, height)

	local frameWidth = self:GetFrameWidth()
	local frameHeight = math.Round(self:GetFrameHeight() * self.open)
	local x = self:GetFrameX()
	local y = math.Round(ScrH() * 0.5 - frameHeight * 0.5)

	if (frameHeight < 4) then
		return
	end

	local radius = math.max(Sc(12), 6)

	util.DrawGlow(x - Sc(26), y - Sc(20), frameWidth + Sc(52),
		frameHeight + Sc(40), Color(0, 0, 0, 140 * alpha))

	draw.RoundedBox(radius, x, y, frameWidth, frameHeight,
		Color(11, 12, 14, 246 * alpha))

	local bReady = self.open >= 0.99

	if (IsValid(self.searchEntry)) then
		self.searchEntry:SetVisible(bReady)
	end

	if (IsValid(self.scroll)) then
		self.scroll:SetVisible(bReady)
	end

	for _, button in ipairs(self.controls) do
		if (IsValid(button)) then
			button:SetVisible(bReady)
		end
	end

	if (IsValid(self.close)) then
		self.close:SetVisible(bReady)
	end

	if (!bReady) then
		return
	end

	local barHeight = self:GetBarHeight()

	util.DrawSimpleTextShadow(util.Upper(L("helpCmdTitle")), "nwMenuItem",
		x + Sc(24), y + math.Round(barHeight * 0.5) - Sc(9),
		ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	util.DrawTextSpaced(util.Upper(L("helpCmdCount", self.count or 0)),
		"nwHudLabelSmall", x + Sc(24), y + math.Round(barHeight * 0.5) + Sc(12),
		ColorAlpha(theme.textDim, 230 * alpha), Sc(3))

	surface.SetDrawColor(255, 255, 255, 16 * alpha)
	surface.DrawRect(x + Sc(20), y + barHeight - 1, frameWidth - Sc(40), 1)

	draw.SimpleText(util.Upper(L("helpCmdHint")), "nwHudLabelSmall",
		x + math.Round(frameWidth * 0.5), y + frameHeight + Sc(16),
		ColorAlpha(theme.textFaint, 220 * alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)

	if ((self.count or 0) == 0) then
		draw.SimpleText(L("helpCmdEmpty"), "nwField",
			x + math.Round(frameWidth * 0.5), y + math.Round(frameHeight * 0.55),
			ColorAlpha(theme.textFaint, 235 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwCommandHelp", PANEL, "EditablePanel")

net.Receive("nwCommandHelp", function()
	local list = NETWORK.util.ReadTable() or {}

	NETWORK.gui.CloseWindows()

	if (IsValid(NETWORK.gui.commandHelp)) then
		NETWORK.gui.commandHelp:Remove()
	end

	local panel = vgui.Create("nwCommandHelp")

	panel:Setup(list)
end)
