local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0

	self:SetSize(math.min(Sc(620), math.Round(ScrW() * 0.86)),
		math.min(Sc(400), math.Round(ScrH() * 0.86)))
	self:Center()
	self:MakePopup()

	self.entry = self:Add("DTextEntry")
	self.entry:SetFont("nwField")
	self.entry:SetMultiline(true)
	self.entry:SetPaintBackground(false)
	self.entry:SetDrawLanguageID(false)
	self.entry:SetTextColor(NETWORK.theme.text)
	self.entry:SetCursorColor(NETWORK.theme.accent)
	self.entry:RequestFocus()
	self.entry.Paint = function(panel, width, height)
		local theme = NETWORK.theme

		surface.SetDrawColor(6, 16, 22, 235)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
			panel:IsEditing() and 190 or 90)
		surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(1), 1))

		panel:DrawTextEntryText(theme.text, theme.accentDeep, theme.accent)
	end

	self.save = self:Add("nwActionButton")
	self.save:SetPrimary(true)
	self.save:SetLabel(L("zoneSave"))
	self.save.DoClick = function()
		local text = string.Trim(self.entry:GetValue())
		local bValid, key, first = NETWORK.creation.ValidateDescription(text)

		if (!bValid) then
			NETWORK.gui.Notify(L(key, first), NETWORK.theme.danger)

			return
		end

		net.Start("nwSetDescription")
			net.WriteString(text)
		net.SendToServer()

		self:Remove()
	end

	self.cancel = self:Add("nwActionButton")
	self.cancel:SetLabel(L("menuBack"))
	self.cancel.DoClick = function()
		self:Remove()
	end
end

function PANEL:Setup(text)
	self.entry:SetValue(text or "")
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.entry:SetPos(Sc(24), Sc(78))
	self.entry:SetSize(width - Sc(48), height - Sc(160))

	self.save:SetPos(Sc(24), height - Sc(66))
	self.save:SetSize(math.Round((width - Sc(60)) * 0.5), Sc(42))

	self.cancel:SetPos(math.Round(width * 0.5) + Sc(6), height - Sc(66))
	self.cancel:SetSize(math.Round((width - Sc(60)) * 0.5), Sc(42))
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
	local util = NETWORK.util

	util.DrawPanel(0, 0, width, height, self.alpha, {bBrackets = true})
	util.DrawTitleBar(0, 0, width, Sc(44), L("descEditTitle"), self.alpha)

	draw.SimpleText(L("descEditHint"), "nwHudSmall", Sc(24), Sc(60),
		ColorAlpha(NETWORK.theme.textDim, 230 * self.alpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	local client = LocalPlayer()
	local character = client:GetCharacter()

	if (character) then
		draw.SimpleText(NETWORK.util.Upper(character:GetName()), "nwHudSmall",
			width - Sc(24), Sc(60), ColorAlpha(NETWORK.theme.textFaint,
			220 * self.alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwDescriptionEditor", PANEL, "EditablePanel")

function NETWORK.gui.OpenDescriptionEditor()
	local client = LocalPlayer()
	local character = client:GetCharacter()

	if (!character) then
		return
	end

	local panel = vgui.Create("nwDescriptionEditor")

	panel:Setup(character:GetDescription())

	return panel
end
