-- The thermal vision of the Alliance: the key "Тепловизор" (N). The world goes cold - a dark blue-grey
-- with the detail kept, the living (players, NPCs) glow white-hot to orange, the hottest in the
-- middle of the body; a fine grain and scan lines over it, the frame of the sight and the state at
-- the top. Only for the Alliance (the visor of the mask); it switches off on death, falling, taking
-- off the uniform. Not through walls.

local active = false
local switched = 0

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

local function Allowed(client)
	return IsValid(client) and client:Alive() and NW.zones.IsAlliance(client) and
		!(NW.Incapable and NW.Incapable(client))
end

local function Set(bOn)
	if (active == bOn) then
		return
	end

	active = bOn
	switched = RealTime()
	surface.PlaySound(bOn and "buttons/combine_button1.wav" or "buttons/combine_button2.wav")
end

hook.Add("NWKey", "nwThermal", function(id)
	if (id != "thermal") then
		return
	end

	if (!Allowed(LocalPlayer())) then
		return NW.notify.Add("Тепловизор — в маске Альянса")
	end

	Set(!active)
end)

hook.Add("Think", "nwThermal", function()
	if (active and !Allowed(LocalPlayer())) then
		Set(false)
	end
end)

function NW.ThermalOn()
	return active
end

-- the bodies that give heat
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

hook.Add("RenderScreenspaceEffects", "nwThermal", function()
	if (!active) then
		return
	end

	-- the cold world
	DrawColorModify(COLD)
	DrawSharpen(0.6, 1.2)

	-- the heat: drawn over at the depth of the world (the walls still hide them)
	cam.Start3D()
		render.SuppressEngineLighting(true)
		render.MaterialOverride(HOT)

		for _, entity in ipairs(Warm()) do
			local hurt = entity:IsPlayer() and entity:Health() / math.max(entity:GetMaxHealth(), 1) or 1

			-- the outer warmth: orange
			render.SetColorModulation(1, 0.55 + 0.2 * hurt, 0.18)
			render.SetBlend(1)
			entity:DrawModel()
		end

		render.MaterialOverride()
		render.SetColorModulation(1, 1, 1)
		render.SuppressEngineLighting(false)
	cam.End3D()

	-- the hot core glows over: a little bloom
	DrawBloom(0.55, 1.8, 6, 6, 2, 1.2, 1, 0.85, 0.6)
end)

-- the sight: grain, scan lines, the frame, the state
surface.CreateFont("nwThermal", {font = "JetBrains Mono ExtraBold", size = math.max(12, math.Round(ScrH() * 0.016)),
	weight = 800, extended = true, antialias = true})

hook.Add("HUDPaint", "nwThermalSight", function()
	if (!active) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local t = RealTime()

	-- switching on: a flash that fades
	local on = math.Clamp((t - switched) / 0.35, 0, 1)

	if (on < 1) then
		surface.SetDrawColor(220, 240, 255, 180 * (1 - on))
		surface.DrawRect(0, 0, sw, sh)
	end

	-- scan lines
	surface.SetDrawColor(0, 0, 0, 40)

	for y = (t * 40) % 4, sh, 4 do
		surface.DrawRect(0, y, sw, 1)
	end

	-- grain
	for _ = 1, 160 do
		local gx, gy = math.random(0, sw), math.random(0, sh)

		surface.SetDrawColor(255, 255, 255, math.random(6, 22))
		surface.DrawRect(gx, gy, 2, 2)
	end

	-- the frame of the sight
	local m = sh * 0.06
	local c = sh * 0.05

	surface.SetDrawColor(220, 236, 246, 140)

	for _, corner in ipairs({{m, m, 1, 1}, {sw - m, m, -1, 1}, {m, sh - m, 1, -1}, {sw - m, sh - m, -1, -1}}) do
		surface.DrawRect(corner[1] - (corner[3] < 0 and c or 0), corner[2] - (corner[4] < 0 and 2 or 0), c, 2)
		surface.DrawRect(corner[1] - (corner[3] < 0 and 2 or 0), corner[2] - (corner[4] < 0 and c or 0), 2, c)
	end

	surface.DrawRect(sw / 2 - 12, sh / 2, 8, 1)
	surface.DrawRect(sw / 2 + 5, sh / 2, 8, 1)
	surface.DrawRect(sw / 2, sh / 2 - 12, 1, 8)
	surface.DrawRect(sw / 2, sh / 2 + 5, 1, 8)

	draw.SimpleText("ТЕПЛОВИЗОР :: АКТИВЕН", "nwThermal", m + c * 0.2, m + c * 0.6, Color(230, 240, 248, 200))
	draw.SimpleText(string.format("ЦЕЛЕЙ :: %d", #Warm()), "nwThermal", sw - m - c * 0.2, m + c * 0.6,
		Color(255, 170, 90, 210), TEXT_ALIGN_RIGHT)
end)
