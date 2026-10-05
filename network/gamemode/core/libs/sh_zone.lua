NETWORK.zone = NETWORK.zone or {}
NETWORK.zone.list = NETWORK.zone.list or {}

NETWORK.zone.types = {
	{id = "neutral", name = "zoneNeutral", color = Color(150, 170, 190)},
	{id = "toxic", name = "zoneToxic", color = Color(126, 214, 92)},
	{id = "loot", name = "zoneLoot", color = Color(240, 190, 84)},
	{id = "npc", name = "zoneNpc", color = Color(226, 96, 96)},

	{id = "outlands", name = "zoneOutlands", color = Color(214, 150, 70)},

	{id = "radiation", name = "zoneRadiation", color = Color(222, 208, 70)}
}

NETWORK.zone.hazards = {
	toxic = {damageType = DMG_NERVEGAS, level = "nwToxicLevel"},
	radiation = {damageType = DMG_RADIATION, level = "nwRadLevel"}
}

function NETWORK.zone.IsHazard(zone)
	return istable(zone) and NETWORK.zone.hazards[zone.type or ""] != nil
end

function NETWORK.zone.IsToxicImmune(client)
	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
		return false
	end

	if ((client.IsCombine and client:IsCombine()) or
		(client.IsCWUMember and client:IsCWUMember())) then
		return true, "faction"
	end

	if (client:GetNWBool("nwGasmask", false) and
		client:GetNWFloat("nwGasmaskFilter", 0) > os.time()) then
		return true, "mask"
	end

	local state

	if (SERVER) then
		state = NETWORK.inventory and NETWORK.inventory.GetState and
			NETWORK.inventory.GetState(client)
	elseif (client == LocalPlayer()) then
		state = NETWORK.inventory and NETWORK.inventory.state
	end

	local worn = state and state.equipped and state.equipped.mask
	local base = istable(worn) and NETWORK.item and NETWORK.item.Get(worn.id)

	if (base and base.gasProtection) then
		return true, "mask"
	end

	return false
end

NETWORK.zone.icons = {
	"home", "apartment", "factory", "local_hospital", "store", "storefront",
	"warning", "park", "forest", "terrain", "train", "local_police",
	"restaurant", "school", "location_city", "science", "coronavirus",
	"shield", "map", "flag", "lock"
}

function NETWORK.zone.GetType(id)
	for _, data in ipairs(NETWORK.zone.types) do
		if (data.id == id) then
			return data
		end
	end

	return NETWORK.zone.types[1]
end

function NETWORK.zone.Default()
	return {
		id = 0,
		name = "Новая зона",
		type = "neutral",
		icon = "",
		mins = {0, 0, 0},
		maxs = {0, 0, 0},
		greeting = "",
		fog = true,
		damage = 4,
		interval = 2,
		items = {},
		total = 12,
		batch = 3,
		spawnInterval = 60
	}
end

function NETWORK.zone.GetMins(zone)
	return Vector(zone.mins[1], zone.mins[2], zone.mins[3])
end

function NETWORK.zone.GetMaxs(zone)
	return Vector(zone.maxs[1], zone.maxs[2], zone.maxs[3])
end

function NETWORK.zone.Contains(zone, position)
	local mins = NETWORK.zone.GetMins(zone)
	local maxs = NETWORK.zone.GetMaxs(zone)

	return position:WithinAABox(mins, maxs)
end

function NETWORK.zone.ContainsEntity(zone, entity)
	if (!IsValid(entity)) then
		return false
	end

	local mins = NETWORK.zone.GetMins(zone)
	local maxs = NETWORK.zone.GetMaxs(zone)
	local position = entity:GetPos()
	local entityMins = position + entity:OBBMins()
	local entityMaxs = position + entity:OBBMaxs()

	return entityMins.x <= maxs.x and entityMaxs.x >= mins.x and
		entityMins.y <= maxs.y and entityMaxs.y >= mins.y and
		entityMins.z <= maxs.z and entityMaxs.z >= mins.z
end

local function Volume(zone)
	local mins = NETWORK.zone.GetMins(zone)
	local maxs = NETWORK.zone.GetMaxs(zone)

	return math.max(maxs.x - mins.x, 1) * math.max(maxs.y - mins.y, 1) *
		math.max(maxs.z - mins.z, 1)
end

local function Better(candidate, best)
	if (!best) then
		return true
	end

	local candidatePriority = tonumber(candidate.priority) or 0
	local bestPriority = tonumber(best.priority) or 0

	if (candidatePriority != bestPriority) then
		return candidatePriority > bestPriority
	end

	return Volume(candidate) < Volume(best)
end

function NETWORK.zone.At(position)
	local best

	for _, zone in pairs(NETWORK.zone.list) do
		if (NETWORK.zone.Contains(zone, position) and Better(zone, best)) then
			best = zone
		end
	end

	return best
end

function NETWORK.zone.AtEntity(entity)
	local best

	for _, zone in pairs(NETWORK.zone.list) do
		if (NETWORK.zone.ContainsEntity(zone, entity) and Better(zone, best)) then
			best = zone
		end
	end

	return best
end

function NETWORK.zone.Normalise(zone)
	local a = NETWORK.zone.GetMins(zone)
	local b = NETWORK.zone.GetMaxs(zone)

	zone.mins = {math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z)}
	zone.maxs = {math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z)}

	return zone
end

function NETWORK.zone.IsOutlands(position)
	local zone = NETWORK.zone.At(position)

	return zone != nil and zone.type == "outlands"
end
