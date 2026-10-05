NETWORK.recruiter = NETWORK.recruiter or {}

NETWORK.recruiter.configs = NETWORK.recruiter.configs or {}

NETWORK.recruiter.maxEntries = 12
NETWORK.recruiter.maxSpawns = 12
NETWORK.recruiter.maxFeatures = 8
NETWORK.recruiter.range = 200

function NETWORK.recruiter.Get(id)
	return NETWORK.recruiter.configs[id]
end

function NETWORK.recruiter.Clean(data)
	local clean = {
		name = NETWORK.util.Sanitise(data.name, 48),
		entries = {}
	}

	for _, entry in pairs(data.entries or {}) do
		if (#clean.entries >= NETWORK.recruiter.maxEntries) then
			break
		end

		if (!NETWORK.factions.Get(entry.faction)) then
			continue
		end

		local features = {}
		local spawns = {}

		for index = 1, NETWORK.recruiter.maxFeatures * 2 do
			local line = (entry.features or {})[index]

			if (#features >= NETWORK.recruiter.maxFeatures) then
				break
			end

			if (!isstring(line)) then
				continue
			end

			line = NETWORK.util.Sanitise(line, 90)

			if (line != "") then
				features[#features + 1] = line
			end
		end

		for _, spawn in pairs(entry.spawns or {}) do
			if (#spawns >= NETWORK.recruiter.maxSpawns) then
				break
			end

			local position = spawn.pos

			if (!istable(position) or #position < 3) then
				continue
			end

			spawns[#spawns + 1] = {
				name = NETWORK.util.Sanitise(spawn.name, 40),
				pos = {
					tonumber(position[1]) or 0,
					tonumber(position[2]) or 0,
					tonumber(position[3]) or 0
				},
				yaw = tonumber(spawn.yaw) or 0
			}
		end

		local class = isstring(entry.class) and
			string.lower(string.Trim(entry.class)) or ""

		local uniform = isstring(entry.uniform) and
			string.lower(string.Trim(entry.uniform)) or ""

		if (uniform != "" and !NETWORK.item.Get(uniform)) then
			uniform = ""
		end

		if (class != "") then
			local classTable = NETWORK.classes and NETWORK.classes.Get and
				NETWORK.classes.Get(class)

			if (!classTable or classTable.faction != entry.faction) then
				class = ""
			end
		end

		clean.entries[#clean.entries + 1] = {
			faction = entry.faction,
			class = class,
			uniform = uniform,
			title = NETWORK.util.Sanitise(entry.title, 40),
			subtitle = NETWORK.util.Sanitise(entry.subtitle, 60),
			description = NETWORK.util.Sanitise(entry.description, 400, true),
			model = isstring(entry.model) and
				string.sub(string.Trim(entry.model), 1, 400) or "",
			limit = math.Clamp(math.Round(tonumber(entry.limit) or 0), 0, 64),
			features = features,
			spawns = spawns
		}
	end

	return clean
end

function NETWORK.recruiter.CountFaction(id)
	local total = 0

	for _, client in ipairs(player.GetAll()) do
		if (client:HasCharacter() and client:GetCharacterFaction() == id) then
			total = total + 1
		end
	end

	return total
end

function NETWORK.recruiter.IsFull(entry)
	if (!entry or (entry.limit or 0) <= 0) then
		return false
	end

	return NETWORK.recruiter.CountFaction(entry.faction) >= entry.limit
end

function NETWORK.recruiter.GetEntry(config, key)
	local entries = config and config.entries or {}
	local index = tonumber(key)

	if (index) then
		return entries[index], index
	end

	for entryIndex, entry in ipairs(entries) do
		if (entry.faction == key) then
			return entry, entryIndex
		end
	end
end

function NETWORK.recruiter.ModelList(entry)
	local list = {}
	local raw = entry and entry.model or ""

	if (!isstring(raw) or raw == "") then
		return list
	end

	for _, path in ipairs(string.Explode("[,;\n]", raw, true)) do
		path = string.Trim(path)

		if (path != "") then
			list[#list + 1] = path
		end
	end

	return list
end

local function ModelNumber(path)
	local name = string.lower(string.GetFileFromFilename(path or "") or "")
	local digits = string.match(name, "(%d+)%s*%.mdl$") or string.match(name, "(%d+)")
	local number = tonumber(digits)

	if (number) then
		return number
	end

	local sum = 0

	for index = 1, #name do
		sum = sum + string.byte(name, index) * index
	end

	return sum
end

function NETWORK.recruiter.PickModel(entry, factionTable, current)
	local pool = NETWORK.recruiter.ModelList(entry)

	if (#pool == 0) then
		pool = factionTable and factionTable.models or {}
	end

	current = current or ""

	if (#pool == 0) then
		return current
	end

	for _, path in ipairs(pool) do
		if (string.lower(path) == string.lower(current)) then
			return current
		end
	end

	return pool[ModelNumber(current) % #pool + 1]
end
