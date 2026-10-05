local P = NETWORK.pvp

local PANEL = {}

function PANEL:Init()
	if (IsValid(NETWORK.gui.pvpTeam)) then
		NETWORK.gui.pvpTeam:Remove()
	end

	NETWORK.gui.pvpTeam = self

	local Sc = NETWORK.util.Scale

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.alpha = 0
	self.tiles = {}

	for _, id in ipairs(P.order) do
		local data = P.GetTeam(id)
		local tile = self:Add("DButton")

		tile:SetText("")
		tile:SetSize(Sc(280), Sc(180))
		tile.DoClick = function()
			net.Start("nwPvpNotice")
				net.WriteUInt(id, 4)
			net.SendToServer()

			surface.PlaySound("buttons/button15.wav")

			self:Remove()
		end
		tile.Paint = function(this, width, height)
			local bHover = this:IsHovered()

			surface.SetDrawColor(10, 11, 13, bHover and 245 or 200)
			surface.DrawRect(0, 0, width, height)

			surface.SetDrawColor(data.color.r, data.color.g, data.color.b,
				bHover and 240 or 90)
			surface.DrawOutlinedRect(0, 0, width, height, bHover and 2 or 1)
			surface.DrawRect(0, 0, width, Sc(4))

			draw.SimpleText(NETWORK.util.Upper(L(data.name)), "nwInvTitle",
				width * 0.5, height * 0.44, data.color, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)

			local count = 0

			for _, other in ipairs(player.GetAll()) do
				if (other:Team() == id) then
					count = count + 1
				end
			end

			draw.SimpleText(L("pvpTeamCount", count, P.GetScore(id)),
				"nwHudSmall", width * 0.5, height * 0.62,
				NETWORK.theme.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		self.tiles[#self.tiles + 1] = tile
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale
	local gap = Sc(28)
	local total = #self.tiles * Sc(280) + (#self.tiles - 1) * gap
	local x = math.Round((width - total) * 0.5)

	for index, tile in ipairs(self.tiles) do
		tile:SetPos(x + (index - 1) * (Sc(280) + gap),
			math.Round(height * 0.4))
	end
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha or 0, 1, 6)
end

function PANEL:Paint(width, height)
	local alpha = NETWORK.util.EaseOut(self.alpha or 0)

	surface.SetDrawColor(4, 5, 6, 235 * alpha)
	surface.DrawRect(0, 0, width, height)

	draw.SimpleText(NETWORK.util.Upper(L("pvpPickSide")), "nwTermTitle",
		width * 0.5, height * 0.28,
		ColorAlpha(NETWORK.theme.text, 250 * alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

vgui.Register("nwPvpTeamMenu", PANEL, "EditablePanel")

PANEL = {}

function PANEL:Init()
	if (IsValid(NETWORK.gui.pvpScores)) then
		NETWORK.gui.pvpScores:Remove()
	end

	NETWORK.gui.pvpScores = self

	local Sc = NETWORK.util.Scale

	self:SetSize(Sc(720), Sc(460))
	self:Center()
	self:MakePopup()

	self.rows = {}

	net.Start("nwPvpTeamMenu")
		net.WriteBool(true)
	net.SendToServer()
end

function PANEL:SetData(list)
	self.rows = list or {}
end

function PANEL:OnRemove()
	net.Start("nwPvpTeamMenu")
		net.WriteBool(false)
	net.SendToServer()

	if (NETWORK.gui.pvpScores == self) then
		NETWORK.gui.pvpScores = nil
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale

	NETWORK.util.DrawBlur(self, 6)

	surface.SetDrawColor(8, 9, 11, 240)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(255, 255, 255, 20)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	draw.SimpleText(NETWORK.util.Upper(L("pvpScores")), "nwField",
		width * 0.5, Sc(22), NETWORK.theme.text, TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)

	local columnWidth = (width - Sc(60)) * 0.5

	for index, id in ipairs(P.order) do
		local data = P.GetTeam(id)
		local x = Sc(20) + (index - 1) * (columnWidth + Sc(20))
		local y = Sc(58)

		surface.SetDrawColor(data.color.r, data.color.g, data.color.b, 40)
		surface.DrawRect(x, y, columnWidth, Sc(34))

		surface.SetDrawColor(data.color)
		surface.DrawRect(x, y, math.max(Sc(3), 2), Sc(34))

		draw.SimpleText(NETWORK.util.Upper(L(data.name)), "nwField",
			x + Sc(14), y + Sc(17), data.color, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		draw.SimpleText(L("pvpScoreValue", P.GetScore(id)), "nwField",
			x + columnWidth - Sc(14), y + Sc(17), NETWORK.theme.text,
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		y = y + Sc(44)

		draw.SimpleText(L("pvpColumnsWins"), "nwHudSmall",
			x + columnWidth - Sc(14), y, NETWORK.theme.textFaint,
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		y = y + Sc(16)

		for _, row in ipairs(self.rows) do
			if (row.team != id) then
				continue
			end

			local color = row.bDead and NETWORK.theme.textFaint or
				NETWORK.theme.text

			draw.SimpleText(row.name, "nwHudSmall", x + Sc(14), y,
				color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText((row.wins or 0) .. " / " .. (row.losses or 0),
				"nwHudSmall", x + columnWidth - Sc(14), y,
				color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			draw.SimpleText(L("pvpKillsShort", row.kills or 0, row.deaths or 0),
				"nwInvKey", x + columnWidth - Sc(76), y,
				NETWORK.theme.textFaint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			y = y + Sc(20)
		end
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

vgui.Register("nwPvpScores", PANEL, "EditablePanel")

net.Receive("nwPvpTeamData", function()
	local list = NETWORK.util.ReadTable()

	if (IsValid(NETWORK.gui.pvpScores)) then
		NETWORK.gui.pvpScores:SetData(list)
	end
end)

net.Receive("nwPvpNotice", function()
	local id = net.ReadString()

	if (id == "team") then
		vgui.Create("nwPvpTeamMenu")
	elseif (id == "scores") then
		vgui.Create("nwPvpScores")
	end
end)

local posX = CreateClientConVar("network_ch_panel_x", "-1", true, false)
local posY = CreateClientConVar("network_ch_panel_y", "-1", true, false)

PANEL = {}

function PANEL:Init()
	if (IsValid(NETWORK.gui.crosshair)) then
		NETWORK.gui.crosshair:Remove()
	end

	NETWORK.gui.crosshair = self

	local Sc = NETWORK.util.Scale

	self.header = Sc(34)

	self:SetSize(Sc(320), Sc(400))
	self:MakePopup()

	local x, y = posX:GetInt(), posY:GetInt()

	if (x < 0 or y < 0) then
		self:SetPos(Sc(40), ScrH() * 0.5 - Sc(200))
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

		surface.SetDrawColor(color)

		local pad = math.Round(width * 0.34)

		surface.DrawLine(pad, pad, width - pad, height - pad)
		surface.DrawLine(width - pad, pad, pad, height - pad)
	end

	self.close = close

	local list = self:Add("DScrollPanel")

	list:Dock(FILL)
	list:DockMargin(Sc(10), self.header + Sc(6), Sc(10), Sc(10))

	self:AddChoice(list, "chStyle", "network_ch_style", P.styles)
	self:AddSlider(list, "chSize", "network_ch_size", 1, 60)
	self:AddSlider(list, "chGap", "network_ch_gap", 0, 40)
	self:AddSlider(list, "chThick", "network_ch_thick", 1, 10)
	self:AddSlider(list, "chRed", "network_ch_r", 0, 255)
	self:AddSlider(list, "chGreen", "network_ch_g", 0, 255)
	self:AddSlider(list, "chBlue", "network_ch_b", 0, 255)
end

function PANEL:AddChoice(parent, label, convar, values)
	local Sc = NETWORK.util.Scale
	local button = parent:Add("DButton")

	button:Dock(TOP)
	button:DockMargin(0, 0, 0, Sc(6))
	button:SetTall(Sc(32))
	button:SetText("")
	button.DoClick = function()
		local current = GetConVar(convar):GetString()
		local index = 1

		for number, value in ipairs(values) do
			if (value == current) then
				index = number % #values + 1

				break
			end
		end

		RunConsoleCommand(convar, values[index])
	end
	button.Paint = function(this, width, height)
		surface.SetDrawColor(14, 15, 17, 235)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(255, 255, 255, this:IsHovered() and 60 or 22)
		surface.DrawOutlinedRect(0, 0, width, height, 1)

		draw.SimpleText(L(label), "nwHudSmall", Sc(10), height * 0.5,
			NETWORK.theme.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(GetConVar(convar):GetString(), "nwHudSmall",
			width - Sc(10), height * 0.5, NETWORK.theme.text,
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

function PANEL:AddSlider(parent, label, convar, minimum, maximum)
	local Sc = NETWORK.util.Scale
	local slider = parent:Add("DNumSlider")

	slider:Dock(TOP)
	slider:DockMargin(0, 0, 0, Sc(4))
	slider:SetTall(Sc(34))
	slider:SetText(L(label))
	slider:SetMin(minimum)
	slider:SetMax(maximum)
	slider:SetDecimals(0)
	slider:SetConVar(convar)
	slider.Label:SetFont("nwHudSmall")
	slider.Label:SetTextColor(NETWORK.theme.textDim)
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

	RunConsoleCommand("network_ch_panel_x", tostring(math.Round(x)))
	RunConsoleCommand("network_ch_panel_y", tostring(math.Round(y)))
end

function PANEL:Think()
	if (!self.dragX) then
		return
	end

	local x, y = gui.MousePos()

	self:SetPos(math.Clamp(x - self.dragX, 0, ScrW() - self:GetWide()),
		math.Clamp(y - self.dragY, 0, ScrH() - self:GetTall()))
end

function PANEL:PerformLayout(width, height)
	if (IsValid(self.close)) then
		self.close:SetPos(width - self.close:GetWide(), 0)
	end
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

	draw.SimpleText(NETWORK.util.Upper(L("chTitle")), "nwHudSmall", Sc(12),
		header * 0.5, NETWORK.theme.text, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	draw.SimpleText(L("chDragHint"), "nwHudSmall", width - Sc(12),
		header * 0.5, NETWORK.theme.textFaint, TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:OnRemove()
	if (NETWORK.gui.crosshair == self) then
		NETWORK.gui.crosshair = nil
	end
end

vgui.Register("nwCrosshairEdit", PANEL, "EditablePanel")

concommand.Add("crosshairedit", function()
	vgui.Create("nwCrosshairEdit")
end)

net.Receive("nwPvpCrosshair", function()
	vgui.Create("nwCrosshairEdit")
end)
