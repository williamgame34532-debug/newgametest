ITEM.name = "Баллончик с краской"
ITEM.description = "Помятый баллончик с остатками краски. Повстанец рисует им лямбду и лозунг на стене — надписи в секторе мешают Альянсу копить лояльность горожан. Наведитесь на стену и используйте."
ITEM.rarity = "uncommon"
ITEM.weight = 0.4
ITEM.width = 1
ITEM.height = 1
ITEM.category = "misc"
ITEM.bContraband = true
ITEM.useLabel = "rebelSprayUseLabel"

ITEM.maxUses = 3

for _, model in ipairs({
	"models/props_junk/garbage_spraypaintcan01a.mdl",
	"models/props_junk/garbage_metalcan002a.mdl",
	"models/props_junk/PopCan01a.mdl"
}) do
	if (file.Exists(model, "GAME")) then
		ITEM.model = model

		break
	end
end

ITEM.model = ITEM.model or "models/props_junk/PopCan01a.mdl"

function ITEM:GetDescription(item)
	local left = item and item.uses or self.maxUses

	return self.description .. "\n" .. L("rebelSprayLeft", left, self.maxUses)
end

function ITEM:OnUse(client, item)
	if (SERVER and NETWORK.rebels and NETWORK.rebels.BeginSpray) then
		NETWORK.rebels.BeginSpray(client, item)
	end

	return false
end
