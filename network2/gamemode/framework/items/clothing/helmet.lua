ITEM.base = "clothing"

ITEM.name = "Каска"
ITEM.description = "Старая стальная каска с подбородочным ремнём. Пуля в голову уже не обязательно смерть."
ITEM.slot = "head"
ITEM.icon = "helmet"
ITEM.model = "models/props_junk/MetalBucket01a.mdl"
ITEM.wear = {group = "head", match = "helmet"}
-- how much of a hit it takes (0..1, sv_body.lua): a helmet turns a lethal head shot into a heavy one
ITEM.protect = 0.6
