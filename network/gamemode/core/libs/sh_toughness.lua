NETWORK.toughness = NETWORK.toughness or {}

local TOUGH = NETWORK.toughness

TOUGH.defaults = {
	damage = 1,
	bleed = true,
	bleedSoften = 0,
	fracture = 1,
	pneumo = true,
	pain = 1,
	wound = 1,
	knockdown = true,
	limp = true,
	helmet = 0,
	armour = 0,
	weaponPower = false
}

TOUGH.softer = {
	artery = "major",
	major = "minor",
	minor = false
}

NETWORK.config.Register("medFactionToughness", {
	name = "cfgMedToughness",
	description = "cfgMedToughnessDesc",
	category = "medical",
	type = "bool",
	default = true
})

function TOUGH.IsEnabled()
	return NETWORK.config.Get("medFactionToughness") != false
end

function TOUGH.GetProfile(client)
	if (!TOUGH.IsEnabled() or !IsValid(client) or !client:IsPlayer() or
		!client:HasCharacter()) then
		return TOUGH.defaults
	end

	local faction = NETWORK.factions.Get(client:GetCharacterFaction())
	local class = NETWORK.classes and
		NETWORK.classes.Get(client:GetNWString("nwClass", ""))

	local factionProfile = faction and faction.toughness
	local classProfile = class and class.toughness

	if (!factionProfile and !classProfile) then
		return TOUGH.defaults
	end

	local profile = {}

	for key, value in pairs(TOUGH.defaults) do
		profile[key] = value
	end

	for _, source in ipairs({factionProfile or {}, classProfile or {}}) do
		for key, value in pairs(source) do
			profile[key] = value
		end
	end

	return profile
end

function TOUGH.Get(client, key)
	local value = TOUGH.GetProfile(client)[key]

	if (value == nil) then
		return TOUGH.defaults[key]
	end

	return value
end

function TOUGH.CanBleed(client)
	return TOUGH.Get(client, "bleed") != false
end

function TOUGH.CanPneumo(client)
	return TOUGH.Get(client, "pneumo") != false
end

function TOUGH.CanKnockdown(client)
	return TOUGH.Get(client, "knockdown") != false
end

function TOUGH.CanLimp(client)
	return TOUGH.Get(client, "limp") != false
end

function TOUGH.AdjustBleed(client, kind)
	if (!TOUGH.CanBleed(client)) then
		return false
	end

	local soften = TOUGH.Get(client, "bleedSoften") or 0

	if (soften > 0 and math.random() < soften) then
		return TOUGH.softer[kind] or false
	end

	return kind
end

local function CollectScales(name, entity, info)
	local scale = 1

	for _, callback in pairs(hook.GetTable()[name] or {}) do
		local bOk, result = pcall(callback, entity, info)

		if (bOk and isnumber(result)) then
			scale = scale * result
		end
	end

	return scale
end

function TOUGH.GetTakenScale(target, info)
	local scale = TOUGH.Get(target, "damage") or 1

	return scale * CollectScales("NetworkDamageTakenScale", target, info)
end

function TOUGH.GetDealtScale(attacker, info)
	if (!IsValid(attacker) or !attacker:IsPlayer() or !attacker:HasCharacter()) then
		return 1
	end

	local scale = 1
	local power = TOUGH.Get(attacker, "weaponPower")
	local weapon = attacker:GetActiveWeapon()

	if (istable(power) and IsValid(weapon)) then
		scale = scale * (power[weapon:GetClass()] or 1)
	end

	return scale * CollectScales("NetworkDamageDealtScale", attacker, info)
end

function TOUGH.RollFracture(client)
	local scale = TOUGH.Get(client, "fracture") or 1

	if (scale >= 1) then
		return true
	end

	return scale > 0 and math.random() < scale
end

function TOUGH.GetInnateProtection(client, slot)
	if (slot == "helmet") then
		return TOUGH.Get(client, "helmet") or 0
	elseif (slot == "armour") then
		return TOUGH.Get(client, "armour") or 0
	end

	return 0
end
