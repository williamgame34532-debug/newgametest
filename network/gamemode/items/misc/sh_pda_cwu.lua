ITEM.name = "КПК ГСР"
ITEM.description = "Личный профиль, камеры С24, рабочие журналы и снабжение."
ITEM.model = "models/network/c24_pda.mdl"
ITEM.width = 2
ITEM.height = 2
ITEM.weight = 0.8
ITEM.category = "misc"
ITEM.maxStack = 1
ITEM.useLabel = "Открыть КПК"
function ITEM:OnUse(client)
 if (SERVER) then NETWORK.city.OpenPDA(client) end
 return false
end
