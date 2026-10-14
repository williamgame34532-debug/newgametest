-- Main menu, client side: the camera flies through the map's menu points (sv_menu.lua) over a
-- slightly muted, darker picture; the NETWORK title top left; "Играть", "Сообщество",
-- "Отключиться" in a column bottom right. Button backgrounds are small materials
-- (materials/network2/menu/button*.png), fonts Jura / Exo 2 (resource/fonts).
-- "Играть": fade to black, then the character creation (no characters yet) or the character
-- selection (cl_charcreate.lua, cl_charselect.lua).

NW.menu = NW.menu or {}

local M = NW.menu
local U = NW.ui

M.sets = M.sets or {main = {}, char = {}}
M.cameraSet = M.cameraSet or "main"

local BUTTON = Material("network2/menu/button.png", "smooth")
local BUTTON_HOVER = Material("network2/menu/button_hover.png", "smooth")
local VIGNETTE = Material("network2/menu/vignette.png", "smooth")
local TITLE = Material("network2/watermark.png", "smooth mips")

-- sounds of the main menu buttons (any sound path works; empty = none)
local SOUND_HOVER = CreateClientConVar("nw_menu_sound_hover", "network2/ui/hover.wav", true, false,
	"Звук наведения на кнопку меню")
local SOUND_CLICK = CreateClientConVar("nw_menu_sound_click", "network2/ui/click.wav", true, false,
	"Звук нажатия кнопки меню")
local SOUND_CONFIRM = CreateClientConVar("nw_menu_sound_play", "network2/ui/confirm.mp3", true, false,
	"Звук кнопки «Играть»")

local function Play(convar)
	local path = convar:GetString()

	if (path == "") then
		return
	end

	if (!file.Exists("sound/" .. path, "GAME")) then
		path = convar:GetDefault()
	end

	surface.PlaySound(path)
end

M.PlayConfirm = function()
	Play(SOUND_CONFIRM)
end

local function Fonts()
	local h = ScrH()

	surface.CreateFont("nwMenuButton", {font = "Jura", size = math.Round(h * 0.034), weight = 700, extended = true,
		antialias = true})
	surface.CreateFont("nwMenuHint", {font = "Jura Medium", size = math.Round(h * 0.018), weight = 500,
		extended = true, antialias = true})
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwMenuFonts", Fonts)

net.Receive("nwMenuPoints", function()
	for _, set in ipairs({"main", "char"}) do
		M.sets[set] = {}

		for _ = 1, net.ReadUInt(8) do
			table.insert(M.sets[set], {pos = net.ReadVector(), ang = net.ReadAngle()})
		end
	end

	M.paths = {}
end)

-- ----------------------------------------------------------------- camera --
M.paths = M.paths or {}

local function MenuView(origin)
	local set = M.cameraSet
	local points = M.sets[set]

	-- the creation camera falls back to the menu points
	if (#points == 0 and set == "char") then
		set = "main"
		points = M.sets.main
	end

	local now = RealTime() - (M.cameraStart or 0)

	if (#points == 0) then
		return origin + Vector(0, 0, 40), Angle(10, now * 4, 0)
	end

	local path = M.paths[set]

	if (!path) then
		path = U.CameraPath(points, GetConVar("nw_menu_speed"):GetFloat())
		M.paths[set] = path
	end

	return U.CameraAt(path, now)
end

function M.SetCamera(set)
	if (M.cameraSet != set) then
		M.cameraSet = set
		M.cameraStart = RealTime()
	end
end

hook.Add("CalcView", "nwMenu", function(client, origin, angles, fov)
	if (!M.active) then
		return
	end

	local pos, ang = MenuView(M.anchor or origin)

	return {origin = pos, angles = ang, fov = 75, drawviewer = true}
end)

hook.Add("PreDrawViewModel", "nwMenu", function()
	if (M.active) then
		return true
	end
end)

-- a little muted and darker, no more
local MOOD = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0.004,
	["$pp_colour_brightness"] = -0.025,
	["$pp_colour_contrast"] = 0.96,
	["$pp_colour_colour"] = 0.6,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

hook.Add("RenderScreenspaceEffects", "nwMenu", function()
	if (M.active) then
		DrawColorModify(MOOD)
	end
end)

hook.Add("HUDShouldDraw", "nwMenu", function()
	if (M.active) then
		return false
	end
end)

-- ------------------------------------------------------------------ panel --
local function MenuButton(parent, text, callback)
	local button = parent:Add("DButton")

	button:SetText("")
	button.hover = 0
	button.Paint = function(self, w, h)
		self.hover = math.Approach(self.hover, self:IsHovered() and 1 or 0, FrameTime() * 6)

		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(BUTTON)
		surface.DrawTexturedRect(0, 0, w, h)

		if (self.hover > 0) then
			surface.SetDrawColor(255, 255, 255, 255 * self.hover)
			surface.SetMaterial(BUTTON_HOVER)
			surface.DrawTexturedRect(0, 0, w, h)
		end

		local pad = h * 0.6 + self.hover * h * 0.25

		draw.SimpleText(text, "nwMenuButton", w - pad, h / 2, U.color.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	button.OnCursorEntered = function()
		Play(SOUND_HOVER)
	end
	button.DoClick = function()
		Play(SOUND_CLICK)
		callback()
	end

	return button
end

function M.ShowMain(bVisible)
	if (IsValid(M.panel)) then
		M.panel:SetVisible(bVisible)

		if (bVisible) then
			M.panel:MakePopup()
			M.panel:SetKeyboardInputEnabled(false)
		end
	end

	if (bVisible) then
		M.SetCamera("main")
	end
end

function M.Close()
	if (IsValid(M.panel)) then
		M.panel:Remove()
	end

	for _, screen in ipairs({NW.charCreate, NW.charSelect}) do
		if (screen and screen.Close) then
			screen.Close()
		end
	end

	M.active = false
end

-- "Играть": creation when there is no character, otherwise the selection
function M.OpenCharacters()
	if (#(NW.char.list or {}) == 0) then
		NW.charCreate.Open()
	else
		NW.charSelect.Open()
	end
end

function M.Open()
	if (IsValid(M.panel)) then
		return
	end

	M.active = true
	M.cameraSet = "main"
	M.cameraStart = RealTime()
	M.anchor = LocalPlayer():EyePos()

	U.FadeTo(0, 1.2)

	local panel = vgui.Create("EditablePanel")
	panel:SetSize(ScrW(), ScrH())
	panel:MakePopup()
	panel:SetKeyboardInputEnabled(false)
	panel.Paint = function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(VIGNETTE)
		surface.DrawTexturedRect(0, 0, w, h)

		local tw = w * 0.36
		surface.SetMaterial(TITLE)
		surface.DrawTexturedRect(w * 0.045, h * 0.07, tw, tw / 4)

		draw.SimpleText(GetHostName(), "nwMenuHint", w * 0.05, h - h * 0.05, U.color.dim, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_BOTTOM)
	end

	M.panel = panel

	local w, h = math.Round(ScrW() * 0.27), math.Round(ScrH() * 0.062)
	local gap = math.Round(h * 0.18)
	local bottom = ScrH() - math.Round(ScrH() * 0.09)
	local buttons = {
		{"Играть", function()
			if (M.busy) then
				return
			end

			M.busy = true
			Play(SOUND_CONFIRM)

			U.Transition(function()
				M.busy = false
				M.ShowMain(false)
				M.OpenCharacters()
			end, 0.6, 0.8, 0.25)
		end},
		{"Сообщество", function()
			local url = GetConVar("nw_community_url"):GetString()

			if (url != "") then
				gui.OpenURL(url)
			else
				chat.AddText(U.color.accent, "[Network] ", U.color.text, "Ссылка сообщества ещё не задана (nw_community_url).")
			end
		end},
		{"Отключиться", function()
			U.FadeTo(255, 0.4)

			timer.Simple(0.45, function()
				RunConsoleCommand("disconnect")
			end)
		end}
	}

	for index, entry in ipairs(buttons) do
		local button = MenuButton(panel, entry[1], entry[2])
		local y = bottom - (#buttons - index + 1) * (h + gap)

		button:SetSize(w, h)
		button:SetPos(ScrW() - w, y)
	end
end

net.Receive("nwMenuOpen", function()
	U.fade.alpha = 255
	M.Open()
end)

hook.Add("InitPostEntity", "nwMenu", function()
	U.fade.alpha = 255
	U.fade.target = 255

	net.Start("nwMenuReady")
	net.SendToServer()
end)

-- in the world with a character: the menu closes, the picture fades in
function M.EnterWorld()
	local started = RealTime()

	timer.Create("nwMenuEnter", 0.1, 100, function()
		local client = LocalPlayer()

		if (IsValid(client) and client:Alive() and !NW.IsInMenu(client) or RealTime() - started > 8) then
			timer.Remove("nwMenuEnter")
			M.Close()
			U.FadeTo(0, 1.0)
		end
	end)
end

-- F2 opens nothing now (it answers requests): the characters are in the pause menu (Персонажи)

