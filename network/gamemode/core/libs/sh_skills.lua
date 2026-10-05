NETWORK.skills = NETWORK.skills or {}

NETWORK.skills.maxLevel = 10
NETWORK.skills.baseXP = 90
NETWORK.skills.curve = 1.55

NETWORK.skills.effects = {
	strength = {
		weight = 1.5,
		punch = 1.2,
		carryMass = 18
	},
	agility = {
		run = 0.012,
		walk = 0.006,
		jump = 0.05
	},
	endurance = {
		drain = 0.04,
		regen = 0.03,
		damage = 0.02
	},
	intellect = {
		craft = 0.04,
		repairAt = {4, 8}
	},
	medicine = {
		time = 0.06,
		heal = 0.08,
		health = 2
	},
	charisma = {
		sell = 0.02,
		buy = 0.015
	},
	crafting = {
		time = 0.04,
		bonusChance = 0.03
	},
	stress = {
		suppress = 0.09
	}
}

function NETWORK.skills.SuppressFactor(client)
	return math.Clamp(1 - NETWORK.skills.Get(client, "stress") *
		NETWORK.skills.Effect("stress", "suppress"), 0.1, 1)
end

function NETWORK.skills.CraftTimeFactor(client)
	return math.Clamp(1 - NETWORK.skills.Get(client, "crafting") *
		NETWORK.skills.Effect("crafting", "time"), 0.5, 1)
end

function NETWORK.skills.RollCraftBonus(client, amount)
	if ((amount or 1) != 1 or !IsValid(client)) then
		return amount or 1
	end

	local chance = NETWORK.skills.Get(client, "crafting") *
		NETWORK.skills.Effect("crafting", "bonusChance")

	return math.Rand(0, 1) < chance and 2 or 1
end

function NETWORK.skills.Need(level)
	return math.Round(NETWORK.skills.baseXP * ((level or 0) + 1) ^ NETWORK.skills.curve)
end

function NETWORK.skills.GetDefinition(id)
	return NETWORK.creation.GetSkill(id)
end

function NETWORK.skills.List()
	return NETWORK.creation.skills
end

local PLAYER = FindMetaTable("Player")

function NETWORK.skills.GetProgress(client)
	if (SERVER) then
		local character = IsValid(client) and client:GetCharacter()

		if (!character) then
			return {levels = {}, xp = {}}
		end

		local key = tostring(character:GetID())

		NETWORK.skills.stored = NETWORK.skills.stored or {}
		NETWORK.skills.stored[key] = NETWORK.skills.stored[key] or {levels = {}, xp = {}}

		return NETWORK.skills.stored[key]
	end

	if (client == LocalPlayer()) then
		return NETWORK.skills.localData or {levels = {}, xp = {}}
	end

	return {levels = {}, xp = {}}
end

function NETWORK.skills.GetBase(client, id)
	return IsValid(client) and client.GetSkill and client:GetSkill(id) or 0
end

function NETWORK.skills.GetEarned(client, id)
	local progress = NETWORK.skills.GetProgress(client)

	return math.Round(tonumber((progress.levels or {})[id]) or 0)
end

function NETWORK.skills.GetXP(client, id)
	local progress = NETWORK.skills.GetProgress(client)

	return math.Round(tonumber((progress.xp or {})[id]) or 0)
end

function NETWORK.skills.Get(client, id)
	if (!IsValid(client)) then
		return 0
	end

	if (CLIENT and client != LocalPlayer()) then
		return client:GetNWInt("nwSkill_" .. id, 0)
	end

	local total = NETWORK.skills.GetBase(client, id) + NETWORK.skills.GetEarned(client, id)

	return math.Clamp(total, 0, NETWORK.skills.maxLevel)
end

function NETWORK.skills.Fraction(client, id)
	return NETWORK.skills.Get(client, id) / math.max(NETWORK.skills.maxLevel, 1)
end

function NETWORK.skills.Bonus(client, id, perLevel)
	return 1 + (perLevel or 0) * NETWORK.skills.Get(client, id)
end

function NETWORK.skills.Effect(id, key)
	local effects = NETWORK.skills.effects[id]

	return effects and effects[key] or 0
end

function PLAYER:GetSkillLevel(id)
	return NETWORK.skills.Get(self, id)
end

function NETWORK.inventory.MaxWeightFor(client)
	local base = NETWORK.inventory.maxWeight or 20

	if (!IsValid(client) or !client:IsPlayer()) then
		return base
	end

	return base + NETWORK.skills.Get(client, "strength") * NETWORK.skills.Effect("strength", "weight")
end

hook.Add("NetworkMovementSpeed", "zzSkillAgility", function(client, walk, run)
	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	local agility = NETWORK.skills.Get(client, "agility")

	walk = walk * (1 + agility * NETWORK.skills.Effect("agility", "walk"))
	run = run * (1 + agility * NETWORK.skills.Effect("agility", "run"))

	if (SERVER and NETWORK.inventory.GetState) then
		local state = NETWORK.inventory.GetState(client)
		local weight = state and NETWORK.inventory.WeightOf(state) or 0
		local limit = NETWORK.inventory.MaxWeightFor(client)

		if (weight > limit) then
			local over = math.Clamp((weight - limit) / math.max(limit, 1), 0, 1)
			local factor = 1 - 0.15 - 0.25 * over

			walk = walk * factor
			run = run * factor
		end
	end

	return walk, run
end)
