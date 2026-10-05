local S = NETWORK.supply

S.orders = S.orders or {}
S.fund = S.fund or S.fundMax
S.nextID = S.nextID or 1

local dataPath = "network/supply.txt"

local function Notice(client, key, tone, ...)
	NETWORK.notice.Send(client, key, tone, ...)
end

local function NoticeFaction(check, key, tone, ...)
	for _, client in ipairs(player.GetAll()) do
		if (client:HasCharacter() and check(client)) then
			Notice(client, key, tone, ...)
		end
	end
end

function S.Save()
	local orders = {}

	for _, order in ipairs(S.orders) do

		if (order.status == "pending" or order.status == "delivered" or
			order.status == "assigned" or order.status == "transit") then

			orders[#orders + 1] = {
				id = order.id,
				entry = order.entry,
				by = order.by,
				time = order.time,
				status = order.status == "delivered" and "delivered" or "pending"
			}
		end
	end

	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON({fund = S.fund, nextID = S.nextID, orders = orders}))
end

function S.Load()
	local data = util.JSONToTable(file.Read(dataPath, "DATA") or "") or {}

	S.fund = tonumber(data.fund) or S.fundMax
	S.nextID = tonumber(data.nextID) or 1
	S.orders = {}

	local seen = {}

	for _, order in ipairs(data.orders or {}) do
		if (S.GetEntry(order.entry) and !seen[order.id] and #S.orders < S.maxActive) then
			seen[order.id] = true
			order.time = CurTime()
			order.bRespawn = order.status == "delivered" or nil
			S.orders[#S.orders + 1] = order
		end
	end
end

function S.Get(id)
	for _, order in ipairs(S.orders) do
		if (order.id == id) then
			return order
		end
	end
end

function S.CountActive()
	local count = 0

	for _, order in ipairs(S.orders) do
		if (order.status == "pending" or order.status == "assigned" or
			order.status == "transit" or order.status == "delivered") then
			count = count + 1
		end
	end

	return count
end

local function GetDepots()
	local list = ents.FindByClass("nw_supply_depot")

	if (#list == 0) then
		list = ents.FindByClass("nw_cwuterminal")
	end

	return list
end

local function GetPoints()
	local list = ents.FindByClass("nw_supply_point")

	if (#list == 0) then
		list = ents.FindByClass("nw_cmbterminal")
	end

	return list
end

local function PickOne(list)
	if (#list == 0) then
		return
	end

	return list[math.random(#list)]
end

local function Nearest(list, position)
	local best, bestDistance

	for _, entity in ipairs(list) do
		local distance = entity:GetPos():DistToSqr(position)

		if (!bestDistance or distance < bestDistance) then
			best, bestDistance = entity, distance
		end
	end

	return best
end

function S.FindSpot(entity)
	local center = entity:WorldSpaceCenter()
	local yaw = entity:GetAngles().y
	local mins, maxs = Vector(-16, -16, 0), Vector(16, 16, 28)

	for _, distance in ipairs({56, 84, 120}) do
		for _, offset in ipairs({0, 180, 90, -90, 45, -45, 135, -135}) do
			local direction = Angle(0, yaw + offset, 0):Forward()
			local probe = center + direction * distance
			local down = util.TraceLine({
				start = probe + Vector(0, 0, 24),
				endpos = probe - Vector(0, 0, 220),
				filter = entity,
				mask = MASK_SOLID
			})

			if (down.Hit and !down.StartSolid) then
				local ground = down.HitPos + Vector(0, 0, 2)
				local hull = util.TraceHull({
					start = ground,
					endpos = ground,
					mins = mins,
					maxs = maxs,
					filter = entity,
					mask = MASK_SOLID
				})
				local sight = util.TraceLine({
					start = center,
					endpos = ground + Vector(0, 0, 14),
					filter = entity,
					mask = MASK_SOLID_BRUSHONLY
				})

				if (!hull.Hit and !hull.StartSolid and !sight.Hit) then
					return ground
				end
			end
		end
	end

	return center + Vector(0, 0, 48)
end

S.GetDepots = GetDepots
S.GetPoints = GetPoints
S.Nearest = Nearest

S.packTime = 4

function S.CountPending()
	local count = 0

	for _, order in ipairs(S.orders) do
		if (order.status == "pending") then
			count = count + 1
		end
	end

	return count
end

function S.UseDepot(client, depot)
	if (!NETWORK.factions.IsCWU(client)) then
		return Notice(client, "supplyDepotOnlyCWU", "bad")
	end

	if (client.nwSupplyPacking) then
		return
	end

	for _, order in ipairs(S.orders) do
		if (order.status == "assigned" and order.worker == client) then
			if (S.ShowRoute(client, order)) then
				return Notice(client, "supplyRouteShown", "good")
			end
		end
	end

	local target

	for _, order in ipairs(S.orders) do
		if (order.status == "pending") then
			target = order

			break
		end
	end

	if (!target) then
		return Notice(client, "supplyNoPending", "warn")
	end

	client.nwSupplyPacking = target.id

	net.Start("nwProgress")
		net.WriteString("supplyPacking")
		net.WriteFloat(S.packTime)
	net.Send(client)

	NETWORK.chat.Send(client, "me", L("supplyPackingMe"))

	local timerID = "nwSupplyPack" .. client:EntIndex()
	local finish = CurTime() + S.packTime

	timer.Create(timerID, 0.2, 0, function()
		if (!IsValid(client) or !IsValid(depot) or !client:Alive() or
			client:GetPos():Distance(depot:GetPos()) > 160) then
			timer.Remove(timerID)

			if (IsValid(client)) then
				client.nwSupplyPacking = nil

				net.Start("nwProgress")
					net.WriteString("")
					net.WriteFloat(0)
				net.Send(client)

				Notice(client, "supplyPackCancelled", "warn")
			end

			return
		end

		if (CurTime() < finish) then
			return
		end

		timer.Remove(timerID)

		client.nwSupplyPacking = nil

		local bOk, key = S.Take(client, target.id, depot)

		Notice(client, key, bOk and "good" or "bad")
	end)
end

function S.RefreshTerminals()
	SetGlobalInt("nwSupplyPending", S.CountPending())

	for _, client in ipairs(player.GetAll()) do
		if (client.nwCmbPage == "supply") then
			NETWORK.cmbterm.Refresh(client)
		end
	end
end

function S.Waybill(order)
	if (NETWORK.mail and NETWORK.mail.SupplyWaybill) then
		NETWORK.mail.SupplyWaybill(order)
	end
end

function S.Order(client, id)
	local entry = S.GetEntry(id)

	if (!entry) then
		return false
	end

	if (!S.CanOrder(client)) then
		return false, "supplyOnlyCmd"
	end

	if (S.CountActive() >= S.maxActive) then
		return false, "supplyTooMany"
	end

	if (S.fund < entry.cost) then
		return false, "supplyNoFund"
	end

	S.fund = S.fund - entry.cost

	local order = {
		id = S.nextID,
		entry = entry.id,
		by = client:GetCharacterName(),
		time = CurTime(),
		status = "pending"
	}

	S.nextID = S.nextID + 1
	S.orders[#S.orders + 1] = order

	S.Waybill(order)

	local bWorkers = false

	for _, other in ipairs(player.GetAll()) do
		if (NETWORK.factions.IsCWU(other)) then
			bWorkers = true

			break
		end
	end

	if (bWorkers) then
		NoticeFaction(NETWORK.factions.IsCWU, "supplyNewOrder", "info", L(entry.name))
	else
		S.StartAuto(order)
	end

	S.Save()
	S.RefreshTerminals()

	return true, "supplyOrdered", L(entry.name)
end

function S.Cancel(client, id)
	if (!S.CanOrder(client)) then
		return false, "supplyOnlyCmd"
	end

	local order = S.Get(id)

	if (!order or order.status != "pending") then
		return false, "supplyCantCancel"
	end

	local entry = S.GetEntry(order.entry)

	order.status = "cancelled"
	S.Waybill(order)
	S.fund = math.min(S.fund + (entry and entry.cost or 0), S.fundMax)

	S.Save()
	S.RefreshTerminals()

	return true, "supplyCancelled"
end

function S.SpawnCrate(order, position, angles)

	if (IsValid(order.crate)) then
		return order.crate
	end

	for _, existing in ipairs(ents.FindByClass("nw_supply_crate")) do
		if (existing:GetOrderID() == order.id) then
			order.crate = existing

			return existing
		end
	end

	local crate = ents.Create("nw_supply_crate")

	if (!IsValid(crate)) then
		return
	end

	crate:SetPos(position)
	crate:SetAngles(angles or angle_zero)
	crate:Spawn()
	crate:Activate()

	crate:SetPos(position - Vector(0, 0, crate:OBBMins().z - 1))

	crate:SetOrderID(order.id)
	crate:SetOrderName(L(S.GetEntry(order.entry).name))

	crate.nwSpawnPos = crate:GetPos()

	order.crate = crate

	return crate
end

function S.ShowRoute(client, order)
	if (!NETWORK.waypoint or !NETWORK.waypoint.Add) then
		return false
	end

	local crate = order.crate

	if (!IsValid(crate)) then
		return false
	end

	local point = Nearest(GetPoints(), crate:GetPos())

	NETWORK.waypoint.Add(client, crate:GetPos() + Vector(0, 0, 40),
		L("supplyWaypointDepot"), Color(240, 178, 70), 600, true)

	if (IsValid(point)) then
		NETWORK.waypoint.Add(client, point:GetPos() + Vector(0, 0, 60),
			L("supplyWaypointPoint"), Color(72, 196, 236), 900, true)
	end

	return true
end

function S.Take(client, id, depot)
	local order = S.Get(id)

	if (!order or order.status != "pending") then
		return false, "supplyTaken"
	end

	depot = IsValid(depot) and depot or Nearest(GetDepots(), client:GetPos())
	local crate

	if (IsValid(depot)) then
		crate = S.SpawnCrate(order, S.FindSpot(depot), Angle(0, depot:GetAngles().y, 0))
	else

		crate = S.SpawnCrate(order, S.FindSpot(client))
	end

	if (!IsValid(crate)) then
		return false, "supplyNoDepot"
	end

	order.status = "assigned"
	order.worker = client

	S.ShowRoute(client, order)

	order.workerName = client:GetCharacterName()
	S.Waybill(order)

	S.RefreshTerminals()

	NoticeFaction(NETWORK.factions.IsAlliance, "supplyAssigned", "info", order.workerName,
		L(S.GetEntry(order.entry).name))

	return true, "supplyTakeDone"
end

function S.Drop(client, id)
	local order = S.Get(id)

	if (!order or order.status != "assigned") then
		return false, "supplyNotYours"
	end

	if (order.worker != client and !client:IsAdmin()) then
		return false, "supplyNotYours"
	end

	if (IsValid(order.crate)) then
		order.crate:Remove()
	end

	order.crate = nil
	order.worker = nil
	order.workerName = nil
	order.status = "pending"

	S.Waybill(order)
	S.RefreshTerminals()

	NoticeFaction(NETWORK.factions.IsAlliance, "supplyDropped", "warn",
		client:GetCharacterName(), L(S.GetEntry(order.entry).name))

	return true, "supplyDropDone"
end

function S.StartAuto(order)
	order.status = "transit"
	order.workerName = L("supplyTransport")
	S.Waybill(order)
	order.autoAt = CurTime() + S.autoDelay
end

function S.Deliver(order, crate)
	if (order.status == "delivered" or order.status == "opened") then
		return
	end

	order.status = "delivered"
	S.Waybill(order)

	if (IsValid(crate)) then
		crate:SetDelivered(true)
	end

	local worker = order.worker

	if (IsValid(worker) and worker:HasCharacter()) then
		NETWORK.currency.Add(worker, S.workerPay)

		if (NETWORK.loyalty and NETWORK.loyalty.Add) then
			NETWORK.loyalty.Add(worker, 1, "supply")
		end

		Notice(worker, "supplyPaid", "good", S.workerPay)
	end

	NoticeFaction(NETWORK.factions.IsAlliance, "supplyArrived", "good",
		L(S.GetEntry(order.entry).name))

	S.Save()
	S.RefreshTerminals()
end

function S.Open(client, crate)
	local order = S.Get(crate:GetOrderID())

	if (!order) then
		crate:Remove()

		return
	end

	if (!NETWORK.factions.IsAlliance(client)) then
		return Notice(client, "supplySealed", "warn")
	end

	if (!crate:GetDelivered()) then

		if (#GetPoints() == 0) then
			S.Deliver(order, crate)
		else
			return Notice(client, "supplyNotDelivered", "warn")
		end
	end

	local entry = S.GetEntry(order.entry)
	local position = crate:GetPos() + Vector(0, 0, 24)

	for _, pair in ipairs(entry.items) do
		for _ = 1, pair[2] do
			if (!NETWORK.inventory.Give(client, pair[1], 1)) then
				NETWORK.item.Spawn(pair[1], position + VectorRand() * 12, nil, 1)
			end
		end
	end

	order.status = "opened"
	S.Waybill(order)

	crate:EmitSound("physics/wood/wood_crate_break" .. math.random(1, 5) .. ".wav", 70)
	crate:Remove()

	NETWORK.chat.Send(client, "me", L("supplyOpenMe"))

	S.Save()
	S.RefreshTerminals()
end

function S.Break(crate, attacker)
	local order = S.Get(crate:GetOrderID())

	if (order) then
		order.status = "lost"
	S.Waybill(order)

		local entry = S.GetEntry(order.entry)

		for _, pair in ipairs(entry.items) do
			for _ = 1, pair[2] do
				NETWORK.item.Spawn(pair[1], crate:GetPos() + VectorRand() * 16 +
					Vector(0, 0, 16), nil, 1)
			end
		end

		NoticeFaction(NETWORK.factions.IsAlliance, "supplyLost", "bad", L(entry.name))

		if (NETWORK.log and NETWORK.log.Add) then
			NETWORK.log.Add("admin", string.format("Ящик поставки #%d разбит: %s",
				order.id, NETWORK.log.Name(attacker)), crate:GetPos())
		end
	end

	local effect = EffectData()

	effect:SetOrigin(crate:WorldSpaceCenter())
	util.Effect("WoodImpact", effect)

	crate:EmitSound("physics/wood/wood_box_break" .. math.random(1, 2) .. ".wav", 75)
	crate:Remove()

	S.Save()
	S.RefreshTerminals()
end

timer.Create("nwSupply", 1, 0, function()
	SetGlobalInt("nwSupplyPending", S.CountPending())

	if ((S.nextRegen or 0) <= CurTime()) then
		S.nextRegen = CurTime() + S.fundInterval

		if (S.fund < S.fundMax) then
			S.fund = math.min(S.fund + S.fundRegen, S.fundMax)
		end
	end

	for index = #S.orders, 1, -1 do
		local order = S.orders[index]

		if (order.status == "pending" and CurTime() - order.time >= S.autoAfter) then
			S.StartAuto(order)
			S.RefreshTerminals()
		end

		if (order.status == "transit" and order.autoAt and order.autoAt <= CurTime()) then
			local point = PickOne(GetPoints())
			local position, angles

			if (IsValid(point)) then
				position = S.FindSpot(point)
				angles = Angle(0, point:GetAngles().y, 0)
			end

			if (!position) then
				local entry = S.GetEntry(order.entry)

				order.status = "cancelled"
				order.autoAt = nil
				S.fund = math.min(S.fund + (entry and entry.cost or 0), S.fundMax)
				S.Waybill(order)
				S.Save()
				S.RefreshTerminals()

				continue
			end

			local crate = S.SpawnCrate(order, position, angles)

			order.autoAt = nil

			if (IsValid(crate)) then
				crate.nwAuto = true
				crate:EmitSound("ambient/machines/wall_move4.wav", 70)
				S.Deliver(order, crate)
			end
		end

		if (order.status == "assigned" and !IsValid(order.crate)) then
			order.status = "pending"
			order.time = CurTime()
			order.worker = nil
			S.RefreshTerminals()
		end

		if ((order.status == "opened" or order.status == "lost" or
			order.status == "cancelled") and #S.orders > 20) then
			table.remove(S.orders, index)
		end
	end

	for _, point in ipairs(GetPoints()) do
		for _, crate in ipairs(ents.FindInSphere(point:GetPos(), S.deliverRange)) do

			if (crate:GetClass() == "nw_supply_crate" and !crate:GetDelivered() and
				(crate.nwAuto or crate:GetPos():Distance(crate.nwSpawnPos or
				crate:GetPos()) >= S.carryDistance)) then
				local order = S.Get(crate:GetOrderID())

				if (order) then
					S.Deliver(order, crate)
				end
			end
		end
	end
end)

function S.BuildPayload(client, kind)
	local orders = {}

	for index = #S.orders, 1, -1 do
		local order = S.orders[index]
		local entry = S.GetEntry(order.entry)

		orders[#orders + 1] = {
			id = order.id,
			name = entry and entry.name or "?",
			status = order.status,
			by = order.by,
			worker = order.workerName or "",
			bMine = order.worker == client,
			wait = math.max(math.floor(S.autoAfter - (CurTime() - order.time)), 0)
		}
	end

	local catalog = {}

	if (kind == "alliance") then
		for _, entry in ipairs(S.catalog) do
			local parts = {}

			for _, pair in ipairs(entry.items) do
				local base = NETWORK.item.Get(pair[1])

				parts[#parts + 1] = (base and base.name or pair[1]) .. " ×" .. pair[2]
			end

			catalog[#catalog + 1] = {
				id = entry.id,
				name = entry.name,
				cost = entry.cost,
				contents = table.concat(parts, ", ")
			}
		end
	end

	return {
		kind = kind,
		bCanOrder = S.CanOrder(client),
		fund = S.fund,
		fundMax = S.fundMax,
		catalog = catalog,
		orders = orders
	}
end

hook.Add("Initialize", "nwSupply", function()
	S.Load()
end)

hook.Add("InitPostEntity", "nwSupplyRespawn", function()
	timer.Simple(10, function()
		local changed = false

		for _, order in ipairs(S.orders) do
			if (!order.bRespawn) then
				continue
			end

			order.bRespawn = nil

			local point = PickOne(GetPoints())

			if (!IsValid(point)) then
				local entry = S.GetEntry(order.entry)

				order.status = "cancelled"
				S.fund = math.min(S.fund + (entry and entry.cost or 0), S.fundMax)
				changed = true

				continue
			end

			local crate = S.SpawnCrate(order, S.FindSpot(point), Angle(0, point:GetAngles().y, 0))

			if (IsValid(crate)) then
				crate.nwAuto = true
				crate:SetDelivered(true)
			end
		end

		if (changed) then
			S.Save()
		end

		S.RefreshTerminals()
	end)
end)

NETWORK.command.Register("supplyclear", {
	description = "cmdSupplyClear",
	usage = "/supplyclear",
	adminOnly = true,
	OnRun = function(command, client)
		local crates = 0

		for _, crate in ipairs(ents.FindByClass("nw_supply_crate")) do
			crate:Remove()
			crates = crates + 1
		end

		local orders = #S.orders

		for _, order in ipairs(S.orders) do
			local entry = S.GetEntry(order.entry)

			if (order.status == "pending" or order.status == "assigned" or
				order.status == "transit" or order.status == "delivered") then
				S.fund = math.min(S.fund + (entry and entry.cost or 0), S.fundMax)
			end
		end

		S.orders = {}
		S.Save()
		S.RefreshTerminals()

		NETWORK.notice.Send(client, "supplyCleared", "good", crates, orders)
	end
})

hook.Add("ShutDown", "nwSupply", function()
	S.Save()
end)
