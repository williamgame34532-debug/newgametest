-- Squads, server (sh_squads.lua): the rules, the sync, the chat commands.

util.AddNetworkString("nwSquads")
util.AddNetworkString("nwSquadAction")

local SQ = NW.squads
local nextID = 1

local function Notify(client, text)
	NW.Notify(client, text)
end

local function Alliance(client)
	return IsValid(client) and client:GetCharacterID() != 0 and NW.zones.IsAlliance(client)
end

-- everyone gets every squad (a few ids and names)
function SQ.Sync(target)
	local out = {}

	for id, squad in pairs(SQ.list) do
		local members = {}

		for _, member in ipairs(SQ.Members(squad)) do
			members[#members + 1] = member:EntIndex()
		end

		out[#out + 1] = {id = id, name = squad.name, side = squad.side, leader = IsValid(squad.leader) and
			squad.leader:EntIndex() or 0, members = members, succession = squad.succession, created = squad.created}
	end

	net.Start("nwSquads")
		net.WriteString(util.TableToJSON(out))
	if (target) then
		net.Send(target)
	else
		net.Broadcast()
	end
end

-- a sound for the members of a squad
local function Sound(squad, name, extra)
	local targets = SQ.Members(squad)

	if (IsValid(extra)) then
		targets[#targets + 1] = extra
	end

	for _, member in ipairs(targets) do
		member:SendLua("surface.PlaySound(\"" .. SQ.sounds[name] .. "\")")
	end
end

local function Tell(squad, text)
	for _, member in ipairs(SQ.Members(squad)) do
		Notify(member, text)
	end
end

function SQ.Create(client, name)
	name = string.Trim(name or "")

	if (!Alliance(client)) then
		return false, "Отряды — только для Альянса"
	elseif (SQ.Of(client)) then
		return false, "Вы уже в отряде"
	end

	if (name == "") then
		name = (SQ.Side(client) == "ota" and "Ударная группа " or "Патруль ") .. nextID
	end

	if ((utf8.len(name) or #name) > 24) then
		name = string.sub(name, 1, (utf8.offset(name, 25) or (#name + 1)) - 1)
	end

	local side = SQ.Side(client)

	if (SQ.Count(side) >= SQ.max:GetInt()) then
		return false, "Отрядов уже " .. SQ.max:GetInt() .. " — больше нельзя"
	end

	for _, squad in pairs(SQ.list) do
		if (squad.side == side and string.lower(squad.name) == string.lower(name)) then
			return false, "Отряд с таким названием уже есть"
		end
	end

	local id = nextID

	nextID = nextID + 1
	SQ.list[id] = {id = id, name = name, side = side, leader = client, members = {client}, succession = false,
		created = os.time()}
	client:SetNW2Int("nwSquad", id)

	Sound(SQ.list[id], "create")
	SQ.Sync()
	hook.Run("NWSquadChanged", SQ.list[id])

	return true
end

function SQ.Disband(squad, why, extra)
	if (!squad or !SQ.list[squad.id]) then
		return
	end

	Sound(squad, "disband", extra)

	if (IsValid(extra)) then
		Notify(extra, "Отряд «" .. squad.name .. "» расформирован")
	end

	Tell(squad, "Отряд «" .. squad.name .. "» расформирован" .. (why and (": " .. why) or ""))

	for _, member in ipairs(SQ.Members(squad)) do
		member:SetNW2Int("nwSquad", 0)
	end

	SQ.list[squad.id] = nil
	SQ.Sync()
	hook.Run("NWSquadChanged", squad)
end

function SQ.Join(client, squad)
	if (!Alliance(client)) then
		return false, "Отряды — только для Альянса"
	elseif (!squad or !SQ.list[squad.id]) then
		return false, "Нет такого отряда"
	elseif (SQ.Of(client)) then
		return false, "Сначала выйдите из своего отряда"
	elseif (squad.side != SQ.Side(client)) then
		return false, "Это отряд другой стороны"
	elseif (#SQ.Members(squad) >= SQ.size:GetInt()) then
		return false, "В отряде нет мест"
	end

	squad.members[#squad.members + 1] = client
	client:SetNW2Int("nwSquad", squad.id)

	Sound(squad, "join")
	Tell(squad, client:Nick() .. " — в отряде «" .. squad.name .. "»")
	SQ.Sync()
	hook.Run("NWSquadChanged", squad)

	return true
end

-- leaving (also death and disconnect of the leader): the end, or the next one leads
function SQ.Leave(client, why)
	local squad = SQ.Of(client)

	if (!squad) then
		return false, "Вы не в отряде"
	end

	local wasLeader = squad.leader == client

	for index = #squad.members, 1, -1 do
		if (squad.members[index] == client or !IsValid(squad.members[index])) then
			table.remove(squad.members, index)
		end
	end

	client:SetNW2Int("nwSquad", 0)

	if (wasLeader) then
		local heir = SQ.Members(squad)[1]

		if (!squad.succession or !IsValid(heir)) then
			SQ.Disband(squad, why or "лидер покинул отряд", client)

			return true
		end

		squad.leader = heir
		Tell(squad, "Лидер отряда теперь " .. heir:Nick())
	end

	if (#SQ.Members(squad) == 0) then
		SQ.list[squad.id] = nil
	else
		Sound(squad, "leave", client)
		Tell(squad, client:Nick() .. " покинул отряд")
	end

	SQ.Sync()
	hook.Run("NWSquadChanged", squad)

	return true
end

function SQ.Kick(leader, target)
	local squad = SQ.Of(leader)

	if (!squad or squad.leader != leader) then
		return false, "Только лидер отряда"
	elseif (!IsValid(target) or SQ.Of(target) != squad or target == leader) then
		return false, "Этот юнит не в вашем отряде"
	end

	Notify(target, "Вас исключили из отряда «" .. squad.name .. "»")

	return SQ.Leave(target)
end

function SQ.SetSuccession(leader, bOn)
	local squad = SQ.Of(leader)

	if (!squad or squad.leader != leader) then
		return false, "Только лидер отряда"
	end

	squad.succession = bOn == true
	Tell(squad, bOn and "Преемственность включена: если лидер уйдёт, отряд поведёт следующий" or
		"Преемственность выключена: с уходом лидера отряд расформируется")
	SQ.Sync()

	return true
end

-- the leader dies or goes: the end or the next (a member who dies stays in the squad); a member who
-- is no longer of the Alliance leaves
hook.Add("PlayerDeath", "nwSquads", function(client)
	if (SQ.IsLeader(client)) then
		SQ.Leave(client, "лидер погиб")
	end
end)

hook.Add("PlayerDisconnected", "nwSquads", function(client)
	if (SQ.Of(client)) then
		SQ.Leave(client, SQ.IsLeader(client) and "лидер вышел" or nil)
	end
end)

hook.Add("NWFactionChanged", "nwSquads", function(client)
	local squad = SQ.Of(client)

	if (squad and (!NW.zones.IsAlliance(client) or squad.side != SQ.Side(client))) then
		SQ.Leave(client)
	end
end)

hook.Add("PlayerSilentDeath", "nwSquads", function(client)
	if (SQ.Of(client)) then
		SQ.Leave(client)
	end
end)

hook.Add("NWCharacterLoaded", "nwSquads", function(client)
	SQ.Sync(client)
end)

-- -------------------------------------------------------------- requests --
local function Find(client, query)
	query = string.lower(string.Trim(query or ""))

	local id = tonumber(query)

	if (id and SQ.list[id]) then
		return SQ.list[id]
	end

	for _, squad in pairs(SQ.list) do
		if (squad.side == SQ.Side(client) and string.find(string.lower(squad.name), query, 1, true)) then
			return squad
		end
	end
end

-- one place for the terminal and the chat: returns ok, the message
function SQ.Request(client, action, arg)
	if (action == "create") then
		return SQ.Create(client, arg)
	elseif (action == "join") then
		return SQ.Join(client, Find(client, arg))
	elseif (action == "leave") then
		return SQ.Leave(client)
	elseif (action == "disband") then
		local squad = tonumber(arg) and SQ.list[tonumber(arg)] or SQ.Of(client)

		if (!squad) then
			return false, "Нет такого отряда"
		end

		if (squad.leader != client and !client:IsAdmin()) then
			return false, "Расформировать может только лидер"
		end

		SQ.Disband(squad, "приказ " .. client:Nick())

		return true
	elseif (action == "kick") then
		return SQ.Kick(client, NW.FindPlayer(arg))
	elseif (action == "succession") then
		local squad = SQ.Of(client)

		return SQ.SetSuccession(client, !(squad and squad.succession))
	end

	return false, "Неизвестное действие"
end

net.Receive("nwSquadAction", function(_, client)
	local action = net.ReadString()
	local arg = net.ReadString()

	if ((client.nwSquadNext or 0) > CurTime()) then
		return
	end

	client.nwSquadNext = CurTime() + 0.5

	local ok, why = SQ.Request(client, action, arg)

	if (!ok and why) then
		Notify(client, why)
	end
end)

local function Command(action)
	return {run = function(client, rest)
		local ok, why = SQ.Request(client, action, rest)

		if (!ok and why) then
			Notify(client, why)
		end
	end}
end

NW.AddChatCommand("squadcreate", Command("create"))
NW.AddChatCommand("squadjoin", Command("join"))
NW.AddChatCommand("squadleave", Command("leave"))
NW.AddChatCommand("squaddisband", Command("disband"))
NW.AddChatCommand("squadkick", Command("kick"))
NW.AddChatCommand("squadsuccession", Command("succession"))
