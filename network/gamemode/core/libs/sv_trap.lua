NETWORK.trap = NETWORK.trap or {}

local function Progress(client, key, duration)
	net.Start("nwProgress")
		net.WriteString(key or "")
		net.WriteFloat(duration or 0)
	net.Send(client)
end

local function Notice(client, key, tone, ...)
	if (NETWORK.notice and NETWORK.notice.Send) then
		return NETWORK.notice.Send(client, key, tone or "info", ...)
	end

	NETWORK.chat.Notice(client, key)
end

NETWORK.trap.Notice = Notice

function NETWORK.trap.Log(text, position)
	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("trap", text, position)
	end
end

function NETWORK.trap.Name(client)
	if (NETWORK.log and NETWORK.log.Name) then
		return NETWORK.log.Name(client)
	end

	return IsValid(client) and (client:IsPlayer() and client:Nick() or client:GetClass()) or "-"
end

function NETWORK.trap.IsRebelSide(entity)
	if (!IsValid(entity)) then
		return false
	end

	if (entity:IsPlayer()) then
		return NETWORK.trap.IsRebel(entity)
	end

	if (entity:GetNWBool("nwTrapHacked", false)) then
		return true
	end

	local rebel = NETWORK.relations and NETWORK.relations.rebel

	return rebel != nil and rebel[entity:GetClass()] == true
end

function NETWORK.trap.IsAllianceSide(entity)
	if (!IsValid(entity)) then
		return false
	end

	if (entity:IsPlayer()) then
		return NETWORK.factions.IsAlliance(entity)
	end

	if (entity:GetNWBool("nwTrapHacked", false)) then
		return false
	end

	local combine = NETWORK.relations and NETWORK.relations.combine

	return combine != nil and combine[entity:GetClass()] == true
end

NETWORK.trap.ignoreNPC = {
	npc_cscanner = true,
	npc_clawscanner = true,
	npc_manhack = true,
	npc_turret_floor = true,
	npc_turret_ceiling = true,
	npc_helicopter = true,
	npc_combinegunship = true,
	npc_combinedropship = true,
	npc_sniper = true,
	npc_barnacle = true,
	nw_npc = true
}

function NETWORK.trap.IsLiving(entity)
	if (!IsValid(entity)) then
		return false
	end

	if (entity:IsPlayer()) then
		return entity:Alive() and entity:HasCharacter() and
			entity:GetMoveType() != MOVETYPE_NOCLIP and
			entity:GetMoveType() != MOVETYPE_OBSERVER
	end

	return entity:IsNPC() and entity:Health() > 0 and
		!NETWORK.trap.ignoreNPC[entity:GetClass()]
end

function NETWORK.trap.Count(charID)
	local total = 0

	if (!charID or charID <= 0) then
		return 0
	end

	for _, entity in ipairs(ents.GetAll()) do
		if (entity.nwOwnerChar == charID and entity.nwTrapLimited) then
			total = total + 1
		end
	end

	return total
end

function NETWORK.trap.CanPlace(client, data)
	if (!data or !data.bLimited or client:IsSuperAdmin()) then
		return true
	end

	local limit = tonumber(NETWORK.config.Get("trapLimit")) or 4

	if (limit > 0 and NETWORK.trap.Count(client:GetCharacterID()) >= limit) then
		return false, "trapLimit"
	end

	return true
end

function NETWORK.trap.Explode(entity, position, radius, damage)
	local owner = IsValid(entity) and entity.nwOwner
	local attacker = (IsValid(owner) and owner:IsPlayer()) and owner or
		(IsValid(entity) and entity or game.GetWorld())
	local boom = ents.Create("env_explosion")

	if (IsValid(boom)) then
		boom:SetPos(position)
		boom:SetKeyValue("iMagnitude", "0")
		boom:SetKeyValue("spawnflags", "1")
		boom:Spawn()
		boom:Fire("Explode", "", 0)
		boom:Fire("Kill", "", 1)
	else
		local effect = EffectData()

		effect:SetOrigin(position)

		util.Effect("Explosion", effect, true, true)
	end

	util.BlastDamage(IsValid(entity) and entity or game.GetWorld(), attacker, position,
		radius, damage)
	util.ScreenShake(position, 6, 80, 0.8, radius * 2)
end

function NETWORK.trap.BeginTask(client, entity, duration, key, OnDone, bHoldUse)
	if (client.nwTrapTask or client.nwDeployTask) then
		return false
	end

	client.nwTrapTask = {
		entity = entity,
		finish = CurTime() + duration,
		OnDone = OnDone,
		bHoldUse = bHoldUse
	}

	Progress(client, key, duration)

	return true
end

function NETWORK.trap.CancelTask(client, key)
	if (!client.nwTrapTask) then
		return
	end

	client.nwTrapTask = nil

	Progress(client, "", 0)

	if (key) then
		Notice(client, key, "warn")
	end
end

local function StillAiming(client, entity)
	local trace = client:GetEyeTrace()

	if (trace.Entity == entity) then
		return true
	end

	return trace.HitPos:Distance(entity:WorldSpaceCenter()) < 48
end

timer.Create("nwTrapTasks", 0.1, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local task = client.nwTrapTask

		if (!task) then
			continue
		end

		local entity = task.entity

		if (!client:Alive() or !IsValid(entity) or IsValid(client.nwRagdollEntity) or
			NETWORK.trap.IsRooted(client) or
			client:GetPos():Distance(entity:GetPos()) > NETWORK.trap.useRange + 40) then
			NETWORK.trap.CancelTask(client, "trapInterrupted")

			continue
		end

		if (task.bHoldUse and (!client:KeyDown(IN_USE) or !StillAiming(client, entity))) then
			NETWORK.trap.CancelTask(client, "trapInterrupted")

			continue
		end

		if (CurTime() < task.finish) then
			continue
		end

		client.nwTrapTask = nil

		task.OnDone(client, entity)
	end
end)

hook.Add("StartCommand", "nwTrapTask", function(client, cmd)
	if (!client.nwTrapTask) then
		return
	end

	cmd:ClearMovement()
	cmd:RemoveKey(IN_JUMP)
	cmd:RemoveKey(IN_ATTACK)
	cmd:RemoveKey(IN_ATTACK2)
	cmd:RemoveKey(IN_SPEED)
end)

function NETWORK.trap.ReturnKit(client, id, position)
	if (!id or !NETWORK.item.Get(id)) then
		return
	end

	if (NETWORK.inventory.Give(client, id, 1)) then
		return
	end

	if (NETWORK.item.Spawn) then
		NETWORK.item.Spawn(id, position or client:GetPos() + Vector(0, 0, 16))
	end
end

function NETWORK.trap.Use(client, entity)
	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter() or !client:Alive()) then
		return
	end

	if (client.nwTrapTask or (client.nwNextTrapUse or 0) > CurTime()) then
		return
	end

	client.nwNextTrapUse = CurTime() + 0.5

	if (entity.bExploding) then
		return
	end

	local victim = entity.GetVictim and entity:GetVictim()

	if (IsValid(victim)) then

		if (victim == client) then
			return
		end

		NETWORK.trap.BeginTask(client, entity, NETWORK.trap.freeTime, "trapFreeing",
			function(helper, trap)
				if (trap.Release) then
					trap:Release(helper)
				end

				Notice(helper, "trapFreed", "good")
				NETWORK.trap.Log(NETWORK.trap.Name(helper) .. " освободил из капкана " ..
					NETWORK.trap.Name(victim), trap:GetPos())
			end, true)

		return
	end

	if (entity.bTriggered) then
		return
	end

	NETWORK.trap.BeginTask(client, entity, NETWORK.trap.defuseTime, "trapDefusing",
		function(defuser, trap)
			if (trap.bTriggered or trap.bExploding) then
				return
			end

			local data = NETWORK.deploy.Get(trap.nwDeployID or trap:GetNWString("nwDeploy", ""))
			local bRebel = NETWORK.trap.IsRebel(defuser)

			NETWORK.trap.Log(NETWORK.trap.Name(defuser) .. " обезвредил " .. trap:GetClass() ..
				" (владелец: " .. NETWORK.trap.Name(trap.nwOwner) .. ")", trap:GetPos())

			trap:EmitSound("weapons/slam/mine_mode.wav", 60, 90)
			trap.bDefused = true
			trap:Remove()

			if (bRebel and data) then
				NETWORK.trap.ReturnKit(defuser, data.item, trap:GetPos())
				Notice(defuser, "trapDefusedKit", "good")
			else
				Notice(defuser, "trapDefused", "good")
			end
		end, true)
end

function NETWORK.trap.Root(victim, trap, duration)
	if (victim:IsPlayer()) then
		victim:SetNWFloat("nwTrapRoot", CurTime() + duration)
		victim:SetNWEntity("nwTrapBy", trap)

		NETWORK.movement.Apply(victim)

		return
	end

	if (victim:IsNPC()) then
		victim.nwTrapMoveType = victim.nwTrapMoveType or victim:GetMoveType()
		victim:StopMoving()
		victim:SetMoveType(MOVETYPE_NONE)
	end
end

function NETWORK.trap.Unroot(victim)
	if (!IsValid(victim)) then
		return
	end

	if (victim:IsPlayer()) then
		victim:SetNWFloat("nwTrapRoot", 0)
		victim:SetNWEntity("nwTrapBy", NULL)

		NETWORK.movement.Apply(victim)

		return
	end

	if (victim:IsNPC() and victim.nwTrapMoveType) then
		victim:SetMoveType(victim.nwTrapMoveType)
		victim.nwTrapMoveType = nil
	end
end

hook.Add("KeyPress", "nwTrapStruggle", function(client, key)
	if (key != IN_USE or !NETWORK.trap.IsRooted(client)) then
		return
	end

	if ((client.nwNextStruggle or 0) > CurTime()) then
		return
	end

	client.nwNextStruggle = CurTime() + 0.35

	local trap = client:GetNWEntity("nwTrapBy", NULL)

	client:EmitSound("physics/metal/metal_chainlink_impact_soft" .. math.random(1, 3) .. ".wav",
		60, math.random(90, 110))
	client:ViewPunch(Angle(math.Rand(-2, 2), math.Rand(-2, 2), 0))

	if (math.random() > NETWORK.trap.struggleChance) then
		return
	end

	if (IsValid(trap) and trap.Release) then
		trap:Release(client)
	else
		NETWORK.trap.Unroot(client)
	end

	Notice(client, "trapStruggleFree", "good")
end)

local function ClearRoot(client)
	if (client:GetNWFloat("nwTrapRoot", 0) <= 0) then
		return
	end

	local trap = client:GetNWEntity("nwTrapBy", NULL)

	if (IsValid(trap) and trap.Release) then
		trap:Release()
	end

	NETWORK.trap.Unroot(client)
end

hook.Add("PlayerDeath", "nwTrap", function(client)
	ClearRoot(client)
	NETWORK.trap.CancelTask(client)
end)

hook.Add("PlayerSpawn", "nwTrap", function(client)
	client:SetNWFloat("nwTrapRoot", 0)
	client:SetNWEntity("nwTrapBy", NULL)
	client.nwTrapTask = nil
end)

hook.Add("PlayerDisconnected", "nwTrap", function(client)
	ClearRoot(client)
end)

hook.Add("NetworkDeploySpawned", "nwTrap", function(client, entity, data)
	if (!data or !data.bLimited) then
		return
	end

	local minutes = tonumber(NETWORK.config.Get("trapLifetime")) or 45

	entity.nwTrapLimited = true
	entity.nwOwnerChar = client:GetCharacterID()
	entity.bNoPersist = true

	if (minutes > 0) then
		entity.nwTrapExpire = CurTime() + minutes * 60
	end

	NETWORK.trap.Log(NETWORK.trap.Name(client) .. " установил " .. data.id, entity:GetPos())
end)

timer.Create("nwTrapExpire", 20, 0, function()
	local now = CurTime()
	local minutes = tonumber(NETWORK.config.Get("trapLifetime")) or 45

	for _, entity in ipairs(ents.GetAll()) do

		if (!entity.nwTrapExpire and minutes > 0 and entity:GetClass() == "npc_turret_floor" and
			entity:GetNWString("nwDeploy", "") == "hackedturret") then
			entity.nwTrapExpire = now + minutes * 60

			if (!entity:GetNWBool("nwTrapHacked", false)) then
				NETWORK.trap.MakeHacked(entity, nil, false)
			end
		end

		if (entity.nwTrapExpire and entity.nwTrapExpire <= now) then
			NETWORK.trap.Log("срок вышел: " .. entity:GetClass() .. " (владелец: " ..
				NETWORK.trap.Name(entity.nwOwner) .. ")", entity:GetPos())

			entity:Remove()
		end
	end
end)

NETWORK.trap.hackedColor = Color(255, 150, 120)

function NETWORK.trap.MakeHacked(turret, client, bFresh)
	if (!IsValid(turret)) then
		return
	end

	turret.nwHostile = {}

	for _, id in ipairs(NETWORK.factions.order or {}) do
		local faction = NETWORK.factions.Get(id)

		turret.nwHostile[id] = faction != nil and faction.bCombine == true
	end

	if (IsValid(client)) then
		turret.nwOwner = client
		turret.nwOwnerChar = client:GetCharacterID()
		turret.nwOwnerFaction = client:GetCharacterFaction()
		turret:SetNWEntity("nwDeployOwner", client)
	end

	turret.nwDeployID = "hackedturret"
	turret.nwNoSalvage = true
	turret.nwTrapHP = turret.nwTrapHP or NETWORK.trap.turretHealth

	turret:SetNWString("nwDeploy", "hackedturret")
	turret:SetNWBool("nwTrapHacked", true)
	turret:SetColor(NETWORK.trap.hackedColor)
	turret:SetEnemy(NULL)
	turret:ClearEnemyMemory()

	if (!bFresh) then
		local effect = EffectData()

		effect:SetOrigin(turret:WorldSpaceCenter())
		effect:SetMagnitude(2)
		effect:SetScale(1)
		effect:SetRadius(4)

		util.Effect("Sparks", effect, true, true)
		turret:EmitSound("npc/turret_floor/retract.wav", 70, 90)
	end

	NETWORK.deploy.ApplyRelations(turret)
	NETWORK.trap.RelateTurret(turret)
end

function NETWORK.trap.RelateTurret(turret)
	if (!IsValid(turret) or !turret:GetNWBool("nwTrapHacked", false)) then
		return
	end

	local combine = NETWORK.relations and NETWORK.relations.combine or {}
	local rebel = NETWORK.relations and NETWORK.relations.rebel or {}

	for _, npc in ipairs(ents.GetAll()) do
		if (npc == turret or !npc:IsNPC()) then
			continue
		end

		local class = npc:GetClass()

		if (npc:GetNWBool("nwTrapHacked", false) or rebel[class]) then
			turret:AddEntityRelationship(npc, D_LI, 99)
			npc:AddEntityRelationship(turret, D_LI, 99)
		elseif (combine[class]) then
			turret:AddEntityRelationship(npc, D_HT, 99)
			npc:AddEntityRelationship(turret, D_HT, 99)
		end
	end
end

timer.Create("nwTrapHackedTurrets", 2, 0, function()
	for _, turret in ipairs(ents.FindByClass("npc_turret_floor")) do
		if (turret:GetNWBool("nwTrapHacked", false)) then
			NETWORK.trap.RelateTurret(turret)
		end
	end
end)

hook.Add("EntityTakeDamage", "nwTrapHackedTurret", function(entity, damage)
	if (entity:GetClass() != "npc_turret_floor" or !entity:GetNWBool("nwTrapHacked", false)) then
		return
	end

	entity.nwTrapHP = (entity.nwTrapHP or NETWORK.trap.turretHealth) - damage:GetDamage()

	if (entity.nwTrapHP > 0 or entity.bTrapDead) then
		return
	end

	entity.bTrapDead = true

	local position = entity:WorldSpaceCenter()
	local effect = EffectData()

	effect:SetOrigin(position)

	util.Effect("Explosion", effect, true, true)

	NETWORK.trap.Log("взломанная турель уничтожена (" ..
		NETWORK.trap.Name(damage:GetAttacker()) .. ")", position)

	entity:Remove()
end)

function NETWORK.trap.CanHack(entity)
	return IsValid(entity) and entity:GetClass() == "npc_turret_floor" and
		!entity:GetNWBool("nwTrapHacked", false)
end

function NETWORK.trap.StartHack(client)
	if (!NETWORK.trap.IsRebel(client)) then
		Notice(client, "trapNoAccess", "warn")

		return false
	end

	local turret = NETWORK.util.FindLookedAt(client, NETWORK.trap.useRange, NETWORK.trap.CanHack)

	if (!IsValid(turret)) then
		Notice(client, "trapHackNoTarget", "warn")

		return false
	end

	local bAllowed, reason = NETWORK.trap.CanPlace(client, NETWORK.deploy.Get("hackedturret"))

	if (bAllowed == false) then
		Notice(client, reason or "trapLimit", "warn")

		return false
	end

	turret:EmitSound("buttons/combine_button2.wav", 60, 110)

	return NETWORK.trap.BeginTask(client, turret, NETWORK.trap.hackTime, "trapHacking",
		function(hacker, target)
			if (!NETWORK.trap.CanHack(target)) then
				return
			end

			if (!NETWORK.inventory.Take(hacker, "turret_hack_module", 1)) then
				return Notice(hacker, "deployNoItem", "warn")
			end

			local minutes = tonumber(NETWORK.config.Get("trapLifetime")) or 45

			NETWORK.trap.MakeHacked(target, hacker, false)

			target.nwTrapLimited = true
			target.nwTrapExpire = minutes > 0 and CurTime() + minutes * 60 or nil

			Notice(hacker, "trapHacked", "good")
			NETWORK.trap.Log(NETWORK.trap.Name(hacker) .. " перепрограммировал турель", target:GetPos())
		end, false)
end
