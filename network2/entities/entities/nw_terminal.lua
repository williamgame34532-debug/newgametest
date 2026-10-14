-- The civic terminal (after the Helix ix_civic_terminal; the rules: gamemode/core/sh_terminal.lua,
-- the server: sv_terminal.lua, the windows and the E key: cl_terminal.lua).
-- A Combine station with a holographic screen in the look of the Half-Life: Alyx civic stations: the
-- player looks at a key and presses E. The screen is drawn in 3D2D on the model
-- (models/combine/combine_terminal.mdl) over its glass (materials/network2/terminal/wallpaper.png);
-- a small diamond cursor follows the exact point of the screen the player looks at.
-- The point under the eyes: in a 3D2D context +x runs along the angles' Forward, +y along their
-- Right, the plane faces along Up - the ray of the eyes is crossed with that plane (the Helix version
-- used Up as the y axis and Right as the plane, so its cursor drifted away from the eyes).

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "Гражданский терминал"
ENT.Category = "Network"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Model = "models/combine/combine_terminal.mdl"
ENT.FallbackModel = "models/props_combine/combine_interface001.mdl"

ENT.ScreenForward = 13.5
ENT.ScreenRight = 0
ENT.ScreenUp = 12
ENT.ScreenPitch = 0
ENT.ScreenYaw = -2.6
ENT.ScreenRoll = 0
ENT.ScreenScale = 0.05
ENT.ScreenW = 560
ENT.ScreenH = 320

function ENT:GetScreenBasis()
	local angles = self:GetAngles()
	local position = self:GetPos() + angles:Forward() * self.ScreenForward + angles:Right() * self.ScreenRight +
		angles:Up() * self.ScreenUp
	local screen = Angle(angles.p, angles.y, angles.r)

	screen:RotateAroundAxis(screen:Up(), 90 + self.ScreenYaw)
	screen:RotateAroundAxis(screen:Forward(), 90 + self.ScreenRoll)
	screen:RotateAroundAxis(screen:Right(), self.ScreenPitch)

	return position, screen
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace)
		if (!trace.Hit) then
			return
		end

		local entity = ents.Create(NW.terminal.class)
		local angles = (client:GetPos() - trace.HitPos):Angle()

		angles.p, angles.r = 0, 0
		entity:SetPos(trace.HitPos + trace.HitNormal * 8)
		entity:SetAngles(angles)
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Initialize()
		self:SetModel(util.IsValidModel(self.Model) and self.Model or self.FallbackModel)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physics = self:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
			physics:Sleep()
		end

		NW.terminal.serial = (NW.terminal.serial or 0) + 1
		self:SetNW2Int("nwTermNumber", NW.terminal.serial)
		NW.terminal.Changed()
	end

	-- E on the body of the terminal (not on a key of the screen): the Alliance ends an alarm
	function ENT:Use(activator)
		if (IsValid(activator) and activator:IsPlayer() and NW.terminal.IsNear(activator, self)) then
			NW.terminal.Resolve(self, activator)
		end
	end

	function ENT:OnRemove()
		if (NW.terminal.Changed) then
			NW.terminal.Changed()
		end
	end

	return
end


-- ------------------------------------------------------------------ client --
-- The look of the Half-Life: Alyx civic stations: the whole glass glows pale cyan with dense scan
-- streaks and a bright rim; thin upper-case letters with wide spacing and a soft glow; outlined
-- keys that fill with light under the cursor. A menu in the middle; the services in two columns:
-- a list (ТИП / ЦЕНА, a warning sign where it is out of reach) and the summary of the chosen line,
-- ВАШИ КРЕДИТЫ and НАЗАД below. The header reads like "НАВИГАЦИЯ :: 80640156051 .. 278 . 4 . 9 . .",
-- the footer "ЦИКЛ РАЦИОНА .. АКТИВЕН . ." and the time.
local T = NW.terminal

local LINE = Color(160, 232, 246)
local TEXT = Color(206, 246, 252)
local DIM = Color(120, 192, 210)
local FILL = Color(156, 230, 244)
local DARK = Color(8, 40, 50)
local RED = Color(244, 112, 100)
local AMBER = Color(244, 186, 92)

local BG = Material("network2/terminal/wallpaper.png", "smooth noclamp")
local CURSOR = Material("network2/terminal/cursor.png", "smooth")
local CURSOR_HOVER = Material("network2/terminal/cursor_hover.png", "smooth")

local function Font(name, size, weight)
	surface.CreateFont(name, {font = "Jura Medium", size = size, weight = weight or 500, extended = true,
		antialias = true})
	surface.CreateFont(name .. "Glow", {font = "Jura Medium", size = size, weight = weight or 500, extended = true,
		antialias = true, blursize = 2})
end

Font("nwTermTitle", 20, 600)
Font("nwTermHead", 14, 600)
Font("nwTermText", 12, 500)
Font("nwTermSmall", 10, 500)
Font("nwTermTiny", 8, 500)

-- -------------------------------------------------------------- the text --
local widths = {}

local function CharWidth(font, char)
	local key = font .. char
	local width = widths[key]

	if (!width) then
		surface.SetFont(font)
		width = surface.GetTextSize(char)
		widths[key] = width
	end

	return width
end

local function Chars(text)
	local out = {}

	for _, code in utf8.codes(tostring(text or "")) do
		out[#out + 1] = utf8.char(code)
	end

	return out
end

local function Measure(text, font, spacing)
	local width, chars = 0, Chars(text)

	for _, char in ipairs(chars) do
		width = width + CharWidth(font, char) + spacing
	end

	return math.max(0, width - spacing), chars
end

-- upper case, letters set apart, a soft glow under them; align: 0 left, 1 centre, 2 right
local function Spaced(text, font, x, y, color, align, spacing, glow)
	spacing = spacing or 1.5
	text = T.Upper(text)

	local width, chars = Measure(text, font, spacing)
	local cx = align == 1 and x - width / 2 or (align == 2 and x - width or x)
	local alpha = color.a or 255

	surface.SetFont(font)

	local _, height = surface.GetTextSize("Я")
	local top = y - height / 2

	if (glow != false) then
		surface.SetFont(font .. "Glow")
		surface.SetTextColor(color.r, color.g, color.b, alpha * 0.55)

		local gx = cx

		for _, char in ipairs(chars) do
			surface.SetTextPos(gx, top)
			surface.DrawText(char)
			gx = gx + CharWidth(font, char) + spacing
		end
	end

	surface.SetFont(font)
	surface.SetTextColor(color.r, color.g, color.b, alpha)

	for _, char in ipairs(chars) do
		surface.SetTextPos(cx, top)
		surface.DrawText(char)
		cx = cx + CharWidth(font, char) + spacing
	end

	return width
end

local function Wrap(text, font, maxWidth, spacing)
	local lines, current = {}, ""

	for _, word in ipairs(string.Explode(" ", T.Upper(tostring(text or "")))) do
		local candidate = current == "" and word or current .. " " .. word

		if (Measure(candidate, font, spacing or 1) > maxWidth and current != "") then
			lines[#lines + 1] = current
			current = word
		else
			current = candidate
		end
	end

	if (current != "") then
		lines[#lines + 1] = current
	end

	return lines
end

local function Alpha(color, alpha)
	return Color(color.r, color.g, color.b, math.Clamp(alpha, 0, 255))
end

local function Outline(x, y, w, h, color, alpha)
	surface.SetDrawColor(color.r, color.g, color.b, alpha or 200)
	surface.DrawOutlinedRect(math.floor(x), math.floor(y), math.floor(w), math.floor(h), 1)
end

local function Rule(x, y, w, color, alpha)
	surface.SetDrawColor(color.r, color.g, color.b, alpha or 120)
	surface.DrawRect(math.floor(x), math.floor(y), math.floor(w), 1)
end

-- the warning sign of an item out of reach
local function Warning(x, y, size, color)
	draw.NoTexture()
	surface.SetDrawColor(color.r, color.g, color.b, 230)
	surface.DrawPoly({{x = x, y = y - size}, {x = x + size * 0.95, y = y + size * 0.7},
		{x = x - size * 0.95, y = y + size * 0.7}})
	surface.SetDrawColor(DARK.r, DARK.g, DARK.b, 255)
	surface.DrawRect(x - 1, y - size * 0.35, 2, size * 0.6)
	surface.DrawRect(x - 1, y + size * 0.38, 2, 2)
end

-- the Alliance mark in the corner (a ring with a notch)
local function Emblem(x, y, color)
	surface.DrawCircle(x, y, 6, color.r, color.g, color.b, 230)
	surface.DrawCircle(x, y, 5, color.r, color.g, color.b, 120)
	surface.SetDrawColor(color.r, color.g, color.b, 255)
	surface.DrawRect(x - 1, y - 3, 3, 3)
	surface.DrawRect(x + 4, y - 7, 4, 2)
end

local X0, X1 = 26, 534
local LIST_X, LIST_W = 28, 236
local SUM_X, SUM_W = 296, 236
local W_, H_ = 560, 320

-- ------------------------------------------------------------- the state --
function ENT:ResetSession()
	self.registered = false
	self.registrationStage = "idle"
	self.registrationStarted = 0
	self.screen = "register"
	self.profile = nil
	self.announcements = {}
	self.apartments = {}
	self.businesses = {}
	self.selected = {}
	self.page = {}
	self.callDraft = ""
	self.housingMessage = ""
	self.housingSequence = nil
	self.housingRouletteStart = 0
	self.housingTicks = 0
	self.assigned = nil
	self.actionMessage = ""
	self.actionMessageUntil = 0
	self.buttons = {}
	self.fade = 0
end

function ENT:Initialize()
	self:ResetSession()
	self.nextFlicker = 0
	self.flicker = 1
	self.previewModelPath = ""
	self.previewRenderTarget = GetRenderTarget("nw_term_profile_" .. self:EntIndex(), 256, 256)
	self.previewMaterial = CreateMaterial("nw_term_profile_mat_" .. self:EntIndex(), "UnlitGeneric", {
		["$basetexture"] = self.previewRenderTarget:GetName(),
		["$translucent"] = "1",
		["$vertexalpha"] = "1",
		["$vertexcolor"] = "1"
	})
end

function ENT:OnRemove()
	if (self.loopSound) then
		self.loopSound:Stop()
		self.loopSound = nil
	end

	if (IsValid(self.previewModel)) then
		self.previewModel:Remove()
	end
end

function ENT:IsAlarm()
	return self:GetNW2Float("nwTermAlarm", 0) > CurTime()
end

function ENT:GetAccent()
	return self:IsAlarm() and RED or LINE
end

function ENT:Request(action, data)
	net.Start("nwTerminal")
		net.WriteString(action)
		net.WriteEntity(self)
		net.WriteString(util.TableToJSON(data or {}))
	net.SendToServer()
end

function ENT:PlaySelectSound()
	self:EmitSound("network2/terminal/select" .. math.random(1, 2) .. ".wav", 62, math.random(97, 103), 0.75)
end

function ENT:Go(screen)
	self.screen = screen
	self.fade = CurTime()
end

-- the code in the header: the same for this terminal and this screen
function ENT:Code(screen)
	local seed = util.CRC(screen .. self:GetNW2Int("nwTermNumber", self:EntIndex()))
	local n = tonumber(seed) or 1

	return string.format("%d .. %d . %d . %d . .", 100000 + n % 9000000, 100 + n % 900, 1 + n % 9, 1 + n % 7)
end

-- -------------------------------------------------------- where one looks --
function ENT:GetAimCoordinates(client)
	if (!IsValid(client)) then
		return
	end

	local position, angles = self:GetScreenBasis()
	local eye = client:EyePos()
	local hit = util.IntersectRayWithPlane(eye, client:GetAimVector(), position, angles:Up())

	if (!hit or hit:DistToSqr(eye) > (T.reach * 1.6) ^ 2) then
		return
	end

	local relative = hit - position
	local x = relative:Dot(angles:Forward()) / self.ScreenScale + self.ScreenW * 0.5
	local y = relative:Dot(angles:Right()) / self.ScreenScale + self.ScreenH * 0.5

	if (x < -20 or x > self.ScreenW + 20 or y < -20 or y > self.ScreenH + 20) then
		return
	end

	self.aimX, self.aimY, self.aimTime = x, y, CurTime()

	return x, y
end

function ENT:GetHoveredButton(client)
	local x, y = self:GetAimCoordinates(client)

	if (!x) then
		return
	end

	for index = #self.buttons, 1, -1 do
		local button = self.buttons[index]

		if (!button.disabled and x >= button.x and x <= button.x + button.w and y >= button.y and
			y <= button.y + button.h) then
			return button
		end
	end
end

function ENT:AddButton(action, label, x, y, width, height, data)
	local button = {action = action, label = label, x = x, y = y, w = width, h = height, data = data}

	button.key = action .. "#" .. tostring(#self.buttons + 1)
	self.buttons[#self.buttons + 1] = button

	return button
end

-- ----------------------------------------------------------------- keys --
-- an outlined key: under the cursor it fills with light and the letters go dark
function ENT:Key(action, label, x, y, w, h, data, options)
	options = options or {}

	local button = self:AddButton(action, label, x, y, w, h, data)
	local accent = options.color or self:GetAccent()

	button.disabled = options.disabled

	self.keyFill = self.keyFill or {}

	local hovered = self.hoveredKey == button.key
	local target = (options.active or hovered) and 1 or 0
	local value = Lerp(math.min(FrameTime() * 14, 1), self.keyFill[button.key] or 0, target)

	self.keyFill[button.key] = value

	local alpha = options.disabled and 0.35 or 1

	surface.SetDrawColor(accent.r, accent.g, accent.b, 16 * alpha)
	surface.DrawRect(x, y, w, h)

	if (value > 0.01) then
		surface.SetDrawColor(FILL.r, FILL.g, FILL.b, 225 * value)
		surface.DrawRect(x, y, w, h)
	end

	Outline(x, y, w, h, accent, 210 * alpha)

	local color = Color(Lerp(value, TEXT.r, DARK.r), Lerp(value, TEXT.g, DARK.g), Lerp(value, TEXT.b, DARK.b),
		235 * alpha)

	Spaced(label, options.font or "nwTermText", options.left and x + 10 or x + w / 2, y + h / 2, color,
		options.left and 0 or 1, 1.6, value < 0.5)

	return button
end

-- a line of a list: name on the left, the cost on the right, a warning sign when out of reach
function ENT:Row(index, name, cost, y, selected, warning)
	local button = self:AddButton("select", "", LIST_X, y, LIST_W, 22, index)
	local hovered = self.hoveredKey == button.key
	local accent = self:GetAccent()

	if (selected) then
		surface.SetDrawColor(FILL.r, FILL.g, FILL.b, 150)
		surface.DrawRect(LIST_X, y, LIST_W, 22)
	elseif (hovered) then
		surface.SetDrawColor(FILL.r, FILL.g, FILL.b, 50)
		surface.DrawRect(LIST_X, y, LIST_W, 22)
	end

	Outline(LIST_X, y, LIST_W, 22, accent, selected and 230 or 110)

	local color = warning and Alpha(TEXT, 110) or TEXT

	Spaced(name, "nwTermSmall", LIST_X + 8, y + 11, color, 0, 1.4)

	if (warning) then
		Warning(LIST_X + LIST_W - 46, y + 11, 6, AMBER)
	end

	Spaced(cost, "nwTermSmall", LIST_X + LIST_W - 8, y + 11, color, 2, 1.2)
end

-- ------------------------------------------------------------- the frame --
function ENT:DrawHeader(title)
	local accent = self:GetAccent()

	Spaced(title .. "  ::  " .. self:Code(title), "nwTermSmall", X0, 20, Alpha(TEXT, 230), 0, 1.6)
	Spaced("ГРАЖД. СТАНЦИЯ 5.3.3.5X2", "nwTermTiny", X1 - 18, 20, Alpha(DIM, 230), 2, 1.2)
	Emblem(X1 - 6, 20, accent)
	Rule(X0, 32, X1 - X0, accent, 150)
end

function ENT:DrawFooter(credits)
	local accent = self:GetAccent()

	Rule(X0, H_ - 30, X1 - X0, accent, 110)
	Spaced(self:IsAlarm() and "ТРЕВОГА .. КАНАЛ ГО . ." or "ЦИКЛ РАЦИОНА .. АКТИВЕН . .", "nwTermTiny", X0, H_ - 17,
		self:IsAlarm() and RED or Alpha(DIM, 230), 0, 1.6)
	Spaced(os.date("%H:%M"), "nwTermText", X1, H_ - 17, Alpha(TEXT, 235), 2, 1.4)

	if (credits) then
		local w = Spaced(tostring(self.profile and self.profile.bank or 0), "nwTermHead", X1, H_ - 44, TEXT, 2, 1.4)

		Spaced("ВАШИ КРЕДИТЫ", "nwTermTiny", X1 - w - 8, H_ - 43, Alpha(DIM, 230), 2, 1.4)
	end
end

function ENT:DrawColumns(left, right, summary)
	local accent = self:GetAccent()

	Spaced(left, "nwTermTiny", LIST_X, 46, Alpha(DIM, 220), 0, 1.4)
	Spaced(right, "nwTermTiny", LIST_X + LIST_W - 8, 46, Alpha(DIM, 220), 2, 1.4)
	Spaced(summary or "СВОДКА", "nwTermTiny", SUM_X, 46, Alpha(DIM, 220), 0, 1.4)
	Rule(LIST_X, 54, LIST_W, accent, 90)
	Rule(SUM_X, 54, SUM_W, accent, 90)
end

function ENT:DrawSummary(title, lines, color)
	Spaced(title, "nwTermHead", SUM_X, 70, color or TEXT, 0, 1.6)

	for index, line in ipairs(Wrap(lines, "nwTermText", SUM_W, 1)) do
		if (index > 8) then
			break
		end

		Spaced(line, "nwTermText", SUM_X, 92 + (index - 1) * 15, Alpha(TEXT, 210), 0, 1)
	end
end

function ENT:DrawReturn(x)
	self:Key("back", "НАЗАД", x or 230, 254, 92, 22)
end

-- a list with pages (5 lines): returns the first index shown
function ENT:Pages(name, count)
	local page = math.Clamp(self.page[name] or 1, 1, math.max(1, math.ceil(count / 5)))

	self.page[name] = page

	if (count > 5) then
		self:Key("page_prev", "<", LIST_X, 222, 26, 20, name, {font = "nwTermSmall"})
		self:Key("page_next", ">", LIST_X + LIST_W - 26, 222, 26, 20, name, {font = "nwTermSmall"})
		Spaced(page .. " / " .. math.ceil(count / 5), "nwTermTiny", LIST_X + LIST_W / 2, 232, DIM, 1, 1.4)
	end

	return (page - 1) * 5 + 1
end

-- ---------------------------------------------------------------- screens --
local MENU = {
	{"go_housing", "Назначение жилья"},
	{"go_business", "Аренда помещений"},
	{"go_bank", "Кредитный баланс"},
	{"go_announcements", "Объявления города"},
	{"go_call", "Вызов Гражданской Обороны"},
	{"go_info", "Личное дело"},
	{"exit", "Завершить сеанс"}
}

function ENT:DrawRegister()
	self:DrawHeader("Авторизация")

	local stage = self.registrationStage
	local elapsed = CurTime() - self.registrationStarted

	if (stage == "idle") then
		local pulse = 0.75 + 0.25 * math.sin(CurTime() * 2.4)

		self:Key("register", "Идентификация гражданина", W_ / 2 - 130, 136, 260, 32, nil,
			{color = Alpha(LINE, 255 * pulse)})
		Spaced("Смотрите на экран и нажмите  [ E ]", "nwTermTiny", W_ / 2, 186, Alpha(DIM, 220), 1, 1.6)
	elseif (stage == "shrinking" or stage == "loading") then
		-- the scan: a bright line runs down the glass
		local scan = (elapsed * 0.8) % 1
		local y = 40 + scan * (H_ - 80)

		for i = 0, 8 do
			surface.SetDrawColor(FILL.r, FILL.g, FILL.b, (9 - i) * 14)
			surface.DrawRect(X0, y - i * 2, X1 - X0, 1)
		end

		Outline(W_ / 2 - 130, 136, 260, 32, LINE, 120 + 100 * math.abs(math.sin(CurTime() * 5)))
		Spaced("Сканирование" .. string.rep(" .", math.floor(CurTime() * 3) % 4), "nwTermText", W_ / 2, 152, TEXT, 1, 1.8)
	else
		-- the citizen as the station sees them: a lit key with the name and the number
		local profile = self.profile or {name = "Неизвестный", cid = "00000"}
		local appear = math.Clamp(elapsed / 0.3, 0, 1)
		local leave = stage == "flying" and math.Clamp(elapsed / 0.6, 0, 1) or 0
		local alpha = appear * (1 - leave)

		surface.SetDrawColor(FILL.r, FILL.g, FILL.b, 225 * alpha)
		surface.DrawRect(W_ / 2 - 130, 136, 260, 32)
		Outline(W_ / 2 - 130, 136, 260, 32, LINE, 255 * alpha)
		Spaced(profile.name .. "  #" .. tostring(profile.cid), "nwTermText", W_ / 2, 152, Alpha(DARK, 255 * alpha), 1, 1.8,
			false)
	end

	self:DrawFooter()
end

function ENT:DrawMain()
	self:DrawHeader("Навигация")

	local y = 46

	for _, entry in ipairs(MENU) do
		self:Key(entry[1], entry[2], W_ / 2 - 120, y, 240, 25)
		y = y + 31
	end

	self:DrawFooter()
end

function ENT:DrawHousing()
	self:DrawHeader("Назначение жилья")
	self:DrawColumns("Жилой блок", "Мест")

	local list = self.apartments
	local selected = self.selected.housing or 1
	local first = self:Pages("housing", #list)

	if (#list == 0) then
		Spaced("Данные загружаются . . .", "nwTermSmall", LIST_X, 74, DIM, 0, 1.4)
	end

	for index = first, math.min(#list, first + 4) do
		local entry = list[index]
		local full = entry.current >= entry.maximum

		self:Row(index, entry.name, entry.current .. "/" .. entry.maximum, 62 + (index - first) * 31,
			index == selected, full)
	end

	local entry = list[selected]
	local home = self.profile and self.profile.home or ""

	if (self.housingMessage != "") then
		self:DrawSummary("Отказ", self.housingMessage, AMBER)
	elseif (entry) then
		local full = entry.current >= entry.maximum

		self:DrawSummary(entry.name, (full and "Мест нет. " or "Есть свободные места. ") .. "Заселено " ..
			entry.current .. " из " .. entry.maximum .. ". Назначение проводит система распределения: " ..
			"жильё выбирается из блоков со свободными местами.", full and AMBER or TEXT)
	end

	if (home != "") then
		Spaced("Ваше жильё: " .. home, "nwTermTiny", SUM_X, 236, Alpha(TEXT, 220), 0, 1.4)
	else
		self:Key("housing_request", "Получить назначение", SUM_X, 254, 150, 22)
	end

	self:DrawReturn(SUM_X + 158)
	self:DrawFooter(true)
end

function ENT:DrawRoulette()
	self:DrawHeader("Назначение жилья")

	local progress = math.Clamp((CurTime() - self.housingRouletteStart) / 4, 0, 1)
	local eased = 1 - (1 - progress) ^ 4
	local cardH = 26
	local offset = (#self.housingSequence - 1) * (cardH + 4) * eased
	local passed = math.floor(offset / (cardH + 4))

	if (passed > self.housingTicks and progress < 1) then
		self.housingTicks = passed
		self:EmitSound("network2/terminal/select1.wav", 55, 120 + passed, 0.35)
	end

	Outline(W_ / 2 - 150, 44, 300, 222, self:GetAccent(), 120)

	for index, name in ipairs(self.housingSequence) do
		local y = 142 + (index - 1) * (cardH + 4) - offset

		if (y > 46 and y + cardH < 264) then
			local near = 1 - math.min(math.abs(y + cardH / 2 - 155) / 90, 1)

			if (near > 0.85) then
				surface.SetDrawColor(FILL.r, FILL.g, FILL.b, 200 * near)
				surface.DrawRect(W_ / 2 - 140, y, 280, cardH)
			end

			Outline(W_ / 2 - 140, y, 280, cardH, LINE, 60 + near * 150)
			Spaced(name, "nwTermText", W_ / 2, y + cardH / 2, near > 0.85 and DARK or Alpha(TEXT, 90 + near * 165), 1,
				1.6, near <= 0.85)
		end
	end

	if (progress >= 1) then
		self.assigned = {title = "Жильё назначено", name = self.housingChosen, back = "housing"}
		self:Go("assigned")
		self:EmitSound("network2/terminal/boot.wav", 60, 115, 0.6)
	end

	self:DrawFooter()
end

-- the result: a lit panel on the left (as STOREFRONT ASSIGNED), the summary on the right
function ENT:DrawAssigned()
	local assigned = self.assigned or {title = "", name = ""}

	self:DrawHeader(assigned.back == "business" and "Распределение помещений" or "Назначение жилья")
	self:DrawColumns("", "", "Сводка")

	surface.SetDrawColor(FILL.r, FILL.g, FILL.b, 70)
	surface.DrawRect(LIST_X, 62, LIST_W, 170)
	surface.SetDrawColor(FILL.r, FILL.g, FILL.b, 230)
	surface.DrawRect(LIST_X, 62, LIST_W, 2)
	Outline(LIST_X, 62, LIST_W, 170, LINE, 160)
	Spaced(assigned.title, "nwTermSmall", LIST_X + LIST_W / 2, 132, TEXT, 1, 1.8)
	Spaced(assigned.name, "nwTermHead", LIST_X + LIST_W / 2, 154, TEXT, 1, 1.8)

	self:DrawSummary(assigned.name, assigned.back == "business" and
		"Помещение закреплено за вами. Аренда списана с кредитного счёта. Дверь отзывается на /doorlock." or
		"Вы зарегистрированы по этому адресу. Дверь отзывается на /doorlock. Нарушение режима проживания " ..
		"будет зафиксировано.")
	self:DrawReturn(SUM_X)
	self:DrawFooter(true)
end

function ENT:DrawBusiness()
	self:DrawHeader("Распределение помещений")
	self:DrawColumns("Помещение", "Цена")

	local list = self.businesses
	local selected = self.selected.business
	local bank = self.profile and self.profile.bank or 0
	local first = self:Pages("business", #list)

	if (#list == 0) then
		Spaced("Свободных помещений нет", "nwTermSmall", LIST_X, 74, DIM, 0, 1.4)
	end

	for index = first, math.min(#list, first + 4) do
		local entry = list[index]

		self:Row(index, entry.name, entry.price, 62 + (index - first) * 31, index == selected, bank < entry.price)
	end

	local entry = selected and list[selected]

	if (entry) then
		local enough = bank >= entry.price

		self:DrawSummary(entry.name, "Коммерческое помещение городского блока. Стоимость аренды " .. entry.price ..
			" кредитов списывается со счёта. " .. (enough and "Средств достаточно." or "Недостаточно средств на счёте."),
			enough and TEXT or AMBER)
		self:Key("rent", "Оформить", SUM_X, 254, 120, 22, entry, {disabled = !enough})
	else
		self:DrawSummary("Выберите помещение", "Наведите на строку слева и нажмите E, чтобы увидеть условия аренды.")
	end

	self:DrawReturn(SUM_X + 128)
	self:DrawFooter(true)
end

function ENT:DrawBank()
	self:DrawHeader("Кредитный баланс")
	self:DrawColumns("Счёт", "", "Операции")

	local profile = self.profile or {bank = 0, tokens = 0, logs = {}}

	Spaced("На счёте", "nwTermTiny", LIST_X, 74, DIM, 0, 1.4)
	Spaced(tostring(profile.bank or 0) .. " кр.", "nwTermTitle", LIST_X, 98, TEXT, 0, 1.8)
	Rule(LIST_X, 116, LIST_W, self:GetAccent(), 80)
	Spaced("На руках", "nwTermTiny", LIST_X, 132, DIM, 0, 1.4)
	Spaced(tostring(profile.tokens or 0) .. " ток.", "nwTermHead", LIST_X, 152, TEXT, 0, 1.6)

	local logs = profile.logs or {}

	if (#logs == 0) then
		Spaced("Операций не было", "nwTermSmall", SUM_X, 74, DIM, 0, 1.4)
	end

	for index = 1, math.min(#logs, 7) do
		local log = logs[index]
		local y = 74 + (index - 1) * 20

		Spaced(log.time, "nwTermTiny", SUM_X, y, DIM, 0, 1.2)
		Spaced(log.text, "nwTermSmall", SUM_X + 40, y, log.positive and TEXT or Alpha(TEXT, 180), 0, 1.2)
	end

	self:Key("bank_deposit", "Внести", LIST_X, 254, 110, 22)
	self:Key("bank_withdraw", "Снять", LIST_X + 118, 254, 110, 22)
	self:DrawReturn(SUM_X)
	self:DrawFooter()
end

function ENT:DrawAnnouncements()
	self:DrawHeader("Объявления города")
	self:DrawColumns("Сообщение", "Дата")

	local list = self.announcements
	local selected = self.selected.announcements or 1
	local first = self:Pages("announcements", #list)

	if (#list == 0) then
		Spaced("Сообщения отсутствуют", "nwTermSmall", LIST_X, 74, DIM, 0, 1.4)
	end

	for index = first, math.min(#list, first + 4) do
		local entry = list[index]

		self:Row(index, entry.title, string.match(entry.gameTime or "", "^%S+") or "", 62 + (index - first) * 31,
			index == selected, entry.priority == "critical")
	end

	local entry = list[selected]

	if (entry) then
		local priority = T.priorities[entry.priority] or T.priorities.normal

		self:DrawSummary(entry.title, entry.body, entry.priority == "normal" and TEXT or priority.color)
		Spaced((entry.author or "") .. "  ·  " .. (entry.gameTime or ""), "nwTermTiny", SUM_X, 236, DIM, 0, 1.4)

		if ((entry.photo or "") != "") then
			self:Key("photo", "Фото", SUM_X + 148, 254, 80, 22, entry)
		end
	end

	self:DrawReturn(SUM_X)
	self:DrawFooter()
end

function ENT:DrawCall()
	self:DrawHeader("Запрос Гражданской Обороны")
	self:DrawColumns("Причина обращения", "", "Сводка")

	local locked = self:IsAlarm()

	Outline(LIST_X, 62, LIST_W, 150, locked and RED or self:GetAccent(), 160)

	if (locked) then
		local blink = math.sin(CurTime() * 6) > 0

		Spaced("Сигнал передан", "nwTermHead", LIST_X + LIST_W / 2, 122, blink and RED or Alpha(RED, 160), 1, 1.8)
		Spaced("Канал закрыт: " .. math.ceil(self:GetNW2Float("nwTermAlarm", 0) - CurTime()) .. " сек.", "nwTermSmall",
			LIST_X + LIST_W / 2, 146, Alpha(RED, 220), 1, 1.4)
	elseif (self.callDraft == "") then
		Spaced("Причина не указана", "nwTermSmall", LIST_X + LIST_W / 2, 137, DIM, 1, 1.4)
	else
		for index, line in ipairs(Wrap(self.callDraft, "nwTermText", LIST_W - 20, 1)) do
			if (index > 8) then
				break
			end

			Spaced(line, "nwTermText", LIST_X + 10, 76 + (index - 1) * 16, TEXT, 0, 1)
		end
	end

	self:DrawSummary("Патруль ГО", "Сообщение будет передано всем подразделениям Гражданской Обороны вместе с " ..
		"вашим именем и номером. Ложный вызов является нарушением.", locked and RED or TEXT)

	if (!locked) then
		self:Key("call_input", self.callDraft == "" and "Указать причину" or "Изменить", LIST_X, 222, 140, 22)

		if (self.callDraft != "") then
			self:Key("call_confirm", "Отправить", SUM_X, 254, 120, 22, nil, {color = RED})
		end
	end

	self:DrawReturn(SUM_X + 128)
	self:DrawFooter()
end

function ENT:DrawInfo()
	self:DrawHeader("Личное дело")
	self:DrawColumns("Данные гражданина", "", "Биометрия")

	local profile = self.profile or {name = "—", cid = "—", faction = "—", bank = 0, home = ""}
	local rows = {
		{"Гражданин", profile.name},
		{"Идентификатор", "#" .. tostring(profile.cid)},
		{"Статус", tostring(profile.faction)},
		{"Место жительства", (profile.home or "") != "" and profile.home or "Не назначено"}
	}

	for index, row in ipairs(rows) do
		local y = 70 + (index - 1) * 38

		Spaced(row[1], "nwTermTiny", LIST_X, y, DIM, 0, 1.4)
		Spaced(row[2], "nwTermText", LIST_X, y + 15, index == 1 and (profile.color or TEXT) or TEXT, 0, 1.4)
		Rule(LIST_X, y + 26, LIST_W, self:GetAccent(), 60)
	end

	-- the silhouette, and the weather under it
	Outline(SUM_X, 62, 96, 150, self:GetAccent(), 120)

	if (self.previewMaterial) then
		surface.SetDrawColor(156, 230, 244, 120)
		surface.SetMaterial(self.previewMaterial)
		surface.DrawTexturedRect(SUM_X, 64, 96, 146)
	end

	local weather = T.Weather()

	Spaced("Метеосводка", "nwTermTiny", SUM_X + 108, 70, DIM, 0, 1.4)
	Spaced((weather.temperature > 0 and "+" or "") .. weather.temperature .. "°", "nwTermTitle", SUM_X + 108, 94, TEXT,
		0, 1.6)

	for index, line in ipairs(Wrap(weather.sky, "nwTermSmall", 120, 1.2)) do
		Spaced(line, "nwTermSmall", SUM_X + 108, 116 + (index - 1) * 13, TEXT, 0, 1.2)
	end

	Spaced("Ветер " .. weather.wind .. " м/с", "nwTermTiny", SUM_X + 108, 156, DIM, 0, 1.2)
	Spaced("Влажность " .. weather.humidity .. "%", "nwTermTiny", SUM_X + 108, 170, DIM, 0, 1.2)
	Spaced("Воздух: " .. weather.air, "nwTermTiny", SUM_X + 108, 184,
		weather.air == "В НОРМЕ" and DIM or AMBER, 0, 1.2)

	self:DrawReturn(SUM_X)
	self:DrawFooter(true)
end

function ENT:DrawAimCursor()
	if (!self.aimX or CurTime() - (self.aimTime or 0) > 0.15) then
		return
	end

	local x, y = math.Clamp(self.aimX, 0, W_), math.Clamp(self.aimY, 0, H_)
	local size = self.hoveredKey and 20 or 16

	surface.SetMaterial(self.hoveredKey and CURSOR_HOVER or CURSOR)
	surface.SetDrawColor(255, 255, 255, 240)
	-- the hotspot of both cursors is the middle of the image
	surface.DrawTexturedRect(x - size / 2, y - size / 2, size, size)
end

local SCREENS = {
	main = "DrawMain", housing = "DrawHousing", roulette = "DrawRoulette", assigned = "DrawAssigned",
	business = "DrawBusiness", bank = "DrawBank", announcements = "DrawAnnouncements", call = "DrawCall",
	info = "DrawInfo"
}

function ENT:DrawScreen(width, height)
	self.buttons = {}

	local accent = self:GetAccent()
	local alpha = (0.92 + math.sin(CurTime() * 1.3) * 0.03) * (self.flicker or 1)

	-- the glass: the wallpaper, a light veil of the accent, a slow sweep of light
	surface.SetDrawColor(255, 255, 255, 200 * alpha)
	surface.SetMaterial(BG)
	surface.DrawTexturedRect(0, 0, width, height)
	surface.SetDrawColor(4, 26, 34, 95)
	surface.DrawRect(0, 0, width, height)

	if (self:IsAlarm()) then
		surface.SetDrawColor(RED.r, RED.g, RED.b, 18 + 12 * math.abs(math.sin(CurTime() * 3)))
		surface.DrawRect(0, 0, width, height)
	end

	local sweep = math.fmod(CurTime() * 30, height + 80) - 40

	for i = 0, 10 do
		surface.SetDrawColor(accent.r, accent.g, accent.b, (11 - i) * 2.2)
		surface.DrawRect(0, sweep + i * 2, width, 2)
	end

	-- the bright rim of the glass
	for i = 0, 9 do
		local a = (10 - i) ^ 2 * 1.2

		surface.SetDrawColor(accent.r, accent.g, accent.b, a)
		surface.DrawRect(i, 0, 1, height)
		surface.DrawRect(width - 1 - i, 0, 1, height)
		surface.DrawRect(0, i, width, 1)
		surface.DrawRect(0, height - 1 - i, width, 1)
	end

	-- a short fade between screens
	local fade = math.Clamp((CurTime() - (self.fade or 0)) / 0.18, 0, 1)

	surface.SetAlphaMultiplier(fade * alpha)

	if (!self.registered) then
		self:DrawRegister()
	else
		self[SCREENS[self.screen] or "DrawMain"](self)
	end

	surface.SetAlphaMultiplier(1)

	if (self.actionMessage != "" and CurTime() < self.actionMessageUntil) then
		surface.SetDrawColor(FILL.r, FILL.g, FILL.b, 225)
		surface.DrawRect(X0, H_ - 62, X1 - X0, 18)
		Spaced(self.actionMessage, "nwTermSmall", W_ / 2, H_ - 53, DARK, 1, 1.6, false)
	end

	self:DrawAimCursor()
end

-- ------------------------------------------------------------------- think --
function ENT:Think()
	local client = LocalPlayer()

	if (CurTime() > self.nextFlicker) then
		self.flicker = math.Rand(0.96, 1)
		self.nextFlicker = CurTime() + math.Rand(0.08, 0.2)
	end

	if (IsValid(client)) then
		local distance = client:GetPos():Distance(self:GetPos())

		if (distance <= 850) then
			if (!self.loopSound) then
				self.loopSound = CreateSound(self, "network2/terminal/loop.wav")

				if (self.loopSound) then
					self.loopSound:PlayEx(0.17, 100)
				end
			end
		elseif (distance > 1050 and self.loopSound) then
			self.loopSound:FadeOut(0.35)
			self.loopSound = nil
		end

		-- walked away: the session ends
		if (self.registrationStage != "idle" and distance > 220) then
			self:ResetSession()
		end

		local hovered = self:GetHoveredButton(client)
		local key = hovered and hovered.key or nil

		-- a soft tick when the cursor comes onto another key
		if (key and key != self.hoveredKey) then
			self:EmitSound("network2/terminal/select1.wav", 50, 150, 0.15)
		end

		self.hoveredButton = hovered
		self.hoveredKey = key
	end

	local stage, elapsed = self.registrationStage, CurTime() - self.registrationStarted

	if (stage == "shrinking" and elapsed >= 0.3) then
		self.registrationStage, self.registrationStarted = "loading", CurTime()
		self:EmitSound("network2/terminal/boot.wav", 60, 100, 0.6)
	elseif (stage == "loading" and elapsed >= 1.6 and self.profile) then
		self.registrationStage, self.registrationStarted = "identity", CurTime()
	elseif (stage == "identity" and elapsed >= 1.4) then
		self.registrationStage, self.registrationStarted = "flying", CurTime()
	elseif (stage == "flying" and elapsed >= 0.6) then
		self.registrationStage = "ready"
		self.registered = true
		self:Go("main")
	end

	self:SetNextClientThink(CurTime())

	return true
end

-- --------------------------------------------------------------- answers --
function ENT:Receive(action, data)
	if (action == "profile") then
		self.profile = data

		local c = data.factionColor or {}

		self.profile.color = Color(c[1] or 156, c[2] or 230, c[3] or 244)
	elseif (action == "announcements") then
		self.announcements = data.list or {}
	elseif (action == "housinglist") then
		self.apartments = data.list or {}
	elseif (action == "business") then
		self.businesses = data.list or {}
		self.selected.business = nil
	elseif (action == "housing") then
		if (!data.success) then
			self.housingMessage = data.message or ""
			self:EmitSound("network2/terminal/deny.wav", 60)

			return
		end

		local names = (data.names and #data.names > 0) and data.names or {data.chosen}

		self.housingChosen = data.chosen
		self.housingMessage = ""
		self.housingSequence = {}
		self.housingRouletteStart = CurTime()
		self.housingTicks = 0

		for index = 1, 28 do
			self.housingSequence[index] = names[math.random(#names)]
		end

		self.housingSequence[28] = data.chosen
		self:Go("roulette")
		self:Request("profile")
		self:Request("housinglist")
	elseif (action == "rented") then
		self.assigned = {title = "Помещение назначено", name = data.name or "", back = "business"}
		self:Go("assigned")
		self:EmitSound("network2/terminal/boot.wav", 60, 115, 0.6)
	elseif (action == "call") then
		self.actionMessage = data.success and "Сигнал передан" or "Ошибка передачи"
		self.actionMessageUntil = CurTime() + 3

		if (!data.success) then
			self:EmitSound("network2/terminal/deny.wav", 60)
		end
	elseif (action == "result") then
		self.actionMessage = data.message or ""
		self.actionMessageUntil = CurTime() + 3
	end
end

-- -------------------------------------------------------------- the preview --
function ENT:EnsurePreviewModel()
	local path = self.profile and self.profile.model or ""

	if (path == "" or path == self.previewModelPath) then
		return
	end

	if (IsValid(self.previewModel)) then
		self.previewModel:Remove()
	end

	self.previewModel = ClientsideModel(path, RENDERGROUP_OPAQUE)

	if (!IsValid(self.previewModel)) then
		return
	end

	self.previewModel:SetNoDraw(true)
	self.previewModel:SetPos(vector_origin)
	self.previewModel:SetAngles(Angle(0, 180, 0))

	local idle = self.previewModel:LookupSequence("idle_all_01")

	self.previewModel:ResetSequence(idle > 0 and idle or 0)
	self.previewModelPath = path
end

function ENT:RenderPreview()
	if (self.screen != "info" or !self.registered or !self.profile) then
		return
	end

	self:EnsurePreviewModel()

	if (!IsValid(self.previewModel)) then
		return
	end

	self.previewModel:SetAngles(Angle(0, 180 + math.sin(CurTime() * 0.6) * 25, 0))

	render.PushRenderTarget(self.previewRenderTarget)
	render.Clear(0, 0, 0, 0, true, true)
	cam.Start3D(Vector(78, 0, 40), Angle(0, 180, 0), 38, 0, 0, 256, 256, 1, 1000)
		render.SuppressEngineLighting(true)
		render.SetColorModulation(0.005, 0.005, 0.005)
		self.previewModel:DrawModel()
		render.SetColorModulation(1, 1, 1)
		render.SuppressEngineLighting(false)
	cam.End3D()
	render.PopRenderTarget()
end

-- --------------------------------------------------------------- pressing E --
local SELECT = {housing = "housing", business = "business", announcements = "announcements"}

function ENT:HandleUse(client)
	if (!T.IsNear(client, self)) then
		return false
	end

	-- the Alliance at an alarmed terminal: E (anywhere on the screen) closes the call
	if (self:IsAlarm() and NW.zones.IsAlliance(client)) then
		self:Request("resolve")
		self:PlaySelectSound()

		return true
	end

	local button = self:GetHoveredButton(client)

	if (!button) then
		return false
	end

	local action = button.action

	if (action == "register") then
		if (self.registrationStage == "idle") then
			self:PlaySelectSound()
			self.registrationStage = "shrinking"
			self.registrationStarted = CurTime()
			self.profile = nil
			self:Request("profile")
		end

		return true
	end

	if (!self.registered) then
		return true
	end

	self:PlaySelectSound()

	if (action == "back") then
		self.housingMessage = ""
		self:Go(self.screen == "assigned" and (self.assigned and self.assigned.back or "main") or "main")

		if (self.screen == "business") then
			self:Request("business")
		end
	elseif (action == "exit") then
		self:ResetSession()
	elseif (action == "go_housing") then
		self.housingMessage = ""
		self.apartments = {}
		self:Go("housing")
		self:Request("housinglist")
		self:Request("profile")
	elseif (action == "go_business") then
		self.businesses = {}
		self:Go("business")
		self:Request("business")
		self:Request("profile")
	elseif (action == "go_bank") then
		self:Go("bank")
		self:Request("profile")
	elseif (action == "go_announcements") then
		self:Go("announcements")
		self:Request("announcements")
	elseif (action == "go_call") then
		self:Go("call")
	elseif (action == "go_info") then
		self:Go("info")
		self:Request("profile")
	elseif (action == "select") then
		local list = SELECT[self.screen]

		if (list) then
			self.selected[list] = button.data
		end
	elseif (action == "page_prev" or action == "page_next") then
		local name = button.data

		self.page[name] = (self.page[name] or 1) + (action == "page_next" and 1 or -1)
	elseif (action == "photo") then
		if ((button.data.photo or "") != "") then
			T.OpenPhoto(button.data.photo, button.data.title)
		end
	elseif (action == "call_input") then
		T.OpenTextPrompt("Причина вызова Г.О", self.callDraft, function(value)
			if (IsValid(self)) then
				self.callDraft = value
			end
		end, true)
	elseif (action == "call_confirm") then
		if (self.callDraft != "") then
			self:Request("call", {text = self.callDraft})
			self.callDraft = ""
		end
	elseif (action == "housing_request") then
		self.housingMessage = ""
		self:Request("housing")
	elseif (action == "rent") then
		self:Request("rent", {door = button.data.door})
	elseif (action == "bank_withdraw" or action == "bank_deposit") then
		local deposit = action == "bank_deposit"

		T.OpenNumberPrompt(deposit and "Внести токены на счёт" or "Снять токены со счёта", function(amount)
			if (IsValid(self)) then
				self:Request("bank", {deposit = deposit, amount = amount})
			end
		end)
	end

	return true
end

-- -------------------------------------------------------------------- draw --
function ENT:Draw()
	self:DrawModel()
end

-- the screen (translucent pass, after the model)
function ENT:DrawTranslucent()
	if (self:GetPos():DistToSqr(EyePos()) > 1000 * 1000) then
		return
	end

	self:RenderPreview()

	local position, angles = self:GetScreenBasis()
	local accent = self:GetAccent()
	local light = DynamicLight(self:EntIndex())

	if (light) then
		light.pos = position + self:GetForward() * 6
		light.r, light.g, light.b = accent.r, accent.g, accent.b
		light.brightness = 0.35 * (self.flicker or 1)
		light.decay = 900
		light.size = 90
		light.dietime = CurTime() + 0.1
	end

	local width, height = self.ScreenW, self.ScreenH

	cam.Start3D2D(position, angles, self.ScreenScale)
		surface.DisableClipping(true)

		local matrix = Matrix()

		matrix:Translate(Vector(-width * 0.5, -height * 0.5, 0))
		cam.PushModelMatrix(matrix, true)

		local success, problem = xpcall(function()
			self:DrawScreen(width, height)
		end, function(message)
			return debug.traceback(tostring(message), 2)
		end)

		cam.PopModelMatrix()
		surface.DisableClipping(false)
	cam.End3D2D()

	if (!success) then
		surface.SetAlphaMultiplier(1)

		if (CurTime() >= (self.nextRenderError or 0)) then
			self.nextRenderError = CurTime() + 1
			ErrorNoHalt("[Network terminal] " .. tostring(problem) .. "\n")
		end
	end
end
