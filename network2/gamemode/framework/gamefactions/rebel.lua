FACTION.name = "Сопротивление"
FACTION.description = "Подполье Сити-17: живут как граждане, работают против Альянса. Тайная частота /rr, " ..
	"граффити, отмычки, вербовка. Для чужих — обычные граждане."
FACTION.color = Color(236, 150, 60)
FACTION.logo = "citizen_logo"
-- the others see a citizen (cl_overhead.lua); only the Resistance knows its own
FACTION.disguise = "citizen"

FACTION.models = {
	male = {
		"models/network/citizens/male01.mdl",
		"models/network/citizens/male02.mdl",
		"models/network/citizens/male03.mdl",
		"models/network/citizens/male04.mdl",
		"models/network/citizens/male05.mdl",
		"models/network/citizens/male06.mdl",
		"models/network/citizens/male07.mdl",
		"models/network/citizens/male08.mdl",
		"models/network/citizens/male09.mdl",
		"models/network/citizens/male10.mdl"
	},
	female = {
		"models/network/citizens/female_01.mdl",
		"models/network/citizens/female_02.mdl",
		"models/network/citizens/female_03.mdl",
		"models/network/citizens/female_04.mdl",
		"models/network/citizens/female_06.mdl",
		"models/network/citizens/female_07.mdl"
	}
}
