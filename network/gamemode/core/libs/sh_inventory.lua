NETWORK.inventory = NETWORK.inventory or {}

NETWORK.inventory.columns = 4
NETWORK.inventory.rows = 4
NETWORK.inventory.maxWeight = 20
NETWORK.inventory.defaultWeight = 0.5

NETWORK.inventory.rarities = NETWORK.inventory.rarities or {}
NETWORK.inventory.rarityOrder = NETWORK.inventory.rarityOrder or {}

function NETWORK.inventory.RegisterRarity(id, data)
	data.id = id
	data.name = data.name or id
	data.color = data.color or Color(226, 238, 248)
	data.order = data.order or (#NETWORK.inventory.rarityOrder + 1) * 10

	if (!NETWORK.inventory.rarities[id]) then
		NETWORK.inventory.rarityOrder[#NETWORK.inventory.rarityOrder + 1] = id
	end

	NETWORK.inventory.rarities[id] = data

	return data
end

function NETWORK.inventory.GetRarity(id)
	return NETWORK.inventory.rarities[id] or NETWORK.inventory.rarities.common
end

NETWORK.inventory.RegisterRarity("common", {
	name = "rarityCommon",
	color = Color(228, 238, 248),
	order = 10
})

NETWORK.inventory.RegisterRarity("uncommon", {
	name = "rarityUncommon",
	color = Color(86, 232, 122),
	order = 20
})

NETWORK.inventory.RegisterRarity("special", {
	name = "raritySpecial",
	color = Color(172, 104, 255),
	order = 30
})

NETWORK.inventory.RegisterRarity("unique", {
	name = "rarityUnique",
	color = Color(255, 86, 86),
	order = 40
})

NETWORK.inventory.RegisterRarity("event", {
	name = "rarityEvent",
	color = Color(255, 208, 58),
	order = 50
})

NETWORK.inventory.RegisterRarity("custom", {
	name = "rarityCustom",
	color = Color(255, 92, 196),
	order = 60
})

NETWORK.inventory.equipment = {
	{
		id = "weapons",
		name = "equipWeapons",
		slots = {
			{id = "primary", name = "slotPrimary"},
			{id = "secondary", name = "slotSecondary"},
			{id = "melee", name = "slotMelee"}
		}
	},
	{
		id = "head",
		name = "equipHead",
		slots = {
			{id = "helmet", name = "slotHelmet"},
			{id = "hat", name = "slotHat"},
			{id = "glasses", name = "slotGlasses"},
			{id = "mask", name = "slotMask"}
		}
	},
	{
		id = "body",
		name = "equipBody",
		slots = {
			{id = "jacket", name = "slotJacket"},
			{id = "vest", name = "slotVest"},
			{id = "armour", name = "slotArmour"},
			{id = "gloves", name = "slotGloves"}
		}
	},
	{
		id = "legs",
		name = "equipLegs",
		slots = {
			{id = "pants", name = "slotPants"},
			{id = "boots", name = "slotBoots"}
		}
	},
	{
		id = "extra",
		name = "equipExtra",
		slots = {
			{id = "backpack", name = "slotBackpack"},
			{id = "radio", name = "slotRadio"},
			{id = "watch", name = "slotWatch"},
			{id = "light", name = "slotLight"},
			{id = "cuffs", name = "slotCuffs"}
		}
	}
}

function NETWORK.inventory.GetSize()
	return NETWORK.inventory.columns * NETWORK.inventory.rows
end

NETWORK.inventory.starter = {"idcard", "suitcase"}

function NETWORK.inventory.NewState()
	return {items = {}, equipped = {}, storage = {}}
end

function NETWORK.inventory.GetGrid(list)
	if (list == "items" or list == "storage") then
		return NETWORK.inventory.columns, NETWORK.inventory.rows
	end

	return NETWORK.inventory.columns, NETWORK.inventory.rows
end

function NETWORK.inventory.CellToIndex(x, y, columns)
	return y * columns + x + 1
end

function NETWORK.inventory.IndexToCell(index, columns)
	index = index - 1

	return index % columns, math.floor(index / columns)
end

function NETWORK.inventory.GetOccupancy(list, columns, rows, ignore)
	local map = {}

	for index, item in pairs(list) do
		if (index == ignore) then
			continue
		end

		local width, height = NETWORK.item.GetSize(item)
		local originX, originY = NETWORK.inventory.IndexToCell(index, columns)

		for offsetY = 0, height - 1 do
			for offsetX = 0, width - 1 do
				map[(originY + offsetY) * columns + (originX + offsetX) + 1] = index
			end
		end
	end

	return map
end

function NETWORK.inventory.Fits(list, columns, rows, item, index, ignore)
	if (!index or index < 1 or index > columns * rows) then
		return false
	end

	local width, height = NETWORK.item.GetSize(item)
	local originX, originY = NETWORK.inventory.IndexToCell(index, columns)

	if (originX + width > columns or originY + height > rows) then
		return false
	end

	local map = NETWORK.inventory.GetOccupancy(list, columns, rows, ignore)

	for offsetY = 0, height - 1 do
		for offsetX = 0, width - 1 do
			if (map[(originY + offsetY) * columns + (originX + offsetX) + 1]) then
				return false
			end
		end
	end

	return true
end

function NETWORK.inventory.GetOverlapping(list, columns, rows, item, index, ignore)
	local width, height = NETWORK.item.GetSize(item)
	local originX, originY = NETWORK.inventory.IndexToCell(index, columns)
	local map = NETWORK.inventory.GetOccupancy(list, columns, rows, ignore)
	local found = {}
	local count = 0

	for offsetY = 0, height - 1 do
		for offsetX = 0, width - 1 do
			local cell = (originY + offsetY) * columns + (originX + offsetX) + 1
			local owner = map[cell]

			if (owner and !found[owner]) then
				found[owner] = true
				count = count + 1
			end
		end
	end

	return found, count
end

function NETWORK.inventory.FindSpot(list, columns, rows, item)
	for index = 1, columns * rows do
		if (NETWORK.inventory.Fits(list, columns, rows, item, index)) then
			return index
		end
	end
end

function NETWORK.inventory.FindStack(list, item, size)
	if (NETWORK.item.GetMaxStack(item) <= 1) then
		return
	end

	for index = 1, size do
		local other = list[index]

		if (other and NETWORK.item.CanStack(other, item)) then
			return index
		end
	end
end

function NETWORK.inventory.FirstFree(list, size)
	for i = 1, size do
		if (!list[i]) then
			return i
		end
	end
end

function NETWORK.inventory.CountState(state)
	local total = 0

	for _ in pairs(state.items) do
		total = total + 1
	end

	return total
end

function NETWORK.inventory.WeightOf(state)
	local total = 0

	local function Add(list)
		for _, item in pairs(list) do
			local base = NETWORK.item.Get(item.id)

			total = total + ((base and base.weight) or NETWORK.inventory.defaultWeight) *
				(item.amount or 1)
		end
	end

	Add(state.items)
	Add(state.equipped)
	Add(state.storage)

	return total
end

function NETWORK.inventory.ContainerOf(state)
	for _, item in pairs(state.equipped) do
		if (NETWORK.item.IsContainer(item)) then
			return item
		end
	end
end

function NETWORK.inventory.Index(index)
	return tonumber(index) or index
end

function NETWORK.inventory.At(state, list, index, slot)
	if (list == "equipped") then
		return state.equipped[slot]
	end

	index = NETWORK.inventory.Index(index)

	return state[list] and index != nil and state[list][index] or nil
end

function NETWORK.inventory.Put(state, list, index, slot, item)
	if (list == "equipped") then
		state.equipped[slot] = item

		return
	end

	index = NETWORK.inventory.Index(index)

	if (state[list] and index != nil) then
		state[list][index] = item
	end
end

function NETWORK.inventory.CanPlace(state, item, list, index, slot, fromList, ignore)
	if (!item) then
		return false
	end

	if (fromList == "equipped" and list != "equipped" and
		NETWORK.item.IsContainer(item) and next(state.storage) != nil) then
		return false
	end

	if (list == "items") then
		local columns, rows = NETWORK.inventory.columns, NETWORK.inventory.rows

		return NETWORK.inventory.Fits(state.items, columns, rows, item, index,
			fromList == "items" and ignore or nil)
	end

	if (list == "storage") then
		local container = NETWORK.inventory.ContainerOf(state)

		if (!container or container == item) then
			return false
		end

		if (!NETWORK.item.CanStore(container, item)) then
			return false
		end

		local slots = NETWORK.item.GetStorageSlots(container)
		local columns = NETWORK.inventory.columns
		local rows = math.ceil(slots / columns)

		return NETWORK.inventory.Fits(state.storage, columns, rows, item, index,
			fromList == "storage" and ignore or nil)
	end

	if (list == "equipped") then
		return NETWORK.item.GetEquipSlot(item) == slot
	end

	return false
end

NETWORK.inventory.categoryColors = {
	medical = Color(120, 220, 150),
	medicine = Color(120, 220, 150),
	food = Color(226, 190, 90),
	rations = Color(226, 190, 90),
	weapon = Color(226, 96, 88),
	weapons = Color(226, 96, 88),
	ammo = Color(212, 130, 90),
	armour = Color(150, 170, 210),
	armor = Color(150, 170, 210),
	clothing = Color(170, 160, 200),
	misc = Color(140, 180, 220),
	documents = Color(200, 200, 210),
	junk = Color(120, 122, 126)
}
