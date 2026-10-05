ITEM.name = "Ключ от навесного замка"
ITEM.description = "Маленький ключ на проволочном кольце. Подходит к одному замку: E по замку (или по двери с ним) — отпереть или запереть; присесть и E по отпертому замку — снять его."
ITEM.model = "models/props_c17/TrapPropeller_Lever.mdl"
ITEM.rarity = "common"
ITEM.weight = 0.05
ITEM.width = 1
ITEM.height = 1
ITEM.category = "misc"

function ITEM:GetName(item)
	local data = item and istable(item.data) and item.data

	if (data and data.serial) then
		return self.name .. " №" .. tostring(data.serial)
	end

	return self.name
end

function ITEM:GetDescription(item)
	local data = item and istable(item.data) and item.data

	if (data and data.label and data.label != "") then
		return self.description .. "\n" .. L("padlockKeyTag", tostring(data.label))
	end

	return self.description
end
