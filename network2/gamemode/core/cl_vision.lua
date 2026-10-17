-- The visions: the thermal of the Alliance (the key "Тепловизор", N) and the night vision goggles
-- (the item "ПНВ" put on, the key "ПНВ", F).
--   thermal   the world goes cold - a dark blue-grey with the detail kept, the living glow
--             white-hot to orange; the state sits in the HUD of the Alliance (cl_combinehud.lua)
--   nvg       the light amplified: a bright green picture, the grain, the dark corners
--   the walls both show the living behind the walls faintly (their movement, up to
--             nw_vision_wall units away)
--   the heat  either works nw_vision_time seconds (30) in a row, then overheats: off, and cools for
--             nw_vision_cool seconds (20); switched off, it cools by itself
-- They switch off on death, falling, taking off the uniform or the goggles.

NW.vision = NW.vision or {}

local VI = NW.vision

local WORK, COOL, WALL = 30, 20, 1400


-- the state: the mode on, the heat (0..WORK seconds), overheated until
local mode
local switched = 0
local heat = 0
local overheated = 0

local HOT = CreateMaterial("nwThermalHot", "VertexLitGeneric", {
	["$basetexture"] = "color/white",
	["$selfillum"] = 1,
	["$model"] = 1
})

local COLD = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0.02,
	["$pp_colour_addb"] = 0.06,
	["$pp_colour_brightness"] = -0.08,
	["$pp_colour_contrast"] = 0.9,
	["$pp_colour_colour"] = 0,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0.3
}

local GREEN = {
	["$pp_colour_addr"] = -0.02,
	["$pp_colour_addg"] = 0.08,
	["$pp_colour_addb"] = -0.02,
	["$pp_colour_brightness"] = 0.12,
	["$pp_colour_contrast"] = 1.9,
	["$pp_colour_colour"] = 0,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

VI.modes = {
	thermal = {name = "ТЕПЛОВИЗОР", on = "buttons/combine_button1.wav", off = "buttons/combine_button2.wav",
		Allowed = function(client)
			return NW.zones.IsAlliance(client)
		end, denied = "Тепловизор — в маске Альянса"},
	nvg = {name = "ПНВ", on = "items/flashlight1.wav", off = "buttons/lightswitch2.wav",
		Allowed = function(client)
			return client:GetNW2Bool("nwHasNVG", false)
		end, denied = "Наденьте прибор ночного видения"}
}

local function Able(client, id)
	return IsValid(client) and client:Alive() and !(NW.Incapable and NW.Incapable(client)) and VI.modes[id].Allowed(client)
end

local function Set(id)
	if (mode == id) then
		return
	end

	local old = mode

	mode = id
	switched = RealTime()

	if (id) then
		surface.PlaySound(VI.modes[id].on)
	elseif (old) then
		surface.PlaySound(VI.modes[old].off)
	end
end

local function Toggle(id)
	local client = LocalPlayer()

	if (!Able(client, id)) then
		return NW.notify.Add(VI.modes[id].denied)
	end

	if (mode == id) then
		return Set(nil)
	end

	if (CurTime() < overheated) then
		surface.PlaySound("buttons/button10.wav")

		return NW.notify.Add(VI.modes[id].name .. " перегрет: " .. math.ceil(overheated - CurTime()) .. " с")
	end

	Set(id)
end

hook.Add("NWKey", "nwVision", function(id)
	if (id == "thermal" or id == "nvg") then
		Toggle(id)
	end
end)

hook.Add("Think", "nwVision", function()
	local client = LocalPlayer()
	local frame = FrameTime()

	if (mode and !Able(client, mode)) then
		Set(nil)
	end

	if (mode) then
		heat = heat + frame

		if (heat >= WORK) then
			heat = WORK
			overheated = CurTime() + COOL
			Set(nil)
			surface.PlaySound("ambient/energy/spark" .. math.random(1, 6) .. ".wav")
			NW.notify.Add("Перегрев прибора: остывает " .. COOL .. " с")
		end
	else
		-- cooling: from full to cold in COOL seconds
		heat = math.max(0, heat - frame * WORK / COOL)
	end
end)

function VI.Mode()
	return mode
end

-- 0..1 how hot; the seconds of overheat left
function VI.Heat()
	return heat / WORK, math.max(0, overheated - CurTime())
end

function NW.ThermalOn()
	return mode == "thermal"
end

-- the bodies that give heat (near: seen; behind the walls: up to WALL)
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
local function Bodies(list, r, g, b, bWalls)
	local eye = EyePos()

	cam.Start3D()
		render.SuppressEngineLighting(true)
		render.MaterialOverride(HOT)

		if (bWalls) then
			-- behind the walls: faint, flickering a little
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
		end

		-- seen: bright
		for _, entity in ipairs(list) do
			local hurt = entity:IsPlayer() and entity:Health() / math.max(entity:GetMaxHealth(), 1) or 1

			render.SetColorModulation(r, g * (0.75 + 0.25 * hurt), b)
			render.SetBlend(1)
			entity:DrawModel()
		end

		render.MaterialOverride()
		render.SetColorModulation(1, 1, 1)
		render.SetBlend(1)
		render.SuppressEngineLighting(false)
	cam.End3D()
end

hook.Add("RenderScreenspaceEffects", "nwVision", function()
	if (mode == "thermal") then
		DrawColorModify(COLD)
		DrawSharpen(0.6, 1.2)
		Bodies(Warm(), 1, 0.7, 0.18, true)
		DrawBloom(0.55, 1.8, 6, 6, 2, 1.2, 1, 0.85, 0.6)
	elseif (mode == "nvg") then
		DrawColorModify(GREEN)
		DrawBloom(0.35, 2.2, 8, 8, 2, 1.4, 0.5, 1, 0.5)
		Bodies(Warm(), 0.55, 1, 0.55, true)
	end
end)

-- the picture: grain, scan lines, the frame; outside the Alliance HUD also the state
surface.CreateFont("nwThermal", {font = "JetBrains Mono ExtraBold", size = math.max(12, math.Round(ScrH() * 0.016)),
	weight = 800, extended = true, antialias = true})

local VIGNETTE = Material("network2/menu/vignette.png", "smooth")

hook.Add("HUDPaint", "nwVisionSight", function()
	if (!mode) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local t = RealTime()
	local nvg = mode == "nvg"
	local on = math.Clamp((t - switched) / 0.35, 0, 1)

	if (on < 1) then
		surface.SetDrawColor(nvg and 170 or 220, 255, nvg and 170 or 255, 180 * (1 - on))
		surface.DrawRect(0, 0, sw, sh)
	end

	surface.SetDrawColor(0, 0, 0, nvg and 26 or 40)

	for y = (t * 40) % 4, sh, 4 do
		surface.DrawRect(0, y, sw, 1)
	end

	for _ = 1, nvg and 320 or 160 do
		surface.SetDrawColor(nvg and 190 or 255, 255, nvg and 190 or 255, math.random(6, nvg and 34 or 22))
		surface.DrawRect(math.random(0, sw), math.random(0, sh), 2, 2)
	end

	-- the goggles: the dark round edge of the tubes
	if (nvg) then
		surface.SetMaterial(VIGNETTE)
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawTexturedRect(0, 0, sw, sh)
		surface.DrawTexturedRect(0, 0, sw, sh)
	end

	local m, c = sh * 0.06, sh * 0.05

	surface.SetDrawColor(nvg and 170 or 220, nvg and 255 or 236, nvg and 170 or 246, 140)

	for _, corner in ipairs({{m, m, 1, 1}, {sw - m, m, -1, 1}, {m, sh - m, 1, -1}, {sw - m, sh - m, -1, -1}}) do
		surface.DrawRect(corner[1] - (corner[3] < 0 and c or 0), corner[2] - (corner[4] < 0 and 2 or 0), c, 2)
		surface.DrawRect(corner[1] - (corner[3] < 0 and 2 or 0), corner[2] - (corner[4] < 0 and c or 0), 2, c)
	end

	surface.DrawRect(sw / 2 - 12, sh / 2, 8, 1)
	surface.DrawRect(sw / 2 + 5, sh / 2, 8, 1)
	surface.DrawRect(sw / 2, sh / 2 - 12, 1, 8)
	surface.DrawRect(sw / 2, sh / 2 + 5, 1, 8)

	-- the state: in the HUD of the Alliance when it is on (VI.DrawHud), here otherwise
	if (mode == "thermal" and NW.combineHud and NW.combineHud.Active and NW.combineHud.Active()) then
		return
	end

	local level = heat / WORK
	local tint = nvg and Color(180, 255, 180, 210) or Color(230, 240, 248, 200)
	local bw = sw * 0.14

	draw.SimpleText(VI.modes[mode].name .. " :: " .. math.ceil(WORK - heat) .. " С", "nwThermal", m + c * 0.2, m + c * 0.6,
		tint)
	surface.SetDrawColor(0, 0, 0, 140)
	surface.DrawRect(m + c * 0.2, m + c * 1.3, bw, 4)
	surface.SetDrawColor(255, 200 - 140 * level, 90 - 60 * level, 220)
	surface.DrawRect(m + c * 0.2, m + c * 1.3, bw * level, 4)
	draw.SimpleText(string.format("ЦЕЛЕЙ :: %d", #Warm()), "nwThermal", sw - m - c * 0.2, m + c * 0.6,
		Color(255, 170, 90, 210), TEXT_ALIGN_RIGHT)
end)

-- in the HUD of the Alliance (cl_combinehud.lua): the thermal - working, its heat; overheated - the
-- cooling; nothing when it is cold and off
function VI.DrawHud(x, y, Text, Bar, color)
	local level, cooling = VI.Heat()
	local sh = ScrH()

	if (mode != "thermal" and level <= 0 and cooling <= 0) then
		return y
	end

	y = y + sh * 0.01

	local state

	if (mode == "thermal") then
		state = "ТЕПЛОВИЗОР :: АКТИВЕН :: " .. math.ceil(WORK - heat) .. " С :: ЦЕЛЕЙ " .. #Warm()
	elseif (cooling > 0) then
		state = "ТЕПЛОВИЗОР :: ПЕРЕГРЕВ :: " .. math.ceil(cooling) .. " С"
	else
		state = "ТЕПЛОВИЗОР :: ОСТЫВАЕТ"
	end

	local hot = Color(255, 200 - 130 * level, 90 - 60 * level, 230)
	local blink = cooling > 0 and math.floor(RealTime() * 3) % 2 == 0

	Text(state, "nwCmbSmall", x, y, blink and Color(255, 255, 255, 230) or (mode == "thermal" and color or hot),
		TEXT_ALIGN_LEFT, false)
	y = y + sh * 0.022
	Bar(x, y, ScrW() * 0.2, 2, ColorAlpha(color, 70))
	Bar(x, y, ScrW() * 0.2 * level, 2, hot)

	return y + sh * 0.012
end
