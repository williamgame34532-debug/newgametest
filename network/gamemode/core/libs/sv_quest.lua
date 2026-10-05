util.AddNetworkString("nwQuestSync")

NETWORK.quest.cooldownMin = 30 * 60
NETWORK.quest.cooldownMax = 40 * 60
NETWORK.quest.cooldowns = NETWORK.quest.cooldowns or {}

local cooldownPath = "network/questcooldown.txt"

local function Notice(client, text)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(text)
	net.Send(client)
end

function NETWORK.quest.LoadCooldowns()
	local contents = file.Read(cooldownPath, "DATA")
	local data = contents and util.JSONToTable(contents)

	if (istable(data)) then
		NETWORK.quest.cooldowns = data
	end
end

function NETWORK.quest.SaveCooldowns()
	local now = os.time()
	local clean = {}

	for key, expires in pairs(NETWORK.quest.cooldowns) do
		if (tonumber(expires) and expires > now) then
			clean[key] = expires
		end
	end

	NETWORK.quest.cooldowns = clean

	file.CreateDir("network")
	file.Write(cooldownPath, util.TableToJSON(clean, true))
end

local function CooldownKey(client, id)
	local character = client:GetCharacter()

	if (!character) then
		return
	end

	return character:GetID() .. ":" .. tostring(id)
end

function NETWORK.quest.GetCooldown(client, id)
	local key = CooldownKey(client, id)

	if (!key) then
		return 0
	end

	local expires = tonumber(NETWORK.quest.cooldowns[key]) or 0

	return math.max(expires - os.time(), 0)
end

function NETWORK.quest.SetCooldown(client, id)
	local key = CooldownKey(client, id)

	if (!key) then
		return
	end

	NETWORK.quest.cooldowns[key] = os.time() +
		math.random(NETWORK.quest.cooldownMin, NETWORK.quest.cooldownMax)

	NETWORK.quest.SaveCooldowns()
end

NETWORK.quest.LoadCooldowns()

function NETWORK.quest.Sync(client)
	net.Start("nwQuestSync")
		NETWORK.util.WriteTable(NETWORK.quest.GetState(client))
	net.Send(client)
end

function NETWORK.quest.Start(client, id)
	local quest = NETWORK.quest.Get(id)

	if (!quest or NETWORK.quest.Has(client, id)) then
		return false
	end

	local left = NETWORK.quest.GetCooldown(client, id)

	if (left > 0) then
		Notice(client, L("questCooldown", math.ceil(left / 60)))

		return false
	end

	NETWORK.quest.GetState(client)[id] = {progress = {}, time = os.time()}

	NETWORK.quest.Sync(client)

	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString("questStarted")
	net.Send(client)

	hook.Run("NetworkQuestStarted", client, quest)

	return true
end

function NETWORK.quest.Complete(client, id)
	if (!NETWORK.quest.CanComplete(client, id)) then
		return false
	end

	local quest = NETWORK.quest.Get(id)
	local state = NETWORK.inventory.GetState(client)

	for _, objective in ipairs(quest.objectives) do
		if (objective.type != "item") then
			continue
		end

		local left = objective.amount or 1

		for _, list in ipairs({"items", "storage"}) do
			for index, item in pairs(state[list]) do
				if (left <= 0) then
					break
				end

				if (item.id != objective.id) then
					continue
				end

				local taken = math.min(item.amount or 1, left)

				left = left - taken

				if ((item.amount or 1) > taken) then
					item.amount = item.amount - taken
				else
					state[list][index] = nil
				end
			end
		end
	end

	for _, reward in ipairs(quest.rewards.items or {}) do
		for _ = 1, reward.amount or 1 do
			NETWORK.inventory.Give(client, reward.id)
		end
	end

	NETWORK.quest.GetState(client)[id] = nil

	NETWORK.quest.SetCooldown(client, id)

	NETWORK.inventory.Sync(client)
	NETWORK.quest.Sync(client)

	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString("questDone")
	net.Send(client)

	hook.Run("NetworkQuestCompleted", client, quest)

	return true
end

function NETWORK.quest.AddProgress(client, id, index, amount)
	local state = NETWORK.quest.GetState(client)[id]

	if (!state) then
		return
	end

	local key = tostring(index)

	state.progress[key] = (state.progress[key] or 0) + (amount or 1)

	NETWORK.quest.Sync(client)
end

local function ForEachObjective(client, callback)
	for id in pairs(NETWORK.quest.GetState(client)) do
		local quest = NETWORK.quest.Get(id)

		if (!quest) then
			continue
		end

		for index, objective in ipairs(quest.objectives) do
			callback(id, index, objective)
		end
	end
end

local function CompletePoint(client, id, index, objective)
	local have, need = NETWORK.quest.GetProgress(client, id, index)

	if (have >= need) then
		return false
	end

	NETWORK.quest.AddProgress(client, id, index, need - have)

	client:EmitSound("buttons/button9.wav", 55, 110)

	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString("questPointDone")
	net.Send(client)

	return true
end

local function AtPoint(client, objective, position)
	if (objective.map and objective.map != "" and objective.map != game.GetMap()) then
		return false
	end

	local radius = math.max(tonumber(objective.radius) or 96, 16)

	return (position or client:GetPos()):DistToSqr(
		NETWORK.quest.GetPosition(objective)) <= radius * radius
end

timer.Create("nwQuestReach", 0.25, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (!client:HasCharacter() or !client:Alive()) then
			continue
		end

		ForEachObjective(client, function(id, index, objective)
			if (objective.type != "reach" or !NETWORK.quest.GetPosition(objective)) then
				return
			end

			if (AtPoint(client, objective)) then
				CompletePoint(client, id, index, objective)
			end
		end)
	end
end)

hook.Add("PlayerUse", "nwQuestUse", function(client, entity)
	if (!IsValid(entity) or !client:HasCharacter()) then
		return
	end

	if ((client.nwQuestUse or 0) > CurTime()) then
		return
	end

	local class = entity:GetClass()
	local position = entity:GetPos()

	ForEachObjective(client, function(id, index, objective)
		if (objective.type != "use" or !NETWORK.quest.GetPosition(objective)) then
			return
		end

		if (objective.class and objective.class != "" and objective.class != class) then
			return
		end

		if (!AtPoint(client, objective, position) and !AtPoint(client, objective)) then
			return
		end

		if (CompletePoint(client, id, index, objective)) then
			client.nwQuestUse = CurTime() + 0.5
		end
	end)
end)

hook.Add("OnNPCKilled", "nwQuest", function(npc, attacker)
	if (!IsValid(attacker) or !attacker:IsPlayer()) then
		return
	end

	local class = npc:GetClass()

	for id in pairs(NETWORK.quest.GetState(attacker)) do
		local quest = NETWORK.quest.Get(id)

		if (!quest) then
			continue
		end

		for index, objective in ipairs(quest.objectives) do
			if (objective.type == "kill" and objective.id == class) then
				NETWORK.quest.AddProgress(attacker, id, index, 1)
			end
		end
	end
end)

hook.Add("NetworkCharacterLoaded", "nwQuest", function(client)
	client.nwQuests = {}

	NETWORK.quest.Sync(client)
end)
