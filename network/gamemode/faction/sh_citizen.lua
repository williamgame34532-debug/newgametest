local FACTION = {}

FACTION.name = "factionCitizen"
FACTION.description = "factionCitizenDescription"
FACTION.icon = "framework/icons/citizen.png"

FACTION.color = Color(108, 190, 116)
FACTION.bDefault = true
FACTION.bWhitelist = false

FACTION.models = {
	"models/willardnetworks/citizens/female_01.mdl",
	"models/willardnetworks/citizens/female_02.mdl",
	"models/willardnetworks/citizens/female_03.mdl",
	"models/willardnetworks/citizens/female_04.mdl",
	"models/willardnetworks/citizens/female_06.mdl",
	"models/willardnetworks/citizens/male01.mdl",
	"models/willardnetworks/citizens/male02.mdl",
	"models/willardnetworks/citizens/male03.mdl",
	"models/willardnetworks/citizens/male04.mdl",
	"models/willardnetworks/citizens/male05.mdl",
	"models/willardnetworks/citizens/male06.mdl",
	"models/willardnetworks/citizens/male07.mdl",
	"models/willardnetworks/citizens/male08.mdl"
}

NETWORK.factions.Register("citizen", FACTION)
