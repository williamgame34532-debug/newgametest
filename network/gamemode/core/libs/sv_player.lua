NETWORK.player = NETWORK.player or {}

NETWORK.player.fallbackModel = "models/humans/group01/male_02.mdl"

function NETWORK.player.SetLimbo(client)
	client:SetModel(NETWORK.player.fallbackModel)
	client:SetModelScale(1, 0)
	client:SetViewOffset(Vector(0, 0, 64))
	client:SetViewOffsetDucked(Vector(0, 0, 28))
	client:SetMoveType(MOVETYPE_NONE)
	client:SetNoDraw(true)
	client:SetNotSolid(true)
	client:Freeze(true)
	client:StripWeapons()
	client:SetNoTarget(true)

	NETWORK.movement.Apply(client)
end

function NETWORK.player.ApplyScale(client)
	local character = client:GetCharacter()

	if (!character) then
		return
	end

	local override = math.Clamp(tonumber(client.nwScaleOverride) or 1, 0.4, 3)
	local scale = NETWORK.creation.GetModelScale(client:GetModel(), character:GetHeight()) * override

	client:SetModelScale(scale, 0)

	client:SetViewOffset(Vector(0, 0, 64 * scale))
	client:SetViewOffsetDucked(Vector(0, 0, 28 * scale))

	client:SetHull(Vector(-16, -16, 0) * override, Vector(16, 16, 72) * override)
	client:SetHullDuck(Vector(-16, -16, 0) * override, Vector(16, 16, 36) * override)

	client:SetNWFloat("nwScale", override)
end

function NETWORK.player.ApplyCharacter(client, character)
	local model = character:GetModel()

	if (!util.IsValidModel(model)) then
		NETWORK.util.PrintWarning("Модель персонажа недоступна: " .. tostring(model))

		model = NETWORK.player.fallbackModel
	end

	client:SetModel(model)
	client:SetupHands()

	NETWORK.player.ApplyScale(client)

	client:SetMoveType(MOVETYPE_WALK)
	client:SetNoDraw(false)
	client:SetNotSolid(false)
	client:Freeze(false)
	client:SetNoTarget(false)

	NETWORK.movement.Apply(client)

	client:Give("weapon_nwhands")
	client:SelectWeapon("weapon_nwhands")

	local faction = character:GetFactionTable()

	if (faction and faction.OnSpawn) then
		faction:OnSpawn(client, character)
	end

	NETWORK.inventory.RefreshAppearance(client)
	NETWORK.inventory.RefreshWeapons(client)

	timer.Simple(0.1, function()
		if (IsValid(client) and client:Alive() and NETWORK.inventory.RefreshAppearance) then
			NETWORK.inventory.RefreshAppearance(client)
			NETWORK.inventory.RefreshWeapons(client)
		end
	end)

	hook.Run("NetworkPlayerLoadout", client, character)
end

function GM:PlayerInitialSpawn(client)
	client:SetTeam(TEAM_UNASSIGNED)

	client.nwNextCharacterAction = 0
end

NETWORK.player.bAllowSuicide = false

function GM:CanPlayerSuicide(client)
	if (NETWORK.player.bAllowSuicide or !client:HasCharacter()) then
		return true
	end

	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString("suicideBlocked")
	net.Send(client)

	return false
end

function GM:PlayerSpawn(client)
	client:SetNWFloat("nwRespawn", 0)
	client:SetNWEntity("nwRagdoll", NULL)
	client:SetNWBool("nwExhausted", false)

	local character = client:GetCharacter()

	if (!character) then
		NETWORK.player.SetLimbo(client)

		return
	end

	NETWORK.player.ApplyCharacter(client, character)
end

NETWORK.player.weaponDropChance = 40

function NETWORK.player.DropLoot(client)
	local state = NETWORK.inventory.GetState(client)

	for slot, item in pairs(state.equipped) do
		local _, tag = NETWORK.item.GetTag(item)

		if (tag == "keep") then
			continue
		end

		if (tag == "destroy") then
			state.equipped[slot] = nil

			continue
		end

		local free = NETWORK.inventory.FindSpot(state.items, NETWORK.inventory.columns,
			NETWORK.inventory.rows, item)

		if (free) then
			state.items[free] = item
			state.equipped[slot] = nil
		end
	end

	local dropped = {}

	for index, item in pairs(state.items) do
		local base = NETWORK.item.Get(item.id)

		if (!base) then
			continue
		end

		local _, tag = NETWORK.item.GetTag(item)

		if (tag == "keep") then
			continue
		end

		if (tag == "destroy") then
			state.items[index] = nil

			continue
		end

		if (base.weaponClass and
			math.random(100) > NETWORK.player.weaponDropChance) then
			continue
		end

		dropped[#dropped + 1] = item
		state.items[index] = nil
	end

	for index, item in pairs(state.storage) do
		local _, tag = NETWORK.item.GetTag(item)

		if (tag == "keep") then
			continue
		end

		state.storage[index] = nil

		if (tag != "destroy") then
			dropped[#dropped + 1] = item
		end
	end

	NETWORK.inventory.Sync(client)

	if (#dropped == 0) then
		return
	end

	local ragdoll = client:GetNWEntity("nwRagdoll", NULL)

	if (!IsValid(ragdoll)) then
		return
	end

	ragdoll.nwLoot = {}

	local columns = NETWORK.inventory.columns
	local rows = NETWORK.inventory.rows

	for _, item in ipairs(dropped) do
		local free = NETWORK.inventory.FindSpot(ragdoll.nwLoot, columns, rows, item)

		if (free) then
			ragdoll.nwLoot[free] = item
		end
	end

	ragdoll:SetNWBool("nwLooted", #dropped == 0)

	NETWORK.util.Print(string.format("%s выронил %d предметов", client:SteamID(),
		#dropped))
end

NETWORK.player.deathVelocity = 140
NETWORK.player.deathDamping = 0.35

NETWORK.player.corpseTime = 0

function GM:PlayerLoadout(client)
	return true
end

function GM:PlayerDeathThink(client)
	return false
end

NETWORK.player.spawnProtect = 6

function NETWORK.player.IsProtected(client)
	return (client.nwProtectUntil or 0) > CurTime()
end

function GM:PlayerShouldTakeDamage(client, attacker)
	if (NETWORK.player.IsProtected(client)) then
		return false
	end

	return client:HasCharacter()
end

hook.Add("PlayerSpawn", "nwSpawnProtect", function(client)
	if (!client:HasCharacter() or NETWORK.player.spawnProtect <= 0) then
		return
	end

	client.nwProtectUntil = CurTime() + NETWORK.player.spawnProtect
	client.nwProtectPos = client:GetPos()
end)

hook.Add("StartCommand", "nwSpawnProtect", function(client, cmd)
	if (!NETWORK.player.IsProtected(client)) then
		return
	end

	local bActed = cmd:KeyDown(IN_ATTACK) or cmd:KeyDown(IN_ATTACK2) or
		cmd:KeyDown(IN_USE)

	if (bActed or (client.nwProtectPos and
		client:GetPos():Distance(client.nwProtectPos) > 64)) then
		client.nwProtectUntil = nil
	end
end)

util.AddNetworkString("nwDeathReport")

hook.Add("EntityTakeDamage", "nwDeathRecord", function(victim, damage)
	if (!victim:IsPlayer()) then
		return
	end

	local attacker = damage:GetAttacker()
	local inflictor = damage:GetInflictor()
	local weapon = IsValid(attacker) and attacker:IsPlayer() and
		attacker:GetActiveWeapon()

	victim.nwLastHit = {
		group = victim:LastHitGroup(),
		position = damage:GetDamagePosition(),
		distance = IsValid(attacker) and
			math.Round(attacker:GetPos():Distance(victim:GetPos()) * 0.0254) or 0,
		weapon = IsValid(weapon) and (weapon.PrintName or weapon:GetClass()) or
			(IsValid(inflictor) and inflictor:GetClass() or ""),
		attacker = IsValid(attacker) and attacker:IsPlayer() and
			attacker:GetCharacterName() or ""
	}
end)

hook.Add("PlayerSpawn", "nwDeathLifetime", function(client)

	client.nwSpawnTime = CurTime()
end)

hook.Add("PlayerDeath", "nwDeathScreen", function(client, inflictor, attacker)
	local hit = client.nwLastHit or {}

	net.Start("nwDeathReport")
		net.WriteUInt(hit.group or HITGROUP_GENERIC, 4)
		net.WriteUInt(math.Clamp(hit.distance or 0, 0, 4095), 12)
		net.WriteString(hit.weapon or "")
		net.WriteString(hit.attacker or "")
		net.WriteUInt(math.Clamp(math.Round(CurTime() -
			(client.nwSpawnTime or CurTime())), 0, 262143), 18)
	net.Send(client)
end)

hook.Add("PlayerDeath", "nwDeathReport", function(client, inflictor, attacker)
	local attackerName = IsValid(attacker) and (attacker:IsPlayer() and
		attacker:GetCharacterName() or attacker:GetClass()) or "мир"
	local inflictorName = IsValid(inflictor) and inflictor:GetClass() or "-"

	NETWORK.util.Print(string.format("%s убит: %s (%s)", client:SteamID(),
		attackerName, inflictorName))

	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(L("deathBy", attackerName, inflictorName))
	net.Send(client)
end)

hook.Add("EntityTakeDamage", "nwPropDamage", function(target, info)
	if (!target:IsPlayer()) then
		return
	end

	local inflictor = info:GetInflictor()
	local class = IsValid(inflictor) and inflictor:GetClass() or ""

	if (info:IsDamageType(DMG_CRUSH) and (class == "" or class == "worldspawn" or
		string.find(class, "prop_") or class == "nw_item" or class == "nw_container")) then
		return true
	end
end)

hook.Add("SetupMove", "nwPropSurf", function(client, mv)
	local ground = client:GetGroundEntity()

	if (!IsValid(ground)) then
		return
	end

	local class = ground:GetClass()

	if (!string.find(class, "prop_") and class != "nw_item" and class != "nw_container") then
		return
	end

	local velocity = mv:GetVelocity()

	if (velocity.z > 90) then
		mv:SetVelocity(Vector(velocity.x, velocity.y, 90))
	end
end)

local function Dress(ragdoll, client)
	ragdoll:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)

	ragdoll.nwOwner = nil

	ragdoll.PhysgunDisabled = true
	ragdoll.nwNoCarry = nil
	ragdoll.nwCarryable = true

	ragdoll:SetNWBool("nwCorpse", true)
	ragdoll:SetNWString("nwCorpseName", client:GetCharacterName())
	ragdoll:SetNWString("nwCorpseFaction", client:GetCharacterFaction() or "")
	ragdoll:SetNWEntity("nwCorpseOwner", client)

	local lifetime = NETWORK.config.Get("corpseTime") or NETWORK.player.corpseTime

	if (lifetime > 0) then
		timer.Simple(lifetime, function()
			if (IsValid(ragdoll)) then
				ragdoll:Remove()
			end
		end)
	end
end

function NETWORK.player.CreateCorpse(client)

	local existing = client.nwLastRagdoll

	client.nwLastRagdoll = nil

	if (IsValid(existing)) then
		Dress(existing, client)

		hook.Run("NetworkCorpseCreated", client, existing)

		return existing
	end

	local ragdoll = ents.Create("prop_ragdoll")

	if (!IsValid(ragdoll)) then
		return
	end

	ragdoll:SetModel(client:GetModel())
	ragdoll:SetPos(client:GetPos())
	ragdoll:SetAngles(Angle(0, client:EyeAngles().y, 0))
	ragdoll:SetSkin(client:GetSkin())

	for _, data in pairs(client:GetBodyGroups()) do
		ragdoll:SetBodygroup(data.id, client:GetBodygroup(data.id))
	end

	ragdoll:Spawn()
	ragdoll:Activate()

	Dress(ragdoll, client)

	local velocity = client:GetVelocity()

	if (velocity:Length() > NETWORK.player.deathVelocity) then
		velocity = velocity:GetNormalized() * NETWORK.player.deathVelocity
	end

	velocity = velocity * NETWORK.player.deathDamping

	for index = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local physics = ragdoll:GetPhysicsObjectNum(index)

		if (!IsValid(physics)) then
			continue
		end

		local bone = ragdoll:TranslatePhysBoneToBone(index)
		local matrix = bone and client:GetBoneMatrix(bone)

		if (matrix) then
			physics:SetPos(matrix:GetTranslation())
			physics:SetAngles(matrix:GetAngles())
		end

		physics:SetVelocity(velocity)
		physics:SetDamping(1.4, 3.2)
		physics:SetMaterial("flesh")
	end

	timer.Simple(2.5, function()
		if (!IsValid(ragdoll)) then
			return
		end

		for index = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			local physics = ragdoll:GetPhysicsObjectNum(index)

			if (IsValid(physics)) then
				physics:SetDamping(4, 8)
			end
		end
	end)

	hook.Run("NetworkCorpseCreated", client, ragdoll)

	return ragdoll
end

function GM:PlayerDeath(client, inflictor, attacker)
	local delay = NETWORK.config.Get("respawnTime") or 12

	local ragdoll = NETWORK.player.CreateCorpse(client)

	if (IsValid(ragdoll)) then
		client:SetNWEntity("nwRagdoll", ragdoll)
	end

	timer.Simple(0, function()
		if (!IsValid(client)) then
			return
		end

		local engine = client:GetRagdollEntity()

		if (IsValid(engine) and engine != ragdoll) then
			engine:Remove()
		end
	end)

	NETWORK.player.DropLoot(client)

	client:SetNWFloat("nwRespawn", CurTime() + delay)

	if (NETWORK.persistence) then
		NETWORK.persistence.Save(client)
	end

	timer.Simple(delay, function()
		if (IsValid(client) and client:HasCharacter() and !client:Alive()) then
			client:Spawn()
		end
	end)
end

function GM:GetFallDamage(client, speed)
	return math.max((speed - 450) / 8, 0)
end

function GM:PlayerDeathSound()
	return true
end

function GM:PlayerPainSound(client)
	return true
end

util.AddNetworkString("nwOpenMenu")

function GM:ShowHelp(client)
	if (!IsValid(client)) then
		return
	end

	timer.Simple(3.6, function()
		if (!IsValid(client) or client:HasCharacter()) then
			return
		end

		net.Start("nwOpenMenu")
		net.Send(client)
	end)
end

function GM:PlayerSwitchFlashlight(client, bEnabled)
	if (!client:HasCharacter()) then
		return false
	end

	if (NETWORK.nvg and NETWORK.nvg.HasFlashlight and NETWORK.nvg.HasFlashlight(client)) then
		return true
	end

	if (NETWORK.factions.IsAlliance(client)) then
		client:EmitSound("buttons/combine_button" ..
			(bEnabled and "1" or "2") .. ".wav", 60, bEnabled and 110 or 90)

		return true
	end

	local state = NETWORK.inventory.GetState(client)

	for _, item in pairs(state.equipped) do
		local base = NETWORK.item.Get(item.id)

		if (base and base.equipSlot == "light") then
			return true
		end
	end

	if (bEnabled) then
		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString("itemNoLight")
		net.Send(client)
	end

	return false
end

hook.Add("PlayerShouldTakeDamage", "nwNoclipGod", function(client, attacker)
	if (client:GetMoveType() == MOVETYPE_NOCLIP) then
		return false
	end
end)

timer.Create("nwNoclipHide", 0.25, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local bNoclip = client:GetMoveType() == MOVETYPE_NOCLIP

		if (bNoclip != (client.nwNoclipHidden == true)) then
			client.nwNoclipHidden = bNoclip

			client:SetNoDraw(bNoclip)
			client:DrawShadow(!bNoclip)
			client:SetNoTarget(bNoclip)

			local weapon = client:GetActiveWeapon()

			if (IsValid(weapon)) then
				weapon:SetNoDraw(bNoclip)
			end
		end
	end
end)
