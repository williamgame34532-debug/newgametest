local PANEL = {}

function PANEL:Init()
	NETWORK.gui.turret = self

	self.alpha = 0
	self.rows = {}
	self.values = {}

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	local Sc = NETWORK.util.Scale

	self.scroll = self:Add("DScrollPanel")
	self.scroll.Paint = function() end

	local bar = self.scroll:GetVBar()

	bar:SetWide(Sc(4))
	bar:SetHideButtons(true)
	bar.Paint = function() end
	bar.btnGrip.Paint = function(_, width, height)
		draw.RoundedBox(Sc(2), 0, 0, width, height, Color(120, 130, 150, 190))
	end

	self.cancel = self:AddButton(L("turretCancel"), function()
		self:Remove()
	end)

	self.save = self:AddButton(L("turretSave"), function()
		net.Start("nwTurretApply")
			net.WriteEntity(self.entity)
			NETWORK.util.WriteTable(self.values)
		net.SendToServer()

		self:Remove()
	end, true)

	self.pickup = self:AddButton(L("turretPickup"), function()
		net.Start("nwTurretPickup")
			net.WriteEntity(self.entity)
		net.SendToServer()

		self:Remove()
	end, false, true)

	self.allHostile = self:AddButton(L("turretAllHostile"), function()
		for _, id in ipairs(NETWORK.factions.order or {}) do
			self.values[id] = true
		end

		surface.PlaySound("ui/buttonclick.wav")
	end)

	self.allFriendly = self:AddButton(L("turretAllFriendly"), function()
		for _, id in ipairs(NETWORK.factions.order or {}) do
			self.values[id] = false
		end

		surface.PlaySound("ui/buttonclick.wav")
	end)
end

function PANEL:AddButton(label, callback, bPrimary, bDanger)
	local Sc = NETWORK.util.Scale
	local button = self:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button.DoClick = callback
	button.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local hover = panel:IsHovered() and 1 or 0
		local accent = bDanger and theme.danger or (bPrimary and theme.combine or Color(255, 255, 255))
		local radius = math.max(Sc(6), 4)

		draw.RoundedBox(radius, 0, 0, width, height, Color(10, 11, 13, 200 * self.alpha))
		draw.RoundedBox(radius, 0, 0, width, height,
			ColorAlpha(accent, ((bPrimary or bDanger) and 30 or 8) + 18 * hover) )

		NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
			ColorAlpha(accent, ((bPrimary or bDanger) and 170 or 40) + 60 * hover))

		draw.SimpleText(NETWORK.util.Upper(label), "nwHudLabelSmall",
			math.Round(width * 0.5), math.Round(height * 0.5),
			ColorAlpha((bPrimary or bDanger) and theme.text or theme.textDim, 245 * self.alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	return button
end

function PANEL:Setup(entity, values)
	self.entity = entity
	self.values = values or {}

	self.scroll:Clear()

	local Sc = NETWORK.util.Scale

	for _, id in ipairs(NETWORK.factions.order or {}) do
		local faction = NETWORK.factions.Get(id)

		if (!faction) then
			continue
		end

		local row = self.scroll:Add("DButton")

		row:SetText("")
		row:SetCursor("hand")
		row:Dock(TOP)
		row:DockMargin(0, 0, Sc(8), Sc(8))
		row:SetTall(Sc(46))
		row.DoClick = function()
			self.values[id] = !self.values[id]

			surface.PlaySound("ui/buttonclick.wav")
		end
		row.Paint = function(panel, width, height)
			local theme = NETWORK.theme
			local bHostile = self.values[id] == true
			local hover = panel:IsHovered() and 1 or 0
			local state = bHostile and theme.danger or theme.positive
			local radius = math.max(Sc(6), 4)

			draw.RoundedBox(radius, 0, 0, width, height, Color(10, 11, 13, 200 * self.alpha))
			draw.RoundedBox(radius, 0, 0, width, height,
				ColorAlpha(state, (8 + 8 * hover) * self.alpha))

			NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
				ColorAlpha(state, (60 + 60 * hover) * self.alpha))

			surface.SetDrawColor(state.r, state.g, state.b, 230 * self.alpha)
			surface.DrawRect(0, Sc(8), math.max(Sc(3), 2), height - Sc(16))

			local icon = faction.icon and NETWORK.util.GetMaterial(faction.icon, "smooth")
			local textX = Sc(16)

			if (icon and !icon:IsError()) then
				local size = Sc(22)

				surface.SetDrawColor(255, 255, 255, 220 * self.alpha)
				surface.SetMaterial(icon)
				surface.DrawTexturedRect(textX, math.Round((height - size) * 0.5), size, size)

				textX = textX + size + Sc(10)
			end

			draw.SimpleText(L(faction.name), "nwInvBody", textX,
				math.Round(height * 0.5),
				ColorAlpha(theme.text, 245 * self.alpha), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			local tagWidth = Sc(78)
			local tagHeight = Sc(24)
			local tagX = width - tagWidth - Sc(14)
			local tagY = math.Round((height - tagHeight) * 0.5)

			draw.RoundedBox(math.max(Sc(4), 3), tagX, tagY, tagWidth, tagHeight,
				ColorAlpha(state, 40 * self.alpha))
			NETWORK.util.DrawRoundedBorder(tagX, tagY, tagWidth, tagHeight, math.max(Sc(4), 3),
				math.max(Sc(1), 1), ColorAlpha(state, 200 * self.alpha))

			draw.SimpleText(NETWORK.util.Upper(L(bHostile and "turretHostile" or "turretFriendly")),
				"nwInvKey", tagX + math.Round(tagWidth * 0.5), tagY + math.Round(tagHeight * 0.5),
				ColorAlpha(state, 250 * self.alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		self.rows[#self.rows + 1] = row
	end
end

function PANEL:GetCardWidth()
	return math.min(NETWORK.util.Scale(520), math.Round(ScrW() * 0.42))
end

function PANEL:GetCardHeight()
	return math.min(NETWORK.util.Scale(640), math.Round(ScrH() * 0.72))
end

function PANEL:PerformLayout()
	local Sc = NETWORK.util.Scale
	local width = self:GetCardWidth()
	local height = self:GetCardHeight()
	local x = math.Round((ScrW() - width) * 0.5)
	local y = math.Round((ScrH() - height) * 0.5)
	local inner = width - Sc(48)
	local buttonHeight = Sc(40)
	local listBottom = y + height - Sc(24) - buttonHeight * 2 - Sc(10)

	if (IsValid(self.scroll)) then
		self.scroll:SetPos(x + Sc(24), y + Sc(132))
		self.scroll:SetSize(inner, listBottom - (y + Sc(132)))
	end

	local half = math.Round((inner - Sc(10)) * 0.5)

	if (IsValid(self.allHostile)) then
		self.allHostile:SetPos(x + Sc(24), y + Sc(92))
		self.allHostile:SetSize(half, Sc(30))
	end

	if (IsValid(self.allFriendly)) then
		self.allFriendly:SetPos(x + Sc(24) + half + Sc(10), y + Sc(92))
		self.allFriendly:SetSize(half, Sc(30))
	end

	if (IsValid(self.cancel)) then
		self.cancel:SetPos(x + Sc(24), listBottom + Sc(10))
		self.cancel:SetSize(half, buttonHeight)
	end

	if (IsValid(self.save)) then
		self.save:SetPos(x + Sc(24) + half + Sc(10), listBottom + Sc(10))
		self.save:SetSize(half, buttonHeight)
	end

	if (IsValid(self.pickup)) then
		self.pickup:SetPos(x + Sc(24), listBottom + Sc(10) + buttonHeight + Sc(8))
		self.pickup:SetSize(inner, buttonHeight)
	end
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 10)

	if (!IsValid(self.entity)) then
		self:Remove()
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_RIGHT) then
		self:Remove()
	end
end

function PANEL:OnRemove()
	if (NETWORK.gui.turret == self) then
		NETWORK.gui.turret = nil
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local alpha = self.alpha

	NETWORK.util.DrawBlur(self, 4 * alpha, 0.3)

	surface.SetDrawColor(0, 0, 0, 150 * alpha)
	surface.DrawRect(0, 0, width, height)

	local cardWidth = self:GetCardWidth()
	local cardHeight = self:GetCardHeight()
	local x = math.Round((width - cardWidth) * 0.5)
	local y = math.Round((height - cardHeight) * 0.5)

	local theme = NETWORK.theme
	local radius = math.max(Sc(10), 6)

	NETWORK.util.DrawBlurRounded(self, x, y, cardWidth, cardHeight, radius, 5 * alpha)

	draw.RoundedBox(radius, x, y, cardWidth, cardHeight, Color(10, 11, 13, 235 * alpha))

	NETWORK.util.DrawRoundedBorder(x, y, cardWidth, cardHeight, radius, math.max(Sc(1), 1),
		Color(255, 255, 255, 26 * alpha))

	surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b, 220 * alpha)
	surface.DrawRect(x + Sc(24), y + Sc(22), Sc(36), math.max(Sc(2), 2))

	draw.SimpleText(NETWORK.util.Upper(L("turretTitle")), "nwInvTitle",
		x + Sc(24), y + Sc(44), ColorAlpha(theme.text, 250 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(L("turretHint"), "nwHudSmall", x + Sc(24), y + Sc(70),
		ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
end

vgui.Register("nwTurretMenu", PANEL, "EditablePanel")

net.Receive("nwTurretMenu", function()
	local entity = net.ReadEntity()
	local values = NETWORK.util.ReadTable() or {}

	NETWORK.gui.CloseWindows()

	if (IsValid(NETWORK.gui.turret)) then
		NETWORK.gui.turret:Remove()
	end

	local panel = vgui.Create("nwTurretMenu")

	panel:Setup(entity, values)
end)
