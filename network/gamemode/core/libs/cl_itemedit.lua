local E = NETWORK.itemedit

net.Receive("nwItemEditSync", function()
	E.stored = NETWORK.util.ReadTable() or {}

	E.ApplyAll()
end)

function E.Send(id, payload)
	net.Start("nwItemEditSave")
		net.WriteString(id)
		NETWORK.util.WriteTable(payload)
	net.SendToServer()
end

hook.Add("NetworkItemsEdited", "nwItemEditIcons", function()
	hook.Run("NetworkIconsUpdated")

	for panel in pairs(NETWORK.icon.panels or {}) do
		if (IsValid(panel) and panel.Build) then
			panel:Build()
		end
	end
end)

E.pendingFull = nil

net.Receive("nwItemCustomSync", function()
	local kind = net.ReadUInt(2)

	if (kind == 0) then
		local bFirst = net.ReadBool()
		local bLast = net.ReadBool()
		local chunk = NETWORK.util.ReadTable() or {}

		if (bFirst or !E.pendingFull) then
			E.pendingFull = {}
		end

		for id, def in pairs(chunk) do
			id = tostring(id)

			if (istable(def) and E.RegisterCustom(id, def)) then
				E.pendingFull[id] = true
			end
		end

		if (!bLast) then
			return
		end

		for id in pairs(table.Copy(E.custom)) do
			if (!E.pendingFull[id]) then
				E.UnregisterCustom(id)
			end
		end

		E.pendingFull = nil
	elseif (kind == 1) then
		local id = net.ReadString()
		local def = NETWORK.util.ReadTable()

		if (istable(def) and def.name) then
			E.RegisterCustom(id, def)
		end
	elseif (kind == 2) then
		E.UnregisterCustom(net.ReadString())
	end

	E.OnCustomChanged()
end)

hook.Add("InitPostEntity", "nwItemCustomRequest", function()
	net.Start("nwItemCustomRequest")
	net.SendToServer()
end)

function E.SendCustom(bNew, id, def)
	net.Start("nwItemCustomSave")
		net.WriteBool(bNew)
		net.WriteString(id or "")
		NETWORK.util.WriteTable(def)
	net.SendToServer()
end

function E.DeleteCustom(id)
	net.Start("nwItemCustomDelete")
		net.WriteString(id)
	net.SendToServer()
end

function E.RefreshSpawnMenu()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:IsAdmin()) then
		return
	end

	timer.Create("nwItemCustomSpawnmenu", 0.6, 1, function()
		if (IsValid(g_SpawnMenu) and g_SpawnMenu:IsVisible()) then
			E.bSpawnmenuDirty = true

			return
		end

		E.bSpawnmenuDirty = nil

		RunConsoleCommand("spawnmenu_reload")
	end)
end

hook.Add("OnSpawnMenuClose", "nwItemCustomSpawnmenu", function()
	if (E.bSpawnmenuDirty) then
		E.RefreshSpawnMenu()
	end
end)

hook.Add("NetworkCustomItemsUpdated", "nwItemCustomSpawnmenu", function()
	E.RefreshSpawnMenu()
end)

net.Receive("nwItemCustomResult", function()
	local bOk = net.ReadBool()
	local key = net.ReadString()
	local field = net.ReadString()
	local id = net.ReadString()
	local base = NETWORK.item.Get(id)
	local text

	if (key == "itemCreateDeleted") then
		text = L(key, field)
	elseif (bOk) then
		text = L(key, base and base.name or id)
	else
		text = L(key)
	end

	if (NETWORK.gui and NETWORK.gui.Notify) then
		NETWORK.gui.Notify(text, bOk and NETWORK.theme.positive or NETWORK.theme.danger)
	end

	local panel = NETWORK.gui and NETWORK.gui.itemCreator

	if (IsValid(panel)) then
		panel:OnResult(bOk, key, field, id)
	end
end)

net.Receive("nwItemCustomOpen", function()
	E.OpenCreator()
end)

local function SlotName(id)
	for _, group in ipairs(NETWORK.inventory.equipment or {}) do
		for _, slot in ipairs(group.slots) do
			if (slot.id == id) then
				return L(slot.name)
			end
		end
	end

	return id
end

function E.OptionLabel(field, value)
	if (value == "" or value == nil) then
		return L("itemCreateAuto")
	end

	if (field == "equipSlot") then
		return SlotName(value)
	elseif (field == "rarity") then
		local rarity = NETWORK.inventory.GetRarity(value)

		return rarity and L(rarity.name) or value
	elseif (field == "category") then
		return NETWORK.spawnmenu and NETWORK.spawnmenu.GetCategoryName and
			NETWORK.spawnmenu.GetCategoryName(value) or value
	elseif (field == "dropTag") then
		local tag = NETWORK.item.tags[value]

		return tag and L(tag.name) or value
	elseif (field == "useLabel") then
		return L(value)
	elseif (field == "armourClass") then
		return L("itemCreateArmour_" .. value)
	end

	return tostring(value)
end

local S = NETWORK.style

local function Sc(value)
	return NETWORK.util.Scale(value)
end

local function Accent()
	return S and S.Accent and S.Accent() or NETWORK.theme.accent
end

local function StyleScroll(scroll)
	local bar = scroll:GetVBar()

	bar:SetWide(math.max(Sc(5), 4))
	bar:SetHideButtons(true)
	bar.Paint = function(panel, width, height)
		draw.RoundedBox(math.floor(width / 2), 0, 0, width, height, Color(255, 255, 255, 10))
	end
	bar.btnGrip.Paint = function(panel, width, height)
		draw.RoundedBox(math.floor(width / 2), 0, 0, width, height, Color(255, 255, 255, 60))
	end
end

local function PaintField(panel, width, height, bError)
	local radius = S.Radius("cell")
	local accent = bError and NETWORK.theme.danger or Accent()
	local focus = panel:HasFocus() and 1 or 0

	draw.RoundedBox(radius, 0, 0, width, height, Color(18, 23, 29, 235))
	NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, 1,
		bError and ColorAlpha(accent, 220) or
		Color(Lerp(focus, 150, accent.r), Lerp(focus, 196, accent.g),
			Lerp(focus, 220, accent.b), 40 + 150 * focus))
end

local function MakeEntry(parent, bMultiline)
	local entry = vgui.Create("DTextEntry", parent)

	entry:SetFont("nwInvBody")
	entry:SetPaintBackground(false)
	entry:SetUpdateOnType(true)
	entry:SetDrawLanguageID(false)
	entry:SetTextColor(NETWORK.theme.text)
	entry:SetCursorColor(Accent())
	entry:SetHighlightColor(ColorAlpha(Accent(), 120))
	entry:SetTall(Sc(32))
	entry:SetTextInset(Sc(10), 0)

	if (bMultiline) then
		entry:SetMultiline(true)
		entry:SetVerticalScrollbarEnabled(true)
		entry:SetTall(Sc(96))
	end

	entry.Paint = function(panel, width, height)
		PaintField(panel, width, height, panel.bError)

		if (panel:GetValue() == "" and panel.placeholder) then
			draw.SimpleText(panel.placeholder, "nwInvBody", Sc(10),
				bMultiline and Sc(8) or math.Round(height * 0.5),
				ColorAlpha(NETWORK.theme.textFaint, 220), TEXT_ALIGN_LEFT,
				bMultiline and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
		end

		panel:DrawTextEntryText(NETWORK.theme.text, ColorAlpha(Accent(), 120), Accent())
	end

	return entry
end

local function MakeButton(parent, text, callback, bPrimary)
	local button = vgui.Create("DButton", parent)

	button:SetText("")
	button:SetCursor("hand")
	button:SetTall(Sc(32))
	button.label = text
	button.bPrimary = bPrimary
	button.hover = 0
	button.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 10)
	end
	button.Paint = function(panel, width, height)
		local accent = panel.color or Accent()
		local radius = S.Radius("cell")
		local fill = panel.bPrimary and 70 or 18

		if (panel:GetDisabled()) then
			fill = 8
		end

		draw.RoundedBox(radius, 0, 0, width, height,
			Color(accent.r, accent.g, accent.b, fill + 50 * panel.hover))
		NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, 1,
			Color(accent.r, accent.g, accent.b, (panel:GetDisabled() and 40 or 120) +
				100 * panel.hover))

		local text = NETWORK.util.TruncateWidth(panel.label or "", "nwInvButton",
			width - Sc(12))

		draw.SimpleText(text, "nwInvButton", math.Round(width * 0.5), math.Round(height * 0.5),
			ColorAlpha(NETWORK.theme.text, panel:GetDisabled() and 110 or 250),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	button.DoClick = function(panel)
		if (panel:GetDisabled()) then
			return
		end

		NETWORK.sound.Click()

		if (callback) then
			callback(panel)
		end
	end

	return button
end

local function MakeCombo(parent)
	local combo = vgui.Create("DComboBox", parent)

	combo:SetFont("nwInvBody")
	combo:SetTextColor(NETWORK.theme.text)
	combo:SetTall(Sc(32))
	combo:SetSortItems(false)
	combo.Paint = function(panel, width, height)
		PaintField(panel, width, height, panel.bError)
	end

	return combo
end

local ROW = {}

function ROW:Init()
	self.label = ""
	self.hint = ""
	self.control = nil
	self.bError = false
	self.lines = {}
	self.hintLines = {}
end

function ROW:Setup(label, hint, control)
	self.label = label or ""
	self.hint = hint or ""
	self.control = control

	control:SetParent(self)
end

function ROW:SetError(bError)
	self.bError = bError

	if (IsValid(self.control)) then
		self.control.bError = bError

		for _, child in ipairs(self.control:GetChildren()) do
			child.bError = bError
		end
	end
end

function ROW:PerformLayout(width, height)
	local pad = Sc(6)
	local bStacked = width < Sc(430)
	local labelWidth = bStacked and width or math.floor(width * 0.36)
	local controlHeight = IsValid(self.control) and self.control:GetTall() or Sc(32)

	self.lines = NETWORK.util.WrapText(self.label, "nwInvName", labelWidth - Sc(8), 3)
	self.hintLines = self.hint != "" and
		NETWORK.util.WrapText(self.hint, "nwInvSub", labelWidth - Sc(8), 3) or {}

	surface.SetFont("nwInvName")

	local _, lineHeight = surface.GetTextSize("Ag")

	surface.SetFont("nwInvSub")

	local _, hintHeight = surface.GetTextSize("Ag")

	local textHeight = #self.lines * lineHeight + #self.hintLines * hintHeight
	local wanted

	self.lineHeight = lineHeight
	self.hintHeight = hintHeight
	self.bStacked = bStacked

	if (bStacked) then
		wanted = textHeight + Sc(4) + controlHeight + pad * 2

		if (IsValid(self.control)) then
			self.control:SetPos(0, pad + textHeight + Sc(4))
			self.control:SetWide(width)
		end
	else
		wanted = math.max(textHeight, controlHeight) + pad * 2

		if (IsValid(self.control)) then
			self.control:SetPos(labelWidth, pad)
			self.control:SetWide(width - labelWidth)
		end
	end

	if (height != wanted) then
		self:SetTall(wanted)
	end
end

function ROW:Paint(width, height)
	local y = Sc(6)
	local color = self.bError and NETWORK.theme.danger or NETWORK.theme.text

	for _, line in ipairs(self.lines) do
		draw.SimpleText(line, "nwInvName", 0, y, ColorAlpha(color, 240))

		y = y + (self.lineHeight or Sc(16))
	end

	for _, line in ipairs(self.hintLines) do
		draw.SimpleText(line, "nwInvSub", 0, y, ColorAlpha(NETWORK.theme.textFaint, 230))

		y = y + (self.hintHeight or Sc(12))
	end
end

vgui.Register("nwItemCreatorRow", ROW, "DPanel")

local PANEL = {}

function PANEL:Init()
	NETWORK.gui.itemCreator = self

	self.alpha = 0
	self.bClosing = false
	self.values = {}
	self.rows = {}
	self.editingID = nil
	self.newID = ""
	self.bShowAll = false
	self.yaw = 35
	self.pitch = 12
	self.zoom = 1
	self.bOnPlayer = false

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetKeyboardInputEnabled(true)

	self.close = MakeButton(self, "×", function()
		self:Close()
	end)

	self.search = MakeEntry(self)
	self.search.placeholder = L("itemCreateSearch")
	self.search.OnValueChange = function()
		self:RebuildList()
	end

	self.newButton = MakeButton(self, L("itemCreateNew"), function()
		self:StartNew()
	end, true)

	self.allToggle = MakeButton(self, L("itemCreateShowAll"), function(panel)
		self.bShowAll = !self.bShowAll
		panel.bPrimary = self.bShowAll

		self:RebuildList()
	end)

	self.list = vgui.Create("DScrollPanel", self)
	StyleScroll(self.list)

	self.form = vgui.Create("DScrollPanel", self)
	StyleScroll(self.form)

	self:BuildPreview()

	self.save = MakeButton(self, L("itemCreateSave"), function()
		self:Submit()
	end, true)

	self.delete = MakeButton(self, L("itemCreateDelete"), function(panel)
		self:TryDelete(panel)
	end)
	self.delete.color = NETWORK.theme.danger

	self.iconButton = MakeButton(self, L("itemCreateIcon"), function()
		self:SaveIcon()
	end)

	self.playerToggle = MakeButton(self, L("itemCreateOnPlayer"), function(panel)
		self.bOnPlayer = !self.bOnPlayer
		panel.bPrimary = self.bOnPlayer

		self:UpdatePreviewModel(true)
	end)

	hook.Add("NetworkCustomItemsUpdated", self, function()
		if (!IsValid(self)) then
			return
		end

		self:RebuildList()

		if (self.editingID and !E.IsCustom(self.editingID)) then
			NETWORK.gui.Notify(L("itemCreateGone"), NETWORK.theme.warning)

			self:StartNew()
		end
	end)

	self:StartNew()
	self:RebuildList()
end

function PANEL:OnRemove()
	if (NETWORK.gui.itemCreator == self) then
		NETWORK.gui.itemCreator = nil
	end
end

function PANEL:BuildPreview()
	local preview = vgui.Create("DModelPanel", self)

	preview:SetFOV(38)
	preview:SetCursor("sizeall")
	preview.LayoutEntity = function(panel, entity)
		if (self.bOnPlayer and panel.bAnimated) then
			panel:RunAnimation()
		end
	end
	preview.OnMousePressed = function(panel, code)
		panel.bDragging = true
		panel.lastX, panel.lastY = gui.MousePos()

		panel:MouseCapture(true)
	end
	preview.OnMouseReleased = function(panel)
		panel.bDragging = false

		panel:MouseCapture(false)
	end
	preview.OnMouseWheeled = function(panel, delta)
		self.zoom = math.Clamp(self.zoom - delta * 0.08, 0.35, 2.5)

		self:FitCamera()
	end
	preview.Think = function(panel)
		if (!panel.bDragging) then
			return
		end

		local x, y = gui.MousePos()

		self.yaw = self.yaw + (x - (panel.lastX or x)) * 0.6
		self.pitch = math.Clamp(self.pitch + (y - (panel.lastY or y)) * 0.4, -70, 70)

		panel.lastX, panel.lastY = x, y

		self:FitCamera()
	end

	local paintModel = preview.Paint

	preview.Paint = function(panel, width, height)
		local radius = S.Radius("card")

		draw.RoundedBox(radius, 0, 0, width, height, Color(8, 11, 14, 240))

		paintModel(panel, width, height)

		NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, 1, S.line)

		if (self.previewError) then
			local lines = NETWORK.util.WrapText(self.previewError, "nwInvBody", width - Sc(24), 3)

			for index, line in ipairs(lines) do
				draw.SimpleText(line, "nwInvBody", math.Round(width * 0.5),
					math.Round(height * 0.5) + (index - 1) * Sc(16),
					ColorAlpha(NETWORK.theme.danger, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		draw.SimpleText(L("itemCreatePreviewHint"), "nwInvSub", Sc(10), height - Sc(8),
			ColorAlpha(NETWORK.theme.textFaint, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end

	self.preview = preview
end

function PANEL:FitCamera()
	local entity = self.preview:GetEntity()

	if (!IsValid(entity)) then
		return
	end

	local mins, maxs = entity:GetRenderBounds()
	local center = (mins + maxs) * 0.5
	local radius = math.max((maxs - mins):Length() * 0.5, 2)
	local fov = self.preview:GetFOV()
	local distance = radius / math.sin(math.rad(fov * 0.5)) * self.zoom
	local direction = Angle(self.pitch, self.yaw, 0):Forward()

	self.camCenter = center
	self.camPos = center - direction * distance

	self.preview:SetLookAt(center)
	self.preview:SetCamPos(self.camPos)
end

function PANEL:UpdatePreviewModel(bForce)
	local values = self.values
	local model = values.model or ""

	if (self.bOnPlayer) then
		local replace = values.replaceModel

		model = (replace and replace != "" and util.IsValidModel(replace)) and replace or
			LocalPlayer():GetModel()
	end

	if (!bForce and model == self.previewModel) then
		self:ApplyPreviewLook()

		return
	end

	self.previewModel = model
	self.previewError = nil

	if (model == "" or !util.IsValidModel(model)) then
		self.preview:SetModel("models/props_junk/cardboard_box001a.mdl")
		self.previewError = L(model == "" and "itemCreateNoModel" or "itemCreateBadModel")
	else
		self.preview:SetModel(model)
	end

	local entity = self.preview:GetEntity()

	self.preview.bAnimated = false

	if (IsValid(entity) and self.bOnPlayer) then
		local sequence = entity:LookupSequence("idle_all_01")

		if (sequence and sequence > 0) then
			entity:ResetSequence(sequence)
			self.preview.bAnimated = true
		end
	end

	self:ApplyPreviewLook()
	self:FitCamera()
end

function PANEL:ApplyPreviewLook()
	local entity = self.preview:GetEntity()

	if (!IsValid(entity)) then
		return
	end

	local groups = istable(self.values.bodygroups) and self.values.bodygroups or
		E.ParseBodygroups(self.values.bodygroups)

	for index = 0, entity:GetNumBodyGroups() - 1 do
		entity:SetBodygroup(index, 0)
	end

	entity:SetSkin(0)

	if (self.bOnPlayer) then
		for index, value in pairs(groups) do
			entity:SetBodygroup(tonumber(index) or 0, tonumber(value) or 0)
		end

		entity:SetSkin(tonumber(self.values.skin) or 0)
	end
end

function PANEL:QueuePreview()
	timer.Create("nwItemCreatorPreview", 0.35, 1, function()
		if (IsValid(self)) then
			self:UpdatePreviewModel()
		end
	end)
end

function PANEL:StartNew(template)
	self.editingID = nil
	self.newID = ""
	self.values = template and table.Copy(template) or {base = "misc"}
	self.values.base = E.GetBase(self.values.base).id

	if (template) then
		self.values.name = self.values.name and (self.values.name .. " " .. L("itemCreateCopy"))
	end

	self:ApplyBaseDefaults(true)
	self:BuildForm()
	self:UpdatePreviewModel(true)
end

function PANEL:StartEdit(id)
	local def = E.custom[id]

	if (!def) then
		return
	end

	self.editingID = id
	self.values = table.Copy(def)

	self:BuildForm()
	self:UpdatePreviewModel(true)
end

function PANEL:ApplyBaseDefaults(bKeep)
	local base = E.GetBase(self.values.base)

	for key, value in pairs(base.defaults or {}) do
		if (self.values[key] == nil or !bKeep) then
			self.values[key] = istable(value) and table.Copy(value) or value
		end
	end

	local categories = E.GetOptions("category", base.id)

	if (base.bLockCategory or !table.HasValue(categories, self.values.category or "")) then
		self.values.category = base.category
	end

	local slots = base.slots or {}

	if (#slots > 0 and !table.HasValue(slots, self.values.equipSlot or "")) then
		self.values.equipSlot = slots[1]
	end
end

local function Hint(spec)
	if (spec.kind == "int" or spec.kind == "number") then
		return string.format("%s – %s", tostring(spec.min), tostring(spec.max))
	end

	return ""
end

function PANEL:MakeControl(field)
	local spec = E.specs[field]
	local values = self.values
	local kind = spec.kind
	local base = E.GetBase(values.base)

	if (kind == "text" or kind == "multiline" or kind == "sound" or kind == "class" or
		kind == "itemid" or kind == "itemlist" or kind == "contents" or
		kind == "bodygroups" or kind == "factions" or kind == "model") then
		local holder = vgui.Create("DPanel")
		local entry = MakeEntry(holder, kind == "multiline")
		local buttons = {}

		holder:SetPaintBackground(false)
		holder:SetTall(entry:GetTall())

		local value = values[field]

		if (kind == "itemlist" or kind == "factions") then
			value = istable(value) and table.concat(value, ", ") or value
		elseif (kind == "contents") then
			value = istable(value) and E.FormatContents(value) or value
		elseif (kind == "bodygroups") then
			value = istable(value) and E.FormatBodygroups(value) or value
		end

		entry:SetText(value and tostring(value) or "")
		entry.placeholder = L("itemCreatePh_" .. field) != ("itemCreatePh_" .. field) and
			L("itemCreatePh_" .. field) or nil

		if (spec.max) then
			entry.AllowInput = function(panel, char)
				return NETWORK.util.Length(panel:GetValue()) >= spec.max
			end
		end

		entry.OnValueChange = function(panel, text)
			values[field] = text

			if (field == "model" or field == "replaceModel") then
				self:QueuePreview()
			elseif (field == "bodygroups" or field == "skin") then
				self:ApplyPreviewLook()
			end
		end

		local function AddButton(label, callback)
			local button = MakeButton(holder, label, callback)

			buttons[#buttons + 1] = button

			return button
		end

		if (kind == "model") then
			AddButton(L("itemCreateFromAim"), function()
				local entity = LocalPlayer():GetEyeTrace().Entity

				if (IsValid(entity) and entity:GetModel()) then
					entry:SetText(string.lower(entity:GetModel()))
					entry:OnValueChange(entry:GetValue())
				else
					NETWORK.gui.Notify(L("itemCreateNoAim"), NETWORK.theme.warning)
				end
			end)
		elseif (field == "weaponClass" or field == "ammoType") then
			AddButton(L("itemCreateFromHands"), function()
				local weapon = LocalPlayer():GetActiveWeapon()

				if (!IsValid(weapon)) then
					return
				end

				local text = weapon:GetClass()

				if (field == "ammoType") then
					local ammo = weapon:GetPrimaryAmmoType()

					text = ammo and ammo >= 0 and game.GetAmmoName(ammo) or ""
				end

				if (text and text != "") then
					entry:SetText(text)
					entry:OnValueChange(text)
				end
			end)
		elseif (kind == "sound") then
			AddButton(L("itemCreatePlay"), function()
				local path = string.Trim(entry:GetValue())

				if (E.IsSoundPath(path)) then
					surface.PlaySound(path)
				end
			end)
		end

		holder.PerformLayout = function(panel, width, height)
			local buttonWidth = 0

			for _, button in ipairs(buttons) do
				surface.SetFont("nwInvButton")

				local textWidth = surface.GetTextSize(button.label or "")

				button:SetSize(math.Clamp(textWidth + Sc(20), Sc(34), math.floor(width * 0.4)),
					entry:GetTall())
				buttonWidth = buttonWidth + button:GetWide() + Sc(6)
			end

			entry:SetPos(0, 0)
			entry:SetSize(math.max(width - buttonWidth, Sc(60)), entry:GetTall())

			local x = entry:GetWide() + Sc(6)

			for _, button in ipairs(buttons) do
				button:SetPos(x, 0)

				x = x + button:GetWide() + Sc(6)
			end
		end

		return holder
	end

	if (kind == "int" or kind == "number") then
		local holder = vgui.Create("DPanel")
		local entry = MakeEntry(holder)
		local step = spec.step or (kind == "int" and 1 or 0.1)

		holder:SetPaintBackground(false)
		holder:SetTall(entry:GetTall())

		entry:SetNumeric(true)

		local function Format(number)
			if (kind == "int") then
				return tostring(math.floor(number + 0.5))
			end

			return string.format("%." .. (spec.decimals or 2) .. "f", number)
		end

		local function Set(number, bUpdateText)
			number = math.Clamp(tonumber(number) or spec.default or spec.min, spec.min, spec.max)

			values[field] = number

			if (bUpdateText) then
				entry:SetText(Format(number))
			end

			if (field == "skin") then
				self:ApplyPreviewLook()
			end
		end

		entry:SetText(Format(tonumber(values[field]) or spec.default or spec.min))
		entry.OnValueChange = function(panel, text)
			local number = tonumber(text)

			if (number) then
				values[field] = math.Clamp(number, spec.min, spec.max)
			end
		end
		entry.OnLoseFocus = function(panel)
			Set(panel:GetValue(), true)

			local parent = vgui.GetControlTable("DTextEntry")

			if (parent and parent.OnLoseFocus) then
				parent.OnLoseFocus(panel)
			end
		end
		entry.OnEnter = function(panel)
			Set(panel:GetValue(), true)
		end

		local minus = MakeButton(holder, "-", function()
			Set((tonumber(values[field]) or spec.default or spec.min) - step, true)
		end)

		local plus = MakeButton(holder, "+", function()
			Set((tonumber(values[field]) or spec.default or spec.min) + step, true)
		end)

		if (field == "maxStack" and base.bEquip and
			!(base.id == "weapon" and values.bConsumeOnEquip)) then
			entry:SetText("1")
			entry:SetEnabled(false)
			minus:SetDisabled(true)
			plus:SetDisabled(true)
		end

		holder.PerformLayout = function(panel, width, height)
			local size = entry:GetTall()

			entry:SetPos(0, 0)
			entry:SetSize(math.max(width - size * 2 - Sc(12), Sc(50)), size)

			minus:SetSize(size, size)
			minus:SetPos(width - size * 2 - Sc(6), 0)

			plus:SetSize(size, size)
			plus:SetPos(width - size, 0)
		end

		return holder
	end

	if (kind == "choice" or kind == "tri") then
		local combo = MakeCombo()
		local options

		if (kind == "tri") then
			options = {"auto", "yes", "no"}
		else
			options = E.GetOptions(field, values.base)
		end

		local current = values[field]

		if (kind == "tri") then
			current = current == true and "yes" or current == false and "no" or "auto"
		end

		for _, option in ipairs(options) do
			local label

			if (kind == "tri") then
				label = L("itemCreateTri_" .. option)
			else
				label = E.OptionLabel(field, option)
			end

			combo:AddChoice(label, option, option == (current or ""))
		end

		if (!combo:GetSelectedID() and options[1] != nil) then
			combo:ChooseOptionID(1)

			if (kind == "choice" and options[1] != "") then
				values[field] = options[1]
			end
		end

		combo.OnSelect = function(panel, index, label, option)
			if (kind == "tri") then
				values[field] = option == "yes" and true or option == "no" and false or nil
			else
				values[field] = option != "" and option or nil
			end

			if (field == "equipSlot" or field == "bConsumeOnEquip") then
				self:QueueRebuild()
			end
		end

		if (field == "category" and base.bLockCategory) then
			combo:SetEnabled(false)
		end

		return combo
	end

	if (kind == "bool") then
		local toggle = vgui.Create("DButton")

		toggle:SetText("")
		toggle:SetTall(Sc(32))
		toggle:SetCursor("hand")
		toggle.fraction = values[field] and 1 or 0
		toggle.Think = function(panel)
			panel.fraction = NETWORK.util.Approach(panel.fraction, values[field] and 1 or 0, 10)
		end
		toggle.DoClick = function()
			NETWORK.sound.Click()

			values[field] = !values[field] or nil

			if (field == "bConsumeOnEquip") then
				self:QueueRebuild()
			end
		end
		toggle.Paint = function(panel, width, height)
			local accent = Accent()
			local trackWidth = Sc(44)
			local trackHeight = Sc(22)
			local y = math.Round((height - trackHeight) * 0.5)
			local fraction = panel.fraction

			draw.RoundedBox(math.floor(trackHeight / 2), 0, y, trackWidth, trackHeight,
				Color(Lerp(fraction, 40, accent.r), Lerp(fraction, 46, accent.g),
					Lerp(fraction, 54, accent.b), 200))

			local knob = trackHeight - Sc(6)

			draw.RoundedBox(math.floor(knob / 2), Sc(3) + math.Round((trackWidth - knob - Sc(6)) *
				fraction), y + Sc(3), knob, knob, Color(236, 240, 244))

			local text = L(values[field] and "itemCreateYes" or "itemCreateNo")

			draw.SimpleText(text, "nwInvBody", trackWidth + Sc(10), math.Round(height * 0.5),
				ColorAlpha(NETWORK.theme.text, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		return toggle
	end
end

function PANEL:DynamicHint(field)
	if (field == "bodygroups") then
		local client = LocalPlayer()
		local parts = {}

		for _, group in ipairs(IsValid(client) and client:GetBodyGroups() or {}) do
			if ((group.num or 0) > 1) then
				parts[#parts + 1] = string.format("%d %s (%d)", group.id, group.name, group.num)
			end
		end

		return #parts > 0 and (L("itemCreateGroupsHint") .. " " .. table.concat(parts, ", ")) or ""
	elseif (field == "factions") then
		local parts = {}

		for id in SortedPairs(NETWORK.factions and NETWORK.factions.stored or {}) do
			parts[#parts + 1] = tostring(id)
		end

		return table.concat(parts, ", ")
	end

	local key = "itemCreateHint_" .. field
	local text = L(key)

	return text != key and text or ""
end

function PANEL:AddSection(title)
	local header = self.form:Add("DPanel")

	header:Dock(TOP)
	header:DockMargin(0, Sc(10), Sc(8), Sc(2))
	header:SetTall(Sc(26))
	header.Paint = function(panel, width, height)
		local accent = Accent()

		draw.SimpleText(NETWORK.util.Upper(title), "nwInvHeader", 0, math.Round(height * 0.5),
			ColorAlpha(accent, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 50)
		surface.DrawRect(0, height - 1, width, 1)
	end
end

function PANEL:AddRow(field, label, hint, control)
	local row = self.form:Add("nwItemCreatorRow")

	row:Dock(TOP)
	row:DockMargin(0, 0, Sc(8), 0)
	row:Setup(label, hint, control)

	self.rows[field] = row

	return row
end

function PANEL:AddFieldRow(field)
	local spec = E.specs[field]
	local control = self:MakeControl(field)

	if (!control) then
		return
	end

	local hint = Hint(spec)
	local extra = self:DynamicHint(field)

	if (extra != "") then
		hint = hint != "" and (hint .. " · " .. extra) or extra
	end

	return self:AddRow(field, L("itemCreateField_" .. field), hint, control)
end

function PANEL:AddBasePicker()
	local picker = self.form:Add("DPanel")

	picker:Dock(TOP)
	picker:DockMargin(0, Sc(4), Sc(8), 0)
	picker:SetPaintBackground(false)
	picker.chips = {}

	for _, base in ipairs(E.bases) do
		local chip = MakeButton(picker, L("itemCreateBase_" .. base.id), function()
			if (self.values.base == base.id) then
				return
			end

			self.values.base = base.id

			self:ApplyBaseDefaults(true)
			self:QueueRebuild()
		end, self.values.base == base.id)

		chip.icon = Material(base.icon, "smooth")

		local paint = chip.Paint

		chip.Paint = function(panel, width, height)
			paint(panel, width, height)

			if (panel.icon and !panel.icon:IsError()) then
				local size = Sc(16)

				surface.SetDrawColor(255, 255, 255, 230)
				surface.SetMaterial(panel.icon)
				surface.DrawTexturedRect(Sc(8), math.Round((height - size) * 0.5), size, size)
			end
		end

		if (self.editingID and self.values.base != base.id) then
			chip:SetDisabled(true)
		end

		picker.chips[#picker.chips + 1] = chip
	end

	picker.PerformLayout = function(panel, width, height)
		local x, y = 0, 0
		local gap = Sc(6)
		local chipHeight = Sc(30)

		surface.SetFont("nwInvButton")

		for _, chip in ipairs(panel.chips) do
			local chipWidth = math.min(surface.GetTextSize(chip.label) + Sc(56), width)

			if (x > 0 and x + chipWidth > width) then
				x = 0
				y = y + chipHeight + gap
			end

			chip:SetPos(x, y)
			chip:SetSize(chipWidth, chipHeight)

			x = x + chipWidth + gap
		end

		local wanted = y + chipHeight

		if (height != wanted) then
			panel:SetTall(wanted)
		end
	end
end

function PANEL:QueueRebuild()
	timer.Simple(0, function()
		if (IsValid(self)) then
			self:BuildForm()
		end
	end)
end

function PANEL:BuildForm()
	local scroll = self.form:GetVBar():GetScroll()

	self.form:Clear()
	self.rows = {}

	local base = E.GetBase(self.values.base)

	self:AddSection(L("itemCreateSecBase"))
	self:AddBasePicker()

	self:AddSection(L("itemCreateSecMain"))

	if (self.editingID) then
		local label = vgui.Create("DLabel")

		label:SetFont("nwInvBody")
		label:SetTextColor(NETWORK.theme.textDim)
		label:SetText(self.editingID)
		label:SetTall(Sc(32))

		self:AddRow("id", L("itemCreateField_id"), L("itemCreateIDLocked"), label)
	else
		local entry = MakeEntry()

		entry:SetText(self.newID or "")
		entry.placeholder = L("itemCreatePh_id")
		entry.AllowInput = function(panel, char)
			return !string.match(char, "^[a-z0-9_]$") or #panel:GetValue() >= E.idMax
		end
		entry.OnValueChange = function(panel, text)
			self.newID = string.lower(text)
		end

		self:AddRow("id", L("itemCreateField_id"), L("itemCreateHint_id"), entry)
	end

	for _, field in ipairs({"name", "description", "model"}) do
		self:AddFieldRow(field)
	end

	self:AddSection(L("itemCreateSecInventory"))

	for _, field in ipairs({"width", "height", "weight", "maxStack"}) do
		self:AddFieldRow(field)
	end

	self:AddSection(L("itemCreateSecTrade"))

	for _, field in ipairs({"rarity", "category", "price", "bContraband", "dropTag"}) do
		self:AddFieldRow(field)
	end

	if (#base.fields > 0) then
		self:AddSection(L("itemCreateSec_" .. base.id))

		for _, field in ipairs(base.fields) do

			if (field == "equipSlot" and base.id == "weapon" and self.values.bConsumeOnEquip) then
				continue
			end

			if (field == "gasProtection" and self.values.equipSlot != "mask") then
				continue
			end

			self:AddFieldRow(field)
		end
	end

	self:AddSection(L("itemCreateSecAccess"))

	for _, field in ipairs({"useLabel", "factions"}) do
		self:AddFieldRow(field)
	end

	local spacer = self.form:Add("DPanel")

	spacer:Dock(TOP)
	spacer:SetTall(Sc(16))
	spacer:SetPaintBackground(false)

	self.delete:SetDisabled(self.editingID == nil)
	self.iconButton:SetDisabled(self.editingID == nil)
	self.delete.label = L("itemCreateDelete")
	self.delete.bConfirm = nil

	timer.Simple(0, function()
		if (IsValid(self) and IsValid(self.form)) then
			self.form:GetVBar():SetScroll(scroll)
		end
	end)
end

function PANEL:RebuildList()
	if (!IsValid(self.list)) then
		return
	end

	self.list:Clear()

	local filter = NETWORK.util.Lower(string.Trim(self.search:GetValue() or ""))
	local entries = {}

	for _, base in ipairs(NETWORK.item.GetAll()) do
		if (!base.bCustom and !self.bShowAll) then
			continue
		end

		if (filter != "" and !string.find(NETWORK.util.Lower(base.name or ""), filter, 1, true) and
			!string.find(base.id, filter, 1, true)) then
			continue
		end

		entries[#entries + 1] = base
	end

	table.sort(entries, function(a, b)
		if (tobool(a.bCustom) != tobool(b.bCustom)) then
			return a.bCustom == true
		end

		return (a.name or a.id) < (b.name or b.id)
	end)

	if (#entries == 0) then
		local empty = self.list:Add("DLabel")

		empty:Dock(TOP)
		empty:SetWrap(true)
		empty:SetAutoStretchVertical(true)
		empty:SetFont("nwInvBody")
		empty:SetTextColor(NETWORK.theme.textFaint)
		empty:SetText(L(self.bShowAll and "itemCreateNothing" or "itemCreateEmpty"))

		return
	end

	for _, base in ipairs(entries) do
		local button = self.list:Add("DButton")
		local rarity = NETWORK.inventory.GetRarity(base.rarity)

		button:Dock(TOP)
		button:DockMargin(0, 0, Sc(6), Sc(4))
		button:SetTall(Sc(40))
		button:SetText("")
		button:SetCursor("hand")
		button:SetTooltip(base.id)
		button.hover = 0
		button.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
		end
		button.Paint = function(panel, width, height)
			local bActive = self.editingID == base.id
			local lit = math.max(panel.hover, bActive and 1 or 0)
			local radius = S.Radius("cell")

			draw.RoundedBox(radius, 0, 0, width, height, Color(18, 23, 29, 170 + 60 * lit))

			if (bActive) then
				NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, 1,
					ColorAlpha(Accent(), 180))
			end

			draw.RoundedBox(math.max(Sc(2), 1), Sc(6), Sc(8), math.max(Sc(3), 2), height - Sc(16),
				ColorAlpha(rarity.color, 230))

			local textWidth = width - Sc(22)
			local name = NETWORK.util.TruncateWidth(L(base.name or base.id), "nwInvName", textWidth)
			local sub = base.bCustom and base.id or (base.id .. " · " .. L("itemCreateTemplate"))

			draw.SimpleText(name, "nwInvName", Sc(16), Sc(5), ColorAlpha(NETWORK.theme.text, 245))
			draw.SimpleText(NETWORK.util.TruncateWidth(sub, "nwInvSub", textWidth), "nwInvSub",
				Sc(16), height - Sc(5), ColorAlpha(NETWORK.theme.textFaint, 230), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_BOTTOM)
		end
		button.DoClick = function()
			NETWORK.sound.Click()

			if (base.bCustom) then
				self:StartEdit(base.id)
			else
				self:StartNew(E.DefFromItem(base))
			end
		end
	end
end

function PANEL:Collect()
	local def = {}

	for key, value in pairs(self.values) do
		def[key] = value
	end

	return def
end

function PANEL:ClearErrors()
	for _, row in pairs(self.rows) do
		if (IsValid(row)) then
			row:SetError(false)
		end
	end
end

function PANEL:ShowError(key, field)
	NETWORK.gui.Notify(L(key or "itemCreateErrPayload"), NETWORK.theme.danger)

	local row = self.rows[field or ""]

	if (IsValid(row)) then
		row:SetError(true)

		self.form:ScrollToChild(row)
	end
end

function PANEL:Submit()
	self:ClearErrors()

	local bNew = self.editingID == nil
	local id = bNew and string.Trim(self.newID or "") or self.editingID

	if (bNew and id != "" and !E.IsValidID(id)) then
		return self:ShowError("itemCreateErrID", "id")
	end

	if (bNew and id != "" and NETWORK.item.Get(id)) then
		return self:ShowError("itemCreateErrTaken", "id")
	end

	local def = self:Collect()
	local clean, key, field = E.CleanCustom(id != "" and id or "new_item", def)

	if (!clean) then
		return self:ShowError(key, field)
	end

	self.bWaiting = true

	E.SendCustom(bNew, id, def)
end

function PANEL:OnResult(bOk, key, field, id)
	self.bWaiting = nil

	if (!bOk) then
		local row = self.rows[field or ""]

		if (IsValid(row)) then
			self:ClearErrors()
			row:SetError(true)
			self.form:ScrollToChild(row)
		end

		return
	end

	if (key == "itemCreateDeleted") then
		self:StartNew()
	elseif (E.IsCustom(id)) then
		self:StartEdit(id)
	end

	self:RebuildList()
end

function PANEL:TryDelete(button)
	if (!self.editingID) then
		return
	end

	if (!button.bConfirm) then
		button.bConfirm = true
		button.label = L("itemCreateDeleteConfirm")

		timer.Simple(3, function()
			if (IsValid(button)) then
				button.bConfirm = nil
				button.label = L("itemCreateDelete")
			end
		end)

		return
	end

	button.bConfirm = nil
	button.label = L("itemCreateDelete")

	E.DeleteCustom(self.editingID)
end

function PANEL:SaveIcon()
	if (!self.editingID or !self.camPos or !self.camCenter or self.bOnPlayer) then
		NETWORK.gui.Notify(L("itemCreateIconHint"), NETWORK.theme.warning)

		return
	end

	NETWORK.icon.Send(self.editingID, {
		pos = {self.camPos.x, self.camPos.y, self.camPos.z},
		ang = {0, 0, 0},
		fov = self.preview:GetFOV(),
		center = {self.camCenter.x, self.camCenter.y, self.camCenter.z}
	})

	NETWORK.gui.Notify(L("iconSaved"), NETWORK.theme.positive)
end

function PANEL:PerformLayout(width, height)
	local gutter = math.max(Sc(16), 16)
	local maxWidth = width - gutter * 2
	local maxHeight = height - gutter * 2

	local frameWidth = math.Clamp(math.floor(width * 0.8), math.min(Sc(900), maxWidth),
		math.min(Sc(1400), maxWidth))
	local frameHeight = math.Clamp(math.floor(height * 0.84), math.min(Sc(560), maxHeight),
		math.min(Sc(900), maxHeight))

	self.frameX = math.floor((width - frameWidth) / 2)
	self.frameY = math.floor((height - frameHeight) / 2)
	self.frameWidth = frameWidth
	self.frameHeight = frameHeight

	local pad = Sc(16)
	local headerHeight = Sc(52)
	local innerY = self.frameY + headerHeight
	local innerHeight = frameHeight - headerHeight - pad

	self.headerHeight = headerHeight

	local previewWidth = math.Clamp(math.floor(frameWidth * 0.3), Sc(200), Sc(420))
	local listWidth = math.Clamp(math.floor(frameWidth * 0.22), Sc(150), Sc(300))
	local formWidth = frameWidth - previewWidth - listWidth - pad * 4

	if (formWidth < Sc(300)) then
		listWidth = math.max(listWidth - (Sc(300) - formWidth), Sc(120))
		formWidth = frameWidth - previewWidth - listWidth - pad * 4
	end

	local listX = self.frameX + pad
	local formX = listX + listWidth + pad
	local previewX = formX + formWidth + pad

	self.columns = {listX = listX, formX = formX, previewX = previewX, listWidth = listWidth,
		formWidth = formWidth, previewWidth = previewWidth, top = innerY, height = innerHeight}

	local closeSize = Sc(32)

	self.close:SetSize(closeSize, closeSize)
	self.close:SetPos(self.frameX + frameWidth - pad - closeSize,
		self.frameY + math.floor((headerHeight - closeSize) / 2))

	local rowHeight = Sc(32)
	local y = innerY

	self.search:SetPos(listX, y)
	self.search:SetSize(listWidth, rowHeight)
	y = y + rowHeight + Sc(8)

	self.newButton:SetPos(listX, y)
	self.newButton:SetSize(listWidth, rowHeight)
	y = y + rowHeight + Sc(6)

	self.allToggle:SetPos(listX, y)
	self.allToggle:SetSize(listWidth, rowHeight)
	y = y + rowHeight + Sc(10)

	self.list:SetPos(listX, y)
	self.list:SetSize(listWidth, math.max(innerY + innerHeight - y, Sc(60)))

	self.form:SetPos(formX, innerY)
	self.form:SetSize(formWidth, innerHeight)

	local buttonHeight = Sc(34)
	local gap = Sc(6)
	local buttonsHeight = buttonHeight * 2 + gap
	local summaryHeight = Sc(96)
	local toggleHeight = rowHeight
	local available = innerHeight - buttonsHeight - summaryHeight - toggleHeight - gap * 3
	local previewSize = math.max(math.min(previewWidth, available), Sc(120))

	self.preview:SetPos(previewX, innerY)
	self.preview:SetSize(previewWidth, previewSize)

	self.playerToggle:SetPos(previewX, innerY + previewSize + gap)
	self.playerToggle:SetSize(previewWidth, toggleHeight)

	self.summaryY = innerY + previewSize + gap * 2 + toggleHeight
	self.summaryHeight = summaryHeight

	local bottom = innerY + innerHeight
	local half = math.floor((previewWidth - gap) / 2)

	self.save:SetPos(previewX, bottom - buttonHeight)
	self.save:SetSize(previewWidth, buttonHeight)

	self.delete:SetPos(previewX, bottom - buttonHeight * 2 - gap)
	self.delete:SetSize(half, buttonHeight)

	self.iconButton:SetPos(previewX + half + gap, bottom - buttonHeight * 2 - gap)
	self.iconButton:SetSize(previewWidth - half - gap, buttonHeight)
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
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

function PANEL:PaintSummary(x, y, width, height)
	local values = self.values
	local columns = NETWORK.inventory.columns or 4
	local rows = NETWORK.inventory.rows or 4
	local cell = math.floor(math.min((height - Sc(8)) / rows, Sc(20)))
	local gridWidth = cell * columns
	local itemWidth = math.Clamp(tonumber(values.width) or 1, 1, columns)
	local itemHeight = math.Clamp(tonumber(values.height) or 1, 1, rows)
	local rarity = NETWORK.inventory.GetRarity(values.rarity)

	S.Card(x, y, width, height, self.alpha, {shadow = false, blur = false,
		radius = S.Radius("cell"), accent = rarity.color})

	local gridX = x + Sc(10)
	local gridY = y + math.floor((height - cell * rows) / 2)

	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			local bFilled = column < itemWidth and row < itemHeight

			draw.RoundedBox(math.max(Sc(2), 1), gridX + column * cell + 1, gridY + row * cell + 1,
				cell - 2, cell - 2, bFilled and ColorAlpha(rarity.color, 170) or
				Color(255, 255, 255, 14))
		end
	end

	local textX = gridX + gridWidth + Sc(12)
	local textWidth = x + width - textX - Sc(8)
	local lineY = y + Sc(10)

	local lines = {
		{NETWORK.util.TruncateWidth(values.name and values.name != "" and values.name or
			L("itemCreateUnnamed"), "nwInvName", textWidth), "nwInvName", NETWORK.theme.text},
		{NETWORK.util.TruncateWidth(L(rarity.name) .. " · " ..
			L("itemCreateBase_" .. E.GetBase(values.base).id), "nwInvSub", textWidth), "nwInvSub",
			rarity.color},
		{NETWORK.util.TruncateWidth(string.format("%d×%d · %s %s", itemWidth, itemHeight,
			tostring(tonumber(values.weight) or 0), L("itemCreateKg")), "nwInvSub", textWidth),
			"nwInvSub", NETWORK.theme.textDim}
	}

	for _, line in ipairs(lines) do
		draw.SimpleText(line[1], line[2], textX, lineY, ColorAlpha(line[3], 240))

		surface.SetFont(line[2])

		local _, lineHeight = surface.GetTextSize("Ag")

		lineY = lineY + lineHeight + Sc(4)
	end
end

function PANEL:Paint(width, height)
	local alpha = self.alpha

	surface.SetDrawColor(0, 0, 0, 170 * alpha)
	surface.DrawRect(0, 0, width, height)

	if (!self.frameX) then
		return
	end

	S.Card(self.frameX, self.frameY, self.frameWidth, self.frameHeight, alpha,
		{radius = S.Radius("panel"), accent = Accent(), panel = self})

	local pad = Sc(16)
	local title = L(self.editingID and "itemCreateTitleEdit" or "itemCreateTitle")
	local titleWidth = self.frameWidth - pad * 3 - Sc(32)

	draw.SimpleText(NETWORK.util.TruncateWidth(title, "nwInvTitle", titleWidth), "nwInvTitle",
		self.frameX + pad, self.frameY + math.floor(self.headerHeight / 2),
		ColorAlpha(NETWORK.theme.text, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local accent = Accent()

	surface.SetDrawColor(accent.r, accent.g, accent.b, 40 * alpha)
	surface.DrawRect(self.frameX + pad, self.frameY + self.headerHeight - Sc(6),
		self.frameWidth - pad * 2, 1)

	local columns = self.columns

	if (columns and self.summaryY) then
		self:PaintSummary(columns.previewX, self.summaryY, columns.previewWidth,
			self.summaryHeight)
	end
end

vgui.Register("nwItemCreator", PANEL, "EditablePanel")

function E.OpenCreator(options)
	local client = LocalPlayer()

	if (!IsValid(client) or !client:IsAdmin()) then
		return
	end

	options = options or {}

	local panel = NETWORK.gui.itemCreator

	if (!IsValid(panel) or panel.bClosing) then
		if (IsValid(panel)) then
			panel:Remove()
		end

		panel = vgui.Create("nwItemCreator")
	end

	if (options.id and E.IsCustom(options.id)) then
		panel:StartEdit(options.id)
	elseif (options.template) then
		panel:StartNew(options.template)
	end

	return panel
end

concommand.Add("network_itemcreate", function()
	E.OpenCreator()
end)

function E.AddMenuOptions(menu, id)
	local base = NETWORK.item.Get(id)

	if (!base or !LocalPlayer():IsAdmin()) then
		return
	end

	menu:AddSpacer()

	if (E.IsCustom(id)) then
		menu:AddOption(L("itemCreateMenuEdit"), function()
			E.OpenCreator({id = id})
		end):SetIcon("icon16/pencil.png")

		menu:AddOption(L("itemCreateMenuDelete"), function()
			Derma_Query(L("itemCreateDeleteQuery", L(base.name)), L("itemCreateMenuDelete"),
				L("itemCreateDelete"), function()
					E.DeleteCustom(id)
				end, L("itemCreateCancel"))
		end):SetIcon("icon16/delete.png")
	end

	menu:AddOption(L("itemCreateMenuCopy"), function()
		E.OpenCreator({template = E.DefFromItem(base)})
	end):SetIcon("icon16/page_copy.png")
end
