ITEM.name = "Патроны 12 калибра"
ITEM.description = "Картонные гильзы с картечью. Годятся для дробовика."
ITEM.model = "models/items/boxbuckshot.mdl"
ITEM.rarity = "common"
ITEM.weight = 0.6
ITEM.maxStack = 3
ITEM.width = 1
ITEM.height = 1
ITEM.category = "ammo"

ITEM.useLabel = "itemLoad"
ITEM.bConsumeOnUse = true

ITEM.ammoType = "Buckshot"
ITEM.ammoAmount = 16

function ITEM:OnUse(client)
	return NETWORK.item.LoadAmmo(client, self)
end
