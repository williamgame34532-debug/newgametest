NETWORK.antidupe = NETWORK.antidupe or {}

local A = NETWORK.antidupe

local dataPath = "network/uids.txt"

A.owners = A.owners or {}
A.counter = A.counter or 0

A.skipCategories = {
	ammo = true,
	junk = true,
	food = true,
	rations = true
}

function A.Save()
	timer.Create("nwAntiDupeSave", 5, 1, function()
		file.CreateDir("network")
		file.Write(dataPath, util.TableToJSON(A.owners))
	end)
end

function A.Load()
	local raw = file.Read(dataPath, "DATA")
	local data = raw and util.JSONToTable(raw)

	A.owners = istable(data) and data or {}
end

hook.Add("Initialize", "nwAntiDupe", A.Load)

function A.NeedsUID(base)
	if (!base) then
		return false
	end

	if (base.bStackable or (base.maxStack or 1) > 1) then
		return false
	end

	return !A.skipCategories[base.category or ""]
end

function A.Generate()
	A.counter = A.counter + 1

	return string.format("%s-%04x-%d", string.sub(util.CRC(tostring(SysTime()) ..
		tostring(math.random(1, 1e9))), 1, 8), math.random(0, 0xFFFF), A.counter)
end

function A.Stamp(item)
	if (!istable(item)) then
		return item
	end

	local base = NETWORK.item.Get(item.id)

	if (!A.NeedsUID(base)) then
		return item
	end

	item.data = item.data or {}

	if (!item.data.uid) then
		item.data.uid = A.Generate()
	end

	return item
end

function A.Owner(uid)
	return A.owners[uid or ""]
end

function A.Claim(uid, charID)
	if (!uid or !charID) then
		return
	end

	if (A.owners[uid] != charID) then
		A.owners[uid] = charID

		A.Save()
	end
end

function A.Release(uid)
	if (uid and A.owners[uid]) then
		A.owners[uid] = nil

		A.Save()
	end
end

function A.Filter(client, state)
	local character = client:GetCharacter()

	if (!character or !istable(state)) then
		return
	end

	local charID = tostring(character:GetID())
	local removed = 0

	for _, list in ipairs({"items", "equipped", "storage", "clothes"}) do
		for index, item in pairs(state[list] or {}) do
			if (!istable(item) or !istable(item.data) or !item.data.uid) then
				continue
			end

			local owner = A.Owner(item.data.uid)

			if (owner and owner != charID) then
				state[list][index] = nil
				removed = removed + 1

				NETWORK.util.PrintWarning(string.format(
					"Дюп: вещь %s (%s) числится за персонажем %s, у %s изъята.",
					tostring(item.id), tostring(item.data.uid), tostring(owner),
					charID))
			else
				A.Claim(item.data.uid, charID)
			end
		end
	end

	if (removed > 0) then
		NETWORK.inventory.Sync(client)
	end

	return removed
end

hook.Add("NetworkSearchTook", "nwAntiDupe", function(client, target, item)
	if (istable(item) and istable(item.data) and item.data.uid and
		client:HasCharacter()) then
		A.Claim(item.data.uid, tostring(client:GetCharacter():GetID()))
	end
end)

hook.Add("NetworkItemPickedUp", "nwAntiDupe", function(client, item)
	if (istable(item) and istable(item.data) and item.data.uid and
		client:HasCharacter()) then
		A.Claim(item.data.uid, tostring(client:GetCharacter():GetID()))
	end
end)

hook.Add("NetworkItemDropped", "nwAntiDupe", function(client, entity, item)
	if (istable(item) and istable(item.data) and item.data.uid) then
		A.Release(item.data.uid)
	end
end)

hook.Add("NetworkCharacterLoaded", "nwAntiDupe", function(client)
	timer.Simple(1.5, function()
		if (IsValid(client) and client:HasCharacter()) then
			A.Filter(client, NETWORK.inventory.GetState(client))
		end
	end)
end)

concommand.Add("network_dupe_check", function(client)
	if (IsValid(client) and !client:IsAdmin()) then
		return
	end

	local seen, dupes = {}, 0

	for _, target in ipairs(player.GetAll()) do
		if (!target:HasCharacter()) then
			continue
		end

		local state = NETWORK.inventory.GetState(target)

		for _, list in ipairs({"items", "equipped", "storage", "clothes"}) do
			for _, item in pairs((state or {})[list] or {}) do
				local uid = istable(item) and istable(item.data) and item.data.uid

				if (!uid) then
					continue
				end

				if (seen[uid]) then
					dupes = dupes + 1

					NETWORK.util.PrintWarning(string.format(
						"Дюп в сети: %s у %s и %s", uid, seen[uid],
						target:GetCharacterName()))
				else
					seen[uid] = target:GetCharacterName()
				end
			end
		end
	end

	NETWORK.util.Print("Проверка дюпа: совпадений " .. dupes)
end)
