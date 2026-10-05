ITEM.name = "Запасная линза визора"
ITEM.description = "Сменное стекло с блоком подсветки. Ставится прямо в маску, инструмент не нужен."
ITEM.model = "models/props_lab/reciever01d.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.6
ITEM.maxStack = 2
ITEM.width = 1
ITEM.height = 1
ITEM.category = "misc"

ITEM.useLabel = "itemVisorFix"
ITEM.bConsumeOnUse = true
ITEM.factions = {"cp", "cmb", "combine"}

function ITEM:OnUse(client)
	return NETWORK.visor.Repair(client)
end
