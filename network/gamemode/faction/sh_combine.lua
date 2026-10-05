local FACTION = {}

FACTION.name = "factionCombine"
FACTION.description = "factionCombineDescription"

FACTION.color = Color(206, 74, 68)
FACTION.bDefault = false
FACTION.bWhitelist = true

FACTION.radios = {"radiota", "radiotac"}
FACTION.bCombine = true

FACTION.bOverwatch = true

FACTION.toughness = {
	damage = 0.65,
	bleed = false,
	fracture = 0,
	pneumo = false,
	pain = 0,
	wound = 0.5,
	knockdown = false,
	limp = false,
	helmet = 0.5
}

FACTION.models = {
	"models/wn7new/metropolice/male_07.mdl",
	"models/wn7new/metropolice/male_08.mdl",
	"models/wn7new/metropolice/male_09.mdl"
}

function FACTION:OnCharacterCreated(client, character)
	character:SetSkill("strength", 3)
end

NETWORK.factions.Register("combine", FACTION)
