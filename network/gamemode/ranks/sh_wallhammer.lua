NETWORK.classes.Register("wallhammer", {
	name = "classWallhammer",
	faction = "cmb",
	model = "models/player/combine_heavy.mdl",
	health = 350,
	armor = 250,
	bodygroups = {[2] = 1},

	callsign = "C24:Wallhammer-%03d",
	callsignMax = 999,

	weapons = {"tfa_heavyshotgun"},

	speed = {walk = 0.82, run = 0.75},

	foley = {
		"framework/vo/wallhammer/foley/step1.wav",
		"framework/vo/wallhammer/foley/step2.wav",
		"framework/vo/wallhammer/foley/step3.wav",
		"framework/vo/wallhammer/foley/step4.wav"
	}
})
