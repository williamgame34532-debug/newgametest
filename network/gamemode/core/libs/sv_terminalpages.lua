util.AddNetworkString("nwTerminalAction")
util.AddNetworkString("nwTerminalMarker")

function NETWORK.terminal.GetBank(client)
	return math.max(math.Round(client.nwBank or 0), 0)
end

function NETWORK.terminal.SetBank(client, amount)
	client.nwBank = math.max(math.Round(amount), 0)

	NETWORK.terminal.Sync(client)
end

local function IsBought(data)
	return NETWORK.apartments and NETWORK.apartments.IsPurchased(data)
end

-- Free residential doors for the terminal: bought apartments are private, every apartment holds
-- at most housingCapacity residents, and new residents go to the emptiest apartment first so the
-- whole city does not end up in a single flat.
function NETWORK.terminal.GetFreeDoors()
	local list = {}
	local seen = {}

	for _, entity in ipairs(ents.GetAll()) do
		if (!NETWORK.door.IsDoor(entity)) then
			continue
		end

		local data = NETWORK.door.GetData(entity)
		local root = data and NETWORK.door.GetRootKey(entity)

		if (!data or data.type != "residential" or IsBought(data) or seen[data] or (root and seen[root]) or
			NETWORK.door.OwnerCount(data) >= NETWORK.door.housingCapacity) then
			continue
		end

		seen[data] = true

		if (root) then
			seen[root] = true
		end

		list[#list + 1] = {entity = entity, count = NETWORK.door.OwnerCount(data), roll = math.random()}
	end

	table.sort(list, function(a, b)
		if (a.count != b.count) then
			return a.count < b.count
		end

		return a.roll < b.roll
	end)

	for index, entry in ipairs(list) do
		list[index] = entry.entity
	end

	return list
end

function NETWORK.terminal.GetHome(client)
	local id = client:SteamID64()

	for _, entity in ipairs(ents.GetAll()) do
		if (!NETWORK.door.IsDoor(entity)) then
			continue
		end

		local data = NETWORK.door.GetData(entity)

		if (data and data.type == "residential" and NETWORK.door.IsOwner(data, id)) then
			return entity, data
		end
	end
end

local function AddResident(data, client)
	local character = client:GetCharacter()

	data.owners = NETWORK.door.GetOwners(data)
	data.owners[client:SteamID64()] = {
		name = client:GetCharacterName(),
		char = character and tostring(character:GetID()) or nil,
		faction = client:GetCharacterFaction()
	}

	if (!data.owner) then
		data.owner = client:SteamID64()
		data.ownerName = client:GetCharacterName()
		data.ownerChar = character and tostring(character:GetID()) or nil
		data.ownerFaction = client:GetCharacterFaction()
	end
end

local function RemoveResident(data, steamID)
	data.owners = NETWORK.door.GetOwners(data)

	local entry = data.owners[steamID]

	if (entry and entry.char and NETWORK.housing and NETWORK.housing.ClearFurniture) then
		NETWORK.housing.ClearFurniture(entry.char)
	end

	data.owners[steamID] = nil

	if (data.owner == steamID) then
		local nextID, entry = next(data.owners)

		data.owner = nextID
		data.ownerName = entry and entry.name or nil
		data.ownerChar = entry and entry.char or nil
		data.ownerFaction = entry and entry.faction or nil
	end

	if (next(data.owners) == nil) then
		data.owners = nil
	end
end

NETWORK.terminal.AddResident = AddResident
NETWORK.terminal.RemoveResident = RemoveResident

function NETWORK.terminal.AssignHome(client)

	if (NETWORK.factions.IsAlliance(client)) then
		return false, "termHousingAlliance"
	end

	if (NETWORK.terminal.GetHome(client)) then
		return false, "termHousingTaken"
	end

	local free = NETWORK.terminal.GetFreeDoors()

	if (#free == 0) then
		return false, "termHousingNoneLeft"
	end

	local entity = free[1]
	local data = NETWORK.door.GetData(entity)

	AddResident(data, client)

	NETWORK.door.Set(entity, data)

	if (NETWORK.dialogue.CountItem(client, "keys") < 1) then
		NETWORK.inventory.Give(client, "keys", 1)
	end

	NETWORK.terminal.SetMarker(client, entity:GetPos(), NETWORK.door.GetHousingName(data))

	return true, "termHousingAssigned"
end

function NETWORK.terminal.ReleaseHome(client)
	local entity, data = NETWORK.terminal.GetHome(client)

	if (!entity) then
		return false, "termHousingNone"
	end

	if (IsBought(data) and data.purchase.steamID == client:SteamID64()) then
		return false, "Это ваша собственная квартира: освободить её может только администрация."
	end

	RemoveResident(data, client:SteamID64())

	NETWORK.door.Set(entity, data)
	NETWORK.terminal.ClearMarker(client)

	return true, "termHousingReleased"
end

hook.Add("PlayerDeath", "nwHousingDeath", function(client)
	if (!client:HasCharacter()) then
		return
	end

	local entity, data = NETWORK.terminal.GetHome(client)

	if (!entity or (IsBought(data) and data.purchase.steamID == client:SteamID64())) then
		return
	end

	RemoveResident(data, client:SteamID64())
	NETWORK.door.Set(entity, data)
	NETWORK.terminal.ClearMarker(client)
	NETWORK.notice.Send(client, "termHousingLostDeath", "warn")
end)

function NETWORK.terminal.ReleaseHomeOf(steamID, currentChar)
	if (!steamID) then
		return
	end

	for _, entity in ipairs(ents.GetAll()) do
		local data = NETWORK.door.GetData(entity)

		if (!data or data.type != "residential" or !NETWORK.door.IsOwner(data, steamID)) then
			continue
		end

		-- The buyer of an apartment keeps it; sv_apartments handles character switches.
		if (IsBought(data) and data.purchase.steamID == steamID) then
			continue
		end

		local entry = NETWORK.door.GetOwners(data)[steamID]

		if (currentChar and (entry == nil or entry.char == nil or entry.char == currentChar)) then
			continue
		end

		RemoveResident(data, steamID)

		NETWORK.door.Set(entity, data)
	end
end

hook.Add("PlayerDisconnected", "nwHousingRelease", function(client)
	NETWORK.terminal.ReleaseHomeOf(client:SteamID64())
end)

hook.Add("NetworkCharacterLoaded", "nwHousingRelease", function(client)
	timer.Simple(1, function()
		if (!IsValid(client) or !client:HasCharacter()) then
			return
		end

		NETWORK.terminal.ReleaseHomeOf(client:SteamID64(),
			tostring(client:GetCharacter():GetID()))
	end)
end)

hook.Add("NetworkFactionTransferred", "nwHousingRelease", function(client, character, faction)
	if (!IsValid(client) or (faction and faction.id == "citizen")) then
		return
	end

	NETWORK.terminal.ReleaseHomeOf(client:SteamID64())
end)

function NETWORK.terminal.SetMarker(client, position, label, color)
	net.Start("nwTerminalMarker")
		net.WriteBool(true)
		net.WriteVector(position)
		net.WriteString(label or "")
		net.WriteColor(color or Color(126, 226, 240), false)
	net.Send(client)
end

function NETWORK.terminal.ClearMarker(client)
	net.Start("nwTerminalMarker")
		net.WriteBool(false)
	net.Send(client)
end

function NETWORK.terminal.BroadcastMarker(position, label)
	for _, client in ipairs(player.GetAll()) do
		if (client:HasCharacter() and NETWORK.factions.IsAlliance(client)) then
			NETWORK.terminal.SetMarker(client, position, label, Color(226, 62, 58))
		end
	end
end

local actions = {}

NETWORK.terminal.actions = actions

NETWORK.terminal.actions = actions

function actions.deposit(client, entity, payload)
	local amount = math.Clamp(math.Round(tonumber(payload.amount) or 0), 1, 100000)

	if (client:GetTokens() < amount) then
		return "termNoTokens"
	end

	NETWORK.currency.Take(client, amount)
	NETWORK.terminal.SetBank(client, NETWORK.terminal.GetBank(client) + amount)

	return "termBankDone"
end

function actions.withdraw(client, entity, payload)
	local amount = math.Clamp(math.Round(tonumber(payload.amount) or 0), 1, 100000)

	if (NETWORK.terminal.GetBank(client) < amount) then
		return "termNoBank"
	end

	NETWORK.terminal.SetBank(client, NETWORK.terminal.GetBank(client) - amount)
	NETWORK.currency.Add(client, amount)

	return "termBankDone"
end

function actions.housing(client, entity, payload)
	local bOk, key = NETWORK.terminal.AssignHome(client)

	return key
end

function actions.housingRelease(client, entity, payload)
	local bOk, key = NETWORK.terminal.ReleaseHome(client)

	return key
end

function actions.businessApply(client, entity, payload)
	local what = string.Trim(tostring(payload.what or ""))
	local why = string.Trim(tostring(payload.why or ""))

	if (what == "" or why == "") then
		return "businessEmpty"
	end

	local character = client:GetCharacter()
	local entry = NETWORK.business.Get(character)

	if (entry and entry.status == "pending") then
		return "businessPending"
	end

	if (NETWORK.factions.IsAlliance(client)) then
		return "businessAlliance"
	end

	NETWORK.business.Apply(client, character, what, why)

	entity:EmitSound(NETWORK.terminal.sounds.confirm or
		NETWORK.terminal.sounds.select, 65)

	return "businessSent"
end

function actions.call(client, entity, payload)
	local index = math.Clamp(math.Round(tonumber(payload.reason) or 1), 1,
		#NETWORK.terminal.reasons)
	local reason = L(NETWORK.terminal.reasons[index])

	NETWORK.terminal.Alarm(client, entity, reason)

	hook.Run("NetworkTerminalCall", client, entity, reason)

	for _, other in ipairs(player.GetAll()) do
		if (other:HasCharacter() and NETWORK.factions.IsAlliance(other)) then
			net.Start("nwChatMessage")
				net.WriteString("center")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString(L("termCallAlert", reason))
			net.Send(other)

			if (NETWORK.waypoint and NETWORK.waypoint.Add) then
				NETWORK.waypoint.Add(other, entity:GetPos() + Vector(0, 0, 32),
					L("callWaypoint", reason), Color(86, 150, 226), 600, true, "call")
			end
		end
	end

	return "termCallSent"
end

net.Receive("nwTerminalAction", function(_, client)
	local action = net.ReadString()
	local payload = NETWORK.util.ReadTable() or {}
	local entity = client.nwTerminal
	local callback = actions[action]

	if (!callback or !NETWORK.terminal.IsUsable(client, entity)) then
		return
	end

	if (!NETWORK.terminal.CanOpen(client)) then
		NETWORK.terminal.Close(client)

		return
	end

	if (entity:GetAlarm() or entity:GetUser() != client) then
		return
	end

	if ((client.nwNextTerminal or 0) > CurTime()) then
		return
	end

	client.nwNextTerminal = CurTime() + 0.3

	local key = callback(client, entity, payload)

	NETWORK.terminal.Sync(client)

	if (key) then
		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(key)
		net.Send(client)
	end
end)

hook.Add("NetworkCharacterLoaded", "nwTerminalHome", function(client)
	timer.Simple(1.5, function()
		if (!IsValid(client)) then
			return
		end

		local entity, data = NETWORK.terminal.GetHome(client)

		if (entity) then
			NETWORK.terminal.SetMarker(client, entity:GetPos(), NETWORK.door.GetHousingName(data))
		end
	end)
end)
