util.AddNetworkString("nwItemEditSync")
util.AddNetworkString("nwItemEditSave")
util.AddNetworkString("nwItemCustomSync")
util.AddNetworkString("nwItemCustomRequest")
util.AddNetworkString("nwItemCustomSave")
util.AddNetworkString("nwItemCustomDelete")
util.AddNetworkString("nwItemCustomResult")
util.AddNetworkString("nwItemCustomOpen")

local E = NETWORK.itemedit
local dataPath = "network/itemedits.txt"
local customPath = "network/customitems.txt"

local function CanEdit(client, key, interval)
	if (!IsValid(client) or !client:IsAdmin()) then
		return false
	end

	local now = CurTime()

	client.nwItemEditNext = client.nwItemEditNext or {}

	if ((client.nwItemEditNext[key] or 0) > now) then
		return false
	end

	client.nwItemEditNext[key] = now + (interval or 1)

	return true
end

local function Log(client, text)
	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("admin", string.format("%s (%s) %s", client:Nick(),
			client:SteamID(), text))
	end
end

function E.Load()
	local raw = file.Read(dataPath, "DATA")
	local data = raw and util.JSONToTable(raw)

	E.stored = {}

	for id, payload in pairs(istable(data) and data or {}) do
		id = tostring(id)

		local clean = E.Clean(payload)

		if (clean and NETWORK.item.Get(id) and !E.IsCustom(id)) then
			E.stored[id] = clean
		end
	end

	E.ApplyAll()
end

function E.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(E.stored, true))
end

function E.Sync(target)
	net.Start("nwItemEditSync")
		NETWORK.util.WriteTable(E.stored)

	if (IsValid(target)) then
		net.Send(target)
	else
		net.Broadcast()
	end
end

E.broken = E.broken or {}

function E.SaveCustom()
	local items = {}

	for id, def in pairs(E.broken) do
		items[id] = def
	end

	for id, def in pairs(E.custom) do
		items[id] = def
	end

	file.CreateDir("network")
	file.Write(customPath, util.TableToJSON({version = 1, items = items}, true))
end

function E.LoadCustom()
	local raw = file.Read(customPath, "DATA")
	local data = raw and util.JSONToTable(raw)
	local items = istable(data) and istable(data.items) and data.items or {}
	local pending = {}

	E.broken = {}

	for id, def in pairs(items) do
		id = tostring(id)

		if (!E.IsValidID(id) or !istable(def)) then
			continue
		end

		local existing = NETWORK.item.Get(id)

		if (existing and !existing.bCustom) then
			NETWORK.util.PrintWarning(string.format(
				"Свой предмет «%s» пропущен: есть предмет из файла с тем же id", id))

			E.broken[id] = def

			continue
		end

		pending[id] = def

		E.RegisterCustom(id, def)
	end

	local count = 0

	for id, def in pairs(pending) do
		local clean, key, field = E.CleanCustom(id, def, {bLenient = true})

		if (clean) then
			E.RegisterCustom(id, clean)

			count = count + 1
		else
			E.UnregisterCustom(id)

			E.broken[id] = def

			NETWORK.util.PrintWarning(string.format("Свой предмет «%s» не загружен: %s (%s)",
				id, tostring(key), tostring(field)))
		end
	end

	if (count > 0) then
		NETWORK.util.Print("Загружено своих предметов: " .. count)
	end

	E.OnCustomChanged()
end

local engineWeapons = {
	weapon_crowbar = true, weapon_stunstick = true, weapon_pistol = true,
	weapon_357 = true, weapon_smg1 = true, weapon_ar2 = true, weapon_shotgun = true,
	weapon_crossbow = true, weapon_rpg = true, weapon_frag = true, weapon_slam = true,
	weapon_physcannon = true, weapon_bugbait = true
}

function E.ServerCheck(clean)
	for _, field in ipairs({"model", "replaceModel"}) do
		if (clean[field] and !file.Exists(clean[field], "GAME")) then
			return false, "itemCreateErrModelMissing", field
		end
	end

	if (clean.useSound and !file.Exists("sound/" .. clean.useSound, "GAME")) then
		return false, "itemCreateErrSoundMissing", "useSound"
	end

	if (clean.weaponClass) then
		local class = clean.weaponClass
		local listed = list.Get("Weapon") or {}

		if (!engineWeapons[class] and !weapons.GetStored(class) and !listed[class]) then
			return false, "itemCreateErrWeapon", "weaponClass"
		end
	end

	if (clean.ammoType and (game.GetAmmoID(clean.ammoType) or -1) < 0) then
		return false, "itemCreateErrAmmo", "ammoType"
	end

	return true
end

local chunkLimit = 24000

function E.SyncCustom(target)
	local ids = table.GetKeys(E.custom)
	local chunks = {}
	local current, size = {}, 0

	table.sort(ids)

	for _, id in ipairs(ids) do
		local def = E.custom[id]
		local length = #(util.TableToJSON(def) or "") + #id

		if (size > 0 and size + length > chunkLimit) then
			chunks[#chunks + 1] = current
			current, size = {}, 0
		end

		current[id] = def
		size = size + length
	end

	chunks[#chunks + 1] = current

	for index, chunk in ipairs(chunks) do
		net.Start("nwItemCustomSync")
			net.WriteUInt(0, 2)
			net.WriteBool(index == 1)
			net.WriteBool(index == #chunks)
			NETWORK.util.WriteTable(chunk)

		if (IsValid(target)) then
			net.Send(target)
		else
			net.Broadcast()
		end
	end
end

local function BroadcastUpsert(id)
	net.Start("nwItemCustomSync")
		net.WriteUInt(1, 2)
		net.WriteString(id)
		NETWORK.util.WriteTable(E.custom[id] or {})
	net.Broadcast()
end

local function BroadcastRemove(id)
	net.Start("nwItemCustomSync")
		net.WriteUInt(2, 2)
		net.WriteString(id)
	net.Broadcast()
end

local function Reply(client, bOk, key, field, id)
	net.Start("nwItemCustomResult")
		net.WriteBool(bOk)
		net.WriteString(key or "")
		net.WriteString(field or "")
		net.WriteString(id or "")
	net.Send(client)
end

local stateLists = {"items", "storage", "equipped", "clothes"}

local function ForEachContainer(callback)
	for class in pairs(NETWORK.container and NETWORK.container.classes or {}) do
		for _, entity in ipairs(ents.FindByClass(class)) do
			if (istable(entity.items)) then
				callback(entity)
			end
		end
	end
end

function E.RefreshHolders(id)
	local base = NETWORK.item.Get(id)

	for _, client in ipairs(player.GetAll()) do
		local state = client.nwInventory

		if (!istable(state)) then
			continue
		end

		local bHas = false

		for _, list in ipairs(stateLists) do
			for slot, item in pairs(state[list] or {}) do
				if (!istable(item) or item.id != id) then
					continue
				end

				bHas = true

				if (list == "equipped" and base and base.equipSlot != slot) then
					state.equipped[slot] = nil

					if (NETWORK.inventory.Insert(state, item) > 0) then
						NETWORK.item.Spawn(id, client:GetPos() + client:GetForward() * 24 +
							Vector(0, 0, 16), nil, item.amount, item.data)
					end
				end
			end
		end

		if (bHas) then
			NETWORK.inventory.Sync(client)
		end
	end
end

function E.PurgeInstances(id)
	local removed = 0

	for _, client in ipairs(player.GetAll()) do
		local state = client.nwInventory
		local bChanged = false

		if (!istable(state)) then
			continue
		end

		for _, list in ipairs(stateLists) do
			for key, item in pairs(state[list] or {}) do
				if (istable(item) and item.id == id) then
					state[list][key] = nil
					removed = removed + (item.amount or 1)
					bChanged = true
				end
			end
		end

		if (bChanged) then
			NETWORK.inventory.Sync(client)
		end
	end

	for _, entity in ipairs(ents.FindByClass("nw_item")) do
		if (entity.GetItemID and entity:GetItemID() == id) then
			removed = removed + 1
			entity:Remove()
		end
	end

	ForEachContainer(function(entity)
		local bChanged = false

		for key, item in pairs(entity.items) do
			if (istable(item) and item.id == id) then
				entity.items[key] = nil
				removed = removed + (item.amount or 1)
				bChanged = true
			end
		end

		if (bChanged and NETWORK.container.Sync) then
			NETWORK.container.Sync(entity)
		end
	end)

	return removed
end

local function DropReferences(id)
	for otherID, def in pairs(E.custom) do
		local bChanged = false

		if (def.trash == id) then
			def.trash = nil
			bChanged = true
		end

		for _, field in ipairs({"contents", "storageBlacklist"}) do
			local list = def[field]

			if (istable(list)) then
				for index = #list, 1, -1 do
					local entry = list[index]

					if ((istable(entry) and entry[1] or entry) == id) then
						table.remove(list, index)
						bChanged = true
					end
				end

				if (#list == 0) then
					def[field] = nil
				end
			end
		end

		if (bChanged) then
			E.RegisterCustom(otherID, def)
			BroadcastUpsert(otherID)
		end
	end
end

local idCounter = 0

local function GenerateID()
	repeat
		idCounter = idCounter + 1

		local id = string.format("custom_%x%d", os.time(), idCounter)

		if (!NETWORK.item.Get(id)) then
			return id
		end
	until (idCounter > 100000)
end

net.Receive("nwItemCustomRequest", function(_, client)
	if (!IsValid(client) or (client.nwItemCustomAsked or 0) > CurTime()) then
		return
	end

	client.nwItemCustomAsked = CurTime() + 5

	E.SyncCustom(client)
end)

net.Receive("nwItemCustomSave", function(_, client)
	if (!CanEdit(client, "save", 1)) then
		return
	end

	local bNew = net.ReadBool()
	local id = string.lower(string.Trim(net.ReadString() or ""))
	local payload = NETWORK.util.ReadTable()

	if (bNew) then
		if (id == "") then
			id = GenerateID()
		end

		if (!E.IsValidID(id)) then
			return Reply(client, false, "itemCreateErrID", "id")
		end

		if (NETWORK.item.Get(id) or E.broken[id]) then
			return Reply(client, false, "itemCreateErrTaken", "id")
		end

		if (table.Count(E.custom) >= E.maxCustom) then
			return Reply(client, false, "itemCreateErrLimit", "id")
		end
	elseif (!E.IsCustom(id)) then
		return Reply(client, false, "itemCreateErrMissing", "id")
	end

	local clean, key, field = E.CleanCustom(id, payload)

	if (!clean) then
		return Reply(client, false, key, field)
	end

	local bOk
	bOk, key, field = E.ServerCheck(clean)

	if (!bOk) then
		return Reply(client, false, key, field)
	end

	E.RegisterCustom(id, clean)
	E.SaveCustom()

	BroadcastUpsert(id)

	if (!bNew) then
		E.RefreshHolders(id)
	end

	E.OnCustomChanged()

	Reply(client, true, bNew and "itemCreateCreated" or "itemCreateUpdated", "", id)

	Log(client, (bNew and "создал предмет " or "изменил свой предмет ") .. id ..
		" (" .. clean.name .. ")")
end)

net.Receive("nwItemCustomDelete", function(_, client)
	if (!CanEdit(client, "delete", 1)) then
		return
	end

	local id = net.ReadString() or ""

	if (!E.IsCustom(id)) then
		return Reply(client, false, "itemCreateErrMissing", "id")
	end

	local name = E.custom[id].name or id
	local removed = E.PurgeInstances(id)

	E.UnregisterCustom(id)

	DropReferences(id)

	E.stored[id] = nil
	E.original[id] = nil

	if (NETWORK.icon and NETWORK.icon.stored and NETWORK.icon.stored[id]) then
		NETWORK.icon.stored[id] = nil
		NETWORK.icon.Save()
		NETWORK.icon.Sync()
	end

	E.SaveCustom()

	BroadcastRemove(id)
	E.OnCustomChanged()

	Reply(client, true, "itemCreateDeleted", tostring(removed), id)

	Log(client, string.format("удалил свой предмет %s (%s), убрано вещей: %d", id, name,
		removed))
end)

net.Receive("nwItemEditSave", function(_, client)
	if (!CanEdit(client, "edit", 0.5)) then
		return
	end

	local id = net.ReadString()
	local payload = NETWORK.util.ReadTable()

	if (!istable(payload) or !NETWORK.item.Get(id)) then
		return
	end

	if (E.IsCustom(id)) then
		if (payload.bReset) then
			return
		end

		local def = table.Copy(E.custom[id])
		local edit = E.Clean(payload) or {}

		for key, value in pairs(edit) do
			def[key] = value
		end

		local clean = E.CleanCustom(id, def)

		if (!clean or !E.ServerCheck(clean)) then
			NETWORK.notice.Send(client, "itemCreateErrPayload", "bad")

			return
		end

		E.RegisterCustom(id, clean)
		E.SaveCustom()

		BroadcastUpsert(id)
		E.RefreshHolders(id)
		E.OnCustomChanged()

		NETWORK.notice.Send(client, "itemEditSaved", "good", clean.name)

		return
	end

	if (payload.bReset) then
		E.stored[id] = nil
	else
		E.stored[id] = E.Clean(payload)
	end

	E.Save()
	E.ApplyAll()
	E.Sync()

	NETWORK.notice.Send(client, payload.bReset and "itemEditReset" or "itemEditSaved", "good",
		NETWORK.item.Get(id).name)

	Log(client, "изменил предмет " .. id)
end)

hook.Add("PlayerInitialSpawn", "nwItemEdit", function(client)
	timer.Simple(2.5, function()
		if (IsValid(client)) then
			E.Sync(client)
		end
	end)
end)

hook.Add("Initialize", "nwItemEdit", function()
	E.Load()
end)

E.LoadCustom()

NETWORK.command.Register("itemsedit", {
	adminOnly = true,
	description = "cmdItemsEdit",
	usage = "/itemsedit",
	aliases = {"itemedit", "предметы"},
	OnRun = function(command, client)
		net.Start("nwIconSync")
			NETWORK.util.WriteTable(NETWORK.icon.stored)
		net.Send(client)

		E.Sync(client)

		net.Start("nwIconEditor")
		net.Send(client)
	end
})

NETWORK.command.Register("itemcreate", {
	adminOnly = true,
	description = "cmdItemCreate",
	usage = "/itemcreate",
	aliases = {"itemcreator", "создатьпредмет"},
	OnRun = function(command, client)
		E.SyncCustom(client)

		net.Start("nwItemCustomOpen")
		net.Send(client)
	end
})
