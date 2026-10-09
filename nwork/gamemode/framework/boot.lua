--[[-------------------------------------------------------------------------
	N-work — порядок загрузки фреймворка.

	Библиотеки подключаются явным списком: у них есть зависимости друг
	от друга. Схема и модули — автоматически, всеми файлами папок.
---------------------------------------------------------------------------]]

local F = NWORK.Folder .. "/framework/"

local LIBRARIES = {
	"sh_util",
	"sh_config",
	"sh_faction",
	"sh_item",
	"sh_character",
	"sh_notify",
	"sh_command",
	"sh_chat",
	"sh_inventory",
	"sh_module",
	"cl_option",
	"sv_database",
	"sv_character",
	"sv_inventory",
}

local INTERFACE = {
	"cl_theme",
	"cl_glyphs",
	"cl_ui",
	"cl_radial",
	"cl_mainmenu",
	"cl_charcreate",
	"cl_charselect",
	"cl_intro",
	"cl_chatbox",
	"cl_hud",
	"cl_interact",
	"cl_wepselect",
	"cl_tabmenu",
	"cl_tabpages",
}

for _, name in ipairs( LIBRARIES ) do
	NWORK.Include( F .. "libraries/" .. name .. ".lua" )
end

NWORK.IncludeDir( "framework/hooks" )

-- схема: сначала sh_schema.lua и прочие файлы корня, затем factions/, items/
NWORK.IncludeDir( "schema", true )

for _, name in ipairs( INTERFACE ) do
	NWORK.Include( F .. "interface/" .. name .. ".lua" )
end

NWORK.Module.LoadAll()

hook.Run( "NworkLoaded" )

NWORK.Print( ( "фреймворк v%s загружен (%s), модулей: %d" ):format(
	NWORK.Version, SERVER and "сервер" or "клиент", table.Count( NWORK.Modules ) ) )
