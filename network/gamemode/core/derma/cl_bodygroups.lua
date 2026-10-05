local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.bodygroups = self

	self.alpha = 0
	self.groups = {}
	self.skin = LocalPlayer():GetSkin()

	self:SetSize(math.min(Sc(460), ScrW() - Sc(60)),
		math.min(Sc(560), ScrH() - Sc(80)))
	self:SetPos(ScrW(), math.Round((ScrH() - Sc(560)) * 0.5))
	self:MakePopup()

	self.slide = 0

	self.list = self:Add("DScrollPanel")

	local bar = self.list:GetVBar()

	bar:SetWide(Sc(4))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(2), 0, 0, width, height, Color(255, 255, 255, 60))
	end

	self.apply = self:Add("nwActionButton")
	self.apply:SetLabel(L("bgApply"))
	self.apply:SetPrimary(true)
	self.apply.DoClick = function()
		net.Start("nwBodygroupEdit")
			NETWORK.util.WriteTable({groups = self.groups, skin = self.skin})
		net.SendToServer()

		NETWORK.gui.Notify(L("adminDone"), NETWORK.theme.accentSoft)
	end

	self:Rebuild()
end

function PANEL:OnRemove()
	if (NETWORK.gui.bodygroups == self) then
		NETWORK.gui.bodygroups = nil
	end
end

function PANEL:Row(label, getter, setter, maximum)
	local Sc = NETWORK.util.Scale
	local row = self.list:Add("DPanel")

	row:Dock(TOP)
	row:DockMargin(0, 0, Sc(12), Sc(4))
	row:SetTall(Sc(46))
	row.hover = 0
	row.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
	end
	row.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local util = NETWORK.util
		local value = getter()

		surface.SetDrawColor(theme.plateDeep.r, theme.plateDeep.g, theme.plateDeep.b,
			200 + 35 * panel.hover)
		surface.DrawRect(0, 0, width, height)

		util.DrawScanlines(0, 0, width, height, 18)

		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
			150 + 90 * panel.hover)
		surface.DrawRect(0, 0, math.max(Sc(3), 2), height)

		draw.SimpleText(label, "nwChatSmall", Sc(16), math.Round(height * 0.5) - Sc(6),
			ColorAlpha(theme.text, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local barWidth = width - Sc(130)

		surface.SetDrawColor(9, 24, 32, 230)
		surface.DrawRect(Sc(16), math.Round(height * 0.5) + Sc(9), barWidth, Sc(4))

		if (maximum > 0) then
			surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 245)
			surface.DrawRect(Sc(16), math.Round(height * 0.5) + Sc(9),
				math.Round(barWidth * (value / maximum)), Sc(4))

			for notch = 1, maximum - 1 do
				surface.SetDrawColor(5, 12, 17, 220)
				surface.DrawRect(Sc(16) + math.Round(barWidth * (notch / maximum)),
					math.Round(height * 0.5) + Sc(9), math.max(Sc(1), 1), Sc(4))
			end
		end

		draw.SimpleText(value .. " / " .. maximum, "nwHudSmall", width - Sc(84),
			math.Round(height * 0.5), ColorAlpha(theme.value, 250), TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)
	end

	local function Button(text, delta, offset)
		local button = row:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button:SetSize(Sc(30), Sc(28))
		button:SetPos(offset, Sc(6))
		button.hover = 0
		button.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
		end
		button.Paint = function(panel, width, height)
			local theme = NETWORK.theme

			surface.SetDrawColor(9, 24, 32, 215 + 40 * panel.hover)
			surface.DrawRect(0, 0, width, height)

			surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
				110 + 120 * panel.hover)
			surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(1), 1))

			draw.SimpleText(text, "nwField", math.Round(width * 0.5),
				math.Round(height * 0.5),
				ColorAlpha(theme.accentSoft, 235 + 20 * panel.hover),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			setter(math.Clamp(getter() + delta, 0, maximum))

			NETWORK.sound.Soft()
		end

		return button
	end

	row.PerformLayout = function(panel, width, height)
		local children = panel:GetChildren()

		for index, child in ipairs(children) do
			child:SetPos(width - Sc(76) + (index - 1) * Sc(34), Sc(6))
		end
	end

	Button("-", -1, 0)
	Button("+", 1, 0)

	return row
end

function PANEL:Preview()
	if ((self.nextPreview or 0) > CurTime()) then
		self.bPending = true

		return
	end

	self.nextPreview = CurTime() + 0.15
	self.bPending = false

	net.Start("nwBodygroupEdit")
		NETWORK.util.WriteTable({groups = self.groups, skin = self.skin})
	net.SendToServer()
end

function PANEL:Rebuild()
	local client = LocalPlayer()

	self.list:Clear()

	for _, data in pairs(client:GetBodyGroups() or {}) do
		if (data.num <= 1) then
			continue
		end

		local id = data.id

		self.groups[id] = self.groups[id] or client:GetBodygroup(id)

		self:Row(data.name .. "  [" .. id .. "]", function()
			return self.groups[id] or 0
		end, function(value)
			self.groups[id] = value

			self:Preview()
		end, data.num - 1)
	end

	if (client:SkinCount() > 1) then
		self:Row(L("bgSkin"), function()
			return self.skin
		end, function(value)
			self.skin = value

			self:Preview()
		end, client:SkinCount() - 1)
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.list:SetPos(Sc(16), Sc(56))
	self.list:SetSize(width - Sc(32), height - Sc(116))

	self.apply:SetPos(Sc(16), height - Sc(52))
	self.apply:SetSize(width - Sc(32), Sc(40))
end

function PANEL:Think()
	local Sc = NETWORK.util.Scale

	self.alpha = NETWORK.util.Approach(self.alpha, 1, 12)
	self.slide = NETWORK.util.Approach(self.slide or 0, 1, 7)

	local target = ScrW() - self:GetWide() - Sc(60)

	self:SetPos(Lerp(NETWORK.util.EaseOut(self.slide), ScrW(), target), self:GetY())

	if (self.bPending and (self.nextPreview or 0) < CurTime()) then
		self:Preview()
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:OnMousePressed(code)
	local Sc = NETWORK.util.Scale
	local x, y = self:CursorPos()

	if (code == MOUSE_LEFT and x >= self:GetWide() - Sc(40) and y <= Sc(40)) then
		NETWORK.sound.Click()

		self:Remove()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util

	util.DrawPanel(0, 0, width, height, self.alpha, {bBrackets = true})
	util.DrawTitleBar(0, 0, width, Sc(40), L("bgTitle"), self.alpha)

	local bHover = self:IsHovered() and gui.MouseX() >= self:GetX() + width - Sc(40)

	draw.SimpleText("×", "nwTab", width - Sc(20), Sc(20),
		ColorAlpha(bHover and NETWORK.theme.danger or NETWORK.theme.textDim,
			250 * self.alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("nwBodygroups", PANEL, "EditablePanel")

NETWORK.view.Register("bodygroups", 12, function(client, view)
	if (!IsValid(NETWORK.gui.bodygroups)) then
		return
	end

	local angles = client:EyeAngles()
	local forward = angles:Forward()

	forward.z = 0
	forward:Normalize()

	local center = client:GetPos() + Vector(0, 0, 40)
	local position = center + forward * 96 + angles:Right() * -28 + Vector(0, 0, 14)

	view.origin = position
	view.angles = (center - position):Angle()
	view.fov = 52
	view.drawviewer = true

	return "stop"
end)

net.Receive("nwBodygroupEdit", function()
	NETWORK.util.ReadTable()

	if (IsValid(NETWORK.gui.bodygroups)) then
		NETWORK.gui.bodygroups:Remove()
	end

	vgui.Create("nwBodygroups")
end)
