--[[-------------------------------------------------------------------------
	N-work — уведомления.

	Сервер:  NWORK.Notify( ply | nil, "текст", "info" | "error" | "ok" )
	         (nil — всем игрокам)
	Клиент:  NWORK.Notify( "текст", kind, seconds )

	Рисуются строками слева сверху (cl_hud.lua), как статус-сообщения
	в Monarch. Стандартные уведомления песочницы тоже идут сюда.
---------------------------------------------------------------------------]]

local KINDS = { info = 0, error = 1, ok = 2 }
local NAMES = { [ 0 ] = "info", [ 1 ] = "error", [ 2 ] = "ok" }

if SERVER then

	util.AddNetworkString( "nwork_notify" )

	function NWORK.Notify( ply, text, kind )
		net.Start( "nwork_notify" )
			net.WriteString( tostring( text ) )
			net.WriteUInt( KINDS[ kind or "info" ] or 0, 2 )
		if ply then net.Send( ply ) else net.Broadcast() end
	end

	return
end

NWORK.Notices = NWORK.Notices or {}

function NWORK.Notify( text, kind, seconds )
	text = language.GetPhrase( tostring( text ) )

	table.insert( NWORK.Notices, 1, {
		text  = text,
		kind  = kind or "info",
		start = CurTime(),
		life  = seconds or 6,
	} )

	while #NWORK.Notices > 5 do table.remove( NWORK.Notices ) end

	if kind == "error" then
		surface.PlaySound( "buttons/button10.wav" )
	end

	MsgC( Color( 190, 194, 198 ), "[N-work] ", color_white, text, "\n" )
end

net.Receive( "nwork_notify", function()
	local text = net.ReadString()
	NWORK.Notify( text, NAMES[ net.ReadUInt( 2 ) ] )
end )

-- уведомления песочницы (отмена, лимиты и т.п.) — в наш стиль
function notification.AddLegacy( text, kind, len )
	NWORK.Notify( text, kind == NOTIFY_ERROR and "error" or "info", len )
end
