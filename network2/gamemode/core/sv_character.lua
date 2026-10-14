-- Characters, server: stored in the server's sqlite (sv.db, table nw_characters), at most
-- NW.char.maxCharacters per SteamID. Every character keeps its own data: model, skin, height,
-- skills, faction and where it was last (map, position, view) - loading a character puts the
-- player back exactly there on that map.

util.AddNetworkString("nwCharList")
util.AddNetworkString("nwCharCreate")
util.AddNetworkString("nwCharResult")
util.AddNetworkString("nwCharDelete")
util.AddNetworkString("nwCharLoad")

local C = NW.char

sql.Query([[CREATE TABLE IF NOT EXISTS nw_characters (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	steamid TEXT NOT NULL,
	name TEXT NOT NULL,
	description TEXT NOT NULL,
	gender TEXT NOT NULL,
	model TEXT NOT NULL,
	skin INTEGER NOT NULL DEFAULT 0,
	height REAL NOT NULL DEFAULT 1,
	faction TEXT NOT NULL DEFAULT 'citizen',
	skills TEXT NOT NULL DEFAULT '{}',
	data TEXT NOT NULL DEFAULT '{}',
	created INTEGER NOT NULL,
	played INTEGER NOT NULL DEFAULT 0
)]])

local function Q(value)
	return sql.SQLStr(value)
end

local function Rows(steamid)
	return sql.Query("SELECT * FROM nw_characters WHERE steamid = " .. Q(steamid) .. " ORDER BY id ASC") or {}
end

local function Row(id, steamid)
	local rows = sql.Query("SELECT * FROM nw_characters WHERE id = " .. tonumber(id) .. " AND steamid = " ..
		Q(steamid) .. " LIMIT 1")

	return rows and rows[1]
end

function C.SendList(client)
	local rows = Rows(client:SteamID64())

	net.Start("nwCharList")
		net.WriteUInt(#rows, 4)

		for _, row in ipairs(rows) do
			net.WriteUInt(tonumber(row.id), 32)
			net.WriteString(row.name)
			net.WriteString(row.faction)
			net.WriteString(row.gender)
			net.WriteString(row.model)
			net.WriteUInt(tonumber(row.skin) or 0, 8)
			net.WriteFloat(tonumber(row.height) or 1)
		end
	net.Send(client)
end

local function Result(client, ok, text)
	net.Start("nwCharResult")
		net.WriteBool(ok)
		net.WriteString(text or "")
	net.Send(client)
end

local function Throttle(client, key, seconds)
	client.nwThrottle = client.nwThrottle or {}

	if ((client.nwThrottle[key] or 0) > CurTime()) then
		return false
	end

	client.nwThrottle[key] = CurTime() + seconds

	return true
end

-- ------------------------------------------------------------------ create --
net.Receive("nwCharCreate", function(_, client)
	if (!Throttle(client, "create", 2)) then
		return
	end

	local name = net.ReadString()
	local description = net.ReadString()
	local gender = net.ReadString()
	local model = net.ReadString()
	local skin = net.ReadUInt(8)
	local height = net.ReadFloat()
	local skills = {}

	for _, skill in ipairs(C.skills) do
		skills[skill.id] = net.ReadUInt(4)
	end

	if (#Rows(client:SteamID64()) >= C.maxCharacters) then
		return Result(client, false, "У вас уже " .. C.maxCharacters .. " персонажа")
	end

	local ok, value = C.CheckName(name)

	if (!ok) then
		return Result(client, false, value)
	end

	name = value
	ok, value = C.CheckDescription(description)

	if (!ok) then
		return Result(client, false, value)
	end

	description = value

	if (gender != "male" and gender != "female") then
		return Result(client, false, "Выберите пол")
	end

	if (!C.IsModelAllowed(gender, model)) then
		return Result(client, false, "Эта модель недоступна")
	end

	ok, value = C.CheckSkills(skills)

	if (!ok) then
		return Result(client, false, value)
	end

	height = math.Clamp(tonumber(height) or 1, C.height.min, C.height.max)

	-- a new character starts with its CID card (never given again) and some tokens
	local data = NW.social.NewCharacterData({name = name, gender = gender, model = model, skin = skin,
		faction = C.DefaultFaction()}, description)

	sql.Query(string.format(
		"INSERT INTO nw_characters (steamid, name, description, gender, model, skin, height, faction, skills, " ..
		"data, created) VALUES (%s, %s, %s, %s, %s, %d, %f, %s, %s, %s, %d)",
		Q(client:SteamID64()), Q(name), Q(description), Q(gender), Q(model), skin, height, Q(C.DefaultFaction()),
		Q(util.TableToJSON(skills)), Q(util.TableToJSON(data)), os.time()))

	Result(client, true, "")
	C.SendList(client)
end)

-- ------------------------------------------------------------------ delete --
net.Receive("nwCharDelete", function(_, client)
	local id = net.ReadUInt(32)

	if (!Throttle(client, "delete", 1) or client:GetCharacterID() == id) then
		return
	end

	sql.Query("DELETE FROM nw_characters WHERE id = " .. id .. " AND steamid = " .. Q(client:SteamID64()))
	C.SendList(client)
end)

-- ------------------------------------------------------- position / data --
local debug = CreateConVar("nw_char_debug", "1", FCVAR_ARCHIVE, "Писать в консоль сервера сохранение и появление персонажей")

local function Log(text)
	if (debug:GetBool()) then
		MsgC(Color(120, 210, 255), "[Network] ", color_white, text, "\n")
	end
end

function C.Save(client, reason)
	local character = client.nwCharacter
	local id = client:GetCharacterID()

	if (id == 0 or !character or character.test or !client:Alive() or client:GetNW2Bool("nwInMenu", false)) then
		return
	end

	local pos, ang = client:GetPos(), client:EyeAngles()
	local data = character.data or {}

	data.map = game.GetMap()
	data.pos = {math.Round(pos.x, 2), math.Round(pos.y, 2), math.Round(pos.z, 2)}
	data.yaw = math.Round(ang.y, 1)
	data.pitch = math.Round(ang.p, 1)
	data.crouch = client:Crouching()
	character.data = data

	local result = sql.Query("UPDATE nw_characters SET data = " .. Q(util.TableToJSON(data)) .. ", played = " ..
		os.time() .. " WHERE id = " .. id)

	if (result == false) then
		Log("ошибка сохранения персонажа " .. id .. ": " .. tostring(sql.LastError()))
	elseif (reason) then
		Log(string.format("%s: персонаж %d «%s» сохранён (%s) %s", client:SteamName(), id, character.name, reason,
			tostring(pos)))
	end
end

-- only the data column (inventory, needs) - right after a change, alive or not
function C.SaveData(client)
	local character = client.nwCharacter
	local id = client:GetCharacterID()

	if (id == 0 or !character or character.test) then
		return
	end

	local result = sql.Query("UPDATE nw_characters SET data = " .. Q(util.TableToJSON(character.data or {})) ..
		" WHERE id = " .. id)

	if (result == false) then
		Log("ошибка сохранения данных персонажа " .. id .. ": " .. tostring(sql.LastError()))
	end
end

timer.Create("nwCharSave", 15, 0, function()
	for _, client in ipairs(player.GetAll()) do
		C.Save(client)
	end
end)

hook.Add("PlayerDisconnected", "nwCharSave", function(client)
	C.Save(client, "выход")
end)

hook.Add("ShutDown", "nwCharSave", function()
	for _, client in ipairs(player.GetAll()) do
		C.Save(client, "выключение сервера")
	end
end)

-- dying keeps the last place alive, not the body
hook.Add("DoPlayerDeath", "nwCharSave", function(client)
	C.Save(client, "смерть")
end)

-- back after a while (the death screen counts it down: cl_death.lua), with Space / a click
local respawnTime = CreateConVar("nw_respawn_time", "10", FCVAR_ARCHIVE, "Через сколько секунд после смерти можно очнуться")

hook.Add("PlayerDeath", "nwRespawnTime", function(client)
	client.NextSpawnTime = CurTime() + respawnTime:GetFloat()
	client:SetNW2Float("nwRespawnAt", client.NextSpawnTime)
end)

-- a saved spot is used only on the same map and only when the player fits there (a little
-- higher, or crouched, if the exact spot is tight)
local function Fits(client, pos, bCrouch)
	local mins, maxs

	if (bCrouch) then
		mins, maxs = client:GetHullDuck()
	else
		mins, maxs = client:GetHull()
	end

	local trace = util.TraceHull({start = pos, endpos = pos, mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID,
		filter = client})

	return !trace.StartSolid
end

local function Spot(client, data)
	if (!data or data.map != game.GetMap() or !istable(data.pos)) then
		return
	end

	local base = Vector(data.pos[1], data.pos[2], data.pos[3])
	local ang = Angle(data.pitch or 0, data.yaw or 0, 0)

	for _, lift in ipairs({1, 8, 16, 32}) do
		local pos = base + Vector(0, 0, lift)

		if (Fits(client, pos, false)) then
			return pos, ang, false
		end

		if (Fits(client, pos, true)) then
			return pos, ang, true
		end
	end
end

-- ------------------------------------------------------------------- load --
net.Receive("nwCharLoad", function(_, client)
	local id = net.ReadUInt(32)

	if (!Throttle(client, "load", 2)) then
		return
	end

	local row = Row(id, client:SteamID64())

	if (!row) then
		return Result(client, false, "Персонаж не найден")
	end

	-- the previous character keeps its spot
	if (client:GetCharacterID() != 0) then
		C.Save(client, "смена персонажа")
	end

	sql.Query("UPDATE nw_characters SET played = " .. os.time() .. " WHERE id = " .. tonumber(row.id))

	C.Activate(client, {
		id = tonumber(row.id),
		name = row.name,
		gender = row.gender,
		model = row.model,
		skin = tonumber(row.skin) or 0,
		height = math.Clamp(tonumber(row.height) or 1, C.height.min, C.height.max),
		faction = row.faction,
		skills = util.JSONToTable(row.skills or "{}") or {},
		data = util.JSONToTable(row.data or "{}") or {}
	}, row.description)
end)

-- puts the player into the world as this character (also used for the bots' test characters)
function C.Activate(client, character, description)
	description = description or ""

	character.description = description
	client.nwCharacter = character

	client:SetNW2Int("nwCharID", character.id)
	client:SetNW2String("nwCharName", character.name)
	client:SetNW2String("nwCharFaction", character.faction)
	client:SetNW2String("nwCharDesc", #description > 240 and
		string.sub(description, 1, (utf8.offset(description, 120) or 241) - 1) .. "..." or description)
	client:SetNW2Bool("nwInMenu", false)

	client.nwSpawnSpot = {Spot(client, character.data)}
	client:Spawn()

	hook.Run("NWCharacterLoaded", client, character)
end

-- ------------------------------------------------------------------- bots --
-- Bots skip the menu: each gets a test character (test name and description, a random citizen
-- model, skin, height and some clothes). Test characters are never saved.
local FIRST = {
	male = {"Иван", "Пётр", "Алексей", "Михаил", "Андрей", "Виктор", "Олег", "Дмитрий"},
	female = {"Анна", "Мария", "Елена", "Ольга", "Ирина", "Наталья", "Вера", "Светлана"}
}
local LAST = {"Тестов", "Пробный", "Образцов", "Проверкин", "Отладов", "Макетов"}
local DESCRIPTIONS = {
	"Тестовый персонаж. Сутулится, смотрит в пол и постоянно поправляет воротник.",
	"Тестовый персонаж. Худой, небритый, на рукаве — выцветший номер.",
	"Тестовый персонаж. Держится уверенно, говорит негромко, руки в карманах.",
	"Тестовый персонаж. Усталое лицо, тёмные круги под глазами, пахнет машинным маслом."
}

function C.LoadTest(client)
	local gender = math.random(2) == 1 and "male" or "female"
	local models = C.GetModels(gender)

	if (#models == 0) then
		return
	end

	local surname = LAST[math.random(#LAST)]

	if (gender == "female") then
		surname = string.EndsWith(surname, "ый") and (string.sub(surname, 1, -5) .. "ая") or (surname .. "а")
	end

	-- random clothes from the wardrobe (sh_items.lua), each slot with some chance
	local bySlot = {}

	for _, id in ipairs(NW.items.wardrobe or {}) do
		local item = NW.items.Get(id)

		bySlot[item.slot] = bySlot[item.slot] or {}
		table.insert(bySlot[item.slot], id)
	end

	local equip = {}

	for slot, ids in pairs(bySlot) do
		if (math.random() < (slot == "torso" and 0.85 or 0.5)) then
			equip[#equip + 1] = {slot, ids[math.random(#ids)], {}}
		end
	end

	local character = {
		id = 1000000 + client:UserID(),
		test = true,
		name = FIRST[gender][math.random(#FIRST[gender])] .. " " .. surname,
		gender = gender,
		model = models[math.random(#models)].path,
		skin = math.random(0, 14),
		height = math.Rand(C.height.min, C.height.max),
		faction = C.DefaultFaction(),
		skills = {}
	}
	local description = DESCRIPTIONS[math.random(#DESCRIPTIONS)]

	-- like a new character: the CID card and tokens, plus the test clothes
	character.data = NW.social.NewCharacterData(character, description)
	character.data.inv.equip = equip

	C.Activate(client, character, description)
end

hook.Add("PlayerInitialSpawn", "nwCharBots", function(client)
	if (client:IsBot()) then
		timer.Simple(1, function()
			if (IsValid(client) and client:GetCharacterID() == 0) then
				C.LoadTest(client)
			end
		end)
	end
end)

-- after the spawn: height and the saved spot
hook.Add("PlayerSpawn", "nwCharacter", function(client)
	local character = client.nwCharacter

	if (!character or client:GetNW2Bool("nwInMenu", false)) then
		return
	end

	timer.Simple(0, function()
		if (!IsValid(client) or client.nwCharacter != character) then
			return
		end

		local scale = character.height

		client:SetModelScale(scale, 0)
		client:SetViewOffset(Vector(0, 0, 64 * scale))
		client:SetViewOffsetDucked(Vector(0, 0, 28 * scale))

		local spot = client.nwSpawnSpot

		client.nwSpawnSpot = nil

		if (spot and spot[1]) then
			-- twice: a spawn system of an addon may move the player right after the spawn
			local function Put()
				if (IsValid(client) and client.nwCharacter == character and client:Alive()) then
					if (spot[3]) then
						client:ConCommand("+duck")

						timer.Simple(0.6, function()
							if (IsValid(client)) then
								client:ConCommand("-duck")
							end
						end)
					end

					client:SetPos(spot[1])
					client:SetEyeAngles(spot[2])
					client:SetVelocity(-client:GetVelocity())
				end
			end

			Put()
			timer.Simple(0.2, Put)
			Log(string.format("%s: персонаж %d «%s» появился на своём месте %s", client:SteamName(), character.id,
				character.name, tostring(spot[1])))
		else
			Log(string.format("%s: персонаж %d «%s» появился на точке спавна (%s)", client:SteamName(), character.id,
				character.name, character.data and character.data.map and (character.data.map != game.GetMap() and
				"сохранён на другой карте" or "сохранённое место занято") or "ещё не сохранялся"))
		end
	end)
end)

-- back to the menu: the character is saved and unloaded
hook.Add("NWEnterMenu", "nwCharacter", function(client)
	C.Save(client, "возврат в меню")

	client.nwCharacter = nil
	client:SetNW2Int("nwCharID", 0)
	client:SetNW2String("nwCharName", "")
	client:SetNW2String("nwCharFaction", "")
	client:SetNW2String("nwCharDesc", "")
	client:SetModelScale(1, 0)
end)

-- ------------------------------------------------------------- factions --
-- the character joins a faction: saved at once, a faction with its own model dresses them in it,
-- what the faction hands out on joining (FACTION.items: the stunstick of Civil Protection) is given
-- once. Used by /setfaction and the profession NPCs (sv_npc.lua).
function C.SetFaction(target, faction)
	local character = target.nwCharacter
	local data = C.factions[faction]

	if (!character or !data) then
		return false
	end

	character.faction = faction
	target:SetNW2String("nwCharFaction", faction)

	if (!character.test) then
		sql.Query("UPDATE nw_characters SET faction = " .. Q(faction) .. " WHERE id = " .. target:GetCharacterID())
	end

	if (target:Alive()) then
		NW.models.Apply(target)
	end

	for _, id in ipairs(data.items or {}) do
		local inventory = NW.inventory.Get(target)
		local has = false

		for _, cell in pairs(inventory.grid) do
			has = has or cell.id == id
		end

		for _, cell in pairs(inventory.equip) do
			has = has or cell.id == id
		end

		if (!has) then
			local item = NW.items.Get(id) or {name = id}

			NW.Notify(target, NW.inventory.Add(target, id) and ("Выдано: " .. item.name) or ("Нет места для: " .. item.name))
		end
	end

	NW.inventory.Changed(target)
	hook.Run("NWFactionChanged", target, faction)

	return true
end

-- /setfaction <игрок> <фракция> (admins); sv_chat.lua loads later: the command goes straight into
-- its table
NW.chatCommands = NW.chatCommands or {}
NW.chatCommands.setfaction = {admin = true, run = function(client, rest)
	local who, which = string.match(rest or "", "^(%S+)%s+(.+)$")
	local target = NW.FindPlayer(who)
	local faction = C.FindFaction(which)

	if (!target or !target.nwCharacter or target:GetCharacterID() == 0) then
		return NW.Notify(client, "Игрок не найден. /setfaction <имя> <фракция>")
	end

	if (!faction) then
		local names = {}

		for _, data in pairs(C.factions) do
			names[#names + 1] = data.name
		end

		table.sort(names)

		return NW.Notify(client, "Фракция не найдена. Есть: " .. table.concat(names, ", "))
	end

	C.SetFaction(target, faction)

	local name = C.factions[faction].name

	NW.Notify(client, target:Nick() .. " → " .. name)

	if (target != client) then
		NW.Notify(target, "Ваша фракция: " .. name)
	end

	Log(string.format("%s: персонаж %d «%s» переведён во фракцию %s", client:SteamName(), target:GetCharacterID(),
		target.nwCharacter.name, faction))
end}
