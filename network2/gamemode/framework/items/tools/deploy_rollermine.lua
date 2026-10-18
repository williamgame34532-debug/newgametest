-- A rollermine (sv_npcrelations.lua): used - it rolls out in front of the unit.
ITEM.name = "Роллермина"
ITEM.description = "Шар Альянса, который катится к врагу и бьёт током. «Выпустить» — на землю перед вами. " ..
	"Только для юнитов."
ITEM.model = "models/roller.mdl"
ITEM.icon = "deploy_rollermine"
ITEM.useVerb = "выпустить"

function ITEM.OnUse(client)
	return NW.npcRelations.Deploy(client, "npc_rollermine")
end
