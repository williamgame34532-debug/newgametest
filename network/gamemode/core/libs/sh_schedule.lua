NETWORK.schedule = NETWORK.schedule or {}

function NETWORK.schedule.IsCurfew()
	local hours = NETWORK.time.GetHours()

	return hours >= 18 or hours < 6
end

function NETWORK.schedule.IsRationTime()
	local hours = NETWORK.time.GetHours()

	return hours >= 6 and hours < 9
end

function NETWORK.schedule.IsFactoryShift()
	local hours = NETWORK.time.GetHours()

	return hours >= 11 and hours < 16.5
end

NETWORK.schedule.periods = {
	{id = "rations", from = 6, to = 9, name = "periodRations", icon = "restaurant"},
	{id = "free", from = 9, to = 11, name = "periodFree", icon = "wb_sunny"},
	{id = "factory", from = 11, to = 16.5, name = "periodFactory", icon = "factory"},
	{id = "free2", from = 16.5, to = 18, name = "periodFree", icon = "wb_sunny"},
	{id = "curfew", from = 18, to = 30, name = "periodCurfew", icon = "bedtime"}
}

local function Normalise(hours)
	if (hours == nil) then
		hours = NETWORK.time.GetHours()
	end

	hours = hours % 24

	if (hours < NETWORK.schedule.periods[1].from) then
		hours = hours + 24
	end

	return hours
end

function NETWORK.schedule.GetCurrent(hours)
	local periods = NETWORK.schedule.periods

	hours = Normalise(hours)

	for _, period in ipairs(periods) do
		if (hours >= period.from and hours < period.to) then
			return period
		end
	end

	return periods[#periods]
end

function NETWORK.schedule.GetNext(hours)
	local periods = NETWORK.schedule.periods

	hours = Normalise(hours)

	for index, period in ipairs(periods) do
		if (hours >= period.from and hours < period.to) then
			local nextPeriod = periods[index + 1]

			if (nextPeriod) then
				return nextPeriod, nextPeriod.from - hours
			end

			return periods[1], periods[1].from + 24 - hours
		end
	end

	return periods[1], math.max(periods[1].from + 24 - hours, 0)
end

NETWORK.chat.Register("cityannounce", {
	format = "chatCityAnnounce",
	color = Color(232, 74, 66),
	bSolidColor = true,
	bNoName = true,
	font = "nwChat",
	order = 95
})

if (CLIENT) then
	net.Receive("nwScheduleAnnounce", function()
		surface.PlaySound("framework/event/reminder.mp3")
	end)
end
