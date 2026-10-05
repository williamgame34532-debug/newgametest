ITEM.name = "Турникет"
ITEM.description = "Кровоостанавливающий жгут. Единственное, что держит артериальное кровотечение на руке или ноге. Затягивается выше раны; конечность под ним больше не кровит."
ITEM.model = "models/props_junk/cardboard_box001a.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.4
ITEM.maxStack = 4
ITEM.width = 1
ITEM.height = 1
ITEM.category = "medical"

ITEM.useLabel = "itemApply"

function ITEM:OnUse(client)
	NETWORK.medical.Begin(client, client, self.id)

	return false
end
