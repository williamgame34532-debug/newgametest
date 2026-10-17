-- A trading stand, folded (sh_business.lua): use it looking at the floor inside your rented premises.
ITEM.name = "Торговая стойка"
ITEM.description = "Складной прилавок с кассой. Ставится в своём арендованном помещении: посмотрите на пол и " ..
	"используйте. Нужна лицензия на торговлю."
ITEM.model = "models/props_junk/cardboard_box001a.mdl"
ITEM.icon = "goods"
ITEM.useVerb = "поставить"

function ITEM.OnUse(client)
	return NW.business.PlaceStand(client)
end
