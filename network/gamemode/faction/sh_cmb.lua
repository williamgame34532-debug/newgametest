local FACTION = {}

FACTION.name = "factionCMB"
FACTION.description = "factionCMBDescription"
FACTION.icon = "framework/icons/cmb.png"
FACTION.unknownName = "unknownCMB"

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
	"models/combine_soldier.mdl",
	"models/combine_soldier_prisonguard.mdl",
	"models/combine_super_soldier.mdl"
}

NETWORK.factions.Register("cmb", FACTION)
