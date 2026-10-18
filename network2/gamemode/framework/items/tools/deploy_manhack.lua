-- A manhack of the Alliance, folded (sv_npcrelations.lua): used - it flies out in front of the unit.
ITEM.name = "Мэнхек"
ITEM.description = "Сложенный летающий резак Альянса. «Выпустить» — взлетает перед вами и атакует врагов " ..
	"Альянса. Только для юнитов."
ITEM.model = "models/manhack.mdl"
ITEM.icon = "deploy_manhack"
ITEM.useVerb = "выпустить"
ITEM.deploy = "npc_manhack"

function ITEM.OnUse(client)
	return NW.npcRelations.Deploy(client, "npc_manhack")
end
