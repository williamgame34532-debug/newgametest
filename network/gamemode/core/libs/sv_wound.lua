util.AddNetworkString("nwWoundSync")
util.AddNetworkString("nwWoundHeal")

function NETWORK.wound.Sync(client)
	local state = NETWORK.wound.GetState(client)

	net.Start("nwWoundSync")
		NETWORK.util.WriteTable(state)
	net.Send(client)

	for _, part in ipairs(NETWORK.wound.parts) do
		client:SetNWInt("nwWound_" .. part.id,
			math.Round(state[part.id] or 0))
	end
end

function NETWORK.wound.Reset(client)
	client.nwWounds = {}
	client.nwFallen = nil

	client:SetNWFloat("nwFallen", 0)
	client:SetNWBool("nwLimping", false)

	NETWORK.wound.Sync(client)
end

function NETWORK.wound.Add(client, id, amount)
	local state = NETWORK.wound.GetState(client)

	if (amount > 0 and amount < NETWORK.wound.max and NETWORK.toughness) then
		amount = amount * (NETWORK.toughness.Get(client, "wound") or 1)
	end

	state[id] = math.Clamp((state[id] or 0) + amount, 0, NETWORK.wound.max)

	client:SetNWBool("nwLimping", NETWORK.wound.IsLimping(client))

	NETWORK.wound.Sync(client)
	NETWORK.movement.Apply(client)

	return state[id]
end

function NETWORK.wound.Heal(client, id, amount)
	local state = NETWORK.wound.GetState(client)

	if ((state[id] or 0) <= 0) then
		return false
	end

	amount = amount * (tonumber(client.nwHealScale) or 1)

	state[id] = math.max((state[id] or 0) - amount, 0)

	client:SetNWBool("nwLimping", NETWORK.wound.IsLimping(client))

	NETWORK.wound.Sync(client)
	NETWORK.movement.Apply(client)

	return true
end

function NETWORK.wound.Fall(client)
	if (IsValid(client.nwRagdollEntity)) then
		return
	end

	if (NETWORK.toughness and !NETWORK.toughness.CanKnockdown(client)) then
		return
	end

	client:EmitSound("physics/body/body_medium_impact_hard" .. math.random(1, 6) .. ".wav",
		70, 100)

	NETWORK.chat.Send(client, "it", L("woundFallAction"))
	NETWORK.ragdoll.Start(client)
end

function NETWORK.wound.GetProtection(client, slot)
	local state = NETWORK.inventory.GetState(client)
	local item = state.equipped[slot]

	if (!item) then
		return 0, nil
	end

	local base = NETWORK.item.Get(item.id)

	return base and base.protection or 0, item
end

local GetItemProtection = NETWORK.wound.GetProtection

util.AddNetworkString("nwArmorRepair")

NETWORK.wound.wearPerDamage = 0.6
NETWORK.wound.wearMinFactor = 0

function NETWORK.wound.GetCondition(item)
	if (!istable(item)) then
		return 1
	end

	local base = NETWORK.item.Get(item.id)
	local maxUses = base and base.maxUses or 0

	if (!maxUses or maxUses <= 1) then
		return 1
	end

	return math.Clamp((item.uses or maxUses) / maxUses, 0, 1)
end

function NETWORK.wound.Wear(client, item, absorbed)
	if (!istable(item) or absorbed <= 0) then
		return
	end

	local base = NETWORK.item.Get(item.id)

	if (!base or !base.maxUses or base.maxUses <= 1) then
		return
	end

	local before = item.uses or base.maxUses

	item.uses = math.max(0, before - absorbed * NETWORK.wound.wearPerDamage)

	if (math.floor(item.uses) != math.floor(before)) then
		client.nwArmorSyncAt = CurTime() + 0.5
	end

	if (before > 0 and item.uses <= 0) then
		NETWORK.notice.Send(client, "armorBroken", "bad", base.name)
	elseif (before > base.maxUses * 0.25 and item.uses <= base.maxUses * 0.25) then
		NETWORK.notice.Send(client, "armorLow", "warn", base.name)
	end
end

timer.Create("nwArmorWearSync", 0.25, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (client.nwArmorSyncAt and client.nwArmorSyncAt <= CurTime()) then
			client.nwArmorSyncAt = nil

			NETWORK.inventory.Sync(client)
		end
	end
end)

function NETWORK.wound.GetProtection(client, slot)
	local protection, item = GetItemProtection(client, slot)
	local innate = NETWORK.toughness and
		NETWORK.toughness.GetInnateProtection(client, slot) or 0

	if (item) then
		local condition = NETWORK.wound.GetCondition(item)

		protection = protection * math.sqrt(condition) * (condition > 0 and 1 or 0)
	end

	if (innate > protection) then
		return innate, nil
	end

	return protection, item
end

hook.Add("ScalePlayerDamage", "nwWound", function(client, hitgroup, info)
	if (!client:HasCharacter()) then
		return
	end

	local part = NETWORK.wound.hitgroups[hitgroup]

	if (!part) then
		part = NETWORK.wound.hitgroups[client:LastHitGroup()]
	end

	if (!part) then
		return
	end

	client.nwLastPart = part

	local damage = info:GetDamage()

	if (part == "head") then
		local protection, helmet = NETWORK.wound.GetProtection(client, "helmet")

		if (protection > 0) then
			info:SetDamage(damage * math.Clamp(1 - protection, 0.1, 1))

			NETWORK.wound.Wear(client, helmet, damage - info:GetDamage())

			client:EmitSound("physics/metal/metal_solid_impact_bullet" ..
				math.random(1, 4) .. ".wav", 75, 105)

			NETWORK.wound.Add(client, part, damage * 0.5)

			return true
		end

		NETWORK.wound.Add(client, part, NETWORK.wound.max)

		info:SetDamage(1000)
		info:SetDamageType(DMG_BULLET)

		client:SetHealth(1)
		client:TakeDamage(1000, info:GetAttacker(), info:GetInflictor())

		return true
	end

	if (part == "chest" or part == "stomach") then
		local protection, vest = NETWORK.wound.GetProtection(client, "armour")

		if (protection > 0) then
			info:SetDamage(damage * math.Clamp(1 - protection, 0.15, 1))

			NETWORK.wound.Wear(client, vest, damage - info:GetDamage())
		end
	end

	NETWORK.wound.Add(client, part, info:GetDamage() * 1.2)

	if ((part == "legLeft" or part == "legRight") and
		NETWORK.wound.Get(client, part) >= NETWORK.wound.fallAt) then
		NETWORK.wound.Fall(client)
	end
end)

net.Receive("nwWoundHeal", function(_, client)
	if (!client:HasCharacter()) then
		return
	end

	local part = net.ReadString()
	local index = net.ReadUInt(8)

	if (!NETWORK.wound.GetPart(part)) then
		return
	end

	local state = NETWORK.inventory.GetState(client)
	local item = state.items[index]

	if (!item) then
		return
	end

	if (NETWORK.medical and NETWORK.medical.IsTreatment(item.id)) then
		NETWORK.medical.Begin(client, client, item.id, part)

		return
	end

	local base = NETWORK.item.Get(item.id)

	if (!base or (base.healWound or 0) <= 0) then
		return
	end

	if (!NETWORK.wound.Heal(client, part, base.healWound)) then
		return
	end

	if ((item.amount or 1) > 1) then
		item.amount = item.amount - 1
	else
		state.items[index] = nil
	end

	client:EmitSound("items/medshot4.wav", 60, 110)

	NETWORK.inventory.Sync(client)
	NETWORK.chat.Send(client, "it", L("woundHealAction"))
end)

hook.Add("EntityTakeDamage", "nwHeadshot", function(target, info)
	if (!target:IsPlayer() or !target:HasCharacter() or !target:Alive()) then
		return
	end

	if (target:LastHitGroup() != HITGROUP_HEAD) then
		return
	end

	if (info:IsDamageType(DMG_CLUB) and IsValid(info:GetInflictor()) and
		info:GetInflictor():GetClass() == "weapon_nwhands") then
		return
	end

	if (NETWORK.wound.GetProtection(target, "helmet") > 0) then
		return
	end

	if (info:GetDamage() < 1) then
		return
	end

	info:SetDamage(math.max(info:GetDamage(), target:Health() + target:Armor() + 50))
end)

hook.Add("EntityTakeDamage", "nwWoundFall", function(target, info)
	if (!target:IsPlayer() or !target:HasCharacter()) then
		return
	end

	if (!info:IsFallDamage()) then
		return
	end

	local speed = target.nwFallSpeed or 0
	local damage = math.max((speed - 450) / 8, 0)

	info:SetDamage(damage)

	if (damage <= 0) then
		return true
	end

	local part = math.random() > 0.5 and "legLeft" or "legRight"

	NETWORK.wound.Add(target, part, damage * 1.6)

	if (NETWORK.wound.Get(target, part) >= NETWORK.wound.fallAt) then
		NETWORK.wound.Fall(target)
	end

	target:EmitSound("physics/body/body_medium_break" .. math.random(2, 4) .. ".wav", 70, 100)
end)

hook.Add("Think", "nwFallSpeed", function()
	for _, client in ipairs(player.GetAll()) do
		if (!client:Alive()) then
			continue
		end

		if (client:IsOnGround()) then
			client.nwFallSpeed = 0
		else
			client.nwFallSpeed = math.max(client.nwFallSpeed or 0,
				math.abs(client:GetVelocity().z))
		end
	end
end)

hook.Add("NetworkCharacterLoaded", "nwWound", function(client)
	NETWORK.wound.Reset(client)
end)

hook.Add("PlayerSpawn", "nwWound", function(client)
	NETWORK.wound.Reset(client)
end)

hook.Add("StartCommand", "nwWound", function(client, cmd)
	if (client:GetNWFloat("nwFallen", 0) > CurTime()) then
		cmd:ClearMovement()
		cmd:RemoveKey(IN_JUMP)
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_SPEED)
	end
end)

hook.Add("NetworkMovementSpeed", "nwWound", function(client, walk, run)
	if (client:GetNWBool("nwLimping", false)) then
		return walk * 0.55, run * 0.5
	end
end)
