ITEM.name = "Мешки с песком"
ITEM.description = "Связка плотных мешков, набитых песком и щебнем. Используйте, чтобы сложить укрытие на полу: R — повернуть, ЛКМ — поставить, ПКМ — отмена. Держит пули лучше всего остального."
ITEM.model = "models/props_junk/garbage_bag001a.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 6
ITEM.width = 2
ITEM.height = 2
ITEM.category = "misc"

ITEM.useLabel = "itemBarricade"

function ITEM:OnUse(client)
	if (SERVER and NETWORK.barricade and NETWORK.barricade.Start) then
		NETWORK.barricade.Start(client, "sandbags")
	end

	return false
end
