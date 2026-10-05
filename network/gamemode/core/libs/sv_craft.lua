util.AddNetworkString("nwCraftOpen")
util.AddNetworkString("nwCraftMake")
util.AddNetworkString("nwCraftCancel")
util.AddNetworkString("nwCraftState")
util.AddNetworkString("nwCraftConfig")
util.AddNetworkString("nwCraftConfigRequest")
util.AddNetworkString("nwCraftConfigOpen")

function NETWORK.craft.GetRecipes(entity, bKeepBroken)
	if (!NETWORK.craft.IsTable(entity)) then
		return {}
	end

	if (entity:GetClass() == "nw_craft_table") then
		return (NETWORK.craft.ParseWorkbench(entity:GetRecipes(), bKeepBroken))
	end

	local list = {}

	for _, raw in ipairs(entity.recipes or {}) do
		local recipe = NETWORK.craft.Normalize(raw)

		if (recipe and (bKeepBroken or NETWORK.craft.Validate(recipe))) then
			list[#list + 1] = recipe
		end
	end

	return list
end

function NETWORK.craft.SetRecipes(entity, list)
	if (entity:GetClass() == "nw_craft_table") then
		local text, dropped = NETWORK.craft.ToWorkbenchText(list)

		entity:SetRecipes(text)

		return dropped
	end

	local stored = {}

	for _, recipe in ipairs(list) do
		local copy = table.Copy(recipe)

		if (#(copy.tools or {}) == 0) then
			copy.tools = nil
		end

		stored[#stored + 1] = copy
	end

	entity.recipes = stored

	if (NETWORK.entities and NETWORK.entities.Save) then
		NETWORK.entities.Save()
	end

	return 0
end

local function SendState(client, task)
	net.Start("nwCraftState")
		net.WriteBool(task != nil)

		if (task) then
			net.WriteEntity(task.entity)
			net.WriteUInt(task.index, 5)
			net.WriteFloat(task.duration or 0)
			net.WriteUInt(task.left, 7)
			net.WriteUInt(task.done, 7)
		end
	net.Send(client)
end

local function Progress(client, duration)
	net.Start("nwProgress")
		net.WriteString(duration > 0 and "craftProgress" or "")
		net.WriteFloat(duration)
	net.Send(client)
end

function NETWORK.craft.Open(client, entity)
	if (!NETWORK.craft.IsTable(entity)) then
		return
	end

	client.nwCraftTable = entity

	net.Start("nwCraftOpen")
		net.WriteEntity(entity)
		NETWORK.util.WriteTable(NETWORK.craft.GetRecipes(entity))
	net.Send(client)

	local task = client.nwCraftTask

	if (task and task.entity == entity) then
		SendState(client, task)
	end
end

local function InReach(client, entity, extra)
	return IsValid(client) and IsValid(entity) and client:Alive() and
		client:HasCharacter() and client:GetPos():Distance(entity:GetPos()) <=
		NETWORK.craft.range + (extra or 0)
end

local function Check(client, recipe)
	if (!NETWORK.craft.HasSkill(client, recipe)) then
		return false, "craftNeedSkill", recipe.skill
	end

	local state = NETWORK.inventory.GetState(client)

	for id, need in SortedPairs(NETWORK.craft.Needs(recipe)) do
		if (NETWORK.craft.Count(state, id) < need.cost + need.tool) then
			return false, need.cost > 0 and "craftMissing" or "craftNeedTool",
				NETWORK.item.GetName({id = id})
		end
	end

	return true
end

local function Consume(state, cost)
	for _, entry in ipairs(cost) do
		local left = entry.amount

		for slot, item in pairs(state.items) do
			if (left <= 0) then
				break
			end

			if (!istable(item) or item.id != entry.id) then
				continue
			end

			local take = math.min(item.amount or 1, left)

			left = left - take

			if ((item.amount or 1) > take) then
				item.amount = item.amount - take
			else
				NETWORK.inventory.Put(state, "items", slot, nil, nil)
			end
		end
	end
end

local function Deliver(client, id, amount, lift)
	local item = NETWORK.item.New(id, amount)

	if (!item) then
		return
	end

	if (NETWORK.item.OnCreated) then
		NETWORK.item.OnCreated(item, client, client:GetCharacter())
	end

	local left = NETWORK.inventory.Insert(NETWORK.inventory.GetState(client), item)

	if (left > 0) then
		NETWORK.item.Spawn(id, client:GetPos() + client:GetForward() * 24 +
			Vector(0, 0, lift or 16), nil, left, item.data)
	end
end

function NETWORK.craft.Stop(client, reason, tone, ...)
	if (!client.nwCraftTask) then
		return
	end

	client.nwCraftTask = nil

	Progress(client, 0)
	SendState(client, nil)

	if (reason) then
		NETWORK.notice.Send(client, reason, tone or "warn", ...)
	end
end

local function Begin(client, task)
	local duration = NETWORK.craft.GetTime(task.recipe, task.entity)

	if (NETWORK.skills and NETWORK.skills.CraftTimeFactor) then
		duration = math.max(0.5, duration * NETWORK.skills.CraftTimeFactor(client))
	end

	task.duration = duration
	task.finish = CurTime() + duration

	Progress(client, duration)
	SendState(client, task)

	task.entity:EmitSound("ambient/machines/machine1_hit1.wav", 60)
end

function NETWORK.craft.Start(client, entity, index, count, resultID)
	if (!NETWORK.craft.IsTable(entity)) then
		return
	end

	if (client.nwCraftTask) then
		return NETWORK.notice.Send(client, "craftBusy", "warn")
	end

	if (!InReach(client, entity)) then
		return NETWORK.notice.Send(client, "craftTooFar", "bad")
	end

	local recipe = NETWORK.craft.GetRecipes(entity)[index]

	if (!recipe or (isstring(resultID) and resultID != "" and
		recipe.result.id != resultID)) then
		return NETWORK.notice.Send(client, "craftChanged", "warn")
	end

	local bOk, reason, extra = Check(client, recipe)

	if (!bOk) then
		return NETWORK.notice.Send(client, reason, "bad", extra)
	end

	count = math.Clamp(math.floor(tonumber(count) or 1), 1, NETWORK.craft.maxBatch)
	count = math.min(count, math.max(NETWORK.craft.MaxBatch(
		NETWORK.inventory.GetState(client), recipe), 1))

	local task = {
		entity = entity,
		index = index,
		recipe = recipe,
		left = count,
		done = 0
	}

	client.nwCraftTask = task

	Begin(client, task)
end

local function Finish(client, task)
	local recipe = task.recipe

	local bOk, reason, extra = Check(client, recipe)

	if (!bOk) then
		return NETWORK.craft.Stop(client, reason, "bad", extra)
	end

	local state = NETWORK.inventory.GetState(client)

	Consume(state, recipe.cost)
	Deliver(client, recipe.result.id, recipe.result.amount)

	local bonus = NETWORK.skills and NETWORK.skills.RollCraftBonus and
		NETWORK.skills.RollCraftBonus(client, recipe.result.amount) -
		recipe.result.amount or 0

	if (bonus > 0) then
		Deliver(client, recipe.result.id, bonus, 24)
		NETWORK.notice.Send(client, "craftBonus", "good")
	end

	NETWORK.inventory.Sync(client)

	task.entity:EmitSound("physics/metal/metal_box_impact_hard" ..
		math.random(3) .. ".wav", 65, math.random(95, 105))

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("item", string.format("%s собрал %s x%d на «%s»",
			NETWORK.log.Name(client), recipe.result.id, recipe.result.amount,
			NETWORK.craft.GetTableName(task.entity)), task.entity:GetPos())
	end

	if (recipe.xp and NETWORK.skills and NETWORK.skills.AddXP) then
		NETWORK.skills.AddXP(client, "crafting", recipe.xp)
	end

	hook.Run("NetworkWorkbenchCrafted", client, task.entity, recipe)

	task.done = task.done + 1
	task.left = task.left - 1

	if (task.left > 0) then

		if (Check(client, recipe)) then
			return Begin(client, task)
		end

		return NETWORK.craft.Stop(client, "craftBatchStopped", "warn", task.done)
	end

	client.nwCraftTask = nil

	SendState(client, nil)

	NETWORK.notice.Send(client, "craftDoneCount", "good",
		NETWORK.item.GetName({id = recipe.result.id}),
		recipe.result.amount * task.done)
end

timer.Create("nwCraftTasks", 0.2, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local task = client.nwCraftTask

		if (!task) then
			continue
		end

		if (!InReach(client, task.entity, 40)) then
			NETWORK.craft.Stop(client, "craftInterrupted", "warn")

			continue
		end

		if (CurTime() >= task.finish) then
			Finish(client, task)
		end
	end
end)

hook.Add("PlayerDisconnected", "nwCraftTasks", function(client)
	client.nwCraftTask = nil
end)

net.Receive("nwCraftMake", function(_, client)
	local entity = client.nwCraftTable
	local index = net.ReadUInt(5)
	local count = net.ReadUInt(7)
	local resultID = net.ReadString()

	NETWORK.craft.Start(client, entity, index, math.max(count, 1), resultID)
end)

net.Receive("nwCraftCancel", function(_, client)
	NETWORK.craft.Stop(client, "craftCancelled", "info")
end)

function NETWORK.craft.ApplyConfig(client, entity, payload)
	if (!IsValid(client) or !client:IsAdmin() or !NETWORK.craft.IsTable(entity)) then
		return
	end

	payload = istable(payload) and payload or {}

	local model = isstring(payload.model) and string.Trim(payload.model) or nil

	if (model != nil and model != "" and !util.IsValidModel(model)) then
		NETWORK.notice.Send(client, "craftBadModel", "warn", model)

		model = nil
	end

	if (entity:GetClass() == "nw_craft_table") then
		entity:SetTitle(NETWORK.util.Sanitise(payload.name or payload.title or "", 40))

		if (model != nil) then
			entity:SetCraftModel(model)

			if (entity.ApplyModel) then
				entity:ApplyModel()
			end
		end
	else
		entity:SetTableName(NETWORK.util.Sanitise(payload.name or "", 48))

		if (model != nil) then
			entity:SetTableModel(model)
		end

		entity:Apply()
	end

	local source = payload.recipes
	local recipes = {}
	local problems = 0

	local function Report(reason, extra)
		problems = problems + 1

		if (problems <= 3) then
			NETWORK.notice.Send(client, reason, "warn", extra or "")
		end
	end

	if (isstring(source)) then
		for _, line in ipairs(string.Explode("\n", source)) do
			if (string.Trim(line) == "") then
				continue
			end

			local recipe, reason, extra

			if (string.find(line, "=", 1, true)) then
				recipe, reason, extra = NETWORK.craft.Parse(line)
			else
				recipe, reason = NETWORK.craft.ParseWorkbenchLine(line)

				if (recipe) then
					local bValid

					bValid, reason, extra = NETWORK.craft.Validate(recipe)
					recipe = bValid and recipe or nil
				end
			end

			if (recipe) then
				recipes[#recipes + 1] = recipe
			else
				Report(reason or "craftBadFormat", extra)
			end
		end
	elseif (istable(source)) then
		for _, raw in ipairs(source) do
			local recipe = NETWORK.craft.Normalize(raw)
			local bValid, reason, extra = NETWORK.craft.Validate(recipe)

			if (bValid) then
				recipes[#recipes + 1] = recipe
			else
				Report(reason or "craftBadFormat", extra)
			end
		end
	end

	if (problems > 3) then
		NETWORK.notice.Send(client, "craftSkipped", "warn", problems)
	end

	if (#recipes > NETWORK.craft.maxRecipes) then
		NETWORK.notice.Send(client, "craftTooMany", "warn", NETWORK.craft.maxRecipes)

		for index = #recipes, NETWORK.craft.maxRecipes + 1, -1 do
			recipes[index] = nil
		end
	end

	local dropped = NETWORK.craft.SetRecipes(entity, recipes)

	if (dropped > 0) then
		NETWORK.notice.Send(client, "craftTooLong", "warn", dropped)
	end

	NETWORK.log.Add("admin", string.format("%s настроил стол крафта «%s»: рецептов %d",
		NETWORK.log.Name(client), NETWORK.craft.GetTableName(entity),
		#recipes - dropped), entity:GetPos())

	NETWORK.notice.Send(client, "craftSavedCount", "good", #recipes - dropped)
end

net.Receive("nwCraftConfig", function(_, client)
	local entity = net.ReadEntity()
	local payload = NETWORK.util.ReadTable() or {}

	NETWORK.craft.ApplyConfig(client, entity, payload)
end)

net.Receive("nwCraftConfigRequest", function(_, client)
	if (!client:IsAdmin()) then
		return
	end

	local entity = net.ReadEntity()

	if (!NETWORK.craft.IsTable(entity)) then
		return
	end

	local info = NETWORK.craft.GetClassInfo(entity)

	net.Start("nwCraftConfigOpen")
		net.WriteEntity(entity)
		NETWORK.util.WriteTable({
			name = NETWORK.craft.GetTableName(entity),
			model = NETWORK.craft.GetTableModel(entity),
			recipes = NETWORK.craft.GetRecipes(entity, true),
			textLimit = info.storage == "text" and NETWORK.craft.textLimit or nil
		})
	net.Send(client)
end)
