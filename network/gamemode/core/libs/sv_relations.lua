NETWORK.relations = NETWORK.relations or {}

NETWORK.relations.bEnabled = true

NETWORK.relations.combine = {
	npc_combine_s = true,
	npc_metropolice = true,
	npc_turret_floor = true,
	npc_turret_ceiling = true,
	npc_cscanner = true,
	npc_clawscanner = true,
	npc_manhack = true,
	npc_rollermine = true,
	npc_hunter = true,
	npc_strider = true,
	npc_combinegunship = true,
	npc_combinedropship = true,
	npc_helicopter = true,
	npc_sniper = true
}

NETWORK.relations.rebel = {
	npc_citizen = true,
	npc_vortigaunt = true,
	npc_alyx = true,
	npc_barney = true,
	npc_monk = true,
	npc_fisherman = true,
	npc_magnusson = true,
	npc_kleiner = true,
	npc_eli = true,
	npc_mossman = true
}

NETWORK.relations.wild = {
	npc_antlion = true,
	npc_antlionguard = true,
	npc_zombie = true,
	npc_zombie_torso = true,
	npc_fastzombie = true,
	npc_fastzombie_torso = true,
	npc_poisonzombie = true,
	npc_headcrab = true,
	npc_headcrab_fast = true,
	npc_headcrab_black = true,
	npc_barnacle = true
}

NETWORK.relations.combineCitizen = D_NU

function NETWORK.relations.GetGroup(npc)
	local class = npc:GetClass()

	if (NETWORK.relations.combine[class]) then
		return {alliance = D_LI, citizen = NETWORK.relations.combineCitizen}
	end

	if (NETWORK.relations.rebel[class]) then
		return {alliance = D_HT, citizen = D_LI}
	end

	if (NETWORK.relations.wild[class]) then
		return {alliance = D_HT, citizen = D_HT}
	end
end

function NETWORK.relations.Apply(npc)
	if (!NETWORK.relations.bEnabled or !IsValid(npc) or !npc:IsNPC()) then
		return
	end

	if (npc:GetNWString("nwDeploy", "") != "" or
		(NETWORK.deploy and NETWORK.deploy.IsManaged and NETWORK.deploy.IsManaged(npc))) then
		return
	end

	local group = NETWORK.relations.GetGroup(npc)

	if (!group) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		if (!client:HasCharacter()) then
			continue
		end

		local disposition = NETWORK.factions.IsAlliance(client) and group.alliance or
			group.citizen

		npc:AddEntityRelationship(client, disposition, 99)
	end
end

function NETWORK.relations.ApplyAll()
	for _, npc in ipairs(ents.GetAll()) do
		if (npc:IsNPC()) then
			NETWORK.relations.Apply(npc)
		end
	end
end

hook.Add("OnEntityCreated", "nwRelations", function(entity)
	timer.Simple(0.2, function()
		if (IsValid(entity) and entity:IsNPC()) then
			NETWORK.relations.Apply(entity)
		end
	end)
end)

hook.Add("PlayerSpawn", "nwRelations", function()
	timer.Simple(0.5, NETWORK.relations.ApplyAll)
end)

hook.Add("NetworkCharacterLoaded", "nwRelations", function()
	timer.Simple(1, NETWORK.relations.ApplyAll)
end)

hook.Add("NetworkFactionTransferred", "nwRelations", function()
	timer.Simple(1, NETWORK.relations.ApplyAll)
end)

hook.Add("InitPostEntity", "nwRelations", function()
	timer.Simple(2, NETWORK.relations.ApplyAll)
end)

concommand.Add("network_relations", function(client, _, arguments)
	if (IsValid(client) and !client:IsSuperAdmin()) then
		return
	end

	NETWORK.relations.bEnabled = tobool(arguments[1])

	if (NETWORK.relations.bEnabled) then
		NETWORK.relations.ApplyAll()
	else
		for _, npc in ipairs(ents.GetAll()) do
			if (npc:IsNPC()) then
				npc:ClearAllEntityRelationships()
			end
		end
	end

	NETWORK.util.Print("Отношения NPC: " ..
		(NETWORK.relations.bEnabled and "включены" or "выключены"))
end, nil, "Включает или выключает раздачу отношений NPC по фракциям")
