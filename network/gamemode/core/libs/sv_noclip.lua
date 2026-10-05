NETWORK.noclip = NETWORK.noclip or {}

function NETWORK.noclip.Apply(client, bState)
	if (client.nwHidden == bState) then
		return
	end

	client.nwHidden = bState

	client:SetNoDraw(bState)
	client:DrawWorldModel(!bState)
	client:DrawShadow(!bState)
	client:SetNWBool("nwHidden", bState)

	local weapon = client:GetActiveWeapon()

	if (IsValid(weapon)) then
		weapon:SetNoDraw(bState)
	end

	if (bState) then
		client:SetNoTarget(true)

		return
	end

	client:SetNoTarget(false)
end

hook.Add("PlayerNoClip", "nwNoclipHide", function(client, bState)
	timer.Simple(0, function()
		if (IsValid(client)) then
			NETWORK.noclip.Apply(client, client:GetMoveType() == MOVETYPE_NOCLIP)
		end
	end)
end)

hook.Add("Think", "nwNoclipHide", function()
	if (!NETWORK.util.Throttle("noclip.hide", 0.2)) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		if (!client:Alive()) then
			continue
		end

		local bNoclip = client:GetMoveType() == MOVETYPE_NOCLIP

		if (client.nwHidden != bNoclip) then
			NETWORK.noclip.Apply(client, bNoclip)
		end
	end
end)

hook.Add("PlayerSpawn", "nwNoclipHide", function(client)
	timer.Simple(0, function()
		if (IsValid(client)) then
			NETWORK.noclip.Apply(client, false)
		end
	end)
end)

hook.Add("PlayerCanPickupWeapon", "nwNoclipHide", function(client)
	if (client:GetNWBool("nwHidden", false)) then
		return false
	end
end)

hook.Add("EntityTakeDamage", "nwNoclipDamage", function(target, damage)
	if (!IsValid(target) or !target:IsPlayer()) then
		return
	end

	if (target:GetMoveType() != MOVETYPE_NOCLIP) then
		return
	end

	damage:SetDamage(0)

	return true
end)

hook.Add("PlayerShouldTakeDamage", "nwNoclipDamage", function(target, attacker)
	if (IsValid(attacker) and attacker:IsPlayer() and
		attacker:GetMoveType() == MOVETYPE_NOCLIP) then
		return false
	end

	if (IsValid(target) and target:GetMoveType() == MOVETYPE_NOCLIP) then
		return false
	end
end)
