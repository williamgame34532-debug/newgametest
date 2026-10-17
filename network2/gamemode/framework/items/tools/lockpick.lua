-- A set of lockpicks (sh_rebels.lua): use it looking at a locked door close by. Contraband.
ITEM.name = "Отмычки"
ITEM.description = "Набор самодельных отмычек. Посмотрите на запертую дверь и используйте. Скрытность ускоряет " ..
	"работу и бережёт отмычки; неудача может поднять шум."
ITEM.model = "models/props_c17/TrapPropeller_Lever.mdl"
ITEM.icon = "lockpick"
ITEM.useVerb = "вскрыть замок"
ITEM.contraband = true
ITEM.price = 40

function ITEM.OnUse(client)
	NW.rebels.Lockpick(client)

	return false
end
