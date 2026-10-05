local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.bindMenu = self

	self.alpha = 0
	self.bClosing = false
	self.pending = nil
	self.rows = {}

	self:SetSize(math.min(Sc(720), ScrW() - Sc(80)), math.min(Sc(640), ScrH() - Sc(120)))
	self:Center()
	self:MakePopup()

	self.close = self:Add("DButton")

	self.close:SetText("")
	self.close:SetCursor("hand")
	self.close.DoClick = function()
		surface.PlaySound("buttons/lightswitch2.wav")

		self:Close()
	end
	self.close.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local colour = panel:IsHovered() and theme.danger or theme.textDim
		local inset = Sc(9)
		local thickness = math.max(Sc(2), 2)

		NETWORK.util.DrawThickLine(inset, inset, width - inset, height - inset,
			thickness, colour)
		NETWORK.util.DrawThickLine(width - inset, inset, inset, height - inset,
			thickness, colour)
	end

	self.list = self:Add("DScrollPanel")

	local bar = self.list:GetVBar()

	bar:SetWide(Sc(4))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(_, width, height)
		draw.RoundedBox(Sc(2), 0, 0, width, height, Color(255, 255, 255, 60))
	end

	self:Rebuild()
end

function PANEL:OnRemove()
	if (NETWORK.gui.bindMenu == self) then
		NETWORK.gui.bindMenu = nil
	end
end

function PANEL:Rebuild()
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme

	self.list:Clear()
	self.rows = {}

	local binds = NETWORK.bind.GetAll()
	local columns = 2
	local cardHeight = Sc(62)
	local gap = Sc(10)

	for index, data in ipairs(binds) do
		local card = self.list:Add("DButton")
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)

		card:SetText("")
		card:SetCursor("hand")
		card:SetTall(cardHeight)
		card.column = column
		card.row = row
		card.hover = 0
		card.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
		end
		card.Paint = function(panel, width, height)
			local util = NETWORK.util
			local bWaiting = self.pending == data.id
			local key = NETWORK.bind.GetKey(data)
			local lit = math.max(panel.hover, bWaiting and 1 or 0)
			local radius = math.max(Sc(6), 4)

			draw.SimpleText(L(data.name), "nwInvKey", 0, Sc(8),
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
		card.DoClick = function()
			self.pending = data.id

			surface.PlaySound("buttons/lightswitch2.wav")

			self:RequestFocus()
		end

		local clear = card:Add("DButton")

		clear:SetText("")
		clear:SetCursor("hand")
		clear.Paint = function(panel, width, height)
			local colour = panel:IsHovered() and theme.danger or theme.textFaint
			local inset = Sc(9)

			NETWORK.util.DrawThickLine(inset, inset, width - inset, height - inset,
				math.max(Sc(1), 1), ColorAlpha(colour, 240 * self.alpha))
			NETWORK.util.DrawThickLine(width - inset, inset, inset, height - inset,
				math.max(Sc(1), 1), ColorAlpha(colour, 240 * self.alpha))
		end
		clear.DoClick = function()
			NETWORK.bind.SetKey(data, KEY_NONE)

			self.pending = nil

			surface.PlaySound("buttons/button19.wav")
		end

		card.PerformLayout = function(panel, width, height)
			clear:SetSize(Sc(28), Sc(28))
			clear:SetPos(width - Sc(30), Sc(20) + math.Round((height - Sc(24) - Sc(28)) * 0.5))
		end

		self.rows[#self.rows + 1] = card
	end

	self.list.PerformLayout = function(panel, width, height)
		local cardWidth = math.floor((width - Sc(16) - gap * (columns - 1)) / columns)

		for _, card in ipairs(self.rows) do
			if (IsValid(card)) then
				card:SetSize(cardWidth, cardHeight)
				card:SetPos(card.column * (cardWidth + gap), card.row * (cardHeight + gap))
			end
		end

		local rows = math.ceil(#self.rows / columns)

		panel:GetCanvas():SetTall(rows * (cardHeight + gap))
	end

	self.list:InvalidateLayout(true)
end

function PANEL:OnKeyCodePressed(key)
	if (!self.pending) then
		if (key == KEY_ESCAPE) then
			self:Close()
		end

		return
	end

	local data = NETWORK.bind.Get(self.pending)

	self.pending = nil

	if (!data or key == KEY_ESCAPE) then
		return
	end

	NETWORK.bind.Assign(data, key)

	surface.PlaySound("buttons/button24.wav")
end

function PANEL:OnMousePressed(code)

	if (self.pending and code != MOUSE_LEFT) then
		local data = NETWORK.bind.Get(self.pending)

		self.pending = nil

		if (data) then
			NETWORK.bind.Assign(data, code)

			surface.PlaySound("buttons/button24.wav")
		end
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.list:SetPos(Sc(18), Sc(116))
	self.list:SetSize(width - Sc(36), height - Sc(136))

	if (IsValid(self.close)) then
		self.close:SetSize(Sc(34), Sc(34))
		self.close:SetPos(width - Sc(46), Sc(14))
	end
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true
	self.pending = nil

	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 12)

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha

	local radius = math.max(Sc(10), 6)

	util.DrawBlurRounded(self, 0, 0, width, height, radius, 4 * alpha)

	draw.RoundedBox(radius, 0, 0, width, height, Color(8, 9, 10, 236 * alpha))

	util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
		Color(255, 255, 255, 26 * alpha))

	local pending = self.pending and NETWORK.bind.Get(self.pending)

	draw.SimpleText(util.Upper(L("bindTitle")), "nwInvKey", Sc(20), Sc(24),
		ColorAlpha(theme.textFaint, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(pending and L(pending.name) or L("bindSubtitle"), "nwInvTitle", Sc(20), Sc(50),
		ColorAlpha(pending and theme.combine or theme.text, 252 * alpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	draw.SimpleText(pending and L("bindPrompt") or "", "nwInvBody", Sc(20), Sc(80),
		ColorAlpha(theme.textDim, 240 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 14 * alpha)
	surface.DrawRect(Sc(18), Sc(100), width - Sc(36), 1)
end

vgui.Register("nwBindMenu", PANEL, "EditablePanel")

function NETWORK.gui.OpenBindMenu()
	if (IsValid(NETWORK.gui.bindMenu)) then
		NETWORK.gui.bindMenu:Remove()
	end

	return vgui.Create("nwBindMenu")
end
