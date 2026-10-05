util.AddNetworkString("nwBusinessDecide")

NETWORK.business = NETWORK.business or {}
NETWORK.business.stored = NETWORK.business.stored or {}

local dataPath = "network/business.txt"

function NETWORK.business.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(NETWORK.business.stored, true))
end

function NETWORK.business.Load()
	NETWORK.business.stored =
		util.JSONToTable(file.Read(dataPath, "DATA") or "") or {}
end

hook.Add("InitPostEntity", "nwBusiness", NETWORK.business.Load)

function NETWORK.business.Get(character)
	return NETWORK.business.stored[tostring(character:GetID())]
end

function NETWORK.business.Apply(client, character, what, why)
	NETWORK.business.stored[tostring(character:GetID())] = {
		name = character:GetName(),
		cid = NETWORK.terminal.GetCitizenID(character),
		what = string.sub(what, 1, 120),
		why = string.sub(why, 1, 400),
		status = "pending",
		location = "",
		time = os.time()
	}

	NETWORK.business.Save()
end

function NETWORK.business.Mark(client, entry)
	if (!IsValid(client) or !istable(entry) or entry.status != "approved" or
		!NETWORK.waypoint or !NETWORK.waypoint.Add) then
		return
	end

	local position

	if (istable(entry.position)) then
		position = Vector(entry.position[1], entry.position[2], entry.position[3])
	else

		local best, bestDistance

		for _, terminal in ipairs(ents.FindByClass("nw_business_terminal")) do
			local distance = terminal:GetPos():DistToSqr(client:GetPos())

			if (!bestDistance or distance < bestDistance) then
				best, bestDistance = terminal, distance
			end
		end

		if (!IsValid(best)) then
			return
		end

		position = best:GetPos()
	end

	for index = #NETWORK.waypoint.list, 1, -1 do
		local point = NETWORK.waypoint.list[index]

		if (point.owner == client:SteamID64() and point.kind == "business") then
			table.remove(NETWORK.waypoint.list, index)
		end
	end

	NETWORK.waypoint.Add(client, position + Vector(0, 0, 32),
		L("businessWaypoint", entry.what or ""), Color(196, 160, 246), 3600, true, "business")

	NETWORK.notice.Send(client, "businessWaypointSet", "good")
end

NETWORK.command.Register("bizwhere", {
	description = "cmdBizwhere",
	usage = "/bizwhere",
	OnRun = function(command, client)
		local character = client:GetCharacter()
		local entry = character and NETWORK.business.Get(character)

		if (!entry or entry.status != "approved") then
			return Notice(client, "shopNoBusiness")
		end

		NETWORK.business.Mark(client, entry)
	end
})

function NETWORK.business.SetPosition(id, position)
	local entry = NETWORK.business.stored[id]

	if (!entry) then
		return false
	end

	entry.position = {position.x, position.y, position.z}

	NETWORK.business.Save()

	return true
end

local function Notify(id, entry)
	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (character and tostring(character:GetID()) == id) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("businessDecided")
			net.Send(client)

			entry.notified = true

			NETWORK.business.Save()
			NETWORK.business.Mark(client, entry)

			return
		end
	end
end

function NETWORK.business.Decide(id, location, bApproved, officer)
	local entry = NETWORK.business.stored[id]

	if (!entry) then
		return false
	end

	entry.status = bApproved and "approved" or "denied"
	entry.location = string.sub(location or "", 1, 120)
	entry.officer = officer
	entry.notified = false

	NETWORK.business.Save()
	Notify(id, entry)

	return true
end

function NETWORK.business.Reset(id)
	local entry = NETWORK.business.stored[id]

	if (!entry or entry.status == "pending") then
		return false
	end

	entry.status = "pending"
	entry.location = ""
	entry.officer = nil
	entry.notified = false

	NETWORK.business.Save()

	return true
end

hook.Add("NetworkPlayerLoadout", "nwBusiness", function(client, character)
	local id = tostring(character:GetID())
	local entry = NETWORK.business.stored[id]

	if (entry and entry.status != "pending" and !entry.notified) then
		timer.Simple(4, function()
			if (IsValid(client) and client:GetCharacter() == character) then
				Notify(id, entry)
			end
		end)
	elseif (entry and entry.status == "approved") then
		timer.Simple(8, function()
			if (IsValid(client) and client:GetCharacter() == character) then
				NETWORK.business.Mark(client, entry)
			end
		end)
	end
end)

NETWORK.command.Register("bizmark", {
	description = "cmdBizmark",
	usage = "/bizmark <имя>",
	OnRun = function(command, client, arguments)
		local class = client:GetNWString("nwClass", "")

		if (class != "cmd" and !NETWORK.classes.IsAdministrativeID(class) and !client:IsAdmin()) then
			return Notice(client, "bizMarkDenied")
		end

		local name = NETWORK.util.Lower(string.Trim(table.concat(arguments, " ")))

		if (name == "") then
			return Notice(client, "bizMarkUsage")
		end

		for id, entry in pairs(NETWORK.business.stored) do
			if (NETWORK.util.Lower(entry.name or "") == name or
				string.find(NETWORK.util.Lower(entry.name or ""), name, 1, true)) then
				NETWORK.business.SetPosition(id, client:GetPos())

				for _, other in ipairs(player.GetAll()) do
					local character = other:GetCharacter()

					if (character and tostring(character:GetID()) == id) then
						NETWORK.business.Mark(other, entry)
					end
				end

				return Notice(client, "bizMarkSet")
			end
		end

		Notice(client, "bizMarkNoBusiness")
	end
})

util.AddNetworkString("nwBusinessReset")

net.Receive("nwBusinessReset", function(_, client)
	local id = net.ReadString()

	if (!IsValid(client.nwCmbTerminal)) then
		return
	end

	if (client:GetNWString("nwClass", "") != "cmd" and !client:IsAdmin()) then
		return
	end

	if (NETWORK.business.Reset(id)) then
		NETWORK.chat.Notice(client, "bizReset")

		NETWORK.cmbterm.Sync(client, "business")
	end
end)

net.Receive("nwBusinessDecide", function(_, client)
	local id = net.ReadString()
	local location = net.ReadString()
	local bApproved = net.ReadBool()

	if (!IsValid(client.nwCmbTerminal)) then
		return
	end

	if (client:GetNWString("nwClass", "") != "cmd" and !client:IsAdmin()) then
		return
	end

	if (NETWORK.business.Decide(id, location, bApproved,
		client:GetCharacterName())) then

		NETWORK.cmbterm.Sync(client, "business")
	end
end)

local function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

NETWORK.command.Register("bizapply", {
	description = "cmdBizapply",
	usage = "/bizapply <что за бизнес> | <почему>",
	OnRun = function(command, client, arguments)
		local raw = table.concat(arguments, " ")
		local what, why = string.match(raw, "^(.-)%s*|%s*(.+)$")

		if (!what or what == "" or !why or why == "") then
			return Notice(client, "bizapplyUsage")
		end

		local character = client:GetCharacter()
		local entry = NETWORK.business.Get(character)

		if (entry and entry.status == "pending") then
			return Notice(client, "businessPending")
		end

		if (NETWORK.factions.IsAlliance(client)) then
			return Notice(client, "businessAlliance")
		end

		NETWORK.business.Apply(client, character, what, why)
		Notice(client, "businessSent")
	end
})

function NETWORK.business.Revoke(client, reasonKey)
	local character = client:GetCharacter()

	if (!character) then
		return false
	end

	local id = tostring(character:GetID())

	if (!NETWORK.business.stored[id]) then
		return false
	end

	NETWORK.business.stored[id] = nil
	NETWORK.business.Save()
	NETWORK.notice.Send(client, reasonKey or "businessRevoked", "warn")

	return true
end

hook.Add("PlayerDeath", "nwBusinessDeath", function(client)
	if (NETWORK.config.Get("businessLostOnDeath") == true) then
		NETWORK.business.Revoke(client, "businessLostDeath")
	end
end)

hook.Add("NetworkFactionTransferred", "nwBusinessFaction", function(client, character, faction)
	if (faction and (faction.bCombine or faction.id == "cp" or faction.id == "cmb")) then
		NETWORK.business.Revoke(client, "businessLostFaction")
	end
end)

hook.Add("NetworkClassAssigned", "nwBusinessRebel", function(client, class)
	if (class and class.id == "rebel") then
		NETWORK.business.Revoke(client, "businessLostRebel")
	end
end)

function NETWORK.business.ClearFixtures(charID)
	charID = tostring(charID)

	local removed = 0

	for _, entity in ipairs(ents.FindByClass("nw_shop_fixture")) do
		if (entity:GetOwnerChar() == charID) then
			entity:Remove()

			removed = removed + 1
		end
	end

	for _, entity in ipairs(ents.FindByClass("nw_shopitem")) do
		if (entity:GetNWString("nwOwnerChar", "") == charID) then
			entity:Remove()

			removed = removed + 1
		end
	end

	return removed
end

local baseRevoke = NETWORK.business.Revoke

function NETWORK.business.Revoke(client, reasonKey)
	local character = client:GetCharacter()

	if (character) then
		NETWORK.business.ClearFixtures(character:GetID())
	end

	return baseRevoke(client, reasonKey)
end

local baseDecide = NETWORK.business.Decide

function NETWORK.business.Decide(id, location, bApproved, officer)
	local bOk = baseDecide(id, location, bApproved, officer)

	if (bOk and !bApproved) then
		NETWORK.business.ClearFixtures(id)
	end

	return bOk
end

local baseReset = NETWORK.business.Reset

function NETWORK.business.Reset(id)
	local bOk = baseReset(id)

	if (bOk) then
		NETWORK.business.ClearFixtures(id)
	end

	return bOk
end
