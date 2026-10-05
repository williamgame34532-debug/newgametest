NETWORK.ragdoll = NETWORK.ragdoll or {}

NETWORK.ragdoll.minTime = 10

function NETWORK.ragdoll.Start(client, duration)
	if (IsValid(client.nwRagdollEntity) or !client:Alive()) then
		return
	end

	local ragdoll = ents.Create("prop_ragdoll")

	if (!IsValid(ragdoll)) then
		return
	end

	ragdoll:SetModel(client:GetModel())
	ragdoll:SetPos(client:GetPos())
	ragdoll:SetAngles(Angle(0, client:EyeAngles().y, 0))
	ragdoll:SetSkin(client:GetSkin())

	for _, data in pairs(client:GetBodyGroups()) do
		ragdoll:SetBodygroup(data.id, client:GetBodygroup(data.id))
	end

	ragdoll:Spawn()
	ragdoll:Activate()

	ragdoll:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)
	ragdoll.PhysgunDisabled = true

	ragdoll.nwNoCarry = nil
	ragdoll.nwCarryable = true

	local velocity = client:GetVelocity()

	for index = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local physics = ragdoll:GetPhysicsObjectNum(index)

		if (IsValid(physics)) then
			physics:SetVelocity(velocity)
		end
	end

	ragdoll.nwPlayer = client

	ragdoll:SetNWEntity("nwRagdollOwner", client)

	client.nwRagdollEntity = ragdoll
	client.nwRagdollUntil = CurTime() + math.max(duration or NETWORK.ragdoll.minTime,
		NETWORK.ragdoll.minTime)
	client.nwRagdollWeapon = IsValid(client:GetActiveWeapon()) and
		client:GetActiveWeapon():GetClass() or nil

	client:SetNWEntity("nwRagdollEntity", ragdoll)
	client:SetNWFloat("nwRagdollUntil", client.nwRagdollUntil)
	client:SetNoDraw(true)
	client:SetNotSolid(true)
	client:SetMoveType(MOVETYPE_NONE)
	client:SetNoTarget(true)
	client:DrawWorldModel(false)

	if (IsValid(client:GetActiveWeapon())) then
		client:GetActiveWeapon():SetNoDraw(true)
	end

	ragdoll.nwOwner = client

	ragdoll:CallOnRemove("nwRagdoll", function()
		if (IsValid(client)) then
			NETWORK.ragdoll.Stop(client, true)
		end
	end)
end

hook.Add("Think", "nwRagdollFall", function()
	for _, client in ipairs(player.GetAll()) do
		local ragdoll = client.nwRagdollEntity

		if (!IsValid(ragdoll) or !client:Alive()) then
			continue
		end

		local physics = ragdoll:GetPhysicsObject()

		if (!IsValid(physics)) then
			continue
		end

		local speed = physics:GetVelocity().z
		local peak = math.min(client.nwRagdollFall or 0, speed)

		client.nwRagdollFall = peak

		if (peak >= -450 or speed > -80) then
			if (speed > -80 and peak < -450) then
				local damage = math.Clamp((-peak - 450) / 16, 5, 100)

				client:TakeDamage(damage, game.GetWorld(), game.GetWorld())
				ragdoll:EmitSound("physics/body/body_medium_impact_hard" ..
					math.random(1, 6) .. ".wav", 75)

				client.nwRagdollFall = 0
			end

			if (speed > -80) then
				client.nwRagdollFall = 0
			end
		end
	end
end)

function NETWORK.ragdoll.IsCarried(client)
	local ragdoll = client.nwRagdollEntity

	if (!IsValid(ragdoll)) then
		return false
	end

	for _, other in ipairs(player.GetAll()) do
		local weapon = other:GetActiveWeapon()

		if (IsValid(weapon) and weapon.carried == ragdoll) then
			return true
		end
	end

	return false
end

function NETWORK.ragdoll.Stop(client, bForce)
	local ragdoll = client.nwRagdollEntity

	if (!bForce and NETWORK.ragdoll.IsCarried(client)) then
		return
	end

	client.nwRagdollEntity = nil
	client.nwRagdollUntil = nil

	client:SetNWEntity("nwRagdollEntity", NULL)
	client:SetNWFloat("nwRagdollUntil", 0)

	if (!client:Alive()) then
		return
	end

	client:SetNoDraw(false)
	client:SetNotSolid(false)
	client:SetMoveType(MOVETYPE_WALK)
	client:SetNoTarget(false)
	client:DrawWorldModel(true)

	if (IsValid(client:GetActiveWeapon())) then
		client:GetActiveWeapon():SetNoDraw(false)
	end

	if (IsValid(ragdoll)) then
		local origin = ragdoll:GetPos()
		local floor = util.TraceLine({
			start = origin + Vector(0, 0, 16),
			endpos = origin - Vector(0, 0, 72),
			filter = {client, ragdoll},
			mask = MASK_PLAYERSOLID
		})

		local position = floor.Hit and floor.HitPos + Vector(0, 0, 2) or origin

		local room = util.TraceHull({
			start = position,
			endpos = position,
			mins = Vector(-16, -16, 0),
			maxs = Vector(16, 16, 72),
			filter = {client, ragdoll},
			mask = MASK_PLAYERSOLID
		})

		if (room.Hit) then
			position = origin + Vector(0, 0, 8)
		end

		client:SetPos(position)
		client:SetEyeAngles(Angle(0, client:EyeAngles().y, 0))

		client:SetLocalVelocity(vector_origin)

		ragdoll:RemoveCallOnRemove("nwRagdoll")
		ragdoll:Remove()
	end

	NETWORK.movement.Apply(client)
end

NETWORK.ragdoll.helpTime = 4
NETWORK.ragdoll.helpRange = 110

local function Progress(client, key, duration)
	net.Start("nwProgress")
		net.WriteString(key or "")
		net.WriteFloat(duration or 0)
	net.Send(client)
end

local function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

function NETWORK.ragdoll.GetDowned(client)
	local trace = client:GetEyeTrace()
	local entity = trace.Entity

	if (!IsValid(entity) or !entity:IsRagdoll()) then
		return
	end

	if (client:GetShootPos():Distance(trace.HitPos) > NETWORK.ragdoll.helpRange) then
		return
	end

	for _, target in ipairs(player.GetAll()) do
		if (target != client and target:Alive() and target.nwRagdollEntity == entity) then
			return target
		end
	end
end

local function StopHelping(client)
	if (!client.nwHelpTarget) then
		return
	end

	client.nwHelpTarget = nil

	Progress(client, "", 0)
end

hook.Add("Think", "nwRagdollHelp", function()
	if (!NETWORK.util.Throttle("ragdoll.help", 0.2)) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		if (!client:Alive() or !client:HasCharacter() or
			IsValid(client.nwRagdollEntity)) then
			StopHelping(client)

			continue
		end

		local bHolding = client:KeyDown(IN_USE) and client:KeyDown(IN_SPEED)
		local target = bHolding and NETWORK.ragdoll.GetDowned(client)

		if (!target) then
			StopHelping(client)

			continue
		end

		if (client.nwHelpTarget != target) then
			client.nwHelpTarget = target
			client.nwHelpUntil = CurTime() + NETWORK.ragdoll.helpTime

			Progress(client, "ragdollHelping", NETWORK.ragdoll.helpTime)

			continue
		end

		if (CurTime() < client.nwHelpUntil) then
			continue
		end

		client.nwHelpTarget = nil

		if (hook.Run("NetworkCanHelpUp", client, target) == false) then
			Progress(client, "", 0)

			continue
		end

		NETWORK.ragdoll.Stop(target)

		Notice(client, "ragdollHelpedThem")
		Notice(target, "ragdollHelped")

		client:EmitSound("physics/body/body_medium_impact_soft6.wav", 60, 105)

		hook.Run("NetworkPlayerHelpedUp", client, target)
	end
end)

hook.Add("StartCommand", "nwRagdoll", function(client, cmd)
	if (!IsValid(client.nwRagdollEntity)) then
		return
	end

	cmd:ClearMovement()
	cmd:RemoveKey(IN_JUMP)
	cmd:RemoveKey(IN_SPEED)
	cmd:RemoveKey(IN_USE)

	if (cmd:KeyDown(IN_ATTACK) and (client.nwRagdollUntil or 0) < CurTime() and
		!client:GetNWBool("nwUnconscious", false)) then
		NETWORK.ragdoll.Stop(client)
	end

	cmd:RemoveKey(IN_ATTACK)
	cmd:RemoveKey(IN_ATTACK2)
end)

hook.Add("Think", "nwRagdollFollow", function()
	for _, client in ipairs(player.GetAll()) do
		local ragdoll = client.nwRagdollEntity

		if (!IsValid(ragdoll)) then
			continue
		end

		client:SetPos(ragdoll:GetPos())
		client:SetVelocity(vector_origin)

		local weapon = client:GetActiveWeapon()

		if (IsValid(weapon)) then
			weapon:SetNextPrimaryFire(CurTime() + 0.5)
			weapon:SetNextSecondaryFire(CurTime() + 0.5)
		end
	end
end)

hook.Add("PhysgunPickup", "nwRagdoll", function(client, entity)
	if (entity.nwNoCarry) then
		return false
	end
end)

hook.Add("CanPlayerEnterVehicle", "nwRagdoll", function(client)
	if (IsValid(client.nwRagdollEntity)) then
		return false
	end
end)

hook.Add("PlayerUse", "nwRagdoll", function(client, entity)
	if (IsValid(client.nwRagdollEntity)) then
		return false
	end

	if (entity.nwNoCarry) then
		return false
	end
end)

hook.Add("GravGunPickupAllowed", "nwRagdoll", function(client, entity)
	if (entity.nwNoCarry) then
		return false
	end
end)

hook.Add("PlayerNoClip", "nwRagdoll", function(client)
	if (IsValid(client.nwRagdollEntity)) then
		return false
	end
end)

hook.Add("PlayerDeath", "nwRagdoll", function(client)
	if (IsValid(client.nwRagdollEntity)) then
		client.nwRagdollEntity:Remove()
	end
end)

hook.Add("PlayerSpawn", "nwRagdoll", function(client)
	if (IsValid(client.nwRagdollEntity)) then
		client.nwRagdollEntity:Remove()
	end

	NETWORK.ragdoll.Stop(client, true)
end)

NETWORK.command.Register("fallover", {
	description = "cmdFallover",
	usage = "/fallover",
	OnRun = function(command, client)
		if (IsValid(client.nwRagdollEntity)) then
			return
		end

		NETWORK.ragdoll.Start(client)

		NETWORK.chat.Send(client, "it", L("ragdollFall"))
	end
})

hook.Add("EntityTakeDamage", "nwRagdollDamage", function(target, info)
	if (!IsValid(target) or !target.nwOwner) then
		return
	end

	if (target:GetNWBool("nwCorpse", false)) then
		return
	end

	local client = target.nwOwner

	if (!IsValid(client) or !client:IsPlayer() or !client:Alive()) then
		return
	end

	if (target.nwForwarding) then
		return
	end

	target.nwForwarding = true

	local forwarded = DamageInfo()

	forwarded:SetAttacker(info:GetAttacker())
	forwarded:SetInflictor(info:GetInflictor())
	forwarded:SetDamage(info:GetDamage())
	forwarded:SetDamageType(info:GetDamageType())
	forwarded:SetDamagePosition(info:GetDamagePosition())
	forwarded:SetDamageForce(info:GetDamageForce())

	client:TakeDamageInfo(forwarded)

	target.nwForwarding = nil

	info:SetDamage(0)

	return true
end)

hook.Add("PlayerDeath", "nwRagdollDeath", function(client)
	local ragdoll = client.nwRagdollEntity

	if (!IsValid(ragdoll)) then
		return
	end

	ragdoll:RemoveCallOnRemove("nwRagdoll")

	client.nwLastRagdoll = ragdoll
	client.nwRagdollEntity = nil
	client.nwRagdollUntil = nil

	client:SetNWEntity("nwRagdollEntity", NULL)
	client:SetNWFloat("nwRagdollUntil", 0)
end)

util.AddNetworkString("nwBodybagPack")
util.AddNetworkString("nwBagStart")
util.AddNetworkString("nwBagStep")

local BAG_STEPS = 5
local BAG_STEPS_DISINFECTOR = 4

local function BagNotice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

local function FindBag(client)
	local state = NETWORK.inventory.GetState(client)

	for _, list in ipairs({"items", "storage", "clothes"}) do
		for index, item in pairs(state[list] or {}) do
			if (istable(item) and item.id == "bodybag") then
				return state, list, index, item
			end
		end
	end
end

local function TakeBag(client)
	local state, list, index, item = FindBag(client)

	if (!state) then
		return false
	end

	if ((item.amount or 1) > 1) then
		item.amount = item.amount - 1
	else
		NETWORK.inventory.Put(state, list, index, nil, nil)
	end

	NETWORK.inventory.Sync(client)

	return true
end

local function FinishBag(client, ragdoll)
	if (!TakeBag(client)) then
		BagNotice(client, "bodybagNeedBag")

		return
	end

	local bag = ents.Create("nw_bodybag")

	if (!IsValid(bag)) then
		NETWORK.inventory.Give(client, "bodybag", 1)

		return
	end

	bag:SetPos(ragdoll:GetPos() + Vector(0, 0, 4))
	bag:SetAngles(Angle(0, ragdoll:GetAngles().y, 0))
	bag:Spawn()
	bag:Activate()

	ragdoll:Remove()

	client:EmitSound("framework/cmb/bodybag/bag" .. math.random(2) .. ".wav", 65)

	BagNotice(client, "bodybagDone")

	hook.Run("NetworkBodyPacked", client, bag)
end

net.Receive("nwBodybagPack", function(_, client)
	local ragdoll = net.ReadEntity()

	if (!IsValid(ragdoll) or !client:HasCharacter() or !client:Alive() or
		client:GetPos():Distance(ragdoll:GetPos()) > 120) then
		return
	end

	local class = ragdoll:GetClass()

	if (class != "prop_ragdoll" and class != "nw_ragdoll") then
		return
	end

	local session = client.nwBagSession

	if (session and (session.expires or 0) > CurTime() and
		IsValid(session.ragdoll)) then
		return
	end

	if (!FindBag(client)) then
		BagNotice(client, "bodybagNeedBag")

		return
	end

	local steps = BAG_STEPS

	if (client.GetCharacterFaction and
		client:GetCharacterFaction() == "disinfector" or client:GetNWString("nwClass", "") == "cwu_disinfector") then
		steps = BAG_STEPS_DISINFECTOR
	end

	client.nwBagSession = {
		ragdoll = ragdoll,
		done = 0,
		need = steps,
		nextStep = 0,
		expires = CurTime() + 90
	}

	client:EmitSound("framework/cmb/bodybag/bag" .. math.random(2) .. ".wav", 65)

	net.Start("nwBagStart")
		net.WriteEntity(ragdoll)
		net.WriteUInt(steps, 4)
	net.Send(client)
end)

net.Receive("nwBagStep", function(_, client)
	local bOk = net.ReadBool()
	local session = client.nwBagSession

	if (!session) then
		return
	end

	local ragdoll = session.ragdoll

	if (!bOk or !IsValid(ragdoll) or !client:Alive() or
		client:GetPos():Distance(ragdoll:GetPos()) > 140) then
		client.nwBagSession = nil

		return
	end

	if (session.nextStep > CurTime()) then
		return
	end

	session.nextStep = CurTime() + 0.25
	session.done = session.done + 1

	client:EmitSound("physics/plastic/plastic_box_impact_soft" ..
		math.random(4) .. ".wav", 55, math.random(90, 110))

	if (session.done < session.need) then
		return
	end

	client.nwBagSession = nil

	FinishBag(client, ragdoll)
end)

hook.Add("PlayerDisconnected", "nwBagSession", function(client)
	client.nwBagSession = nil
end)
