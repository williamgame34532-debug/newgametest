-- A breaching charge (the fabricator, sh_fabricator.lua): on a door close by, three seconds, the door
-- is blown open away from the one who set it.
ITEM.name = "Пробивной заряд"
ITEM.description = "Устройство Альянса, которое силой открывает закрытую или запертую дверь. Посмотрите на " ..
	"дверь и используйте: три секунды — отойдите."
ITEM.model = "models/weapons/w_slam.mdl"
ITEM.icon = "breach_charge"
ITEM.useVerb = "установить на дверь"

function ITEM.OnUse(client)
	return NW.fabricator.Breach(client)
end
