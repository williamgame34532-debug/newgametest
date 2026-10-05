NETWORK.perf = NETWORK.perf or {}

NETWORK.perf.interface = {
	{convar = "network_menu_blur", low = "0"},
	{convar = "network_blur", low = "0"},
	{convar = "network_fx_vignette", low = "0"},
	{convar = "network_fx_fog", low = "0"},
	{convar = "network_legs", low = "0"},
	{convar = "network_hud_curve", low = "0"},
	{convar = "network_visor_curve", low = "0"},
	{convar = "network_visor_sway", low = "0"},
	{convar = "network_weather_quality", low = "0"},
	{convar = "network_cull", low = "1"},
	{convar = "network_cull_distance", low = "0.6"},
	{convar = "network_full_effects", low = "0"}
}

NETWORK.perf.engine = {
	{convar = "r_shadows", low = "0"},
	{convar = "r_drawmodeldecals", low = "0"},
	{convar = "r_decals", low = "32"},
	{convar = "mp_decals", low = "32"},
	{convar = "cl_detaildist", low = "0"},
	{convar = "cl_detailfade", low = "0"},
	{convar = "cl_drawmonitors", low = "0"},
	{convar = "cl_ejectbrass", low = "0"},
	{convar = "cl_show_splashes", low = "0"},
	{convar = "r_lod", low = "2"},
	{convar = "r_propsmaxdist", low = "400"},
	{convar = "props_break_max_pieces", low = "0"},
	{convar = "violence_ablood", low = "0"}
}

local level = CreateClientConVar("network_perf_level", "0", true, false,
	"ФПС-бустер: 0 выключен, 1 умеренный, 2 максимальный")

CreateClientConVar("network_perf_low", "0", true, false,
	"Экономный режим (старое имя network_perf_level)")

local storePath = "network_perf_backup.txt"

local backup = {}

local function LoadBackup()
	if (!file.Exists(storePath, "DATA")) then
		return
	end

	local data = util.JSONToTable(file.Read(storePath, "DATA") or "")

	backup = istable(data) and data or {}
end

local function SaveBackup()
	file.Write(storePath, util.TableToJSON(backup))
end

LoadBackup()

local function Set(name, value)
	local convar = GetConVar(name)

	if (!convar or convar:IsFlagSet(FCVAR_CHEAT)) then
		return
	end

	if (convar:GetString() == tostring(value)) then
		return
	end

	RunConsoleCommand(name, tostring(value))
end

local queue = {}

hook.Add("Think", "nwPerfQueue", function()
	if (#queue == 0) then
		return
	end

	for _ = 1, math.min(3, #queue) do
		local entry = table.remove(queue, 1)

		Set(entry[1], entry[2])
	end
end)

local function Enqueue(name, value)
	queue[#queue + 1] = {name, value}
end

function NETWORK.perf.GetLevel()
	return math.Clamp(level:GetInt(), 0, 2)
end

function NETWORK.perf.Apply(newLevel)
	newLevel = math.Clamp(tonumber(newLevel) or 0, 0, 2)

	if (newLevel <= 0) then

		for name, value in pairs(backup) do
			Enqueue(name, value)
		end

		backup = {}

		SaveBackup()

		return
	end

	local entries = {}

	for _, entry in ipairs(NETWORK.perf.interface) do
		entries[#entries + 1] = entry
	end

	if (newLevel >= 2) then
		for _, entry in ipairs(NETWORK.perf.engine) do
			entries[#entries + 1] = entry
		end
	end

	for _, entry in ipairs(entries) do
		local convar = GetConVar(entry.convar)

		if (convar and !convar:IsFlagSet(FCVAR_CHEAT)) then
			if (backup[entry.convar] == nil) then
				backup[entry.convar] = convar:GetString()
			end

			Enqueue(entry.convar, entry.low)
		end
	end

	if (newLevel < 2) then
		for _, entry in ipairs(NETWORK.perf.engine) do
			if (backup[entry.convar] != nil) then
				Enqueue(entry.convar, backup[entry.convar])

				backup[entry.convar] = nil
			end
		end
	end

	SaveBackup()
end

cvars.AddChangeCallback("network_perf_level", function(_, old, value)
	if (old == value) then
		return
	end

	NETWORK.perf.Apply(value)
end, "nwPerf")

cvars.AddChangeCallback("network_perf_low", function(_, old, value)
	if (old == value) then
		return
	end

	local target = tobool(value) and 1 or 0

	if (NETWORK.perf.GetLevel() != target) then
		RunConsoleCommand("network_perf_level", tostring(target))
	end
end, "nwPerfLegacy")

local bSuggested = false
local lowSince = 0

hook.Add("Think", "nwPerfWatch", function()
	if (bSuggested or NETWORK.perf.GetLevel() > 0) then
		return
	end

	local frame = FrameTime()

	if (frame < 1 / 35) then
		lowSince = 0

		return
	end

	if (lowSince == 0) then
		lowSince = CurTime()

		return
	end

	if (CurTime() - lowSince < 30) then
		return
	end

	bSuggested = true

	if (NETWORK.gui and NETWORK.gui.Notify) then
		NETWORK.gui.Notify(L("perfSuggest"), NETWORK.theme.warning)
	end
end)

concommand.Add("network_perf", function(_, _, arguments)
	local target = tonumber(arguments[1])

	if (!target) then
		NETWORK.util.Print("ФПС-бустер: уровень " .. NETWORK.perf.GetLevel() ..
			" (network_perf <0|1|2>)")

		return
	end

	RunConsoleCommand("network_perf_level", tostring(math.Clamp(target, 0, 2)))
end)
