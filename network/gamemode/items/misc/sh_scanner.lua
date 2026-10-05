ITEM.name = "Сканер Альянса"
ITEM.description = "Восстановленный сканер. После запуска держится в воздухе сам и не трогает персонал Альянса."
ITEM.model = "models/combine_scanner.mdl"
ITEM.rarity = "unique"
ITEM.weight = 4
ITEM.maxStack = 1
ITEM.width = 2
ITEM.height = 2
ITEM.category = "misc"

ITEM.useLabel = "itemDeploy"
ITEM.factions = {"cp", "cmb", "combine"}

function ITEM:OnUse(client)
	NETWORK.deploy.Start(client, "scanner")

	return false
end
