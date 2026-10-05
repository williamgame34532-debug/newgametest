NETWORK.junk = NETWORK.junk or {}

NETWORK.junk.range = 110
NETWORK.junk.searchTime = 3

NETWORK.junk.refill = 300

function NETWORK.junk.GetRefill(entity)
	if (!IsValid(entity) or !entity.GetRefill) then
		return NETWORK.junk.refill
	end

	local value = entity:GetRefill() or 0

	if (value < 0) then
		return -1
	end

	return value > 0 and value or NETWORK.junk.refill
end

NETWORK.junk.models = {
	"models/props_junk/garbage_bag001a.mdl",
	"models/props_junk/garbage_metalcan002a.mdl",
	"models/props_junk/cardboard_box003a.mdl",
	"models/props_junk/trashbin01a.mdl",
	"models/props_junk/wood_crate001a.mdl",
	"models/props_debris/wood_board05a.mdl"
}

NETWORK.junk.defaultLoot = {
	scrap = 40,
	rag = 30,
	can = 25,
	wire = 20,
	battery = 10,
	resin = 6
}

function NETWORK.junk.GetModel(id)
	if (isstring(id) and id != "") then
		return id
	end

	return NETWORK.junk.models[1]
end

NETWORK.junk.rareCategories = {
	weapon = 0.03,
	ammo = 0.1,
	armour = 0.04,
	clothing = 0.05,
	document = 0.05
}

NETWORK.junk.rareItems = {
	idcard = 0.03,
	toolkit = 0.2,
	emptool = 0.05,
	lockpick = 0.15
}

function NETWORK.junk.GetRareScale(id)
	if (NETWORK.junk.rareItems[id]) then
		return NETWORK.junk.rareItems[id]
	end

	local base = NETWORK.item.Get(id)

	if (!base) then
		return 1
	end

	if (base.weaponClass and !NETWORK.junk.rareCategories[base.category]) then
		return NETWORK.junk.rareCategories.weapon
	end

	return NETWORK.junk.rareCategories[base.category or ""] or 1
end

function NETWORK.junk.Roll(loot, count)
	local pool = {}
	local total = 0

	local ordinary, ordinaryCount = 0, 0

	for id, weight in pairs(loot or {}) do
		weight = math.max(math.Round(tonumber(weight) or 0), 0)

		if (weight > 0 and NETWORK.item.Get(id) and
			NETWORK.junk.GetRareScale(id) >= 1) then
			ordinary = ordinary + weight
			ordinaryCount = ordinaryCount + 1
		end
	end

	ordinary = ordinaryCount > 0 and (ordinary / ordinaryCount) or 10

	for id, weight in pairs(loot or {}) do
		weight = math.max(math.Round(tonumber(weight) or 0), 0)

		if (weight > 0 and NETWORK.item.Get(id)) then
			local scale = NETWORK.junk.GetRareScale(id)

			if (scale < 1) then
				weight = math.min(weight, ordinary * scale)
			end

			if (weight > 0) then
				pool[#pool + 1] = {id = id, weight = weight}
				total = total + weight
			end
		end
	end

	local result = {}

	if (total <= 0) then
		return result
	end

	for _ = 1, math.max(count or 1, 0) do
		local roll = math.random() * total
		local seen = 0

		for _, entry in ipairs(pool) do
			seen = seen + entry.weight

			if (roll <= seen) then
				result[#result + 1] = entry.id

				break
			end
		end
	end

	return result
end
