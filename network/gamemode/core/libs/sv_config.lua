util.AddNetworkString("nwConfigSync")
util.AddNetworkString("nwConfigSet")

local dataPath = "network/config.txt"

function NETWORK.config.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(NETWORK.config.values, true))
end

function NETWORK.config.Load()
	local contents = file.Read(dataPath, "DATA")

	if (contents) then
		local data = util.JSONToTable(contents)

		if (istable(data)) then
			for id, value in pairs(data) do
				if (NETWORK.config.stored[id]) then
					NETWORK.config.values[id] = value
				end
			end
		end
	end

	NETWORK.config.ApplyAll()
end

function NETWORK.config.Broadcast(target)
	net.Start("nwConfigSync")
		NETWORK.util.WriteTable(NETWORK.config.values)

	if (IsValid(target)) then
		net.Send(target)
	else
		net.Broadcast()
	end
end

function NETWORK.config.Set(id, value)
	local data = NETWORK.config.stored[id]

	if (!data) then
		return false
	end

	if (data.type == "number") then
		value = math.Clamp(tonumber(value) or data.default, data.min or 0, data.max or 1000)

		if ((data.decimals or 0) <= 0) then
			value = math.Round(value)
		else
			value = math.Round(value, data.decimals)
		end
	elseif (data.type == "bool") then
		value = tobool(value)
	else
		value = tostring(value)
	end

	NETWORK.config.values[id] = value

	NETWORK.config.Apply(id)
	NETWORK.config.Save()
	NETWORK.config.Broadcast()

	hook.Run("NetworkConfigChanged", id, value)

	return true
end

net.Receive("nwConfigSet", function(_, client)
	if (!client:IsSuperAdmin()) then
		return
	end

	local id = net.ReadString()
	local value = NETWORK.util.ReadTable().value

	if (NETWORK.config.Set(id, value)) then
		NETWORK.util.Print(string.format("%s изменил %s на %s", client:SteamID(), id,
			tostring(value)))
	end
end)

hook.Add("PlayerInitialSpawn", "nwConfig", function(client)
	timer.Simple(1, function()
		if (IsValid(client)) then
			NETWORK.config.Broadcast(client)
		end
	end)
end)

hook.Add("Initialize", "nwConfig", function()
	NETWORK.config.Load()
end)
