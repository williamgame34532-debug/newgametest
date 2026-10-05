NETWORK.classes.Register("grunt", {
	name = "classGrunt",
	faction = "cmb",
	model = "models/synapse/combine/combine_grunt.mdl",
	health = 150,
	armor = 100,

	callsign = "C24:Echo-%03d",
	callsignMax = 999,

	weapons = {"tfa_osips"},

	foley = {
		"framework/vo/grunt/foley/step1.wav",
		"framework/vo/grunt/foley/step2.wav",
		"framework/vo/grunt/foley/step3.wav",
		"framework/vo/grunt/foley/step4.wav"
	}
})
