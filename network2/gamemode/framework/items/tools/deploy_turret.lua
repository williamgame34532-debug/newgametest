-- A floor turret of the Alliance (sv_npcrelations.lua): put where the unit looks; Alt + E on it by the one
-- who put it - folded back into the inventory.
ITEM.name = "Турель Альянса"
ITEM.description = "Напольная автоматическая турель. Посмотрите на пол рядом и используйте. Alt + E по своей " ..
	"турели — сложить обратно. Только для юнитов."
ITEM.model = "models/combine_turrets/floor_turret.mdl"
ITEM.icon = "deploy_turret"
ITEM.useVerb = "установить"

function ITEM.OnUse(client)
	return NW.npcRelations.Deploy(client, "npc_turret_floor")
end
