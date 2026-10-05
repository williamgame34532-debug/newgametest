ITEM.name = "Патроны 4.6x30"
ITEM.description = "Пачка патронов для пистолета-пулемёта."
ITEM.model = "models/items/boxmrounds.mdl"
ITEM.rarity = "common"
ITEM.weight = 0.7
ITEM.maxStack = 3
ITEM.width = 1
ITEM.height = 1
ITEM.category = "ammo"

ITEM.useLabel = "itemLoad"
ITEM.bConsumeOnUse = true

ITEM.ammoType = "SMG1"
ITEM.ammoAmount = 45

function ITEM:OnUse(client)
	return NETWORK.item.LoadAmmo(client, self)
end
