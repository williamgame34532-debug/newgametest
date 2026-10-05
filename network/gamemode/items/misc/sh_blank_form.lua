ITEM.name = "Чистый бланк"
ITEM.description = "Незаполненный казённый бланк с водяными знаками Альянса. Заполнить его может кто угодно — но в реестре такой бумаги не будет."
ITEM.model = "models/props_c17/paper01.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.02
ITEM.maxStack = 5
ITEM.category = "documents"
ITEM.useLabel = "itemFill"

function ITEM:OnUse(client, item)
	NETWORK.documents.OpenForge(client, item)

	return false
end
