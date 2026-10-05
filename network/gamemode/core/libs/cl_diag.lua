local D = NETWORK.diag

local function Line(text)
	print("[clientperf] " .. text)
end

concommand.Add("network_clientperf", function()
	Line("----------------------------------------")
	Line(string.format("Кадров в секунду: %.0f", 1 / math.max(FrameTime(), 0.0001)))

	D.WrapReport(Line, 10)
	D.WrapReset()

	Line("Отчёт напечатан, счётчики обнулены.")
end)

local events = {
	"Think", "Tick", "HUDPaint", "HUDPaintBackground", "PreDrawHUD",
	"PostDrawHUD", "DrawOverlay", "PostDrawOpaqueRenderables",
	"PostDrawTranslucentRenderables", "PreDrawTranslucentRenderables",
	"PreDrawOpaqueRenderables", "RenderScreenspaceEffects", "RenderScene",
	"PreRender", "PostRender", "CalcView", "CalcViewModelView",
	"PrePlayerDraw", "PostPlayerDraw", "PreDrawHalos", "PostDrawEffects",
	"CreateMove", "PreDrawViewModel", "PostDrawViewModel",
	"NetworkEntityCreated", "OnEntityCreated", "PostDrawSkyBox",
	"HUDShouldDraw", "ShouldDrawLocalPlayer", "PreDrawPlayerHands"
}

local profile

local function Stop()
	if (!profile) then
		return
	end

	for _, entry in ipairs(profile.wrapped) do
		hook.Add(entry.event, entry.name, entry.original)
	end

	local state = profile

	profile = nil

	return state
end

concommand.Add("network_clientprofile", function(_, _, arguments)
	if (profile) then
		return Line("Замер уже идёт.")
	end

	local duration = math.Clamp(tonumber(arguments[1]) or 20, 5, 60)

	profile = {times = {}, wrapped = {}, start = SysTime(), frames = 0}

	local state = profile

	for _, event in ipairs(events) do
		local handlers = hook.GetTable()[event]

		if (!handlers) then
			continue
		end

		for name, callback in pairs(handlers) do
			if (!isstring(name) or !isfunction(callback)) then
				continue
			end

			local key = event .. " / " .. name

			state.wrapped[#state.wrapped + 1] = {event = event, name = name,
				original = callback}

			hook.Add(event, name, function(...)
				local began = SysTime()
				local a, b, c, d, e, f = callback(...)
				local entry = state.times[key]

				if (!entry) then
					entry = {time = 0, calls = 0, worst = 0}

					state.times[key] = entry
				end

				local took = SysTime() - began

				entry.time = entry.time + took
				entry.calls = entry.calls + 1
				entry.worst = math.max(entry.worst, took)

				return a, b, c, d, e, f
			end)
		end
	end

	Line(string.format("Замер на %d с. Играйте как обычно.", duration))

	timer.Simple(duration, function()
		local finished = Stop()

		if (!finished) then
			return
		end

		local span = SysTime() - finished.start
		local list = {}

		for key, entry in pairs(finished.times) do
			list[#list + 1] = {key = key, time = entry.time, calls = entry.calls,
				worst = entry.worst}
		end

		table.sort(list, function(a, b)
			return a.time > b.time
		end)

		Line("----------------------------------------")
		Line(string.format("Замер %.0f с. Тяжелее всего:", span))

		for index = 1, math.min(12, #list) do
			local entry = list[index]

			Line(string.format("   %s — %.1f мс/с (%.1f%% кадра), худший %.1f мс, %.0f/с",
				entry.key, entry.time / span * 1000, entry.time / span * 100,
				entry.worst * 1000, entry.calls / span))
		end

		table.sort(list, function(a, b)
			return a.worst > b.worst
		end)

		Line("Самые долгие одиночные вызовы:")

		for index = 1, math.min(6, #list) do
			local entry = list[index]

			Line(string.format("   %s — %.1f мс", entry.key, entry.worst * 1000))
		end
	end)
end)
