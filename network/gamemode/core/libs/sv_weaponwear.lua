local W = NETWORK.weaponwear

function W.FindItem(client, weapon)
	local state = NETWORK.inventory.GetState(client)

	if (!state or !istable(state.equipped) or !IsValid(weapon)) then
		return
	end

	local class = weapon:GetClass()

	for slot in pairs(W.slots) do
		local item = state.equipped[slot]
		local base = item and NETWORK.item.Get(item.id)

		if (base and base.bWearWeapon and base.weaponClass == class) then
			return item, base
		end
	end
end

util.AddNetworkString("nwWearDry")

local function Click(client, bOthers)
	local filter

	if (bOthers) then
		filter = RecipientFilter()
		filter:AddPAS(client:GetPos())
		filter:RemovePlayer(client)
	end

	client:EmitSound("weapons/pistol/pistol_empty.wav", 62, math.random(96, 104), 0.8,
		CHAN_AUTO, 0, 0, filter)
end

local function Notice(client, key, tone, ...)
	local now = CurTime()

	client.nwWearNotice = client.nwWearNotice or {}

	if ((client.nwWearNotice[key] or 0) > now) then
		return
	end

	client.nwWearNotice[key] = now + 2.5

	NETWORK.notice.Send(client, key, tone, ...)
end

function W.SetState(weapon, state)
	if (IsValid(weapon) and W.GetState(weapon) != state) then
		weapon:SetNWInt("nwWearState", state)
	end
end

function W.Refresh(client, weapon, bForce)
	local now = CurTime()

	if (!bForce and (client.nwWearRefresh or 0) > now) then
		return
	end

	client.nwWearRefresh = now + 0.25

	if (!IsValid(weapon)) then
		return
	end

	local item, base = W.FindItem(client, weapon)

	if (!item) then
		W.SetState(weapon, W.STATE_OK)

		return
	end

	local maxUses = base.maxUses or W.maxUses
	local bBroken = (item.uses or maxUses) <= 0
	local state = W.GetState(weapon)

	if (bBroken) then
		W.SetState(weapon, W.STATE_BROKEN)
	elseif (state == W.STATE_BROKEN) then
		W.SetState(weapon, W.STATE_OK)
	end
end

function W.OnDryFire(client, weapon, state, bFromClient)

	client.nwWearDryAt = CurTime() + 0.4

	Click(client, bFromClient)

	local item, base = W.FindItem(client, weapon)
	local name = base and base.name or weapon:GetClass()

	if (state == W.STATE_BROKEN) then
		Notice(client, "weaponBroken", "bad", name)
	else
		Notice(client, "weaponJam", "warn", name)
	end
end

net.Receive("nwWearDry", function(_, client)
	local now = CurTime()

	if ((client.nwWearDryAt or 0) > now or !client:Alive()) then
		return
	end

	local weapon = client:GetActiveWeapon()
	local state = W.GetState(weapon)

	if (state != W.STATE_OK) then
		W.OnDryFire(client, weapon, state, true)
	end
end)

function W.Wear(client, weapon)
	local tick = engine.TickCount()

	if (client.nwWearTick == tick) then
		return
	end

	client.nwWearTick = tick

	local item, base = W.FindItem(client, weapon)

	if (!item) then
		return
	end

	local maxUses = base.maxUses or W.maxUses
	local before = item.uses or maxUses

	if (before <= 0) then
		W.SetState(weapon, W.STATE_BROKEN)

		return
	end

	item.uses = math.max(0, before - W.perShot)

	if (math.floor(item.uses) != math.floor(before)) then
		client.nwArmorSyncAt = CurTime() + 0.5
	end

	if (item.uses <= 0) then
		W.SetState(weapon, W.STATE_BROKEN)
		Notice(client, "weaponBrokeNow", "bad", base.name)

		return
	end

	if (math.Rand(0, 1) < W.GetJamChance(item.uses / maxUses)) then
		W.SetState(weapon, W.STATE_JAM)
	end

	if (before > maxUses * W.jamBelow and item.uses <= maxUses * W.jamBelow) then
		Notice(client, "weaponLow", "warn", base.name)
	end
end

function W.Fire(client, weapon)
	W.Refresh(client, weapon, true)

	if (W.IsBlocked(weapon)) then
		return false
	end

	W.Wear(client, weapon)
end

hook.Add("EntityFireBullets", "nwWeaponWear", function(entity, data)
	if (!IsValid(entity) or !entity:IsPlayer() or !entity:HasCharacter()) then
		return
	end

	local weapon = entity:GetActiveWeapon()

	if (!IsValid(weapon)) then
		return
	end

	W.Refresh(entity, weapon)

	if (W.IsBlocked(weapon)) then
		return false
	end

	if (!W.bPostHook) then
		W.Wear(entity, weapon)
	end
end)

hook.Add("PostEntityFireBullets", "nwWeaponWear", function(entity, data)
	W.bPostHook = true

	if (IsValid(entity) and entity:IsWeapon()) then
		entity = entity:GetOwner()
	end

	if (!IsValid(entity) or !entity:IsPlayer() or !entity:HasCharacter()) then
		return
	end

	local weapon = entity:GetActiveWeapon()

	if (IsValid(weapon)) then
		W.Wear(entity, weapon)
	end
end)

hook.Add("KeyPress", "nwWeaponWearClear", function(client, key)
	if (key != IN_RELOAD or !client:Alive()) then
		return
	end

	local weapon = client:GetActiveWeapon()

	if (W.GetState(weapon) != W.STATE_JAM or weapon.nwWearClearing) then
		return
	end

	weapon.nwWearClearing = true

	client:EmitSound("weapons/shotgun/shotgun_cock.wav", 58, math.random(108, 116), 0.55)

	timer.Simple(W.clearTime, function()
		if (!IsValid(weapon)) then
			return
		end

		weapon.nwWearClearing = nil

		if (IsValid(client) and client:GetActiveWeapon() == weapon and
			W.GetState(weapon) == W.STATE_JAM) then
			W.SetState(weapon, W.STATE_OK)

			weapon:SetNextPrimaryFire(CurTime() + 0.15)
		end
	end)
end)

hook.Add("PlayerSwitchWeapon", "nwWeaponWear", function(client, _, weapon)
	timer.Simple(0, function()
		if (IsValid(client) and IsValid(weapon) and client:GetActiveWeapon() == weapon) then
			W.Refresh(client, weapon, true)
		end
	end)
end)

function W.Repair(client, item, amount)
	local base = istable(item) and NETWORK.item.Get(item.id)

	if (!base or !base.bWearWeapon) then
		return
	end

	local maxUses = base.maxUses or W.maxUses

	item.uses = math.min(maxUses, (item.uses or maxUses) + amount)

	if (IsValid(client)) then
		NETWORK.inventory.Sync(client)

		local weapon = client.GetWeapon and client:GetWeapon(base.weaponClass)

		if (IsValid(weapon)) then
			W.SetState(weapon, W.STATE_OK)
			W.Refresh(client, weapon, true)
		end
	end

	return math.Round(item.uses / maxUses * 100)
end

NETWORK.command.Register("wearcheck", {
	description = "cmdWearCheck",
	usage = "/wearcheck",
	OnRun = function(command, client)
		local weapon = client:GetActiveWeapon()
		local item, base = IsValid(weapon) and W.FindItem(client, weapon)

		if (!item) then
			return NETWORK.chat.Notice(client, L("wearNoWeapon"))
		end

		local condition = W.GetCondition(item)

		NETWORK.chat.Notice(client, L("wearState", base.name, math.Round(condition * 100),
			math.Round(W.GetJamChance(condition) * 100)))
	end
})
