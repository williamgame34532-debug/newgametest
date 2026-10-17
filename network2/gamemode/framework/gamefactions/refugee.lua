FACTION.name = "Беженец"
FACTION.description = "Пришли в Сити-17 из-за стен: без регистрации, без CID-карты, без рациона и жилья. " ..
	"Регистрация — через гражданский терминал и проверку Гражданской Обороны."
FACTION.color = Color(176, 150, 118)
FACTION.logo = "citizen_logo"
-- no card, no rations: the registration at the civic terminal (sh_rebels.lua)
FACTION.refugee = true

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
