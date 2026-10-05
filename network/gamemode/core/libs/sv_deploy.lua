util.AddNetworkString("nwDeployBegin")
util.AddNetworkString("nwDeployPlace")
util.AddNetworkString("nwDeployCancel")

local function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

local function Progress(client, key, duration)
	net.Start("nwProgress")
		net.WriteString(key or "")
		net.WriteFloat(duration or 0)
	net.Send(client)
end

local function CountItem(state, id)
	local total = 0

	for _, list in ipairs({state.items or {}, state.storage or {}}) do
		for _, item in pairs(list) do
			if (item.id == id) then
				total = total + (item.amount or 1)
			end
		end
	end

	return total
end

local function TakeItem(state, id)
	for _, key in ipairs({"items", "storage"}) do
		for index, item in pairs(state[key] or {}) do
			if (item.id != id) then
				continue
			end

			if ((item.amount or 1) > 1) then
				item.amount = item.amount - 1
			else
				state[key][index] = nil
			end

			return true
		end
	end

	return false
end

function NETWORK.deploy.Start(client, id)
	local data = NETWORK.deploy.Get(id)

	if (!data) then
		return false
	end

	if (!NETWORK.deploy.CanUseType(client, data)) then
		Notice(client, data.noAccess or "deployNoAccess")

		return false
	end

	if (client.nwDeployTask) then
		return false
	end

	if (data.CanPlace) then
		local bAllowed, reason = data.CanPlace(client, data)

		if (bAllowed == false) then
			Notice(client, reason or "deployBlocked")

			return false
		end
	end

	client.nwDeploying = id

	net.Start("nwDeployBegin")
		net.WriteString(id)
	net.Send(client)

	return true
end

function NETWORK.deploy.StopPlacing(client)
	client.nwDeploying = nil

	net.Start("nwDeployCancel")
	net.Send(client)
end

local function Cancel(client, key)
	client.nwDeployTask = nil

	Progress(client, "", 0)

	if (key) then
		Notice(client, key)
	end
end

function NETWORK.deploy.IsClear(position, filter, data)
	local mount = data and data.mount or "floor"

	if (mount == "floor") then
		local size = data and data.hullSize or 16
		local height = data and data.hullHeight or NETWORK.deploy.clearance
		local hull = util.TraceHull({
			start = position + Vector(0, 0, height * 0.5),
			endpos = position + Vector(0, 0, height * 0.5),
			mins = Vector(-size, -size, 0),
			maxs = Vector(size, size, height),
			filter = filter,
			mask = MASK_SOLID
		})

		if (hull.Hit) then
			return false
		end
	end

	local spacing = data and data.spacing and math.max(data.spacing - 8, 8) or 40

	for _, entity in ipairs(ents.FindInSphere(position, spacing)) do
		if (entity:GetNWString("nwDeploy", "") != "") then
			return false
		end
	end

	return true
end

function NETWORK.deploy.Spawn(client, data, position, angles, extra)
	local entity = ents.Create(data.class)

	if (!IsValid(entity)) then
		return
	end

	entity:SetPos(position)
	entity:SetAngles(angles)

	entity.nwDeployID = data.id
	entity.nwOwner = client
	entity.nwOwnerChar = client:GetCharacterID()
	entity.nwDeployExtra = extra

	if (NETWORK.deploy.turretClasses[data.class]) then
		entity:SetKeyValue("spawnflags", "32")
	end

	entity:Spawn()
	entity:Activate()

	if (NETWORK.deploy.turretClasses[data.class]) then
		entity:Fire("Enable")
	end

	entity.nwDeployID = data.id
	entity.nwOwner = client
	entity.nwOwnerFaction = client:GetCharacterFaction()

	entity:SetNWString("nwDeploy", data.id)
	entity:SetNWEntity("nwDeployOwner", client)

	if (data.OnDeployed) then
		data.OnDeployed(entity, client, data, extra)
	end

	if (entity:IsNPC()) then
		entity.nwNoSalvage = true

		NETWORK.deploy.ApplyRelations(entity)
	end

	local physics = entity:GetPhysicsObject()

	if (IsValid(physics)) then
		physics:Wake()
	end

	hook.Run("NetworkDeploySpawned", client, entity, data)

	return entity
end

function NETWORK.deploy.IsManaged(entity)
	if (!IsValid(entity)) then
		return false
	end

	return entity:GetNWString("nwDeploy", "") != "" or istable(entity.nwHostile)
end

NETWORK.deploy.turretClasses = {
	npc_turret_floor = true,
	npc_turret_ceiling = true
}

function NETWORK.deploy.ApplyRelations(turret)
	if (!IsValid(turret)) then
		return
	end

	local hostile = NETWORK.deploy.GetHostile(turret)

	for _, client in ipairs(player.GetAll()) do
		local faction = client:GetCharacterFaction() or ""
		local bFriendly = client == turret.nwOwner

		if (!bFriendly) then
			bFriendly = !hostile[faction]
		end

		turret:AddEntityRelationship(client, bFriendly and D_LI or D_HT, 99)
	end
end

function NETWORK.deploy.RefreshTurrets()
	for _, entity in ipairs(ents.GetAll()) do
		if (entity:IsNPC() and NETWORK.deploy.IsManaged(entity)) then
			NETWORK.deploy.ApplyRelations(entity)
		end
	end
end

NETWORK.deploy.turretRange = 1200

function NETWORK.deploy.IsHostileTo(turret, client)
	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return false
	end

	if (client:GetMoveType() == MOVETYPE_NOCLIP) then
		return false
	end

	if (client == turret.nwOwner) then
		return false
	end

	return NETWORK.deploy.GetHostile(turret)[client:GetCharacterFaction() or ""]
		== true
end

hook.Add("EntityTakeDamage", "nwTurretRelations", function(victim, damage)
	if (!victim:IsPlayer()) then
		return
	end

	local attacker = damage:GetAttacker()
	local inflictor = damage:GetInflictor()
	local classes = NETWORK.deploy.turretClasses
	local turret = (IsValid(attacker) and classes[attacker:GetClass()]) and attacker or
		((IsValid(inflictor) and classes[inflictor:GetClass()]) and inflictor or nil)

	if (!IsValid(turret) or !NETWORK.deploy.IsManaged(turret)) then
		return
	end

	if (NETWORK.deploy.IsHostileTo(turret, victim)) then
		return
	end

	turret:SetEnemy(NULL)
	turret:ClearEnemyMemory()

	damage:SetDamage(0)

	return true
end)

function NETWORK.deploy.FindTarget(turret)
	local best, bestDistance
	local origin = turret:WorldSpaceCenter()

	for _, client in ipairs(player.GetAll()) do
		if (!NETWORK.deploy.IsHostileTo(turret, client)) then
			continue
		end

		local distance = origin:Distance(client:WorldSpaceCenter())

		if (distance > NETWORK.deploy.turretRange) then
			continue
		end

		local trace = util.TraceLine({
			start = origin,
			endpos = client:WorldSpaceCenter(),
			filter = {turret, client},
			mask = MASK_SHOT
		})

		if (trace.Hit and trace.Fraction < 0.96) then
			continue
		end

		if (!bestDistance or distance < bestDistance) then
			best = client
			bestDistance = distance
		end
	end

	return best
end

timer.Create("nwTurretWatch", 0.15, 0, function()
	for class in pairs(NETWORK.deploy.turretClasses) do
		for _, turret in ipairs(ents.FindByClass(class)) do
			if (!NETWORK.deploy.IsManaged(turret)) then
				continue
			end

			NETWORK.deploy.ApplyRelations(turret)

			local enemy = turret:GetEnemy()

			if (IsValid(enemy) and enemy:IsPlayer() and
				!NETWORK.deploy.IsHostileTo(turret, enemy)) then
				turret:SetEnemy(NULL)
				turret:ClearEnemyMemory()

				enemy = nil
			end

			if (IsValid(enemy)) then
				continue
			end

			local target = NETWORK.deploy.FindTarget(turret)

			if (!IsValid(target)) then
				continue
			end

			turret:UpdateEnemyMemory(target, target:WorldSpaceCenter())
			turret:SetEnemy(target)
			turret:SetLastPosition(target:WorldSpaceCenter())

			if ((turret.nwNextEnable or 0) < CurTime()) then
				turret.nwNextEnable = CurTime() + 1

				turret:Fire("Enable")
			end
		end
	end
end)

hook.Add("PlayerSpawn", "nwDeploy", function()
	timer.Simple(0.5, NETWORK.deploy.RefreshTurrets)
end)

hook.Add("NetworkCharacterLoaded", "nwDeploy", function()
	timer.Simple(1, NETWORK.deploy.RefreshTurrets)
end)

hook.Add("NetworkFactionTransferred", "nwDeploy", function()
	timer.Simple(1, NETWORK.deploy.RefreshTurrets)
end)

hook.Add("StartCommand", "nwDeploy", function(client, cmd)
	if (!client.nwDeployTask) then
		return
	end

	cmd:ClearMovement()
	cmd:RemoveKey(IN_JUMP)
	cmd:RemoveKey(IN_ATTACK)
	cmd:RemoveKey(IN_ATTACK2)
	cmd:RemoveKey(IN_SPEED)
end)

local function Finish(client, task)
	if (!IsValid(client) or client.nwDeployTask != task) then
		return
	end

	client.nwDeployTask = nil

	local data = task.data

	if (task.bPickup) then
		if (IsValid(task.entity) and !NETWORK.deploy.CanControl(client, task.entity)) then
			return
		end
	elseif (!NETWORK.deploy.CanUseType(client, data)) then
		return
	end

	local state = NETWORK.inventory.GetState(client)

	if (task.bPickup) then
		local entity = task.entity

		if (!IsValid(entity)) then
			return Notice(client, "deployGone")
		end

		local item = NETWORK.item.New(data.item, 1)
		local columns, rows = NETWORK.inventory.columns, NETWORK.inventory.rows

		if (!NETWORK.inventory.FindStack(state.items, item, NETWORK.inventory.GetSize()) and
			!NETWORK.inventory.FindSpot(state.items, columns, rows, item)) then
			return Notice(client, "deployNoRoom")
		end

		entity:Remove()

		NETWORK.item.OnCreated(item, client, client:GetCharacter())
		NETWORK.inventory.Insert(state, item)
		NETWORK.inventory.Sync(client)

		client:EmitSound("items/ammocrate_close.wav", 60, 105)

		return Notice(client, "deployTaken")
	end

	if (client:GetPos():Distance(task.position) > NETWORK.deploy.range *
		(data.bTwoPoint and 2.4 or 1.5)) then
		return Notice(client, "deployTooFar")
	end

	if (!NETWORK.deploy.IsClear(task.position, client, data)) then
		return Notice(client, "deployBlocked")
	end

	if (CountItem(state, data.item) < 1) then
		return Notice(client, "deployNoItem")
	end

	if (data.CanPlace) then
		local bAllowed, reason = data.CanPlace(client, data)

		if (bAllowed == false) then
			return Notice(client, reason or "deployBlocked")
		end
	end

	local entity = NETWORK.deploy.Spawn(client, data, task.position, task.angles,
		task.extra)

	if (!IsValid(entity)) then
		NETWORK.util.PrintWarning("Не удалось создать " .. tostring(data.class))

		return Notice(client, "deployBlocked")
	end

	TakeItem(state, data.item)
	NETWORK.inventory.Sync(client)

	client:EmitSound(data.placeSound or "npc/turret_floor/deploy.wav", 65, 100)

	Notice(client, "deployDone")
end

local function StartTask(client, task, key, duration)
	client.nwDeployTask = task

	Progress(client, key, duration)

	client:EmitSound("physics/metal/metal_box_strain" .. math.random(1, 3) .. ".wav",
		55, 105, 0.4)

	timer.Simple(duration, function()
		Finish(client, task)
	end)
end

local function OnSurface(position, normal)
	local trace = util.TraceLine({
		start = position + normal * 4,
		endpos = position - normal * 6,
		mask = MASK_SOLID
	})

	return trace.Hit
end

local function ReadTwoPoint(client, data, anchor, anchorNormal)
	local finish, _, bValid, normal = NETWORK.deploy.GetSpot(client, data)

	if (!bValid) then
		return
	end

	if (client:GetShootPos():Distance(anchor) > NETWORK.deploy.range * 2.2 or
		anchor:Distance(finish) > (data.wireLength or 250) or
		anchor:Distance(finish) < (data.wireMin or 24)) then
		return
	end

	if (!OnSurface(anchor, anchorNormal) or !OnSurface(finish, normal or vector_up)) then
		return
	end

	local wire = util.TraceLine({
		start = anchor + anchorNormal * 2,
		endpos = finish + (normal or vector_up) * 2,
		mask = MASK_SOLID_BRUSHONLY
	})

	if (wire.Hit and wire.Fraction < 0.98) then
		return
	end

	return finish + (normal or vector_up) * 2
end

net.Receive("nwDeployPlace", function(_, client)
	local id = net.ReadString()
	local position = net.ReadVector()
	local angles = net.ReadAngle()
	local bTwoPoint = net.ReadBool()
	local anchorNormal = bTwoPoint and net.ReadVector() or nil
	local data = NETWORK.deploy.Get(id)

	if (!data or client.nwDeploying != id or client.nwDeployTask) then
		return
	end

	if (!NETWORK.deploy.CanUseType(client, data)) then
		return
	end

	local state = NETWORK.inventory.GetState(client)

	if (CountItem(state, data.item) < 1) then
		return Notice(client, "deployNoItem")
	end

	local ownPosition, ownAngles, bValid
	local extra

	if (data.bTwoPoint) then
		if (!bTwoPoint or !anchorNormal or anchorNormal:LengthSqr() < 0.5) then
			return Notice(client, "deployBlocked")
		end

		anchorNormal:Normalize()

		extra = ReadTwoPoint(client, data, position, anchorNormal)

		if (!extra) then
			return Notice(client, "deployBlocked")
		end

		ownPosition = position + anchorNormal * (data.offset or 0)
		ownAngles = anchorNormal.z >= 0.7 and Angle(0, client:EyeAngles().y, 0) or
			anchorNormal:Angle()
		bValid = true
	else
		ownPosition, ownAngles, bValid = NETWORK.deploy.GetSpot(client, data)

		if (!bValid or ownPosition:Distance(position) > 48) then
			return Notice(client, "deployBlocked")
		end
	end

	client.nwDeploying = nil

	NETWORK.deploy.StopPlacing(client)

	StartTask(client, {
		data = data,
		position = ownPosition,
		angles = ownAngles,
		extra = extra
	}, "deployProgress", data.time)
end)

net.Receive("nwDeployCancel", function(_, client)
	client.nwDeploying = nil

	if (client.nwDeployTask and !client.nwDeployTask.bPickup) then
		Cancel(client)
	end
end)

util.AddNetworkString("nwTurretMenu")
util.AddNetworkString("nwTurretApply")
util.AddNetworkString("nwTurretPickup")

function NETWORK.deploy.CanControl(client, entity)
	if (!IsValid(client) or !IsValid(entity) or !client:HasCharacter()) then
		return false
	end

	if (client:IsAdmin()) then
		return true
	end

	if (entity.nwOwner == client) then
		return true
	end

	local data = NETWORK.deploy.Get(entity:GetNWString("nwDeploy", ""))

	if (data and data.CanControl) then
		return data.CanControl(client, entity, data) == true
	end

	if (entity.nwOwnerFaction == nil and NETWORK.deploy.turretClasses[entity:GetClass()]) then
		return NETWORK.factions.IsAlliance(client)
	end

	return entity.nwOwnerFaction != nil and
		entity.nwOwnerFaction == client:GetCharacterFaction()
end

function NETWORK.deploy.GetHostile(entity)
	if (!entity.nwHostile) then

		entity.nwHostile = {}

		for _, id in ipairs(NETWORK.factions.order or {}) do
			local data = NETWORK.factions.Get(id)

			entity.nwHostile[id] = !(data and data.bCombine)
		end
	end

	return entity.nwHostile
end

net.Receive("nwTurretApply", function(_, client)
	local entity = net.ReadEntity()
	local list = NETWORK.util.ReadTable() or {}

	if (!NETWORK.deploy.CanControl(client, entity)) then
		return Notice(client, "deployNoAccess")
	end

	local hostile = NETWORK.deploy.GetHostile(entity)

	for id, value in pairs(list) do
		if (NETWORK.factions.Get(id)) then
			hostile[id] = value == true
		end
	end

	NETWORK.deploy.ApplyRelations(entity)

	if (NETWORK.entities and NETWORK.entities.Save) then
		NETWORK.entities.Save()
	end

	Notice(client, "turretSaved")
end)

net.Receive("nwTurretPickup", function(_, client)
	local entity = net.ReadEntity()

	if (!NETWORK.deploy.CanControl(client, entity)) then
		return Notice(client, "deployNoAccess")
	end

	if (client.nwDeployTask) then
		return
	end

	if (client:GetPos():Distance(entity:GetPos()) > NETWORK.deploy.range * 1.5) then
		return Notice(client, "deployTooFar")
	end

	local data = NETWORK.deploy.Get(entity:GetNWString("nwDeploy", ""))

	if (!data) then
		return
	end

	StartTask(client, {
		data = data,
		entity = entity,
		bPickup = true
	}, "deployPickup", data.pickupTime)
end)

hook.Add("PlayerUse", "nwDeploy", function(client, entity)
	if (!IsValid(entity)) then
		return
	end

	local bDeployed = entity:GetNWString("nwDeploy", "") != ""
	local bTurret = NETWORK.deploy.turretClasses[entity:GetClass()] == true

	if (!bDeployed and !bTurret) then
		return
	end

	local data = NETWORK.deploy.Get(entity:GetNWString("nwDeploy", ""))

	if (data and data.bNoMenu) then
		return
	end

	if (client.nwDeployTask or (client.nwNextDeployUse or 0) > CurTime()) then
		return false
	end

	client.nwNextDeployUse = CurTime() + 0.5

	if (!data) then
		if (!bTurret or !client:HasCharacter() or
			(!client:IsAdmin() and !NETWORK.factions.IsAlliance(client))) then
			return
		end

		NETWORK.deploy.GetHostile(entity)
		NETWORK.deploy.ApplyRelations(entity)
	end

	if (!NETWORK.deploy.CanControl(client, entity)) then
		Notice(client, "deployNoAccess")

		return false
	end

	local payload = {}

	for id, value in pairs(NETWORK.deploy.GetHostile(entity)) do
		payload[id] = value
	end

	net.Start("nwTurretMenu")
		net.WriteEntity(entity)
		NETWORK.util.WriteTable(payload)
	net.Send(client)

	return false
end)

hook.Add("PlayerDeath", "nwDeploy", function(client)
	client.nwDeploying = nil

	if (client.nwDeployTask) then
		Cancel(client)
	end
end)

timer.Create("nwDeployWatch", 0.5, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local task = client.nwDeployTask

		if (!task) then
			continue
		end

		if (!client:Alive() or IsValid(client.nwRagdollEntity) or
			(task.bPickup and !IsValid(task.entity))) then
			Cancel(client, "deployInterrupted")
		end
	end
end)

NETWORK.command.Register("turretinfo", {
	description = "cmdTurretInfo",
	usage = "/turretinfo",
	OnRun = function(command, client)
		local trace = client:GetEyeTrace()
		local turret = trace.Entity

		if (!IsValid(turret) or !NETWORK.deploy.turretClasses[turret:GetClass()]) then
			return NETWORK.chat.Notice(client, L("turretInfoNone"))
		end

		local hostile = {}
		local friendly = {}

		for id, value in pairs(NETWORK.deploy.GetHostile(turret)) do
			local faction = NETWORK.factions.Get(id)
			local name = faction and L(faction.name) or id

			if (value) then
				hostile[#hostile + 1] = name
			else
				friendly[#friendly + 1] = name
			end
		end

		table.sort(hostile)
		table.sort(friendly)

		local enemy = turret:GetEnemy()

		NETWORK.chat.Notice(client, L("turretInfoHead", turret:EntIndex(),
			NETWORK.deploy.IsManaged(turret) and L("turretInfoManaged") or L("turretInfoFree"),
			IsValid(turret.nwOwner) and turret.nwOwner:GetCharacterName() or "-"))
		NETWORK.chat.Notice(client, L("turretInfoHostile",
			#hostile > 0 and table.concat(hostile, ", ") or "-"))
		NETWORK.chat.Notice(client, L("turretInfoFriendly",
			#friendly > 0 and table.concat(friendly, ", ") or "-"))
		NETWORK.chat.Notice(client, L("turretInfoEnemy",
			IsValid(enemy) and (enemy:IsPlayer() and enemy:GetCharacterName() or enemy:GetClass()) or "-",
			L(NETWORK.deploy.IsHostileTo(turret, client) and "turretInfoYouEnemy" or "turretInfoYouFriend")))
	end
})

hook.Add("OnEntityCreated", "nwDeployTurretWake", function(entity)
	if (!IsValid(entity) or !NETWORK.deploy.turretClasses[entity:GetClass()]) then
		return
	end

	timer.Simple(0.3, function()
		if (IsValid(entity) and NETWORK.deploy.IsManaged(entity)) then
			entity:Fire("Enable")
		end
	end)
end)
