ITEM.name = "Набор для тайника"
ITEM.description = "Потёртая коробка, пара тряпок и моток проволоки. Из этого выйдет неприметный тайник: на вид — обычный мусор."
ITEM.model = "models/props_junk/cardboard_box003a.mdl"
ITEM.rarity = "uncommon"
ITEM.weight = 1.5
ITEM.width = 2
ITEM.height = 1
ITEM.category = "misc"
ITEM.useLabel = "itemPlaceCache"

function ITEM:GetModel()
	return NETWORK.container.PickModel({
		"models/props_junk/cardboard_box003a.mdl",
		"models/props_junk/cardboard_box001a.mdl",
		"models/props_junk/wood_crate001a.mdl"
	})
end

function ITEM:OnUse(client)
	if (NETWORK.cache and NETWORK.cache.Begin) then
		NETWORK.cache.Begin(client)
	end

	return false
end
