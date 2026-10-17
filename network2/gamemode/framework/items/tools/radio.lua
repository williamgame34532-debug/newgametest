ITEM.name = "Рация"
ITEM.description = "Портативная рация с шифрованием Альянса. ПКМ → настроить канал; говорить — зажать клавишу " ..
	"рации (по умолчанию H), настроить — B."
ITEM.model = "models/props_lab/reciever01d.mdl"
ITEM.icon = "radio"
ITEM.useVerb = "настроить"

function ITEM.OnUse(client)
	NW.radio.Open(client)

	return false
end
