ITEM.name = "Турель Альянса"
ITEM.description = "Автоматическая напольная турель. Ставится на ровную поверхность и бьёт по всем, кроме персонала Альянса."
ITEM.model = "models/combine_turrets/floor_turret.mdl"
ITEM.rarity = "unique"
ITEM.weight = 8
ITEM.maxStack = 1

ITEM.width = 2
ITEM.height = 1
ITEM.category = "weapon"

ITEM.useLabel = "itemDeploy"
ITEM.factions = {"cp", "cmb", "combine"}

function ITEM:OnUse(client)
	NETWORK.deploy.Start(client, "turret")

	return false
end
