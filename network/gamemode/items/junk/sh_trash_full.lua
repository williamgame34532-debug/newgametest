ITEM.name = "Пакет с мусором"
ITEM.description = "Полный пакет мусора из бака. Сдаётся на пункте утилизации за жетоны."
ITEM.model = "models/props_junk/garbage_bag001a.mdl"
ITEM.rarity = "common"
ITEM.weight = 1.5
ITEM.width = 2
ITEM.height = 2
ITEM.category = "junk"

ITEM.useLabel = "Распаковать"
function ITEM:OnUse(client, item)
 if (SERVER) then NETWORK.city.UnpackTrash(client) end
 return false
end
