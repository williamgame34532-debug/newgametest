NETWORK.admincomp = NETWORK.admincomp or {}

local AC = NETWORK.admincomp

AC.class = "administration"
AC.councilClass = "council"
AC.cwuClass = "cwuhead"
AC.range = 120

function AC.GetKind(entity)
	if (IsValid(entity)) then
		local class = entity:GetClass()

		if (class == "nw_cwu_computer") then
			return "cwu"
		end

		if (class == "nw_council_computer") then
			return "council"
		end
	end

	return "admin"
end

function AC.DeniedKey(entity)
	local kind = AC.GetKind(entity)

	if (kind == "cwu") then
		return "cwuCompDenied"
	end

	return kind == "council" and "councilCompDenied" or "adminCompDenied"
end

function AC.IsCWUHead(client, entity)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	if (client:IsAdmin()) then
		return true
	end

	if (client:GetNWString("nwClass", "") != AC.cwuClass) then
		return false
	end

	if (IsValid(entity) and entity.GetOwnerName) then
		local owner = entity:GetOwnerName()

		return owner == "" or NETWORK.util.Lower(owner) ==
			NETWORK.util.Lower(client:GetCharacterName())
	end

	return true
end

function AC.CanUse(client, entity)
	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
		return false
	end

	if (client:IsAdmin()) then
		return true
	end

	if (AC.GetKind(entity) == "cwu") then

		return AC.IsCWUHead(client, entity) or NETWORK.factions.IsAlliance(client)
	end

	return NETWORK.classes.IsAdministrative(client)
end

if (CLIENT) then
	return
end

util.AddNetworkString("nwAdminCompOpen")
util.AddNetworkString("nwAdminCompReq")
util.AddNetworkString("nwAdminCompData")

local function Notice(client, key, tone, ...)
	if (key) then
		NETWORK.notice.Send(client, key, tone or "info", ...)
	end
end

function AC.Open(client, entity)
	if (!AC.CanUse(client, entity)) then
		return Notice(client, AC.DeniedKey(entity), "bad")
	end

	if (client:GetPos():Distance(entity:GetPos()) > AC.range) then
		return
	end

	client.nwAdminComp = entity

	net.Start("nwAdminCompOpen")
		net.WriteEntity(entity)
	net.Send(client)
end

function AC.IsSession(client)
	local entity = client.nwAdminComp

	return AC.CanUse(client, entity) and IsValid(entity) and
		client:GetPos():Distance(entity:GetPos()) <= AC.range + 80
end

function AC.Reply(client, app, data)
	net.Start("nwAdminCompData")
		net.WriteString(app)
		NETWORK.util.WriteTable(data or {})
	net.Send(client)
end

local function FactionLabel(id)
	local faction = NETWORK.factions.Get(id or "")

	return faction and L(faction.name) or tostring(id or "?")
end

local function OnlineByChar()
	local list = {}

	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (character) then
			list[character:GetID()] = client
		end
	end

	return list
end

function AC.BuildDatabase()
	local rows = sql.Query("SELECT id, name, surname, faction, lastused FROM network_characters") or {}
	local online = OnlineByChar()
	local result = {alliance = {}, cwu = {}, citizens = {}}
	local withCards = {}

	for _, card in pairs(NETWORK.cid.cards or {}) do
		withCards[tonumber(card.char) or 0] = true
	end

	for _, row in ipairs(rows) do
		local id = tonumber(row.id)
		local faction = NETWORK.factions.Get(row.faction or "")
		local category

		if (faction and faction.bCombine) then
			category = "alliance"
		elseif (faction and faction.bCWU) then
			category = "cwu"
		elseif (row.faction == "citizen" and withCards[id]) then
			category = "citizens"
		end

		if (category) then
			local list = result[category]

			list[#list + 1] = {
				id = id,
				name = string.Trim((row.name or "") .. " " .. (row.surname or "")),
				cid = NETWORK.cid.Get(id),
				faction = FactionLabel(row.faction),
				bOnline = online[id] != nil
			}
		end
	end

	for _, list in pairs(result) do
		table.sort(list, function(a, b)
			if (a.bOnline != b.bOnline) then
				return a.bOnline
			end

			return a.name < b.name
		end)
	end

	return result
end

function AC.BuildRecord(id)
	id = tonumber(id) or 0

	local row = (sql.Query("SELECT id, name, surname, faction, lastused, created FROM " ..
		"network_characters WHERE id = " .. id) or {})[1]

	if (!row) then
		return
	end

	local target = OnlineByChar()[id]
	local key = tostring(id)
	local loyalty

	if (IsValid(target)) then
		loyalty = target:GetLoyalty()
	else
		local cache = NETWORK.persistence and NETWORK.persistence.cache[key]

		loyalty = cache and tonumber(cache.loyalty) or NETWORK.loyalty.default
	end

	local band = NETWORK.loyalty.GetBand(loyalty)
	local violations = {}

	for _, entry in ipairs((NETWORK.cmbterm.violations or {})[key] or {}) do
		violations[#violations + 1] = {
			reason = entry.reason or "?",
			term = entry.term or 0,
			time = entry.time and os.date("%d.%m.%Y", entry.time) or ""
		}
	end

	local notes = {}

	for _, entry in ipairs((NETWORK.cmbterm.notes or {})[key] or {}) do
		notes[#notes + 1] = {
			author = entry.author or "?",
			text = entry.text or "",
			time = entry.time and os.date("%d.%m %H:%M", entry.time) or ""
		}
	end

	local cards = {}

	for _, card in ipairs(NETWORK.cid.GetCards(id)) do
		cards[#cards + 1] = {
			serial = card.serial or "?",
			bValid = card.valid != false,
			issued = card.issued and os.date("%d.%m.%Y", card.issued) or ""
		}
	end

	local housing = ""

	for _, entity in ipairs(ents.GetAll()) do
		if (NETWORK.door.IsDoor(entity)) then
			local data = NETWORK.door.GetData(entity)

			local bResident = data and data.type == "residential" and
				tostring(data.ownerChar or "") == key

			if (data and data.type == "residential" and !bResident) then
				for _, entry in pairs(NETWORK.door.GetOwners(data)) do
					if (istable(entry) and tostring(entry.char or "") == key) then
						bResident = true

						break
					end
				end
			end

			if (bResident) then

				local name = NETWORK.door.GetHousingName(data)

				housing = name != "" and name or "Квартира без названия"

				break
			end
		end
	end

	local business = NETWORK.business.stored[key]
	local class = IsValid(target) and NETWORK.classes.Get(target:GetNWString("nwClass", ""))

	return {
		id = id,
		name = string.Trim((row.name or "") .. " " .. (row.surname or "")),
		cid = NETWORK.cid.Get(id),
		faction = FactionLabel(row.faction),
		class = class and L(class.name) or "",
		bOnline = IsValid(target),
		lastUsed = os.date("%d.%m.%Y %H:%M", tonumber(row.lastused) or 0),
		created = os.date("%d.%m.%Y", tonumber(row.created) or 0),
		loyalty = loyalty,
		band = L(band.label),
		bandColor = {band.color.r, band.color.g, band.color.b},
		violations = violations,
		notes = notes,
		cards = cards,
		housing = housing,
		business = business and {what = business.what, status = business.status} or nil
	}
end

function AC.BuildHousing()
	local blocks = {}
	local order = {}
	local zoneBlocks = {}

	local function Block(name)
		if (!blocks[name]) then
			blocks[name] = {name = name, total = 0, taken = 0, flats = {}}
			order[#order + 1] = name
		end

		return blocks[name]
	end

	for _, entity in ipairs(ents.GetAll()) do
		if (!NETWORK.door.IsDoor(entity)) then
			continue
		end

		local data = NETWORK.door.GetData(entity)

		if (!data or data.type != "residential") then
			continue
		end

		local zone = NETWORK.zone.AtEntity(entity)
		local zoneName = zone and zone.name != "" and zone.name or "Без блока"
		local blockName = string.Trim(tostring(data.block or ""))

		if (blockName == "") then
			blockName = zoneName
		end

		zoneBlocks[zoneName] = zoneBlocks[zoneName] or blockName

		local block = Block(blockName)

		block.total = block.total + 1

		local owners = NETWORK.door.GetOwners(data)
		local names = {}

		for _, entry in pairs(owners) do
			names[#names + 1] = entry.name or "?"
		end

		if (#names > 0) then
			block.taken = block.taken + 1
		end

		local title = string.Trim(tostring(data.title or ""))
		local number = string.Trim(tostring(data.number or ""))

		block.flats[#block.flats + 1] = {
			name = title != "" and title or
				("Квартира " .. (number != "" and number or block.total)),
			owner = table.concat(names, ", ")
		}
	end

	local cameras = {}

	for _, camera in ipairs(ents.FindByClass("nw_housing_camera")) do
		local zone = NETWORK.zone.At(camera:GetPos())
		local zoneName = zone and zone.name != "" and zone.name or "Без блока"

		cameras[#cameras + 1] = {
			index = camera:EntIndex(),
			name = camera:GetCamName(),
			block = zoneBlocks[zoneName] or zoneName
		}

		Block(cameras[#cameras].block)
	end

	local list = {}

	table.sort(order)

	for _, name in ipairs(order) do
		local block = blocks[name]

		table.sort(block.flats, function(a, b)
			return a.name < b.name
		end)

		list[#list + 1] = block
	end

	return {blocks = list, cameras = cameras}
end

function AC.BuildBudget()
	local B = NETWORK.budget
	local salaries = {}

	for _, group in ipairs(B.groups) do
		local count = 0

		for _, client in ipairs(player.GetAll()) do
			if (B.GetGroup(client) == group.id) then
				count = count + 1
			end
		end

		salaries[#salaries + 1] = {
			id = group.id,
			label = group.label,
			amount = B.state.salaries[group.id] or 0,
			online = count
		}
	end

	return {
		balance = B.state.balance,
		income = B.state.income,
		interval = B.interval,
		nextPay = B.GetNextPay(),
		maxSalary = B.maxSalary,
		salaries = salaries,
		history = B.state.history,
		log = B.state.log
	}
end

function AC.BuildMail()
	local list = {}

	for _, letter in ipairs(NETWORK.mail.letters) do
		local business = letter.businessID and NETWORK.business.stored[letter.businessID]

		list[#list + 1] = {
			id = letter.id,
			kind = letter.kind,
			from = letter.from,
			cid = letter.cid,
			subject = letter.subject,
			text = letter.text,
			time = os.date("%d.%m %H:%M", letter.time or 0),
			bRead = letter.bRead == true,
			reply = letter.reply,
			status = business and business.status or letter.status or
				(letter.offerID and NETWORK.parcel.Get(letter.offerID) and
				NETWORK.parcel.Get(letter.offerID).status) or nil,
			location = business and business.location or nil
		}
	end

	return {letters = list}
end

local ACTIONS = {}

ACTIONS.db_list = function(client)
	AC.Reply(client, "database", {list = AC.BuildDatabase()})
end

ACTIONS.db_record = function(client, payload)
	local record = AC.BuildRecord(payload.id)

	if (record) then
		AC.Reply(client, "record", record)
	end
end

ACTIONS.board_list = function(client)
	AC.Reply(client, "board", {messages = NETWORK.channels.GetMessages("board")})
end

ACTIONS.board_post = function(client, payload)
	local bOk, key = NETWORK.channels.Post(client, "admin", "board", payload.text)

	Notice(client, key or (bOk and "chanPosted"), bOk and "good" or "bad")
	ACTIONS.board_list(client)
end

local function DocKind(client)
	return NETWORK.factions.IsAlliance(client) and "alliance" or "cwu"
end

ACTIONS.doc_state = function(client, payload)
	local kind = DocKind(client)
	local types = {}

	for _, data in ipairs(NETWORK.documents.GetTypesFor(kind)) do
		types[#types + 1] = {id = data.id, name = L(data.name), hours = data.hours}
	end

	local recent = NETWORK.documents.GetRecent(nil, 12)

	for _, entry in ipairs(recent) do
		local docType = NETWORK.documents.GetType(entry.type)

		entry.typeName = entry.type == "idcard" and "ID-карта" or (docType and L(docType.name) or "?")
		entry.issuedText = os.date("%d.%m %H:%M", entry.issued or 0)
	end

	AC.Reply(client, "documents", {
		types = types,
		recent = recent,
		check = payload and payload.check or nil
	})
end

ACTIONS.doc_issue = function(client, payload)
	local bOk, key, serial = NETWORK.documents.Issue(client, DocKind(client), {
		type = payload.type,
		cid = payload.cid,
		holder = payload.holder,
		hours = payload.hours,
		text = payload.text
	})

	Notice(client, key, bOk and "good" or "bad", serial)
	ACTIONS.doc_state(client)
end

ACTIONS.doc_verify = function(client, payload)
	local status, entry, serial = NETWORK.documents.Verify(payload.serial)

	ACTIONS.doc_state(client, {check = {
		serial = serial,
		status = status,
		holder = entry and entry.holder or "",
		cid = entry and entry.cid or ""
	}})
end

ACTIONS.doc_revoke = function(client, payload)
	local bOk, key = NETWORK.documents.Revoke(client, string.upper(tostring(payload.serial or "")))

	Notice(client, key, bOk and "good" or "bad", payload.serial)
	ACTIONS.doc_state(client)
end

ACTIONS.mail_list = function(client)
	AC.Reply(client, "mail", AC.BuildMail())
end

ACTIONS.mail_read = function(client, payload)
	local letter = NETWORK.mail.Get(tonumber(payload.id) or 0)

	if (letter and !letter.bRead) then
		letter.bRead = true
		NETWORK.mail.Save()
	end

	ACTIONS.mail_list(client)
end

ACTIONS.mail_reply = function(client, payload)
	local bOk, key = NETWORK.mail.Reply(client, tonumber(payload.id) or 0, payload.text)

	Notice(client, key, bOk and "good" or "bad")
	ACTIONS.mail_list(client)
end

ACTIONS.mail_decide = function(client, payload)
	local letter = NETWORK.mail.Get(tonumber(payload.id) or 0)

	if (letter and letter.businessID) then
		local bOk = NETWORK.business.Decide(letter.businessID, payload.location or "",
			payload.bApprove == true, client:GetCharacterName())

		Notice(client, bOk and (payload.bApprove and "mailBizApproved" or "mailBizDenied") or
			"mailBizMissing", bOk and "good" or "bad")
	end

	ACTIONS.mail_list(client)
end

ACTIONS.mail_offer = function(client, payload)
	local letter = NETWORK.mail.Get(tonumber(payload.id) or 0)

	if (letter and letter.offerID) then
		local bOk, key = NETWORK.parcel.Decide(client, letter.offerID, payload.bAccept == true)

		Notice(client, key, bOk and "good" or "bad")
	end

	ACTIONS.mail_list(client)
end

ACTIONS.decisions_state = function(client)
	local list = {}

	for _, entry in ipairs(NETWORK.decisions.list) do
		list[#list + 1] = {
			id = entry.id, title = entry.title, text = entry.text, author = entry.author,
			accept = entry.accept, decline = entry.decline, status = entry.status,
			by = entry.by, time = os.date("%d.%m %H:%M", entry.time or 0)
		}
	end

	AC.Reply(client, "decisions", {list = list})
end

ACTIONS.decisions_decide = function(client, payload)
	local bOk, key, delta = NETWORK.decisions.Decide(client, tonumber(payload.id) or 0,
		payload.bAccept == true)

	Notice(client, key, bOk and "good" or "bad", delta)
	ACTIONS.decisions_state(client)
end

ACTIONS.budget_state = function(client)
	AC.Reply(client, "budget", AC.BuildBudget())
end

ACTIONS.budget_salaries = function(client, payload)
	for group, amount in pairs(istable(payload.salaries) and payload.salaries or {}) do
		NETWORK.budget.SetSalary(client, tostring(group), amount)
	end

	Notice(client, "budgetSaved", "good")
	ACTIONS.budget_state(client)
end

ACTIONS.supply_state = function(client)
	local S = NETWORK.supply
	local catalog = {}

	for _, entry in ipairs(S.catalog) do
		catalog[#catalog + 1] = {id = entry.id, name = L(entry.name), cost = entry.cost,
			desc = entry.description and L(entry.description) or ""}
	end

	local orders = {}

	for _, order in ipairs(S.orders) do
		local entry = S.GetEntry(order.entry)

		orders[#orders + 1] = {id = order.id, name = entry and L(entry.name) or "?",
			by = order.by, worker = order.workerName or "", status = order.status}
	end

	AC.Reply(client, "supply", {catalog = catalog, orders = orders, fund = S.fund,
		fundMax = S.fundMax, bCanOrder = S.CanOrder(client)})
end

ACTIONS.supply_order = function(client, payload)
	local bOk, key, name = NETWORK.supply.Order(client, tostring(payload.id or ""))

	Notice(client, key, bOk and "good" or "bad", name)
	ACTIONS.supply_state(client)
end

ACTIONS.supply_cancel = function(client, payload)
	local bOk, key = NETWORK.supply.Cancel(client, tonumber(payload.id) or 0)

	Notice(client, key, bOk and "good" or "bad")
	ACTIONS.supply_state(client)
end

AC.callLog = AC.callLog or {}
AC.callCooldown = 45
AC.nextCall = AC.nextCall or 0

local CALL_FACTIONS = {cp = "Гражданская Оборона", cmb = "ОТА"}

local function CallState(client)
	local online = {cp = 0, cmb = 0}

	for _, other in ipairs(player.GetAll()) do
		local faction = other:HasCharacter() and other:GetCharacterFaction() or nil

		if (faction and online[faction]) then
			online[faction] = online[faction] + 1
		end
	end

	AC.Reply(client, "call", {
		log = AC.callLog,
		nextCall = AC.nextCall,
		cpOnline = online.cp,
		cmbOnline = online.cmb
	})
end

ACTIONS.call_state = function(client)
	CallState(client)
end

ACTIONS.call_send = function(client, payload)
	local faction = tostring(payload.faction or "")
	local label = CALL_FACTIONS[faction]

	if (!label) then
		return
	end

	if (AC.nextCall > CurTime()) then
		Notice(client, "acCallCooldown", "warn")

		return CallState(client)
	end

	local reason = NETWORK.util.Sanitise(tostring(payload.reason or ""), 120)

	if (reason == "") then
		reason = L("acCallDefault")
	end

	local entity = client.nwAdminComp
	local zone = IsValid(entity) and NETWORK.zone and NETWORK.zone.At(entity:GetPos())
	local place = zone and zone.name or L("acCallPlaceDefault")

	AC.nextCall = CurTime() + AC.callCooldown

	AC.callLog[#AC.callLog + 1] = {
		time = os.date("%H:%M"),
		faction = label,
		who = client:GetCharacterName(),
		reason = reason
	}

	while (#AC.callLog > 20) do
		table.remove(AC.callLog, 1)
	end

	local alert = L("acCallAlert", label, place, reason)
	local count = 0

	for _, other in ipairs(player.GetAll()) do
		if (!other:HasCharacter() or !NETWORK.factions.IsAlliance(other)) then
			continue
		end

		net.Start("nwChatMessage")
			net.WriteString("center")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(alert)
		net.Send(other)

		if (other:GetCharacterFaction() == faction) then
			other:EmitSound("npc/overwatch/radiovoice/on1.wav", 60, 100)

			count = count + 1

			if (IsValid(entity) and NETWORK.waypoint and NETWORK.waypoint.Add) then
				NETWORK.waypoint.Add(other, entity:GetPos() + Vector(0, 0, 32),
					L("callWaypoint", reason), Color(86, 150, 226), 600, true, "call")
			end
		end
	end

	if (IsValid(entity)) then
		entity:EmitSound("ambient/machines/keyboard7_clicks_enter.wav", 60, 100)
	end

	Notice(client, "acCallSent", "good", label, count)
	CallState(client)
end

ACTIONS.housing_state = function(client)
	AC.Reply(client, "housing", AC.BuildHousing())
end

net.Receive("nwAdminCompReq", function(_, client)
	local action = net.ReadString()
	local payload = NETWORK.util.ReadTable() or {}
	local handler = ACTIONS[action]

	if (!handler or !AC.IsSession(client)) then
		return
	end

	local bCWUAction = string.sub(action, 1, 4) == "cwu_"

	if ((AC.GetKind(client.nwAdminComp) == "cwu") != bCWUAction) then
		return
	end

	if (bCWUAction and action != "cwu_state" and !AC.IsCWUHead(client, client.nwAdminComp)) then
		return
	end

	if ((client.nwNextCompReq or 0) > CurTime()) then
		return
	end

	client.nwNextCompReq = CurTime() + 0.15

	handler(client, payload)
end)

AC.cwuPath = "network/cwucomputer.txt"
AC.cwu = AC.cwu or {fines = {}, notes = {}, nextID = 1}
AC.cwuCallCooldown = 30
AC.cwuNextCall = AC.cwuNextCall or 0
AC.cwuFineMax = 500

AC.cwuRoles = {
	{id = "medic", label = "cwuRoleMedic", classes = {medic = true}},
	{id = "engineer", label = "cwuRoleEngineer", classes = {worker_factory = true, factoryworker = true}},
	{id = "mechanic", label = "cwuRoleMechanic", classes = {mechanic = true}},
	{id = "disinfector", label = "cwuRoleDisinfector", factions = {disinfector = true}}
}

function AC.LoadCWU()
	local raw = file.Read(AC.cwuPath, "DATA")
	local data = raw and util.JSONToTable(raw)

	if (istable(data)) then
		AC.cwu.fines = istable(data.fines) and data.fines or {}
		AC.cwu.notes = istable(data.notes) and data.notes or {}
		AC.cwu.nextID = tonumber(data.nextID) or 1
	end
end

function AC.SaveCWU()
	file.CreateDir("network")
	file.Write(AC.cwuPath, util.TableToJSON(AC.cwu, true))
end

hook.Add("Initialize", "nwCWUCompLoad", AC.LoadCWU)

local function RoleOf(client)
	local class = client:GetNWString("nwClass", "")
	local faction = client:GetCharacterFaction()

	for _, role in ipairs(AC.cwuRoles) do
		if ((role.classes and role.classes[class]) or (role.factions and role.factions[faction])) then
			return role
		end
	end
end

function AC.BuildCWU(client)
	local staff = {}
	local counts = {}

	for _, other in ipairs(player.GetAll()) do
		if (!other:HasCharacter()) then
			continue
		end

		local role = RoleOf(other)
		local bCWU = NETWORK.factions.IsCWU(other)

		if (!role and !bCWU) then
			continue
		end

		local class = NETWORK.classes.Get(other:GetNWString("nwClass", ""))

		staff[#staff + 1] = {
			name = other:GetCharacterName(),
			role = role and L(role.label) or (class and L(class.name)) or FactionLabel(other:GetCharacterFaction()),
			roleID = role and role.id or "",
			tokens = other:GetTokens(),
			zone = NETWORK.zone and NETWORK.zone.AtEntity and
				(function()
					local zone = NETWORK.zone.AtEntity(other)

					return zone and (zone.name != "" and zone.name or zone.id) or ""
				end)() or ""
		}

		if (role) then
			counts[role.id] = (counts[role.id] or 0) + 1
		end
	end

	table.sort(staff, function(a, b)
		return a.name < b.name
	end)

	local roles = {}

	for _, role in ipairs(AC.cwuRoles) do
		roles[#roles + 1] = {id = role.id, label = L(role.label), online = counts[role.id] or 0}
	end

	local B = NETWORK.budget
	local entity = client.nwAdminComp

	return {
		staff = staff,
		roles = roles,
		fines = AC.cwu.fines,
		notes = AC.cwu.notes,
		callLog = AC.cwuCallLog or {},
		nextCall = AC.cwuNextCall,
		salary = B and B.state.salaries.worker or 0,
		maxSalary = B and B.maxSalary or 0,
		nextPay = B and B.GetNextPay and B.GetNextPay() or 0,
		bHead = AC.IsCWUHead(client, entity),
		owner = IsValid(entity) and entity.GetOwnerName and entity:GetOwnerName() or "",
		me = client:GetCharacterName()
	}
end

ACTIONS.cwu_state = function(client)
	AC.Reply(client, "cwu", AC.BuildCWU(client))
end

ACTIONS.cwu_call = function(client, payload)
	local roleID = tostring(payload.role or "")
	local role

	for _, entry in ipairs(AC.cwuRoles) do
		if (entry.id == roleID) then
			role = entry
		end
	end

	if (!role) then
		return
	end

	if (AC.cwuNextCall > CurTime()) then
		Notice(client, "acCallCooldown", "warn")

		return ACTIONS.cwu_state(client)
	end

	local reason = NETWORK.util.Sanitise(tostring(payload.reason or ""), 120)

	if (reason == "") then
		reason = L("acCallDefault")
	end

	local entity = client.nwAdminComp
	local zone = IsValid(entity) and NETWORK.zone and NETWORK.zone.At(entity:GetPos())
	local place = zone and zone.name or L("acCallPlaceDefault")
	local label = L(role.label)
	local count = 0

	for _, other in ipairs(player.GetAll()) do
		if (other:HasCharacter() and (RoleOf(other) == role or other:IsAdmin())) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString(L("cwuCallAlert", label, client:GetCharacterName(), place, reason))
			net.Send(other)

			other:EmitSound("buttons/blip1.wav", 60, 100)

			if (NETWORK.waypoint and NETWORK.waypoint.Add and IsValid(entity)) then
				NETWORK.waypoint.Add(other, entity:GetPos() + Vector(0, 0, 32), L("cwuCallWaypoint"),
					Color(214, 190, 96), 600, true)
			end

			count = count + 1
		end
	end

	AC.cwuNextCall = CurTime() + AC.cwuCallCooldown
	AC.cwuCallLog = AC.cwuCallLog or {}
	AC.cwuCallLog[#AC.cwuCallLog + 1] = {
		time = os.date("%H:%M"),
		faction = label,
		who = client:GetCharacterName(),
		reason = reason
	}

	while (#AC.cwuCallLog > 20) do
		table.remove(AC.cwuCallLog, 1)
	end

	if (IsValid(entity)) then
		entity:EmitSound("ambient/machines/keyboard7_clicks_enter.wav", 60, 100)
	end

	Notice(client, "cwuCallSent", "good", label, count)
	ACTIONS.cwu_state(client)
end

ACTIONS.cwu_call_one = function(client, payload)
	local target

	for _, other in ipairs(player.GetAll()) do
		if (other:HasCharacter() and other:GetCharacterName() == tostring(payload.name or "")) then
			target = other

			break
		end
	end

	if (!IsValid(target)) then
		return Notice(client, "cwuFineNoTarget", "warn")
	end

	local entity = client.nwAdminComp

	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(L("cwuCallOne", client:GetCharacterName()))
	net.Send(target)

	target:EmitSound("buttons/blip1.wav", 60, 100)

	if (NETWORK.waypoint and NETWORK.waypoint.Add and IsValid(entity)) then
		NETWORK.waypoint.Add(target, entity:GetPos() + Vector(0, 0, 32), L("cwuCallWaypoint"),
			Color(214, 190, 96), 600, true)
	end

	Notice(client, "cwuCallOneSent", "good", target:GetCharacterName())
end

local function FindByName(name)
	name = NETWORK.util.Lower(string.Trim(name or ""))

	if (name == "") then
		return
	end

	for _, other in ipairs(player.GetAll()) do
		if (other:HasCharacter() and NETWORK.util.Lower(other:GetCharacterName()) == name) then
			return other
		end
	end

	for _, other in ipairs(player.GetAll()) do
		if (other:HasCharacter() and string.find(NETWORK.util.Lower(other:GetCharacterName()),
			name, 1, true)) then
			return other
		end
	end
end

ACTIONS.cwu_fine = function(client, payload)
	local target = FindByName(tostring(payload.name or ""))
	local amount = math.Clamp(math.floor(tonumber(payload.amount) or 0), 1, AC.cwuFineMax)
	local reason = NETWORK.util.Sanitise(tostring(payload.reason or ""), 80)

	if (!IsValid(target)) then
		return Notice(client, "cwuFineNoTarget", "warn")
	end

	if (!NETWORK.factions.IsCWU(target) and !RoleOf(target)) then
		return Notice(client, "cwuFineNotStaff", "warn")
	end

	if (reason == "") then
		reason = L("cwuFineDefault")
	end

	local taken = math.min(amount, target:GetTokens())

	NETWORK.currency.Add(target, -taken)

	local B = NETWORK.budget

	if (B and B.state) then
		B.state.balance = (B.state.balance or 0) + taken

		if (B.Log) then
			B.Log(L("cwuFineBudget", target:GetCharacterName(), taken))
		end

		if (B.Save) then
			B.Save()
		end
	end

	table.insert(AC.cwu.fines, 1, {
		id = AC.cwu.nextID,
		who = target:GetCharacterName(),
		amount = taken,
		reason = reason,
		by = client:GetCharacterName(),
		time = os.date("%d.%m %H:%M")
	})

	AC.cwu.nextID = AC.cwu.nextID + 1

	while (#AC.cwu.fines > 40) do
		table.remove(AC.cwu.fines)
	end

	AC.SaveCWU()

	Notice(target, "cwuFined", "bad", taken, reason)
	Notice(client, "cwuFineDone", "good", target:GetCharacterName(), taken)
	ACTIONS.cwu_state(client)
end

ACTIONS.cwu_note_add = function(client, payload)
	local text = NETWORK.util.Sanitise(tostring(payload.text or ""), 300, true)

	if (text == "") then
		return
	end

	table.insert(AC.cwu.notes, 1, {
		id = AC.cwu.nextID,
		text = text,
		by = client:GetCharacterName(),
		time = os.date("%d.%m %H:%M")
	})

	AC.cwu.nextID = AC.cwu.nextID + 1

	while (#AC.cwu.notes > 30) do
		table.remove(AC.cwu.notes)
	end

	AC.SaveCWU()
	Notice(client, "cwuNoteAdded", "good")
	ACTIONS.cwu_state(client)
end

local function FindNote(id)
	for index, note in ipairs(AC.cwu.notes) do
		if (note.id == id) then
			return note, index
		end
	end
end

ACTIONS.cwu_note_remove = function(client, payload)
	local note, index = FindNote(tonumber(payload.id) or 0)

	if (!note) then
		return
	end

	if (note.by != client:GetCharacterName() and !client:IsAdmin()) then
		return Notice(client, "cwuNoteNotYours", "warn")
	end

	table.remove(AC.cwu.notes, index)
	AC.SaveCWU()
	Notice(client, "cwuNoteTaken", "good")
	ACTIONS.cwu_state(client)
end

ACTIONS.cwu_note_mail = function(client, payload)
	local note = FindNote(tonumber(payload.id) or 0)
	local to = NETWORK.util.Sanitise(tostring(payload.to or ""), 64)

	if (!note or to == "") then
		return Notice(client, "cwuNoteMailWho", "warn")
	end

	if (note.by != client:GetCharacterName() and !client:IsAdmin()) then
		return Notice(client, "cwuNoteNotYours", "warn")
	end

	local bOk = NETWORK.mail and NETWORK.mail.SendTo and
		NETWORK.mail.SendTo(client:GetCharacterName(), to, L("cwuNoteSubject"), note.text)

	Notice(client, bOk and "mailBoxSent" or "mailNoBox", bOk and "good" or "warn", to)
end

ACTIONS.cwu_salary = function(client, payload)
	if (!NETWORK.budget or !NETWORK.budget.SetSalary) then
		return
	end

	NETWORK.budget.SetSalary(client, "worker", tonumber(payload.amount) or 0)
	Notice(client, "budgetSaved", "good")
	ACTIONS.cwu_state(client)
end

NETWORK.command.Register("cwucompreset", {
	adminOnly = true,
	description = "cmdCwuCompReset",
	usage = "/cwucompreset [имя]",
	OnRun = function(command, client, arguments)
		local entity = client:GetEyeTrace().Entity

		if (!IsValid(entity) or entity:GetClass() != "nw_cwu_computer" or
			client:GetPos():Distance(entity:GetPos()) > 200) then
			return Notice(client, "cwuCompResetLook", "warn")
		end

		local name = string.Trim(table.concat(arguments, " "))

		entity:SetOwnerName(string.sub(name, 1, 64))
		NETWORK.entities.Save()
		Notice(client, name == "" and "cwuCompResetFree" or "cwuCompResetTo", "good", name)
	end
})

NETWORK.command.Register("camname", {
	adminOnly = true,
	description = "cmdCamName",
	usage = "/camname <название>",
	OnRun = function(command, client, arguments)
		local entity = client:GetEyeTrace().Entity
		local name = NETWORK.util.Sanitise(table.concat(arguments, " "), 32)

		if (!IsValid(entity) or entity:GetClass() != "nw_housing_camera" or name == "") then
			return Notice(client, "camNameUsage", "warn")
		end

		entity:SetCamName(name)

		Notice(client, "camNameSet", "good", name)
	end
})
