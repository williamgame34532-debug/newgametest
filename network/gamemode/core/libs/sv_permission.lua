local function Notice(client, text)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(text)
	net.Send(client)
end

local dataPath = "network/permissions.txt"

NETWORK.permission.data = NETWORK.permission.data or {}

function NETWORK.permission.Load()
	local contents = file.Read(dataPath, "DATA")

	if (!contents) then
		return
	end

	local data = util.JSONToTable(contents)

	if (istable(data)) then
		NETWORK.permission.data = data
	end
end

function NETWORK.permission.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(NETWORK.permission.data, true))
end

function NETWORK.permission.Apply(client)
	local granted = NETWORK.permission.data[client:SteamID64() or ""] or {}

	for _, id in ipairs(NETWORK.permission.list) do
		client:SetNWBool("nwPerm_" .. id, granted[id] == true)
	end
end

function NETWORK.permission.Set(client, id, bValue)
	if (!NETWORK.permission.stored[id]) then
		return false
	end

	local key = client:SteamID64()

	NETWORK.permission.data[key] = NETWORK.permission.data[key] or {}
	NETWORK.permission.data[key][id] = bValue or nil

	NETWORK.permission.Save()
	NETWORK.permission.Apply(client)

	return true
end

function NETWORK.permission.Find(name)
	name = string.lower(name or "")

	for _, client in ipairs(player.GetAll()) do
		if (string.find(string.lower(client:GetCharacterName()), name, 1, true) or
			string.find(string.lower(client:SteamName()), name, 1, true)) then
			return client
		end
	end
end

hook.Add("PlayerInitialSpawn", "nwPermission", function(client)
	NETWORK.permission.Apply(client)
end)

hook.Add("Initialize", "nwPermission", function()
	NETWORK.permission.Load()
end)

NETWORK.permission.Load()

NETWORK.command.Register("setpermition", {
	description = "cmdSetpermition",
	usage = "/setpermition <игрок> <право> <0/1>",
	adminOnly = true,
	aliases = {"setpermission", "perm"},
	OnRun = function(command, client, arguments)
		local target = NETWORK.permission.Find(arguments[1])
		local id = string.lower(arguments[2] or "")
		local value = arguments[3]

		if (!IsValid(target)) then
			Notice(client, L("permNoTarget"))

			return
		end

		if (!NETWORK.permission.stored[id]) then
			local names = {}

			for _, key in ipairs(NETWORK.permission.list) do
				names[#names + 1] = key
			end

			Notice(client, L("permUsage") .. " " .. table.concat(names, ", "))

			return
		end

		local bValue = value == nil and !target:HasPermission(id) or tobool(value)

		NETWORK.permission.Set(target, id, bValue)

		Notice(client, string.format("%s: %s = %s", target:GetCharacterName(), id,
			bValue and "1" or "0"))
	end
})
