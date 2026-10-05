util.AddNetworkString("nwIconSync")
util.AddNetworkString("nwIconSave")
util.AddNetworkString("nwIconEditor")

local dataPath = "network/icons.txt"

function NETWORK.icon.Load()
	local contents = file.Read(dataPath, "DATA")

	if (!contents) then
		return
	end

	local data = util.JSONToTable(contents)

	if (istable(data)) then
		NETWORK.icon.stored = data

		NETWORK.util.Print("Загружено иконок: " .. table.Count(data))
	end
end

function NETWORK.icon.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(NETWORK.icon.stored, true))
end

function NETWORK.icon.Sync(target)
	net.Start("nwIconSync")
		NETWORK.util.WriteTable(NETWORK.icon.stored)

	if (IsValid(target)) then
		net.Send(target)
	else
		net.Broadcast()
	end
end

net.Receive("nwIconSave", function(_, client)
	if (!client:IsAdmin()) then
		return
	end

	local id = net.ReadString()
	local payload = NETWORK.util.ReadTable()

	if (!NETWORK.item.Get(id)) then
		return
	end

	if (payload.bReset) then
		NETWORK.icon.stored[id] = nil
	else
		local clean = NETWORK.icon.Clean({[id] = payload})

		NETWORK.icon.stored[id] = clean and clean[id] or nil
	end

	NETWORK.icon.Save()
	NETWORK.icon.Sync()
end)

hook.Add("PlayerInitialSpawn", "nwIcon", function(client)
	timer.Simple(2, function()
		if (IsValid(client)) then
			NETWORK.icon.Sync(client)
		end
	end)
end)

NETWORK.icon.Load()

NETWORK.command.Register("iconedit", {
	adminOnly = true,
	description = "cmdIconEdit",
	usage = "/iconedit",
	OnRun = function(command, client)
		net.Start("nwIconSync")
			NETWORK.util.WriteTable(NETWORK.icon.stored)
		net.Send(client)

		net.Start("nwIconEditor")
		net.Send(client)
	end
})
