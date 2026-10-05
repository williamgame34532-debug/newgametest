ITEM.name = "Обломок сканера"
ITEM.description = "Корпус сбитого сканера с уцелевшим блоком оптики. Разбираться в нём без инструмента бесполезно."
ITEM.model = "models/combine_scanner.mdl"
ITEM.rarity = "special"
ITEM.weight = 5
ITEM.maxStack = 1
ITEM.width = 2
ITEM.height = 2
ITEM.category = "junk"

ITEM.useLabel = "itemRepair"

ITEM.factions = {"cp", "cmb", "combine"}

function ITEM:OnUse(client)
	NETWORK.scanner.BeginRepair(client)

	return false
end
