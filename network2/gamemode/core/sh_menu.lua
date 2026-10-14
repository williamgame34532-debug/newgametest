-- shared settings of the main menu (sv_menu.lua, cl_menu.lua)
CreateConVar("nw_menu_speed", "70", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Скорость полёта камеры меню (юнитов в секунду)")
CreateConVar("nw_community_url", "", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Ссылка кнопки «Сообщество» (Discord, форум)")

function NW.IsInMenu(client)
	return IsValid(client) and client:GetNW2Bool("nwInMenu", false)
end
