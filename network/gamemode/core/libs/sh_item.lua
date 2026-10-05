NETWORK.item = NETWORK.item or {}

NETWORK.worldItem = NETWORK.worldItem or {}
NETWORK.worldItem.range = 110
NETWORK.worldItem.holdTime = 0.7

NETWORK.manhack = NETWORK.manhack or {}
NETWORK.manhack.range = 96
NETWORK.manhack.itemID = "manhack"
NETWORK.manhack.class = "npc_manhack"

NETWORK.manhack.health = 45
NETWORK.item.stored = NETWORK.item.stored or {}
NETWORK.item.order = NETWORK.item.order or {}

local BASE = {
	name = "Предмет",
	description = "",
	model = "models/props_junk/cardboard_box001a.mdl",
	rarity = "common",
	weight = 0.5,
	category = "misc",
	weaponClass = nil,
	bodygroups = nil,
	skin = nil,
	replaceModel = nil,
	protection = 0,
	healWound = 0,
	bodygroups = nil,
	skin = nil,
	hunger = 0,
	thirst = 0,
	useSound = nil,
	maxStack = 1,
	width = 1,
	height = 1,
	equipSlot = nil,
	storageSlots = 0,
	storageBlacklist = nil,

	bConsumeOnEquip = false,
	contents = nil,
	tokens = 0,
	useLabel = nil
}

function NETWORK.item.Register(id, data)
	for key, value in pairs(BASE) do
		if (data[key] == nil) then
			data[key] = value
		end
	end

	data.id = id
	data.blacklist = {}

	for _, entry in ipairs(data.storageBlacklist or {}) do
		data.blacklist[entry] = true
	end

	if (!NETWORK.item.stored[id]) then
		NETWORK.item.order[#NETWORK.item.order + 1] = id
	end

	NETWORK.item.stored[id] = data

	return data
end

function NETWORK.item.LoadAmmo(client, base)
	if (!SERVER or !base.ammoType) then
		return false
	end

	client:GiveAmmo(base.ammoAmount or 1, base.ammoType, true)
	client:EmitSound("items/ammo_pickup.wav", 55, 105, 0.6)

	return true
end

NETWORK.item.tags = {
	keep = {color = Color(96, 224, 140), name = "tagKeep"},
	drop = {color = Color(232, 84, 76), name = "tagDrop"},
	destroy = {color = Color(178, 118, 232), name = "tagDestroy"}
}

function NETWORK.item.GetTag(item)
	local base = NETWORK.item.Get(item and item.id or item)
	local id = base and base.dropTag or "drop"

	return NETWORK.item.tags[id] or NETWORK.item.tags.drop, id
end

function NETWORK.item.Get(id)
	return NETWORK.item.stored[id]
end

function NETWORK.item.Find(text)
	text = NETWORK.util.Lower(string.Trim(text or ""))

	if (text == "") then
		return
	end

	if (NETWORK.item.stored[text]) then
		return NETWORK.item.stored[text]
	end

	for _, id in ipairs(NETWORK.item.order) do
		if (string.sub(id, 1, string.len(text)) == text) then
			return NETWORK.item.stored[id]
		end
	end

	for _, id in ipairs(NETWORK.item.order) do
		local base = NETWORK.item.stored[id]

		if (string.find(NETWORK.util.Lower(base.name), text, 1, true)) then
			return base
		end
	end
end

function NETWORK.item.GetAll()
	local list = {}

	for _, id in ipairs(NETWORK.item.order) do
		list[#list + 1] = NETWORK.item.stored[id]
	end

	return list
end

function NETWORK.item.New(id, amount)
	local base = NETWORK.item.Get(id)

	if (!base) then
		return
	end

	local item = {
		id = id,
		amount = math.max(amount or 1, 1),
		data = {}
	}

	if (SERVER and NETWORK.antidupe and NETWORK.antidupe.Stamp) then
		NETWORK.antidupe.Stamp(item)
	end

	return item
end

function NETWORK.item.IsContainer(item)
	if (!item) then
		return false
	end

	local base = NETWORK.item.Get(item.id)

	return base != nil and (base.storageSlots or 0) > 0
end

-- Короткая подпись для клетки инвентаря: ITEM.shortName или первое слово названия.
function NETWORK.item.GetShortName(item)
	local base = item and NETWORK.item.Get(item.id)

	if (base and isstring(base.shortName) and base.shortName != "") then
		return base.shortName
	end

	local name = NETWORK.item.GetName(item)
	local first = string.match(name, "^[^%s\"(,]+") or name

	if (utf8.len(first) and utf8.len(first) < 3) then
		return name
	end

	return first
end

function NETWORK.item.GetName(item)
	local base = item and NETWORK.item.Get(item.id)

	if (base and base.GetName) then
		local bSuccess, result = pcall(base.GetName, base, item)

		if (bSuccess and isstring(result) and result != "") then
			return result
		end
	end

	return base and base.name or "?"
end

function NETWORK.item.GetModel(item)
	local base = item and NETWORK.item.Get(item.id)

	if (base and base.GetModel) then
		local bSuccess, result = pcall(base.GetModel, base, item)

		if (bSuccess and isstring(result) and result != "") then
			return result
		end
	end

	return base and base.model or "models/props_junk/cardboard_box001a.mdl"
end

function NETWORK.item.GetRarity(item)
	local base = item and NETWORK.item.Get(item.id)

	return base and base.rarity or "common"
end

NETWORK.item.contrabandCategories = {
	weapon = true,
	weapons = true,
	ammo = true,
	armour = true,
	armor = true
}

function NETWORK.item.IsContraband(item)
	local base = istable(item) and (item.id and NETWORK.item.Get(item.id) or item)

	if (!base) then
		return false
	end

	if (base.bContraband != nil) then
		return base.bContraband == true
	end

	return NETWORK.item.contrabandCategories[base.category or ""] == true
end

function NETWORK.item.GetWeight(item)
	local base = item and NETWORK.item.Get(item.id)

	return (base and base.weight or 0.5) * (item and item.amount or 1)
end

function NETWORK.item.GetEquipSlot(item)
	local base = item and NETWORK.item.Get(item.id)

	return base and base.equipSlot
end

function NETWORK.item.GetStorageSlots(item)
	local base = item and NETWORK.item.Get(item.id)

	return base and base.storageSlots or 0
end

function NETWORK.item.GetDescription(item)
	local base = item and NETWORK.item.Get(item.id)

	if (!base) then
		return ""
	end

	if (base.GetDescription) then
		local bSuccess, result = pcall(base.GetDescription, base, item)

		if (bSuccess and isstring(result)) then
			return result
		end
	end

	local description = base.description or ""

	if (NETWORK.issued and NETWORK.issued.Is(item)) then
		description = description .. "\n" .. L("itemIssued")
	end

	return description
end

function NETWORK.item.CanStore(container, item)
	if (!container or !item) then
		return false
	end

	local base = NETWORK.item.Get(container.id)

	if (!base) then
		return false
	end

	if (base.blacklist[item.id]) then
		return false
	end

	if (NETWORK.item.IsContainer(item)) then
		return false
	end

	return true
end

function NETWORK.item.CanUse(item)
	local base = NETWORK.item.Get(item and item.id)

	if (!base) then
		return false
	end

	return base.OnUse != nil or base.weaponClass != nil or base.contents != nil or
		(base.hunger or 0) != 0 or (base.thirst or 0) != 0
end

function NETWORK.item.GetSize(item)
	local base = NETWORK.item.Get(item and item.id)

	if (!base) then
		return 1, 1
	end

	local width = math.Clamp(math.Round(base.width or 1), 1, 6)
	local height = math.Clamp(math.Round(base.height or 1), 1, 6)

	if (item and item.rotated) then
		return height, width
	end

	return width, height
end

function NETWORK.item.CanRotate(item)
	local base = NETWORK.item.Get(item and item.id)

	if (!base) then
		return false
	end

	return (base.width or 1) != (base.height or 1)
end

function NETWORK.item.GetMaxStack(item)
	local base = NETWORK.item.Get(item and item.id)

	return math.max(base and base.maxStack or 1, 1)
end

function NETWORK.item.CanStack(a, b)
	if (!a or !b or a.id != b.id) then
		return false
	end

	if (NETWORK.item.GetMaxStack(a) <= 1) then
		return false
	end

	if (!table.IsEmpty(a.data or {}) or !table.IsEmpty(b.data or {})) then
		if (!NETWORK.spoil or !NETWORK.spoil.CanStack(a, b)) then
			return false
		end
	end

	return (a.amount or 1) < NETWORK.item.GetMaxStack(a)
end

function NETWORK.item.GetUseLabel(item)
	local base = NETWORK.item.Get(item and item.id)

	if (!base) then
		return "itemUse"
	end

	if (base.useLabel) then
		return base.useLabel
	end

	if (base.contents) then
		return "itemUnpack"
	end

	if (base.weaponClass) then
		return "itemTake"
	end

	if ((base.thirst or 0) > (base.hunger or 0)) then
		return "itemDrink"
	end

	if ((base.hunger or 0) > 0) then
		return "itemEat"
	end

	return "itemUse"
end

function NETWORK.item.OnCreated(item, client, character)
	local base = NETWORK.item.Get(item.id)

	if (base and base.OnCreated) then
		base:OnCreated(item, client, character)
	end

	return item
end

function NETWORK.item.LoadDirectory()
	local base = NETWORK.folder .. "/gamemode/items"
	local files, folders = file.Find(base .. "/*", "LUA")

	for _, name in ipairs(files or {}) do
		if (name:sub(-4) != ".lua") then
			continue
		end

		local id = name:gsub("^sh_", ""):gsub("^cl_", ""):gsub("^sv_", ""):gsub("%.lua$", "")

		ITEM = {}

		if (SERVER) then
			AddCSLuaFile(base .. "/" .. name)
		end

		include(base .. "/" .. name)

		NETWORK.item.Register(id, ITEM)

		ITEM = nil
	end

	for _, name in ipairs(folders or {}) do
		local path = base .. "/" .. name

		for _, sub in ipairs(file.Find(path .. "/*.lua", "LUA") or {}) do
			local id = sub:gsub("^sh_", ""):gsub("%.lua$", "")

			ITEM = {}

			if (SERVER) then
				AddCSLuaFile(path .. "/" .. sub)
			end

			include(path .. "/" .. sub)

			NETWORK.item.Register(id, ITEM)

			ITEM = nil
		end
	end
end

NETWORK.item.LoadDirectory()

if (SERVER) then
	function NETWORK.item.Spawn(id, position, angles, amount, data)
		local item = NETWORK.item.New(id, amount)

		if (!item) then
			return
		end

		if (istable(data)) then
			table.Merge(item.data, data)
		end

		local entity = ents.Create("nw_item")

		if (!IsValid(entity)) then
			return
		end

		entity:SetPos(position)
		entity:SetAngles(angles or Angle(0, math.random(0, 360), 0))
		entity:SetItem(item)
		entity:Spawn()
		entity:Activate()

		return entity
	end
end
