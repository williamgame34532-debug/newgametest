local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0
	self.fields = {}

	self:SetSize(math.min(Sc(560), math.Round(ScrW() * 0.86)),
		math.min(Sc(420), math.Round(ScrH() * 0.86)))
	self:Center()
	self:MakePopup()

	self.model = self:Add("DModelPanel")

	self.model:SetFOV(34)
	self.model:SetMouseInputEnabled(false)
	self.model.LayoutEntity = function(panel, entity)
		entity:SetAngles(Angle(0, RealTime() * 20 % 360, 0))
	end

	self.save = self:Add("nwActionButton")
	self.save:SetLabel(L("zoneSave"))
	self.save:SetPrimary(true)
	self.save.DoClick = function()
		if (IsValid(self.entity)) then
			NETWORK.gui.SendRecruiterConfig(self.entity, {
				name = self.fields.name:GetValue(),
				model = self.fields.model:GetValue(),
				sequence = self.fields.sequence:GetValue(),
				config = self.fields.config:GetValue()
			})
		end

		self:Remove()
	end
end

function PANEL:AddField(key, value)
	local Sc = NETWORK.util.Scale
	local entry = self:Add("DTextEntry")

	entry:SetFont("nwChatSmall")
	entry:SetPaintBackground(false)
	entry:SetDrawLanguageID(false)
	entry:SetTextColor(NETWORK.theme.text)
	entry:SetCursorColor(NETWORK.theme.accent)
	entry:SetValue(value or "")
	entry.Paint = function(panel, width, height)
		local theme = NETWORK.theme

		surface.SetDrawColor(9, 24, 32, 225)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
			panel:IsEditing() and 200 or 110)
		surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(1), 1))

		panel:DrawTextEntryText(theme.text, theme.accentDeep, theme.accent)
	end

	self.fields[key] = entry

	return entry
end

function PANEL:Setup(entity)

	for key, field in pairs(self.fields or {}) do
		if (IsValid(field)) then
			field:Remove()
		end

		self.fields[key] = nil
	end

	self.entity = entity

	self:AddField("name", entity:GetNPCName())
	self:AddField("model", entity:GetNPCModel())
	self:AddField("sequence", entity:GetNPCSequence())
	self:AddField("config", entity:GetConfigID())

	self.fields.model.OnChange = function(panel)
		self:Preview(panel:GetValue())
	end

	self:Preview(entity:GetNPCModel())
end

function PANEL:Preview(path)
	if (!IsValid(self.model) or !isstring(path) or path == "") then
		return
	end

	if (self.model:GetModel() == path or !util.IsValidModel(path)) then
		return
	end

	self.model:SetModel(path)

	local entity = self.model:GetEntity()

	if (IsValid(entity)) then
		NETWORK.util.FrameModelPanel(self.model)
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale
	local fieldWidth = width - Sc(220)
	local y = Sc(76)

	for _, key in ipairs({"name", "model", "sequence", "config"}) do
		local field = self.fields[key]

		if (IsValid(field)) then
			field:SetPos(Sc(20), y)
			field:SetSize(fieldWidth, Sc(32))
		end

		y = y + Sc(64)
	end

	if (IsValid(self.model)) then
		self.model:SetPos(width - Sc(190), Sc(70))
		self.model:SetSize(Sc(170), height - Sc(140))
	end

	self.save:SetPos(Sc(20), height - Sc(56))
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
	local alpha = self.alpha

	util.DrawBlur(self, 5 * alpha, 0.3)

	draw.RoundedBox(Sc(12), 0, 0, width, height, Color(9, 12, 17, 248 * alpha))

	util.DrawTextSpaced(util.Upper(L("recruiterConfig")), "nwTab", Sc(20), Sc(30),
		ColorAlpha(theme.text, 250 * alpha), Sc(4), TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 12 * alpha)
	surface.DrawRect(Sc(14), Sc(52), width - Sc(28), 1)

	local labels = {
		{"recruiterName", Sc(64)},
		{"labelModel", Sc(128)},
		{"labelSequence", Sc(192)},
		{"recruiterID", Sc(256)}
	}

	for _, entry in ipairs(labels) do
		draw.SimpleText(L(entry[1]), "nwHudSmall", Sc(20), entry[2],
			ColorAlpha(theme.textDim, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwRecruiterConfig", PANEL, "EditablePanel")

function NETWORK.gui.OpenRecruiterConfig(entity)
	if (!IsValid(entity)) then
		return
	end

	local panel = vgui.Create("nwRecruiterConfig")

	panel:Setup(entity)

	return panel
end
