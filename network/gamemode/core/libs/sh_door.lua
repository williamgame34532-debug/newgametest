NETWORK.door = NETWORK.door or {}
NETWORK.door.list = NETWORK.door.list or {}

NETWORK.door.classes = {
	prop_door_rotating = true,
	func_door = true,
	func_door_rotating = true,
	prop_dynamic = false
}

NETWORK.door.types = {
	{id = "public", name = "doorPublic", color = Color(158, 172, 186)},
	{id = "residential", name = "doorResidential", color = Color(120, 200, 255)},
	{id = "business", name = "doorBusiness", color = Color(240, 200, 90)},
	{id = "faction", name = "doorFaction", color = Color(226, 96, 96)}
}

function NETWORK.door.GetType(id)
	for _, data in ipairs(NETWORK.door.types) do
		if (data.id == id) then
			return data
		end
	end

	return NETWORK.door.types[1]
end

function NETWORK.door.ParseFactions(raw)
	raw = string.lower(raw or "")

	if (raw == "") then
		return nil
	end

	local list = {}
	local seen = {}

	local function Add(id)
		if (!seen[id]) then
			seen[id] = true
			list[#list + 1] = id
		end
	end

	for token in string.gmatch(raw, "[^,%+%s]+") do
		if (token == "alliance") then
			for id, faction in pairs(NETWORK.factions.stored or {}) do
				if (faction.bCombine) then
					Add(id)
				end
			end
		elseif (NETWORK.factions.Get(token)) then
			Add(token)
		else
			return nil, token
		end
	end

	if (#list == 0) then
		return nil, raw
	end

	table.sort(list)

	return list
end

function NETWORK.door.IsFactionDoor(entity)

	if (!NETWORK.door.IsDoor(entity)) then
		return false
	end

	local data = NETWORK.door.GetData and NETWORK.door.GetData(entity)

	if (!data) then
		return false
	end

	return #NETWORK.door.GetFactions(data) > 0
end

function NETWORK.door.GetFactions(data)
	if (!data) then
		return nil
	end

	if (istable(data.factions) and #data.factions > 0) then
		return data.factions
	end

	if (data.faction and data.faction != "") then
		return {data.faction}
	end

	return nil
end

function NETWORK.door.IsDoor(entity)
	return IsValid(entity) and NETWORK.door.classes[entity:GetClass()] == true
end

function NETWORK.door.GetKey(entity)
	if (!NETWORK.door.IsDoor(entity)) then
		return
	end

	local id = entity:MapCreationID()

	if (id and id > 0) then
		return game.GetMap() .. ":" .. id
	end

	local position = entity:GetPos()

	return string.format("%s:%d_%d_%d", game.GetMap(), math.Round(position.x),
		math.Round(position.y), math.Round(position.z))
end

function NETWORK.door.GetLeaves(entity)

	if (!IsValid(entity)) then
		return {}
	end

	local leaves = {entity}
	local seen = {[entity] = true}
	local partner = entity.GetDoorPartner and entity:GetDoorPartner()

	if (IsValid(partner) and !seen[partner]) then
		seen[partner] = true
		leaves[#leaves + 1] = partner
	end

	local class = entity:GetClass()

	if (class == "func_door" or class == "func_door_rotating") then

		local name = entity.GetName and entity:GetName() or ""

		if (name != "") then
			for _, other in ipairs(ents.FindByName(name)) do
				if (!seen[other] and NETWORK.door.IsDoor(other)) then
					seen[other] = true
					leaves[#leaves + 1] = other
				end
			end
		end
	end

	return leaves
end

function NETWORK.door.GetData(entity)
	if (!IsValid(entity)) then
		return nil, nil
	end

	local key = NETWORK.door.GetKey(entity)

	for _, leaf in ipairs(NETWORK.door.GetLeaves(entity)) do
		local leafKey = NETWORK.door.GetKey(leaf)
		local data = leafKey and NETWORK.door.list[leafKey]

		if (data) then
			local depth = 0

			while (data and data.linkKey and NETWORK.door.list[data.linkKey] and depth < 8) do
				data = NETWORK.door.list[data.linkKey]
				depth = depth + 1
			end

			return data, key
		end
	end

	return nil, key
end

function NETWORK.door.IsLocked(data)
	if (!data) then
		return false
	end

	if (data.bLocked != nil) then
		return data.bLocked == true
	end

	return data.type == "faction"
end

function NETWORK.door.ShouldShow(data)
	return data != nil and data.bShow != false
end

function NETWORK.door.Describe(data)
	if (!data) then
		return
	end

	local parts = {L(NETWORK.door.GetType(data.type).name)}

	if (data.block and data.block != "") then
		parts[#parts + 1] = data.block
	end

	if (data.number and data.number != "") then
		parts[#parts + 1] = L("doorNumber") .. " " .. data.number
	end

	return table.concat(parts, "  ·  ")
end

NETWORK.door.housingCapacity = 3

function NETWORK.door.GetOwners(data)
	if (!istable(data)) then
		return {}
	end

	if (istable(data.owners)) then
		return data.owners
	end

	if (data.owner) then
		return {[data.owner] = {name = data.ownerName, char = data.ownerChar,
			faction = data.ownerFaction}}
	end

	return {}
end

function NETWORK.door.OwnerCount(data)
	return table.Count(NETWORK.door.GetOwners(data))
end

function NETWORK.door.IsOwner(data, steamID)
	if (!istable(data) or !steamID) then
		return false
	end

	if (data.owner == steamID) then
		return true
	end

	return istable(data.owners) and data.owners[steamID] != nil
end

function NETWORK.door.HasOwner(data)
	return NETWORK.door.OwnerCount(data) > 0
end

function NETWORK.door.GetRootKey(entity)
	for _, leaf in ipairs(NETWORK.door.GetLeaves(entity)) do
		local key = NETWORK.door.GetKey(leaf)
		local data = key and NETWORK.door.list[key]

		if (data) then
			local depth = 0

			while (data.linkKey and NETWORK.door.list[data.linkKey] and depth < 8) do
				key = data.linkKey
				data = NETWORK.door.list[key]
				depth = depth + 1
			end

			return key, data
		end
	end
end

function NETWORK.door.CanLend(data)
	return istable(data) and (data.type == "residential" or data.type == "business")
end

function NETWORK.door.GetOwned(steamID)
	local list = {}
	local seen = {}

	if (!steamID) then
		return list
	end

	for key, data in pairs(NETWORK.door.list) do
		if (!istable(data) or data.linkKey or seen[data]) then
			continue
		end

		seen[data] = true

		if (NETWORK.door.IsOwner(data, steamID)) then
			list[#list + 1] = {key = key, data = data}
		end
	end

	table.sort(list, function(a, b)
		return a.key < b.key
	end)

	return list
end

function NETWORK.door.GetTitle(data)
	if (!data) then
		return ""
	end

	if (data.title and data.title != "") then
		return data.title
	end

	return NETWORK.door.Describe(data) or ""
end

local function Field(value)
	if (value == nil) then
		return ""
	end

	return string.Trim(tostring(value))
end

function NETWORK.door.GetHousingName(data)
	if (!istable(data)) then
		return ""
	end

	local title = Field(data.title)

	if (title != "") then
		return title
	end

	local legacy = Field(data.name)

	if (legacy != "") then
		return legacy
	end

	local parts = {}
	local block = Field(data.block)
	local number = Field(data.number)

	if (block != "") then
		parts[#parts + 1] = block
	end

	if (number != "") then
		parts[#parts + 1] = L("doorNumber") .. " " .. number
	end

	return table.concat(parts, "  ·  ")
end
