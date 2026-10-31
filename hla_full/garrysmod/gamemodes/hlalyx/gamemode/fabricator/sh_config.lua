-- Combine Fabricator: configuration. Edit freely.
CFRework = CFRework or {}
local C = CFRework

C.Model = 'models/cf_rework/hla_station.mdl' -- Half-Life: Alyx fabricator with its own skeleton and sequences
C.ResinModel = 'models/cf_rework/resin_pickup.mdl'         -- resin lying in the world
C.CartridgeModel = 'models/cf_rework/resin_cartridge.mdl'  -- resin cartridge loaded into a cell

C.FabClass = 'sent_combine_fabricator' -- the gamemode uses its own class names
C.ResinClass = 'sent_cf_resin'

C.WakeRadius = 150      -- the station wakes up when a living player is this close
C.CloseDelay = 1.2      -- seconds with nobody within WakeRadius before everything folds away
C.UseRange = 110        -- max eye distance for the screen / cells / chamber
C.LeaveRadius = 185     -- operator further than this -> session ends, resin refunded, everything closes
C.IdleTimeout = 120     -- seconds without interaction -> session ends
C.FeedInterval = 0.45   -- one resin per this many seconds while E is held on the tray (a carousel step is 0.37 s)
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

C.ClickSounds = {'combine_fabricator/ui/click_01.mp3', 'combine_fabricator/ui/click_02.mp3',
	'combine_fabricator/ui/click_03.mp3', 'combine_fabricator/ui/click_04.mp3'}

-- Entity space of the compiled model: studiomdl turns the source 90 degrees, so the working side
-- (screen, resin tray, rib bay) faces +X. Hologram of the chosen item, in front of the grille middle:
C.HoloCenter = Vector(7.5, -15.5, 62)
C.HoloBox = {w = 10.5, h = 8.5}
-- printed item inside the rib bay: longest side along the bay, scaled to fit
C.ItemFit = {len = 8.5, cross = 4.5}

-- Print progress follows the 'print' sequence of the model (stage times are set when it starts)
function C.PrintProgress(ent, t)
	local elapsed = (t or CurTime()) - ent:GetStageStarted()
	return C.M.clamp(elapsed / math.max(0.1, ent:GetStageUntil() - ent:GetStageStarted()), 0, 1)
end
-- the item materialises during the middle of the print sequence (ribs closed, rings spinning)
function C.BuildProgress(ent, t)
	return C.M.clamp((C.PrintProgress(ent, t) - 0.18) / 0.62, 0, 1)
end
