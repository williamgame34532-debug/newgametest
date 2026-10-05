ITEM.name = "Вода Брина, усиленная"
ITEM.description = "Тот же состав с двойной дозой добавок. Дороже всех и держит дольше всех, но и она не напоит досыта."
ITEM.model = "models/props_junk/garbage_metalcan002a.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.9
ITEM.maxStack = 3
ITEM.width = 1
ITEM.height = 1
ITEM.category = "food"

ITEM.thirst = 70
ITEM.useLabel = "itemDrink"
ITEM.useSound = "npc/barnacle/barnacle_gulp2.wav"

function ITEM:OnUse(client, item)
	client:SetHealth(math.Clamp(client:Health() + 12, 1, client:GetMaxHealth()))
end

ITEM.bConsumeOnUse = true

ITEM.trash = "bottle_empty"

ITEM.bNoSpoil = true
