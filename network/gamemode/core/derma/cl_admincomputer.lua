local PANEL = {}

local WIN = {
	desktopTop = Color(34, 96, 168),
	desktopBottom = Color(12, 44, 96),
	taskbar = Color(18, 28, 44, 236),
	frame = Color(166, 196, 228),
	frameInactive = Color(206, 220, 236),
	frameBorder = Color(62, 88, 122),
	title = Color(20, 30, 46),
	body = Color(255, 255, 255),
	dialog = Color(240, 240, 240),
	text = Color(20, 20, 20),
	textDim = Color(96, 96, 96),
	line = Color(214, 214, 214),
	selection = Color(204, 232, 255),
	selectionBorder = Color(123, 181, 232),
	hover = Color(229, 243, 255),
	button = Color(236, 236, 236),
	buttonBorder = Color(112, 112, 112),
	buttonHover = Color(223, 238, 252),
	buttonHoverBorder = Color(60, 127, 177),
	close = Color(199, 80, 80),
	closeHover = Color(232, 17, 35),
	link = Color(0, 102, 204),
	good = Color(34, 139, 34),
	bad = Color(192, 32, 32),
	warn = Color(200, 130, 0)
}

local COMPUTER = NETWORK.sound and NETWORK.sound.computer or {}

local SOUNDS = {
	boot = "ambient/machines/keyboard7_clicks_enter.wav",
	click = "buttons/lightswitch2.wav",
	open = COMPUTER.open or "buttons/button9.wav",
	close = "buttons/button18.wav",
	error = COMPUTER.deny or "buttons/combine_button_locked.wav",
	notify = "buttons/blip1.wav",
	shutdown = "buttons/button19.wav",
	hum = COMPUTER.hum or "ambient/machines/computer_ambient_loop.wav",
	menu = "ui/buttonrollover.wav",
	keys = COMPUTER.keys or {
		"ambient/machines/keyboard1_clicks.wav",
		"ambient/machines/keyboard2_clicks.wav",
		"ambient/machines/keyboard3_clicks.wav",
		"ambient/machines/keyboard4_clicks.wav",
		"ambient/machines/keyboard6_clicks.wav"
	}
}

NETWORK.admincomp = NETWORK.admincomp or {}
NETWORK.admincomp.sounds = SOUNDS

local MENU_ITEMS = {"Файл", "Правка", "Вид", "Справка"}

local function Sc(value)
	return NETWORK.util.Scale(value)
end

local fontScale

local function EnsureFonts()
	local scale = Sc(100)

	if (fontScale == scale) then
		return
	end

	fontScale = scale

	local function Font(name, face, size, weight)
		surface.CreateFont(name, {
			font = face,
			size = math.max(math.Round(Sc(size)), 10),
			weight = weight or 400,
			extended = true,
			antialias = true
		})
	end

	Font("nwWinText", "Tahoma", 15)
	Font("nwWinBold", "Tahoma", 15, 700)
	Font("nwWinSmall", "Tahoma", 13)
	Font("nwWinTitle", "Segoe UI", 16)
	Font("nwWinBig", "Segoe UI Light", 30, 300)
	Font("nwWinHeader", "Segoe UI", 22)
	Font("nwWinMono", NETWORK.fonts.mono or "Courier New", 15)
	Font("nwWinCam", NETWORK.fonts.mono or "Courier New", 18, 700)
	Font("nwWinMenu", "Tahoma", 14)
	Font("nwWinTray", "Tahoma", 12)
end

local ARROW = {
	{{0, 0}, {11, 11}, {6, 11}},
	{{0, 0}, {6, 11}, {4, 12}},
	{{0, 0}, {4, 12}, {0, 16}},
	{{4, 12}, {6, 11}, {9, 17}, {7, 18}}
}

local function DrawArrow(x, y, scale, color, dx, dy)
	draw.NoTexture()
	surface.SetDrawColor(color)

	for _, poly in ipairs(ARROW) do
		local points = {}

		for index, point in ipairs(poly) do
			points[index] = {x = x + point[1] * scale + (dx or 0), y = y + point[2] * scale + (dy or 0)}
		end

		surface.DrawPoly(points)
	end
end

local function DrawCursor(x, y, bBusy, bText)
	local scale = math.max(Sc(1.1), 1)

	if (bText) then
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(x - 1, y - Sc(8), 3, Sc(16))
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawRect(x, y - Sc(8), 1, Sc(16))

		return
	end

	for _, offset in ipairs({{-1, 0}, {1, 0}, {0, -1}, {0, 1}, {1, 1}}) do
		DrawArrow(x, y, scale, Color(0, 0, 0), offset[1], offset[2])
	end

	DrawArrow(x, y, scale, Color(255, 255, 255))

	if (bBusy) then

		local hx, hy = x + Sc(20), y + Sc(20)
		local w, h = Sc(10), Sc(14)
		local flip = math.floor(RealTime() * 2) % 2 == 0

		draw.NoTexture()
		surface.SetDrawColor(0, 0, 0)
		surface.DrawPoly({{x = hx - w, y = hy - h}, {x = hx + w, y = hy - h}, {x = hx, y = hy}})
		surface.DrawPoly({{x = hx, y = hy}, {x = hx + w, y = hy + h}, {x = hx - w, y = hy + h}})
		surface.SetDrawColor(230, 200, 90)

		if (flip) then
			surface.DrawPoly({{x = hx - w + 2, y = hy - h + 2}, {x = hx + w - 2, y = hy - h + 2},
				{x = hx, y = hy - 1}})
		else
			surface.DrawPoly({{x = hx, y = hy + 1}, {x = hx + w - 2, y = hy + h - 2},
				{x = hx - w + 2, y = hy + h - 2}})
		end
	end
end

local function Inside(px, py, x, y, width, height)
	return px >= x and py >= y and px < x + width and py < y + height
end

local function Text(text, font, x, y, color, alignX, alignY)
	draw.SimpleText(text, font, x, y, color, alignX or TEXT_ALIGN_LEFT, alignY or TEXT_ALIGN_CENTER)
end

local function Box(x, y, width, height, fill, border)
	if (fill) then
		surface.SetDrawColor(fill)
		surface.DrawRect(x, y, width, height)
	end

	if (border) then
		surface.SetDrawColor(border)
		surface.DrawOutlinedRect(x, y, width, height, 1)
	end
end

function PANEL:Hit(x, y, width, height, callback, kind)
	self.hits[#self.hits + 1] = {x, y, width, height, callback, kind}
end

function PANEL:Button(x, y, width, height, label, callback, bDefault, bDisabled)
	local bHover = !bDisabled and Inside(self.mouseX, self.mouseY, x, y, width, height)
	local top = bHover and Color(236, 244, 252) or Color(246, 246, 246)
	local bottom = bHover and WIN.buttonHover or Color(222, 222, 222)

	NETWORK.util.DrawVGradient(x, y, width, height, top, bottom)

	surface.SetDrawColor(bHover and WIN.buttonHoverBorder or
		(bDefault and Color(51, 153, 255) or WIN.buttonBorder))
	surface.DrawOutlinedRect(x, y, width, height, 1)

	Text(label, "nwWinText", x + math.floor(width * 0.5), y + math.floor(height * 0.5),
		bDisabled and WIN.textDim or WIN.text, TEXT_ALIGN_CENTER)

	if (!bDisabled and callback) then
		self:Hit(x, y, width, height, function()
			surface.PlaySound(SOUNDS.click)
			callback()
		end)
	end
end

function PANEL:Input(window, key, x, y, width, height, placeholder, bMultiline, bNumeric)
	local entry = window.inputs[key]

	if (!IsValid(entry)) then
		entry = self:Add("DTextEntry")
		entry:SetFont("nwWinText")
		entry:SetDrawLanguageID(false)
		entry:SetAllowNonAsciiCharacters(true)
		entry:SetMultiline(bMultiline or false)
		entry:SetNumeric(bNumeric or false)
		entry:SetPaintBackground(false)
		entry:SetCursor("blank")
		entry:SetTextColor(WIN.text)
		entry:SetCursorColor(WIN.text)
		entry:SetHighlightColor(Color(51, 153, 255))
		entry.placeholder = placeholder
		entry.Paint = function(this, entryWidth, entryHeight)
			Box(0, 0, entryWidth, entryHeight, WIN.body, this:HasFocus() and Color(51, 153, 255) or
				Color(171, 173, 179))

			if (this:GetValue() == "" and !this:HasFocus() and this.placeholder) then
				Text(this.placeholder, "nwWinText", Sc(6), bMultiline and Sc(11) or
					math.floor(entryHeight * 0.5), Color(150, 150, 150))
			end

			this:DrawTextEntryText(WIN.text, Color(51, 153, 255), WIN.text)
		end
		entry.OnChange = function()
			self:TypeSound()
		end

		window.inputs[key] = entry
	end

	entry:SetPos(x, y)
	entry:SetSize(width, height)
	entry.placed = self.paintFrame
	entry.window = window

	return entry
end

function PANEL:TypeSound()
	if ((self.nextTypeSound or 0) > RealTime()) then
		return
	end

	self.nextTypeSound = RealTime() + 0.35

	surface.PlaySound(SOUNDS.keys[math.random(#SOUNDS.keys)])
end

function PANEL:GetInputValue(window, key)
	local entry = window.inputs[key]

	return IsValid(entry) and entry:GetValue() or ""
end

function PANEL:SetInputValue(window, key, value)
	local entry = window.inputs[key]

	if (IsValid(entry)) then
		entry:SetValue(value or "")
	end
end

function PANEL:ListView(window, key, x, y, width, height, columns, rows, onClick, selected)
	local headerHeight = Sc(24)
	local rowHeight = Sc(24)

	Box(x, y, width, height, WIN.body, Color(130, 135, 144))

	NETWORK.util.DrawVGradient(x + 1, y + 1, width - 2, headerHeight, Color(255, 255, 255),
		Color(236, 238, 242))
	surface.SetDrawColor(WIN.line)
	surface.DrawRect(x + 1, y + headerHeight, width - 2, 1)

	for index, column in ipairs(columns) do
		local columnX = x + math.floor(width * column[2])

		Text(column[1], "nwWinText", columnX + Sc(6), y + math.floor(headerHeight * 0.5), WIN.text)

		if (index > 1) then
			surface.SetDrawColor(WIN.line)
			surface.DrawRect(columnX, y + Sc(3), 1, headerHeight - Sc(6))
		end
	end

	local visible = math.floor((height - headerHeight - 2) / rowHeight)
	local maxScroll = math.max(#rows - visible, 0)

	window.scrolls = window.scrolls or {}
	window.scrolls[key] = math.Clamp(window.scrolls[key] or 0, 0, maxScroll)

	window.scrollAreas = window.scrollAreas or {}
	window.scrollAreas[key] = {x, y, width, height, maxScroll}

	local offset = window.scrolls[key]

	for index = 1, visible do
		local row = rows[index + offset]

		if (!row) then
			break
		end

		local rowY = y + headerHeight + 1 + (index - 1) * rowHeight
		local bSelected = selected and selected == row
		local bHover = self.bTopWindow and Inside(self.mouseX, self.mouseY, x + 1, rowY, width - Sc(14),
			rowHeight)

		if (bSelected) then
			Box(x + 2, rowY, width - Sc(16), rowHeight - 1, WIN.selection, WIN.selectionBorder)
		elseif (bHover) then
			Box(x + 2, rowY, width - Sc(16), rowHeight - 1, WIN.hover)
		end

		for columnIndex, column in ipairs(columns) do
			local value = row.cells[columnIndex]
			local color = row.colors and row.colors[columnIndex] or WIN.text

			Text(NETWORK.util.TruncateWidth(tostring(value or ""), row.bBold and "nwWinBold" or
				"nwWinText", math.floor(width * ((columns[columnIndex + 1] or {nil, 1})[2] -
				column[2])) - Sc(10)), row.bBold and "nwWinBold" or "nwWinText",
				x + math.floor(width * column[2]) + Sc(6), rowY + math.floor(rowHeight * 0.5), color)
		end

		if (onClick) then
			local rect = {x + 1, rowY, width - Sc(16), rowHeight}

			self:Hit(rect[1], rect[2], rect[3], rect[4], function()
				surface.PlaySound(SOUNDS.click)
				onClick(row, rect)
			end)
		end
	end

	local barX = x + width - Sc(14)

	Box(barX, y + headerHeight + 1, Sc(13), height - headerHeight - 2, Color(240, 240, 240))

	if (maxScroll > 0) then
		local track = height - headerHeight - Sc(6)
		local grip = math.max(track * visible / #rows, Sc(20))
		local gripY = y + headerHeight + Sc(3) + (track - grip) * offset / maxScroll

		Box(barX + Sc(2), gripY, Sc(9), grip, Color(205, 205, 205), Color(160, 160, 160))
	end
end

local APPS = {}
local APP_ORDER = {"database", "board", "documents", "mail", "budget", "housing", "supply", "decisions", "call"}

local CWU_ORDER = {"staff", "fines", "notes", "salary"}
local CWU_ALLIANCE_ORDER = {"notes"}

function PANEL:GetAppOrder()
	return self.appOrder or APP_ORDER
end

function PANEL:Init()
	EnsureFonts()

	NETWORK.gui.adminComputer = self

	self.alpha = 0
	self.bClosing = false
	self.born = RealTime()
	self.windows = {}
	self.toasts = {}
	self.hits = {}
	self.zooms = {}
	self.data = {}
	self.selectedIcon = nil
	self.lastClick = 0
	self.bStart = false
	self.busyUntil = 0
	self.mouseX, self.mouseY = 0, 0
	self.paintFrame = 0

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetCursor("blank")

	surface.PlaySound(SOUNDS.boot)

	self.hum = CreateSound(LocalPlayer(), SOUNDS.hum)

	if (self.hum) then
		self.hum:PlayEx(0.18, 100)
	end
end

function PANEL:Setup(entity)
	self.entity = entity
	self.kind = NETWORK.admincomp.GetKind(entity)

	if (self.kind == "cwu") then
		local client = LocalPlayer()
		local bHead = client:IsAdmin() or client:GetNWString("nwClass", "") == "cwuhead"

		self.appOrder = bHead and CWU_ORDER or CWU_ALLIANCE_ORDER
		self.roleLines = {"Гражданский Союз", "Рабочих"}
		self.nodeTag = "24-CWU-"
	elseif (self.kind == "council") then

		self.appOrder = APP_ORDER
		self.roleLines = {"Совет", "Лоялистов"}
		self.orgName = L("classCouncil")
		self.nodeTag = "24-LCN-"
	else
		self.appOrder = APP_ORDER
		self.roleLines = {"Городская", "Администрация"}
		self.nodeTag = "24-ADM-"
	end

	timer.Simple(1.9, function()
		if (IsValid(self)) then
			self:Toast("Добро пожаловать, " .. LocalPlayer():GetCharacterName())
			self:Request(self.kind == "cwu" and "cwu_state" or "mail_list")
		end
	end)
end

function PANEL:OnRemove()
	if (self.hum) then
		self.hum:Stop()
	end

	if (NETWORK.gui.adminComputer == self) then
		NETWORK.gui.adminComputer = nil
	end
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	surface.PlaySound(SOUNDS.shutdown)

	if (self.hum) then
		self.hum:FadeOut(0.5)
	end

	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

function PANEL:Request(action, payload)
	self.busyUntil = RealTime() + 0.35

	net.Start("nwAdminCompReq")
		net.WriteString(action)
		NETWORK.util.WriteTable(payload or {})
	net.SendToServer()
end

function PANEL:OnData(app, data)
	if (app == "record") then
		return self:OpenRecord(data)
	end

	self.data[app] = data

	if (app == "mail") then
		local unread = 0

		for _, letter in ipairs(data.letters or {}) do
			if (!letter.bRead) then
				unread = unread + 1
			end
		end

		if (self.lastUnread and unread > self.lastUnread) then
			self:Toast("Новое письмо в почте")
		end

		self.lastUnread = unread
	end
end

function PANEL:Toast(text)
	self.toasts[#self.toasts + 1] = {text = text, born = RealTime()}

	surface.PlaySound(SOUNDS.notify)
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		if (self.bStart) then
			self.bStart = false

			return
		end

		self:Close()
	end
end

function PANEL:GetScreen()
	local margin = Sc(30)
	local width = math.min(ScrW() - margin * 2, Sc(1600))
	local height = math.min(ScrH() - margin * 2 - Sc(110), math.Round(width * 0.6))

	width = math.min(width, math.Round(height / 0.6))

	return math.Round((ScrW() - width) * 0.5), math.Round((ScrH() - height) * 0.5) - Sc(48),
		width, height
end

function PANEL:GetTaskbar()
	local x, y, width, height = self:GetScreen()
	local barHeight = Sc(40)

	return x, y + height - barHeight, width, barHeight
end

function PANEL:GetIconRect(index)
	local x, y, _, screenHeight = self:GetScreen()
	local width, height = Sc(84), Sc(78)
	local perColumn = math.max(math.floor((screenHeight - Sc(60)) / (height + Sc(4))), 1)
	local column = math.floor((index - 1) / perColumn)
	local row = (index - 1) % perColumn

	return x + Sc(8) + column * (width + Sc(4)), y + Sc(8) + row * (height + Sc(4)), width, height
end

function PANEL:GetStartRect()
	local x, y = self:GetTaskbar()
	local width, height = Sc(400), Sc(440)

	return x, y - height, width, height
end

function PANEL:FindWindow(id)
	for _, window in ipairs(self.windows) do
		if (window.id == id) then
			return window
		end
	end
end

function PANEL:Focus(window)
	for index, other in ipairs(self.windows) do
		if (other == window) then
			table.remove(self.windows, index)

			break
		end
	end

	self.windows[#self.windows + 1] = window
	window.bMinimized = false
end

function PANEL:CreateWindow(id, title, width, height, from, extra)
	local sx, sy, sw, sh = self:GetScreen()
	local count = #self.windows

	width = math.min(Sc(width), sw - Sc(140))
	height = math.min(Sc(height), sh - Sc(80))

	local window = {
		id = id,
		title = title,
		x = sx + Sc(120) + (count % 6) * Sc(26),
		y = sy + Sc(20) + (count % 6) * Sc(22),
		width = width,
		height = height,
		born = RealTime() + 0.28,
		inputs = {},
		state = {}
	}

	if (extra) then
		table.Merge(window, extra)
	end

	self.zooms[#self.zooms + 1] = {
		from = from or {self.mouseX, self.mouseY, 2, 2},
		to = window,
		born = RealTime()
	}

	self.windows[#self.windows + 1] = window

	surface.PlaySound(SOUNDS.open)

	return window
end

function PANEL:OpenApp(id, from)
	local window = self:FindWindow(id)

	if (window) then
		return self:Focus(window)
	end

	local app = APPS[id]

	window = self:CreateWindow(id, app.title, app.width, app.height, from)
	window.app = app

	if (app.OnOpen) then
		app.OnOpen(self, window)
	end
end

function PANEL:CloseWindow(window)
	if (self.menu and self.menu.window == window) then
		self.menu = nil
	end

	for _, entry in pairs(window.inputs) do
		if (IsValid(entry)) then
			entry:Remove()
		end
	end

	for index, other in ipairs(self.windows) do
		if (other == window) then
			table.remove(self.windows, index)

			break
		end
	end

	surface.PlaySound(SOUNDS.close)
end

function PANEL:GetWindowRect(window)
	if (window.bMaximized) then
		local sx, sy, sw = self:GetScreen()
		local _, barY = self:GetTaskbar()

		return sx, sy, sw, barY - sy
	end

	return window.x, window.y, window.width, window.height
end

PANEL.bootTime = 3.4

function PANEL:IsBooting()
	return RealTime() - self.born < self.bootTime
end

function PANEL:OnMousePressed(code)
	if (self.bClosing or self:IsBooting()) then
		if (code == MOUSE_LEFT and !self.bClosing) then
			self.born = RealTime() - self.bootTime
		end

		return
	end

	if (code != MOUSE_LEFT) then
		return
	end

	local mouseX, mouseY = gui.MousePos()
	local menu = self.menu

	if (menu and menu.width and !Inside(mouseX, mouseY, menu.x, menu.y, menu.width, menu.height)) then

		self.menu = nil
	end

	for index = #self.hits, 1, -1 do
		local hit = self.hits[index]

		if (Inside(mouseX, mouseY, hit[1], hit[2], hit[3], hit[4])) then
			hit[5](mouseX, mouseY)

			return
		end
	end

	self.bStart = false
	self.selectedIcon = nil
end

function PANEL:OnMouseWheeled(delta)
	local window = self.windows[#self.windows]

	if (!window or window.bMinimized) then
		return
	end

	for key, area in pairs(window.scrollAreas or {}) do
		if (Inside(self.mouseX, self.mouseY, area[1], area[2], area[3], area[4])) then
			window.scrolls[key] = math.Clamp((window.scrolls[key] or 0) - delta * 3, 0, area[5])

			return
		end
	end

	window.state.scroll = math.max((window.state.scroll or 0) - delta * Sc(30), 0)
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 6)

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()

		return
	end

	self.mouseX, self.mouseY = gui.MousePos()

	local drag = self.dragging

	if (drag) then
		if (!input.IsMouseDown(MOUSE_LEFT)) then
			self.dragging = nil
		else
			local sx, sy, sw = self:GetScreen()
			local _, barY = self:GetTaskbar()
			local window = drag.window

			window.x = math.Clamp(self.mouseX - drag.dx, sx - window.width + Sc(80),
				sx + sw - Sc(80))
			window.y = math.Clamp(self.mouseY - drag.dy, sy, barY - Sc(30))
		end
	end

	for index = #self.toasts, 1, -1 do
		if (RealTime() - self.toasts[index].born > 5) then
			table.remove(self.toasts, index)
		end
	end

	for index = #self.zooms, 1, -1 do
		if (RealTime() - self.zooms[index].born > 0.3) then
			table.remove(self.zooms, index)
		end
	end
end

function PANEL:PaintDesktop(x, y, width, height)
	local util = NETWORK.util

	util.DrawVGradient(x, y, width, height, WIN.desktopTop, WIN.desktopBottom)

	local time = RealTime() * 0.04

	for index = 1, 3 do
		util.DrawSoftLight(math.Round(x + width * (0.3 + index * 0.18 + math.sin(time + index) * 0.05)),
			math.Round(y + height * (0.25 + index * 0.12)), width * 0.7, height * 0.35,
			Color(120, 190, 255), 26)
	end

	local centerX = x + math.Round(width * 0.62)
	local centerY = y + math.Round(height * 0.44)
	local radius = math.Round(math.min(width, height) * 0.2)

	util.DrawCircle(centerX, centerY, radius, Color(255, 255, 255, 14))
	util.DrawArc(centerX, centerY, radius, math.max(Sc(3), 2), 1, Color(255, 255, 255, 40), 96)
	Text("24", "nwBrand", centerX, centerY, Color(255, 255, 255, 60), TEXT_ALIGN_CENTER)
	Text(self.orgName or "Городская Администрация", "nwWinHeader", centerX, centerY + radius + Sc(26),
		Color(255, 255, 255, 70), TEXT_ALIGN_CENTER)

	local system = {
		{"Компьютер", function(ix, iy, size)
			Box(ix + 3, iy + 4, size - 6, size - 14, Color(60, 70, 84), Color(20, 24, 30))
			NETWORK.util.DrawVGradient(ix + 5, iy + 6, size - 10, size - 18, Color(90, 160, 230),
				Color(30, 80, 150))
			Box(ix + math.floor(size * 0.35), iy + size - 8, math.floor(size * 0.3), 3,
				Color(60, 70, 84))
			Box(ix + math.floor(size * 0.2), iy + size - 5, math.floor(size * 0.6), 3,
				Color(60, 70, 84))
		end},
		{"Корзина", function(ix, iy, size)
			NETWORK.util.DrawVGradient(ix + math.floor(size * 0.25), iy + 8, math.floor(size * 0.5),
				size - 10, Color(220, 226, 232), Color(140, 150, 160))
			Box(ix + math.floor(size * 0.2), iy + 5, math.floor(size * 0.6), 4, Color(120, 130, 140))
			surface.SetDrawColor(90, 100, 110)

			for line = 0, 2 do
				surface.DrawRect(ix + math.floor(size * 0.32) + line * math.floor(size * 0.16),
					iy + 14, 1, size - 20)
			end
		end}
	}

	for index, entry in ipairs(system) do
		local ix, iy, iw, ih = self:GetIconRect(index)
		local bHover = Inside(self.mouseX, self.mouseY, ix, iy, iw, ih)
		local bSelected = self.selectedIcon == index

		if (bHover or bSelected) then
			Box(ix, iy, iw, ih, Color(160, 200, 240, bSelected and 110 or 60),
				Color(200, 225, 250, bSelected and 200 or 120))
		end

		local size = Sc(40)

		entry[2](ix + math.floor((iw - size) * 0.5), iy + Sc(6), size)
		util.DrawSimpleTextShadow(entry[1], "nwWinSmall", ix + math.floor(iw * 0.5), iy + Sc(56),
			Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)

		self:Hit(ix, iy, iw, ih, function()
			surface.PlaySound(SOUNDS.click)
			self.selectedIcon = index
			self.lastClick = RealTime()

			if (index == 1) then
				self:Toast("Диск C: 40 ГБ, свободно 23 ГБ")
			else
				self:Toast("Корзина пуста")
			end
		end)
	end

	for order, id in ipairs(self:GetAppOrder()) do
		local app = APPS[id]
		local index = order + #system
		local ix, iy, iw, ih = self:GetIconRect(index)
		local bHover = Inside(self.mouseX, self.mouseY, ix, iy, iw, ih)
		local bSelected = self.selectedIcon == index

		if (bHover or bSelected) then
			Box(ix, iy, iw, ih, Color(160, 200, 240, bSelected and 110 or 60),
				Color(200, 225, 250, bSelected and 200 or 120))
		end

		local tile = Sc(38)
		local tileX = ix + math.floor((iw - tile) * 0.5)
		local tileY = iy + Sc(6)

		draw.RoundedBox(Sc(5), tileX + 1, tileY + 2, tile, tile, Color(0, 0, 0, 80))
		draw.RoundedBox(Sc(5), tileX, tileY, tile, tile, app.color)
		draw.RoundedBoxEx(Sc(5), tileX + 1, tileY + 1, tile - 2, math.floor(tile * 0.45),
			Color(255, 255, 255, 70), true, true, false, false)
		NETWORK.gui.DrawGlyph(app.glyph, tileX + Sc(10), tileY + Sc(10), tile - Sc(20),
			Color(255, 255, 255))

		local lines = util.WrapText(app.title, "nwWinSmall", iw - Sc(4), 2)

		for line, textLine in ipairs(lines) do
			util.DrawSimpleTextShadow(textLine, "nwWinSmall", ix + math.floor(iw * 0.5),
				iy + Sc(54) + (line - 1) * Sc(13), Color(255, 255, 255), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER, 1)
		end

		self:Hit(ix, iy, iw, ih, function()
			if (self.selectedIcon == index and RealTime() - self.lastClick < 0.45) then
				self:OpenApp(id, {ix, iy, iw, ih})
			else
				surface.PlaySound(SOUNDS.click)
			end

			self.selectedIcon = index
			self.lastClick = RealTime()
		end)
	end
end

function PANEL:PaintWindow(window, bTop)
	local util = NETWORK.util
	local x, y, width, height = self:GetWindowRect(window)
	local frame = Sc(6)
	local titleHeight = Sc(28)
	local frameColor = bTop and WIN.frame or WIN.frameInactive

	self.paintOwner = window
	self.bTopWindow = bTop

	util.DrawSoftLight(x + math.floor(width * 0.5), y + math.floor(height * 0.5), width * 1.15,
		height * 1.2, Color(0, 0, 0), bTop and 130 or 70)

	self:Hit(x, y, width, height, function()
		self:Focus(window)
	end)

	draw.RoundedBoxEx(Sc(6), x, y, width, height, frameColor, true, true, false, false)
	util.DrawVGradient(x + Sc(6), y + 1, width - Sc(12), titleHeight,
		Color(255, 255, 255, bTop and 90 or 50), Color(255, 255, 255, 0))
	surface.SetDrawColor(WIN.frameBorder)
	surface.DrawOutlinedRect(x, y, width, height, 1)

	local app = window.app
	local glyph = app and app.glyph or window.glyph or "list"

	NETWORK.gui.DrawGlyph(glyph, x + Sc(8), y + Sc(7), Sc(14), app and app.color or WIN.title)
	Text(window.title, "nwWinTitle", x + Sc(28), y + math.floor(titleHeight * 0.5) + 1,
		bTop and WIN.title or Color(90, 100, 114))

	self:Hit(x, y, width, titleHeight, function(mouseX, mouseY)
		self:Focus(window)

		if (!window.bMaximized) then
			self.dragging = {window = window, dx = mouseX - window.x, dy = mouseY - window.y}
		end
	end)

	local buttonHeight = Sc(19)
	local closeWidth = Sc(44)
	local smallWidth = Sc(26)
	local buttonY = y + 1
	local closeX = x + width - closeWidth - Sc(6)
	local maxX = closeX - smallWidth
	local minX = maxX - smallWidth

	local function CaptionButton(bx, bw, fill, hoverFill, drawIcon, callback)
		local bHover = Inside(self.mouseX, self.mouseY, bx, buttonY, bw, buttonHeight)

		draw.RoundedBoxEx(Sc(3), bx, buttonY, bw, buttonHeight, bHover and hoverFill or fill,
			false, false, bx == minX, bx == closeX)
		surface.SetDrawColor(WIN.frameBorder)
		surface.DrawOutlinedRect(bx, buttonY, bw, buttonHeight, 1)

		drawIcon(bx + math.floor(bw * 0.5), buttonY + math.floor(buttonHeight * 0.5))

		self:Hit(bx, buttonY, bw, buttonHeight, callback)
	end

	CaptionButton(minX, smallWidth, Color(214, 228, 244), Color(236, 244, 252), function(cx, cy)
		surface.SetDrawColor(WIN.title)
		surface.DrawRect(cx - Sc(4), cy + Sc(3), Sc(9), Sc(2))
	end, function()
		window.bMinimized = true

		surface.PlaySound(SOUNDS.click)
	end)

	CaptionButton(maxX, smallWidth, Color(214, 228, 244), Color(236, 244, 252), function(cx, cy)
		surface.SetDrawColor(WIN.title)
		surface.DrawOutlinedRect(cx - Sc(5), cy - Sc(4), Sc(10), Sc(8), 1)
		surface.DrawRect(cx - Sc(5), cy - Sc(4), Sc(10), Sc(2))
	end, function()
		window.bMaximized = !window.bMaximized

		surface.PlaySound(SOUNDS.click)
	end)

	CaptionButton(closeX, closeWidth, WIN.close, WIN.closeHover, function(cx, cy)
		util.DrawThickLine(cx - Sc(4), cy - Sc(4), cx + Sc(4), cy + Sc(4), 2, Color(255, 255, 255))
		util.DrawThickLine(cx + Sc(4), cy - Sc(4), cx - Sc(4), cy + Sc(4), 2, Color(255, 255, 255))
	end, function()
		self:CloseWindow(window)
	end)

	local bodyX = x + frame
	local bodyY = y + titleHeight
	local bodyWidth = width - frame * 2
	local bodyHeight = height - titleHeight - frame
	local menuHeight = app and Sc(20) or 0
	local statusHeight = app and Sc(20) or 0

	Box(bodyX, bodyY, bodyWidth, bodyHeight, window.bodyColor or WIN.dialog, Color(130, 150, 176))

	if (app) then
		Box(bodyX + 1, bodyY + 1, bodyWidth - 2, menuHeight, Color(240, 240, 240))
		surface.SetDrawColor(WIN.line)
		surface.DrawRect(bodyX + 1, bodyY + menuHeight, bodyWidth - 2, 1)

		local menuX = bodyX + Sc(8)
		local menu = self.menu

		window.menuRects = {}

		for _, item in ipairs(MENU_ITEMS) do
			surface.SetFont("nwWinMenu")

			local itemWidth = surface.GetTextSize(item) + Sc(12)
			local bOpen = menu and menu.window == window and menu.item == item
			local bHover = bTop and Inside(self.mouseX, self.mouseY, menuX, bodyY + 1, itemWidth, menuHeight)

			if (bOpen or bHover) then
				Box(menuX, bodyY + 2, itemWidth, menuHeight - 2, WIN.selection, WIN.selectionBorder)
			end

			if (menu and menu.window == window and bHover and !bOpen) then
				self.menu = {window = window, item = item, x = menuX, y = bodyY + menuHeight}
			end

			Text(item, "nwWinMenu", menuX + Sc(6), bodyY + 1 + math.floor(menuHeight * 0.5), WIN.text)

			local itemX = menuX

			if (bTop) then
				self:Hit(itemX, bodyY + 1, itemWidth, menuHeight, function()
					if (self.menu and self.menu.window == window and self.menu.item == item) then
						self.menu = nil
					else
						self.menu = {window = window, item = item, x = itemX, y = bodyY + menuHeight}

						surface.PlaySound(SOUNDS.menu)
					end
				end)
			end

			menuX = menuX + itemWidth
		end

		local statusY = bodyY + bodyHeight - statusHeight - 1

		Box(bodyX + 1, statusY, bodyWidth - 2, statusHeight, Color(240, 240, 240))
		surface.SetDrawColor(WIN.line)
		surface.DrawRect(bodyX + 1, statusY, bodyWidth - 2, 1)
		Text(window.status or "Готово", "nwWinTray", bodyX + Sc(8), statusY + math.floor(statusHeight * 0.5),
			WIN.textDim)
		surface.SetDrawColor(WIN.line)
		surface.DrawRect(bodyX + bodyWidth - Sc(120), statusY + Sc(3), 1, statusHeight - Sc(6))
		Text(os.date("%H:%M"), "nwWinTray", bodyX + bodyWidth - Sc(8),
			statusY + math.floor(statusHeight * 0.5), WIN.textDim, TEXT_ALIGN_RIGHT)

		surface.SetDrawColor(160, 160, 160)

		for line = 0, 2 do
			surface.DrawLine(bodyX + bodyWidth - Sc(4) - line * 3, bodyY + bodyHeight - 2,
				bodyX + bodyWidth - 2, bodyY + bodyHeight - Sc(4) - line * 3)
		end
	end

	bodyY = bodyY + menuHeight
	bodyHeight = bodyHeight - menuHeight - statusHeight

	window.scrollAreas = {}

	local screenX, screenY = self:LocalToScreen(bodyX, bodyY)
	local sx, sy, sw, sh = self:GetScreen()
	local clipX, clipY = self:LocalToScreen(sx, sy)

	render.SetScissorRect(math.max(screenX, clipX), math.max(screenY, clipY),
		math.min(screenX + bodyWidth, clipX + sw), math.min(screenY + bodyHeight, clipY + sh), true)

	local painter = app and app.Paint or window.Paint
	local firstHit = #self.hits + 1

	if (painter) then
		painter(self, window, bodyX + 1, bodyY + 1, bodyWidth - 2, bodyHeight - 2)
	end

	for index = firstHit, #self.hits do
		local callback = self.hits[index][5]

		self.hits[index][5] = function(...)
			self:Focus(window)

			return callback(...)
		end
	end

	render.SetScissorRect(clipX, clipY, clipX + sw, clipY + sh, true)

	if (bTop and self.menu and self.menu.window == window) then
		self:PaintMenu(window, app)
	end
end

function PANEL:GetMenuEntries(window, app, item)
	if (item == "Файл") then
		return {
			{"Обновить", function()
				if (app and app.OnOpen) then
					app.OnOpen(self, window)
				end

				window.status = "Данные обновлены"
			end},
			{"Свернуть", function()
				window.bMinimized = true
			end},
			{},
			{"Закрыть", function()
				self:CloseWindow(window)
			end}
		}
	end

	if (item == "Правка") then
		return {
			{"Очистить поля", function()
				for _, entry in pairs(window.inputs) do
					if (IsValid(entry)) then
						entry:SetValue("")
					end
				end

				window.status = "Поля очищены"
			end},
			{"Выделить всё", function()
				for _, entry in pairs(window.inputs) do
					if (IsValid(entry) and entry:HasFocus()) then
						entry:SelectAllText()
					end
				end
			end}
		}
	end

	if (item == "Вид") then
		return {
			{window.bMaximized and "Восстановить" or "Развернуть", function()
				window.bMaximized = !window.bMaximized
			end},
			{"По центру", function()
				local sx, sy, sw, sh = self:GetScreen()

				window.bMaximized = false
				window.x = sx + math.floor((sw - window.width) * 0.5)
				window.y = sy + math.floor((sh - window.height) * 0.5) - Sc(20)
			end},
			{"Поверх всех", function()
				self:Focus(window)
			end}
		}
	end

	return {
		{"О программе", function()
			self:Toast((app and app.title or window.title) .. " — C24 Municipal Suite 2.15")
		end},
		{"О компьютере", function()
			self:Toast("Узел " .. (self.nodeTag or "24-ADM-") ..
				(IsValid(self.entity) and self.entity:EntIndex() or 0) .. " · CMB-8000 · 40 ГБ")
		end}
	}
end

function PANEL:PaintMenu(window, app)
	local menu = self.menu
	local entries = self:GetMenuEntries(window, app, menu.item)
	local rowHeight = Sc(22)
	local width = Sc(170)
	local height = Sc(6)

	for _, entry in ipairs(entries) do
		height = height + (entry[1] and rowHeight or Sc(7))
	end

	local x, y = menu.x, menu.y

	menu.width, menu.height = width, height

	NETWORK.util.DrawSoftLight(x + math.floor(width * 0.5), y + math.floor(height * 0.5), width * 1.3,
		height * 1.5, Color(0, 0, 0), 90)
	Box(x, y, width, height, Color(240, 240, 240), Color(151, 151, 151))
	surface.SetDrawColor(WIN.line)
	surface.DrawRect(x + Sc(26), y + Sc(3), 1, height - Sc(6))

	self:Hit(x, y, width, height, function() end)

	local cursor = y + Sc(3)

	for _, entry in ipairs(entries) do
		if (!entry[1]) then
			surface.SetDrawColor(WIN.line)
			surface.DrawRect(x + Sc(30), cursor + Sc(3), width - Sc(36), 1)

			cursor = cursor + Sc(7)

			continue
		end

		local bHover = Inside(self.mouseX, self.mouseY, x + Sc(2), cursor, width - Sc(4), rowHeight)

		if (bHover) then
			Box(x + Sc(2), cursor, width - Sc(4), rowHeight, WIN.selection, WIN.selectionBorder)
		end

		Text(entry[1], "nwWinMenu", x + Sc(34), cursor + math.floor(rowHeight * 0.5), WIN.text)

		local callback = entry[2]

		self:Hit(x + Sc(2), cursor, width - Sc(4), rowHeight, function()
			self.menu = nil

			surface.PlaySound(SOUNDS.click)
			callback()
		end)

		cursor = cursor + rowHeight
	end
end

function PANEL:GetTaskOrder()
	local list = {}

	for _, window in ipairs(self.windows) do
		list[#list + 1] = window
	end

	table.sort(list, function(a, b)
		return a.born < b.born
	end)

	return list
end

function PANEL:PaintTaskbar()
	local util = NETWORK.util
	local x, y, width, height = self:GetTaskbar()

	self.paintOwner = nil

	util.DrawVGradient(x, y, width, height, Color(46, 78, 120, 236), Color(20, 34, 58, 240))
	util.DrawVGradient(x, y, width, math.floor(height * 0.45), Color(255, 255, 255, 46),
		Color(255, 255, 255, 0))
	surface.SetDrawColor(255, 255, 255, 70)
	surface.DrawRect(x, y, width, 1)

	self:Hit(x, y, width, height, function() end)

	local orb = Sc(34)
	local orbX = x + Sc(8) + math.floor(orb * 0.5)
	local orbY = y + math.floor(height * 0.5)
	local bOrbHover = Inside(self.mouseX, self.mouseY, orbX - math.floor(orb * 0.5), y, orb, height)

	util.DrawSoftLight(orbX, orbY, orb * 2, orb * 2, Color(90, 170, 255),
		(self.bStart or bOrbHover) and 110 or 50)
	util.DrawCircle(orbX, orbY, math.floor(orb * 0.5), Color(20, 70, 140))
	util.DrawCircle(orbX, orbY, math.floor(orb * 0.5) - Sc(2),
		(self.bStart or bOrbHover) and Color(60, 150, 240) or Color(40, 110, 200))
	util.DrawArc(orbX, orbY, math.floor(orb * 0.5), 1, 1, Color(200, 230, 255, 180), 48)
	util.DrawCircle(orbX, orbY - Sc(6), Sc(9), Color(255, 255, 255, 40))

	local petal = Sc(6)

	for _, part in ipairs({{-1, -1, Color(240, 90, 60)}, {1, -1, Color(120, 200, 60)},
		{-1, 1, Color(60, 150, 240)}, {1, 1, Color(250, 200, 60)}}) do
		draw.RoundedBox(2, orbX + (part[1] < 0 and -petal - 1 or 1), orbY + (part[2] < 0 and -petal - 1 or 1),
			petal, petal, part[3])
	end

	self:Hit(orbX - math.floor(orb * 0.5), y, orb + Sc(4), height, function()
		self.bStart = !self.bStart

		surface.PlaySound(SOUNDS.click)
	end)

	local cursor = x + Sc(60)
	local top = self.windows[#self.windows]

	for _, window in ipairs(self:GetTaskOrder()) do
		local buttonWidth = Sc(170)
		local bActive = window == top and !window.bMinimized
		local bHover = Inside(self.mouseX, self.mouseY, cursor, y + Sc(3), buttonWidth, height - Sc(6))

		if (bActive or bHover) then
			draw.RoundedBox(Sc(3), cursor, y + Sc(3), buttonWidth, height - Sc(6),
				Color(255, 255, 255, bActive and 40 or 24))
			util.DrawRoundedBorder(cursor, y + Sc(3), buttonWidth, height - Sc(6), Sc(3), 1,
				Color(255, 255, 255, 70))
		end

		local app = window.app

		NETWORK.gui.DrawGlyph(app and app.glyph or window.glyph or "list", cursor + Sc(10),
			y + math.floor(height * 0.5) - Sc(7), Sc(14), Color(210, 230, 250))
		Text(util.TruncateWidth(window.title, "nwWinText", buttonWidth - Sc(40)), "nwWinText",
			cursor + Sc(32), y + math.floor(height * 0.5), Color(240, 244, 250))

		self:Hit(cursor, y + Sc(3), buttonWidth, height - Sc(6), function()
			if (top == window and !window.bMinimized) then
				window.bMinimized = true
			else
				self:Focus(window)
			end

			surface.PlaySound(SOUNDS.click)
		end)

		cursor = cursor + buttonWidth + Sc(4)
	end

	local deskX = x + width - Sc(10)
	local bDeskHover = Inside(self.mouseX, self.mouseY, deskX, y, Sc(10), height)

	Box(deskX, y + 1, Sc(9), height - 2, Color(255, 255, 255, bDeskHover and 60 or 26),
		Color(255, 255, 255, 80))

	self:Hit(deskX, y, Sc(10), height, function()
		surface.PlaySound(SOUNDS.click)

		for _, window in ipairs(self.windows) do
			window.bMinimized = true
		end
	end)

	local right = deskX - Sc(10)

	Text(os.date("%H:%M"), "nwWinText", right, y + Sc(13), Color(255, 255, 255), TEXT_ALIGN_RIGHT)
	Text(os.date("%d.%m.%Y"), "nwWinTray", right, y + Sc(28), Color(255, 255, 255),
		TEXT_ALIGN_RIGHT)

	local trayX = right - Sc(80)
	local middle = y + math.floor(height * 0.5)

	Text("RU", "nwWinTray", trayX, middle, Color(255, 255, 255), TEXT_ALIGN_RIGHT)

	trayX = trayX - Sc(30)
	draw.NoTexture()
	surface.SetDrawColor(230, 236, 244)
	surface.DrawPoly({{x = trayX, y = middle - 3}, {x = trayX + 4, y = middle - 3},
		{x = trayX + 9, y = middle - 8}, {x = trayX + 9, y = middle + 8}, {x = trayX + 4, y = middle + 3},
		{x = trayX, y = middle + 3}})
	util.DrawArc(trayX + 9, middle, Sc(6), 1, 0.3, Color(230, 236, 244), 16, -54)

	trayX = trayX - Sc(30)

	for bar = 1, 5 do
		surface.SetDrawColor(230, 236, 244)
		surface.DrawRect(trayX + bar * 3, middle + 7 - bar * 3, 2, bar * 3)
	end

	trayX = trayX - Sc(24)
	Text("▲", "nwWinTray", trayX, middle, Color(230, 236, 244), TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 40)
	surface.DrawRect(trayX + Sc(12), y + Sc(6), 1, height - Sc(12))
end

function PANEL:PaintStart()
	local util = NETWORK.util
	local x, y, width, height = self:GetStartRect()
	local client = LocalPlayer()
	local leftWidth = math.floor(width * 0.58)

	self.paintOwner = nil

	util.DrawSoftLight(x + math.floor(width * 0.5), y + math.floor(height * 0.5), width * 1.3,
		height * 1.2, Color(0, 0, 0), 150)

	draw.RoundedBoxEx(Sc(8), x, y, width, height, Color(40, 70, 110, 245), true, true, false, false)
	surface.SetDrawColor(WIN.frameBorder)
	surface.DrawOutlinedRect(x, y, width, height, 1)

	self:Hit(x, y, width, height, function() end)

	Box(x + Sc(8), y + Sc(8), leftWidth - Sc(8), height - Sc(56), WIN.body, Color(120, 140, 170))

	for index, id in ipairs(self:GetAppOrder()) do
		local app = APPS[id]
		local rowY = y + Sc(14) + (index - 1) * Sc(44)
		local rowX = x + Sc(14)
		local rowWidth = leftWidth - Sc(20)
		local bHover = Inside(self.mouseX, self.mouseY, rowX, rowY, rowWidth, Sc(40))

		if (bHover) then
			Box(rowX, rowY, rowWidth, Sc(40), WIN.selection, WIN.selectionBorder)
		end

		draw.RoundedBox(Sc(5), rowX + Sc(6), rowY + Sc(6), Sc(28), Sc(28), app.color)
		NETWORK.gui.DrawGlyph(app.glyph, rowX + Sc(13), rowY + Sc(13), Sc(14), Color(255, 255, 255))
		Text(app.title, "nwWinText", rowX + Sc(44), rowY + Sc(20), WIN.text)

		self:Hit(rowX, rowY, rowWidth, Sc(40), function()
			self.bStart = false
			self:OpenApp(id)
		end)
	end

	local rightX = x + leftWidth + Sc(12)
	local name = client:GetCharacterName()

	draw.RoundedBox(Sc(6), rightX, y + Sc(12), Sc(60), Sc(60), Color(255, 255, 255, 40))
	util.DrawCircle(rightX + Sc(30), y + Sc(42), Sc(24), Color(60, 140, 220))
	Text(util.Upper(util.Sub(name, 1, 1)), "nwWinHeader", rightX + Sc(30), y + Sc(42),
		Color(255, 255, 255), TEXT_ALIGN_CENTER)

	for index, line in ipairs(util.WrapText(name, "nwWinBold", width - leftWidth - Sc(24), 2)) do
		Text(line, "nwWinBold", rightX, y + Sc(90) + (index - 1) * Sc(18), Color(255, 255, 255))
	end

	local roleLines = self.roleLines or {"Городская", "Администрация"}

	Text(roleLines[1] or "", "nwWinText", rightX, y + Sc(136), Color(200, 220, 240))
	Text(roleLines[2] or "", "nwWinText", rightX, y + Sc(154), Color(200, 220, 240))

	local powerWidth = Sc(120)
	local powerX = x + width - powerWidth - Sc(12)
	local powerY = y + height - Sc(40)

	self:Button(powerX, powerY, powerWidth, Sc(28), "Выключение", function()
		self:Close()
	end)
end

function PANEL:PaintToasts()
	local x, y, width = self:GetTaskbar()

	for index, toast in ipairs(self.toasts) do
		local age = RealTime() - toast.born
		local fade = math.Clamp(age / 0.3, 0, 1) * math.Clamp((5 - age) / 0.5, 0, 1)
		local toastWidth = Sc(300)
		local toastHeight = Sc(64)
		local toastX = x + width - toastWidth - Sc(12)
		local toastY = y - (toastHeight + Sc(8)) * index + math.Round((1 - fade) * Sc(20))

		draw.RoundedBox(Sc(4), toastX, toastY, toastWidth, toastHeight, Color(255, 255, 225, 250 * fade))
		surface.SetDrawColor(118, 118, 118, 255 * fade)
		surface.DrawOutlinedRect(toastX, toastY, toastWidth, toastHeight, 1)

		NETWORK.util.DrawCircle(toastX + Sc(22), toastY + Sc(22), Sc(10), Color(40, 120, 210, 255 * fade))
		Text("i", "nwWinBold", toastX + Sc(22), toastY + Sc(22), Color(255, 255, 255, 255 * fade),
			TEXT_ALIGN_CENTER)
		Text(self.orgName and (self.orgName .. " C24") or "Администрация C24", "nwWinBold",
			toastX + Sc(40), toastY + Sc(20), Color(0, 0, 0, 255 * fade))
		Text(NETWORK.util.TruncateWidth(toast.text, "nwWinText", toastWidth - Sc(52)), "nwWinText",
			toastX + Sc(40), toastY + Sc(42), Color(30, 30, 30, 255 * fade))
	end
end

function PANEL:PaintZooms()
	for _, zoom in ipairs(self.zooms) do
		local progress = math.Clamp((RealTime() - zoom.born) / 0.28, 0, 1)
		local from = zoom.from
		local to = zoom.to

		for step = 0, 4 do
			local t = math.Clamp(progress - step * 0.08, 0, 1)

			if (t <= 0 or t >= 1) then
				continue
			end

			local x = Lerp(t, from[1], to.x)
			local y = Lerp(t, from[2], to.y)
			local width = Lerp(t, from[3], to.width)
			local height = Lerp(t, from[4], to.height)

			surface.SetDrawColor(0, 0, 0, 200)
			surface.DrawOutlinedRect(x, y, width, height, 2)
			surface.SetDrawColor(255, 255, 255, 160)
			surface.DrawOutlinedRect(x + 2, y + 2, width - 4, height - 4, 1)
		end
	end
end

function PANEL:PaintBoot(x, y, width, height)
	local util = NETWORK.util
	local age = RealTime() - self.born

	Box(x, y, width, height, Color(0, 0, 0))

	if (age < 1.4) then
		local lines = {
			"C24 Municipal BIOS v2.15  (C) Citadel Systems",
			"CPU: CMB-8000 @ 2.40 GHz",
			"Memory Test: " .. math.min(math.floor(age / 0.9 * 4096), 4096) .. " KB OK",
			"Detecting IDE drives ... HDD0: ADMIN-C24 40 GB",
			"Network: link up, node " .. (self.nodeTag or "24-ADM-") ..
				(IsValid(self.entity) and self.entity:EntIndex() or 0),
			"",
			"Boot from HDD0 ..."
		}

		for index, line in ipairs(lines) do
			if (age > (index - 1) * 0.16) then
				Text(line, "nwWinMono", x + Sc(16), y + Sc(16) + (index - 1) * Sc(20), Color(190, 190, 190))
			end
		end

		if (math.floor(age * 4) % 2 == 0) then
			Box(x + Sc(16), y + Sc(16) + #lines * Sc(20) - Sc(6), Sc(9), Sc(14), Color(190, 190, 190))
		end

		Text("Press DEL to enter SETUP", "nwWinMono", x + width - Sc(16), y + height - Sc(20),
			Color(120, 120, 120), TEXT_ALIGN_RIGHT)

		return
	end

	if (age < 2.5) then
		local centerX = x + math.floor(width * 0.5)
		local centerY = y + math.floor(height * 0.55)
		local barWidth = Sc(220)

		Text("Запуск ОС Администрации C24", "nwWinHeader", centerX, centerY - Sc(50),
			Color(230, 230, 230), TEXT_ALIGN_CENTER)
		Box(centerX - math.floor(barWidth * 0.5), centerY, barWidth, Sc(14), Color(0, 0, 0),
			Color(120, 120, 120))

		for step = 0, 2 do
			local segX = ((age * 220 + step * Sc(24)) % (barWidth + Sc(40))) - Sc(20)

			Box(centerX - math.floor(barWidth * 0.5) + 2 + math.max(segX, 0), centerY + 2,
				math.min(Sc(18), barWidth - 4 - math.max(segX, 0)), Sc(10), Color(60, 150, 240))
		end

		Text("© " .. (self.orgName or "Городская Администрация"), "nwWinSmall", centerX,
			y + height - Sc(30), Color(140, 140, 140), TEXT_ALIGN_CENTER)

		return
	end

	util.DrawVGradient(x, y, width, height, WIN.desktopTop, WIN.desktopBottom)

	local centerX = x + math.floor(width * 0.5)
	local centerY = y + math.floor(height * 0.42)
	local name = LocalPlayer():GetCharacterName()

	draw.RoundedBox(Sc(8), centerX - Sc(60), centerY - Sc(60), Sc(120), Sc(120),
		Color(255, 255, 255, 60))
	util.DrawCircle(centerX, centerY, Sc(48), Color(60, 140, 220))
	Text(util.Upper(util.Sub(name, 1, 1)), "nwBrand", centerX, centerY, Color(255, 255, 255),
		TEXT_ALIGN_CENTER)

	util.DrawSimpleTextShadow(name, "nwWinHeader", centerX, centerY + Sc(88),
		Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
	util.DrawSimpleTextShadow("Добро пожаловать", "nwWinText", centerX, centerY + Sc(116),
		Color(220, 235, 250), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)

	util.DrawArc(centerX - Sc(80), centerY + Sc(116), Sc(8), math.max(Sc(2), 2), 0.35,
		Color(255, 255, 255), 24, (age * 450) % 360)
end

function PANEL:Paint(width, height)
	local util = NETWORK.util
	local alpha = util.EaseOut(self.alpha)

	self:SetAlpha(math.Round(alpha * 255))

	self.paintFrame = self.paintFrame + 1
	self.hits = {}

	surface.SetDrawColor(0, 0, 0, 215)
	surface.DrawRect(0, 0, width, height)

	local sx, sy, sw, sh = self:GetScreen()
	local bezel = Sc(20)
	local chin = Sc(34)
	local caseX, caseY = sx - bezel, sy - bezel
	local caseW, caseH = sw + bezel * 2, sh + bezel + chin

	local standW, standH = Sc(260), Sc(14)
	local neckW, neckH = Sc(90), Sc(46)
	local standX = sx + math.floor((sw - standW) * 0.5)
	local standY = caseY + caseH + neckH

	util.DrawSoftLight(sx + math.floor(sw * 0.5), standY + Sc(30), standW * 1.6, Sc(80),
		Color(0, 0, 0), 180)
	util.DrawVGradient(sx + math.floor((sw - neckW) * 0.5), caseY + caseH, neckW, neckH,
		Color(40, 42, 46), Color(22, 23, 26))
	draw.RoundedBox(Sc(6), standX, standY, standW, standH, Color(34, 36, 40))
	util.DrawVGradient(standX + Sc(6), standY + 1, standW - Sc(12), math.floor(standH * 0.5),
		Color(255, 255, 255, 40), Color(255, 255, 255, 0))

	draw.RoundedBox(Sc(10), caseX + Sc(4), caseY + Sc(8), caseW, caseH, Color(0, 0, 0, 120))
	util.DrawVGradient(caseX, caseY, caseW, caseH, Color(38, 40, 44), Color(20, 21, 24))
	draw.RoundedBox(Sc(10), caseX, caseY, caseW, caseH, Color(28, 29, 33))
	util.DrawRoundedBorder(caseX, caseY, caseW, caseH, Sc(10), 1, Color(70, 72, 78))
	util.DrawVGradient(caseX + Sc(10), caseY + 1, caseW - Sc(20), Sc(10), Color(255, 255, 255, 30),
		Color(255, 255, 255, 0))

	surface.SetDrawColor(8, 8, 10)
	surface.DrawOutlinedRect(sx - 2, sy - 2, sw + 4, sh + 4, 2)

	local chinY = sy + sh + Sc(6)

	Text("C24 · ADMINISTRATION", "nwWinSmall", sx + Sc(6), chinY + Sc(12), Color(130, 134, 142))

	local buttonX = sx + sw - Sc(160)

	for _, label in ipairs({"MENU", "◄", "►", "AUTO"}) do
		Box(buttonX, chinY + Sc(6), Sc(28), Sc(12), Color(40, 42, 48), Color(60, 62, 70))
		Text(label, "nwWinTray", buttonX + Sc(14), chinY + Sc(12), Color(150, 154, 162), TEXT_ALIGN_CENTER)

		buttonX = buttonX + Sc(32)
	end

	local ledX = sx + sw - Sc(12)
	local ledY = chinY + Sc(12)

	util.DrawSoftLight(ledX, ledY, Sc(24), Sc(24), Color(80, 220, 120), 120)
	util.DrawCircle(ledX, ledY, Sc(3), Color(120, 240, 150))

	local clipX, clipY = self:LocalToScreen(sx, sy)

	render.SetScissorRect(clipX, clipY, clipX + sw, clipY + sh, true)

	local top = self.windows[#self.windows]

	if (self:IsBooting()) then
		self:PaintBoot(sx, sy, sw, sh)
	else
		self.paintOwner = nil
		self:PaintDesktop(sx, sy, sw, sh)

		for _, window in ipairs(self.windows) do
			if (!window.bMinimized and RealTime() >= window.born) then
				self:PaintWindow(window, window == top)
			end
		end

		self:PaintZooms()
		self:PaintTaskbar()

		if (self.bStart) then
			self:PaintStart()
		end

		self:PaintToasts()
	end

	NETWORK.util.DrawScanlines(sx, sy, sw, sh + 1, 14, 3)

	local columns = NETWORK.util.GetTexture("framework/pattern/scanv3.png")

	surface.SetDrawColor(0, 0, 0, 6)

	if (columns) then
		NETWORK.util.DrawTiled(columns, sx, sy, sw + 1, sh)
		draw.NoTexture()
	else
		for column = sx, sx + sw, 3 do
			surface.DrawRect(column, sy, 1, sh)
		end
	end

	util.DrawHGradient(sx, sy, math.floor(sw * 0.4), sh, Color(255, 255, 255, 10),
		Color(255, 255, 255, 0))
	util.DrawVGradient(sx, sy, sw, math.floor(sh * 0.25), Color(255, 255, 255, 12),
		Color(255, 255, 255, 0))
	util.DrawVignette(sx, sy, sw, sh, math.floor(math.min(sw, sh) * 0.22), 70)

	render.SetScissorRect(0, 0, 0, 0, false)

	for _, window in ipairs(self.windows) do
		for _, entry in pairs(window.inputs) do
			if (IsValid(entry)) then
				local bVisible = entry.placed == self.paintFrame and window == top and
					!window.bMinimized and !self.bStart and !self:IsBooting()

				if (entry:IsVisible() != bVisible) then
					entry:SetVisible(bVisible)
				end
			end
		end
	end
end

function PANEL:PaintOver(width, height)
	local hovered = vgui.GetHoveredPanel()
	local bText = IsValid(hovered) and hovered:GetClassName() == "TextEntry"

	DrawCursor(self.mouseX, self.mouseY, self.busyUntil > RealTime() or self:IsBooting(), bText)
end

local function Field(label, value, x, y, width, color)
	Text(label, "nwWinText", x, y, WIN.textDim)
	Text(NETWORK.util.TruncateWidth(tostring(value or "—"), "nwWinBold", width - Sc(140)),
		"nwWinBold", x + Sc(140), y, color or WIN.text)
end

function PANEL:OpenRecord(record)
	local from = self.recordFrom or {self.mouseX, self.mouseY, 2, 2}

	self.recordFrom = nil
	self.busyUntil = 0

	local window = self:CreateWindow("record" .. record.id, "Досье: " .. record.name, 560, 600, from,
		{glyph = "person", record = record, bodyColor = WIN.body})

	window.Paint = function(panel, win, x, y, width, height)
		local data = win.record
		local util = NETWORK.util
		local scroll = win.state.scroll or 0
		local cursor = y + Sc(16) - scroll

		local photo = Sc(110)

		Box(x + Sc(16), cursor, photo, math.floor(photo * 1.25), Color(226, 230, 236),
			Color(160, 170, 180))

		local body = NETWORK.medical and NETWORK.medical.body

		if (body and body.IsAvailable()) then
			local bx, by, bw, bh = body.GetRect(x + Sc(24), cursor + Sc(8), photo - Sc(16),
				math.floor(photo * 1.8))
			local screenX, screenY = panel:LocalToScreen(x + Sc(16), cursor)
			local oldX, oldY = panel:LocalToScreen(x, y)

			render.SetScissorRect(math.max(screenX, oldX), math.max(screenY, oldY),
				screenX + photo, screenY + math.floor(photo * 1.25), true)
			body.Draw(bx, by, bw, bh, nil, 1, Color(120, 128, 140))
			render.SetScissorRect(oldX, oldY, oldX + width, oldY + height, true)
		end

		local infoX = x + photo + Sc(32)
		local infoWidth = width - photo - Sc(48)

		Text(data.name, "nwWinHeader", infoX, cursor + Sc(12), WIN.text)
		Field("CID", "#" .. data.cid, infoX, cursor + Sc(44), infoWidth)
		Field("Фракция", data.faction, infoX, cursor + Sc(66), infoWidth)
		Field("Класс", data.class != "" and data.class or "—", infoX, cursor + Sc(88), infoWidth)
		Field("Статус", data.bOnline and "в сети" or ("не в сети, был " .. data.lastUsed), infoX,
			cursor + Sc(110), infoWidth, data.bOnline and WIN.good or WIN.textDim)
		Field("Регистрация", data.created, infoX, cursor + Sc(132), infoWidth)

		cursor = cursor + math.floor(photo * 1.25) + Sc(20)

		local function Section(title)
			NETWORK.util.DrawHGradient(x + Sc(12), cursor, width - Sc(24), Sc(24),
				Color(220, 232, 246), Color(255, 255, 255))
			Text(title, "nwWinBold", x + Sc(18), cursor + Sc(12), Color(20, 60, 110))

			cursor = cursor + Sc(32)
		end

		Section("Лояльность (ОЛ)")

		local bandColor = Color(data.bandColor[1], data.bandColor[2], data.bandColor[3])
		local fraction = (data.loyalty - NETWORK.loyalty.min) /
			(NETWORK.loyalty.max - NETWORK.loyalty.min)
		local barWidth = width - Sc(48)

		Text(data.loyalty .. " ОЛ — " .. data.band, "nwWinBold", x + Sc(20), cursor + Sc(8),
			WIN.text)
		Box(x + Sc(20), cursor + Sc(22), barWidth, Sc(14), Color(230, 230, 230), Color(160, 160, 160))
		Box(x + Sc(21), cursor + Sc(23), math.floor((barWidth - 2) * fraction), Sc(12), bandColor)

		cursor = cursor + Sc(50)

		Section("Документы и имущество")

		Field("Жильё", data.housing != "" and data.housing or "не назначено", x + Sc(20),
			cursor + Sc(8), width - Sc(40))
		cursor = cursor + Sc(22)

		local business = data.business
		local statusText = {pending = "на рассмотрении", approved = "одобрен", denied = "отклонён"}

		Field("Бизнес", business and (business.what .. " (" ..
			(statusText[business.status] or business.status) .. ")") or "нет", x + Sc(20),
			cursor + Sc(8), width - Sc(40))
		cursor = cursor + Sc(22)

		if (#data.cards == 0) then
			Field("ID-карты", "нет", x + Sc(20), cursor + Sc(8), width - Sc(40))
			cursor = cursor + Sc(22)
		end

		for index, card in ipairs(data.cards) do
			Field(index == 1 and "ID-карты" or "", card.serial .. "  от " .. card.issued ..
				(card.bValid and "  — действует" or "  — аннулирована"), x + Sc(20), cursor + Sc(8),
				width - Sc(40), card.bValid and WIN.good or WIN.bad)
			cursor = cursor + Sc(22)
		end

		cursor = cursor + Sc(12)

		Section("Нарушения (" .. #data.violations .. ")")

		if (#data.violations == 0) then
			Text("Нарушений не зафиксировано.", "nwWinText", x + Sc(20), cursor + Sc(8), WIN.good)
			cursor = cursor + Sc(26)
		end

		for index, entry in ipairs(data.violations) do
			Text(index .. ". " .. entry.reason, "nwWinText", x + Sc(20), cursor + Sc(8), WIN.bad)
			Text(entry.term .. " мин. " .. entry.time, "nwWinText", x + width - Sc(20),
				cursor + Sc(8), WIN.textDim, TEXT_ALIGN_RIGHT)
			cursor = cursor + Sc(22)
		end

		cursor = cursor + Sc(12)

		Section("Заметки сотрудников (" .. #data.notes .. ")")

		if (#data.notes == 0) then
			Text("Заметок нет.", "nwWinText", x + Sc(20), cursor + Sc(8), WIN.textDim)
			cursor = cursor + Sc(26)
		end

		for _, note in ipairs(data.notes) do
			Text(note.author .. " — " .. note.time, "nwWinBold", x + Sc(20), cursor + Sc(8), WIN.text)
			cursor = cursor + Sc(20)

			for _, line in ipairs(util.WrapText(note.text, "nwWinText", width - Sc(48), 4)) do
				Text(line, "nwWinText", x + Sc(28), cursor + Sc(8), WIN.textDim)
				cursor = cursor + Sc(18)
			end

			cursor = cursor + Sc(6)
		end

		local total = cursor + scroll - y + Sc(20)

		win.state.scroll = math.Clamp(scroll, 0, math.max(total - height, 0))
	end
end

APPS.database = {
	title = "База данных C24",
	glyph = "person",
	color = Color(40, 110, 190),
	width = 820,
	height = 540,
	OnOpen = function(panel, window)
		window.state.category = "alliance"
		panel:Request("db_list")
	end,
	Paint = function(panel, window, x, y, width, height)
		local data = panel.data.database
		local list = data and data.list or {}
		local treeWidth = Sc(200)
		local categories = {
			{"alliance", "Сотрудники Альянса"},
			{"cwu", "Сотрудники ГСР"},
			{"citizens", "Граждане (ID-карты)"}
		}

		NETWORK.util.DrawVGradient(x, y, width, Sc(40), Color(250, 250, 250), Color(232, 236, 242))
		surface.SetDrawColor(WIN.line)
		surface.DrawRect(x, y + Sc(40), width, 1)

		panel:Input(window, "search", x + treeWidth + Sc(10), y + Sc(8), Sc(260), Sc(24),
			"Поиск: имя или CID")
		panel:Button(x + width - Sc(110), y + Sc(7), Sc(100), Sc(26), "Обновить", function()
			panel:Request("db_list")
		end)

		Box(x + Sc(6), y + Sc(48), treeWidth - Sc(6), height - Sc(54), WIN.body, Color(130, 135, 144))
		Text("База данных C24", "nwWinBold", x + Sc(14), y + Sc(62), WIN.text)

		for index, category in ipairs(categories) do
			local rowY = y + Sc(76) + (index - 1) * Sc(26)
			local bActive = window.state.category == category[1]
			local count = #(list[category[1]] or {})

			if (bActive) then
				Box(x + Sc(12), rowY, treeWidth - Sc(20), Sc(24), WIN.selection, WIN.selectionBorder)
			end

			NETWORK.gui.DrawGlyph("list", x + Sc(20), rowY + Sc(6), Sc(12), Color(200, 150, 40))
			Text(category[2] .. " (" .. count .. ")", "nwWinText", x + Sc(38), rowY + Sc(12), WIN.text)

			panel:Hit(x + Sc(12), rowY, treeWidth - Sc(20), Sc(24), function()
				surface.PlaySound(SOUNDS.click)
				window.state.category = category[1]
				window.state.selected = nil
			end)
		end

		local query = string.lower(panel:GetInputValue(window, "search"))
		local rows = {}

		window.state.selectedRow = nil

		for _, entry in ipairs(list[window.state.category] or {}) do
			if (query == "" or string.find(string.lower(entry.name), query, 1, true) or
				string.find(entry.cid, query, 1, true)) then
				rows[#rows + 1] = {
					entry = entry,
					cells = {entry.name, "#" .. entry.cid, entry.faction,
						entry.bOnline and "в сети" or "—"},
					colors = {nil, nil, nil, entry.bOnline and WIN.good or WIN.textDim}
				}

				if (window.state.selected == entry.id) then
					window.state.selectedRow = rows[#rows]
				end
			end
		end

		if (!data) then
			Text("Загрузка данных…", "nwWinText", x + treeWidth + Sc(20), y + Sc(80), WIN.textDim)
		end

		panel:ListView(window, "people", x + treeWidth + Sc(6), y + Sc(48),
			width - treeWidth - Sc(12), height - Sc(80),
			{{"ФИО", 0}, {"CID", 0.44}, {"Фракция", 0.6}, {"Статус", 0.84}}, rows,
			function(row, rect)
				if (window.state.selected == row.entry.id and
					RealTime() - (window.state.lastClick or 0) < 0.45) then
					panel.recordFrom = rect
					panel:Request("db_record", {id = row.entry.id})
				end

				window.state.selected = row.entry.id
				window.state.lastClick = RealTime()
			end, window.state.selected and window.state.selectedRow)

		Text("Двойной щелчок по записи — открыть досье. Всего: " .. #rows, "nwWinSmall",
			x + treeWidth + Sc(8), y + height - Sc(16), WIN.textDim)
	end
}

APPS.board = {
	title = "Объявления",
	glyph = "radio",
	color = Color(210, 120, 30),
	width = 620,
	height = 520,
	OnOpen = function(panel, window)
		panel:Request("board_list")
	end,
	Paint = function(panel, window, x, y, width, height)
		local util = NETWORK.util
		local messages = panel.data.board and panel.data.board.messages or {}
		local formHeight = Sc(130)
		local listHeight = height - formHeight - Sc(12)

		Box(x + Sc(6), y + Sc(6), width - Sc(12), listHeight, WIN.body, Color(130, 135, 144))

		local cursor = y + listHeight - Sc(4)
		local screenX, screenY = panel:LocalToScreen(x + Sc(6), y + Sc(6))

		for index = #messages, 1, -1 do
			local message = messages[index]
			local lines = util.WrapText(message.text or "", "nwWinText", width - Sc(40), 5)
			local itemHeight = Sc(30) + #lines * Sc(18)

			cursor = cursor - itemHeight - Sc(6)

			if (cursor < y + Sc(8)) then
				break
			end

			Box(x + Sc(12), cursor, width - Sc(24), itemHeight, Color(255, 252, 230),
				Color(220, 200, 140))
			Text(message.author or "?", "nwWinBold", x + Sc(20), cursor + Sc(14), WIN.text)
			Text(message.time or "", "nwWinSmall", x + width - Sc(20), cursor + Sc(14), WIN.textDim,
				TEXT_ALIGN_RIGHT)

			for line, text in ipairs(lines) do
				Text(text, "nwWinText", x + Sc(20), cursor + Sc(16) + line * Sc(18), WIN.text)
			end
		end

		if (#messages == 0) then
			Text("Объявлений пока нет.", "nwWinText", x + Sc(20), y + Sc(30), WIN.textDim)
		end

		local formY = y + listHeight + Sc(12)

		Text("Новое объявление (увидят все терминалы города):", "nwWinText", x + Sc(8),
			formY + Sc(6), WIN.text)
		panel:Input(window, "text", x + Sc(8), formY + Sc(18), width - Sc(16), Sc(66), "",
			true)
		panel:Button(x + width - Sc(148), formY + Sc(92), Sc(140), Sc(28), "Опубликовать",
			function()
				local text = panel:GetInputValue(window, "text")

				if (string.Trim(text) == "") then
					surface.PlaySound(SOUNDS.error)

					return
				end

				panel:Request("board_post", {text = text})
				panel:SetInputValue(window, "text", "")
			end, true)
	end
}

APPS.call = {
	title = "Вызов",
	glyph = "shield",
	color = Color(180, 60, 60),
	width = 520,
	height = 400,
	OnOpen = function(panel, window)
		panel:Request("call_state")
	end,
	Paint = function(panel, window, x, y, width, height)
		local util = NETWORK.util
		local state = panel.data.call or {}
		local log = state.log or {}

		Text("Причина вызова (увидят бойцы):", "nwWinText", x + Sc(8), y + Sc(12), WIN.text)
		panel:Input(window, "reason", x + Sc(8), y + Sc(24), width - Sc(16), Sc(28),
			"например: беспорядки у терминала")

		local buttonWidth = math.floor((width - Sc(24)) * 0.5)
		local bCooldown = (state.nextCall or 0) > CurTime()

		panel:Button(x + Sc(8), y + Sc(62), buttonWidth, Sc(34), "Вызвать Гражданскую Оборону",
			function()
				panel:Request("call_send", {faction = "cp",
					reason = panel:GetInputValue(window, "reason")})
			end, true, bCooldown)

		panel:Button(x + Sc(16) + buttonWidth, y + Sc(62), buttonWidth, Sc(34), "Вызвать ОТА",
			function()
				panel:Request("call_send", {faction = "cmb",
					reason = panel:GetInputValue(window, "reason")})
			end, false, bCooldown)

		if (bCooldown) then
			Text(string.format("Повторный вызов через %d с", math.ceil(state.nextCall - CurTime())),
				"nwWinSmall", x + Sc(8), y + Sc(106), WIN.warn)
		else
			Text(string.format("В сети: ГО — %d, ОТА — %d", state.cpOnline or 0, state.cmbOnline or 0),
				"nwWinSmall", x + Sc(8), y + Sc(106), WIN.textDim)
		end

		local listY = y + Sc(124)
		local listHeight = height - Sc(132)

		Box(x + Sc(6), listY, width - Sc(12), listHeight, WIN.body, Color(130, 135, 144))
		Text("Журнал вызовов", "nwWinBold", x + Sc(14), listY + Sc(14), WIN.text)

		local cursor = listY + Sc(30)

		for index = #log, math.max(#log - 7, 1), -1 do
			local entry = log[index]

			if (cursor > listY + listHeight - Sc(16)) then
				break
			end

			Text(entry.time .. "  " .. entry.faction .. "  ·  " .. entry.who, "nwWinText",
				x + Sc(14), cursor, WIN.text)
			Text(entry.reason, "nwWinSmall", x + Sc(14), cursor + Sc(15), WIN.textDim)

			cursor = cursor + Sc(34)
		end

		if (#log == 0) then
			Text("Вызовов ещё не было.", "nwWinText", x + Sc(14), listY + Sc(40), WIN.textDim)
		end
	end
}

APPS.documents = {
	title = "Документы",
	glyph = "list",
	color = Color(40, 90, 160),
	width = 860,
	height = 580,
	OnOpen = function(panel, window)
		window.state.typeIndex = 1
		panel:Request("doc_state")
	end,
	Paint = function(panel, window, x, y, width, height)
		local data = panel.data.documents or {}
		local types = data.types or {}
		local docType = types[window.state.typeIndex or 1]
		local pageWidth = math.floor(width * 0.6)

		NETWORK.util.DrawVGradient(x, y, width, Sc(70), Color(250, 251, 253), Color(224, 232, 242))
		surface.SetDrawColor(WIN.line)
		surface.DrawRect(x, y + Sc(70), width, 1)

		Text("Тип", "nwWinSmall", x + Sc(10), y + Sc(12), WIN.textDim)

		local typeX, typeY, typeWidth = x + Sc(10), y + Sc(22), Sc(220)

		Box(typeX, typeY, typeWidth, Sc(24), WIN.body, Color(171, 173, 179))
		Text(docType and docType.name or "—", "nwWinText", typeX + Sc(6), typeY + Sc(12), WIN.text)
		Text("▼", "nwWinSmall", typeX + typeWidth - Sc(12), typeY + Sc(12), WIN.text, TEXT_ALIGN_CENTER)

		panel:Hit(typeX, typeY, typeWidth, Sc(24), function()
			surface.PlaySound(SOUNDS.click)
			window.state.bTypes = !window.state.bTypes
		end)

		Text("CID получателя", "nwWinSmall", x + Sc(244), y + Sc(12), WIN.textDim)
		panel:Input(window, "cid", x + Sc(244), typeY, Sc(110), Sc(24), "00000", false, true)
		Text("Имя (если не в сети)", "nwWinSmall", x + Sc(368), y + Sc(12), WIN.textDim)
		panel:Input(window, "holder", x + Sc(368), typeY, Sc(170), Sc(24), "")
		Text("Срок, ч", "nwWinSmall", x + Sc(552), y + Sc(12), WIN.textDim)
		panel:Input(window, "hours", x + Sc(552), typeY, Sc(70), Sc(24),
			docType and tostring(docType.hours) or "0", false, true)

		local pageX = x + Sc(20)
		local pageY = y + Sc(84)
		local pageHeight = height - Sc(140)

		Box(x, y + Sc(71), pageWidth + Sc(40), height - Sc(71), Color(171, 180, 194))
		Box(pageX + 3, pageY + 4, pageWidth, pageHeight, Color(0, 0, 0, 60))
		Box(pageX, pageY, pageWidth, pageHeight, Color(250, 248, 240), Color(150, 150, 150))

		surface.SetDrawColor(200, 200, 200)

		for dot = 0, pageWidth - Sc(32), 6 do
			surface.DrawRect(pageX + Sc(16) + dot, pageY + Sc(64), 3, 1)
		end
		Text("ГОРОДСКАЯ АДМИНИСТРАЦИЯ СИТИ-24", "nwWinBold", pageX + math.floor(pageWidth * 0.5),
			pageY + Sc(20), WIN.text, TEXT_ALIGN_CENTER)
		Text(docType and docType.name or "", "nwWinHeader", pageX + math.floor(pageWidth * 0.5),
			pageY + Sc(48), WIN.text, TEXT_ALIGN_CENTER)
		if (!window.state.bTypes) then
			panel:Input(window, "text", pageX + Sc(20), pageY + Sc(72), pageWidth - Sc(40),
				pageHeight - Sc(90), "Текст документа…", true)
		end

		panel:Button(pageX + pageWidth - Sc(160), y + height - Sc(44), Sc(160), Sc(30),
			"Выдать документ", function()
				panel:Request("doc_issue", {
					type = docType and docType.id,
					cid = panel:GetInputValue(window, "cid"),
					holder = panel:GetInputValue(window, "holder"),
					hours = panel:GetInputValue(window, "hours"),
					text = panel:GetInputValue(window, "text")
				})
			end, true)

		local sideX = x + pageWidth + Sc(52)
		local sideWidth = width - pageWidth - Sc(60)
		local check = data.check

		Text("Проверка по реестру", "nwWinBold", sideX, y + Sc(90), WIN.text)
		panel:Input(window, "serial", sideX, y + Sc(104), sideWidth - Sc(100), Sc(24), "Серия")
		panel:Button(sideX + sideWidth - Sc(94), y + Sc(103), Sc(94), Sc(26), "Проверить",
			function()
				panel:Request("doc_verify", {serial = panel:GetInputValue(window, "serial")})
			end)

		if (check) then
			local texts = {
				valid = {"Действителен", WIN.good},
				expired = {"Просрочен", WIN.warn},
				revoked = {"Аннулирован", WIN.bad},
				missing = {"Не найден — вероятная подделка", WIN.bad}
			}
			local result = texts[check.status] or {check.status, WIN.text}

			Text(check.serial .. ": " .. result[1], "nwWinBold", sideX, y + Sc(144), result[2])

			if (check.holder != "") then
				Text(check.holder .. "  #" .. check.cid, "nwWinText", sideX, y + Sc(162), WIN.textDim)
			end
		end

		Text("Недавние документы", "nwWinBold", sideX, y + Sc(190), WIN.text)

		local rows = {}
		local selectedRow

		for _, entry in ipairs(data.recent or {}) do
			local state = entry.revoked and "аннул." or (entry.expired and "просроч." or "действ.")

			rows[#rows + 1] = {
				entry = entry,
				cells = {entry.serial, entry.holder, state},
				colors = {nil, nil, entry.revoked and WIN.bad or (entry.expired and WIN.warn or WIN.good)}
			}

			if (window.state.selectedDoc == entry.serial) then
				selectedRow = rows[#rows]
			end
		end

		panel:ListView(window, "recent", sideX, y + Sc(204), sideWidth, height - Sc(256),
			{{"Серия", 0}, {"Кому", 0.4}, {"Статус", 0.76}}, rows, function(row)
				window.state.selectedDoc = row.entry.serial
			end, selectedRow)

		panel:Button(sideX, y + height - Sc(44), sideWidth, Sc(30), "Аннулировать выбранный",
			function()
				if (window.state.selectedDoc) then
					panel:Request("doc_revoke", {serial = window.state.selectedDoc})
					window.state.selectedDoc = nil
				end
			end, false, selectedRow == nil)

		if (window.state.bTypes) then
			local listY = typeY + Sc(24)

			Box(typeX, listY, typeWidth, #types * Sc(24) + 2, WIN.body, Color(100, 100, 100))

			for index, entry in ipairs(types) do
				local rowY = listY + 1 + (index - 1) * Sc(24)

				if (Inside(panel.mouseX, panel.mouseY, typeX, rowY, typeWidth, Sc(24))) then
					Box(typeX + 1, rowY, typeWidth - 2, Sc(24), Color(51, 153, 255))
				end

				Text(entry.name, "nwWinText", typeX + Sc(6), rowY + Sc(12), WIN.text)

				panel:Hit(typeX, rowY, typeWidth, Sc(24), function()
					surface.PlaySound(SOUNDS.click)
					window.state.typeIndex = index
					window.state.bTypes = false
					panel:SetInputValue(window, "hours", tostring(entry.hours or 0))
				end)
			end
		end
	end
}

APPS.mail = {
	title = "Почта",
	glyph = "stack",
	color = Color(30, 130, 200),
	width = 900,
	height = 560,
	OnOpen = function(panel, window)
		window.state.folder = "letter"
		panel:Request("mail_list")
	end,
	Paint = function(panel, window, x, y, width, height)
		local util = NETWORK.util
		local letters = panel.data.mail and panel.data.mail.letters or {}
		local folderWidth = Sc(170)
		local listWidth = Sc(290)

		Box(x, y, folderWidth, height, Color(233, 238, 245))
		Text("Почта Администрации", "nwWinBold", x + Sc(10), y + Sc(16), WIN.text)

		for index, folder in ipairs({{"letter", "Входящие"}, {"business", "Заявки на бизнес"},
			{"supply", "Поставки (накладные)"}, {"offer", "Предложения посылок"}}) do
			local rowY = y + Sc(34) + (index - 1) * Sc(28)
			local unread = 0

			for _, letter in ipairs(letters) do
				if (letter.kind == folder[1] and !letter.bRead) then
					unread = unread + 1
				end
			end

			if (window.state.folder == folder[1]) then
				Box(x + Sc(6), rowY, folderWidth - Sc(12), Sc(24), WIN.selection, WIN.selectionBorder)
			end

			Text(folder[2] .. (unread > 0 and (" (" .. unread .. ")") or ""),
				unread > 0 and "nwWinBold" or "nwWinText", x + Sc(14), rowY + Sc(12), WIN.text)

			panel:Hit(x + Sc(6), rowY, folderWidth - Sc(12), Sc(24), function()
				surface.PlaySound(SOUNDS.click)
				window.state.folder = folder[1]
				window.state.letter = nil
			end)
		end

		local rows = {}
		local current

		for _, letter in ipairs(letters) do
			if (letter.kind == window.state.folder) then
				rows[#rows + 1] = {
					letter = letter,
					bBold = !letter.bRead,
					cells = {letter.from, letter.time},
					colors = {nil, WIN.textDim}
				}

				if (window.state.letter == letter.id) then
					current = rows[#rows]
				end
			end
		end

		panel:ListView(window, "letters", x + folderWidth + Sc(4), y + Sc(4), listWidth, height - Sc(8),
			{{"От кого", 0}, {"Когда", 0.62}}, rows, function(row)
				window.state.letter = row.letter.id

				if (!row.letter.bRead) then
					panel:Request("mail_read", {id = row.letter.id})
				end
			end, current)

		local readX = x + folderWidth + listWidth + Sc(12)
		local readWidth = width - folderWidth - listWidth - Sc(16)

		Box(readX, y + Sc(4), readWidth, height - Sc(8), WIN.body, Color(130, 135, 144))

		if (!current) then
			Text(#rows == 0 and "Писем нет." or "Выберите письмо слева.", "nwWinText",
				readX + Sc(14), y + Sc(26), WIN.textDim)

			return
		end

		local letter = current.letter
		local cursor = y + Sc(22)

		Text(letter.subject, "nwWinHeader", readX + Sc(14), cursor, WIN.text)
		cursor = cursor + Sc(26)
		Text("От: " .. letter.from .. "  (CID #" .. (letter.cid or "?") .. ")   " .. letter.time,
			"nwWinText", readX + Sc(14), cursor, WIN.textDim)
		cursor = cursor + Sc(16)

		surface.SetDrawColor(WIN.line)
		surface.DrawRect(readX + Sc(10), cursor, readWidth - Sc(20), 1)
		cursor = cursor + Sc(16)

		for _, line in ipairs(util.WrapText(letter.text or "", "nwWinText", readWidth - Sc(28), 10)) do
			Text(line, "nwWinText", readX + Sc(14), cursor, WIN.text)
			cursor = cursor + Sc(18)
		end

		cursor = cursor + Sc(10)

		if (letter.kind == "offer") then
			local statusText = {offered = {"Ожидает вашего ответа", WIN.warn},
				accepted = {"Принято — посылка в пути", WIN.link}, declined = {"Отклонено", WIN.textDim},
				delivered = {"Посылка на точке поезда", WIN.good},
				shipped = {"Отправлена дальше, ждём оплату", WIN.link}, done = {"Сделка закрыта", WIN.good}}
			local status = statusText[letter.status or ""] or {"—", WIN.textDim}

			Text("Состояние: " .. status[1], "nwWinBold", readX + Sc(14), cursor, status[2])
			cursor = cursor + Sc(28)

			if (letter.status == "offered") then
				Text("Ответить отправителю:", "nwWinText", readX + Sc(14), cursor, WIN.text)
				panel:Button(readX + Sc(14), cursor + Sc(14), Sc(150), Sc(28), "Принять посылку", function()
					panel:Request("mail_offer", {id = letter.id, bAccept = true})
				end, true)
				panel:Button(readX + Sc(172), cursor + Sc(14), Sc(120), Sc(28), "Отказаться", function()
					panel:Request("mail_offer", {id = letter.id, bAccept = false})
				end)
			end

			return
		end

		if (letter.kind == "supply") then

			local statusText = {
				pending = {"ОЖИДАЕТ СБОРКИ", WIN.warn}, assigned = {"В ПУТИ (ГСР)", WIN.link},
				transit = {"В ПУТИ (ТРАНСПОРТ)", WIN.link}, delivered = {"ДОСТАВЛЕНО", WIN.good},
				opened = {"ПОЛУЧЕНО", WIN.good}, lost = {"УТЕРЯНО", WIN.bad},
				cancelled = {"ОТМЕНЕНО", WIN.bad}
			}
			local status = statusText[letter.status or ""] or {"—", WIN.textDim}
			local formX, formW = readX + Sc(14), readWidth - Sc(28)
			local formY = cursor
			local formH = y + height - formY - Sc(20)

			Box(formX + 3, formY + 3, formW, formH, Color(0, 0, 0, 40))
			Box(formX, formY, formW, formH, Color(250, 247, 236), Color(150, 140, 120))
			Text("СКЛАД ГСР · СНАБЖЕНИЕ СИТИ-24", "nwWinMono", formX + math.floor(formW * 0.5),
				formY + Sc(18), WIN.text, TEXT_ALIGN_CENTER)
			surface.SetDrawColor(120, 110, 90)
			surface.DrawRect(formX + Sc(12), formY + Sc(30), formW - Sc(24), 1)

			local rowY = formY + Sc(44)

			for _, line in ipairs(string.Explode("\n", letter.text or "")) do
				if (line != "" and !string.find(line, "^НАКЛАДНАЯ")) then
					local label, value = string.match(line, "^(.-):%s*(.*)$")

					if (label) then
						Text(label, "nwWinMono", formX + Sc(14), rowY, WIN.textDim)
						Text(NETWORK.util.TruncateWidth(value, "nwWinMono", formW - Sc(160)),
							"nwWinMono", formX + Sc(150), rowY, WIN.text)
					else
						Text(line, "nwWinMono", formX + Sc(14), rowY, WIN.text)
					end

					surface.SetDrawColor(200, 190, 170)

					for dot = 0, formW - Sc(28), 5 do
						surface.DrawRect(formX + Sc(14) + dot, rowY + Sc(10), 2, 1)
					end

					rowY = rowY + Sc(22)
				end
			end

			surface.SetFont("nwWinBold")

			local stampW = surface.GetTextSize(status[1]) + Sc(24)
			local stampX = formX + formW - stampW - Sc(16)
			local stampY = formY + formH - Sc(44)

			surface.SetDrawColor(status[2].r, status[2].g, status[2].b, 200)
			surface.DrawOutlinedRect(stampX, stampY, stampW, Sc(28), 2)
			surface.DrawOutlinedRect(stampX + 3, stampY + 3, stampW - 6, Sc(28) - 6, 1)
			Text(status[1], "nwWinBold", stampX + math.floor(stampW * 0.5), stampY + Sc(14),
				ColorAlpha(status[2], 220), TEXT_ALIGN_CENTER)

			return
		end

		if (letter.kind == "business") then
			local statusText = {pending = {"На рассмотрении", WIN.warn},
				approved = {"Одобрена", WIN.good}, denied = {"Отклонена", WIN.bad}}
			local status = statusText[letter.status or ""] or {"Заявка удалена", WIN.textDim}

			Text("Статус заявки: " .. status[1], "nwWinBold", readX + Sc(14), cursor, status[2])
			cursor = cursor + Sc(24)

			Text("Место работы (при одобрении):", "nwWinText", readX + Sc(14), cursor, WIN.text)
			panel:Input(window, "location", readX + Sc(14), cursor + Sc(12), readWidth - Sc(28), Sc(24),
				letter.location or "")

			local buttonY = cursor + Sc(44)

			panel:Button(readX + Sc(14), buttonY, Sc(120), Sc(28), "Одобрить", function()
				panel:Request("mail_decide", {id = letter.id, bApprove = true,
					location = panel:GetInputValue(window, "location")})
			end, true)
			panel:Button(readX + Sc(142), buttonY, Sc(120), Sc(28),
				letter.status == "approved" and "Отозвать" or "Отклонить", function()
					panel:Request("mail_decide", {id = letter.id, bApprove = false})
				end)

			return
		end

		if (letter.reply) then
			Box(readX + Sc(14), cursor, readWidth - Sc(28), Sc(22), Color(232, 244, 232))
			Text("Ответ отправлен: " .. letter.reply.author, "nwWinBold", readX + Sc(20),
				cursor + Sc(11), WIN.good)
			cursor = cursor + Sc(28)

			for _, line in ipairs(util.WrapText(letter.reply.text, "nwWinText", readWidth - Sc(28), 4)) do
				Text(line, "nwWinText", readX + Sc(14), cursor, WIN.textDim)
				cursor = cursor + Sc(18)
			end

			return
		end

		local replyHeight = height - (cursor - y) - Sc(52)

		if (replyHeight > Sc(40)) then
			panel:Input(window, "reply", readX + Sc(14), cursor, readWidth - Sc(28), replyHeight,
				"Текст ответа…", true)
		end

		panel:Button(readX + readWidth - Sc(154), y + height - Sc(40), Sc(140), Sc(28),
			"Отправить ответ", function()
				panel:Request("mail_reply", {id = letter.id,
					text = panel:GetInputValue(window, "reply")})
				panel:SetInputValue(window, "reply", "")
			end, true)
	end
}

APPS.budget = {
	title = "Бюджет города",
	glyph = "coin",
	color = Color(30, 140, 70),
	width = 820,
	height = 560,
	OnOpen = function(panel, window)
		panel:Request("budget_state")
	end,
	Paint = function(panel, window, x, y, width, height)
		local data = panel.data.budget

		if (!data) then
			Text("Загрузка…", "nwWinText", x + Sc(16), y + Sc(20), WIN.textDim)

			return
		end

		local cards = {
			{"Счёт города", data.balance .. " т.", WIN.good},
			{"Субсидия Альянса за выплату", "+" .. data.income .. " т.", WIN.text},
			{"Следующая выплата через", string.format("%d:%02d", math.floor(data.nextPay / 60),
				data.nextPay % 60), WIN.text}
		}
		local cardWidth = math.floor((width - Sc(32)) / 3)

		for index, card in ipairs(cards) do
			local cardX = x + Sc(8) + (index - 1) * (cardWidth + Sc(8))

			Box(cardX, y + Sc(8), cardWidth, Sc(64), WIN.body, Color(171, 173, 179))
			Text(card[1], "nwWinText", cardX + Sc(10), y + Sc(24), WIN.textDim)
			Text(card[2], "nwWinBig", cardX + Sc(10), y + Sc(52), card[3])
		end

		local tableX = x + Sc(8)
		local tableY = y + Sc(84)
		local tableWidth = math.floor(width * 0.55)
		local rowHeight = Sc(26)

		Text("Зарплаты за одну выплату (0–" .. data.maxSalary .. " т.)", "nwWinBold", tableX,
			tableY, WIN.text)

		local gridY = tableY + Sc(14)

		Box(tableX, gridY, tableWidth, rowHeight * (#data.salaries + 1), WIN.body, Color(171, 173, 179))
		Box(tableX, gridY, tableWidth, rowHeight, Color(238, 238, 238))

		Text("Группа", "nwWinBold", tableX + Sc(8), gridY + math.floor(rowHeight * 0.5), WIN.text)
		Text("В сети", "nwWinBold", tableX + math.floor(tableWidth * 0.58),
			gridY + math.floor(rowHeight * 0.5), WIN.text)
		Text("Сумма, т.", "nwWinBold", tableX + math.floor(tableWidth * 0.74),
			gridY + math.floor(rowHeight * 0.5), WIN.text)

		for index, row in ipairs(data.salaries) do
			local rowY = gridY + index * rowHeight

			surface.SetDrawColor(WIN.line)
			surface.DrawRect(tableX, rowY, tableWidth, 1)

			Text(row.label, "nwWinText", tableX + Sc(8), rowY + math.floor(rowHeight * 0.5), WIN.text)
			Text(tostring(row.online), "nwWinText", tableX + math.floor(tableWidth * 0.58),
				rowY + math.floor(rowHeight * 0.5), WIN.textDim)

			local entry = panel:Input(window, "salary_" .. row.id,
				tableX + math.floor(tableWidth * 0.72), rowY + Sc(2),
				math.floor(tableWidth * 0.26), rowHeight - Sc(4), "0", false, true)

			if (!entry.bFilled) then
				entry.bFilled = true
				entry:SetValue(tostring(row.amount))
			end
		end

		local afterY = gridY + rowHeight * (#data.salaries + 1) + Sc(10)

		panel:Button(tableX + tableWidth - Sc(150), afterY, Sc(150), Sc(28), "Сохранить", function()
			local salaries = {}

			for _, row in ipairs(data.salaries) do
				salaries[row.id] = tonumber(panel:GetInputValue(window, "salary_" .. row.id)) or 0
			end

			panel:Request("budget_salaries", {salaries = salaries})
		end, true)

		panel:Button(tableX, afterY, Sc(120), Sc(28), "Обновить", function()
			for _, entry in pairs(window.inputs) do
				if (IsValid(entry)) then
					entry.bFilled = nil
				end
			end

			panel:Request("budget_state")
		end)

		local chartX = x + tableWidth + Sc(24)
		local chartWidth = width - tableWidth - Sc(32)
		local chartY = tableY + Sc(14)
		local chartHeight = Sc(200)
		local history = data.history or {}
		local maximum = 1

		for _, value in ipairs(history) do
			maximum = math.max(maximum, value)
		end

		Text("Счёт после выплат", "nwWinBold", chartX, tableY, WIN.text)
		Box(chartX, chartY, chartWidth, chartHeight, WIN.body, Color(171, 173, 179))

		for step = 1, 3 do
			surface.SetDrawColor(236, 236, 236)
			surface.DrawRect(chartX + 1, chartY + math.floor(chartHeight * step / 4), chartWidth - 2, 1)
		end

		if (#history == 0) then
			Text("Выплат ещё не было", "nwWinText", chartX + math.floor(chartWidth * 0.5),
				chartY + math.floor(chartHeight * 0.5), WIN.textDim, TEXT_ALIGN_CENTER)
		end

		local barWidth = math.floor((chartWidth - Sc(20)) / math.max(#history, 1)) - Sc(4)

		for index, value in ipairs(history) do
			local barHeight = math.floor((chartHeight - Sc(20)) * value / maximum)
			local barX = chartX + Sc(10) + (index - 1) * (barWidth + Sc(4))

			NETWORK.util.DrawVGradient(barX, chartY + chartHeight - barHeight - Sc(4), barWidth,
				barHeight, Color(90, 170, 110), Color(40, 120, 60))
		end

		local logY = afterY + Sc(44)
		local rows = {}

		for _, entry in ipairs(data.log or {}) do
			rows[#rows + 1] = {cells = {entry.time, entry.text}}
		end

		Text("Журнал операций", "nwWinBold", x + Sc(8), logY, WIN.text)
		panel:ListView(window, "log", x + Sc(8), logY + Sc(14), width - Sc(16),
			height - (logY - y) - Sc(22), {{"Время", 0}, {"Операция", 0.16}}, rows)
	end
}

local CAMERA_W, CAMERA_H = 640, 400
local cameraTargets = {}

local function GetCameraTarget(slot)
	if (!cameraTargets[slot]) then
		local texture = GetRenderTarget("nwAdminCamRT" .. slot, CAMERA_W, CAMERA_H)
		local material = CreateMaterial("nwAdminCamMat" .. slot, "UnlitGeneric", {
			["$basetexture"] = texture:GetName()
		})

		cameraTargets[slot] = {texture = texture, material = material}
	end

	return cameraTargets[slot]
end

function PANEL:OpenCamera(camera, from)
	local id = "camera" .. camera.index
	local existing = self:FindWindow(id)

	if (existing) then
		return self:Focus(existing)
	end

	local used = {}

	for _, window in ipairs(self.windows) do
		if (window.cameraSlot) then
			used[window.cameraSlot] = true
		end
	end

	local slot

	for index = 1, 4 do
		if (!used[index]) then
			slot = index

			break
		end
	end

	if (!slot) then
		surface.PlaySound(SOUNDS.error)
		self:Toast("Открыто слишком много камер")

		return
	end

	local window = self:CreateWindow(id, "Камера — " .. camera.name, 560, 400, from,
		{glyph = "eye", cameraSlot = slot, camera = camera, bodyColor = Color(0, 0, 0)})

	window.Paint = function(panel, win, x, y, width, height)
		local target = GetCameraTarget(win.cameraSlot)
		local entity = Entity(win.camera.index)

		if (!IsValid(entity)) then
			Text("НЕТ СИГНАЛА", "nwWinCam", x + math.floor(width * 0.5), y + math.floor(height * 0.5),
				Color(220, 220, 220), TEXT_ALIGN_CENTER)

			return
		end

		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(target.material)
		surface.DrawTexturedRect(x, y, width, height)

		surface.SetDrawColor(30, 50, 30, 70)
		surface.DrawRect(x, y, width, height)

		NETWORK.util.DrawScanlines(x, y, width, height + 1, 60, 3)

		local roll = (RealTime() * 60) % (height + 40) - 20

		surface.SetDrawColor(255, 255, 255, 12)
		surface.DrawRect(x, y + roll, width, Sc(18))

		local noise = NETWORK.util.GetTexture("framework/pattern/noise.png")

		if (noise) then
			surface.SetDrawColor(255, 255, 255, 40)
			NETWORK.util.DrawTiled(noise, x, y, width, height, nil, nil, math.random(0, 255),
				math.random(0, 255))
			draw.NoTexture()
		else
			for _ = 1, 30 do
				surface.SetDrawColor(255, 255, 255, math.random(10, 40))
				surface.DrawRect(x + math.random(0, width), y + math.random(0, height), 2, 1)
			end
		end

		NETWORK.util.DrawVignette(x, y, width, height, math.floor(math.min(width, height) * 0.3), 160)

		Text("CAM " .. string.format("%02d", win.cameraSlot) .. "  " .. win.camera.name, "nwWinCam",
			x + Sc(12), y + Sc(16), Color(230, 230, 230))
		Text(os.date("%d.%m.%Y  %H:%M:%S"), "nwWinCam", x + width - Sc(12), y + height - Sc(16),
			Color(230, 230, 230), TEXT_ALIGN_RIGHT)

		if (math.floor(RealTime() * 1.5) % 2 == 0) then
			NETWORK.util.DrawCircle(x + width - Sc(64), y + Sc(16), Sc(5), Color(230, 30, 30))
		end

		Text("REC", "nwWinCam", x + width - Sc(12), y + Sc(16), Color(230, 230, 230),
			TEXT_ALIGN_RIGHT)
	end
end

hook.Add("Tick", "nwAdminCameras", function()
	local panel = NETWORK.gui.adminComputer

	if (!IsValid(panel) or panel.bClosing) then
		return
	end

	if ((panel.nextCameraRender or 0) > RealTime()) then
		return
	end

	panel.nextCameraRender = RealTime() + 1 / 15

	for _, window in ipairs(panel.windows) do
		if (!window.cameraSlot or window.bMinimized) then
			continue
		end

		local entity = Entity(window.camera.index)

		if (!IsValid(entity)) then
			continue
		end

		local target = GetCameraTarget(window.cameraSlot)
		local angles = entity:GetAngles()

		angles:RotateAroundAxis(angles:Up(), math.sin(RealTime() * 0.25 + window.cameraSlot) * 25)

		render.PushRenderTarget(target.texture)
			render.Clear(0, 0, 0, 255, true, true)

			render.RenderView({
				origin = entity:GetPos() + entity:GetForward() * 8,
				angles = angles,
				fov = 80,
				aspect = CAMERA_W / CAMERA_H,
				x = 0,
				y = 0,
				w = CAMERA_W,
				h = CAMERA_H,
				drawviewmodel = false,
				drawviewer = true
			})
		render.PopRenderTarget()

		target.material:SetTexture("$basetexture", target.texture)
	end
end)

APPS.housing = {
	title = "Жилые блоки",
	glyph = "grid",
	color = Color(120, 80, 170),
	width = 900,
	height = 580,
	OnOpen = function(panel, window)
		panel:Request("housing_state")
	end,
	Paint = function(panel, window, x, y, width, height)
		local data = panel.data.housing

		if (!data) then
			Text("Загрузка…", "nwWinText", x + Sc(16), y + Sc(20), WIN.textDim)

			return
		end

		local blocks = data.blocks or {}
		local listWidth = Sc(230)

		window.state.block = window.state.block or (blocks[1] and blocks[1].name)

		Box(x + Sc(4), y + Sc(4), listWidth, height - Sc(8), WIN.body, Color(130, 135, 144))
		Text("Жилые блоки", "nwWinBold", x + Sc(12), y + Sc(18), WIN.text)

		local current

		for index, block in ipairs(blocks) do
			local rowY = y + Sc(32) + (index - 1) * Sc(44)
			local bActive = window.state.block == block.name

			if (bActive) then
				current = block
				Box(x + Sc(8), rowY, listWidth - Sc(8), Sc(40), WIN.selection, WIN.selectionBorder)
			end

			Text(block.name, "nwWinBold", x + Sc(16), rowY + Sc(12), WIN.text)
			Text("Занято " .. block.taken .. " из " .. block.total, "nwWinSmall", x + Sc(16),
				rowY + Sc(28), WIN.textDim)

			local barWidth = Sc(70)
			local barX = x + listWidth - barWidth - Sc(10)
			local fraction = block.total > 0 and block.taken / block.total or 0

			Box(barX, rowY + Sc(22), barWidth, Sc(10), Color(230, 230, 230), Color(160, 160, 160))
			Box(barX + 1, rowY + Sc(23), math.floor((barWidth - 2) * fraction), Sc(8),
				fraction >= 1 and WIN.bad or Color(60, 160, 90))

			panel:Hit(x + Sc(8), rowY, listWidth - Sc(8), Sc(40), function()
				surface.PlaySound(SOUNDS.click)
				window.state.block = block.name
			end)
		end

		if (#blocks == 0) then
			Text("Жилых дверей не найдено.", "nwWinText", x + Sc(12), y + Sc(40), WIN.textDim)
		end

		panel:Button(x + Sc(8), y + height - Sc(38), listWidth - Sc(8), Sc(28), "Обновить", function()
			panel:Request("housing_state")
		end)

		if (!current) then
			return
		end

		local areaX = x + listWidth + Sc(12)
		local areaWidth = width - listWidth - Sc(16)

		Text(current.name, "nwWinHeader", areaX, y + Sc(18), WIN.text)
		Text("Свободно: " .. (current.total - current.taken), "nwWinText", areaX + areaWidth,
			y + Sc(18), WIN.good, TEXT_ALIGN_RIGHT)

		local tileWidth, tileHeight = Sc(150), Sc(52)
		local perRow = math.max(math.floor((areaWidth + Sc(6)) / (tileWidth + Sc(6))), 1)

		for index, flat in ipairs(current.flats) do
			local column = (index - 1) % perRow
			local row = math.floor((index - 1) / perRow)
			local tileX = areaX + column * (tileWidth + Sc(6))
			local tileY = y + Sc(40) + row * (tileHeight + Sc(6))
			local bTaken = flat.owner != ""

			if (tileY + tileHeight > y + height - Sc(170)) then
				Text("…и ещё " .. (#current.flats - index + 1), "nwWinText", areaX,
					tileY + Sc(10), WIN.textDim)

				break
			end

			Box(tileX, tileY, tileWidth, tileHeight, bTaken and Color(252, 232, 232) or
				Color(232, 248, 234), bTaken and Color(210, 140, 140) or Color(140, 200, 150))
			Text(NETWORK.util.TruncateWidth(flat.name, "nwWinBold", tileWidth - Sc(12)), "nwWinBold",
				tileX + Sc(8), tileY + Sc(15), WIN.text)
			Text(NETWORK.util.TruncateWidth(bTaken and flat.owner or "свободна", "nwWinText",
				tileWidth - Sc(12)), "nwWinText", tileX + Sc(8), tileY + Sc(35),
				bTaken and WIN.bad or WIN.good)
		end

		local camY = y + height - Sc(160)

		surface.SetDrawColor(WIN.line)
		surface.DrawRect(areaX, camY - Sc(8), areaWidth, 1)
		Text("Камеры блока", "nwWinBold", areaX, camY + Sc(4), WIN.text)

		local cursor = areaX
		local count = 0

		for _, camera in ipairs(data.cameras or {}) do
			if (camera.block != current.name) then
				continue
			end

			count = count + 1

			local tileX, tileY = cursor, camY + Sc(20)
			local tileW, tileH = Sc(150), Sc(110)
			local bHover = Inside(panel.mouseX, panel.mouseY, tileX, tileY, tileW, tileH)

			Box(tileX, tileY, tileW, tileH, Color(20, 24, 28), bHover and Color(51, 153, 255) or
				Color(90, 90, 90))
			NETWORK.gui.DrawGlyph("eye", tileX + math.floor(tileW * 0.5) - Sc(16), tileY + Sc(22), Sc(32),
				Color(160, 200, 160))
			Text(NETWORK.util.TruncateWidth(camera.name, "nwWinText", tileW - Sc(12)), "nwWinText",
				tileX + math.floor(tileW * 0.5), tileY + tileH - Sc(28), Color(220, 230, 220),
				TEXT_ALIGN_CENTER)
			Text("Открыть", "nwWinSmall", tileX + math.floor(tileW * 0.5), tileY + tileH - Sc(12),
				Color(140, 180, 240), TEXT_ALIGN_CENTER)

			panel:Hit(tileX, tileY, tileW, tileH, function()
				panel:OpenCamera(camera, {tileX, tileY, tileW, tileH})
			end)

			cursor = cursor + tileW + Sc(8)
		end

		if (count == 0) then
			Text("В блоке нет камер. Админ может поставить «Камеру жилого блока» в его зоне.",
				"nwWinText", areaX, camY + Sc(40), WIN.textDim)
		end
	end
}

APPS.supply = {
	title = "Снабжение",
	glyph = "backpack",
	color = Color(180, 120, 40),
	width = 820,
	height = 540,
	OnOpen = function(panel, window)
		panel:Request("supply_state")
	end,
	Paint = function(panel, window, x, y, width, height)
		local data = panel.data.supply

		if (!data) then
			Text("Загрузка…", "nwWinText", x + Sc(16), y + Sc(20), WIN.textDim)

			return
		end

		local leftWidth = math.floor(width * 0.5)

		Text("Каталог поставок", "nwWinBold", x + Sc(8), y + Sc(14), WIN.text)
		Text("Фонд: " .. data.fund .. " / " .. data.fundMax, "nwWinText", x + leftWidth - Sc(8),
			y + Sc(14), WIN.good, TEXT_ALIGN_RIGHT)

		local rowY = y + Sc(30)

		for _, entry in ipairs(data.catalog) do
			if (rowY + Sc(50) > y + height - Sc(8)) then
				break
			end

			Box(x + Sc(8), rowY, leftWidth - Sc(16), Sc(46), WIN.body, Color(171, 173, 179))
			Text(entry.name, "nwWinBold", x + Sc(18), rowY + Sc(15), WIN.text)
			Text(NETWORK.util.TruncateWidth(entry.desc, "nwWinSmall", leftWidth - Sc(150)),
				"nwWinSmall", x + Sc(18), rowY + Sc(32), WIN.textDim)

			if (data.bCanOrder) then
				panel:Button(x + leftWidth - Sc(120), rowY + Sc(9), Sc(104), Sc(28),
					"Заказать · " .. entry.cost, function()
						panel:Request("supply_order", {id = entry.id})
					end, data.fund >= entry.cost, data.fund < entry.cost)
			else
				Text(entry.cost .. " оч.", "nwWinText", x + leftWidth - Sc(18), rowY + Sc(23),
					WIN.textDim, TEXT_ALIGN_RIGHT)
			end

			rowY = rowY + Sc(52)
		end

		local rightX = x + leftWidth + Sc(4)
		local rightWidth = width - leftWidth - Sc(12)
		local statusText = {pending = "ожидает", assigned = "несёт ГСР", transit = "транспорт",
			delivered = "доставлен", opened = "получен", lost = "утерян", cancelled = "отменён"}
		local rows = {}
		local selected

		for _, order in ipairs(data.orders) do
			rows[#rows + 1] = {
				order = order,
				cells = {string.format("%03d", order.id), order.name, order.by,
					statusText[order.status] or order.status},
				colors = {nil, nil, nil, order.status == "pending" and WIN.warn or
					((order.status == "lost" or order.status == "cancelled") and WIN.bad or WIN.good)}
			}

			if (window.state.selected == order.id) then
				selected = rows[#rows]
			end
		end

		Text("Заказы", "nwWinBold", rightX, y + Sc(14), WIN.text)
		panel:ListView(window, "orders", rightX, y + Sc(30), rightWidth, height - Sc(80),
			{{"№", 0}, {"Наименование", 0.12}, {"Заказчик", 0.5}, {"Статус", 0.78}}, rows,
			function(row)
				window.state.selected = row.order.id
			end, selected)

		panel:Button(rightX, y + height - Sc(42), Sc(120), Sc(28), "Обновить", function()
			panel:Request("supply_state")
		end)

		if (data.bCanOrder) then
			panel:Button(rightX + rightWidth - Sc(160), y + height - Sc(42), Sc(160), Sc(28),
				"Отменить заказ", function()
					if (window.state.selected) then
						panel:Request("supply_cancel", {id = window.state.selected})
						window.state.selected = nil
					end
				end, false, !(selected and selected.order.status == "pending"))
		end
	end
}

APPS.decisions = {
	title = "Решения",
	glyph = "shield",
	color = Color(150, 60, 60),
	width = 820,
	height = 540,
	OnOpen = function(panel, window)
		panel:Request("decisions_state")
	end,
	Paint = function(panel, window, x, y, width, height)
		local data = panel.data.decisions

		if (!data) then
			Text("Загрузка…", "nwWinText", x + Sc(16), y + Sc(20), WIN.textDim)

			return
		end

		local listWidth = Sc(300)
		local rows = {}
		local selected

		for _, entry in ipairs(data.list) do
			local statusText = {pending = "ждёт", accepted = "принято", declined = "отклонено"}

			rows[#rows + 1] = {
				entry = entry,
				bBold = entry.status == "pending",
				cells = {entry.title, statusText[entry.status] or entry.status},
				colors = {nil, entry.status == "pending" and WIN.warn or
					(entry.status == "accepted" and WIN.good or WIN.textDim)}
			}

			if (window.state.selected == entry.id) then
				selected = rows[#rows]
			end
		end

		panel:ListView(window, "decisions", x + Sc(4), y + Sc(4), listWidth, height - Sc(8),
			{{"Предложение", 0}, {"Статус", 0.7}}, rows, function(row)
				window.state.selected = row.entry.id
			end, selected)

		local readX = x + listWidth + Sc(12)
		local readWidth = width - listWidth - Sc(16)

		Box(readX, y + Sc(4), readWidth, height - Sc(8), WIN.body, Color(130, 135, 144))

		if (!selected) then
			Text(#rows == 0 and "Предложений пока нет." or "Выберите предложение слева.", "nwWinText",
				readX + Sc(14), y + Sc(26), WIN.textDim)

			return
		end

		local entry = selected.entry
		local cursor = y + Sc(22)

		Text(entry.title, "nwWinHeader", readX + Sc(14), cursor, WIN.text)
		cursor = cursor + Sc(26)
		Text("От: " .. entry.author .. "   " .. entry.time, "nwWinText", readX + Sc(14), cursor,
			WIN.textDim)
		cursor = cursor + Sc(16)
		surface.SetDrawColor(WIN.line)
		surface.DrawRect(readX + Sc(10), cursor, readWidth - Sc(20), 1)
		cursor = cursor + Sc(16)

		for _, line in ipairs(NETWORK.util.WrapText(entry.text or "", "nwWinText", readWidth - Sc(28), 12)) do
			Text(line, "nwWinText", readX + Sc(14), cursor, WIN.text)
			cursor = cursor + Sc(18)
		end

		cursor = cursor + Sc(12)

		Text(string.format("При согласии: %+d т.   При отказе: %+d т.", entry.accept, entry.decline),
			"nwWinBold", readX + Sc(14), cursor, WIN.text)
		cursor = cursor + Sc(28)

		if (entry.status == "pending") then
			panel:Button(readX + Sc(14), cursor, Sc(130), Sc(28), "Принять", function()
				panel:Request("decisions_decide", {id = entry.id, bAccept = true})
			end, true)
			panel:Button(readX + Sc(152), cursor, Sc(130), Sc(28), "Отклонить", function()
				panel:Request("decisions_decide", {id = entry.id, bAccept = false})
			end)
		else
			Text((entry.status == "accepted" and "Принято" or "Отклонено") .. " — " ..
				(entry.by or "?"), "nwWinBold", readX + Sc(14), cursor,
				entry.status == "accepted" and WIN.good or WIN.bad)
		end
	end
}

vgui.Register("nwAdminComputer", PANEL, "EditablePanel")

local CWU_COLOR = Color(150, 120, 40)

local function CWUState(panel)
	return panel.data.cwu or {}
end

APPS.staff = {
	title = "Сотрудники",
	glyph = "group",
	color = CWU_COLOR,
	width = 640,
	height = 500,
	OnOpen = function(panel, window)
		panel:Request("cwu_state")
	end,
	Paint = function(panel, window, x, y, width, height)
		local state = CWUState(panel)
		local rows = {}

		for _, entry in ipairs(state.staff or {}) do
			rows[#rows + 1] = {cells = {entry.name, entry.role, entry.zone, tostring(entry.tokens or 0)},
				entry = entry}
		end

		Text(string.format("В сети сотрудников: %d  ·  щёлкните по строке", #rows), "nwWinBold",
			x + Sc(8), y + Sc(12), WIN.text)

		panel:ListView(window, "staff", x + Sc(6), y + Sc(24), width - Sc(12), height - Sc(150),
			{{"Имя", 0}, {"Роль", 0.36}, {"Район", 0.62}, {"Токены", 0.86}}, rows, function(row, rect)
				panel:OpenCWUPerson(row.entry, rect)
			end)

		local formY = y + height - Sc(118)

		Text("Причина вызова:", "nwWinText", x + Sc(8), formY, WIN.text)
		panel:Input(window, "reason", x + Sc(110), formY - Sc(12), width - Sc(118), Sc(26),
			"например: пострадавший у завода")

		local bCooldown = (state.nextCall or 0) > CurTime()
		local buttonWidth = math.floor((width - Sc(12) - Sc(6) * 3) * 0.25)

		for index, role in ipairs(state.roles or {}) do
			local bx = x + Sc(6) + (index - 1) * (buttonWidth + Sc(6))

			panel:Button(bx, formY + Sc(24), buttonWidth, Sc(34),
				string.format("%s (%d)", role.label, role.online or 0), function()
					panel:Request("cwu_call", {role = role.id,
						reason = panel:GetInputValue(window, "reason")})
				end, index == 1, bCooldown or (role.online or 0) == 0)
		end

		if (bCooldown) then
			Text(string.format("Повторный вызов через %d с", math.ceil(state.nextCall - CurTime())),
				"nwWinSmall", x + Sc(8), formY + Sc(70), WIN.warn)
		else
			local last = (state.callLog or {})[#(state.callLog or {})]

			Text(last and string.format("Последний вызов: %s  %s — %s", last.time, last.faction,
				last.reason) or "Вызовов ещё не было.", "nwWinSmall", x + Sc(8), formY + Sc(70),
				WIN.textDim)
		end
	end
}

function PANEL:OpenCWUPerson(entry, from)
	if (!entry) then
		return
	end

	local id = "cwuperson"
	local existing = self:FindWindow(id)

	if (existing) then
		self:CloseWindow(existing)
	end

	local window = self:CreateWindow(id, entry.name, 420, 260, from, {glyph = "person"})

	window.Paint = function(panel, win, x, y, width, height)
		Text(entry.name, "nwWinHeader", x + Sc(14), y + Sc(22), WIN.text)
		Text(entry.role .. (entry.zone != "" and ("  ·  " .. entry.zone) or ""), "nwWinText",
			x + Sc(14), y + Sc(48), WIN.textDim)
		Text("Токены: " .. tostring(entry.tokens or 0), "nwWinText", x + Sc(14), y + Sc(68), WIN.textDim)

		panel:Button(x + Sc(14), y + Sc(100), Sc(180), Sc(30), "Вызвать к компьютеру", function()
			panel:Request("cwu_call_one", {name = entry.name})
			panel:CloseWindow(win)
		end, true)

		panel:Button(x + Sc(14), y + Sc(138), Sc(180), Sc(30), "Выписать штраф", function()
			panel:CloseWindow(win)
			panel:OpenApp("fines")

			timer.Simple(0.05, function()
				local fines = IsValid(panel) and panel:FindWindow("fines")

				if (fines) then
					panel:SetInputValue(fines, "name", entry.name)
				end
			end)
		end)

		panel:Button(x + Sc(14), y + Sc(176), Sc(180), Sc(30), "Заметка о сотруднике", function()
			panel:CloseWindow(win)
			panel:OpenApp("notes")

			timer.Simple(0.05, function()
				local notes = IsValid(panel) and panel:FindWindow("notes")

				if (notes) then
					panel:SetInputValue(notes, "text", entry.name .. ": ")
				end
			end)
		end)
	end
end

APPS.fines = {
	title = "Штрафы",
	glyph = "coin",
	color = Color(170, 60, 50),
	width = 600,
	height = 480,
	OnOpen = function(panel, window)
		panel:Request("cwu_state")
	end,
	Paint = function(panel, window, x, y, width, height)
		local state = CWUState(panel)

		Text("Сотрудник:", "nwWinText", x + Sc(8), y + Sc(16), WIN.text)
		panel:Input(window, "name", x + Sc(8), y + Sc(28), Sc(220), Sc(26), "имя персонажа")
		Text("Сумма:", "nwWinText", x + Sc(240), y + Sc(16), WIN.text)
		panel:Input(window, "amount", x + Sc(240), y + Sc(28), Sc(90), Sc(26), "10", false, true)
		Text("Причина:", "nwWinText", x + Sc(8), y + Sc(66), WIN.text)
		panel:Input(window, "reason", x + Sc(8), y + Sc(78), width - Sc(170), Sc(26),
			"опоздание, порча имущества…")

		panel:Button(x + width - Sc(150), y + Sc(76), Sc(142), Sc(30), "Выписать штраф", function()
			local name = panel:GetInputValue(window, "name")
			local amount = tonumber(panel:GetInputValue(window, "amount")) or 0

			if (string.Trim(name) == "" or amount <= 0) then
				surface.PlaySound(SOUNDS.error)

				return
			end

			panel:Request("cwu_fine", {name = name, amount = amount,
				reason = panel:GetInputValue(window, "reason")})
			panel:SetInputValue(window, "reason", "")
		end, true)

		local rows = {}

		for _, fine in ipairs(state.fines or {}) do
			rows[#rows + 1] = {cells = {fine.time, fine.who, tostring(fine.amount), fine.reason, fine.by}}
		end

		panel:ListView(window, "fines", x + Sc(6), y + Sc(118), width - Sc(12), height - Sc(126),
			{{"Время", 0}, {"Кому", 0.14}, {"Сумма", 0.4}, {"Причина", 0.52}, {"Кто", 0.82}}, rows)
	end
}

APPS.notes = {
	title = "Заметки",
	glyph = "list",
	color = Color(60, 120, 90),
	width = 620,
	height = 520,
	OnOpen = function(panel, window)
		panel:Request("cwu_state")
	end,
	Paint = function(panel, window, x, y, width, height)
		local util = NETWORK.util
		local state = CWUState(panel)
		local notes = state.notes or {}
		local bHead = state.bHead
		local formHeight = bHead and Sc(126) or Sc(0)
		local listHeight = height - formHeight - Sc(12)

		Box(x + Sc(6), y + Sc(6), width - Sc(12), listHeight, WIN.body, Color(130, 135, 144))

		local cursor = y + Sc(12)

		for _, note in ipairs(notes) do
			local lines = util.WrapText(note.text or "", "nwWinText", width - Sc(60), 6)
			local bMine = note.by == state.me or LocalPlayer():IsAdmin()
			local itemHeight = Sc(30) + #lines * Sc(18) + (bMine and Sc(30) or 0)

			if (cursor + itemHeight > y + listHeight) then
				break
			end

			Box(x + Sc(12), cursor, width - Sc(24), itemHeight, Color(255, 252, 230),
				Color(220, 200, 140))
			Text(note.by or "?", "nwWinBold", x + Sc(20), cursor + Sc(14), WIN.text)
			Text(note.time or "", "nwWinSmall", x + width - Sc(20), cursor + Sc(14), WIN.textDim,
				TEXT_ALIGN_RIGHT)

			for line, text in ipairs(lines) do
				Text(text, "nwWinText", x + Sc(20), cursor + Sc(16) + line * Sc(18), WIN.text)
			end

			if (bMine and bHead) then
				local buttonY = cursor + itemHeight - Sc(28)

				panel:Button(x + Sc(20), buttonY, Sc(110), Sc(24), "Забрать", function()
					panel:Request("cwu_note_remove", {id = note.id})
				end)

				panel:Button(x + Sc(138), buttonY, Sc(150), Sc(24), "Отправить в ящик", function()
					local to = panel:GetInputValue(window, "to")

					if (string.Trim(to) == "") then
						surface.PlaySound(SOUNDS.error)
						panel:Toast("Укажите имя адресата в поле под списком")

						return
					end

					panel:Request("cwu_note_mail", {id = note.id, to = to})
				end)
			end

			cursor = cursor + itemHeight + Sc(6)
		end

		if (#notes == 0) then
			Text("Заметок пока нет.", "nwWinText", x + Sc(20), y + Sc(30), WIN.textDim)
		end

		if (!bHead) then
			return
		end

		local formY = y + listHeight + Sc(12)

		Text("Новая заметка:", "nwWinText", x + Sc(8), formY + Sc(6), WIN.text)
		panel:Input(window, "text", x + Sc(8), formY + Sc(18), width - Sc(16), Sc(56), "", true)
		Text("Адресат (для «Отправить в ящик»):", "nwWinText", x + Sc(8), formY + Sc(90), WIN.text)
		panel:Input(window, "to", x + Sc(230), formY + Sc(78), Sc(200), Sc(26), "имя персонажа")
		panel:Button(x + width - Sc(148), formY + Sc(78), Sc(140), Sc(28), "Добавить", function()
			local text = panel:GetInputValue(window, "text")

			if (string.Trim(text) == "") then
				surface.PlaySound(SOUNDS.error)

				return
			end

			panel:Request("cwu_note_add", {text = text})
			panel:SetInputValue(window, "text", "")
		end, true)
	end
}

APPS.salary = {
	title = "Зарплата ГСР",
	glyph = "stack",
	color = Color(40, 110, 160),
	width = 440,
	height = 300,
	OnOpen = function(panel, window)
		panel:Request("cwu_state")
	end,
	Paint = function(panel, window, x, y, width, height)
		local state = CWUState(panel)
		local wait = math.max((state.nextPay or 0) - CurTime(), 0)

		Text("Текущая ставка сотрудников ГСР:", "nwWinText", x + Sc(8), y + Sc(16), WIN.text)
		Text(string.format("%d т. за выплату", state.salary or 0), "nwWinHeader", x + Sc(8),
			y + Sc(44), CWU_COLOR)
		Text(string.format("Потолок: %d т.  ·  Следующая выплата через %d мин.", state.maxSalary or 0,
			math.ceil(wait / 60)), "nwWinSmall", x + Sc(8), y + Sc(70), WIN.textDim)

		Text("Новая ставка:", "nwWinText", x + Sc(8), y + Sc(108), WIN.text)
		panel:Input(window, "amount", x + Sc(110), y + Sc(96), Sc(100), Sc(26),
			tostring(state.salary or 0), false, true)
		panel:Button(x + Sc(220), y + Sc(95), Sc(130), Sc(28), "Сохранить", function()
			panel:Request("cwu_salary", {amount = tonumber(panel:GetInputValue(window, "amount")) or 0})
		end, true)

		Text("Ставка одна на всех сотрудников ГСР. Штрафы возвращаются в бюджет города.",
			"nwWinSmall", x + Sc(8), y + Sc(150), WIN.textDim)
	end
}

net.Receive("nwAdminCompOpen", function()
	local entity = net.ReadEntity()

	if (IsValid(NETWORK.gui.adminComputer)) then
		NETWORK.gui.adminComputer:Remove()
	end

	vgui.Create("nwAdminComputer"):Setup(entity)
end)

net.Receive("nwAdminCompData", function()
	local app = net.ReadString()
	local data = NETWORK.util.ReadTable()
	local panel = NETWORK.gui.adminComputer

	if (IsValid(panel)) then
		panel:OnData(app, data)
	end
end)
