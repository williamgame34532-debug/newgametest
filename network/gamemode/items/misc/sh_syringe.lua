ITEM.name = "Медицинский шприц"
ITEM.description = "Одноразовый инъектор Альянса со стимулятором. Поднимает на ноги раненого «при смерти», если кровотечение у него уже остановлено, и немного восполняет кровь."
ITEM.model = "models/hla_prop/health_syringe.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.25
ITEM.maxStack = 3
ITEM.width = 1
ITEM.height = 1
ITEM.category = "medical"

ITEM.useLabel = "itemInject"

function ITEM:OnUse(client)
	NETWORK.medical.Begin(client, client, self.id)

	return false
end
