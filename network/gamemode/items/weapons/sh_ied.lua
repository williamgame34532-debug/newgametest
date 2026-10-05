ITEM.name = "Самодельная мина"
ITEM.description = "Банка с порохом, гвоздями и датчиком из старого сканера. Прикапывается в землю и рвётся, когда рядом проходит чужой."
ITEM.model = "models/props_junk/metal_paintcan001a.mdl"
ITEM.rarity = "special"
ITEM.weight = 1.5
ITEM.maxStack = 2
ITEM.width = 1
ITEM.height = 1
ITEM.category = "weapon"

ITEM.useLabel = "itemDeploy"

function ITEM:OnUse(client)
	NETWORK.deploy.Start(client, "ied")

	return false
end
