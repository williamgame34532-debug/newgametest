-- ESC in game. First it closes what is open (the chat, the inventory, the take panel); otherwise
-- it opens the framework's own pause menu instead of the Garry's Mod one:
--   left    the emblem, NETWORK and the buttons: Вернуться в игру, Персонажи (back to the
--           character menu), Бинды, Сообщество, Отключиться (asks once more);
--   right   the binds page: every key of the framework with what it is bound to now, and a
--           button that opens the keyboard settings of the game;
--   bottom  the server name and a small "Меню Garry's Mod" link (the usual game menu).
-- ESC again (or "Вернуться в игру") closes it. In the main menu ESC works as usual.

NW.pause = NW.pause or {}

local PM = NW.pause
local U = NW.ui

local EMBLEM = Material("network2/emblem.png", "smooth mips")
local VIGNETTE = Material("network2/menu/vignette.png", "smooth")
local MUTED = Color(124, 128, 134)
local BAD = Color(226, 104, 92)

local function Fonts()
	local h = ScrH()
	local function F(name, font, size, weight)
		surface.CreateFont(name, {font = font, size = math.max(12, math.Round(h * size)), weight = weight,
			extended = true, antialias = true})
	end

	F("nwPauseTitle", "Jura", 0.064, 700)
	F("nwPauseSub", "Exo 2", 0.02, 500)
	F("nwPauseButton", "Exo 2", 0.031, 600)
	F("nwPauseHead", "Montserrat SemiBold", 0.0135, 600)
	F("nwPauseText", "Exo 2", 0.019, 500)
	F("nwPauseKey", "Montserrat SemiBold", 0.016, 600)
	F("nwPauseSmall", "Exo 2", 0.0155, 500)
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwPauseFonts", Fonts)

local function Ease(t)
	return t * t * (3 - 2 * t)
end

-- ------------------------------------------------------------------ binds --
-- the framework's keys can be changed here (click, then press a key; ESC cancels); the others
-- belong to the game and are only shown
local BINDS = {
	{name = "Фреймворк", custom = true, rows = {}},
	{name = "Основное", rows = {
		{"Таблица игроков", "+showscores", "TAB"},
		{"Чат", "messagemode", "Y"},
		{"Чат команды", "messagemode2", "U"},
		{"Взять / использовать", "+use", "E"}
	}},
	{name = "Движение", rows = {
		{"Бег", "+speed", "SHIFT"},
		{"Медленный шаг", "+walk", "ALT"},
		{"Присесть", "+duck", "CTRL"},
		{"Прыжок", "+jump", "SPACE"}
	}},
	{name = "Камера и руки", rows = {
		{"Расстояние камеры", nil, "ALT + колесо"},
		{"Удар / бросить предмет", "+attack", "ЛКМ"},
		{"Поднять, постучать, оттолкнуть", "+attack2", "ПКМ"}
	}}
}

for _, key in ipairs(NW.keys.list) do
	table.insert(BINDS[1].rows, {key.name, custom = key.id})
end

local function KeyName(code)
	local name = code and input.GetKeyName(code)

	return name and U.Upper(name) or "не назначено"
end

local function KeyOf(row)
	if (row.custom) then
		return KeyName(NW.keys.Get(row.custom))
	end

	if (!row[2]) then
		return row[3]
	end

	local key = input.LookupBinding(row[2], true)

	return key and U.Upper(key) or "не назначено"
end

local function BindsPanel(parent, x, y, w)
	local sh = ScrH()
	local panel = parent:Add("EditablePanel")
	local rowH = math.Round(sh * 0.034)
	local groupH = math.Round(sh * 0.032)
	local cy = math.Round(sh * 0.04)

	panel:SetPos(x, y)
	panel:SetWide(w)

	panel.Paint = function(self, pw, ph)
		draw.SimpleText("БИНДЫ", "nwPauseHead", 0, 0, U.color.text)
		draw.SimpleText("Свои клавиши фреймворка — нажмите, чтобы изменить", "nwPauseSmall", pw, 0, MUTED,
			TEXT_ALIGN_RIGHT)
	end

	for _, group in ipairs(BINDS) do
		local caption = panel:Add("DLabel")

		caption:SetPos(0, cy + groupH * 0.25)
		caption:SetSize(w, groupH * 0.6)
		caption:SetFont("nwPauseHead")
		caption:SetTextColor(group.custom and Color(232, 196, 72) or MUTED)
		caption:SetText(U.Upper(group.name))
		cy = cy + groupH

		for _, row in ipairs(group.rows) do
			local line = panel:Add("DButton")

			line:SetPos(0, cy)
			line:SetSize(w, rowH)
			line:SetText("")
			line:SetCursor(row.custom and "hand" or "arrow")
			line.Paint = function(self, lw, lh)
				local capturing = PM.capture == row.custom and row.custom != nil
				local key = capturing and "нажмите клавишу…" or KeyOf(row)

				if (row.custom and (self:IsHovered() or capturing)) then
					draw.RoundedBox(4, -6, 1, lw + 12, lh - 2, Color(255, 255, 255, capturing and 22 or 10))
				end

				surface.SetFont("nwPauseKey")

				local kw = surface.GetTextSize(key) + sh * 0.02

				draw.SimpleText(row[1], "nwPauseText", 0, lh / 2, row.custom and U.color.text or U.color.dim,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.RoundedBox(4, lw - kw, lh * 0.14, kw, lh * 0.72,
					capturing and Color(232, 196, 72, 60) or Color(255, 255, 255, 16))
				draw.SimpleText(key, "nwPauseKey", lw - kw / 2, lh / 2,
					key == "не назначено" and BAD or U.color.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				surface.SetDrawColor(255, 255, 255, 10)
				surface.DrawRect(0, lh - 1, lw, 1)
			end
			line.DoClick = function()
				if (!row.custom) then
					return
				end

				PM.capture = row.custom
				parent:SetKeyboardInputEnabled(true)
				parent:RequestFocus()
				U.Tick()
			end

			cy = cy + rowH
		end

		cy = cy + math.Round(sh * 0.012)
	end

	-- under the list, not over it
	local button = panel:Add("DButton")

	cy = cy + math.Round(sh * 0.01)
	button:SetSize(math.Round(w * 0.62), math.Round(sh * 0.04))
	button:SetPos(0, cy)
	button:SetText("")
	button.Paint = function(self, bw, bh)
		draw.RoundedBox(6, 0, 0, bw, bh, Color(255, 255, 255, self:IsHovered() and 26 or 12))
		draw.SimpleText("Остальные клавиши — в настройках игры", "nwPauseSmall", bw / 2, bh / 2,
			self:IsHovered() and U.color.text or U.color.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	button.OnCursorEntered = function()
		surface.PlaySound("network2/ui/hover.wav")
	end
	button.DoClick = function()
		PM.allowGameMenu = true
		PM.Close()
		RunConsoleCommand("gamemenucommand", "openoptionsdialog")
		gui.ActivateGameUI()
	end

	panel:SetTall(cy + button:GetTall())

	return panel
end

-- a key pressed while waiting for one
local function Capture(frame, code)
	local id = PM.capture

	if (!id) then
		return
	end

	PM.capture = nil
	frame:SetKeyboardInputEnabled(false)

	if (code == KEY_ESCAPE) then
		return
	end

	RunConsoleCommand(NW.keys.byID[id].convar, tostring(code))
	surface.PlaySound("network2/ui/char/hls_ui_affirm.wav")
end

-- ------------------------------------------------------------------ menu --
function PM.IsOpen()
	return IsValid(PM.frame) and PM.frame.target == 1
end

function PM.Close()
	PM.capture = nil

	if (PM.IsOpen()) then
		PM.frame.target = 0
		PM.frame:SetMouseInputEnabled(false)
		PM.frame:SetKeyboardInputEnabled(false)
		surface.PlaySound("network2/ui/char/textline_2.wav")
	end
end

function PM.Open()
	if (PM.IsOpen()) then
		return
	end

	if (IsValid(PM.frame)) then
		PM.frame:Remove()
	end

	local sw, sh = ScrW(), ScrH()
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(sw, sh)
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	frame.appear = 0
	frame.target = 1
	frame.page = nil

	local M = math.Round(sh * 0.09)

	frame.Paint = function(self, w, h)
		local e = Ease(self.appear)

		U.Blur(0, 0, w, h, 5 * e, 255 * e, nil, 1)
		surface.SetDrawColor(10, 12, 14, 200 * e)
		surface.DrawRect(0, 0, w, h)
		surface.SetMaterial(VIGNETTE)
		surface.SetDrawColor(255, 255, 255, 255 * e)
		surface.DrawTexturedRect(0, 0, w, h)

		-- a darker band on the left behind the menu
		draw.NoTexture()

		for i = 0, 19 do
			surface.SetDrawColor(0, 0, 0, (120 - i * 6) * e)
			surface.DrawRect(i * w * 0.025, 0, w * 0.025, h)
		end

		-- the emblem and the title
		local es = math.Round(sh * 0.07)
		local slide = (1 - e) * sh * 0.03

		surface.SetMaterial(EMBLEM)
		surface.SetDrawColor(255, 255, 255, 255 * e)
		surface.DrawTexturedRect(M - slide, sh * 0.16, es, es)

		draw.SimpleText("NETWORK", "nwPauseTitle", M + es + sh * 0.02 - slide, sh * 0.16 + es * 0.42,
			ColorAlpha(U.color.text, 255 * e), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Half-Life Roleplay  ·  пауза", "nwPauseSub", M + es + sh * 0.022 - slide,
			sh * 0.16 + es * 0.95, ColorAlpha(MUTED, 255 * e), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(255, 255, 255, 40 * e)
		surface.DrawRect(M - slide, sh * 0.16 + es + sh * 0.035, sh * 0.42, 1)

		-- the server, bottom left
		draw.SimpleText(GetHostName(), "nwPauseSmall", M, h - sh * 0.06, ColorAlpha(MUTED, 255 * e), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end
	frame.Think = function(self)
		self.appear = math.Approach(self.appear, self.target, FrameTime() / (self.target == 1 and 0.25 or 0.2))
		self:SetAlpha(255 * Ease(self.appear))

		if (self.target == 0 and self.appear <= 0) then
			self:Remove()
		end
	end

	-- the buttons
	local items = {
		{"Вернуться в игру", function()
			PM.Close()
		end},
		{"Персонажи", function()
			PM.Close()
			RunConsoleCommand("nw_menu")
		end},
		{"Бинды", function(button)
			frame.page = frame.page != "binds" and "binds" or nil

			if (IsValid(frame.binds)) then
				frame.binds:SetVisible(frame.page == "binds")
			end
		end, "binds"},
		{"Сообщество", function()
			local url = GetConVar("nw_community_url") and GetConVar("nw_community_url"):GetString() or ""

			if (url != "") then
				gui.OpenURL(url)
			else
				chat.AddText(U.color.accent, "[Network] ", U.color.text,
					"Ссылка сообщества ещё не задана (nw_community_url).")
			end
		end},
		{"Отключиться", function(button)
			if (!button.confirm) then
				button.confirm = RealTime()
				U.Tick()

				return
			end

			RunConsoleCommand("disconnect")
		end, nil, true}
	}

	local y = math.Round(sh * 0.36)
	local bh = math.Round(sh * 0.062)

	for index, info in ipairs(items) do
		local button = frame:Add("DButton")

		button:SetPos(M, y + (index - 1) * bh)
		button:SetSize(math.Round(sh * 0.5), bh)
		button:SetText("")
		button.hover = 0
		button.Paint = function(self, w, h)
			self.hover = Lerp(math.Clamp(FrameTime() * 12, 0, 1), self.hover, self:IsHovered() and 1 or 0)

			-- "Отключиться" asks once more for 3 seconds
			if (self.confirm and RealTime() - self.confirm > 3) then
				self.confirm = nil
			end

			local text = self.confirm and "Точно отключиться?" or info[1]
			local active = info[3] and frame.page == info[3]
			local color = (info[4] and (self.confirm or self:IsHovered())) and BAD or
				((self:IsHovered() or active) and U.color.text or U.color.dim)
			local shift = math.Round(self.hover * sh * 0.012)

			if (self.hover > 0.01 or active) then
				surface.SetDrawColor(color.r, color.g, color.b, 220 * math.max(self.hover, active and 1 or 0))
				surface.DrawRect(0, h * 0.28, 2, h * 0.44)
			end

			draw.SimpleText(text, "nwPauseButton", sh * 0.02 + shift, h / 2, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		button.OnCursorEntered = function()
			surface.PlaySound("network2/ui/hover.wav")
		end
		button.DoClick = function(self)
			if (!info[4]) then
				U.Tick()
			end

			info[2](self)
		end
	end

	-- the small link to the game's own menu
	local link = frame:Add("DButton")

	link:SetSize(math.Round(sh * 0.25), math.Round(sh * 0.03))
	link:SetPos(M, sh - sh * 0.11)
	link:SetText("")
	link.Paint = function(self, w, h)
		draw.SimpleText("Меню Garry's Mod", "nwPauseSmall", 0, h / 2, self:IsHovered() and U.color.text or MUTED,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	link.DoClick = function()
		PM.allowGameMenu = true
		PM.Close()
		gui.ActivateGameUI()
	end

	frame.binds = BindsPanel(frame, math.Round(sw * 0.55), math.Round(sh * 0.14), math.Round(sh * 0.56))
	frame.OnKeyCodePressed = function(self, code)
		Capture(self, code)
	end
	frame.binds:SetVisible(false)

	PM.frame = frame
	surface.PlaySound("network2/ui/char/hls_ui_appear.wav")
end

-- ---------------------------------------------------------------- ESC --
hook.Add("OnPauseMenuShow", "nwPause", function()
	-- "Меню Garry's Mod": let the game menu through once
	if (PM.allowGameMenu) then
		PM.allowGameMenu = nil

		return
	end

	-- waiting for a key in Бинды: ESC only cancels that
	if (PM.capture and IsValid(PM.frame)) then
		PM.capture = nil
		PM.frame:SetKeyboardInputEnabled(false)

		return false
	end

	-- placing a pose (the G wheel)
	if (NW.wheel and NW.wheel.placing) then
		NW.wheel.CancelPlace()

		return false
	end

	-- other windows (the interaction wheel, the CID card...): true when one closed
	if (hook.Run("NWEscape")) then
		return false
	end

	local chatbox = NW.chat

	if (chatbox and chatbox.open and chatbox.Close) then
		chatbox.Close()

		return false
	end

	local inventory = NW.inventory

	if (inventory and inventory.IsOpen and inventory.IsOpen()) then
		inventory.Close()

		return false
	end

	if (inventory and IsValid(inventory.take)) then
		inventory.take.target = 0

		return false
	end

	-- the main menu and the character screens keep the usual game menu
	if (NW.menu and NW.menu.active) then
		return
	end

	if (PM.IsOpen()) then
		PM.Close()
	else
		PM.Open()
	end

	return false
end)
