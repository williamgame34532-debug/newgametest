-- Scoreboard (hold TAB): a sheet over the left part of the screen, edge to edge from top to
-- bottom, that slides in from the left while TAB is held (the rest of the screen dims) and
-- slides back out when TAB is released. Flat look of its own: graphite sheet with film grain
-- (board_sheet.png, tiled), a light edge line with a shadow falling onto the screen
-- (board_edge.png), "NETWORK" spaced out in the header, players as numbered lines split by
-- hairlines, the ping as signal bars. Someone you do not know is a black silhouette,
-- "Неизвестный", "Неизвестное описание"; yourself and the people you know (NW.char.Knows) are
-- drawn normally with the real name and description. RMB on a line: a large menu (copy name /
-- SteamID64 / SteamID / Steam name, Steam profile, PM, mute, staff actions for superadmins).

NW.scoreboard = NW.scoreboard or {}

local SB = NW.scoreboard
local U = NW.ui

local EMBLEM = Material("network2/emblem.png", "smooth mips")
local SHEET = Material("network2/ui/board_sheet.png", "noclamp smooth")
local EDGE = Material("network2/ui/board_edge.png", "smooth")
local MENU = "network2/ui/board_menu.png"
local LINE = Color(255, 255, 255, 14)
local MUTED = Color(118, 120, 122)
local STEAM = Color(120, 176, 222)

local SLIDE_TIME = 0.32

local function Fonts()
	local h = ScrH()
	local function F(name, font, size, weight)
		surface.CreateFont(name, {font = font, size = math.max(12, math.Round(h * size)), weight = weight,
			extended = true, antialias = true})
	end

	F("nwBoardTitle", "Jura", 0.028, 700)
	F("nwBoardIndex", "Montserrat Medium", 0.0125, 500)
	F("nwBoardSub", "Exo 2", 0.0145, 500)
	F("nwBoardName", "Exo 2", 0.0175, 600)
	F("nwBoardDesc", "Exo 2", 0.0138, 400)
	F("nwBoardMenu", "Exo 2", 0.021, 500)
	F("nwBoardMenuHead", "Exo 2", 0.023, 700)
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwBoardFonts", Fonts)

local function Knows(client)
	return client == LocalPlayer() or (NW.char and NW.char.Knows and NW.char.Knows(LocalPlayer(), client)) or false
end

local function Description(client)
	local text = client.GetCharacterDescription and client:GetCharacterDescription() or ""

	return text != "" and text or "Без описания"
end

-- text cut to a width with an ellipsis
local function Fit(text, font, width)
	surface.SetFont(font)

	if (surface.GetTextSize(text) <= width) then
		return text
	end

	local chars = utf8.len(text) or #text

	while (chars > 1) do
		chars = chars - 1

		local cut = utf8.offset(text, chars + 1)
		local short = string.sub(text, 1, (cut or #text + 1) - 1) .. "…"

		if (surface.GetTextSize(short) <= width) then
			return short
		end
	end

	return "…"
end

-- ---------------------------------------------------------------- the menu --
local function MenuOption(menu, text, icon, callback)
	local option = menu:AddOption(text, callback)
	local oh = math.Round(ScrH() * 0.042)

	option:SetFont("nwBoardMenu")
	option:SetTextColor(U.color.text)
	option:SetTextInset(math.Round(oh * 1.25), 0)
	option.PerformLayout = function(self)
		self:SizeToContents()
		self:SetSize(math.max(menu:GetMinimumWidth(), self:GetWide() + oh), oh)
	end
	option.Paint = function(self, w, h)
		local hovered = self:IsHovered()

		if (hovered) then
			surface.SetDrawColor(255, 255, 255, 16)
			surface.DrawRect(1, 0, w - 2, h)
		end

		if (icon) then
			local size = math.Round(h * 0.5)

			U.DrawIcon(icon, h * 0.4, (h - size) / 2, size, hovered and U.color.text or U.color.dim)
		end
	end
	local entered = option.OnCursorEntered

	option.OnCursorEntered = function(self)
		entered(self)
		surface.PlaySound("network2/ui/hover.wav")
	end

	return option
end

local function MenuSpacer(menu)
	local spacer = vgui.Create("DPanel", menu)

	spacer:SetTall(9)
	spacer.Paint = function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 18)
		surface.DrawRect(12, 4, w - 24, 1)
	end

	menu:AddPanel(spacer)
end

local function Copy(text, what)
	SetClipboardText(text or "")
	U.Play("affirm")
	chat.AddText(U.color.dim, what .. " скопирован: ", U.color.text, text or "")
end

local function PlayerMenu(client)
	if (!IsValid(client)) then
		return
	end

	U.Tick()

	local menu = DermaMenu()
	local known = Knows(client)
	local headH = math.Round(ScrH() * 0.05)

	menu:SetMinimumWidth(math.Round(ScrH() * 0.34))
	menu.Paint = function(self, w, h)
		U.Slice(U.Material(MENU), 0, 0, w, h, 2, 255, 255, 255, 250)
	end

	-- the head: who this is
	local head = vgui.Create("DPanel", menu)

	head:SetTall(headH)
	head.Paint = function(self, w, h)
		if (!IsValid(client)) then
			return
		end

		draw.SimpleText(Fit(known and client:Nick() or "Неизвестный", "nwBoardMenuHead", w - 28), "nwBoardMenuHead",
			14, h * 0.4, U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(client:SteamName() .. "  ·  " .. client:Ping() .. " мс", "nwBoardDesc", 14, h * 0.78,
			U.color.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	menu:AddPanel(head)
	MenuSpacer(menu)

	if (known) then
		MenuOption(menu, "Скопировать имя", "user", function()
			Copy(client:Nick(), "Имя")
		end)
	end

	MenuOption(menu, "Скопировать SteamID64", "check", function()
		Copy(client:SteamID64(), "SteamID64")
	end)
	MenuOption(menu, "Скопировать SteamID", "check", function()
		Copy(client:SteamID(), "SteamID")
	end)
	MenuOption(menu, "Скопировать ник Steam", "faction", function()
		Copy(client:SteamName(), "Ник Steam")
	end)
	MenuOption(menu, "Открыть профиль Steam", "play", function()
		client:ShowProfile()
	end)

	if (client != LocalPlayer()) then
		MenuSpacer(menu)

		MenuOption(menu, "Личное сообщение", "chat", function()
			if (!IsValid(client) or !NW.chat or !NW.chat.Open) then
				return
			end

			GAMEMODE:ScoreboardHide()
			NW.chat.Open(false)

			local text = "/pm #" .. client:UserID() .. " "

			NW.chat.entry:SetText(text)
			NW.chat.entry:SetCaretPos(utf8.len(text) or #text)
		end)

		MenuOption(menu, client:IsMuted() and "Включить голос" or "Заглушить голос", "speech", function()
			if (IsValid(client)) then
				client:SetMuted(!client:IsMuted())
			end
		end)
	end

	if (LocalPlayer():IsSuperAdmin()) then
		MenuSpacer(menu)

		local id = client:UserID()

		if (client != LocalPlayer()) then
			MenuOption(menu, "Телепортироваться к игроку", "back", function()
				RunConsoleCommand("nw_admin", "go", id)
			end)
			MenuOption(menu, "Телепортировать к себе", "height", function()
				RunConsoleCommand("nw_admin", "bring", id)
			end)
		end

		MenuOption(menu, "Убить", "trash", function()
			RunConsoleCommand("nw_admin", "slay", id)
		end)
	end

	menu:Open()
	SB.menu = menu
end

-- ------------------------------------------------------------------- rows --
local function PingColor(ping)
	if (ping < 80) then
		return Color(140, 210, 150)
	elseif (ping < 160) then
		return Color(230, 200, 110)
	end

	return Color(230, 110, 100)
end

local function SetupModel(model, client, known)
	model:SetModel(client:GetModel())

	local entity = model:GetEntity()

	if (!IsValid(entity)) then
		return
	end

	entity:SetSkin(client:GetSkin())

	for _, group in ipairs(client:GetBodyGroups() or {}) do
		entity:SetBodygroup(group.id, client:GetBodygroup(group.id))
	end

	local idle = entity:SelectWeightedSequence(ACT_IDLE)

	entity:ResetSequence(idle and idle > 0 and idle or 0)

	if (known) then
		model:SetAmbientLight(Color(70, 74, 80))
		model:SetDirectionalLight(BOX_TOP, Color(255, 250, 240))
		model:SetDirectionalLight(BOX_FRONT, Color(150, 160, 175))
		model:SetDirectionalLight(BOX_RIGHT, Color(64, 190, 240))
		model:SetColor(Color(255, 255, 255))
	else
		model:SetAmbientLight(Color(0, 0, 0))
		model:SetDirectionalLight(BOX_TOP, Color(0, 0, 0))
		model:SetDirectionalLight(BOX_FRONT, Color(0, 0, 0))
		model:SetDirectionalLight(BOX_RIGHT, Color(0, 0, 0))
		model:SetColor(Color(0, 0, 0))
	end

	model.known = known
end

-- the ping as four bars
local function PingBars(x, y, size, ping)
	local lit = ping < 60 and 4 or ping < 110 and 3 or ping < 180 and 2 or 1
	local color = PingColor(ping)
	local bw = math.max(2, math.Round(size / 6))
	local gap = math.max(1, math.Round(bw * 0.6))

	for i = 1, 4 do
		local bh = math.Round(size * (0.3 + i * 0.175))

		if (i <= lit) then
			surface.SetDrawColor(color.r, color.g, color.b, 230)
		else
			surface.SetDrawColor(255, 255, 255, 26)
		end

		surface.DrawRect(x + (i - 1) * (bw + gap), y + size - bh, bw, bh)
	end

	return 4 * bw + 3 * gap
end

-- the staff: a plate on the line of everyone with rights, seen by all (known or not)
local STAFF = {
	superadmin = {"СУПЕРАДМИН", Color(222, 86, 74)},
	admin = {"АДМИН", Color(232, 176, 64)}
}

local function Staff(client)
	local group = client:GetUserGroup()

	if (STAFF[group]) then
		return STAFF[group]
	end

	if (client:IsAdmin()) then
		return {string.upper(group), Color(232, 176, 64)}
	end
end

-- the plate ending at right, its width
local function DrawStaff(staff, right, y, h)
	surface.SetFont("nwBoardIndex")

	local tw, th = surface.GetTextSize(staff[1])
	local padX = math.Round(h * 0.12)
	local bw, bh = tw + padX * 2, th + math.Round(h * 0.06)
	local x = right - bw

	draw.RoundedBox(3, x, y - bh / 2, bw, bh, ColorAlpha(staff[2], 38))
	surface.SetDrawColor(staff[2])
	surface.DrawRect(x, y - bh / 2, 2, bh)
	draw.SimpleText(staff[1], "nwBoardIndex", x + padX + 1, y, staff[2], TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	return bw
end

local function Row(parent, client, height, index)
	local row = parent:Add("DButton")

	row:SetText("")
	row:Dock(TOP)
	row:SetTall(height)
	row.client = client
	row.index = string.format("%02d", index)
	row.hover = 0
	row.Paint = function(self, w, h)
		self.hover = Lerp(math.Clamp(FrameTime() * 12, 0, 1), self.hover, self:IsHovered() and 1 or 0)

		if (self.hover > 0.01) then
			surface.SetDrawColor(255, 255, 255, 12 * self.hover)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(255, 255, 255, 200 * self.hover)
			surface.DrawRect(0, 0, 2, h)
		end

		surface.SetDrawColor(LINE)
		surface.DrawRect(0, h - 1, w, 1)

		if (!IsValid(self.client)) then
			return
		end

		draw.SimpleText(self.index, "nwBoardIndex", h * 0.32, h / 2, MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local known = Knows(self.client)
		local nameX = self.textX
		local ping = self.client:Ping()
		local size = math.Round(h * 0.26)
		-- the text ends before the ping column (and the mute mark), never past it
		local room = math.max(10, w - size - h * 0.3 - h * 0.55 - nameX)
		local sx, sy = self:LocalToScreen(0, 0)
		local staff = Staff(self.client)

		if (staff) then
			room = math.max(10, room - DrawStaff(staff, nameX + room, h * 0.36, h) - h * 0.15)
		end

		render.SetScissorRect(sx + nameX, sy, sx + nameX + room, sy + h, true)

		if (known) then
			local you = ""

			if (self.client == LocalPlayer()) then
				surface.SetFont("nwBoardDesc")
				you = surface.GetTextSize("вы") + h * 0.15
			end

			local name = Fit(self.client:Nick(), "nwBoardName", room - (you == "" and 0 or you))

			draw.SimpleText(name, "nwBoardName", nameX, h * 0.36, U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			surface.SetFont("nwBoardName")

			local after = nameX + surface.GetTextSize(name) + h * 0.12

			if (self.client == LocalPlayer()) then
				draw.SimpleText("вы", "nwBoardDesc", after, h * 0.37, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				surface.SetFont("nwBoardDesc")
				after = after + surface.GetTextSize("вы") + h * 0.12
			end


			-- the second line: the Steam nick first (always seen), then the description
			local steam = self.client:SteamName()

			surface.SetFont("nwBoardDesc")

			local steamW = surface.GetTextSize(steam .. "  ·  ")

			draw.SimpleText(steam, "nwBoardDesc", nameX, h * 0.67, STEAM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText("·", "nwBoardDesc", nameX + surface.GetTextSize(steam .. "  "), h * 0.67, MUTED,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(Fit(Description(self.client), "nwBoardDesc", room - steamW), "nwBoardDesc",
				nameX + steamW, h * 0.67, U.color.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		else
			draw.SimpleText("Неизвестный", "nwBoardName", nameX, h * 0.36, Color(186, 188, 190), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			local steam = self.client:SteamName()

			surface.SetFont("nwBoardDesc")

			local steamW = surface.GetTextSize(steam .. "  ·  ")

			draw.SimpleText(steam, "nwBoardDesc", nameX, h * 0.67, STEAM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText("·", "nwBoardDesc", nameX + surface.GetTextSize(steam .. "  "), h * 0.67, MUTED,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(Fit("Неизвестное описание", "nwBoardDesc", room - steamW), "nwBoardDesc", nameX + steamW,
				h * 0.67, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		render.SetScissorRect(0, 0, 0, 0, false)

		local bars = PingBars(w - h * 0.3 - size, h * 0.36 - size / 2, size, ping)

		draw.SimpleText(ping, "nwBoardIndex", w - h * 0.3 - size + bars / 2, h * 0.7, MUTED, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)

		if (self.client:IsMuted()) then
			U.DrawIcon("speech", w - h * 0.3 - size - h * 0.4, h * 0.36 - h * 0.11, h * 0.22, Color(220, 110, 100))
		end
	end
	row.DoRightClick = function(self)
		PlayerMenu(self.client)
	end
	row.DoClick = function(self)
		PlayerMenu(self.client)
	end
	row.OnCursorEntered = function()
		surface.PlaySound("network2/ui/hover.wav")
	end

	-- Steam avatar, square
	local avatar = row:Add("AvatarImage")
	local size = math.Round(height * 0.6)
	local x = math.Round(height * 0.62)

	avatar:SetSize(size, size)
	avatar:SetPos(x, math.Round((height - size) / 2))
	avatar:SetPlayer(client, 64)
	avatar:SetMouseInputEnabled(false)

	-- the character (head and shoulders): black for a stranger
	local model = row:Add("DModelPanel")
	local mw = math.Round(height * 0.72)

	model:SetSize(mw, height - 2)
	model:SetPos(x + size + math.Round(height * 0.08), 1)
	model:SetMouseInputEnabled(false)
	model:SetFOV(22)
	model.LayoutEntity = function(self, entity)
		entity:SetAngles(Angle(0, 12, 0))
		entity:FrameAdvance()

		local head = entity:LookupBone("ValveBiped.Bip01_Head1")
		local pos = head and entity:GetBonePosition(head)

		if (pos) then
			self:SetLookAt(pos - Vector(0, 0, 3))
			self:SetCamPos(pos + Vector(42, 0, 0))
		else
			self:SetLookAt(Vector(0, 0, 61))
			self:SetCamPos(Vector(42, 0, 64))
		end
	end
	model.PreDrawModel = function(self, entity)
		if (!self.known) then
			render.SuppressEngineLighting(true)
			render.SetColorModulation(0, 0, 0)
		end
	end
	model.PostDrawModel = function(self, entity)
		if (!self.known) then
			render.SetColorModulation(1, 1, 1)
			render.SuppressEngineLighting(false)
		end
	end

	SetupModel(model, client, Knows(client))

	row.textX = x + size + math.Round(height * 0.08) + mw + math.Round(height * 0.14)
	row.model = model

	return row
end

-- ------------------------------------------------------------------ board --
-- a word with its letters spaced out
local function Spaced(text, font, x, y, spacing, color)
	surface.SetFont(font)
	surface.SetTextColor(color)

	local _, th = surface.GetTextSize("W")

	for _, code in utf8.codes(text) do
		local char = utf8.char(code)

		surface.SetTextPos(x, y - th / 2)
		surface.DrawText(char)
		x = x + surface.GetTextSize(char) + spacing
	end
end

local function Build()
	if (IsValid(SB.frame)) then
		SB.frame:Remove()
	end

	local sw, sh = ScrW(), ScrH()
	local w = math.Round(math.Clamp(sw * 0.235, 360, 540))
	local pad = math.Round(sh * 0.022)
	local header = math.Round(sh * 0.095)
	local footer = math.Round(sh * 0.048)
	local columns = math.Round(sh * 0.03)

	-- the whole screen: dims what is not covered
	local frame = vgui.Create("EditablePanel")
	frame:SetSize(sw, sh)
	frame:SetPos(0, 0)
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	frame.progress = 0
	frame.target = 1
	frame.eased = 0

	frame.Paint = function(self, pw, ph)
		surface.SetDrawColor(4, 5, 6, 55 * self.eased)
		surface.DrawRect(0, 0, pw, ph)
	end

	local sheet = frame:Add("EditablePanel")
	sheet:SetSize(w, sh)
	sheet:SetPos(-w, 0)

	frame.Think = function(self)
		self.progress = math.Approach(self.progress, self.target, FrameTime() / SLIDE_TIME)

		-- ease out on the way in, ease in on the way out
		local p = self.progress

		self.eased = self.target == 1 and (1 - (1 - p) ^ 3) or (p * p * p)
		sheet:SetX(math.Round(Lerp(self.eased, -w - sh * 0.07, 0)))

		if (self.target == 0 and self.progress <= 0) then
			self:Remove()
		end
	end

	-- the shadow and edge are drawn outside the sheet, on the frame
	frame.PaintOver = function(self, pw, ph)
		local ex = sheet:GetX() + w - 2

		surface.SetMaterial(EDGE)
		surface.SetDrawColor(255, 255, 255, 150 * self.eased)
		surface.DrawTexturedRect(ex, 0, math.Round(sh * 0.07), ph)
	end

	sheet.Paint = function(self, pw, ph)
		U.Blur(0, 0, pw, ph, 3, 255, self, 1)

		surface.SetMaterial(SHEET)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRectUV(0, 0, pw, ph, 0, 0, pw / 512, ph / 512)

		-- header: emblem, NETWORK spaced out, the subtitle and the host
		local es = math.Round(header * 0.5)

		surface.SetMaterial(EMBLEM)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(pad, (header - es) / 2, es, es)

		local tx = pad + es + pad * 0.6

		Spaced("NETWORK", "nwBoardTitle", tx, header * 0.4, math.Round(sh * 0.009), U.color.text)
		draw.SimpleText("Half-Life Roleplay  ·  " .. Fit(GetHostName(), "nwBoardSub", pw - tx - pad - sh * 0.15),
			"nwBoardSub", tx, header * 0.68, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(255, 255, 255, 40)
		surface.DrawRect(pad, header, pw - pad * 2, 1)

		-- column titles
		local cy = header + columns / 2

		draw.SimpleText("№", "nwBoardIndex", pad + sh * 0.056 * 0.32, cy, MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("ПЕРСОНАЖ", "nwBoardIndex", pad + sh * 0.056 * 0.62, cy, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("ПИНГ", "nwBoardIndex", pw - pad - sh * 0.012, cy, MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		-- footer: count and the hint
		local fy = ph - footer

		surface.SetDrawColor(255, 255, 255, 40)
		surface.DrawRect(pad, fy, pw - pad * 2, 1)

		draw.SimpleText("ИГРОКОВ  " .. player.GetCount() .. " / " .. game.MaxPlayers(), "nwBoardSub", pad,
			fy + footer / 2, U.color.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("ПКМ — действия", "nwBoardSub", pw - pad, fy + footer / 2, MUTED, TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)
	end

	local top = header + columns
	local scroll = sheet:Add("DScrollPanel")

	scroll:SetPos(pad, top)
	scroll:SetSize(w - pad * 2, sh - top - footer - 2)

	local bar = scroll:GetVBar()
	bar:SetWide(3)
	bar:SetHideButtons(true)
	bar.Paint = function() end
	bar.btnGrip.Paint = function(self, bw, bh)
		surface.SetDrawColor(255, 255, 255, 50)
		surface.DrawRect(0, 0, bw, bh)
	end

	-- TAB → Навыки (cl_skills.lua): the panel beside the sheet
	local skills = sheet:Add("DButton")
	local bh = math.Round(header * 0.42)

	surface.SetFont("nwBoardSub")

	local bw = math.Round(surface.GetTextSize("НАВЫКИ") + bh * 1.6)

	skills:SetSize(bw, bh)
	skills:SetPos(w - pad - bw, (header - bh) / 2)
	skills:SetText("")
	skills.Paint = function(self, pw, ph)
		local open = IsValid(NW.skills.panel)
		local hover = self:IsHovered()

		draw.RoundedBox(6, 0, 0, pw, ph, Color(255, 255, 255, open and 40 or (hover and 26 or 12)))
		U.DrawIcon("skills", ph * 0.22, ph * 0.2, ph * 0.6, open and Color(232, 196, 72) or U.color.text)
		draw.SimpleText("НАВЫКИ", "nwBoardSub", ph * 0.98, ph / 2, U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	skills.DoClick = function()
		U.Tick()
		NW.skills.OpenPanel(frame, w + math.Round(sh * 0.08))
	end
	skills.OnCursorEntered = function()
		surface.PlaySound("network2/ui/hover.wav")
	end

	SB.frame = frame
	SB.sheet = sheet
	SB.scroll = scroll
	SB.key = nil
	SB.Refresh()
end

function SB.Refresh()
	if (!IsValid(SB.scroll)) then
		return
	end

	local players = player.GetAll()
	local me = LocalPlayer()

	-- yourself first, then the people you know, then everyone else
	table.sort(players, function(a, b)
		if ((a == me) != (b == me)) then
			return a == me
		end

		local ka, kb = Knows(a), Knows(b)

		if (ka != kb) then
			return ka
		end

		return a:EntIndex() < b:EntIndex()
	end)

	-- rebuild only when someone came, left, changed the model or became known
	local key = {}

	for _, client in ipairs(players) do
		key[#key + 1] = client:EntIndex() .. ":" .. client:GetModel() .. ":" .. client:GetSkin() .. ":" ..
			(Knows(client) and 1 or 0)
	end

	key = table.concat(key, ",")

	if (SB.key == key) then
		return
	end

	SB.key = key
	SB.scroll:Clear()

	local height = math.Round(ScrH() * 0.056)

	for index, client in ipairs(players) do
		Row(SB.scroll, client, height, index)
	end
end

function GM:ScoreboardShow()
	-- not over the Q menu or the pause menu
	if ((NW.inventory and NW.inventory.IsOpen and NW.inventory.IsOpen()) or
		(NW.pause and NW.pause.IsOpen and NW.pause.IsOpen())) then
		return true
	end

	if (IsValid(SB.frame) and SB.frame.target == 0) then
		-- caught on the way out: slide back in
		SB.frame.target = 1
		SB.frame:MakePopup()
		SB.frame:SetKeyboardInputEnabled(false)
		SB.key = nil
		SB.Refresh()
	else
		Build()
	end

	U.Play("appear")

	return true
end

function GM:ScoreboardHide()
	if (IsValid(SB.frame) and SB.frame.target != 0) then
		SB.frame.target = 0
		SB.frame:SetMouseInputEnabled(false)
		SB.frame:SetKeyboardInputEnabled(false)
		U.Tick()
	end

	CloseDermaMenus()

	return true
end

timer.Create("nwScoreboardRefresh", 1, 0, function()
	if (IsValid(SB.frame) and SB.frame.target == 1) then
		SB.Refresh()
	end
end)
