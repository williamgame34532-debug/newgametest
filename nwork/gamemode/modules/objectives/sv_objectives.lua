--[[-------------------------------------------------------------------------
	Задания (сервер).

	NWORK.SetObjective( ply | nil, "Заголовок", "Подзадача" )
		nil — общее задание для всех (сохраняется в data/nwork/objective.txt)
		ply — личное задание поверх общего; пустой заголовок снимает его
	/objective Заголовок | Подзадача   (админ; без текста — по умолчанию)
---------------------------------------------------------------------------]]

util.AddNetworkString( "nwork_objective" )

local FILE = "nwork/objective.txt"
local global = util.JSONToTable( file.Read( FILE, "DATA" ) or "" )

local function Default()
	return global or ( NWORK.Schema and NWORK.Schema.Objective ) or { Title = "", Desc = "" }
end

local function Send( ply, obj )
	net.Start( "nwork_objective" )
		net.WriteString( obj.Title or "" )
		net.WriteString( obj.Desc or "" )
	if ply then net.Send( ply ) else net.Broadcast() end
end

function NWORK.SetObjective( ply, title, desc )
	local obj = { Title = title or "", Desc = desc or "" }

	if IsValid( ply ) then
		ply.NworkObjective = obj.Title ~= "" and obj or nil
		Send( ply, ply.NworkObjective or Default() )
		return
	end

	global = obj.Title ~= "" and obj or nil
	file.CreateDir( "nwork" )
	if global then file.Write( FILE, util.TableToJSON( global ) ) else file.Delete( FILE ) end

	for _, p in ipairs( player.GetAll() ) do
		if not p.NworkObjective then Send( p, Default() ) end
	end
end

hook.Add( "NworkPlayerReady", "Nwork.Objective", function( ply )
	Send( ply, ply.NworkObjective or Default() )
end )
