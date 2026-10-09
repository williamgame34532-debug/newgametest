--[[-------------------------------------------------------------------------
	Анимации: колесо жестов (F2), как в Monarch.
	Жесты — стандартная команда act, работают на любых playermodel.
---------------------------------------------------------------------------]]

local ACTS = {
	{ "Помахать",   "wave" },
	{ "Подозвать",  "becon" },
	{ "Вперёд",     "forward" },
	{ "Группа",     "group" },
	{ "Стоп",       "halt" },
	{ "Согласиться","agree" },
	{ "Возразить",  "disagree" },
	{ "Смех",       "laugh" },
	{ "Поклон",     "bow" },
	{ "Честь",      "salute" },
	{ "Ободрить",   "cheer" },
	{ "Ждать",      "pers" },
}

function NWORK.OpenActs()
	if NWORK.UI.Active() or not LocalPlayer():Alive() or not LocalPlayer():HasCharacter() then return end

	local opts = {}
	for _, a in ipairs( ACTS ) do
		opts[ #opts + 1 ] = { Name = a[ 1 ], Run = function() RunConsoleCommand( "act", a[ 2 ] ) end }
	end
	NWORK.UI.Radial( opts )
end

hook.Add( "PlayerBindPress", "Nwork.Acts", function( _, bind, pressed )
	if pressed and bind == "gm_showteam" then
		NWORK.OpenActs()
		return true
	end
end )
