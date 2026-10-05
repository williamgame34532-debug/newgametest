ITEM.name = "Вода Брина, малая"
ITEM.description = "Малая банка очищенной воды. Стандартная выдача Альянса: жажду сбивает, но не снимает."
ITEM.model = "models/props_junk/popcan01a.mdl"
ITEM.rarity = "common"
ITEM.weight = 0.35
ITEM.maxStack = 5
ITEM.width = 1
ITEM.height = 1
ITEM.category = "food"

ITEM.thirst = 30
ITEM.useLabel = "itemDrink"
ITEM.useSound = "npc/barnacle/barnacle_gulp2.wav"

function ITEM:OnUse(client, item)
	client:SetHealth(math.Clamp(client:Health() + 6, 1, client:GetMaxHealth()))
end

ITEM.bConsumeOnUse = true

ITEM.trash = "bottle_empty"

ITEM.bNoSpoil = true
