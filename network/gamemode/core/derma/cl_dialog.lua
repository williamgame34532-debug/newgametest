local PANEL = {}

function PANEL:Init()
	self.alpha = 0

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
end

function PANEL:Setup(title, text, bInput, default, callback)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme

	self.title = title or ""
	self.text = text or ""
	self.callback = callback

	if (bInput) then
		local entry = self:Add("DTextEntry")

		entry:SetFont("nwChatSmall")
		entry:SetDrawLanguageID(false)
		entry:SetAllowNonAsciiCharacters(true)
		entry:SetPaintBackground(false)
		entry:SetTextColor(theme.text)
		entry:SetCursorColor(theme.accent)
		entry:SetValue(default or "")
		entry.OnEnter = function()
			self:Confirm()
		end
		entry.Paint = function(panel, width, height)
			draw.RoundedBox(Sc(6), 0, 0, width, height,
				Color(255, 255, 255, 12))

			panel:DrawTextEntryText(theme.text, theme.accentDeep, theme.accent)
		end

		self.entry = entry

		timer.Simple(0, function()
			if (IsValid(entry)) then
				entry:RequestFocus()
			end
		end)
	end

	self.accept = self:AddButton(L("dialogAccept"), function()
		self:Confirm()
	end, true)

	self.cancel = self:AddButton(L("dialogCancel"), function()
		self:Remove()
	end)

	self:InvalidateLayout(true)
end

function PANEL:AddButton(label, callback, bPrimary)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local button = self:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button.DoClick = callback
	button.Paint = function(panel, width, height)
		local hover = panel:IsHovered() and 1 or 0
		local base = bPrimary and theme.accent or theme.line

		draw.RoundedBox(Sc(6), 0, 0, width, height,
			Color(base.r, base.g, base.b, (bPrimary and 30 or 16) + 22 * hover))

		draw.SimpleText(NETWORK.util.Upper(label), "nwField",
			math.Round(width * 0.5), math.Round(height * 0.5),
			ColorAlpha(theme.text, 250 * self.alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end

	return button
end

function PANEL:Confirm()
	if (self.callback) then
		self.callback(IsValid(self.entry) and self.entry:GetValue() or nil)
	end

	self:Remove()
end

function PANEL:GetCardWidth()
	return math.min(NETWORK.util.Scale(440), math.Round(ScrW() * 0.42))
end

function PANEL:GetCardHeight()
	return NETWORK.util.Scale(IsValid(self.entry) and 206 or 168)
end

function PANEL:PerformLayout()
	local Sc = NETWORK.util.Scale
	local width = self:GetCardWidth()
	local height = self:GetCardHeight()
	local x = math.Round((ScrW() - width) * 0.5)
	local y = math.Round((ScrH() - height) * 0.5)
	local inner = width - Sc(48)

	if (IsValid(self.entry)) then
		self.entry:SetPos(x + Sc(24), y + Sc(104))
		self.entry:SetSize(inner, Sc(32))
	end

	local buttonWidth = math.Round((inner - Sc(10)) * 0.5)
	local buttonY = y + height - Sc(56)

	if (IsValid(self.cancel)) then
		self.cancel:SetPos(x + Sc(24), buttonY)
		self.cancel:SetSize(buttonWidth, Sc(38))
	end

	if (IsValid(self.accept)) then
		self.accept:SetPos(x + Sc(24) + buttonWidth + Sc(10), buttonY)
		self.accept:SetSize(buttonWidth, Sc(38))
	end
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 12)
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local alpha = self.alpha

	surface.SetDrawColor(0, 0, 0, 170 * alpha)
	surface.DrawRect(0, 0, width, height)

	local cardWidth = self:GetCardWidth()
	local cardHeight = self:GetCardHeight()
	local x = math.Round((width - cardWidth) * 0.5)
	local y = math.Round((height - cardHeight) * 0.5)

	draw.RoundedBox(Sc(10), x, y, cardWidth, cardHeight,
		Color(24, 25, 29, 248 * alpha))

	draw.SimpleText(NETWORK.util.Upper(self.title), "nwField", x + Sc(24),
		y + Sc(32), ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	local lineY = y + Sc(58)

	for _, line in ipairs(NETWORK.util.WrapText(self.text, "nwChatSmall",
		cardWidth - Sc(48), 3)) do
		draw.SimpleText(line, "nwChatSmall", x + Sc(24), lineY,
			ColorAlpha(theme.textDim, 240 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_TOP)

		lineY = lineY + Sc(18)
	end
end

vgui.Register("nwDialog", PANEL, "EditablePanel")

function NETWORK.gui.Prompt(title, text, default, callback)
	local panel = vgui.Create("nwDialog")

	panel:Setup(title, text, true, default, callback)

	return panel
end

function NETWORK.gui.Confirm(title, text, callback)
	local panel = vgui.Create("nwDialog")

	panel:Setup(title, text, false, nil, callback)

	return panel
end
