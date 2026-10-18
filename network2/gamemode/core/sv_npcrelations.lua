-- Who the NPCs of Half-Life are to whom (by the faction of the player):
--   the Combine NPCs   (metrocops, soldiers, scanners, manhacks, rollermines, turrets, cameras, striders,
--                      hunters, gunships...) - the Alliance: friends; everyone else: left alone, until they
--                      attack the Alliance (a unit or a Combine NPC) - then "wanted" for nw_wanted_time
--                      seconds (120) and hunted
--   the rebels         (Alyx, Barney, the vortigaunts, the rebels among the citizens) - the Alliance:
--                      enemies; everyone else: friends
--   the other citizens of the map - nobody's enemy
-- The zombies and the rest stay as the game made them.
-- The deployables of the Alliance (the items «Мэнхек», «Роллермина», «Турель Альянса», from the fabricator):
-- used - the NPC comes out in front of the unit, with the same friends and enemies; Alt + E on one's own
-- turret folds it back into the inventory.

NW.npcRelations = NW.npcRelations or {}

local NR = NW.npcRelations

local wantedTime = CreateConVar("nw_wanted_time", "120", FCVAR_ARCHIVE,
	"Сколько секунд Альянс-NPC охотятся на того, кто напал на Альянс")

NR.combine = {}

for _, class in ipairs({"npc_metropolice", "npc_combine_s", "npc_cscanner", "npc_clawscanner", "npc_manhack",
	"npc_rollermine", "npc_turret_floor", "npc_turret_ceiling", "npc_turret_ground", "npc_combine_camera", "npc_strider",
	"npc_hunter", "npc_helicopter", "npc_combinegunship", "npc_combinedropship", "npc_stalker", "npc_apcdriver",
	"npc_sniper", "npc_advisor"}) do
	NR.combine[class] = true
end

NR.rebels = {npc_alyx = true, npc_barney = true, npc_vortigaunt = true, npc_dog = true, npc_monk = true,
	npc_eli = true, npc_kleiner = true, npc_mossman = true, npc_magnusson = true, npc_fisherman = true}

local function Alliance(client)
	return client:GetCharacterID() != 0 and NW.zones.IsAlliance(client)
end

function NR.Wanted(client)
	return (client.nwWanted or 0) > CurTime()
end

-- a citizen of the map is a rebel when the map made it one (citizentype 3)
local function Rebel(npc)
	if (NR.rebels[npc:GetClass()]) then
		return true
	end

	if (npc:GetClass() == "npc_citizen") then
		local values = npc:GetKeyValues()

		return tonumber(values.citizentype) == 3
	end

	return false
end

function NR.Apply(npc, client)
	if (!IsValid(npc) or !npc:IsNPC() or !IsValid(client) or !client:IsPlayer()) then
		return
	end

	local class = npc:GetClass()

	if (NR.combine[class]) then
		if (Alliance(client)) then
			npc:AddEntityRelationship(client, D_LI, 99)
		elseif (NR.Wanted(client)) then
			npc:AddEntityRelationship(client, D_HT, 80)
		else
			npc:AddEntityRelationship(client, D_NU, 50)
		end
	elseif (Rebel(npc)) then
		npc:AddEntityRelationship(client, Alliance(client) and D_HT or D_LI, 70)
	elseif (class == "npc_citizen") then
		npc:AddEntityRelationship(client, D_NU, 50)
	end
end

local function AllNPCs(client)
	for _, npc in ipairs(ents.GetAll()) do
		if (npc:IsNPC()) then
			NR.Apply(npc, client)
		end
	end
end

local function AllPlayers(npc)
	for _, client in ipairs(player.GetAll()) do
		NR.Apply(npc, client)
	end
end

NR.Refresh = AllNPCs

hook.Add("OnEntityCreated", "nwNpcRelations", function(entity)
	timer.Simple(0, function()
		if (IsValid(entity) and entity:IsNPC()) then
			AllPlayers(entity)
		end
	end)
end)

hook.Add("PlayerSpawn", "nwNpcRelations", function(client)
	timer.Simple(0.5, function()
		if (IsValid(client)) then
			AllNPCs(client)
		end
	end)
end)

hook.Add("NWFactionChanged", "nwNpcRelations", AllNPCs)
hook.Add("NWCharacterLoaded", "nwNpcRelations", function(client)
	timer.Simple(1, function()
		if (IsValid(client)) then
			AllNPCs(client)
		end
	end)
end)

-- an attack on the Alliance: wanted
hook.Add("EntityTakeDamage", "nwNpcRelations", function(target, damage)
	local attacker = damage:GetAttacker()

	if (!IsValid(attacker) or !attacker:IsPlayer() or Alliance(attacker)) then
		return
	end

	local victim = (target:IsPlayer() and Alliance(target)) or (target:IsNPC() and NR.combine[target:GetClass()])

	if (!victim) then
		return
	end

	local was = NR.Wanted(attacker)

	attacker.nwWanted = CurTime() + wantedTime:GetFloat()

	if (!was) then
		AllNPCs(attacker)
	end
end)

-- the wanted time over: left alone again
timer.Create("nwNpcWanted", 5, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (client.nwWanted and !NR.Wanted(client)) then
			client.nwWanted = nil
			AllNPCs(client)
		end
	end
end)

-- ------------------------------------------------------------ deployables --
function NR.Deploy(client, class)
	if (!Alliance(client)) then
		NW.Notify(client, "Устройства Альянса — только для юнитов")

		return false
	end

	local trace = client:GetEyeTrace()
	local pos

	if (class == "npc_manhack") then
		pos = client:EyePos() + client:GetAimVector() * 40
	else
		if (!trace.Hit or trace.HitPos:DistToSqr(client:GetShootPos()) > 150 * 150 or trace.HitNormal.z < 0.6) then
			NW.Notify(client, "Посмотрите на пол рядом с собой")

			return false
		end

		pos = trace.HitPos + trace.HitNormal * (class == "npc_rollermine" and 12 or 2)
	end

	local npc = ents.Create(class)

	if (!IsValid(npc)) then
		return false
	end

	npc:SetPos(pos)
	npc:SetAngles(Angle(0, client:EyeAngles().y, 0))
	npc:Spawn()
	npc:Activate()
	npc.nwOwner = client
	AllPlayers(npc)

	NW.SayMe(client, class == "npc_turret_floor" and "устанавливает турель" or "выпускает устройство Альянса")

	return true
end

-- folded back into the inventory: Alt + E on one's own device (a turret, a manhack, a rollermine; a unit can
-- take one whose owner is gone), or /fold - all of one's own within 400 units
NR.items = {npc_turret_floor = "deploy_turret", npc_manhack = "deploy_manhack", npc_rollermine = "deploy_rollermine"}

local function Fold(client, entity)
	local id = NR.items[entity:GetClass()]

	if (!NW.inventory.Add(client, id)) then
		NW.inventory.SpawnWorldItem(client, {id = id, data = {}})
	end

	NW.inventory.Changed(client)
	entity:EmitSound("buttons/combine_button" .. math.random(1, 3) .. ".wav", 60)
	entity:Remove()
end

local function Mine(client, entity)
	return entity.nwOwner == client or (!IsValid(entity.nwOwner) and Alliance(client))
end

hook.Add("PlayerUse", "nwDeployables", function(client, entity)
	if (IsValid(entity) and NR.items[entity:GetClass()] and Mine(client, entity) and client:KeyDown(IN_WALK) and
		(client.nwFoldNext or 0) < CurTime()) then
		client.nwFoldNext = CurTime() + 1
		Fold(client, entity)
		NW.Notify(client, "Устройство сложено в инвентарь")

		return false
	end
end)

NW.AddChatCommand("fold", {run = function(client)
	local count = 0

	for _, entity in ipairs(ents.FindInSphere(client:GetPos(), 400)) do
		if (IsValid(entity) and NR.items[entity:GetClass()] and entity.nwOwner == client) then
			Fold(client, entity)
			count = count + 1
		end
	end

	NW.Notify(client, count > 0 and ("Сложено устройств: " .. count) or "Рядом нет ваших устройств")
end})
