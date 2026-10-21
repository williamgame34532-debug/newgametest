-- What the "Конфигурация" page of the Q menu (superadmins) can change: server convars in
-- groups, with their limits. The server accepts only these (sv_config.lua).

NW.config = NW.config or {}

local CF = NW.config

CF.groups = {
	{name = "Движение", rows = {
		{convar = "nw_walkspeed", label = "Скорость шага", type = "slider", min = 50, max = 200},
		{convar = "nw_runspeed", label = "Скорость бега", type = "slider", min = 100, max = 400},
		{convar = "nw_slowwalkspeed", label = "Медленный шаг (Alt)", type = "slider", min = 40, max = 120},
		{convar = "nw_jumppower", label = "Сила прыжка", type = "slider", min = 100, max = 300}
	}},
	{name = "Потребности", rows = {
		{convar = "nw_hunger_minutes", label = "Голод до нуля, минут", type = "slider", min = 10, max = 300},
		{convar = "nw_thirst_minutes", label = "Жажда до нуля, минут", type = "slider", min = 10, max = 300},
		{convar = "nw_stamina_drain", label = "Расход стамины в секунду", type = "slider", min = 0, max = 30}
	}},
	{name = "Оружие", rows = {
		{convar = "nw_safety", label = "Предохранитель (зажатая R)", type = "toggle"}
	}},
	{name = "ГСР: поломки и заражения", rows = {
		{convar = "nw_breakdown_interval", label = "Поломка раз в, секунд", type = "slider", min = 30, max = 3600},
		{convar = "nw_breakdown_spread", label = "Разброс интервала, %", type = "slider", min = 0, max = 90},
		{convar = "nw_breakdown_cooldown", label = "КД точки после ремонта, секунд", type = "slider", min = 0, max = 7200},
		{convar = "nw_breakdown_max", label = "Поломок одновременно, не больше", type = "slider", min = 1, max = 20},
		{convar = "nw_infestation_interval", label = "Очаг заражения раз в, секунд", type = "slider", min = 60,
			max = 3600}
	}},
	{name = "Главное меню", rows = {
		{convar = "nw_menu_speed", label = "Скорость полёта камеры", type = "slider", min = 20, max = 200},
		{convar = "nw_community_url", label = "Ссылка «Сообщество»", type = "text"}
	}},
	{name = "Сервер", rows = {
		{convar = "nw_char_debug", label = "Журнал персонажей в консоли", type = "toggle"}
	}}
}

CF.byName = {}

for _, group in ipairs(CF.groups) do
	for _, row in ipairs(group.rows) do
		CF.byName[row.convar] = row
	end
end
