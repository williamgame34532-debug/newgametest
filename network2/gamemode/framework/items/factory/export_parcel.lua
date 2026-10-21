-- The parcel of a state order (sh_exports.lua): given by the bench when the order is full, taken at the
-- point of sale. Says what order it is and where it goes.
ITEM.base = "junk"

ITEM.name = "Посылка госзаказа"
ITEM.description = "Опломбированный ящик продукции завода. Сдаётся на точке сбыта."
ITEM.model = "models/props_junk/cardboard_box003a.mdl"
ITEM.icon = "export_parcel"

function ITEM.Describe(data)
	if (data and data.order) then
		return "Заказ №" .. tostring(data.order) .. " для «" .. tostring(data.city or "?") .. "»: " ..
			tostring(data.text or "") .. ". Сдать на точке сбыта."
	end
end

-- not opened, not used up: only carried
ITEM.useVerb = "осмотреть"

function ITEM.OnUse(client, cell)
	local data = cell and cell.data or {}

	NW.Notify(client, "Посылка заказа №" .. tostring(data.order or "?") .. " для «" .. tostring(data.city or "?") ..
		"». Сдать на точке сбыта")

	return false
end
