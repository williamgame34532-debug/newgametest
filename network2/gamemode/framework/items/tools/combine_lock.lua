-- A combine lock (the fabricator, sh_fabricator.lua): put on the door looked at.
ITEM.name = "Замок Альянса"
ITEM.description = "Механический замок: дверь открывается только юнитами Альянса. Посмотрите на дверь без " ..
	"замка и используйте."
ITEM.model = "models/props_combine/combine_lock01.mdl"
ITEM.icon = "combine_lock"
ITEM.useVerb = "установить на дверь"

function ITEM.OnUse(client)
	return NW.fabricator.PlaceLock(client)
end
