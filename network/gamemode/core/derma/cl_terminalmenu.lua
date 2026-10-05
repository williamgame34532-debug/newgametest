local CIVIC = setmetatable({
	accent = Color(132, 214, 164),
	accentDeep = Color(46, 96, 70),
	accentSoft = Color(200, 240, 214),
	hover = Color(168, 232, 190),
	text = Color(228, 242, 232),
	textDim = Color(150, 178, 160),
	textFaint = Color(96, 120, 104),
	value = Color(196, 232, 208),
	line = Color(62, 104, 82),
	plate = Color(8, 17, 13),
	plateDeep = Color(5, 11, 8),
	plateBright = Color(16, 30, 23)
}, {__index = function(_, key)
	return NETWORK.theme[key]
end})

NETWORK.terminal.palette = CIVIC

local skyline

local function GetSkyline()
	if (skyline) then
		return skyline
	end

	skyline = {}

	local seed = 7
	local cursor = 0

	local function Random()
		seed = (seed * 1103515245 + 12345) % 2147483648

		return seed / 2147483648
	end

	while (cursor < 1) do
		local width = 0.03 + Random() * 0.05

		skyline[#skyline + 1] = {
			x = cursor,
			width = width,
			height = 0.08 + Random() * 0.16,
			seed = math.floor(Random() * 1000)
		}

		cursor = cursor + width + Random() * 0.008
	end

	return skyline
end

function NETWORK.terminal.DrawBackdrop(panel, x, y, width, height, alpha, inset)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local accent = CIVIC.accent
	local time = RealTime()

	inset = inset or 0

	local screenX, screenY = panel:LocalToScreen(x, y)

	render.SetScissorRect(screenX, screenY, screenX + width, screenY + height, true)

	for index = 1, 3 do
		local phase = index * 2.3
		local blobX = x + width * (0.5 + math.sin(time * 0.05 + phase) * 0.4)
		local blobY = y + height * (0.45 + math.cos(time * 0.04 + phase) * 0.3)
		local size = math.min(width, height) * 0.9

		util.DrawSoftLight(math.Round(blobX), math.Round(blobY), size, size, accent,
			20 * alpha)
	end

	local bFull = !NETWORK.cmbterm.FullEffects or NETWORK.cmbterm.FullEffects()

	for index = 1, bFull and 22 or 10 do
		local rise = (index * 0.37 + time * (0.015 + index * 0.0012)) % 1
		local bubbleX = x + ((index * 0.618) % 1) * width + math.sin(time * 0.5 + index) * Sc(10)
		local bubbleY = y + height - rise * height
		local fade = math.sin(rise * math.pi)

		util.DrawCircle(bubbleX, bubbleY, math.max(Sc(2 + index % 3), 2),
			ColorAlpha(accent, 50 * fade * alpha))
	end

	local baseY = y + height
	local left = x + inset
	local span = width - inset * 2
	local citadelX = left + span * 0.72
	local citadelWidth = span * 0.035
	local citadelHeight = height * 0.42

	draw.NoTexture()
	surface.SetDrawColor(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 230 * alpha)
	surface.DrawPoly({
		{x = citadelX - citadelWidth, y = baseY},
		{x = citadelX - citadelWidth * 0.35, y = baseY - citadelHeight},
		{x = citadelX + citadelWidth * 0.2, y = baseY - citadelHeight * 1.04},
		{x = citadelX + citadelWidth, y = baseY}
	})

	util.DrawSoftLight(math.Round(citadelX - citadelWidth * 0.1),
		math.Round(baseY - citadelHeight), Sc(60), Sc(60), accent,
		(40 + 30 * math.abs(math.sin(time * 1.3))) * alpha)

	for _, house in ipairs(GetSkyline()) do
		local houseX = left + house.x * span
		local houseWidth = house.width * span
		local houseHeight = house.height * height

		surface.SetDrawColor(accent.r * 0.12, accent.g * 0.14, accent.b * 0.13, 240 * alpha)
		surface.DrawRect(houseX, baseY - houseHeight, houseWidth, houseHeight)

		local window = math.max(Sc(3), 2)
		local step = Sc(10)

		for column = 0, math.floor((houseWidth - step) / step) do
			for row = 0, math.floor((houseHeight - step * 1.5) / step) do
				local id = house.seed + column * 31 + row * 17
				local lit = math.floor(time * 0.25 + id * 0.37) % 5 == 0

				if (lit) then
					surface.SetDrawColor(accent.r, accent.g, accent.b, 120 * alpha)
					surface.DrawRect(houseX + Sc(5) + column * step,
						baseY - houseHeight + Sc(8) + row * step, window, window)
				end
			end
		end
	end

	render.SetScissorRect(0, 0, 0, 0, false)
end

local PANEL = {}

local steps = {10, 50, 100, 500}

local glyphs = {
	info = "person",
	housing = "grid",
	call = "radio",
	bank = "coin",
	business = "stack",
	board = "list",
	mail = "stack",
	exit = "back"
}

local function Sounds()
	return NETWORK.terminal.sounds
end

function PANEL:Init()
	NETWORK.gui.terminal = self

	self.open = 0
	self.alpha = 0
	self.page = "root"
	self.pageItems = {}
	self.navItems = {}
	self.data = {}

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.close = self:Add("DButton")
	self.close:SetText("")
	self.close:SetCursor("hand")
	self.close.DoClick = function()
		self:RequestClose()
	end
	self.close.Paint = function(panel, width, height)
		local Sc = NETWORK.util.Scale
		local theme = CIVIC
		local colour = panel:IsHovered() and theme.danger or theme.accent
		local inset = Sc(12)
		local thickness = math.max(Sc(2), 2)

		NETWORK.util.DrawThickLine(inset, inset, width - inset, height - inset,
			thickness, colour)
		NETWORK.util.DrawThickLine(width - inset, inset, inset, height - inset,
			thickness, colour)
	end

	self.fullscreenButton = self:Add("DButton")
	self.fullscreenButton:SetText("")
	self.fullscreenButton:SetCursor("hand")
	self.fullscreenButton.DoClick = function()
		self:SetFullscreen(!self:IsFullscreen())
	end
	self.fullscreenButton.Paint = function(panel, width, height)
		local Sc = NETWORK.util.Scale
		local theme = CIVIC
		local hover = panel:IsHovered() and 1 or 0
		local color = ColorAlpha(hover > 0 and theme.text or theme.accent, 235)
		local line = math.max(Sc(2), 2)
		local arm = Sc(7)
		local inset = Sc(11)
		local bIn = self:IsFullscreen()

		draw.RoundedBox(math.floor(height * 0.5), 0, 0, width, height,
			ColorAlpha(theme.accent, 16 + 26 * hover))

		surface.SetDrawColor(color.r, color.g, color.b, color.a)

		for _, corner in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
			local sx, sy = corner[1], corner[2]
			local px = sx < 0 and inset or width - inset
			local py = sy < 0 and inset or height - inset

			if (bIn) then
				px = px - sx * arm
				py = py - sy * arm
			end

			local dirX = bIn and sx or -sx
			local dirY = bIn and sy or -sy

			surface.DrawRect(dirX > 0 and px or px - arm, py - math.floor(line * 0.5),
				arm, line)
			surface.DrawRect(px - math.floor(line * 0.5), dirY > 0 and py or py - arm,
				line, arm)
		end
	end

	self:BuildNav()
	self:OpenPage("info")
end

function PANEL:Setup(entity, data)
	self.entity = entity
	self.data = data or {}

	self:OpenPage(self.page == "root" and "info" or self.page)
end

function PANEL:SetData(data)
	self.data = data or {}

	self:OpenPage(self.page)
end

function PANEL:OnRemove()
	if (NETWORK.gui.terminal == self) then
		NETWORK.gui.terminal = nil
	end
end

function PANEL:RequestClose()
	surface.PlaySound(Sounds().denied)

	net.Start("nwTerminalClose")
	net.SendToServer()
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_F11) then
		return self:SetFullscreen(!self:IsFullscreen())
	end

	if (key == KEY_ESCAPE) then
		self:RequestClose()
	end
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_RIGHT) then
		self:RequestClose()
	end
end

NETWORK.terminal.fullscreen = cookie.GetNumber("nwCivicFullscreenV2", 1) == 1

function PANEL:IsFullscreen()
	return NETWORK.terminal.fullscreen == true
end

function PANEL:SetFullscreen(bValue)
	NETWORK.terminal.fullscreen = bValue == true

	cookie.Set("nwCivicFullscreenV2", bValue and "1" or "0")

	surface.PlaySound(Sounds().select)

	self:InvalidateLayout(true)
	self:BuildNav()
	self:OpenPage(self.page)
end

function PANEL:GetFrameWidth()
	if (self:IsFullscreen()) then
		return ScrW()
	end

	return math.Round(math.min(ScrW() * 0.82, NETWORK.util.Scale(1340)))
end

function PANEL:GetFrameHeight()
	if (self:IsFullscreen()) then
		return ScrH()
	end

	return math.Round(math.min(ScrH() * 0.84, NETWORK.util.Scale(820)))
end

function PANEL:GetFrameX()
	return math.Round((ScrW() - self:GetFrameWidth()) * 0.5)
end

function PANEL:GetFrameY()
	return math.Round((ScrH() - self:GetFrameHeight()) * 0.5)
end

function PANEL:GetBarHeight()
	return NETWORK.util.Scale(62)
end

function PANEL:GetNavWidth()
	return NETWORK.util.Scale(self:IsFullscreen() and 340 or 310)
end

function PANEL:GetContentX()
	return self:GetFrameX() + self:GetNavWidth()
end

function PANEL:GetContentWidth()
	return self:GetFrameWidth() - self:GetNavWidth()
end

function PANEL:GetPageTop()
	return self:GetFrameY() + self:GetBarHeight() + NETWORK.util.Scale(26)
end

function PANEL:GetPageBottom()
	return self:GetFrameY() + self:GetFrameHeight() - NETWORK.util.Scale(30)
end

function PANEL:BuildNav()
	for _, item in ipairs(self.navItems) do
		if (IsValid(item)) then
			item:Remove()
		end
	end

	self.navItems = {}

	local Sc = NETWORK.util.Scale
	local theme = CIVIC
	local util = NETWORK.util
	local x = self:GetFrameX() + Sc(18)
	local width = self:GetNavWidth() - Sc(36)
	local height = Sc(60)
	local y = self:GetFrameY() + self:GetBarHeight() + Sc(24)
	local index = 0

	local function Row(id, label, yPos, bDanger, description)
		index = index + 1

		local button = self:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button:SetPos(x, yPos)
		button:SetSize(width, height)
		button.born = CurTime() + index * 0.04
		button.DoClick = function()
			if (id == "exit") then
				self:RequestClose()

				return
			end

			surface.PlaySound(Sounds().select)
			self:OpenPage(id)
		end
		button.OnCursorEntered = function()
			surface.PlaySound(Sounds().hover)
		end
		button.Paint = function(panel, rowWidth, rowHeight)
			local reveal = math.Clamp((CurTime() - panel.born) / 0.3, 0, 1)

			if (reveal <= 0) then
				return
			end

			local hover = panel:IsHovered() and 1 or 0
			local bActive = self.page == id
			local base = bDanger and theme.danger or theme.accent
			local strength = (bActive and 1 or hover)

			local pill = Sc(14)

			draw.RoundedBox(pill, 0, 0, rowWidth, rowHeight,
				ColorAlpha(base, (bActive and 46 or 10 + 22 * hover) * reveal))

			if (bActive) then
				NETWORK.util.DrawRoundedBorder(0, 0, rowWidth, rowHeight, pill,
					math.max(Sc(2), 2), ColorAlpha(base, 200 * reveal))
			end

			local glyphSize = Sc(20)
			local circle = Sc(40)
			local circleX = Sc(10) + math.floor(circle * 0.5)
			local middle = math.Round(rowHeight * 0.5)

			NETWORK.util.DrawCircle(circleX, middle, math.floor(circle * 0.5),
				ColorAlpha(base, (22 + 30 * strength) * reveal))

			NETWORK.gui.DrawGlyph((self.navGlyphs or glyphs)[id] or "dot", circleX - math.floor(glyphSize * 0.5),
				middle - math.floor(glyphSize * 0.5), glyphSize,
				ColorAlpha(base, (190 + 65 * strength) * reveal))

			local textX = Sc(10) + circle + Sc(12)

			if (description) then
				draw.SimpleText(util.Upper(label), "nwTermNav", textX, middle - Sc(9),
					ColorAlpha(strength > 0 and theme.text or theme.value, 245 * reveal),
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				draw.SimpleText(util.TruncateWidth(description, "nwHudSmall",
					rowWidth - textX - Sc(10)), "nwHudSmall", textX, middle + Sc(11),
					ColorAlpha(theme.textDim, 230 * reveal), TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)
			else
				draw.SimpleText(util.Upper(label), "nwTermNav", textX, middle,
					ColorAlpha(strength > 0 and theme.text or base, 245 * reveal),
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end

		self.navItems[#self.navItems + 1] = button

		return button
	end

	for _, entry in ipairs(self:GetNavPages()) do
		if (entry.id == "exit") then
			continue
		end

		Row(entry.id, L(entry.label), y, false, L(entry.label .. "Desc"))

		y = y + height + Sc(8)
	end

	Row("exit", L("termExit"), self:GetPageBottom() - Sc(48), true):SetTall(Sc(48))
end

function PANEL:GetNavPages()
	return NETWORK.terminal.pages.root
end

function PANEL:ClearPage()
	for _, item in ipairs(self.pageItems) do
		if (IsValid(item)) then
			item:Remove()
		end
	end

	self.pageItems = {}
end

function PANEL:OpenPage(id)
	self.page = id or "info"

	self:ClearPage()

	local builder = self["Build" .. string.upper(string.sub(self.page, 1, 1)) ..
		string.sub(self.page, 2)]

	if (builder) then
		builder(self)
	end
end

function PANEL:AddButton(label, x, y, width, height, callback, bDanger, bActive)
	local Sc = NETWORK.util.Scale
	local theme = CIVIC
	local button = self:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button:SetPos(x, y)
	button:SetSize(width, height)
	button.DoClick = function()
		surface.PlaySound(Sounds().select)

		callback()
	end
	button.OnCursorEntered = function()
		surface.PlaySound(Sounds().hover)
	end
	button.Paint = function(panel, buttonWidth, buttonHeight)
		local hover = panel:IsHovered() and 1 or 0
		local base = bDanger and theme.danger or theme.accent
		local strength = math.max(hover, panel.bActive and 1 or 0)

		local pill = math.min(Sc(12), math.floor(buttonHeight * 0.5))

		draw.RoundedBox(pill, 0, 0, buttonWidth, buttonHeight,
			ColorAlpha(base, 14 + 30 * strength))

		NETWORK.util.DrawRoundedBorder(0, 0, buttonWidth, buttonHeight, pill,
			strength > 0 and math.max(Sc(2), 2) or 1,
			ColorAlpha(base, 110 + 130 * strength))

		draw.SimpleText(NETWORK.util.Upper(label), "nwTermNav",
			math.Round(buttonWidth * 0.5), math.Round(buttonHeight * 0.5),
			ColorAlpha(strength > 0 and theme.text or base, 250),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	button.bActive = bActive or false

	self.pageItems[#self.pageItems + 1] = button

	return button
end

function PANEL:AddEntry(x, y, width, height, bMultiline)
	local theme = CIVIC
	local entry = self:Add("DTextEntry")

	entry:SetPos(x, y)
	entry:SetSize(width, height)
	entry:SetFont("nwChat")
	entry:SetDrawLanguageID(false)
	entry:SetAllowNonAsciiCharacters(true)
	entry:SetMultiline(bMultiline or false)
	entry:SetPaintBackground(false)
	entry:SetTextColor(theme.text)
	entry:SetCursorColor(theme.accent)
	entry:SetHighlightColor(theme.accentDeep)
	entry.Paint = function(this, entryWidth, entryHeight)
		local pill = NETWORK.util.Scale(10)

		draw.RoundedBox(pill, 0, 0, entryWidth, entryHeight,
			ColorAlpha(theme.plateBright, 240))
		NETWORK.util.DrawRoundedBorder(0, 0, entryWidth, entryHeight, pill, 1,
			ColorAlpha(this:HasFocus() and theme.accent or theme.line, 180))

		this:DrawTextEntryText(theme.text, theme.accentDeep, theme.accent)
	end

	self.pageItems[#self.pageItems + 1] = entry

	return entry
end

function PANEL:BuildInfo()
end

function PANEL:BuildHousing()
	local Sc = NETWORK.util.Scale
	local data = self.data
	local bHome = data.housing and data.housing != ""
	local width = math.min(Sc(340), self:GetContentWidth() - Sc(68))
	local x = self:GetContentX() + math.Round((self:GetContentWidth() - width) * 0.5)
	local y = self:GetPageTop() + Sc(190)

	local apartment = data.apartment or {}

	if (bHome and !apartment.owned) then
		self:AddButton(L("termHousingDrop"), x, y, width, Sc(46), function()
			NETWORK.terminal.Send("housingRelease", {})
		end, true)
	elseif (!bHome) then
		self:AddButton(L("termHousingTake"), x, y, width, Sc(46), function()
			NETWORK.terminal.Send("housing", {})
		end)
	end

	-- Purchasable apartment (sv_apartments.lua).
	if (!apartment.price) then
		return
	end

	y = y + Sc(150)

	if (apartment.owned) then
		if ((apartment.owned.debt or 0) > 0) then
			self:AddButton("Оплатить налоговый долг", x, y, width, Sc(42), function()
				NETWORK.terminal.Send("aptPay", {})
			end)
		end
	elseif (apartment.request) then
		self:AddButton("Отозвать заявку (возврат)", x, y, width, Sc(42), function()
			NETWORK.terminal.Send("aptCancel", {})
		end, true)
	else
		local entry = self:AddEntry(x, y, width, Sc(40))

		entry:SetPlaceholderText("Где хотите жить: дом, этаж, номер")
		entry:SetPlaceholderColor(CIVIC.textDim)

		self:AddButton("Купить квартиру — " .. apartment.price .. " т.", x, y + Sc(50), width, Sc(42), function()
			NETWORK.terminal.Send("aptBuy", {wish = entry:GetValue()})
		end)
	end
end

function PANEL:BuildCall()
	local Sc = NETWORK.util.Scale
	local width = math.min(Sc(420), self:GetContentWidth() - Sc(68))
	local x = self:GetContentX() + math.Round((self:GetContentWidth() - width) * 0.5)
	local y = self:GetPageTop() + Sc(84)

	for index, key in ipairs(NETWORK.terminal.reasons or {}) do
		self:AddButton(L(key), x, y, width, Sc(40), function()
			NETWORK.terminal.Send("call", {reason = index})
		end)

		y = y + Sc(48)
	end
end

function PANEL:BuildBank()
	local Sc = NETWORK.util.Scale
	local contentWidth = self:GetContentWidth()
	local chipWidth = Sc(86)
	local gap = Sc(10)
	local total = #steps * (chipWidth + gap) - gap
	local x = self:GetContentX() + math.Round((contentWidth - total) * 0.5)
	local y = self:GetPageTop() + Sc(206)

	for _, step in ipairs(steps) do
		local button = self:AddButton(tostring(step), x, y, chipWidth, Sc(38),
			function()
				NETWORK.terminal.amount = step

				for _, item in ipairs(self.pageItems) do
					if (IsValid(item) and item.amountStep) then
						item.bActive = item.amountStep == step
					end
				end
			end, false, NETWORK.terminal.amount == step)

		button.amountStep = step

		x = x + chipWidth + gap
	end

	local actionWidth = Sc(200)
	local middle = self:GetContentX() + math.Round(contentWidth * 0.5)

	y = y + Sc(64)

	self:AddButton(L("termDeposit"), middle - actionWidth - Sc(8), y,
		actionWidth, Sc(46), function()
			NETWORK.terminal.Send("deposit", {amount = NETWORK.terminal.amount})
		end)

	self:AddButton(L("termWithdraw"), middle + Sc(8), y, actionWidth, Sc(46),
		function()
			NETWORK.terminal.Send("withdraw", {amount = NETWORK.terminal.amount})
		end)
end

function PANEL:BuildBusiness()
	local Sc = NETWORK.util.Scale
	local x = self:GetContentX() + Sc(34)
	local width = self:GetContentWidth() - Sc(68)
	local y = self:GetPageTop() + self:GetBusinessStatusHeight() + Sc(58)

	self.businessWhat = self:AddEntry(x, y, width, Sc(34))

	y = y + Sc(34) + Sc(40)

	self.businessWhy = self:AddEntry(x, y, width, Sc(96), true)

	y = y + Sc(96) + Sc(18)

	self:AddButton(L("termBusinessSend"), x, y, math.min(Sc(260), width),
		Sc(42), function()
			NETWORK.terminal.Send("businessApply", {
				what = IsValid(self.businessWhat) and self.businessWhat:GetValue() or "",
				why = IsValid(self.businessWhy) and self.businessWhy:GetValue() or ""
			})
		end)
end

function PANEL:GetBusinessStatusHeight()
	local Sc = NETWORK.util.Scale

	return self.data.business and Sc(96) or Sc(34)
end

function PANEL:Think()
	local util = NETWORK.util

	self.alpha = util.Approach(self.alpha, 1, 4)
	self.open = util.Approach(self.open, 1, 2.2)

	if (!IsValid(self.entity)) then
		self:Remove()

		return
	end

	if (!vgui.CursorVisible()) then
		self:MakePopup()
	end
end

function PANEL:PerformLayout()
	local Sc = NETWORK.util.Scale

	if (IsValid(self.close)) then
		self.close:SetSize(Sc(44), Sc(44))
		self.close:SetPos(self:GetFrameX() + self:GetFrameWidth() - Sc(54),
			self:GetFrameY() + Sc(9))
	end

	if (IsValid(self.fullscreenButton)) then
		self.fullscreenButton:SetSize(Sc(38), Sc(38))
		self.fullscreenButton:SetPos(self:GetFrameX() + self:GetFrameWidth() - Sc(100),
			self:GetFrameY() + math.Round((self:GetBarHeight() - Sc(38)) * 0.5))
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = CIVIC
	local alpha = self.alpha

	if (self:IsFullscreen()) then
		surface.SetDrawColor(2, 5, 11, 228 * alpha)
		surface.DrawRect(0, 0, width, height)
	else
		surface.SetDrawColor(CIVIC.plateDeep.r, CIVIC.plateDeep.g, CIVIC.plateDeep.b,
			245 * alpha)
		surface.DrawRect(0, 0, width, height)

		NETWORK.terminal.DrawBackdrop(self, 0, 0, width, height, alpha * 0.6)

		surface.SetDrawColor(0, 0, 0, 110 * alpha)
		surface.DrawRect(0, 0, width, height)
	end

	local eased = NETWORK.util.EaseOut(self.open)
	local frameWidth = math.Round(self:GetFrameWidth() * (0.9 + 0.1 * eased))
	local frameHeight = math.Round(self:GetFrameHeight() * math.max(eased, 0.01))
	local x = math.Round(ScrW() * 0.5 - frameWidth * 0.5)
	local y = math.Round(ScrH() * 0.5 - frameHeight * 0.5)

	if (frameHeight < 4) then
		return
	end

	local radius = math.min(self:IsFullscreen() and 0 or Sc(18), math.floor(frameHeight * 0.5))

	draw.RoundedBox(radius, x + Sc(4), y + Sc(8), frameWidth, frameHeight,
		Color(0, 0, 0, 110 * alpha))
	draw.RoundedBox(radius, x, y, frameWidth, frameHeight,
		ColorAlpha(theme.plate, 248 * alpha))

	NETWORK.util.DrawVGradient(x + radius, y + 1, frameWidth - radius * 2,
		math.Round(frameHeight * 0.45), ColorAlpha(theme.accent, 18 * alpha),
		ColorAlpha(theme.accent, 0))

	NETWORK.terminal.DrawBackdrop(self, x, y, frameWidth, frameHeight, alpha, radius)

	NETWORK.gui.DrawHoloScreen(self, x, y, frameWidth, frameHeight, alpha * 0.85, theme.accent)

	local step = Sc(22)

	surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 10 * alpha)

	local dots = NETWORK.util.GetTexture("framework/pattern/dots.png", "noclamp smooth mips")

	if (dots) then
		NETWORK.util.DrawTiled(dots, x + radius, y + radius, frameWidth - radius * 2 + 2,
			frameHeight - radius * 2 + 2, step, step)
		draw.NoTexture()
	else
		for dotY = y + radius, y + frameHeight - radius, step do
			for dotX = x + radius, x + frameWidth - radius, step do
				surface.DrawRect(dotX, dotY, 2, 2)
			end
		end
	end

	NETWORK.util.DrawRoundedBorder(x, y, frameWidth, frameHeight, radius,
		math.max(Sc(2), 2), ColorAlpha(theme.accent, 110 * alpha))

	local thickness = math.max(Sc(2), 2)

	if (self.open < 0.99) then
		surface.SetDrawColor(theme.accentSoft.r, theme.accentSoft.g,
			theme.accentSoft.b, 255 * alpha)
		surface.DrawRect(x, y, frameWidth, thickness)
		surface.DrawRect(x, y + frameHeight - thickness, frameWidth, thickness)

		self:SetItemsVisible(false)

		return
	end

	self:SetItemsVisible(true)
	self:PaintChrome(x, y, frameWidth, frameHeight, alpha)
	self:PaintContent(alpha)

	local keys = L("civicKeysHint")

	surface.SetFont("nwHudSmall")

	local keysWidth = surface.GetTextSize(keys) + Sc(28)
	local keysX = x + frameWidth - keysWidth - Sc(18)
	local keysY = self:IsFullscreen() and (y + frameHeight - Sc(34)) or
		(y + frameHeight + Sc(8))

	draw.RoundedBox(Sc(11), keysX, keysY, keysWidth, Sc(22),
		ColorAlpha(CIVIC.accent, 20 * alpha))
	draw.SimpleText(keys, "nwHudSmall", keysX + math.floor(keysWidth * 0.5),
		keysY + Sc(11), ColorAlpha(CIVIC.textDim, 230 * alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)
end

function PANEL:SetItemsVisible(bVisible)
	if (self.bItemsVisible == bVisible) then
		return
	end

	self.bItemsVisible = bVisible

	for _, list in ipairs({self.navItems, self.pageItems}) do
		for _, item in ipairs(list) do
			if (IsValid(item)) then
				item:SetVisible(bVisible)
			end
		end
	end

	if (IsValid(self.close)) then
		self.close:SetVisible(bVisible)
	end
end

function PANEL:PaintChrome(x, y, width, height, alpha)
	local Sc = NETWORK.util.Scale
	local theme = CIVIC
	local util = NETWORK.util
	local barHeight = self:GetBarHeight()
	local data = self.data
	local radius = Sc(18)

	draw.RoundedBoxEx(radius, x, y, width, barHeight,
		Color(255, 255, 255, 6 * alpha), true, true, false, false)

	local emblem = Sc(40)
	local emblemX = x + Sc(22) + math.Round(emblem * 0.5)
	local emblemY = y + math.Round(barHeight * 0.5)

	util.DrawCircle(emblemX, emblemY, math.Round(emblem * 0.5),
		ColorAlpha(theme.accent, 235 * alpha))
	util.DrawCircle(emblemX, emblemY, math.Round(emblem * 0.5) - Sc(3),
		ColorAlpha(theme.plate, 255 * alpha))

	draw.SimpleText(self.emblem or "24", "nwTermNav", emblemX, emblemY,
		ColorAlpha(theme.accent, 250 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local titleX = x + Sc(22) + emblem + Sc(14)

	draw.SimpleText(util.Upper(L(self.brandKey or "termBrand")), "nwTermBrand", titleX,
		y + math.Round(barHeight * 0.5) - Sc(8),
		ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	util.DrawTextSpaced(util.Upper(L(self.subtitleKey or "termSubtitle")), "nwHudSmall", titleX,
		y + math.Round(barHeight * 0.5) + Sc(10),
		ColorAlpha(theme.textDim, 230 * alpha), Sc(3))

	local rightX = x + width - Sc(120)

	local owner = (data.name or "?") .. "  ·  #" .. (data.cid or "00000")

	surface.SetFont("nwTermNav")

	local ownerWidth = surface.GetTextSize(owner) + Sc(28)

	draw.RoundedBox(math.max(Sc(6), 4), rightX - ownerWidth, y + math.Round(barHeight * 0.5) - Sc(22),
		ownerWidth, Sc(28), ColorAlpha(theme.accent, 26 * alpha))
	util.DrawRoundedBorder(rightX - ownerWidth, y + math.Round(barHeight * 0.5) - Sc(22),
		ownerWidth, Sc(28), math.max(Sc(6), 4), math.max(Sc(1), 1), ColorAlpha(theme.accent, 150 * alpha))

	draw.SimpleText(owner, "nwTermNav", rightX - math.Round(ownerWidth * 0.5),
		y + math.Round(barHeight * 0.5) - Sc(8), ColorAlpha(theme.value, 245 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(util.Upper(L("termTime")) .. "  " .. NETWORK.terminal.GetTime(),
		"nwHudSmall", rightX - math.Round(ownerWidth * 0.5),
		y + math.Round(barHeight * 0.5) + Sc(16), ColorAlpha(theme.textDim, 235 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 22 * alpha)
	surface.DrawRect(x + radius, y + barHeight - 1, width - radius * 2, 1)

	draw.RoundedBoxEx(radius, x, y + barHeight, self:GetNavWidth(), height - barHeight,
		Color(255, 255, 255, 5 * alpha), false, false, true, false)

	surface.SetDrawColor(255, 255, 255, 14 * alpha)
	surface.DrawRect(x + self:GetNavWidth(), y + barHeight + Sc(12), 1, height - barHeight - Sc(24))
end

function PANEL:PaintContent(alpha)
	local builder = self["Paint" .. string.upper(string.sub(self.page, 1, 1)) ..
		string.sub(self.page, 2) .. "Page"]

	if (builder) then
		builder(self, alpha)
	end
end

function PANEL:PaintHeader(label, alpha)
	local Sc = NETWORK.util.Scale
	local theme = CIVIC
	local x = self:GetContentX() + Sc(34)
	local y = self:GetFrameY() + self:GetBarHeight() + Sc(6)

	draw.SimpleText(NETWORK.util.Upper(label), "nwInvKey", x,
		y + Sc(10), ColorAlpha(theme.accent, 235 * alpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP)

	return self:GetPageTop()
end

local function Line(x, y, width, color, alpha)
	surface.SetDrawColor(color.r, color.g, color.b, alpha or 90)
	surface.DrawRect(x, y, width, 1)
end

function PANEL:PaintInfoPage(alpha)
	local Sc = NETWORK.util.Scale
	local theme = CIVIC
	local data = self.data
	local x = self:GetContentX() + Sc(34)
	local width = self:GetContentWidth() - Sc(68)
	local y = self:PaintHeader(L("termInfo"), alpha) + Sc(8)

	draw.SimpleText((data.name or "?") .. "  #" .. (data.cid or "00000"),
		"nwTermTitle", x, y, ColorAlpha(theme.value, 250 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	y = y + Sc(46)
	Line(x, y, width, theme.line, 120 * alpha)
	y = y + Sc(22)

	draw.SimpleText(data.faction or "", "nwTermBody", x, y,
		ColorAlpha(theme.text, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	y = y + Sc(38)
	Line(x, y, width, theme.line, 60 * alpha)
	y = y + Sc(22)

	draw.SimpleText(NETWORK.util.Upper(L("termHousingLine")) .. ": " ..
		(data.housing and data.housing != "" and data.housing or
		L("termHousingNone")), "nwTermBody", x, y,
		ColorAlpha(theme.text, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	y = y + Sc(38)
	Line(x, y, width, theme.line, 60 * alpha)
	y = y + Sc(22)

	draw.SimpleText(NETWORK.util.Upper(L("termViolations")) .. ": " ..
		(data.violations or L("termViolationsNone")), "nwTermBody", x, y,
		ColorAlpha(data.violations and Color(226, 92, 84) or theme.text,
		235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	y = y + Sc(30)

	if (data.loyalty) then
		local band = NETWORK.loyalty.GetBand(data.loyalty)

		draw.SimpleText(NETWORK.util.Upper(L("termLoyalty")) .. ": " ..
			data.loyalty .. "  //  " ..
			NETWORK.util.Upper(data.loyaltyBand or ""), "nwTermBody", x, y,
			ColorAlpha(band and band.color or theme.text, 235 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	y = y + Sc(38)
	Line(x, y, width, theme.line, 60 * alpha)
	y = y + Sc(22)

	local weather = NETWORK.weather.GetCurrent()
	local bNight = NETWORK.time.IsNight()

	draw.SimpleText(NETWORK.util.Upper(L("termWeather")) .. ": " ..
		L(weather.name), "nwTermBody", x, y,
		ColorAlpha(theme.text, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	local rain = NETWORK.weather.GetValue("rain")
	local fog = NETWORK.weather.GetValue("fog")
	local detail

	if (rain > 0.6) then
		detail = L("termWeatherHeavyRain")
	elseif (rain > 0.15) then
		detail = L("termWeatherRain")
	elseif (fog > 0.6) then
		detail = L("termWeatherThickFog")
	elseif (fog > 0.2) then
		detail = L("termWeatherHaze")
	else
		detail = L("termWeatherCalm")
	end

	draw.SimpleText(NETWORK.util.Upper(detail), "nwHudSmall", x + width, y + Sc(4),
		ColorAlpha(rain > 0.15 and Color(126, 176, 220) or
		(fog > 0.2 and theme.textDim or Color(120, 200, 140)), 240 * alpha),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

	y = y + Sc(30)

	draw.SimpleText(NETWORK.util.Upper(L("termDaytime")) .. ": " ..
		L(bNight and "termNight" or "termDay") .. "  //  " ..
		NETWORK.time.GetFormatted(), "nwTermBody", x, y,
		ColorAlpha(theme.textDim, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

function PANEL:PaintHousingPage(alpha)
	local Sc = NETWORK.util.Scale
	local theme = CIVIC
	local data = self.data
	local bHome = data.housing and data.housing != ""
	local middle = self:GetContentX() + math.Round(self:GetContentWidth() * 0.5)
	local y = self:PaintHeader(L("termHousing"), alpha)

	draw.SimpleText(NETWORK.util.Upper(L(bHome and "termHousingYours" or
		"termHousingSearch")), "nwTermTitle", middle, y + Sc(64),
		ColorAlpha(theme.accent, 245 * alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)

	if (bHome) then
		draw.SimpleText(data.housing, "nwTermBody", middle, y + Sc(110),
			ColorAlpha(theme.text, 235 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end

	local apartment = data.apartment

	if (!apartment or !apartment.price) then
		return
	end

	local top = self:GetPageTop() + Sc(190) + Sc(150)
	local lineY = top - Sc(66)
	local x = self:GetContentX() + Sc(34)
	local width = self:GetContentWidth() - Sc(68)

	surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 70 * alpha)
	surface.DrawRect(x, lineY, width, 1)

	draw.SimpleText("СОБСТВЕННАЯ КВАРТИРА", "nwTermCaption", middle, lineY + Sc(20),
		ColorAlpha(theme.accent, 240 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local text

	if (apartment.owned) then
		text = string.format("%s  ·  налог %d т. за выплату  ·  долг %d т.", apartment.owned.address,
			apartment.tax, apartment.owned.debt or 0)
	elseif (apartment.request) then
		text = "Заявка «" .. (apartment.request.wish or "") .. "» ожидает администрацию"
	else
		text = string.format("Цена %d т.  ·  налог %d т. за выплату  ·  адрес вносится в базу ГО",
			apartment.price, apartment.tax)
	end

	draw.SimpleText(text, "nwTermBody", middle, lineY + Sc(46), ColorAlpha(theme.textDim, 235 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:PaintCallPage(alpha)
	local theme = CIVIC
	local middle = self:GetContentX() + math.Round(self:GetContentWidth() * 0.5)
	local y = self:PaintHeader(L("termCall"), alpha)

	draw.SimpleText(NETWORK.util.Upper(L("termCallReason")), "nwTermTitle",
		middle, y + NETWORK.util.Scale(34), ColorAlpha(theme.accent, 245 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:PaintBankPage(alpha)
	local Sc = NETWORK.util.Scale
	local theme = CIVIC
	local data = self.data
	local x = self:GetContentX() + Sc(34)
	local width = self:GetContentWidth() - Sc(68)
	local middle = self:GetContentX() + math.Round(self:GetContentWidth() * 0.5)
	local y = self:PaintHeader(L("termBank"), alpha)

	surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
		20 * alpha)
	surface.DrawRect(x, y, width, Sc(108))

	surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
		190 * alpha)
	surface.DrawRect(x, y, width, math.max(Sc(2), 2))

	draw.SimpleText(NETWORK.util.Upper(L("termBankBalance")), "nwTermCaption",
		middle, y + Sc(26), ColorAlpha(theme.textDim, 235 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(tostring(data.bank or 0), "nwTermTitle", middle, y + Sc(66),
		ColorAlpha(theme.value, 250 * alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)

	draw.SimpleText(NETWORK.util.Upper(L("termBankOnHand")) .. ": " ..
		(data.tokens or 0), "nwTermBody", middle, y + Sc(136),
		ColorAlpha(theme.text, 235 * alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)

	draw.SimpleText(NETWORK.util.Upper(L("termBankAmount")) .. ": " ..
		NETWORK.terminal.amount, "nwTermCaption", middle, y + Sc(178),
		ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)
end

function PANEL:PaintBusinessPage(alpha)
	local Sc = NETWORK.util.Scale
	local theme = CIVIC
	local entry = self.data.business
	local x = self:GetContentX() + Sc(34)
	local width = self:GetContentWidth() - Sc(68)
	local y = self:PaintHeader(L("termBusiness"), alpha)

	if (entry) then
		local status = L("termBusinessPending")
		local statusColor = theme.warning

		if (entry.status == "approved") then
			status = L("termBusinessApproved")
			statusColor = theme.positive
		elseif (entry.status == "denied") then
			status = L("termBusinessDenied")
			statusColor = theme.danger
		end

		local lineY = y

		for _, line in ipairs(NETWORK.util.WrapText(
			NETWORK.util.Upper(L("termBusinessWhat")) .. ": " ..
			(entry.what or ""), "nwTermCaption", width, 2)) do
			draw.SimpleText(line, "nwTermCaption", x, lineY,
				ColorAlpha(theme.text, 235 * alpha), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_TOP)

			lineY = lineY + Sc(20)
		end

		draw.SimpleText(NETWORK.util.Upper(L("termBusinessState")) .. ": " ..
			status, "nwTermCaption", x, lineY, ColorAlpha(statusColor,
			245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		lineY = lineY + Sc(20)

		draw.SimpleText(NETWORK.util.Upper(L("termBusinessDoor")) .. ": " ..
			(entry.location and entry.location != "" and entry.location or
			L("termBusinessNoDoor")), "nwTermCaption", x, lineY,
			ColorAlpha(theme.text, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	else
		draw.SimpleText(L("termBusinessNone"), "nwTermCaption", x, y,
			ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_TOP)
	end

	local formY = self:GetPageTop() + self:GetBusinessStatusHeight()

	Line(x, formY + Sc(14), width, theme.line, 80 * alpha)

	draw.SimpleText(L("termBusinessWhat"), "nwTermCaption", x, formY + Sc(34),
		ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	draw.SimpleText(L("termBusinessWhy"), "nwTermCaption", x,
		formY + Sc(58) + Sc(34) + Sc(22), ColorAlpha(theme.textDim, 235 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

function PANEL:BuildMail()
	local Sc = NETWORK.util.Scale
	local x = self:GetContentX() + Sc(34)
	local width = math.floor((self:GetContentWidth() - Sc(68)) * 0.46)
	local top = self:GetPageTop() + Sc(28)
	local bottom = self:GetPageBottom()

	local subject = self:AddEntry(x, top, width, Sc(40))

	subject:SetValue(self.mailSubject or "")
	subject:SetPlaceholderText(L("termMailSubject"))
	subject.OnChange = function(panel)
		self.mailSubject = panel:GetValue()
	end

	local text = self:AddEntry(x, top + Sc(76), width, bottom - top - Sc(76) - Sc(60), true)

	text:SetValue(self.mailText or "")
	text:SetPlaceholderText(L("termMailText"))
	text.OnChange = function(panel)
		self.mailText = panel:GetValue()
	end

	self:AddButton(L("termMailSend"), x, bottom - Sc(44), width, Sc(44), function()
		NETWORK.terminal.Send("mail_send", {
			subject = self.mailSubject or "",
			text = self.mailText or ""
		})

		self.mailSubject = ""
		self.mailText = ""
		subject:SetValue("")
		text:SetValue("")
	end)
end

function PANEL:PaintMailPage(alpha)
	local Sc = NETWORK.util.Scale
	local theme = CIVIC
	local top = self:PaintHeader(L("termMail"), alpha)
	local x = self:GetContentX() + Sc(34)
	local fullWidth = self:GetContentWidth() - Sc(68)
	local formWidth = math.floor(fullWidth * 0.46)

	draw.SimpleText(NETWORK.util.Upper(L("termMailTo")), "nwHudSmall", x, top + Sc(12),
		ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(L("termMailTextLabel"), "nwHudSmall", x, top + Sc(92),
		ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local listX = x + formWidth + Sc(30)
	local listWidth = fullWidth - formWidth - Sc(30)
	local cursor = top + Sc(12)
	local letters = self.data.mail or {}

	draw.SimpleText(NETWORK.util.Upper(L("termMailMine")), "nwHudSmall", listX, cursor,
		ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	cursor = cursor + Sc(18)

	if (#letters == 0) then
		draw.SimpleText(L("termMailEmpty"), "nwTermCaption", listX, cursor + Sc(14),
			ColorAlpha(theme.textFaint, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	for _, letter in ipairs(letters) do
		local replyLines = letter.reply and NETWORK.util.WrapText(letter.reply.text,
			"nwTermCaption", listWidth - Sc(40), 3) or {}
		local height = Sc(50) + (#replyLines > 0 and (Sc(24) + #replyLines * Sc(17)) or 0)

		if (cursor + height > self:GetPageBottom()) then
			break
		end

		draw.RoundedBox(Sc(12), listX, cursor, listWidth, height,
			ColorAlpha(theme.accent, 14 * alpha))

		draw.SimpleText(letter.subject or "", "nwTermNav", listX + Sc(14), cursor + Sc(16),
			ColorAlpha(theme.text, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(letter.time or "", "nwHudSmall", listX + listWidth - Sc(14),
			cursor + Sc(16), ColorAlpha(theme.textDim, 225 * alpha), TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)
		draw.SimpleText(letter.reply and L("termMailAnswered") or L("termMailWaiting"),
			"nwHudSmall", listX + Sc(14), cursor + Sc(36),
			ColorAlpha(letter.reply and theme.accent or theme.textFaint, 235 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (#replyLines > 0) then
			local replyY = cursor + Sc(52)

			draw.RoundedBox(Sc(8), listX + Sc(12), replyY, listWidth - Sc(24),
				Sc(14) + #replyLines * Sc(17), ColorAlpha(theme.accent, 22 * alpha))

			for index, line in ipairs(replyLines) do
				draw.SimpleText(line, "nwTermCaption", listX + Sc(22),
					replyY + Sc(4) + index * Sc(17) - Sc(4), ColorAlpha(theme.text, 240 * alpha),
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end

		cursor = cursor + height + Sc(10)
	end
end

function PANEL:BuildBoard()
	local Sc = NETWORK.util.Scale
	local x = self:GetContentX() + Sc(34)
	local width = self:GetContentWidth() - Sc(68)
	local y = self:GetPageBottom() - Sc(44)

	if (!self.data.bBoardWrite) then
		return
	end

	local entry = self:AddEntry(x, y, width - Sc(150), Sc(40))

	entry:SetValue(self.boardDraft or "")
	entry:SetPlaceholderText(L("chanPlaceholder"))
	entry.OnChange = function(panel)
		self.boardDraft = panel:GetValue()
	end

	local function Send()
		local text = string.Trim(self.boardDraft or "")

		if (text == "") then
			return
		end

		self.boardDraft = ""
		entry:SetValue("")

		NETWORK.terminal.Send("board_post", {text = text})
	end

	entry.OnEnter = Send

	self:AddButton(L("chanSend"), x + width - Sc(140), y, Sc(140), Sc(40), Send)
end

function PANEL:PaintBoardPage(alpha)
	local Sc = NETWORK.util.Scale
	local theme = CIVIC
	local x = self:GetContentX() + Sc(34)
	local width = self:GetContentWidth() - Sc(68)
	local top = self:PaintHeader(L("termBoard"), alpha)
	local cursor = self:GetPageBottom() - Sc(56)
	local messages = self.data.board or {}

	if (!self.data.bBoardWrite) then
		local hintY = self:GetPageBottom() - Sc(22)

		draw.RoundedBox(Sc(10), x, hintY - Sc(18), width, Sc(36),
			ColorAlpha(theme.accent, 10 * alpha))
		draw.SimpleText(L("boardReadOnly"), "nwTermCaption", x + math.Round(width * 0.5),
			hintY, ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end

	if (#messages == 0) then
		draw.SimpleText(L("chanEmpty"), "nwTermBody", x, top + Sc(20),
			ColorAlpha(theme.textDim, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	for index = #messages, 1, -1 do
		local message = messages[index]
		local lines = NETWORK.util.WrapText(message.text or "", "nwTermCaption",
			width - Sc(28), 4)
		local height = Sc(30) + #lines * Sc(17)

		cursor = cursor - height - Sc(8)

		if (cursor < top) then
			break
		end

		draw.RoundedBox(Sc(10), x, cursor, width, height, ColorAlpha(theme.accent, 16 * alpha))

		draw.SimpleText(message.author or "?", "nwTermNav", x + Sc(14), cursor + Sc(13),
			ColorAlpha(theme.accent, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(message.time or "", "nwHudSmall", x + width - Sc(14), cursor + Sc(13),
			ColorAlpha(theme.textDim, 225 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		for lineIndex, line in ipairs(lines) do
			draw.SimpleText(line, "nwTermCaption", x + Sc(14), cursor + Sc(10) +
				lineIndex * Sc(17), ColorAlpha(theme.text, 245 * alpha), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
		end
	end
end

vgui.Register("nwTerminalMenu", PANEL, "EditablePanel")

NETWORK.terminal.panels = NETWORK.terminal.panels or {}

function NETWORK.gui.OpenTerminal(entity, data)
	NETWORK.gui.CloseWindows()

	local class = IsValid(entity) and entity:GetClass() or ""
	local panel = vgui.Create(NETWORK.terminal.panels[class] or "nwTerminalMenu")

	panel:Setup(entity, data)

	return panel
end

function NETWORK.gui.CloseTerminal()
	if (IsValid(NETWORK.gui.terminal)) then
		NETWORK.gui.terminal:Remove()
	end

	NETWORK.gui.terminal = nil
end
