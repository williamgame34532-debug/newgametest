ITEM.name = "Документ"
ITEM.description = "Казённая бумага с печатью."
ITEM.model = "models/props_c17/paper01.mdl"
ITEM.rarity = "common"
ITEM.weight = 0.02
ITEM.category = "documents"
ITEM.useLabel = "itemRead"

function ITEM:GetName(item)
	local docType = item and item.data and NETWORK.documents.GetType(item.data.type)

	if (docType) then
		return L(docType.name)
	end
end

function ITEM:GetDescription(item)
	local data = item.data or {}

	return string.format("Выдан: %s (#%s)\nСерия: %s\nВыдал: %s, %s",
		data.holder or "?", data.cid or "—", data.serial or "—",
		data.issuer or "—", data.issued or "—")
end

function ITEM:OnUse(client, item)
	NETWORK.documents.View(client, item)

	return false
end
