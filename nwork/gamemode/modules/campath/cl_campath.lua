--[[-------------------------------------------------------------------------
	Камера меню (клиент): приём пути с сервера и nwork_campos.
	Сам полёт камеры — в cl_ui.lua (NWORK.CamPath).
---------------------------------------------------------------------------]]

net.Receive( "nwork_campath", function()
	local n = net.ReadUInt( 8 )
	local path = {}

	for i = 1, n do
		path[ i ] = { pos = net.ReadVector(), ang = net.ReadAngle() }
	end

	NWORK.CamPath = n > 0 and path or nil
end )

hook.Add( "InitPostEntity", "Nwork.RequestCamPath", function()
	net.Start( "nwork_campath" )
	net.SendToServer()
end )

-- снять точку для T.CameraPaths: печатает готовую строку конфига
concommand.Add( "nwork_campos", function( ply )
	local p, a = ply:EyePos(), ply:EyeAngles()
	print( string.format( "{ pos = Vector( %.1f, %.1f, %.1f ), ang = Angle( %.2f, %.2f, %.2f ) },",
		p.x, p.y, p.z, a.p, a.y, a.r ) )
end )
