ITEM.name = "Тёмная энергия"
ITEM.description = "Импульсный картридж Альянса. Гражданскому оружию не подходит."
ITEM.model = "models/items/combine_rifle_cartridge01.mdl"
ITEM.rarity = "common"
ITEM.weight = 0.8
ITEM.maxStack = 3
ITEM.width = 1
ITEM.height = 1
ITEM.category = "ammo"

ITEM.useLabel = "itemLoad"
ITEM.bConsumeOnUse = true

ITEM.ammoType = "AR2"
ITEM.ammoAmount = 30

function ITEM:OnUse(client)
	return NETWORK.item.LoadAmmo(client, self)
end
