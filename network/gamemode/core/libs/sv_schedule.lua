util.AddNetworkString("nwScheduleAnnounce")

local function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

local EVENTS = {
	[12] = {"announceCurfewEnd", "announceRationsStart"},
	[18] = {"announceRationsEnd"},
	[22] = {"announceFactoryOpen"},
	[33] = {"announceFactoryClose"},
	[34] = {"announceCurfewSoon"},
	[36] = {"announceCurfewStart"}
}

function NETWORK.schedule.Announce(key)
	net.Start("nwScheduleAnnounce")
	net.Broadcast()

	for _, client in ipairs(player.GetAll()) do
		net.Start("nwChatMessage")
			net.WriteString("cityannounce")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(L(key, client))
		net.Send(client)
	end
end

NETWORK.command.Register("announcetest", {
	description = "cmdAnnouncetest",
	usage = "/announcetest [12|17|19|20|5|8|10]",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		local hour = tonumber(arguments[1] or "")
		local keys = hour and EVENTS[math.floor(hour * 2)]

		if (!keys) then
			for _, list in pairs(EVENTS) do
				keys = list

				break
			end
		end

		for _, key in ipairs(keys) do
			NETWORK.schedule.Announce(key)
		end
	end
})

local lastHour

hook.Add("NetworkTimeSet", "nwScheduleSync", function(hours)
	lastHour = math.floor(hours * 2)
end)

timer.Create("nwSchedule", 2, 0, function()
	local bOk, hour = pcall(function()
		return math.floor(NETWORK.time.GetHours() * 2)
	end)

	if (!bOk) then
		if (!NETWORK.schedule.bWarned) then
			NETWORK.schedule.bWarned = true

			ErrorNoHalt("[Network] Диктор не может прочитать время: " ..
				tostring(hour) .. "\n")
		end

		return
	end

	if (hour == lastHour) then
		return
	end

	lastHour = lastHour or hour

	while (lastHour != hour) do
		lastHour = (lastHour + 1) % 48

		for _, key in ipairs(EVENTS[lastHour] or {}) do
			NETWORK.schedule.Announce(key)
		end
	end
end)

NETWORK.command.Register("settime", {
	description = "cmdSettime",
	usage = "/settime <час[:минуты]>",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		local raw = arguments[1] or ""
		local hour, minute = string.match(raw, "^(%d+):(%d+)$")

		hour = tonumber(hour or raw)
		minute = tonumber(minute) or 0

		if (!hour or hour < 0 or hour > 23 or minute < 0 or minute > 59) then
			return Notice(client, "settimeUsage")
		end

		NETWORK.time.Set(hour + minute / 60)

		Notice(client, "settimeDone")
		Notice(client, NETWORK.time.GetFormatted())
	end
})
