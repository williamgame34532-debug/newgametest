ITEM.name = "Бланк объявления"
ITEM.description = "Лист для доски объявлений. Заполняется один раз; снять с доски его уже нельзя."
ITEM.model = "models/props_c17/paper01.mdl"
ITEM.rarity = "common"
ITEM.weight = 0.02
ITEM.maxStack = 10
ITEM.category = "documents"
ITEM.useLabel = "itemFill"

function ITEM:OnUse(client, item)
	NETWORK.board.OpenForm(client, item)

	return false
end
