ITEM.name = "Пустой рацион"
ITEM.description = "Вскрытая упаковка пайка. Мусор — но в неё можно сложить еду обратно."
ITEM.model = "models/props_junk/cardboard_box004a.mdl"
ITEM.rarity = "common"
ITEM.weight = 0.1
ITEM.maxStack = 5

ITEM.width = 2
ITEM.height = 1
ITEM.category = "junk"

function ITEM:GetName(item)
	local origin = item and item.data and item.data.origin
	local base = origin and NETWORK.item.Get(origin)

	if (!base) then
		return self.name
	end

	return self.name .. " (" .. base.name .. ")"
end

function ITEM:GetModel(item)
	local origin = item and item.data and item.data.origin
	local base = origin and NETWORK.item.Get(origin)

	return base and base.model or self.model
end
