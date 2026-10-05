util.AddNetworkString("nwDocView")
util.AddNetworkString("nwDocForm")
util.AddNetworkString("nwDocForge")
util.AddNetworkString("nwDocVerify")

local D = NETWORK.documents
local dataPath = "network/documents.txt"

D.registry = D.registry or {}

local function Notice(client, key, tone, ...)
	NETWORK.notice.Send(client, key, tone, ...)
end

function D.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(D.registry))
end

function D.Load()
	D.registry = util.JSONToTable(file.Read(dataPath, "DATA") or "") or {}
end

function D.NewSerial(prefix)
	local serial

	repeat
		serial = string.format("%s-%05d", prefix or "DC", math.random(0, 99999))
	until (!D.registry[serial])

	return serial
end

function D.Verify(serial)
	serial = string.upper(string.Trim(tostring(serial or "")))

	local entry = D.registry[serial]

	if (entry) then
		if (entry.revoked) then
			return "revoked", entry, serial
		end

		if ((entry.expires or 0) > 0 and entry.expires < os.time()) then
			return "expired", entry, serial
		end

		return "valid", entry, serial
	end

	local card = NETWORK.cid and NETWORK.cid.Check(serial)

	if (card) then
		return card.valid and "valid" or "revoked", {
			type = "idcard",
			holder = card.name,
			cid = card.cid,
			issuer = card.by,
			issued = card.issued
		}, serial
	end

	return "missing", nil, serial
end

local function FindByCID(cid)
	for _, target in ipairs(player.GetAll()) do
		local character = target:GetCharacter()

		if (character and NETWORK.terminal.GetCitizenID(character) == cid) then
			return target
		end
	end
end

function D.Issue(operator, kind, fields)
	local docType = D.GetType(fields.type)

	if (!docType or !docType.issuers[kind]) then
		return false, "docBadType"
	end

	local cid = NETWORK.cid.Normalise(fields.cid)

	if (!cid) then
		return false, "idBadCID"
	end

	local target = FindByCID(cid)
	local holder = NETWORK.util.Sanitise(fields.holder or "", 40)

	if (holder == "") then
		if (!IsValid(target)) then
			return false, "docHolderUnknown"
		end

		holder = target:GetCharacterName()
	end

	local hours = math.Clamp(math.floor(tonumber(fields.hours) or docType.hours), 0, 720)
	local text = NETWORK.util.Sanitise(fields.text or "", D.textMax, true)

	local serial = D.NewSerial(kind == "cwu" and "GS" or (kind == "medic" and "MD" or "AL"))
	local now = os.time()

	D.registry[serial] = {
		type = docType.id,
		holder = holder,
		cid = cid,
		text = text,
		issuer = operator:GetCharacterName(),
		kind = kind,
		issued = now,
		expires = hours > 0 and now + hours * 3600 or 0
	}

	D.Save()

	local data = {
		type = docType.id,
		holder = holder,
		cid = cid,
		text = text,
		serial = serial,
		issuer = operator:GetCharacterName(),
		issued = os.date("%d.%m.%Y %H:%M", now),
		expires = hours > 0 and os.date("%d.%m.%Y %H:%M", now + hours * 3600) or ""
	}

	local receiver = operator

	if (IsValid(target) and target:GetPos():Distance(operator:GetPos()) <= 300 and
		NETWORK.inventory.Give(target, "document", 1, data)) then
		receiver = target
	elseif (!NETWORK.inventory.Give(operator, "document", 1, data)) then
		NETWORK.item.Spawn("document", operator:GetPos() + operator:GetForward() * 24 +
			Vector(0, 0, 40), nil, 1, data)
	end

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("admin", string.format("%s выдал документ %s (%s) на %s #%s",
			NETWORK.log.Name(operator), serial, docType.id, holder, cid), operator:GetPos())
	end

	return true, receiver == operator and "docIssuedSelf" or "docIssuedTarget", serial
end

function D.Revoke(operator, serial)
	local entry = D.registry[serial]

	if (!entry) then
		return false, "docNotFound"
	end

	if (entry.revoked) then
		return false, "docAlreadyRevoked"
	end

	entry.revoked = true
	entry.revokedBy = operator:GetCharacterName()

	D.Save()

	return true, "docRevoked", serial
end

function D.GetRecent(kind, limit)
	local list = {}

	for serial, entry in pairs(D.registry) do
		if (!kind or entry.kind == kind) then
			list[#list + 1] = {
				serial = serial,
				type = entry.type,
				holder = entry.holder,
				cid = entry.cid,
				issued = entry.issued,
				revoked = entry.revoked == true,
				expired = (entry.expires or 0) > 0 and entry.expires < os.time()
			}
		end
	end

	table.sort(list, function(a, b)
		return (a.issued or 0) > (b.issued or 0)
	end)

	while (#list > (limit or 8)) do
		table.remove(list)
	end

	return list
end

function D.Send(receiver, view, shownBy)
	net.Start("nwDocView")
		NETWORK.util.WriteTable(view)
		net.WriteString(shownBy or "")
	net.Send(receiver)
end

function D.Stamp(view)
	if (!view) then
		return view
	end

	if (view.serial and view.serial != "") then
		local status = D.Verify(view.serial)

		view.status = status == "missing" and "forged" or status
	else
		view.status = "valid"
	end

	return view
end

function D.View(client, item)
	local view = D.Stamp(D.BuildView(item))

	if (view) then
		D.Send(client, view)
	end
end

function D.Show(client, target, item)
	local view = D.Stamp(D.BuildView(item))

	if (!view) then
		return
	end

	D.Send(target, view, client:GetRecognisedName(target))

	Notice(client, "docShown", "info")
	NETWORK.chat.Send(client, "me", L("docShowMe"))
end

net.Receive("nwDocVerify", function(_, client)
	local serial = net.ReadString()

	if (!NETWORK.factions.CanCheckDocuments(client)) then
		return
	end

	if ((client.nwNextDocVerify or 0) > CurTime()) then
		return
	end

	client.nwNextDocVerify = CurTime() + 1.5

	local status, entry = D.Verify(serial)

	if (status == "valid") then
		Notice(client, "docVerifyValid", "good", serial, entry.holder or "?")
	elseif (status == "missing") then
		Notice(client, "docVerifyMissing", "bad", serial)
	else
		Notice(client, status == "revoked" and "docVerifyRevoked" or "docVerifyExpired",
			"warn", serial)
	end
end)

function D.OpenForge(client, item)
	client.nwForgeItem = item

	net.Start("nwDocForm")
	net.Send(client)
end

net.Receive("nwDocForge", function(_, client)
	local fields = NETWORK.util.ReadTable() or {}
	local item = client.nwForgeItem

	client.nwForgeItem = nil

	if (!istable(item) or item.id != "blank_form") then
		return
	end

	local state = NETWORK.inventory.GetState(client)
	local bFound = false

	for _, other in pairs(state.items) do
		if (other == item) then
			bFound = true

			break
		end
	end

	if (!bFound) then
		return
	end

	local docType = D.GetType(fields.type) or D.GetType("note")
	local holder = NETWORK.util.Sanitise(fields.holder or "", 40)
	local cid = NETWORK.cid.Normalise(fields.cid) or ""

	if (holder == "") then
		return Notice(client, "docHolderUnknown", "bad")
	end

	if ((item.amount or 1) > 1) then
		item.amount = item.amount - 1

		local forged = {
			type = docType.id,
			holder = holder,
			cid = cid,
			text = NETWORK.util.Sanitise(fields.text or "", D.textMax, true),
			serial = string.format("AL-%05d", math.random(0, 99999)),
			issuer = NETWORK.util.Sanitise(fields.issuer or "", 40),
			issued = os.date("%d.%m.%Y %H:%M")
		}

		if (!NETWORK.inventory.Give(client, "document", 1, forged)) then
			item.amount = item.amount + 1

			return Notice(client, "deployNoRoom", "bad")
		end
	else
		item.id = "document"
		item.amount = 1
		item.data = {
			type = docType.id,
			holder = holder,
			cid = cid,
			text = NETWORK.util.Sanitise(fields.text or "", D.textMax, true),

			serial = string.format("AL-%05d", math.random(0, 99999)),
			issuer = NETWORK.util.Sanitise(fields.issuer or "", 40),
			issued = os.date("%d.%m.%Y %H:%M")
		}
	end

	NETWORK.inventory.Sync(client)

	Notice(client, "docForged", "info")
end)

hook.Add("Initialize", "nwDocuments", function()
	D.Load()
end)
