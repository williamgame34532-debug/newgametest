NETWORK.classes.Register("soldier_elite", {

	bCommand = true,

	name = "classElite",
	faction = "cmb",
	model = "models/player/combine_super_soldier.mdl",
	modelConfig = "eliteModel",
	health = 180,
	armor = 150,

	callsign = "C24:Elite-%03d",
	callsignMax = 999,
	callsignConfig = "eliteCallsign",

	items = {"ar2"},

	foley = {
		"framework/vo/grunt/foley/step1.wav",
		"framework/vo/grunt/foley/step2.wav",
		"framework/vo/grunt/foley/step3.wav",
		"framework/vo/grunt/foley/step4.wav"
	}
})
