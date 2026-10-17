-- The weather, seen and heard (sh_weather.lua). Everything follows the state softly (about half a
-- minute from one weather to the next).
--   where the sky is   a grid of points around the player (every half a second) asks the sky above:
--                      the rain and the snow fall only there, so not indoors or under roofs
--   rain               streaks falling with the wind, little splashes where they land
--   snow               flakes drifting and swaying
--   fog                the fog of the world and of the skybox (colour, start, end, density)
--   the picture        darker and greyer with the clouds
--   sounds             sound/network2/weather (branding/make_weather_sounds.py): rain, downpour,
--                      wind; indoors they are quieter
--   lightning          a flash of the sky (two, sometimes), the thunder a moment after
-- Settings: nw_weather_fx (0..1 - how many particles), nw_weather 0 - no particles and no picture.

local WE = NW.weather

local enabled = CreateClientConVar("nw_weather", "1", true, false, "Погода: частицы и картинка")
local density = CreateClientConVar("nw_weather_fx", "1", true, false, "Погода: сколько частиц (0..1)")

local FLAKE = Material("particle/particle_glow_04_additive")
local DROP = "sprites/light_glow02_add"
local SNOW = "particle/particle_glow_04_additive"

-- the blended state
local now = {rain = 0, snow = 0, wind = 0, dark = 0, haze = 0, fogStart = 2500, fogEnd = 14000, fogDensity = 0.1,
	fogR = 150, fogG = 160, fogB = 170}
local outdoors = 1

hook.Add("Think", "nwWeatherBlend", function()
	local kind = WE.kinds[WE.Current()]
	local step = math.Clamp(FrameTime() / 25, 0, 1)

	now.rain = Lerp(step, now.rain, kind.rain)
	now.snow = Lerp(step, now.snow, kind.snow)
	now.wind = Lerp(step, now.wind, kind.wind)
	now.dark = Lerp(step, now.dark, kind.dark)
	now.haze = Lerp(step, now.haze, kind.haze)
	now.fogStart = Lerp(step, now.fogStart, kind.fog.start)
	now.fogEnd = Lerp(step, now.fogEnd, kind.fog.finish)
	now.fogDensity = Lerp(step, now.fogDensity, kind.fog.density)
	now.fogR = Lerp(step, now.fogR, kind.fog.color[1])
	now.fogG = Lerp(step, now.fogG, kind.fog.color[2])
	now.fogB = Lerp(step, now.fogB, kind.fog.color[3])
end)

-- the wind: one direction for the whole city, turning slowly
local function Wind()
	local angle = CurTime() * 0.01

	return Vector(math.cos(angle), math.sin(angle), 0) * now.wind
end

-- ------------------------------------------------------------ the open sky --
local grid = {}
local GRID, SPAN = 8, 1000

local function Sky(pos)
	local up = util.TraceLine({start = pos, endpos = pos + Vector(0, 0, 4096), mask = MASK_SOLID_BRUSHONLY})

	return up.HitSky or !up.Hit, up
end

timer.Create("nwWeatherGrid", 0.5, 0, function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local eye = client:EyePos()
	local open = Sky(eye)

	outdoors = open and 1 or 0
	grid = {}

	if (now.rain < 0.02 and now.snow < 0.02) then
		return
	end

	local cell = SPAN * 2 / GRID

	for i = 0, GRID - 1 do
		for j = 0, GRID - 1 do
			local pos = Vector(eye.x - SPAN + (i + 0.5) * cell, eye.y - SPAN + (j + 0.5) * cell, eye.z + 40)
			local sky = Sky(pos)

			if (sky) then
				local down = util.TraceLine({start = pos + Vector(0, 0, 200), endpos = pos - Vector(0, 0, 2000),
					mask = MASK_SOLID_BRUSHONLY})

				grid[#grid + 1] = {x = pos.x, y = pos.y, ground = down.HitPos.z, size = cell}
			end
		end
	end
end)

-- -------------------------------------------------------------- particles --
local emitter

hook.Add("Think", "nwWeatherParticles", function()
	if (!enabled:GetBool() or #grid == 0 or (now.rain < 0.02 and now.snow < 0.02)) then
		return
	end

	local eye = EyePos()

	if (!emitter or !emitter:IsValid()) then
		emitter = ParticleEmitter(eye)
	end

	emitter:SetPos(eye)

	local wind = Wind()
	local amount = density:GetFloat()
	local frame = math.Clamp(FrameTime(), 0, 0.05)

	-- rain
	local drops = math.floor(now.rain * 900 * amount * frame + math.random())

	for _ = 1, drops do
		local cell = grid[math.random(#grid)]
		local pos = Vector(cell.x + math.Rand(-0.5, 0.5) * cell.size, cell.y + math.Rand(-0.5, 0.5) * cell.size,
			math.min(eye.z + math.Rand(150, 420), cell.ground + 800))
		local fall = 1100 + now.rain * 500
		local velocity = Vector(wind.x * 260, wind.y * 260, -fall)
		local life = math.max(0.1, (pos.z - cell.ground) / fall)
		local drop = emitter:Add(DROP, pos)

		if (drop) then
			drop:SetVelocity(velocity)
			drop:SetDieTime(life)
			drop:SetStartAlpha(70 + 50 * now.rain)
			drop:SetEndAlpha(70)
			drop:SetStartSize(1.1)
			drop:SetEndSize(1.1)
			drop:SetStartLength(36 + 30 * now.rain)
			drop:SetEndLength(36 + 30 * now.rain)
			drop:SetColor(175, 190, 205)
		end

		-- a splash where it lands, now and then
		if (math.random() < 0.25) then
			local splash = emitter:Add(SNOW, Vector(pos.x + velocity.x * life, pos.y + velocity.y * life, cell.ground + 1))

			if (splash) then
				splash:SetDieTime(0.18)
				splash:SetStartAlpha(0)
				splash:SetEndAlpha(0)
				splash:SetStartSize(0.5)
				splash:SetEndSize(5)
				splash:SetColor(200, 210, 220)
				splash:SetNextThink(CurTime() + life)
				splash:SetThinkFunction(function(self)
					self:SetStartAlpha(90)
					self:SetEndAlpha(0)
					self:SetLifeTime(0)
				end)
			end
		end
	end

	-- snow
	local flakes = math.floor(now.snow * 260 * amount * frame + math.random())

	for _ = 1, flakes do
		local cell = grid[math.random(#grid)]
		local pos = Vector(cell.x + math.Rand(-0.5, 0.5) * cell.size, cell.y + math.Rand(-0.5, 0.5) * cell.size,
			math.min(eye.z + math.Rand(100, 380), cell.ground + 600))
		local fall = math.Rand(50, 95)
		local flake = emitter:Add(SNOW, pos)

		if (flake) then
			flake:SetVelocity(Vector(wind.x * 90 + math.Rand(-15, 15), wind.y * 90 + math.Rand(-15, 15), -fall))
			flake:SetDieTime(math.max(0.5, (pos.z - cell.ground) / fall))
			flake:SetStartAlpha(220)
			flake:SetEndAlpha(200)
			flake:SetStartSize(math.Rand(1.2, 2.6))
			flake:SetEndSize(math.Rand(1.2, 2.6))
			flake:SetRoll(math.Rand(0, 360))
			flake:SetRollDelta(math.Rand(-2, 2))
			flake:SetAirResistance(10)
			flake:SetColor(240, 244, 250)
		end
	end
end)

-- -------------------------------------------------------------------- fog --
local function Fog(scale)
	if (!enabled:GetBool()) then
		return
	end

	scale = scale or 1

	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(now.fogStart * scale)
	render.FogEnd(now.fogEnd * scale)
	render.FogMaxDensity(now.fogDensity)
	render.FogColor(now.fogR, now.fogG, now.fogB)

	return true
end

hook.Add("SetupWorldFog", "nwWeather", function()
	return Fog(1)
end)

hook.Add("SetupSkyboxFog", "nwWeather", function(scale)
	return Fog(scale)
end)

-- ------------------------------------------------------------ the picture --
local flash = 0

hook.Add("RenderScreenspaceEffects", "nwWeather", function()
	if (!enabled:GetBool()) then
		return
	end

	local dark = now.dark * (0.55 + 0.45 * outdoors)

	DrawColorModify({
		["$pp_colour_addr"] = flash * 0.25,
		["$pp_colour_addg"] = flash * 0.27,
		["$pp_colour_addb"] = flash * 0.3 + dark * 0.01,
		["$pp_colour_brightness"] = -0.06 * dark + flash * 0.15,
		["$pp_colour_contrast"] = 1 - 0.08 * dark,
		["$pp_colour_colour"] = 1 - 0.28 * dark,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0
	})

	flash = math.max(0, flash - FrameTime() * 4)
end)

-- --------------------------------------------------------------- lightning --
net.Receive("nwWeatherStrike", function()
	local which = net.ReadUInt(2)
	local delay = net.ReadFloat()

	-- the flash: once or twice
	flash = outdoors > 0 and 1 or 0.35

	if (math.random() < 0.5) then
		timer.Simple(math.Rand(0.12, 0.25), function()
			flash = outdoors > 0 and 0.8 or 0.25
		end)
	end

	timer.Simple(delay, function()
		surface.PlaySound("network2/weather/thunder_" .. math.Clamp(which, 1, 3) .. ".wav")
	end)
end)

-- ----------------------------------------------------------------- sounds --
local loops = {}

local function Loop(name, path, volume)
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local sound = loops[name]

	if (volume > 0.01) then
		if (!sound) then
			sound = CreateSound(client, path)
			sound:SetSoundLevel(0)
			sound:PlayEx(0, 100)
			loops[name] = sound
		elseif (!sound:IsPlaying()) then
			sound:PlayEx(0, 100)
		end

		sound:ChangeVolume(math.Clamp(volume, 0, 1), 0.5)
	elseif (sound) then
		sound:Stop()
		loops[name] = nil
	end
end

timer.Create("nwWeatherSounds", 0.5, 0, function()
	local client = LocalPlayer()

	if (!IsValid(client) or (NW.menu and NW.menu.active)) then
		for name, sound in pairs(loops) do
			sound:Stop()
			loops[name] = nil
		end

		return
	end

	local inside = outdoors > 0 and 1 or 0.3

	Loop("rain", "network2/weather/rain_loop.wav", math.Clamp(now.rain * 1.6, 0, 1) * (1 - math.Clamp((now.rain - 0.6) *
		2.5, 0, 1)) * 0.7 * inside)
	Loop("heavy", "network2/weather/rain_heavy_loop.wav", math.Clamp((now.rain - 0.5) * 2, 0, 1) * 0.75 * inside)
	Loop("wind", "network2/weather/wind_loop.wav", math.Clamp((now.wind - 0.2) * 1.4, 0, 1) * 0.6 * inside)
end)

-- the weather now, for the others (the civic terminal shows it)
function WE.Now()
	return now
end
