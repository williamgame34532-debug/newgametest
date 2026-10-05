local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0

	self:SetSize(math.min(Sc(460), math.Round(ScrW() * 0.86)),
		math.min(Sc(360), math.Round(ScrH() * 0.86)))
	self:Center()
	self:MakePopup()

	self.text = self:Add("DTextEntry")
	self.text:SetFont("nwChatSmall")
	self.text:SetPaintBackground(false)
	self.text:SetMultiline(true)
	self.text:SetTextColor(NETWORK.theme.text)
	self.text:SetCursorColor(NETWORK.theme.accent)
	self.text.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(6), 0, 0, width, height, Color(255, 255, 255, 14))

		panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.accentDeep,
			NETWORK.theme.accent)
	end

	self.size = self:Add("nwOptSlider")
	self.red = self:Add("nwOptSlider")
	self.green = self:Add("nwOptSlider")
	self.blue = self:Add("nwOptSlider")

	self.save = self:Add("nwActionButton")
	self.save:SetLabel(L("zoneSave"))
	self.save:SetPrimary(true)
	self.save.DoClick = function()
		if (IsValid(self.entity)) then
			NETWORK.gui.SendTextConfig(self.entity, {
				text = self.text:GetValue(),
				size = self.values.size,
				r = self.values.r,
				g = self.values.g,
				b = self.values.b
			})
		end

		self:Remove()
	end
end

function PANEL:Setup(entity)
	local color = entity:GetTextColor()

	self.entity = entity
	self.values = {
		size = entity:GetTextSize(),
		r = color.x,
		g = color.y,
		b = color.z
	}

	self.text:SetValue(entity:GetText())

	self.size:Setup(function()
		return self.values.size
	end, function(value)
		self.values.size = value
	end, 4, 200, 0, false)

	for key, slider in pairs({r = self.red, g = self.green, b = self.blue}) do
		slider:Setup(function()
			return self.values[key]
		end, function(value)
			self.values[key] = value
		end, 0, 1, 2, false)
	end

	self:InvalidateLayout(true)
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.text:SetPos(Sc(20), Sc(64))
	self.text:SetSize(width - Sc(40), Sc(76))

	local y = Sc(158)

	for _, slider in ipairs({self.size, self.red, self.green, self.blue}) do
		slider:SetPos(Sc(20), y)
		slider:SetSize(width - Sc(40), Sc(30))

		y = y + Sc(38)
	end

	self.save:SetPos(Sc(20), height - Sc(52))
	self.save:SetSize(width - Sc(40), Sc(40))
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
	local util = NETWORK.util

	util.DrawBlur(self, 5 * self.alpha, 0.3)

	draw.RoundedBox(Sc(12), 0, 0, width, height, Color(9, 12, 17, 248 * self.alpha))

	util.DrawTextSpaced(util.Upper(L("textConfig")), "nwTab", Sc(20), Sc(28),
		ColorAlpha(theme.text, 250 * self.alpha), Sc(4), TEXT_ALIGN_CENTER)

	local labels = {L("textSize"), "R", "G", "B"}
	local y = Sc(150)

	for i = 1, #labels do
		draw.SimpleText(labels[i], "nwHudSmall", Sc(20), y,
			ColorAlpha(theme.textFaint, 220 * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		y = y + Sc(38)
	end
end

vgui.Register("nwTextConfig", PANEL, "EditablePanel")

function NETWORK.gui.OpenTextConfig(entity)
	if (!IsValid(entity)) then
		return
	end

	local panel = vgui.Create("nwTextConfig")

	panel:Setup(entity)

	return panel
end
