-- The civic terminal (after the Helix ix_civic_terminal; the rules: gamemode/core/sh_terminal.lua,
-- the server: sv_terminal.lua, the windows and the E key: cl_terminal.lua).
-- A Combine station with a holographic screen: the player looks at a button and presses E. The
-- screen is drawn in 3D2D on the model (models/combine/combine_terminal.mdl) over its own wallpaper
-- (materials/network2/terminal/wallpaper.png); a cursor follows the exact point of the screen the
-- player looks at (cursor.png, over a button cursor_hover.png).
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

	function ENT:OnRemove()
		if (NW.terminal.Changed) then
			NW.terminal.Changed()
		end
	end

	return
end

-- ------------------------------------------------------------------ client --
local T = NW.terminal

local BLUE = Color(30, 168, 196)
local BLUE_SOFT = Color(96, 186, 206)
local BLUE_DIM = Color(38, 100, 116)
local WHITE = Color(168, 208, 216)
local RED = Color(184, 62, 60)
local RED_SOFT = Color(198, 110, 100)
local AMBER = Color(214, 168, 72)

local BG = Material("network2/terminal/wallpaper.png", "smooth noclamp")
local CURSOR = Material("network2/terminal/cursor.png", "smooth")
local CURSOR_HOVER = Material("network2/terminal/cursor_hover.png", "smooth")

local function Font(name, font, size, weight)
	surface.CreateFont(name, {font = font, size = size, weight = weight, extended = true, antialias = true})
end

Font("nwTerm3DTitle", "Oswald Medium", 22, 500)
Font("nwTerm3DHeader", "Oswald Medium", 17, 500)
Font("nwTerm3DTab", "Oswald Medium", 12, 500)
Font("nwTerm3DButton", "Oswald Medium", 14, 500)
Font("nwTerm3DText", "Oswald Light", 14, 300)
Font("nwTerm3DSmall", "Oswald Light", 11, 300)
Font("nwTerm3DTiny", "Oswald Light", 9, 300)

local descriptions = {
	info = "Личный кабинет гражданина. Идентификация, статус и банковский счёт.",
	announcements = "Городские сообщения, распоряжения администрации и важные обновления сети.",
	call = "Экстренный канал связи с патрулём Гражданской Обороны. Только при необходимости.",
	housing = "Назначение места жительства и список апартаментов жилого блока.",
	additional = "Метеосводка, банковские операции и аренда коммерческих помещений."
}

local TOP_TABS = {
	{action = "open_info", label = "ПРОФИЛЬ", screen = "info", description = descriptions.info},
	{action = "open_announcements", label = "ОБЪЯВЛЕНИЯ", screen = "announcements", description = descriptions.announcements},
	{action = "open_call", label = "ВЫЗОВ Г.О", screen = "call", description = descriptions.call},
	{action = "open_housing", label = "ЖИЛЬЁ", screen = "housing", description = descriptions.housing},
	{action = "open_additional", label = "СЕРВИСЫ", screen = "additional", description = descriptions.additional}
}

local function Alpha(color, alpha)
	return Color(color.r, color.g, color.b, math.Clamp(alpha or 255, 0, 255))
end

local function Text(text, font, x, y, color, alignX, alignY, glow)
	glow = glow or 0.14

	if (glow > 0.01) then
		local halo = Alpha(color, (color.a or 255) * glow)

		draw.SimpleText(text, font, x - 1, y, halo, alignX, alignY)
		draw.SimpleText(text, font, x + 1, y, halo, alignX, alignY)
		draw.SimpleText(text, font, x, y - 1, halo, alignX, alignY)
		draw.SimpleText(text, font, x, y + 1, halo, alignX, alignY)
	end

	draw.SimpleText(text, font, x, y, color, alignX, alignY)
end

local function Wrap(text, font, maxWidth)
	surface.SetFont(font)

	local lines, current = {}, ""

	for _, word in ipairs(string.Explode(" ", tostring(text or ""))) do
		local candidate = current == "" and word or current .. " " .. word

		if (surface.GetTextSize(candidate) > maxWidth and current != "") then
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

local NAV_X, NAV_Y, NAV_W, NAV_H, NAV_GAP = 28, 46, 504, 22, 3
local CONTENT_X, CONTENT_W = 28, 504

local function Line(x, y, width, color, alpha)
	surface.SetDrawColor(color.r, color.g, color.b, alpha or 90)
	surface.DrawRect(math.floor(x), math.floor(y), math.floor(width), 1)
end

local function Box(x, y, width, height, color, alpha)
	surface.SetDrawColor(color.r, color.g, color.b, math.Clamp((alpha or 34) + 26, 0, 255))
	surface.DrawOutlinedRect(math.floor(x), math.floor(y), math.floor(width), math.floor(height), 1)
end

-- --------------------------------------------------------------- the state --
function ENT:ResetSession()
	self.registered = false
	self.registrationStage = "idle"
	self.registrationStarted = 0
	self.screen = "register"
	self.profile = nil
	self.announcements = {}
	self.apartments = {}
	self.businesses = {}
	self.selectedAnnouncement = nil
	self.announcementPage = 1
	self.callDraft = ""
	self.housingMessage = ""
	self.housingChosen = ""
	self.housingSequence = nil
	self.housingRouletteStart = 0
	self.housingTicks = 0
	self.actionMessage = ""
	self.actionMessageUntil = 0
	self.buttons = {}
end

function ENT:Initialize()
	self:ResetSession()
	self.nextFlicker = 0
	self.flicker = 1
	self.lastNear = 0
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

function ENT:GetAccent()
	return self:GetNW2Float("nwTermAlarm", 0) > CurTime() and RED or BLUE
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

		if (x >= button.x and x <= button.x + button.w and y >= button.y and y <= button.y + button.h) then
			return button
		end
	end
end

function ENT:AddButton(action, label, x, y, width, height, data, description)
	local button = {action = action, label = label, x = x, y = y, w = width, h = height, data = data,
		description = description}

	button.key = action .. "#" .. tostring(#self.buttons + 1)
	self.buttons[#self.buttons + 1] = button

	return button
end

-- ----------------------------------------------------------------- drawing --
function ENT:DrawButton(button, accent, alpha, alignLeft)
	alpha = alpha or 1
	self.buttonAnimations = self.buttonAnimations or {}

	local hovered = self.hoveredKey == button.key
	local target = button.active and 1 or (hovered and 0.4 or 0)
	local value = Lerp(math.min(FrameTime() * 15, 1), self.buttonAnimations[button.key] or 0, target)

	self.buttonAnimations[button.key] = value

	local x, y, w, h = math.floor(button.x), math.floor(button.y), math.floor(button.w), math.floor(button.h)

	if (value > 0.01) then
		surface.SetDrawColor(accent.r, accent.g, accent.b, 196 * value * alpha)
		surface.DrawRect(x, y, w, h)
	end

	surface.SetDrawColor(accent.r, accent.g, accent.b, (150 - value * 58) * alpha)
	surface.DrawOutlinedRect(x, y, w, h, 1)

	-- a small corner tick on the left: a holographic key
	surface.SetDrawColor(accent.r, accent.g, accent.b, (200 - value * 120) * alpha)
	surface.DrawRect(x, y, 3, 1)
	surface.DrawRect(x, y, 1, 3)

	local color = Color(Lerp(value, BLUE_SOFT.r, 3), Lerp(value, BLUE_SOFT.g, 27), Lerp(value, BLUE_SOFT.b, 34))

	Text(button.label, button.font or "nwTerm3DButton", alignLeft and x + 13 or x + w * 0.5, y + h * 0.5,
		Alpha(color, 228 * alpha), alignLeft and TEXT_ALIGN_LEFT or TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
		0.16 * (1 - value))
end

function ENT:DrawHeader(width, height, accent, alpha)
	Text("CIVIC NETWORK // ACCESS TERMINAL", "nwTerm3DTiny", 28, 25, Alpha(BLUE_DIM, 205 * alpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
	Text("СТАНЦИЯ АЛЬЯНСА 08 0 " .. string.format("%03d", self:GetNW2Int("nwTermNumber", self:EntIndex())),
		"nwTerm3DSmall", width - 57, 27, Alpha(accent, 218 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	Line(28, 42, width - 56, accent, 58 * alpha)

	local ix, iy = width - 38, 28

	surface.DrawCircle(ix, iy, 10, Alpha(accent, 200 * alpha))
	surface.DrawCircle(ix, iy, 9, Alpha(accent, 90 * alpha))
	surface.DrawCircle(ix, iy, 4, Alpha(accent, 170 * alpha))
	surface.SetDrawColor(accent.r, accent.g, accent.b, 215 * alpha)
	surface.DrawRect(ix - 1, iy - 10, 2, 5)
	surface.DrawRect(ix - 1, iy + 5, 2, 5)
end

function ENT:DrawFooter(width, height, accent)
	Line(28, height - 31, width - 56, accent, 26)
	Text("||:07·17·04::  18·4·2::  C17//ACTIVE", "nwTerm3DTiny", 28, height - 18, Alpha(accent, 155), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
	Text("::7·04::", "nwTerm3DTiny", 132, height - 18, Alpha(RED, 165), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	Text("//" .. os.date("%H:%M"), "nwTerm3DSmall", width - 28, height - 18, Alpha(BLUE_SOFT, 210), TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)
end

function ENT:GetActiveTopTab()
	local screen = self.screen

	if (screen == "announcement_detail") then
		return "announcements"
	elseif (screen == "housing_list" or screen == "housing_roulette") then
		return "housing"
	elseif (screen == "weather" or screen == "bank" or screen == "business") then
		return "additional"
	end

	return screen
end

function ENT:DrawNavigation(accent)
	local active = self:GetActiveTopTab()
	local tabWidth = (NAV_W - NAV_GAP * (#TOP_TABS - 1)) / #TOP_TABS

	for index, tab in ipairs(TOP_TABS) do
		local button = self:AddButton(tab.action, tab.label, NAV_X + (index - 1) * (tabWidth + NAV_GAP), NAV_Y, tabWidth,
			NAV_H, nil, tab.description)

		button.font = "nwTerm3DTab"
		button.active = active == tab.screen
		self:DrawButton(button, accent, 1, false)
	end
end

function ENT:DrawWorkspaceHeader(accent)
	local description = self.hoveredDescription
	local active = self:GetActiveTopTab()

	if (!description) then
		for _, tab in ipairs(TOP_TABS) do
			if (tab.screen == active) then
				description = tab.description
			end
		end
	end

	description = description or "Выберите вкладку для доступа к городским службам."

	local lines = Wrap(description, "nwTerm3DSmall", CONTENT_W - 4)

	Text(lines[1] or description, "nwTerm3DSmall", CONTENT_X, 77, Alpha(BLUE_SOFT, 205), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
	Line(CONTENT_X, 86, CONTENT_W, accent, 42)
end

function ENT:DrawBackButton()
	local button = self:AddButton("back", "НАЗАД", CONTENT_X + CONTENT_W - 64, 266, 64, 17)

	button.font = "nwTerm3DTiny"
	self:DrawButton(button, self:GetAccent(), 1, false)
end

function ENT:DrawRegister(width, height, accent)
	Text("ГРАЖДАНСКИЙ", "nwTerm3DTitle", 48, 91, Alpha(BLUE_SOFT, 236), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	Text("ТЕРМИНАЛ", "nwTerm3DTitle", 48, 114, Alpha(BLUE_SOFT, 236), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	Line(48, 143, 172, accent, 90)
	Text("ЕДИНАЯ СЕТЬ ГОРОДСКИХ СЛУЖБ", "nwTerm3DTiny", 48, 155, Alpha(BLUE_DIM, 185), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	local stage = self.registrationStage

	if (stage == "idle") then
		self:DrawButton(self:AddButton("register", "АВТОРИЗОВАТЬСЯ", 48, 186, 172, 38), accent, 1, true)
	elseif (stage == "shrinking") then
		local progress = math.Clamp((CurTime() - self.registrationStarted) / 0.45, 0, 1)
		local width_ = 172 * (1 - math.ease.InOutCubic(progress))

		if (width_ > 2) then
			self:DrawButton({key = "register_anim", x = 48 + (172 - width_) * 0.5, y = 186, w = width_, h = 38,
				label = "АВТОРИЗОВАТЬСЯ"}, accent, 1 - progress, false)
		end
	elseif (stage == "loading") then
		local elapsed = CurTime() - self.registrationStarted

		-- a scan line runs over the box, the dots pulse
		local scan = (elapsed * 0.9) % 1

		surface.SetDrawColor(accent.r, accent.g, accent.b, 120)
		surface.DrawRect(48, 180 + scan * 46, 172, 1)

		for index = 1, 3 do
			local pulse = (math.sin(elapsed * 6 - index * 1.1) + 1) * 0.5

			surface.SetDrawColor(accent.r, accent.g, accent.b, 90 + pulse * 160)
			surface.DrawRect(78 + index * 28, 201 - pulse * 4, 7, 7)
		end

		Text("ИДЕНТИФИКАЦИЯ...", "nwTerm3DTiny", 134, 236, Alpha(BLUE_DIM, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else
		local profile = self.profile or {name = "НЕИЗВЕСТНЫЙ", cid = "00000"}
		local elapsed = CurTime() - self.registrationStarted
		local alpha = math.Clamp(elapsed / 0.35, 0, 1)
		local progress = stage == "flying" and math.ease.InOutCubic(math.Clamp(elapsed / 0.65, 0, 1)) or 0
		local color = profile.color or accent

		Text(T.Upper(profile.name), "nwTerm3DHeader", Lerp(progress, 134, 48), Lerp(progress, 192, 186),
			Alpha(color, 255 * alpha), progress > 0.5 and TEXT_ALIGN_LEFT or TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		Text("ID: #" .. tostring(profile.cid or "00000"), "nwTerm3DSmall", Lerp(progress, 134, 48),
			Lerp(progress, 215, 210), Alpha(BLUE_SOFT, 220 * alpha), progress > 0.5 and TEXT_ALIGN_LEFT or TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end

	local px, pw = 278, 254

	Box(px, 82, pw, 152, accent, 34)
	Text("ОПИСАНИЕ", "nwTerm3DHeader", px + 16, 102, BLUE_SOFT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	Line(px + 16, 119, pw - 32, accent, 45)

	for index, line in ipairs({"Для продолжения требуется", "идентификация гражданина.", "Сохраняйте прямой зрительный",
		"контакт с экраном терминала."}) do
		Text(line, "nwTerm3DText", px + 16, 134 + (index - 1) * 18, index == 2 and WHITE or BLUE_SOFT, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_TOP)
	end
end

function ENT:DrawMain(width, height, accent)
	self:DrawNavigation(accent)
	self:DrawWorkspaceHeader(accent)

	local profile = self.profile or {name = "ГРАЖДАНИН", cid = "00000", faction = "НЕ ОПРЕДЕЛЕНО", bank = 0}

	Box(CONTENT_X, 99, CONTENT_W, 137, accent, 30)
	Text("СИСТЕМНЫЙ ДОСТУП", "nwTerm3DTiny", CONTENT_X + 16, 119, BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	Text("РАЗРЕШЁН", "nwTerm3DTitle", CONTENT_X + 16, 147, WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	Text("ВЫБЕРИТЕ ВКЛАДКУ В ВЕРХНЕЙ ПАНЕЛИ", "nwTerm3DSmall", CONTENT_X + 16, 177, BLUE_SOFT, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	if (#(self.announcements or {}) > 0) then
		Text("НОВЫХ СООБЩЕНИЙ СЕТИ: " .. #self.announcements, "nwTerm3DTiny", CONTENT_X + 16, 210, AMBER, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	surface.SetDrawColor(accent.r, accent.g, accent.b, 48)
	surface.DrawRect(CONTENT_X + 252, 112, 1, 110)
	Text("ПРОФИЛЬ ГРАЖДАНИНА", "nwTerm3DTiny", CONTENT_X + 270, 119, BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	Text(T.Upper(profile.name), "nwTerm3DHeader", CONTENT_X + 270, 145, profile.color or accent, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
	Text("ID: #" .. tostring(profile.cid), "nwTerm3DSmall", CONTENT_X + 270, 166, BLUE_SOFT, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
	Text(T.Upper(tostring(profile.faction)), "nwTerm3DSmall", CONTENT_X + 270, 187, WHITE, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
	Text("СЧЁТ: " .. tostring(profile.bank or 0) .. " ТК", "nwTerm3DSmall", CONTENT_X + 270, 208, BLUE_DIM,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function ENT:DrawInfo(width, height, accent)
	self:DrawNavigation(accent)
	self:DrawWorkspaceHeader(accent)

	local profile = self.profile or {name = "—", cid = "—", faction = "—", bank = 0}
	local rows = {
		{"ГРАЖДАНИН", T.Upper(profile.name), profile.color or accent},
		{"ИДЕНТИФИКАТОР", "#" .. tostring(profile.cid), WHITE},
		{"СТАТУС", T.Upper(tostring(profile.faction)), BLUE_SOFT},
		{"МЕСТО ЖИТЕЛЬСТВА", profile.home != "" and T.Upper(profile.home or "") or "НЕ НАЗНАЧЕНО", WHITE}
	}

	for index, row in ipairs(rows) do
		local y = 92 + (index - 1) * 41

		Text(row[1], "nwTerm3DTiny", CONTENT_X, y, BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		Text(row[2], "nwTerm3DText", CONTENT_X, y + 13, row[3], TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		Line(CONTENT_X, y + 33, CONTENT_W - 120, accent, 28)
	end

	-- the silhouette of the character
	local sx, sy, size = CONTENT_X + CONTENT_W - 108, 94, 108

	Box(sx, sy, size, size + 50, accent, 26)

	if (self.previewMaterial) then
		surface.SetDrawColor(90, 218, 236, 70)
		surface.SetMaterial(self.previewMaterial)
		surface.DrawTexturedRect(sx, sy + 6, size, size + 40)
	end

	Text("БИОМЕТРИЯ", "nwTerm3DTiny", sx + size / 2, sy + size + 44, BLUE_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function ENT:DrawAnnouncements(width, height, accent)
	self:DrawNavigation(accent)
	self:DrawWorkspaceHeader(accent)

	local page = math.max(1, self.announcementPage or 1)
	local first = (page - 1) * 4 + 1

	if (#self.announcements == 0) then
		Text("СООБЩЕНИЯ ОТСУТСТВУЮТ", "nwTerm3DText", CONTENT_X + CONTENT_W * 0.5, 165, BLUE_DIM, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)

		return
	end

	for slot = 1, 4 do
		local announcement = self.announcements[first + slot - 1]

		if (!announcement) then
			break
		end

		local y = 92 + (slot - 1) * 41
		local priority = T.priorities[announcement.priority] or T.priorities.normal
		local button = self:AddButton("announcement", "", CONTENT_X, y, CONTENT_W, 35, announcement)
		local hovered = self.hoveredKey == button.key

		surface.SetDrawColor(0, 17, 22, 86)
		surface.DrawRect(button.x, button.y, button.w, button.h)
		surface.SetDrawColor(accent.r, accent.g, accent.b, hovered and 215 or 60)
		surface.DrawOutlinedRect(button.x, button.y, button.w, button.h, 1)
		surface.SetDrawColor(priority.color.r, priority.color.g, priority.color.b, 210)
		surface.DrawRect(button.x, button.y, 3, button.h)
		Text(T.Upper(announcement.title), "nwTerm3DSmall", button.x + 11, button.y + 11, hovered and WHITE or BLUE_SOFT,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		Text(announcement.gameTime .. "  ·  " .. T.Upper(priority.name), "nwTerm3DTiny", button.x + 11, button.y + 25,
			BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local maximum = math.max(1, math.ceil(#self.announcements / 4))

	if (maximum > 1) then
		local previous = self:AddButton("ann_prev", "<", CONTENT_X, 261, 34, 17)
		local nextButton = self:AddButton("ann_next", ">", CONTENT_X + CONTENT_W - 34, 261, 34, 17)

		previous.font, nextButton.font = "nwTerm3DTiny", "nwTerm3DTiny"
		self:DrawButton(previous, accent, 1, false)
		self:DrawButton(nextButton, accent, 1, false)
		Text(page .. " / " .. maximum, "nwTerm3DTiny", CONTENT_X + CONTENT_W * 0.5, 269, BLUE_SOFT, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end
end

function ENT:DrawAnnouncementDetail(width, height, accent)
	self:DrawNavigation(accent)
	self:DrawWorkspaceHeader(accent)
	self:DrawBackButton()

	local announcement = self.selectedAnnouncement

	if (!announcement) then
		self.screen = "announcements"

		return
	end

	local priority = T.priorities[announcement.priority] or T.priorities.normal

	Text(T.Upper(announcement.title), "nwTerm3DHeader", CONTENT_X, 91, accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	Text(announcement.gameTime .. "  ·  " .. T.Upper(announcement.author or ""), "nwTerm3DTiny", CONTENT_X, 113,
		BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	surface.SetDrawColor(priority.color.r, priority.color.g, priority.color.b, 220)
	surface.DrawRect(CONTENT_X + CONTENT_W - 4, 86, 4, 32)
	Line(CONTENT_X, 127, CONTENT_W, accent, 38)

	local lines = Wrap(announcement.body, "nwTerm3DText", CONTENT_W)

	for index = 1, math.min(#lines, 7) do
		Text(lines[index], "nwTerm3DText", CONTENT_X, 141 + (index - 1) * 17, index == 1 and WHITE or BLUE_SOFT,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	if ((announcement.photo or "") != "") then
		local button = self:AddButton("announcement_photo", "ОТКРЫТЬ ФОТОМАТЕРИАЛ", CONTENT_X, 262, CONTENT_W - 76, 21)

		button.font = "nwTerm3DTiny"
		self:DrawButton(button, accent, 1, false)
	end
end

function ENT:DrawCall(width, height, accent)
	self:DrawNavigation(accent)
	self:DrawWorkspaceHeader(accent)

	local alarmUntil = self:GetNW2Float("nwTermAlarm", 0)
	local locked = alarmUntil > CurTime()

	Text("ОПИШИТЕ ПРИЧИНУ ОБРАЩЕНИЯ", "nwTerm3DTiny", CONTENT_X, 92, BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	Box(CONTENT_X, 108, CONTENT_W, 84, locked and RED or accent, 42)

	if (self.callDraft == "") then
		if (!locked) then
			self:DrawButton(self:AddButton("call_input", "ВВЕСТИ СООБЩЕНИЕ", CONTENT_X + 16, 131, CONTENT_W - 32, 34),
				accent, 1, false)
		end
	else
		local lines = Wrap(self.callDraft, "nwTerm3DText", CONTENT_W - 24)

		for index = 1, math.min(#lines, 4) do
			Text(lines[index], "nwTerm3DText", CONTENT_X + 12, 118 + (index - 1) * 17, WHITE, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_TOP)
		end
	end

	if (locked) then
		local blink = math.sin(CurTime() * 6) > 0

		Text("СИГНАЛ ПЕРЕДАН", "nwTerm3DHeader", CONTENT_X, 215, blink and RED or RED_SOFT, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
		Text("КАНАЛ ЗАБЛОКИРОВАН: " .. math.max(0, math.ceil(alarmUntil - CurTime())) .. " СЕК.", "nwTerm3DSmall",
			CONTENT_X, 237, RED_SOFT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	elseif (self.callDraft != "") then
		local half = (CONTENT_W - 16) * 0.5

		self:DrawButton(self:AddButton("call_input", "ИЗМЕНИТЬ", CONTENT_X, 206, half, 29), accent, 1, false)
		self:DrawButton(self:AddButton("call_confirm", "ОТПРАВИТЬ", CONTENT_X + half + 16, 206, half, 29), RED_SOFT, 1,
			false)
		Text("ЛОЖНЫЙ ВЫЗОВ ЯВЛЯЕТСЯ НАРУШЕНИЕМ", "nwTerm3DTiny", CONTENT_X, 253, RED_SOFT, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end
end

function ENT:DrawHousing(width, height, accent)
	self:DrawNavigation(accent)
	self:DrawWorkspaceHeader(accent)
	Text("УПРАВЛЕНИЕ ГРАЖДАНСКИМ ЗАСЕЛЕНИЕМ", "nwTerm3DTiny", CONTENT_X, 93, BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	self:DrawButton(self:AddButton("housing_request", "ПОЛУЧИТЬ АПАРТАМЕНТЫ", CONTENT_X, 113, CONTENT_W, 38), accent, 1,
		true)
	self:DrawButton(self:AddButton("housing_list", "СПИСОК АПАРТАМЕНТОВ", CONTENT_X, 163, CONTENT_W, 38), accent, 1, true)

	local home = self.profile and self.profile.home or ""

	if (home != "") then
		Text("ВАШЕ МЕСТО ЖИТЕЛЬСТВА: " .. T.Upper(home), "nwTerm3DSmall", CONTENT_X, 216, WHITE, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_TOP)
	end

	if (self.housingMessage != "") then
		local lines = Wrap(self.housingMessage, "nwTerm3DSmall", CONTENT_W)

		for index = 1, math.min(#lines, 2) do
			Text(lines[index], "nwTerm3DSmall", CONTENT_X, 236 + (index - 1) * 15, AMBER, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
	end
end

function ENT:DrawHousingRoulette(width, height, accent)
	self:DrawNavigation(accent)
	self:DrawWorkspaceHeader(accent)

	local progress = math.Clamp((CurTime() - self.housingRouletteStart) / 4, 0, 1)
	local eased = 1 - (1 - progress) ^ 4
	local cardH = 28
	local count = #(self.housingSequence or {})
	local offset = (count - 1) * (cardH + 5) * eased

	Box(CONTENT_X, 91, CONTENT_W, 137, accent, 34)

	-- a tick each time a card crosses the line
	local passed = math.floor(offset / (cardH + 5))

	if (passed > self.housingTicks and progress < 1) then
		self.housingTicks = passed
		self:EmitSound("network2/terminal/select1.wav", 55, 120 + passed, 0.35)
	end

	for index, name in ipairs(self.housingSequence or {}) do
		local y = 159 + (index - 1) * (cardH + 5) - offset

		if (y > 93 and y < 225) then
			local near = 1 - math.min(math.abs(y + cardH / 2 - 159) / 70, 1)

			surface.SetDrawColor(accent.r, accent.g, accent.b, 40 + near * 120)
			surface.DrawOutlinedRect(CONTENT_X + 15, y, CONTENT_W - 30, cardH, 1)
			Text(T.Upper(name), "nwTerm3DSmall", CONTENT_X + CONTENT_W * 0.5, y + cardH * 0.5, Alpha(WHITE, 120 + near * 135),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	surface.SetDrawColor(WHITE.r, WHITE.g, WHITE.b, 220)
	surface.DrawRect(CONTENT_X + 7, 172, CONTENT_W - 14, 1)

	if (progress >= 1) then
		if (!self.housingAnnounced) then
			self.housingAnnounced = true
			self:EmitSound("network2/terminal/boot.wav", 60, 115, 0.6)
		end

		Text("НАЗНАЧЕНО: " .. T.Upper(self.housingChosen), "nwTerm3DHeader", CONTENT_X, 251, WHITE, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
		self:DrawBackButton()
	end
end

function ENT:DrawHousingList(width, height, accent)
	self:DrawNavigation(accent)
	self:DrawWorkspaceHeader(accent)
	self:DrawBackButton()

	if (#self.apartments == 0) then
		Text("ДОСТУПНЫЕ ПОМЕЩЕНИЯ НЕ НАЙДЕНЫ", "nwTerm3DSmall", CONTENT_X, 132, BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	for index = 1, math.min(#self.apartments, 5) do
		local apartment = self.apartments[index]
		local y = 92 + (index - 1) * 33
		local full = apartment.current >= apartment.maximum

		Box(CONTENT_X, y, CONTENT_W, 27, accent, 28)
		Text(T.Upper(apartment.name), "nwTerm3DSmall", CONTENT_X + 10, y + 14, WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		-- the fill as a bar
		local bw = 80
		local bx = CONTENT_X + CONTENT_W - 50 - bw

		surface.SetDrawColor(accent.r, accent.g, accent.b, 50)
		surface.DrawRect(bx, y + 12, bw, 3)
		surface.SetDrawColor(full and RED.r or accent.r, full and RED.g or accent.g, full and RED.b or accent.b, 220)
		surface.DrawRect(bx, y + 12, bw * apartment.current / math.max(apartment.maximum, 1), 3)
		Text(apartment.current .. "/" .. apartment.maximum, "nwTerm3DSmall", CONTENT_X + CONTENT_W - 9, y + 14,
			full and RED or BLUE_SOFT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

function ENT:DrawAdditional(width, height, accent)
	self:DrawNavigation(accent)
	self:DrawWorkspaceHeader(accent)
	Text("ВСПОМОГАТЕЛЬНЫЕ МОДУЛИ ГОРОДСКОЙ СЕТИ", "nwTerm3DTiny", CONTENT_X, 93, BLUE_DIM, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP)

	self:DrawButton(self:AddButton("open_weather", "МЕТЕОСВОДКА", CONTENT_X, 110, CONTENT_W, 34), accent, 1, true)
	self:DrawButton(self:AddButton("open_bank", "УПРАВЛЕНИЕ СРЕДСТВАМИ", CONTENT_X, 152, CONTENT_W, 34), accent, 1, true)
	self:DrawButton(self:AddButton("open_business", "АРЕНДА КОММЕРЧЕСКИХ ПОМЕЩЕНИЙ", CONTENT_X, 194, CONTENT_W, 34),
		accent, 1, true)
end

function ENT:DrawWeather(width, height, accent)
	self:DrawNavigation(accent)
	self:DrawWorkspaceHeader(accent)
	self:DrawBackButton()

	local weather = T.Weather()

	Box(CONTENT_X, 93, CONTENT_W, 160, accent, 32)
	Text("СОСТОЯНИЕ НА " .. os.date("%H:%M"), "nwTerm3DTiny", CONTENT_X + 15, 110, BLUE_DIM, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
	Text((weather.temperature > 0 and "+" or "") .. weather.temperature .. "°", "nwTerm3DTitle", CONTENT_X + 15, 140,
		WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	Text(weather.sky, "nwTerm3DHeader", CONTENT_X + 80, 140, BLUE_SOFT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	Line(CONTENT_X + 15, 162, CONTENT_W - 30, accent, 38)

	local rows = {{"ВЕТЕР", weather.wind .. " М/С"}, {"ВЛАЖНОСТЬ", weather.humidity .. "%"},
		{"ЧИСТОТА ВОЗДУХА", weather.air}}

	for index, row in ipairs(rows) do
		local x = CONTENT_X + 15 + (index - 1) * 160

		Text(row[1], "nwTerm3DTiny", x, 182, BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		Text(row[2], "nwTerm3DText", x, 200, row[2] == "ПОВЫШЕННЫЙ ФОН" and AMBER or WHITE, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	Text("ДАННЫЕ ПЕРЕДАНЫ ГОРОДСКОЙ МЕТЕОСЛУЖБОЙ", "nwTerm3DTiny", CONTENT_X + 15, 236, BLUE_DIM, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
end

function ENT:DrawBank(width, height, accent)
	self:DrawNavigation(accent)
	self:DrawWorkspaceHeader(accent)
	self:DrawBackButton()

	local profile = self.profile or {bank = 0, tokens = 0, logs = {}}

	Text("ТЕКУЩИЙ БАЛАНС", "nwTerm3DTiny", CONTENT_X, 95, BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	Text(tostring(profile.bank or 0) .. " ТОКЕНОВ", "nwTerm3DTitle", CONTENT_X, 116, WHITE, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
	Text("НА РУКАХ: " .. tostring(profile.tokens or 0) .. " ТК", "nwTerm3DSmall", CONTENT_X + CONTENT_W - 72, 116,
		BLUE_SOFT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	Line(CONTENT_X, 132, CONTENT_W, accent, 48)

	local logs = profile.logs or {}

	if (#logs == 0) then
		Text("ОПЕРАЦИЙ НЕ БЫЛО", "nwTerm3DTiny", CONTENT_X, 150, BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	for index = 1, math.min(#logs, 3) do
		local log = logs[index]
		local y = 150 + (index - 1) * 18

		Text(log.time, "nwTerm3DTiny", CONTENT_X, y, BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		Text(log.text, "nwTerm3DSmall", CONTENT_X + 42, y, log.positive and BLUE_SOFT or WHITE, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	local half = (CONTENT_W - 80) * 0.5

	self:DrawButton(self:AddButton("bank_withdraw", "СНЯТЬ СО СЧЁТА", CONTENT_X, 216, half, 31), accent, 1, false)
	self:DrawButton(self:AddButton("bank_deposit", "ВНЕСТИ НА СЧЁТ", CONTENT_X + half + 8, 216, half, 31), accent, 1,
		false)
end

function ENT:DrawBusiness(width, height, accent)
	self:DrawNavigation(accent)
	self:DrawWorkspaceHeader(accent)
	self:DrawBackButton()
	Text("СВОБОДНЫЕ ПОМЕЩЕНИЯ · ОПЛАТА СО СЧЁТА", "nwTerm3DTiny", CONTENT_X, 93, BLUE_DIM, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP)

	if (#self.businesses == 0) then
		Text("СВОБОДНЫХ ПОМЕЩЕНИЙ НЕТ", "nwTerm3DSmall", CONTENT_X, 132, BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	for index = 1, math.min(#self.businesses, 4) do
		local business = self.businesses[index]
		local y = 108 + (index - 1) * 36

		Box(CONTENT_X, y, CONTENT_W, 30, accent, 28)
		Text(T.Upper(business.name), "nwTerm3DSmall", CONTENT_X + 10, y + 15, WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local button = self:AddButton("rent", business.price .. " ТК · ОФОРМИТЬ", CONTENT_X + CONTENT_W - 138, y + 4, 132,
			22, business)

		button.font = "nwTerm3DTiny"
		self:DrawButton(button, accent, 1, false)
	end
end

function ENT:DrawAimCursor(width, height, accent)
	if (!self.aimX or CurTime() - (self.aimTime or 0) > 0.15) then
		return
	end

	local x, y = math.Clamp(self.aimX, 0, width), math.Clamp(self.aimY, 0, height)
	local hover = self.hoveredKey != nil
	local size = hover and 22 or 20

	surface.SetMaterial(hover and CURSOR_HOVER or CURSOR)
	surface.SetDrawColor(255, 255, 255, 235)
	-- the hotspot of both cursors is the middle of the image
	surface.DrawTexturedRect(x - size / 2, y - size / 2, size, size)
end

local SCREENS = {
	main = "DrawMain", info = "DrawInfo", announcements = "DrawAnnouncements",
	announcement_detail = "DrawAnnouncementDetail", call = "DrawCall", housing = "DrawHousing",
	housing_roulette = "DrawHousingRoulette", housing_list = "DrawHousingList", additional = "DrawAdditional",
	weather = "DrawWeather", bank = "DrawBank", business = "DrawBusiness"
}

function ENT:DrawScreen(width, height)
	self.buttons = {}

	local accent = self:GetAccent()
	local alpha = (0.86 + math.sin(CurTime() * 1.4) * 0.02) * (self.flicker or 1)

	-- the wallpaper, a dark glass over it, the tint of the accent
	surface.SetDrawColor(255, 255, 255, 120 * alpha)
	surface.SetMaterial(BG)
	surface.DrawTexturedRect(0, 0, width, height)
	surface.SetDrawColor(0, 11, 16, 150 * alpha)
	surface.DrawRect(0, 0, width, height)
	surface.SetDrawColor(accent.r, accent.g, accent.b, 11 * alpha)
	surface.DrawRect(0, 0, width, height)

	-- a slow sweep of light down the screen
	local sweepY = math.fmod(CurTime() * 26, height + 60) - 30

	for index = 0, 6 do
		surface.SetDrawColor(accent.r, accent.g, accent.b, (6 - index) * alpha)
		surface.DrawRect(0, sweepY + index * 2, width, 1)
	end

	self:DrawHeader(width, height, accent, alpha)

	if (!self.registered) then
		self:DrawRegister(width, height, accent)
	else
		self[SCREENS[self.screen] or "DrawMain"](self, width, height, accent)
	end

	if (self.actionMessage != "" and CurTime() < self.actionMessageUntil) then
		surface.SetDrawColor(0, 12, 16, 220)
		surface.DrawRect(CONTENT_X, height - 50, CONTENT_W, 18)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 120)
		surface.DrawOutlinedRect(CONTENT_X, height - 50, CONTENT_W, 18, 1)
		Text(self.actionMessage, "nwTerm3DSmall", CONTENT_X + CONTENT_W * 0.5, height - 41, accent, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end

	self:DrawFooter(width, height, accent)
	self:DrawAimCursor(width, height, accent)
end

-- ------------------------------------------------------------------- think --
function ENT:Think()
	local client = LocalPlayer()

	if (CurTime() > self.nextFlicker) then
		self.flicker = math.Rand(0.97, 1)
		self.nextFlicker = CurTime() + math.Rand(0.08, 0.2)
	end

	if (IsValid(client)) then
		local distance = client:GetPos():Distance(self:GetPos())

		if (distance <= 850) then
			self.lastNear = CurTime()

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

		-- a soft tick when the cursor comes onto another button
		if (key and key != self.hoveredKey and self.registered) then
			self:EmitSound("network2/terminal/select1.wav", 50, 150, 0.15)
		end

		self.hoveredButton = hovered
		self.hoveredKey = key
		self.hoveredDescription = hovered and hovered.description or nil
	end

	local stage, elapsed = self.registrationStage, CurTime() - self.registrationStarted

	if (stage == "shrinking" and elapsed >= 0.45) then
		self.registrationStage, self.registrationStarted = "loading", CurTime()
		self:EmitSound("network2/terminal/boot.wav", 60, 100, 0.6)
	elseif (stage == "loading" and elapsed >= 2 and self.profile) then
		self.registrationStage, self.registrationStarted = "identity", CurTime()
	elseif (stage == "identity" and elapsed >= 1.6) then
		self.registrationStage, self.registrationStarted = "flying", CurTime()
	elseif (stage == "flying" and elapsed >= 0.65) then
		self.registrationStage = "ready"
		self.registered = true
		self.screen = "main"
		self:Request("announcements")
	end

	self:SetNextClientThink(CurTime())

	return true
end

-- --------------------------------------------------------------- answers --
function ENT:Receive(action, data)
	if (action == "profile") then
		self.profile = data

		local c = data.factionColor or {}

		self.profile.color = Color(c[1] or 96, c[2] or 186, c[3] or 206)
	elseif (action == "announcements") then
		self.announcements = data.list or {}
		self.announcementPage = 1
	elseif (action == "housing") then
		if (!data.success) then
			self.housingMessage = data.message or ""
			self.screen = "housing"
			self:EmitSound("network2/terminal/deny.wav", 60)

			return
		end

		local names = (data.names and #data.names > 0) and data.names or {data.chosen}

		self.housingChosen = data.chosen
		self.housingMessage = ""
		self.housingSequence = {}
		self.housingRouletteStart = CurTime()
		self.housingTicks = 0
		self.housingAnnounced = false
		self.screen = "housing_roulette"

		for index = 1, 28 do
			self.housingSequence[index] = names[math.random(#names)]
		end

		self.housingSequence[28] = data.chosen
		self:Request("profile")
	elseif (action == "housinglist") then
		self.apartments = data.list or {}
		self.screen = "housing_list"
	elseif (action == "business") then
		self.businesses = data.list or {}
	elseif (action == "call") then
		self.actionMessage = data.success and "СИГНАЛ ПЕРЕДАН" or "ОШИБКА ПЕРЕДАЧИ"
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
function ENT:HandleUse(client)
	if (!T.IsNear(client, self)) then
		return false
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
		if (self.screen == "announcement_detail") then
			self.screen = "announcements"
		elseif (self.screen == "weather" or self.screen == "bank" or self.screen == "business") then
			self.screen = "additional"
		elseif (self.screen == "housing_list" or self.screen == "housing_roulette") then
			self.screen = "housing"
		else
			self.screen = "main"
		end
	elseif (action == "open_info") then
		self.screen = "info"
		self:Request("profile")
	elseif (action == "open_announcements") then
		self.screen = "announcements"
		self:Request("announcements")
	elseif (action == "open_call") then
		self.screen = "call"
	elseif (action == "open_housing") then
		self.screen = "housing"
		self.housingMessage = ""
	elseif (action == "open_additional") then
		self.screen = "additional"
	elseif (action == "announcement") then
		self.selectedAnnouncement = button.data
		self.screen = "announcement_detail"
	elseif (action == "announcement_photo") then
		if (self.selectedAnnouncement and (self.selectedAnnouncement.photo or "") != "") then
			T.OpenPhoto(self.selectedAnnouncement.photo, self.selectedAnnouncement.title)
		end
	elseif (action == "ann_prev") then
		self.announcementPage = math.max(1, self.announcementPage - 1)
	elseif (action == "ann_next") then
		self.announcementPage = math.min(math.max(1, math.ceil(#self.announcements / 4)), self.announcementPage + 1)
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
		self.housingMessage = "ПОИСК ДОСТУПНЫХ АПАРТАМЕНТОВ..."
		self:Request("housing")
	elseif (action == "housing_list") then
		self:Request("housinglist")
	elseif (action == "open_weather") then
		self.screen = "weather"
	elseif (action == "open_bank") then
		self.screen = "bank"
		self:Request("profile")
	elseif (action == "open_business") then
		self.screen = "business"
		self.businesses = {}
		self:Request("business")
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
		light.pos = position + self:GetForward() * 4
		light.r, light.g, light.b = accent.r, accent.g, accent.b
		light.brightness = 0.08 * (0.9 + math.sin(CurTime() * 2) * 0.08) * (self.flicker or 1)
		light.decay = 700
		light.size = 30
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

	if (!success and CurTime() >= (self.nextRenderError or 0)) then
		self.nextRenderError = CurTime() + 1
		ErrorNoHalt("[Network terminal] " .. tostring(problem) .. "\n")
	end
end
