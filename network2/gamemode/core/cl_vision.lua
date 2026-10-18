-- The visions and the light.
--   thermal   the Alliance, the key "Тепловизор" (N): the world goes cold, the living glow white-hot
--   nvg       the night vision: the light really amplified - a strong light only you see goes with your
--             eyes, so the dark rooms and the night streets open up;
--               the goggles of the city   (the item «Прибор ночного видения» put on) - green, grainy, the
--                                         round edges of the tubes, a thin whine
--               the visor of the Alliance (always there)                       - cold blue-white, clean,
--                                         a hex grid, the state in the HUD of the Alliance
--   the walls both show the living behind the walls faintly (their movement, up to 1400 units)
--   the heat  each device warms on its own: the thermal 30 s, the goggles of the city 30 s, the visor of
--             the Alliance 60 s; then it overheats - off and cooling (20 s, the Alliance 15 s); off, it
--             cools by itself
-- The key "Фонарик / ПНВ" (F): a tap - the main one of the two (the flashlight or the night vision);
-- held - the choice of the main one (when both are there). The Alliance has both always; the others -
-- with the items (a flashlight, the goggles). nw_light_primary - the choice, kept.
-- Sounds: sound/network2/nvg (branding/make_nvg_sounds.py).

NW.vision = NW.vision or {}

local VI = NW.vision
local WALL = 1400

local primary = CreateClientConVar("nw_light_primary", "nvg", true, false, "Основной прибор на F: flashlight / nvg")

local mode
local switched = 0
local heat = {thermal = 0, nvg = 0}
local overheated = {thermal = 0, nvg = 0}

local HOT = CreateMaterial("nwThermalHot", "VertexLitGeneric", {
	["$basetexture"] = "color/white",
	["$selfillum"] = 1,
	["$model"] = 1
})

local COLD = {
	["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0.02, ["$pp_colour_addb"] = 0.06, ["$pp_colour_brightness"] = -0.08,
	["$pp_colour_contrast"] = 0.9, ["$pp_colour_colour"] = 0, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0.3
}

-- the goggles of the city: green
local GREEN = {
	["$pp_colour_addr"] = -0.03, ["$pp_colour_addg"] = 0.06, ["$pp_colour_addb"] = -0.03, ["$pp_colour_brightness"] = 0.04,
	["$pp_colour_contrast"] = 1.45, ["$pp_colour_colour"] = 0, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

-- the visor of the Alliance: cold blue-white
local VISOR = {
	["$pp_colour_addr"] = -0.02, ["$pp_colour_addg"] = 0.02, ["$pp_colour_addb"] = 0.07, ["$pp_colour_brightness"] = 0.03,
	["$pp_colour_contrast"] = 1.25, ["$pp_colour_colour"] = 0.05, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

local function Alliance(client)
	return IsValid(client) and NW.zones.IsAlliance(client)
end

-- how long it works and cools (seconds)
local function Limits(id, client)
	if (id == "nvg" and Alliance(client)) then
		return 60, 15
	end

	return 30, 20
end

VI.modes = {
	thermal = {name = "ТЕПЛОВИЗОР",
		Sound = function(bOn)
			return bOn and "buttons/combine_button1.wav" or "buttons/combine_button2.wav"
		end,
		Allowed = function(client)
			return Alliance(client)
		end, denied = "Тепловизор — в маске Альянса"},
	nvg = {name = "НОЧНОЕ ВИДЕНИЕ",
		Sound = function(bOn, client)
			return "network2/nvg/" .. (Alliance(client) and "cmb_" or "") .. (bOn and "on" or "off") .. ".wav"
		end,
		Allowed = function(client)
			return client:GetNW2Bool("nwHasNVG", false)
		end, denied = "Нужен прибор ночного видения"}
}

local function Able(client, id)
	return IsValid(client) and client:Alive() and !(NW.Incapable and NW.Incapable(client)) and VI.modes[id].Allowed(client)
end

local hum

local function Hum(bOn)
	if (bOn and !hum) then
		hum = CreateSound(LocalPlayer(), "network2/nvg/hum_loop.wav")
		hum:SetSoundLevel(0)
		hum:PlayEx(Alliance(LocalPlayer()) and 0.05 or 0.14, 100)
	elseif (!bOn and hum) then
		hum:Stop()
		hum = nil
	end
end

local function Set(id)
	if (mode == id) then
		return
	end

	local old = mode
	local client = LocalPlayer()

	mode = id
	switched = RealTime()

	if (id) then
		surface.PlaySound(VI.modes[id].Sound(true, client))
	elseif (old) then
		surface.PlaySound(VI.modes[old].Sound(false, client))
	end

	Hum(id == "nvg")
end

local function Toggle(id)
	local client = LocalPlayer()

	if (!Able(client, id)) then
		return NW.notify.Add(VI.modes[id].denied)
	end

	if (mode == id) then
		return Set(nil)
	end

	if (CurTime() < overheated[id]) then
		surface.PlaySound("buttons/button10.wav")

		return NW.notify.Add(VI.modes[id].name .. ": перегрев, ещё " .. math.ceil(overheated[id] - CurTime()) .. " с")
	end

	Set(id)
end

hook.Add("Think", "nwVision", function()
	local client = LocalPlayer()
	local frame = FrameTime()

	if (mode and !Able(client, mode)) then
		Set(nil)
	end

	for id in pairs(heat) do
		local work, cool = Limits(id, client)

		if (mode == id) then
			heat[id] = heat[id] + frame

			if (heat[id] >= work) then
				heat[id] = work
				overheated[id] = CurTime() + cool
				Set(nil)
				surface.PlaySound("network2/nvg/overheat.wav")
				NW.notify.Add(VI.modes[id].name .. ": перегрев, остывает " .. cool .. " с")
			end
		else
			heat[id] = math.max(0, heat[id] - frame * work / cool)
		end
	end
end)

function VI.Mode()
	return mode
end

-- 0..1 how hot; the seconds of overheat left; the seconds of work left
function VI.Heat(id)
	id = id or mode or "thermal"

	local work = Limits(id, LocalPlayer())

	return heat[id] / work, math.max(0, overheated[id] - CurTime()), work - heat[id]
end

function NW.ThermalOn()
	return mode == "thermal"
end

-- ----------------------------------------------------------------- the key F --
-- what the player has: the flashlight, the night vision
local function Has(which)
	local client = LocalPlayer()

	if (which == "flashlight") then
		return client:GetNW2Bool("nwHasLight", false)
	end

	return client:GetNW2Bool("nwHasNVG", false)
end

-- the main one: the choice, or the only one there is
function VI.Primary()
	local choice = primary:GetString() == "flashlight" and "flashlight" or "nvg"

	if (!Has(choice)) then
		choice = choice == "nvg" and "flashlight" or "nvg"
	end

	return Has(choice) and choice or nil
end

local function Use(which)
	if (which == "nvg") then
		Toggle("nvg")
	elseif (which == "flashlight") then
		net.Start("nwLightToggle")
		net.SendToServer()
	else
		NW.notify.Add("Нет ни фонарика, ни прибора ночного видения")
	end
end

local held
local chooser

local function CloseChooser(pick)
	if (IsValid(chooser)) then
		if (pick) then
			primary:SetString(pick)
			surface.PlaySound("network2/ui/click.wav")
			NW.notify.Add("Основной на F: " .. (pick == "nvg" and "ночное видение" or "фонарик"))
		end

		chooser:Remove()
	end

	gui.EnableScreenClicker(false)
end

local function OpenChooser()
	local sh = ScrH()
	local size = math.Round(sh * 0.16)
	local gap = math.Round(sh * 0.02)

	chooser = vgui.Create("EditablePanel")
	chooser:SetSize(size * 2 + gap, size + sh * 0.05)
	chooser:Center()
	chooser.Paint = function(_, w)
		draw.SimpleTextOutlined("Основной прибор на F", "nwWidgetBold", w / 2, 0, color_white, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 200))
	end

	for index, which in ipairs({"flashlight", "nvg"}) do
		local card = chooser:Add("DButton")

		card:SetText("")
		card:SetPos((index - 1) * (size + gap), sh * 0.04)
		card:SetSize(size, size)
		card.which = which
		card.Paint = function(self, w, h)
			local current = VI.Primary() == which

			draw.RoundedBox(10, 0, 0, w, h, self:IsHovered() and Color(232, 196, 72, 70) or Color(14, 16, 20, 230))

			if (current) then
				surface.SetDrawColor(232, 196, 72)
				surface.DrawOutlinedRect(0, 0, w, h, 2)
			end

			NW.ui.DrawIcon(which == "nvg" and "nvg" or "flashlight", w * 0.3, h * 0.14, w * 0.4, color_white)
			draw.SimpleText(which == "nvg" and "Ночное видение" or "Фонарик", "nwWidgetBold", w / 2, h * 0.7,
				color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(current and "основной" or "", "nwWidget", w / 2, h * 0.86, Color(232, 196, 72),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		card.DoClick = function()
			CloseChooser(which)
		end
	end

	gui.EnableScreenClicker(true)
	surface.PlaySound("network2/ui/hover.wav")
end

hook.Add("NWKey", "nwVision", function(id)
	if (id == "thermal") then
		Toggle("thermal")
	elseif (id == "light") then
		held = RealTime()
	end
end)

hook.Add("NWKeyUp", "nwVision", function(id)
	if (id != "light" or !held) then
		return
	end

	held = nil

	if (IsValid(chooser)) then
		-- let go over a card: that one
		local hovered = vgui.GetHoveredPanel()

		CloseChooser(IsValid(hovered) and hovered.which or nil)

		return
	end

	Use(VI.Primary())
end)

-- held long enough with both there: the choice
hook.Add("Think", "nwLightChooser", function()
	if (held and !IsValid(chooser) and RealTime() - held > 0.3 and Has("flashlight") and Has("nvg")) then
		OpenChooser()
	end
end)

-- -------------------------------------------------------------- the picture --
local function Warm()
	local out = {}
	local me = LocalPlayer()
	local eye = EyePos()

	for _, entity in ipairs(ents.GetAll()) do
		if ((entity:IsPlayer() and entity != me and entity:Alive() and !(NW.Hidden and NW.Hidden(entity))) or
			entity:IsNPC() or entity:IsNextBot()) then
			if (!entity:IsDormant() and entity:GetPos():DistToSqr(eye) < 4000 * 4000) then
				out[#out + 1] = entity
			end
		end
	end

	return out
end

-- the living drawn flat in one colour; through the walls faint and only near
local function Bodies(list, r, g, b, bSeen)
	local eye = EyePos()

	cam.Start3D()
		render.SuppressEngineLighting(true)
		render.MaterialOverride(HOT)
		cam.IgnoreZ(true)

		for _, entity in ipairs(list) do
			local distance = entity:GetPos():Distance(eye)

			if (distance < WALL) then
				render.SetColorModulation(r * 0.7, g * 0.7, b * 0.7)
				render.SetBlend((0.16 + 0.05 * math.sin(RealTime() * 9 + entity:EntIndex())) * (1 - distance / WALL))
				entity:DrawModel()
			end
		end

		cam.IgnoreZ(false)

		if (bSeen) then
			for _, entity in ipairs(list) do
				local hurt = entity:IsPlayer() and entity:Health() / math.max(entity:GetMaxHealth(), 1) or 1

				render.SetColorModulation(r, g * (0.75 + 0.25 * hurt), b)
				render.SetBlend(1)
				entity:DrawModel()
			end
		end

		render.MaterialOverride()
		render.SetColorModulation(1, 1, 1)
		render.SetBlend(1)
		render.SuppressEngineLighting(false)
	cam.End3D()
end

-- the amplified light: only this player sees it, it goes with the eyes
hook.Add("Think", "nwNightLight", function()
	if (mode != "nvg") then
		return
	end

	local light = DynamicLight(LocalPlayer():EntIndex() + 4096)

	if (light) then
		local cmb = Alliance(LocalPlayer())

		light.pos = EyePos() + EyeAngles():Forward() * 40
		light.r, light.g, light.b = cmb and 170 or 120, cmb and 200 or 255, cmb and 255 or 130
		light.brightness = cmb and 1.6 or 2
		light.decay = 0
		light.size = cmb and 1700 or 1300
		light.dietime = CurTime() + 0.2
	end
end)

hook.Add("RenderScreenspaceEffects", "nwVision", function()
	if (mode == "thermal") then
		DrawColorModify(COLD)
		DrawSharpen(0.6, 1.2)
		Bodies(Warm(), 1, 0.7, 0.18, true)
		DrawBloom(0.55, 1.8, 6, 6, 2, 1.2, 1, 0.85, 0.6)
	elseif (mode == "nvg") then
		if (Alliance(LocalPlayer())) then
			DrawColorModify(VISOR)
			DrawSharpen(0.8, 1)
			Bodies(Warm(), 0.6, 0.8, 1, false)
		else
			DrawColorModify(GREEN)
			DrawBloom(0.4, 1.8, 7, 7, 2, 1.2, 0.5, 1, 0.5)
			Bodies(Warm(), 0.55, 1, 0.55, false)
		end
	end
end)

surface.CreateFont("nwThermal", {font = "JetBrains Mono ExtraBold", size = math.max(12, math.Round(ScrH() * 0.016)),
	weight = 800, extended = true, antialias = true})

local VIGNETTE = Material("network2/menu/vignette.png", "smooth")

local function Corners(sw, sh, color)
	local m, c = sh * 0.06, sh * 0.05

	surface.SetDrawColor(color)

	for _, corner in ipairs({{m, m, 1, 1}, {sw - m, m, -1, 1}, {m, sh - m, 1, -1}, {sw - m, sh - m, -1, -1}}) do
		surface.DrawRect(corner[1] - (corner[3] < 0 and c or 0), corner[2] - (corner[4] < 0 and 2 or 0), c, 2)
		surface.DrawRect(corner[1] - (corner[3] < 0 and 2 or 0), corner[2] - (corner[4] < 0 and c or 0), 2, c)
	end

	surface.DrawRect(sw / 2 - 12, sh / 2, 8, 1)
	surface.DrawRect(sw / 2 + 5, sh / 2, 8, 1)
	surface.DrawRect(sw / 2, sh / 2 - 12, 1, 8)
	surface.DrawRect(sw / 2, sh / 2 + 5, 1, 8)

	return m, c
end

hook.Add("HUDPaint", "nwVisionSight", function()
	if (!mode or (NW.cameras and NW.cameras.full)) then
		return
	end

	local client = LocalPlayer()
	local sw, sh = ScrW(), ScrH()
	local t = RealTime()
	local cmb = Alliance(client)
	local on = math.Clamp((t - switched) / 0.35, 0, 1)
	local tint = mode == "thermal" and Color(230, 240, 248) or (cmb and Color(190, 220, 255) or Color(170, 255, 170))

	if (on < 1) then
		surface.SetDrawColor(tint.r, tint.g, tint.b, 180 * (1 - on))
		surface.DrawRect(0, 0, sw, sh)
	end

	if (mode == "nvg" and cmb) then
		-- the visor: a fine hex grid of the Combine, a slow sweep
		surface.SetDrawColor(150, 200, 255, 14)

		for y = 0, sh, 22 do
			surface.DrawRect(0, y, sw, 1)
		end

		for x = (t * 30) % 38, sw, 38 do
			surface.DrawRect(x, 0, 1, sh)
		end

		local sweep = (t * 0.25) % 1

		surface.SetDrawColor(180, 220, 255, 26)
		surface.DrawRect(0, sh * sweep, sw, 3)
	else
		surface.SetDrawColor(0, 0, 0, mode == "nvg" and 26 or 40)

		for y = (t * 40) % 4, sh, 4 do
			surface.DrawRect(0, y, sw, 1)
		end

		for _ = 1, mode == "nvg" and 380 or 160 do
			surface.SetDrawColor(tint.r, tint.g, tint.b, math.random(6, mode == "nvg" and 38 or 22))
			surface.DrawRect(math.random(0, sw), math.random(0, sh), 2, 2)
		end
	end

	-- the goggles of the city: the dark round edges of the tubes
	if (mode == "nvg" and !cmb) then
		surface.SetMaterial(VIGNETTE)
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawTexturedRect(0, 0, sw, sh)
		surface.DrawTexturedRect(0, 0, sw, sh)
	end

	local m, c = Corners(sw, sh, ColorAlpha(tint, 140))

	-- the state: in the HUD of the Alliance when it is shown (VI.DrawHud), here otherwise
	if (cmb and NW.combineHud and NW.combineHud.Active and NW.combineHud.Active()) then
		return
	end

	local level, _, left = VI.Heat(mode)
	local bw = sw * 0.14

	draw.SimpleText(VI.modes[mode].name .. " :: " .. math.ceil(left) .. " С", "nwThermal", m + c * 0.2, m + c * 0.6,
		ColorAlpha(tint, 210))
	surface.SetDrawColor(0, 0, 0, 140)
	surface.DrawRect(m + c * 0.2, m + c * 1.3, bw, 4)
	surface.SetDrawColor(255, 200 - 140 * level, 90 - 60 * level, 220)
	surface.DrawRect(m + c * 0.2, m + c * 1.3, bw * level, 4)
end)

-- in the HUD of the Alliance (cl_combinehud.lua): each device working, its heat, the overheat; nothing
-- when it is cold and off
function VI.DrawHud(x, y, Text, Bar, color)
	local sh = ScrH()

	for _, id in ipairs({"thermal", "nvg"}) do
		local level, cooling, left = VI.Heat(id)

		if (mode == id or level > 0 or cooling > 0) then
			local name = VI.modes[id].name
			local state

			y = y + sh * 0.008

			if (mode == id) then
				state = name .. " :: АКТИВЕН :: " .. math.ceil(left) .. " С" .. (id == "thermal" and (" :: ЦЕЛЕЙ " .. #Warm()) or "")
			elseif (cooling > 0) then
				state = name .. " :: ПЕРЕГРЕВ :: " .. math.ceil(cooling) .. " С"
			else
				state = name .. " :: ОСТЫВАЕТ"
			end

			local hot = Color(255, 200 - 130 * level, 90 - 60 * level, 230)
			local blink = cooling > 0 and math.floor(RealTime() * 3) % 2 == 0

			Text(state, "nwCmbSmall", x, y, blink and Color(255, 255, 255, 230) or (mode == id and color or hot),
				TEXT_ALIGN_LEFT, false)
			y = y + sh * 0.022
			Bar(x, y, ScrW() * 0.2, 2, ColorAlpha(color, 70))
			Bar(x, y, ScrW() * 0.2 * level, 2, hot)
			y = y + sh * 0.01
		end
	end

	return y
end
