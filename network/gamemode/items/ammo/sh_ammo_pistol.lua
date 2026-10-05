ITEM.name = "Патроны 9x19"
ITEM.description = "Коробка пистолетных патронов. Подходит к штатному пистолету."
ITEM.model = "models/hla_prop/ammo_clip.mdl"
ITEM.rarity = "common"
ITEM.weight = 0.5
ITEM.maxStack = 3
ITEM.width = 1
ITEM.height = 1
ITEM.category = "ammo"

ITEM.useLabel = "itemLoad"
ITEM.bConsumeOnUse = true

ITEM.ammoType = "Pistol"
ITEM.ammoAmount = 30

function ITEM:OnUse(client)
	return NETWORK.item.LoadAmmo(client, self)
end
