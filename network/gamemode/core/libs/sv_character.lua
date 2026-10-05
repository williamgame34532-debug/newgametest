NETWORK.character = NETWORK.character or {}
NETWORK.character.cache = NETWORK.character.cache or {}

util.AddNetworkString("nwCharacterRequest")
util.AddNetworkString("nwCharacterDesc")

function NETWORK.character.BroadcastDescription(client, target)
	if (!IsValid(client)) then
		return
	end

	local character = client:GetCharacter()
	local text = character and character:GetDescription() or ""

	net.Start("nwCharacterDesc")
		net.WriteUInt(client:EntIndex(), 16)
		net.WriteString(text)

	if (IsValid(target)) then
		net.Send(target)
	else
		net.Broadcast()
	end
end

util.AddNetworkString("nwCharacterDescReq")

net.Receive("nwCharacterDescReq", function(_, client)
	if ((client.nwNextDescReq or 0) > CurTime()) then
		return
	end

	client.nwNextDescReq = CurTime() + 0.25

	local target = Entity(net.ReadUInt(16))

	if (IsValid(target) and target:IsPlayer() and target:HasCharacter()) then
		NETWORK.character.BroadcastDescription(target, client)
	end
end)

hook.Add("PlayerInitialSpawn", "nwCharacterDesc", function(client)
	timer.Simple(3, function()
		if (!IsValid(client)) then
			return
		end

		for _, other in ipairs(player.GetAll()) do
			if (other != client and other:HasCharacter()) then
				NETWORK.character.BroadcastDescription(other, client)
			end
		end
	end)
end)
util.AddNetworkString("nwCharacterRefresh")
util.AddNetworkString("nwCharacterList")
util.AddNetworkString("nwCharacterCreate")
util.AddNetworkString("nwCharacterDelete")
util.AddNetworkString("nwCharacterSelect")
util.AddNetworkString("nwCharacterResult")

local ACTION_COOLDOWN = 0.5
local TABLE_NAME = "network_characters"

local function Query(query)
	local result = sql.Query(query)

	if (result == false) then
		NETWORK.util.PrintWarning("SQL: " .. tostring(sql.LastError()))
		NETWORK.util.PrintWarning("SQL: " .. query)

		return nil, sql.LastError()
	end

	return result or {}
end

function NETWORK.character.InitialiseStorage()
	Query([[
		CREATE TABLE IF NOT EXISTS ]] .. TABLE_NAME .. [[ (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			steamid TEXT NOT NULL,
			schema TEXT NOT NULL,
			name TEXT NOT NULL,
			surname TEXT NOT NULL,
			description TEXT NOT NULL,
			model TEXT NOT NULL,
			faction TEXT NOT NULL,
			kit TEXT NOT NULL,
			height INTEGER NOT NULL,
			skills TEXT NOT NULL,
			created INTEGER NOT NULL,
			lastused INTEGER NOT NULL
		)
	]])

	Query("CREATE INDEX IF NOT EXISTS nwCharacterOwner ON " .. TABLE_NAME .. " (steamid, schema)")

	local existing = {}

	for _, row in ipairs(Query("PRAGMA table_info(" .. TABLE_NAME .. ")") or {}) do
		existing[row.name] = true
	end

	if (!existing.bodygroups) then
		Query("ALTER TABLE " .. TABLE_NAME .. " ADD COLUMN bodygroups TEXT")
	end

	if (!existing.skin) then
		Query("ALTER TABLE " .. TABLE_NAME .. " ADD COLUMN skin INTEGER")
	end

	if (!existing.modelforced) then
		Query("ALTER TABLE " .. TABLE_NAME .. " ADD COLUMN modelforced INTEGER")
	end
end

NETWORK.character.InitialiseStorage()

local function RowToCharacter(row)
	return NETWORK.character.New({
		id = tonumber(row.id),
		steamID = row.steamid,
		name = row.name,
		surname = row.surname,
		description = row.description,
		model = row.model,
		faction = row.faction,
		kit = row.kit,
		height = tonumber(row.height),
		skills = util.JSONToTable(row.skills or "{}") or {},
		bodygroups = util.JSONToTable(row.bodygroups or "{}") or {},
		skin = tonumber(row.skin) or 0,
		created = tonumber(row.created),
		lastUsed = tonumber(row.lastused)
	})
end

function NETWORK.character.GetCache(client)
	if (!IsValid(client)) then
		return {}
	end

	return NETWORK.character.cache[client:SteamID64() or ""] or {}
end

function NETWORK.character.GetByID(client, id)
	id = tonumber(id) or 0

	for _, character in ipairs(NETWORK.character.GetCache(client)) do
		if (character:GetID() == id) then
			return character
		end
	end
end

function NETWORK.character.Load(client)
	if (!IsValid(client)) then
		return {}
	end

	local rows = Query(string.format("SELECT * FROM %s WHERE steamid = %s AND schema = %s ORDER BY id ASC",
		TABLE_NAME, sql.SQLStr(client:SteamID64()), sql.SQLStr(NETWORK.schema)))

	local characters = {}

	for _, row in ipairs(rows or {}) do
		characters[#characters + 1] = RowToCharacter(row)
	end

	NETWORK.character.cache[client:SteamID64()] = characters

	hook.Run("NetworkCharacterListLoaded", client, characters)

	return characters
end

function NETWORK.character.Send(client)
	if (!IsValid(client)) then
		return
	end

	local payload = {}

	for _, character in ipairs(NETWORK.character.GetCache(client)) do
		local data = character:GetNetworkData()
		local active = character:GetPlayer()

		if (IsValid(active)) then
			data.vitals = {
				health = math.Round(active:Health() / math.max(active:GetMaxHealth(), 1) * 100),
				hunger = math.Round(active:GetHunger()),
				thirst = math.Round(active:GetThirst())
			}
		else
			local saved = NETWORK.persistence and NETWORK.persistence.Get(character)

			if (saved) then
				data.vitals = {
					health = math.Round(saved.health or 100),
					hunger = math.Round(saved.hunger or 100),
					thirst = math.Round(saved.thirst or 100)
				}
			end
		end

		payload[#payload + 1] = data
	end

	net.Start("nwCharacterList")
		net.WriteUInt(NETWORK.character.maxSlots, 8)
		NETWORK.util.WriteTable(payload)
	net.Send(client)
end

function NETWORK.character.Reply(client, action, bSuccess, key, ...)
	if (!IsValid(client)) then
		return
	end

	net.Start("nwCharacterResult")
		net.WriteString(action)
		net.WriteBool(bSuccess)
		net.WriteString(key or "")
		NETWORK.util.WriteTable({...})
	net.Send(client)
end

function NETWORK.character.Create(client, payload)
	if (!IsValid(client)) then
		return nil, "errUnknown"
	end

	payload = NETWORK.creation.Sanitise(payload)

	if (#NETWORK.character.GetCache(client) >= NETWORK.character.maxSlots) then
		return nil, "errSlotsFull"
	end

	local bValid, key, a, b = NETWORK.creation.Validate(payload, client)

	if (!bValid) then
		return nil, key, a, b
	end

	local time = os.time()
	local result, err = Query(string.format(
		"INSERT INTO %s (steamid, schema, name, surname, description, model, faction, kit, height, skills, bodygroups, skin, created, lastused) " ..
		"VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %d, %s, %s, %d, %d, %d)",
		TABLE_NAME,
		sql.SQLStr(client:SteamID64()), sql.SQLStr(NETWORK.schema),
		sql.SQLStr(payload.name), sql.SQLStr(payload.surname), sql.SQLStr(payload.description),
		sql.SQLStr(payload.model), sql.SQLStr(payload.faction), sql.SQLStr(payload.kit),
		payload.height, sql.SQLStr(util.TableToJSON(payload.skills)),
		sql.SQLStr(util.TableToJSON(payload.bodygroups or {})), payload.skin or 0, time, time))

	if (err) then
		return nil, "errStorage"
	end

	local inserted = Query("SELECT last_insert_rowid() AS id")
	local id = tonumber(inserted and inserted[1] and inserted[1].id)

	if (!id) then
		return nil, "errStorage"
	end

	local character = NETWORK.character.New({
		id = id,
		steamID = client:SteamID64(),
		name = payload.name,
		surname = payload.surname,
		description = payload.description,
		model = payload.model,
		faction = payload.faction,
		kit = payload.kit,
		height = payload.height,
		skills = payload.skills,
		bodygroups = payload.bodygroups or {},
		skin = payload.skin or 0,
		created = time,
		lastUsed = time
	})

	local cache = NETWORK.character.cache[client:SteamID64()] or {}

	cache[#cache + 1] = character

	NETWORK.character.cache[client:SteamID64()] = cache

	hook.Run("NetworkCharacterCreated", client, character)

	NETWORK.util.Print(string.format("%s создал персонажа %s (#%d)",
		client:SteamID(), character:GetName(), character:GetID()))

	return character
end

function NETWORK.character.Delete(client, id)
	local character = NETWORK.character.GetByID(client, id)

	if (!character) then
		return false, "errNotFound"
	end

	if (hook.Run("NetworkCanDeleteCharacter", client, character) == false) then
		return false, "errNoAccess"
	end

	local _, err = Query(string.format("DELETE FROM %s WHERE id = %d AND steamid = %s",
		TABLE_NAME, character:GetID(), sql.SQLStr(client:SteamID64())))

	if (err) then
		return false, "errStorage"
	end

	local cache = NETWORK.character.cache[client:SteamID64()] or {}

	for i = #cache, 1, -1 do
		if (cache[i]:GetID() == character:GetID()) then
			table.remove(cache, i)
		end
	end

	if (client:GetCharacterID() == character:GetID()) then
		NETWORK.character.Clear(client)
	end

	hook.Run("NetworkCharacterDeleted", client, character)

	return true
end

function NETWORK.character.Set(client, character)

	local previous = client:GetCharacter()

	if (previous) then
		hook.Run("NetworkCharacterUnloaded", client, previous)
	end

	client.nwRestore = nil
	client.nwScaleOverride = nil
	client.nwAppearanceSignature = nil
	client:SetNWString("nwClass", "")
	client:SetNWString("nwCallsign", "")
	client.nwInventory = NETWORK.inventory.NewState()
	client.nwStarted = nil
	client.nwBodygroups = nil
	client.nwSkin = nil
	client.nwWounds = nil
	client.nwTraderLevels = nil
	client.nwTraderUnlocked = nil
	client.nwBank = nil
	client.nwLoyalty = nil
	client.nwRecognised = nil

	if (NETWORK.classes.MigrateCWU) then NETWORK.classes.MigrateCWU(character) end
	client.nwCharacter = character

	client:SetNWInt("nwCharacterID", character:GetID())
	client:SetNWString("nwCharacterName", character:GetName())
	client:SetNWString("nwCharacterDescription", NETWORK.util.Sub(character:GetDescription(), 1, 90))
	NETWORK.character.BroadcastDescription(client)
	client:SetNWString("nwCharacterFaction", character:GetFaction())
	client:SetNWString("nwCharacterModel", character:GetModel())

	client:StripWeapons()
	client:RemoveAllAmmo()

	character.lastUsed = os.time()

	if (!character.bTemporary) then
		Query(string.format("UPDATE %s SET lastused = %d WHERE id = %d",
			TABLE_NAME, character.lastUsed, character:GetID()))
	end

	client:Spawn()

	hook.Run("NetworkCharacterLoaded", client, character)

	NETWORK.util.Print(string.format("%s вошёл как %s (#%d)",
		client:SteamID(), character:GetName(), character:GetID()))
end

function NETWORK.character.Update(character, fields)
	if (!character or character.bTemporary) then
		return
	end

	local parts = {}

	for key, value in pairs(fields) do
		character[key] = value

		if (isnumber(value)) then
			parts[#parts + 1] = string.format("%s = %d", key, value)
		else
			parts[#parts + 1] = string.format("%s = %s", key, sql.SQLStr(tostring(value)))
		end
	end

	if (#parts == 0) then
		return
	end

	Query(string.format("UPDATE %s SET %s WHERE id = %d", TABLE_NAME,
		table.concat(parts, ", "), character:GetID()))

	local bVisible = false

	for key in pairs(fields) do
		if (key == "name" or key == "surname" or key == "description" or
			key == "faction" or key == "model") then
			bVisible = true

			break
		end
	end

	if (!bVisible) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		if (client:GetCharacter() == character) then
			NETWORK.character.Refresh(client)

			hook.Run("NetworkCharacterUpdated", client, character, fields)

			break
		end
	end
end

function NETWORK.character.Refresh(client)
	local character = client:GetCharacter()

	if (!character) then
		return
	end

	client:SetNWString("nwCharacterName", character:GetName())
	client:SetNWString("nwCharacterDescription", NETWORK.util.Sub(character:GetDescription(), 1, 90))
	NETWORK.character.BroadcastDescription(client)
	client:SetNWString("nwCharacterFaction", character:GetFaction())

	local worn = client:Alive() and client:GetModel() or ""

	client:SetNWString("nwCharacterModel", (worn != "" and util.IsValidModel(worn)) and worn or
		character:GetModel())

	NETWORK.character.Send(client)

	net.Start("nwCharacterRefresh")
	net.Send(client)
end

function NETWORK.character.Clear(client)
	local previous = client:GetCharacter()
	if (previous) then hook.Run("NetworkCharacterUnloaded", client, previous) end
	client.nwRestore = nil
	client.nwCharacter = nil

	client:SetNWInt("nwCharacterID", 0)
	client:SetNWString("nwCharacterName", "")
	client:SetNWString("nwCharacterDescription", "")
	NETWORK.character.BroadcastDescription(client)
	client:SetNWString("nwCharacterFaction", "")

	client:Spawn()
end

function NETWORK.character.Select(client, id)
	local character = NETWORK.character.GetByID(client, id)

	if (!character) then
		return false, "errNotFound"
	end

	local faction = NETWORK.factions.Get(character:GetFaction())

	if (faction and faction.bWhitelist and !client:IsAdmin() and
		!client:IsWhitelisted(faction.id) and NETWORK.admin and NETWORK.admin.SetWhitelist) then
		NETWORK.admin.SetWhitelist(client, faction.id, true)

		MsgN(string.format("[Network] %s (%s): допуск к фракции %s восстановлен по персонажу «%s».",
			client:Nick(), client:SteamID(), faction.id, character:GetName()))
	end

	if (!NETWORK.factions.CanUse(client, character:GetFaction())) then
		return false, "errFaction"
	end

	if (hook.Run("NetworkCanSelectCharacter", client, character) == false) then
		return false, "errNoAccess"
	end

	NETWORK.character.Set(client, character)

	return true, character
end

local function CheckCooldown(client)
	if ((client.nwNextCharacterAction or 0) > CurTime()) then
		return false
	end

	client.nwNextCharacterAction = CurTime() + ACTION_COOLDOWN

	return true
end

net.Receive("nwCharacterRequest", function(_, client)
	if (!CheckCooldown(client)) then
		return
	end

	NETWORK.character.Load(client)
	NETWORK.character.Send(client)
end)

net.Receive("nwCharacterCreate", function(_, client)
	local payload = NETWORK.util.ReadTable()

	if (!CheckCooldown(client)) then
		NETWORK.character.Reply(client, "create", false, "errCooldown")

		return
	end

	local character, key, a, b = NETWORK.character.Create(client, payload)

	if (!character) then
		NETWORK.character.Reply(client, "create", false, key or "errUnknown", a, b)

		return
	end

	NETWORK.character.Send(client)
	NETWORK.character.Reply(client, "create", true, "okCreated")
end)

net.Receive("nwCharacterDelete", function(_, client)
	local id = net.ReadUInt(32)

	if (!CheckCooldown(client)) then
		NETWORK.character.Reply(client, "delete", false, "errCooldown")

		return
	end

	local bSuccess, key = NETWORK.character.Delete(client, id)

	NETWORK.character.Send(client)
	NETWORK.character.Reply(client, "delete", bSuccess, bSuccess and "okDeleted" or key)
end)

net.Receive("nwCharacterSelect", function(_, client)
	local id = net.ReadUInt(32)

	if (!CheckCooldown(client)) then
		NETWORK.character.Reply(client, "select", false, "errCooldown")

		return
	end

	local bSuccess, result = NETWORK.character.Select(client, id)

	if (!bSuccess) then
		NETWORK.character.Reply(client, "select", false, result)

		return
	end

	NETWORK.character.Reply(client, "select", true, "okSelected", result:GetName())
end)

hook.Add("PlayerDisconnected", "nwCharacterCache", function(client)
	local steamID = client:SteamID64()

	if (steamID) then
		NETWORK.character.cache[steamID] = nil
	end
end)

concommand.Add("network_characters", function(client)
	if (IsValid(client) and !client:IsSuperAdmin()) then
		return
	end

	local rows = Query(string.format("SELECT id, steamid, name, surname, faction FROM %s WHERE schema = %s",
		TABLE_NAME, sql.SQLStr(NETWORK.schema))) or {}

	NETWORK.util.Print("Персонажей в базе: " .. #rows)

	for _, row in ipairs(rows) do
		NETWORK.util.Print(string.format("#%s  %s %s  [%s]  %s",
			row.id, row.name, row.surname, row.faction, row.steamid))
	end
end)
