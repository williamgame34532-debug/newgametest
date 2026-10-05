local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.recognise = self

	self.alpha = 0
	self.bClosing = false
	self.buttons = {}

	self:SetSize(Sc(420), Sc(78) + #NETWORK.recognition.modes * Sc(52))
	self:Center()
	self:MakePopup()

	for index, mode in ipairs(NETWORK.recognition.modes) do
		local button = self:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button.hover = 0
		button.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 13)
		end
		button.Paint = function(panel, width, height)
			local theme = NETWORK.theme
			local util = NETWORK.util
			local hover = util.EaseInOut(panel.hover)
			local reveal = util.EaseOut(util.Stagger(self.startTime or CurTime(),
				index * 0.04, 0.35))
			local x = math.Round(hover * Sc(10))

			draw.RoundedBox(Sc(8), x, 0, width, height,
				Color(14, 19, 28, (200 + 45 * hover) * self.alpha * reveal))
			draw.RoundedBox(Sc(3), x, Sc(10), math.max(Sc(3), 2), height - Sc(20),
				ColorAlpha(theme.accent, (140 + 115 * hover) * self.alpha * reveal))

			draw.SimpleText(L(mode.name), "nwField", x + Sc(22), math.Round(height * 0.5) - Sc(8),
				ColorAlpha(theme.text, (215 + 40 * hover) * self.alpha * reveal),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local hint = mode.id == "target" and L("recogTargetHint") or
				(mode.hint and L(mode.hint)) or
				(L("recogRange") .. ": " .. mode.range)

			draw.SimpleText(hint, "nwChatSmall", x + Sc(22), math.Round(height * 0.5) + Sc(12),
				ColorAlpha(theme.textDim, 230 * self.alpha * reveal), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			NETWORK.sound.Click()

			NETWORK.recognition.Send(mode.id)

			self:Close()
		end

		self.buttons[index] = button
	end

	self.startTime = CurTime()
end

function PANEL:OnRemove()
	if (NETWORK.gui.recognise == self) then
		NETWORK.gui.recognise = nil
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	for index, button in ipairs(self.buttons) do
		button:SetSize(width - Sc(40), Sc(46))
		button:SetPos(Sc(20), Sc(64) + (index - 1) * Sc(52))
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
	end
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 12)

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE or key == KEY_F3) then
		self:Close()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util

	util.DrawBlur(self, 5 * self.alpha, 0.3)

	draw.RoundedBox(Sc(12), 0, 0, width, height, Color(9, 12, 17, 248 * self.alpha))
	draw.RoundedBoxEx(Sc(12), 0, 0, width, Sc(5), ColorAlpha(theme.accent, 240 * self.alpha),
		true, true, false, false)

	util.DrawTextSpaced(util.Upper(L("recogTitle")), "nwTab", Sc(22), Sc(34),
		ColorAlpha(theme.text, 252 * self.alpha), Sc(4), TEXT_ALIGN_CENTER)
end

vgui.Register("nwRecognise", PANEL, "EditablePanel")

function NETWORK.gui.OpenRecognise()
	if (IsValid(NETWORK.gui.recognise)) then
		NETWORK.gui.recognise:Close()

		return
	end

	if (!LocalPlayer():HasCharacter()) then
		return
	end

	return vgui.Create("nwRecognise")
end
