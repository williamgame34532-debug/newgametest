NETWORK.props = NETWORK.props or {}

local BLOCKED = {
	prop_physics = true,
	prop_physics_multiplayer = true,
	prop_ragdoll = true,
	func_physbox = true,
	nw_item = true,
	nw_container = true
}

hook.Add("EntityTakeDamage", "nwProps", function(target, info)
	if (!target:IsPlayer()) then
		return
	end

	local inflictor = info:GetInflictor()
	local attacker = info:GetAttacker()

	if (IsValid(inflictor) and BLOCKED[inflictor:GetClass()]) then
		info:SetDamage(0)

		return true
	end

	if (IsValid(attacker) and BLOCKED[attacker:GetClass()]) then
		info:SetDamage(0)

		return true
	end

	if (info:IsDamageType(DMG_CRUSH) and IsValid(inflictor) and !inflictor:IsPlayer() and
		!inflictor:IsWorld()) then
		info:SetDamage(0)

		return true
	end
end)

hook.Add("PhysgunPickup", "nwPropSurf", function(client, entity)
	if (!IsValid(entity) or !BLOCKED[entity:GetClass()]) then
		return
	end

	entity.nwOldCollision = entity.nwOldCollision or entity:GetCollisionGroup()

	entity:SetCollisionGroup(COLLISION_GROUP_WEAPON)
end)

hook.Add("PhysgunDrop", "nwPropSurf", function(client, entity)
	if (!IsValid(entity) or !entity.nwOldCollision) then
		return
	end

	local old = entity.nwOldCollision

	entity.nwOldCollision = nil

	timer.Simple(0.3, function()
		if (IsValid(entity)) then
			entity:SetCollisionGroup(old)
		end
	end)
end)

hook.Add("OnPhysgunFreeze", "nwPropSurf", function(weapon, physics, entity, client)
	if (IsValid(entity) and entity.nwOldCollision) then
		entity:SetCollisionGroup(entity.nwOldCollision)

		entity.nwOldCollision = nil
	end
end)
