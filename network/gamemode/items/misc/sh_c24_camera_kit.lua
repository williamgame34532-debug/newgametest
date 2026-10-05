ITEM.name = "Камера С24 — монтажный комплект"
ITEM.description = "Монтаж сотрудником ГСР рядом с ГО. Прочность камеры: 20."
ITEM.model = "models/dav0r/camera.mdl"
ITEM.width = 2
ITEM.height = 2
ITEM.weight = 0.8
ITEM.category = "misc"
ITEM.maxStack = 1
ITEM.useLabel = "Установить"
function ITEM:OnUse(client)
 if (SERVER) then NETWORK.deploy.Start(client, "c24_camera") end
 return false
end
