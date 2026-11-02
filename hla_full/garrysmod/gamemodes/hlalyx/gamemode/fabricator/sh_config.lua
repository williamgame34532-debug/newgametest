CFRework = CFRework or {}
local C = CFRework

C.Model = 'models/cf_rework/hla_station.mdl'
C.ResinModel = 'models/cf_rework/resin_pickup.mdl'
C.CartridgeModel = 'models/cf_rework/resin_cartridge.mdl'

C.FabClass = 'sent_combine_fabricator'
C.ResinClass = 'sent_cf_resin'

C.WakeRadius = 150
C.CloseDelay = 1.2
C.UseRange = 110
C.LeaveRadius = 185
C.IdleTimeout = 120
C.FeedInterval = 0.45
C.MaxResin = 1000000

C.Categories = {'МЕДИЦИНА', 'ОРУЖИЕ', 'БОЕПРИПАСЫ'}

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
	{id = 'ammo_service', category = 3, name = 'Магазины к табельному оружию', cost = 4, kind = 'item', item = 'ammo_service',
		model = 'models/items/boxmrounds.mdl', text = 'Два магазина к оружию в руках. Попадает в инвентарь.'},
	{id = 'ammo_pistol', category = 3, name = 'Патроны 9 мм', cost = 2, kind = 'item', item = 'ammo_pistol', ammo = 'Pistol', amount = 30,
		model = 'models/items/boxsrounds.mdl', text = 'Пополняет запас пистолетных патронов на 30. Попадает в инвентарь.'},
	{id = 'ammo_smg', category = 3, name = 'Патроны ПП', cost = 3, kind = 'item', item = 'ammo_smg', ammo = 'SMG1', amount = 45,
		model = 'models/items/boxmrounds.mdl', text = 'Пополняет запас патронов пистолета-пулемёта на 45. Попадает в инвентарь.'},
	{id = 'ammo_shotgun', category = 3, name = 'Дробь', cost = 4, kind = 'item', item = 'ammo_shotgun', ammo = 'Buckshot', amount = 12,
		model = 'models/items/boxbuckshot.mdl', text = 'Пополняет запас дробовых патронов на 12. Попадает в инвентарь.'},
	{id = 'ammo_ar2', category = 3, name = 'Импульсные заряды', cost = 5, kind = 'item', item = 'ammo_ar2', ammo = 'AR2', amount = 30,
		model = 'models/items/combine_rifle_cartridge01.mdl', text = 'Пополняет запас импульсной винтовки на 30. Попадает в инвентарь.'},
	{id = 'health_vial', category = 1, name = 'Колба с личинкой', cost = 6, kind = 'item', item = 'health_vial',
		model = 'models/hla/health_station/health_vial.mdl', text = 'Для станции первой помощи. Попадает в инвентарь.'},
}

function C.TabCat(tab)
	tab = tonumber(tab) or 1
	return math.max(1, tab % 16), math.floor(tab / 16)
end

function C.CategoryItems(cat)
	local out = {}
	for i, v in ipairs(C.Items) do if v.category == cat and not v.off then out[#out + 1] = i end end
	return out
end

C.State = {
	DORMANT = 0,
	MENU = 1,
	DEPOSIT = 2,
	PRINT = 3,
	DONE = 4,
}

C.ClickSounds = {'combine_fabricator/ui/click_01.mp3', 'combine_fabricator/ui/click_02.mp3',
	'combine_fabricator/ui/click_03.mp3', 'combine_fabricator/ui/click_04.mp3'}

C.HoloCenter = Vector(7.5, -15.5, 62)
C.HoloBox = {w = 10.5, h = 8.5}
C.ItemFit = {len = 8.5, cross = 4.5}

function C.PrintProgress(ent, t)
	local elapsed = (t or CurTime()) - ent:GetStageStarted()
	return C.M.clamp(elapsed / math.max(0.1, ent:GetStageUntil() - ent:GetStageStarted()), 0, 1)
end
function C.BuildProgress(ent, t)
	return C.M.clamp((C.PrintProgress(ent, t) - 0.18) / 0.62, 0, 1)
end
