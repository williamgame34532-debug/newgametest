-- Items: definitions shared by the inventory, world items, the fabricator and the health station.
HLA = HLA or {}
local I = {}
HLA.Items = I

I.Slots = 16            -- 4 x 4
I.PickupTime = 0.6      -- seconds of holding E on a world item
I.PickupRange = 95
I.PickupSound = 'hla/ui/inv_move1.wav'

I.Defs = {
	health_vial = {
		name = 'Колба с личинкой', model = 'models/hla/health_station/health_vial.mdl',
		fallback = 'models/healthvial.mdl',
		text = 'Личинка муравьиного льва в колбе Альянса. Вставьте в станцию первой помощи и удерживайте E, чтобы восстановить здоровье.',
		use = 'place', -- placed into a health station from the inventory
	},
	medkit = {
		name = 'Аптечка', model = 'models/items/healthkit.mdl',
		text = 'Восстанавливает 25 единиц здоровья.',
		use = 'heal', amount = 25,
	},
	battery = {
		name = 'Энергоячейка', model = 'models/items/battery.mdl',
		text = 'Восстанавливает 15 единиц брони.',
		use = 'armor', amount = 15,
	},
}

function I.Get(id) return I.Defs[id] end

function I.Model(id)
	local d = I.Defs[id]
	if not d then return 'models/props_junk/cardboard_box004a.mdl' end
	if d.fallback and not util.IsValidModel(d.model) then return d.fallback end
	return d.model
end
