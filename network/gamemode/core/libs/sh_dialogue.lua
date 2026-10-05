NETWORK.dialogue = NETWORK.dialogue or {}
NETWORK.dialogue.stored = NETWORK.dialogue.stored or {}
NETWORK.dialogue.order = NETWORK.dialogue.order or {}

function NETWORK.dialogue.Register(id, data)
	data.id = id
	data.name = data.name or id
	data.start = data.start or "greeting"
	data.nodes = data.nodes or {}

	if (!NETWORK.dialogue.stored[id]) then
		NETWORK.dialogue.order[#NETWORK.dialogue.order + 1] = id
	end

	NETWORK.dialogue.stored[id] = data

	return data
end

function NETWORK.dialogue.Get(id)
	return NETWORK.dialogue.stored[id]
end

function NETWORK.dialogue.GetAll()
	local list = {}

	for _, id in ipairs(NETWORK.dialogue.order) do
		list[#list + 1] = NETWORK.dialogue.stored[id]
	end

	return list
end

function NETWORK.dialogue.GetNode(id, node)
	local data = NETWORK.dialogue.Get(id)

	return data and data.nodes[node]
end

function NETWORK.dialogue.FactionAllowed(client, factions)
	if (!istable(factions) or table.IsEmpty(factions)) then
		return true
	end

	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	local faction = client:GetCharacterFaction()

	if (!faction) then
		return false
	end

	for _, entry in pairs(factions) do
		if (entry == faction) then
			return true
		end
	end

	return false
end

function NETWORK.dialogue.ParseFactions(text)
	local list = {}

	if (!isstring(text) or text == "") then
		return list
	end

	for _, entry in ipairs(string.Explode(",", text)) do
		entry = string.Trim(string.lower(entry))

		if (entry != "" and NETWORK.factions.Get(entry)) then
			list[#list + 1] = entry
		end
	end

	return list
end

function NETWORK.dialogue.EntityAllows(entity, client)
	if (!IsValid(entity) or !entity.GetFactions) then
		return true
	end

	return NETWORK.dialogue.FactionAllowed(client,
		NETWORK.dialogue.ParseFactions(entity:GetFactions()))
end

function NETWORK.dialogue.GetStart(id, client)
	local data = NETWORK.dialogue.Get(id)

	if (!data) then
		return
	end

	local faction = IsValid(client) and client:GetCharacterFaction()

	if (faction and istable(data.starts) and isstring(data.starts[faction]) and
		data.nodes[data.starts[faction]]) then
		return data.starts[faction]
	end

	return data.start
end

function NETWORK.dialogue.GetReplies(id, node, client)
	local data = NETWORK.dialogue.GetNode(id, node)
	local list = {}

	if (!data) then
		return list
	end

	for index, reply in ipairs(data.replies or {}) do
		local bAllowed = true

		if (reply.condition) then
			bAllowed = reply.condition(client) != false
		end

		if (reply.quest and NETWORK.quest.Has(client, reply.quest)) then
			bAllowed = false
		end

		if (reply.complete and !NETWORK.quest.CanComplete(client, reply.complete)) then
			bAllowed = false
		end

		if (!NETWORK.dialogue.FactionAllowed(client, reply.factions)) then
			bAllowed = false
		end

		if (reply.unlock and istable(reply.unlock) and SERVER) then
			if (!NETWORK.dialogue.HasUnlockPrice(client, reply.unlock)) then
				bAllowed = false
			end
		end

		if (bAllowed) then
			list[#list + 1] = {index = index, text = reply.text}
		end
	end

	return list
end

function NETWORK.dialogue.LoadDirectory()
	local base = NETWORK.folder .. "/gamemode/dialogues"
	local files = file.Find(base .. "/*.lua", "LUA")

	for _, name in ipairs(files or {}) do
		local id = name:gsub("^sh_", ""):gsub("%.lua$", "")

		DIALOGUE = {}

		if (SERVER) then
			AddCSLuaFile(base .. "/" .. name)
		end

		include(base .. "/" .. name)

		NETWORK.dialogue.Register(id, DIALOGUE)

		DIALOGUE = nil
	end
end

function NETWORK.dialogue.CountItem(client, id)
	if (!SERVER or !IsValid(client) or !client:HasCharacter()) then
		return 0
	end

	local state = NETWORK.inventory.GetState(client)
	local total = 0

	for _, list in ipairs({"items", "storage"}) do
		for _, item in pairs(state[list]) do
			if (item.id == id) then
				total = total + (item.amount or 1)
			end
		end
	end

	return total
end

function NETWORK.dialogue.HasUnlockPrice(client, unlock)
	if (!istable(unlock) or !isstring(unlock.id) or unlock.id == "") then
		return false
	end

	return NETWORK.dialogue.CountItem(client, unlock.id) >=
		math.max(math.Round(tonumber(unlock.amount) or 1), 1)
end
