NETWORK.rebels = NETWORK.rebels or {}

local R = NETWORK.rebels

util.AddNetworkString("nwRebelAction")
util.AddNetworkString("nwRebelPocket")
util.AddNetworkString("nwRebelPocketMove")

local function Notice(client, key, tone, ...)
	NETWORK.notice.Send(client, key, tone or "info", ...)
end

local function Progress(client, key, duration)
	net.Start("nwProgress")
		net.WriteString(key or "")
		net.WriteFloat(duration or 0)
	net.Send(client)
end

local function Log(text, position)
	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("rebel", text, position)
	end
end

local function ZoneName(entity)
	local zone = NETWORK.zone and NETWORK.zone.At(entity:GetPos())

	return (zone and zone.name) or L("rebelUnknownZone")
end

local function CharKey(client)
	local character = IsValid(client) and client:GetCharacter()

	return character and tostring(character:GetID()) or nil
end

function R.FindItem(client, id)
	local state = NETWORK.inventory.GetState(client)

	for _, list in ipairs({"items", "storage"}) do
		for index, item in pairs(state[list] or {}) do
			if (istable(item) and item.id == id) then
				return list, index, item
			end
		end
	end
end

function R.ConsumeItem(client, id)
	local list, index, item = R.FindItem(client, id)

	if (!item) then
		return false
	end

	local state = NETWORK.inventory.GetState(client)

	if ((item.amount or 1) > 1) then
		item.amount = item.amount - 1
	else
		NETWORK.inventory.Put(state, list, index, nil, nil)
	end

	NETWORK.inventory.Sync(client)

	return true
end

function R.CancelTask(client, key)
	local task = client.nwRebelTask

	if (!task) then
		return
	end

	client.nwRebelTask = nil
	timer.Remove("nwRebelTask" .. client:EntIndex())
	Progress(client, "", 0)

	if (task.OnCancel) then
		task.OnCancel(client, task)
	end

	if (key) then
		Notice(client, key, "warn")
	end
end

local function CommonCheck(client, task)
	if (!client:Alive() or !client:HasCharacter()) then
		return false
	end

	if (NETWORK.restraint and NETWORK.restraint.IsTied and NETWORK.restraint.IsTied(client)) then
		return false, "rebelTaskStopped"
	end

	if (NETWORK.pmenu and NETWORK.pmenu.IsHelpless and NETWORK.pmenu.IsHelpless(client)) then
		return false, "rebelTaskStopped"
	end

	if (client:InVehicle()) then
		return false, "rebelTaskStopped"
	end

	if (client:GetPos():Distance(task.start) > R.sabotage.moveTolerance) then
		return false, "rebelTaskMoved"
	end

	if (task.bHold and !client:KeyDown(IN_USE)) then
		return false, "rebelTaskReleased"
	end

	return true
end

function R.StartTask(client, task)
	if (client.nwRebelTask) then
		return false
	end

	task.start = client:GetPos()
	task.finish = CurTime() + task.time
	client.nwRebelTask = task

	Progress(client, task.label, task.time)

	local name = "nwRebelTask" .. client:EntIndex()

	timer.Create(name, 0.1, 0, function()
		if (!IsValid(client) or client.nwRebelTask != task) then
			timer.Remove(name)

			return
		end

		local bOk, reason = CommonCheck(client, task)

		if (bOk and task.Check) then
			bOk, reason = task.Check(client, task)
		end

		if (!bOk) then
			return R.CancelTask(client, reason)
		end

		if (task.Tick) then
			task.Tick(client, task)
		end

		if (CurTime() < task.finish) then
			return
		end

		client.nwRebelTask = nil
		timer.Remove(name)
		Progress(client, "", 0)

		task.Done(client, task)
	end)

	return true
end

hook.Add("PlayerDeath", "nwRebelTask", function(client)
	R.CancelTask(client)
end)

hook.Add("PlayerDisconnected", "nwRebelTask", function(client)
	R.CancelTask(client)
end)

hook.Add("EntityTakeDamage", "nwRebelTask", function(victim, damage)
	if (IsValid(victim) and victim:IsPlayer() and victim.nwRebelTask and
		damage:GetDamage() >= 5) then
		R.CancelTask(victim, "rebelTaskHurt")
	end
end)

R.active = R.active or {}
R.handlers = R.handlers or {}

local function QuietTurret(entity)
	if (entity.SetEnemy) then
		entity:SetEnemy(NULL)
	end

	if (entity.ClearEnemyMemory) then
		entity:ClearEnemyMemory()
	end

	entity:Fire("Disable")
end

R.handlers.turret = {
	Apply = function(entity, sab)
		if (NETWORK.deploy and NETWORK.deploy.IsManaged and NETWORK.deploy.IsManaged(entity)) then
			sab.bManaged = true
			sab.saved = entity.nwHostile
			sab.empty = {}

			entity.nwHostile = sab.empty
		end

		QuietTurret(entity)

		if (sab.bManaged and NETWORK.deploy.ApplyRelations) then
			NETWORK.deploy.ApplyRelations(entity)
		end
	end,
	Enforce = function(entity, sab)
		if (sab.bManaged) then

			if (entity.nwHostile != sab.empty) then
				sab.saved = entity.nwHostile
				entity.nwHostile = sab.empty
			end

			if (next(sab.empty) != nil) then
				sab.saved = table.Copy(sab.empty)

				table.Empty(sab.empty)
			end
		end

		if (entity.GetEnemy and IsValid(entity:GetEnemy())) then
			QuietTurret(entity)
		end
	end,
	Restore = function(entity, sab)
		if (sab.bManaged and entity.nwHostile == sab.empty) then
			entity.nwHostile = sab.saved
		end

		entity:Fire("Enable")

		if (sab.bManaged and NETWORK.deploy and NETWORK.deploy.ApplyRelations) then
			NETWORK.deploy.ApplyRelations(entity)
		end
	end
}

R.handlers.scanner = {
	Apply = function(entity, sab)

		if (entity:IsNPC()) then
			if (entity.SetEnemy) then
				entity:SetEnemy(NULL)
			end

			entity:AddEFlags(EFL_NO_THINK_FUNCTION)

			sab.bFrozen = true
		end
	end,
	Restore = function(entity, sab)
		if (sab.bFrozen) then
			entity:RemoveEFlags(EFL_NO_THINK_FUNCTION)
		end
	end
}

R.handlers.field = {
	Apply = function(entity, sab)

		sab.mode = entity:GetMode()

		entity:SetModeEx(entity.MODE_SHUTDOWN)
	end,
	Enforce = function(entity)
		if (entity:GetMode() != entity.MODE_SHUTDOWN) then
			return "repaired"
		end
	end,
	Restore = function(entity, sab)
		if (entity:GetMode() != entity.MODE_SHUTDOWN) then
			return
		end

		entity.integrity = entity.MaxIntegrity

		entity:SetModeEx(sab.mode or entity.MODE_CARD)
	end
}

R.handlers.lock = {
	Apply = function(entity)

		entity.nwHacked = true
		entity:Apply(false)
		entity:SetError(true)

		timer.Simple(1.5, function()
			if (IsValid(entity)) then
				entity:SetError(false)
			end
		end)
	end,
	Enforce = function(entity)
		if (!entity.nwHacked) then
			return "repaired"
		end
	end,
	Restore = function(entity)
		if (entity.nwHacked) then
			entity:Apply(true)
		end
	end
}

R.handlers.terminal = {
	Apply = function(entity)
		local user = entity.GetUser and entity:GetUser()

		if (IsValid(user) and NETWORK.cmbterm and NETWORK.cmbterm.Close) then
			NETWORK.cmbterm.Close(user)
		end

		if (entity.nwLoop) then
			entity.nwLoop:Stop()
			entity.nwLoop = nil
		end
	end,
	Enforce = function(entity)
		local user = entity.GetUser and entity:GetUser()

		if (IsValid(user) and NETWORK.cmbterm and NETWORK.cmbterm.Close) then
			NETWORK.cmbterm.Close(user)
		end
	end,
	Restore = function(entity)
		if (!entity:GetNWBool("nwBroken", false) and NETWORK.cmbterm and
			NETWORK.cmbterm.StartLoop) then
			NETWORK.cmbterm.StartLoop(entity)
		end
	end
}

R.handlers.dispenser = {
	Apply = function(entity, sab)

		local count = math.random(1, 2)
		local given = 0

		for _ = 1, count do
			for level = 1, 3 do
				local stock = entity:GetStock(level)

				if (stock <= 0) then
					continue
				end

				local ration

				for _, entry in ipairs(entity.Tickets or {}) do
					if (entry.level == level) then
						ration = entry.ration
					end
				end

				if (!ration) then
					continue
				end

				entity:SetStock(level, stock - 1)

				given = given + 1

				local delay = given * 1.6

				timer.Simple(delay, function()
					if (IsValid(entity)) then
						entity:SpawnRation(ration, 0.6)
					end
				end)

				break
			end
		end

		sab.given = given
		entity.bReady = false

		entity:EmitSound("buttons/combine_button_locked.wav", 70)
	end,
	Restore = function(entity)
		entity.bReady = true

		entity:SetDisplay(1)
	end
}

local function Sparks(entity)
	local effect = EffectData()

	effect:SetOrigin(entity:WorldSpaceCenter() + VectorRand() * 6)
	effect:SetNormal(VectorRand())
	effect:SetMagnitude(1)
	effect:SetScale(1)
	effect:SetRadius(2)

	util.Effect("Sparks", effect)

	entity:EmitSound("ambient/energy/spark" .. math.random(1, 6) .. ".wav", 62,
		math.random(92, 108), 0.6)
end

local function ClearFlags(entity)
	entity.nwRebelSab = nil
	entity:SetNWBool("nwSabotaged", false)
	entity:SetNWString("nwSabotageKind", "")
	entity:SetNWFloat("nwSabotageEnd", 0)

	R.active[entity] = nil
end

function R.EndSabotage(entity, bRepaired)
	local sab = entity.nwRebelSab

	if (!sab) then
		return
	end

	local handler = R.handlers[sab.kind]

	if (!bRepaired and handler and handler.Restore) then
		local bOk, err = pcall(handler.Restore, entity, sab)

		if (!bOk) then
			ErrorNoHalt("[rebels] восстановление " .. tostring(sab.kind) .. ": " ..
				tostring(err) .. "\n")
		end
	end

	ClearFlags(entity)

	entity.nwRebelSabNext = CurTime() + R.sabotage.reuseDelay

	entity:EmitSound("buttons/combine_button1.wav", 65, 95)

	hook.Run("NetworkRebelSabotageEnd", entity, sab.kind, bRepaired == true)
end

function R.Alert(entity, kind)
	if (math.random(100) > R.sabotage.dispatchChance) then
		return false
	end

	if (!NETWORK.dispatch or !NETWORK.dispatch.SendRadio) then
		return false
	end

	NETWORK.dispatch.SendRadio(L("rebelDispatchSabotage", L(R.kindNames[kind] or kind),
		ZoneName(entity)), Color(240, 150, 70))

	return true
end

function R.Sabotage(client, entity, kind, bKit)
	local range = bKit and R.sabotage.durationKit or R.sabotage.durationHands
	local duration = math.random(range[1], range[2])
	local sab = {
		kind = kind,
		finish = CurTime() + duration,
		by = CharKey(client) or "",
		bKit = bKit
	}

	local handler = R.handlers[kind]

	if (handler and handler.Apply) then
		local bOk, result = pcall(handler.Apply, entity, sab, client)

		if (!bOk or result == false) then
			if (!bOk) then
				ErrorNoHalt("[rebels] саботаж " .. tostring(kind) .. ": " .. tostring(result) .. "\n")
			end

			return Notice(client, "rebelSabotageFailed", "bad")
		end
	end

	entity.nwRebelSab = sab
	entity:SetNWBool("nwSabotaged", true)
	entity:SetNWString("nwSabotageKind", kind)
	entity:SetNWFloat("nwSabotageEnd", sab.finish)

	R.active[entity] = true

	Sparks(entity)
	entity:EmitSound("ambient/levels/labs/electric_explosion" .. math.random(1, 5) .. ".wav",
		72, math.random(105, 115), 0.7)

	client.nwRebelSabCooldown = CurTime() + R.sabotage.cooldown

	Notice(client, "rebelSabotageDone", "good", L(R.kindNames[kind] or kind),
		math.ceil(duration / 60))

	if (bKit and math.random(100) <= R.sabotage.kitConsumeChance and
		R.ConsumeItem(client, R.sabotage.kit)) then
		Notice(client, "rebelKitSpent", "info")
	end

	local bAlerted = R.Alert(entity, kind)

	Log(string.format("%s саботировал %s (%s) на %d с%s", NETWORK.log.Name(client),
		entity:GetClass(), ZoneName(entity), duration, bAlerted and ", диспетчер оповещён" or ""),
		entity:GetPos())

	hook.Run("NetworkRebelSabotage", client, entity, kind, duration)
end

function R.BeginSabotage(client, wanted, bHold)
	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return
	end

	if (!R.Is(client)) then
		return Notice(client, "rebelOnly", "warn")
	end

	if (client.nwRebelTask) then
		return
	end

	local wait = (client.nwRebelSabCooldown or 0) - CurTime()

	if (wait > 0) then
		return Notice(client, "rebelSabotageCooldown", "warn", math.ceil(wait))
	end

	local entity, kind = R.FindSabotageTarget(client)

	if (!IsValid(entity) or (IsValid(wanted) and wanted != entity)) then
		return Notice(client, "rebelSabotageNoTarget", "warn")
	end

	if ((entity.nwRebelSabNext or 0) > CurTime()) then
		return Notice(client, "rebelSabotageRecent", "warn")
	end

	local busy = entity.nwRebelBusy

	if (IsValid(busy) and busy != client and busy.nwRebelTask and
		busy.nwRebelTask.entity == entity) then
		return Notice(client, "rebelSabotageBusy", "warn")
	end

	local bKit = R.FindItem(client, R.sabotage.kit) != nil
	local time = bKit and R.sabotage.timeKit or R.sabotage.timeHands

	entity.nwRebelBusy = client

	local bStarted = R.StartTask(client, {
		label = "rebelSabotageProgress",
		time = time,
		bHold = bHold,
		entity = entity,
		kind = kind,
		bKit = bKit,
		nextSound = 0,
		Check = function(_, task)
			if (!IsValid(task.entity) or R.Classify(task.entity) != task.kind) then
				return false, "rebelSabotageLost"
			end

			local seen = NETWORK.util.FindLookedAt(client, R.sabotage.range + 24,
				function(candidate)
					return candidate == task.entity
				end)

			if (!IsValid(seen)) then
				return false, "rebelSabotageLost"
			end

			return true
		end,
		Tick = function(_, task)
			if (task.nextSound > CurTime()) then
				return
			end

			task.nextSound = CurTime() + math.Rand(0.9, 1.5)

			local sounds = {
				"physics/metal/metal_box_impact_soft" .. math.random(1, 3) .. ".wav",
				"weapons/stunstick/spark" .. math.random(1, 3) .. ".wav",
				"buttons/lever" .. math.random(1, 8) .. ".wav"
			}

			task.entity:EmitSound(sounds[math.random(#sounds)], 58, math.random(95, 110), 0.5)
		end,
		OnCancel = function(_, task)
			if (IsValid(task.entity) and task.entity.nwRebelBusy == client) then
				task.entity.nwRebelBusy = nil
			end
		end,
		Done = function(_, task)
			if (IsValid(task.entity) and task.entity.nwRebelBusy == client) then
				task.entity.nwRebelBusy = nil
			end

			if (!IsValid(task.entity) or R.Classify(task.entity) != task.kind) then
				return Notice(client, "rebelSabotageLost", "warn")
			end

			R.Sabotage(client, task.entity, task.kind, task.bKit)
		end
	})

	if (!bStarted) then
		entity.nwRebelBusy = nil

		return
	end

	Notice(client, bKit and "rebelSabotageStartKit" or "rebelSabotageStartHands", "info", time)
	NETWORK.chat.Send(client, "me", L("rebelSabotageMe"))
end

timer.Create("nwRebelSabotageWatch", 1, 0, function()
	for entity in pairs(R.active) do
		if (!IsValid(entity) or !entity.nwRebelSab) then
			R.active[entity] = nil

			continue
		end

		local sab = entity.nwRebelSab

		if (CurTime() >= sab.finish) then
			R.EndSabotage(entity)

			continue
		end

		local handler = R.handlers[sab.kind]

		if (handler and handler.Enforce) then
			local bOk, result = pcall(handler.Enforce, entity, sab)

			if (bOk and result == "repaired") then
				R.EndSabotage(entity, true)

				continue
			end
		end

		if (math.random() < 0.35) then
			Sparks(entity)
		end
	end
end)

hook.Add("EntityTakeDamage", "nwRebelTurret", function(victim, damage)
	local attacker = damage:GetAttacker()
	local inflictor = damage:GetInflictor()

	if ((IsValid(attacker) and attacker.nwRebelSab and attacker.nwRebelSab.kind == "turret") or
		(IsValid(inflictor) and inflictor.nwRebelSab and inflictor.nwRebelSab.kind == "turret")) then
		damage:SetDamage(0)

		return true
	end
end)

hook.Add("PlayerUse", "nwRebelTurret", function(client, entity)
	if (!IsValid(entity) or !entity.nwRebelSab or entity.nwRebelSab.kind != "turret") then
		return
	end

	if ((client.nwRebelNextUseNotice or 0) < CurTime()) then
		client.nwRebelNextUseNotice = CurTime() + 2

		Notice(client, "rebelDeviceSabotaged", "warn")
	end

	return false
end)

local function SaveWrapper(...)
	local swapped = {}

	for entity in pairs(R.active) do
		local sab = IsValid(entity) and entity.nwRebelSab

		if (sab and sab.kind == "field" and sab.mode and
			entity:GetMode() == entity.MODE_SHUTDOWN) then
			entity:SetMode(sab.mode)

			swapped[#swapped + 1] = entity
		end
	end

	local results = {pcall(R.baseEntitiesSave, ...)}

	for _, entity in ipairs(swapped) do
		if (IsValid(entity)) then
			entity:SetMode(entity.MODE_SHUTDOWN)
		end
	end

	if (!results[1]) then
		ErrorNoHalt("[rebels] сохранение сущностей: " .. tostring(results[2]) .. "\n")

		return false
	end

	return unpack(results, 2)
end

local function WrapEntitiesSave()
	if (!NETWORK.entities or !NETWORK.entities.Save or
		NETWORK.entities.Save == SaveWrapper) then
		return
	end

	R.baseEntitiesSave = NETWORK.entities.Save
	NETWORK.entities.Save = SaveWrapper
end

WrapEntitiesSave()
hook.Add("InitPostEntity", "nwRebelSaveWrap", WrapEntitiesSave)

net.Receive("nwRebelAction", function(_, client)
	local action = net.ReadUInt(2)
	local entity = net.ReadEntity()

	if ((client.nwRebelNextAction or 0) > CurTime()) then
		return
	end

	client.nwRebelNextAction = CurTime() + 0.5

	if (action == 1) then
		R.BeginSabotage(client, entity, true)
	elseif (action == 2) then
		R.BeginClean(client, entity)
	end
end)

local function GraffitiPath()
	return "network/rebel_graffiti_" .. game.GetMap() .. ".txt"
end

function R.SaveGraffiti()
	timer.Create("nwRebelGraffitiSave", 2, 1, function()
		local list = {}

		for _, entity in ipairs(ents.FindByClass("nw_graffiti")) do
			local position = entity:GetPos()
			local angles = entity:GetAngles()

			list[#list + 1] = {
				pos = {position.x, position.y, position.z},
				ang = {angles.p, angles.y, angles.r},
				slogan = entity:GetSlogan(),
				tint = entity:GetTint(),
				owner = entity:GetOwnerChar(),
				created = entity.nwCreated or os.time()
			}
		end

		file.CreateDir("network")
		file.Write(GraffitiPath(), util.TableToJSON(list, true))
	end)
end

function R.SpawnGraffiti(position, angles, slogan, tint, owner, created)
	local entity = ents.Create("nw_graffiti")

	if (!IsValid(entity)) then
		return
	end

	entity:SetPos(position)
	entity:SetAngles(angles)
	entity:Spawn()
	entity:Activate()

	entity:SetSlogan(math.Clamp(math.Round(tonumber(slogan) or 1), 1, #R.slogans))
	entity:SetTint(math.Clamp(math.Round(tonumber(tint) or 1), 1, #R.tints))
	entity:SetOwnerChar(tostring(owner or ""))

	entity.nwCreated = tonumber(created) or os.time()
	entity.nwSpawnedAt = CurTime()

	return entity
end

function R.LoadGraffiti()
	for _, entity in ipairs(ents.FindByClass("nw_graffiti")) do
		entity:Remove()
	end

	local raw = file.Read(GraffitiPath(), "DATA")
	local data = raw and util.JSONToTable(raw)

	if (!istable(data)) then
		return
	end

	local loaded = 0

	for _, entry in ipairs(data) do
		if (!istable(entry) or !istable(entry.pos) or !istable(entry.ang)) then
			continue
		end

		local entity = R.SpawnGraffiti(
			Vector(tonumber(entry.pos[1]) or 0, tonumber(entry.pos[2]) or 0,
				tonumber(entry.pos[3]) or 0),
			Angle(tonumber(entry.ang[1]) or 0, tonumber(entry.ang[2]) or 0,
				tonumber(entry.ang[3]) or 0),
			entry.slogan, entry.tint, entry.owner, entry.created)

		if (IsValid(entity)) then
			loaded = loaded + 1
		end
	end

	if (loaded > 0) then
		NETWORK.util.Print("Надписей повстанцев восстановлено: " .. loaded)
	end
end

hook.Add("InitPostEntity", "nwRebelGraffiti", function()
	timer.Simple(3, R.LoadGraffiti)
end)

hook.Add("PostCleanupMap", "nwRebelGraffiti", function()
	timer.Simple(1, R.LoadGraffiti)
end)

local function CountOwned(key)
	local count = 0

	for _, entity in ipairs(ents.FindByClass("nw_graffiti")) do
		if (entity:GetOwnerChar() == key) then
			count = count + 1
		end
	end

	return count
end

local function WallTrace(client)
	local start = client:GetShootPos()

	return util.TraceLine({
		start = start,
		endpos = start + client:GetAimVector() * R.graffiti.range,
		filter = client,
		mask = MASK_SOLID_BRUSHONLY
	})
end

local function IsWall(trace)
	return trace.Hit and trace.HitWorld and !trace.HitSky and
		math.abs(trace.HitNormal.z) < 0.3
end

local function SpendSpray(client, sprayItem)
	local state = NETWORK.inventory.GetState(client)
	local base = NETWORK.item.Get(R.graffiti.spray)
	local max = base and base.maxUses or 3

	for _, list in ipairs({"items", "storage"}) do
		for index, item in pairs(state[list] or {}) do
			if (item == sprayItem) then
				item.uses = (item.uses or max) - 1

				if (item.uses <= 0) then
					NETWORK.inventory.Put(state, list, index, nil, nil)
				end

				NETWORK.inventory.Sync(client)

				return true, math.max(item.uses, 0)
			end
		end
	end

	return false
end

function R.BeginSpray(client, sprayItem)
	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return
	end

	if (!R.Is(client)) then
		return Notice(client, "rebelOnly", "warn")
	end

	if (client.nwRebelTask) then
		return
	end

	local key = CharKey(client)

	if (!key) then
		return
	end

	if (CountOwned(key) >= R.graffiti.perCharacter) then
		return Notice(client, "rebelGraffitiLimit", "warn", R.graffiti.perCharacter)
	end

	local trace = WallTrace(client)

	if (!IsWall(trace)) then
		return Notice(client, "rebelGraffitiNoWall", "warn")
	end

	for _, entity in ipairs(ents.FindInSphere(trace.HitPos, R.graffiti.spacing)) do
		if (entity:GetClass() == "nw_graffiti") then
			return Notice(client, "rebelGraffitiTooClose", "warn")
		end
	end

	if (!istable(sprayItem) or sprayItem.id != R.graffiti.spray) then
		local _, _, found = R.FindItem(client, R.graffiti.spray)

		sprayItem = found
	end

	if (!sprayItem) then
		return
	end

	local bStarted = R.StartTask(client, {
		label = "rebelSprayProgress",
		time = R.graffiti.sprayTime,
		hit = trace.HitPos,
		normal = trace.HitNormal,
		item = sprayItem,
		nextSound = 0,
		Check = function(_, task)
			local current = WallTrace(client)

			if (!IsWall(current) or current.HitPos:Distance(task.hit) > 28) then
				return false, "rebelGraffitiLost"
			end

			return true
		end,
		Tick = function(_, task)
			if (task.nextSound > CurTime()) then
				return
			end

			task.nextSound = CurTime() + 1.1

			client:EmitSound("player/sprayer.wav", 60, math.random(92, 104), 0.7)
		end,
		Done = function(_, task)
			if (CountOwned(key) >= R.graffiti.perCharacter) then
				return Notice(client, "rebelGraffitiLimit", "warn", R.graffiti.perCharacter)
			end

			local bSpent, left = SpendSpray(client, task.item)

			if (!bSpent) then
				return Notice(client, "rebelGraffitiLost", "warn")
			end

			local all = ents.FindByClass("nw_graffiti")

			if (#all >= R.graffiti.mapLimit) then
				table.sort(all, function(a, b)
					return (a.nwCreated or 0) < (b.nwCreated or 0)
				end)

				for index = 1, #all - R.graffiti.mapLimit + 1 do
					all[index]:Remove()
				end
			end

			local angles = task.normal:Angle()

			angles:RotateAroundAxis(angles:Up(), 90)
			angles:RotateAroundAxis(angles:Forward(), 90)

			local entity = R.SpawnGraffiti(task.hit + task.normal * 0.6, angles,
				math.random(#R.slogans), math.random(#R.tints), key, os.time())

			if (!IsValid(entity)) then
				return
			end

			Notice(client, "rebelGraffitiDone", "good", left or 0)

			Log(string.format("%s нарисовал граффити (%s)", NETWORK.log.Name(client),
				ZoneName(entity)), entity:GetPos())

			R.SaveGraffiti()

			hook.Run("NetworkRebelGraffiti", client, entity)
		end
	})

	if (bStarted) then
		NETWORK.chat.Send(client, "me", L("rebelSprayMe"))
	end
end

function R.BeginClean(client, wanted)
	if (!IsValid(client) or !R.CanClean(client) or client.nwRebelTask) then
		return
	end

	local entity = R.FindGraffiti(client)

	if (!IsValid(entity) or (IsValid(wanted) and wanted != entity)) then
		return Notice(client, "rebelGraffitiNoTarget", "warn")
	end

	R.StartTask(client, {
		label = "rebelCleanProgress",
		time = R.graffiti.cleanTime,
		bHold = true,
		entity = entity,
		nextSound = 0,
		Check = function(_, task)
			if (!IsValid(task.entity) or R.FindGraffiti(client) != task.entity) then
				return false, "rebelGraffitiLost"
			end

			return true
		end,
		Tick = function(_, task)
			if (task.nextSound > CurTime()) then
				return
			end

			task.nextSound = CurTime() + 0.8

			client:EmitSound("physics/cardboard/cardboard_box_impact_soft" ..
				math.random(1, 7) .. ".wav", 55, math.random(120, 140), 0.5)
		end,
		Done = function(_, task)
			local target = task.entity

			if (!IsValid(target)) then
				return
			end

			local owner = target:GetOwnerChar()
			local position = target:GetPos()
			local zoneName = ZoneName(target)
			local bOwn = owner != "" and owner == CharKey(client)
			local bFresh = CurTime() - (target.nwSpawnedAt or 0) < R.graffiti.freshTime

			target:Remove()
			R.SaveGraffiti()

			if (!bOwn and !bFresh) then
				if (NETWORK.currency and NETWORK.currency.Add and R.graffiti.rewardTokens > 0) then
					NETWORK.currency.Add(client, R.graffiti.rewardTokens)
				end

				if (!NETWORK.factions.IsAlliance(client) and NETWORK.loyalty and
					NETWORK.loyalty.Add and R.graffiti.rewardLoyalty > 0) then
					NETWORK.loyalty.Add(client, R.graffiti.rewardLoyalty, "graffiti")
				end

				Notice(client, "rebelGraffitiCleaned", "good", R.graffiti.rewardTokens)
			else
				Notice(client, "rebelGraffitiCleanedNoReward", "info")
			end

			Log(string.format("%s закрасил граффити (%s)", NETWORK.log.Name(client), zoneName),
				position)

			hook.Run("NetworkRebelGraffitiCleaned", client, owner)
		end
	})
end

function R.AdminClearGraffiti(client, bAll)
	local removed = 0
	local origin = IsValid(client) and client:GetPos()

	for _, entity in ipairs(ents.FindByClass("nw_graffiti")) do
		if (bAll or !origin or entity:GetPos():Distance(origin) <= 400) then
			entity:Remove()

			removed = removed + 1
		end
	end

	R.SaveGraffiti()

	Notice(client, "rebelGraffitiCleared", "good", removed)

	Log(string.format("%s стёр граффити: %d", NETWORK.log.Name(client), removed),
		origin or nil)
end

local function LoyaltyWrapper(client, amount, reason)
	if (IsValid(client) and client:IsPlayer() and (tonumber(amount) or 0) > 0 and
		R.graffiti.reasons[tostring(reason or "")]) then
		local count = R.GetGraffitiCountAt(client:GetPos())

		if (count > 0 and math.random() <
			math.min(count * R.graffiti.chancePer, R.graffiti.chanceMax)) then
			if ((client.nwRebelLoyaltyNotice or 0) < CurTime()) then
				client.nwRebelLoyaltyNotice = CurTime() + 60

				Notice(client, "rebelGraffitiLoyalty", "warn")
			end

			hook.Run("NetworkRebelLoyaltyBlocked", client, amount, reason, count)

			return
		end
	end

	return R.baseLoyaltyAdd(client, amount, reason)
end

local function WrapLoyalty()
	if (!NETWORK.loyalty or !NETWORK.loyalty.Add or NETWORK.loyalty.Add == LoyaltyWrapper) then
		return
	end

	R.baseLoyaltyAdd = NETWORK.loyalty.Add
	NETWORK.loyalty.Add = LoyaltyWrapper
end

WrapLoyalty()
hook.Add("InitPostEntity", "nwRebelLoyaltyWrap", WrapLoyalty)

hook.Add("NetworkChatSent", "nwRebelRadio", function(speaker, id, text, receivers)
	if (id != "rebelradio" or !IsValid(speaker)) then
		return
	end

	local heard = {}

	for _, listener in ipairs(receivers or {}) do
		heard[listener] = true
	end

	local intercept = {}

	for _, listener in ipairs(player.GetAll()) do
		if (heard[listener] or listener == speaker or !listener:HasCharacter() or
			!listener:Alive()) then
			continue
		end

		if (NETWORK.zone and NETWORK.zone.IsOutlands and
			NETWORK.zone.IsOutlands(listener:GetPos())) then
			continue
		end

		if (NETWORK.factions.IsAlliance(listener) and
			R.radio.interceptClasses[listener:GetNWString("nwClass", "")]) then
			intercept[#intercept + 1] = listener
		elseif (NETWORK.radio and NETWORK.radio.GetFreq(listener) != "") then
			net.Start("nwChatMessage")
				net.WriteString("rebeljam")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString(R.Garble(text))
			net.Send(listener)
		end
	end

	if (#intercept > 0) then
		local line = L("rebelInterceptText")

		local zone = NETWORK.zone and NETWORK.zone.At(speaker:GetPos())

		if (zone and zone.name and math.random(100) <= R.radio.interceptZoneChance) then
			line = L("rebelInterceptZone", zone.name)
		end

		net.Start("nwChatMessage")
			net.WriteString("rebelintercept")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(line)
		net.Send(intercept)
	end
end)

local pocketPath = "network/rebel_pockets.txt"

R.pockets = R.pockets or {}

function R.SavePockets()
	timer.Create("nwRebelPocketSave", 2, 1, function()
		local out = {}

		for key, pocket in pairs(R.pockets) do
			local entry = {}
			local bAny = false

			for slot = 1, R.pocket.slots do
				if (pocket[slot]) then
					entry["s" .. slot] = pocket[slot]
					bAny = true
				end
			end

			if (bAny) then
				out[key] = entry
			end
		end

		file.CreateDir("network")
		file.Write(pocketPath, util.TableToJSON(out, true))
	end)
end

function R.LoadPockets()
	local raw = file.Read(pocketPath, "DATA")
	local data = raw and util.JSONToTable(raw)

	R.pockets = {}

	if (!istable(data)) then
		return
	end

	for key, entry in pairs(data) do
		if (!istable(entry)) then
			continue
		end

		local pocket = {}

		for slot = 1, R.pocket.slots do
			local item = entry["s" .. slot]

			if (istable(item) and item.id and NETWORK.item.Get(item.id)) then
				pocket[slot] = item
			end
		end

		R.pockets[tostring(key)] = pocket
	end
end

hook.Add("Initialize", "nwRebelPockets", R.LoadPockets)

function R.GetPocket(client, bCreate)
	local key = CharKey(client)

	if (!key) then
		return
	end

	if (!R.pockets[key] and bCreate) then
		R.pockets[key] = {}
	end

	return R.pockets[key]
end

function R.PocketCount(client)
	local pocket = R.GetPocket(client)
	local count = 0

	for slot = 1, R.pocket.slots do
		if (pocket and pocket[slot]) then
			count = count + 1
		end
	end

	return count
end

function R.SyncPocket(client, bOpen)
	if (!IsValid(client)) then
		return
	end

	local pocket = R.GetPocket(client) or {}
	local list = {}

	for slot = 1, R.pocket.slots do
		if (pocket[slot]) then
			list[#list + 1] = {slot = slot, item = pocket[slot]}
		end
	end

	net.Start("nwRebelPocket")
		net.WriteBool(bOpen == true)
		net.WriteBool(R.Is(client))
		NETWORK.util.WriteTable({slots = R.pocket.slots, list = list})
	net.Send(client)
end

function R.OpenPocket(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	if (!R.Is(client) and R.PocketCount(client) == 0) then
		return Notice(client, "rebelOnly", "warn")
	end

	R.SyncPocket(client, true)
end

net.Receive("nwRebelPocketMove", function(_, client)
	local bIn = net.ReadBool()
	local index = net.ReadUInt(16)

	if ((client.nwRebelPocketNext or 0) > CurTime()) then
		return
	end

	client.nwRebelPocketNext = CurTime() + 0.3

	if (!client:Alive() or !client:HasCharacter()) then
		return
	end

	if ((NETWORK.restraint and NETWORK.restraint.IsTied and NETWORK.restraint.IsTied(client)) or
		client:GetNWBool("nwSearched", false) or client.nwRebelTask) then
		return Notice(client, "rebelPocketBusy", "warn")
	end

	local state = NETWORK.inventory.GetState(client)

	if (bIn) then
		if (!R.Is(client)) then
			return Notice(client, "rebelOnly", "warn")
		end

		local item = NETWORK.inventory.At(state, "items", index)

		if (!item) then
			return
		end

		if (!R.CanPocket(item)) then
			return Notice(client, "rebelPocketTooBig", "warn")
		end

		local pocket = R.GetPocket(client, true)
		local free

		for slot = 1, R.pocket.slots do
			if (!pocket[slot]) then
				free = slot

				break
			end
		end

		if (!free) then
			return Notice(client, "rebelPocketFull", "warn")
		end

		NETWORK.inventory.Put(state, "items", index, nil, nil)

		item.x, item.y = nil, nil
		pocket[free] = item

		client:EmitSound("framework/inv/cloth.wav", 45, math.random(95, 105), 0.5)

		Log(string.format("%s спрятал в тайный карман %s x%d", NETWORK.log.Name(client),
			NETWORK.item.GetName(item), item.amount or 1), client:GetPos())
	else
		local pocket = R.GetPocket(client)
		local item = pocket and pocket[index]

		if (!item) then
			return
		end

		local spot = NETWORK.inventory.FindSpot(state.items, NETWORK.inventory.columns,
			NETWORK.inventory.rows, item)

		if (!spot) then
			return Notice(client, "rebelPocketNoRoom", "warn")
		end

		pocket[index] = nil
		state.items[spot] = item

		client:EmitSound("framework/inv/cloth2.wav", 45, math.random(95, 105), 0.5)
	end

	NETWORK.inventory.Sync(client)
	R.SyncPocket(client)
	R.SavePockets()
end)

function R.SpillPocket(target, position)
	local pocket = R.GetPocket(target)

	if (!pocket) then
		return 0, {}
	end

	local state = NETWORK.inventory.GetState(target)
	local names = {}

	for slot = 1, R.pocket.slots do
		local item = pocket[slot]

		if (!item) then
			continue
		end

		pocket[slot] = nil
		names[#names + 1] = NETWORK.item.GetName(item)

		local spot = NETWORK.inventory.FindSpot(state.items, NETWORK.inventory.columns,
			NETWORK.inventory.rows, item)

		if (spot) then
			state.items[spot] = item
		else
			NETWORK.item.Spawn(item.id, (position or target:GetPos()) +
				Vector(math.random(-12, 12), math.random(-12, 12), 12),
				Angle(0, math.random(0, 360), 0), item.amount, item.data)
		end
	end

	NETWORK.inventory.Sync(target)
	R.SyncPocket(target)
	R.SavePockets()

	return #names, names
end

function R.OnSearch(searcher, target)
	if (!IsValid(searcher) or !IsValid(target) or !target:IsPlayer() or
		!NETWORK.factions.IsAlliance(searcher)) then
		return false
	end

	if (R.PocketCount(target) == 0) then
		return false
	end

	target.nwRebelPocketRolls = target.nwRebelPocketRolls or {}

	local previous = target.nwRebelPocketRolls[searcher]

	if (previous and previous.time > CurTime()) then
		return false
	end

	local bFound = math.random(100) <= R.pocket.revealChance

	target.nwRebelPocketRolls[searcher] = {time = CurTime() + R.pocket.rerollDelay}

	Log(string.format("%s обыскал %s: тайный карман %s", NETWORK.log.Name(searcher),
		NETWORK.log.Name(target), bFound and "НАЙДЕН" or "не найден"), target:GetPos())

	if (!bFound) then
		return false
	end

	local count, names = R.SpillPocket(target, target:GetPos())

	if (count == 0) then
		return false
	end

	Notice(searcher, "rebelPocketFound", "good", table.concat(names, ", "))
	Notice(target, "rebelPocketDiscovered", "bad")

	hook.Run("NetworkRebelPocketFound", searcher, target, names)

	return true
end

hook.Add("PlayerDeath", "nwRebelPocket", function(client)
	if (R.PocketCount(client) == 0) then
		return
	end

	local position = client:GetPos()

	timer.Simple(0.1, function()
		if (!IsValid(client)) then
			return
		end

		local pocket = R.GetPocket(client)
		local ragdoll = client:GetNWEntity("nwRagdoll", NULL)

		for slot = 1, R.pocket.slots do
			local item = pocket and pocket[slot]

			if (!item) then
				continue
			end

			pocket[slot] = nil

			local spot

			if (IsValid(ragdoll)) then
				ragdoll.nwLoot = ragdoll.nwLoot or {}

				spot = NETWORK.inventory.FindSpot(ragdoll.nwLoot, NETWORK.inventory.columns,
					NETWORK.inventory.rows, item)
			end

			if (spot) then
				ragdoll.nwLoot[spot] = item
				ragdoll:SetNWBool("nwLooted", false)
			else
				NETWORK.item.Spawn(item.id, position + Vector(0, 0, 16),
					Angle(0, math.random(0, 360), 0), item.amount, item.data)
			end
		end

		R.SyncPocket(client)
		R.SavePockets()
	end)
end)

hook.Add("NetworkCharacterLoaded", "nwRebelPocket", function(client)
	timer.Simple(1, function()
		if (IsValid(client)) then
			R.SyncPocket(client)
		end
	end)
end)

hook.Add("NetworkClassAssigned", "nwRebelIntro", function(target, class)
	if (!IsValid(target) or !class or !R.IsClass(class.id)) then
		return
	end

	timer.Simple(1, function()
		if (!IsValid(target)) then
			return
		end

		Notice(target, class.description or "classRebelDesc", "info")
		R.SyncPocket(target)
	end)
end)
