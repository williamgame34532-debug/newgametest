util.AddNetworkString("nwCIDSync")

local C = NETWORK.cid
local dataPath = "network/cid_registry.txt"

C.cards = C.cards or {}

function C.Save()
	local overrides = {}

	for id, cid in pairs(C.overrides) do
		overrides[tostring(id)] = cid
	end

	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON({overrides = overrides, cards = C.cards}))
end

function C.Load()
	local data = util.JSONToTable(file.Read(dataPath, "DATA") or "") or {}

	C.overrides = {}

	for id, cid in pairs(data.overrides or {}) do
		C.overrides[tonumber(id) or 0] = tostring(cid)
	end

	C.cards = istable(data.cards) and data.cards or {}
end

function C.Sync(target)
	local list = {}

	for id, cid in pairs(C.overrides) do
		list[#list + 1] = {id, cid}
	end

	net.Start("nwCIDSync")
		NETWORK.util.WriteTable(list)

	if (target) then
		net.Send(target)
	else
		net.Broadcast()
	end
end

function C.IsTaken(cid, exceptID)
	exceptID = tonumber(exceptID) or 0

	for id, value in pairs(C.overrides) do
		if (value == cid and id != exceptID) then
			return true
		end
	end

	local rows = sql.Query(string.format(
		"SELECT id FROM network_characters WHERE (id %% 100000) = %d",
		tonumber(cid) or -1)) or {}

	for _, row in ipairs(rows) do
		local id = tonumber(row.id) or 0

		if (id != exceptID and !C.overrides[id]) then
			return true
		end
	end

	return false
end

function C.Set(id, cid)
	id = tonumber(id) or 0

	if (id <= 0) then
		return
	end

	if (!cid or cid == C.Default(id)) then
		C.overrides[id] = nil
	else
		C.overrides[id] = cid
	end

	C.Save()
	C.Sync()
end

function C.NewSerial()
	local serial

	repeat
		serial = string.format("%04X-%04X", math.random(0, 65535), math.random(0, 65535))
	until (!C.cards[serial])

	return serial
end

function C.RegisterCard(data)
	local serial = C.NewSerial()

	C.cards[serial] = {
		char = tonumber(data.char) or 0,
		cid = data.cid or "",
		name = data.name or "",
		by = data.by or "",
		issued = os.time(),
		valid = true
	}

	C.Save()

	return serial
end

function C.RevokeCards(id, exceptSerial)
	local count = 0

	for serial, card in pairs(C.cards) do
		if (card.char == id and card.valid and serial != exceptSerial) then
			card.valid = false
			count = count + 1
		end
	end

	if (count > 0) then
		C.Save()
	end

	return count
end

function C.Check(serial)
	serial = string.upper(string.Trim(tostring(serial or "")))

	return C.cards[serial], serial
end

function C.GetCards(id)
	local list = {}

	for serial, card in pairs(C.cards) do
		if (card.char == id) then
			list[#list + 1] = {
				serial = serial,
				cid = card.cid,
				name = card.name,
				issued = card.issued,
				valid = card.valid,
				by = card.by
			}
		end
	end

	table.sort(list, function(a, b)
		return (a.issued or 0) > (b.issued or 0)
	end)

	return list
end

local function SplitName(name)
	local first, rest = string.match(name, "^(%S+)%s*(.*)$")

	return first or name, rest or ""
end

function C.Issue(operator, target, fields)
	local character = IsValid(target) and target:GetCharacter()

	if (!character) then
		return false, "idNoTarget"
	end

	local name = NETWORK.util.Sanitise(fields.name or "", 40)
	local cid = C.Normalise(fields.cid)

	if (NETWORK.util.Length(name) < 3) then
		return false, "idBadName"
	end

	if (!cid) then
		return false, "idBadCID"
	end

	local id = character:GetID()

	if (cid != C.Get(id) and C.IsTaken(cid, id)) then
		return false, "idTaken", cid
	end

	if (fields.bRegistry) then
		C.Set(id, cid)

		local first, rest = SplitName(name)

		if (name != character:GetName()) then
			NETWORK.character.Update(character, {name = first, surname = rest})
		end
	end

	local serial = C.RegisterCard({
		char = id,
		cid = cid,
		name = name,
		by = operator:GetCharacterName()
	})

	if (fields.bRevoke) then
		C.RevokeCards(id, serial)
	end

	local data = {
		owner = name,
		number = cid,
		serial = serial,
		issuer = operator:GetCharacterName(),
		issued = os.date("%d.%m.%Y")
	}

	local receiver = target

	if (operator:GetPos():Distance(target:GetPos()) > 300 or
		!NETWORK.inventory.Give(target, "idcard", 1, data)) then
		receiver = operator

		if (!NETWORK.inventory.Give(operator, "idcard", 1, data)) then
			NETWORK.item.Spawn("idcard", operator:GetPos() + operator:GetForward() * 24 +
				Vector(0, 0, 40), nil, 1, data)
		end
	end

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("admin", string.format("%s выпустил ID-карту %s (%s, #%s) для %s%s",
			NETWORK.log.Name(operator), serial, name, cid, NETWORK.log.Name(target),
			fields.bRegistry and " [реестр]" or ""), operator:GetPos())
	end

	hook.Run("NetworkIDCardIssued", operator, target, data, fields)

	return true, receiver == target and "idIssuedTarget" or "idIssuedSelf", serial
end

hook.Add("Initialize", "nwCID", function()
	C.Load()
end)

hook.Add("PlayerInitialSpawn", "nwCID", function(client)
	timer.Simple(2, function()
		if (IsValid(client)) then
			C.Sync(client)
		end
	end)
end)

hook.Add("NetworkCharacterDeleted", "nwCID", function(_, character)
	if (character and C.overrides[character:GetID()]) then
		C.overrides[character:GetID()] = nil

		C.Save()
		C.Sync()
	end
end)
