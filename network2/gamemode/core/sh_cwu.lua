-- The Civil Workers' Union (framework/gamefactions/cwu.lua) and the factory.
-- The CWU has three classes (chosen at the CWU terminal, nw_cwu_terminal → Назначение):
--   worker    Рабочий Альянса - keeps the city running: the breakdowns (nw_breakdown: a leaking
--             pipe, a sparking power box, a dead panel of the Combine) are fixed with a toolkit
--   icu       Дезинфекционный контроль (ICU of Half-Life: Alyx) - burns out the outbreaks of the
--             infestation (nw_infestation) with a disinfector, in a gas mask
--   factory   Завод - the shifts at the factory, more pay there
-- The breakdowns and the outbreaks happen by themselves now and then (sv_cwu.lua) at the points
-- an admin has put; the CWU sees them at its terminal and on its HUD.
--
-- The factory: anyone hired at the personnel office (an NPC with the answer "Отдел кадров завода")
-- works there; the product goes through the whole line, each station is a role:
--   Приёмка сырья      → Металлолом                 (Стажёр and up)
--   Станок             2 Металлолом → Детали        (Рабочий and up)
--   Сборочный стол     2 Детали → Блок Альянса      (Оператор and up)
--   Контроль/упаковка  Блок → Упакованный груз      (Мастер смены and up; a defect sometimes)
--   Отгрузка           any product → токены         (anyone hired: scrap 1, parts 3, a block 6, a
--                                                   crate 14 - so a trainee has somewhere to bring the scrap)
-- Every station pays a little and gives experience of the factory; the experience raises the rank,
-- the rank opens the stations. /menufactory - the instruction (also opens once for the admin who
-- spawns the first station).

NW.cwu = NW.cwu or {}

local CW = NW.cwu

CW.classes = {
	{id = "worker", name = "Рабочий Альянса", icon = "tool",
		text = "Ремонтирует город: трубы, электрощиты, панели Альянса. Поломки видны на терминале ГСР и на " ..
			"экране. Нужен набор инструментов."},
	{id = "icu", name = "Дезинфекционный контроль", icon = "biohazard",
		text = "Выжигает очаги заражения дезинфектором. Работает в противогазе: споры жгут лёгкие."},
	{id = "factory", name = "Завод", icon = "factory",
		text = "Смены на заводе. Оплата на станциях выше на 20%."}
}

CW.classByID = {}

for _, class in ipairs(CW.classes) do
	CW.classByID[class.id] = class
end

function CW.Class(client)
	return client:GetNW2String("nwCwuClass", "")
end

function CW.IsCWU(client)
	return IsValid(client) and client:GetFaction() == "cwu"
end

-- ---------------------------------------------------------------- the factory --
CW.ranks = {
	{name = "Стажёр", xp = 0},
	{name = "Рабочий", xp = 30},
	{name = "Оператор", xp = 100},
	{name = "Мастер смены", xp = 220},
	{name = "Начальник цеха", xp = 420}
}

function CW.Rank(xp)
	local rank = 1

	for index, entry in ipairs(CW.ranks) do
		if ((xp or 0) >= entry.xp) then
			rank = index
		end
	end

	return rank
end

-- the stations: what goes in, what comes out, how long, the pay, the experience, the rank needed
CW.stations = {
	intake = {name = "Приёмка сырья", rank = 1, take = {}, give = "scrap", time = 4, pay = 1, xp = 3,
		skill = "strength", verb = "Разбираю лом", model = "models/props_junk/TrashDumpster01a.mdl",
		hint = "Забрать металлолом"},
	press = {name = "Станок", rank = 2, take = {scrap = 2}, give = "parts", time = 6, pay = 3, xp = 5,
		skill = "engineering", verb = "Работаю на станке", model = "models/props_c17/TrapPropeller_Engine.mdl",
		hint = "2 металлолома → детали"},
	assembly = {name = "Сборочный стол", rank = 3, take = {parts = 2}, give = "unit_core", time = 8, pay = 5, xp = 8,
		skill = "engineering", verb = "Собираю блок", model = "models/props_wasteland/controlroom_desk001b.mdl",
		hint = "2 детали → блок Альянса"},
	packing = {name = "Контроль и упаковка", rank = 4, take = {unit_core = 1}, give = "factory_crate", time = 6, pay = 6,
		xp = 10, skill = "engineering", verb = "Проверяю и упаковываю", defect = 0.18,
		model = "models/props_combine/combine_interface001.mdl", hint = "Блок → упакованный груз"},
	shipping = {name = "Отгрузка", rank = 1, take = {}, give = nil, time = 3, pay = 0, xp = 2,
		skill = "strength", verb = "Сдаю продукцию", model = "models/props_junk/wood_crate002a.mdl",
		hint = "Сдать продукцию за токены",
		-- what it takes (the most valuable one you carry): the pay and the experience for it
		buys = {factory_crate = {14, 8}, unit_core = {6, 4}, parts = {3, 2}, scrap = {1, 1}}}
}

CW.order = {"intake", "press", "assembly", "packing", "shipping"}

-- the instruction (/menufactory): sections on the left, the page on the right. The pages "line",
-- "ranks" and "pay" are drawn from CW.stations and CW.ranks (always as the server has them); the rest
-- are steps and paragraphs.
CW.instruction = {
	{id = "start", title = "С чего начать", icon = "factory", steps = {
		{"Оформиться", "Найдите отдел кадров завода (NPC) и нажмите «Оформиться». Без этого станции не " ..
			"работают."},
		{"Подойти к станции", "Над каждой станцией табличка: название, что она делает и с какого ранга. " ..
			"Начните с «Приёмки сырья» — она открыта всем."},
		{"Нажать E", "Стойте рядом, пока идёт полоска. Отошли — операция прервалась, сырьё цело."},
		{"Передать дальше", "Готовое ложится в инвентарь. Несите его на следующую станцию линии или " ..
			"отдайте напарнику."},
		{"Сдать продукцию", "«Отгрузка» принимает всё, что сделано на линии: лом — 1 токен, детали — 3, блок — 6, " ..
			"упакованный груз — 14. Чем дальше по линии, тем выгоднее."},
		{"Расти", "Опыт идёт за каждую операцию; после каждой видно, сколько осталось до ранга. Первый ранг — " ..
			"около десяти операций. Работают станции только в рабочую смену (оповещения в чате)."}
	}},
	{id = "line", title = "Линия продукта", icon = "trend",
		text = "Продукт проходит станции слева направо. Каждая станция берёт сырьё из инвентаря и отдаёт " ..
			"следующий полуфабрикат. На «Контроле» бывает брак: блок разбирается обратно на детали."},
	{id = "ranks", title = "Ранги и доступ", icon = "skills",
		text = "Опыт завода даётся за каждую операцию и поднимает ранг. Ранг открывает станции. Начальник " ..
			"цеха получает +25% к оплате, мастер смены и выше реже допускают брак."},
	{id = "pay", title = "Оплата и опыт", icon = "status",
		text = "Токены приходят сразу после операции. Класс ГСР «Завод» получает ещё +20%. Навык персонажа " ..
			"(сила или инженерия) растёт вместе с работой и ускоряет её."},
	{id = "team", title = "Работа сменой", icon = "squad", steps = {
		{"Делите линию", "Один носит лом, второй точит детали, третий собирает и упаковывает. Втроём " ..
			"линия идёт втрое быстрее, чем у одиночки."},
		{"Передавайте вещи", "Металлолом, детали и блоки можно отдать из рук в руки: G → Передать."},
		{"Следите за браком", "Брак на контроле возвращает детали: их снова несут на сборку, ничего не " ..
			"пропадает."},
		{"Статистика", "Ваш опыт и сколько операций сделано — у отдела кадров и на терминале ГСР → Завод."}
	}},
	{id = "cwu", title = "Поломки и заражения", icon = "tool", steps = {
		{"Поломки", "Трубы, щиты, панели, проводка, котлы и фонари ломаются сами. Список — на терминале " ..
			"ГСР → Поломки и значками на экране. Чинит рабочий с нужным инструментом (по умолчанию — набор " ..
			"инструментов), E у точки."},
		{"Заражения", "Очаги растут на отмеченных местах. Дезинфекционный контроль выжигает их " ..
			"дезинфектором, E у очага. Без противогаза в спорах нельзя."},
		{"Оплата", "За каждую поломку и очаг — токены и навык (инженерия или медицина)."}
	}},
	{id = "admin", title = "Для администратора", icon = "lock", steps = {
		{"Поставить станции", "Спавн-меню → Entities → Network: «Завод: приёмка сырья», «станок», " ..
			"«сборочный стол», «контроль и упаковка», «отгрузка». Ставьте в одном цехе по порядку линии, в " ..
			"паре шагов друг от друга."},
		{"Отдел кадров", "Поставьте NPC (Network → NPC), в редакторе диалога добавьте ответ «Отдел кадров " ..
			"завода»."},
		{"Настроить", "Зажмите C, ПКМ по станции или точке поломки → «Настройки». Станции: модель. Точки " ..
			"поломки: тип, название, модель, чем чинить, расходуется ли инструмент, время, оплата, кто " ..
			"чинит."},
		{"Сохранение", "Всё остаётся с картой: позиция (двигать физганом), модель, настройки. Удалили — " ..
			"забыто."},
		{"Команды", "/menufactory — эта инструкция. /entmodel <модель> — сменить модель того, на что " ..
			"смотрите."}
	}}
}
