-- Server side of the "Конфигурация" page: superadmins read and change the convars listed in
-- sh_config.lua (only those, numbers clamped to their limits).

util.AddNetworkString("nwConfig")
util.AddNetworkString("nwConfigSet")

local CF = NW.config

local function Send(client)
	local values = {}

	for name in pairs(CF.byName) do
		local convar = GetConVar(name)

		values[name] = convar and convar:GetString() or ""
	end

	net.Start("nwConfig")
		net.WriteString(util.TableToJSON(values))
	net.Send(client)
end

net.Receive("nwConfig", function(_, client)
	if (client:IsSuperAdmin() and (client.nwConfigNext or 0) < CurTime()) then
		client.nwConfigNext = CurTime() + 0.5
		Send(client)
	end
end)

net.Receive("nwConfigSet", function(_, client)
	local name, value = net.ReadString(), net.ReadString()
	local row = CF.byName[name]

	if (!client:IsSuperAdmin() or !row or !GetConVar(name)) then
		return
	end

	if (row.type == "slider") then
		value = tostring(math.Clamp(math.Round(tonumber(value) or row.min), row.min, row.max))
	elseif (row.type == "toggle") then
		value = tobool(value) and "1" or "0"
	else
		value = string.sub(string.gsub(value, "[%c\"]", ""), 1, 200)
	end

	RunConsoleCommand(name, value)
	MsgN(string.format("[nw_config] %s: %s = %s", client:SteamName(), name, value))

	timer.Simple(0.1, function()
		if (IsValid(client)) then
			Send(client)
		end
	end)
end)
