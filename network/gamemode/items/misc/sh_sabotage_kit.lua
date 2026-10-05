ITEM.name = "Набор для саботажа"
ITEM.description = "Отвёртки, перемычки и моток изоленты в промасленной тряпке. С ним повстанец выводит технику Альянса из строя быстрее и надольше: турели, сканеры, силовые поля, замки, терминалы, раздатчики. Наведитесь на цель и используйте (или удерживайте E). Может износиться после работы."
ITEM.rarity = "special"
ITEM.weight = 0.8
ITEM.width = 1
ITEM.height = 1
ITEM.category = "misc"
ITEM.bContraband = true
ITEM.useLabel = "rebelKitUseLabel"

for _, model in ipairs({
	"models/props_c17/tools_wrench01a.mdl",
	"models/props_lab/box01a.mdl",
	"models/props_junk/cardboard_box004a.mdl"
}) do
	if (file.Exists(model, "GAME")) then
		ITEM.model = model

		break
	end
end

ITEM.model = ITEM.model or "models/props_junk/cardboard_box004a.mdl"

function ITEM:OnUse(client, item)
	if (SERVER and NETWORK.rebels and NETWORK.rebels.BeginSabotage) then
		NETWORK.rebels.BeginSabotage(client, nil, false)
	end

	return false
end
