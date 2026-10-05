ITEM.name = "Мина Альянса"
ITEM.description = "Осколочная мина с распознаванием свой-чужой. Персонал Альянса она пропускает."
ITEM.model = "models/props_combine/combine_mine01.mdl"
ITEM.rarity = "special"
ITEM.weight = 2.5
ITEM.maxStack = 2
ITEM.width = 1
ITEM.height = 1
ITEM.category = "weapon"

ITEM.useLabel = "itemDeploy"
ITEM.factions = {"cp", "cmb", "combine"}

function ITEM:OnUse(client)
	NETWORK.deploy.Start(client, "mine")

	return false
end
