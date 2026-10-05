ITEM.name = "Рация"
ITEM.description = "Портативная гражданская рация. «Использовать» — выставить радиочастоту и включить радиопередачу голоса. Писать в эфир: /r текст."
ITEM.model = "models/radio/w_radio.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.6
ITEM.width = 1
ITEM.height = 1
ITEM.category = "misc"

ITEM.equipSlot = "radio"
ITEM.useLabel = "radioItemUse"

if ((file.Size(ITEM.model, "GAME") or 0) == 0) then
	ITEM.model = "models/props_lab/citizenradio.mdl"
end

function ITEM:OnUse(client, item)
	if (SERVER and NETWORK.radio and NETWORK.radio.OpenMenu) then
		NETWORK.radio.OpenMenu(client)
	end

	return false
end
