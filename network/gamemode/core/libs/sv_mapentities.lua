NETWORK.mapents = NETWORK.mapents or {}

NETWORK.mapents.classes = {
	nw_npc = {"NPCName", "NPCModel", "NPCSequence", "Dialogue", "Factions"},
	nw_trader = {"NPCName", "NPCModel", "NPCSequence", "TraderDescription",
		"Dialogue", "TraderID", "Factions", "UnlockItem", "UnlockAmount"},
	nw_recruiter = {"NPCName", "NPCModel", "NPCSequence", "ConfigID"},
	nw_vending = {},
	nw_dispenser = {"StockBasic", "StockStandard", "StockPremium", "Enabled"},
	nw_locker = {},
	nw_container = {"ContainerID", "ContainerName", "ContainerDescription",
		"ContainerSlots", "ContainerRefill"},
	nw_forcefield = {"Mode"},
	nw_text = {"Text", "TextSize", "TextColor"},
	nw_led = {"Text", "Subtext", "Style", "TextScale"},
	nw_lock = {"Locked"},
	nw_junk = {"JunkModel", "MinItems", "MaxItems"},
	nw_supply_depot = {},
	nw_supply_point = {},
	nw_admin_computer = {},
	nw_council_computer = {},
	nw_housing_camera = {"CamName"},
	nw_train_point = {},
	nw_furniture = {"FurnModel", "Kind", "OwnerChar", "FurnitureID", "Locked"},
	nw_business_terminal = {},
	nw_workterminal = {},
	nw_infoterminal = {},
	nw_craft_table = {"Title", "CraftModel", "Recipes"},
	nw_shop_fixture = {"FixModel", "Kind", "OwnerChar", "ShopName", "Open"}
}

NETWORK.mapents.body = {
	nw_npc = true,
	nw_trader = true,
	nw_recruiter = true
}

NETWORK.mapents.raw = {
	nw_trader = {"offers"},
	nw_container = {"items"},
	nw_vending = {"stock"},
	nw_junk = {"loot"}
}

local function Path()
	return "network/entities_" .. game.GetMap() .. ".txt"
end

local function PositionKey(class, position)
	return class .. ":" .. math.Round(position.x / 4) .. ":" ..
		math.Round(position.y / 4) .. ":" .. math.Round(position.z / 4)
end

function NETWORK.mapents.Collect()
	local list = {}
	local seen = {}

	for class, fields in pairs(NETWORK.mapents.classes) do
		for _, entity in ipairs(ents.FindByClass(class)) do
			local key = PositionKey(class, entity:GetPos())

			if (class == "nw_lock") then
				if (!IsValid(entity.door)) then
					continue
				end

				key = "nw_lock:door:" .. entity.door:MapCreationID()
			end

			if (seen[key]) then
				continue
			end

			seen[key] = true

			local angles = NETWORK.mapents.body[class] and entity.baseAngles or
				entity:GetAngles()

			local entry = {
				class = class,
				pos = {entity:GetPos().x, entity:GetPos().y, entity:GetPos().z},
				ang = {angles.p, angles.y, angles.r},
				data = {}
			}

			if (NETWORK.mapents.body[class] and NETWORK.entities and
				NETWORK.entities.CollectBody) then
				entry.body = NETWORK.entities.CollectBody(entity, {})
			end

			if (class == "nw_lock") then
				local door = entity.door

				if (!IsValid(door)) then
					continue
				end

				entry.door = door:MapCreationID()

				if (entry.door == -1) then
					continue
				end

				local localPos, localAng = WorldToLocal(entity:GetPos(), entity:GetAngles(),
					door:GetPos(), door:GetAngles())

				entry.localPos = {localPos.x, localPos.y, localPos.z}
				entry.localAng = {localAng.p, localAng.y, localAng.r}
			end

			for _, field in ipairs(NETWORK.mapents.raw[class] or {}) do
				if (istable(entity[field])) then
					entry.data["#" .. field] = table.Copy(entity[field])
				end
			end

			for _, field in ipairs(fields) do
				local getter = entity["Get" .. field]

				if (!getter) then
					continue
				end

				local value = getter(entity)

				if (isvector(value)) then
					value = {value.x, value.y, value.z}
				elseif (IsColor(value)) then
					value = {value.r, value.g, value.b}
				end

				entry.data[field] = value
			end

			local color = entity:GetColor()

			entry.look = {material = entity:GetMaterial() or "", color = {color.r, color.g, color.b, color.a}}

			list[#list + 1] = entry
		end
	end

	return list
end

function NETWORK.mapents.Save()
	file.CreateDir("network")
	file.Write(Path(), util.TableToJSON(NETWORK.mapents.Collect(), true))
end

local function BuildDoorIndex()
	local index = {}

	for _, entity in ipairs(ents.GetAll()) do
		local id = entity:MapCreationID()

		if (id != -1) then
			index[id] = entity
		end
	end

	return index
end

local function AlreadyPlaced(class, position)
	for _, entity in ipairs(ents.FindInSphere(position, 12)) do
		if (entity:GetClass() == class) then
			return true
		end
	end

	return false
end

function NETWORK.mapents.Load()

	if (NETWORK.mapents.bLoaded) then
		return
	end

	NETWORK.mapents.bLoaded = true

	local contents = file.Read(Path(), "DATA")

	if (!contents) then
		return
	end

	local list = util.JSONToTable(contents)

	if (!istable(list)) then
		return
	end

	local doors = BuildDoorIndex()

	for _, entry in ipairs(list) do
		local fields = NETWORK.mapents.classes[entry.class]

		if (!fields) then
			continue
		end

		local position = Vector(entry.pos[1], entry.pos[2], entry.pos[3])
		local angles = Angle(entry.ang[1], entry.ang[2], entry.ang[3])

		if (entry.class == "nw_lock") then
			local door = entry.door and doors[entry.door]

			if (!IsValid(door) or IsValid(door.nwLock)) then
				continue
			end

			if (istable(entry.localPos) and istable(entry.localAng)) then
				position, angles = LocalToWorld(
					Vector(entry.localPos[1], entry.localPos[2], entry.localPos[3]),
					Angle(entry.localAng[1], entry.localAng[2], entry.localAng[3]),
					door:GetPos(), door:GetAngles())
			end
		elseif (AlreadyPlaced(entry.class, position)) then
			continue
		end

		local entity = ents.Create(entry.class)

		if (!IsValid(entity)) then
			continue
		end

		entity:SetPos(position)
		entity:SetAngles(angles)
		entity:Spawn()

		if (istable(entry.look) and NETWORK.entities and NETWORK.entities.ApplyLook) then
			NETWORK.entities.ApplyLook(entity, entry.look)
		end
		entity:Activate()

		for _, field in ipairs(fields) do
			local setter = entity["Set" .. field]
			local value = entry.data and entry.data[field]

			if (!setter or value == nil) then
				continue
			end

			if (istable(value)) then
				value = #value == 3 and Vector(value[1], value[2], value[3]) or value
			end

			setter(entity, value)
		end

		for _, field in ipairs(NETWORK.mapents.raw[entry.class] or {}) do
			local value = entry.data and entry.data["#" .. field]

			if (istable(value)) then
				entity[field] = value
			end
		end

		-- Старые сохранения хранят прежний размер; не даём ему быть меньше текущего в реестре.
		if (entry.class == "nw_container" and entity.SetContainerSlots) then
			local data = NETWORK.container.Get(entity:GetContainerID())

			if (data and entity:GetContainerSlots() < data.slots) then
				entity:SetContainerSlots(data.slots)
			end
		end

		if (entry.class == "nw_trader" and istable(entity.offers)) then
			entity.offers = NETWORK.trade.CleanOffers(entity.offers)
		end

		if (entry.class == "nw_lock") then
			local door = entry.door and doors[entry.door]

			if (!IsValid(door) or entity:Attach(door, position, angles) == false) then
				if (IsValid(entity)) then
					entity:Remove()
				end

				continue
			end
		end

		if (entity.Apply) then
			entity:Apply()
		end

		if (istable(entry.body) and NETWORK.entities and NETWORK.entities.RestoreBody) then
			NETWORK.entities.RestoreBody(entity, entry.body)
		end
	end
end

concommand.Add("network_entities_save", function(client)
	if (IsValid(client) and !client:IsSuperAdmin()) then
		return
	end

	NETWORK.mapents.Save()

	NETWORK.util.Print("Сущности сохранены: " .. Path())
end, nil, "Сохраняет расставленные NPC, торговцев и прочие сущности")

function NETWORK.mapents.Dedupe()
	local removed = 0

	for class in pairs(NETWORK.mapents.classes) do
		local seen = {}

		for _, entity in ipairs(ents.FindByClass(class)) do
			local key = PositionKey(class, entity:GetPos())

			if (seen[key]) then
				entity:Remove()

				removed = removed + 1
			else
				seen[key] = true
			end
		end
	end

	if (removed > 0) then
		NETWORK.mapents.Save()
	end

	return removed
end

concommand.Add("network_entities_dedupe", function(client)
	if (IsValid(client) and !client:IsSuperAdmin()) then
		return
	end

	NETWORK.util.Print("Удалено дубликатов: " .. NETWORK.mapents.Dedupe())
end, nil, "Удаляет наложенные друг на друга сущности и пересохраняет карту")

function NETWORK.mapents.Wipe()
	local removed = 0

	for class in pairs(NETWORK.mapents.classes) do
		for _, entity in ipairs(ents.FindByClass(class)) do
			entity:Remove()

			removed = removed + 1
		end
	end

	file.Delete(Path())

	NETWORK.mapents.bLoaded = true

	return removed
end

NETWORK.command.Register("clearall", {
	adminOnly = true,
	description = "cmdClearAll",
	usage = "/clearall confirm",
	OnRun = function(command, client, arguments)
		if (string.lower(arguments[1] or "") != "confirm") then
			return NETWORK.chat.Notice(client, L("clearConfirm"))
		end

		local entities = NETWORK.mapents.Wipe()

		local zones = NETWORK.zone and NETWORK.zone.Clear and NETWORK.zone.Clear() or 0

		NETWORK.chat.Notice(client, L("clearDone", entities, zones))
		NETWORK.util.Print(client:SteamID() .. " очистил карту: сущностей " ..
			entities .. ", зон " .. zones)
	end
})

concommand.Add("network_clear_all", function(client)
	if (IsValid(client) and !client:IsSuperAdmin()) then
		return
	end

	local entities = NETWORK.mapents.Wipe()
	local zones = NETWORK.zone and NETWORK.zone.Clear and NETWORK.zone.Clear() or 0

	NETWORK.util.Print("Удалено: сущностей " .. entities .. ", зон " .. zones)
end, nil, "Удаляет все расставленные сущности и зоны вместе с их файлами")

concommand.Add("network_entities_clear", function(client)
	if (IsValid(client) and !client:IsSuperAdmin()) then
		return
	end

	file.Delete(Path())

	NETWORK.util.Print("Сохранение сущностей удалено")
end, nil, "Удаляет файл сохранения сущностей карты")

hook.Add("InitPostEntity", "nwMapEnts", function()
	timer.Simple(3, function()
		NETWORK.mapents.Load()
	end)

	timer.Create("nwMapEntsSave", 120, 0, function()
		NETWORK.mapents.Save()
	end)
end)

hook.Add("ShutDown", "nwMapEnts", function()
	NETWORK.mapents.Save()
end)
