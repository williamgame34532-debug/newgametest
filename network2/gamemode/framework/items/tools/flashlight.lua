-- A flashlight. The usual HL2 flashlight (F) works only while one is in the inventory; using the
-- item switches it on and off too.
ITEM.name = "Фонарик"
ITEM.description = "Небольшой фонарик на батарейках. Пока он при вас, свет включается клавишей фонарика (F) " ..
	"или отсюда."
ITEM.model = "models/lamps/torch.mdl"
ITEM.icon = "flashlight"
ITEM.useVerb = "включить / выключить"
ITEM.flashlight = true

function ITEM.OnUse(client)
	client:Flashlight(!client:FlashlightIsOn())
	client:EmitSound("items/flashlight1.wav", 55)

	return false
end
