ITEM.name = "Ключ"
ITEM.description = "Ключ от двери. ПКМ → запереть / отпереть, стоя у своей двери."
ITEM.model = "models/props_c17/TrapPropeller_Lever.mdl"
ITEM.icon = "key"
ITEM.useVerb = "запереть / отпереть"

function ITEM.Describe(data)
	if (isstring(data.label) and data.label != "") then
		return "Ключ от двери: " .. data.label .. ". ПКМ → запереть / отпереть, стоя у двери."
	end
end

function ITEM.OnUse(client, cell)
	NW.doors.UseKey(client, cell and cell.data or {})

	return false
end
