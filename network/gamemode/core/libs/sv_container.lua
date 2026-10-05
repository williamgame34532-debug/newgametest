util.AddNetworkString("nwContainerOpen")
util.AddNetworkString("nwContainerSync")
util.AddNetworkString("nwContainerClose")
util.AddNetworkString("nwContainerAction")
util.AddNetworkString("nwContainerConfig")
util.AddNetworkString("nwContainerLoot")
util.AddNetworkString("nwProgress")

NETWORK.container.openTime = 3

NETWORK.container.range = 140

function NETWORK.container.Begin(client, entity)
	if (!IsValid(entity) or client.nwContainerPending) then
		return
	end

	if (!NETWORK.container.CheckLock(client, entity)) then
		return
	end

	client.nwContainerPending = entity
	client.nwContainerStart = client:GetPos()

	net.Start("nwProgress")
		net.WriteString("progressOpening")
		net.WriteFloat(NETWORK.container.openTime)
	net.Send(client)

	entity:EmitSound("physics/wood/wood_crate_impact_soft2.wav", 55, 95, 0.4)

	timer.Simple(NETWORK.container.openTime, function()
		if (!IsValid(client) or !IsValid(entity)) then
			return
		end

		local pending = client.nwContainerPending

		client.nwContainerPending = nil

		if (pending != entity or !client:Alive()) then
			return
		end

		if (client:GetPos():Distance(entity:GetPos()) > NETWORK.container.range) then
			net.Start("nwProgress")
				net.WriteString("")
				net.WriteFloat(0)
			net.Send(client)

			return
		end

		NETWORK.container.Open(client, entity)
	end)
end

function NETWORK.container.Open(client, entity)

	if (IsValid(entity) and entity:GetNWBool("nwCorpse", false)) then
		return
	end

	if (!IsValid(entity)) then
		return
	end

	if (!NETWORK.container.CheckLock(client, entity)) then
		return
	end

	NETWORK.container.Close(client)

	client.nwContainer = entity
	entity.viewers[client] = true

	client:SetNWBool("nwBusy", true)

	net.Start("nwContainerOpen")
		net.WriteEntity(entity)
	net.Send(client)

	NETWORK.container.Sync(entity, client)

	entity:EmitSound("physics/wood/wood_crate_impact_soft" .. math.random(1, 3) .. ".wav",
		60, 105)

	hook.Run("NetworkContainerOpened", client, entity)
end

function NETWORK.container.Close(client)
	local entity = client.nwContainer

	if (IsValid(entity)) then
		entity.viewers[client] = nil

		hook.Run("NetworkContainerClosed", client, entity)
	end

	client.nwContainer = nil

	client:SetNWBool("nwBusy", false)

	net.Start("nwContainerClose")
	net.Send(client)
end

function NETWORK.container.Sync(entity, target)
	if (!IsValid(entity)) then
		return
	end

	local receivers = {}

	if (IsValid(target)) then
		receivers[1] = target
	else
		for client in pairs(entity.viewers or {}) do
			if (IsValid(client)) then
				receivers[#receivers + 1] = client
			end
		end
	end

	if (#receivers == 0) then
		return
	end

	local payload = {}

	for index, item in pairs(entity.items or {}) do
		payload[tostring(index)] = item
	end

	net.Start("nwContainerSync")
		net.WriteEntity(entity)
		NETWORK.util.WriteTable(payload)
	net.Send(receivers)
end

NETWORK.container.classes = {
	nw_container = true,
	nw_ration_bin = true,
	nw_stash = true,

	nw_cache = true
}

function NETWORK.container.IsUsable(client, entity)
	return IsValid(entity) and
		NETWORK.container.classes[entity:GetClass()] == true and
		client.nwContainer == entity and
		client:GetPos():Distance(entity:GetPos()) <= NETWORK.container.range
end

local function Take(state, entity, list, index, slot)
	if (list == "container") then
		return entity.items[index]
	end

	return NETWORK.inventory.At(state, list, index, slot)
end

local function Put(state, entity, list, index, slot, item)
	if (list == "container") then
		entity.items[index] = item

		return
	end

	NETWORK.inventory.Put(state, list, index, slot, item)
end

local function ContainerGrid(entity)
	local columns = NETWORK.inventory.columns

	return columns, math.ceil(entity:GetContainerSlots() / columns)
end

local function CanPlace(state, entity, item, list, index, slot, fromList, ignore)
	if (list == "container") then
		local columns, rows = ContainerGrid(entity)

		return NETWORK.inventory.Fits(entity.items, columns, rows, item, index,
			fromList == "container" and ignore or nil)
	end

	return NETWORK.inventory.CanPlace(state, item, list, index, slot, fromList, ignore)
end

local RunContainerAction

net.Receive("nwContainerAction", function(_, client)
	local action = net.ReadString()
	local payload = NETWORK.util.ReadTable()

	if (!NETWORK.container.IsUsable(client, client.nwContainer)) then
		return
	end

	local ready = client.nwNextContainer or 0

	client.nwNextContainer = math.max(ready, CurTime()) + 0.06

	if (ready > CurTime()) then
		local queued = client.nwContainerQueue or 0

		if (queued >= 12) then
			return
		end

		client.nwContainerQueue = queued + 1

		timer.Simple(ready - CurTime(), function()
			if (IsValid(client)) then
				client.nwContainerQueue = math.max((client.nwContainerQueue or 1) - 1, 0)

				RunContainerAction(client, action, payload)
			end
		end)

		return
	end

	RunContainerAction(client, action, payload)
end)

function RunContainerAction(client, action, payload)
	local entity = client.nwContainer

	if (!NETWORK.container.IsUsable(client, entity)) then
		return
	end

	local state = NETWORK.inventory.GetState(client)

	if (action == "close") then
		NETWORK.container.Close(client)

		return
	end

	if (action == "move") then
		local item = Take(state, entity, payload.fromList, payload.fromIndex, payload.fromSlot)

		if (!item) then
			return
		end

		if (payload.rotate and NETWORK.item.CanRotate(item)) then
			item.rotated = !item.rotated or nil
		end

		local target = Take(state, entity, payload.toList, payload.toIndex, payload.toSlot)

		if (target == item) then
			return
		end

		if (!target and (payload.toList == "container" or payload.toList == "items")) then
			local list = payload.toList == "container" and entity.items or state.items
			local columns, rows

			if (payload.toList == "container") then
				columns, rows = ContainerGrid(entity)
			else
				columns, rows = NETWORK.inventory.columns, NETWORK.inventory.rows
			end

			local overlapping, count = NETWORK.inventory.GetOverlapping(list, columns, rows,
				item, payload.toIndex,
				payload.fromList == payload.toList and payload.fromIndex or nil)

			if (count == 1) then
				for owner in pairs(overlapping) do
					target = list[owner]
					payload.toIndex = owner
				end
			elseif (count > 1) then
				return
			end
		end

		if (!CanPlace(state, entity, item, payload.toList, payload.toIndex, payload.toSlot,
			payload.fromList, payload.fromIndex)) then
			return
		end

		if (payload.fromList == "container" and payload.toList != "container" and
			hook.Run("NetworkContainerCanTake", client, entity, item) == false) then
			return
		end

		if (target and !CanPlace(state, entity, target, payload.fromList, payload.fromIndex,
			payload.fromSlot, payload.toList, payload.toIndex)) then
			return
		end

		Put(state, entity, payload.toList, payload.toIndex, payload.toSlot, item)
		Put(state, entity, payload.fromList, payload.fromIndex, payload.fromSlot, target)

		NETWORK.inventory.Sync(client)
		NETWORK.container.Sync(entity)

		hook.Run("NetworkContainerStored", client, entity, item,
			payload.toList, payload.toIndex)

		return
	end

	if (action == "split") then
		local fromList = payload.fromList or "items"
		local toList = payload.toList or fromList

		if (fromList != "container" and toList != "container") then
			NETWORK.inventory.SplitStack(state, payload)
			NETWORK.inventory.Sync(client)

			return
		end

		local item = Take(state, entity, fromList, payload.fromIndex, payload.fromSlot)

		if (!item) then
			return
		end

		local total = item.amount or 1

		if (total <= 1) then
			return
		end

		local amount = math.Clamp(math.Round(tonumber(payload.amount) or 1), 1, total - 1)
		local piece = {
			id = item.id,
			amount = amount,
			data = table.Copy(item.data or {}),
			rotated = item.rotated
		}

		local list, columns, rows

		if (toList == "container") then
			list = entity.items
			columns, rows = ContainerGrid(entity)
		elseif (toList == "items") then
			list = state.items
			columns, rows = NETWORK.inventory.columns, NETWORK.inventory.rows
		else
			return
		end

		local index = tonumber(payload.toIndex)

		if (index) then
			local target = list[index]

			if (target and target != item and NETWORK.item.CanStack(target, piece)) then
				local room = NETWORK.item.GetMaxStack(piece) - (target.amount or 1)

				amount = math.min(amount, room)

				if (amount <= 0) then
					return
				end

				target.amount = (target.amount or 1) + amount
				item.amount = total - amount

				NETWORK.inventory.Sync(client)
				NETWORK.container.Sync(entity)

				return
			end

			if (target or !NETWORK.inventory.Fits(list, columns, rows, piece, index)) then
				return
			end
		else
			index = NETWORK.inventory.FindSpot(list, columns, rows, piece)

			if (!index) then
				return
			end
		end

		list[index] = piece
		item.amount = total - amount

		NETWORK.inventory.Sync(client)
		NETWORK.container.Sync(entity)

		return
	end

	if (action == "swap") then
		local items = {}
		local container = {}

		for index = 1, NETWORK.inventory.GetSize() do
			items[index] = state.items[index]
		end

		for index = 1, entity:GetContainerSlots() do
			container[index] = entity.items[index]
		end

		state.items = {}
		entity.items = {}

		for index = 1, entity:GetContainerSlots() do
			if (container[index]) then
				local free = NETWORK.inventory.FindSpot(state.items,
					NETWORK.inventory.columns, NETWORK.inventory.rows, container[index])

				if (free) then
					state.items[free] = container[index]
				else
					entity.items[index] = container[index]
				end
			end
		end

		for index = 1, NETWORK.inventory.GetSize() do
			if (items[index]) then
				local columns, rows = ContainerGrid(entity)
				local free = NETWORK.inventory.FindSpot(entity.items, columns, rows,
					items[index])

				if (free) then
					entity.items[free] = items[index]
				else
					local back = NETWORK.inventory.FindSpot(state.items,
						NETWORK.inventory.columns, NETWORK.inventory.rows, items[index])

					if (back) then
						state.items[back] = items[index]
					end
				end
			end
		end

		NETWORK.inventory.Sync(client)
		NETWORK.container.Sync(entity)
	end
end

net.Receive("nwContainerConfig", function(_, client)
	if (!client:IsAdmin()) then
		return
	end

	local entity = net.ReadEntity()
	local payload = NETWORK.util.ReadTable()

	if (!IsValid(entity) or entity:GetClass() != "nw_container") then
		return
	end

	entity:SetContainerName(NETWORK.util.Sanitise(payload.name, 48))
	entity:SetContainerDescription(NETWORK.util.Sanitise(payload.description, 200, true))

	entity:SetContainerRefill(math.Clamp(math.Round(tonumber(payload.refill) or 0),
		0, 1440))

	entity.nwEmptySince = nil
end)

net.Receive("nwContainerLoot", function(_, client)
	if (!client:IsAdmin()) then
		return
	end

	local entity = net.ReadEntity()
	local payload = NETWORK.util.ReadTable()

	if (!IsValid(entity) or entity:GetClass() != "nw_container") then
		return
	end

	entity.items = {}

	local slot = 1

	for id, count in pairs(payload) do
		for _ = 1, math.min(tonumber(count) or 0, 64) do
			if (slot > entity:GetContainerSlots()) then
				break
			end

			local item = NETWORK.item.New(id)

			if (item) then
				entity.items[slot] = item

				slot = slot + 1
			end
		end
	end

	NETWORK.container.Sync(entity)
end)

hook.Add("Think", "nwContainerRange", function()
	if (!NETWORK.util.Throttle("container.range", 0.25)) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		local entity = client.nwContainer

		if (!IsValid(entity)) then
			if (entity != nil) then
				NETWORK.container.Close(client)
			end

			continue
		end

		if (client:GetPos():Distance(entity:GetPos()) > NETWORK.container.range) then
			NETWORK.container.Close(client)
		end
	end
end)

hook.Add("PlayerDisconnected", "nwContainer", function(client)
	NETWORK.container.Close(client)
end)

concommand.Add("network_container_spawn", function(client, _, arguments)
	if (IsValid(client) and !client:IsAdmin()) then
		return
	end

	local data = NETWORK.container.Get(arguments[1] or "crate")
	local trace = client:GetEyeTrace()
	local entity = ents.Create("nw_container")

	if (!IsValid(entity)) then
		return
	end

	entity.ContainerType = data.id
	entity.model = data.model

	entity:SetPos(trace.HitPos + Vector(0, 0, 16))
	entity:SetAngles(Angle(0, client:EyeAngles().y + 180, 0))
	entity:Spawn()
	entity:Activate()
	entity:DropToFloor()
end)

hook.Add("StartCommand", "nwContainerFreeze", function(client, cmd)
	if (!client:GetNWBool("nwBusy", false)) then
		return
	end

	cmd:ClearMovement()
	cmd:RemoveKey(IN_JUMP)
	cmd:RemoveKey(IN_SPEED)
	cmd:RemoveKey(IN_ATTACK)
	cmd:RemoveKey(IN_ATTACK2)
end)

hook.Add("Think", "nwContainerPending", function()
	if (!NETWORK.util.Throttle("container.pending", 0.1)) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		local entity = client.nwContainerPending

		if (!entity) then
			continue
		end

		local bBroken = !IsValid(entity) or !client:Alive() or
			client:GetPos():Distance(entity:GetPos()) > NETWORK.container.range or
			(client.nwContainerStart and
				client:GetPos():Distance(client.nwContainerStart) > 48)

		if (!bBroken) then
			continue
		end

		client.nwContainerPending = nil
		client.nwContainerStart = nil

		net.Start("nwProgress")
			net.WriteString("")
			net.WriteFloat(0)
		net.Send(client)
	end
end)

timer.Create("nwContainerRefill", 30, 0, function()
	for _, entity in ipairs(ents.FindByClass("nw_container")) do
		local minutes = entity:GetContainerRefill()

		if (minutes <= 0 or !istable(entity.items)) then
			entity.nwEmptySince = nil

			continue
		end

		if (next(entity.items) != nil or next(entity.viewers or {}) != nil) then
			entity.nwEmptySince = nil

			continue
		end

		if (!entity.nwEmptySince) then
			entity.nwEmptySince = CurTime()

			continue
		end

		if (CurTime() - entity.nwEmptySince < minutes * 60) then
			continue
		end

		entity.nwEmptySince = nil

		local data = NETWORK.container.Get(entity:GetContainerID())

		for index, item in ipairs(NETWORK.container.Roll(data.id)) do
			if (index > entity:GetContainerSlots()) then
				break
			end

			entity.items[index] = item
		end

		NETWORK.container.Sync(entity)

		hook.Run("NetworkContainerRefilled", entity)
	end
end)

function NETWORK.container.CheckLock(client, entity)
	if (!NETWORK.container.CanLock(entity) or !NETWORK.container.IsLocked(entity)) then
		return true
	end

	local lockItem, lockCode = NETWORK.container.GetLock(entity)

	if (NETWORK.container.FindKey(NETWORK.inventory.GetState(client), lockItem, lockCode)) then
		return true
	end

	local base = NETWORK.item.Get(lockItem)
	local name = base and base.name or lockItem

	if (client:IsAdmin()) then
		client.nwLockBypass = client.nwLockBypass or {}

		if ((client.nwLockBypass[entity] or 0) < CurTime()) then
			client.nwLockBypass[entity] = CurTime() + 5

			NETWORK.notice.Send(client, "containerLockBypass", "info", name)
		end

		return true
	end

	entity:EmitSound("doors/door_locked2.wav", 60, math.random(96, 104))

	if ((client.nwNextLockNotice or 0) < CurTime()) then
		client.nwNextLockNotice = CurTime() + 1.5

		NETWORK.notice.Send(client, "containerLockNeed", "warn", name)
	end

	return false
end

local CODE_CHARS = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"

function NETWORK.container.RandomCode()
	local code = {}

	for index = 1, 6 do
		local position = math.random(#CODE_CHARS)

		code[index] = string.sub(CODE_CHARS, position, position)
	end

	return table.concat(code)
end

function NETWORK.container.SetLock(entity, lockItem, lockCode)
	if (!NETWORK.container.CanLock(entity)) then
		return false
	end

	entity:SetLockItem(lockItem or "")
	entity:SetLockCode(lockItem != "" and (lockCode or "") or "")

	hook.Run("NetworkContainerLockChanged", entity)

	NETWORK.container.SaveLocks()

	return true
end

function NETWORK.container.GiveKey(client, entity, label)
	if (!NETWORK.container.CanLock(entity)) then
		return
	end

	local lockItem, lockCode = NETWORK.container.GetLock(entity)

	if (lockItem == "") then
		lockItem = NETWORK.container.keyItem
		lockCode = NETWORK.container.RandomCode()

		NETWORK.container.SetLock(entity, lockItem, lockCode)
	end

	local data = {}

	if (lockCode != "") then
		data.code = lockCode
	end

	if (lockItem == NETWORK.container.keyItem) then
		data.label = NETWORK.util.Sanitise(label or "", 32)
	end

	local item = NETWORK.inventory.Give(client, lockItem, 1, data)

	if (!item) then
		NETWORK.item.Spawn(lockItem, client:GetPos() + client:GetForward() * 20 +
			Vector(0, 0, 12), nil, 1, data)
	end

	return lockItem, lockCode
end

NETWORK.container.lockFile = "network/containerlocks.txt"
NETWORK.container.lockMatch = 40
NETWORK.container.lockOrphans = NETWORK.container.lockOrphans or {}

local function ReadLockFile()
	local raw = file.Read(NETWORK.container.lockFile, "DATA")
	local data = raw and util.JSONToTable(raw)

	return istable(data) and data or {}
end

function NETWORK.container.SaveLocks()
	if (!NETWORK.container.bLocksLoaded) then
		return
	end

	timer.Create("nwContainerLockSave", 2, 1, NETWORK.container.WriteLocks)
end

function NETWORK.container.WriteLocks()
	local list = {}

	for class in pairs(NETWORK.container.lockable) do
		if (class == "nw_cache") then
			continue
		end

		for _, entity in ipairs(ents.FindByClass(class)) do
			if (!NETWORK.container.CanLock(entity) or
				!NETWORK.container.IsLocked(entity)) then
				continue
			end

			local position = entity:GetPos()
			local lockItem, lockCode = NETWORK.container.GetLock(entity)

			list[#list + 1] = {
				class = class,
				pos = {math.Round(position.x, 1), math.Round(position.y, 1),
					math.Round(position.z, 1)},
				item = lockItem,
				code = lockCode
			}
		end
	end

	for _, entry in ipairs(NETWORK.container.lockOrphans) do
		list[#list + 1] = entry
	end

	local data = ReadLockFile()

	data[game.GetMap()] = list

	file.CreateDir("network")
	file.Write(NETWORK.container.lockFile, util.TableToJSON(data, true))
end

function NETWORK.container.LoadLocks()
	local list = ReadLockFile()[game.GetMap()]

	NETWORK.container.lockOrphans = {}

	for _, entry in ipairs(istable(list) and list or {}) do
		if (!istable(entry) or !istable(entry.pos) or !isstring(entry.item) or
			entry.item == "") then
			continue
		end

		local position = Vector(tonumber(entry.pos[1]) or 0, tonumber(entry.pos[2]) or 0,
			tonumber(entry.pos[3]) or 0)
		local best, bestDistance

		for _, entity in ipairs(ents.FindInSphere(position, NETWORK.container.lockMatch)) do
			if (entity:GetClass() != entry.class or !NETWORK.container.CanLock(entity) or
				NETWORK.container.IsLocked(entity)) then
				continue
			end

			local distance = entity:GetPos():DistToSqr(position)

			if (!best or distance < bestDistance) then
				best, bestDistance = entity, distance
			end
		end

		if (IsValid(best)) then
			best:SetLockItem(entry.item)
			best:SetLockCode(tostring(entry.code or ""))
		else
			NETWORK.container.lockOrphans[#NETWORK.container.lockOrphans + 1] = entry
		end
	end

	NETWORK.container.bLocksLoaded = true
end

hook.Add("InitPostEntity", "nwContainerLocks", function()
	timer.Simple(6, function()
		local bOk, err = pcall(NETWORK.container.LoadLocks)

		NETWORK.container.bLocksLoaded = true

		if (!bOk) then
			NETWORK.util.PrintWarning("Замки контейнеров: " .. tostring(err))
		end
	end)
end)

hook.Add("ShutDown", "nwContainerLocks", function()
	if (!NETWORK.container.bLocksLoaded) then
		return
	end

	timer.Remove("nwContainerLockSave")

	NETWORK.container.WriteLocks()
end)

function NETWORK.container.LockAction(client, entity, action, value)
	if (!IsValid(client) or !client:IsAdmin() or !NETWORK.container.CanLock(entity)) then
		return
	end

	local lockItem, lockCode = NETWORK.container.GetLock(entity)

	if (action == "item") then
		value = string.lower(string.Trim(value or ""))

		if (value == "") then
			NETWORK.container.SetLock(entity, "", "")

			return NETWORK.notice.Send(client, "containerLockCleared", "good")
		end

		local base = NETWORK.item.Get(value)

		if (!base) then
			return NETWORK.notice.Send(client, "containerLockBadItem", "warn", value)
		end

		NETWORK.container.SetLock(entity, value, value == lockItem and lockCode or "")

		return NETWORK.notice.Send(client, "containerLockSet", "good", base.name)
	end

	if (action == "code") then
		value = string.sub(string.Trim(value or ""), 1, 32)

		if (lockItem == "") then

			if (value == "") then
				return
			end

			lockItem = NETWORK.container.keyItem
		end

		NETWORK.container.SetLock(entity, lockItem, value)

		return NETWORK.notice.Send(client, value == "" and "containerLockCodeAny" or
			"containerLockCodeSet", "good", value)
	end

	if (action == "give") then

		if (lockItem == NETWORK.container.keyItem and lockCode == "") then
			NETWORK.container.SetLock(entity, lockItem, NETWORK.container.RandomCode())
		end

		local label = entity.GetDisplayName and entity:GetDisplayName() or ""
		local item, code = NETWORK.container.GiveKey(client, entity, label)

		if (item) then
			local base = NETWORK.item.Get(item)

			NETWORK.notice.Send(client, "containerLockKeyGiven", "good",
				base and base.name or item, code != "" and code or "—")
		end

		return
	end

	if (action == "clear") then
		NETWORK.container.SetLock(entity, "", "")

		return NETWORK.notice.Send(client, "containerLockCleared", "good")
	end
end

NETWORK.container.pickDifficulty = {
	nw_cache = "easy",
	nw_container = "medium",
	nw_ration_bin = "hard",
	nw_stash = "medium"
}

hook.Add("NetworkLockpickContainer", "nwContainerLock", function(client, entity)
	if (!NETWORK.container.CanLock(entity) or !NETWORK.container.IsLocked(entity)) then
		return
	end

	return NETWORK.container.pickDifficulty[entity:GetClass()] or "medium"
end)

hook.Add("NetworkLockpicked", "nwContainerLock", function(client, entity, kind)
	if (kind != "container" or !NETWORK.container.CanLock(entity)) then
		return
	end

	NETWORK.container.SetLock(entity, "", "")

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("item", string.format("%s вскрыл отмычкой замок %s",
			NETWORK.log.Name(client), entity:GetClass()), entity:GetPos())
	end
end)
