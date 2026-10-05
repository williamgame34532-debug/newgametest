function NETWORK.weapon.SetRaised(client, bRaised)
	client:SetNWBool("nwRaised", bRaised)
	client:SetNWFloat("nwRaiseStart", 0)

	client.nwRaiseHold = nil

	local weapon = client:GetActiveWeapon()

	if (IsValid(weapon)) then

		if (bRaised) then
			client:EmitSound("weapons/smg1/switch_single.wav", 55, 105, 0.35)
		else
			client:EmitSound("weapons/smg1/switch_burst.wav", 50, 95, 0.3)
		end

		weapon:SetNextPrimaryFire(CurTime() + 0.4)
		weapon:SetNextSecondaryFire(CurTime() + 0.4)

		if (bRaised) then
			if (isfunction(weapon.OnRaised)) then
				weapon:OnRaised()
			end
		elseif (isfunction(weapon.OnLowered)) then
			weapon:OnLowered()
		end
	end

	hook.Run("NetworkWeaponRaised", client, bRaised)
end

hook.Add("PlayerSwitchWeapon", "nwSafetyDeploy", function(client, _, weapon)
	if (!IsValid(weapon) or !weapon.IsSafety) then
		return
	end

	timer.Simple(0.1, function()
		if (IsValid(client) and IsValid(weapon) and
			client:GetActiveWeapon() == weapon and weapon:IsSafety()) then
			client:SetNWBool("nwRaised", true)
		end
	end)
end)

hook.Add("KeyPress", "nwWeaponRaise", function(client, key)
	if (key != IN_RELOAD or !client:HasCharacter()) then
		return
	end

	local weapon = client:GetActiveWeapon()

	if (IsValid(weapon) and weapon.IsSafety) then

		if (client:KeyDown(IN_SPEED) and client:KeyDown(IN_USE)) then
			return
		end

		if (weapon:IsSafety()) then
			return
		end
	end

	local weapon = client:GetActiveWeapon()

	if (!IsValid(weapon) or NETWORK.weapon.alwaysRaised[weapon:GetClass()]) then
		return
	end

	client.nwRaiseHold = CurTime()

	client:SetNWFloat("nwRaiseStart", CurTime())
end)

hook.Add("KeyRelease", "nwWeaponRaise", function(client, key)
	if (key != IN_RELOAD) then
		return
	end

	client.nwRaiseHold = nil

	client:SetNWFloat("nwRaiseStart", 0)
end)

hook.Add("PlayerTick", "nwWeaponRaise", function(client)
	if (!client.nwRaiseHold) then
		return
	end

	if (CurTime() - client.nwRaiseHold < NETWORK.weapon.raiseTime) then
		return
	end

	NETWORK.weapon.SetRaised(client, !client:IsWeaponRaised())
end)

hook.Add("StartCommand", "nwWeaponRaise", function(client, cmd)
	if (client:IsWeaponRaised() or !client:HasCharacter()) then
		return
	end

	local weapon = client:GetActiveWeapon()

	if (IsValid(weapon) and weapon:GetClass() == NETWORK.weapon.hands) then
		return
	end

	cmd:RemoveKey(IN_ATTACK)
	cmd:RemoveKey(IN_ATTACK2)

	if (IsValid(weapon)) then
		weapon:SetNextPrimaryFire(CurTime() + 0.2)
		weapon:SetNextSecondaryFire(CurTime() + 0.2)
	end
end)

hook.Add("EntityFireBullets", "nwWeaponRaise", function(entity)
	if (entity:IsPlayer() and entity:HasCharacter() and !entity:IsWeaponRaised()) then
		return false
	end
end)

NETWORK.weapon.damageScale = {
	tfa_heavyshotgun = function()
		return NETWORK.config.Get("heavyShotgunDamage") or 2.1
	end,
	tfa_ocipr = function()
		return NETWORK.config.Get("combineRifleDamage") or 1.35
	end,
	tfa_osips = function()
		return NETWORK.config.Get("combineRifleDamage") or 1.35
	end,
	tfa_suppressor = function()
		return NETWORK.config.Get("combineRifleDamage") or 1.35
	end
}

hook.Add("EntityTakeDamage", "nwHeavyShotgun", function(target, info)
	local attacker = info:GetAttacker()

	if (!IsValid(attacker) or !attacker:IsPlayer()) then
		return
	end

	local weapon = attacker:GetActiveWeapon()
	local getter = IsValid(weapon) and NETWORK.weapon.damageScale[weapon:GetClass()]

	if (!getter) then
		return
	end

	local scale = getter()

	if (scale > 0 and scale != 1) then
		info:ScaleDamage(scale)
	end
end)

hook.Add("EntityTakeDamage", "nwWeaponRaise", function(target, info)
	local attacker = info:GetAttacker()

	if (!IsValid(attacker) or !attacker:IsPlayer() or !attacker:HasCharacter()) then
		return
	end

	if (attacker:IsWeaponRaised()) then
		return
	end

	local weapon = attacker:GetActiveWeapon()

	if (IsValid(weapon) and weapon:GetClass() != NETWORK.weapon.hands) then
		info:SetDamage(0)

		return true
	end
end)

hook.Add("PlayerSwitchWeapon", "nwWeaponRaise", function(client, previous)

	if (IsValid(previous) and isfunction(previous.OnLowered)) then
		previous:OnLowered()
	end

	client:SetNWBool("nwRaised", false)
	client:SetNWFloat("nwRaiseStart", 0)

	client.nwRaiseHold = nil
end)

hook.Add("PlayerSpawn", "nwWeaponRaise", function(client)
	client:SetNWBool("nwRaised", false)
	client:SetNWFloat("nwRaiseStart", 0)
end)
