NETWORK.spawns = NETWORK.spawns or {}
NETWORK.spawns.list = NETWORK.spawns.list or {}

local dataPath = "network/spawns.txt"

local function Pack(client)
	local position = client:GetPos()

	return {
		x = position.x,
		y = position.y,
		z = position.z,
		yaw = client:EyeAngles().y
	}
end

local function Unpack(entry)
	if (!istable(entry)) then
		return
	end

	return Vector(entry.x or 0, entry.y or 0, entry.z or 0), Angle(0, entry.yaw or 0, 0)
end

function NETWORK.spawns.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(NETWORK.spawns.list, true))
end

function NETWORK.spawns.Load()
	local contents = file.Read(dataPath, "DATA")
	local data = contents and util.JSONToTable(contents)

	if (istable(data)) then
		NETWORK.spawns.list = data
	end
end

function NETWORK.spawns.Get(faction)
	local map = NETWORK.spawns.list[game.GetMap()]

	return map and map[faction]
end

function NETWORK.spawns.Add(client, faction)
	local map = game.GetMap()

	NETWORK.spawns.list[map] = NETWORK.spawns.list[map] or {}
	NETWORK.spawns.list[map][faction] = NETWORK.spawns.list[map][faction] or {}

	local list = NETWORK.spawns.list[map][faction]

	list[#list + 1] = Pack(client)

	NETWORK.spawns.Save()

	return #list
end

function NETWORK.spawns.Remove(faction, index)
	local list = NETWORK.spawns.Get(faction)

	if (!list or !list[index]) then
		return false
	end

	table.remove(list, index)

	NETWORK.spawns.Save()

	return true
end

function NETWORK.spawns.Clear(faction)
	local map = NETWORK.spawns.list[game.GetMap()]

	if (!map or !map[faction]) then
		return 0
	end

	local count = #map[faction]

	map[faction] = nil

	NETWORK.spawns.Save()

	return count
end

function NETWORK.spawns.Pick(faction)
	local list = NETWORK.spawns.Get(faction)

	if (!list or #list == 0) then
		return
	end

	NETWORK.spawns.next = NETWORK.spawns.next or {}
	NETWORK.spawns.next[faction] = (NETWORK.spawns.next[faction] or 0) % #list + 1

	return Unpack(list[NETWORK.spawns.next[faction]])
end

function NETWORK.spawns.Place(client, bForce)
	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return false
	end

	if (!bForce and client.nwRestore) then
		return false
	end

	local faction = client:GetCharacterFaction()

	if (!faction) then
		return false
	end

	local classID = client:GetNWString("nwClass", "")
	local position, angles

	if (classID != "") then
		position, angles = NETWORK.spawns.Pick(faction .. ":" .. classID)
	end

	if (!position) then
		position, angles = NETWORK.spawns.Pick(faction)
	end

	if (!position) then
		return false
	end

	local trace = util.TraceHull({
		start = position + Vector(0, 0, 16),
		endpos = position - Vector(0, 0, 200),
		mins = Vector(-16, -16, 0),
		maxs = Vector(16, 16, 72),
		filter = client,
		mask = MASK_PLAYERSOLID
	})

	client:SetPos(trace.Hit and trace.HitPos or position)
	client:SetEyeAngles(angles or Angle(0, 0, 0))
	client:SetLocalVelocity(vector_origin)

	return true
end

hook.Add("PlayerDeath", "nwSpawns", function(client)
	client.nwSpawnAtFaction = true
end)

local function PlaceLater(client, force)
	for _, delay in ipairs({0.1, 0.6}) do
		timer.Simple(delay, function()
			if (!IsValid(client)) then
				return
			end

			if (client.nwSpawnPlaced) then
				return
			end

			if (NETWORK.spawns.Place(client, force)) then
				client.nwSpawnPlaced = true
			end
		end)
	end
end

hook.Add("PlayerSpawn", "nwSpawns", function(client)
	local bDied = client.nwSpawnAtFaction

	client.nwSpawnAtFaction = nil
	client.nwSpawnPlaced = false

	PlaceLater(client, bDied == true)
end)

hook.Add("NetworkCharacterLoaded", "nwSpawns", function(client)
	client.nwSpawnPlaced = false

	PlaceLater(client, false)
end)

hook.Add("NetworkFactionTransferred", "nwSpawns", function(client)
	client.nwSpawnPlaced = false

	timer.Simple(0.4, function()
		if (IsValid(client)) then
			NETWORK.spawns.Place(client, true)
		end
	end)
end)

NETWORK.command.Register("spawninfo", {
	description = "cmdSpawnInfo",
	usage = "/spawninfo",
	adminOnly = true,
	OnRun = function(command, client)
		local faction = client:GetCharacterFaction() or "?"
		local classID = client:GetNWString("nwClass", "")
		local own = NETWORK.spawns.Get(faction) or {}
		local byClass = classID != "" and NETWORK.spawns.Get(faction .. ":" .. classID) or {}

		NETWORK.notice.Send(client, "spawnInfo", "info", faction, #own,
			classID != "" and classID or "-", #byClass)
	end
})

hook.Add("InitPostEntity", "nwSpawns", function()
	NETWORK.spawns.Load()
end)

NETWORK.spawns.Load()

local function Resolve(client, id, classID)
	id = string.lower(id or "")

	if (id == "") then
		id = client:GetCharacterFaction()
	elseif (!NETWORK.factions.Get(id)) then
		return
	end

	if (!id) then
		return
	end

	classID = string.lower(classID or "")

	if (classID != "") then
		local class = NETWORK.classes.Get(classID)

		if (!class or class.faction != id) then
			return nil, true
		end

		return id .. ":" .. classID
	end

	return id
end

local function Describe(key)
	local faction, classID = string.match(key, "^([^:]+):(.+)$")
	local data = NETWORK.factions.Get(faction or key)
	local label = data and L(data.name) or key

	if (classID) then
		local class = NETWORK.classes.Get(classID)

		label = label .. " / " .. (class and L(class.name) or classID)
	end

	return label
end

NETWORK.command.Register("spawnadd", {
	adminOnly = true,
	description = "cmdSpawnAdd",
	usage = "/spawnadd [фракция] [класс]",
	OnRun = function(command, client, arguments)
		local key, bBadClass = Resolve(client, arguments[1], arguments[2])

		if (!key) then
			return NETWORK.chat.Notice(client,
				L(bBadClass and "classUnknown" or "adminNoFaction"))
		end

		NETWORK.chat.Notice(client, L("spawnAdded", Describe(key),
			NETWORK.spawns.Add(client, key)))
	end
})

NETWORK.command.Register("spawnlist", {
	adminOnly = true,
	description = "cmdSpawnList",
	usage = "/spawnlist",
	OnRun = function(command, client)
		local map = NETWORK.spawns.list[game.GetMap()] or {}
		local parts = {}

		for key, list in pairs(map) do
			parts[#parts + 1] = Describe(key) .. ": " .. #list
		end

		NETWORK.chat.Notice(client, #parts > 0 and table.concat(parts, ", ") or
			L("spawnNone"))
	end
})

NETWORK.command.Register("spawndel", {
	adminOnly = true,
	description = "cmdSpawnDel",
	usage = "/spawndel <фракция> <номер> [класс]",
	OnRun = function(command, client, arguments)
		local key, bBadClass = Resolve(client, arguments[1], arguments[3])

		if (!key) then
			return NETWORK.chat.Notice(client,
				L(bBadClass and "classUnknown" or "adminNoFaction"))
		end

		if (!NETWORK.spawns.Remove(key, tonumber(arguments[2]) or 0)) then
			return NETWORK.chat.Notice(client, L("spawnNoPoint"))
		end

		NETWORK.chat.Notice(client, L("spawnRemoved"))
	end
})

NETWORK.command.Register("spawnclear", {
	adminOnly = true,
	description = "cmdSpawnClear",
	usage = "/spawnclear <фракция> [класс]",
	OnRun = function(command, client, arguments)
		local key, bBadClass = Resolve(client, arguments[1], arguments[2])

		if (!key) then
			return NETWORK.chat.Notice(client,
				L(bBadClass and "classUnknown" or "adminNoFaction"))
		end

		NETWORK.chat.Notice(client, L("spawnCleared", NETWORK.spawns.Clear(key)))
	end
})
