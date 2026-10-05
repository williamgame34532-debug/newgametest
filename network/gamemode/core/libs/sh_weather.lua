NETWORK.weather = NETWORK.weather or {}

NETWORK.weather.types = {
	{id = "clear", name = "weatherClear", fog = 0, rain = 0, wind = 0.1},
	{id = "overcast", name = "weatherOvercast", fog = 0.25, rain = 0, wind = 0.3},
	{id = "fog", name = "weatherFog", fog = 1, rain = 0, wind = 0.15},
	{id = "rain", name = "weatherRain", fog = 0.35, rain = 0.6, wind = 0.5},
	{id = "storm", name = "weatherStorm", fog = 0.5, rain = 1, wind = 1}
}

NETWORK.weather.transition = 25
NETWORK.weather.minLength = 480
NETWORK.weather.maxLength = 1500

function NETWORK.weather.Get(id)
	for _, entry in ipairs(NETWORK.weather.types) do
		if (entry.id == id) then
			return entry
		end
	end

	return NETWORK.weather.types[1]
end

function NETWORK.weather.GetCurrent()
	return NETWORK.weather.Get(GetGlobalString("nwWeather", "clear"))
end

function NETWORK.weather.GetBlend()
	local stamp = GetGlobalFloat("nwWeatherStamp", 0)

	if (stamp <= 0) then
		return 1
	end

	return math.Clamp((CurTime() - stamp) / NETWORK.weather.transition, 0, 1)
end

function NETWORK.weather.GetPrevious()
	return NETWORK.weather.Get(GetGlobalString("nwWeatherLast", "clear"))
end

function NETWORK.weather.GetValue(key)
	local blend = NETWORK.weather.GetBlend()
	local from = NETWORK.weather.GetPrevious()[key] or 0
	local to = NETWORK.weather.GetCurrent()[key] or 0

	return Lerp(blend, from, to)
end

NETWORK.weather.stormfox = {
	clear = "Clear",
	overcast = "Clear",
	fog = "Fog",
	rain = "Rain",
	storm = "Rain"
}

function NETWORK.weather.GetStormFoxName()
	return NETWORK.weather.stormfox[GetGlobalString("nwWeather", "clear")] or
		"Clear"
end

function NETWORK.weather.HasStormFox()
	return StormFox2 ~= nil and StormFox2.Weather ~= nil
end

if (SERVER) then
	function NETWORK.weather.Set(id, bSilent)
		local entry = NETWORK.weather.Get(id)

		SetGlobalString("nwWeatherLast", GetGlobalString("nwWeather", "clear"))
		SetGlobalString("nwWeather", entry.id)
		SetGlobalFloat("nwWeatherStamp", CurTime())

		if (NETWORK.weather.HasStormFox()) then
			StormFox2.Weather.Set(NETWORK.weather.stormfox[entry.id] or "Clear")
		end

		hook.Run("NetworkWeatherChanged", entry.id)

		if (!bSilent) then
			NETWORK.log.Add("weather", "Погода: " .. tostring(entry.id))
		end

		return entry
	end

	NETWORK.weather.rollBlacklist = {storm = true}

	function NETWORK.weather.Roll()
		local pool = {}
		local current = GetGlobalString("nwWeather", "clear")

		for _, entry in ipairs(NETWORK.weather.types) do
			if (entry.id != current and
				!NETWORK.weather.rollBlacklist[entry.id]) then
				local weight = entry.id == "clear" and 4 or
					(entry.id == "overcast" and 3 or 2)

				for _ = 1, weight do
					pool[#pool + 1] = entry.id
				end
			end
		end

		if (#pool == 0) then
			return
		end

		NETWORK.weather.Set(pool[math.random(#pool)], true)
	end

	NETWORK.config.Register("weatherCycle", {
		name = "cfgWeatherCycle",
		description = "cfgWeatherCycleDesc",
		category = "world",
		type = "bool",
		default = true
	})

	NETWORK.config.Register("weatherStart", {
		name = "cfgWeatherStart",
		description = "cfgWeatherStartDesc",
		category = "world",
		type = "string",
		default = "clear"
	})

	NETWORK.command.Register("citysky", {
		adminOnly = true,
		description = "cmdSetweather",
		usage = "/citysky <clear|overcast|fog|rain|storm>",
		example = "/citysky rain",
		aliases = {"nwweather", "setweather"},
		OnRun = function(command, client, arguments)
			local id = string.lower(arguments[1] or "")
			local entry

			for _, data in ipairs(NETWORK.weather.types) do
				if (data.id == id) then
					entry = data
				end
			end

			if (!entry) then
				return NETWORK.chat.Notice(client, "weatherUnknown")
			end

			NETWORK.weather.Set(entry.id)
			NETWORK.weather.nextRoll = CurTime() + math.random(
				NETWORK.weather.minLength, NETWORK.weather.maxLength)

			NETWORK.chat.Notice(client, "weatherSet", L(entry.name))
		end
	})

	hook.Add("Initialize", "nwWeather", function()
		timer.Simple(5, function()
			NETWORK.weather.Set(NETWORK.config.Get("weatherStart") or "clear",
				true)
		end)
	end)

	timer.Create("nwWeatherGuard", 30, 0, function()
		if (!NETWORK.weather.HasStormFox()) then
			return
		end

		local expected = NETWORK.weather.GetStormFoxName()
		local current = StormFox2.Weather.GetCurrent and
			StormFox2.Weather.GetCurrent()

		if (istable(current)) then
			current = current.Name or current.name
		end

		if (isstring(current) and current != expected) then
			StormFox2.Weather.Set(expected)
		end
	end)

	timer.Create("nwWeatherCycle", 60, 0, function()
		if (NETWORK.config.Get("weatherCycle") == false) then
			return
		end

		if ((NETWORK.weather.nextRoll or 0) > CurTime()) then
			return
		end

		NETWORK.weather.nextRoll = CurTime() + math.random(
			NETWORK.weather.minLength, NETWORK.weather.maxLength)

		NETWORK.weather.Roll()
	end)
end
