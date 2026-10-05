util.AddNetworkString("nwDamageDirection")

NETWORK.playtime = NETWORK.playtime or {}
NETWORK.playtime.stored = NETWORK.playtime.stored or {}

local playtimePath = "network/playtime.txt"

function NETWORK.playtime.Load()
	local raw = file.Read(playtimePath, "DATA")

	NETWORK.playtime.stored = raw and util.JSONToTable(raw) or {}
end

function NETWORK.playtime.Save()

	file.CreateDir("network")
	file.Write(playtimePath, util.TableToJSON(NETWORK.playtime.stored, true))
end

hook.Add("Initialize", "nwPlaytime", function()
	NETWORK.playtime.Load()
end)

function NETWORK.playtime.Get(client)
	local character = client:GetCharacter()

	if (!character) then
		return 0
	end

	return NETWORK.playtime.stored[tostring(character:GetID())] or 0
end

timer.Create("nwPlaytime", 60, 0, function()
	local bChanged = false

	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (!character) then
			continue
		end

		local key = tostring(character:GetID())

		NETWORK.playtime.stored[key] = (NETWORK.playtime.stored[key] or 0) + 1

		client:SetNWInt("nwPlaytime", NETWORK.playtime.stored[key])

		bChanged = true
	end

	if (bChanged) then
		NETWORK.playtime.Save()
	end
end)

hook.Add("NetworkCharacterLoaded", "nwPlaytime", function(client)
	client:SetNWInt("nwPlaytime", NETWORK.playtime.Get(client))
end)

NETWORK.command.Register("playtime", {
	description = "cmdPlaytime",
	usage = "/playtime",
	OnRun = function(command, client)
		local minutes = NETWORK.playtime.Get(client)

		NETWORK.chat.Notice(client, L("playtimeResult",
			math.floor(minutes / 60), minutes % 60))
	end
})

hook.Add("PlayerHurt", "nwDamageDirection", function(client, attacker, healthLeft,
	amount)
	if (!IsValid(client) or !client:IsPlayer()) then
		return
	end

	local direction = 0

	if (IsValid(attacker) and attacker != client) then
		local offset = (attacker:GetPos() - client:GetPos()):GetNormalized()
		local side = offset:Dot(client:EyeAngles():Right())

		direction = side > 0.2 and 1 or (side < -0.2 and -1 or 0)
	end

	net.Start("nwDamageDirection")

		net.WriteFloat(math.Clamp(amount / 45, 0.25, 1))
		net.WriteInt(direction, 4)
	net.Send(client)
end)

hook.Add("OnNPCKilled", "nwRagdollCleanup", function(npc)

	local position = IsValid(npc) and npc:GetPos()

	if (!position) then
		return
	end

	timer.Simple(0.2, function()
		for _, entity in ipairs(ents.FindInSphere(position, 96)) do
			if (entity:GetClass() == "prop_ragdoll" and
				!entity.nwNoCleanup) then

				entity.nwNoCleanup = true

				SafeRemoveEntityDelayed(entity, 60)
			end
		end
	end)
end)

local gestures = {
	agree = ACT_GMOD_GESTURE_AGREE,
	disagree = ACT_GMOD_GESTURE_DISAGREE,
	wave = ACT_GMOD_GESTURE_WAVE,
	salute = ACT_GMOD_GESTURE_BECON,
	point = ACT_GMOD_GESTURE_ITEM_PLACE,
	clap = ACT_GMOD_TAUNT_CHEER,
	halt = ACT_SIGNAL_HALT,
	forward = ACT_SIGNAL_FORWARD,
	group = ACT_SIGNAL_GROUP
}

NETWORK.command.Register("act", {
	description = "cmdAct",
	usage = "/act <жест>",
	example = "/act wave",
	OnRun = function(command, client, arguments)
		local name = string.lower(arguments[1] or "")
		local act = gestures[name]

		if (!act) then
			local list = {}

			for id in pairs(gestures) do
				list[#list + 1] = id
			end

			table.sort(list)

			return NETWORK.chat.Notice(client, L("actList",
				table.concat(list, ", ")))
		end

		if (!client:Alive() or client:GetNWBool("nwTied", false)) then
			return NETWORK.chat.Notice(client, "actUnavailable")
		end

		client:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, act, true)
	end
})
