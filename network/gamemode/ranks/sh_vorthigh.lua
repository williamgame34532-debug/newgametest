NETWORK.classes.Register("vorthigh", {
	name = "classVortHigh",
	faction = "vortigaunt",

	icon = "framework/icons/citizen.png",

	model = "models/vortigaunt.mdl",

	modelScale = 1.15,

	health = 600,
	armor = 120,

	toughness = {

		damage = 0.35,
		bleedSoften = 0.2,
		fracture = 0.08,
		pneumo = false,
		pain = 0.1,
		wound = 0.17,
		knockdown = false,
		armour = 0.1,
		weaponPower = {
			swep_vortigaunt_beam = 9
		}
	},

	weapons = {"swep_vortigaunt_beam"},

	speed = {walk = 1.15, run = 1.2}
})
