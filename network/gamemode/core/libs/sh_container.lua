NETWORK.container = NETWORK.container or {}
NETWORK.container.stored = NETWORK.container.stored or {}
NETWORK.container.order = NETWORK.container.order or {}

function NETWORK.container.Register(id, data)
	data.id = id
	data.name = data.name or id
	data.description = data.description or ""
	data.model = data.model or "models/props_junk/wood_crate001a.mdl"
	data.slots = data.slots or 8
	data.minItems = data.minItems or 1
	data.maxItems = data.maxItems or 3
	data.loot = data.loot or {}

	if (!NETWORK.container.stored[id]) then
		NETWORK.container.order[#NETWORK.container.order + 1] = id
	end

	NETWORK.container.stored[id] = data

	return data
end

NETWORK.container.fallback = "models/props_junk/wood_crate001a.mdl"

local picked = {}

function NETWORK.container.PickModel(list)
	if (!istable(list) or #list == 0) then
		return NETWORK.container.fallback
	end

	local key = table.concat(list, "|")

	if (picked[key]) then
		return picked[key]
	end

	local result = list[#list]

	for _, path in ipairs(list) do
		if (util.IsValidModel(path) or file.Exists(path, "GAME")) then
			result = path

			break
		end
	end

	picked[key] = result

	return result
end

function NETWORK.container.SafeModel(path)
	if (!isstring(path) or path == "" or string.find(string.lower(path), "error")) then
		return NETWORK.container.fallback
	end

	if (util.IsValidModel(path) or file.Exists(path, "GAME")) then
		return path
	end

	if (SERVER) then
		NETWORK.util.PrintWarning("Модель контейнера не найдена: " .. path ..
			" — поставлен ящик.")
	end

	return NETWORK.container.fallback
end

function NETWORK.container.Get(id)
	return NETWORK.container.stored[id] or NETWORK.container.stored.crate
end

NETWORK.container.keyItem = "container_key"

NETWORK.container.lockable = {
	nw_container = true,
	nw_ration_bin = true,
	nw_stash = true,
	nw_cache = true
}

function NETWORK.container.CanLock(entity)
	return IsValid(entity) and entity.GetLockItem != nil and
		NETWORK.container.lockable[entity:GetClass()] == true
end

function NETWORK.container.GetLock(entity)
	if (!IsValid(entity) or !entity.GetLockItem) then
		return "", ""
	end

	return entity:GetLockItem() or "", entity.GetLockCode and entity:GetLockCode() or ""
end

function NETWORK.container.IsLocked(entity)
	local item = NETWORK.container.GetLock(entity)

	return item != ""
end

function NETWORK.container.KeyFits(item, lockItem, lockCode)
	if (!istable(item) or lockItem == "" or item.id != lockItem) then
		return false
	end

	if (lockCode == "") then
		return true
	end

	local code = istable(item.data) and item.data.code

	return code != nil and tostring(code) == lockCode
end

function NETWORK.container.FindKey(state, lockItem, lockCode)
	if (!istable(state) or lockItem == "") then
		return
	end

	for _, list in ipairs({"items", "storage", "equipped"}) do
		for _, item in pairs(state[list] or {}) do
			if (NETWORK.container.KeyFits(item, lockItem, lockCode)) then
				return item
			end
		end
	end
end

function NETWORK.container.GetAll()
	local list = {}

	for _, id in ipairs(NETWORK.container.order) do
		list[#list + 1] = NETWORK.container.stored[id]
	end

	return list
end

function NETWORK.container.Roll(id)
	local data = NETWORK.container.Get(id)
	local items = {}

	if (!data) then
		return items
	end

	local count = math.random(data.minItems, data.maxItems)

	for _ = 1, count do
		local pool = {}

		for _, entry in ipairs(data.loot) do
			if (math.random(100) <= (entry.chance or 100)) then
				pool[#pool + 1] = entry
			end
		end

		if (#pool == 0) then
			continue
		end

		local entry = pool[math.random(#pool)]
		local id = entry.id

		if (entry.pool) then
			local candidates = {}

			for _, base in ipairs(NETWORK.item.GetAll()) do
				if (base.category == entry.pool) then
					candidates[#candidates + 1] = base.id
				end
			end

			if (#candidates == 0) then
				continue
			end

			id = candidates[math.random(#candidates)]
		end

		local amount = 1

		if (istable(entry.amount)) then
			amount = math.random(entry.amount[1], entry.amount[2])
		end

		local item = NETWORK.item.New(id, amount)

		if (item) then
			items[#items + 1] = item
		end
	end

	return items
end

NETWORK.container.Register("crate", {
	name = "Деревянный ящик",
	model = "models/props_junk/wood_crate001a.mdl",
	slots = 8,
	minItems = 1,
	maxItems = 4,
	loot = {
		{id = "scrap", chance = 70, amount = {1, 3}},
		{id = "rag", chance = 60},
		{id = "can", chance = 60, amount = {1, 2}},
		{id = "wire", chance = 45},
		{id = "battery", chance = 25},
		{id = "bread", chance = 30},
		{id = "water", chance = 30},
		{id = "bandage", chance = 20}
	}
})

NETWORK.container.Register("locker", {
	name = "Шкафчик",
	model = "models/props_c17/lockers001a.mdl",
	slots = 12,
	minItems = 2,
	maxItems = 5,
	loot = {
		{id = "rag", chance = 60},
		{id = "scrap", chance = 50, amount = {1, 2}},
		{id = "ration", chance = 40},
		{id = "water", chance = 40},
		{id = "bandage", chance = 35},
		{id = "battery", chance = 20},
		{id = "idcard", chance = 10}
	}
})

NETWORK.container.Register("supply", {
	name = "Ящик снабжения",
	model = "models/items/ammocrate_smg1.mdl",
	slots = 10,
	minItems = 2,
	maxItems = 4,
	loot = {
		{id = "bandage", chance = 60, amount = {1, 2}},
		{id = "ration", chance = 55},
		{id = "battery", chance = 40},
		{id = "scrap", chance = 40, amount = {1, 3}},
		{pool = "weapon", chance = 8}
	}
})

NETWORK.container.Register("weapons", {
	name = "Оружейный ящик",
	model = "models/items/item_item_crate.mdl",
	slots = 8,
	minItems = 1,
	maxItems = 3,
	loot = {
		{pool = "weapon", chance = 30},
		{id = "scrap", chance = 50, amount = {1, 2}},
		{id = "rag", chance = 40},
		{id = "bandage", chance = 30}
	}
})

NETWORK.container.Register("corpse", {
	name = "Вещи погибшего",
	description = "Всё, что осталось при себе.",
	model = "models/props_c17/suitcase_passenger_physics.mdl",
	slots = 16,
	minItems = 0,
	maxItems = 0,
	loot = {}
})

NETWORK.container.Register("crate_big", {
	name = "Большой ящик",
	model = "models/props_junk/wood_crate002a.mdl",
	slots = 12,
	minItems = 2,
	maxItems = 5,
	loot = {
		{id = "scrap", chance = 70, amount = {1, 4}},
		{id = "wire", chance = 55, amount = {1, 2}},
		{id = "rag", chance = 50},
		{id = "resin", chance = 35},
		{id = "battery", chance = 30},
		{id = "toolkit", chance = 12}
	}
})

NETWORK.container.Register("cardboard", {
	name = "Картонная коробка",
	model = "models/props_junk/cardboard_box001a.mdl",
	slots = 6,
	minItems = 1,
	maxItems = 3,
	loot = {
		{id = "rag", chance = 65},
		{id = "bottle_empty", chance = 50},
		{id = "can", chance = 45, amount = {1, 2}},
		{id = "scrap", chance = 40},
		{id = "blank_form", chance = 20}
	}
})

NETWORK.container.Register("barrel", {
	name = "Бочка",
	model = "models/props_c17/oildrum001.mdl",
	slots = 8,
	minItems = 1,
	maxItems = 3,
	loot = {
		{id = "scrap", chance = 60, amount = {1, 3}},
		{id = "resin", chance = 45},
		{id = "trash_bag", chance = 40},
		{id = "wire", chance = 35},
		{id = "battery", chance = 20}
	}
})

NETWORK.container.Register("fridge", {
	name = "Холодильник",
	model = "models/props_c17/FurnitureFridge001a.mdl",
	slots = 10,
	minItems = 1,
	maxItems = 4,
	loot = {
		{id = "water", chance = 60, amount = {1, 2}},
		{id = "canned_fruit", chance = 45},
		{id = "bread", chance = 40},
		{id = "synth_paste", chance = 35},
		{id = "dry_ration", chance = 25},
		{id = "water_breen", chance = 10}
	}
})

NETWORK.container.Register("drawer", {
	name = "Комод",
	model = "models/props_c17/FurnitureDrawer001a.mdl",
	slots = 10,
	minItems = 1,
	maxItems = 4,
	loot = {
		{id = "rag", chance = 60},
		{id = "document", chance = 35},
		{id = "keys", chance = 25},
		{id = "flashlight", chance = 20},
		{id = "painkillers", chance = 20},
		{id = "idcard", chance = 8}
	}
})

NETWORK.container.Register("filecabinet", {
	name = "Картотека",
	model = "models/props_lab/filecabinet02.mdl",
	slots = 8,
	minItems = 1,
	maxItems = 3,
	loot = {
		{id = "document", chance = 60},
		{id = "blank_form", chance = 50, amount = {1, 2}},
		{id = "notice_form", chance = 25},
		{id = "idcard", chance = 10}
	}
})

NETWORK.container.Register("medical", {
	name = "Медицинский бокс",
	model = "models/props_lab/box01a.mdl",
	slots = 10,
	minItems = 2,
	maxItems = 4,
	loot = {
		{id = "bandage", chance = 70, amount = {1, 2}},
		{id = "painkillers", chance = 45},
		{id = "splint", chance = 30},
		{id = "chestseal", chance = 25},
		{id = "morphine", chance = 15},
		{id = "bloodbag", chance = 10}
	}
})

NETWORK.container.Register("ammobox", {
	name = "Патронный ящик",
	model = "models/items/ammocrate_ar2.mdl",
	slots = 8,
	minItems = 1,
	maxItems = 3,
	loot = {
		{id = "ammo_pistol", chance = 55, amount = {1, 2}},
		{id = "ammo_smg", chance = 45},
		{id = "ammo_buckshot", chance = 35},
		{id = "ammo_ar2", chance = 20},
		{id = "ammo_357", chance = 12}
	}
})

NETWORK.container.Register("toolbox", {
	name = "Ящик с инструментом",
	model = "models/props_wasteland/controlroom_storagecloset001a.mdl",
	slots = 10,
	minItems = 1,
	maxItems = 4,
	loot = {
		{id = "wire", chance = 60, amount = {1, 2}},
		{id = "scrap", chance = 55, amount = {1, 3}},
		{id = "toolkit", chance = 25},
		{id = "repair_kit", chance = 20},
		{id = "mechanic_toolkit", chance = 8}
	}
})

NETWORK.container.Register("trashbin", {
	name = "Мусорный бак",
	model = "models/props_junk/trashbin01a.mdl",
	slots = 6,
	minItems = 1,
	maxItems = 3,
	loot = {
		{id = "trash_bag", chance = 60},
		{id = "trash_full", chance = 45},
		{id = "bottle_empty", chance = 45},
		{id = "can", chance = 40},
		{id = "scrap", chance = 30},
		{id = "ration_empty", chance = 25}
	}
})

NETWORK.container.Register("briefcase", {
	name = "Портфель",
	model = "models/props_c17/briefcase001a.mdl",
	slots = 6,
	minItems = 1,
	maxItems = 2,
	loot = {
		{id = "document", chance = 60},
		{id = "blank_form", chance = 40},
		{id = "keys", chance = 25},
		{id = "idcard", chance = 12}
	}
})
