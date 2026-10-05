NETWORK.classes.Register("ordinal", {

	bCommand = true,

	name = "classOrdinal",
	faction = "cmb",

	model = "models/synapse/hl_a/combine_commander/npc/combine_commander.mdl",
	health = 220,
	armor = 150,

	callsign = "C24:Ordinal-%03d",
	callsignMax = 999,

	speed = {walk = 0.96, run = 0.9},

	weapons = {"tfa_ocipr"},

	foley = {
		"framework/vo/grunt/foley/step1.wav",
		"framework/vo/grunt/foley/step2.wav",
		"framework/vo/grunt/foley/step3.wav",
		"framework/vo/grunt/foley/step4.wav"
	}
})
