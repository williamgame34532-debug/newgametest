util.AddNetworkString("nwWaypointSync")
util.AddNetworkString("nwWaypointQuick")
util.AddNetworkString("nwWaypointRemove")

NETWORK.waypoint.list = NETWORK.waypoint.list or {}

local function Notice(client, key, ...)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

function NETWORK.waypoint.GetViewers()
	local list = {}

	for _, client in ipairs(player.GetAll()) do
		if (NETWORK.waypoint.CanSee(client)) then
			list[#list + 1] = client
		end
	end

	return list
end

local function BuildPayload(viewer)
	local payload = {}

	local squad = IsValid(viewer) and viewer.GetSquad and viewer:GetSquad()

	for _, entry in ipairs(NETWORK.waypoint.list) do
		if (entry.owner and (!IsValid(viewer) or
			viewer:SteamID64() != entry.owner)) then
			continue
		end

		if (entry.bGlobal) then
			if (!IsValid(viewer) or !NETWORK.factions.IsAlliance(viewer)) then
				continue
			end
		elseif (entry.squad) then
			if (entry.squad != squad) then
				continue
			end
		elseif (!IsValid(viewer) or entry.ownerID != viewer:SteamID64()) then
			continue
		end

		payload[#payload + 1] = {
			pos = {entry.pos.x, entry.pos.y, entry.pos.z},
			text = entry.text,
			color = {entry.color.r, entry.color.g, entry.color.b},
			expires = entry.expires,
			author = entry.author,
			kind = entry.kind or "point",
			mine = IsValid(viewer) and entry.ownerID == viewer:SteamID64()
		}
	end

	return payload
end

function NETWORK.waypoint.Sync(target)
	if (IsValid(target)) then
		net.Start("nwWaypointSync")
			NETWORK.util.WriteTable(BuildPayload(target))
		net.Send(target)

		return
	end

	for _, viewer in ipairs(NETWORK.waypoint.GetViewers()) do
		net.Start("nwWaypointSync")
			NETWORK.util.WriteTable(BuildPayload(viewer))
		net.Send(viewer)
	end
end

function NETWORK.waypoint.Add(client, position, text, color, length, bPersonal,
	kind, bGlobal)

	if (#NETWORK.waypoint.list >= NETWORK.waypoint.max) then
		return false, "waypointFull"
	end

	NETWORK.waypoint.list[#NETWORK.waypoint.list + 1] = {
		pos = position,
		text = text,
		color = color,
		expires = CurTime() + length,
		author = IsValid(client) and client:GetCharacterName() or "",

		ownerID = IsValid(client) and client:SteamID64() or "",
		owner = (bPersonal and IsValid(client)) and client:SteamID64() or nil,

		squad = (!bPersonal and IsValid(client) and client.GetSquad) and
			client:GetSquad() or nil,

		kind = kind or "point",
		bGlobal = bGlobal == true
	}

	NETWORK.waypoint.Sync()

	return true
end

function NETWORK.waypoint.FindNearest(position, maxDistance)
	local best, bestDistance

	for index, entry in ipairs(NETWORK.waypoint.list) do
		local distance = entry.pos:DistToSqr(position)

		if (!bestDistance or distance < bestDistance) then
			best, bestDistance = index, distance
		end
	end

	if (!best or bestDistance > (maxDistance or 200) ^ 2) then
		return
	end

	return best
end

timer.Create("nwWaypointExpire", 1, 0, function()
	local bChanged = false

	for index = #NETWORK.waypoint.list, 1, -1 do
		if (NETWORK.waypoint.list[index].expires < CurTime()) then
			table.remove(NETWORK.waypoint.list, index)

			bChanged = true
		end
	end

	if (bChanged) then
		NETWORK.waypoint.Sync()
	end
end)

hook.Add("NetworkCharacterLoaded", "nwWaypoint", function(client)
	timer.Simple(1, function()
		if (IsValid(client) and NETWORK.waypoint.CanSee(client)) then
			NETWORK.waypoint.Sync(client)
		end
	end)
end)

NETWORK.waypoint.calls = NETWORK.waypoint.calls or {}

NETWORK.waypoint.callTime = 900

hook.Add("NetworkTerminalCall", "nwWaypointCall", function(client, entity, reason)
	if (!IsValid(entity)) then
		return
	end

	NETWORK.waypoint.RemoveCall(entity)

	local position = entity:GetPos() + Vector(0, 0, 40)
	local label = NETWORK.util.Sanitise(reason or "", 48)

	if (label == "") then
		label = L("termCall")
	end

	local bOk = NETWORK.waypoint.Add(nil, position, label,
		Color(232, 74, 66), NETWORK.waypoint.callTime)

	if (!bOk) then
		for index, entry in ipairs(NETWORK.waypoint.list) do
			if (!entry.bCall) then
				table.remove(NETWORK.waypoint.list, index)

				break
			end
		end

		bOk = NETWORK.waypoint.Add(nil, position, label,
			Color(232, 74, 66), NETWORK.waypoint.callTime)
	end

	if (bOk) then

		NETWORK.waypoint.list[#NETWORK.waypoint.list].bCall = true

		NETWORK.waypoint.calls[entity:EntIndex()] = position
	end
end)

function NETWORK.waypoint.RemoveCall(entity)
	if (!IsValid(entity)) then
		return
	end

	local position = NETWORK.waypoint.calls[entity:EntIndex()]

	if (!position) then
		return
	end

	NETWORK.waypoint.calls[entity:EntIndex()] = nil

	for index = #NETWORK.waypoint.list, 1, -1 do
		if (NETWORK.waypoint.list[index].pos == position) then
			table.remove(NETWORK.waypoint.list, index)

			NETWORK.waypoint.Sync()

			return
		end
	end
end

timer.Create("nwWaypointCallWatch", 2, 0, function()
	for entIndex, _ in pairs(NETWORK.waypoint.calls) do
		local entity = Entity(entIndex)

		if (!IsValid(entity) or !entity.GetAlarm or !entity:GetAlarm()) then
			if (IsValid(entity)) then
				NETWORK.waypoint.RemoveCall(entity)
			else
				NETWORK.waypoint.calls[entIndex] = nil
			end
		end
	end
end)

NETWORK.command.Register("waypoint", {
	description = "cmdWaypoint",
	usage = "/waypoint <подпись> [секунды] [цвет]",
	example = "/waypoint Сбор 120 red",
	OnRun = function(command, client, arguments)
		if (!NETWORK.waypoint.CanPlace(client)) then
			return Notice(client, "waypointNoAccess")
		end

		local parts = {}

		for _, value in ipairs(arguments) do
			parts[#parts + 1] = value
		end

		local color, length

		if (#parts > 1) then
			local candidate = NETWORK.waypoint.GetColor(parts[#parts])

			if (candidate) then
				color = candidate

				table.remove(parts)
			end
		end

		if (#parts > 1 and tonumber(parts[#parts])) then
			length = tonumber(table.remove(parts))
		end

		local text = NETWORK.util.Sanitise(table.concat(parts, " "), 48)

		if (text == "") then
			return Notice(client, "waypointNoText")
		end

		length = math.Clamp(math.Round(length or NETWORK.waypoint.defaultTime),
			10, NETWORK.waypoint.maxTime)

		if (!color) then
			local faction = NETWORK.factions.Get(client:GetCharacterFaction())

			color = faction and faction.color or NETWORK.waypoint.colors.white
		end

		local trace = client:GetEyeTraceNoCursor()

		if (client:GetPos():Distance(trace.HitPos) > NETWORK.waypoint.range) then
			return Notice(client, "waypointTooFar")
		end

		local bOk, reason = NETWORK.waypoint.Add(client,
			trace.HitPos + Vector(0, 0, 24), text, color, length)

		Notice(client, bOk and "waypointAdded" or reason)
	end
})

NETWORK.command.Register("waypointremove", {
	description = "cmdWaypointremove",
	usage = "/waypointremove",
	OnRun = function(command, client)
		if (!NETWORK.waypoint.CanPlace(client)) then
			return Notice(client, "waypointNoAccess")
		end

		local trace = client:GetEyeTraceNoCursor()
		local index = NETWORK.waypoint.FindNearest(trace.HitPos, 220)

		if (!index) then
			return Notice(client, "waypointNoneNear")
		end

		table.remove(NETWORK.waypoint.list, index)
		NETWORK.waypoint.Sync()
		Notice(client, "waypointRemoved")
	end
})

NETWORK.command.Register("waypointclear", {
	description = "cmdWaypointclear",
	usage = "/waypointclear",
	OnRun = function(command, client)

		if (!NETWORK.factions.CanControlCombine(client)) then
			return Notice(client, "waypointNoAccess")
		end

		NETWORK.waypoint.list = {}

		NETWORK.waypoint.Sync()
		Notice(client, "waypointCleared")
	end
})

net.Receive("nwWaypointQuick", function(_, client)
	if (!NETWORK.waypoint.CanQuickPlace(client)) then
		return Notice(client, "waypointNoAccess")
	end

	if ((client.nwNextWaypoint or 0) > CurTime()) then
		return
	end

	client.nwNextWaypoint = CurTime() + 1.5

	local trace = client:GetEyeTraceNoCursor()

	if (client:GetPos():Distance(trace.HitPos) > NETWORK.waypoint.range) then
		return Notice(client, "waypointTooFar")
	end

	local text = L("waypointQuick")
	local squad = client.GetSquad and client:GetSquad()
	local data = squad and NETWORK.squad and NETWORK.squad.Get(squad)

	if (!squad or !data) then
		return Notice(client, "waypointNoAccess")
	end

	if (data and data.name and data.name != "") then
		text = data.name
	end

	local kindID = client:GetSquad() and "squad" or "alert"
	local kind = NETWORK.waypoint.GetKind(kindID)
	local color = kind.color

	local targets, bPersonal = NETWORK.squad.GetTargets(client)
	local bOk, reason

	if (bPersonal and IsValid(targets[1])) then
		bOk, reason = NETWORK.waypoint.Add(targets[1],
			trace.HitPos + Vector(0, 0, 24), text, color, kind.time, true,
			kindID)

		client.nwSquadSelected = nil

		net.Start("nwSquadSelect")
			net.WriteEntity(NULL)
		net.Send(client)
	else
		bOk, reason = NETWORK.waypoint.Add(client,
			trace.HitPos + Vector(0, 0, 24), text, color, kind.time, false,
			kindID)
	end

	if (!bOk) then
		return Notice(client, reason)
	end

	client:EmitSound("buttons/button17.wav", 55, 130, 0.4)
end)

net.Receive("nwWaypointRemove", function(_, client)
	local position = net.ReadVector()

	for index = #NETWORK.waypoint.list, 1, -1 do
		local entry = NETWORK.waypoint.list[index]

		if (entry.pos:Distance(position) > 8) then
			continue
		end

		if (entry.ownerID != client:SteamID64() and !client:IsAdmin()) then
			return Notice(client, "waypointNotYours")
		end

		table.remove(NETWORK.waypoint.list, index)

		NETWORK.waypoint.Sync()

		return
	end
end)

timer.Create("nwWaypointReached", 0.5, 0, function()
	if (#NETWORK.waypoint.list == 0) then
		return
	end

	for index = #NETWORK.waypoint.list, 1, -1 do
		local entry = NETWORK.waypoint.list[index]
		local kind = NETWORK.waypoint.GetKind(entry.kind)

		if (kind.radius <= 0) then
			continue
		end

		for _, client in ipairs(player.GetAll()) do
			if (!client:Alive() or !client:HasCharacter()) then
				continue
			end

			if (entry.ownerID == client:SteamID64()) then
				continue
			end

			if (entry.squad and client:GetSquad() != entry.squad) then
				continue
			end

			if (client:GetPos():Distance(entry.pos) > kind.radius) then
				continue
			end

			table.remove(NETWORK.waypoint.list, index)

			NETWORK.waypoint.Sync()

			client:EmitSound("buttons/button17.wav", 50, 120, 0.5)

			break
		end
	end
end)
