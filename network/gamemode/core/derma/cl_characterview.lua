local PANEL = {}

PANEL.headYaw = 38
PANEL.headPitch = 26

local idleSequences = {
	"idle_all_01", "idle_subtle", "idle_unarmed", "idle01", "idle_angry",
	"idle_passive", "idle"
}

local function ResolveIdle(entity)
	for _, name in ipairs(idleSequences) do
		local sequence = entity:LookupSequence(name)

		if (sequence and sequence > 0) then
			return sequence
		end
	end

	return entity:SelectWeightedSequence(ACT_IDLE)
end

function PANEL:Init()
	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)

	self.pages = {}
	self.index = 1
	self.alpha = 0
	self.bClosing = false
	self.swap = 1
	self.startTime = CurTime()
	self.tint = Color(60, 66, 72)
	self.tintTarget = Color(60, 66, 72)
	self.loading = 0
	self.bLoading = false
	self.bStrip = true

	self:BuildPages()
	self:BuildControls()

	if (self.bStrip) then
		self:BuildStrip()
	end

	self:Refresh()
end

function PANEL:BuildStrip()
	if (IsValid(self.strip)) then
		self.strip:Remove()
	end

	local Sc = NETWORK.util.Scale
	local strip = self:Add("EditablePanel")

	strip.cards = {}

	self.strip = strip

	for index, page in ipairs(self.pages) do
		local card = strip:Add("DButton")

		card:SetText("")
		card.index = index
		card.page = page

		card.DoClick = function()
			if (self.index == index or self.bLoading) then
				return
			end

			self.index = index

			NETWORK.sound.Click()

			self:Refresh()
		end

		card.Paint = function(panel, width, height)
			self:PaintCard(panel, width, height, page, index)
		end

		strip.cards[#strip.cards + 1] = card
	end
end

function PANEL:PaintCard(panel, width, height, page, index)
	local S = NETWORK.style
	local P = S.Pda()
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local bOn = self.index == index
	local bHover = panel:IsHovered()
	local alpha = util.EaseOut(self.alpha or 0)

	if (alpha < 0.01) then
		return
	end

	local character = page.character
	local faction = character and NETWORK.factions.Get(character:GetFaction())
	local color = faction and faction.color or P.muted

	surface.SetDrawColor(P.deep.r, P.deep.g, P.deep.b, (bOn and 240 or 200) * alpha)
	surface.DrawRect(0, 0, width, height)

	if (bOn or bHover) then
		surface.SetDrawColor(P.accent.r, P.accent.g, P.accent.b, (bOn and 34 or 14) * alpha)
		surface.DrawRect(0, 0, width, height)
	end

	surface.SetDrawColor(P.line.r, P.line.g, P.line.b, (bOn and 255 or 170) * alpha)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	if (bOn) then
		S.Ticks(0, 0, width, height, Sc(8), ColorAlpha(P.accent, 255 * alpha))
	end

	draw.SimpleText(string.format("%02d", index), S.Font("mono", 11, 600), Sc(8), Sc(7),
		ColorAlpha(bOn and P.accent or P.faint, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	if (page.bCreate) then
		draw.SimpleText("+", S.Font("body", 30, 600), width * 0.5, height * 0.44,
			ColorAlpha(P.accent, 230 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(util.Upper(L("createNew")), S.Font("label", 11, 700), width * 0.5,
			height * 0.76, ColorAlpha(P.muted, 230 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		return
	end

	if (!character) then
		return
	end

	surface.SetDrawColor(color.r, color.g, color.b, 235 * alpha)
	surface.DrawRect(1, height - math.max(Sc(3), 2) - 1, width - 2, math.max(Sc(3), 2))

	local nameFont = S.Font("body", 17, 600)
	local name = util.TruncateWidth(character:GetName(), nameFont, width - Sc(16))

	draw.SimpleText(name, nameFont, Sc(8), height * 0.5,
		ColorAlpha(bOn and P.text or Color(190, 206, 220), 245 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(util.Upper(NETWORK.factions.GetName(character:GetFaction())),
		S.Font("label", 10, 700), Sc(8), height * 0.5 + Sc(18),
		ColorAlpha(color, (bOn and 240 or 190) * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function PANEL:BuildPages()
	local pages = {}

	for _, character in ipairs(NETWORK.character.list or {}) do
		pages[#pages + 1] = {character = character}
	end

	if (NETWORK.character.HasFreeSlot()) then
		pages[#pages + 1] = {bCreate = true}
	end

	self.pages = pages
	self.index = math.Clamp(self.index, 1, math.max(#pages, 1))
end

function PANEL:GetPage()
	return self.pages[self.index]
end

function PANEL:GetCharacter()
	local page = self:GetPage()

	return page and page.character or nil
end

function PANEL:BuildControls()
	local Sc = NETWORK.util.Scale

	self.takeButton = self:Add("nwMenuButton")
	self.takeButton:SetAlign("center")
	self.takeButton:SetRevealDelay(0.2)
	self.takeButton.DoClick = function()
		self:Confirm()
	end

	self.deleteButton = self:Add("nwMenuButton")
	self.deleteButton:SetAlign("center")
	self.deleteButton:SetFontName("nwMenuItemSmall")
	self.deleteButton:SetRevealDelay(0.26)
	self.deleteButton:SetLabel(L("delete"))
	self.deleteButton.DoClick = function()
		self:DeleteCharacter()
	end

	self.backButton = self:Add("nwMenuButton")
	self.backButton:SetAlign("left")
	self.backButton:SetFontName("nwMenuItemSmall")
	self.backButton:SetRevealDelay(0.3)
	self.backButton:SetLabel(L("back"))
	self.backButton.DoClick = function()
		self:Close()
	end

	local S = NETWORK.style

	self.takeButton.Paint = function(panel, width, height)
		S.Button(panel, width, height, self.alpha, {primary = true})
	end

	self.deleteButton.Paint = function(panel, width, height)
		S.Button(panel, width, height, self.alpha, {danger = true, small = true})
	end

	self.backButton.Paint = function(panel, width, height)
		S.Button(panel, width, height, self.alpha, {small = true})
	end

	self.nextButton = self:BuildArrow(1)

	if (self.bStrip) then
		self.prevButton = self:BuildArrow(-1)
	end
end

function PANEL:BuildArrow(direction)
	local Sc = NETWORK.util.Scale
	local button = self:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button.hover = 0
	button.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 8)
	end
	button.OnCursorEntered = function()
		NETWORK.sound.MenuHover()
	end
	button.Paint = function(panel, width, height)
		local util = NETWORK.util
		local hover = util.EaseInOut(panel.hover)
		local alpha = self.alpha * (0.45 + 0.55 * hover)
		local centerX = math.Round(width * 0.5) + math.Round(direction * hover * Sc(5))
		local centerY = math.Round(height * 0.5)
		local arm = Sc(13) + math.Round(hover * Sc(3))
		local thickness = math.max(Sc(3), 2)
		local P = NETWORK.style.Pda()
		local color = ColorAlpha(Color(
			Lerp(hover, P.muted.r, P.accent.r),
			Lerp(hover, P.muted.g, P.accent.g),
			Lerp(hover, P.muted.b, P.accent.b)
		), 255 * alpha)

		surface.SetDrawColor(P.deep.r, P.deep.g, P.deep.b, 190 * self.alpha)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(P.line.r, P.line.g, P.line.b, (120 + 120 * hover) * self.alpha)
		surface.DrawOutlinedRect(0, 0, width, height, 1)

		util.DrawThickLine(centerX - direction * arm * 0.5, centerY - arm,
			centerX + direction * arm * 0.5, centerY, thickness, color)
		util.DrawThickLine(centerX - direction * arm * 0.5, centerY + arm,
			centerX + direction * arm * 0.5, centerY, thickness, color)
	end
	button.DoClick = function()
		self:Shift(direction)
	end

	return button
end

function PANEL:BuildModel(character)
	if (IsValid(self.model)) then
		self.model:Remove()

		self.model = nil
	end

	if (!character) then
		return
	end

	local model = self:Add("DModelPanel")

	model:SetFOV(32)
	model:SetAnimated(true)
	model:SetModel(character:GetModel())
	model:SetCursor("sizewe")

	model.rotation = 8
	model.headYaw = 0
	model.headPitch = 0

	model.zoom = 1
	model.zoomWanted = 1
	model.panY = 0
	model.panZ = 0
	model.panWantedY = 0
	model.panWantedZ = 0

	model.LayoutEntity = function(panel, entity)
		panel:RunAnimation()

		local x, y = gui.MouseX(), gui.MouseY()

		if (panel.bDragging) then
			panel.rotation = panel.rotation + (x - (panel.lastX or x)) * 0.4
		end

		if (panel.bPanning) then

			local step = (panel.distance or 60) * 0.0016

			panel.panWantedY = panel.panWantedY - (x - (panel.lastX or x)) * step
			panel.panWantedZ = panel.panWantedZ + (y - (panel.lastY or y)) * step
		end

		panel.lastX = x
		panel.lastY = y

		local speed = math.Clamp(FrameTime() * 9, 0, 1)

		panel.zoom = Lerp(speed, panel.zoom, panel.zoomWanted)
		panel.panY = Lerp(speed, panel.panY, panel.panWantedY)
		panel.panZ = Lerp(speed, panel.panZ, panel.panWantedZ)

		self:ApplyCamera(panel)

		entity:SetAngles(Angle(0, panel.rotation % 360, 0))

		self:TrackHead(panel, entity)
	end

	model.OnMousePressed = function(panel, code)

		if (code == MOUSE_MIDDLE) then
			panel.zoomWanted = 1
			panel.panWantedY = 0
			panel.panWantedZ = 0
			panel.rotation = 8

			NETWORK.sound.MenuPress()

			return
		end

		if (code != MOUSE_LEFT and code != MOUSE_RIGHT) then
			return
		end

		panel.bDragging = code == MOUSE_LEFT
		panel.bPanning = code == MOUSE_RIGHT
		panel.lastX = gui.MouseX()
		panel.lastY = gui.MouseY()

		panel:MouseCapture(true)
	end

	model.OnMouseReleased = function(panel)
		panel.bDragging = false
		panel.bPanning = false

		panel:MouseCapture(false)
	end

	model.OnMouseWheeled = function(panel, delta)

		panel.zoomWanted = math.Clamp(panel.zoomWanted * (1 - delta * 0.12), 0.4, 2.2)

		return true
	end

	local entity = model:GetEntity()

	if (IsValid(entity)) then
		entity:SetModelScale(character:GetScale(), 0)
		entity:SetSkin(character:GetSkin())

		for index, value in pairs(character:GetBodygroups()) do
			entity:SetBodygroup(index, value)
		end

		local sequence = ResolveIdle(entity)

		if (sequence and sequence > 0) then
			entity:ResetSequence(sequence)
		end
	end

	self.model = model

	for _, name in ipairs({"nextButton", "takeButton",
		"deleteButton", "backButton"}) do
		if (IsValid(self[name])) then
			self[name]:MoveToFront()
		end
	end

	self:InvalidateLayout(true)
end

function PANEL:ApplyCamera(panel)
	local base = panel.baseCam
	local look = panel.baseLook

	if (!base or !look) then
		return
	end

	local distance = base.x - look.x

	panel.distance = distance * panel.zoom

	panel:SetCamPos(Vector(look.x + panel.distance, base.y + panel.panY,
		base.z + panel.panZ))
	panel:SetLookAt(Vector(look.x, look.y + panel.panY, look.z + panel.panZ))
end

function PANEL:TrackHead(panel, entity)
	local x, y = input.GetCursorPos()
	local dx = math.Clamp((x / ScrW() - 0.5) * 2, -1, 1)
	local dy = math.Clamp((y / ScrH() - 0.5) * 2, -1, 1)
	local speed = math.Clamp(FrameTime() * 4, 0, 1)

	panel.headYaw = Lerp(speed, panel.headYaw or 0, dx * PANEL.headYaw)
	panel.headPitch = Lerp(speed, panel.headPitch or 0, dy * PANEL.headPitch)

	local facing = math.Clamp(math.cos(math.rad(panel.rotation or 0)), -1, 1)
	local yaw = panel.headYaw * facing

	entity:SetPoseParameter("head_yaw", yaw)
	entity:SetPoseParameter("head_pitch", panel.headPitch)
	entity:SetPoseParameter("aim_yaw", yaw * 0.35)
	entity:SetPoseParameter("aim_pitch", panel.headPitch * 0.35)
	entity:InvalidateBoneCache()

	local camPos = panel:GetCamPos()

	entity:SetEyeTarget(Vector(camPos.x, camPos.y + dx * 40, camPos.z - dy * 30))
end

function PANEL:Refresh()
	local character = self:GetCharacter()

	self:BuildModel(character)

	if (IsValid(self.takeButton)) then
		self.takeButton:SetLabel(character and L("menuTake") or L("menuCreate"))
	end

	if (IsValid(self.deleteButton)) then
		self.deleteButton:SetVisible(character != nil)
		self.deleteButton:SetLabel(L("delete"))
	end

	self.bDeleteConfirm = false

	local faction = character and character:GetFactionTable()
	local color = faction and faction.color or NETWORK.theme.accentDeep

	self.tintTarget = Color(color.r, color.g, color.b)

	if (IsValid(self.nextButton)) then
		self.nextButton:SetVisible(#self.pages > 1)
	end

	self.lines = nil
	self.swap = 0

	self:InvalidateLayout(true)
end

function PANEL:Shift(direction)
	if (#self.pages < 2) then
		return
	end

	self.index = (self.index - 1 + direction) % #self.pages + 1

	self:Refresh()
end

function PANEL:Confirm()
	if (self.bLoading) then
		return
	end

	local character = self:GetCharacter()

	if (!character) then
		if (self.OnCreate) then
			self:OnCreate()
		end

		return
	end

	NETWORK.sound.MenuLoad()

	self.bLoading = true

	for _, name in ipairs({"takeButton", "deleteButton", "backButton", "nextButton"}) do
		local panel = self[name]

		if (IsValid(panel)) then
			panel:SetMouseInputEnabled(false)

			if (panel.SetExiting) then
				panel:SetExiting(true)
			end
		end
	end

	NETWORK.character.RequestSelect(character:GetID())
end

function PANEL:StopLoading()
	if (!self.bLoading) then
		return
	end

	self.bLoading = false

	for index, name in ipairs({"takeButton", "deleteButton", "backButton", "nextButton"}) do
		local panel = self[name]

		if (IsValid(panel)) then
			panel:SetMouseInputEnabled(true)

			if (panel.SetExiting) then
				panel:SetExiting(false)

				panel.startTime = CurTime()
				panel:SetRevealDelay(index * 0.05)
			end
		end
	end
end

function PANEL:DeleteCharacter()
	local character = self:GetCharacter()

	if (!character) then
		return
	end

	if (!self.bDeleteConfirm) then
		self.bDeleteConfirm = true

		self.deleteButton:SetLabel(L("deleteConfirm"))
		self.deleteButton:SetDanger(true)

		timer.Simple(3, function()
			if (IsValid(self) and self.bDeleteConfirm) then
				self.bDeleteConfirm = false

				self.deleteButton:SetLabel(L("delete"))
				self.deleteButton:SetDanger(false)
			end
		end)

		return
	end

	self.bDeleteConfirm = false

	NETWORK.character.RequestDelete(character:GetID())
end

function PANEL:LayoutStrip(width, height)
	if (!IsValid(self.strip)) then
		return
	end

	local Sc = NETWORK.util.Scale
	local count = #self.strip.cards

	if (count == 0) then
		return
	end

	local gap = Sc(10)
	local maxWidth = width - Sc(120)
	local cardWidth = math.min(Sc(132), (maxWidth - gap * (count - 1)) / count)
	local cardTall = Sc(84)
	local total = count * cardWidth + gap * (count - 1)
	local left = math.Round((width - total) * 0.5)

	local top = height - cardTall - Sc(24)

	self.strip:SetPos(0, 0)
	self.strip:SetSize(width, height)

	for index, card in ipairs(self.strip.cards) do
		local bOn = self.index == index

		card:SetSize(cardWidth, cardTall)
		card:SetPos(math.Round(left + (index - 1) * (cardWidth + gap)),
			math.Round(top - (bOn and Sc(8) or 0)))
	end
end

function PANEL:OnListUpdated()
	self:BuildPages()
	self:Refresh()

	if (self.bStrip) then
		self:BuildStrip()
	end

	self:InvalidateLayout(true)
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self:LayoutStrip(width, height)

	self.inset = math.min(Sc(64), math.Round(width * 0.06))
	self.panelX = self.inset
	self.panelWidth = math.Clamp(math.Round(width * 0.26), Sc(240), Sc(400))

	local buttonWidth = Sc(240)
	local centerX = math.Round(width * 0.55 - buttonWidth * 0.5)

	local stripHeight = (self.bStrip and #self.pages > 1) and
		Sc(126) or 0
	local takeY = height - self.inset - Sc(78) - stripHeight
	local modelTop = Sc(60)

	if (IsValid(self.model)) then
		local modelWidth = math.Round(width * 0.42)
		local modelHeight = math.max(takeY - modelTop - Sc(14), Sc(200))

		self.model:SetSize(modelWidth, modelHeight)
		self.model:SetPos(math.Round(width * 0.55 - modelWidth * 0.5), modelTop)

		NETWORK.util.FrameModelPanel(self.model, NETWORK.creation.GetFrameUnits(),
			-0.02, 1.1)

		self.model.baseCam = self.model:GetCamPos()
		self.model.baseLook = self.model:GetLookAt()

		self:ApplyCamera(self.model)
	end

	if (IsValid(self.takeButton)) then
		self.takeButton:SetSize(buttonWidth, Sc(40))
		self.takeButton:SetPos(centerX, takeY)
	end

	if (IsValid(self.deleteButton)) then
		self.deleteButton:SetSize(buttonWidth, Sc(26))
		self.deleteButton:SetPos(centerX, takeY + Sc(46))
	end

	if (IsValid(self.backButton)) then
		self.backButton:SetSize(Sc(160), Sc(28))
		self.backButton:SetPos(self.inset, height - self.inset - Sc(28))
	end

	local arrow = Sc(56)
	local arrowY = math.Round((height - arrow) * 0.5)

	local bMany = #self.pages > 1

	if (IsValid(self.nextButton)) then
		self.nextButton:SetVisible(bMany)
		self.nextButton:SetSize(arrow, arrow)
		self.nextButton:SetPos(math.Round(width * 0.74) + Sc(18), arrowY)
	end

	if (IsValid(self.prevButton)) then
		self.prevButton:SetVisible(bMany)
		self.prevButton:SetSize(arrow, arrow)
		self.prevButton:SetPos(math.Round(width * 0.36) - arrow - Sc(18), arrowY)
	end
end

function PANEL:Think()
	local util = NETWORK.util

	self.alpha = util.Approach(self.alpha, self.bClosing and 0 or 1, self.bClosing and 8 or 4)
	self.swap = util.Approach(self.swap or 1, 1, 5)
	self.loading = util.Approach(self.loading or 0, self.bLoading and 1 or 0, 2.5)

	self.tint = Color(
		util.Approach(self.tint.r, self.tintTarget.r, 1.6),
		util.Approach(self.tint.g, self.tintTarget.g, 1.6),
		util.Approach(self.tint.b, self.tintTarget.b, 1.6)
	)

	if (IsValid(self.model)) then
		self.model:SetAlpha(math.Round(self.alpha * self.swap * 255))
	end

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()
	end
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	NETWORK.sound.MenuPress()

	for _, name in ipairs({"takeButton", "deleteButton", "backButton", "nextButton"}) do
		local panel = self[name]

		if (IsValid(panel)) then
			panel:SetMouseInputEnabled(false)

			if (panel.SetExiting) then
				panel:SetExiting(true)
			end
		end
	end

	if (self.OnClosed) then
		self:OnClosed()
	end
end

function PANEL:PaintBackdrop(width, height)
	local S = NETWORK.style
	local P = S.Pda()
	local util = NETWORK.util
	local Sc = util.Scale
	local a = self.alpha
	local inset = self.inset or Sc(48)

	util.DrawVGradient(0, 0, width, height, Color(8, 18, 30, 255 * a), Color(4, 9, 16, 255 * a), 28)
	S.Grid(0, 0, width, height, Sc(64), a)

	-- Soft light behind the model stage.
	util.DrawSoftLight(width * 0.55, height * 0.42, width * 0.34, height * 0.66, P.accent, 30 * a)

	-- Model stage frame.
	local stageX = math.Round(width * 0.36)
	local stageW = math.Round(width * 0.38)
	local stageY = math.Round(height * 0.08)
	local stageH = math.Round(height * 0.66)

	surface.SetDrawColor(P.line.r, P.line.g, P.line.b, 90 * a)
	surface.DrawOutlinedRect(stageX, stageY, stageW, stageH, 1)
	S.Ticks(stageX, stageY, stageW, stageH, Sc(16), ColorAlpha(P.accent, 160 * a), math.max(Sc(2), 2))

	-- Header strip.
	local strip = Sc(40)

	surface.SetDrawColor(P.deep.r, P.deep.g, P.deep.b, 225 * a)
	surface.DrawRect(0, 0, width, strip)
	surface.SetDrawColor(P.line.r, P.line.g, P.line.b, 200 * a)
	surface.DrawRect(0, strip, width, 1)

	local cap = S.Font("label", 12, 700)

	draw.SimpleText("C24  ·  " .. util.Upper(L("charArchive")), cap, inset, math.Round(strip * 0.5),
		ColorAlpha(P.muted, 240 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(util.Upper(L("charStateSaved")), cap, width - inset, math.Round(strip * 0.5),
		ColorAlpha(P.good, 230 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	draw.SimpleText(util.Upper(L("charSelectTitle")), S.Font("display", 34, 700), inset, strip + Sc(28),
		ColorAlpha(P.text, 250 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	surface.SetDrawColor(P.accent.r, P.accent.g, P.accent.b, 230 * a)
	surface.DrawRect(inset, strip + Sc(76), Sc(42), math.max(Sc(2), 2))
end

local function Field(x, y, label, value, width, alpha)
	local S = NETWORK.style
	local P = S.Pda()
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local valueFont = S.Font("body", 18, 500)

	draw.SimpleText(util.Upper(label), S.Font("label", 11, 700), x, y,
		ColorAlpha(P.faint, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local lines = util.WrapText(value, valueFont, width, 4)
	local lineY = y + Sc(19)

	for i = 1, #lines do
		draw.SimpleText(lines[i], valueFont, x, lineY,
			ColorAlpha(P.text, 240 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		lineY = lineY + Sc(19)
	end

	return lineY + Sc(8)
end

local function Stat(x, y, label, value, color, width, alpha)
	local S = NETWORK.style
	local P = S.Pda()
	local Sc = NETWORK.util.Scale
	local cap = S.Font("label", 11, 700)

	draw.SimpleText(NETWORK.util.Upper(label), cap, x, y,
		ColorAlpha(P.faint, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(math.Round(value) .. "%", S.Font("mono", 12, 600), x + width, y,
		ColorAlpha(color, 245 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	-- Segmented PDA meter.
	local barY = y + Sc(10)
	local barHeight = math.max(Sc(5), 3)
	local segments = 20
	local gap = math.max(Sc(2), 1)
	local segment = (width - gap * (segments - 1)) / segments
	local lit = math.Clamp(value / 100, 0, 1) * segments

	for i = 0, segments - 1 do
		local sx = math.Round(x + i * (segment + gap))
		local sw = math.Round(x + (i + 1) * (segment + gap) - gap) - sx
		local fill = math.Clamp(lit - i, 0, 1)

		surface.SetDrawColor(255, 255, 255, 14 * alpha)
		surface.DrawRect(sx, barY, sw, barHeight)

		if (fill > 0) then
			surface.SetDrawColor(color.r, color.g, color.b, (70 + 170 * fill) * alpha)
			surface.DrawRect(sx, barY, sw, barHeight)
		end
	end

	return barY + Sc(24)
end

function PANEL:PaintChips(x, y, panelWidth, character, alpha)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local chips = {}

	local health = character.GetHealth and character:GetHealth() or 100

	if (health <= 0) then
		chips[#chips + 1] = {text = L("chipDead"), color = theme.danger}
	elseif (health < 40) then
		chips[#chips + 1] = {text = L("chipHurt"), color = theme.warning}
	end

	local played = character.GetPlayTime and character:GetPlayTime() or 0

	if (played > 0) then
		chips[#chips + 1] = {
			text = played >= 3600 and
				L("chipPlayedHours", math.floor(played / 3600)) or
				L("chipPlayedMinutes", math.max(math.floor(played / 60), 1)),
			color = theme.textDim
		}
	end

	local class = character.GetClass and character:GetClass()
	local classTable = class and NETWORK.classes and NETWORK.classes.Get(class)

	if (classTable and classTable.name) then
		chips[#chips + 1] = {text = L(classTable.name), color = theme.combine}
	end

	if (#chips == 0) then
		return y
	end

	if (!isnumber(y) or !isnumber(x) or !isnumber(panelWidth)) then
		return y
	end

	local chipFont = NETWORK.style.Font("label", 11, 700)

	surface.SetFont(chipFont)

	local cursorX = x
	local rowY = y
	local rowHeight = Sc(21)

	for _, chip in ipairs(chips) do
		local text = util.Upper(chip.text)
		local textWidth = surface.GetTextSize(text)
		local chipWidth = textWidth + Sc(16)

		if (cursorX + chipWidth > x + panelWidth and cursorX > x) then
			cursorX = x
			rowY = rowY + rowHeight + Sc(6)
		end

		surface.SetDrawColor(7, 15, 25, 220 * alpha)
		surface.DrawRect(cursorX, rowY, chipWidth, rowHeight)
		surface.SetDrawColor(44, 70, 96, 220 * alpha)
		surface.DrawOutlinedRect(cursorX, rowY, chipWidth, rowHeight, 1)
		surface.SetDrawColor(chip.color.r, chip.color.g, chip.color.b, 240 * alpha)
		surface.DrawRect(cursorX, rowY, math.max(Sc(2), 2), rowHeight)

		draw.SimpleText(text, chipFont, cursorX + chipWidth * 0.5,
			rowY + rowHeight * 0.5, ColorAlpha(chip.color, 245 * alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		cursorX = cursorX + chipWidth + Sc(6)
	end

	return rowY + rowHeight + Sc(18)
end

function PANEL:PaintInfo(width, height)
	local character = self:GetCharacter()

	if (!character) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha * util.EaseOut(self.swap or 1) *
		(1 - util.EaseInOut(self.loading or 0))
	local x = self.panelX
	local panelWidth = self.panelWidth
	local y = math.Round(height * 0.3)

	local band = Sc(32)
	local plateX = x - Sc(18)
	local plateY = y - Sc(18) - band
	local plateHeight = (self.infoBottom or (y + Sc(200))) - plateY + Sc(6)
	local faction = NETWORK.factions.Get(character:GetFaction())

	NETWORK.style.Plate(plateX, plateY, panelWidth + Sc(36), plateHeight, alpha, {
		band = band,
		title = L("charDossier"),
		right = "#" .. tostring(character.GetID and character:GetID() or self.index),
		accent = faction and faction.color or nil,
		stripe = true
	})

	if (self.bStrip) then
		y = self:PaintChips(x, y, panelWidth, character, alpha) or y
	end

	y = Field(x, y, L("infoName"), character:GetName(), panelWidth, alpha)
	y = Field(x, y, L("infoDescription"),
		character:GetDescription() != "" and character:GetDescription() or "—",
		panelWidth, alpha)
	y = Field(x, y, L("infoFaction"), character:GetFactionName(), panelWidth, alpha)

	surface.SetDrawColor(44, 70, 96, 200 * alpha)
	surface.DrawRect(x, y, panelWidth, 1)

	y = y + Sc(18)

	y = Stat(x, y, L("infoHealth"), character:GetHealth(), theme.danger, panelWidth, alpha)
	y = Stat(x, y, L("infoHunger"), character:GetHunger(), theme.warning, panelWidth, alpha)
	y = Stat(x, y, L("infoThirst"), character:GetThirst(), theme.combine, panelWidth, alpha)

	self.infoBottom = y
end

function PANEL:PaintCreate(width, height)
	if (self:GetCharacter()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha * util.EaseOut(self.swap or 1)
	local centerX = math.Round(width * 0.5)
	local centerY = math.Round(height * 0.45)

	draw.SimpleText(util.Upper(L("menuCreate")), "nwMenuGhost", centerX, centerY,
		ColorAlpha(theme.text, 46 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(L("menuCreateHint"), "nwMenuSub", centerX, centerY + Sc(60),
		ColorAlpha(theme.textDim, 205 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:PaintCounter(width, height)
	if (#self.pages < 2 or self.bStrip) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme

	draw.SimpleText(self.index .. " / " .. #self.pages, "nwMenuMeta",
		math.Round(width * 0.5), height - self.inset - Sc(12),
		ColorAlpha(theme.textFaint, 200 * self.alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:PaintLoading(width, height)
	local util = NETWORK.util
	local fraction = util.EaseInOut(self.loading or 0)

	if (fraction < 0.01) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local character = self:GetCharacter()

	local barWidth = math.min(Sc(340), math.Round(width * 0.3))
	local barX = math.Round((width - barWidth) * 0.5)
	local barY = height - self.inset - Sc(56)
	local thickness = math.max(Sc(2), 2)

	if (character) then
		util.DrawSimpleTextShadow(util.Upper(character:GetName()), "nwMenuItem",
			math.Round(width * 0.5), barY - Sc(30),
			ColorAlpha(theme.text, 235 * fraction), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	surface.SetDrawColor(255, 255, 255, 30 * fraction)
	surface.DrawRect(barX, barY, barWidth, thickness)

	local spread = math.Round(barWidth * 0.5)
	local travel = math.sin(CurTime() * 1.5) * 0.5 + 0.5
	local spotX = barX - math.Round(spread * 0.5) +
		math.Round((barWidth - spread * 0.5) * travel)
	local screenX, screenY = self:LocalToScreen(barX, barY)

	render.SetScissorRect(screenX, screenY, screenX + barWidth,
		screenY + thickness, true)

	util.DrawSpread(spotX, barY, spread, thickness,
		ColorAlpha(self.tint, 255 * fraction))

	render.SetScissorRect(0, 0, 0, 0, false)
end

function PANEL:PaintHint(width, height)
	if (!self:GetCharacter()) then
		return
	end

	local util = NETWORK.util
	local Sc = NETWORK.util.Scale
	local alpha = self.alpha * (1 - util.EaseInOut(self.loading or 0))

	if (alpha < 0.01) then
		return
	end

	draw.SimpleText(util.Upper(L("viewHint")), NETWORK.style.Font("label", 11, 700), width - self.inset,
		height - self.inset - Sc(12), ColorAlpha(NETWORK.style.Pda().muted, 210 * alpha),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

function PANEL:Paint(width, height)
	self:PaintBackdrop(width, height)
	self:PaintCreate(width, height)
end

function PANEL:PaintOver(width, height)
	self:PaintInfo(width, height)
	self:PaintCounter(width, height)
	self:PaintHint(width, height)
	self:PaintLoading(width, height)
end

vgui.Register("nwCharacterView", PANEL, "EditablePanel")
