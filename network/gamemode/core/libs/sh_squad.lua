NETWORK.squad = NETWORK.squad or {}

NETWORK.squad.list = NETWORK.squad.list or {}

NETWORK.squad.nameMax = 18
NETWORK.squad.sizeMin = 2
NETWORK.squad.sizeMax = 8
NETWORK.squad.color = Color(126, 210, 245)

local PLAYER = FindMetaTable("Player")

function PLAYER:GetSquad()
	local id = self:GetNWString("nwSquad", "")

	return id != "" and id or nil
end

function PLAYER:GetSquadData()
	local id = self:GetSquad()

	return id and NETWORK.squad.list[id]
end

function PLAYER:IsSquadLeader()
	local squad = self:GetSquadData()

	return squad != nil and squad.leader == self:SteamID64()
end

function PLAYER:GetSquadName()
	local id = self:GetSquad()

	if (!id) then
		return
	end

	local squad = NETWORK.squad.list[id]

	return squad and squad.name or string.upper(id)
end

NETWORK.squad.kinds = {alliance = true, cwu = true}

function NETWORK.squad.GetKind(client)
	if (NETWORK.factions.IsCWU(client)) then
		return "cwu"
	end

	return "alliance"
end

function NETWORK.squad.GetSquadKind(squad)
	return squad and squad.kind or "alliance"
end

function NETWORK.squad.CanSee(client, squad)
	return NETWORK.squad.GetSquadKind(squad) == NETWORK.squad.GetKind(client)
end

function NETWORK.squad.Get(id)
	return NETWORK.squad.list[id]
end

function NETWORK.squad.GetMembers(id)
	local list = {}

	for _, client in ipairs(player.GetAll()) do
		if (client:HasCharacter() and client:GetSquad() == id) then
			list[#list + 1] = client
		end
	end

	local squad = NETWORK.squad.list[id]

	table.sort(list, function(a, b)
		if (squad) then
			local aLead = a:SteamID64() == squad.leader
			local bLead = b:SteamID64() == squad.leader

			if (aLead != bLead) then
				return aLead
			end
		end

		return a:GetCharacterName() < b:GetCharacterName()
	end)

	return list
end

function NETWORK.squad.GetLeader(id)
	local squad = NETWORK.squad.list[id]

	if (!squad) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		if (client:SteamID64() == squad.leader) then
			return client
		end
	end
end

function NETWORK.squad.IsFull(id)
	local squad = NETWORK.squad.list[id]

	return squad != nil and #NETWORK.squad.GetMembers(id) >= squad.size
end

if (SERVER) then
	util.AddNetworkString("nwSquadSync")

	function NETWORK.squad.Sync(target)
		net.Start("nwSquadSync")
			NETWORK.util.WriteTable(NETWORK.squad.list)

		if (IsValid(target)) then
			net.Send(target)
		else
			net.Broadcast()
		end
	end

	hook.Add("PlayerInitialSpawn", "nwSquadSync", function(client)
		timer.Simple(2, function()
			if (IsValid(client)) then
				NETWORK.squad.Sync(client)
			end
		end)
	end)

	function NETWORK.squad.Set(client, id)
		if (id and !NETWORK.squad.list[id]) then
			return false
		end

		client:SetNWString("nwSquad", id or "")

		NETWORK.squad.Sync()

		return true
	end

	function NETWORK.squad.Create(client, name, size)
		name = NETWORK.util.Sanitise(name, NETWORK.squad.nameMax)

		if (name == "") then
			return false, "squadNoName"
		end

		if (client:GetSquad()) then
			return false, "squadAlready"
		end

		local id = string.lower(string.gsub(name, "%s+", "_"))

		if (NETWORK.squad.list[id]) then
			return false, "squadExists"
		end

		NETWORK.squad.list[id] = {
			id = id,
			name = name,
			kind = NETWORK.squad.GetKind(client),
			size = math.Clamp(math.Round(tonumber(size) or 4),
				NETWORK.squad.sizeMin, NETWORK.squad.sizeMax),
			leader = client:SteamID64(),
			created = os.time()
		}

		NETWORK.squad.Set(client, id)

		for _, member in ipairs(NETWORK.squad.GetMembers(id)) do
			member:EmitSound("framework/cmb/hud/squadadd.mp3", 60, 100, 0.6)
		end

		return true, "squadCreated"
	end

	function NETWORK.squad.Disband(id)
		if (!NETWORK.squad.list[id]) then
			return
		end

		for _, member in ipairs(NETWORK.squad.GetMembers(id)) do
			member:SetNWString("nwSquad", "")
		end

		NETWORK.squad.list[id] = nil

		NETWORK.squad.Sync()
	end

	function NETWORK.squad.Join(client, id)
		local squad = NETWORK.squad.list[id]

		if (!squad) then
			return false, "squadGone"
		end

		if (client:GetSquad()) then
			return false, "squadAlready"
		end

		if (!NETWORK.squad.CanSee(client, squad)) then
			return false, "squadWrongKind"
		end

		if (NETWORK.squad.IsFull(id)) then
			return false, "squadFull"
		end

		NETWORK.squad.Set(client, id)

		local leader = NETWORK.squad.GetLeader(id)

		if (IsValid(leader) and leader != client) then
			net.Start("nwDispatchLine")
				net.WriteString(NETWORK.util.Sanitise(
					L("squadJoinedLeader", client:GetCharacterName()), 90))
				net.WriteColor(Color(232, 74, 66), false)
				net.WriteString("")
			net.Send(leader)
		end

		return true, "squadJoined"
	end

	function NETWORK.squad.Leave(client)
		local id = client:GetSquad()

		if (!id) then
			return
		end

		local members = NETWORK.squad.GetMembers(id)

		if (#members <= 1) then
			return NETWORK.squad.Disband(id)
		end

		if (client:IsSquadLeader()) then
			for _, member in ipairs(members) do
				if (member != client) then
					NETWORK.squad.list[id].leader = member:SteamID64()

					break
				end
			end
		end

		NETWORK.squad.Set(client, nil)
	end

	function NETWORK.squad.SetLeader(id, target)
		local squad = NETWORK.squad.list[id]

		if (!squad or target:GetSquad() != id) then
			return false
		end

		squad.leader = target:SteamID64()

		NETWORK.squad.Sync()

		return true
	end

	NETWORK.squad.disbandOn = "leader"

	local function Tell(client, key, ...)
		if (!IsValid(client)) then
			return
		end

		local text = select("#", ...) > 0 and L(key, ...) or key

		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(text)
		net.Send(client)
	end

	function NETWORK.squad.Release(client, reason)
		if (!IsValid(client)) then
			return
		end

		local id = client:GetNWString("nwSquad", "")
		local squad = id != "" and NETWORK.squad.list[id]

		if (!squad) then
			client:SetNWString("nwSquad", "")

			return
		end

		local name = client:GetCharacterName()

		if (squad.leader == client:SteamID64() or NETWORK.squad.disbandOn == "any") then
			for _, member in ipairs(NETWORK.squad.GetMembers(id)) do
				if (member != client) then
					Tell(member, reason, name)
				end
			end

			NETWORK.squad.Disband(id)

			client:SetNWString("nwSquad", "")

			return
		end

		client:SetNWString("nwSquad", "")

		for _, member in ipairs(NETWORK.squad.GetMembers(id)) do
			Tell(member, "squadMemberLost", name)
		end

		NETWORK.squad.Sync()
	end

	hook.Add("PlayerDeath", "nwSquad", function(client)
		NETWORK.squad.Release(client, "squadDisbandedDeath")
	end)

	hook.Add("NetworkFactionTransferred", "nwSquad", function(client)
		NETWORK.squad.Release(client, "squadDisbandedFaction")
	end)

	hook.Add("NetworkCharacterUnloaded", "nwSquad", function(client)
		NETWORK.squad.Release(client, "squadDisbandedFaction")
	end)

	hook.Add("PlayerDisconnected", "nwSquad", function(client)
		NETWORK.squad.Release(client, "squadDisbandedLeft")

		timer.Simple(0, function()
			for id in pairs(NETWORK.squad.list) do
				if (#NETWORK.squad.GetMembers(id) == 0) then
					NETWORK.squad.Disband(id)
				end
			end
		end)
	end)

	hook.Add("NetworkCharacterLoaded", "nwSquad", function(client)

		client:SetNWString("nwSquad", "")

		timer.Simple(1, function()
			if (IsValid(client)) then
				NETWORK.squad.Sync()
			end
		end)
	end)

	NETWORK.command.Register("squadinvite", {
		description = "cmdSquadInvite",
		usage = "/squadinvite <игрок>",
		aliases = {"sqinvite"},
		OnRun = function(command, client, arguments)
			local function Notice(key)
				net.Start("nwChatMessage")
					net.WriteString("notice")
					net.WriteEntity(NULL)
					net.WriteString("")
					net.WriteString(key)
				net.Send(client)
			end

			if (!NETWORK.factions.IsAlliance(client)) then
				return Notice("squadNoAccess")
			end

			local id = client:GetSquad()

			if (!id) then
				return Notice("squadNone")
			end

			if (!client:IsSquadLeader()) then
				return Notice("squadNotLeader")
			end

			local target = NETWORK.permission.Find(arguments[1])

			if (!IsValid(target) or !target:HasCharacter()) then
				return Notice("permNoTarget")
			end

			if (!NETWORK.factions.IsAlliance(target)) then
				return Notice("squadNotAlliance")
			end

			local bOk, key = NETWORK.squad.Join(target, id)

			if (!bOk) then
				return Notice(key)
			end

			Notice("squadInvited")

			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("squadJoined")
			net.Send(target)
		end
	})

	NETWORK.command.Register("squadleave", {
		description = "cmdSquadLeave",
		usage = "/squadleave",
		OnRun = function(command, client)
			NETWORK.squad.Leave(client)
		end
	})
else
	net.Receive("nwSquadSync", function()
		NETWORK.squad.list = NETWORK.util.ReadTable() or {}
	end)
end
