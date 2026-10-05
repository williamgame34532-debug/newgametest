NETWORK.ration = NETWORK.ration or {}

NETWORK.ration.quota = 4
NETWORK.ration.range = 150

NETWORK.ration.items = {
	ration_basic = true,
	ration_standard = true,
	ration_premium = true
}

function NETWORK.ration.IsRation(id)
	return NETWORK.ration.items[id] == true
end

function NETWORK.ration.GetMade()
	return GetGlobalInt("nwRationsMade", 0)
end

function NETWORK.ration.GetDelivered()
	return GetGlobalInt("nwRationsDone", 0)
end

function NETWORK.ration.GetLeft()
	return math.max(NETWORK.ration.quota - NETWORK.ration.GetMade(), 0)
end

if (CLIENT) then
	return
end

function NETWORK.ration.SetMade(amount)
	SetGlobalInt("nwRationsMade", math.max(math.floor(amount or 0), 0))
end

function NETWORK.ration.SetDelivered(amount)
	SetGlobalInt("nwRationsDone", math.max(math.floor(amount or 0), 0))
end

local bShift

timer.Create("nwRationShift", 10, 0, function()
	local bNow = NETWORK.schedule.IsFactoryShift()

	if (bShift == nil) then
		bShift = bNow

		return
	end

	if (bNow == bShift) then
		return
	end

	bShift = bNow

	if (bNow) then
		NETWORK.ration.SetMade(0)
		NETWORK.ration.SetDelivered(0)
	end
end)

function NETWORK.ration.AddWorker(list, client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return list
	end

	local id = tostring(client:GetCharacterID())

	for _, entry in ipairs(list) do
		if (entry.id == id) then
			return list
		end
	end

	list[#list + 1] = {id = id, name = client:GetCharacterName()}

	return list
end

local function FindByCharacter(id)
	for _, target in ipairs(player.GetAll()) do
		if (target:HasCharacter() and
			tostring(target:GetCharacterID()) == id) then
			return target
		end
	end
end

function NETWORK.ration.Credit(client, crew)
	crew = istable(crew) and crew or {}

	local paid = {}

	if (IsValid(client) and client:HasCharacter()) then
		local amount = math.random(3, 4)

		NETWORK.currency.Add(client, amount)
		NETWORK.chat.Notice(client, "rationPaidSelf")

		hook.Run("NetworkRationPaid", client, amount)

		paid[tostring(client:GetCharacterID())] = true

		if (math.random() <= 0.12) then
			NETWORK.loyalty.Add(client, 1, "factory")
			NETWORK.chat.Notice(client, "factoryLoyalty")
		end
	end

	local helpers = 0

	for _, entry in ipairs(crew) do
		if (paid[entry.id]) then
			continue
		end

		paid[entry.id] = true

		local target = FindByCharacter(entry.id)

		if (!IsValid(target)) then
			continue
		end

		helpers = helpers + 1

		local share = math.random(1, 2)

		NETWORK.currency.Add(target, share)
		NETWORK.chat.Notice(target, "rationPaidCrew")

		hook.Run("NetworkRationPaid", target, share)

		if (math.random() <= 0.08) then
			NETWORK.loyalty.Add(target, 1, "factory")
		end
	end

	NETWORK.ration.SetDelivered(NETWORK.ration.GetDelivered() + 1)

	return helpers
end

NETWORK.container.Register("ration_bin", {
	name = "Приёмник пайков",
	description = "Сюда сдают собранные пайки. Норма считается по сданному, а не по собранному.",
	model = "models/props_wasteland/controlroom_storagecloset001a.mdl",
	slots = 8,
	minItems = 0,
	maxItems = 0,
	loot = {}
})

function NETWORK.ration.IsBin(entity)
	return IsValid(entity) and entity.GetContainerID and
		entity:GetContainerID() == "ration_bin"
end

function NETWORK.ration.CountStock(entity)
	local count = 0

	for _, item in pairs(entity.items or {}) do
		if (istable(item) and NETWORK.ration.IsRation(item.id)) then
			count = count + (item.amount or 1)
		end
	end

	return count
end

if (SERVER) then
	function NETWORK.ration.UpdateStock(entity)
		if (IsValid(entity)) then
			entity:SetNWInt("nwBinStock", NETWORK.ration.CountStock(entity))
		end
	end

	timer.Create("nwRationBinStock", 2, 0, function()
		for _, entity in ipairs(ents.GetAll()) do
			if (NETWORK.ration.IsBin(entity)) then
				NETWORK.ration.UpdateStock(entity)
			end
		end
	end)

	hook.Add("NetworkContainerCanTake", "nwRationBin", function(client, entity, item)
		if (!NETWORK.ration.IsBin(entity)) then
			return
		end

		if (!NETWORK.factions.IsAlliance(client) and !NETWORK.factions.IsCWU(client)) then
			NETWORK.chat.Notice(client, "rationBinStaffOnly")

			return false
		end
	end)

	hook.Add("NetworkCmbTasks", "nwRationBin", function(client, list)
		if (!NETWORK.factions.IsCWU(client)) then
			return
		end

		for _, entity in ipairs(ents.GetAll()) do
			if (NETWORK.ration.IsBin(entity) and NETWORK.ration.CountStock(entity) > 0) then
				local zone = NETWORK.zone and NETWORK.zone.At and NETWORK.zone.At(entity:GetPos())

				list[#list + 1] = {
					name = L("cwuTaskRations", NETWORK.ration.CountStock(entity)),
					kind = "maint",
					class = "ration_bin",
					zone = zone and (zone.name or zone.id) or "",
					distance = math.Round(client:GetPos():Distance(entity:GetPos()) * 0.0254),
					position = {entity:GetPos().x, entity:GetPos().y, entity:GetPos().z}
				}
			end
		end
	end)
end

hook.Add("NetworkContainerStored", "nwRationBin", function(client, entity, item,
	list, index)
	if (list != "container" or !NETWORK.ration.IsBin(entity)) then
		return
	end

	if (!istable(item)) then
		return
	end

	if (!NETWORK.ration.IsRation(item.id)) then
		return NETWORK.chat.Notice(client, "rationBinWrong")
	end

	item.data = item.data or {}

	if (item.data.credited) then
		return
	end

	local amount = item.amount or 1
	local crew = item.data.crew

	item.data.credited = true
	item.data.crew = nil

	entity:EmitSound("physics/cardboard/cardboard_box_impact_soft" ..
		math.random(1, 3) .. ".wav", 65, math.random(96, 104))

	for _ = 1, amount do
		NETWORK.ration.Credit(client, crew)
	end

	if (NETWORK.factorywork and NETWORK.factorywork.CreditDelivered) then
		NETWORK.factorywork.CreditDelivered(client, amount)
	end

	NETWORK.container.Sync(entity)
	NETWORK.ration.UpdateStock(entity)
	NETWORK.ration.ClearWaypoint(client)

	NETWORK.log.Add("item", string.format("%s сдал паёк (%s) в приёмник",
		NETWORK.log.Name(client), item.id), entity:GetPos())
end)

NETWORK.ration.waypointKind = "ration"

function NETWORK.ration.IsStaff(client)
	return NETWORK.factions.IsAlliance(client) or NETWORK.factions.IsCWU(client)
end

function NETWORK.ration.FindNearest(origin, check)
	local best, bestDistance

	for _, entity in ipairs(ents.GetAll()) do
		if (check(entity)) then
			local distance = origin:DistToSqr(entity:GetPos())

			if (!best or distance < bestDistance) then
				best = entity
				bestDistance = distance
			end
		end
	end

	return best
end

function NETWORK.ration.FindBin(origin)
	return NETWORK.ration.FindNearest(origin, NETWORK.ration.IsBin)
end

function NETWORK.ration.FindDispenser(origin)
	return NETWORK.ration.FindNearest(origin, function(entity)
		return entity:GetClass() == "nw_dispenser"
	end)
end

function NETWORK.ration.ClearWaypoint(client)
	if (!IsValid(client) or !NETWORK.waypoint or !NETWORK.waypoint.list) then
		return
	end

	local bChanged = false

	for index = #NETWORK.waypoint.list, 1, -1 do
		local point = NETWORK.waypoint.list[index]

		if (point.owner == client:SteamID64() and point.kind == NETWORK.ration.waypointKind) then
			table.remove(NETWORK.waypoint.list, index)
			bChanged = true
		end
	end

	if (bChanged) then
		NETWORK.waypoint.Sync()
	end
end

function NETWORK.ration.PointAt(client, entity, key)
	if (!IsValid(client) or !IsValid(entity) or !NETWORK.waypoint or !NETWORK.waypoint.Add) then
		return
	end

	NETWORK.ration.ClearWaypoint(client)
	NETWORK.waypoint.Add(client, entity:GetPos() + Vector(0, 0, 40), L(key),
		Color(240, 178, 70), 900, true, NETWORK.ration.waypointKind)
end

function NETWORK.ration.MarkBin(terminal, crew)
	local bin = IsValid(terminal) and NETWORK.ration.FindBin(terminal:GetPos())

	if (!IsValid(bin)) then
		return
	end

	for _, entry in ipairs(crew or {}) do
		for _, target in ipairs(player.GetAll()) do
			if (target:HasCharacter() and tostring(target:GetCharacterID()) == entry.id) then
				NETWORK.ration.PointAt(target, bin, "rationWaypointBin")

				break
			end
		end
	end
end

function NETWORK.ration.QuickTake(client, entity)
	if (!NETWORK.ration.IsBin(entity) or !NETWORK.ration.IsStaff(client)) then
		return false
	end

	if (client:KeyDown(IN_SPEED)) then
		return false
	end

	if (NETWORK.ration.CountStock(entity) <= 0) then
		NETWORK.chat.Notice(client, "rationBinEmpty")

		return true
	end

	for index, item in pairs(entity.items or {}) do
		if (istable(item) and NETWORK.ration.IsRation(item.id)) then
			local amount = item.amount or 1
			local data = item.data

			if (amount > 1) then
				item.amount = amount - 1
			else
				entity.items[index] = nil
			end

			local given = NETWORK.inventory.Give(client, item.id, 1, data)

			if (!given) then

				if (amount > 1) then
					item.amount = amount
				else
					entity.items[index] = item
				end

				NETWORK.chat.Notice(client, "rationNoRoom")

				return true
			end

			NETWORK.container.Sync(entity)
			NETWORK.ration.UpdateStock(entity)

			entity:EmitSound("items/ammocrate_open.wav", 60, math.random(96, 104))
			NETWORK.chat.Notice(client, "rationTaken")

			local dispenser = NETWORK.ration.FindDispenser(entity:GetPos())

			if (IsValid(dispenser)) then
				NETWORK.ration.PointAt(client, dispenser, "rationWaypointDispenser")
			end

			NETWORK.log.Add("item", string.format("%s взял паёк (%s) из приёмника",
				NETWORK.log.Name(client), item.id), entity:GetPos())

			return true
		end
	end

	return false
end
