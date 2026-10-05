util.AddNetworkString("nwZoneSync")
util.AddNetworkString("nwZoneEdit")
util.AddNetworkString("nwZoneEditor")

local dataPath = "network/zones.txt"

NETWORK.zone.runtimeFields = {nextDamage = true, nextSpawn = true}

function NETWORK.zone.Save()
	local clean = {}

	for key, zone in pairs(NETWORK.zone.list) do
		local copy = {}

		for field, value in pairs(zone) do
			if (!NETWORK.zone.runtimeFields[field]) then
				copy[field] = value
			end
		end

		clean[key] = copy
	end

	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(clean, true))
end

function NETWORK.zone.Load()
	local contents = file.Read(dataPath, "DATA")

	if (!contents) then
		return
	end

	local data = util.JSONToTable(contents)

	if (!istable(data)) then
		return
	end

	local list = {}

	for key, zone in pairs(data) do
		if (istable(zone)) then
			for field in pairs(NETWORK.zone.runtimeFields) do
				zone[field] = nil
			end

			list[tostring(zone.id or key)] = zone
		end
	end

	NETWORK.zone.list = list
end

function NETWORK.zone.Get(id)
	return NETWORK.zone.list[tostring(id)] or NETWORK.zone.list[tonumber(id) or -1]
end

function NETWORK.zone.Sync(target)
	net.Start("nwZoneSync")
		NETWORK.util.WriteTable(NETWORK.zone.list)

	if (IsValid(target)) then
		net.Send(target)
	else
		net.Broadcast()
	end
end

function NETWORK.zone.NextID()
	local highest = 0

	for _, zone in pairs(NETWORK.zone.list) do
		highest = math.max(highest, zone.id or 0)
	end

	return highest + 1
end

function NETWORK.zone.Set(zone)
	NETWORK.zone.Normalise(zone)

	NETWORK.zone.list[tonumber(zone.id) or -1] = nil
	NETWORK.zone.list[tostring(zone.id)] = zone

	NETWORK.zone.Save()
	NETWORK.zone.Sync()
end

function NETWORK.zone.Delete(id)
	NETWORK.zone.list[tostring(id)] = nil
	NETWORK.zone.list[tonumber(id) or -1] = nil

	NETWORK.zone.Save()
	NETWORK.zone.Sync()
end

function NETWORK.zone.Clear()
	local count = table.Count(NETWORK.zone.list)

	NETWORK.zone.list = {}

	file.Delete(dataPath)

	NETWORK.zone.Save()
	NETWORK.zone.Sync()

	return count
end

function NETWORK.zone.SpawnLoot(zone)
	local ids = {}

	for id, count in pairs(zone.items or {}) do
		if (NETWORK.item.Get(id) and count > 0) then
			for _ = 1, count do
				ids[#ids + 1] = id
			end
		end
	end

	if (#ids == 0) then
		return
	end

	local existing = 0

	for _, entity in ipairs(ents.FindByClass("nw_item")) do
		if (entity.nwZone == zone.id) then
			existing = existing + 1
		end
	end

	local mins = NETWORK.zone.GetMins(zone)
	local maxs = NETWORK.zone.GetMaxs(zone)

	for _ = 1, math.min(zone.batch or 1, math.max((zone.total or 0) - existing, 0)) do
		local position = Vector(
			math.Rand(mins.x, maxs.x),
			math.Rand(mins.y, maxs.y),
			maxs.z - 4
		)

		local trace = util.TraceLine({
			start = position,
			endpos = Vector(position.x, position.y, mins.z - 16),
			mask = MASK_SOLID_BRUSHONLY
		})

		local entity = ents.Create("nw_item")

		if (!IsValid(entity)) then
			return
		end

		entity:SetPos((trace.Hit and trace.HitPos or position) + Vector(0, 0, 6))
		entity:SetAngles(Angle(0, math.random(0, 360), 0))
		entity:SetItem(NETWORK.item.New(ids[math.random(#ids)]))
		entity:Spawn()
		entity:Activate()

		entity.nwZone = zone.id
	end
end

function NETWORK.zone.GetRadProtection(client)
	local state = NETWORK.inventory and NETWORK.inventory.GetState and
		NETWORK.inventory.GetState(client)
	local total = 0

	for _, item in pairs(state and state.equipped or {}) do
		local base = istable(item) and NETWORK.item.Get(item.id)

		if (base and isnumber(base.radProtection)) then
			total = total + base.radProtection
		end
	end

	return math.Clamp(total, 0, 0.9)
end

local function ApplyHazard(client, zone, hazard, interval)

	if (zone.type == "toxic" and NETWORK.zone.IsToxicImmune(client)) then
		return
	end

	local levelKey = hazard.level
	local field = "nw" .. zone.type .. "Dose"
	local dose = math.min((client[field] or 0) + interval, 12)

	client[field] = dose
	client.nwHazardSeen = client.nwHazardSeen or {}
	client.nwHazardSeen[zone.type] = CurTime()
	client:SetNWFloat(levelKey, dose / 12)

	local ramp = math.Clamp(dose / 12, 0, 1)
	local amount = (tonumber(zone.damage) or 4) * (0.25 + ramp * 1.75)

	local bMask = client:GetNWBool("nwGasmask", false) and
		client:GetNWFloat("nwGasmaskFilter", 0) > os.time()

	if (zone.type == "radiation") then
		local protection = NETWORK.zone.GetRadProtection(client)

		if (bMask) then
			protection = math.min(protection + 0.3, 0.9)
		end

		amount = amount * (1 - protection)
	end

	if (amount <= 0) then
		return
	end

	local info = DamageInfo()

	info:SetDamage(amount)
	info:SetDamageType(hazard.damageType)
	info:SetAttacker(game.GetWorld())
	info:SetInflictor(game.GetWorld())
	info:SetDamagePosition(client:GetPos())

	client:TakeDamageInfo(info)

	if (dose <= interval * 2) then
		client:EmitSound(zone.type == "radiation" and "player/geiger3.wav" or
			"player/pl_pain5.wav", 60, 100)
	end
end

timer.Create("nwZoneThink", 1, 0, function()
	local time = CurTime()
	local inside = {}

	for _, zone in pairs(NETWORK.zone.list) do
		local hazard = NETWORK.zone.hazards[zone.type or ""]

		if (hazard) then
			if ((zone.nextDamage or 0) < time) then
				local interval = math.max(tonumber(zone.interval) or 2, 0.5)

				zone.nextDamage = time + interval

				for _, client in ipairs(player.GetAll()) do
					if (!client:Alive() or !client:HasCharacter()) then
						continue
					end

					if (NETWORK.zone.ContainsEntity(zone, client)) then
						inside[client] = inside[client] or {}
						inside[client][zone.type] = true

						ApplyHazard(client, zone, hazard, interval)
					end
				end
			end
		elseif (zone.type == "loot") then
			if ((zone.nextSpawn or 0) < time) then
				zone.nextSpawn = time + math.max(tonumber(zone.spawnInterval) or 60, 5)

				NETWORK.zone.SpawnLoot(zone)
			end
		end
	end

	for _, client in ipairs(player.GetAll()) do
		for kind, hazard in pairs(NETWORK.zone.hazards) do
			local field = "nw" .. kind .. "Dose"
			local seen = client.nwHazardSeen and client.nwHazardSeen[kind] or 0

			if ((client[field] or 0) > 0 and time - seen > 2.5) then
				client[field] = math.max(client[field] - 1.5, 0)
				client:SetNWFloat(hazard.level, client[field] / 12)
			end
		end
	end
end)

hook.Add("PlayerSpawn", "nwZoneDose", function(client)
	for kind, hazard in pairs(NETWORK.zone.hazards) do
		client["nw" .. kind .. "Dose"] = 0
		client:SetNWFloat(hazard.level, 0)
	end
end)

net.Receive("nwZoneEdit", function(_, client)
	if (!client:IsAdmin()) then
		return
	end

	local action = net.ReadString()
	local payload = NETWORK.util.ReadTable()

	local data = payload.data or {}

	data.id = nil
	data.mins = nil
	data.maxs = nil
	data.nextSpawn = nil
	data.nextDamage = nil

	if (action == "create") then
		if (!istable(payload.mins) or !istable(payload.maxs)) then
			return
		end

		local zone = NETWORK.zone.Default()

		table.Merge(zone, data)

		zone.id = NETWORK.zone.NextID()
		zone.mins = payload.mins
		zone.maxs = payload.maxs

		NETWORK.zone.Normalise(zone)

		local mins = NETWORK.zone.GetMins(zone)
		local maxs = NETWORK.zone.GetMaxs(zone)

		if (maxs.x - mins.x < 8 or maxs.y - mins.y < 8) then
			return
		end

		if (maxs.z - mins.z < 128) then
			zone.maxs[3] = zone.mins[3] + 128
		end

		NETWORK.zone.Set(zone)

		NETWORK.util.Print(string.format("%s создал зону #%d (%s)", client:SteamID(),
			zone.id, zone.name))

		return
	end

	if (action == "update") then
		local zone = NETWORK.zone.Get(payload.id)

		if (!zone) then
			NETWORK.util.PrintWarning("Правка зоны #" .. tostring(payload.id) ..
				": такой зоны нет.")

			return
		end

		table.Merge(zone, data)

		if (istable(payload.mins) and istable(payload.maxs)) then
			local previous = {mins = zone.mins, maxs = zone.maxs}

			zone.mins = payload.mins
			zone.maxs = payload.maxs

			NETWORK.zone.Normalise(zone)

			local mins = NETWORK.zone.GetMins(zone)
			local maxs = NETWORK.zone.GetMaxs(zone)

			if (maxs.x - mins.x < 8 or maxs.y - mins.y < 8) then
				zone.mins = previous.mins
				zone.maxs = previous.maxs
			elseif (maxs.z - mins.z < 128) then
				zone.maxs[3] = zone.mins[3] + 128
			end

			NETWORK.util.Print(string.format("%s переснял границы зоны #%s",
				client:SteamID(), tostring(zone.id)))
		end

		NETWORK.zone.Set(zone)

		return
	end

	if (action == "delete") then
		NETWORK.zone.Delete(payload.id)
	end
end)

hook.Add("PlayerInitialSpawn", "nwZone", function(client)
	timer.Simple(1.2, function()
		if (IsValid(client)) then
			NETWORK.zone.Sync(client)
		end
	end)
end)

hook.Add("Initialize", "nwZone", function()
	NETWORK.zone.Load()
end)

NETWORK.command.Register("areaedit", {
	description = "cmdAreaedit",
	usage = "/areaedit",
	adminOnly = true,
	OnRun = function(command, client)
		net.Start("nwZoneEditor")
			net.WriteString("toggle")
			NETWORK.util.WriteTable({})
		net.Send(client)
	end
})

NETWORK.command.Register("zoneclear", {
	adminOnly = true,
	description = "cmdZoneClear",
	usage = "/zoneclear",
	OnRun = function(command, client)
		local count = NETWORK.zone.Clear()

		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(L("zoneCleared", count))
		net.Send(client)
	end
})

concommand.Add("network_zones_clear", function(client)
	if (IsValid(client) and !client:IsSuperAdmin()) then
		return
	end

	NETWORK.util.Print("Зон удалено: " .. NETWORK.zone.Clear())
end, nil, "Удаляет все зоны и их файл сохранения")
