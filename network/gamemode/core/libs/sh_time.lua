NETWORK.time = NETWORK.time or {}

NETWORK.time.dayScale = 15 / 0.5
NETWORK.time.nightScale = 9 / 0.25

NETWORK.time.dayStart = 6
NETWORK.time.nightStart = 21

function NETWORK.time.IsNightHour(hours)
	hours = (tonumber(hours) or 0) % 24

	return hours < NETWORK.time.dayStart or hours >= NETWORK.time.nightStart
end

function NETWORK.time.GetScale(hours)
	return NETWORK.time.IsNightHour(hours) and NETWORK.time.nightScale or
		NETWORK.time.dayScale
end

local lastBase, lastAt

function NETWORK.time.GetHours()
	local base = GetGlobalFloat("nwTimeHours", NETWORK.config and
		NETWORK.config.Get("timeStart") or 8)

	if (SERVER) then
		return base % 24
	end

	if (lastBase != base) then
		lastBase = base
		lastAt = CurTime()
	end

	if (!lastAt) then
		return base % 24
	end

	local elapsed = math.Clamp(CurTime() - lastAt, 0, 1)

	return (base + elapsed / 3600 * NETWORK.time.GetScale(base)) % 24
end

if (SERVER) then
	local hours

	function NETWORK.time.Set(value)
		hours = value % 24

		SetGlobalFloat("nwTimeHours", hours)
		SetGlobalFloat("nwTimeStamp", CurTime())

		hook.Run("NetworkTimeSet", hours)
	end

	timer.Create("nwTimeTick", 1, 0, function()
		if (!hours) then
			hours = (NETWORK.config and NETWORK.config.Get("timeStart") or 8) % 24
		end

		hours = (hours + NETWORK.time.GetScale(hours) / 3600) % 24

		SetGlobalFloat("nwTimeHours", hours)
		SetGlobalFloat("nwTimeStamp", CurTime())
	end)
end

function NETWORK.time.GetFormatted()
	local hours = NETWORK.time.GetHours()
	local minutes = math.floor((hours % 1) * 60)

	return string.format("%02d:%02d", math.floor(hours), minutes)
end

function NETWORK.time.IsNight()
	return NETWORK.time.IsNightHour(NETWORK.time.GetHours())
end
