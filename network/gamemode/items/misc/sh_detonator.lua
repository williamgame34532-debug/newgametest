ITEM.name = "Детонатор сопротивления"
ITEM.description = "Запускает установленные этим персонажем заряды в радиусе 2000 игровых единиц."
ITEM.model = "models/props_lab/reciever01a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.weight = 0.8
ITEM.category = "misc"
ITEM.maxStack = 1
ITEM.useLabel = "Подорвать свои заряды"
function ITEM:OnUse(client)
 if (SERVER) then NETWORK.city.Detonate(client) end
 return false
end
