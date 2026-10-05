ITEM.name = "Навесной замок"
ITEM.description = "Самодельный стальной замок с дужкой. Наведитесь на закрытую дверь и используйте — замок встанет у ручки и запрёт её, а вы получите ключ. Замок можно сломать или вскрыть отмычкой."
ITEM.model = "models/props_c17/padlock001a.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.6
ITEM.width = 1
ITEM.height = 1
ITEM.category = "misc"

ITEM.useLabel = "itemPadlock"

function ITEM:GetDescription(item)
	local code = item and istable(item.data) and item.data.code

	if (code and NETWORK.padlock and NETWORK.padlock.Serial) then
		return self.description .. "\n" .. L("padlockItemSerial", NETWORK.padlock.Serial(code))
	end

	return self.description
end

function ITEM:OnUse(client, item)
	if (SERVER and NETWORK.padlock and NETWORK.padlock.BeginPlace) then
		NETWORK.padlock.BeginPlace(client, item)
	end

	return false
end
