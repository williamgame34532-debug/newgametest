NETWORK.classes.Register("soldier", {
	name = "classSoldier",
	faction = "cmb",

	model = "models/player/combine_soldier.mdl",
	modelConfig = "soldierModel",
	health = 150,
	armor = 100,

	callsign = "C24:Soldier-%03d",
	callsignMax = 999,
	callsignConfig = "soldierCallsign",

	items = {"ar2"},

	foley = {
		"framework/vo/grunt/foley/step1.wav",
		"framework/vo/grunt/foley/step2.wav",
		"framework/vo/grunt/foley/step3.wav",
		"framework/vo/grunt/foley/step4.wav"
	}
})
