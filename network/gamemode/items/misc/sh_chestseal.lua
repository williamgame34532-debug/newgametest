ITEM.name = "Окклюзионная повязка"
ITEM.description = "Клапанная наклейка на грудь. Закрывает сквозную рану грудной клетки при пневмотораксе: человек снова может дышать. Без неё раненый в грудь задыхается за несколько минут."
ITEM.model = "models/props_lab/box01b.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.15
ITEM.maxStack = 6
ITEM.width = 1
ITEM.height = 1
ITEM.category = "medical"

ITEM.useLabel = "itemApply"

function ITEM:OnUse(client)
	NETWORK.medical.Begin(client, client, self.id)

	return false
end
