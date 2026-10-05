ITEM.name = "Отмычка"
ITEM.description = "Согнутая проволока и натяжитель из полотна ножовки. Наведитесь на запертую дверь, навесной замок или ящик и используйте. Ломается от неосторожности — берите с запасом."
ITEM.model = "models/props_c17/tools_wrench01a.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.05
ITEM.maxStack = 5
ITEM.width = 1
ITEM.height = 1
ITEM.category = "misc"

ITEM.useLabel = "itemLockpick"

function ITEM:GetModel()
	if (NETWORK.lockpick and NETWORK.lockpick.GetModel) then
		return NETWORK.lockpick.GetModel()
	end

	return self.model
end

function ITEM:OnUse(client)
	if (SERVER and NETWORK.lockpick and NETWORK.lockpick.Start) then
		NETWORK.lockpick.Start(client)
	end

	return false
end
