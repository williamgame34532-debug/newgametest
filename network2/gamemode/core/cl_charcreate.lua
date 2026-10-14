-- Character creation, step by step, over its own camera flight (nw_charcam_point_*):
--   1 name        "Введите имя персонажа"
--   2 description "Введите описание..." (height, build, marks, the look)
--   3 gender      two rounded buttons; the character model appears on the left
--   4 model       the citizen models of that gender, the skin under them, the height
--   5 skills      points to spread
-- Every step is a glass panel (blurred scene behind, 9-slice material). A finished step moves up,
-- the next one comes in under it, joined by a line from the middle of the panel above. ENTER
-- moves on (the yellow hint says so once the step is filled in); any step can be reopened at any
-- time from the row at the top. Sounds: textline_* on keys and buttons, hls_ui_affirm on ENTER,
-- hls_ui_appear when a panel comes in. Nothing ever leaves the screen.

NW.charCreate = NW.charCreate or {}

local CC = NW.charCreate
local U = NW.ui
local C = NW.char

local STEPS = {
	{id = "name", title = "Введите имя персонажа", chip = "Имя"},
	{id = "description", title = "Введите описание...",
		sub = "Укажите рост, телосложение, приметы и сам внешний вид персонажа", chip = "Описание"},
	{id = "gender", title = "Выберите пол", chip = "Пол"},
	{id = "model", title = "Выберите внешность", chip = "Внешность"},
	{id = "skills", title = "Распределите навыки", chip = "Навыки"}
}

local function Lerp2(current, target, speed)
	return Lerp(math.Clamp(FrameTime() * speed, 0, 1), current, target)
end

local function Valid(step)
	local d = CC.data

	if (step == 1) then
		return C.CheckName(d.name)
	elseif (step == 2) then
		return C.CheckDescription(d.description)
	elseif (step == 3) then
		return d.gender != nil, "Выберите пол"
	elseif (step == 4) then
		return d.model != nil, "Выберите модель"
	end

	return C.CheckSkills(d.skills)
end

local function PointsLeft()
	local total = 0

	for _, skill in ipairs(C.skills) do
		total = total + (CC.data.skills[skill.id] or 0)
	end

	return C.skillBudget - total
end

-- ------------------------------------------------------------------ layout --
local function Layout()
	local w, h = ScrW(), ScrH()
	local L = {}

	L.margin = math.Round(h * 0.035)
	L.model = {x = w * 0.03, y = h * 0.12, w = w * 0.31, h = h * 0.8}
	L.columnLeft = L.model.x + L.model.w + w * 0.03
	L.columnRight = w - w * 0.04
	L.pw = math.min(L.columnRight - L.columnLeft, h * 1.05)
	L.cx = (L.columnLeft + L.columnRight) / 2
	L.px = L.cx - L.pw / 2
	L.top = h * 0.17                     -- under the title and the step row
	L.bottom = h - h * 0.11               -- above the bottom buttons
	L.heights = {h * 0.15, h * 0.24, h * 0.21}
	L.gap = h * 0.04
	L.big = math.min(L.bottom - L.top - h * 0.02, h * 0.66)
	L.center = (L.top + L.bottom) / 2
	L.skillsHeight = math.min(L.big, h * 0.58)

	return L
end

-- ------------------------------------------------------------------- panels --
local function PanelHeight(index)
	local L = CC.layout

	if (index <= 3) then
		return L.heights[index]
	elseif (index == 4) then
		return CC.modelHeight or L.big
	end

	return L.skillsHeight
end

local function Panel(index)
	local L = CC.layout
	local p = CC.panels[index]

	return L.px, p.y, L.pw, PanelHeight(index), p.a
end

-- y / alpha of every step panel, animated towards their targets each frame
local function Targets(L)
	local targets = {}
	local step = CC.step

	if (step <= 3) then
		-- the active panel in the middle, the finished ones above it, joined by lines; the whole
		-- stack is moved down when its top would run into the step row, and never below the bottom
		local ys = {}
		local y = L.center - L.heights[step] / 2

		ys[step] = y

		for k = step - 1, 1, -1 do
			y = y - L.heights[k] - L.gap
			ys[k] = y
		end

		for k = step + 1, math.min(CC.reached, 3) do
			ys[k] = ys[k - 1] + L.heights[k - 1] + L.gap
		end

		local first, last = 1, math.min(math.max(CC.reached, step), 3)
		local shift = math.max(0, L.top - ys[first])

		shift = math.min(shift, math.max(0, L.bottom - (ys[last] + L.heights[last])))

		for k = 1, 3 do
			if (ys[k]) then
				local ty = ys[k] + shift
				local inside = ty >= L.top - 4 and ty + L.heights[k] <= L.bottom + 4

				targets[k] = {y = ty, a = k == step and 1 or (inside and 0.62 or 0)}
			else
				targets[k] = {y = L.bottom + 40, a = 0}
			end
		end

		targets[4] = {y = L.bottom + 40, a = 0}
		targets[5] = {y = L.bottom + 40, a = 0}
	else
		-- model / skills: the small panels fly up and away, the big one takes the middle
		for k = 1, 3 do
			targets[k] = {y = L.top - L.heights[k] - 60, a = 0}
		end

		local h4, h5 = PanelHeight(4), PanelHeight(5)

		targets[4] = {y = step == 4 and L.center - h4 / 2 or L.top - h4 - 60, a = step == 4 and 1 or 0}
		targets[5] = {y = step == 5 and L.center - h5 / 2 or L.bottom + 40, a = step == 5 and 1 or 0}
	end

	return targets
end

-- ---------------------------------------------------------------- the model --
local function PreviewModel()
	local d = CC.data
	local model = d.model

	if (!model) then
		local list = C.GetModels(d.gender or "male")

		model = list[1] and list[1].path or "models/network/citizens/male01.mdl"
	end

	return NW.models.Resolve(model)
end

-- the model's plain standing idle (stock HL2 activity), not the build's living stances
local IDLES = {}

local function UpdatePreview()
	local panel = CC.preview

	if (!IsValid(panel)) then
		return
	end

	local model = PreviewModel()

	if (panel:GetModel() != model) then
		panel:SetModel(model)

		local entity = panel:GetEntity()

		if (IsValid(entity)) then
			local sequence

			for _, name in ipairs(IDLES) do
				local id = entity:LookupSequence(name)

				if (id and id > 0) then
					sequence = id

					break
				end
			end

			entity:ResetSequence(sequence or math.max(entity:SelectWeightedSequence(ACT_IDLE), 0))
			entity:SetCycle(math.Rand(0, 1))
		end
	end

	local entity = panel:GetEntity()

	if (IsValid(entity)) then
		entity:SetSkin(CC.data.skin or 0)
		entity:SetModelScale(CC.data.height or 1, 0)
	end
end

-- ------------------------------------------------------------------ actions --
local function Appear()
	CC.appearTime = RealTime()
	U.Play("appear")
end

function CC.Go(step)
	step = math.Clamp(step, 1, math.max(CC.reached, 1))

	if (step == CC.step) then
		return
	end

	U.Tick()
	CC.step = step
	CC.error = nil
	CC.Focus()
end

function CC.Advance()
	local ok, err = Valid(CC.step)

	if (!ok) then
		CC.error = err
		CC.shake = RealTime()
		U.Tick()

		return
	end

	CC.error = nil

	if (CC.step == 5) then
		return CC.Submit()
	end

	U.Play("affirm")

	CC.step = CC.step + 1

	if (CC.step > CC.reached) then
		CC.reached = CC.step
		Appear()
	end

	CC.Focus()
end

function CC.Submit()
	if (CC.sending) then
		return
	end

	CC.sending = true
	U.Play("affirm")

	local d = CC.data

	net.Start("nwCharCreate")
		net.WriteString(d.name)
		net.WriteString(d.description)
		net.WriteString(d.gender or "")
		net.WriteString(d.model or "")
		net.WriteUInt(d.skin or 0, 8)
		net.WriteFloat(d.height or 1)

		for _, skill in ipairs(C.skills) do
			net.WriteUInt(d.skills[skill.id] or 0, 4)
		end
	net.SendToServer()
end

function CC.OnResult(ok, text)
	CC.sending = false

	if (!IsValid(CC.frame)) then
		return
	end

	if (!ok) then
		CC.error = text
		CC.shake = RealTime()

		return
	end

	-- created: away with the creation, to the character selection
	NW.menu.PlayConfirm()
	U.Transition(function()
		CC.Close()
		NW.charSelect.Open()
	end, 0.6, 0.8, 0.3)
end

-- keyboard focus goes to the text field of the active step
function CC.Focus()
	if (!IsValid(CC.frame)) then
		return
	end

	if (CC.step == 1 and IsValid(CC.nameEntry)) then
		CC.nameEntry:RequestFocus()
	elseif (CC.step == 2 and IsValid(CC.descEntry)) then
		CC.descEntry:RequestFocus()
	else
		CC.frame:RequestFocus()
	end
end

-- ------------------------------------------------------------- text fields --
local function TextEntry(parent, multiline)
	local entry = parent:Add("DTextEntry")

	entry:SetMultiline(multiline)
	entry:SetFont(multiline and "nwText" or "nwTextBig")
	entry:SetPaintBackground(false)
	entry:SetTextColor(U.color.text)
	entry:SetCursorColor(U.color.text)
	entry:SetHighlightColor(Color(64, 190, 240, 90))
	entry:SetUpdateOnType(true)
	entry:SetDrawLanguageID(false)
	entry.Paint = function(self, w, h)
		self:DrawTextEntryText(U.color.text, Color(64, 190, 240, 90), U.color.text)
	end
	entry.OnKeyCodeTyped = function(self, code)
		if (code == KEY_ENTER or code == KEY_PAD_ENTER) then
			-- Shift+Enter: a new line in the description
			if (multiline and input.IsKeyDown(KEY_LSHIFT)) then
				return
			end

			CC.Advance()

			return true
		end

		if (code == KEY_TAB) then
			return true
		end

		U.Tick()
	end

	return entry
end

-- ------------------------------------------------------- model / skin / height --
local function BuildModelGrid()
	for _, child in ipairs(CC.modelIcons or {}) do
		if (IsValid(child)) then
			child:Remove()
		end
	end

	for _, child in ipairs(CC.skinIcons or {}) do
		if (IsValid(child)) then
			child:Remove()
		end
	end

	CC.modelIcons, CC.skinIcons = {}, {}
	CC.gridGender = CC.data.gender

	for _, entry in ipairs(C.GetModels(CC.data.gender or "male")) do
		local icon = CC.frame:Add("SpawnIcon")

		icon:SetModel(NW.models.Resolve(entry.path))
		icon:SetTooltip(entry.title)
		icon.path = entry.path
		icon.DoClick = function()
			U.Tick()

			if (CC.data.model != entry.path) then
				CC.data.model = entry.path
				CC.data.skin = 0
				CC.skinsFor = nil
			end
		end
		icon.PaintOver = function(self, w, h)
			local selected = CC.data.model == entry.path

			if (selected or self:IsHovered()) then
				U.Slice(U.Material("network2/ui/outline.png"), 0, 0, w, h, 12, 255, 255, 255,
					(selected and 255 or 90) * (self.alpha or 1))
			end
		end

		table.insert(CC.modelIcons, icon)
	end
end

-- skins of the chosen model as small portraits under the model list
local function BuildSkins()
	for _, child in ipairs(CC.skinIcons or {}) do
		if (IsValid(child)) then
			child:Remove()
		end
	end

	CC.skinIcons = {}
	CC.skinsFor = CC.data.model

	if (!CC.data.model) then
		return
	end

	local model = NW.models.Resolve(CC.data.model)
	local probe = ClientsideModel(model, RENDERGROUP_OTHER)
	local count = IsValid(probe) and probe:SkinCount() or 1

	if (IsValid(probe)) then
		probe:Remove()
	end

	for skin = 0, math.max(count - 1, 0) do
		local icon = CC.frame:Add("SpawnIcon")

		icon:SetModel(model, skin)
		icon:SetTooltip("Скин " .. (skin + 1))
		icon.DoClick = function()
			U.Tick()
			CC.data.skin = skin
		end
		icon.PaintOver = function(self, w, h)
			local selected = (CC.data.skin or 0) == skin

			if (selected or self:IsHovered()) then
				U.Slice(U.Material("network2/ui/outline.png"), 0, 0, w, h, 10, 255, 255, 255,
					(selected and 255 or 90) * (self.alpha or 1))
			end
		end

		table.insert(CC.skinIcons, icon)
	end
end

-- ------------------------------------------------------------------- open --
function CC.Close()
	if (IsValid(CC.frame)) then
		CC.frame:Remove()
	end
end

function CC.Open()
	CC.Close()

	NW.menu.SetCamera("char")

	CC.data = {name = "", description = "", gender = nil, model = nil, skin = 0, height = 1, skills = {}}
	CC.step = 1
	CC.reached = 1
	CC.error = nil
	CC.sending = false
	CC.layout = Layout()
	CC.panels = {}
	CC.modelIcons, CC.skinIcons = {}, {}
	CC.gridGender = nil
	CC.skinsFor = nil
	CC.previewAlpha = 0
	CC.dragging = false

	for k = 1, 5 do
		CC.panels[k] = {y = CC.layout.bottom + 40, a = 0}
	end

	local frame = vgui.Create("EditablePanel")
	frame:SetSize(ScrW(), ScrH())
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(true)
	CC.frame = frame

	-- the character model, left
	local preview = frame:Add("DModelPanel")
	preview:SetFOV(26)
	preview:SetCamPos(Vector(120, 0, 44))
	preview:SetLookAt(Vector(0, 0, 38))
	preview:SetAmbientLight(Color(70, 74, 82))
	preview:SetDirectionalLight(BOX_TOP, Color(230, 232, 236))
	preview:SetDirectionalLight(BOX_FRONT, Color(140, 146, 156))
	preview:SetAlpha(0)
	preview.LayoutEntity = function(self, entity)
		entity:SetAngles(Angle(0, 12 + math.sin(RealTime() * 0.35) * 14, 0))
		self:RunAnimation()
	end
	CC.preview = preview

	CC.nameEntry = TextEntry(frame, false)
	CC.descEntry = TextEntry(frame, true)
	CC.nameEntry.OnValueChange = function(self, value)
		CC.data.name = value
		CC.error = nil
	end
	CC.descEntry.OnValueChange = function(self, value)
		CC.data.description = value
		CC.error = nil
	end

	-- gender buttons
	CC.genderButtons = {}

	for index, gender in ipairs({"female", "male"}) do
		local button = frame:Add("DButton")

		button:SetText("")
		button.hover = 0
		button.Paint = function(self, w, h)
			self.hover = Lerp2(self.hover, self:IsHovered() and 1 or 0, 10)
			U.Button(0, 0, w, h, self.alpha or 1, CC.data.gender == gender, self.hover)

			local size = h * 0.55
			U.DrawIcon(gender, (w - size) / 2, h * 0.14, size, U.color.text, self.alpha or 1)
			draw.SimpleText(gender == "male" and "Мужской" or "Женский", "nwSmall", w / 2, h * 0.86,
				ColorAlpha(U.color.dim, 255 * (self.alpha or 1)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			U.Tick()

			if (CC.data.gender != gender) then
				CC.data.gender = gender
				CC.data.model = C.GetModels(gender)[1] and C.GetModels(gender)[1].path
				CC.data.skin = 0
				CC.skinsFor = nil
			end

			CC.error = nil
		end

		CC.genderButtons[index] = button
	end

	-- skill +/- buttons
	CC.skillButtons = {}

	for _, skill in ipairs(C.skills) do
		for _, delta in ipairs({-1, 1}) do
			local button = frame:Add("DButton")

			button:SetText("")
			button.hover = 0
			button.Paint = function(self, w, h)
				self.hover = Lerp2(self.hover, self:IsHovered() and 1 or 0, 10)
				U.Button(0, 0, w, h, self.alpha or 1, false, self.hover)
				draw.SimpleText(delta > 0 and "+" or "−", "nwHeader", w / 2, h / 2 - 1,
					ColorAlpha(U.color.text, 255 * (self.alpha or 1)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			button.DoClick = function()
				local value = (CC.data.skills[skill.id] or 0) + delta

				if (value < 0 or value > C.skillMax or (delta > 0 and PointsLeft() <= 0)) then
					return
				end

				U.Tick()
				CC.data.skills[skill.id] = value
			end

			table.insert(CC.skillButtons, {button = button, skill = skill, delta = delta})
		end
	end

	-- create / back buttons
	local function BottomButton(text, icon, callback)
		local button = frame:Add("DButton")

		button:SetText("")
		button.hover = 0
		button.Paint = function(self, w, h)
			self.hover = Lerp2(self.hover, self:IsHovered() and 1 or 0, 10)
			U.Button(0, 0, w, h, self.alpha or 1, false, self.hover)

			local size = h * 0.42
			U.DrawIcon(icon, h * 0.35, (h - size) / 2, size, U.color.text, self.alpha or 1)
			draw.SimpleText(text, "nwButton", h * 0.35 + size + h * 0.3, h / 2,
				ColorAlpha(U.color.text, 255 * (self.alpha or 1)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			U.Tick()
			callback()
		end

		return button
	end

	CC.createButton = BottomButton("Создать персонажа", "check", function()
		CC.Advance()
	end)
	CC.backButton = BottomButton("Назад", "back", function()
		U.Transition(function()
			CC.Close()

			if (#(C.list or {}) > 0) then
				NW.charSelect.Open()
			else
				NW.menu.ShowMain(true)
			end
		end, 0.4, 0.6)
	end)

	-- the step row at the top: reopen any step reached so far
	CC.chips = {}

	for index, step in ipairs(STEPS) do
		local chip = frame:Add("DButton")

		chip:SetText("")
		chip.hover = 0
		chip.Paint = function(self, w, h)
			if (index > CC.reached) then
				return
			end

			self.hover = Lerp2(self.hover, self:IsHovered() and 1 or 0, 10)
			U.Button(0, 0, w, h, 1, CC.step == index, self.hover)

			local done = index < CC.reached or (index == CC.reached and Valid(index))

			draw.SimpleText(index .. "  " .. step.chip, "nwSmall", w / 2, h / 2,
				CC.step == index and U.color.text or (done and U.color.text or U.color.dim), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end
		chip.DoClick = function()
			if (index <= CC.reached) then
				CC.Go(index)
			end
		end

		CC.chips[index] = chip
	end

	frame.OnKeyCodePressed = function(self, code)
		if (code == KEY_ENTER or code == KEY_PAD_ENTER) then
			CC.Advance()
		end
	end

	frame.Think = CC.Think
	frame.Paint = CC.Paint

	Appear()
	timer.Simple(0, CC.Focus)
end

-- ------------------------------------------------------------------- think --
local function Place(panel, x, y, w, h, alpha, bVisible)
	if (!IsValid(panel)) then
		return
	end

	local visible = bVisible and alpha > 0.03

	panel:SetVisible(visible)

	if (visible) then
		panel:SetPos(math.Round(x), math.Round(y))
		panel:SetSize(math.Round(w), math.Round(h))
		panel:SetAlpha(255 * alpha)
		panel.alpha = alpha
	end
end

function CC.Think()
	local L = CC.layout
	local targets = Targets(L)

	for k = 1, 5 do
		local p, t = CC.panels[k], targets[k]

		p.y = Lerp2(p.y, t.y, 9)
		p.a = Lerp2(p.a, t.a, 9)
	end

	local w, h = ScrW(), ScrH()
	local pad = h * 0.03

	-- name field
	do
		local x, y, pw, ph, a = Panel(1)
		Place(CC.nameEntry, x + pad, y + ph * 0.42, pw - pad * 2, ph * 0.38, a, true)
		CC.nameEntry:SetEnabled(CC.step == 1)
	end

	-- description field
	do
		local x, y, pw, ph, a = Panel(2)
		Place(CC.descEntry, x + pad, y + ph * 0.36, pw - pad * 2, ph * 0.46, a, true)
		CC.descEntry:SetEnabled(CC.step == 2)
	end

	-- gender buttons
	do
		local x, y, pw, ph, a = Panel(3)
		local bw, bh = ph * 0.6, ph * 0.5
		local gap = pw * 0.05

		for index, button in ipairs(CC.genderButtons) do
			local bx = x + pw / 2 + (index == 1 and -gap / 2 - bw or gap / 2)
			Place(button, bx, y + ph * 0.27, bw, bh, a, CC.reached >= 3)
		end
	end

	-- model grid, skins, height
	if (CC.gridGender != CC.data.gender and CC.data.gender) then
		BuildModelGrid()
	end

	if (CC.skinsFor != CC.data.model) then
		BuildSkins()
	end

	do
		local x, y, pw, ph, a = Panel(4)
		local icons = CC.modelIcons
		local gap = 6
		local columns = math.max(1, math.min(#icons, 8))
		local cell = math.floor(math.min((pw - pad * 2 - (columns - 1) * gap) / columns, h * 0.085))
		local gx = x + (pw - (cell + gap) * columns + gap) / 2
		local gridTop = y + h * 0.075

		for index, icon in ipairs(icons) do
			local col, row = (index - 1) % columns, math.floor((index - 1) / columns)
			Place(icon, gx + col * (cell + gap), gridTop + row * (cell + gap), cell, cell, a, CC.step == 4)
		end

		local rows = math.max(1, math.ceil(#icons / columns))
		CC.skinY = gridTop + rows * (cell + gap) + h * 0.012
		local skinCell = math.floor(math.min(cell * 0.7, (pw - pad * 2) / math.max(#CC.skinIcons, 1) - gap))
		local sx = x + (pw - (skinCell + gap) * #CC.skinIcons + gap) / 2

		for index, icon in ipairs(CC.skinIcons) do
			Place(icon, sx + (index - 1) * (skinCell + gap), CC.skinY + h * 0.03, skinCell, skinCell, a, CC.step == 4)
		end

		-- the panel is as tall as its content: grid, skins, height
		CC.modelHeight = (CC.skinY + h * 0.03 + skinCell + h * 0.11) - y + h * 0.035

		CC.heightBar = {x = x + pw * 0.2, y = CC.skinY + h * 0.03 + skinCell + h * 0.065, w = pw * 0.6, h = h * 0.012}

		-- dragging the height
		if (CC.step == 4 and input.IsMouseDown(MOUSE_LEFT)) then
			local mx, my = input.GetCursorPos()
			local bar = CC.heightBar

			if (CC.dragging or (mx >= bar.x - 10 and mx <= bar.x + bar.w + 10 and math.abs(my - bar.y) < h * 0.025)) then
				CC.dragging = true

				local f = math.Clamp((mx - bar.x) / bar.w, 0, 1)
				local value = math.Round((C.height.min + (C.height.max - C.height.min) * f) * 100) / 100

				if (value != CC.data.height) then
					CC.data.height = value
					U.Tick()
				end
			end
		else
			CC.dragging = false
		end
	end

	-- skill buttons
	do
		local x, y, pw, ph, a = Panel(5)
		local rowH = (ph - ph * 0.3) / #C.skills

		for _, entry in ipairs(CC.skillButtons) do
			local index = 0

			for k, skill in ipairs(C.skills) do
				if (skill == entry.skill) then
					index = k
				end
			end

			local ry = y + ph * 0.16 + (index - 1) * rowH
			local size = rowH * 0.56
			local bx = x + pw - pad - size * (entry.delta > 0 and 1 or 2) - (entry.delta > 0 and 0 or 6)

			Place(entry.button, bx, ry + (rowH - size) / 2, size, size, a, CC.step == 5)
		end
	end

	-- bottom buttons
	local bh, bw = h * 0.06, w * 0.17

	Place(CC.backButton, w * 0.03, h - bh - h * 0.03, bw * 0.7, bh, 1, true)
	Place(CC.createButton, L.cx - bw / 2, h - bh - h * 0.03, bw, bh, CC.step == 5 and 1 or 0, CC.step == 5)

	-- step row
	local chipW, chipH = math.min((L.pw - 4 * 8) / 5, w * 0.11), h * 0.04

	for index, chip in ipairs(CC.chips) do
		Place(chip, L.cx - (chipW * 5 + 32) / 2 + (index - 1) * (chipW + 8), h * 0.09, chipW, chipH, 1,
			index <= CC.reached)
	end

	-- the model on the left appears with the gender step
	local m = L.model
	local appear = CC.reached >= 3 and 1 or 0

	CC.previewAlpha = Lerp2(CC.previewAlpha or 0, appear, 4)
	Place(CC.preview, m.x - (1 - CC.previewAlpha) * 60, m.y, m.w, m.h, CC.previewAlpha, true)
	UpdatePreview()
end

-- ------------------------------------------------------------------- paint --
local function DrawLine(x, y1, y2, alpha)
	if (y2 - y1 < 4 or alpha <= 0.02) then
		return
	end

	local c = U.color.line

	surface.SetDrawColor(c.r, c.g, c.b, c.a * alpha)
	surface.DrawRect(x - 1, y1, 2, y2 - y1)
	draw.RoundedBox(3, x - 3, y1 - 3, 6, 6, ColorAlpha(c, c.a * alpha))
	draw.RoundedBox(3, x - 3, y2 - 3, 6, 6, ColorAlpha(c, c.a * alpha))
end

local function Hint(text, x, y, alpha, color)
	draw.SimpleText(text, "nwSmall", x, y, ColorAlpha(color or U.color.hint, 255 * alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)
end

function CC.Paint(self, w, h)
	local L = CC.layout

	-- vignette and title
	surface.SetMaterial(U.Material("network2/menu/vignette.png"))
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(0, 0, w, h)
	draw.SimpleText("СОЗДАНИЕ ПЕРСОНАЖА", "nwTitle", w * 0.035, h * 0.03, ColorAlpha(U.color.text, 200))

	local shake = CC.shake and math.max(0, 1 - (RealTime() - CC.shake) * 3) or 0
	local sx = math.sin(RealTime() * 60) * 8 * shake

	-- lines between the step panels (middle of the lower edge -> middle of the upper edge)
	for k = 1, 2 do
		local _, y1, _, h1, a1 = Panel(k)
		local _, y2, _, _, a2 = Panel(k + 1)

		DrawLine(L.cx, y1 + h1, y2, math.min(a1, a2))
	end

	for k = 1, 5 do
		local x, y, pw, ph, a = Panel(k)

		if (a > 0.02) then
			local active = CC.step == k
			local ox = active and sx or 0

			U.Panel(x + ox, y, pw, ph, a, self)

			local step = STEPS[k]
			local pad = h * 0.03

			draw.SimpleText(step.title, "nwHeader", x + pad + ox, y + pad * 0.9, ColorAlpha(U.color.text, 255 * a))

			if (step.sub) then
				draw.SimpleText("(" .. step.sub .. ")", "nwSmall", x + pad + ox, y + pad * 0.9 + h * 0.034,
					ColorAlpha(U.color.dim, 255 * a))
			end

			-- name / description: an underline under the field
			if (k <= 2) then
				local fy = k == 1 and y + ph * 0.82 or y + ph * 0.84

				surface.SetDrawColor(255, 255, 255, 40 * a)
				surface.DrawRect(x + pad, fy, pw - pad * 2, 1)
			end

			if (k == 4) then
				draw.SimpleText("Скин", "nwSmall", x + pad, (CC.skinY or y) + h * 0.005, ColorAlpha(U.color.dim, 255 * a))

				local bar = CC.heightBar

				if (bar) then
					local f = (CC.data.height - C.height.min) / (C.height.max - C.height.min)

					draw.SimpleText("Рост: " .. math.Round(C.height.baseCm * CC.data.height) .. " см", "nwSmall", x + pad,
						bar.y - h * 0.035, ColorAlpha(U.color.dim, 255 * a))
					draw.RoundedBox(4, bar.x, bar.y - bar.h / 2, bar.w, bar.h, Color(255, 255, 255, 30 * a))
					draw.RoundedBox(4, bar.x, bar.y - bar.h / 2, bar.w * f, bar.h, Color(220, 226, 232, 160 * a))
					draw.RoundedBox(8, bar.x + bar.w * f - 8, bar.y - 8, 16, 16, Color(240, 244, 248, 255 * a))
					U.DrawIcon("height", bar.x - h * 0.045, bar.y - h * 0.015, h * 0.03, U.color.dim, a)
				end
			end

			if (k == 5) then
				local rowH = (ph - ph * 0.3) / #C.skills

				for index, skill in ipairs(C.skills) do
					local ry = y + ph * 0.16 + (index - 1) * rowH
					local size = rowH * 0.5
					local value = CC.data.skills[skill.id] or 0

					U.DrawIcon(skill.icon, x + pad, ry + (rowH - size) / 2, size, U.color.text, a)
					draw.SimpleText(skill.name, "nwButton", x + pad + size + pad * 0.6, ry + rowH * 0.36,
						ColorAlpha(U.color.text, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					draw.SimpleText(skill.text, "nwSmall", x + pad + size + pad * 0.6, ry + rowH * 0.7,
						ColorAlpha(U.color.dim, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

					-- pips
					local pip = rowH * 0.2
					local px = x + pw * 0.56

					for n = 1, C.skillMax do
						local filled = n <= value

						draw.RoundedBox(pip / 2, px + (n - 1) * (pip + 6), ry + (rowH - pip) / 2, pip, pip,
							filled and Color(236, 240, 244, 230 * a) or Color(255, 255, 255, 34 * a))
					end
				end

				draw.SimpleText("Осталось очков: " .. PointsLeft(), "nwButton", x + pw - pad, y + pad * 0.9,
					ColorAlpha(PointsLeft() > 0 and U.color.hint or U.color.dim, 255 * a), TEXT_ALIGN_RIGHT)
			end

			-- hints at the bottom of the active panel
			if (active) then
				local hy = y + ph - h * 0.022

				if (CC.error) then
					Hint(CC.error, x + pw / 2, hy, a, U.color.error)
				elseif (Valid(k)) then
					local text = k == 5 and "Нажмите ENTER, чтобы создать персонажа" or "Нажмите ENTER, чтобы продолжить"
					local pulse = 0.75 + math.sin(RealTime() * 3) * 0.25

					Hint(text, x + pw / 2, hy, a * pulse)
				end
			end
		end
	end
end
