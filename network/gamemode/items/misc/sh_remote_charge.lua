ITEM.name = "Радиозаряд сопротивления"
ITEM.description = "Игровой заряд с дистанционным запуском через привязанный к персонажу детонатор."
ITEM.model = "models/props_lab/reciever01b.mdl"
ITEM.width = 2
ITEM.height = 1
ITEM.weight = 0.8
ITEM.category = "misc"
ITEM.maxStack = 1
ITEM.useLabel = "Установить"
function ITEM:OnUse(client)
 if (SERVER) then NETWORK.deploy.Start(client, "remote_charge") end
 return false
end
