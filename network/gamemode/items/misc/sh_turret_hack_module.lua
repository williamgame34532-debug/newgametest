ITEM.name = "Модуль взлома турели"
ITEM.description = "Плата с перемычками и чужим ключом доступа. Подключается к турели Альянса и переписывает ей список целей. Взлом занимает несколько секунд — под огнём самой турели."
ITEM.model = "models/props_lab/reciever01a.mdl"
ITEM.rarity = "unique"
ITEM.weight = 0.6
ITEM.maxStack = 1
ITEM.width = 1
ITEM.height = 1
ITEM.category = "misc"

ITEM.useLabel = "itemTurretHack"

function ITEM:OnUse(client)
	if (CLIENT) then
		return false
	end

	NETWORK.trap.StartHack(client)

	return false
end
