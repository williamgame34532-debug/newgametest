local function Palette()
	return NETWORK.theme.create
end

local function StyleScrollbar(scroll)
	local Sc = NETWORK.util.Scale
	local bar = scroll:GetVBar()

	bar:SetWide(Sc(4))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(2), 0, 0, width, height, Color(255, 255, 255, 70))
	end
end

local BUTTON = {}

function BUTTON:Init()
	self:SetText("")
	self:SetCursor("hand")

	self.label = ""
	self.font = "nwCreateButton"
	self.bSelected = false
	self.bPrimary = false
	self.hover = 0
	self.select = 0
	self.disabled = 0
end

function BUTTON:SetLabel(text, bRaw)
	self.label = bRaw and text or NETWORK.util.Upper(text or "")
end

function BUTTON:SetFont(font)
	self.font = font
end

function BUTTON:SetSelected(bSelected)
	self.bSelected = tobool(bSelected)
end

function BUTTON:SetPrimary(bPrimary)
	self.bPrimary = tobool(bPrimary)
end

function BUTTON:OnCursorEntered()
	if (!self:GetDisabled()) then
		NETWORK.sound.CreateHover()
	end
end

function BUTTON:OnMousePressed(code)
	if (self:GetDisabled()) then
		NETWORK.sound.Play("hover3", 92, 0.5)

		return
	end

	NETWORK.sound.CreatePress()

	if (code == MOUSE_LEFT and self.DoClick) then
		self:DoClick(self)
	end
end

function BUTTON:Think()
	local util = NETWORK.util

	self.hover = util.Approach(self.hover, (self:IsHovered() and !self:GetDisabled()) and 1 or 0, 10)
	self.select = util.Approach(self.select, self.bSelected and 1 or 0, 10)
	self.disabled = util.Approach(self.disabled, self:GetDisabled() and 1 or 0, 8)
end

function BUTTON:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local palette = Palette()
	local theme = NETWORK.theme
	local hover = util.EaseInOut(self.hover)
	local select = util.EaseInOut(self.select)
	local alpha = 1 - self.disabled * 0.55
	local lift = (self.bPrimary and 1 or 0)

	util.DrawVGradient(0, 0, width, height,
		Color(30 + 10 * lift + 12 * hover, 32 + 10 * lift + 12 * hover,
			35 + 10 * lift + 12 * hover, (215 + 30 * lift) * alpha),
		Color(14 + 6 * lift, 15 + 6 * lift, 17 + 6 * lift, (230 + 20 * lift) * alpha))

	if (select > 0.01) then
		surface.SetDrawColor(theme.hover.r, theme.hover.g, theme.hover.b, 22 * select * alpha)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(theme.hover.r, theme.hover.g, theme.hover.b,
			210 * select * alpha)
		surface.DrawRect(0, height - math.max(Sc(2), 2), width, math.max(Sc(2), 2))
	end

	surface.SetDrawColor(255, 255, 255, (8 + 14 * hover) * alpha)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	local base = (self.bSelected or self.bPrimary) and palette.text or palette.textDim
	local target = theme.hover

	draw.SimpleText(self.label, self.font, math.Round(width * 0.5),
		math.Round(height * 0.5), Color(
			Lerp(hover, base.r, target.r),
			Lerp(hover, base.g, target.g),
			Lerp(hover, base.b, target.b),
			250 * alpha
		), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("nwCreateButton", BUTTON, "DButton")

local CARD = {}

function CARD:Init()
	self:SetText("")
	self:SetCursor("hand")

	self.bSelected = false
	self.hover = 0
	self.select = 0
	self.framing = "head"
end

function CARD:Setup(path, options)
	options = options or {}

	self.path = path
	self.framing = options.framing or "head"

	if (IsValid(self.model)) then
		self.model:Remove()
	end

	local model = self:Add("DModelPanel")

	model:Dock(FILL)
	model:DockMargin(2, 2, 2, 2)
	model:SetModel(path)
	model:SetFOV(self.framing == "head" and 24 or 30)
	model:SetMouseInputEnabled(false)
	model:SetAnimated(false)
	model.LayoutEntity = function() end

	local basePaint = model.Paint

	model.Paint = function(panel, width, height)
		local _, screenY = panel:LocalToScreen(0, 0)

		if (screenY + height < 0 or screenY > ScrH()) then
			return
		end

		if (!NETWORK.gui.TakeModelBudget(panel)) then
			return
		end

		basePaint(panel, width, height)
	end

	local entity = model:GetEntity()

	if (IsValid(entity)) then
		entity:SetAngles(Angle(0, 0, 0))

		for id, value in pairs(options.bodygroups or {}) do
			entity:SetBodygroup(id, value)
		end

		if (options.group != nil) then
			entity:SetBodygroup(options.group, options.value or 0)
		end

		entity:SetSkin(options.skin or 0)

		local sequence = entity:LookupSequence("idle_all_01")

		if (sequence > 0) then
			entity:ResetSequence(sequence)
		end

		local mins, maxs = entity:GetModelBounds()

		if (mins and maxs) then
			local size = maxs.z - mins.z
			local centerX = (mins.x + maxs.x) * 0.5
			local centerY = (mins.y + maxs.y) * 0.5

			if (self.framing == "head") then
				local look = Vector(centerX, centerY, maxs.z - size * 0.105)

				model:SetLookAt(look)
				model:SetCamPos(look + Vector(size * 0.34, 0, size * 0.01))
			elseif (self.framing == "bust") then
				local look = Vector(centerX, centerY, maxs.z - size * 0.17)

				model:SetLookAt(look)
				model:SetCamPos(look + Vector(size * 0.62, 0, size * 0.02))
			else
				NETWORK.util.FrameModelPanel(model, nil, 0.02, 1.08)
			end
		end
	end

	self.model = model
end

function CARD:GetEntity()
	return IsValid(self.model) and self.model:GetEntity() or nil
end

function CARD:SetSelected(bSelected)
	self.bSelected = tobool(bSelected)
end

function CARD:OnCursorEntered()
	NETWORK.sound.CreateHover()
end

function CARD:OnMousePressed(code)
	NETWORK.sound.CreatePress()

	if (code == MOUSE_LEFT and self.DoClick) then
		self:DoClick(self)
	end
end

function CARD:Think()
	local util = NETWORK.util

	self.hover = util.Approach(self.hover, self:IsHovered() and 1 or 0, 10)
	self.select = util.Approach(self.select, self.bSelected and 1 or 0, 10)
end

function CARD:Paint(width, height)
	local util = NETWORK.util
	local hover = util.EaseInOut(self.hover)

	util.DrawVGradient(0, 0, width, height,
		Color(26 + 10 * hover, 28 + 10 * hover, 31 + 10 * hover, 235),
		Color(12, 13, 15, 245))
end

function CARD:PaintOver(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local hover = NETWORK.util.EaseInOut(self.hover)
	local lit = math.max(hover * 0.5, self.select)

	surface.SetDrawColor(255, 255, 255, 14 + 18 * hover)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	if (lit > 0.01) then
		surface.SetDrawColor(theme.hover.r, theme.hover.g, theme.hover.b, 235 * lit)
		surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(2), 1))
	end
end

vgui.Register("nwCreateCard", CARD, "DButton")

local ENTRY = {}

function ENTRY:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local palette = Palette()
	local focus = NETWORK.util.EaseInOut(self.focus)
	local error = self.error

	local theme = NETWORK.theme

	NETWORK.util.DrawVGradient(0, 0, width, height,
		Color(24 + 8 * focus, 26 + 8 * focus, 29 + 8 * focus, 235),
		Color(12, 13, 15, 245))

	local line = Color(
		Lerp(error, Lerp(focus, palette.line.r, theme.hover.r), palette.error.r),
		Lerp(error, Lerp(focus, palette.line.g, theme.hover.g), palette.error.g),
		Lerp(error, Lerp(focus, palette.line.b, theme.hover.b), palette.error.b)
	)

	surface.SetDrawColor(255, 255, 255, 10)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	surface.SetDrawColor(line.r, line.g, line.b, 120 + 130 * math.max(focus, error))
	surface.DrawRect(0, height - math.max(Sc(2), 2), width, math.max(Sc(2), 2))

	if (self:GetText() == "" and self.placeholder != "") then
		draw.SimpleText(self.placeholder, self:GetFont(), self.padding,
			self.bMultilineField and Sc(14) or math.Round(height * 0.5),
			ColorAlpha(palette.textFaint, 220), TEXT_ALIGN_LEFT,
			self.bMultilineField and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
	end

	if (self.limit > 0 and self.bMultilineField) then
		draw.SimpleText(self:GetLength() .. " / " .. self.limit, "nwHudSmall",
			width - Sc(10), height - Sc(10), ColorAlpha(palette.textFaint, 200),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	end

	self:DrawTextEntryText(palette.text, Color(80, 100, 130), palette.text)
end

vgui.Register("nwCreateEntry", ENTRY, "nwTextEntry")

local PANEL = {}

PANEL.cardSize = 78
PANEL.cardGap = 8

function PANEL:Init()
	local config = NETWORK.creation

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)

	self.startTime = CurTime()
	self.alpha = 0
	self.bClosing = false
	self.bSaving = false
	self.status = nil
	self.statusFade = 0
	self.view = "bust"

	local models = config.GetModels(config.faction)

	self.data = {
		name = "",
		surname = "",
		description = "",
		model = 1,
		height = config.heightDefault,
		skills = {},
		kit = 1,
		faction = config.faction,
		bodygroups = {},
		skin = 0,
		gender = config.GetGender(models[1])
	}

	for i = 1, #config.skills do
		self.data.skills[config.skills[i].id] = 0
	end

	self:SetMouseInputEnabled(true)
	self:SetKeyboardInputEnabled(true)
	self:MoveToFront()

	self:Rebuild()
end

function PANEL:SetFaction(id)
	if (!id or self.data.faction == id) then
		return
	end

	self.data.faction = id

	local models = NETWORK.creation.GetModels(id)

	self.data.model = 1
	self.data.bodygroups = {}
	self.data.skin = 0

	if (self.RefreshModel) then
		self:RefreshModel(true)
	end

	if (self.Rebuild) then
		self:Rebuild()
	end
end

function PANEL:GetModelPath()
	local models = NETWORK.creation.GetModels(self.data.faction)

	return models[self.data.model] or models[1]
end

function PANEL:BuildPayload()
	local config = NETWORK.creation
	local kit = config.kits[self.data.kit]

	return {
		name = self.data.name,
		surname = self.data.surname,
		description = self.data.description,
		faction = self.data.faction,
		model = self:GetModelPath() or "",
		height = self.data.height,
		skills = table.Copy(self.data.skills),
		kit = kit and kit.id or "",
		bodygroups = table.Copy(self.data.bodygroups),
		skin = self.data.skin
	}
end

function PANEL:GetSpentPoints()
	local total = 0

	for _, value in pairs(self.data.skills) do
		total = total + value
	end

	return total
end

function PANEL:GetValidation()
	if (self.validationFrame == FrameNumber() and self.validation) then
		return self.validation
	end

	local config = NETWORK.creation
	local payload = self:BuildPayload()
	local result = {payload = payload}

	result[1] = {config.ValidateIdentity(payload)}
	result[2] = {config.ValidateAppearance(payload, LocalPlayer())}
	result[3] = {config.ValidateSkills(payload)}
	result[4] = {config.ValidateGear(payload)}

	self.validation = result
	self.validationFrame = FrameNumber()

	return result
end

function PANEL:IsReady()
	if (self.bSaving) then
		return false
	end

	local validation = self:GetValidation()

	for i = 1, 4 do
		if (!validation[i][1]) then
			return false
		end
	end

	return true
end

function PANEL:Rebuild()
	local Sc = NETWORK.util.Scale

	for _, panel in ipairs(self:GetChildren()) do
		panel:Remove()
	end

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)

	self.layoutWidth = ScrW()
	self.layoutHeight = ScrH()

	self.modelX = Sc(30)
	self.modelWidth = math.Round(ScrW() * 0.34)
	self.contentX = self.modelX + self.modelWidth + Sc(50)
	self.contentWidth = ScrW() - self.contentX - Sc(80)
	self.contentY = Sc(170)
	self.contentHeight = ScrH() - self.contentY - Sc(120)

	self:BuildModel()
	self:BuildScroll()
	self:BuildActions()
end

function PANEL:PerformLayout()
	if (self.layoutWidth == ScrW() and self.layoutHeight == ScrH()) then
		return
	end

	self:Rebuild()
end

function PANEL:BuildModel()
	local Sc = NETWORK.util.Scale

	self.model = self:Add("DModelPanel")
	self.model:SetSize(self.modelWidth, ScrH() - Sc(160))
	self.model:SetPos(self.modelX, Sc(70))
	self.model:SetFOV(30)
	self.model:SetAnimated(true)
	self.model:SetCursor("sizewe")
	self.model.rotation = 18
	self.model.LayoutEntity = function(panel, entity)
		panel:RunAnimation()

		if (panel.bDragging) then
			local x = gui.MouseX()

			panel.rotation = panel.rotation + (x - (panel.lastX or x)) * 0.5
			panel.lastX = x
		end

		entity:SetAngles(Angle(0, panel.rotation % 360, 0))
	end
	self.model.OnMousePressed = function(panel, code)
		if (code != MOUSE_LEFT) then
			return
		end

		panel.bDragging = true
		panel.lastX = gui.MouseX()

		panel:MouseCapture(true)
	end
	self.model.OnMouseReleased = function(panel)
		panel.bDragging = false

		panel:MouseCapture(false)
	end
	self.model.PaintOver = function(panel, width, height)
		local palette = Palette()

		draw.SimpleText(L("createDragHint"), "nwHudSmall", math.Round(width * 0.5),
			height - Sc(12), ColorAlpha(palette.textFaint, 200), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end

	local views = {
		{id = "bust", label = "createViewBust"},
		{id = "body", label = "createViewBody"}
	}

	self.viewButtons = {}

	for i = 1, #views do
		local data = views[i]
		local button = self:Add("nwCreateButton")

		button:SetSize(Sc(120), Sc(30))
		button:SetPos(self.modelX + Sc(20) + (i - 1) * Sc(126), ScrH() - Sc(74))
		button:SetLabel(L(data.label))
		button:SetSelected(self.view == data.id)
		button.DoClick = function()
			self.view = data.id

			for index = 1, #self.viewButtons do
				self.viewButtons[index]:SetSelected(index == i)
			end

			self:RefreshModel(true)
		end

		self.viewButtons[i] = button
	end

	local strip = Sc(34)
	local stripY = ScrH() - Sc(112)

	local function Models(gender)
		local list = {}

		for index, path in ipairs(NETWORK.creation.GetModels(self.data.faction)) do
			if (!gender or NETWORK.creation.GetGender(path) == gender) then
				list[#list + 1] = index
			end
		end

		return list
	end

	function self:CycleModel(step)
		local list = Models(self.data.gender)

		if (#list == 0) then
			list = Models()
		end

		if (#list == 0) then
			return
		end

		local position = 1

		for index, modelIndex in ipairs(list) do
			if (modelIndex == self.data.model) then
				position = index

				break
			end
		end

		position = ((position - 1 + step) % #list) + 1

		self:SelectModel(list[position])

		for _, card in ipairs(self.modelCards or {}) do
			if (IsValid(card)) then
				card:SetSelected(card.modelIndex == self.data.model)
			end
		end
	end

	function self:SwapGender()
		local other = self.data.gender == "female" and "male" or "female"
		local list = Models(other)

		if (#list == 0) then
			return
		end

		self.data.gender = other
		self.data.bodygroups = {}
		self.data.skin = 0

		self:SelectModel(list[1])

		if (self.BuildBasics) then
			self:BuildAppearance()
			self:BuildDetails()
		end

		self:SyncGender()
	end

	function self:SyncGender()
		for index, button in ipairs(self.genderButtons or {}) do
			if (IsValid(button)) then
				button:SetSelected((index == 1) == (self.data.gender == "male"))
			end
		end

		if (IsValid(self.genderSwap)) then
			self.genderSwap:SetLabel(L(self.data.gender == "female" and "createGenderFemale" or
				"createGenderMale"))
		end
	end

	local prev = self:Add("nwCreateButton")

	prev:SetSize(strip, strip)
	prev:SetPos(self.modelX + Sc(20), stripY)
	prev:SetLabel("<")
	prev.DoClick = function()
		NETWORK.sound.Click()
		self:CycleModel(-1)
	end

	local gender = self:Add("nwCreateButton")

	gender:SetSize(Sc(186), strip)
	gender:SetPos(self.modelX + Sc(20) + strip + Sc(6), stripY)
	gender:SetLabel(L(self.data.gender == "female" and "createGenderFemale" or
		"createGenderMale"))
	gender.DoClick = function()
		NETWORK.sound.Click()
		self:SwapGender()
	end

	local next = self:Add("nwCreateButton")

	next:SetSize(strip, strip)
	next:SetPos(self.modelX + Sc(20) + strip + Sc(198), stripY)
	next:SetLabel(">")
	next.DoClick = function()
		NETWORK.sound.Click()
		self:CycleModel(1)
	end

	self.genderSwap = gender

	self:RefreshModel(true)
end

function PANEL:RefreshModel(bReframe)
	if (!IsValid(self.model)) then
		return
	end

	local config = NETWORK.creation
	local path = self:GetModelPath()

	if (!path) then
		return
	end

	if (self.modelPath != path) then
		self.model:SetModel(path)

		self.modelPath = path
		bReframe = true
	end

	local entity = self.model:GetEntity()

	if (!IsValid(entity)) then
		return
	end

	entity:SetModelScale(config.GetModelScale(path, self.data.height), 0)
	entity:SetSkin(self.data.skin or 0)

	for _, group in ipairs(config.GetBodygroups(path)) do
		entity:SetBodygroup(group.id, self.data.bodygroups[group.id] or 0)
	end

	local sequence = entity:LookupSequence("idle_all_01")

	if (sequence > 0 and entity:GetSequence() != sequence) then
		entity:ResetSequence(sequence)
	end

	if (!bReframe) then
		return
	end

	if (self.view == "body") then
		NETWORK.util.FrameModelPanel(self.model, config.GetFrameUnits(), 0.03, 1.12)

		return
	end

	local mins, maxs = entity:GetModelBounds()

	if (!mins or !maxs) then
		return
	end

	local scale = entity:GetModelScale() or 1
	local size = (maxs.z - mins.z) * scale
	local bottom = mins.z * scale
	local frame = size * 0.66
	local look = Vector((mins.x + maxs.x) * 0.5 * scale, (mins.y + maxs.y) * 0.5 * scale,
		bottom + size * 0.70)
	local width, height = self.model:GetSize()
	local aspect = width / math.max(height, 1)
	local horizontal = math.rad(self.model:GetFOV())
	local vertical = 2 * math.atan(math.tan(horizontal * 0.5) / math.max(aspect, 0.0001))
	local distance = (frame * 0.5) / math.max(math.tan(vertical * 0.5), 0.0001)

	self.model:SetLookAt(look)
	self.model:SetCamPos(look + Vector(distance, 0, 0))
end

function PANEL:BuildScroll()
	local Sc = NETWORK.util.Scale

	self.scroll = self:Add("DScrollPanel")
	self.scroll:SetSize(self.contentWidth + Sc(28), self.contentHeight)
	self.scroll:SetPos(self.contentX, self.contentY)

	StyleScrollbar(self.scroll)

	self.sections = {}

	self.step = self.step or 1

	if (!NETWORK.gui.bNewCharacterUI) then
		self:BuildIdentity()
		self:BuildBasics()

		self.appearanceHolder = self:Section(0)
		self.detailsHolder = self:Section(0)

		self:BuildAppearance()
		self:BuildDetails()

		self:BuildDescription()
		self:BuildSkills()
		self:BuildGear()

		self.lookCount = #self.sections

		self:ApplyStep()

		return
	end

	self:BuildIdentity()
	self:BuildDescription()
	self:BuildSkills()
	self:BuildGear()

	self.lookCount = #self.sections

	self:BuildBasics()

	self.appearanceHolder = self:Section(0)
	self.detailsHolder = self:Section(0)

	self:BuildAppearance()
	self:BuildDetails()

	self:ApplyStep()
end

function PANEL:ApplyStep()
	for index, section in ipairs(self.sections) do
		local bLook = index <= (self.lookCount or 0)

		section:SetVisible(!NETWORK.gui.bNewCharacterUI or bLook == (self.step == 1))
	end

	if (IsValid(self.scroll)) then
		self.scroll:InvalidateLayout(true)

		local bar = self.scroll:GetVBar()

		if (IsValid(bar)) then
			bar:SetScroll(0)
		end
	end
end

function PANEL:SetStep(step)
	step = math.Clamp(step, 1, 2)

	if (self.step == step) then
		return
	end

	self.step = step

	NETWORK.sound.Click()

	self:ApplyStep()
end

function PANEL:GetStepBlocker()
	local validation = self:GetValidation()

	if (!NETWORK.gui.bNewCharacterUI) then
		for _, index in ipairs({1, 2, 3, 4}) do
			local bValid, key, a, b = unpack(validation[index])

			if (!bValid) then
				return L(key or "createFillName", a, b)
			end
		end

		return nil
	end

	if (self.step == 1) then
		for _, index in ipairs({1, 3, 4}) do
			local bValid, key, a, b = unpack(validation[index])

			if (!bValid) then
				return L(key or "createFillName", a, b)
			end
		end

		return nil
	end

	local bValid, key, a, b = unpack(validation[2])

	return !bValid and L(key or "createFillAppearance", a, b) or nil
end

function PANEL:Section(height)
	local Sc = NETWORK.util.Scale
	local section = self.scroll:Add("DPanel")

	section:Dock(TOP)
	section:DockMargin(0, 0, Sc(28), Sc(30))
	section:SetTall(height)
	section.Paint = function() end

	self.sections[#self.sections + 1] = section

	return section
end

function PANEL:Header(parent, text, x, y, width, rightCallback)
	local Sc = NETWORK.util.Scale
	local header = parent:Add("DPanel")
	local caption = NETWORK.util.Upper(text)

	header:SetPos(x, y)
	header:SetSize(width, Sc(32))
	header:SetMouseInputEnabled(false)
	header.Paint = function(panel, panelWidth, panelHeight)
		local palette = Palette()

		draw.SimpleText(caption, "nwCreateHeader", 0, math.Round(panelHeight * 0.5),
			ColorAlpha(palette.title, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (rightCallback) then
			local value, color = rightCallback()

			if (value) then
				draw.SimpleText(value, "nwCreateValue", panelWidth,
					math.Round(panelHeight * 0.5), ColorAlpha(color or palette.textDim, 245),
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end
	end

	return header
end

function PANEL:Hint(parent, x, y, width, callback)
	local Sc = NETWORK.util.Scale
	local hint = parent:Add("DPanel")

	hint:SetPos(x, y)
	hint:SetSize(width, Sc(20))
	hint:SetMouseInputEnabled(false)
	hint.Paint = function(panel, panelWidth, panelHeight)
		local text, bError = callback()

		if (!text) then
			return
		end

		local palette = Palette()
		local color = bError and palette.error or palette.textFaint

		if (bError) then
			surface.SetDrawColor(color.r, color.g, color.b, 235)
			surface.DrawRect(0, math.Round(panelHeight * 0.5) - Sc(4), Sc(3), Sc(8))
		end

		draw.SimpleText(text, "nwCreateBody", bError and Sc(10) or 0,
			math.Round(panelHeight * 0.5), ColorAlpha(color, 230), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	return hint
end

function PANEL:BuildIdentity()
	local Sc = NETWORK.util.Scale
	local config = NETWORK.creation
	local width = self.contentWidth
	local section = self:Section(0)

	self:Header(section, L("createFullName"), 0, 0, width)

	self.nameEntry = section:Add("nwCreateEntry")
	self.nameEntry:SetSize(width, Sc(52))
	self.nameEntry:SetPos(0, Sc(38))
	self.nameEntry:SetFont("nwCreateField")
	self.nameEntry:SetPlaceholder(L("placeholderName"))
	self.nameEntry:SetLimit(config.nameMax * 2)
	self.nameEntry:SetText(string.Trim(self.data.name .. " " .. (self.data.surname or "")))
	self.nameEntry.OnValueChange = function(panel, value)
		self.data.name = string.Trim(value)
		self.data.surname = ""
	end

	local guide = section:Add("DPanel")
	local lines = {}

	local slotText = L("createSlotInfo", NETWORK.character.Count() + 1,
		NETWORK.character.maxSlots or 1)

	for _, line in ipairs(NETWORK.util.WrapText(slotText, "nwCreateBody", width, 2)) do
		lines[#lines + 1] = {text = line}
	end

	for i = 1, 3 do
		local key = "createGuide" .. i

		if (NETWORK.lang.Exists(key)) then
			local wrapped = NETWORK.util.WrapText(L(key), "nwCreateBody", width - Sc(26), 3)

			for index, line in ipairs(wrapped) do
				lines[#lines + 1] = {text = line, bullet = index == 1, indent = true}
			end
		end
	end

	local guideY = Sc(102)
	local lineHeight = Sc(21)

	guide:SetPos(0, guideY)
	guide:SetSize(width, #lines * lineHeight)
	guide:SetMouseInputEnabled(false)
	guide.Paint = function(panel, panelWidth, panelHeight)
		local palette = Palette()

		for i = 1, #lines do
			local line = lines[i]
			local y = (i - 1) * lineHeight + math.Round(lineHeight * 0.5)
			local x = line.indent and Sc(26) or 0

			if (line.bullet) then
				surface.SetDrawColor(palette.textDim.r, palette.textDim.g, palette.textDim.b, 220)
				surface.DrawRect(Sc(12), y - Sc(2), Sc(4), Sc(4))
			end

			draw.SimpleText(line.text, "nwCreateBody", x, y, ColorAlpha(palette.textDim, 235),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	local hintY = guideY + #lines * lineHeight + Sc(6)

	self:Hint(section, 0, hintY, width, function()
		local bValid, key, a, b = unpack(self:GetValidation()[1])
		local bNameError = !bValid and key != nil and key:sub(1, 7) == "errName"

		self.nameEntry:SetErrorState(bNameError)

		if (bNameError) then
			return L(key, a, b), true
		end

		return L("hintName"), false
	end)

	section:SetTall(hintY + Sc(20))
end

function PANEL:BuildBasics()
	local Sc = NETWORK.util.Scale
	local config = NETWORK.creation
	local width = self.contentWidth
	local section = self:Section(Sc(110))
	local columnWidth = math.Round((width - Sc(40)) * 0.5)

	self:Header(section, L("createGender"), 0, 0, columnWidth)

	local genders = {
		{id = "male", glyph = "♂"},
		{id = "female", glyph = "♀"}
	}

	self.genderButtons = {}

	for i = 1, #genders do
		local data = genders[i]
		local bAvailable = false

		for _, path in ipairs(config.GetModels(self.data.faction)) do
			if (config.GetGender(path) == data.id) then
				bAvailable = true

				break
			end
		end

		local button = section:Add("nwCreateButton")

		button:SetSize(Sc(64), Sc(64))
		button:SetPos((i - 1) * Sc(74), Sc(42))
		button:SetFont("nwCreateGlyph")
		button:SetLabel(data.glyph, true)
		button:SetSelected(self.data.gender == data.id)
		button:SetDisabled(!bAvailable)
		button.DoClick = function()
			if (self.data.gender == data.id) then
				return
			end

			self.data.gender = data.id

			for index = 1, #self.genderButtons do
				self.genderButtons[index]:SetSelected(index == i)
			end

			for index, path in ipairs(config.GetModels(self.data.faction)) do
				if (config.GetGender(path) == data.id) then
					self:SelectModel(index)

					break
				end
			end

			self:BuildAppearance()

			if (self.SyncGender) then
				self:SyncGender()
			end
		end

		self.genderButtons[i] = button
	end

	local heightX = columnWidth + Sc(40)

	self:Header(section, L("labelHeight"), heightX, 0, columnWidth, function()
		return self.data.height .. L("heightSuffix"), Palette().text
	end)

	local slider = section:Add("DPanel")

	slider:SetPos(heightX, Sc(46))
	slider:SetSize(columnWidth, Sc(56))
	slider:SetCursor("hand")
	slider.hover = 0
	slider.display = (self.data.height - config.heightMin) /
		math.max(config.heightMax - config.heightMin, 1)
	slider.UpdateFromCursor = function(panel)
		local x = panel:CursorPos()
		local track = panel:GetWide() - Sc(16)
		local fraction = math.Clamp((x - Sc(8)) / math.max(track, 1), 0, 1)
		local value = math.Round(config.heightMin + fraction * (config.heightMax - config.heightMin))

		if (value != self.data.height) then
			self.data.height = value

			self:RefreshModel(false)
		end
	end
	slider.OnMousePressed = function(panel)
		panel.bDragging = true

		panel:UpdateFromCursor()
		panel:MouseCapture(true)

		NETWORK.sound.CreateHover()
	end
	slider.OnMouseReleased = function(panel)
		panel.bDragging = false

		panel:MouseCapture(false)
	end
	slider.Think = function(panel)
		if (panel.bDragging) then
			panel:UpdateFromCursor()
		end

		panel.hover = NETWORK.util.Approach(panel.hover,
			(panel:IsHovered() or panel.bDragging) and 1 or 0, 10)
		panel.display = NETWORK.util.Approach(panel.display,
			(self.data.height - config.heightMin) / math.max(config.heightMax - config.heightMin, 1), 14)
	end
	slider.Paint = function(panel, panelWidth, panelHeight)
		local palette = Palette()
		local hover = NETWORK.util.EaseInOut(panel.hover)
		local trackX = Sc(8)
		local trackWidth = panelWidth - Sc(16)
		local trackY = math.Round(panelHeight * 0.5)
		local knobX = math.Round(trackX + trackWidth * panel.display)

		surface.SetDrawColor(palette.line.r, palette.line.g, palette.line.b, 160)
		surface.DrawRect(trackX, trackY - 1, trackWidth, Sc(2))

		surface.SetDrawColor(palette.select.r, palette.select.g, palette.select.b, 200 + 50 * hover)
		surface.DrawRect(trackX, trackY - 1, knobX - trackX, Sc(2))

		surface.SetDrawColor(palette.button.r, palette.button.g, palette.button.b, 250)
		surface.DrawRect(knobX - Sc(7), trackY - Sc(11), Sc(14), Sc(22))

		surface.SetDrawColor(palette.select.r, palette.select.g, palette.select.b, 220 + 35 * hover)
		surface.DrawOutlinedRect(knobX - Sc(7), trackY - Sc(11), Sc(14), Sc(22), 1)

		draw.SimpleText(config.heightMin .. L("heightSuffix"), "nwHudSmall", trackX,
			trackY + Sc(22), ColorAlpha(palette.textFaint, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(config.heightMax .. L("heightSuffix"), "nwHudSmall", trackX + trackWidth,
			trackY + Sc(22), ColorAlpha(palette.textFaint, 220), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

function PANEL:CardGrid(parent, y, width, count, builder)
	local Sc = NETWORK.util.Scale
	local size = Sc(self.cardSize)
	local gap = Sc(self.cardGap)
	local columns = math.max(math.floor((width + gap) / (size + gap)), 1)
	local cards = {}

	for i = 1, count do
		local card = parent:Add("nwCreateCard")

		card:SetSize(size, size)
		card:SetPos((i - 1) % columns * (size + gap), y + math.floor((i - 1) / columns) * (size + gap))

		builder(card, i)

		cards[i] = card
	end

	local rows = math.ceil(count / columns)

	return cards, math.max(rows * (size + gap) - gap, 0)
end

function PANEL:SelectModel(index)
	if (self.data.model == index) then
		return
	end

	self.data.model = index
	self.data.bodygroups = {}
	self.data.skin = 0

	self:RefreshModel(true)
	self:BuildDetails()
end

function PANEL:BuildAppearance()
	local Sc = NETWORK.util.Scale
	local config = NETWORK.creation
	local holder = self.appearanceHolder
	local width = self.contentWidth

	if (!IsValid(holder)) then
		return
	end

	for _, child in ipairs(holder:GetChildren()) do
		child:Remove()
	end

	self:Header(holder, L("createAppearance"), 0, 0, width)

	local models = config.GetModels(self.data.faction)

	local genders = {male = false, female = false}

	for _, path in ipairs(models) do
		genders[config.GetGender(path)] = true
	end

	local toggleHeight = 0

	if (genders.male and genders.female) then
		toggleHeight = Sc(40)

		local theme = NETWORK.theme
		local buttonWidth = math.floor((width - Sc(8)) * 0.5)

		for index, gender in ipairs({"male", "female"}) do
			local button = holder:Add("DButton")

			button:SetText("")
			button:SetCursor("hand")
			button:SetSize(buttonWidth, Sc(32))
			button:SetPos((index - 1) * (buttonWidth + Sc(8)), Sc(40))
			button.Paint = function(panel, panelWidth, panelHeight)
				local bOn = self.data.gender == gender
				local radius = math.max(Sc(6), 4)

				draw.RoundedBox(radius, 0, 0, panelWidth, panelHeight, Color(12, 13, 15, 220))

				if (bOn) then
					draw.RoundedBox(radius, 0, 0, panelWidth, panelHeight, ColorAlpha(theme.combine, 34))
				elseif (panel:IsHovered()) then
					draw.RoundedBox(radius, 0, 0, panelWidth, panelHeight, Color(255, 255, 255, 10))
				end

				NETWORK.util.DrawRoundedBorder(0, 0, panelWidth, panelHeight, radius, math.max(Sc(1), 1),
					bOn and ColorAlpha(theme.combine, 210) or Color(255, 255, 255, 30))
				draw.SimpleText(L(gender == "male" and "createGenderMale" or "createGenderFemale"),
					"nwInvBody", math.Round(panelWidth * 0.5), math.Round(panelHeight * 0.5),
					bOn and theme.text or theme.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			button.DoClick = function()
				if (self.data.gender == gender) then
					return
				end

				self.data.gender = gender

				for modelIndex, path in ipairs(models) do
					if (config.GetGender(path) == gender) then
						self.data.model = modelIndex

						break
					end
				end

				self.data.bodygroups = {}
				self.data.skin = 0

				NETWORK.sound.Click()
				self:RefreshModel(true)
				self:BuildAppearance()
				self:BuildDetails()

				if (self.SyncGender) then
					self:SyncGender()
				end
			end
		end
	end

	local visible = {}

	for index, path in ipairs(models) do
		if (config.GetGender(path) == self.data.gender) then
			visible[#visible + 1] = index
		end
	end

	if (#visible == 0) then
		for index = 1, #models do
			visible[#visible + 1] = index
		end
	end

	local cards, gridHeight = self:CardGrid(holder, Sc(40) + toggleHeight, width, #visible, function(card, i)
		local index = visible[i]

		card:Setup(models[index], {framing = "head"})
		card:SetSelected(self.data.model == index)
		card.modelIndex = index
		card.DoClick = function()
			for other = 1, #self.modelCards do
				self.modelCards[other]:SetSelected(other == i)
			end

			self:SelectModel(index)
		end
	end)

	self.modelCards = cards

	holder:SetTall(Sc(40) + toggleHeight + gridHeight)
	holder:InvalidateParent(true)
end

function PANEL:SyncDetailCards()
	local holder = self.detailsHolder

	if (!IsValid(holder)) then
		return
	end

	for _, set in ipairs(holder.cardSets or {}) do
		for i, card in ipairs(set.cards) do
			local entity = card:GetEntity()
			local bOwn

			if (set.group == "skin") then
				bOwn = self.data.skin == i - 1
			else
				bOwn = (self.data.bodygroups[set.group] or 0) == i - 1
			end

			card:SetSelected(bOwn)

			if (!IsValid(entity)) then
				continue
			end

			for id, value in pairs(self.data.bodygroups) do
				if (id != set.group) then
					entity:SetBodygroup(id, value)
				end
			end

			if (set.group != "skin") then
				entity:SetSkin(self.data.skin or 0)
			end
		end
	end
end

function PANEL:BuildDetails()
	local Sc = NETWORK.util.Scale
	local config = NETWORK.creation
	local holder = self.detailsHolder
	local width = self.contentWidth
	local path = self:GetModelPath()

	if (!IsValid(holder)) then
		return
	end

	for _, child in ipairs(holder:GetChildren()) do
		child:Remove()
	end

	holder.cardSets = {}

	local y = 0

	if (path) then
		for _, group in ipairs(config.GetBodygroups(path)) do
			self:Header(holder, config.GetBodygroupLabel(group.name), 0, y, width)

			local cards, gridHeight = self:CardGrid(holder, y + Sc(40), width, group.count,
				function(card, i)
					card:Setup(path, {
						framing = "head",
						bodygroups = self.data.bodygroups,
						skin = self.data.skin,
						group = group.id,
						value = i - 1
					})
					card:SetSelected((self.data.bodygroups[group.id] or 0) == i - 1)
					card.DoClick = function()
						self.data.bodygroups[group.id] = i - 1

						self:SyncDetailCards()
						self:RefreshModel(false)
					end
				end)

			holder.cardSets[#holder.cardSets + 1] = {group = group.id, cards = cards}

			y = y + Sc(40) + gridHeight + Sc(30)
		end

		local skins = config.GetSkinCount(path)

		if (skins > 1) then
			self:Header(holder, L("createSkin"), 0, y, width)

			local cards, gridHeight = self:CardGrid(holder, y + Sc(40), width, skins,
				function(card, i)
					card:Setup(path, {
						framing = "head",
						bodygroups = self.data.bodygroups,
						skin = i - 1
					})
					card:SetSelected(self.data.skin == i - 1)
					card.DoClick = function()
						self.data.skin = i - 1

						self:SyncDetailCards()
						self:RefreshModel(false)
					end
				end)

			holder.cardSets[#holder.cardSets + 1] = {group = "skin", cards = cards}

			y = y + Sc(40) + gridHeight + Sc(30)
		end
	end

	if (y > 0) then
		y = y - Sc(30)
	end

	holder:SetTall(y)
	holder:DockMargin(0, 0, Sc(28), y > 0 and Sc(30) or 0)
	holder:InvalidateParent(true)
end

function PANEL:BuildDescription()
	local Sc = NETWORK.util.Scale
	local config = NETWORK.creation
	local width = self.contentWidth
	local section = self:Section(Sc(40) + Sc(150) + Sc(30))

	self:Header(section, L("labelDescription"), 0, 0, width, function()
		local length = NETWORK.util.Length(self.data.description)
		local palette = Palette()

		return length .. " / " .. config.descriptionMax,
			length < config.descriptionMin and palette.textFaint or palette.text
	end)

	self.descriptionEntry = section:Add("nwCreateEntry")
	self.descriptionEntry:SetSize(width, Sc(150))
	self.descriptionEntry:SetPos(0, Sc(38))
	self.descriptionEntry:SetFont("nwCreateBody")
	self.descriptionEntry:SetPlaceholder(L("placeholderDescription"))
	self.descriptionEntry:SetLimit(config.descriptionMax)
	self.descriptionEntry:SetMultilineField(true)
	self.descriptionEntry:SetText(self.data.description)
	self.descriptionEntry.OnValueChange = function(panel, value)
		self.data.description = string.Trim(value)
	end

	self:Hint(section, 0, Sc(196), width, function()
		local bValid, key, a, b = unpack(self:GetValidation()[1])
		local bError = !bValid and key != nil and key:sub(1, 14) == "errDescription"

		self.descriptionEntry:SetErrorState(bError)

		if (bError) then
			return L(key, a, b), true
		end

		return L("hintDescription"), false
	end)
end

function PANEL:BuildSkills()
	local Sc = NETWORK.util.Scale
	local config = NETWORK.creation
	local width = self.contentWidth
	local rowHeight = Sc(46)
	local section = self:Section(Sc(44) + #config.skills * rowHeight)

	self:Header(section, L("stepSkills"), 0, 0, width, function()
		local left = config.skillPoints - self:GetSpentPoints()
		local palette = Palette()

		return NETWORK.util.Upper(L("freePoints")) .. ": " .. left .. " / " .. config.skillPoints,
			left > 0 and palette.text or palette.textFaint
	end)

	self.skillRows = {}

	for i = 1, #config.skills do
		local data = config.skills[i]
		local row = section:Add("DPanel")

		row:SetPos(0, Sc(44) + (i - 1) * rowHeight)
		row:SetSize(width, rowHeight - Sc(6))
		row:SetCursor("hand")
		row.hover = 0
		row.preview = -1
		row.segmentWidth = Sc(52)
		row.barX = width - config.skillMax * row.segmentWidth
		row.GetSegmentAt = function(panel, x)
			for index = 1, config.skillMax do
				local left = panel.barX + (index - 1) * panel.segmentWidth

				if (x >= left and x < left + panel.segmentWidth - Sc(6)) then
					return index
				end
			end

			return -1
		end
		row.OnCursorMoved = function(panel, x)
			panel.preview = panel:GetSegmentAt(x)
		end
		row.OnCursorExited = function(panel)
			panel.preview = -1
		end
		row.OnMousePressed = function(panel, code)
			local x = panel:CursorPos()
			local segment = panel:GetSegmentAt(x)

			if (segment < 0) then
				return
			end

			local current = self.data.skills[data.id] or 0

			if (code == MOUSE_RIGHT or segment == current) then
				segment = segment - 1
			end

			local spent = self:GetSpentPoints() - current + segment

			if (spent > config.skillPoints) then
				NETWORK.sound.Play("hover3", 92, 0.5)

				return
			end

			self.data.skills[data.id] = math.Clamp(segment, 0, config.skillMax)

			NETWORK.sound.CreatePress()
		end
		row.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 10)
		end
		row.Paint = function(panel, panelWidth, panelHeight)
			local palette = Palette()
			local hover = NETWORK.util.EaseInOut(panel.hover)
			local value = self.data.skills[data.id] or 0
			local middle = math.Round(panelHeight * 0.5)

			surface.SetDrawColor(palette.cell.r, palette.cell.g, palette.cell.b, 200 + 30 * hover)
			surface.DrawRect(0, 0, panelWidth, panelHeight)

			draw.SimpleText(NETWORK.util.Upper(L(data.name)), "nwCreateBodyBold", Sc(14),
				middle - Sc(8), ColorAlpha(palette.text, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(L(data.description), "nwHudSmall", Sc(14), middle + Sc(10),
				ColorAlpha(palette.textDim, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local segmentHeight = Sc(18)
			local segmentY = middle - math.Round(segmentHeight * 0.5)

			for index = 1, config.skillMax do
				local left = panel.barX + (index - 1) * panel.segmentWidth
				local segmentWidth = panel.segmentWidth - Sc(6)
				local bFilled = index <= value
				local bPreview = panel.preview >= index and panel.preview > value

				surface.SetDrawColor(palette.button.r, palette.button.g, palette.button.b, 240)
				surface.DrawRect(left, segmentY, segmentWidth, segmentHeight)

				if (bFilled) then
					surface.SetDrawColor(palette.select.r, palette.select.g, palette.select.b, 235)
					surface.DrawRect(left, segmentY, segmentWidth, segmentHeight)
				elseif (bPreview) then
					surface.SetDrawColor(palette.select.r, palette.select.g, palette.select.b, 60)
					surface.DrawRect(left, segmentY, segmentWidth, segmentHeight)
				end

				surface.SetDrawColor(palette.line.r, palette.line.g, palette.line.b, 120)
				surface.DrawOutlinedRect(left, segmentY, segmentWidth, segmentHeight, 1)
			end
		end

		self.skillRows[i] = row
	end
end

function PANEL:BuildGear()
	local Sc = NETWORK.util.Scale
	local config = NETWORK.creation
	local width = self.contentWidth
	local cardHeight = Sc(150)
	local gap = Sc(12)
	local section = self:Section(Sc(40) + cardHeight + Sc(30))
	local cardWidth = math.floor((width - gap * (#config.kits - 1)) / #config.kits)

	self:Header(section, L("labelKit"), 0, 0, width)

	self.kitCards = {}

	for i = 1, #config.kits do
		local kit = config.kits[i]
		local card = section:Add("nwCreateButton")

		card:SetSize(cardWidth, cardHeight)
		card:SetPos((i - 1) * (cardWidth + gap), Sc(40))
		card:SetLabel("", true)
		card:SetSelected(self.data.kit == i)
		card.DoClick = function()
			self.data.kit = i

			for index = 1, #self.kitCards do
				self.kitCards[index]:SetSelected(index == i)
			end
		end
		card.PaintOver = function(panel, panelWidth, panelHeight)
			local palette = Palette()
			local color = panel.bSelected and palette.text or palette.textDim

			draw.SimpleText(NETWORK.util.Upper(L(kit.name)), "nwCreateHeaderSmall", Sc(16), Sc(22),
				ColorAlpha(color, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(L(kit.description or ""), "nwHudSmall", Sc(16), Sc(42),
				ColorAlpha(palette.textDim, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local y = Sc(66)

			for _, line in ipairs(kit.items or {}) do
				surface.SetDrawColor(color.r, color.g, color.b, 200)
				surface.DrawRect(Sc(16), y - Sc(1), Sc(6), Sc(2))

				draw.SimpleText(line, "nwCreateBody", Sc(28), y, ColorAlpha(palette.textDim, 235),
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				y = y + Sc(19)
			end
		end

		self.kitCards[i] = card
	end

	self:Hint(section, 0, Sc(40) + cardHeight + Sc(8), width, function()
		return L("hintGear"), false
	end)
end

function PANEL:BuildActions()
	local Sc = NETWORK.util.Scale
	local y = ScrH() - Sc(84)

	self.createButton = self:Add("nwCreateButton")
	self.createButton:SetSize(Sc(300), Sc(50))
	self.createButton:SetPos(self.contentX, y)
	self.createButton:SetLabel(L("createFinish"))
	self.createButton:SetPrimary(true)

	self.createButton.DoClick = function()
		if (NETWORK.gui.bNewCharacterUI and self.step < 3) then
			if (self:GetStepBlocker()) then
				return
			end

			return self:SetStep(self.step + 1)
		end

		self:Finish()
	end

	self.backButton = self:Add("nwCreateButton")
	self.backButton:SetSize(Sc(220), Sc(50))
	self.backButton:SetPos(self.contentX + Sc(312), y)
	self.backButton:SetLabel(L("backButton"))
	self.backButton.DoClick = function()

		if (NETWORK.gui.bNewCharacterUI and self.step > 1) then
			return self:SetStep(self.step - 1)
		end

		self:Close()
	end

	self.statusX = self.contentX + Sc(548)
	self.statusY = y + Sc(25)
end

function PANEL:RefreshActions()
	if (!IsValid(self.createButton)) then
		return
	end

	local blocker = self:GetStepBlocker()

	if (!NETWORK.gui.bNewCharacterUI) then
		self.createButton:SetLabel(L("createFinish"))
		self.backButton:SetLabel(L("backButton"))

		return
	end

	self.createButton:SetLabel(self.step < 3 and L("createNext") or
		L("createFinish"))
	self.backButton:SetLabel(self.step > 1 and L("createBack") or L("backButton"))

	self:SetStatus(blocker, blocker != nil)
end

function PANEL:SetStatus(text, bError)
	self.status = text
	self.bStatusError = tobool(bError)
end

function PANEL:Finish()
	if (self.bSaving) then
		return
	end

	local payload = self:BuildPayload()
	local bValid, key, a, b = NETWORK.creation.Validate(payload, LocalPlayer())

	if (!bValid) then
		self:SetStatus(L(key, a, b), true)
		NETWORK.sound.Play("hover3", 92, 0.5)

		return
	end

	self.bSaving = true

	self:SetStatus(L("saving"), false)

	NETWORK.character.RequestCreate(payload)

	timer.Simple(5, function()
		if (IsValid(self)) then
			self.bSaving = false
		end
	end)
end

function PANEL:Think()
	local util = NETWORK.util

	self:RefreshActions()

	self.alpha = util.Approach(self.alpha, self.bClosing and 0 or 1, 6)
	self.statusFade = util.Approach(self.statusFade, self.status and 1 or 0, 8)

	self:SetAlpha(math.Round(self.alpha * 255))

	if (self.bClosing and self.alpha < 0.02) then
		if (self.OnClosed) then
			self:OnClosed()
		end

		self:Remove()

		return
	end

	if (IsValid(self.createButton)) then

		if (NETWORK.gui.bNewCharacterUI) then
			self.createButton:SetDisabled(self.step >= 3 and !self:IsReady() or
				self:GetStepBlocker() != nil)
		else
			self.createButton:SetDisabled(!self:IsReady())
		end
	end
end

function PANEL:GetReveal(delay, duration)
	if (self.bClosing) then
		return self.alpha
	end

	return NETWORK.util.EaseOut(NETWORK.util.Stagger(self.startTime, delay, duration or 0.8))
end

function PANEL:Paint(width, height)

	if (NETWORK.gui.PaintSteps) then
		NETWORK.gui.PaintSteps(width, NETWORK.util.Scale(54),
			self.step + 1, self.alpha or 1)
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local palette = Palette()
	local theme = NETWORK.theme
	local reveal = self:GetReveal(0.05, 0.9)
	local faction = NETWORK.factions.Get(self.data.faction)
	local tint = faction and faction.color or theme.accentDeep

	util.DrawBlur(self, 3 * self.alpha, 0.25)

	surface.SetDrawColor(palette.background.r, palette.background.g, palette.background.b,
		(NETWORK.camera.bConfigured and 150 or 236) * self.alpha)
	surface.DrawRect(0, 0, width, height)

	local light = Color(
		Lerp(0.26, tint.r, theme.background.r),
		Lerp(0.26, tint.g, theme.background.g),
		Lerp(0.26, tint.b, theme.background.b)
	)

	util.DrawSoftLight(self.modelX + math.Round(self.modelWidth * 0.5),
		math.Round(height * 0.46), math.Round(self.modelWidth * 1.25),
		math.Round(height * 0.95), light, 54 * self.alpha)

	util.DrawVignette(0, 0, width, height,
		math.Round(math.min(width, height) * 0.55), 205 * self.alpha)

	local x = Sc(40) - math.Round((1 - reveal) * Sc(30))
	local y = Sc(30)
	local title = util.Upper(L("createTitle"))

	surface.SetFont("nwCreateTitle")

	local titleWidth, titleHeight = surface.GetTextSize(title)
	local mark = math.Round(titleHeight * 0.58)
	local textX = x
	local logo = util.GetMaterial("logos/n-logo.png", "smooth")

	if (logo and !logo:IsError()) then
		local markY = y + math.Round((titleHeight - mark) * 0.5)

		surface.SetDrawColor(255, 255, 255, 235 * reveal)
		surface.SetMaterial(logo)
		surface.DrawTexturedRect(x, markY, mark, mark)

		textX = x + mark + Sc(14)
	end

	util.DrawSimpleTextShadow(title, "nwCreateTitle", textX, y,
		ColorAlpha(palette.title, 120 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 2)

	local lineY = y + titleHeight - Sc(2)

	surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 140 * reveal)
	surface.DrawRect(x, lineY, math.Round((textX - x + titleWidth) * reveal), 1)

	if (faction) then
		util.DrawTextSpacedShadow(util.Upper(L("creationFaction", L(faction.name))),
			"nwMenuSub", x, lineY + Sc(16), ColorAlpha(faction.color, 230 * reveal), Sc(3),
			TEXT_ALIGN_CENTER)
	end

	if (self.status and self.statusFade > 0.01) then
		local color = self.bStatusError and palette.error or palette.ok

		util.DrawSimpleTextShadow(self.status, "nwCreateBody", self.statusX or 0,
			self.statusY or 0, ColorAlpha(color, 240 * self.statusFade),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	util.DrawHGradient(self.contentX, ScrH() - Sc(104), self.contentWidth, 1,
		ColorAlpha(theme.line, 160 * self.alpha), ColorAlpha(theme.line, 0))
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)

	NETWORK.sound.CreatePress()
end

vgui.Register("nwCharacterCreate", PANEL, "EditablePanel")

hook.Add("NetworkCharacterResult", "nwCreationResult", function(action, bSuccess, text)
	local menu = NETWORK.gui.menu

	if (action != "create" or !IsValid(menu) or !IsValid(menu.creation)) then
		return
	end

	menu.creation.bSaving = false

	menu.creation:SetStatus(text, !bSuccess)
end)
