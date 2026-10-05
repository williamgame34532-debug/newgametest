ITEM.name = "Шина"
ITEM.description = "Дощечки и бинт. Фиксирует сломанную конечность: со сломанной ногой не побежишь, со сломанной рукой не прицелишься. Очень больно, если заранее не принять обезболивающее."
ITEM.model = "models/props_c17/tools_wrench01a.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.5
ITEM.maxStack = 5
ITEM.width = 1
ITEM.height = 1
ITEM.category = "medical"

ITEM.useLabel = "itemApply"

function ITEM:OnUse(client)
	NETWORK.medical.Begin(client, client, self.id)

	return false
end
