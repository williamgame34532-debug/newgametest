NETWORK.classes.Register("suppressor", {
	name = "classSuppressor",
	faction = "cmb",

	model = "models/synapse/combine/combine_supressor.mdl",
	health = 300,
	armor = 200,

	callsign = "C24:APF-%03d",
	callsignMax = 999,

	speed = {walk = 0.88, run = 0.8},

	weapons = {"tfa_suppressor"},

	foley = {
		"framework/vo/wallhammer/foley/step1.wav",
		"framework/vo/wallhammer/foley/step2.wav",
		"framework/vo/wallhammer/foley/step3.wav",
		"framework/vo/wallhammer/foley/step4.wav"
	}
})
