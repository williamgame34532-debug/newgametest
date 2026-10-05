NETWORK.vort = NETWORK.vort or {}

local VORT = NETWORK.vort

VORT.freeClass = "vortigaunt"
VORT.slaveClass = "vortslave"
VORT.highClass = "vorthigh"
VORT.beam = "swep_vortigaunt_beam"

VORT.highScale = 3
VORT.highDrain = 0
VORT.highUnityNeeded = 1

VORT.energyMax = 100
VORT.energyRegen = 1
VORT.auraDrain = 1
VORT.auraRadius = 320
VORT.auraTick = 3

VORT.auraHeal = 4
VORT.auraWound = 5
VORT.wardScale = 0.75
VORT.dreadSpeed = 0.8
VORT.dreadDealt = 0.8

VORT.healRange = 130
VORT.healAmount = 60
VORT.healBlood = 800
VORT.healWound = 60

VORT.fieldHits = 5
VORT.fieldMemory = 30
VORT.fieldRange = 2000

VORT.unityTime = 300
VORT.unityCooldown = 900
VORT.unityNeeded = 3
VORT.unityTaken = 0.7
VORT.unityDealt = 1.5
VORT.unityAura = 2
VORT.prayRadius = 320
VORT.prayTime = 20

VORT.auras = {
	{id = "none", name = "vortAuraNone", hint = "vortAuraNoneHint", icon = "icon16/cancel.png"},
	{id = "heal", name = "vortAuraHeal", hint = "vortAuraHealHint", icon = "icon16/heart.png",
		color = Color(120, 235, 140)},
	{id = "ward", name = "vortAuraWard", hint = "vortAuraWardHint", icon = "icon16/shield.png",
		color = Color(120, 190, 250)},
	{id = "dread", name = "vortAuraDread", hint = "vortAuraDreadHint",
		icon = "icon16/weather_lightning.png", color = Color(180, 120, 250)}
}

VORT.casts = {
	heal = {name = "vortCastHeal", hint = "vortCastHealHint", icon = "icon16/heart_add.png",
		cost = 30, cooldown = 30, sequence = {"heal_start", "gest_heal"}, time = 3},
	wave = {name = "vortCastWave", hint = "vortCastWaveHint", icon = "icon16/lightning.png",
		cost = 40, cooldown = 30, sequence = {"stomp", "meleelow"}, time = 1.2,
		radius = 260, damage = 40},
	sight = {name = "vortCastSight", hint = "vortCastSightHint", icon = "icon16/eye.png",
		cost = 20, cooldown = 45, sequence = {"hg_headup", "idle02"}, time = 1.5,
		duration = 15, range = 1600},
	pray = {name = "vortCastPray", hint = "vortCastPrayHint", icon = "icon16/star.png",
		cost = 0, cooldown = 5, sequence = {"gest_chant", "chess_wait"}, bSlave = true}
}

VORT.castOrder = {"heal", "wave", "sight", "pray"}

for id, cast in pairs(VORT.casts) do
	cast.id = id
end

function VORT.IsVort(client)
	return IsValid(client) and client:IsPlayer() and client:HasCharacter() and
		client:GetCharacterFaction() == "vortigaunt"
end

function VORT.GetClass(client)
	return IsValid(client) and client:GetNWString("nwClass", "") or ""
end

function VORT.IsHigh(client)
	return VORT.IsVort(client) and VORT.GetClass(client) == VORT.highClass
end

function VORT.IsFree(client)
	local class = VORT.GetClass(client)

	return VORT.IsVort(client) and
		(class == VORT.freeClass or class == VORT.highClass)
end

function VORT.GetScale(client)
	return VORT.IsHigh(client) and VORT.highScale or 1
end

function VORT.GetCost(client, id)
	local cast = VORT.casts[id]

	if (!cast) then
		return 0
	end

	return math.floor(cast.cost / VORT.GetScale(client))
end

function VORT.GetCooldownTime(client, id)
	local cast = VORT.casts[id]

	if (!cast) then
		return 0
	end

	return cast.cooldown / VORT.GetScale(client)
end

function VORT.GetAuraDrain(client)
	return VORT.IsHigh(client) and VORT.highDrain or VORT.auraDrain
end

function VORT.GetAuraRadius(client)
	return VORT.auraRadius * VORT.GetScale(client)
end

function VORT.GetUnityNeeded(client)
	return VORT.IsHigh(client) and VORT.highUnityNeeded or VORT.unityNeeded
end

function VORT.GetAura(client)
	local aura = client:GetNWString("nwVortAura", "none")

	return aura != "" and aura or "none"
end

function VORT.GetEnergy(client)
	return client:GetNWFloat("nwVortEnergy", VORT.energyMax)
end

function VORT.GetCooldown(client, id)
	return math.max(client:GetNWFloat("nwVortCD_" .. id, 0) - CurTime(), 0)
end

function VORT.HasUnity(client)
	return IsValid(client) and client:GetNWFloat("nwVortUnity", 0) > CurTime()
end

function VORT.IsPraying(client)
	return client:GetNWFloat("nwVortPraying", 0) > CurTime()
end

function VORT.GetAuraData(id)
	for _, data in ipairs(VORT.auras) do
		if (data.id == id) then
			return data
		end
	end
end

function VORT.IsAlly(target)
	return IsValid(target) and target:IsPlayer() and target:Alive() and
		target:HasCharacter() and !NETWORK.factions.IsAlliance(target)
end

function VORT.IsEnemy(target)
	if (!IsValid(target)) then
		return false
	end

	if (target:IsPlayer()) then
		return target:Alive() and target:HasCharacter() and NETWORK.factions.IsAlliance(target)
	end

	return target:IsNPC() and target:Health() > 0 and
		(target:Classify() == CLASS_COMBINE or target:Classify() == CLASS_METROPOLICE or
		target:Classify() == CLASS_MANHACK or target:Classify() == CLASS_SCANNER or
		target:Classify() == CLASS_COMBINE_HUNTER)
end

function VORT.GetPower(client)
	return (VORT.HasUnity(client) and VORT.unityAura or 1) * VORT.GetScale(client)
end

function VORT.CanCast(client, id)
	local cast = VORT.casts[id]

	if (!cast or !VORT.IsVort(client) or !client:Alive()) then
		return false, "vortNoPower"
	end

	if (!cast.bSlave and !VORT.IsFree(client)) then
		return false, "vortCollared"
	end

	if (VORT.GetCooldown(client, id) > 0) then
		return false, "vortCooldown"
	end

	if (VORT.GetEnergy(client) < VORT.GetCost(client, id)) then
		return false, "vortNoEnergy"
	end

	return true
end

function VORT.FindSequence(client, list, keywords)
	for _, name in ipairs(list or {}) do
		local sequence = client:LookupSequence(name)

		if (sequence and sequence > 0) then
			return name, sequence
		end
	end

	if (!keywords) then
		return
	end

	local count = client:GetSequenceCount() or 0

	for index = 0, count - 1 do
		local name = client:GetSequenceName(index)

		if (!name) then
			continue
		end

		local lower = string.lower(name)

		for _, word in ipairs(keywords) do
			if (string.find(lower, word, 1, true)) then
				return name, index
			end
		end
	end
end

function VORT.GetHealTarget(client)
	return NETWORK.util.FindLookedAt(client, VORT.healRange * VORT.GetScale(client),
		function(entity)
			return entity:IsPlayer() and entity != client and entity:Alive() and
				entity:HasCharacter()
		end)
end

hook.Add("NetworkMovementSpeed", "nwVortDread", function(client, walk, run)
	if (client:GetNWFloat("nwVortDreaded", 0) <= CurTime()) then
		return
	end

	return math.Round(walk * VORT.dreadSpeed), math.Round(run * VORT.dreadSpeed)
end)
