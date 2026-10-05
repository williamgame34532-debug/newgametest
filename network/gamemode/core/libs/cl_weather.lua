local rainMaterial = Material("effects/fleck_cement2")
local dropCount = 220

local drops = {}
local nextThunder = 0

local function ResetDrops()
	drops = {}

	for index = 1, dropCount do
		drops[index] = {
			pos = VectorRand() * 420,
			speed = math.Rand(900, 1400),
			length = math.Rand(14, 34)
		}
	end
end

ResetDrops()

function NETWORK.weather.GetDarkness()
	local hours = NETWORK.time.GetHours()
	local dayStart = NETWORK.time.dayStart or 6
	local nightStart = NETWORK.time.nightStart or 21

	if (hours >= dayStart + 2 and hours <= nightStart - 2) then
		return 0
	end

	if (hours > dayStart and hours < dayStart + 2) then
		return 1 - (hours - dayStart) / 2
	end

	if (hours > nightStart - 2 and hours < nightStart) then
		return (hours - (nightStart - 2)) / 2
	end

	return 1
end

local function IsOutside(position)
	local trace = util.TraceLine({
		start = position,
		endpos = position + Vector(0, 0, 4096),
		mask = MASK_SOLID_BRUSHONLY
	})

	return !trace.Hit or trace.HitSky
end

hook.Add("Think", "nwWeatherAmbient", function()
	if (NETWORK.weather.HasStormFox()) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local rain = NETWORK.weather.GetValue("rain")

	if (rain < 0.15) then
		if (NETWORK.weather.loop) then
			NETWORK.weather.loop:Stop()

			NETWORK.weather.loop = nil
		end

		return
	end

	if (!IsOutside(client:EyePos())) then
		if (NETWORK.weather.loop) then
			NETWORK.weather.loop:ChangeVolume(0.15, 1)
		end

		return
	end

	if (!NETWORK.weather.loop) then
		NETWORK.weather.loop = CreateSound(client,
			"ambient/weather/rain_gutter_loop1.wav")

		NETWORK.weather.loop:PlayEx(0.4, 100)
	end

	NETWORK.weather.loop:ChangeVolume(0.25 + rain * 0.55, 1)

	if (rain > 0.85 and CurTime() > nextThunder) then
		nextThunder = CurTime() + math.random(18, 55)

		client:EmitSound("ambient/levels/canals/dam_water_loop1.wav", 75,
			math.random(90, 110), 0.35)
	end
end)

hook.Add("PostDrawTranslucentRenderables", "nwWeatherRain", function(bDepth, bSky)
	if (bSky or NETWORK.weather.HasStormFox()) then
		return
	end

	local rain = NETWORK.weather.GetValue("rain")

	if (rain < 0.1) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !IsOutside(client:EyePos())) then
		return
	end

	local origin = client:EyePos()
	local frame = math.min(FrameTime(), 0.1)
	local alpha = math.Clamp(rain, 0, 1) * 150
	local wind = NETWORK.weather.GetValue("wind")

	render.SetMaterial(rainMaterial)

	for index = 1, math.floor(dropCount * rain) do
		local drop = drops[index]

		drop.pos.z = drop.pos.z - drop.speed * frame
		drop.pos.x = drop.pos.x + wind * 60 * frame

		if (drop.pos.z < -260 or drop.pos:Length() > 620) then
			drop.pos = Vector(math.Rand(-380, 380), math.Rand(-380, 380),
				math.Rand(180, 420))
		end

		local position = origin + drop.pos

		render.DrawBeam(position, position - Vector(wind * 6, 0, drop.length),
			1.6, 0, 1, Color(190, 210, 235, alpha))
	end
end)

NETWORK.weather.indoor = NETWORK.weather.indoor or 0

hook.Add("Think", "nwWeatherIndoor", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	if (NETWORK.util.Throttle("weather.indoor", 0.25)) then
		NETWORK.weather.bIndoor = !IsOutside(client:EyePos())
	end

	NETWORK.weather.indoor = math.Approach(NETWORK.weather.indoor,
		NETWORK.weather.bIndoor and 1 or 0, FrameTime())
end)

function NETWORK.weather.GetFog()
	return NETWORK.weather.GetValue("fog") *
		(1 - (NETWORK.weather.indoor or 0))
end

hook.Add("SetupWorldFog", "nwWeatherFog", function()
	if (NETWORK.weather.HasStormFox()) then
		return
	end

	local fog = NETWORK.weather.GetFog()

	if (fog < 0.02) then
		return
	end

	local dark = NETWORK.weather.GetDarkness()

	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(Lerp(fog, 4200, 900))
	render.FogEnd(Lerp(fog, 14000, 4200))

	render.FogMaxDensity(Lerp(fog, 0.08, Lerp(dark, 0.40, 0.55)))
	render.FogColor(Lerp(dark, 132, 14), Lerp(dark, 140, 17),
		Lerp(dark, 150, 22))

	return true
end)

hook.Add("SetupSkyboxFog", "nwWeatherFog", function(scale)
	if (NETWORK.weather.HasStormFox()) then
		return
	end

	local fog = NETWORK.weather.GetValue("fog")

	if (fog < 0.02) then
		return
	end

	local dark = NETWORK.weather.GetDarkness()

	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(Lerp(fog, 4200, 900) * scale)
	render.FogEnd(Lerp(fog, 14000, 4200) * scale)
	render.FogMaxDensity(Lerp(fog, 0.08, Lerp(dark, 0.40, 0.55)))
	render.FogColor(Lerp(dark, 132, 14), Lerp(dark, 140, 17),
		Lerp(dark, 150, 22))

	return true
end)

hook.Add("RenderScreenspaceEffects", "nwWeatherTone", function()
	if (NETWORK.weather.HasStormFox()) then
		return
	end

	local dark = NETWORK.weather.GetDarkness()
	local rain = NETWORK.weather.GetValue("rain")

	if (dark < 0.02 and rain < 0.1) then
		return
	end

	DrawColorModify({
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = dark * 0.015,
		["$pp_colour_brightness"] = -dark * 0.06,
		["$pp_colour_contrast"] = 1 - rain * 0.03,
		["$pp_colour_colour"] = 1 - dark * 0.25 - rain * 0.06,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0
	})
end)
