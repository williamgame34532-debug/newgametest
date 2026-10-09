--[[-------------------------------------------------------------------------
	Задания: команда (общая — чтобы была в подсказках чата).
---------------------------------------------------------------------------]]

NWORK.Command.Add( "objective", {
	Args = "<заголовок> | <подзадача>", Admin = true,
	Desc = "Задание слева сверху для всех. Без текста — вернуть по умолчанию.",
	Run = function( _, _, raw )
		local title, desc = string.match( raw, "^(.-)%s*|%s*(.*)$" )
		title = string.Trim( title or raw )
		NWORK.SetObjective( nil, title, string.Trim( desc or "" ) )
		return title ~= "" and "Задание обновлено." or "Задание сброшено."
	end,
} )
