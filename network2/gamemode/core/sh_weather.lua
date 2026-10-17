-- The weather of the city. One state for everyone, changing by itself (nw_weather_auto) every
-- nw_weather_min..max seconds, by weights - the city is mostly grey and wet:
--   clear    Ясно            nothing falls, the air clear
--   cloudy   Пасмурно        a little darker, a light haze
--   rain     Дождь           rain, a haze, the picture greyer
--   storm    Гроза           a downpour, wind, lightning and thunder, dark
--   fog      Туман           a thick fog, quiet
--   snow     Снег            snow drifting with the wind, a cold haze
-- The client (cl_weather.lua) blends from one to the next over half a minute: the particles where the
-- sky is open (not indoors), the fog of the world and the skybox, the colour of the picture, the
-- sounds (rain, downpour, wind - quieter indoors), lightning flashes with the thunder after them.
-- Admins: /weather <ясно|пасмурно|дождь|гроза|туман|снег|авто>.

NW.weather = NW.weather or {}

local WE = NW.weather

WE.kinds = {
	clear = {name = "Ясно", weight = 3, rain = 0, snow = 0, wind = 0.15, dark = 0, haze = 0,
		fog = {start = 2500, finish = 14000, density = 0.15, color = {150, 160, 170}}},
	cloudy = {name = "Пасмурно", weight = 4, rain = 0, snow = 0, wind = 0.3, dark = 0.25, haze = 0.2,
		fog = {start = 1200, finish = 9000, density = 0.35, color = {120, 128, 136}}},
	rain = {name = "Дождь", weight = 4, rain = 0.55, snow = 0, wind = 0.35, dark = 0.45, haze = 0.35,
		fog = {start = 600, finish = 6000, density = 0.5, color = {96, 104, 112}}},
	storm = {name = "Гроза", weight = 2, rain = 1, snow = 0, wind = 0.9, dark = 0.75, haze = 0.45, thunder = true,
		fog = {start = 300, finish = 4500, density = 0.6, color = {70, 76, 86}}},
	fog = {name = "Туман", weight = 2, rain = 0, snow = 0, wind = 0.1, dark = 0.3, haze = 0.8,
		fog = {start = 60, finish = 1400, density = 0.92, color = {128, 134, 138}}},
	snow = {name = "Снег", weight = 1, rain = 0, snow = 1, wind = 0.5, dark = 0.2, haze = 0.45,
		fog = {start = 300, finish = 5000, density = 0.6, color = {176, 184, 192}}}
}

WE.order = {"clear", "cloudy", "rain", "storm", "fog", "snow"}

WE.aliases = {
	["ясно"] = "clear", ["пасмурно"] = "cloudy", ["дождь"] = "rain", ["гроза"] = "storm", ["туман"] = "fog",
	["снег"] = "snow"
}

function WE.Current()
	local kind = GetGlobal2String("nwWeather", "cloudy")

	return WE.kinds[kind] and kind or "cloudy"
end

if (CLIENT) then
	return
end

util.AddNetworkString("nwWeatherStrike")

local auto = CreateConVar("nw_weather_auto", "1", FCVAR_ARCHIVE, "Погода меняется сама")
local minimum = CreateConVar("nw_weather_min", "600", FCVAR_ARCHIVE, "Погода: наименьшее время одной погоды (с)")
local maximum = CreateConVar("nw_weather_max", "1500", FCVAR_ARCHIVE, "Погода: наибольшее время одной погоды (с)")

local function Pick(except)
	local total = 0

	for id, kind in pairs(WE.kinds) do
		if (id != except) then
			total = total + kind.weight
		end
	end

	local roll = math.random() * total

	for _, id in ipairs(WE.order) do
		if (id != except) then
			roll = roll - WE.kinds[id].weight

			if (roll <= 0) then
				return id
			end
		end
	end

	return "cloudy"
end

function WE.Set(kind)
	if (!WE.kinds[kind]) then
		return false
	end

	SetGlobal2String("nwWeather", kind)
	SetGlobal2Float("nwWeatherSince", CurTime())
	WE.nextChange = CurTime() + math.Rand(minimum:GetFloat(), math.max(minimum:GetFloat(), maximum:GetFloat()))
	file.CreateDir("network2")
	file.Write("network2/weather.txt", kind)

	return true
end

hook.Add("Initialize", "nwWeather", function()
	local saved = file.Read("network2/weather.txt", "DATA")

	WE.Set(WE.kinds[saved or ""] and saved or "cloudy")
end)

timer.Create("nwWeather", 5, 0, function()
	if (auto:GetBool() and CurTime() >= (WE.nextChange or 0)) then
		WE.Set(Pick(WE.Current()))
	end

	-- a storm: a strike now and then
	if (WE.kinds[WE.Current()].thunder and CurTime() >= (WE.nextStrike or 0)) then
		WE.nextStrike = CurTime() + math.Rand(10, 35)

		net.Start("nwWeatherStrike")
			net.WriteUInt(math.random(1, 3), 2)
			net.WriteFloat(math.Rand(0.4, 3.5))
		net.Broadcast()
	end
end)

NW.AddChatCommand("weather", {admin = true, run = function(client, rest)
	local word = string.lower(string.Trim(rest or ""))

	if (word == "авто" or word == "auto") then
		RunConsoleCommand("nw_weather_auto", "1")
		WE.nextChange = 0

		return NW.Notify(client, "Погода снова меняется сама")
	end

	local kind = WE.aliases[word] or word

	if (!WE.kinds[kind]) then
		return NW.Notify(client, "/weather ясно | пасмурно | дождь | гроза | туман | снег | авто")
	end

	RunConsoleCommand("nw_weather_auto", "0")
	WE.Set(kind)
	NW.Notify(client, "Погода: " .. WE.kinds[kind].name .. " (сама больше не меняется: /weather авто)")
end})
