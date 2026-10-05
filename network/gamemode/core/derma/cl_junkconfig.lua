local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.junkConfig = self

	self.alpha = 0
	self.loot = {}
	self.model = ""
	self.minItems = 1
	self.maxItems = 2
	self.refill = 0

	self:SetSize(math.min(Sc(560), ScrW() - Sc(80)), math.min(Sc(700), ScrH() - Sc(120)))
	self:Center()
	self:MakePopup()

	self.list = self:Add("DScrollPanel")

	local bar = self.list:GetVBar()

	bar:SetWide(Sc(4))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(_, width, height)
		draw.RoundedBox(Sc(2), 0, 0, width, height, Color(255, 255, 255, 60))
	end

	self.save = self:Add("nwActionButton")
	self.save:SetPrimary(true)
	self.save:SetLabel(L("editorSave"))
	self.save.DoClick = function()
		if (!IsValid(self.entity)) then
			return
		end

		NETWORK.junk.SendConfig(self.entity, {
			loot = self.loot,
			model = self.model,
			minItems = self.minItems,
			maxItems = self.maxItems,
			refill = self.refill
		})

		self:Remove()
	end
end

function PANEL:OnRemove()
	NETWORK.gui.junkConfig = nil
end

function PANEL:Setup(entity)
	self.entity = entity
	self.model = entity:GetJunkModel()
	self.minItems = math.max(entity:GetMinItems(), 1)
	self.maxItems = math.max(entity:GetMaxItems(), self.minItems)
	self.refill = entity:GetRefill() or 0

	self.loot = table.Copy(NETWORK.junk.defaultLoot)

	self:Rebuild()
end

function PANEL:Stepper(row, label, callback)
	local Sc = NETWORK.util.Scale
	local button = row:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button:SetSize(Sc(26), Sc(26))
	button.hover = 0
	button.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
	end
	button.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(6), 0, 0, width, height,
			Color(255, 255, 255, 14 + 18 * panel.hover))

		draw.SimpleText(label, "nwChatSmall", math.Round(width * 0.5),
			math.Round(height * 0.5), ColorAlpha(NETWORK.theme.text, 235),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	button.DoClick = callback

	return button
end

function PANEL:Header()
	local Sc = NETWORK.util.Scale
	local row = self.list:Add("DPanel")

	row:Dock(TOP)
	row:DockMargin(0, 0, Sc(14), Sc(8))
	row:SetTall(Sc(34))
	row.Paint = function(panel, width, height)
		local text = L("junkCount") .. ": " .. self.minItems .. " - " .. self.maxItems

		draw.SimpleText(text, "nwChatSmall", Sc(8), math.Round(height * 0.5),
			ColorAlpha(NETWORK.theme.accentSoft, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	row.PerformLayout = function(panel, width)
		for index, child in ipairs(panel:GetChildren()) do
			child:SetPos(width - Sc(124) + (index - 1) * Sc(30), Sc(4))
		end
	end

	self:Stepper(row, "-", function()
		self.minItems = math.max(self.minItems - 1, 1)
		self.maxItems = math.max(self.maxItems, self.minItems)
	end)

	self:Stepper(row, "+", function()
		self.minItems = math.min(self.minItems + 1, 10)
		self.maxItems = math.max(self.maxItems, self.minItems)
	end)

	self:Stepper(row, "<", function()
		self.maxItems = math.max(self.maxItems - 1, self.minItems)
	end)

	self:Stepper(row, ">", function()
		self.maxItems = math.min(self.maxItems + 1, 10)
	end)

	local refillRow = self.list:Add("DPanel")

	refillRow:Dock(TOP)
	refillRow:DockMargin(0, 0, Sc(14), Sc(8))
	refillRow:SetTall(Sc(34))
	refillRow.Paint = function(panel, width, height)
		local value = L("junkRefillDefault")

		if (self.refill < 0) then
			value = L("junkRefillNever")
		elseif (self.refill > 0) then
			value = math.Round(self.refill / 60 * 10) / 10 .. " " ..
				L("junkRefillMinutes")
		end

		draw.SimpleText(L("junkRefill") .. ": " .. value, "nwChatSmall",
			Sc(8), math.Round(height * 0.5),
			ColorAlpha(NETWORK.theme.accentSoft, 245), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end
	refillRow.PerformLayout = function(panel, width)
		for index, child in ipairs(panel:GetChildren()) do
			child:SetPos(width - Sc(94) + (index - 1) * Sc(30), Sc(4))
		end
	end

	self:Stepper(refillRow, "-", function()

		if (self.refill <= 0) then
			self.refill = -1
		else
			self.refill = math.max(self.refill - 30, 0)
		end
	end)

	self:Stepper(refillRow, "+", function()
		if (self.refill < 0) then
			self.refill = 0
		else
			self.refill = math.min(self.refill + 30, 86400)
		end
	end)

	local field = self.list:Add("DTextEntry")

	field:Dock(TOP)
	field:DockMargin(0, 0, Sc(14), Sc(4))
	field:SetTall(Sc(30))
	field:SetFont("nwChatSmall")
	field:SetPaintBackground(false)
	field:SetDrawLanguageID(false)
	field:SetTextColor(NETWORK.theme.text)
	field:SetCursorColor(NETWORK.theme.accent)
	field:SetValue(NETWORK.junk.GetModel(self.model))
	field.OnValueChange = function(_, text)
		self.model = string.Trim(text or "")
	end
	field.OnChange = function(panel)
		self.model = string.Trim(panel:GetValue() or "")
	end
	field.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(4), 0, 0, width, height, Color(255, 255, 255, 16))

		panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.accentDeep,
			NETWORK.theme.accent)

		if (panel:GetValue() == "" and !panel:HasFocus()) then
			draw.SimpleText(L("junkModelHint"), "nwHudSmall", Sc(10),
				math.Round(height * 0.5), NETWORK.theme.textFaint,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	self.modelField = field

	local models = self.list:Add("DButton")

	models:Dock(TOP)
	models:DockMargin(0, 0, Sc(14), Sc(10))
	models:SetTall(Sc(30))
	models:SetText("")
	models:SetCursor("hand")
	models.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(4), 0, 0, width, height, Color(255, 255, 255, 16))

		draw.SimpleText(L("junkModel") .. ": " ..
			string.GetFileFromFilename(NETWORK.junk.GetModel(self.model)), "nwHudSmall",
			Sc(10), math.Round(height * 0.5), ColorAlpha(NETWORK.theme.text, 235),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	models.DoClick = function()
		local current = 1

		for index, path in ipairs(NETWORK.junk.models) do
			if (path == NETWORK.junk.GetModel(self.model)) then
				current = index
			end
		end

		self.model = NETWORK.junk.models[(current % #NETWORK.junk.models) + 1]

		if (IsValid(self.modelField)) then
			self.modelField:SetValue(self.model)
		end
	end
end

function PANEL:Rebuild()
	local Sc = NETWORK.util.Scale

	self.list:Clear()

	self:Header()

	for _, base in ipairs(NETWORK.item.GetAll()) do
		local id = base.id
		local row = self.list:Add("DPanel")

		row:Dock(TOP)
		row:DockMargin(0, 0, Sc(14), Sc(3))
		row:SetTall(Sc(34))
		row.Paint = function(panel, width, height)
			local rarity = NETWORK.inventory.GetRarity(base.rarity)
			local weight = self.loot[id] or 0

			draw.RoundedBox(Sc(2), Sc(4), Sc(9), math.max(Sc(3), 2), height - Sc(18),
				ColorAlpha(rarity.color, weight > 0 and 235 or 90))

			draw.SimpleText(base.name, "nwChatSmall", Sc(16), math.Round(height * 0.5),
				ColorAlpha(NETWORK.theme.text, weight > 0 and 235 or 130),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(weight, "nwField", width - Sc(96),
				math.Round(height * 0.5),
				ColorAlpha(weight > 0 and NETWORK.theme.accentSoft or
				NETWORK.theme.textFaint, 245), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
		row.PerformLayout = function(panel, width)
			for index, child in ipairs(panel:GetChildren()) do
				child:SetPos(width - Sc(64) + (index - 1) * Sc(30), Sc(4))
			end
		end

		self:Stepper(row, "-", function()
			self.loot[id] = math.max((self.loot[id] or 0) - 5, 0)

			if (self.loot[id] == 0) then
				self.loot[id] = nil
			end
		end)

		self:Stepper(row, "+", function()
			self.loot[id] = math.min((self.loot[id] or 0) + 5, 100)
		end)
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.list:SetPos(Sc(16), Sc(56))
	self.list:SetSize(width - Sc(32), height - Sc(116))

	self.save:SetPos(Sc(16), height - Sc(52))
	self.save:SetSize(width - Sc(32), Sc(40))
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

	util.DrawBlur(self, 5 * self.alpha, 0.3)

	draw.RoundedBox(Sc(12), 0, 0, width, height, Color(9, 12, 17, 248 * self.alpha))

	util.DrawTextSpaced(util.Upper(L("junkConfig")), "nwTab", Sc(20), Sc(28),
		ColorAlpha(NETWORK.theme.text, 250 * self.alpha), Sc(4), TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 12 * self.alpha)
	surface.DrawRect(Sc(14), Sc(48), width - Sc(28), 1)
end

vgui.Register("nwJunkConfig", PANEL, "EditablePanel")

function NETWORK.gui.OpenJunkConfig(entity)
	if (!IsValid(entity)) then
		return
	end

	local panel = vgui.Create("nwJunkConfig")

	panel:Setup(entity)

	return panel
end
