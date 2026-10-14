-- The civic terminal, server side (sh_terminal.lua). Terminals are placed by admins from the spawn
-- menu (Entities → Network → Гражданский терминал) and moved with the physics gun; every one on the
-- map is kept in data/network2/terminals/<map>.json. Announcements are kept for all maps in
-- data/network2/announcements.json (the last 40). The bank account is part of the character
-- (data.bank, data.bankLog).
--   client → server   nwTerminal: action, terminal, JSON
--     profile                           the citizen's file
--     announcements                     the list
--     call {text}                       a call to Civil Protection
--     housing / housinglist             an apartment / the list of them
--     bank {deposit, amount}            on hand ↔ the account
--     business / rent {door}            the free businesses / renting one
--     announce_list / announce_save {id?, title, body, priority, photo} / announce_delete {id}
--   server → client   nwTerminal: action, terminal, JSON (the same names; "rented" - a business is
--                     yours, "result" - a short message, "alert" - a call for the Alliance)

util.AddNetworkString("nwTerminal")

local T = NW.terminal
local D = NW.doors
local SO = NW.social
local DIR = "network2/terminals"
local ANNOUNCEMENTS = "network2/announcements.json"

local function Send(client, action, terminal, data)
	net.Start("nwTerminal")
		net.WriteString(action)
		net.WriteEntity(terminal or NULL)
		net.WriteString(util.TableToJSON(data or {}))
	net.Send(client)
end

local function Result(client, terminal, message)
	Send(client, "result", terminal, {message = message})
end

-- --------------------------------------------------------------- placing --
local loading = false

local function Path()
	return DIR .. "/" .. game.GetMap() .. ".json"
end

function T.Save()
	if (loading) then
		return
	end

	local list = {}

	for _, terminal in ipairs(ents.FindByClass(T.class)) do
		local pos, ang = terminal:GetPos(), terminal:GetAngles()

		list[#list + 1] = {pos = {pos.x, pos.y, pos.z}, ang = {ang.p, ang.y, ang.r}}
	end

	file.CreateDir(DIR)
	file.Write(Path(), util.TableToJSON(list, true))
end

function T.Changed()
	timer.Create("nwTerminalsSave", 1, 1, T.Save)
end

function T.Load()
	loading = true

	for _, saved in ipairs(util.JSONToTable(file.Read(Path(), "DATA") or "") or {}) do
		local terminal = ents.Create(T.class)

		if (IsValid(terminal) and istable(saved.pos)) then
			terminal:SetPos(Vector(saved.pos[1], saved.pos[2], saved.pos[3]))
			terminal:SetAngles(Angle(saved.ang[1], saved.ang[2], saved.ang[3]))
			terminal:Spawn()
			terminal:Activate()
		end
	end

	loading = false
end

hook.Add("InitPostEntity", "nwTerminals", function()
	timer.Simple(1, T.Load)
end)

hook.Add("PostCleanupMap", "nwTerminals", function()
	timer.Simple(0.5, T.Load)
end)

-- admins move them with the physics gun; nobody else
hook.Add("PhysgunPickup", "nwTerminals", function(client, entity)
	if (entity:GetClass() == T.class) then
		return client:IsAdmin()
	end
end)

hook.Add("PhysgunDrop", "nwTerminals", function(client, entity)
	if (entity:GetClass() == T.class) then
		local physics = entity:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end

		T.Changed()
	end
end)

-- ------------------------------------------------------------- the account --
local function Data(client)
	local character = client.nwCharacter

	if (!character) then
		return
	end

	character.data = character.data or {}
	character.data.bank = math.max(0, math.floor(tonumber(character.data.bank) or 0))
	character.data.bankLog = istable(character.data.bankLog) and character.data.bankLog or {}

	return character.data
end

local function Log(client, text, positive)
	local data = Data(client)

	table.insert(data.bankLog, 1, {time = os.date("%H:%M"), text = text, positive = positive == true})

	while (#data.bankLog > 8) do
		table.remove(data.bankLog)
	end
end

local function SaveData(client)
	if (NW.char.SaveData) then
		NW.char.SaveData(client)
	end
end

-- the apartment of the city this character lives in (its name) or nil
local function Home(client)
	for _, door in ipairs(ents.GetAll()) do
		if (D.IsDoor(door) and door:GetNW2String("nwDoorKind", "") == "apartment" and D.Mode(door) == "terminal" and
			D.IsOwner(client, door)) then
			return door
		end
	end
end

local function Profile(client)
	local data = Data(client)
	local faction = NW.char.factions[client:GetFaction() or ""]
	local color = faction and faction.color or Color(96, 186, 206)
	local home = Home(client)

	return {
		name = client:Nick(),
		cid = data.cid or "00000",
		faction = faction and faction.name or "НЕ ОПРЕДЕЛЕНО",
		factionColor = {color.r, color.g, color.b},
		bank = data.bank,
		tokens = SO.GetTokens(client),
		model = client:GetModel(),
		logs = data.bankLog,
		home = home and home:GetNW2String("nwDoorName", "") or ""
	}
end

-- ---------------------------------------------------------- announcements --
T.announcements = util.JSONToTable(file.Read(ANNOUNCEMENTS, "DATA") or "") or {}

local function SaveAnnouncements()
	file.CreateDir("network2")
	file.Write(ANNOUNCEMENTS, util.TableToJSON(T.announcements, true))
end

local function Clip(text, length)
	text = string.Trim(string.gsub(tostring(text or ""), "[%c]", " "))

	if ((utf8.len(text) or 0) > length) then
		text = string.sub(text, 1, (utf8.offset(text, length + 1) or (#text + 1)) - 1)
	end

	return text
end

NW.AddChatCommand("announce", {run = function(client)
	if (!T.CanAnnounce(client)) then
		return NW.Notify(client, "Неизвестная команда: /announce")
	end

	Send(client, "announce_list", NULL, {list = T.announcements})
end})

-- ------------------------------------------------------------------ housing --
-- the apartments of the city: one entry per door group
local function Apartments()
	local out, seen = {}, {}

	for _, door in ipairs(ents.GetAll()) do
		if (!seen[door] and D.IsDoor(door) and door:GetNW2String("nwDoorKind", "") == "apartment" and
			D.Mode(door) == "terminal") then
			for _, member in ipairs(D.Group(door)) do
				seen[member] = true
			end

			out[#out + 1] = {door = door, name = door:GetNW2String("nwDoorName", "Квартира"),
				current = #D.Tenants(door), maximum = D.Capacity(door)}
		end
	end

	table.SortByMember(out, "name", true)

	return out
end

local function Businesses()
	local out, seen = {}, {}

	for _, door in ipairs(ents.GetAll()) do
		if (!seen[door] and D.IsDoor(door) and door:GetNW2String("nwDoorKind", "") == "business") then
			for _, member in ipairs(D.Group(door)) do
				seen[member] = true
			end

			if (D.Owner(door) == 0) then
				out[#out + 1] = {door = door:EntIndex(), name = door:GetNW2String("nwDoorName", "Бизнес"),
					price = door:GetNW2Int("nwDoorPrice", 0)}
			end
		end
	end

	table.SortByMember(out, "name", true)

	return out
end

-- -------------------------------------------------------------- the actions --
local ACTIONS = {}

function ACTIONS.profile(client, terminal)
	Send(client, "profile", terminal, Profile(client))
end

function ACTIONS.announcements(client, terminal)
	Send(client, "announcements", terminal, {list = T.announcements})
end

function ACTIONS.call(client, terminal, input)
	local text = Clip(input.text, 300)

	if (text == "" or terminal:GetNW2Float("nwTermAlarm", 0) > CurTime()) then
		return Send(client, "call", terminal, {success = false})
	end

	local until_ = CurTime() + T.callCooldown

	terminal:SetNW2Float("nwTermAlarm", until_)
	terminal:EmitSound("network2/terminal/alarm.wav", 70)

	local alert = {pos = {terminal:GetPos().x, terminal:GetPos().y, terminal:GetPos().z},
		number = terminal:GetNW2Int("nwTermNumber", terminal:EntIndex()), name = client:Nick(),
		cid = (Data(client) or {}).cid or "?", reason = text, until_ = T.callCooldown}

	for _, member in ipairs(player.GetAll()) do
		if (member:GetCharacterID() != 0 and NW.zones.IsAlliance(member)) then
			Send(member, "alert", terminal, alert)
		end
	end

	Send(client, "call", terminal, {success = true, text = text})
	MsgN(string.format("[Terminal] %s (%s) вызывает ГО: %s", client:Nick(), client:SteamName(), text))
end

function ACTIONS.housing(client, terminal)
	local home = Home(client)

	if (home) then
		return Send(client, "housing", terminal, {success = false,
			message = "ВЫ УЖЕ ПРОЖИВАЕТЕ: " .. T.Upper(home:GetNW2String("nwDoorName", "КВАРТИРА"))})
	end

	local list = Apartments()
	local names, free = {}, {}

	for _, entry in ipairs(list) do
		names[#names + 1] = entry.name

		if (entry.current < entry.maximum) then
			free[#free + 1] = entry
		end
	end

	if (#free == 0) then
		return Send(client, "housing", terminal, {success = false, message = "СВОБОДНЫХ АПАРТАМЕНТОВ НЕТ"})
	end

	-- the emptier the more likely
	local total = 0

	for _, entry in ipairs(free) do
		entry.weight = entry.maximum - entry.current
		total = total + entry.weight
	end

	local roll, chosen = math.random() * total

	for _, entry in ipairs(free) do
		roll = roll - entry.weight

		if (roll <= 0) then
			chosen = entry

			break
		end
	end

	chosen = chosen or free[#free]
	D.AddTenant(chosen.door, client)
	Send(client, "housing", terminal, {success = true, chosen = chosen.name, names = names})
	MsgN(string.format("[Terminal] %s заселён: %s", client:Nick(), chosen.name))
end

function ACTIONS.housinglist(client, terminal)
	local out = {}

	for _, entry in ipairs(Apartments()) do
		out[#out + 1] = {name = entry.name, current = entry.current, maximum = entry.maximum}
	end

	Send(client, "housinglist", terminal, {list = out})
end

function ACTIONS.bank(client, terminal, input)
	local data = Data(client)
	local amount = math.floor(tonumber(input.amount) or 0)
	local tokens = SO.GetTokens(client)

	if (amount < 1) then
		return
	end

	if (input.deposit) then
		if (tokens < amount) then
			return Result(client, terminal, "НЕДОСТАТОЧНО ТОКЕНОВ НА РУКАХ")
		end

		SO.SetTokens(client, tokens - amount)
		data.bank = data.bank + amount
		Log(client, "ВЗНОС +" .. amount .. " ТК", true)
	else
		if (data.bank < amount) then
			return Result(client, terminal, "НЕДОСТАТОЧНО СРЕДСТВ НА СЧЁТЕ")
		end

		data.bank = data.bank - amount
		SO.SetTokens(client, tokens + amount)
		Log(client, "ВЫДАЧА −" .. amount .. " ТК", false)
	end

	SaveData(client)
	Send(client, "profile", terminal, Profile(client))
	Result(client, terminal, "ОПЕРАЦИЯ ВЫПОЛНЕНА")
	terminal:EmitSound("network2/terminal/select2.wav", 60)
end

function ACTIONS.business(client, terminal)
	Send(client, "business", terminal, {list = Businesses()})
end

function ACTIONS.rent(client, terminal, input)
	local door = Entity(math.floor(tonumber(input.door) or 0))

	if (!D.IsDoor(door) or door:GetNW2String("nwDoorKind", "") != "business" or D.Owner(door) != 0) then
		Result(client, terminal, "ПОМЕЩЕНИЕ УЖЕ ЗАНЯТО")

		return ACTIONS.business(client, terminal)
	end

	if (D.Owned(client) >= GetConVar("nw_door_limit"):GetInt()) then
		return Result(client, terminal, "ПРЕВЫШЕН ЛИМИТ ПОМЕЩЕНИЙ")
	end

	local data = Data(client)
	local price = door:GetNW2Int("nwDoorPrice", 0)

	if (data.bank < price) then
		return Result(client, terminal, "НА СЧЁТЕ НЕДОСТАТОЧНО СРЕДСТВ: " .. price .. " ТК")
	end

	data.bank = data.bank - price
	Log(client, "АРЕНДА −" .. price .. " ТК", false)
	SaveData(client)
	D.SetOwner(door, client)
	Send(client, "profile", terminal, Profile(client))
	Send(client, "rented", terminal, {name = door:GetNW2String("nwDoorName", "Бизнес")})
	ACTIONS.business(client, terminal)
end

-- announcements: the editor (/announce) - no terminal needed
local EDITOR = {announce_list = true, announce_save = true, announce_delete = true}

function ACTIONS.announce_list(client)
	Send(client, "announce_list", NULL, {list = T.announcements})
end

function ACTIONS.announce_save(client, _, input)
	local title, body = Clip(input.title, 60), Clip(input.body, 900)

	if (title == "" or body == "") then
		return NW.Notify(client, "Нужны заголовок и текст")
	end

	local entry

	for _, old in ipairs(T.announcements) do
		if (old.id == input.id) then
			entry = old
		end
	end

	if (!entry) then
		entry = {id = os.time() * 100 + math.random(0, 99)}
		table.insert(T.announcements, 1, entry)
	end

	entry.title = title
	entry.body = body
	entry.priority = T.priorities[input.priority or ""] and input.priority or "normal"
	entry.photo = string.match(tostring(input.photo or ""), "^https?://%S+$") and Clip(input.photo, 300) or ""
	entry.author = client:Nick()
	entry.gameTime = os.date("%d.%m %H:%M")

	while (#T.announcements > 40) do
		table.remove(T.announcements)
	end

	SaveAnnouncements()
	NW.Notify(client, "Объявление опубликовано: " .. title)
	ACTIONS.announce_list(client)
end

function ACTIONS.announce_delete(client, _, input)
	for index, old in ipairs(T.announcements) do
		if (old.id == input.id) then
			table.remove(T.announcements, index)
			SaveAnnouncements()

			break
		end
	end

	ACTIONS.announce_list(client)
end

net.Receive("nwTerminal", function(_, client)
	local action = net.ReadString()
	local terminal = net.ReadEntity()
	local input = util.JSONToTable(net.ReadString() or "") or {}
	local run = ACTIONS[action]

	if (!run or (client.nwTerminalNext or 0) > CurTime()) then
		return
	end

	client.nwTerminalNext = CurTime() + 0.25

	if (EDITOR[action]) then
		if (T.CanAnnounce(client)) then
			run(client, nil, input)
		end

		return
	end

	if (!T.IsNear(client, terminal) or !client.nwCharacter) then
		return
	end

	run(client, terminal, input)
end)
