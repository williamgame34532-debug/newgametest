util.AddNetworkString("nwBarricadeBegin")
util.AddNetworkString("nwBarricadePlace")
util.AddNetworkString("nwBarricadeCancel")

local B = NETWORK.barricade

local function Progress(client, key, duration)
	if (!IsValid(client)) then
		return
	end

	net.Start("nwProgress")
		net.WriteString(key or "")
		net.WriteFloat(duration or 0)
	net.Send(client)
end

B.Progress = Progress

local function CountItem(state, id)
	local total = 0

	for _, item in pairs(state.items or {}) do
		if (istable(item) and item.id == id) then
			total = total + (item.amount or 1)
		end
	end

	return total
end

function B.CanUse(client)
	return IsValid(client) and client:Alive() and client:HasCharacter() and
		!IsValid(client.nwRagdollEntity) and !client:InVehicle()
end

function B.CountOwned(client)
	local id = client:GetCharacterID()
	local count = 0

	if (!id) then
		return 0
	end

	for _, entity in ipairs(ents.FindByClass("nw_barricade")) do
		if (entity:GetOwnerChar() == id) then
			count = count + 1
		end
	end

	return count
end

local SPAWN_CLASSES = {
	"info_player_start", "info_player_combine", "info_player_rebel",
	"info_player_deathmatch", "info_player_counterterrorist", "info_player_terrorist"
}

function B.NearSpawn(position)
	local limit = B.spawnClearance * B.spawnClearance

	for _, class in ipairs(SPAWN_CLASSES) do
		for _, entity in ipairs(ents.FindByClass(class)) do
			if (entity:GetPos():DistToSqr(position) < limit) then
				return true
			end
		end
	end

	local map = NETWORK.spawns and NETWORK.spawns.list and
		NETWORK.spawns.list[game.GetMap()]

	for _, list in pairs(istable(map) and map or {}) do
		for _, entry in pairs(istable(list) and list or {}) do
			if (istable(entry) and
				Vector(entry.x or 0, entry.y or 0, entry.z or 0):DistToSqr(position) < limit) then
				return true
			end
		end
	end

	return false
end

function B.PlayersInside(model, position, angles)
	local mins, maxs = B.GetBounds(model)
	local low, high

	for _, x in ipairs({mins.x, maxs.x}) do
		for _, y in ipairs({mins.y, maxs.y}) do
			for _, z in ipairs({mins.z, maxs.z}) do
				local corner = LocalToWorld(Vector(x, y, z), angle_zero, position, angles)

				low = low and Vector(math.min(low.x, corner.x), math.min(low.y, corner.y),
					math.min(low.z, corner.z)) or corner
				high = high and Vector(math.max(high.x, corner.x), math.max(high.y, corner.y),
					math.max(high.z, corner.z)) or corner
			end
		end
	end

	for _, entity in ipairs(ents.FindInBox(low, high)) do
		if (entity:IsPlayer() and entity:Alive()) then
			return true
		end
	end

	return false
end

function B.Validate(client, data, position, angles, door)
	local model = B.PickModel(data)

	if (client:GetShootPos():Distance(position) > B.range + 64) then
		return "barricadeTooFar"
	end

	if (B.PlayersInside(model, position, angles)) then
		return "barricadePlayers"
	end

	if (B.NearSpawn(position)) then
		return "barricadeSpawn"
	end

	if (B.CountOwned(client) >= B.maxPerCharacter) then
		return "barricadeLimit"
	end

	if (IsValid(door)) then
		if (NETWORK.door.IsOpen(door)) then
			return "barricadeDoorOpen"
		end

		if (#B.GetBoards(door) >= B.maxBoards) then
			return "barricadeDoorFull"
		end
	end
end

function B.Start(client, id)
	local data = B.Get(id)

	if (!data or !B.CanUse(client) or client.nwBarricadeTask) then
		return false
	end

	client.nwBarricadePlacing = id

	net.Start("nwBarricadeBegin")
		net.WriteString(id)
	net.Send(client)

	return true
end

function B.StopPlacing(client)
	client.nwBarricadePlacing = nil

	net.Start("nwBarricadeCancel")
	net.Send(client)
end

function B.Cancel(client, key)
	if (!client.nwBarricadeTask) then
		return
	end

	client.nwBarricadeTask = nil

	Progress(client, "", 0)

	if (key) then
		NETWORK.notice.Send(client, key, "warn")
	end
end

function B.Spawn(client, data, position, angles, door)
	local entity = ents.Create("nw_barricade")

	if (!IsValid(entity)) then
		return
	end

	entity:SetPos(position)
	entity:SetAngles(angles)
	entity:Spawn()
	entity:Activate()
	entity:ApplyType(data.id, true)

	entity:SetPos(position)
	entity:SetAngles(angles)

	entity.bNoPersist = true
	entity.nwOwner = client

	entity:SetOwnerChar(client:GetCharacterID() or 0)

	if (IsValid(door)) then
		entity:SetDoor(door)

		B.SealDoor(door)
	end

	hook.Run("NetworkBarricadePlaced", client, entity, data)

	return entity
end

local function FinishPlace(client, task)
	local data = task.data
	local state = NETWORK.inventory.GetState(client)

	if (CountItem(state, data.item) < 1) then
		return NETWORK.notice.Send(client, "barricadeNoItem", "warn")
	end

	local door = task.door

	if (task.bDoor and !IsValid(door)) then
		return NETWORK.notice.Send(client, "barricadeGone", "warn")
	end

	local position, angles = task.position, task.angles

	if (IsValid(door)) then
		local mins, maxs = B.GetBounds(B.PickModel(data))

		position, angles = B.DoorBoardTransform(door, #B.GetBoards(door) + 1,
			client:GetShootPos(), mins, maxs, task.rotation)
	end

	local refusal = B.Validate(client, data, position, angles, door)

	if (refusal) then
		return NETWORK.notice.Send(client, refusal, "warn")
	end

	local entity = B.Spawn(client, data, position, angles, door)

	if (!IsValid(entity)) then
		return NETWORK.notice.Send(client, "barricadeBlocked", "warn")
	end

	NETWORK.inventory.Take(client, data.item, 1)

	entity:EmitSound(data.bBoard and "physics/wood/wood_plank_impact_hard" ..
		math.random(1, 5) .. ".wav" or "physics/concrete/concrete_block_impact_hard" ..
		math.random(1, 3) .. ".wav", 70, 100)

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("item", string.format("%s поставил укрепление «%s»%s",
			NETWORK.log.Name(client), L(data.name), IsValid(door) and " на дверь" or ""),
			position)
	end

	NETWORK.notice.Send(client, IsValid(door) and "barricadeBoarded" or "barricadeDone",
		"good")
end

local function FinishDismantle(client, task)
	local entity = task.entity

	if (!IsValid(entity)) then
		return NETWORK.notice.Send(client, "barricadeGone", "warn")
	end

	local data = entity:GetTypeData()
	local bReturn = data and entity:GetFraction() > B.returnFraction

	entity:EmitSound(data and data.material == "metal" and
		"physics/metal/metal_box_impact_soft2.wav" or "physics/wood/wood_box_impact_soft3.wav",
		65, 100)

	entity:Remove()

	if (!bReturn) then
		return NETWORK.notice.Send(client, "barricadeScrapped", "warn")
	end

	if (!NETWORK.inventory.Give(client, data.item, 1)) then
		NETWORK.item.Spawn(data.item, client:GetPos() + client:GetForward() * 24 +
			Vector(0, 0, 16))
	end

	NETWORK.notice.Send(client, "barricadeTaken", "good")
end

local function Finish(client, task)
	if (!IsValid(client) or client.nwBarricadeTask != task) then
		return
	end

	client.nwBarricadeTask = nil

	Progress(client, "", 0)

	if (!B.CanUse(client)) then
		return
	end

	if (task.OnFinish) then
		return task.OnFinish(client, task)
	end

	if (task.bDismantle) then
		return FinishDismantle(client, task)
	end

	return FinishPlace(client, task)
end

function B.StartTask(client, task, key, duration)
	task.finish = CurTime() + duration
	task.start = client:GetPos()

	client.nwBarricadeTask = task

	Progress(client, key, duration)
end

net.Receive("nwBarricadePlace", function(_, client)
	local id = net.ReadString()
	local position = net.ReadVector()
	local rotation = math.Clamp(math.Round(net.ReadFloat() or 0), -360, 360)
	local data = B.Get(id)

	if (!data or client.nwBarricadePlacing != id or client.nwBarricadeTask) then
		return
	end

	if (!B.CanUse(client)) then
		return
	end

	if (CountItem(NETWORK.inventory.GetState(client), data.item) < 1) then
		return NETWORK.notice.Send(client, "barricadeNoItem", "warn")
	end

	local ownPosition, ownAngles, bValid, door = B.GetSpot(client, data, rotation)

	if (!bValid or ownPosition:Distance(position) > 32) then
		return NETWORK.notice.Send(client, "barricadeBlocked", "warn")
	end

	local refusal = B.Validate(client, data, ownPosition, ownAngles, door)

	if (refusal) then
		return NETWORK.notice.Send(client, refusal, "warn")
	end

	B.StopPlacing(client)

	B.StartTask(client, {
		data = data,
		position = ownPosition,
		angles = ownAngles,
		rotation = rotation,
		door = door,
		bDoor = IsValid(door)
	}, data.bBoard and "barricadeNailing" or "barricadeProgress", data.placeTime)

	NETWORK.chat.Send(client, "me", L(data.bBoard and "barricadeMeBoard" or "barricadeMe"))

	client:EmitSound(data.bBoard and "physics/wood/wood_box_impact_hard" ..
		math.random(1, 3) .. ".wav" or "physics/cardboard/cardboard_box_impact_hard" ..
		math.random(1, 7) .. ".wav", 60, 100, 0.6)
end)

net.Receive("nwBarricadeCancel", function(_, client)
	client.nwBarricadePlacing = nil

	if (client.nwBarricadeTask and !client.nwBarricadeTask.bDismantle) then
		B.Cancel(client)
	end
end)

function B.CanDismantle(client, entity)
	if (!IsValid(client) or !IsValid(entity) or !client:HasCharacter()) then
		return false
	end

	if (client:IsAdmin()) then
		return true
	end

	local owner = entity:GetOwnerChar()

	return owner != 0 and owner == client:GetCharacterID()
end

function B.CanRepair(client, entity)
	local data = IsValid(entity) and entity.GetTypeData and entity:GetTypeData()
	local repair = data and data.repair

	if (!repair or entity:GetDurability() >= entity:GetMaxDurability()) then
		return false
	end

	local state = NETWORK.inventory.GetState(client)

	for id, amount in pairs(repair.items or {}) do
		if (NETWORK.craft.Count(state, id) < amount) then
			return false, id, amount
		end
	end

	return true
end

local function FinishRepair(client, task)
	local entity = task.entity

	if (!IsValid(entity)) then
		return NETWORK.notice.Send(client, "barricadeGone", "warn")
	end

	local bOk = B.CanRepair(client, entity)

	if (!bOk) then
		return NETWORK.notice.Send(client, "barricadeRepairNoMat", "warn")
	end

	local repair = entity:GetTypeData().repair

	for id, amount in pairs(repair.items or {}) do
		for _ = 1, amount do
			NETWORK.inventory.Take(client, id, 1)
		end
	end

	local before = entity:GetDurability()

	entity:SetDurability(math.min(before + (repair.amount or 100), entity:GetMaxDurability()))

	if (entity.RefreshStage) then
		entity:RefreshStage()
	end

	entity:EmitSound(entity:GetTypeData().material == "metal" and
		"physics/metal/metal_box_impact_hard2.wav" or "physics/wood/wood_plank_impact_hard1.wav",
		65, math.random(96, 104))

	NETWORK.notice.Send(client, "barricadeRepaired", "good", entity:GetDurability(),
		entity:GetMaxDurability())
end

function B.BeginRepair(client, entity)
	if (!B.CanUse(client) or client.nwBarricadeTask) then
		return true
	end

	local bOk, missing, amount = B.CanRepair(client, entity)

	if (!bOk) then
		if (missing) then
			local base = NETWORK.item.Get(missing)

			NETWORK.notice.Send(client, "barricadeRepairNeed", "warn",
				base and base.name or missing, amount)

			return true
		end

		return false
	end

	local repair = entity:GetTypeData().repair

	B.StartTask(client, {
		entity = entity,
		OnFinish = FinishRepair,
		Check = function(_, task)
			if (!IsValid(task.entity) or !client:KeyDown(IN_USE)) then
				return false
			end

			local trace = client:GetEyeTrace()

			return trace.Entity == task.entity and
				client:GetShootPos():Distance(trace.HitPos) <= B.range + 24
		end
	}, "barricadeRepairing", repair.time or 3)

	return true
end

function B.Use(client, entity)
	local bDamaged = entity:GetDurability() < entity:GetMaxDurability()

	if (bDamaged and !client:KeyDown(IN_WALK)) then
		if (B.BeginRepair(client, entity)) then
			return
		end
	end

	B.BeginDismantle(client, entity)
end

function B.BeginDismantle(client, entity)
	if (!B.CanUse(client) or client.nwBarricadeTask) then
		return
	end

	if ((client.nwNextBarricadeUse or 0) > CurTime()) then
		return
	end

	client.nwNextBarricadeUse = CurTime() + 0.6

	if (!B.CanDismantle(client, entity)) then
		return NETWORK.notice.Send(client, "barricadeNotYours", "warn")
	end

	local data = entity:GetTypeData()

	B.StartTask(client, {
		entity = entity,
		bDismantle = true
	}, "barricadeDismantling", data and data.pickupTime or 3)
end

local function IsLookingAt(client, entity)
	local trace = client:GetEyeTrace()

	return trace.Entity == entity and
		client:GetShootPos():Distance(trace.HitPos) <= B.range + 24
end

timer.Create("nwBarricadeWatch", 0.1, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local task = client.nwBarricadeTask

		if (!task) then
			continue
		end

		if (!B.CanUse(client) or client:GetPos():Distance(task.start) > 40) then
			B.Cancel(client, "barricadeInterrupted")

			continue
		end

		if (task.bDismantle and (!IsValid(task.entity) or !client:KeyDown(IN_USE) or
			!IsLookingAt(client, task.entity))) then
			B.Cancel(client, "barricadeInterrupted")

			continue
		end

		if (task.Check and !task.Check(client, task)) then
			B.Cancel(client, "barricadeInterrupted")

			continue
		end

		if (task.bDoor and !IsValid(task.door)) then
			B.Cancel(client, "barricadeGone")

			continue
		end

		if (CurTime() >= task.finish) then
			Finish(client, task)
		end
	end
end)

hook.Add("StartCommand", "nwBarricade", function(client, cmd)
	local task = client.nwBarricadeTask

	if (!task) then
		return
	end

	cmd:ClearMovement()
	cmd:RemoveKey(IN_JUMP)
	cmd:RemoveKey(IN_ATTACK)
	cmd:RemoveKey(IN_ATTACK2)
	cmd:RemoveKey(IN_SPEED)
end)

hook.Add("PlayerDeath", "nwBarricade", function(client)
	client.nwBarricadePlacing = nil
	client.nwBarricadeTask = nil
end)

hook.Add("PlayerDisconnected", "nwBarricade", function(client)
	client.nwBarricadeTask = nil
end)

local function Drive(callback)
	B.bDriving = true

	local ok, err = pcall(callback)

	B.bDriving = false

	if (!ok) then
		ErrorNoHalt("[Network] barricade drive: " .. tostring(err) .. "\n")
	end
end

function B.SealDoor(door)
	if (!IsValid(door)) then
		return
	end

	Drive(function()
		for _, leaf in ipairs(B.GetLeaves(door)) do
			leaf:Fire("Close")
			leaf:Fire("Lock")
		end
	end)
end

function B.IsHeldElsewhere(door)
	local data = NETWORK.door.GetData(door)

	if (NETWORK.door.IsLocked(data) or door.nwMapLocked) then
		return true
	end

	for _, leaf in ipairs(B.GetLeaves(door)) do
		local lock = leaf.nwLock

		if (IsValid(lock) and lock:GetLocked()) then
			return true
		end
	end

	return false
end

function B.RefreshDoor(door)
	if (!IsValid(door) or !NETWORK.door.IsDoor(door)) then
		return
	end

	if (B.IsDoorSealed(door)) then
		return B.SealDoor(door)
	end

	if (B.IsHeldElsewhere(door)) then
		return
	end

	Drive(function()
		for _, leaf in ipairs(B.GetLeaves(door)) do
			leaf:Fire("Unlock")
		end
	end)
end

local BLOCKED = {open = true, toggle = true, unlock = true, setposition = true}

hook.Add("AcceptInput", "nwBarricadeSeal", function(entity, input)
	if (B.bDriving or !BLOCKED[string.lower(input or "")]) then
		return
	end

	if (!NETWORK.door.IsDoor(entity)) then
		return
	end

	if (B.IsDoorSealed(entity)) then
		return true
	end
end)

timer.Create("nwBarricadeSealWatch", 1, 0, function()
	local seen = {}

	for _, class in ipairs({"nw_barricade", "nw_padlock"}) do
		for _, entity in ipairs(ents.FindByClass(class)) do
			local door = entity:GetDoor()

			if (IsValid(door) and !seen[door]) then
				seen[door] = true

				if (B.IsDoorSealed(door) and (NETWORK.door.IsOpen(door) or
					door:GetInternalVariable("m_bLocked") != true)) then
					B.SealDoor(door)
				end
			end
		end
	end
end)

B.kickDamage = 110

hook.Add("NetworkDoorBreach", "nwBarricade", function(client, door)
	local reason, padlock = B.IsDoorSealed(door)

	if (!reason) then
		return
	end

	local target = padlock

	if (reason == "boarded") then
		local boards = B.GetBoards(door)

		target = boards[math.random(#boards)]
	end

	if (IsValid(target)) then
		local damage = DamageInfo()

		damage:SetDamage(B.kickDamage)
		damage:SetDamageType(DMG_CLUB)
		damage:SetAttacker(client)
		damage:SetInflictor(client)
		damage:SetDamagePosition(target:WorldSpaceCenter())

		target:OnTakeDamage(damage)
	end

	NETWORK.notice.Send(client, reason == "boarded" and "breachBoarded" or "breachPadlock", "warn")

	return false
end)
