-- Between players, server side (the wheel and the windows: cl_social.lua).
--   Познакомиться        a request; when accepted both know each other from then on (names over
--                        the body and in the chat). Kept in each character's data (known).
--   Передать токены      a request with the amount; accepted - the tokens move (rechecked then).
--   Показать CID-карту   a request; accepted - the other one sees the card of the shower.
--   Осмотреть            no request: the full description of the other character.
-- A request waits 20 seconds for the answer (keys "Принять" / "Отказаться", F1 / F2 by default,
-- changed in Бинды); one at a time per player. Bots accept by themselves.
-- Tokens: character data.tokens, shown as the NW2 int nwTokens. /givetokens <имя> <число> (staff).
-- The CID card: an item ("cid") a new character gets once, never again (not after death either).
-- Its data: name, number (#12345), gender, model, skin, faction, description, the issue date.

util.AddNetworkString("nwSocial")
util.AddNetworkString("nwRequest")
util.AddNetworkString("nwRequestAnswer")
util.AddNetworkString("nwKnown")
util.AddNetworkString("nwCidShow")
util.AddNetworkString("nwExamine")

NW.social = NW.social or {}

local SO = NW.social
local C = NW.char
local RANGE = 160
local WAIT = 20
local START_TOKENS = 20

local function Notify(client, text)
	NW.Notify(client, text)
end

-- ----------------------------------------------------------------- the card --
function SO.MakeCard(character, description)
	description = string.Trim(description or "")

	if (utf8.len(description) or 0) > 300 then
		description = string.sub(description, 1, (utf8.offset(description, 300) or 301) - 1) .. "…"
	end

	return {
		name = character.name,
		number = character.cid or string.format("%05d", math.random(0, 99999)),
		gender = character.gender,
		model = character.model,
		skin = character.skin or 0,
		faction = character.faction,
		description = description,
		issued = os.date("%d.%m.%Y")
	}
end

-- the data of a new character: its card in the first cell, the starting tokens
function SO.NewCharacterData(character, description)
	local card = SO.MakeCard(character, description)

	return {
		cid = card.number,
		tokens = START_TOKENS,
		inv = {grid = {{1, "cid", card}}, equip = {}}
	}
end

-- ---------------------------------------------------------------- knowing --
local function Known(client)
	local character = client.nwCharacter

	if (!character) then
		return {}
	end

	character.data = character.data or {}
	character.data.known = istable(character.data.known) and character.data.known or {}

	return character.data.known
end

hook.Add("NWRecognizes", "nwSocial", function(client, target)
	if (IsValid(target) and target:GetCharacterID() != 0 and Known(client)[tostring(target:GetCharacterID())]) then
		return true
	end
end)

local function SendKnown(client)
	local ids = {}

	for id in pairs(Known(client)) do
		ids[#ids + 1] = id
	end

	net.Start("nwKnown")
		net.WriteString(table.concat(ids, ","))
	net.Send(client)
end

local function Meet(a, b)
	Known(a)[tostring(b:GetCharacterID())] = true
	Known(b)[tostring(a:GetCharacterID())] = true
	C.SaveData(a)
	C.SaveData(b)
	SendKnown(a)
	SendKnown(b)
	Notify(a, "Вы познакомились: " .. b:Nick())
	Notify(b, "Вы познакомились: " .. a:Nick())
end

-- ----------------------------------------------------------------- tokens --
function SO.GetTokens(client)
	return client:GetNW2Int("nwTokens", 0)
end

function SO.SetTokens(client, amount)
	local character = client.nwCharacter

	amount = math.max(0, math.floor(amount))
	client:SetNW2Int("nwTokens", amount)

	if (character) then
		character.data = character.data or {}
		character.data.tokens = amount
		C.SaveData(client)
	end
end

hook.Add("NWCharacterLoaded", "nwSocial", function(client, character)
	client:SetNW2Int("nwTokens", math.max(0, math.floor(tonumber(character.data and character.data.tokens) or 0)))
	client.nwRequest = nil
	SendKnown(client)
end)

NW.AddChatCommand("givetokens", {admin = true, run = function(client, rest)
	local who, amount = string.match(rest, "^(.-)%s+(%-?%d+)$")
	local target = who and NW.FindPlayer(who)

	if (!target or target:GetCharacterID() == 0) then
		return Notify(client, "Использование: /givetokens <имя> <число>")
	end

	SO.SetTokens(target, SO.GetTokens(target) + tonumber(amount))
	Notify(client, string.format("%s: токенов теперь %d", target:Nick(), SO.GetTokens(target)))

	if (target != client) then
		Notify(target, "Ваш баланс изменён: " .. SO.GetTokens(target) .. " токенов")
	end
end})

-- ---------------------------------------------------------------- the card --
local function FindCard(client)
	local inventory = NW.inventory.Get(client)

	for index = 1, NW.items.maxSize do
		local cell = inventory.grid[index]

		if (cell and cell.id == "cid") then
			return cell
		end
	end
end

function SO.ShowCard(viewer, data)
	net.Start("nwCidShow")
		net.WriteString(util.TableToJSON(istable(data) and data or {}))
	net.Send(viewer)
end

-- -------------------------------------------------------------- requests --
local nextID = 0

local function Close(a, b)
	return IsValid(a) and IsValid(b) and a:Alive() and b:Alive() and a:GetCharacterID() != 0 and
		b:GetCharacterID() != 0 and a:GetPos():DistToSqr(b:GetPos()) <= RANGE * RANGE
end

-- kind: "meet", "tokens", "cid"; accept() runs when the target agrees (both still close)
local function Request(from, target, kind, amount, accept)
	local pending = target.nwRequest

	if (pending and pending.expires > CurTime() and IsValid(pending.from)) then
		return Notify(from, "Игрок сейчас отвечает на другой запрос")
	end

	nextID = nextID + 1
	target.nwRequest = {id = nextID, from = from, kind = kind, accept = accept, expires = CurTime() + WAIT}

	if (target:IsBot()) then
		local id = nextID

		timer.Simple(1, function()
			if (IsValid(target) and target.nwRequest and target.nwRequest.id == id) then
				target.nwRequest = nil

				if (Close(from, target)) then
					accept()
				end
			end
		end)
	else
		net.Start("nwRequest")
			net.WriteUInt(nextID, 16)
			net.WriteEntity(from)
			net.WriteString(kind)
			net.WriteUInt(amount or 0, 24)
			net.WriteUInt(WAIT, 8)
		net.Send(target)
	end

	Notify(from, "Запрос отправлен, ждём ответа")
end

net.Receive("nwRequestAnswer", function(_, client)
	local id = net.ReadUInt(16)
	local yes = net.ReadBool()
	local pending = client.nwRequest

	if (!pending or pending.id != id) then
		return
	end

	client.nwRequest = nil

	if (pending.expires < CurTime() or !IsValid(pending.from)) then
		return
	end

	if (!yes) then
		return Notify(pending.from, "Отказ: " .. (C.Knows(pending.from, client) and client:Nick() or "Неизвестный") ..
			" не согласен")
	end

	if (!Close(pending.from, client)) then
		return Notify(client, "Слишком далеко")
	end

	pending.accept()
end)

-- ----------------------------------------------------------- the actions --
local ACTIONS = {}

-- other files add theirs (sv_body.lua: pulse, help up, heal, searching)
SO.actions = ACTIONS
SO.Request = function(...)
	return Request(...)
end

function ACTIONS.meet(client, target)
	if (C.Knows(client, target) and C.Knows(target, client)) then
		return Notify(client, "Вы уже знакомы")
	end

	Request(client, target, "meet", 0, function()
		Meet(client, target)
		NW.skills.Add(client, "speech", 5)
		NW.skills.Add(target, "speech", 5)
	end)
end

function ACTIONS.tokens(client, target, amount)
	amount = math.floor(amount or 0)

	if (amount < 1) then
		return Notify(client, "Укажите количество токенов")
	end

	if (SO.GetTokens(client) < amount) then
		return Notify(client, "У вас нет столько токенов")
	end

	Request(client, target, "tokens", amount, function()
		if (SO.GetTokens(client) < amount) then
			Notify(target, "Передача не состоялась")

			return Notify(client, "У вас нет столько токенов")
		end

		SO.SetTokens(client, SO.GetTokens(client) - amount)
		SO.SetTokens(target, SO.GetTokens(target) + amount)
		Notify(client, "Вы передали " .. amount .. " ток.")
		Notify(target, "Вы получили " .. amount .. " ток.")
	end)
end

function ACTIONS.cid(client, target)
	if (!FindCard(client)) then
		return Notify(client, "У вас нет CID-карты")
	end

	Request(client, target, "cid", 0, function()
		local card = FindCard(client)

		if (!card) then
			return Notify(target, "Карту так и не показали")
		end

		SO.ShowCard(target, card.data)
	end)
end

function ACTIONS.examine(client, target)
	local character = target.nwCharacter

	net.Start("nwExamine")
		net.WriteEntity(target)
		net.WriteString(character and character.description or target:GetCharacterDescription())
	net.Send(client)
end

net.Receive("nwSocial", function(_, client)
	local kind = net.ReadString()
	local target = net.ReadEntity()
	local amount = net.ReadUInt(24)

	if ((client.nwSocialNext or 0) > CurTime()) then
		return
	end

	client.nwSocialNext = CurTime() + 0.5

	local action = ACTIONS[kind]

	if (!action or !IsValid(target) or target == client or client:GetNW2Bool("nwKnocked", false)) then
		return
	end

	-- a player, or a body (sv_body.lua)
	if (target:IsPlayer()) then
		if (!Close(client, target)) then
			return Notify(client, "Подойдите ближе")
		end
	elseif (!SO.IsBody or !SO.IsBody(target) or !client:Alive() or client:GetCharacterID() == 0 or
		client:GetPos():DistToSqr(target:GetPos()) > RANGE * RANGE) then
		return Notify(client, "Подойдите ближе")
	end

	action(client, target, amount)
end)

-- F1 / F2 open nothing (they answer requests now, sh_keys.lua)
function GM:ShowHelp()
end

function GM:ShowTeam()
end
