local L = NETWORK.lootprops

L.tasks = L.tasks or {}

local function Notice(client, key, tone, ...)
	NETWORK.notice.Send(client, key, tone or "info", ...)
end

function L.Roll(kind)
	local items = {}

	for _, entry in ipairs(kind.loot or {}) do
		if (math.random(100) <= (entry.chance or 100)) then
			local amount = 1

			if (istable(entry.amount)) then
				amount = math.random(entry.amount[1], entry.amount[2])
			end

			items[#items + 1] = {id = entry.id, amount = amount}
		end
	end

	return items
end

function L.Finish(client, entity, kind)
	if (!IsValid(client) or !IsValid(entity)) then
		return
	end

	local items = L.Roll(kind)

	entity:SetNWFloat("nwLootEmpty", CurTime() + L.refill)
	entity:EmitSound("physics/cardboard/cardboard_box_impact_soft" ..
		math.random(1, 3) .. ".wav", 60, math.random(95, 105))

	if (#items == 0) then
		return Notice(client, "lootNothing", "warn")
	end

	local names = {}

	for _, item in ipairs(items) do
		local base = NETWORK.item.Get(item.id)

		if (!base) then
			continue
		end

		if (!NETWORK.inventory.Give(client, item.id, item.amount)) then
			NETWORK.item.Spawn(item.id, entity:WorldSpaceCenter() +
				Vector(0, 0, 16), nil, item.amount)
		end

		names[#names + 1] = base.name or item.id
	end

	Notice(client, "lootFound", "good", table.concat(names, ", "))
end

hook.Add("KeyPress", "nwLootProps", function(client, key)
	if (key != IN_USE or !client:Alive() or !client:HasCharacter()) then
		return
	end

	local trace = client:GetEyeTrace()
	local entity = trace.Entity

	if (!IsValid(entity) or client:GetShootPos():Distance(trace.HitPos) > L.range) then
		return
	end

	local kind = L.GetKind(entity)

	if (!kind) then
		return
	end

	if (L.IsEmpty(entity)) then
		return Notice(client, "lootEmpty", "warn")
	end

	if (L.tasks[client]) then
		return
	end

	L.tasks[client] = {
		entity = entity,
		kind = kind,
		finish = CurTime() + kind.time
	}

	net.Start("nwProgress")
		net.WriteString("lootSearching")
		net.WriteFloat(kind.time)
	net.Send(client)

	client:EmitSound("physics/cardboard/cardboard_box_scrape_smooth_loop1.wav",
		55, 100, 0.5)
end)

local function Cancel(client, bQuiet)
	if (!L.tasks[client]) then
		return
	end

	L.tasks[client] = nil

	if (IsValid(client)) then
		net.Start("nwProgress")
			net.WriteString("")
			net.WriteFloat(0)
		net.Send(client)

		if (!bQuiet) then
			Notice(client, "lootStopped", "warn")
		end
	end
end

hook.Add("KeyRelease", "nwLootProps", function(client, key)
	if (key == IN_USE) then
		Cancel(client, true)
	end
end)

hook.Add("PlayerDisconnected", "nwLootProps", function(client)
	L.tasks[client] = nil
end)

timer.Create("nwLootProps", 0.1, 0, function()
	for client, task in pairs(L.tasks) do
		if (!IsValid(client) or !client:Alive() or !IsValid(task.entity)) then
			L.tasks[client] = nil

			continue
		end

		if (client:GetPos():Distance(task.entity:GetPos()) > L.range + 32) then
			Cancel(client)

			continue
		end

		if (CurTime() < task.finish) then
			continue
		end

		L.tasks[client] = nil

		L.Finish(client, task.entity, task.kind)
	end
end)
