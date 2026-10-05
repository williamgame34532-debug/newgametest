ITEM.name = "Мэнхэк"
ITEM.description = "Сложенный дрон Альянса. Разворачивается по команде оператора."
ITEM.model = "models/manhack.mdl"
ITEM.rarity = "special"
ITEM.weight = 3.5

ITEM.width = 1
ITEM.height = 1
ITEM.category = "weapon"

ITEM.useLabel = "itemDeploy"

ITEM.factions = {"cp", "cmb"}

ITEM.deployTime = 4

function ITEM:OnUse(client, item)
	NETWORK.manhack.Deploy(client, item)
end
