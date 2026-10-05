ITEM.name = "Пакет крови"
ITEM.description = "Полтора литра консервированной крови с системой для переливания. Восполняет кровопотерю в течение минуты. Бесполезен, пока кровотечение не остановлено."
ITEM.model = "models/props_junk/garbage_plasticbottle003a.mdl"
ITEM.rarity = "special"
ITEM.weight = 1.6
ITEM.maxStack = 2
ITEM.width = 1
ITEM.height = 2
ITEM.category = "medical"

ITEM.useLabel = "itemApply"

function ITEM:OnUse(client)
	NETWORK.medical.Begin(client, client, self.id)

	return false
end
