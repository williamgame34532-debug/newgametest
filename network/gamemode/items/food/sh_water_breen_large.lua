ITEM.name = "Вода Брина, большая"
ITEM.description = "Банка увеличенного объёма. Выдаётся по талону или покупается за токены."
ITEM.model = "models/props_junk/popcan01a.mdl"
ITEM.rarity = "common"
ITEM.weight = 0.6
ITEM.maxStack = 4
ITEM.width = 1
ITEM.height = 1
ITEM.category = "food"

ITEM.thirst = 50
ITEM.useLabel = "itemDrink"
ITEM.useSound = "npc/barnacle/barnacle_gulp2.wav"

function ITEM:OnUse(client, item)
	client:SetHealth(math.Clamp(client:Health() + 8, 1, client:GetMaxHealth()))
end

ITEM.bConsumeOnUse = true

ITEM.trash = "bottle_empty"

ITEM.bNoSpoil = true
