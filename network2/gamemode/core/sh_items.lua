-- Items: what exists (NW.items.list), the grid size of the inventory and the equipment slots.
-- An item is a table:
--   name, description      shown in the tooltip, the world hint and the take panel
--   icon                   materials/network2/items/<icon>.png (white, drawn tinted)
--   model                  world model (dropped / spawned)
--   category               food, drink, medical, weapon, clothing, misc (colour and label)
--   slot                   equipment slot id (weapons, clothing) - see NW.items.slots
--   weapon                 SWEP given while the item sits in its weapon slot
--   wear                   clothing: {group = bodygroup name, index = submodel} - put on the
--                          character while in its slot (bags: while carried anywhere)
--   bag                    extra cells this bag adds under the grid while it is in the "Сумка"
--                          slot (only one bag works; a bag cannot lie in the bag's cells)
--   contents               a package (ration): what is inside; hold the mouse on it to open it
--                          and take the things out
--   hunger, thirst, heal   what using it restores (food, drink, medical are used up)
--   useSound               played when used
--   leaves                 what stays in its cell after it is used up (an empty bottle, a can)
--   useVerb                the verb of "Взаимодействовать" (default: by category)
--   OnUse(client, cell)    server, when used; false keeps the item (a card, a flashlight)
-- NW.items.Register(id, table) adds one; test items: nw_testitems (superadmin).

NW.items = NW.items or {}

local I = NW.items

I.list = I.list or {}
I.columns, I.rows = 6, 4
I.gridSize = I.columns * I.rows
-- bags add up to this many cells (rows of I.columns) under the grid
I.maxExtra = 24
I.maxSize = I.gridSize + I.maxExtra

-- equipment: three weapon slots, one slot per kind of clothing
I.slots = {
	{id = "primary", name = "Основное", group = "weapon", icon = "rifle"},
	{id = "secondary", name = "Вторичное", group = "weapon", icon = "pistol"},
	{id = "melee", name = "Холодное", group = "weapon", icon = "crowbar"},
	{id = "head", name = "Голова", group = "clothing", icon = "cap"},
	{id = "face", name = "Лицо", group = "clothing", icon = "gasmask"},
	{id = "torso", name = "Торс", group = "clothing", icon = "jacket"},
	{id = "hands", name = "Руки", group = "clothing", icon = "gloves"},
	{id = "legs", name = "Ноги", group = "clothing", icon = "trousers"},
	{id = "feet", name = "Обувь", group = "clothing", icon = "boots"},
	{id = "bag", name = "Сумка", group = "gear", icon = "bag"}
}

-- which bodygroup of the citizen models each clothing slot dresses (empty slot: submodel 0)
I.slotGroups = {head = "head", face = "face", torso = "torso", hands = "hands", legs = "legs", feet = "shoes"}
-- every bodygroup the clothes manage (reset to 0 before dressing)
I.dressGroups = {"head", "face", "glasses", "torso", "hands", "legs", "shoes", "bag", "satchel"}

I.slotByID = {}

for _, slot in ipairs(I.slots) do
	I.slotByID[slot.id] = slot
end

I.categories = {
	food = {name = "Еда", color = Color(214, 178, 104)},
	drink = {name = "Напиток", color = Color(104, 176, 222)},
	medical = {name = "Медицина", color = Color(222, 104, 98)},
	weapon = {name = "Оружие", color = Color(226, 152, 72)},
	clothing = {name = "Одежда", color = Color(150, 170, 196)},
	misc = {name = "Разное", color = Color(170, 176, 182)}
}

function I.Register(id, item)
	item.id = id
	item.category = item.category or "misc"
	item.icon = item.icon or id
	item.model = item.model or "models/props_junk/cardboard_box004a.mdl"
	I.list[id] = item

	return item
end

function I.Get(id)
	return I.list[id or ""]
end

-- the submodel of a bodygroup for a clothing item on this entity (the variants have the same
-- numbers on every citizen model; a name match is the fallback for other models)
function I.WearIndex(entity, wear)
	local group = entity:FindBodygroupByName(wear.group)

	if (group < 0) then
		return
	end

	if (wear.index and wear.index < entity:GetBodygroupCount(group)) then
		return group, wear.index
	end

	if (wear.match) then
		for _, data in ipairs(entity:GetBodyGroups() or {}) do
			if (data.id == group) then
				for index, name in pairs(data.submodels or {}) do
					if (string.find(string.lower(name), wear.match, 1, true)) then
						return group, index
					end
				end
			end
		end
	end
end

-- how many cells the grid has: the base ones plus what the bag in the "Сумка" slot gives (one bag)
function I.Capacity(equip)
	local cell = equip and equip.bag
	local item = cell and I.Get(cell.id)

	return I.gridSize + math.min(item and item.bag or 0, I.maxExtra)
end

-- the verb of "Взаимодействовать" for an item (the menu shows it as a hint)
function I.UseVerb(item, bEquipped)
	if (item.useVerb) then
		return item.useVerb
	end

	if (item.slot) then
		return bEquipped and "снять" or "надеть"
	elseif (item.category == "food") then
		return "съесть"
	elseif (item.category == "drink") then
		return "выпить"
	elseif (item.contents) then
		return "распаковать"
	elseif (item.category == "medical") then
		return "применить"
	end

	return "использовать"
end

-- short lines with what the item does (tooltip)
function I.Effects(item)
	local lines = {}

	if (item.heal) then
		lines[#lines + 1] = "Здоровье +" .. item.heal
	end

	if (item.hunger) then
		lines[#lines + 1] = "Сытость +" .. item.hunger
	end

	if (item.thirst) then
		lines[#lines + 1] = "Жажда +" .. item.thirst
	end

	if (item.slot) then
		local slot = I.slotByID[item.slot]

		lines[#lines + 1] = "Слот: " .. (slot and slot.name or item.slot)
	end

	if (item.bag) then
		lines[#lines + 1] = "Ячейки +" .. item.bag
	end

	if (item.contents) then
		lines[#lines + 1] = "Зажмите, чтобы распаковать"
	end

	return lines
end

-- -------------------------------------------------------- the item files --
-- framework/items/base/<base>.lua fill BASE (what every item of that base has);
-- framework/items/<group>/<id>.lua fill ITEM (ITEM.base names its base, the file name is its id);
-- files starting with "_" are run as they are (they may register many items at once).
I.bases = I.bases or {}

local ROOT = (GM or GAMEMODE).FolderName .. "/gamemode/framework/items/"

local function Run(path)
	if (SERVER) then
		AddCSLuaFile(path)
	end

	include(path)
end

function I.LoadFolder()
	for _, name in ipairs(file.Find(ROOT .. "base/*.lua", "LUA")) do
		BASE = {}
		Run(ROOT .. "base/" .. name)
		I.bases[string.StripExtension(name)] = BASE
		BASE = nil
	end

	local _, groups = file.Find(ROOT .. "*", "LUA")

	for _, group in ipairs(groups) do
		if (group != "base") then
			for _, name in ipairs(file.Find(ROOT .. group .. "/*.lua", "LUA")) do
				ITEM = {}
				Run(ROOT .. group .. "/" .. name)

				if (string.sub(name, 1, 1) != "_" and ITEM.name) then
					local item = table.Copy(I.bases[ITEM.base or ""] or {})

					for key, value in pairs(ITEM) do
						item[key] = value
					end

					item.group = group
					I.Register(ITEM.id or string.StripExtension(name), item)
				end

				ITEM = nil
			end
		end
	end
end

I.LoadFolder()

I.testSet = {"ration", "ration", "canned", "bread", "water", "soda", "medkit", "bandage", "pills", "pistol", "smg",
	"shotgun", "crowbar", "stunstick", "satchel", "backpack", "pouch", "cl_head_9", "cl_face_2", "cl_torso_41",
	"cl_hands_1", "cl_legs_10", "cl_shoes_6", "flashlight"}
