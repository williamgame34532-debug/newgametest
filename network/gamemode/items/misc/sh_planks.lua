ITEM.name = "Доски"
ITEM.description = "Несколько досок и горсть гвоздей. Наведитесь на дверь — доска прибьётся поперёк створки, и дверь не откроется, пока доски целы (до трёх на дверь). Наведитесь на стену или окно — доска прибьётся к ней. R — наклон, ЛКМ — прибить, ПКМ — отмена."
ITEM.model = "models/props_debris/wood_board04a.mdl"
ITEM.rarity = "common"
ITEM.weight = 2.5
ITEM.maxStack = 3
ITEM.width = 1
ITEM.height = 2
ITEM.category = "misc"

ITEM.useLabel = "itemBoardUp"

function ITEM:OnUse(client)
	if (SERVER and NETWORK.barricade and NETWORK.barricade.Start) then
		NETWORK.barricade.Start(client, "planks")
	end

	return false
end
