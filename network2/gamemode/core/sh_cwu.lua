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
--   Отгрузка           Упакованный груз → токены    (anyone hired)
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
	{name = "Рабочий", xp = 60},
	{name = "Оператор", xp = 180},
	{name = "Мастер смены", xp = 400},
	{name = "Начальник цеха", xp = 800}
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
	intake = {name = "Приёмка сырья", rank = 1, take = {}, give = "scrap", time = 4, pay = 1, xp = 2,
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
	shipping = {name = "Отгрузка", rank = 1, take = {factory_crate = 1}, give = nil, time = 3, pay = 14, xp = 6,
		skill = "strength", verb = "Сдаю груз", model = "models/props_junk/wood_crate002a.mdl",
		hint = "Сдать упакованный груз за токены"}
}

CW.order = {"intake", "press", "assembly", "packing", "shipping"}

-- the instruction (/menufactory)
CW.instruction = {
	{"Как поставить завод", {
		"Спавн-меню → Entities → Network: «Завод: приёмка сырья», «Завод: станок», «Завод: сборочный стол», " ..
			"«Завод: контроль и упаковка», «Завод: отгрузка».",
		"Ставьте станции в одном цехе по порядку линии, в паре шагов друг от друга: продукт идёт по " ..
			"цепочке руками рабочих.",
		"Станции сохраняются вместе с картой. Двигать — физганом; сменить модель — посмотреть на станцию и " ..
			"/entmodel <путь к .mdl>.",
		"Отдел кадров: NPC, в редакторе диалога — ответ «Отдел кадров завода». Без оформления станции не " ..
			"работают."
	}},
	{"Цепочка продукта", {
		"Приёмка: металлолом (4 с).",
		"Станок: 2 металлолома → детали (6 с).",
		"Сборка: 2 детали → блок Альянса (8 с).",
		"Контроль и упаковка: блок → упакованный груз (6 с). Бывает брак: блок разбирается обратно на детали.",
		"Отгрузка: упакованный груз → токены."
	}},
	{"Роли и ранги", {
		"Стажёр (0 опыта): приёмка и отгрузка.",
		"Рабочий (60): + станок.",
		"Оператор (180): + сборочный стол.",
		"Мастер смены (400): + контроль и упаковка; брака меньше.",
		"Начальник цеха (800): все станции, оплата +25%."
	}},
	{"Оплата и опыт", {
		"Каждая станция платит токены сразу: приёмка 1, станок 3, сборка 5, контроль 6, отгрузка 14.",
		"Опыт завода растёт с каждой операцией и поднимает ранг. Класс ГСР «Завод» получает +20% оплаты.",
		"Навыки персонажа тоже растут: Сила (приёмка, отгрузка), Инженерия (станок, сборка, контроль). " ..
			"Инженерия ускоряет работу на станциях."
	}},
	{"Советы", {
		"Работа идёт, пока вы стоите у станции; отошли — операция прервалась, сырьё цело.",
		"Делите линию: один носит лом, второй точит детали, третий собирает — так быстрее.",
		"Мастер смены видит, сколько продукции прошло за смену, на терминале ГСР → Завод."
	}}
}
