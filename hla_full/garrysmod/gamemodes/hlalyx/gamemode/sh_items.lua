HLA = HLA or {}
local I = {}
HLA.Items = I

I.Slots = 16
I.PickupTime = 0.6
I.PickupRange = 95
I.PickupSound = 'hla/ui/inv_move1.wav'
I.MoveSounds = {'hla/ui/inv_move1.wav', 'hla/ui/inv_move2.wav', 'hla/ui/inv_move3.wav', 'hla/ui/inv_move4.mp3', 'hla/ui/inv_move5.mp3', 'hla/ui/inv_move6.mp3'}
function I.MoveSound() return I.MoveSounds[math.random(#I.MoveSounds)] end

I.Defs = {
	health_vial = {
		name = 'Колба с личинкой', model = 'models/hla/health_station/health_vial.mdl',
		fallback = 'models/healthvial.mdl',
		text = 'Личинка муравьиного льва в колбе Альянса. Вставьте в станцию первой помощи и удерживайте E, чтобы восстановить здоровье.',
		use = 'place',
	},
	medkit = {
		name = 'Аптечка', model = 'models/items/healthkit.mdl',
		text = 'Восстанавливает 25 единиц здоровья.',
		use = 'heal', amount = 25, sound = 'hla/ui/inv_bandage.wav',
	},
	pills = {
		name = 'Обезболивающее', model = 'models/props_lab/jar01b.mdl',
		text = 'Пачка таблеток из пайка Альянса. Восстанавливает 10 единиц здоровья.',
		use = 'heal', amount = 10, sound = 'hla/ui/inv_pills.wav',
	},
	battery = {
		name = 'Энергоячейка', model = 'models/items/battery.mdl',
		text = 'Восстанавливает 15 единиц брони.',
		use = 'armor', amount = 15,
	},
	ammo_service = {
		name = 'Магазины к табельному оружию', model = 'models/items/boxmrounds.mdl',
		text = 'Два магазина к оружию в руках (или к табельному оружию юнита).',
		use = 'ammo', clips = 2,
	},
	ammo_pistol = {
		name = 'Патроны 9 мм', model = 'models/items/boxsrounds.mdl',
		text = 'Пополняет запас пистолетных патронов на 30.',
		use = 'ammo', ammo = 'Pistol', amount = 30,
	},
	ammo_smg = {
		name = 'Патроны ПП', model = 'models/items/boxmrounds.mdl',
		text = 'Пополняет запас патронов пистолета-пулемёта на 45.',
		use = 'ammo', ammo = 'SMG1', amount = 45,
	},
	ammo_shotgun = {
		name = 'Дробь', model = 'models/items/boxbuckshot.mdl',
		text = 'Пополняет запас дробовых патронов на 12.',
		use = 'ammo', ammo = 'Buckshot', amount = 12,
	},
	ammo_ar2 = {
		name = 'Импульсные заряды', model = 'models/items/combine_rifle_cartridge01.mdl',
		text = 'Пополняет запас импульсной винтовки на 30.',
		use = 'ammo', ammo = 'AR2', amount = 30,
	},
}

local STACK = {pills = 5, battery = 3, medkit = 2, ammo_service = 5, ammo_pistol = 5, ammo_smg = 5, ammo_shotgun = 5, ammo_ar2 = 5}
function I.Stack(id)
	local d = I.Defs[id]
	if not d then return 1 end
	if d.stack then return d.stack end
	if STACK[id] then return STACK[id] end
	if d.use == 'ammo' then return 5 end
	return 1
end

function I.Get(id) return I.Defs[id] end

function I.Model(id)
	local d = I.Defs[id]
	if not d then return 'models/props_junk/cardboard_box004a.mdl' end
	if d.fallback and not util.IsValidModel(d.model) then return d.fallback end
	return d.model
end
