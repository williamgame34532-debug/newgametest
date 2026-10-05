local FACTION = {}

FACTION.name = "factionDisinfector"
FACTION.description = "factionDisinfectorDescription"
FACTION.icon = "framework/icons/disinfector.png"

FACTION.color = Color(226, 190, 84)
FACTION.bWhitelist = true

FACTION.bCWU = true

FACTION.toughness = {
	damage = 0.88,
	bleedSoften = 0.3,
	fracture = 0.6,
	pain = 0.6,
	wound = 0.85,
	armour = 0.15
}

FACTION.bHazmat = true

FACTION.coldResist = 0.35

FACTION.models = {
	"models/hlvr/characters/hazmat_worker/npc/hazmat_worker_citizen.mdl"
}

function FACTION:GetDefaultName(client, character)
	local taken = {}

	for _, other in ipairs(player.GetAll()) do
		local otherCharacter = other:GetCharacter()

		if (otherCharacter and otherCharacter != character) then
			taken[otherCharacter:GetName()] = true
		end
	end

	for _ = 1, 40 do
		local name = string.format("C24:ICU-%03d", math.random(0, 999))

		if (!taken[name]) then
			return name
		end
	end

	return string.format("C24:ICU-%04d", math.random(0, 9999))
end

NETWORK.factions.Register("disinfector", FACTION)

FACTION.alwaysWeapons = {"weapon_applicator"}
