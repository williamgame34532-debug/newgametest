ITEM.name = "Бинт"
ITEM.description = "Стерильный бинт в помятой упаковке. Давящая повязка останавливает венозное кровотечение и кровь из корпуса. Артериальное кровотечение бинт не удержит — нужен жгут."
ITEM.model = "models/props_junk/garbage_takeoutcarton001a.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.2
ITEM.maxStack = 10
ITEM.category = "medical"

ITEM.useLabel = "itemApply"

function ITEM:OnUse(client)
	NETWORK.medical.Begin(client, client, self.id)

	return false
end
