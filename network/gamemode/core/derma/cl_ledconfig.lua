local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0
	self.style = 0
	self.scale = 1

	self:SetSize(math.min(Sc(460), math.Round(ScrW() * 0.86)),
		math.min(Sc(360), math.Round(ScrH() * 0.86)))
	self:Center()
	self:MakePopup()

	self.text = self:Add("DTextEntry")
	self.subtext = self:Add("DTextEntry")

	for _, entry in ipairs({self.text, self.subtext}) do
		entry:SetFont("nwChatSmall")
		entry:SetPaintBackground(false)
		entry:SetDrawLanguageID(false)
		entry:SetTextColor(NETWORK.theme.text)
		entry:SetCursorColor(NETWORK.theme.accent)
		entry.Paint = function(panel, width, height)
			draw.RoundedBox(Sc(6), 0, 0, width, height, Color(255, 255, 255, 14))

			panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.accentDeep,
				NETWORK.theme.accent)
		end
	end

	self.styleChoice = self:Add("nwOptChoice")
	self.styleChoice:Setup(function()
		return tostring(self.style)
	end, function(value)
		self.style = tonumber(value) or 0
	end, {
		{value = "0", label = "ledBlue"},
		{value = "1", label = "ledAmber"},
		{value = "2", label = "ledRed"},
		{value = "3", label = "ledGreen"}
	}, false)

	self.scaleSlider = self:Add("nwOptSlider")
	self.scaleSlider:Setup(function()
		return self.scale
	end, function(value)
		self.scale = value
	end, 0.2, 4, 2, false)

	self.save = self:Add("nwActionButton")
	self.save:SetLabel(L("zoneSave"))
	self.save:SetPrimary(true)
	self.save.DoClick = function()
		if (IsValid(self.entity)) then
			NETWORK.gui.SendLedConfig(self.entity, {
				text = self.text:GetValue(),
				subtext = self.subtext:GetValue(),
				style = self.style,
				scale = self.scale
			})
		end

		self:Remove()
	end
end

function PANEL:Setup(entity)
	self.entity = entity
	self.style = entity:GetStyle()
	self.scale = math.max(entity:GetTextScale(), 0.2)

	self.text:SetValue(entity:GetText())
	self.subtext:SetValue(entity:GetSubtext())
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.text:SetPos(Sc(20), Sc(74))
	self.text:SetSize(width - Sc(40), Sc(32))

	self.subtext:SetPos(Sc(20), Sc(136))
	self.subtext:SetSize(width - Sc(40), Sc(32))

	self.styleChoice:SetPos(Sc(20), Sc(198))
	self.styleChoice:SetSize(width - Sc(40), Sc(32))

	self.scaleSlider:SetPos(Sc(20), Sc(258))
	self.scaleSlider:SetSize(width - Sc(40), Sc(32))

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

	util.DrawTextSpaced(util.Upper(L("ledConfig")), "nwTab", Sc(20), Sc(28),
		ColorAlpha(theme.text, 250 * self.alpha), Sc(4), TEXT_ALIGN_CENTER)

	local labels = {L("ledText"), L("ledSubtext"), L("ledStyle"), L("ledScale")}
	local offsets = {Sc(60), Sc(122), Sc(184), Sc(244)}

	for i = 1, #labels do
		draw.SimpleText(labels[i], "nwChatSmall", Sc(20), offsets[i],
			ColorAlpha(theme.textDim, 230 * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwLedConfig", PANEL, "EditablePanel")

function NETWORK.gui.OpenLedConfig(entity)
	if (!IsValid(entity)) then
		return
	end

	local panel = vgui.Create("nwLedConfig")

	panel:Setup(entity)

	return panel
end
