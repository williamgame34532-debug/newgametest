function NETWORK.manhack.Deploy(client, item)
	if (client.nwManhackPending) then
		return
	end

	local base = NETWORK.item.Get(item.id)
	local time = base and base.deployTime or 4

	client.nwManhackPending = true
	client.nwManhackStart = client:GetPos()

	net.Start("nwProgress")
		net.WriteString("progressManhack")
		net.WriteFloat(time)
	net.Send(client)

	client:EmitSound("npc/manhack/mh_blade_snick1.wav", 55, 100, 0.4)

	timer.Simple(time, function()
		if (!IsValid(client)) then
			return
		end

		client.nwManhackPending = nil

		if (!client:Alive() or !client:HasCharacter() or
			client:GetPos():Distance(client.nwManhackStart or client:GetPos()) > 48) then
			net.Start("nwProgress")
				net.WriteString("")
				net.WriteFloat(0)
			net.Send(client)

			return
		end

		if (!NETWORK.dialogue.TakeItem(client, NETWORK.manhack.itemID, 1)) then
			return
		end

		NETWORK.manhack.Spawn(client)
	end)
end

function NETWORK.manhack.Spawn(client)
	local manhack = ents.Create(NETWORK.manhack.class)

	if (!IsValid(manhack)) then
		return
	end

	local forward = client:GetAimVector()

	forward.z = 0
	forward:Normalize()

	manhack:SetPos(client:GetPos() + forward * 60 + Vector(0, 0, 50))
	manhack:SetAngles(Angle(0, client:EyeAngles().y, 0))
	manhack:Spawn()
	manhack:Activate()

	manhack.nwManhack = true
	manhack.nwOwner = client
	manhack:SetUseType(SIMPLE_USE)

	manhack:SetMaxHealth(NETWORK.manhack.health)
	manhack:SetHealth(NETWORK.manhack.health)
	manhack:SetKeyValue("health", tostring(NETWORK.manhack.health))
	manhack:SetKeyValue("spawnflags", "0")

	manhack:AddRelationship("player D_LI 99")

	for _, other in ipairs(player.GetAll()) do
		manhack:AddEntityRelationship(other,
			NETWORK.factions.IsAlliance(other) and D_LI or D_HT, 99)
	end

	return manhack
end

hook.Add("PlayerUse", "nwManhack", function(client, entity)
	if (!IsValid(entity) or !entity.nwManhack) then
		return
	end

	if (!client:HasCharacter() or !NETWORK.factions.IsAlliance(client)) then
		return false
	end

	if (client:GetPos():Distance(entity:GetPos()) > NETWORK.manhack.range) then
		return false
	end

	if ((client.nwNextManhack or 0) > CurTime()) then
		return false
	end

	client.nwNextManhack = CurTime() + 0.5

	if (!NETWORK.inventory.Give(client, NETWORK.manhack.itemID, 1)) then
		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString("invNoRoom")
		net.Send(client)

		return false
	end

	client:EmitSound("npc/manhack/mh_blade_snick2.wav", 55, 100, 0.4)
	entity:Remove()

	return false
end)

local FRIENDLY = {
	npc_manhack = true,
	npc_metropolice = true,
	npc_combine_s = true,
	npc_cscanner = true,
	npc_clawscanner = true,
	npc_turret_ceiling = true,
	npc_turret_floor = true,
	npc_combinedropship = true,
	npc_combinegunship = true,
	npc_helicopter = true,
	npc_strider = true,
	npc_rollermine = true,
	npc_hunter = true
}

function NETWORK.manhack.ApplyRelations(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	local disposition = NETWORK.factions.IsAlliance(client) and D_LI or D_HT

	for _, entity in ipairs(ents.GetAll()) do
		if (!IsValid(entity) or !entity:IsNPC()) then
			continue
		end

		if (!FRIENDLY[entity:GetClass()]) then
			continue
		end

		if (NETWORK.deploy and NETWORK.deploy.IsManaged and
			NETWORK.deploy.IsManaged(entity)) then
			continue
		end

		entity:AddEntityRelationship(client, disposition, 99)
	end
end

hook.Add("PlayerSpawn", "nwManhackRelations", function(client)
	timer.Simple(0.5, function()
		NETWORK.manhack.ApplyRelations(client)
	end)
end)

hook.Add("NetworkCharacterLoaded", "nwManhackRelations", function(client)
	timer.Simple(1, function()
		NETWORK.manhack.ApplyRelations(client)
	end)
end)

hook.Add("OnEntityCreated", "nwManhackRelations", function(entity)
	if (!IsValid(entity) or !FRIENDLY[entity:GetClass()]) then
		return
	end

	timer.Simple(0.5, function()
		if (!IsValid(entity) or !entity:IsNPC()) then
			return
		end

		if (NETWORK.deploy and NETWORK.deploy.IsManaged and
			NETWORK.deploy.IsManaged(entity)) then
			return
		end

		for _, client in ipairs(player.GetAll()) do
			if (client:HasCharacter()) then
				entity:AddEntityRelationship(client,
					NETWORK.factions.IsAlliance(client) and D_LI or D_HT, 99)
			end
		end
	end)
end)

hook.Add("EntityTakeDamage", "nwManhackDeath", function(target, info)
	if (!IsValid(target) or target:GetClass() != NETWORK.manhack.class) then
		return
	end

	timer.Simple(0, function()
		if (!IsValid(target) or target:Health() > 0) then
			return
		end

		local position = target:WorldSpaceCenter()
		local effect = EffectData()

		effect:SetOrigin(position)
		effect:SetMagnitude(2)
		effect:SetScale(1)

		util.Effect("ManhackSparks", effect)

		sound.Play("npc/manhack/mh_death1.wav", position, 70, 100)

		if (IsValid(target.nwOwner)) then
			NETWORK.notice.Send(target.nwOwner, "manhackLost", "warn")
		end

		target:Remove()
	end)
end)

hook.Add("OnEntityCreated", "nwManhackHealth", function(entity)
	if (!IsValid(entity) or entity:GetClass() != NETWORK.manhack.class) then
		return
	end

	timer.Simple(0.1, function()
		if (!IsValid(entity)) then
			return
		end

		if (entity:GetMaxHealth() > NETWORK.manhack.health or entity:Health() <= 0) then
			entity:SetMaxHealth(NETWORK.manhack.health)
			entity:SetHealth(NETWORK.manhack.health)
		end
	end)
end)
