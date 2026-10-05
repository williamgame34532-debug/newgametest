local PANEL = {}

local FIELDS = {
	{convar = "network_shield_f", name = "shieldEditForward", min = -40, max = 80},
	{convar = "network_shield_r", name = "shieldEditRight", min = -40, max = 40},
	{convar = "network_shield_u", name = "shieldEditUp", min = -40, max = 40},
	{convar = "network_shield_yaw", name = "shieldEditYaw", min = -180, max = 180},
	{convar = "network_shield_pitch", name = "shieldEditPitch", min = -180, max = 180},
	{convar = "network_shield_roll", name = "shieldEditRoll", min = -180, max = 180},
	{convar = "network_shield_scale", name = "shieldEditScale", min = 0.2,
		max = 4, decimals = 2}
}

local posX = CreateClientConVar("network_shield_panel_x", "-1", true, false)
local posY = CreateClientConVar("network_shield_panel_y", "-1", true, false)

function PANEL:Init()
	if (IsValid(NETWORK.gui.shieldEdit)) then
		NETWORK.gui.shieldEdit:Remove()
	end

	NETWORK.gui.shieldEdit = self

	local Sc = NETWORK.util.Scale

	self.header = Sc(34)

	self:SetSize(Sc(330), Sc(360))
	self:MakePopup()

	local x, y = posX:GetInt(), posY:GetInt()

	if (x < 0 or y < 0) then
		self:SetPos(ScrW() - Sc(360), ScrH() * 0.5 - Sc(180))
	else
		self:SetPos(math.Clamp(x, 0, ScrW() - self:GetWide()),
			math.Clamp(y, 0, ScrH() - self:GetTall()))
	end

	local close = self:Add("DButton")

	close:SetText("")
	close:SetSize(self.header, self.header)
	close.DoClick = function()
		self:Remove()
	end
	close.Paint = function(this, width, height)
		local color = this:IsHovered() and Color(226, 96, 92) or
			NETWORK.theme.textDim
		local pad = math.Round(width * 0.34)

		surface.SetDrawColor(color)
		surface.DrawLine(pad, pad, width - pad, height - pad)
		surface.DrawLine(width - pad, pad, pad, height - pad)
	end

	self.close = close

	local list = self:Add("DScrollPanel")

	list:Dock(FILL)
	list:DockMargin(Sc(10), self.header + Sc(6), Sc(10), Sc(42))

	for _, field in ipairs(FIELDS) do
		local slider = list:Add("DNumSlider")

		slider:Dock(TOP)
		slider:DockMargin(0, 0, 0, Sc(4))
		slider:SetTall(Sc(34))
		slider:SetText(L(field.name))
		slider:SetMin(field.min)
		slider:SetMax(field.max)
		slider:SetDecimals(field.decimals or 0)
		slider:SetConVar(field.convar)
		slider.Label:SetFont("nwHudSmall")
		slider.Label:SetTextColor(NETWORK.theme.textDim)
	end

	local reset = self:Add("DButton")

	reset:SetText("")
	reset:SetSize(Sc(140), Sc(28))
	reset.DoClick = function()
		for _, field in ipairs(FIELDS) do
			local convar = GetConVar(field.convar)

			if (convar) then
				RunConsoleCommand(field.convar, convar:GetDefault())
			end
		end
	end
	reset.Paint = function(this, width, height)
		surface.SetDrawColor(14, 15, 17, 235)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(255, 255, 255, this:IsHovered() and 60 or 22)
		surface.DrawOutlinedRect(0, 0, width, height, 1)

		draw.SimpleText(L("shieldEditReset"), "nwHudSmall", width * 0.5,
			height * 0.5, NETWORK.theme.textDim, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end

	self.reset = reset
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	if (IsValid(self.close)) then
		self.close:SetPos(width - self.close:GetWide(), 0)
	end

	if (IsValid(self.reset)) then
		self.reset:SetPos(math.Round((width - self.reset:GetWide()) * 0.5),
			height - Sc(36))
	end
end

function PANEL:OnMousePressed(code)
	if (code != MOUSE_LEFT) then
		return
	end

	local x, y = self:CursorPos()

	if (y > self.header) then
		return
	end

	self.dragX, self.dragY = x, y

	self:MouseCapture(true)
end

function PANEL:OnMouseReleased()
	if (!self.dragX) then
		return
	end

	self.dragX, self.dragY = nil, nil

	self:MouseCapture(false)

	local x, y = self:GetPos()

	RunConsoleCommand("network_shield_panel_x", tostring(math.Round(x)))
	RunConsoleCommand("network_shield_panel_y", tostring(math.Round(y)))
end

function PANEL:Think()
	if (!self.dragX) then
		return
	end

	local x, y = gui.MousePos()

	self:SetPos(math.Clamp(x - self.dragX, 0, ScrW() - self:GetWide()),
		math.Clamp(y - self.dragY, 0, ScrH() - self:GetTall()))
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local header = self.header or Sc(34)

	NETWORK.util.DrawBlur(self, 6)

	surface.SetDrawColor(8, 9, 11, 242)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(255, 255, 255, 22)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	surface.SetDrawColor(14, 15, 17, 255)
	surface.DrawRect(0, 0, width, header)

	draw.SimpleText(NETWORK.util.Upper(L("shieldEditTitle")), "nwHudSmall",
		Sc(12), header * 0.5, NETWORK.theme.text, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	if (!NETWORK.shield.IsActive(LocalPlayer())) then
		draw.SimpleText(L("shieldEditRaise"), "nwHudSmall", width * 0.5,
			height - Sc(58), Color(226, 190, 120), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:OnRemove()
	if (NETWORK.gui.shieldEdit == self) then
		NETWORK.gui.shieldEdit = nil
	end
end

vgui.Register("nwShieldEdit", PANEL, "EditablePanel")

concommand.Add("nw_shieldedit", function()
	vgui.Create("nwShieldEdit")
end)
