-- A frag grenade (the fabricator, sh_fabricator.lua): using it puts the grenade into the hands.
ITEM.name = "Осколочная граната"
ITEM.description = "Взрывное устройство Альянса. Взрывается через несколько секунд после броска. " ..
	"«Использовать» — взять в руки."
ITEM.model = "models/items/grenadeammo.mdl"
ITEM.icon = "grenade"
ITEM.category = "weapon"
ITEM.useVerb = "взять в руки"

function ITEM.OnUse(client)
	if (client:HasWeapon("weapon_frag")) then
		client:GiveAmmo(1, "Grenade", true)
	else
		client:Give("weapon_frag")
	end

	client:SelectWeapon("weapon_frag")
end
