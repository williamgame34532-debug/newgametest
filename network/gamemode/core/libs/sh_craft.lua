NETWORK.craft = NETWORK.craft or {}

NETWORK.craft.maxRecipes = 24
NETWORK.craft.maxCost = 8
NETWORK.craft.maxTools = 4
NETWORK.craft.maxAmount = 99
NETWORK.craft.maxTime = 120
NETWORK.craft.maxXP = 100
NETWORK.craft.maxBatch = 20
NETWORK.craft.range = 120
NETWORK.craft.time = 2.5

NETWORK.craft.textLimit = 500

NETWORK.craft.classes = {
	nw_crafttable = {defaultTime = 2.5, storage = "table", fallbackName = "craftTitle"},
	nw_craft_table = {defaultTime = 5, storage = "text", fallbackName = "craftTableTitle"}
}

function NETWORK.craft.IsTable(entity)
	return IsValid(entity) and NETWORK.craft.classes[entity:GetClass()] != nil
end

function NETWORK.craft.GetClassInfo(entity)
	return IsValid(entity) and NETWORK.craft.classes[entity:GetClass()] or nil
end

function NETWORK.craft.GetTableName(entity)
	if (!IsValid(entity)) then
		return ""
	end

	if (entity:GetClass() == "nw_craft_table") then
		return entity:GetTitle()
	end

	return entity.GetTableName and entity:GetTableName() or ""
end

function NETWORK.craft.GetTableModel(entity)
	if (!IsValid(entity)) then
		return ""
	end

	if (entity:GetClass() == "nw_craft_table") then
		return entity:GetCraftModel()
	end

	return entity.GetTableModel and entity:GetTableModel() or ""
end

function NETWORK.craft.GetDisplayName(entity)
	local name = NETWORK.craft.GetTableName(entity)

	if (name != "") then
		return name
	end

	local info = NETWORK.craft.GetClassInfo(entity)

	return L(info and info.fallbackName or "craftTitle")
end

function NETWORK.craft.GetTime(recipe, entity)
	local info = NETWORK.craft.GetClassInfo(entity)
	local time = tonumber(recipe and recipe.time)

	if (!time or time <= 0) then
		time = info and info.defaultTime or NETWORK.craft.time
	end

	return math.Clamp(time, 0.5, NETWORK.craft.maxTime)
end

function NETWORK.craft.ParsePiece(text)
	text = string.lower(string.Trim(tostring(text or "")))

	if (text == "") then
		return
	end

	if (NETWORK.item.Get(text)) then
		return {id = text, amount = 1}
	end

	local id, amount = string.match(text, "^(%S+)%s*[x%*]%s*(%d+)$")

	if (!id) then
		id, amount = string.match(text, "^(%S+)%s+(%d+)$")
	end

	if (!id) then
		id, amount = text, 1
	end

	return {id = id, amount = math.Clamp(math.floor(tonumber(amount) or 1), 1,
		NETWORK.craft.maxAmount)}
end

local function Entry(source)
	if (isstring(source)) then
		return NETWORK.craft.ParsePiece(source)
	end

	if (!istable(source)) then
		return
	end

	local id = source.id or source[1]

	if (!isstring(id)) then
		return
	end

	id = string.lower(string.Trim(id))

	if (id == "" or string.find(id, "[%s:,=|]")) then
		return
	end

	return {id = id, amount = math.Clamp(math.floor(tonumber(source.amount or
		source[2]) or 1), 1, NETWORK.craft.maxAmount)}
end

local function List(source, limit)
	local list = {}
	local index = {}

	if (isstring(source)) then
		source = string.Explode(",", source)
	end

	if (!istable(source)) then
		return list
	end

	local raw = {}

	if (source[1] != nil) then
		for _, value in ipairs(source) do
			raw[#raw + 1] = Entry(value)
		end
	else
		for id, count in SortedPairs(source) do
			if (isstring(id)) then
				raw[#raw + 1] = Entry({id = id, amount = count})
			end
		end
	end

	for _, entry in ipairs(raw) do
		if (index[entry.id]) then
			local existing = index[entry.id]

			existing.amount = math.min(existing.amount + entry.amount,
				NETWORK.craft.maxAmount)
		elseif (#list < limit) then
			list[#list + 1] = entry
			index[entry.id] = entry
		end
	end

	return list
end

local function Optional(value, low, high, bFloat)
	value = tonumber(value)

	if (!value or value <= 0) then
		return nil
	end

	if (!bFloat) then
		value = math.floor(value)
	else
		value = math.Round(value * 10) / 10
	end

	value = math.Clamp(value, low, high)

	return value > 0 and value or nil
end

function NETWORK.craft.Normalize(raw)
	if (!istable(raw)) then
		return
	end

	local result

	if (istable(raw.result)) then
		result = Entry(raw.result)
	elseif (isstring(raw.result)) then
		result = Entry({id = raw.result, amount = raw.amount})
	end

	if (!result) then
		return
	end

	local maxSkill = NETWORK.skills and NETWORK.skills.maxLevel or 10

	return {
		result = result,
		cost = List(raw.cost, NETWORK.craft.maxCost),
		tools = List(raw.tools, NETWORK.craft.maxTools),
		time = Optional(raw.time, 0.5, NETWORK.craft.maxTime, true),
		skill = Optional(raw.skill, 1, maxSkill),
		xp = Optional(raw.xp, 1, NETWORK.craft.maxXP)
	}
end

function NETWORK.craft.Validate(recipe)
	if (!istable(recipe) or !istable(recipe.result)) then
		return false, "craftBadFormat"
	end

	if (!NETWORK.item.Get(recipe.result.id)) then
		return false, "craftUnknownItem", recipe.result.id
	end

	if (#(recipe.cost or {}) == 0) then
		return false, "craftNoCost"
	end

	for _, list in ipairs({recipe.cost or {}, recipe.tools or {}}) do
		for _, entry in ipairs(list) do
			if (!NETWORK.item.Get(entry.id)) then
				return false, "craftUnknownItem", entry.id
			end
		end
	end

	return true
end

function NETWORK.craft.Parse(line)
	line = string.Trim(line or "")

	if (line == "") then
		return
	end

	local segments = string.Explode("|", line)
	local left, right = string.match(segments[1], "^(.-)=(.*)$")

	if (!left) then
		return nil, "craftBadFormat"
	end

	local raw = {result = NETWORK.craft.ParsePiece(left), cost = {}}

	for _, part in ipairs(string.Explode(",", right)) do
		raw.cost[#raw.cost + 1] = NETWORK.craft.ParsePiece(part)
	end

	for index = 2, #segments do
		local key, value = string.match(segments[index], "^%s*(%a+)%s*:%s*(.-)%s*$")

		key = key and string.lower(key)

		if (key == "tools") then
			raw.tools = string.Explode(",", value)
		elseif (key == "time" or key == "skill" or key == "xp") then
			raw[key] = value
		end
	end

	local recipe = NETWORK.craft.Normalize(raw)

	if (!recipe) then
		return nil, "craftBadFormat"
	end

	local bValid, reason, extra = NETWORK.craft.Validate(recipe)

	if (!bValid) then
		return nil, reason, extra
	end

	return recipe
end

local function Piece(entry, separator)
	return entry.amount > 1 and (entry.id .. separator .. entry.amount) or entry.id
end

local function Join(list, separator, pieceSeparator)
	local parts = {}

	for _, entry in ipairs(list or {}) do
		parts[#parts + 1] = Piece(entry, pieceSeparator)
	end

	return table.concat(parts, separator)
end

function NETWORK.craft.ToLine(recipe)
	if (!recipe or !recipe.result) then
		return ""
	end

	local line = Piece(recipe.result, " x") .. " = " .. Join(recipe.cost, ", ", " x")

	if (#(recipe.tools or {}) > 0) then
		line = line .. " | tools: " .. Join(recipe.tools, ", ", " x")
	end

	for _, key in ipairs({"time", "skill", "xp"}) do
		if (recipe[key]) then
			line = line .. " | " .. key .. ": " .. recipe[key]
		end
	end

	return line
end

function NETWORK.craft.ParseWorkbenchLine(line)
	line = string.Trim(line or "")

	if (line == "") then
		return
	end

	local parts = string.Explode(":", line)

	if (#parts < 2) then
		return nil, "craftBadFormat"
	end

	local recipe = NETWORK.craft.Normalize({
		result = NETWORK.craft.ParsePiece(parts[1]),
		cost = string.Explode(",", parts[2]),
		time = string.Trim(parts[3] or ""),
		tools = string.Explode(",", parts[4] or ""),
		skill = string.Trim(parts[5] or ""),
		xp = string.Trim(parts[6] or "")
	})

	if (!recipe) then
		return nil, "craftBadFormat"
	end

	return recipe
end

function NETWORK.craft.ToWorkbenchLine(recipe)
	if (!recipe or !recipe.result) then
		return ""
	end

	local parts = {
		Piece(recipe.result, "*"),
		Join(recipe.cost, ",", "*"),
		recipe.time and tostring(recipe.time) or "",
		Join(recipe.tools, ",", "*"),
		recipe.skill and tostring(recipe.skill) or "",
		recipe.xp and tostring(recipe.xp) or ""
	}

	while (#parts > 2 and parts[#parts] == "") do
		parts[#parts] = nil
	end

	return table.concat(parts, ":")
end

function NETWORK.craft.ParseWorkbench(text, bKeepBroken)
	local list = {}
	local skipped = 0

	for _, line in ipairs(string.Explode("\n", text or "")) do
		local recipe = NETWORK.craft.ParseWorkbenchLine(line)

		if (recipe) then
			if (bKeepBroken or NETWORK.craft.Validate(recipe)) then
				list[#list + 1] = recipe
			else
				skipped = skipped + 1
			end
		elseif (string.Trim(line) != "") then
			skipped = skipped + 1
		end
	end

	return list, skipped
end

function NETWORK.craft.ToWorkbenchText(list, limit)
	limit = limit or NETWORK.craft.textLimit

	local lines = {}
	local length = 0
	local dropped = 0

	for _, recipe in ipairs(list or {}) do
		local line = NETWORK.craft.ToWorkbenchLine(recipe)
		local added = string.len(line) + (#lines > 0 and 1 or 0)

		if (length + added <= limit) then
			lines[#lines + 1] = line
			length = length + added
		else
			dropped = dropped + 1
		end
	end

	return table.concat(lines, "\n"), dropped
end

function NETWORK.craft.Count(state, id)
	local total = 0

	for _, item in pairs(istable(state) and state.items or {}) do
		if (istable(item) and item.id == id) then
			total = total + (item.amount or 1)
		end
	end

	return total
end

function NETWORK.craft.Needs(recipe)
	local needs = {}

	for _, entry in ipairs(recipe and recipe.cost or {}) do
		needs[entry.id] = needs[entry.id] or {cost = 0, tool = 0}
		needs[entry.id].cost = needs[entry.id].cost + entry.amount
	end

	for _, entry in ipairs(recipe and recipe.tools or {}) do
		needs[entry.id] = needs[entry.id] or {cost = 0, tool = 0}
		needs[entry.id].tool = math.max(needs[entry.id].tool, entry.amount)
	end

	return needs
end

function NETWORK.craft.MaxBatch(state, recipe, cap)
	local best = cap or NETWORK.craft.maxBatch

	for id, need in pairs(NETWORK.craft.Needs(recipe)) do
		local have = NETWORK.craft.Count(state, id)

		if (need.cost > 0) then
			best = math.min(best, math.floor((have - need.tool) / need.cost))
		elseif (have < need.tool) then
			return 0
		end
	end

	return math.max(best, 0)
end

function NETWORK.craft.CanAfford(state, recipe)
	return NETWORK.craft.MaxBatch(state, recipe, 1) >= 1
end

function NETWORK.craft.HasSkill(client, recipe)
	local need = recipe and recipe.skill or 0

	if (need <= 0 or !NETWORK.skills or !NETWORK.skills.Get) then
		return true
	end

	return NETWORK.skills.Get(client, "crafting") >= need
end
