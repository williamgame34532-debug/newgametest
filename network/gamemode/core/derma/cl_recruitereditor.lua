local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0
	self.fields = {}
	self.selected = 1

	self:SetSize(math.min(Sc(900), math.Round(ScrW() * 0.86)),
		math.min(Sc(720), math.Round(ScrH() * 0.86)))
	self:Center()
	self:MakePopup()

	self.scroll = self:Add("DScrollPanel")

	self.save = self:Add("nwActionButton")
	self.save:SetPrimary(true)
	self.save:SetLabel(L("zoneSave"))
	self.save.DoClick = function()

		local focus = vgui.GetKeyboardFocus()

		if (IsValid(focus) and focus.OnValueChange) then
			focus:OnValueChange(focus:GetValue())
		end

		NETWORK.recruiter.Save(self.id, self.data)

		self:Remove()
	end
end

function PANEL:Setup(id, position, yaw)
	self.id = id != "" and id or "default"
	self.position = position
	self.yaw = yaw
	self.data = table.Copy(NETWORK.recruiter.Get(self.id) or
		{name = "", entries = {}})

	self.data.entries = self.data.entries or {}

	self:Rebuild()
end

function PANEL:Label(text)
	local Sc = NETWORK.util.Scale
	local label = self.scroll:Add("DLabel")

	label:Dock(TOP)
	label:DockMargin(0, Sc(10), Sc(12), Sc(2))
	label:SetTall(Sc(18))
	label:SetFont("nwHudSmall")
	label:SetTextColor(NETWORK.theme.accentSoft)
	label:SetText(NETWORK.util.Upper(text))

	return label
end

function PANEL:Entry(value, callback, bMultiline)
	local Sc = NETWORK.util.Scale
	local entry = self.scroll:Add("DTextEntry")

	entry:Dock(TOP)
	entry:DockMargin(0, 0, Sc(12), 0)
	entry:SetTall(bMultiline and Sc(90) or Sc(30))
	entry:SetFont("nwChatSmall")
	entry:SetMultiline(tobool(bMultiline))
	entry:SetPaintBackground(false)
	entry:SetDrawLanguageID(false)
	entry:SetTextColor(NETWORK.theme.text)
	entry:SetCursorColor(NETWORK.theme.accent)
	entry:SetValue(tostring(value or ""))

	entry.OnValueChange = function(panel, text)
		if (self.bBuilding) then
			return
		end

		callback(text)
	end

	entry.OnChange = function(panel)
		if (self.bBuilding) then
			return
		end

		callback(panel:GetValue())
	end
	entry.Paint = function(panel, width, height)
		local theme = NETWORK.theme

		surface.SetDrawColor(9, 24, 32, 225)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
			panel:IsEditing() and 200 or 100)
		surface.DrawOutlinedRect(0, 0, width, height, 1)

		panel:DrawTextEntryText(theme.text, theme.accentDeep, theme.accent)
	end

	return entry
end

function PANEL:Button(text, callback, color)
	local Sc = NETWORK.util.Scale
	local button = self.scroll:Add("DButton")

	button:Dock(TOP)
	button:DockMargin(0, Sc(8), Sc(12), 0)
	button:SetTall(Sc(30))
	button:SetText("")
	button.DoClick = callback
	button.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local base = color or theme.accent

		surface.SetDrawColor(base.r, base.g, base.b, panel:IsHovered() and 60 or 26)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(base.r, base.g, base.b, 190)
		surface.DrawOutlinedRect(0, 0, width, height, 1)

		draw.SimpleText(NETWORK.util.Upper(text), "nwHudSmall",
			math.Round(width * 0.5), math.Round(height * 0.5), theme.text,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	return button
end

function PANEL:Rebuild()
	local Sc = NETWORK.util.Scale

	self.bBuilding = true

	self.scroll:Clear()

	self:Label(L("recruiterConfigName"))
	self:Entry(self.data.name, function(value)
		self.data.name = value
	end)

	self:Button(L("recruiterAddFaction"), function()
		self.data.entries[#self.data.entries + 1] = {
			faction = NETWORK.factions.order[1] or "citizen",
			class = "",
			uniform = "",
			title = "",
			subtitle = "",
			description = "",
			model = "",
			limit = 0,
			features = {},
			spawns = {}
		}

		self.selected = #self.data.entries

		self:Rebuild()
	end)

	for index, entry in ipairs(self.data.entries) do
		local bOpen = self.selected == index

		self:Button((bOpen and "- " or "+ ") .. (entry.title != "" and entry.title or
			entry.faction), function()
			self.selected = bOpen and 0 or index

			self:Rebuild()
		end, bOpen and NETWORK.theme.accentSoft or nil)

		if (!bOpen) then
			continue
		end

		self:Label(L("recruiterFaction") .. "  (" ..
			table.concat(NETWORK.factions.order, ", ") .. ")")
		self:Entry(entry.faction, function(value)
			value = string.Trim(string.lower(value))

			if (NETWORK.factions.Get(value)) then
				entry.faction = value
			end
		end)

		local classes = {}

		for id, data in pairs(NETWORK.classes and NETWORK.classes.list or {}) do
			if (data.faction == entry.faction) then
				classes[#classes + 1] = id
			end
		end

		table.sort(classes)

		self:Label(L("recruiterEntryClass") .. "  (" ..
			(#classes > 0 and table.concat(classes, ", ") or
			L("recruiterNoClasses")) .. ")")
		self:Entry(entry.class or "", function(value)
			entry.class = string.Trim(string.lower(value))
		end)

		self:Label(L("recruiterEntryUniform"))
		self:Entry(entry.uniform or "", function(value)
			entry.uniform = string.Trim(string.lower(value))
		end)

		self:Label(L("recruiterEntryTitle"))
		self:Entry(entry.title, function(value)
			entry.title = value
		end)

		self:Label(L("recruiterEntrySubtitle"))
		self:Entry(entry.subtitle, function(value)
			entry.subtitle = value
		end)

		self:Label(L("labelDescription"))
		self:Entry(entry.description, function(value)
			entry.description = value
		end, true)

		self:Label(L("recruiterEntryModel"))
		self:Entry(entry.model, function(value)
			entry.model = string.Trim(value)
		end)

		self:Label(L("recruiterEntryLimit"))
		self:Entry(entry.limit, function(value)
			entry.limit = math.Clamp(math.Round(tonumber(value) or 0), 0, 64)
		end)

		self:Label(L("recruiterFeatures"))

		for featureIndex = 1, #entry.features + 1 do
			self:Entry(entry.features[featureIndex] or "", function(value)

				entry.features[featureIndex] = string.Trim(value)
			end)
		end

		self:Label(L("recruiterSpawns"))

		for spawnIndex, spawn in ipairs(entry.spawns) do
			self:Entry(spawn.name, function(value)
				spawn.name = value
			end)

			self:Button(L("recruiterRemoveSpawn") .. " " .. spawnIndex, function()
				table.remove(entry.spawns, spawnIndex)

				self:Rebuild()
			end, NETWORK.theme.danger)
		end

		self:Button(L("recruiterAddSpawn"), function()
			local client = LocalPlayer()

			entry.spawns[#entry.spawns + 1] = {
				name = L("recruiterSpawn") .. " " .. (#entry.spawns + 1),
				pos = {client:GetPos().x, client:GetPos().y, client:GetPos().z},
				yaw = client:EyeAngles().y
			}

			self:Rebuild()
		end)

		self:Button(L("recruiterRemoveFaction"), function()
			table.remove(self.data.entries, index)

			self.selected = 0

			self:Rebuild()
		end, NETWORK.theme.danger)
	end

	self.bBuilding = false
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.scroll:SetPos(Sc(20), Sc(58))
	self.scroll:SetSize(width - Sc(40), height - Sc(122))

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
	local util = NETWORK.util

	util.DrawPanel(0, 0, width, height, self.alpha, {bBrackets = true})
	util.DrawTitleBar(0, 0, width, Sc(42),
		L("recruiterEditor") .. "  [" .. tostring(self.id) .. "]", self.alpha)
end

vgui.Register("nwRecruiterEditor", PANEL, "EditablePanel")

function NETWORK.gui.OpenRecruiterEditor(id, position, yaw)
	local panel = vgui.Create("nwRecruiterEditor")

	panel:Setup(id, position, yaw)

	return panel
end
