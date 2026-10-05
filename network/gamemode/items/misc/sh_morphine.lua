ITEM.name = "Морфин"
ITEM.description = "Автоинъектор с морфином. Надолго снимает боль, а раненому «при смерти» даёт лишние полминуты. Вторая доза подряд угнетает дыхание — не колоть дважды."
ITEM.model = "models/hla_prop/health_syringe.mdl"
ITEM.rarity = "special"
ITEM.weight = 0.1
ITEM.maxStack = 3
ITEM.width = 1
ITEM.height = 1
ITEM.category = "medical"

ITEM.useLabel = "itemInject"

function ITEM:OnUse(client)
	NETWORK.medical.Begin(client, client, self.id)

	return false
end
