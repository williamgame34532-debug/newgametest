local PANEL = {}

function PANEL:Init()
	local ScDefault = NETWORK.util.Scale

	self.frameWidth = ScDefault(980)
	self.frameHeight = ScDefault(600)
	self.frameX = ScDefault(140)
	self.frameY = ScDefault(120)
	self.headerHeight = ScDefault(44)
	self.listWidth = ScDefault(300)
	local Sc = NETWORK.util.Scale

	NETWORK.gui.iconEditor = self

	self.alpha = 0
	self.bClosing = false
	self.selected = nil
	self.distance = 40
	self.height = 0
	self.rotation = 0
	self.pitch = 0
	self.fov = 40
	self.sliders = {}

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.search = self:Add("DTextEntry")
	self.search:SetFont("nwChatSmall")
	self.search:SetPaintBackground(false)
	self.search:SetUpdateOnType(true)
	self.search:SetTextColor(NETWORK.theme.text)
	self.search:SetCursorColor(NETWORK.theme.accent)
	self.search.Paint = function(panel, width, height)
		surface.SetDrawColor(9, 24, 32, 225)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(NETWORK.theme.accent.r, NETWORK.theme.accent.g,
			NETWORK.theme.accent.b, 110)
		surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(1), 1))

		if (panel:GetValue() == "") then
			draw.SimpleText(L("iconSearch"), "nwChatSmall", Sc(12),
				math.Round(height * 0.5), ColorAlpha(NETWORK.theme.textFaint, 210),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.accentDeep,
			NETWORK.theme.accent)
	end
	self.search.OnValueChange = function()
		self:Rebuild()
	end

	self.list = self:Add("DScrollPanel")

	local bar = self.list:GetVBar()

	bar:SetWide(Sc(3))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(2), 0, 0, width, height, Color(255, 255, 255, 55))
	end

	self.preview = self:Add("DModelPanel")
	self.preview:SetAnimated(false)
	self.preview:SetCursor("sizeall")
	self.preview.LayoutEntity = function() end
	self.preview.OnMousePressed = function(panel, code)
		panel.bDragging = code
		panel.lastX, panel.lastY = gui.MousePos()

		panel:MouseCapture(true)
	end
	self.preview.OnMouseReleased = function(panel)
		panel.bDragging = nil

		panel:MouseCapture(false)
	end
	self.preview.OnMouseWheeled = function(panel, delta)
		self.distance = math.Clamp(self.distance - delta * 4, 6, 400)

		self:UpdatePreview()
	end
	self.preview.Think = function(panel)
		if (!panel.bDragging) then
			return
		end

		local x, y = gui.MousePos()
		local deltaX = x - (panel.lastX or x)
		local deltaY = y - (panel.lastY or y)

		panel.lastX, panel.lastY = x, y

		if (panel.bDragging == MOUSE_LEFT) then
			self.rotation = self.rotation + deltaX * 0.6
			self.pitch = math.Clamp(self.pitch + deltaY * 0.4, -80, 80)
		else
			self.height = self.height - deltaY * 0.3
		end

		self:UpdatePreview()
	end

	local function AddSlider(key, min, max, get, set)
		local slider = self:Add("nwSlider")

		slider:SetRange(min, max)
		slider:SetValue(get())
		slider.nwKey = key
		slider.nwGet = get
		slider.OnValueChanged = function(panel, value)
			if (panel.nwSilent) then
				return
			end

			set(value)

			self:UpdatePreview()
		end

		self.sliders[#self.sliders + 1] = slider

		return slider
	end

	AddSlider("iconDistance", 6, 200, function()
		return self.distance
	end, function(value)
		self.distance = value
	end)

	AddSlider("iconHeight", -60, 60, function()
		return self.height
	end, function(value)
		self.height = value
	end)

	AddSlider("iconRotation", -180, 180, function()
		return self.rotation
	end, function(value)
		self.rotation = value
	end)

	AddSlider("iconPitch", -80, 80, function()
		return self.pitch
	end, function(value)
		self.pitch = value
	end)

	AddSlider("iconFov", 5, 90, function()
		return self.fov
	end, function(value)
		self.fov = value
	end)

	self.save = self:Add("nwActionButton")
	self.save:SetPrimary(true)
	self.save:SetLabel(L("iconSave"))
	self.save.DoClick = function()
		if (!self.selected or !self.center) then
			NETWORK.gui.Notify(L("iconPickFirst"), NETWORK.theme.danger)

			return
		end

		NETWORK.icon.Send(self.selected, self:BuildData())

		NETWORK.gui.Notify(L("iconSaved"), NETWORK.theme.accentSoft)
	end

	self.reset = self:Add("nwActionButton")
	self.reset:SetLabel(L("iconReset"))
	self.reset.DoClick = function()
		if (!self.selected) then
			NETWORK.gui.Notify(L("iconPickFirst"), NETWORK.theme.danger)

			return
		end

		NETWORK.icon.Send(self.selected, {bReset = true})

		timer.Simple(0.2, function()
			if (IsValid(self)) then
				self:Select(self.selected)
			end
		end)
	end

	self.close = self:Add("nwActionButton")
	self.close:SetLabel(L("containerClose"))
	self.close.DoClick = function()
		self:Close()
	end

	local function AddField(key)
		local entry = self:Add("DTextEntry")

		entry:SetFont("nwChatSmall")
		entry:SetPaintBackground(false)
		entry:SetUpdateOnType(true)
		entry:SetTextColor(NETWORK.theme.text)
		entry:SetCursorColor(NETWORK.theme.accent)
		entry.nwKey = key
		entry.Paint = function(panel, width, height)
			surface.SetDrawColor(9, 24, 32, 225)
			surface.DrawRect(0, 0, width, height)

			surface.SetDrawColor(NETWORK.theme.accent.r, NETWORK.theme.accent.g,
				NETWORK.theme.accent.b, panel:HasFocus() and 200 or 90)
			surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(1), 1))

			panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.accentDeep,
				NETWORK.theme.accent)
		end

		return entry
	end

	self.fieldModel = AddField("iconModel")
	self.fieldGroups = AddField("iconBodygroups")
	self.fieldWeapon = AddField("iconWeapon")

	self.applyItem = self:Add("nwActionButton")
	self.applyItem:SetPrimary(true)
	self.applyItem:SetLabel(L("iconApplyItem"))
	self.applyItem.DoClick = function()
		if (!self.selected) then
			NETWORK.gui.Notify(L("iconPickFirst"), NETWORK.theme.danger)

			return
		end

		local payload = {
			model = string.Trim(self.fieldModel:GetValue()),
			weaponClass = string.Trim(self.fieldWeapon:GetValue()),
			bodygroups = NETWORK.itemedit.ParseBodygroups(self.fieldGroups:GetValue())
		}

		NETWORK.itemedit.Send(self.selected, payload)
	end

	self.resetItem = self:Add("nwActionButton")
	self.resetItem:SetLabel(L("iconResetItem"))
	self.resetItem.DoClick = function()
		if (!self.selected) then
			NETWORK.gui.Notify(L("iconPickFirst"), NETWORK.theme.danger)

			return
		end

		NETWORK.itemedit.Send(self.selected, {bReset = true})
	end

	self.createItem = self:Add("nwActionButton")
	self.createItem:SetPrimary(true)
	self.createItem:SetLabel(L("itemCreateNode"))
	self.createItem.DoClick = function()
		if (NETWORK.itemedit and NETWORK.itemedit.OpenCreator) then
			NETWORK.itemedit.OpenCreator()
		end
	end

	hook.Add("NetworkItemsEdited", self, function()
		if (IsValid(self) and self.selected) then
			self:Select(self.selected)
		end
	end)

	hook.Add("NetworkCustomItemsUpdated", self, function()
		if (!IsValid(self)) then
			return
		end

		if (self.selected and !NETWORK.item.Get(self.selected)) then
			self.selected = nil
		end

		self:Rebuild()
	end)

	self:Rebuild()
end

function PANEL:OnRemove()
	if (NETWORK.gui.iconEditor == self) then
		NETWORK.gui.iconEditor = nil
	end
end

function PANEL:BuildData()
	if (!self.center) then
		return {pos = {28, 0, 0}, ang = {0, 0, 0}, fov = self.fov or 40,
			center = {0, 0, 0}}
	end

	local radians = math.rad(self.rotation)
	local pitch = math.rad(self.pitch)
	local flat = math.cos(pitch) * self.distance

	return {
		pos = {
			self.center.x + math.cos(radians) * flat,
			self.center.y + math.sin(radians) * flat,
			self.center.z + math.sin(pitch) * self.distance + self.height
		},
		ang = {0, 0, 0},
		fov = self.fov or 40,
		center = {self.center.x, self.center.y, self.center.z}
	}
end

function PANEL:SyncSliders()
	for _, slider in ipairs(self.sliders or {}) do
		slider.nwSilent = true

		slider:SetValue(slider.nwGet())

		slider.nwSilent = nil
	end
end

function PANEL:UpdatePreview()
	self:SyncSliders()

	local entity = self.preview:GetEntity()

	if (!IsValid(entity) or !self.center) then
		return
	end

	local data = self:BuildData()

	self.preview:SetFOV(data.fov)
	self.preview:SetCamPos(Vector(data.pos[1], data.pos[2], data.pos[3]))
	self.preview:SetLookAt(self.center)
end

function PANEL:Select(id)
	local base = NETWORK.item.Get(id)

	if (!base) then
		return
	end

	self.selected = id

	self.preview:SetModel(base.model)

	if (IsValid(self.fieldModel)) then
		self.fieldModel:SetText(base.model or "")
		self.fieldGroups:SetText(NETWORK.itemedit.FormatBodygroups(base.bodygroups))
		self.fieldWeapon:SetText(base.weaponClass or "")
	end

	local entity = self.preview:GetEntity()

	if (!IsValid(entity)) then
		return
	end

	local mins, maxs = entity:GetRenderBounds()

	self.center = (mins + maxs) * 0.5

	local custom = NETWORK.icon.Get(id)

	self.bCustom = custom != nil

	if (custom) then
		local position = Vector(custom.pos[1], custom.pos[2], custom.pos[3])
		local offset = position - self.center

		self.distance = math.max(offset:Length(), 6)
		self.rotation = math.deg(math.atan2(offset.y, offset.x))
		self.pitch = math.deg(math.asin(math.Clamp(offset.z / self.distance, -1, 1)))
		self.height = 0
		self.fov = tonumber(custom.fov) or 40
	else
		local size = math.max(maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z)

		self.distance = math.max(size * 1.6, 12)
		self.rotation = 45
		self.pitch = 20
		self.height = 0
		self.fov = 40
	end

	self:UpdatePreview()
end

function PANEL:Rebuild()
	local Sc = NETWORK.util.Scale
	local filter = NETWORK.util.Lower(self.search:GetValue())

	self.list:Clear()

	for _, base in ipairs(NETWORK.item.GetAll()) do
		if (filter != "" and !string.find(NETWORK.util.Lower(base.name), filter, 1, true) and
			!string.find(base.id, filter, 1, true)) then
			continue
		end

		local button = self.list:Add("DButton")
		local rarity = NETWORK.inventory.GetRarity(base.rarity)

		button:Dock(TOP)
		button:DockMargin(0, 0, Sc(10), Sc(4))
		button:SetTall(Sc(38))
		button:SetText("")
		button:SetCursor("hand")
		button.hover = 0
		button.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
		end
		button.Paint = function(panel, width, height)
			local theme = NETWORK.theme
			local util = NETWORK.util
			local bActive = self.selected == base.id
			local lit = math.max(panel.hover, bActive and 1 or 0)

			surface.SetDrawColor(theme.plateDeep.r, theme.plateDeep.g, theme.plateDeep.b,
				(180 + 55 * lit) * self.alpha)
			surface.DrawRect(0, 0, width, height)

			util.DrawScanlines(0, 0, width, height, 16 * self.alpha)

			surface.SetDrawColor(rarity.color.r, rarity.color.g, rarity.color.b,
				(170 + 85 * lit) * self.alpha)
			surface.DrawRect(0, 0, math.max(Sc(3), 2), height)

			draw.SimpleText(base.name, "nwChatSmall", Sc(14), math.Round(height * 0.5),
				ColorAlpha(theme.text, 245 * self.alpha), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			if (NETWORK.icon.Get(base.id)) then
				draw.SimpleText("*", "nwField", width - Sc(12), math.Round(height * 0.5),
					ColorAlpha(theme.value, 245 * self.alpha), TEXT_ALIGN_RIGHT,
					TEXT_ALIGN_CENTER)
			end
		end
		button.DoClick = function()
			NETWORK.sound.Click()

			self:Select(base.id)
		end
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.frameWidth = width - Sc(80)
	self.frameHeight = height - Sc(70)
	self.frameX = Sc(40)
	self.frameY = Sc(35)
	self.headerHeight = Sc(42)
	self.listWidth = Sc(230)
	self.stripHeight = Sc(210)

	self.search:SetPos(self.frameX + Sc(14), self.frameY + self.headerHeight + Sc(12))
	self.search:SetSize(self.listWidth, Sc(28))

	self.list:SetPos(self.frameX + Sc(14), self.frameY + self.headerHeight + Sc(46))
	self.list:SetSize(self.listWidth,
		self.frameHeight - self.headerHeight - Sc(60))

	local previewX = self.frameX + Sc(28) + self.listWidth
	local previewWidth = self.frameWidth - self.listWidth - Sc(42)
	local previewHeight = self.frameHeight - self.headerHeight - self.stripHeight - Sc(24)

	self.previewX = previewX
	self.previewY = self.frameY + self.headerHeight + Sc(12)
	self.previewWidth = previewWidth
	self.previewHeight = previewHeight

	local size = math.min(previewWidth, previewHeight)

	self.preview:SetSize(size, size)
	self.preview:SetPos(previewX + math.Round((previewWidth - size) * 0.5),
		self.previewY + math.Round((previewHeight - size) * 0.5))

	local stripY = self.frameY + self.frameHeight - self.stripHeight + Sc(30)
	local columnWidth = math.Round((previewWidth - Sc(40)) / 3)
	local sliderWidth = columnWidth - Sc(80)

	local layout = {
		{column = 0, row = 0},
		{column = 0, row = 1},
		{column = 1, row = 0},
		{column = 1, row = 1},
		{column = 2, row = 0}
	}

	for index, slider in ipairs(self.sliders) do
		local place = layout[index]

		slider:SetSize(sliderWidth, Sc(20))
		slider:SetPos(previewX + place.column * (columnWidth + Sc(20)) + Sc(96),
			stripY + place.row * Sc(30))
	end

	local buttonWidth = Sc(150)
	local buttonX = self.frameX + self.frameWidth - Sc(14) - buttonWidth

	self.save:SetSize(buttonWidth, Sc(30))
	self.save:SetPos(buttonX, stripY - Sc(4))

	self.reset:SetSize(buttonWidth, Sc(30))
	self.reset:SetPos(buttonX, stripY + Sc(30))

	self.close:SetSize(buttonWidth, Sc(30))
	self.close:SetPos(buttonX, stripY + Sc(64))

	local fieldY = stripY + Sc(74)
	local fieldWidth = math.Round((previewWidth - Sc(40) - buttonWidth - Sc(20)) / 3) - Sc(10)
	local fields = {self.fieldModel, self.fieldGroups, self.fieldWeapon}

	for index, field in ipairs(fields) do
		if (IsValid(field)) then
			field:SetSize(fieldWidth, Sc(26))
			field:SetPos(previewX + (index - 1) * (fieldWidth + Sc(10)), fieldY + Sc(18))
		end
	end

	if (IsValid(self.applyItem)) then
		self.applyItem:SetSize(buttonWidth, Sc(30))
		self.applyItem:SetPos(buttonX, stripY + Sc(98))
	end

	if (IsValid(self.resetItem)) then
		self.resetItem:SetSize(buttonWidth, Sc(30))
		self.resetItem:SetPos(buttonX, stripY + Sc(132))
	end

	if (IsValid(self.createItem)) then
		local createWidth = Sc(190)

		self.createItem:SetSize(createWidth, self.headerHeight - Sc(12))
		self.createItem:SetPos(self.frameX + self.frameWidth - Sc(14) - createWidth,
			self.frameY + Sc(6))
	end
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	self:SetMouseInputEnabled(false)
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 11)

	self:SetAlpha(math.Round(self.alpha * 255))

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Close()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha

	surface.SetDrawColor(0, 0, 0, 160 * alpha)
	surface.DrawRect(0, 0, width, height)

	util.DrawPanel(self.frameX, self.frameY, self.frameWidth, self.frameHeight, alpha,
		{bBrackets = true})

	util.DrawTitleBar(self.frameX, self.frameY, self.frameWidth, self.headerHeight,
		L("iconTitle"), alpha)

	local previewX = self.previewX or self.frameX
	local previewY = self.previewY or self.frameY
	local previewWidth = self.previewWidth or Sc(400)
	local previewHeight = self.previewHeight or Sc(400)

	surface.SetDrawColor(4, 10, 14, 235 * alpha)
	surface.DrawRect(previewX, previewY, previewWidth, previewHeight)

	local size = math.min(previewWidth, previewHeight)
	local frameX = previewX + math.Round((previewWidth - size) * 0.5)
	local frameY = previewY + math.Round((previewHeight - size) * 0.5)

	surface.SetDrawColor(9, 24, 32, 220 * alpha)
	surface.DrawRect(frameX, frameY, size, size)

	util.DrawBrackets(frameX, frameY, size, size, Sc(14), math.max(Sc(2), 2),
		ColorAlpha(theme.accent, 170 * alpha))

	draw.SimpleText(L("iconHint"), "nwHudSmall", previewX + Sc(4),
		previewY + previewHeight + Sc(12), ColorAlpha(theme.textFaint, 235 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (self.selected) then
		draw.SimpleText(L(self.bCustom and "iconCustom" or "iconDefault"), "nwHudSmall",
			previewX + previewWidth - Sc(4), previewY + previewHeight + Sc(12),
			ColorAlpha(self.bCustom and theme.value or theme.textFaint, 240 * alpha),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	local stripY = self.frameY + self.frameHeight - (self.stripHeight or Sc(150)) + Sc(30)
	local columnWidth = math.Round((previewWidth - Sc(40)) / 3)
	local groups = {L("iconGroupCamera"), L("iconGroupAngle"), L("iconGroupLens")}

	for index, name in ipairs(groups) do
		util.DrawTextSpaced(util.Upper(name), "nwHudSmall",
			previewX + (index - 1) * (columnWidth + Sc(20)), stripY - Sc(22),
			ColorAlpha(theme.accentSoft, 240 * alpha), Sc(3), TEXT_ALIGN_CENTER)
	end

	for _, field in ipairs({self.fieldModel, self.fieldGroups, self.fieldWeapon}) do
		if (IsValid(field)) then
			local fieldX, fieldY = field:GetPos()

			draw.SimpleText(L(field.nwKey), "nwHudSmall", fieldX, fieldY - Sc(8),
				ColorAlpha(theme.accentSoft, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	for _, slider in ipairs(self.sliders or {}) do
		if (!IsValid(slider)) then
			continue
		end

		local sliderX, sliderY = slider:GetPos()
		local sliderWidth, sliderHeight = slider:GetSize()
		local middle = sliderY + math.Round(sliderHeight * 0.5)

		draw.SimpleText(L(slider.nwKey), "nwHudSmall", sliderX - Sc(10), middle,
			ColorAlpha(theme.textDim, 240 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		draw.SimpleText(string.format("%.1f", slider:GetValue()), "nwHudSmall",
			sliderX + sliderWidth + Sc(10), middle,
			ColorAlpha(theme.text, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwIconEditor", PANEL, "EditablePanel")

function NETWORK.gui.OpenIconEditor()
	if (IsValid(NETWORK.gui.iconEditor)) then
		NETWORK.gui.iconEditor:Close()

		return
	end

	NETWORK.gui.CloseWindows()

	return vgui.Create("nwIconEditor")
end

concommand.Add("network_iconedit", function()
	if (!LocalPlayer():IsAdmin()) then
		return
	end

	NETWORK.gui.OpenIconEditor()
end)
