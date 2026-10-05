ITEM.name = "Ключ"
ITEM.description = "Небольшой ключ на проволочном кольце."
ITEM.model = "models/props_c17/TrapPropeller_Lever.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.05
ITEM.maxStack = 1
ITEM.category = "misc"

function ITEM:GetModel()
	return NETWORK.container.PickModel({
		"models/props_c17/TrapPropeller_Lever.mdl",
		"models/props_lab/keypad.mdl"
	})
end

function ITEM:GetName(item)
	local label = item and item.data and item.data.label

	if (isstring(label) and label != "") then
		return string.format("Ключ «%s»", label)
	end
end

function ITEM:GetDescription(item)
	local data = item and item.data or {}
	local lines = {self.description}

	if (isstring(data.label) and data.label != "") then
		lines[#lines + 1] = "Бирка: " .. data.label
	end

	if (data.code != nil and tostring(data.code) != "") then
		lines[#lines + 1] = "Бородка: " .. tostring(data.code)
	else
		lines[#lines + 1] = "Бородка стёрта — подходит к любому такому замку."
	end

	return table.concat(lines, "\n")
end
