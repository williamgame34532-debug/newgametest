NETWORK.schedule = NETWORK.schedule or {}

NETWORK.schedule.curfewStart = 18
NETWORK.schedule.curfewEnd = 6

-- Уровень тревоги (/alert) общий для сервера и клиента, поэтому HUD видит
-- и досрочный комендантский час, а не только обычный 18:00–06:00.
function NETWORK.schedule.GetAlertLevel()
	return NETWORK.alert and NETWORK.alert.GetLevel and NETWORK.alert.GetLevel() or "green"
end

function NETWORK.schedule.GetCurfewStart()
	return NETWORK.schedule.GetAlertLevel() == "yellow" and 16 or NETWORK.schedule.curfewStart
end

function NETWORK.schedule.IsCurfew()
	if (NETWORK.schedule.GetAlertLevel() == "red") then
		return true
	end

	local hours = NETWORK.time.GetHours()

	return hours >= NETWORK.schedule.GetCurfewStart() or hours < NETWORK.schedule.curfewEnd
end

-- Сколько игровых часов осталось до момента target (0–24).
function NETWORK.schedule.HoursUntil(target, hours)
	hours = hours or NETWORK.time.GetHours()

	return (target - hours) % 24
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
