-- A can of paint (sh_rebels.lua): the Lambda on a wall close by. Three uses. Contraband.
ITEM.name = "Баллончик с краской"
ITEM.description = "Оранжевая краска, хватит на три рисунка. Посмотрите на стену и используйте: символ " ..
	"Сопротивления. Гражданская Оборона узнает об этом довольно скоро."
ITEM.model = "models/props_junk/garbage_metalcan001a.mdl"
ITEM.icon = "disinfectant"
ITEM.useVerb = "нарисовать лямбду"
ITEM.contraband = true
ITEM.price = 25

function ITEM.OnUse(client, cell)
	NW.rebels.Graffiti(client, cell)

	return false
end
