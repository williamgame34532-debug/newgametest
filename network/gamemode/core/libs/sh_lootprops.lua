NETWORK.lootprops = NETWORK.lootprops or {}

local L = NETWORK.lootprops

L.range = 96
L.refill = 1800

L.kinds = {
	{
		match = "oildrum001",
		name = "lootBarrel",
		time = 4,
		loot = {
			{id = "scrap", chance = 55, amount = {1, 2}},
			{id = "rag", chance = 40},
			{id = "resin", chance = 25},
			{id = "wire", chance = 20}
		}
	},
	{
		match = "wood_crate",
		name = "lootCrate",
		time = 4,
		loot = {
			{id = "scrap", chance = 50, amount = {1, 3}},
			{id = "wire", chance = 35},
			{id = "can", chance = 30},
			{id = "battery", chance = 12}
		}
	},
	{
		match = "trashcan",
		name = "lootTrash",
		time = 3,
		loot = {
			{id = "trash_bag", chance = 45},
			{id = "bottle_empty", chance = 40},
			{id = "can", chance = 35},
			{id = "ration_empty", chance = 20}
		}
	},
	{
		match = "trashdumpster",
		name = "lootDumpster",
		time = 5,
		loot = {
			{id = "trash_full", chance = 50},
			{id = "rag", chance = 40},
			{id = "scrap", chance = 35, amount = {1, 2}},
			{id = "bandage", chance = 10}
		}
	},
	{
		match = "cardboard_box",
		name = "lootBox",
		time = 3,
		loot = {
			{id = "rag", chance = 45},
			{id = "blank_form", chance = 25},
			{id = "can", chance = 25},
			{id = "document", chance = 10}
		}
	},
	{
		match = "footlocker",
		name = "lootLocker",
		time = 5,
		loot = {
			{id = "rag", chance = 40},
			{id = "bandage", chance = 30},
			{id = "painkillers", chance = 18},
			{id = "flashlight", chance = 12},
			{id = "ammo_pistol", chance = 8}
		}
	},
	{
		match = "filecabinet",
		name = "lootCabinet",
		time = 5,
		loot = {
			{id = "document", chance = 45},
			{id = "blank_form", chance = 40},
			{id = "keys", chance = 12}
		}
	},
	{
		match = "furnituredrawer",
		name = "lootDrawer",
		time = 4,
		loot = {
			{id = "rag", chance = 40},
			{id = "document", chance = 25},
			{id = "painkillers", chance = 20},
			{id = "keys", chance = 15}
		}
	}
}

function L.GetKind(entity)
	if (!IsValid(entity)) then
		return
	end

	local class = entity:GetClass()

	if (class != "prop_physics" and class != "prop_physics_multiplayer" and
		class != "prop_dynamic") then
		return
	end

	local model = string.lower(entity:GetModel() or "")

	if (model == "") then
		return
	end

	for _, kind in ipairs(L.kinds) do
		if (string.find(model, kind.match, 1, true)) then
			return kind
		end
	end
end

function L.IsEmpty(entity)
	local until_ = entity:GetNWFloat("nwLootEmpty", 0)

	return until_ > CurTime()
end
