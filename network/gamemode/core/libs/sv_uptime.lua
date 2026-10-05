NETWORK.uptime = NETWORK.uptime or {}

local U = NETWORK.uptime

NETWORK.config.RegisterCategory("server", "cfgCatServer", 37)

NETWORK.config.Register("restartAfter", {
	name = "cfgRestartAfter",
	description = "cfgRestartAfterDesc",
	category = "server",
	default = 120,
	min = 0,
	max = 1440,
	decimals = 0
})

NETWORK.config.Register("restartMode", {
	name = "cfgRestartMode",
	description = "cfgRestartModeDesc",
	category = "server",
	type = "choice",
	default = "quit",
	options = {
		{value = "quit", label = "restartModeQuit"},
		{value = "map", label = "restartModeMap"}
	}
})

U.bootTime = U.bootTime or SysTime()
U.restartAt = nil
U.bArmed = false

local warnings = {1800, 600, 300, 60, 30, 10}

local function Broadcast(key, ...)
	local text = L(key, ...)

	for _, client in ipairs(player.GetAll()) do
		NETWORK.chat.Notice(client, text)
		NETWORK.notice.Send(client, key, "warn", ...)
	end
end

function U.GetTimeLeft()
	if (!U.restartAt) then
		return nil
	end

	return math.max(U.restartAt - SysTime(), 0)
end

function U.DoRestart()
	U.restartAt = nil
	U.bArmed = false

	local mode = NETWORK.config.Get("restartMode")

	for _, client in ipairs(player.GetAll()) do
		client:Kick(L("restartKick"))
	end

	timer.Simple(2, function()
		if (mode == "map") then
			game.ConsoleCommand("changelevel " .. game.GetMap() .. "\n")
		else
			game.ConsoleCommand("quit\n")
		end
	end)
end

function U.TryRestart()
	Broadcast("restartNow")

	timer.Simple(3, U.DoRestart)
end

function U.Arm(seconds)
	U.Disarm()

	if (!seconds or seconds <= 0) then
		return
	end

	U.restartAt = SysTime() + seconds
	U.bArmed = true

	for _, before in ipairs(warnings) do
		local at = seconds - before

		if (at > 0) then
			timer.Create("nwRestartWarn" .. before, at, 1, function()
				Broadcast("restartIn", before >= 60 and
					L("restartMinutes", math.floor(before / 60)) or
					L("restartSeconds", before))
			end)
		end
	end

	timer.Create("nwRestartDue", seconds, 1, function()
		U.dueSince = nil
		U.bWaitAnnounced = false

		U.TryRestart()
	end)
end

function U.Disarm()
	for _, before in ipairs(warnings) do
		timer.Remove("nwRestartWarn" .. before)
	end

	timer.Remove("nwRestartDue")

	U.restartAt = nil
	U.bArmed = false
end

hook.Add("InitPostEntity", "nwUptime", function()
	U.bootTime = SysTime()

	timer.Simple(5, function()
		local minutes = NETWORK.config.Get("restartAfter") or 0

		if (minutes > 0) then
			U.Arm(minutes * 60 - (SysTime() - U.bootTime))
		end
	end)
end)

hook.Add("NetworkConfigChanged", "nwUptime", function(id, value)
	if (id != "restartAfter") then
		return
	end

	local minutes = tonumber(value) or 0

	if (minutes <= 0) then
		U.Disarm()

		return
	end

	U.Arm(math.max(minutes * 60 - (SysTime() - U.bootTime), 30))
end)

NETWORK.command.Register("restartin", {
	adminOnly = true,
	description = "cmdRestartIn",
	usage = "/restartin <минут>",
	OnRun = function(command, client, arguments)
		local minutes = tonumber(arguments[1])

		if (!minutes or minutes <= 0) then
			return NETWORK.notice.Send(client, "restartUsage", "warn")
		end

		U.Arm(minutes * 60)

		NETWORK.notice.Send(client, "restartArmed", "good", math.floor(minutes))
	end
})

NETWORK.command.Register("restartcancel", {
	adminOnly = true,
	description = "cmdRestartCancel",
	OnRun = function(command, client)
		if (!U.bArmed) then
			return NETWORK.notice.Send(client, "restartNone", "warn")
		end

		U.Disarm()

		NETWORK.notice.Send(client, "restartCancelled", "good")
	end
})

NETWORK.command.Register("restartnow", {
	adminOnly = true,
	description = "cmdRestartNow",
	OnRun = function(command, client)
		NETWORK.notice.Send(client, "restartGoing", "good")

		U.Arm(15)
	end
})

NETWORK.command.Register("restart", {
	adminOnly = true,
	description = "cmdRestartNow",
	OnRun = function(command, client)
		NETWORK.notice.Send(client, "restartGoing", "good")

		U.Arm(15)
	end
})

NETWORK.command.Register("restartstatus", {
	adminOnly = true,
	description = "cmdRestartStatus",
	OnRun = function(command, client)
		local left = U.GetTimeLeft()
		local uptime = SysTime() - U.bootTime

		NETWORK.chat.Notice(client, L("restartStatusUptime",
			math.floor(uptime / 3600), math.floor(uptime % 3600 / 60)))

		if (left) then
			NETWORK.chat.Notice(client, L("restartStatusLeft",
				math.floor(left / 60), math.floor(left % 60)))
		else
			NETWORK.chat.Notice(client, L("restartStatusOff"))
		end

		NETWORK.chat.Notice(client, L("restartStatusMode",
			NETWORK.config.Get("restartMode") == "map" and L("restartModeMap") or
			L("restartModeQuit")))
	end
})
