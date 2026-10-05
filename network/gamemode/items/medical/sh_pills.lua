ITEM.name = "Антибиотик"
ITEM.description = "Блистер таблеток широкого спектра. Снимает отравление и инфекцию за один приём. Здоровому не нужен — пачка не тратится."
ITEM.model = "models/props_lab/jar01a.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 0.15
ITEM.maxStack = 6
ITEM.width = 1
ITEM.height = 1
ITEM.category = "medical"

ITEM.useLabel = "itemTake"

ITEM.bConsumeOnUse = true

function ITEM:OnUse(client)
	if (!SERVER) then
		return false
	end

	if (!NETWORK.disease or !NETWORK.disease.Has(client)) then
		NETWORK.notice.Send(client, "diseaseNone", "info")

		return false
	end

	NETWORK.disease.Cure(client)
	client:EmitSound("items/medshot4.wav", 55, math.random(95, 105))
end
