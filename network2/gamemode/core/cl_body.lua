-- Lying there: the screens of death and of being unconscious (server: sv_body.lua). In both the
-- camera sits in the eyes of the body (its head hidden for you only).
--   death        the colour drains, then the picture sinks into the dark: a slowly drifting red
--                smoke (materials/network2/ui/death_bg.png), falling ash, "ВЫ ПОГИБЛИ" letter by
--                letter, the time until you can come back (nw_respawn_time) and "[ПРОБЕЛ] Очнуться".
--   unconscious  the eyes close: almost black with a cold smoke (knock_bg.png) that breathes, the
--                world barely seen through it; "БЕЗ СОЗНАНИЯ" and:
--                  strong enough (30+ health) - "придёте в себя через N с", then "[ПРОБЕЛ] Прийти в себя";
--                  too weak - "Нужна помощь", and hold [ПРОБЕЛ] 3 s to give up (die).
-- Also: the answers to "Проверить пульс" (which bodies you checked and what you found).

NW.body = NW.body or {}

local B = NW.body
local U = NW.ui
local DEATH_BG = Material("network2/ui/death_bg.png", "smooth")
local KNOCK_BG = Material("network2/ui/knock_bg.png", "smooth")
local BLUR = Material("pp/blurscreen")
local state = {fade = 0, dark = 0, knock = 0, hold = 0, ash = {}}

local function Fonts()
	local h = ScrH()

	surface.CreateFont("nwDeathTitle", {font = "Jura", size = math.max(28, math.Round(h * 0.064)), weight = 700,
		extended = true, antialias = true})
	surface.CreateFont("nwDeathText", {font = "Exo 2", size = math.max(14, math.Round(h * 0.021)), weight = 500,
		extended = true, antialias = true})
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwDeathFonts", Fonts)

local function InGame(client)
	return IsValid(client) and client:GetCharacterID() != 0 and !NW.IsInMenu(client) and !(NW.menu and NW.menu.active)
end

local function Dead(client)
	return InGame(client) and !client:Alive()
end

function B.Knocked(client)
	return InGame(client) and client:Alive() and client:GetNW2Bool("nwKnocked", false)
end

local function Body(client)
	local body = client:GetNW2Entity("nwBody")

	if (IsValid(body)) then
		return body
	end

	local ragdoll = client:GetRagdollEntity()

	return IsValid(ragdoll) and ragdoll or nil
end

-- ---------------------------------------------------------------- pulse --
B.pulse = B.pulse or {}

net.Receive("nwPulse", function()
	local body = net.ReadEntity()
	local alive = net.ReadBool()

	if (IsValid(body)) then
		B.pulse[body] = alive
	end
end)

-- ------------------------------------------------------------------ state --
hook.Add("Think", "nwBodyScreen", function()
	local client = LocalPlayer()
	local dead, knocked = Dead(client), B.Knocked(client)
	local dt = FrameTime()

	if (dead and !state.dead) then
		state.since = RealTime()
		state.angles = nil
		state.ash = {}
	end

	if (knocked and !state.knocked) then
		state.knockSince = RealTime()
		state.angles = nil
		state.hold = 0
	end

	state.dead, state.knocked = dead, knocked
	state.fade = math.Approach(state.fade, dead and 1 or 0, dt * (dead and 0.6 or 3))
	state.knock = math.Approach(state.knock, knocked and 1 or 0, dt * (knocked and 0.9 or 2.5))

	-- after the fall the picture sinks into the background
	local wantDark = dead and RealTime() - (state.since or 0) > 2.2 and 0.93 or 0

	state.dark = math.Approach(state.dark, wantDark, dt * (wantDark > 0 and 0.45 or 3))

	-- the head of the body is not in the way (for you only)
	local body = (dead or knocked) and Body(client)

	if (body != state.body) then
		if (IsValid(state.body) and state.headBone) then
			state.body:ManipulateBoneScale(state.headBone, Vector(1, 1, 1))
		end

		state.body = body or nil
		state.headBone = nil

		if (IsValid(body)) then
			state.headBone = body:LookupBone("ValveBiped.Bip01_Head1")

			if (state.headBone) then
				body:ManipulateBoneScale(state.headBone, Vector(0, 0, 0))
			end
		end
	end

	-- unconscious: hold Space to give up (only when too weak to get up), press to come to
	if (knocked) then
		local key = input.GetKeyCode(input.LookupBinding("+jump", true) or "SPACE")
		local down = key and key > 0 and input.IsKeyDown(key) and !vgui.GetKeyboardFocus() and !gui.IsGameUIVisible()
		local weak = client:Health() < client:GetNW2Int("nwWakeHP", 30)
		local ready = CurTime() >= client:GetNW2Float("nwWakeAt", 0)

		if (weak) then
			state.hold = down and state.hold + dt or 0

			if (state.hold >= 3 and !state.sent) then
				state.sent = true

				net.Start("nwKnock")
					net.WriteString("giveup")
				net.SendToServer()
			end
		elseif (ready and down and !state.sent) then
			state.sent = true

			net.Start("nwKnock")
				net.WriteString("wake")
			net.SendToServer()

			timer.Simple(1, function()
				state.sent = nil
			end)
		end
	else
		state.hold = 0
		state.sent = nil
	end
end)

-- ----------------------------------------------------------------- camera --
hook.Add("CalcView", "nwBodyScreen", function(client, origin, angles, fov)
	if (!Dead(client) and !B.Knocked(client)) then
		return
	end

	local body = Body(client)

	if (!body) then
		return
	end

	local attachment = body:LookupAttachment("eyes")
	local eyes = attachment and attachment > 0 and body:GetAttachment(attachment)

	if (!eyes) then
		return
	end

	-- smoothed, so the tumbling body does not shake the picture to pieces
	state.angles = state.angles and LerpAngle(math.min(FrameTime() * 8, 1), state.angles, eyes.Ang) or eyes.Ang

	return {origin = eyes.Pos + eyes.Ang:Forward() * 1.5, angles = state.angles, fov = fov, znear = 1,
		drawviewer = false}
end)

hook.Add("ShouldDrawLocalPlayer", "nwBodyScreen", function(client)
	if (Dead(client) or B.Knocked(client)) then
		return false
	end
end)

hook.Add("PreDrawViewModel", "nwBodyScreen", function()
	if (B.Knocked(LocalPlayer())) then
		return true
	end
end)

hook.Add("CreateMove", "nwBodyScreen", function(cmd)
	if (B.Knocked(LocalPlayer())) then
		cmd:ClearMovement()
		cmd:ClearButtons()
	end
end)

hook.Add("RenderScreenspaceEffects", "nwBodyScreen", function()
	local f = math.max(state.fade, state.knock)

	if (f <= 0.01) then
		return
	end

	DrawColorModify({
		["$pp_colour_addr"] = 0.02 * state.fade,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.12 * f,
		["$pp_colour_contrast"] = 1 - 0.2 * f,
		["$pp_colour_colour"] = 1 - 0.92 * f,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0
	})
	DrawMotionBlur(0.2, 0.6 * f, 0.01)
end)

-- ---------------------------------------------------------------- drawing --
local function Blur(amount)
	surface.SetMaterial(BLUR)
	surface.SetDrawColor(255, 255, 255, 255)

	for i = 1, 2 do
		BLUR:SetFloat("$blur", i * amount)
		BLUR:Recompute()
		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
	end
end

-- a background slowly drifting (a little bigger than the screen)
local function Background(material, alpha, speed)
	local sw, sh = ScrW(), ScrH()
	local t = RealTime() * (speed or 1)
	local scale = 1.12
	local w, h = sw * scale, math.max(sh * scale, sw * scale * 9 / 16)
	local x = -(w - sw) / 2 + math.sin(t * 0.07) * sw * 0.04
	local y = -(h - sh) / 2 + math.cos(t * 0.05) * sh * 0.03

	surface.SetMaterial(material)
	surface.SetDrawColor(255, 255, 255, 255 * alpha)
	surface.DrawTexturedRect(x, y, w, h)
end

-- ash falling through the dark
local function Ash(alpha)
	local sw, sh = ScrW(), ScrH()
	local ash = state.ash

	while (#ash < 70) do
		ash[#ash + 1] = {x = math.Rand(0, sw), y = math.Rand(-sh, sh), s = math.Rand(1, 3.2), v = math.Rand(8, 26),
			drift = math.Rand(0, 6.28), a = math.Rand(0.2, 0.8)}
	end

	local dt = FrameTime()

	draw.NoTexture()

	for _, p in ipairs(ash) do
		p.y = p.y + p.v * dt
		p.x = p.x + math.sin(RealTime() * 0.6 + p.drift) * 8 * dt

		if (p.y > sh + 10) then
			p.y = -10
			p.x = math.Rand(0, sw)
		end

		surface.SetDrawColor(210, 170, 150, 90 * p.a * alpha)
		surface.DrawRect(p.x, p.y, p.s, p.s)
	end
end

local function Letters(title, age, x, y, color)
	local shown = math.Clamp(math.floor(age / 0.09), 0, utf8.len(title))

	if (shown > 0) then
		local text = string.sub(title, 1, (utf8.offset(title, shown + 1) or (#title + 1)) - 1)

		draw.SimpleText(text, "nwDeathTitle", x, y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

local function Key(text, x, y, alpha)
	if (NW.interact and NW.interact.DrawKey) then
		NW.interact.DrawKey(input.LookupBinding("+jump", true) or "space", text, x, y, alpha)
	end
end

local function DrawDeath()
	local f = state.fade
	local sw, sh = ScrW(), ScrH()

	Blur(2 * f)
	surface.SetDrawColor(0, 0, 0, 120 * f)
	surface.DrawRect(0, 0, sw, sh)

	-- sinking into the dark
	if (state.dark > 0.01) then
		surface.SetDrawColor(0, 0, 0, 255 * state.dark)
		surface.DrawRect(0, 0, sw, sh)
		Background(DEATH_BG, state.dark * 0.95, 1)
		Ash(state.dark)
	end

	if (!state.dead) then
		return
	end

	local age = RealTime() - (state.since or RealTime())
	local cy = sh * 0.44

	Letters("ВЫ ПОГИБЛИ", age - 0.8, sw / 2, cy, Color(226, 218, 214, 240 * f))

	if (age < 2.4) then
		return
	end

	local a = math.Clamp((age - 2.4) / 0.8, 0, 1) * f

	surface.SetDrawColor(200, 70, 60, 160 * a)
	surface.DrawRect(sw / 2 - sh * 0.06, cy + sh * 0.045, sh * 0.12, 2)

	local left = LocalPlayer():GetNW2Float("nwRespawnAt", 0) - CurTime()

	if (left > 0) then
		draw.SimpleText(string.format("Очнуться можно через %d с", math.ceil(left)), "nwDeathText", sw / 2,
			cy + sh * 0.08, Color(176, 170, 168, 230 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else
		Key("Очнуться", sw / 2, cy + sh * 0.085, a)
	end
end

local function DrawKnock()
	local client = LocalPlayer()
	local k = state.knock
	local sw, sh = ScrW(), ScrH()
	local breath = 0.5 + math.sin(RealTime() * 1.3) * 0.5

	-- the eyes close; now and then they almost open
	Blur(3 * k)
	surface.SetDrawColor(0, 0, 0, 255 * k * (0.86 + breath * 0.08))
	surface.DrawRect(0, 0, sw, sh)
	Background(KNOCK_BG, k * (0.55 + breath * 0.2), 0.6)

	if (!state.knocked) then
		return
	end

	local age = RealTime() - (state.knockSince or RealTime())
	local cy = sh * 0.44

	Letters("БЕЗ СОЗНАНИЯ", age - 0.6, sw / 2, cy, Color(206, 212, 222, 235 * k))

	if (age < 2) then
		return
	end

	local a = math.Clamp((age - 2) / 0.8, 0, 1) * k
	local weak = client:Health() < client:GetNW2Int("nwWakeHP", 30)
	local left = client:GetNW2Float("nwWakeAt", 0) - CurTime()

	surface.SetDrawColor(120, 150, 190, 150 * a)
	surface.DrawRect(sw / 2 - sh * 0.06, cy + sh * 0.045, sh * 0.12, 2)

	if (weak) then
		draw.SimpleText("Вы слишком слабы, чтобы встать. Нужна помощь", "nwDeathText", sw / 2, cy + sh * 0.08,
			Color(196, 200, 208, 230 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		Key("Зажать 3 с — сдаться", sw / 2, cy + sh * 0.13, a * 0.85)

		if (state.hold > 0) then
			local w = sh * 0.2

			draw.RoundedBox(2, sw / 2 - w / 2, cy + sh * 0.16, w, 4, Color(0, 0, 0, 160 * a))
			draw.RoundedBox(2, sw / 2 - w / 2, cy + sh * 0.16, w * math.Clamp(state.hold / 3, 0, 1), 4,
				Color(200, 70, 60, 255 * a))
		end
	elseif (left > 0) then
		draw.SimpleText(string.format("Вы придёте в себя через %d с", math.ceil(left)), "nwDeathText", sw / 2,
			cy + sh * 0.08, Color(196, 200, 208, 230 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else
		Key("Прийти в себя", sw / 2, cy + sh * 0.085, a)
	end
end

-- over the whole HUD (it shows through only faintly)
hook.Add("PostDrawHUD", "nwBodyScreen", function()
	if (state.fade <= 0.01 and state.knock <= 0.01) then
		return
	end

	cam.Start2D()

	if (state.knock > 0.01) then
		DrawKnock()
	end

	if (state.fade > 0.01) then
		DrawDeath()
	end

	cam.End2D()
end)
