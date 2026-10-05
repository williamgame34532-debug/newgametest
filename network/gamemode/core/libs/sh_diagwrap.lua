NETWORK.diag = NETWORK.diag or {}

local D = NETWORK.diag

D.calls = D.calls or {}
D.stalls = D.stalls or {}
D.stallLimit = 40
D.stallThreshold = 0.008

D.frameCalls = {}
D.frameStart = SysTime()

local function Caller(level)
	local info = debug.getinfo(level, "Sl")

	if (!info) then
		return "?"
	end

	local source = info.short_src or "?"

	source = string.gsub(source, "^.*gamemodes/", "")
	source = string.gsub(source, "^.*addons/", "")

	return source .. ":" .. tostring(info.currentline or 0)
end

D.Caller = Caller

function D.Account(key, took)
	local entry = D.calls[key]

	if (!entry) then
		entry = {time = 0, calls = 0, worst = 0}

		D.calls[key] = entry
	end

	entry.time = entry.time + took
	entry.calls = entry.calls + 1
	entry.worst = math.max(entry.worst, took)

	D.frameCalls[#D.frameCalls + 1] = key

	if (took >= D.stallThreshold) then
		D.stalls[#D.stalls + 1] = {
			key = key,
			took = took,
			at = os.time(),
			cur = CurTime()
		}

		if (#D.stalls > D.stallLimit) then
			table.remove(D.stalls, 1)
		end
	end
end

local function Wrap(original, keyFn)
	return function(...)
		local began = SysTime()
		local a, b, c, d, e, f = original(...)

		D.Account(keyFn(...), SysTime() - began)

		return a, b, c, d, e, f
	end
end

local function WrapCallback(callback, key)
	if (!isfunction(callback)) then
		return callback
	end

	return function(...)
		local began = SysTime()
		local a, b, c, d, e, f = callback(...)

		D.Account(key, SysTime() - began)

		return a, b, c, d, e, f
	end
end

if (D.bWrapped) then
	return
end

D.bWrapped = true

local baseCreate = timer.Create
local baseSimple = timer.Simple

function timer.Create(name, delay, repetitions, callback)
	return baseCreate(name, delay, repetitions,
		WrapCallback(callback, "timer / " .. tostring(name)))
end

function timer.Simple(delay, callback)
	local info = isfunction(callback) and debug.getinfo(callback, "S")
	local key = "timer.Simple / " .. (info and
		(string.gsub(info.short_src or "?", "^.*gamemodes/", "") .. ":" ..
		tostring(info.linedefined or 0)) or "?")

	return baseSimple(delay, WrapCallback(callback, key))
end

local baseReceive = net.Receive

function net.Receive(name, callback)
	return baseReceive(name, WrapCallback(callback, "net.Receive / " .. tostring(name)))
end

local function ByCaller(prefix)
	return function()
		return prefix .. " / " .. Caller(4)
	end
end

file.Write = Wrap(file.Write, ByCaller("file.Write"))
file.Append = Wrap(file.Append, ByCaller("file.Append"))
file.Read = Wrap(file.Read, ByCaller("file.Read"))

if (SERVER) then
	sql.Query = Wrap(sql.Query, ByCaller("sql.Query"))
	sql.QueryValue = Wrap(sql.QueryValue, ByCaller("sql.QueryValue"))
	sql.QueryRow = Wrap(sql.QueryRow, ByCaller("sql.QueryRow"))
	sql.Begin = Wrap(sql.Begin, ByCaller("sql.Begin"))
	sql.Commit = Wrap(sql.Commit, ByCaller("sql.Commit"))
end

util.TableToJSON = Wrap(util.TableToJSON, ByCaller("util.TableToJSON"))
util.JSONToTable = Wrap(util.JSONToTable, ByCaller("util.JSONToTable"))

if (CLIENT) then

	Material = Wrap(Material, ByCaller("Material"))
	CreateMaterial = Wrap(CreateMaterial, ByCaller("CreateMaterial"))

	surface.CreateFont = Wrap(surface.CreateFont, ByCaller("surface.CreateFont"))

	if (sound and sound.PlayFile) then
		sound.PlayFile = Wrap(sound.PlayFile, ByCaller("sound.PlayFile"))
	end

	if (util.PrecacheModel) then
		util.PrecacheModel = Wrap(util.PrecacheModel, ByCaller("util.PrecacheModel"))
	end
end

D.longFrames = D.longFrames or {}
D.longLimit = 30
D.longThreshold = 0.045

hook.Add("Think", "nwDiagFrames", function()
	local now = SysTime()
	local took = now - D.frameStart

	if (took >= D.longThreshold and #D.frameCalls > 0) then

		local seen, unique = {}, {}

		for _, key in ipairs(D.frameCalls) do
			if (!seen[key]) then
				seen[key] = true
				unique[#unique + 1] = key
			end
		end

		D.longFrames[#D.longFrames + 1] = {
			took = took,
			at = os.time(),
			keys = unique
		}

		if (#D.longFrames > D.longLimit) then
			table.remove(D.longFrames, 1)
		end
	end

	D.frameCalls = {}
	D.frameStart = now
end)

function D.WrapReport(Line, limit)
	local list = {}

	for key, entry in pairs(D.calls) do
		list[#list + 1] = {key = key, time = entry.time, calls = entry.calls,
			worst = entry.worst}
	end

	table.sort(list, function(a, b)
		return a.worst > b.worst
	end)

	Line("Самые долгие одиночные вызовы (worst):")

	for index = 1, math.min(limit or 8, #list) do
		local entry = list[index]

		Line(string.format("   %s — худший %.1f мс, всего %.0f мс за %d вызовов",
			entry.key, entry.worst * 1000, entry.time * 1000, entry.calls))
	end

	if (#D.stalls > 0) then
		Line(string.format("Журнал замираний (вызовы дольше %d мс), последние:",
			D.stallThreshold * 1000))

		for index = math.max(#D.stalls - 9, 1), #D.stalls do
			local stall = D.stalls[index]

			Line(string.format("   %s  %s — %.1f мс", os.date("%H:%M:%S", stall.at),
				stall.key, stall.took * 1000))
		end
	end

	if (#D.longFrames > 0) then
		Line(string.format("Длинные кадры (дольше %d мс), последние:",
			D.longThreshold * 1000))

		for index = math.max(#D.longFrames - 7, 1), #D.longFrames do
			local frame = D.longFrames[index]

			Line(string.format("   %s  %.0f мс — %s", os.date("%H:%M:%S", frame.at),
				frame.took * 1000, table.concat(frame.keys, ", ")))
		end
	else
		Line("Длинных кадров с обёрнутыми вызовами не было: если фризы " ..
			"есть, они вне Lua — движок или процессор.")
	end
end

function D.WrapReset()
	D.calls = {}
	D.stalls = {}
	D.longFrames = {}
end
