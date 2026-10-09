--[[-------------------------------------------------------------------------
	N-work — модули.

	Модуль — папка в gamemode/modules/<id>/. Все её файлы (и подпапки)
	подключаются автоматически, реалм по префиксу. Во время загрузки
	доступна глобальная MODULE — таблица модуля:

		MODULE.Name = "Нужды"
		MODULE.Desc = "Голод, жажда и усталость."

	Отключить модуль: NWORK.Config.DisabledModules[ "needs" ] = true
	(в schema/sh_schema.lua). После загрузки модули лежат в NWORK.Modules.
---------------------------------------------------------------------------]]

NWORK.Modules = NWORK.Modules or {}
NWORK.Module  = NWORK.Module or {}

function NWORK.Module.LoadAll()
	local _, folders = file.Find( NWORK.Folder .. "/modules/*", "LUA" )
	table.sort( folders )

	for _, id in ipairs( folders ) do
		if not NWORK.Config.DisabledModules[ id ] then
			MODULE = { id = id, Name = id, Desc = "" }
			NWORK.IncludeDir( "modules/" .. id, true )
			NWORK.Modules[ id ] = MODULE
			MODULE = nil
		end
	end
end

function NWORK.Module.Get( id )
	return NWORK.Modules[ id ]
end
