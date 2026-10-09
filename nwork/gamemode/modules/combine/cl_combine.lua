--[[-------------------------------------------------------------------------
	Оверлей Альянса (как у Гражданской Обороны в Project Synapse).

	Для фракций с Combine = true:
	* сверху по центру — компас со шкалой курса;
	* справа сверху — расписание и локация курсивом-«терминалом»;
	* у союзных юнитов в поле зрения — позывной над головой.
---------------------------------------------------------------------------]]

local CYAN  = Color( 92, 204, 236 )
local UI    = NWORK.UI

local function IsCombine( ply )
	local f = IsValid( ply ) and ply:GetFactionTable()
	return f and f.Combine and ply:HasCharacter()
end

local DIRS = { [ 0 ] = "С", [ 45 ] = "СВ", [ 90 ] = "В", [ 135 ] = "ЮВ", [ 180 ] = "Ю", [ 225 ] = "ЮЗ", [ 270 ] = "З", [ 315 ] = "СЗ" }

local function Compass( w, k )
	local yaw   = ( 90 - LocalPlayer():EyeAngles().y ) % 360   -- 0 = север (+Y карты)
	local cx    = w / 2
	local y     = math.floor( 92 * k )
	local width = math.floor( 420 * k )
	local ppd   = width / 120                                    -- пикселей на градус

	for deg = 0, 355, 5 do
		local d = ( ( deg - yaw + 540 ) % 360 ) - 180
		if math.abs( d ) <= 60 then
			local x   = cx + d * ppd
			local a   = 230 * ( 1 - math.abs( d ) / 70 )
			local big = deg % 15 == 0
			surface.SetDrawColor( CYAN.r, CYAN.g, CYAN.b, a )
			surface.DrawRect( x, y, 1, big and math.floor( 10 * k ) or math.floor( 5 * k ) )

			if big then
				local label = DIRS[ deg ] or tostring( deg )
				draw.SimpleText( label, "Nwork.Combine", x, y + math.floor( 14 * k ),
					Color( CYAN.r, CYAN.g, CYAN.b, a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
			end
		end
	end

	-- указатель курса
	draw.SimpleText( "v", "Nwork.Combine", cx, y - math.floor( 4 * k ), CYAN, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
end

hook.Add( "NworkHUDPaint", "Nwork.Combine", function( w, h, k )
	local lp = LocalPlayer()
	if not IsCombine( lp ) then return end

	Compass( w, k )

	-- справа сверху: расписание и локация
	local x = w - math.floor( 48 * k )
	local y = math.floor( 70 * k )
	local lines = {
		( "ПАТРУЛЬ (%s) :: РАСПИСАНИЕ" ):format( os.date( "%H:%M" ) ),
		( "%s :: ЛОКАЦИЯ" ):format( string.upper( game.GetMap() ) ),
		( "ЮНИТ %s :: ПОЗЫВНОЙ" ):format( NWORK.Util.Upper( lp:GetCharName() ) ),
	}
	for i, l in ipairs( lines ) do
		UI.ShadowText( l, "Nwork.Combine", x, y + ( i - 1 ) * math.floor( 22 * k ), CYAN, TEXT_ALIGN_RIGHT )
	end

	-- позывные союзников
	for _, ply in ipairs( player.GetAll() ) do
		if ply ~= lp and ply:Alive() and IsCombine( ply ) then
			local pos  = ply:EyePos() + Vector( 0, 0, 16 )
			local dist = lp:EyePos():Distance( pos )
			if dist < 1500 then
				local scr = pos:ToScreen()
				if scr.visible then
					UI.ShadowText( NWORK.Util.Upper( ply:GetCharName() ), "Nwork.Combine", scr.x, scr.y,
						Color( CYAN.r, CYAN.g, CYAN.b, 220 * math.Clamp( 1 - dist / 1500, 0.3, 1 ) ),
						TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
				end
			end
		end
	end
end )
