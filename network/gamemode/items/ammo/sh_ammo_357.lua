ITEM.name = "Патроны .357"
ITEM.description = "Тяжёлые револьверные патроны в картонной пачке."
ITEM.model = "models/items/357ammobox.mdl"
ITEM.rarity = "common"
ITEM.weight = 0.5
ITEM.maxStack = 3
ITEM.width = 1
ITEM.height = 1
ITEM.category = "ammo"

ITEM.useLabel = "itemLoad"
ITEM.bConsumeOnUse = true

ITEM.ammoType = "357"
ITEM.ammoAmount = 12

function ITEM:OnUse(client)
	return NETWORK.item.LoadAmmo(client, self)
end
