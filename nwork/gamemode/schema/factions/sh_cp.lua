NWORK.Faction.Register( "cp", {
	Name        = "Гражданская Оборона",
	Initials    = "ГО",
	Color       = Color( 92, 204, 236 ),
	Description = "Человеческие силы правопорядка Альянса. Патрулируют улицы, проводят проверки и подавляют беспорядки. Имеют рацию и видят тактический оверлей.",
	Radio       = true,
	Combine     = true,

	Models = {
		male = { "models/player/police.mdl" },
	},
} )
