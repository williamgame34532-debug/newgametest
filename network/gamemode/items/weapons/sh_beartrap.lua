ITEM.name = "Капкан"
ITEM.description = "Стальные челюсти на пружине. Кто наступит — останется на месте, пока его не освободят или он сам не вырвется. Капкану всё равно, на чьей вы стороне."
ITEM.model = "models/props_junk/sawblade001a.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 2
ITEM.maxStack = 1
ITEM.width = 2
ITEM.height = 1
ITEM.category = "weapon"

ITEM.useLabel = "itemDeploy"

function ITEM:OnUse(client)
	NETWORK.deploy.Start(client, "beartrap")

	return false
end
