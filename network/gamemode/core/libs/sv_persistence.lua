NETWORK.persistence = NETWORK.persistence or {}
NETWORK.persistence.cache = NETWORK.persistence.cache or {}

local dataPath = "network/state.txt"

local function Notify(client, key)
	if (!IsValid(client)) then
		return
	end

	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end
local TABLE_NAME = "network_character_state"

local function Query(query, callback)
	local result = sql.Query(query)
	local err = result == false and sql.LastError() or nil
	if (err) then NETWORK.util.PrintWarning("SQL: " .. tostring(err)) end
	if (callback) then callback(result, err) end
	return result
end

Query("CREATE TABLE IF NOT EXISTS " .. TABLE_NAME .. " (id INTEGER PRIMARY KEY, data TEXT NOT NULL)")
hook.Add("NetworkDatabaseReady", "nwPersistenceMirror", function()
	NETWORK.db.CreateTable("network_character_state_mirror", {{"id", "INTEGER PRIMARY KEY"}, {"data", "TEXT NOT NULL"}})
	for _, row in ipairs(Query("SELECT id, data FROM " .. TABLE_NAME) or {}) do
		NETWORK.db.Query(string.format("REPLACE INTO %s (id, data) VALUES (%d, %s)", "network_character_state_mirror",
			tonumber(row.id), NETWORK.db.Escape(row.data)))
	end
end)

NETWORK.persistence.backupKeep = 10

function NETWORK.persistence.BackupData()
	local files = file.Find("network/*.txt", "DATA") or {}

	if (#files == 0) then
		return
	end

	file.CreateDir("network/backup")

	local stamp = os.date("%Y-%m-%d_%H-%M-%S")
	local copied = 0

	for _, name in ipairs(files) do
		local contents = file.Read("network/" .. name, "DATA")

		if (contents and contents != "") then
			local base = string.StripExtension(name)

			file.Write("network/backup/" .. base .. "_" .. stamp .. ".txt", contents)

			copied = copied + 1

			local copies = file.Find("network/backup/" .. base .. "_*.txt", "DATA") or {}

			table.sort(copies)

			for index = 1, #copies - NETWORK.persistence.backupKeep do
				file.Delete("network/backup/" .. copies[index])
			end
		end
	end

	NETWORK.util.Print(string.format("[СОХРАНЕНИЕ] резервные копии: %d файлов в data/network/backup", copied))
end

hook.Add("Initialize", "nwPersistenceBackup", function()
	timer.Simple(5, NETWORK.persistence.BackupData)
end)

concommand.Add("nw_backup", function(client)
	if (IsValid(client) and !client:IsSuperAdmin()) then
		return
	end

	NETWORK.persistence.BackupData()
end)

function NETWORK.persistence.Ingest(rows)
	if (!istable(rows)) then
		return 0
	end

	local count = 0

	for _, row in ipairs(rows) do
		local data = util.JSONToTable(row.data or "")

		if (istable(data)) then
			NETWORK.persistence.cache[tostring(row.id)] = data
			count = count + 1
		end
	end

	return count
end

function NETWORK.persistence.LoadAll()
	local cache = NETWORK.persistence.cache
	local backup = util.JSONToTable(file.Read(dataPath, "DATA") or "{}")
	if (istable(backup)) then
		for id, data in pairs(backup) do
			if (istable(data) and !cache[tostring(id)]) then cache[tostring(id)] = data end
		end
	end
	for _, row in ipairs(Query("SELECT id, data FROM " .. TABLE_NAME) or {}) do
		local id = tostring(row.id)
		local data = util.JSONToTable(row.data or "")
		if (istable(data) and (!cache[id] or
			(tonumber(data.updatedAt) or 0) >= (tonumber(cache[id].updatedAt) or 0))) then
			cache[id] = data
		end
	end
	NETWORK.util.Print("[СОХРАНЕНИЕ] загружено персонажей: " .. table.Count(cache))
end

local written = {}

local pending = {}

function NETWORK.persistence.Write(id, data, bImmediate)
	local encoded = util.TableToJSON(data)

	if (!encoded) then
		NETWORK.util.PrintWarning("Не удалось упаковать состояние #" .. tostring(id))

		return false
	end

	id = tostring(id)

	if (written[id] == encoded) then
		return false
	end

	pending[id] = encoded

	if (bImmediate) then
		NETWORK.persistence.Flush()
	end

	return true
end

function NETWORK.persistence.Flush()
	if (next(pending) == nil) then return 0 end
	local batch = pending
	pending = {}
	local count = 0
	for id, encoded in pairs(batch) do
		local escaped = sql.SQLStr(encoded)
		Query(string.format("REPLACE INTO %s (id, data) VALUES (%d, %s)", TABLE_NAME,
			tonumber(id) or 0, escaped), function(_, err)
			if (err) then
				pending[id] = pending[id] or encoded
			else
				written[id] = encoded
				if (NETWORK.db.IsMySQL()) then
					NETWORK.db.Query(string.format("REPLACE INTO %s (id, data) VALUES (%d, %s)", "network_character_state_mirror",
						tonumber(id), NETWORK.db.Escape(encoded)))
				end
			end
		end)
		count = count + 1
	end
	NETWORK.persistence.bBackupDirty = true
	return count
end

function NETWORK.persistence.WriteBackup()
	if (!NETWORK.persistence.bBackupDirty) then
		return
	end

	file.CreateDir("network")

	local encoded = util.TableToJSON(NETWORK.persistence.cache)

	if (encoded) then
		file.Write(dataPath, encoded)
	end

	NETWORK.persistence.bBackupDirty = false
end

function NETWORK.persistence.SaveAll()
	for id, data in pairs(NETWORK.persistence.cache) do
		NETWORK.persistence.Write(id, data)
	end

	NETWORK.persistence.Flush()
	NETWORK.persistence.WriteBackup()

	return true
end

local function CleanItems(list)
	local clean = {}

	for index, item in pairs(list or {}) do
		if (!istable(item) or !NETWORK.item.Get(item.id)) then
			continue
		end

		clean[tostring(index)] = table.Copy(item)
		clean[tostring(index)].amount = math.max(math.Round(tonumber(item.amount) or 1), 1)
	end

	return clean
end

function NETWORK.persistence.Collect(client)
	local character = client:GetCharacter()

	if (!character or character.bTemporary or client.nwRestore) then
		return
	end

	local previous = NETWORK.persistence.cache[tostring(character:GetID())]
	local position = client:GetPos()
	local angles = client:EyeAngles()
	local health = math.max(client:Health(), 1)
	local state = NETWORK.inventory.GetState(client)
	local weapons = {}

	if (!client:Alive()) then
		if (istable(previous) and istable(previous.position) and istable(previous.angles)) then
			position = Vector(previous.position[1], previous.position[2],
				previous.position[3])
			angles = Angle(previous.angles[1], previous.angles[2], 0)
			health = previous.health or health
		else
			position = nil
			angles = nil
			health = nil
		end
	end

	for _, weapon in ipairs(client:GetWeapons()) do
		local class = weapon:GetClass()

		if (class == NETWORK.weapon.hands) then
			continue
		end

		weapons[#weapons + 1] = {
			class = class,
			clip = weapon:Clip1(),
			ammo = client:GetAmmoCount(weapon:GetPrimaryAmmoType())
		}
	end

	return {
		updatedAt = os.time(),
		height = character:GetHeight(),
		map = game.GetMap(),
		bStarted = client.nwStarted == true,

		position = position and {position.x, position.y, position.z} or nil,
		angles = angles and {angles.p, angles.y} or nil,
		health = health,
		armour = client:Armor(),
		hunger = client:GetHunger(),
		thirst = client:GetThirst(),
		stamina = client:GetStamina(),
		tokens = client:GetTokens(),
		wounds = table.Copy(client.nwWounds or {}),
		traderLevels = table.Copy(client.nwTraderLevels or {}),
		traderUnlocked = table.Copy(client.nwTraderUnlocked or {}),
		bank = math.max(math.Round(client.nwBank or 0), 0),
		loyalty = client.nwLoyalty or NETWORK.loyalty.default,
		recognised = table.GetKeys(client.nwRecognised or {}),
		bodygroups = table.Copy(client.nwBodygroups or {}),
		skin = client.nwSkin,
		weapons = weapons,
		inventory = {
			items = CleanItems(state.items),
			storage = CleanItems(state.storage),
			equipped = CleanItems(state.equipped)
		}
	}
end

function NETWORK.persistence.Save(client, bWrite)
	if (!IsValid(client)) then
		return
	end

	local character = client:GetCharacter()

	if (!character) then
		return
	end

	local data = NETWORK.persistence.Collect(client)

	if (!data) then
		return
	end

	hook.Run("NetworkPersistenceCollect", client, data)

	NETWORK.persistence.cache[tostring(character:GetID())] = data

	local bChanged = NETWORK.persistence.Write(character:GetID(), data,
		bWrite != false)

	if (bChanged and bWrite != false) then
		NETWORK.util.Print(string.format(
			"[СОХРАНЕНИЕ] записан #%d: предметов %d, %s HP",
			character:GetID(), table.Count(data.inventory.items),
			data.health and math.Round(data.health) or "-"))
	end

	return data
end

function NETWORK.persistence.Get(character)
	if (!character or character.bTemporary) then
		return
	end

	local data = NETWORK.persistence.cache[tostring(character:GetID())]

	if (!istable(data)) then
		return
	end

	return data
end

function NETWORK.persistence.Apply(client)
	local data = client.nwRestore

	if (!data or !IsValid(client) or !client:Alive()) then
		return
	end

	client.nwRestore = nil
	local character = client:GetCharacter()
	if (character and tonumber(data.height)) then
		character.height = math.Clamp(tonumber(data.height), NETWORK.creation.heightMin, NETWORK.creation.heightMax)
	end

	hook.Run("NetworkPersistenceRestore", client, data)

	if (istable(data.position) and data.map == game.GetMap()) then
		local position = Vector(data.position[1], data.position[2], data.position[3])
		local trace = util.TraceHull({
			start = position + Vector(0, 0, 16),
			endpos = position - Vector(0, 0, 160),
			mins = Vector(-16, -16, 0),
			maxs = Vector(16, 16, 72),
			filter = client,
			mask = MASK_PLAYERSOLID
		})

		client:SetPos(trace.Hit and trace.HitPos or position)
		client:SetVelocity(-client:GetVelocity())
	end

	if (istable(data.angles)) then
		client:SetEyeAngles(Angle(data.angles[1], data.angles[2], 0))
	end

	if (istable(data.inventory)) then
		local state = NETWORK.inventory.NewState()

		for _, key in ipairs({"items", "storage"}) do
			for index, item in pairs(data.inventory[key] or {}) do
				if (!NETWORK.item.Get(item.id)) then
					continue
				end

				local slot = tonumber(index)
				if (slot) then state[key][slot] = table.Copy(item) end
			end
		end

		for slot, item in pairs(data.inventory.equipped or {}) do

			if (NETWORK.item.GetEquipSlot(item) != slot) then
				continue
			end

			state.equipped[slot] = table.Copy(item)
		end

		client.nwInventory = state
		client.nwStarted = true
	end

	local maximum = client:GetMaxHealth()
	local minimum = math.max(math.floor(maximum * 0.35), 25)

	client:SetHealth(math.Clamp(data.health or maximum, minimum, maximum))
	client:SetArmor(math.Clamp(data.armour or 0, 0, 100))
	client:SetNWFloat("nwHunger", math.Clamp(data.hunger or 100, 0, 100))
	client:SetNWFloat("nwThirst", math.Clamp(data.thirst or 100, 0, 100))

	NETWORK.needs.PushStamina(client,
		math.Clamp(data.stamina or NETWORK.stamina.GetMax(client),
		NETWORK.stamina.recoverAt, NETWORK.stamina.GetMax(client)), true)
	client:SetNWBool("nwExhausted", false)

	if (data.tokens) then
		NETWORK.currency.Set(client, data.tokens)
	end

	if (istable(data.bodygroups)) then
		client.nwBodygroups = {}

		for index, value in pairs(data.bodygroups) do
			client.nwBodygroups[tonumber(index)] = math.Round(tonumber(value) or 0)
		end
	end

	if (data.skin) then
		client.nwSkin = math.Round(data.skin)
	end

	if (istable(data.traderLevels)) then
		client.nwTraderLevels = table.Copy(data.traderLevels)
	end

	client.nwBank = math.max(math.Round(tonumber(data.bank) or 0), 0)

	local character = client:GetCharacter()
	local storedLoyalty = character and NETWORK.loyalty.stored and
		NETWORK.loyalty.stored[tostring(character:GetID())]

	NETWORK.loyalty.Set(client, tonumber(storedLoyalty) or tonumber(data.loyalty) or
		NETWORK.loyalty.default)

	if (istable(data.recognised)) then
		client.nwRecognised = {}

		for _, id in ipairs(data.recognised) do
			client.nwRecognised[tonumber(id) or 0] = true
		end

		client.nwRecognised[0] = nil
	end

	if (istable(data.traderUnlocked)) then
		client.nwTraderUnlocked = table.Copy(data.traderUnlocked)
	end

	if (istable(data.wounds)) then
		client.nwWounds = table.Copy(data.wounds)

		NETWORK.wound.Sync(client)
	end

	NETWORK.inventory.RefreshWeapons(client)

	for _, entry in ipairs(data.weapons or {}) do
		if (!client:HasWeapon(entry.class)) then
			continue
		end

		local weapon = client:GetWeapon(entry.class)

		if (IsValid(weapon)) then
			weapon:SetClip1(entry.clip or 0)

			local ammoType = weapon:GetPrimaryAmmoType()

			if (ammoType and ammoType > 0) then
				client:SetAmmo(entry.ammo or 0, ammoType)
			end
		end
	end

	NETWORK.inventory.Sync(client)
	NETWORK.inventory.RefreshWeapons(client)
	NETWORK.inventory.RefreshAppearance(client)
	NETWORK.movement.Apply(client)
	NETWORK.player.ApplyScale(client)

	Notify(client, "saveRestored")

	NETWORK.util.Print(string.format(
		"[СОХРАНЕНИЕ] восстановлен %s: предметов %d, %d HP, позиция %s (%d %d %d)",
		client:SteamID(), table.Count(NETWORK.inventory.GetState(client).items),
		math.Round(data.health or 0),
		data.map == game.GetMap() and "применена" or "пропущена, другая карта",
		math.Round((data.position or {})[1] or 0), math.Round((data.position or {})[2] or 0),
		math.Round((data.position or {})[3] or 0)))
end

hook.Add("NetworkCharacterLoaded", "nwPersistence", function(client, character)
	client.nwRestore = NETWORK.persistence.Get(character)

	NETWORK.util.Print(string.format(
		"[СОХРАНЕНИЕ] персонаж #%d, записей в кэше %d, найдено: %s",
		character:GetID(), table.Count(NETWORK.persistence.cache),
		client.nwRestore and "ДА" or "НЕТ"))

	if (!client.nwRestore) then
		Notify(client, "saveNone")

		return
	end

	NETWORK.persistence.Apply(client)

	for _, delay in ipairs({0, 0.3, 1, 2}) do
		timer.Simple(delay, function()
			if (IsValid(client) and client.nwRestore) then
				NETWORK.persistence.Apply(client)
			end
		end)
	end
end)

hook.Add("PlayerSpawn", "nwPersistence", function(client)
	if (!client.nwRestore) then
		return
	end

	timer.Simple(0, function()
		if (IsValid(client)) then
			NETWORK.persistence.Apply(client)
		end
	end)
end)

hook.Add("PlayerDisconnected", "nwPersistence", function(client)
	NETWORK.persistence.Save(client)
	NETWORK.persistence.WriteBackup()
end)

hook.Add("NetworkCharacterUnloaded", "nwPersistence", function(client)
	NETWORK.persistence.Save(client)
end)

hook.Add("PlayerDeath", "nwPersistence", function(client)
	NETWORK.persistence.Save(client)
end)

hook.Add("ShutDown", "nwPersistence", function()
	for _, client in ipairs(player.GetAll()) do
		NETWORK.persistence.Save(client, false)
	end

	NETWORK.persistence.SaveAll()
end)

timer.Create("nwPersistence", 15, 0, function()
	for _, client in ipairs(player.GetAll()) do
		NETWORK.persistence.Save(client, false)
	end

	NETWORK.persistence.Flush()
	NETWORK.persistence.WriteBackup()
end)

timer.Create("nwPersistenceBackup", 300, 0, function()
	NETWORK.persistence.WriteBackup()
end)

concommand.Add("network_persistence_save", function(client)
	if (IsValid(client) and !client:IsAdmin()) then
		return
	end

	for _, target in ipairs(player.GetAll()) do
		NETWORK.persistence.Save(target, false)
	end

	local rows = Query("SELECT COUNT(*) AS total FROM " .. TABLE_NAME)

	NETWORK.util.Print("Записано: " .. tostring(NETWORK.persistence.SaveAll()) ..
		", в кэше: " .. table.Count(NETWORK.persistence.cache) ..
		", в базе: " .. tostring(rows and rows[1] and rows[1].total) ..
		", файл: " .. tostring(file.Size(dataPath, "DATA")))
end)

NETWORK.persistence.LoadAll()

NETWORK.command.Register("save", {
	description = "cmdSave",
	usage = "/save",
	OnRun = function(command, client)
		local data = NETWORK.persistence.Save(client)

		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(data and "saveDone" or "saveFail")
		net.Send(client)
	end
})

concommand.Add("network_persistence_test", function(client)
	if (IsValid(client) and !client:IsAdmin()) then
		return
	end

	local target = IsValid(client) and client or player.GetAll()[1]

	if (!IsValid(target) or !target:HasCharacter()) then
		NETWORK.util.PrintWarning("Нет игрока с персонажем для проверки.")

		return
	end

	local character = target:GetCharacter()
	local id = character:GetID()

	NETWORK.util.Print("=== проверка сохранения #" .. id .. " ===")

	local collected = NETWORK.persistence.Collect(target)

	if (!collected) then
		NETWORK.util.PrintWarning("1. Сбор данных не удался (временный персонаж?)")

		return
	end

	NETWORK.util.Print(string.format("1. Собрано: предметов %d, флаг набора %s",
		table.Count(collected.inventory.items), tostring(collected.bStarted)))

	local encoded = util.TableToJSON(collected)

	NETWORK.util.Print("2. Упаковано в JSON: " ..
		(encoded and (#encoded .. " байт") or "ОШИБКА"))

	NETWORK.persistence.cache[tostring(id)] = collected

	local bWritten = NETWORK.persistence.Write(id, collected, true)

	NETWORK.util.Print("3. Запись в базу: " .. tostring(bWritten))

	local rows = sql.Query("SELECT data FROM network_character_state WHERE id = " .. id)

	if (!istable(rows) or !rows[1]) then
		NETWORK.util.PrintWarning("4. Чтение из базы не удалось: " ..
			tostring(sql.LastError()))

		return
	end

	local decoded = util.JSONToTable(rows[1].data)

	if (!istable(decoded)) then
		NETWORK.util.PrintWarning("4. JSON из базы повреждён")

		return
	end

	NETWORK.util.Print(string.format("4. Прочитано из базы: предметов %d, позиция %s",
		table.Count((decoded.inventory or {}).items or {}),
		tostring(decoded.position and math.Round(decoded.position[1]))))

	local bFile = NETWORK.persistence.SaveAll()

	NETWORK.util.Print("5. Резервный файл: " .. tostring(bFile) .. ", размер " ..
		tostring(file.Size("network/state.txt", "DATA")))

	NETWORK.util.Print("6. Get() вернул: " ..
		(NETWORK.persistence.Get(character) and "данные есть" or "НИЧЕГО"))

	NETWORK.util.Print("=== проверка завершена ===")
end)
