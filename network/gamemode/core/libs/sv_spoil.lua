local S = NETWORK.spoil

S.interval = 60

function S.TickList(list, scale, seen)
	if (!istable(list) or (seen and seen[list])) then
		return false
	end

	if (seen) then
		seen[list] = true
	end

	local bChanged = false

	for _, item in pairs(list) do
		if (!istable(item)) then
			continue
		end

		local base = NETWORK.item.Get(item.id)

		if (base and S.Tick(item, base, scale, S.interval / 60)) then
			bChanged = true
		end
	end

	return bChanged
end

function S.GetEntityScale(entity)
	if (S.IsFridge(entity)) then
		return S.fridgeScale
	end

	return S.containerScale
end

function S.Run()
	local seen = {}

	for _, client in ipairs(player.GetAll()) do
		if (!client:HasCharacter()) then
			continue
		end

		local state = NETWORK.inventory.GetState(client)
		local bChanged = S.TickList(state.items, 1, seen)

		if (S.TickList(state.storage, 1, seen)) then
			bChanged = true
		end

		if (bChanged) then
			NETWORK.inventory.Sync(client)
		end
	end

	local classes = NETWORK.container and NETWORK.container.classes or
		{nw_container = true, nw_stash = true}

	for class in pairs(classes) do
		for _, entity in ipairs(ents.FindByClass(class)) do
			if (!istable(entity.items)) then
				continue
			end

			if (S.TickList(entity.items, S.GetEntityScale(entity), seen)) then
				NETWORK.container.Sync(entity)
			end
		end
	end

	if (NETWORK.stash and istable(NETWORK.stash.stored)) then
		local bChanged = false

		for _, list in pairs(NETWORK.stash.stored) do
			if (S.TickList(list, S.containerScale, seen)) then
				bChanged = true
			end
		end

		if (bChanged and NETWORK.stash.Save) then
			NETWORK.stash.Save()
		end
	end
end

timer.Create("nwSpoil", S.interval, 0, function()
	local bOk, err = pcall(S.Run)

	if (!bOk) then
		ErrorNoHalt("[Network] spoil: " .. tostring(err) .. "\n")
	end
end)

function S.OnConsume(client, item, base)
	local scale = 1
	local spoil = S.CanSpoil(base) and S.Get(item) or 0

	if (spoil >= 100) then
		return "foodRotten"
	end

	if (spoil >= 50) then
		scale = 0.6

		NETWORK.notice.Send(client, "foodSpoiled", "warn")

		if (NETWORK.disease and NETWORK.disease.Roll) then
			NETWORK.disease.Roll(client, "poisoning", 0.35 + (spoil - 50) / 100)
		end
	elseif (base.bLowQuality and NETWORK.disease and NETWORK.disease.Roll) then
		NETWORK.disease.Roll(client, "poisoning", 0.08)
	end

	return nil, scale
end

concommand.Add("network_spoil_set", function(client, _, arguments)
	if (!IsValid(client) or !client:IsAdmin() or !client:HasCharacter()) then
		return
	end

	local value = math.Clamp(tonumber(arguments[1]) or 0, 0, 100)
	local state = NETWORK.inventory.GetState(client)

	for _, list in ipairs({state.items, state.storage}) do
		for _, item in pairs(list or {}) do
			if (istable(item) and S.CanSpoil(NETWORK.item.Get(item.id))) then
				item.data = item.data or {}
				item.data.spoil = value
			end
		end
	end

	NETWORK.inventory.Sync(client)
end)
