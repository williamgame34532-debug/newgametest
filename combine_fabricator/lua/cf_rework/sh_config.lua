-- Combine Fabricator: configuration. Edit freely.
CFRework = CFRework or {}
local C = CFRework

C.Model = 'models/cf_rework/station.mdl'
C.ResinModel = 'models/cf_rework/resin_pickup.mdl'

C.WakeRadius = 170      -- the station wakes up when a living player is this close
C.UseRange = 110        -- max eye distance for the screen / cells / chamber
C.LeaveRadius = 260     -- operator further than this -> session ends, resin refunded
C.IdleTimeout = 120     -- seconds without interaction -> session ends
C.PrintTime = 5.0       -- seconds the chamber prints
C.FeedInterval = 0.22   -- one resin per this many seconds while E is held on the cells
C.MaxResin = 1000000

C.Categories = {'МЕДИЦИНА', 'ОРУЖИЕ', 'БОЕПРИПАСЫ'}

-- kind: health / armor (applied to the player), weapon (class), ammo (ammo type + amount)
C.Items = {
	{id = 'vial', category = 1, name = 'Медицинская ампула', cost = 2, kind = 'health', amount = 10,
		model = 'models/healthvial.mdl', text = 'Восстанавливает 10 единиц здоровья.'},
	{id = 'kit', category = 1, name = 'Медицинский комплект', cost = 5, kind = 'health', amount = 25,
		model = 'models/items/healthkit.mdl', text = 'Полевая аптечка. Восстанавливает 25 единиц здоровья.'},
	{id = 'battery', category = 1, name = 'Энергоячейка', cost = 4, kind = 'armor', amount = 15,
		model = 'models/items/battery.mdl', text = 'Восстанавливает 15 единиц брони, до 100.'},
	{id = 'pistol', category = 2, name = 'Пистолет 9 мм', cost = 10, kind = 'weapon', class = 'weapon_pistol',
		model = 'models/weapons/w_pistol.mdl', text = 'Полуавтоматический пистолет.'},
	{id = 'smg', category = 2, name = 'Пистолет-пулемёт', cost = 20, kind = 'weapon', class = 'weapon_smg1',
		model = 'models/weapons/w_smg1.mdl', text = 'Компактное автоматическое оружие ближнего боя.'},
	{id = 'shotgun', category = 2, name = 'Дробовик', cost = 35, kind = 'weapon', class = 'weapon_shotgun',
		model = 'models/weapons/w_shotgun.mdl', text = 'Помповый дробовик.'},
	{id = 'ar2', category = 2, name = 'Импульсная винтовка', cost = 45, kind = 'weapon', class = 'weapon_ar2',
		model = 'models/weapons/w_irifle.mdl', text = 'Штурмовая импульсная винтовка Альянса.'},
	{id = 'ammo_pistol', category = 3, name = 'Патроны 9 мм', cost = 2, kind = 'ammo', ammo = 'Pistol', amount = 30,
		model = 'models/items/boxsrounds.mdl', text = 'Пополняет запас пистолетных патронов на 30.'},
	{id = 'ammo_smg', category = 3, name = 'Патроны ПП', cost = 3, kind = 'ammo', ammo = 'SMG1', amount = 45,
		model = 'models/items/boxmrounds.mdl', text = 'Пополняет запас патронов пистолета-пулемёта на 45.'},
	{id = 'ammo_shotgun', category = 3, name = 'Дробь', cost = 4, kind = 'ammo', ammo = 'Buckshot', amount = 12,
		model = 'models/items/boxbuckshot.mdl', text = 'Пополняет запас дробовых патронов на 12.'},
	{id = 'ammo_ar2', category = 3, name = 'Импульсные заряды', cost = 5, kind = 'ammo', ammo = 'AR2', amount = 30,
		model = 'models/items/combine_rifle_cartridge01.mdl', text = 'Пополняет запас импульсной винтовки на 30.'},
}

function C.CategoryItems(cat)
	local out = {}
	for i, v in ipairs(C.Items) do if v.category == cat then out[#out + 1] = i end end
	return out
end

-- Session stages
C.State = {
	DORMANT = 0,  -- folded, nobody around
	MENU = 1,     -- awake, catalogue
	DEPOSIT = 2,  -- item chosen, load resin into the cells
	PRINT = 3,    -- the rib chamber prints
	DONE = 4,     -- chamber out with the item, take it with E
}

-- Animation channels: seconds for a full 0..1 travel
C.Channels = {deploy = 2.6, cradle = 1.6, tray = 0.7, pull = 1.0}
