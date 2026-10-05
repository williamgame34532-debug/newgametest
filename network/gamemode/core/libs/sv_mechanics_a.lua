NETWORK.mech = NETWORK.mech or {}

local M = NETWORK.mech

local function Notice(client, key, tone, ...)
	NETWORK.notice.Send(client, key, tone or "info", ...)
end

M.shoveTime = 20
M.shoveRange = 100
M.shoveCost = 35

NETWORK.command.Register("shove", {
	description = "cmdShove",
	usage = "/shove",
	aliases = {"vyrubit", "knock"},
	OnRun = function(command, client)
		if (!NETWORK.factions.IsAlliance(client)) then
			return Notice(client, "shoveNoAccess", "warn")
		end

		local target = client:GetEyeTrace().Entity

		if (!IsValid(target) or !target:IsPlayer() or !target:HasCharacter() or
			client:GetPos():Distance(target:GetPos()) > M.shoveRange) then
			return Notice(client, "shoveNoTarget", "warn")
		end

		if (target:IsDowned() or target:IsUnconscious()) then
			return Notice(client, "shoveAlready", "warn")
		end

		if (NETWORK.needs.GetExact(client) < M.shoveCost) then
			return Notice(client, "shoveTired", "warn")
		end

		if ((client.nwNextShove or 0) > CurTime()) then
			return
		end

		client.nwNextShove = CurTime() + 4

		NETWORK.needs.PushStamina(client, NETWORK.needs.GetExact(client) - M.shoveCost,
			true)

		target:EmitSound("physics/body/body_medium_impact_hard" ..
			math.random(1, 6) .. ".wav", 70, 100)

		NETWORK.chat.Send(client, "me", L("shoveMe"))

		if (NETWORK.medical and NETWORK.medical.SetUnconscious) then
			NETWORK.medical.SetUnconscious(target, true)

			target.nwRagdollUntil = CurTime() + M.shoveTime
			target:SetNWFloat("nwRagdollUntil", target.nwRagdollUntil)
		end

		Notice(target, "shoveHit", "bad")
	end
})

M.ammoItems = {
	Pistol = "ammo_pistol",
	SMG1 = "ammo_smg",
	Buckshot = "ammo_buckshot",
	AR2 = "ammo_ar2",
	[".357"] = "ammo_357",
	["357"] = "ammo_357"
}

NETWORK.command.Register("unload", {
	description = "cmdUnload",
	usage = "/unload",
	aliases = {"razryadit"},
	OnRun = function(command, client)
		local weapon = client:GetActiveWeapon()

		if (!IsValid(weapon) or weapon:Clip1() <= 0) then
			return Notice(client, "unloadNothing", "warn")
		end

		local ammoType = game.GetAmmoName(weapon:GetPrimaryAmmoType() or 0)
		local id = M.ammoItems[ammoType or ""]

		if (!id or !NETWORK.item.Get(id)) then
			return Notice(client, "unloadNoItem", "warn")
		end

		local rounds = weapon:Clip1()

		weapon:SetClip1(0)

		if (!NETWORK.inventory.Give(client, id, 1)) then
			NETWORK.item.Spawn(id, client:GetPos() + client:GetForward() * 20 +
				Vector(0, 0, 16))
		end

		client:EmitSound("weapons/smg1/switch_single.wav", 55, 110)

		Notice(client, "unloadDone", "good", rounds)
	end
})

concommand.Add("network_item_use", function(client, _, arguments)
	if (!IsValid(client) or !client:HasCharacter() or !client:Alive()) then
		return
	end

	local id = string.lower(arguments[1] or "")

	if (id == "") then
		return
	end

	if ((client.nwNextBindUse or 0) > CurTime()) then
		return
	end

	client.nwNextBindUse = CurTime() + 0.4

	local state = NETWORK.inventory.GetState(client)

	for list, entries in pairs({items = state.items, storage = state.storage}) do
		for index, item in pairs(entries or {}) do
			if (istable(item) and item.id == id) then

				if (NETWORK.inventory.RunAction) then
					NETWORK.inventory.RunAction(client, "use", {
						fromList = list,
						fromIndex = index
					})
				end

				return
			end
		end
	end

	Notice(client, "bindNoItem", "warn")
end, nil, "Использовать предмет из сумки по названию: bind j \"network_item_use medkit\"")

NETWORK.config.Register("cleanupTime", {
	name = "cfgCleanup",
	description = "cfgCleanupDesc",
	category = "world",
	default = 20,
	min = 0,
	max = 120,
	decimals = 0
})

timer.Create("nwCleanupDrops", 60, 0, function()
	local minutes = tonumber(NETWORK.config.Get("cleanupTime")) or 20

	if (minutes <= 0) then
		return
	end

	local life = minutes * 60

	for _, entity in ipairs(ents.FindByClass("nw_item")) do
		if (entity.nwNoCleanup) then
			continue
		end

		entity.nwDropTime = entity.nwDropTime or CurTime()

		local age = CurTime() - entity.nwDropTime

		if (age > life - 60 and !entity.nwCleanupWarned) then
			entity.nwCleanupWarned = true
			entity:SetColor(Color(255, 180, 180))
		end

		if (age > life) then
			entity:Remove()
		end
	end
end)

M.npcDrops = {
	npc_headcrab = {{"scrap", 40}},
	npc_zombie = {{"rag", 45}, {"scrap", 30}},
	npc_fastzombie = {{"rag", 40}, {"bandage", 15}},
	npc_antlion = {{"resin", 35}},
	npc_metropolice = {{"ammo_pistol", 35}, {"bandage", 20}},
	npc_combine_s = {{"ammo_smg", 30}, {"ammo_ar2", 15}}
}

hook.Add("OnNPCKilled", "nwNpcDrops", function(npc, attacker)
	local list = M.npcDrops[npc:GetClass()]

	if (!list or !IsValid(attacker) or !attacker:IsPlayer()) then
		return
	end

	local position = npc:WorldSpaceCenter()

	for _, entry in ipairs(list) do
		if (math.random(100) <= entry[2]) then
			NETWORK.item.Spawn(entry[1], position + VectorRand() * 16 +
				Vector(0, 0, 8))
		end
	end
end)

hook.Add("NetworkMedicalStarted", "nwLowerOnHeal", function(client)
	if (!IsValid(client)) then
		return
	end

	if (client:IsWeaponRaised() and NETWORK.weapon.SetRaised) then
		NETWORK.weapon.SetRaised(client, false)
	end
end)

hook.Add("NetworkWeaponRaised", "nwLowerOnHeal", function(client, bRaised)

	if (bRaised and IsValid(client) and client.nwMedTask and NETWORK.medical.Cancel) then
		NETWORK.medical.Cancel(client, "medInterrupted")
	end
end)

M.kickTime = 1.2
M.kickNeed = 3

NETWORK.command.Register("kick", {
	description = "cmdKickDoor",
	usage = "/kick",
	aliases = {"vybit", "breach"},
	OnRun = function(command, client)
		if (!NETWORK.factions.IsAlliance(client)) then
			return Notice(client, "kickNoAccess", "warn")
		end

		local entity = client:GetEyeTrace().Entity

		if (!NETWORK.door.IsDoor(entity) or
			client:GetPos():Distance(entity:GetPos()) > 110) then
			return Notice(client, "doorNotDoor", "warn")
		end

		if ((client.nwNextKick or 0) > CurTime()) then
			return
		end

		client.nwNextKick = CurTime() + M.kickTime

		entity.nwKicks = (entity.nwKicks or 0) + 1

		entity:EmitSound("physics/wood/wood_crate_impact_hard" ..
			math.random(2, 3) .. ".wav", 85, 90)

		for _, target in ipairs(player.GetAll()) do
			if (target != client and target:GetPos():Distance(entity:GetPos()) < 1200) then
				Notice(target, "kickHeard", "warn")
			end
		end

		if (entity.nwKicks < M.kickNeed) then
			return Notice(client, "kickProgress", "info", entity.nwKicks, M.kickNeed)
		end

		entity.nwKicks = 0

		entity:Fire("Unlock")
		entity:Fire("Open")
		entity:EmitSound("doors/door_squeak1.wav", 80, 90)

		timer.Simple(20, function()
			if (IsValid(entity)) then
				entity:Fire("Lock")
			end
		end)

		Notice(client, "kickDone", "good")

		if (NETWORK.log and NETWORK.log.Add) then
			NETWORK.log.Add("door", string.format("%s выбил дверь",
				NETWORK.log.Name(client)), client:GetPos())
		end
	end
})
