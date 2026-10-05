util.AddNetworkString("nwJailOpen")
util.AddNetworkString("nwJailClose")
util.AddNetworkString("nwJailData")
util.AddNetworkString("nwJailAction")

local dataPath = "network/jail.txt"

local function Notice(client, key, ...)
	local text = select("#", ...) > 0 and L(key, ...) or key

	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(text)
	net.Send(client)
end

NETWORK.jail.points = NETWORK.jail.points or {}
NETWORK.jail.release = NETWORK.jail.release

local function Pack(position, angles)
	return {
		x = position.x,
		y = position.y,
		z = position.z,
		yaw = angles and angles.y or 0
	}
end

local function Unpack(entry)
	if (!istable(entry)) then
		return
	end

	return Vector(entry.x or 0, entry.y or 0, entry.z or 0),
		Angle(0, entry.yaw or 0, 0)
end

function NETWORK.jail.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON({
		points = NETWORK.jail.points,
		release = NETWORK.jail.release
	}, true))
end

function NETWORK.jail.Load()
	local contents = file.Read(dataPath, "DATA")
	local data = contents and util.JSONToTable(contents)

	if (!istable(data)) then
		return
	end

	NETWORK.jail.points = istable(data.points) and data.points or {}
	NETWORK.jail.release = istable(data.release) and data.release or nil
end

function NETWORK.jail.AddPoint(client)
	NETWORK.jail.points[#NETWORK.jail.points + 1] = Pack(client:GetPos(),
		client:EyeAngles())

	NETWORK.jail.Save()

	return #NETWORK.jail.points
end

function NETWORK.jail.RemovePoint(index)
	if (!NETWORK.jail.points[index]) then
		return false
	end

	table.remove(NETWORK.jail.points, index)

	NETWORK.jail.Save()

	return true
end

function NETWORK.jail.SetRelease(client)
	NETWORK.jail.release = Pack(client:GetPos(), client:EyeAngles())

	NETWORK.jail.Save()
end

function NETWORK.jail.GetCell()
	local count = #NETWORK.jail.points

	if (count == 0) then
		return
	end

	NETWORK.jail.next = ((NETWORK.jail.next or 0) % count) + 1

	return Unpack(NETWORK.jail.points[NETWORK.jail.next])
end

function NETWORK.jail.GetRelease()
	if (NETWORK.jail.release) then
		return Unpack(NETWORK.jail.release)
	end

	local spawns = ents.FindByClass("info_player_start")

	if (spawns[1]) then
		return spawns[1]:GetPos(), spawns[1]:GetAngles()
	end
end

function NETWORK.jail.IsInside(client)
	if (#NETWORK.jail.points == 0) then
		return true
	end

	local position = client:GetPos()

	for _, entry in ipairs(NETWORK.jail.points) do
		local point = Unpack(entry)

		if (point and position:Distance(point) <= NETWORK.jail.holdRange) then
			return true
		end
	end

	return false
end

local function GetRecord(client)
	local character = client:GetCharacter()

	if (!character) then
		return
	end

	local record = NETWORK.detain.Get(character:GetID())

	if (!record or !record.jail) then
		return
	end

	return record
end

function NETWORK.jail.Put(client)
	local position, angles = NETWORK.jail.GetCell()

	if (!position) then
		return false
	end

	client.nwJailed = true

	client:SetPos(position)
	client:SetEyeAngles(angles or Angle(0, 0, 0))
	client:SetVelocity(-client:GetVelocity())
	client:EmitSound("buttons/combine_button7.wav", 65, 90)

	return true
end

function NETWORK.jail.Free(client, bQuiet)
	client.nwJailed = nil

	local position, angles = NETWORK.jail.GetRelease()

	if (position) then
		client:SetPos(position)
		client:SetEyeAngles(angles or Angle(0, 0, 0))
		client:SetVelocity(-client:GetVelocity())
	end

	if (!bQuiet) then
		Notice(client, "jailFreed")
	end

	hook.Run("NetworkJailReleased", client)
end

function NETWORK.jail.Sentence(client, target, term, reason)
	if (!NETWORK.jail.CanJail(target)) then
		return false, "jailNoTarget"
	end

	if (#NETWORK.jail.points == 0) then
		return false, "jailNoPoints"
	end

	term = math.Clamp(math.Round(tonumber(term) or NETWORK.jail.termDefault), 1,
		NETWORK.jail.termMax)
	reason = NETWORK.util.Sanitise(reason or "", NETWORK.jail.reasonMax)

	if (reason == "") then
		return false, "jailNoReason"
	end

	local bOk, key = NETWORK.detain.Add(client, target,
		math.max(math.Round(term * NETWORK.jail.timeScale), 1), reason)

	if (!bOk) then
		return false, key
	end

	local record = NETWORK.detain.Get(target:GetCharacter():GetID())

	if (record) then

		record.jail = true

		NETWORK.cmbterm.Save()
	end

	if (NETWORK.restraint and NETWORK.restraint.IsTied(target)) then
		NETWORK.restraint.Set(target, false)
	end

	NETWORK.jail.Put(target)

	Notice(target, "jailSentenced", reason, term)

	hook.Run("NetworkJailSentenced", client, target, term, reason)

	return true, "jailDone"
end

function NETWORK.jail.ReleaseTarget(client, target)
	local character = IsValid(target) and target:GetCharacter()

	if (!character) then
		return false, "permNoTarget"
	end

	if (!NETWORK.detain.Release(character:GetID())) then
		return false, "detainNoRecord"
	end

	if (target.nwJailed) then
		NETWORK.jail.Free(target)
	end

	return true, "detainReleased"
end

function NETWORK.jail.Open(client, entity)
	if (IsValid(client.nwJailTerminal)) then
		NETWORK.jail.Close(client)
	end

	client.nwJailTerminal = entity

	entity:SetUser(client)
	entity:EmitSound(NETWORK.cmbterm.sounds.open, 70)

	net.Start("nwJailOpen")
		net.WriteEntity(entity)
		net.WriteFloat(math.Rand(NETWORK.cmbterm.bootMin, NETWORK.cmbterm.bootMax))
	net.Send(client)

	if (#NETWORK.jail.points == 0) then
		Notice(client, "jailNoPoints")
	end

	NETWORK.jail.SendData(client)
end

function NETWORK.jail.Close(client)
	local entity = client.nwJailTerminal

	client.nwJailTerminal = nil

	if (IsValid(entity) and entity:GetUser() == client) then
		entity:SetUser(NULL)
	end

	net.Start("nwJailClose")
	net.Send(client)
end

function NETWORK.jail.SendData(client)
	local entity = client.nwJailTerminal

	if (!IsValid(entity)) then
		return
	end

	local list = {}

	for _, target in ipairs(player.GetAll()) do
		if (target == client or !NETWORK.jail.CanJail(target)) then
			continue
		end

		if (target:GetPos():Distance(entity:GetPos()) > NETWORK.jail.scanRange) then
			continue
		end

		local character = target:GetCharacter()
		local record = NETWORK.detain.Get(character:GetID())

		list[#list + 1] = {
			index = target:EntIndex(),
			name = character:GetName(),
			cid = NETWORK.terminal.GetCitizenID(character),
			faction = character:GetFactionName(),
			model = character:GetModel(),
			distance = math.Round(target:GetPos():Distance(client:GetPos())),
			reason = record and record.reason,
			remaining = record and NETWORK.detain.GetRemaining(record)
		}
	end

	table.sort(list, function(a, b)
		return a.distance < b.distance
	end)

	net.Start("nwJailData")
		NETWORK.util.WriteTable({list = list, points = #NETWORK.jail.points})
	net.Send(client)
end

net.Receive("nwJailAction", function(_, client)
	local action = net.ReadString()
	local index = net.ReadUInt(16)
	local term = net.ReadUInt(16)
	local reason = net.ReadString()
	local entity = client.nwJailTerminal

	if (action == "close") then
		return NETWORK.jail.Close(client)
	end

	if (!NETWORK.jail.CanUse(client, entity)) then
		return
	end

	if ((client.nwNextJail or 0) > CurTime()) then
		return
	end

	client.nwNextJail = CurTime() + 0.4

	local target = Entity(index)

	if (!IsValid(target) or !target:IsPlayer()) then
		return Notice(client, "jailNoTarget")
	end

	if (target:GetPos():Distance(entity:GetPos()) > NETWORK.jail.scanRange) then
		return Notice(client, "jailTooFar")
	end

	if (action == "jail") then
		local bOk, key = NETWORK.jail.Sentence(client, target, term, reason)

		Notice(client, key)
	elseif (action == "release") then
		local bOk, key = NETWORK.jail.ReleaseTarget(client, target)

		Notice(client, key)
	end

	NETWORK.jail.SendData(client)
end)

net.Receive("nwJailClose", function(_, client)
	NETWORK.jail.Close(client)
end)

timer.Create("nwJailWatch", NETWORK.jail.refresh, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (IsValid(client.nwJailTerminal)) then
			if (!NETWORK.jail.CanUse(client, client.nwJailTerminal)) then
				NETWORK.jail.Close(client)
			else
				NETWORK.jail.SendData(client)
			end
		end

		if (!client:HasCharacter() or !client:Alive()) then
			continue
		end

		local record = GetRecord(client)

		if (record) then
			client.nwJailed = true

			if (!client:InVehicle() and !NETWORK.jail.IsInside(client)) then
				NETWORK.jail.Put(client)

				Notice(client, "jailReturned")
			end
		elseif (client.nwJailed) then
			NETWORK.jail.Free(client)
		end
	end
end)

hook.Add("NetworkCharacterLoaded", "nwJail", function(client)
	timer.Simple(1, function()
		if (IsValid(client) and GetRecord(client)) then
			NETWORK.jail.Put(client)

			Notice(client, "jailStillHeld")
		end
	end)
end)

hook.Add("PlayerSpawn", "nwJail", function(client)
	timer.Simple(0.5, function()
		if (IsValid(client) and GetRecord(client)) then
			NETWORK.jail.Put(client)
		end
	end)
end)

hook.Add("InitPostEntity", "nwJail", function()
	NETWORK.jail.Load()
end)

NETWORK.jail.Load()

NETWORK.command.Register("jailpoint", {
	adminOnly = true,
	description = "cmdJailPoint",
	usage = "/jailpoint",
	OnRun = function(command, client)
		Notice(client, "jailPointAdded", NETWORK.jail.AddPoint(client))
	end
})

NETWORK.command.Register("jailpoints", {
	adminOnly = true,
	description = "cmdJailPoints",
	usage = "/jailpoints",
	OnRun = function(command, client)
		Notice(client, "jailPointCount", #NETWORK.jail.points,
			NETWORK.jail.release and L("jailReleaseSet") or L("jailReleaseUnset"))
	end
})

NETWORK.command.Register("jailpointdel", {
	adminOnly = true,
	description = "cmdJailPointDel",
	usage = "/jailpointdel <номер>",
	OnRun = function(command, client, arguments)
		local index = tonumber(arguments[1])

		if (!index or !NETWORK.jail.RemovePoint(index)) then
			return Notice(client, "jailNoPoint")
		end

		Notice(client, "jailPointRemoved")
	end
})

NETWORK.command.Register("jailrelease", {
	adminOnly = true,
	description = "cmdJailRelease",
	usage = "/jailrelease",
	OnRun = function(command, client)
		NETWORK.jail.SetRelease(client)

		Notice(client, "jailReleasePoint")
	end
})

hook.Add("NetworkCanSelectCharacter", "nwJail", function(client)
	if (GetRecord(client)) then
		NETWORK.chat.Notice(client, L("jailNoSwap"))

		return false
	end
end)
