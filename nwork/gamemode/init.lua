--[[-------------------------------------------------------------------------
	N-work — точка входа сервера.
---------------------------------------------------------------------------]]

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

-- материалы интерфейса раздаются клиентам
resource.AddFile( "materials/nwork/menu_icon.png" )
resource.AddFile( "materials/nwork/watermark.png" )
resource.AddFile( "materials/nwork/fac_citizen.png" )
