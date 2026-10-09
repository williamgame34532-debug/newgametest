--[[-------------------------------------------------------------------------
	Камера меню (сервер).

	Точки задаются админами прямо из игры и хранятся на сервере в
	data/nwork/campaths.txt (JSON, по карте на запись). При изменении и
	при заходе игрока путь синхронизируется клиентам — он имеет приоритет
	над T.CameraPaths из темы.

	Команды (только админ):
		nwork_cam_add    — добавить точку там, где стоишь и куда смотришь
		nwork_cam_undo   — убрать последнюю точку
		nwork_cam_clear  — очистить путь текущей карты
		nwork_cam_list   — показать точки в консоли
---------------------------------------------------------------------------]]

util.AddNetworkString( "nwork_campath" )

local PATHS

local function Load()
	if PATHS then return end
	local raw = file.Read( "nwork/campaths.txt", "DATA" )
	PATHS = raw and util.JSONToTable( raw ) or {}
end

local function Save()
	file.CreateDir( "nwork" )
	file.Write( "nwork/campaths.txt", util.TableToJSON( PATHS, true ) )
end

local function CurrentPath()
	Load()
	local map = game.GetMap()
	PATHS[ map ] = PATHS[ map ] or {}
	return PATHS[ map ]
end

local function Send( ply )
	local path = CurrentPath()

	net.Start( "nwork_campath" )
		net.WriteUInt( #path, 8 )
		for _, p in ipairs( path ) do
			net.WriteVector( Vector( p.pos[ 1 ], p.pos[ 2 ], p.pos[ 3 ] ) )
			net.WriteAngle( Angle( p.ang[ 1 ], p.ang[ 2 ], p.ang[ 3 ] ) )
		end

	if ply then net.Send( ply ) else net.Broadcast() end
end

-- клиент просит путь при загрузке
net.Receive( "nwork_campath", function( _, ply )
	Send( ply )
end )

------------------------------------------------------------------- команды

local function AdminCmd( name, fn )
	concommand.Add( name, function( ply, _, args )
		if IsValid( ply ) and not ply:IsAdmin() then
			ply:ChatPrint( "[N-work] Только для админов." )
			return
		end
		fn( ply, args )
	end )
end

AdminCmd( "nwork_cam_add", function( ply )
	if not IsValid( ply ) then return end

	local path = CurrentPath()
	local p, a = ply:EyePos(), ply:EyeAngles()

	table.insert( path, {
		pos = { math.Round( p.x, 1 ), math.Round( p.y, 1 ), math.Round( p.z, 1 ) },
		ang = { math.Round( a.p, 2 ), math.Round( a.y, 2 ), math.Round( a.r, 2 ) },
	} )

	Save()
	Send()

	ply:ChatPrint( ( "[N-work] Точка камеры %d добавлена (%s)." )
		:format( #path, game.GetMap() ) )
end )

AdminCmd( "nwork_cam_undo", function( ply )
	local path = CurrentPath()
	if #path == 0 then
		if IsValid( ply ) then ply:ChatPrint( "[N-work] Путь пуст." ) end
		return
	end

	table.remove( path )
	Save()
	Send()

	if IsValid( ply ) then
		ply:ChatPrint( ( "[N-work] Последняя точка убрана, осталось %d." ):format( #path ) )
	end
end )

AdminCmd( "nwork_cam_clear", function( ply )
	Load()
	PATHS[ game.GetMap() ] = {}
	Save()
	Send()

	if IsValid( ply ) then ply:ChatPrint( "[N-work] Путь камеры очищен." ) end
end )

AdminCmd( "nwork_cam_list", function( ply )
	local path = CurrentPath()
	local out = ( "[N-work] Точек на %s: %d\n" ):format( game.GetMap(), #path )

	for i, p in ipairs( path ) do
		out = out .. ( "  %d) pos %.1f %.1f %.1f | ang %.2f %.2f %.2f\n" )
			:format( i, p.pos[ 1 ], p.pos[ 2 ], p.pos[ 3 ], p.ang[ 1 ], p.ang[ 2 ], p.ang[ 3 ] )
	end

	if IsValid( ply ) then
		ply:PrintMessage( HUD_PRINTCONSOLE, out )
		ply:ChatPrint( ( "[N-work] Точек: %d, список в консоли." ):format( #path ) )
	else
		print( out )
	end
end )
