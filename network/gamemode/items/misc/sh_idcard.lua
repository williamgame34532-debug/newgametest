ITEM.name = "ID-карточка"
ITEM.description = "Пластиковая карточка гражданина."
ITEM.model = "models/dorado/tarjeta1.mdl"
ITEM.rarity = "common"
ITEM.weight = 0.05
ITEM.category = "documents"
ITEM.useLabel = "itemRead"

function ITEM:OnCreated(item, client, character)
	if (item.data.owner or !character) then
		return
	end

	item.data.owner = character:GetName()
	item.data.number = NETWORK.terminal.GetCitizenID(character)
	item.data.issued = os.date("%d.%m.%Y")

	if (SERVER and NETWORK.cid and NETWORK.cid.RegisterCard) then
		item.data.serial = NETWORK.cid.RegisterCard({
			char = character:GetID(),
			cid = item.data.number,
			name = item.data.owner,
			by = "Регистратура C24"
		})
	end
end

function ITEM:GetName(item)
	if (item and item.data and item.data.owner) then
		return "ID-карта: " .. item.data.owner
	end
end

function ITEM:GetDescription(item)
	local owner = item.data.owner or "?"
	local number = item.data.number or 0

	if (isnumber(number)) then
		number = string.format("%05d", number % 100000)
	end

	return string.format("Удостоверение гражданина Сити-24.\nВладелец: %s\nCID: #%s\n" ..
		"Серия: %s", owner, number, item.data.serial or "без серии")
end

function ITEM:OnUse(client, item)
	if (NETWORK.documents and NETWORK.documents.View) then
		NETWORK.documents.View(client, item)
	end

	return false
end

ITEM.dropTag = "keep"
