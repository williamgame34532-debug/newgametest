ITEM.name = "Объявление"
ITEM.description = "Заполненное объявление. Прикрепляется к доске объявлений."
ITEM.model = "models/props_c17/paper01.mdl"
ITEM.rarity = "common"
ITEM.weight = 0.02
ITEM.category = "documents"
ITEM.useLabel = "itemRead"

function ITEM:GetName(item)
	local data = item and item.data

	if (data and data.title and data.title != "") then
		return L("noticeItemName", data.title)
	end
end

function ITEM:GetDescription(item)
	local data = item and item.data or {}

	return string.format("%s\n%s, %s", string.sub(data.text or "", 1, 120),
		data.author or "?", data.date or "")
end

function ITEM:OnUse(client, item)
	NETWORK.board.ViewItem(client, item)

	return false
end
