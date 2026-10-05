local SERVICES = {}

local function Notice(client, key, tone, ...)
	if (key) then
		NETWORK.notice.Send(client, key, tone, ...)
	end
end

local function Json(text)
	local data = util.JSONToTable(text or "")

	return istable(data) and data or {}
end

SERVICES.idcards = {
	access = function(client, kind)
		return kind == "alliance" and NETWORK.factions.IsAlliance(client)
	end
}

SERVICES.documents = {
	access = function(client, kind)
		if (kind == "alliance") then
			return NETWORK.factions.IsAlliance(client)
		end

		return kind == "cwu" and (NETWORK.factions.IsCWU(client) or
			NETWORK.factions.IsAlliance(client))
	end
}

SERVICES.supply = {
	access = function(client, kind)
		if (kind == "alliance") then
			return NETWORK.factions.IsAlliance(client)
		end

		return kind == "cwu" and NETWORK.factions.IsCWU(client)
	end
}

SERVICES.channels = {
	access = function(client, kind)
		return kind != nil
	end
}

local function PlayerByIndex(text)
	local target = Entity(tonumber(text) or 0)

	if (IsValid(target) and target:IsPlayer() and target:HasCharacter()) then
		return target
	end
end

hook.Add("NetworkCmbPayload", "nwCmbServices", function(client, page, argument, payload)
	local service = SERVICES[page]
	local kind = NETWORK.cmbterm.GetKind(client)

	if (!service or !service.access(client, kind)) then
		return
	end

	if (page == "idcards") then
		payload.list = {}

		for _, target in ipairs(player.GetAll()) do
			local character = target:GetCharacter()

			if (!character) then
				continue
			end

			local faction = NETWORK.factions.Get(character:GetFaction())

			payload.list[#payload.list + 1] = {
				index = target:EntIndex(),
				name = character:GetName(),
				cid = NETWORK.terminal.GetCitizenID(character),
				default = NETWORK.cid.Default(character:GetID()),
				faction = faction and L(faction.name) or "",
				bAlliance = NETWORK.factions.IsAlliance(target)
			}
		end

		table.sort(payload.list, function(a, b)
			if (a.bAlliance != b.bAlliance) then
				return !a.bAlliance
			end

			return a.name < b.name
		end)

		local selected = PlayerByIndex(argument)

		if (selected) then
			payload.selected = selected:EntIndex()
			payload.cards = NETWORK.cid.GetCards(selected:GetCharacter():GetID())

			for _, card in ipairs(payload.cards) do
				card.issued = os.date("%d.%m.%Y", card.issued or 0)
			end
		end

		payload.check = client.nwIdCheck
	elseif (page == "documents") then
		payload.types = {}

		for _, data in ipairs(NETWORK.documents.GetTypesFor(kind)) do
			payload.types[#payload.types + 1] = {id = data.id, name = data.name,
				hours = data.hours}
		end

		payload.recent = NETWORK.documents.GetRecent(kind == "cwu" and "cwu" or nil, 8)

		for _, entry in ipairs(payload.recent) do
			entry.issued = os.date("%d.%m %H:%M", entry.issued or 0)
		end

		payload.check = client.nwDocCheck
		payload.bCanRevoke = kind == "alliance"
	elseif (page == "supply") then
		table.Merge(payload, NETWORK.supply.BuildPayload(client, kind))
	elseif (page == "channels") then
		table.Merge(payload, NETWORK.channels.BuildPayload(client,
			kind == "cwu" and "cwu" or "cmb", argument != "" and argument or client.nwChannel))
	end
end)

local ACTIONS = {}

ACTIONS.id_issue = {"idcards", function(client, argument)
	local fields = Json(argument)
	local target = PlayerByIndex(fields.target)

	if (!target) then
		return "idNoTarget", "bad"
	end

	local bOk, key, extra = NETWORK.cid.Issue(client, target, {
		name = fields.name,
		cid = fields.cid,
		bRegistry = fields.bRegistry == true,
		bRevoke = fields.bRevoke == true
	})

	return key, bOk and "good" or "bad", extra
end}

ACTIONS.id_reset = {"idcards", function(client, argument)
	local target = PlayerByIndex(argument)

	if (!target) then
		return "idNoTarget", "bad"
	end

	NETWORK.cid.Set(target:GetCharacter():GetID(), nil)

	return "idResetDone", "good"
end}

ACTIONS.id_check = {"idcards", function(client, argument)
	local card, serial = NETWORK.cid.Check(argument)

	client.nwIdCheck = card and {
		serial = serial,
		name = card.name,
		cid = card.cid,
		by = card.by,
		issued = os.date("%d.%m.%Y", card.issued or 0),
		valid = card.valid
	} or {serial = serial, missing = true}
end}

ACTIONS.doc_issue = {"documents", function(client, argument, _, kind)
	local bOk, key, extra = NETWORK.documents.Issue(client, kind, Json(argument))

	return key, bOk and "good" or "bad", extra
end}

ACTIONS.doc_revoke = {"documents", function(client, argument, _, kind)
	if (kind != "alliance") then
		return
	end

	local bOk, key, extra = NETWORK.documents.Revoke(client, string.upper(argument))

	return key, bOk and "good" or "bad", extra
end}

ACTIONS.doc_check = {"documents", function(client, argument)
	local status, entry, serial = NETWORK.documents.Verify(argument)
	local docType = entry and NETWORK.documents.GetType(entry.type)

	client.nwDocCheck = {
		serial = serial,
		status = status,
		holder = entry and entry.holder or "",
		cid = entry and entry.cid or "",
		issuer = entry and entry.issuer or "",
		type = entry and (entry.type == "idcard" and "idCardTitle" or
			(docType and docType.name or "")) or ""
	}
end}

ACTIONS.supply_order = {"supply", function(client, argument, _, kind)
	if (kind != "alliance") then
		return
	end

	local bOk, key, extra = NETWORK.supply.Order(client, argument)

	return key, bOk and "good" or "bad", extra
end}

ACTIONS.supply_cancel = {"supply", function(client, argument, _, kind)
	if (kind != "alliance") then
		return
	end

	local bOk, key = NETWORK.supply.Cancel(client, tonumber(argument) or 0)

	return key, bOk and "good" or "bad"
end}

ACTIONS.supply_take = {"supply", function(client, argument, _, kind)
	if (kind != "cwu") then
		return
	end

	local bOk, key = NETWORK.supply.Take(client, tonumber(argument) or 0)

	return key, bOk and "good" or "bad"
end}

ACTIONS.supply_drop = {"supply", function(client, argument, _, kind)
	if (kind != "cwu") then
		return
	end

	local bOk, key = NETWORK.supply.Drop(client, tonumber(argument) or 0)

	return key, bOk and "good" or "bad"
end}

ACTIONS.supply_route = {"supply", function(client, argument, _, kind)
	local order = NETWORK.supply.Get(tonumber(argument) or 0)

	if (kind != "cwu" or !order or order.worker != client or order.status != "assigned") then
		return
	end

	if (NETWORK.supply.ShowRoute(client, order)) then
		return "supplyRouteShown", "good"
	end

	return "supplyCrateGone", "bad"
end}

ACTIONS.chan_post = {"channels", function(client, argument, extra, kind)
	local bOk, key = NETWORK.channels.Post(client, kind == "cwu" and "cwu" or "cmb",
		extra, argument)

	return key, bOk and "good" or "bad"
end}

ACTIONS.chan_delete = {"channels", function(client, argument, extra)
	if (client:IsAdmin()) then
		NETWORK.channels.Delete(extra, tonumber(argument) or 0)
	end
end}

hook.Add("NetworkCmbAction", "nwCmbServices", function(client, action, argument, extra, entity)
	local kind = NETWORK.cmbterm.GetKind(client)
	local service = SERVICES[action]

	if (service) then
		if (service.access(client, kind)) then
			if (action == "channels" and argument != "") then
				client.nwChannel = argument
			end

			NETWORK.cmbterm.OpenPage(client, action, argument)
		end

		return true
	end

	local handler = ACTIONS[action]

	if (!handler) then
		return
	end

	local page = handler[1]

	if (!SERVICES[page].access(client, kind)) then
		return true
	end

	local key, tone, value = handler[2](client, argument, extra, kind)

	Notice(client, key, tone or "info", value)

	NETWORK.cmbterm.OpenPage(client, page,
		page == "channels" and (client.nwChannel or "") or (client.nwCmbArgument or ""))

	return true
end)
