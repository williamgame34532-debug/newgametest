-- Chat, server side. Messages come over the net (no 127 byte limit of the "say" command, so
-- long Cyrillic lines arrive whole), go through PlayerSay (other systems may change or drop them),
-- then are sorted by kind (sh_chat.lua) and sent only to the players in range.

util.AddNetworkString("nwChatSay")
util.AddNetworkString("nwChatTyped")
util.AddNetworkString("nwChatNotice")
util.AddNetworkString("nwGesture")
util.AddNetworkString("nwTyping")

local K = NW.chatKinds
local MAX = 1000

local function Notice(client, text)
	NW.Notify(client, text)
end

-- chat commands of other systems: NW.AddChatCommand("spawnadd", {admin = true, run = function(client,
-- rest) ... end}); a staff command is "unknown" for everyone else
NW.chatCommands = NW.chatCommands or {}

function NW.AddChatCommand(name, command)
	NW.chatCommands[string.lower(name)] = command
end

local function InRange(speaker, range)
	local out = {}
	local origin = speaker:EyePos()
	local range2 = range * range

	for _, target in ipairs(player.GetAll()) do
		if (target == speaker or (target:Alive() and !NW.IsInMenu(target) and
			target:EyePos():DistToSqr(origin) <= range2)) then
			out[#out + 1] = target
		end
	end

	return out
end

-- a player by (part of) the character name or the Steam name
function NW.FindPlayer(query)
	query = string.lower(query or "")

	if (query == "") then
		return
	end

	-- "#12": the player with that user id (the TAB menu fills it in)
	local id = tonumber(string.match(query, "^#(%d+)$") or "")

	if (id) then
		local target = Player(id)

		return IsValid(target) and target or nil
	end

	for _, target in ipairs(player.GetAll()) do
		if (string.lower(target:Nick()) == query or string.lower(target:SteamName()) == query) then
			return target
		end
	end

	for _, target in ipairs(player.GetAll()) do
		if (string.find(string.lower(target:Nick()), query, 1, true) or
			string.find(string.lower(target:SteamName()), query, 1, true)) then
			return target
		end
	end
end

local function Send(kind, speaker, text, extra, recipients)
	net.Start("nwChatTyped")
		net.WriteUInt(kind, 4)
		net.WriteEntity(speaker)
		net.WriteString(text)
		net.WriteString(extra or "")
	net.Send(recipients)
end

-- an action of the character in the chat, as if typed with /me (pulse checks, searching...)
function NW.SayMe(client, text)
	Send(K.ME, client, text, "", InRange(client, K.range[K.ME]))
end

net.Receive("nwChatSay", function(_, client)
	local text = string.Trim(net.ReadString() or "")
	local bTeam = net.ReadBool()

	if (text == "" or (client.nwChatNext or 0) > CurTime()) then
		return
	end

	client.nwChatNext = CurTime() + 0.35

	if (#text > MAX) then
		text = string.sub(text, 1, MAX)
	end

	text = string.gsub(text, "[%c]", " ")

	local result = hook.Run("PlayerSay", client, text, bTeam)

	if (!isstring(result) or result == "") then
		return
	end

	local kind, body, rest = K.Parse(result)

	if (kind == K.ADMIN and !client:IsAdmin()) then
		kind, body = nil, "achat"
	end

	if (!kind) then
		local command = NW.chatCommands[string.lower(body)]

		if (command and (!command.admin or client:IsAdmin())) then
			command.run(client, rest or "")

			return
		end

		return Notice(client, "Неизвестная команда: /" .. body)
	end

	-- the staff chat: every admin on the server
	if (kind == K.ADMIN) then
		if (body == "") then
			return
		end

		local admins = {}

		for _, target in ipairs(player.GetAll()) do
			if (target:IsAdmin()) then
				admins[#admins + 1] = target
			end
		end

		Send(kind, client, body, "", admins)
		MsgN(string.format("[ACHAT] %s: %s", client:SteamName(), body))

		return
	end

	local inWorld = client:Alive() and !NW.IsInMenu(client)

	-- in-character kinds need a character in the world
	if (!inWorld and kind != K.OOC and kind != K.PM) then
		return Notice(client, "Это можно только в игре за персонажа.")
	end

	if (kind == K.PM) then
		local who, message = string.match(body, "^(%S+)%s+(.+)$")
		local target = NW.FindPlayer(who)

		if (!target) then
			return Notice(client, "Игрок не найден. /pm <имя> <текст>")
		end

		Send(kind, client, message, target:SteamName(), {client, target})
		MsgN(string.format("[PM] %s -> %s: %s", client:SteamName(), target:SteamName(), message))

		return
	end

	if (kind == K.ROLL) then
		local max = math.Clamp(math.floor(tonumber(body) or 100), 1, 1000000)

		Send(kind, client, tostring(math.random(0, max)), tostring(max), InRange(client, K.range[kind]))

		return
	end

	if (body == "") then
		return
	end

	local recipients = kind == K.OOC and player.GetAll() or InRange(client, K.range[kind])

	Send(kind, client, body, "", recipients)

	-- talking: sometimes a gesture with it (not in a pose)
	if ((kind == K.IC or kind == K.WHISPER or kind == K.YELL) and !client:GetAct() and
		math.random() < K.gestureChance) then
		net.Start("nwGesture")
			net.WriteEntity(client)
			net.WriteUInt(math.random(#K.gestures), 5)
		net.SendPVS(client:GetPos())
	end
	MsgN(string.format("[%d] %s (%s): %s", kind, client:Nick(), client:SteamName(), body))
end)

-- typing: what the others see over the head (0 none, 1 talking, 2 whispering, 3 yelling, 4 other).
-- Quick changes are merged: the latest state is sent at most 10 times a second.
local function Relay(client)
	if (!IsValid(client)) then
		return
	end

	local state = client.nwTypingPending or 0

	client.nwTypingSent = RealTime()

	net.Start("nwTyping")
		net.WriteEntity(client)
		net.WriteUInt(state, 3)

	if (state == 0) then
		net.Broadcast()
	else
		net.SendPVS(client:GetPos())
	end
end

net.Receive("nwTyping", function(_, client)
	client.nwTypingPending = math.Clamp(net.ReadUInt(3), 0, 4)

	local wait = 0.1 - (RealTime() - (client.nwTypingSent or 0))

	if (wait <= 0) then
		Relay(client)
	elseif (!timer.Exists("nwTyping" .. client:EntIndex())) then
		timer.Create("nwTyping" .. client:EntIndex(), wait, 1, function()
			Relay(client)
		end)
	end
end)
