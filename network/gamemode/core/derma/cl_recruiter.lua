local PANEL = {}

local ROW_HEIGHT = 50
local ROW_GAP = 4

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0
	self.rows = {}
	self.stage = "faction"
	self.spawnButtons = {}
	self.startTime = CurTime()

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.close = self:Add("DButton")
	self.close:SetText("")
	self.close:SetCursor("hand")
	self.close.hover = 0
	self.close.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover,
			panel:IsHovered() and 1 or 0, 10)
	end
	self.close.DoClick = function()
		NETWORK.sound.Click()
		self:Remove()
	end
	self.close.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local hover = NETWORK.util.EaseInOut(panel.hover)
		local color = Color(
			Lerp(hover, theme.textDim.r, theme.danger.r),
			Lerp(hover, theme.textDim.g, theme.danger.g),
			Lerp(hover, theme.textDim.b, theme.danger.b)
		)
		local inset = Sc(14) - Sc(2) * hover

		if (hover > 0.01) then
			draw.RoundedBox(math.max(Sc(6), 4), 0, 0, width, height,
				Color(255, 255, 255, 12 * hover * self.alpha))
		end

		NETWORK.util.DrawThickLine(inset, inset, width - inset, height - inset,
			math.max(Sc(2), 2), ColorAlpha(color, 255 * self.alpha))
		NETWORK.util.DrawThickLine(width - inset, inset, inset, height - inset,
			math.max(Sc(2), 2), ColorAlpha(color, 255 * self.alpha))
	end

	self.leave = self:Add("DButton")
	self.leave:SetText("")
	self.leave:SetCursor("hand")
	self.leave.hover = 0
	self.leave.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover,
			panel:IsHovered() and 1 or 0, 10)
	end
	self.leave.DoClick = function()
		NETWORK.sound.Click()

		net.Start("nwRecruitLeave")
		net.SendToServer()

		self:Remove()
	end
	self.leave.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local hover = NETWORK.util.EaseInOut(panel.hover)

		local radius = math.floor(height * 0.5)

		draw.RoundedBox(radius, 0, 0, width, height, Color(0, 0, 0, 150 * self.alpha))
		draw.RoundedBox(radius, 0, 0, width, height,
			ColorAlpha(theme.danger, (10 + 30 * hover) * self.alpha))
		NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, 1,
			ColorAlpha(theme.danger, (80 + 150 * hover) * self.alpha))

		draw.SimpleText(NETWORK.util.Upper(L("recruiterLeave")), "nwHudSmall",
			math.Round(width * 0.5), math.Round(height * 0.5),
			ColorAlpha(theme.danger, (215 + 40 * hover) * self.alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local function BuildAction(label, bPrimary, callback)
		local button = self:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button.label = label
		button.hover = 0
		button.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover,
				panel:IsHovered() and 1 or 0, 10)
		end
		button.OnCursorEntered = function()
			NETWORK.sound.Hover()
		end
		button.DoClick = function()
			NETWORK.sound.Click()

			callback()
		end
		button.SetLabel = function(panel, text)
			panel.label = text
		end
		button.Paint = function(panel, width, height)
			local theme = NETWORK.theme
			local hover = NETWORK.util.EaseInOut(panel.hover)
			local radius = math.floor(height * 0.5)
			local accent = bPrimary and self:GetAccent() or theme.textDim

			draw.RoundedBox(radius, 0, 0, width, height, Color(0, 0, 0, 160 * self.alpha))

			if (hover > 0.01) then
				draw.RoundedBox(radius, 0, 0, width, height,
					ColorAlpha(accent, 30 * hover * self.alpha))
			end

			NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius,
				bPrimary and math.max(Sc(2), 2) or 1,
				ColorAlpha(accent, ((bPrimary and 150 or 50) + 100 * hover) * self.alpha))

			draw.SimpleText(NETWORK.util.Upper(panel.label), "nwHudLabelSmall",
				math.Round(width * 0.5), math.Round(height * 0.5),
				ColorAlpha(bPrimary and theme.text or theme.textDim,
					(220 + 35 * hover) * self.alpha), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end

		return button
	end

	self.confirm = BuildAction(L("recruiterChoose"), true, function()
		self:Advance()
	end)

	self.back = BuildAction(L("recruiterBack"), false, function()
		self.stage = "faction"

		self:Rebuild()
	end)

	self.back:SetVisible(false)

	self.preview = self:Add("DModelPanel")
	self.preview:SetFOV(28)
	self.preview:SetAnimated(false)
	self.preview.LayoutEntity = function() end
end

function PANEL:DrawField(x, y, width, height, alpha, accent)
	local Sc = NETWORK.util.Scale
	local radius = math.max(Sc(10), 6)

	NETWORK.gui.DrawBlackGlass(self, x, y, width, height, alpha * 0.85, Sc(16))

	if (accent) then
		NETWORK.util.DrawVGradient(x + radius, y + 1, width - radius * 2, Sc(120),
			ColorAlpha(accent, 30 * alpha), ColorAlpha(accent, 0))

		local bar = math.max(Sc(3), 2)
		local barHeight = math.Round(height * 0.4)

		draw.RoundedBox(bar, x, y + math.Round((height - barHeight) * 0.5),
			bar, barHeight, ColorAlpha(accent, 230 * alpha))
	end
end

function PANEL:Setup(entity)
	self.entity = entity
	self.config = NETWORK.recruiter.Get(entity:GetConfigID())

	if (!self.config or #self.config.entries == 0) then
		self:Remove()

		return
	end

	self:SetSelected(1)
	self:Rebuild()
end

function PANEL:GetEntry()
	return self.config.entries[self.selected or 1]
end

function PANEL:GetReveal(delay, duration)
	return NETWORK.util.EaseOut(NETWORK.util.Stagger(self.startTime, delay,
		duration or 0.5))
end

function PANEL:SetSelected(index)
	self.selected = index
	self.spawn = 1

	self.cardTime = CurTime()

	local entry = self:GetEntry()

	if (!entry) then
		return
	end

	local faction = NETWORK.factions.Get(entry.faction)

	local client = LocalPlayer()
	local current = IsValid(client) and client:GetModel() or ""
	local model = NETWORK.recruiter.PickModel(entry, faction, current)

	if (!model or model == "") then
		model = current != "" and current or
			(faction and faction.models and faction.models[1])
	end

	if (model and IsValid(self.preview)) then
		self.preview:SetModel(model)

		local target = self.preview:GetEntity()

		if (IsValid(target)) then
			local mins, maxs = target:GetRenderBounds()
			local center = (mins + maxs) * 0.5

			center.z = maxs.z * 0.72

			self.preview:SetLookAt(center)
			self.preview:SetCamPos(center + Vector(52, 22, 6))

			target:SetAngles(Angle(0, 35, 0))
		end
	end
end

function PANEL:GetCardReveal()
	return NETWORK.util.EaseOut(math.Clamp(
		(CurTime() - (self.cardTime or 0)) / 0.35, 0, 1))
end

function PANEL:BuildRow(entry, index)
	local Sc = NETWORK.util.Scale
	local button = self:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button.hover = 0
	button.select = 0
	button.Think = function(panel)
		local util = NETWORK.util

		panel.hover = util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 10)
		panel.select = util.Approach(panel.select,
			self.selected == index and 1 or 0, 10)
	end
	button.OnCursorEntered = function()
		if (self.stage == "faction") then
			NETWORK.sound.Hover()
		end
	end
	button.DoClick = function()
		if (self.stage != "faction") then
			return
		end

		NETWORK.sound.Soft()
		self:SetSelected(index)
	end
	button.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local util = NETWORK.util
		local faction = NETWORK.factions.Get(entry.faction)
		local accent = (faction and faction.color) or theme.accent
		local hover = util.EaseInOut(panel.hover)
		local select = util.EaseInOut(panel.select)
		local lit = math.max(hover, select)
		local reveal = self:GetReveal(0.12 + index * 0.05, 0.45)
		local alpha = self.alpha * reveal

		if (alpha < 0.01) then
			return
		end

		local shift = math.Round(Sc(6) * select + Sc(3) * hover -
			(1 - reveal) * Sc(18))
		local radius = math.max(Sc(10), 6)
		local rowWidth = width - shift

		if (lit > 0.01) then
			util.DrawHGradient(shift, 0, rowWidth, height,
				ColorAlpha(accent, (10 + 34 * select + 8 * hover) * alpha), ColorAlpha(accent, 0))
		end

		local markerHeight = math.Round(height * (0.3 + 0.7 * select))

		surface.SetDrawColor(accent.r, accent.g, accent.b, (60 + 190 * lit) * alpha)
		surface.DrawRect(shift, math.Round((height - markerHeight) * 0.5), math.max(Sc(3), 2),
			markerHeight)

		surface.SetDrawColor(255, 255, 255, 10 * alpha)
		surface.DrawRect(shift + Sc(12), height - 1, rowWidth - Sc(12), 1)

		local circle = math.min(Sc(36), height - Sc(12))
		local circleX = shift + Sc(12) + math.floor(circle * 0.5)
		local middle = math.Round(height * 0.5)

		util.DrawCircle(circleX, middle, math.floor(circle * 0.5),
			ColorAlpha(accent, (20 + 40 * lit) * alpha))

		local textX = shift + Sc(12) + circle + Sc(12)
		local icon = faction and faction.icon and
			util.GetMaterial(faction.icon, "smooth")

		if (icon and !icon:IsError()) then
			local size = math.floor(circle * 0.6)

			surface.SetDrawColor(255, 255, 255, (170 + 85 * lit) * alpha)
			surface.SetMaterial(icon)
			surface.DrawTexturedRect(circleX - math.floor(size * 0.5),
				middle - math.floor(size * 0.5), size, size)
		end

		local title = entry.title != "" and entry.title or
			(faction and L(faction.name) or entry.faction)

		draw.SimpleText(util.Upper(title), "nwHudLabelSmall", textX,
			math.Round(height * 0.5) - ((entry.limit or 0) > 0 and Sc(8) or 0),
			ColorAlpha(select > 0.5 and theme.text or theme.textDim, 250 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if ((entry.limit or 0) > 0) then
			local taken = NETWORK.recruiter.CountFaction(entry.faction)
			local bFull = taken >= entry.limit

			draw.SimpleText(L("recruiterSlots") .. ": " .. taken .. "/" ..
				entry.limit, "nwHudSmall", textX,
				math.Round(height * 0.5) + Sc(10),
				ColorAlpha(bFull and theme.danger or theme.textFaint,
					235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	return button
end

function PANEL:BuildSpawnButton(spawn, index)
	local Sc = NETWORK.util.Scale
	local button = self:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button.hover = 0
	button.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover,
			panel:IsHovered() and 1 or 0, 10)
	end
	button.OnCursorEntered = function()
		NETWORK.sound.Hover()
	end
	button.DoClick = function()
		NETWORK.sound.Soft()

		self.spawn = index
	end
	button.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local util = NETWORK.util
		local bActive = self.spawn == index
		local hover = util.EaseInOut(panel.hover)
		local lit = math.max(hover, bActive and 1 or 0)
		local radius = math.max(Sc(10), 6)
		local accent = self:GetAccent()

		draw.RoundedBox(radius, 0, 0, width, height, Color(0, 0, 0, 150 * self.alpha))

		if (lit > 0.01) then
			draw.RoundedBox(radius, 0, 0, width, height,
				ColorAlpha(accent, (bActive and 40 or 18 * hover) * self.alpha))
		end

		util.DrawRoundedBorder(0, 0, width, height, radius, 1,
			ColorAlpha(lit > 0.01 and accent or Color(255, 255, 255),
			(lit > 0.01 and (70 + 160 * lit) or 22) * self.alpha))

		util.DrawCircle(Sc(10) + math.floor(Sc(8) * 0.5), math.Round(height * 0.5),
			math.floor(Sc(8) * 0.5), ColorAlpha(bActive and accent or theme.textFaint,
			(150 + 100 * lit) * self.alpha))

		draw.SimpleText(spawn.name != "" and spawn.name or
			(L("recruiterSpawn") .. " " .. index), "nwChatSmall", Sc(26),
			math.Round(height * 0.5),
			ColorAlpha(bActive and theme.text or theme.textDim, 245 * self.alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (bActive) then
			draw.SimpleText(util.Upper(L("recruiterDeploy")), "nwHudSmall",
				width - Sc(18), math.Round(height * 0.5),
				ColorAlpha(accent, 235 * self.alpha), TEXT_ALIGN_RIGHT,
				TEXT_ALIGN_CENTER)
		end
	end

	return button
end

function PANEL:Rebuild()
	for _, row in ipairs(self.rows) do
		if (IsValid(row)) then
			row:Remove()
		end
	end

	for _, row in ipairs(self.spawnButtons) do
		if (IsValid(row)) then
			row:Remove()
		end
	end

	self.rows = {}
	self.spawnButtons = {}

	if (self.stage == "faction") then
		for index, entry in ipairs(self.config.entries) do
			self.rows[index] = self:BuildRow(entry, index)
		end
	else
		for index, spawn in ipairs(self:GetEntry().spawns) do
			self.spawnButtons[index] = self:BuildSpawnButton(spawn, index)
		end
	end

	self.confirm:SetLabel(self.stage == "faction" and L("recruiterChoose") or
		L("recruiterDeploy"))
	self.back:SetVisible(self.stage != "faction")

	self:InvalidateLayout(true)
end

function PANEL:Advance()
	local entry = self:GetEntry()

	if (!entry) then
		return
	end

	if (self.stage == "faction") then
		if (NETWORK.recruiter.IsFull(entry)) then
			NETWORK.gui.Notify(L("recruiterFull"), NETWORK.theme.danger)

			return
		end

		if (!NETWORK.factions.CanUse(LocalPlayer(), entry.faction)) then
			NETWORK.gui.Notify(L("recruiterNoAccess"), NETWORK.theme.danger)

			return
		end

		if (#entry.spawns == 0) then
			NETWORK.recruiter.Pick(self.selected or 1, 0)
			self:Remove()

			return
		end

		self.stage = "spawn"
		self.cardTime = CurTime()

		self:Rebuild()

		return
	end

	NETWORK.recruiter.Pick(self.selected or 1, self.spawn or 1)
	self:Remove()
end

function PANEL:GetLayout()
	local Sc = NETWORK.util.Scale
	local width, height = self:GetSize()
	local margin = Sc(48)
	local gap = Sc(18)
	local top = Sc(104)
	local bottom = height - Sc(104)
	local listWidth = math.Clamp(math.Round(width * 0.24), Sc(280), Sc(400))
	local cardWidth = math.Clamp(math.Round(width * 0.36), Sc(420), Sc(720))
	local viewWidth = width - margin * 2 - listWidth - cardWidth - gap * 2

	return {
		margin = margin,
		gap = gap,
		top = top,
		bottom = bottom,
		listX = margin,
		listWidth = listWidth,
		viewX = margin + listWidth + gap,
		viewWidth = viewWidth,
		cardX = width - margin - cardWidth,
		cardWidth = cardWidth
	}
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale
	local layout = self:GetLayout()
	local step = Sc(ROW_HEIGHT + ROW_GAP)
	local listTop = layout.top + Sc(44)

	self.close:SetSize(Sc(44), Sc(44))
	self.close:SetPos(width - Sc(56), Sc(30))

	for index, row in ipairs(self.rows) do
		row:SetSize(layout.listWidth - Sc(24), Sc(ROW_HEIGHT))
		row:SetPos(layout.listX + Sc(12), listTop + (index - 1) * step)
	end

	for index, row in ipairs(self.spawnButtons) do
		row:SetSize(layout.cardWidth - Sc(48), Sc(44))
		row:SetPos(layout.cardX + Sc(24),
			layout.top + Sc(150) + (index - 1) * Sc(52))
	end

	self.preview:SetSize(math.max(layout.viewWidth - Sc(24), Sc(80)),
		layout.bottom - layout.top - Sc(24))
	self.preview:SetPos(layout.viewX + Sc(12), layout.top + Sc(12))

	self.confirm:SetSize(layout.cardWidth, Sc(52))
	self.confirm:SetPos(layout.cardX, height - Sc(88))

	self.back:SetSize(math.max(layout.viewWidth, Sc(120)), Sc(52))
	self.back:SetPos(layout.viewX, height - Sc(88))

	self.leave:SetSize(layout.listWidth, Sc(52))
	self.leave:SetPos(layout.listX, height - Sc(88))
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 6)
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:PaintBackdrop(width, height)
	local theme = NETWORK.theme
	local util = NETWORK.util

	util.DrawBlur(self, 6 * self.alpha)

	surface.SetDrawColor(0, 0, 0, 130 * self.alpha)
	surface.DrawRect(0, 0, width, height)

	local accent = self:GetAccent()

	surface.SetDrawColor(accent.r, accent.g, accent.b, 220 * self.alpha)
	surface.DrawRect(0, 0, width, math.max(NETWORK.util.Scale(2), 2))

	util.DrawVGradient(0, 0, width, NETWORK.util.Scale(160),
		ColorAlpha(accent, 26 * self.alpha), ColorAlpha(accent, 0))
end

function PANEL:GetAccent()
	local entry = self:GetEntry()
	local faction = entry and NETWORK.factions.Get(entry.faction)
	local target = (faction and faction.color) or NETWORK.theme.combine

	self.accentColor = self.accentColor or Color(target.r, target.g, target.b)

	local speed = math.Clamp(FrameTime() * 6, 0, 1)

	self.accentColor.r = Lerp(speed, self.accentColor.r, target.r)
	self.accentColor.g = Lerp(speed, self.accentColor.g, target.g)
	self.accentColor.b = Lerp(speed, self.accentColor.b, target.b)

	return Color(self.accentColor.r, self.accentColor.g, self.accentColor.b)
end

function PANEL:PaintHeader(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local layout = self:GetLayout()
	local reveal = self:GetReveal(0, 0.45)
	local alpha = self.alpha * reveal

	if (alpha < 0.01) then
		return
	end

	local y = Sc(44) + math.Round((1 - reveal) * -Sc(10))

	local accent = self:GetAccent()

	draw.SimpleText(util.Upper(L("recruiterTitle")), "nwInvKey", layout.margin, y - Sc(14),
		ColorAlpha(accent, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(self.config.name != "" and self.config.name or L("recruiterTitle"),
		"nwInvTitle", layout.margin, y + Sc(14),
		ColorAlpha(theme.text, 252 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local lineWidth = math.Round((width - layout.margin * 2) * reveal)

	surface.SetDrawColor(255, 255, 255, 16 * alpha)
	surface.DrawRect(layout.margin, Sc(90), lineWidth, 1)
end

function PANEL:PaintCard(layout, entry)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local faction = NETWORK.factions.Get(entry.faction)
	local accent = (faction and faction.color) or theme.accent
	local reveal = self:GetReveal(0.2, 0.5)
	local card = self:GetCardReveal()
	local alpha = self.alpha * reveal
	local x = layout.cardX
	local y = layout.top

	if (alpha < 0.01) then
		return
	end

	self:DrawField(x, y, layout.cardWidth, layout.bottom - y, alpha, accent)

	local textX = x + Sc(28)
	local textWidth = layout.cardWidth - Sc(56)
	local slide = math.Round((1 - card) * Sc(12))
	local cardAlpha = alpha * card

	local icon = faction and faction.icon and
		util.GetMaterial(faction.icon, "smooth")

	if (icon and !icon:IsError()) then
		local size = Sc(40)

		surface.SetDrawColor(255, 255, 255, 150 * cardAlpha)
		surface.SetMaterial(icon)
		surface.DrawTexturedRect(x + layout.cardWidth - size - Sc(28),
			y + Sc(28), size, size)
	end

	local cursor = y + Sc(36)

	util.DrawTextSpaced(util.Upper(entry.subtitle != "" and entry.subtitle or
		(faction and L(faction.name) or entry.faction)), "nwHudSmall",
		textX + slide, cursor, ColorAlpha(accent, 245 * cardAlpha), Sc(4),
		TEXT_ALIGN_CENTER)

	cursor = cursor + Sc(34)

	draw.SimpleText(util.Upper(entry.title != "" and entry.title or
		entry.faction), "nwTitle", textX + slide, cursor,
		ColorAlpha(theme.text, 252 * cardAlpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	cursor = cursor + Sc(30)

	local classTable = entry.class and entry.class != "" and
		NETWORK.classes and NETWORK.classes.Get(entry.class)

	if (classTable) then
		draw.SimpleText(util.Upper(L("recruiterClassLine")) .. ": " ..
			L(classTable.name or classTable.id), "nwHudSmall", textX + slide,
			cursor, ColorAlpha(theme.textDim, 240 * cardAlpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(24)
	end

	if (self.stage == "spawn") then
		surface.SetDrawColor(255, 255, 255, 12 * cardAlpha)
		surface.DrawRect(textX, cursor + Sc(12), textWidth, 1)

		util.DrawTextSpaced(util.Upper(L("recruiterPickSpawn")), "nwHudSmall",
			textX, cursor + Sc(34),
			ColorAlpha(theme.accentSoft, 245 * cardAlpha), Sc(4),
			TEXT_ALIGN_CENTER)

		return
	end

	cursor = cursor + Sc(14)

	for _, line in ipairs(util.WrapText(entry.description, "nwChatSmall",
		textWidth, 8)) do
		draw.SimpleText(line, "nwChatSmall", textX, cursor,
			ColorAlpha(theme.textDim, 238 * cardAlpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(20)
	end

	if (#entry.features > 0) then
		cursor = cursor + Sc(24)

		util.DrawTextSpaced(util.Upper(L("recruiterFeatures")), "nwHudSmall",
			textX, cursor, ColorAlpha(theme.textFaint, 240 * cardAlpha), Sc(4),
			TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(26)

		for _, line in ipairs(entry.features) do

			util.DrawCircle(textX + Sc(4), cursor, Sc(4), ColorAlpha(accent, 60 * cardAlpha))
			util.DrawCircle(textX + Sc(4), cursor, Sc(2), ColorAlpha(accent, 240 * cardAlpha))

			draw.SimpleText(line, "nwChatSmall", textX + Sc(16), cursor,
				ColorAlpha(theme.text, 238 * cardAlpha), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			cursor = cursor + Sc(22)
		end
	end

	if ((entry.limit or 0) > 0) then
		local taken = NETWORK.recruiter.CountFaction(entry.faction)
		local bFull = taken >= entry.limit
		local barY = layout.bottom - Sc(52)

		surface.SetDrawColor(255, 255, 255, 12 * cardAlpha)
		surface.DrawRect(textX, barY - Sc(16), textWidth, 1)

		draw.SimpleText(util.Upper(L("recruiterSlots")), "nwHudSmall", textX,
			barY, ColorAlpha(theme.textFaint, 240 * cardAlpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		draw.SimpleText(taken .. " / " .. entry.limit, "nwField",
			textX + textWidth, barY,
			ColorAlpha(bFull and theme.danger or theme.positive,
				248 * cardAlpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		local barColor = bFull and theme.danger or theme.positive
		local barHeight = math.max(Sc(3), 2)
		local fill = math.Round(textWidth *
			math.Clamp(taken / entry.limit, 0, 1))

		barHeight = math.max(Sc(5), 4)

		draw.RoundedBox(math.floor(barHeight * 0.5), textX, barY + Sc(16), textWidth,
			barHeight, Color(255, 255, 255, 18 * cardAlpha))

		if (fill >= barHeight) then
			draw.RoundedBox(math.floor(barHeight * 0.5), textX, barY + Sc(16), fill,
				barHeight, ColorAlpha(barColor, 235 * cardAlpha))
		end
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local layout = self:GetLayout()
	local entry = self:GetEntry()

	self:PaintBackdrop(width, height)
	self:PaintHeader(width, height)

	local listReveal = self:GetReveal(0.1, 0.45)
	local viewReveal = self:GetReveal(0.16, 0.45)

	if (listReveal > 0.01) then
		util.DrawTextSpaced(util.Upper(L("recruiterChoose")), "nwHudSmall",
			layout.listX + Sc(12), layout.top + Sc(26),
			ColorAlpha(theme.textFaint, 235 * self.alpha * listReveal), Sc(4),
			TEXT_ALIGN_CENTER)

		surface.SetDrawColor(255, 255, 255, 18 * self.alpha * listReveal)
		surface.DrawRect(layout.listX + Sc(12), layout.top + Sc(40),
			math.Round((layout.listWidth - Sc(24)) * listReveal), 1)
	end

	if (viewReveal > 0.01 and layout.viewWidth > Sc(120) and entry) then
		local accent = self:GetAccent()
		local centerX = layout.viewX + math.Round(layout.viewWidth * 0.5)
		local floorY = layout.bottom - Sc(70)
		local ringRadius = math.Round(math.min(layout.viewWidth * 0.32, Sc(150)))
		local card = self:GetCardReveal()
		local ringAlpha = self.alpha * viewReveal

		for i = 0, 2 do
			util.DrawCircleOutline(centerX, floorY, ringRadius - i * Sc(10),
				ColorAlpha(accent, (70 - i * 20) * ringAlpha * (0.6 + 0.4 * card)),
				math.max(Sc(1), 1))
		end

		local sweep = (CurTime() * 40) % 360

		util.DrawArc(centerX, floorY, ringRadius, math.max(Sc(2), 2), 0.18,
			ColorAlpha(accent, 220 * ringAlpha), 48, sweep)

		local faction = NETWORK.factions.Get(entry.faction)
		local mark = util.Upper(entry.title != "" and entry.title or
			(faction and L(faction.name) or entry.faction))

		util.DrawTextSpaced(mark, "nwSchema",
			centerX - math.Round(util.TextSpacedSize(mark, "nwSchema", Sc(10)) * 0.5),
			layout.top + Sc(60), ColorAlpha(accent, 22 * ringAlpha * card), Sc(10),
			TEXT_ALIGN_CENTER)
	end

	if (entry) then
		self:PaintCard(layout, entry)
	end
end

vgui.Register("nwRecruiter", PANEL, "EditablePanel")

function NETWORK.gui.OpenRecruiter(entity)
	if (IsValid(NETWORK.gui.recruiter)) then
		NETWORK.gui.recruiter:Remove()
	end

	local panel = vgui.Create("nwRecruiter")

	panel:Setup(entity)

	NETWORK.gui.recruiter = panel

	return panel
end
