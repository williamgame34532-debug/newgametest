NETWORK.netcfg = NETWORK.netcfg or {}

NETWORK.netcfg.values = {
	{convar = "rate", value = 786432, bHigher = true},
	{convar = "cl_updaterate", value = 66, bHigher = true},
	{convar = "cl_cmdrate", value = 66, bHigher = true},

	{convar = "cl_interp_ratio", value = 2, bHigher = false},
	{convar = "cl_interp", value = 0, bHigher = false},

	{convar = "cl_predict", value = 1, bHigher = true},
	{convar = "cl_predictweapons", value = 1, bHigher = true},
	{convar = "cl_lagcompensation", value = 1, bHigher = true},
	{convar = "cl_smooth", value = 1, bHigher = true}
}

local auto = CreateClientConVar("network_net_auto", "1", true, false,
	"Выставлять сетевые настройки автоматически при входе")

function NETWORK.netcfg.Apply(bForce)
	if (!bForce and !auto:GetBool()) then
		return 0
	end

	local changed = 0

	for _, entry in ipairs(NETWORK.netcfg.values) do
		local convar = GetConVar(entry.convar)

		if (!convar or convar:IsFlagSet(FCVAR_CHEAT)) then
			continue
		end

		local current = convar:GetFloat()

		local bWorse = entry.bHigher and current < entry.value or
			(!entry.bHigher and current > entry.value)

		if (entry.convar == "cl_interp_ratio") then
			bWorse = current != entry.value
		end

		if (!bWorse) then
			continue
		end

		RunConsoleCommand(entry.convar, tostring(entry.value))

		changed = changed + 1
	end

	return changed
end

hook.Add("InitPostEntity", "nwNetCfg", function()
	timer.Simple(8, function()
		local changed = NETWORK.netcfg.Apply()

		if (changed > 0) then
			NETWORK.gui.Notify(L("netTuned"), NETWORK.theme.positive)
		end
	end)
end)

NETWORK.option.Register("network_net_auto", {
	name = "optNetAuto",
	description = "optNetAutoDesc",
	category = "performance",
	type = "bool",
	convar = "network_net_auto"
})

concommand.Add("network_net", function()
	NETWORK.util.Print("Сетевые настройки:")

	for _, entry in ipairs(NETWORK.netcfg.values) do
		local convar = GetConVar(entry.convar)

		if (!convar) then
			continue
		end

		local current = convar:GetFloat()
		local bWorse = entry.bHigher and current < entry.value or
			(!entry.bHigher and current > entry.value)

		NETWORK.util.Print(string.format("   %s = %s%s", entry.convar,
			convar:GetString(), bWorse and
			(" — лучше " .. entry.value) or ""))
	end

	local changed = NETWORK.netcfg.Apply(true)

	NETWORK.util.Print(changed > 0 and ("Поправлено значений: " .. changed) or
		"Всё уже выставлено верно. Остаток пинга — это маршрут до сервера.")
end)
