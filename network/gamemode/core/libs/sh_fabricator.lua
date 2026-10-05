NETWORK.fabricator = NETWORK.fabricator or {}

NETWORK.fabricator.model = "models/hla_prop/fabricator.mdl"
NETWORK.fabricator.fallback = "models/props_lab/reciever01b.mdl"

NETWORK.fabricator.range = 140
NETWORK.fabricator.craftTime = 3.5
NETWORK.fabricator.labelRange = 300

NETWORK.fabricator.recipes = NETWORK.fabricator.recipes or {}
NETWORK.fabricator.order = NETWORK.fabricator.order or {}

function NETWORK.fabricator.GetModel()
	if (file.Exists(NETWORK.fabricator.model, "GAME")) then
		return NETWORK.fabricator.model
	end

	return NETWORK.fabricator.fallback
end

function NETWORK.fabricator.Register(id, data)
	data = data or {}
	data.id = id
	data.item = data.item or id
	data.amount = data.amount or 1
	data.cost = data.cost or {}

	if (!NETWORK.fabricator.recipes[id]) then
		NETWORK.fabricator.order[#NETWORK.fabricator.order + 1] = id
	end

	NETWORK.fabricator.recipes[id] = data
end

function NETWORK.fabricator.Get(id)
	return NETWORK.fabricator.recipes[id]
end

function NETWORK.fabricator.GetAll()
	local result = {}

	for _, id in ipairs(NETWORK.fabricator.order) do
		result[#result + 1] = NETWORK.fabricator.recipes[id]
	end

	return result
end

NETWORK.fabricator.resource = "resin"

NETWORK.fabricator.poolMax = 25

function NETWORK.fabricator.GetPool()
	return GetGlobalInt("nwFabResin", 0)
end

function NETWORK.fabricator.Count(state, id)

	if (id == NETWORK.fabricator.resource) then
		return NETWORK.fabricator.GetPool()
	end

	return NETWORK.fabricator.CountItems(state, id)
end

function NETWORK.fabricator.CountItems(state, id)
	local total = 0

	if (!istable(state)) then
		return total
	end

	for _, list in ipairs({state.items or {}, state.storage or {}}) do
		for _, item in pairs(list) do
			if (item.id == id) then
				total = total + (item.amount or 1)
			end
		end
	end

	return total
end

function NETWORK.fabricator.CanAfford(state, recipe)
	if (!recipe) then
		return false
	end

	for id, amount in pairs(recipe.cost) do
		if (NETWORK.fabricator.Count(state, id) < amount) then
			return false
		end
	end

	return true
end

NETWORK.fabricator.Register("syringe", {cost = {resin = 1}})
NETWORK.fabricator.Register("grenade", {cost = {resin = 1}})

for _, id in ipairs({"ammo_pistol", "ammo_smg", "ammo_ar2", "ammo_buckshot",
	"ammo_357"}) do
	NETWORK.fabricator.Register(id, {cost = {resin = 1}})
end

NETWORK.fabricator.Register("pistol",{cost={resin=4},allianceOnly=true})
NETWORK.fabricator.Register("smg",{cost={resin=7},allianceOnly=true})
NETWORK.fabricator.Register("ar2",{cost={resin=10},allianceOnly=true})
NETWORK.fabricator.Register("pda_alliance",{cost={resin=3},allianceOnly=true})
