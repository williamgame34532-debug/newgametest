NETWORK.itemedit = NETWORK.itemedit or {}
NETWORK.itemedit.stored = NETWORK.itemedit.stored or {}
NETWORK.itemedit.original = NETWORK.itemedit.original or {}

local E = NETWORK.itemedit

E.fields = {"model", "bodygroups", "weaponClass"}

function E.Clean(payload)
	if (!istable(payload)) then
		return nil
	end

	local clean = {}

	if (isstring(payload.model) and payload.model != "" and #payload.model < 200) then
		clean.model = payload.model
	end

	if (isstring(payload.weaponClass) and payload.weaponClass != "" and
		#payload.weaponClass < 64) then
		clean.weaponClass = payload.weaponClass
	end

	if (istable(payload.bodygroups)) then
		local groups = {}
		local count = 0

		for id, value in pairs(payload.bodygroups) do
			local index = tonumber(id)
			local number = tonumber(value)

			if (index and number and index >= 0 and index < 32 and number >= 0 and number < 64) then
				groups[math.floor(index)] = math.floor(number)
				count = count + 1
			end
		end

		if (count > 0) then
			clean.bodygroups = groups
		end
	end

	if (next(clean) == nil) then
		return nil
	end

	return clean
end

function E.ParseBodygroups(text)
	local groups = {}

	for id, value in string.gmatch(tostring(text or ""), "(%d+)%s*[=:]%s*(%d+)") do
		groups[tonumber(id)] = tonumber(value)
	end

	return groups
end

function E.FormatBodygroups(groups)
	local parts = {}

	for id, value in pairs(groups or {}) do
		parts[#parts + 1] = tostring(id) .. "=" .. tostring(value)
	end

	table.sort(parts)

	return table.concat(parts, ", ")
end

function E.Restore(id)
	local base = NETWORK.item.Get(id)
	local original = E.original[id]

	if (!base or !original) then
		return
	end

	for _, field in ipairs(E.fields) do
		base[field] = original[field]
	end
end

function E.ApplyOne(id, data)
	local base = NETWORK.item.Get(id)

	if (!base) then
		return
	end

	if (!E.original[id]) then
		E.original[id] = {}

		for _, field in ipairs(E.fields) do
			E.original[id][field] = istable(base[field]) and table.Copy(base[field]) or base[field]
		end
	end

	E.Restore(id)

	if (data.model) then
		base.model = data.model
	end

	if (data.weaponClass) then
		base.weaponClass = data.weaponClass
	end

	if (istable(data.bodygroups)) then
		local groups = {}

		for key, value in pairs(data.bodygroups) do
			groups[tonumber(key) or key] = tonumber(value) or value
		end

		base.bodygroups = groups
	end
end

function E.ApplyAll()
	for id in pairs(E.original) do
		if (!E.stored[id]) then
			E.Restore(id)
		end
	end

	for id, data in pairs(E.stored) do
		E.ApplyOne(id, data)
	end

	hook.Run("NetworkItemsEdited")
end

function E.Get(id)
	return E.stored[id]
end

E.custom = E.custom or {}

E.maxCustom = 400
E.idMin = 3
E.idMax = 32

E.specs = {
	name = {kind = "text", max = 48, bRequired = true},
	description = {kind = "multiline", max = 600},
	model = {kind = "model", bRequired = true},
	width = {kind = "int", min = 1, max = 4, default = 1},
	height = {kind = "int", min = 1, max = 4, default = 1},
	weight = {kind = "number", min = 0, max = 50, step = 0.05, decimals = 2, default = 0.5},
	maxStack = {kind = "int", min = 1, max = 99, default = 1},
	rarity = {kind = "choice", default = "common"},
	category = {kind = "choice", default = "misc"},
	price = {kind = "int", min = 0, max = 100000, step = 5, default = 0},
	bContraband = {kind = "tri"},
	dropTag = {kind = "choice", options = {"", "keep", "drop", "destroy"}},
	useLabel = {kind = "choice", options = {"", "itemUse", "itemEat", "itemDrink",
		"itemApply", "itemTake", "itemInject", "itemRead", "itemWear", "itemLoad"}},
	useSound = {kind = "sound"},
	factions = {kind = "factions"},

	hunger = {kind = "int", min = -100, max = 100, step = 5, default = 0},
	thirst = {kind = "int", min = -100, max = 100, step = 5, default = 0},
	spoilRate = {kind = "number", min = 0, max = 10, step = 0.1, decimals = 1, default = 0},
	bNoSpoil = {kind = "bool"},
	trash = {kind = "itemid"},

	contents = {kind = "contents"},
	tokens = {kind = "int", min = 0, max = 1000, default = 0},

	equipSlot = {kind = "choice"},
	protection = {kind = "number", min = 0, max = 0.95, step = 0.05, decimals = 2, default = 0.5},
	maxUses = {kind = "int", min = 1, max = 1000, step = 10, default = 100},
	armourClass = {kind = "choice", options = {"light", "medium", "heavy"}, default = "medium"},
	bodygroups = {kind = "bodygroups"},
	skin = {kind = "int", min = 0, max = 63, default = 0},
	replaceModel = {kind = "model"},
	radProtection = {kind = "number", min = 0, max = 0.9, step = 0.05, decimals = 2, default = 0},
	gasProtection = {kind = "bool"},

	storageSlots = {kind = "int", min = 1, max = 16, default = 8},
	storageBlacklist = {kind = "itemlist"},

	weaponClass = {kind = "class", max = 48, bRequired = true},
	bConsumeOnEquip = {kind = "bool"},

	ammoType = {kind = "class", max = 32, bRequired = true},
	ammoAmount = {kind = "int", min = 1, max = 500, step = 5, default = 30},

	healWound = {kind = "int", min = 0, max = 100, step = 5, default = 25},
	useCooldown = {kind = "int", min = 0, max = 600, step = 5, default = 0}
}

E.common = {"name", "description", "model", "width", "height", "weight", "maxStack",
	"rarity", "category", "price", "bContraband", "dropTag", "useLabel", "factions"}

E.bases = {
	{id = "misc", icon = "icon16/brick.png", category = "misc", fields = {}},
	{id = "food", icon = "icon16/cake.png", category = "food", bLockCategory = true,
		fields = {"hunger", "thirst", "spoilRate", "bNoSpoil", "trash", "useSound"},
		defaults = {hunger = 25, maxStack = 5}},
	{id = "drink", icon = "icon16/drink.png", category = "food", bLockCategory = true,
		fields = {"thirst", "hunger", "spoilRate", "bNoSpoil", "trash", "useSound"},
		defaults = {thirst = 50, bNoSpoil = true, maxStack = 5}},
	{id = "pack", icon = "icon16/box.png", category = "rations",
		fields = {"contents", "tokens", "useSound"},
		defaults = {width = 2}},
	{id = "equipment", icon = "icon16/lightbulb.png", category = "misc", bEquip = true,
		fields = {"equipSlot"}, slots = {"light", "radio", "watch"},
		defaults = {equipSlot = "light"}},
	{id = "armour", icon = "icon16/shield.png", category = "armour", bEquip = true,
		fields = {"equipSlot", "protection", "maxUses", "armourClass", "bodygroups", "skin",
			"radProtection"},
		slots = {"armour", "helmet"},
		defaults = {equipSlot = "armour", protection = 0.5, maxUses = 100,
			armourClass = "medium", width = 2, height = 2}},
	{id = "clothing", icon = "icon16/user_suit.png", category = "clothing", bEquip = true,
		fields = {"equipSlot", "bodygroups", "skin", "replaceModel", "radProtection",
			"gasProtection"},
		slots = {"jacket", "pants", "hat", "mask", "glasses", "vest", "gloves", "boots"},
		defaults = {equipSlot = "jacket", width = 2, height = 2}},
	{id = "container", icon = "icon16/package.png", category = "container", bEquip = true,
		fields = {"equipSlot", "storageSlots", "storageBlacklist", "bodygroups"},
		slots = {"backpack"},
		defaults = {equipSlot = "backpack", storageSlots = 8, width = 2, height = 2}},
	{id = "weapon", icon = "icon16/gun.png", category = "weapon", bEquip = true,
		fields = {"weaponClass", "equipSlot", "bConsumeOnEquip"},
		slots = {"primary", "secondary", "melee"},
		defaults = {equipSlot = "secondary", width = 2}},
	{id = "ammo", icon = "icon16/bullet_yellow.png", category = "ammo",
		fields = {"ammoType", "ammoAmount"},
		defaults = {ammoType = "Pistol", ammoAmount = 30, maxStack = 3}},
	{id = "medical", icon = "icon16/heart.png", category = "medical",
		fields = {"healWound", "useCooldown", "useSound"},
		defaults = {healWound = 25, maxStack = 4}}
}

E.baseIndex = {}

for _, base in ipairs(E.bases) do
	E.baseIndex[base.id] = base
end

function E.GetBase(id)
	return E.baseIndex[id] or E.baseIndex.misc
end

function E.IsCustom(id)
	return isstring(id) and E.custom[id] != nil
end

function E.GetCategories()
	local seen = {}
	local list = {}

	local function Add(id)
		if (isstring(id) and id != "" and !seen[id]) then
			seen[id] = true
			list[#list + 1] = id
		end
	end

	for _, base in ipairs(NETWORK.item.GetAll()) do
		if (!base.bCustom) then
			Add(base.category)
		end
	end

	for _, base in ipairs(E.bases) do
		Add(base.category)
	end

	table.sort(list)

	return list
end

function E.GetOptions(field, baseID)
	local spec = E.specs[field]

	if (field == "rarity") then
		return table.Copy(NETWORK.inventory.rarityOrder or {"common"})
	elseif (field == "category") then
		local base = E.GetBase(baseID)

		if (base.bLockCategory) then
			return {base.category}
		end

		return E.GetCategories()
	elseif (field == "equipSlot") then
		return table.Copy(E.GetBase(baseID).slots or {})
	end

	return spec and spec.options or {}
end

local function Contains(list, value)
	for _, entry in ipairs(list or {}) do
		if (entry == value) then
			return true
		end
	end

	return false
end

function E.IsModelPath(path)
	if (!isstring(path) or #path < 12 or #path > 160) then
		return false
	end

	path = string.lower(path)

	if (string.find(path, "..", 1, true) or string.find(path, "//", 1, true) or
		string.find(path, "\\", 1, true)) then
		return false
	end

	return string.match(path, "^models/[%w_%-%./]+%.mdl$") != nil
end

function E.IsSoundPath(path)
	if (!isstring(path) or #path < 5 or #path > 160) then
		return false
	end

	if (string.find(path, "..", 1, true) or string.find(path, "\\", 1, true)) then
		return false
	end

	path = string.lower(path)

	local extension = string.match(path, "^[%w_%-%./]+%.(%w+)$")

	return extension == "wav" or extension == "mp3" or extension == "ogg"
end

function E.IsValidID(id)
	return isstring(id) and #id >= E.idMin and #id <= E.idMax and
		string.match(id, "^[a-z][a-z0-9_]*$") != nil
end

local function IsItemRef(id, selfID)
	return isstring(id) and id != "" and id != selfID and NETWORK.item.Get(id) != nil
end

local function ParseIDList(value, selfID, limit)
	local list = {}
	local seen = {}

	if (isstring(value)) then
		value = string.Explode(",", value)
	end

	for _, entry in ipairs(istable(value) and value or {}) do
		local id = string.lower(string.Trim(tostring(entry)))

		if (IsItemRef(id, selfID) and !seen[id]) then
			seen[id] = true
			list[#list + 1] = id

			if (#list >= limit) then
				break
			end
		end
	end

	return list
end

function E.ParseContents(value, selfID)
	local list = {}

	if (isstring(value)) then
		local parsed = {}

		for _, part in ipairs(string.Explode(",", value)) do

			part = string.gsub(string.Trim(part), "х", "x")

			local id, count = string.match(part, "^([%w_]+)%s*[x%*]?%s*(%d*)$")

			if (id) then
				parsed[#parsed + 1] = {string.lower(id), tonumber(count) or 1}
			end
		end

		value = parsed
	end

	local total = 0

	for _, entry in ipairs(istable(value) and value or {}) do
		local id = istable(entry) and (entry[1] or entry.id) or entry
		local count = istable(entry) and tonumber(entry[2] or entry.count) or 1

		id = isstring(id) and string.lower(id) or nil
		count = math.Clamp(math.floor(count or 1), 1, 10)

		if (IsItemRef(id, selfID) and total + count <= 24) then
			list[#list + 1] = {id, count}
			total = total + count
		end
	end

	return list
end

function E.FormatContents(list)
	local parts = {}

	for _, entry in ipairs(list or {}) do
		local id = istable(entry) and entry[1] or entry
		local count = istable(entry) and tonumber(entry[2]) or 1

		parts[#parts + 1] = count > 1 and (id .. " x" .. count) or tostring(id)
	end

	return table.concat(parts, ", ")
end

local function CleanNumber(spec, value)
	local number = tonumber(value)

	if (!number or number != number) then
		number = spec.default or spec.min or 0
	end

	number = math.Clamp(number, spec.min, spec.max)

	if (spec.kind == "int") then
		return math.floor(number + 0.5)
	end

	local scale = 10 ^ (spec.decimals or 2)

	return math.floor(number * scale + 0.5) / scale
end

function E.CleanCustom(id, payload, options)
	options = options or {}

	if (!istable(payload)) then
		return nil, "itemCreateErrPayload"
	end

	local base = E.GetBase(payload.base)
	local clean = {base = base.id}
	local fields = {}

	for _, field in ipairs(E.common) do
		fields[#fields + 1] = field
	end

	for _, field in ipairs(base.fields) do
		fields[#fields + 1] = field
	end

	for _, field in ipairs(fields) do
		local spec = E.specs[field]
		local value = payload[field]
		local kind = spec.kind

		if (kind == "text" or kind == "multiline") then
			value = NETWORK.util.Sanitise(isstring(value) and value or "", spec.max,
				kind == "multiline")

			if (value != "") then
				clean[field] = value
			elseif (spec.bRequired) then
				return nil, "itemCreateErrRequired", field
			end
		elseif (kind == "model") then
			value = isstring(value) and string.lower(string.Trim(value)) or ""

			if (value != "") then
				if (!E.IsModelPath(value)) then
					return nil, "itemCreateErrModel", field
				end

				clean[field] = value
			elseif (spec.bRequired) then
				return nil, "itemCreateErrRequired", field
			end
		elseif (kind == "sound") then
			value = isstring(value) and string.Trim(value) or ""

			if (value != "") then
				if (!E.IsSoundPath(value)) then
					return nil, "itemCreateErrSound", field
				end

				clean[field] = value
			end
		elseif (kind == "int" or kind == "number") then
			clean[field] = CleanNumber(spec, value)
		elseif (kind == "choice") then
			local options = E.GetOptions(field, base.id)

			value = isstring(value) and value or ""

			if (value != "" and Contains(options, value)) then
				clean[field] = value
			elseif (spec.default and Contains(options, spec.default)) then
				clean[field] = spec.default
			elseif (field == "equipSlot" or field == "category") then
				clean[field] = options[1]
			end
		elseif (kind == "tri") then
			if (value == true or value == false) then
				clean[field] = value
			end
		elseif (kind == "bool") then
			if (value == true) then
				clean[field] = true
			end
		elseif (kind == "class") then
			value = isstring(value) and string.Trim(value) or ""

			if (value != "") then
				if (#value > spec.max or !string.match(value, "^[%w_]+$")) then
					return nil, "itemCreateErrClass", field
				end

				clean[field] = value
			elseif (spec.bRequired) then
				return nil, "itemCreateErrRequired", field
			end
		elseif (kind == "itemid") then
			value = isstring(value) and string.lower(string.Trim(value)) or ""

			if (value != "") then
				if (!IsItemRef(value, id)) then
					return nil, "itemCreateErrItemRef", field
				end

				clean[field] = value
			end
		elseif (kind == "itemlist") then
			local list = ParseIDList(value, id, 16)

			if (#list > 0) then
				clean[field] = list
			end
		elseif (kind == "contents") then
			local list = E.ParseContents(value, id)

			if (#list > 0) then
				clean[field] = list
			end
		elseif (kind == "bodygroups") then
			local groups = istable(value) and value or E.ParseBodygroups(value)
			local checked = E.Clean({bodygroups = groups})
			local result = {}
			local count = 0

			for index, number in pairs(checked and checked.bodygroups or {}) do
				if (count < 16) then
					result[index] = number
					count = count + 1
				end
			end

			if (count > 0) then
				clean[field] = result
			end
		elseif (kind == "factions") then
			local list = {}
			local seen = {}

			if (isstring(value)) then
				value = string.Explode(",", value)
			end

			for _, entry in ipairs(istable(value) and value or {}) do
				local faction = string.lower(string.Trim(tostring(entry)))

				local bKnown = options.bLenient or !NETWORK.factions or
					!NETWORK.factions.Get or NETWORK.factions.Get(faction) != nil

				if (faction != "" and !seen[faction] and #list < 12 and bKnown and
					string.match(faction, "^[%w_]+$")) then
					seen[faction] = true
					list[#list + 1] = faction
				end
			end

			if (#list > 0) then
				clean[field] = list
			end
		end
	end

	if (base.bEquip and !(base.id == "weapon" and clean.bConsumeOnEquip)) then
		clean.maxStack = 1
	end

	if (clean.gasProtection and clean.equipSlot != "mask") then
		clean.gasProtection = nil
	end

	if (base.id == "weapon" and clean.bConsumeOnEquip) then
		clean.equipSlot = nil
	end

	if (clean.skin == 0) then
		clean.skin = nil
	end

	if (clean.spoilRate == 0) then
		clean.spoilRate = nil
	end

	if (clean.price == 0) then
		clean.price = nil
	end

	for _, field in ipairs({"hunger", "thirst", "tokens", "useCooldown", "radProtection"}) do
		if (clean[field] == 0) then
			clean[field] = nil
		end
	end

	if ((base.id == "food" or base.id == "drink") and !clean.hunger and !clean.thirst) then
		return nil, "itemCreateErrNeeds", base.id == "drink" and "thirst" or "hunger"
	end

	if (base.id == "medical" and (clean.healWound or 0) <= 0) then
		return nil, "itemCreateErrRequired", "healWound"
	end

	return clean
end

function E.BuildItem(id, def)
	local base = E.GetBase(def.base)
	local data = {}

	for key, value in pairs(def) do
		data[key] = istable(value) and table.Copy(value) or value
	end

	data.base = nil
	data.bCustom = true
	data.customBase = base.id

	if (istable(def.bodygroups)) then
		local groups = {}

		for index, value in pairs(def.bodygroups) do
			local number = tonumber(index)

			if (number) then
				groups[number] = tonumber(value) or 0
			end
		end

		data.bodygroups = groups
	end

	if (istable(def.contents)) then
		local list = {}

		for _, entry in ipairs(def.contents) do
			for _ = 1, math.max(tonumber(entry[2]) or 1, 1) do
				list[#list + 1] = entry[1]
			end
		end

		data.contents = list
	end

	if (base.id == "ammo") then
		data.bConsumeOnUse = true
		data.useLabel = data.useLabel or "itemLoad"
		data.OnUse = function(self, client)
			return NETWORK.item.LoadAmmo(client, self)
		end
	elseif (base.id == "armour") then
		data.bWearable = true
	elseif (base.id == "medical") then
		data.useLabel = data.useLabel or "itemApply"
		data.OnUse = function() end
	elseif (base.id == "drink") then
		data.useLabel = data.useLabel or "itemDrink"
	elseif (base.id == "food") then
		data.useLabel = data.useLabel or "itemEat"
	end

	return data
end

function E.RegisterCustom(id, def)
	local existing = NETWORK.item.Get(id)

	if (existing and !existing.bCustom) then
		return false
	end

	E.custom[id] = def
	E.original[id] = nil
	E.stored[id] = nil

	NETWORK.item.Register(id, E.BuildItem(id, def))

	return true
end

function E.UnregisterCustom(id)
	local existing = NETWORK.item.Get(id)

	E.custom[id] = nil

	if (!existing or !existing.bCustom) then
		return
	end

	NETWORK.item.stored[id] = nil

	for index = #NETWORK.item.order, 1, -1 do
		if (NETWORK.item.order[index] == id) then
			table.remove(NETWORK.item.order, index)
		end
	end
end

function E.OnCustomChanged()
	hook.Run("NetworkItemsLoaded")
	hook.Run("NetworkItemsEdited")
	hook.Run("NetworkCustomItemsUpdated")
end

function E.GuessBase(item)
	if (item.customBase and E.baseIndex[item.customBase]) then
		return item.customBase
	end

	local slot = item.equipSlot

	if (item.weaponClass) then
		return "weapon"
	elseif (item.ammoType) then
		return "ammo"
	elseif ((item.storageSlots or 0) > 0) then
		return "container"
	elseif (item.contents) then
		return "pack"
	elseif (slot and Contains(E.baseIndex.armour.slots, slot) and (item.protection or 0) > 0) then
		return "armour"
	elseif (slot and Contains(E.baseIndex.clothing.slots, slot)) then
		return "clothing"
	elseif (slot and Contains(E.baseIndex.equipment.slots, slot)) then
		return "equipment"
	elseif ((item.hunger or 0) != 0 or (item.thirst or 0) != 0) then
		return (item.thirst or 0) > (item.hunger or 0) and "drink" or "food"
	elseif ((item.healWound or 0) > 0 or item.category == "medical") then
		return "medical"
	end

	return "misc"
end

function E.DefFromItem(item)
	if (!istable(item)) then
		return {}
	end

	if (item.bCustom and E.custom[item.id]) then
		return table.Copy(E.custom[item.id])
	end

	local baseID = E.GuessBase(item)
	local base = E.GetBase(baseID)
	local def = {base = baseID}

	local function Copy(field)
		local value = item[field]

		if (value == nil) then
			return
		end

		if (field == "contents" and istable(value)) then
			local list = {}

			for _, entry in ipairs(value) do
				list[#list + 1] = istable(entry) and {entry[1] or entry.id, tonumber(entry[2]) or 1} or
					{entry, 1}
			end

			value = list
		end

		def[field] = istable(value) and table.Copy(value) or value
	end

	for _, field in ipairs(E.common) do
		Copy(field)
	end

	for _, field in ipairs(base.fields) do
		Copy(field)
	end

	return def
end
