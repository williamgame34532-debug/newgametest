NETWORK.weaponwear = NETWORK.weaponwear or {}

local W = NETWORK.weaponwear

W.maxUses = 100
W.perShot = 0.28
W.jamBelow = 0.35
W.jamChance = 0.14

W.slots = {primary = true, secondary = true}

W.skip = {
	weapon_frag = true,
	weapon_slam = true
}

function W.IsWearable(base)
	if (!istable(base) or !isstring(base.weaponClass) or base.bConsumeOnEquip) then
		return false
	end

	if (base.bNoWear or W.skip[base.weaponClass]) then
		return false
	end

	return W.slots[base.equipSlot or ""] == true
end

function W.Mark()
	local list = NETWORK.item and NETWORK.item.GetAll and NETWORK.item.GetAll() or {}

	for _, base in ipairs(list) do
		if (W.IsWearable(base)) then
			base.maxUses = base.maxUses or W.maxUses
			base.bWearWeapon = true
		end
	end
end

function W.GetCondition(item)
	if (!istable(item)) then
		return 1
	end

	local base = NETWORK.item.Get(item.id)

	if (!base or !base.bWearWeapon) then
		return 1
	end

	local maxUses = base.maxUses or W.maxUses

	return math.Clamp((item.uses or maxUses) / maxUses, 0, 1)
end

function W.GetJamChance(condition)
	if (condition >= W.jamBelow) then
		return 0
	end

	return (1 - condition / W.jamBelow) * W.jamChance
end

W.Mark()

hook.Add("Initialize", "nwWeaponWearMark", function()
	W.Mark()
end)

hook.Add("NetworkItemsLoaded", "nwWeaponWearMark", function()
	W.Mark()
end)

W.STATE_OK = 0
W.STATE_JAM = 1
W.STATE_BROKEN = 2

W.clearTime = 0.55

W.altFire = {
	weapon_smg1 = true,
	weapon_ar2 = true,
	weapon_shotgun = true
}

function W.GetState(weapon)
	if (!IsValid(weapon) or !weapon.GetNWInt) then
		return W.STATE_OK
	end

	return weapon:GetNWInt("nwWearState", W.STATE_OK)
end

function W.IsBlocked(weapon)
	return W.GetState(weapon) != W.STATE_OK
end

hook.Add("StartCommand", "nwWeaponWear", function(client, cmd)
	if (CLIENT and client != LocalPlayer()) then
		return
	end

	local weapon = client:GetActiveWeapon()
	local bAlt = IsValid(weapon) and W.altFire[weapon:GetClass()] and
		cmd:KeyDown(IN_ATTACK2)
	local bFire = cmd:KeyDown(IN_ATTACK) or bAlt
	local bWasFire = client.nwWearFire
	local bWasBlocked = client.nwWearBlocked

	client.nwWearFire = bFire
	client.nwWearBlocked = false

	if (!bFire or !IsValid(weapon) or !client:Alive()) then
		return
	end

	if (SERVER and W.Refresh) then
		W.Refresh(client, weapon)
	end

	local state = W.GetState(weapon)

	if (state == W.STATE_OK) then
		return
	end

	cmd:RemoveKey(IN_ATTACK)

	if (W.altFire[weapon:GetClass()]) then
		cmd:RemoveKey(IN_ATTACK2)
	end

	client.nwWearBlocked = true

	if ((bWasFire and bWasBlocked) or !client:IsWeaponRaised()) then
		return
	end

	if (W.OnDryFire) then
		W.OnDryFire(client, weapon, state)
	end
end)
