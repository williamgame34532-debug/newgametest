ITEM.name = "КПК Альянса"
ITEM.description = "Личное дело, база CID, очки лояльности, заметки и журнал ГСР."
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
