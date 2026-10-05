ITEM.name = "Перепрограммированная турель"
ITEM.description = "Напольная турель Альянса с переписанной прошивкой: бьёт по патрулям и солдатам, своих не трогает."
ITEM.model = "models/combine_turrets/floor_turret.mdl"
ITEM.rarity = "unique"
ITEM.weight = 8
ITEM.maxStack = 1
ITEM.width = 2
ITEM.height = 1
ITEM.category = "weapon"

ITEM.useLabel = "itemDeploy"

function ITEM:OnUse(client)
	NETWORK.deploy.Start(client, "hackedturret")

	return false
end
