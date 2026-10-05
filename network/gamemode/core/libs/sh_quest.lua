NETWORK.quest = NETWORK.quest or {}
NETWORK.quest.stored = NETWORK.quest.stored or {}
NETWORK.quest.order = NETWORK.quest.order or {}

function NETWORK.quest.Register(id, data)
	data.id = id
	data.name = data.name or id
	data.description = data.description or ""
	data.objectives = data.objectives or {}
	data.rewards = data.rewards or {}

	if (!NETWORK.quest.stored[id]) then
		NETWORK.quest.order[#NETWORK.quest.order + 1] = id
	end

	NETWORK.quest.stored[id] = data

	return data
end

function NETWORK.quest.Get(id)
	return NETWORK.quest.stored[id]
end

function NETWORK.quest.GetState(client)
	if (SERVER) then
		client.nwQuests = client.nwQuests or {}

		return client.nwQuests
	end

	return NETWORK.quest.active or {}
end

function NETWORK.quest.Has(client, id)
	return NETWORK.quest.GetState(client)[id] != nil
end

NETWORK.quest.types = {"item", "kill", "reach", "use"}

function NETWORK.quest.IsPointType(type)
	return type == "reach" or type == "use"
end

function NETWORK.quest.GetPosition(objective)
	if (!istable(objective) or !istable(objective.pos)) then
		return
	end

	return Vector(objective.pos[1] or 0, objective.pos[2] or 0, objective.pos[3] or 0)
end

function NETWORK.quest.GetObjectiveText(objective)
	if (objective.type == "item") then
		local base = NETWORK.item.Get(objective.id)

		return L("questBring") .. " " .. (base and base.name or objective.id)
	end

	if (objective.type == "kill") then
		return L("questKill") .. " " .. (objective.name or objective.id or "?")
	end

	if (NETWORK.quest.IsPointType(objective.type)) then

		local name = objective.name

		if (!isstring(name) or name == "") then
			name = L("questPointUnnamed")
		end

		return L(objective.type == "use" and "questUse" or "questReach") .. " " .. name
	end

	return objective.text or "?"
end

function NETWORK.quest.CountItems(client, id)
	local total = 0

	if (SERVER) then
		local state = NETWORK.inventory.GetState(client)

		for _, list in ipairs({state.items, state.storage}) do
			for _, item in pairs(list) do
				if (item.id == id) then
					total = total + (item.amount or 1)
				end
			end
		end

		return total
	end

	for _, list in ipairs({NETWORK.inventory.state.items, NETWORK.inventory.state.storage}) do
		for _, item in pairs(list) do
			if (item.id == id) then
				total = total + (item.amount or 1)
			end
		end
	end

	return total
end

function NETWORK.quest.GetProgress(client, id, index)
	local quest = NETWORK.quest.Get(id)
	local objective = quest and quest.objectives[index]

	if (!objective) then
		return 0, 1
	end

	local need = objective.amount or 1

	if (objective.type == "item") then
		return math.min(NETWORK.quest.CountItems(client, objective.id), need), need
	end

	local state = NETWORK.quest.GetState(client)[id]
	local progress = state and state.progress and state.progress[tostring(index)] or 0

	return math.min(progress, need), need
end

function NETWORK.quest.GetOpenPoints(client, id)
	local quest = NETWORK.quest.Get(id)
	local list = {}

	if (!quest) then
		return list
	end

	for index, objective in ipairs(quest.objectives) do
		if (!NETWORK.quest.IsPointType(objective.type)) then
			continue
		end

		local position = NETWORK.quest.GetPosition(objective)

		if (!position) then
			continue
		end

		if (objective.map and objective.map != "" and objective.map != game.GetMap()) then
			continue
		end

		local have, need = NETWORK.quest.GetProgress(client, id, index)

		list[#list + 1] = {
			index = index,
			objective = objective,
			position = position,
			have = have,
			need = need,
			bDone = have >= need
		}
	end

	return list
end

function NETWORK.quest.CanComplete(client, id)
	if (!NETWORK.quest.Has(client, id)) then
		return false
	end

	local quest = NETWORK.quest.Get(id)

	if (!quest) then
		return false
	end

	for index = 1, #quest.objectives do
		local have, need = NETWORK.quest.GetProgress(client, id, index)

		if (have < need) then
			return false
		end
	end

	return true
end
