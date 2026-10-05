ITEM.name = "Наручники"
ITEM.description = "Стальные наручники Гражданской обороны. Надеваются, пока смотришь на человека; снимаются ключом (ПКМ)."

ITEM.model = (file.Size("models/chara/simplehandcuffs/handcuffs.mdl", "GAME") or 0) > 0 and
	"models/chara/simplehandcuffs/handcuffs.mdl" or "models/maxofs2d/hover_rings.mdl"
ITEM.rarity = "special"
ITEM.weight = 0.5
ITEM.width = 1
ITEM.height = 1
ITEM.category = "misc"

ITEM.equipSlot = "cuffs"
ITEM.weaponClass = "weapon_nwhandcuffs"
