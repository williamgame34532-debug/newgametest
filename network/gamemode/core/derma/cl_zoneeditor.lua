local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.zoneEditor = self

	self.alpha = 0
	self.selected = nil
	self.data = NETWORK.zone.Default()

	self:SetSize(math.min(Sc(640), math.Round(ScrW() * 0.86)),
		math.min(Sc(560), math.Round(ScrH() * 0.86)))
	self:Center()
	self:MakePopup()

	self.fields = self:Add("DScrollPanel")

	local bar = self.fields:GetVBar()

	bar:SetWide(Sc(4))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(2), 0, 0, width, height, Color(255, 255, 255, 60))
	end

	self.actions = self:Add("DPanel")
	self.actions.Paint = function() end
	self.actionButtons = {}
end

function PANEL:OnRemove()
	NETWORK.gui.zoneEditor = nil
end

function PANEL:Setup(zone, mins, maxs)
	self.selected = zone and zone.id or nil
	self.data = zone and table.Copy(zone) or NETWORK.zone.Default()
	self.mins = mins
	self.maxs = maxs

	self:BuildActions()
	self:Refresh()
end

function PANEL:Button(parent, label, callback, color)
	local Sc = NETWORK.util.Scale
	local button = parent:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button.hover = 0
	button.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
	end
	button.Paint = function(panel, width, height)
		local tint = color or NETWORK.theme.text
		local hover = NETWORK.util.EaseInOut(panel.hover)

		draw.RoundedBox(Sc(6), 0, 0, width, height,
			ColorAlpha(tint, 16 + 22 * hover))

		draw.SimpleText(label, "nwChatSmall", math.Round(width * 0.5), math.Round(height * 0.5),
			ColorAlpha(tint, 220 + 35 * hover), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	button.DoClick = function()
		NETWORK.sound.Click()

		callback()
	end

	return button
end

function PANEL:BuildActions()
	for _, button in ipairs(self.actionButtons) do
		if (IsValid(button)) then
			button:Remove()
		end
	end

	self.actionButtons = {}

	local buttons = {}

	if (self.selected) then
		buttons[#buttons + 1] = {L("zoneSave"), function()

			NETWORK.gui.ZoneEdit("update", {
				id = self.selected,
				data = self:Collect(),
				mins = self.mins and {self.mins.x, self.mins.y, self.mins.z},
				maxs = self.maxs and {self.maxs.x, self.maxs.y, self.maxs.z}
			})

			self:Remove()
		end}

		buttons[#buttons + 1] = {L("zoneRebound"), function()
			NETWORK.zone.rebound = {id = self.selected,
				data = table.Copy(self.data or {})}

			NETWORK.zone.editStart = nil

			NETWORK.zone.ToggleEditing(true)

			NETWORK.chat.Notify(L("zoneReboundHint"))

			self:Remove()
		end}

		buttons[#buttons + 1] = {L("zoneDelete"), function()
			NETWORK.gui.ZoneEdit("delete", {id = self.selected})

			self:Remove()
		end, NETWORK.theme.danger}
	else
		buttons[#buttons + 1] = {L("zoneCreate"), function()
			if (!self.mins or !self.maxs) then
				return
			end

			NETWORK.gui.ZoneEdit("create", {
				data = self:Collect(),
				mins = {self.mins.x, self.mins.y, self.mins.z},
				maxs = {self.maxs.x, self.maxs.y, self.maxs.z}
			})

			NETWORK.zone.editStart = nil

			self:Remove()
		end}
	end

	buttons[#buttons + 1] = {L("zoneCancel"), function()
		self:Remove()
	end}

	for i = 1, #buttons do
		self.actionButtons[i] = self:Button(self.actions, buttons[i][1], buttons[i][2],
			buttons[i][3])
	end

	self:InvalidateLayout(true)
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	if (IsValid(self.fields)) then
		self.fields:SetPos(Sc(16), Sc(56))
		self.fields:SetSize(width - Sc(32), height - Sc(116))
	end

	if (!IsValid(self.actions)) then
		return
	end

	self.actions:SetPos(Sc(16), height - Sc(52))
	self.actions:SetSize(width - Sc(32), Sc(38))

	local count = #self.actionButtons

	if (count == 0) then
		return
	end

	local buttonWidth = math.floor((self.actions:GetWide() - Sc(8) * (count - 1)) / count)

	for i = 1, count do
		self.actionButtons[i]:SetSize(buttonWidth, Sc(38))
		self.actionButtons[i]:SetPos((i - 1) * (buttonWidth + Sc(8)), 0)
	end
end

function PANEL:Collect()
	local data = table.Copy(self.data)

	data.id = nil
	data.mins = nil
	data.maxs = nil
	data.items = table.Copy(self.data.items or {})

	return data
end

function PANEL:AddRow(label, tall, build)
	local Sc = NETWORK.util.Scale
	local row = self.fields:Add("DPanel")

	row:Dock(TOP)
	row:DockMargin(0, 0, Sc(14), Sc(6))
	row:SetTall(tall or Sc(38))
	row.Paint = function(panel, width, height)
		if (label) then
			draw.SimpleText(label, "nwChatSmall", Sc(6), math.Round(height * 0.5),
				ColorAlpha(NETWORK.theme.textDim, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	local control = build(row)

	if (IsValid(control)) then
		row.control = control
		row.PerformLayout = function(panel, width, height)
			control:SetPos(width - control:GetWide() - Sc(10),
				math.Round((height - control:GetTall()) * 0.5))
		end

		row:InvalidateLayout(true)
	end

	return row
end

function PANEL:AddNumber(label, key, min, max, decimals)
	local Sc = NETWORK.util.Scale

	self:AddRow(label, nil, function(row)
		local slider = row:Add("nwOptSlider")

		slider:SetSize(Sc(320), Sc(30))
		slider:Setup(function()
			return self.data[key] or min
		end, function(value)
			self.data[key] = value
		end, min, max, decimals or 0, false)

		return slider
	end)
end

function PANEL:AddToggle(label, key)
	local Sc = NETWORK.util.Scale

	self:AddRow(label, nil, function(row)
		local toggle = row:Add("nwOptToggle")

		toggle:SetSize(Sc(80), Sc(30))
		toggle:Setup(function()
			return self.data[key] != false
		end, function(value)
			self.data[key] = value
		end, false)

		return toggle
	end)
end

function PANEL:AddHeader(label)
	local Sc = NETWORK.util.Scale
	local header = self.fields:Add("DPanel")

	header:Dock(TOP)
	header:DockMargin(0, Sc(12), Sc(14), Sc(4))
	header:SetTall(Sc(24))
	header.Paint = function(panel, width, height)
		NETWORK.util.DrawTextSpaced(NETWORK.util.Upper(label), "nwHudSmall", Sc(6),
			math.Round(height * 0.5), ColorAlpha(NETWORK.theme.accentSoft, 235), Sc(3),
			TEXT_ALIGN_CENTER)

		surface.SetDrawColor(255, 255, 255, 14)
		surface.DrawRect(0, height - 1, width, 1)
	end

	return header
end

function PANEL:AddIconPicker(label)
	local Sc = NETWORK.util.Scale
	local icons = NETWORK.zone.icons or {}
	local cell = Sc(28)
	local step = cell + Sc(4)
	local perRow = 10
	local count = #icons + 1
	local rows = math.ceil(count / perRow)
	local gridWidth = perRow * step - Sc(4)
	local gridHeight = rows * step - Sc(4)

	self:AddRow(label, gridHeight + Sc(12), function(row)
		local holder = row:Add("DPanel")

		holder:SetSize(gridWidth, gridHeight)
		holder.Paint = function() end

		for index = 1, count do
			local id = index == 1 and "" or icons[index - 1]
			local button = holder:Add("DButton")

			button:SetText("")
			button:SetCursor("hand")
			button:SetSize(cell, cell)
			button:SetPos(((index - 1) % perRow) * step, math.floor((index - 1) / perRow) * step)
			button.hover = 0
			button.Think = function(panel)
				panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
			end
			button.Paint = function(panel, width, height)
				local theme = NETWORK.theme
				local hover = NETWORK.util.EaseInOut(panel.hover)
				local bSelected = (self.data.icon or "") == id

				surface.SetDrawColor(255, 255, 255, 12 + 18 * hover)
				surface.DrawRect(0, 0, width, height)

				if (bSelected) then
					surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b, 235)
				else
					surface.SetDrawColor(255, 255, 255, 30 + 40 * hover)
				end

				surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(1), 1))

				if (id == "") then
					draw.SimpleText("—", "nwChatSmall", math.Round(width * 0.5),
						math.Round(height * 0.5), ColorAlpha(theme.textDim, 220 + 35 * hover),
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

					return
				end

				local material = NETWORK.util.GetMaterial("framework/icons/" .. id .. ".png",
					"smooth")

				if (!material or material:IsError()) then
					return
				end

				local size = Sc(18)
				local tint = bSelected and theme.combine or theme.text

				surface.SetMaterial(material)
				surface.SetDrawColor(tint.r, tint.g, tint.b, 200 + 55 * hover)
				surface.DrawTexturedRect(math.Round((width - size) * 0.5),
					math.Round((height - size) * 0.5), size, size)
			end
			button.DoClick = function()
				NETWORK.sound.Click()

				self.data.icon = id
			end
			button.OnCursorEntered = function(panel)
				NETWORK.gui.SetTooltip(panel, {
					title = id == "" and L("zoneIconNone") or id,
					color = NETWORK.theme.combine
				})
			end
			button.OnCursorExited = function(panel)
				NETWORK.gui.ClearTooltip(panel)
			end
		end

		return holder
	end)
end

function PANEL:Refresh()
	local Sc = NETWORK.util.Scale

	self.fields:Clear()

	self:AddRow(L("zoneName"), nil, function(row)
		local entry = row:Add("DTextEntry")

		entry:SetSize(Sc(320), Sc(30))
		entry:SetFont("nwChatSmall")
		entry:SetPaintBackground(false)
		entry:SetDrawLanguageID(false)
		entry:SetUpdateOnType(true)
		entry:SetTextColor(NETWORK.theme.text)
		entry:SetCursorColor(NETWORK.theme.accent)
		entry:SetHighlightColor(NETWORK.theme.accentDeep)
		entry:SetValue(self.data.name or "")
		entry.Paint = function(panel, width, height)
			draw.RoundedBox(Sc(6), 0, 0, width, height, Color(255, 255, 255, 14))

			panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.accentDeep,
				NETWORK.theme.accent)
		end
		entry.OnValueChange = function(panel, value)
			self.data.name = value
		end
		entry.OnChange = function(panel)
			self.data.name = panel:GetValue()
		end

		return entry
	end)

	self:AddRow(L("zoneType"), nil, function(row)
		local options = {}

		for _, data in ipairs(NETWORK.zone.types) do
			options[#options + 1] = {value = data.id, label = data.name}
		end

		local choice = row:Add("nwOptChoice")

		choice:SetSize(Sc(240), Sc(30))
		choice:Setup(function()
			return self.data.type or "neutral"
		end, function(value)
			self.data.type = value

			timer.Simple(0, function()
				if (IsValid(self)) then
					self:Refresh()
				end
			end)
		end, options, false)

		return choice
	end)

	self:AddIconPicker(L("zoneIcon"))

	self:AddRow(L("zoneGreeting"), Sc(60), function(row)
		local entry = row:Add("DTextEntry")

		entry:SetSize(Sc(320), Sc(48))
		entry:SetFont("nwChatSmall")
		entry:SetPaintBackground(false)
		entry:SetDrawLanguageID(false)
		entry:SetUpdateOnType(true)
		entry:SetMultiline(true)
		entry:SetTextColor(NETWORK.theme.text)
		entry:SetCursorColor(NETWORK.theme.accent)
		entry:SetValue(self.data.greeting or "")
		entry.Paint = function(panel, width, height)
			draw.RoundedBox(Sc(6), 0, 0, width, height, Color(255, 255, 255, 14))

			panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.accentDeep,
				NETWORK.theme.accent)
		end
		entry.OnChange = function(panel)
			self.data.greeting = panel:GetValue()
		end
		entry.OnValueChange = function(panel, value)
			self.data.greeting = value
		end

		return entry
	end)

	if (self.data.type == "toxic" or self.data.type == "radiation") then
		self:AddHeader(L(self.data.type == "radiation" and "zoneRadiation" or "zoneToxic"))

		if (self.data.type == "toxic") then
			self:AddToggle(L("zoneFog"), "fog")
		end

		self:AddNumber(L("zonePriority"), "priority", 0, 100)
		self:AddNumber(L("zoneDamage"), "damage", 1, 40)
		self:AddNumber(L("zoneInterval"), "interval", 1, 20)
	end

	if (self.data.type == "loot") then
		self:AddHeader(L("zoneLoot"))
		self:AddNumber(L("zoneTotal"), "total", 1, 60)
		self:AddNumber(L("zoneBatch"), "batch", 1, 20)
		self:AddNumber(L("zoneSpawnInterval"), "spawnInterval", 5, 600)

		self:AddHeader(L("zoneItems"))

		self.data.items = self.data.items or {}

		for _, base in ipairs(NETWORK.item.GetAll()) do
			local id = base.id

			self:AddRow(nil, Sc(34), function(row)
				local holder = row:Add("DPanel")

				holder:SetSize(Sc(96), Sc(26))
				holder.Paint = function() end

				local minus = self:Button(holder, "-", function()
					self.data.items[id] = math.max((self.data.items[id] or 0) - 1, 0)

					if (self.data.items[id] == 0) then
						self.data.items[id] = nil
					end
				end)

				minus:SetSize(Sc(26), Sc(26))
				minus:SetPos(0, 0)

				local plus = self:Button(holder, "+", function()
					self.data.items[id] = (self.data.items[id] or 0) + 1
				end)

				plus:SetSize(Sc(26), Sc(26))
				plus:SetPos(Sc(70), 0)

				local count = holder:Add("DPanel")

				count:SetSize(Sc(40), Sc(26))
				count:SetPos(Sc(28), 0)
				count.Paint = function(panel, width, height)
					draw.SimpleText(tostring(self.data.items[id] or 0), "nwField",
						math.Round(width * 0.5), math.Round(height * 0.5),
						ColorAlpha(NETWORK.theme.accentSoft, 245), TEXT_ALIGN_CENTER,
						TEXT_ALIGN_CENTER)
				end

				return holder
			end).Paint = function(panel, width, height)
				local rarity = NETWORK.inventory.GetRarity(base.rarity)

				draw.RoundedBox(Sc(2), Sc(4), Sc(8), math.max(Sc(3), 2), height - Sc(16),
					ColorAlpha(rarity.color, 235))

				draw.SimpleText(base.name, "nwChatSmall", Sc(16), math.Round(height * 0.5),
					ColorAlpha(NETWORK.theme.text, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end
	end

	self.fields:InvalidateLayout(true)
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

	util.DrawTextSpaced(util.Upper(L("zoneEditor")), "nwTab", Sc(20), Sc(28),
		ColorAlpha(theme.text, 250 * self.alpha), Sc(4), TEXT_ALIGN_CENTER)

	local status = self.selected and ("#" .. self.selected) or L("zoneNew")

	draw.SimpleText(status, "nwChatSmall", width - Sc(20), Sc(28),
		ColorAlpha(theme.accentSoft, 235 * self.alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 12 * self.alpha)
	surface.DrawRect(Sc(14), Sc(48), width - Sc(28), 1)
end

vgui.Register("nwZoneEditor", PANEL, "EditablePanel")

function NETWORK.gui.ZoneEdit(action, payload)
	net.Start("nwZoneEdit")
		net.WriteString(action)
		NETWORK.util.WriteTable(payload or {})
	net.SendToServer()
end

function NETWORK.gui.OpenZoneEditor(zone, mins, maxs)
	NETWORK.gui.CloseWindows()

	local panel = vgui.Create("nwZoneEditor")

	panel:Setup(zone, mins, maxs)

	return panel
end
