util.AddNetworkString("nwGroupSync")
util.AddNetworkString("nwGroupAction")
util.AddNetworkString("nwGroupInvite")
util.AddNetworkString("nwGroupChat")
util.AddNetworkString("nwGroupChatSend")

local dataPath = "network/groups.txt"

local function Notice(client, key, ...)
	if (!IsValid(client)) then
		return
	end

	NETWORK.chat.Notice(client, select("#", ...) > 0 and L(key, ...) or key)
end

function NETWORK.group.Save()

	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(NETWORK.group.list, true))
end

function NETWORK.group.Load()
	local raw = file.Read(dataPath, "DATA")

	NETWORK.group.list = raw and util.JSONToTable(raw) or {}
end

hook.Add("Initialize", "nwGroup", function()
	NETWORK.group.Load()
end)

function NETWORK.group.Sync(client)
	if (!IsValid(client)) then
		return
	end

	local group, id = NETWORK.group.GetOf(client)

	net.Start("nwGroupSync")

	if (!group) then
		net.WriteBool(false)
		net.Send(client)

		return
	end

	net.WriteBool(true)
	NETWORK.util.WriteTable({
		id = id,
		name = group.name,
		icon = group.icon,
		leader = group.leader,
		size = group.size,
		members = group.members,
		chat = group.chat,
		color = group.color,
		bGradient = group.bGradient,
		layout = group.layout,
		messages = group.messages
	})
	net.Send(client)
end

function NETWORK.group.SyncAll(group)
	for _, client in ipairs(player.GetAll()) do
		if (client:HasCharacter()) then
			local own = NETWORK.group.GetOf(client)

			if (own == group) then
				NETWORK.group.Sync(client)
			end
		end
	end
end

function NETWORK.group.Create(client, name, icon)
	if (NETWORK.group.GetOf(client)) then
		return false, "groupAlready"
	end

	if (!NETWORK.group.CanCreate(client)) then
		return false, "groupNoAccess"
	end

	name = NETWORK.util.Sanitise(name, NETWORK.group.nameMax)

	if (name == "") then
		return false, "groupNoName"
	end

	if (!NETWORK.group.IsIcon(icon)) then
		icon = NETWORK.group.icons[1]
	end

	local key = tostring(client:GetCharacterID())

	local id = string.format("%d_%s", os.time(), key)

	NETWORK.group.list[id] = {
		name = name,
		icon = icon,
		leader = key,
		size = NETWORK.group.defaultSize,
		members = {[key] = {name = client:GetCharacterName(), role = ""}}
	}

	NETWORK.group.Save()
	NETWORK.group.Sync(client)

	return true, "groupCreated"
end

function NETWORK.group.Disband(client)
	local group, id = NETWORK.group.GetOf(client)

	if (!group or !NETWORK.group.IsLeader(client)) then
		return false, "groupNotLeader"
	end

	for _, entity in ipairs(ents.GetAll()) do
		if (entity.nwGroup == id) then
			entity.nwGroup = nil
		end
	end

	NETWORK.group.list[id] = nil

	NETWORK.group.Save()
	NETWORK.group.SyncAll(group)

	for _, target in ipairs(player.GetAll()) do
		NETWORK.group.Sync(target)
	end

	return true, "groupDisbanded"
end

function NETWORK.group.Invite(client, target)
	local group, id = NETWORK.group.GetOf(client)

	if (!group or !NETWORK.group.IsLeader(client)) then
		return false, "groupNotLeader"
	end

	if (!IsValid(target) or !target:HasCharacter()) then
		return false, "groupNoTarget"
	end

	if (NETWORK.group.GetOf(target)) then
		return false, "groupTargetBusy"
	end

	if (NETWORK.group.Count(group) >= group.size) then
		return false, "groupFull"
	end

	target.nwGroupInvite = {id = id, expires = CurTime() +
		NETWORK.group.inviteTime, from = client:GetCharacterName()}

	net.Start("nwGroupInvite")
		net.WriteString(group.name)
		net.WriteString(client:GetCharacterName())
	net.Send(target)

	return true, "groupInvited"
end

function NETWORK.group.Accept(client)
	local invite = client.nwGroupInvite

	client.nwGroupInvite = nil

	if (!invite or invite.expires < CurTime()) then
		return false, "groupInviteGone"
	end

	local group = NETWORK.group.Get(invite.id)

	if (!group) then
		return false, "groupInviteGone"
	end

	if (NETWORK.group.GetOf(client)) then
		return false, "groupAlready"
	end

	if (NETWORK.group.Count(group) >= group.size) then
		return false, "groupFull"
	end

	group.members[tostring(client:GetCharacterID())] = {
		name = client:GetCharacterName(),
		role = ""
	}

	NETWORK.group.Save()
	NETWORK.group.SyncAll(group)

	return true, "groupJoined"
end

function NETWORK.group.Kick(client, key)
	local group = NETWORK.group.GetOf(client)

	if (!group or !NETWORK.group.IsLeader(client)) then
		return false, "groupNotLeader"
	end

	if (key == group.leader or !group.members[key]) then
		return false, "groupNoMember"
	end

	group.members[key] = nil

	NETWORK.group.Save()
	NETWORK.group.SyncAll(group)

	for _, target in ipairs(player.GetAll()) do
		if (target:HasCharacter() and
			tostring(target:GetCharacterID()) == key) then
			NETWORK.group.Sync(target)
			Notice(target, "groupKicked")

			break
		end
	end

	return true, "groupKickedDone"
end

function NETWORK.group.SetRole(client, key, role)
	local group = NETWORK.group.GetOf(client)

	if (!group or !NETWORK.group.IsLeader(client)) then
		return false, "groupNotLeader"
	end

	if (!group.members[key]) then
		return false, "groupNoMember"
	end

	group.members[key].role = NETWORK.util.Sanitise(role, NETWORK.group.roleMax)

	NETWORK.group.Save()
	NETWORK.group.SyncAll(group)

	return true, "groupRoleSet"
end

function NETWORK.group.Transfer(client, key)
	local group = NETWORK.group.GetOf(client)

	if (!group or !NETWORK.group.IsLeader(client)) then
		return false, "groupNotLeader"
	end

	if (!group.members[key] or key == group.leader) then
		return false, "groupNoMember"
	end

	group.leader = key

	group.members[key].role = ""

	NETWORK.group.Save()
	NETWORK.group.SyncAll(group)

	for _, target in ipairs(player.GetAll()) do
		if (target:HasCharacter() and
			tostring(target:GetCharacterID()) == key) then
			Notice(target, "groupNowLeader")

			break
		end
	end

	return true, "groupTransferred"
end

function NETWORK.group.SetStyle(client, payload)
	local group = NETWORK.group.GetOf(client)

	if (!group or !NETWORK.group.IsLeader(client)) then
		return false, "groupNotLeader"
	end

	local function Allowed(list, value)
		for _, entry in ipairs(list) do
			if ((istable(entry) and entry.id or entry) == value) then
				return true
			end
		end

		return false
	end

	if (Allowed(NETWORK.group.palette, payload.color)) then
		group.color = payload.color
	end

	if (Allowed(NETWORK.group.layouts, payload.layout)) then
		group.layout = payload.layout
	end

	if (Allowed(NETWORK.group.messageStyles, payload.messages)) then
		group.messages = payload.messages
	end

	if (payload.bGradient != nil) then
		group.bGradient = payload.bGradient == true
	end

	NETWORK.group.Save()
	NETWORK.group.SyncAll(group)

	return true, "groupStyleSaved"
end

function NETWORK.group.SetSize(client, size)
	local group = NETWORK.group.GetOf(client)

	if (!group or !NETWORK.group.IsLeader(client)) then
		return false, "groupNotLeader"
	end

	size = math.Clamp(math.Round(tonumber(size) or 0), 1, NETWORK.group.maxSize)

	if (size < NETWORK.group.Count(group)) then
		return false, "groupSizeBelow"
	end

	group.size = size

	NETWORK.group.Save()
	NETWORK.group.SyncAll(group)

	return true, "groupSizeSet"
end

function NETWORK.group.ShareContainer(client, entity)
	local group, id = NETWORK.group.GetOf(client)

	if (!group or !NETWORK.group.IsLeader(client)) then
		return false, "groupNotLeader"
	end

	if (!IsValid(entity)) then
		return false, "groupNoContainer"
	end

	local class = entity:GetClass()

	if (class != "nw_container" and class != "nw_stash") then
		return false, "groupNoContainer"
	end

	if (client:GetPos():Distance(entity:GetPos()) > 160) then
		return false, "groupNoContainer"
	end

	if (entity.nwGroup == id) then
		entity.nwGroup = nil

		entity:SetNWString("nwGroupName", "")

		if (NETWORK.entities and NETWORK.entities.Save) then
			NETWORK.entities.Save()
		end

		return true, "groupUnshared"
	end

	entity.nwGroup = id

	entity:SetNWString("nwGroupName", group.name or "")

	if (NETWORK.entities and NETWORK.entities.Save) then
		NETWORK.entities.Save()
	end

	return true, "groupShared"
end

hook.Add("NetworkStashKey", "nwGroup", function(client, entity)
	if (!IsValid(entity) or !entity.nwGroup) then
		return
	end

	local group, id = NETWORK.group.GetOf(client)

	if (group and id == entity.nwGroup) then
		return "group_" .. id
	end
end)

net.Receive("nwGroupAction", function(_, client)
	local action = net.ReadString()
	local payload = NETWORK.util.ReadTable() or {}

	if (!client:HasCharacter() or (client.nwNextGroup or 0) > CurTime()) then
		return
	end

	client.nwNextGroup = CurTime() + 0.4

	local bOk, message

	if (action == "create") then
		bOk, message = NETWORK.group.Create(client, payload.name, payload.icon)
	elseif (action == "disband") then
		bOk, message = NETWORK.group.Disband(client)
	elseif (action == "invite") then
		bOk, message = NETWORK.group.Invite(client,
			NETWORK.permission.Find(payload.name or ""))
	elseif (action == "accept") then
		bOk, message = NETWORK.group.Accept(client)
	elseif (action == "kick") then
		bOk, message = NETWORK.group.Kick(client, payload.key)
	elseif (action == "style") then
		bOk, message = NETWORK.group.SetStyle(client, payload)
	elseif (action == "transfer") then
		bOk, message = NETWORK.group.Transfer(client, payload.key)
	elseif (action == "role") then
		bOk, message = NETWORK.group.SetRole(client, payload.key, payload.role)
	elseif (action == "size") then
		bOk, message = NETWORK.group.SetSize(client, payload.size)
	elseif (action == "share") then
		bOk, message = NETWORK.group.ShareContainer(client,
			client:GetEyeTrace().Entity)
	end

	if (message) then
		Notice(client, message)
	end
end)

hook.Add("NetworkCharacterLoaded", "nwGroup", function(client)
	timer.Simple(1, function()
		if (IsValid(client)) then
			NETWORK.group.Sync(client)
		end
	end)
end)

function NETWORK.group.SendChat(client, text)
	local group, id = NETWORK.group.GetOf(client)

	if (!group) then
		return false, "groupNone"
	end

	text = NETWORK.util.Sanitise(text, NETWORK.group.chatLength)

	if (text == "") then
		return false
	end

	if ((client.nwNextGroupChat or 0) > CurTime()) then
		return false, "groupChatSlow"
	end

	client.nwNextGroupChat = CurTime() + 1

	local entry = {
		name = client:GetCharacterName(),
		text = text,
		time = os.date("%H:%M")
	}

	group.chat = group.chat or {}
	group.chat[#group.chat + 1] = entry

	while (#group.chat > NETWORK.group.chatMax) do
		table.remove(group.chat, 1)
	end

	NETWORK.group.Save()

	for _, target in ipairs(player.GetAll()) do
		if (!target:HasCharacter()) then
			continue
		end

		local _, targetID = NETWORK.group.GetOf(target)

		if (targetID != id and !target:IsAdmin()) then
			continue
		end

		net.Start("nwGroupChat")
			net.WriteString(targetID == id and entry.name or
				("[" .. (group.name or "?") .. "] " .. entry.name))
			net.WriteString(entry.text)
			net.WriteString(entry.time)
			net.WriteBool(target == client)
		net.Send(target)
	end

	return true
end

net.Receive("nwGroupChatSend", function(_, client)
	local text = net.ReadString()
	local bOk, message = NETWORK.group.SendChat(client, text)

	if (!bOk and message) then
		Notice(client, message)
	end
end)
