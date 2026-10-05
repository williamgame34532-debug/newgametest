ITEM.name = "Обезболивающее"
ITEM.description = "Пачка таблеток без маркировки. Снимает боль на пару минут: можно бежать и пережить наложение шины молча. Человеку без сознания таблетку не дать."
ITEM.model = "models/props_lab/box01a.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.2
ITEM.maxStack = 6
ITEM.width = 1
ITEM.height = 1
ITEM.category = "medical"

ITEM.useLabel = "itemTake"

function ITEM:OnUse(client)
	NETWORK.medical.Begin(client, client, self.id)

	return false
end
