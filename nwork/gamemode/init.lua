--[[-------------------------------------------------------------------------
	N-work — server init
---------------------------------------------------------------------------]]

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "sh_config.lua" )
AddCSLuaFile( "sh_factions.lua" )
AddCSLuaFile( "sh_items.lua" )

AddCSLuaFile( "client/cl_theme.lua" )
AddCSLuaFile( "client/cl_glyphs.lua" )
AddCSLuaFile( "client/cl_menubase.lua" )
AddCSLuaFile( "client/cl_mainmenu.lua" )
AddCSLuaFile( "client/cl_charcreate.lua" )
AddCSLuaFile( "client/cl_charselect.lua" )
AddCSLuaFile( "client/cl_intro.lua" )
AddCSLuaFile( "client/cl_chat.lua" )
AddCSLuaFile( "client/cl_hud.lua" )
AddCSLuaFile( "client/cl_wepselect.lua" )
AddCSLuaFile( "client/cl_inventory.lua" )
AddCSLuaFile( "client/cl_interact.lua" )

include( "shared.lua" )
include( "sh_config.lua" )
include( "sh_factions.lua" )
include( "sh_items.lua" )

include( "server/sv_characters.lua" )
include( "server/sv_spawn.lua" )
include( "server/sv_campath.lua" )
include( "server/sv_recognize.lua" )
include( "server/sv_bots.lua" )
include( "server/sv_items.lua" )

-- Иконка главного меню раздаётся клиентам
resource.AddFile( "materials/nwork/menu_icon.png" )
resource.AddFile( "materials/nwork/fac_citizen.png" )
