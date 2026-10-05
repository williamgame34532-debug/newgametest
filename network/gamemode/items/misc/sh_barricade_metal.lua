ITEM.name = "Металлический заслон"
ITEM.description = "Сваренная из сетки и листового железа секция заграждения. Используйте, чтобы перекрыть проход: R — повернуть, ЛКМ — поставить, ПКМ — отмена. Самая прочная из баррикад."
ITEM.model = "models/props_debris/metal_panel01a.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 8
ITEM.width = 2
ITEM.height = 2
ITEM.category = "misc"

ITEM.useLabel = "itemBarricade"

function ITEM:OnUse(client)
	if (SERVER and NETWORK.barricade and NETWORK.barricade.Start) then
		NETWORK.barricade.Start(client, "metal")
	end

	return false
end
