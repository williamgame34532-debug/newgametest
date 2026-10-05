NETWORK.diag = NETWORK.diag or {}

local samples = {}
local sampleMax = 600

local last = 0

hook.Add("Think", "nwDiagFrame", function()
	local now = SysTime()

	if (last > 0) then
		samples[#samples + 1] = now - last

		if (#samples > sampleMax) then
			table.remove(samples, 1)
		end
	end

	last = now
end)

function NETWORK.diag.Report()
	if (#samples < 2) then
		return
	end

	local total, worst = 0, 0
	local overruns = 0
	local interval = engine.TickInterval()

	for _, value in ipairs(samples) do
		total = total + value
		worst = math.max(worst, value)

		if (value > interval * 1.5) then
			overruns = overruns + 1
		end
	end

	local average = total / #samples
	local spread = 0

	for _, value in ipairs(samples) do
		spread = spread + (value - average) ^ 2
	end

	return {
		average = average,
		worst = worst,
		jitter = math.sqrt(spread / #samples),
		overruns = overruns,
		count = #samples,
		interval = interval
	}
end

NETWORK.diag.net = NETWORK.diag.net or {}

NETWORK.diag.baseStart = NETWORK.diag.baseStart or net.Start
NETWORK.diag.baseSend = NETWORK.diag.baseSend or net.Send
NETWORK.diag.baseBroadcast = NETWORK.diag.baseBroadcast or net.Broadcast

local current = ""

local function Account(bytes, receivers)
	local entry = NETWORK.diag.net[current]

	if (!entry) then
		entry = {bytes = 0, count = 0}

		NETWORK.diag.net[current] = entry
	end

	entry.bytes = entry.bytes + bytes * math.max(receivers, 1)
	entry.count = entry.count + math.max(receivers, 1)

	if (bytes > 8192) then
		NETWORK.diag.big = NETWORK.diag.big or {}

		local big = NETWORK.diag.big[current] or {count = 0, largest = 0}

		big.count = big.count + 1
		big.largest = math.max(big.largest, bytes)

		NETWORK.diag.big[current] = big
	end
end

function net.Start(name, ...)
	current = tostring(name)

	return NETWORK.diag.baseStart(name, ...)
end

function net.Send(target)
	local receivers = 1

	if (istable(target)) then
		receivers = #target
	end

	Account(net.BytesWritten() or 0, receivers)

	return NETWORK.diag.baseSend(target)
end

function net.Broadcast()
	Account(net.BytesWritten() or 0, player.GetCount())

	return NETWORK.diag.baseBroadcast()
end

NETWORK.diag.netSince = CurTime()

function NETWORK.diag.NetReport(limit)
	local list = {}
	local total = 0
	local span = math.max(CurTime() - NETWORK.diag.netSince, 1)

	for name, entry in pairs(NETWORK.diag.net) do
		list[#list + 1] = {
			name = name,
			rate = entry.bytes / span,
			count = entry.count / span
		}

		total = total + entry.bytes / span
	end

	table.sort(list, function(a, b)
		return a.rate > b.rate
	end)

	local top = {}

	for index = 1, math.min(limit or 5, #list) do
		top[#top + 1] = list[index]
	end

	return top, total, span
end

function NETWORK.diag.NetReset()
	NETWORK.diag.net = {}
	NETWORK.diag.netSince = CurTime()
end

NETWORK.diag.events = {
	"Think", "Tick", "PlayerTick", "StartCommand", "SetupMove", "Move",
	"PlayerPostThink", "EntityTakeDamage", "PlayerFootstep",
	"SetupPlayerVisibility", "PlayerCanHearPlayersVoice", "PlayerSay",
	"OnEntityCreated", "EntityRemoved", "PlayerUse", "KeyPress"
}

NETWORK.diag.profile = nil

local function StopProfile()
	local state = NETWORK.diag.profile

	if (!state) then
		return
	end

	for _, entry in ipairs(state.wrapped) do
		hook.Add(entry.event, entry.name, entry.original)
	end

	NETWORK.diag.profile = nil

	return state
end

function NETWORK.diag.StartProfile(duration, OnDone)
	StopProfile()

	local state = {
		times = {},
		wrapped = {},
		start = SysTime()
	}

	NETWORK.diag.profile = state

	for _, event in ipairs(NETWORK.diag.events) do
		local handlers = hook.GetTable()[event]

		if (!handlers) then
			continue
		end

		for name, callback in pairs(handlers) do

			if (!isstring(name) or !isfunction(callback)) then
				continue
			end

			local key = event .. " / " .. name

			state.wrapped[#state.wrapped + 1] = {
				event = event,
				name = name,
				original = callback
			}

			hook.Add(event, name, function(...)
				local began = SysTime()
				local a, b, c, d, e, f = callback(...)

				local entry = state.times[key]

				if (!entry) then
					entry = {time = 0, calls = 0}

					state.times[key] = entry
				end

				entry.time = entry.time + (SysTime() - began)
				entry.calls = entry.calls + 1

				return a, b, c, d, e, f
			end)
		end
	end

	state.thinks = {}

	for _, entity in ipairs(ents.GetAll()) do
		if (!IsValid(entity) or !isfunction(entity.Think) or
			!entity:GetClass():find("^nw_")) then
			continue
		end

		local class = entity:GetClass()
		local original = entity.Think
		local own = rawget(entity:GetTable(), "Think")
		local key = "ENT:Think / " .. class

		state.thinks[#state.thinks + 1] = {entity = entity, own = own}

		entity.Think = function(self, ...)
			local began = SysTime()
			local result = original(self, ...)

			local entry = state.times[key]

			if (!entry) then
				entry = {time = 0, calls = 0}

				state.times[key] = entry
			end

			entry.time = entry.time + (SysTime() - began)
			entry.calls = entry.calls + 1

			return result
		end
	end

	timer.Create("nwDiagProfile", duration or 20, 1, function()
		for _, entry in ipairs(state.thinks or {}) do
			if (IsValid(entry.entity)) then
				entry.entity.Think = entry.own
			end
		end

		local finished = StopProfile()

		if (finished and OnDone) then
			OnDone(finished, SysTime() - finished.start)
		end
	end)
end

NETWORK.command.Register("serverprofile", {
	adminOnly = true,
	description = "cmdServerProfile",
	usage = "/serverprofile [секунд]",
	OnRun = function(command, client, arguments)
		if (NETWORK.diag.profile) then
			return NETWORK.notice.Send(client, "diagProfileBusy", "warn")
		end

		local duration = math.Clamp(tonumber(arguments[1]) or 20, 5, 60)

		NETWORK.notice.Send(client, "diagProfileStart", "info", duration)

		NETWORK.diag.StartProfile(duration, function(state, span)
			if (!IsValid(client)) then
				return
			end

			local list = {}

			for key, entry in pairs(state.times) do
				list[#list + 1] = {
					key = key,
					time = entry.time,
					calls = entry.calls
				}
			end

			table.sort(list, function(a, b)
				return a.time > b.time
			end)

			NETWORK.chat.Notice(client, string.format(
				"Замер %.0f с. Тяжелее всего:", span))

			for index = 1, math.min(8, #list) do
				local entry = list[index]

				NETWORK.chat.Notice(client, string.format(
					"   %s — %.1f мс/с (%.1f%%), вызовов %.0f/с",
					entry.key, entry.time / span * 1000,
					entry.time / span * 100, entry.calls / span))
			end

			if (#list == 0) then
				NETWORK.chat.Notice(client, "Ничего не поймалось.")
			end
		end)
	end
})

NETWORK.command.Register("serverperf", {
	adminOnly = true,
	description = "cmdServerPerf",
	OnRun = function(command, client)
		local data = NETWORK.diag.Report()

		if (!data) then
			return NETWORK.notice.Send(client, "diagNoData", "warn")
		end

		local function Line(text)
			NETWORK.chat.Notice(client, text)
			client:PrintMessage(HUD_PRINTCONSOLE, "[serverperf] " .. text)
		end

		client:PrintMessage(HUD_PRINTCONSOLE, "[serverperf] ---------------")

		Line(string.format("Такт: норма %.1f мс · среднее %.1f мс · худшее %.1f мс",
			data.interval * 1000, data.average * 1000, data.worst * 1000))

		Line(string.format("Кадров в секунду у сервера: %.0f (норма %.0f)",
			1 / math.max(data.average, 0.0001), 1 / data.interval))

		Line(string.format("Просадок за замер: %d из %d · разброс такта %.1f мс",
			data.overruns, data.count, data.jitter * 1000))

		if (data.jitter > 0.005) then
			Line("Разброс велик — сервер регулярно замирает. Это и есть " ..
				"рывки у игроков. Ищите через /serverprofile.")
		end

		local physics = 0

		for _, entity in ipairs(ents.GetAll()) do
			local object = entity:GetPhysicsObject()

			if (IsValid(object) and object:IsMotionEnabled()) then
				physics = physics + 1
			end
		end

		Line(string.format("Игроков: %d · сущностей: %d · физика: %d",
			player.GetCount(), #ents.GetAll(), physics))

		if (data.average < data.interval) then
			Line("Такт в норме — процессор не при чём.")
		else
			Line("Такт не укладывается в норму — сервер не успевает считать.")
		end

		local function Rate(name, wanted, bMore)
			local convar = GetConVar(name)

			if (!convar) then
				return
			end

			local value = convar:GetFloat()
			local bBad = bMore and value < wanted or
				(!bMore and value > wanted)

			Line(string.format("   %s = %s%s", name,
				convar:GetString(), bBad and
				(" — ожидалось " .. (bMore and "не меньше " or "не больше ") ..
				wanted) or ""))
		end

		Line("Настройки сети:")

		Rate("sv_maxupdaterate", 66, true)
		Rate("sv_maxcmdrate", 66, true)
		Rate("sv_minupdaterate", 20, true)
		Rate("sv_mincmdrate", 20, true)
		Rate("sv_maxrate", 0, false)

		local fpsMax = GetConVar("fps_max")

		if (fpsMax) then
			local value = fpsMax:GetFloat()
			local bBad = value > 0 and value < 1 / data.interval

			Line(string.format("   fps_max = %s%s", fpsMax:GetString(),
				bBad and " — ниже такта, сервер не успевает по определению" or ""))
		end

		local fps = 1 / math.max(data.average, 0.0001)
		local want = 1 / data.interval

		if (want < 60) then
			Line(string.format("Такт сервера задан как %.0f — это и есть " ..
				"причина пинга. Ставьте -tickrate 66 в параметрах запуска.",
				want))
		elseif (fps < want * 0.6) then
			Line("Такт задан верно, но сервер до него не дотягивает. " ..
				"Lua при этом свободен — смотрите физику, число сущностей " ..
				"и загрузку процессора у хостера.")
		end

		local top, total, span = NETWORK.diag.NetReport(5)

		Line(string.format("Исходящий net: %.1f КБ/с (замер %d с)",
			total / 1024, math.floor(span)))

		for _, entry in ipairs(top) do
			Line(string.format("   %s — %.1f КБ/с, %.0f пакетов/с",
				entry.name, entry.rate / 1024, entry.count))
		end

		if (total / 1024 > 60) then
			Line("Поток великоват: при 60+ КБ/с на сервер канал и есть " ..
				"причина пинга.")
		end

		if (NETWORK.diag.big and next(NETWORK.diag.big)) then
			Line("Гигантские сообщения (больше 8 КБ — дают choke):")

			for name, big in pairs(NETWORK.diag.big) do
				Line(string.format("   %s — до %.1f КБ, раз: %d", name,
					big.largest / 1024, big.count))
			end
		end

		NETWORK.diag.big = {}
		NETWORK.diag.NetReset()

		Line("---")
		NETWORK.diag.WrapReport(Line, 8)
		NETWORK.diag.WrapReset()
	end
})
