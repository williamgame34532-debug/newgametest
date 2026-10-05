ITEM.name = "Аптечка"
ITEM.description = "Полевая аптечка с полным набором: гемостатическая набивка, повязки, шины. Останавливает любое кровотечение, фиксирует переломы и поднимает стабилизированного раненого. Применяется долго."
ITEM.model = "models/items/healthkit.mdl"
ITEM.rarity = "special"
ITEM.weight = 1.4
ITEM.maxStack = 2
ITEM.width = 2
ITEM.height = 1

ITEM.useCooldown = 120

ITEM.category = "medical"

ITEM.useLabel = "itemApply"

function ITEM:OnUse(client)
	NETWORK.medical.Begin(client, client, self.id)

	return false
end
