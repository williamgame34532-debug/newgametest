--[[-------------------------------------------------------------------------
	N-work — HUD в стиле Monarch.

	* прицел — маленькая точка;
	* слева сверху — статус-строки модулей («Вы устали.»), текущее
	  задание «? Заголовок / 《 подзадача» и уведомления;
	* неймплейт игрока: рамка с иконкой фракции (или «?»), крупное имя,
	  под ним фракция; у NPC — компактная плашка;
	* реплики над головами (чат-классы с Overhead) и микрофон над
	  говорящими в голосовой чат;
	* справа снизу — список говорящих и логотип-вотермарк;
	* экран смерти с отсчётом до возрождения.

	Модули добавляют строки слева сверху через хук:
		hook.Add( "NworkHUDStatus", "id", function( lines )
			lines[ #lines + 1 ] = { text = "Вы устали.", color = Color( ... ) }
		end )
	Задание — таблица NWORK.HUD.Objective = { Title = "...", Desc = "..." }.
---------------------------------------------------------------------------]]

local T  = NWORK.Theme
local O  = NWORK.Option
local UI = NWORK.UI

NWORK.HUD = NWORK.HUD or {}
local HUD = NWORK.HUD

local WHITE = Color( 240, 243, 247 )

local function Text( text, font, x, y, col, ax, ay )
	return UI.ShadowText( text, font, x, y, col, ax, ay )
end

-- точка над головой сущности в мире
local function HeadPos( ent )
	local bone = ent:LookupBone( "ValveBiped.Bip01_Head1" )
	if bone then
		local pos = ent:GetBonePosition( bone )
		if pos then return pos end
	end
	return ent:EyePos()
end

-- виден ли игрок (не за стеной)
local function Visible( ent, pos )
	local lp = LocalPlayer()
	local tr = util.TraceLine( {
		start  = lp:EyePos(),
		endpos = pos,
		filter = { lp, ent },
		mask   = MASK_VISIBLE,
	} )
	return not tr.Hit
end

------------------------------------------------------------- иконки фракций

local iconCache = {}

function NWORK.GetFactionIcon( key )
	local f = NWORK.Factions[ key ]
	if not f or not f.Icon then return nil end

	if iconCache[ key ] == nil then
		local m = Material( f.Icon, "smooth mips" )
		iconCache[ key ] = ( m and not m:IsError() ) and m or false
	end

	return iconCache[ key ] or nil
end

---------------------------------------------------------------- слева сверху

local function DrawTopLeft( w, h, k )
	local x = math.floor( 28 * k )
	local y = math.floor( 40 * k )

	-- статус-строки модулей
	local lines = {}
	hook.Run( "NworkHUDStatus", lines )

	for _, l in ipairs( lines ) do
		Text( l.text, "Nwork.Notice", math.floor( 58 * k ), y, l.color or WHITE )
		y = y + math.floor( 26 * k )
	end

	-- задание
	local obj = HUD.Objective
	if obj and obj.Title and obj.Title ~= "" and O.Get( "objective" ) then
		y = math.max( y + math.floor( 22 * k ), math.floor( 92 * k ) )

		Text( "?", "Nwork.ObjMark", x, y, WHITE )
		Text( obj.Title, "Nwork.ObjTitle", math.floor( 62 * k ), y, WHITE )
		y = y + math.floor( 40 * k )

		if obj.Desc and obj.Desc ~= "" then
			Text( "《 " .. obj.Desc, "Nwork.ObjSub", math.floor( 6 * k ), y, Color( 228, 232, 236 ) )
			y = y + math.floor( 28 * k )
		end
	end

	-- уведомления
	y = y + math.floor( 12 * k )
	for i = #NWORK.Notices, 1, -1 do
		local n = NWORK.Notices[ i ]
		local t = CurTime() - n.start
		if t > n.life + 0.6 then table.remove( NWORK.Notices, i ) end
	end

	for _, n in ipairs( NWORK.Notices ) do
		local t = CurTime() - n.start
		local a = math.Clamp( math.min( t / 0.2, ( n.life + 0.6 - t ) / 0.6 ), 0, 1 )

		local col = n.kind == "error" and Color( 232, 120, 110, 255 * a )
			or ( n.kind == "ok" and Color( 160, 214, 160, 255 * a ) or Color( 236, 238, 240, 255 * a ) )

		Text( n.text, "Nwork.Notice", math.floor( 58 * k ), y, col )
		y = y + math.floor( 26 * k )
	end
end

------------------------------------------------------------------ неймплейт

local tgtAlpha, tgtEnt = 0, nil

local function NPCName( ent )
	local npcs = list.Get( "NPC" )
	local cls  = ent:GetClass()
	for _, v in pairs( npcs ) do
		if v.Class == cls and v.Name then return language.GetPhrase( v.Name ) end
	end
	return language.GetPhrase( cls )
end

local function DrawNameplate( k )
	local lp = LocalPlayer()

	local tr = util.TraceLine( {
		start  = lp:EyePos(),
		endpos = lp:EyePos() + lp:GetAimVector() * 300,
		filter = lp,
		mask   = MASK_SHOT,
	} )

	local ent   = tr.Entity
	local valid = IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() ) and ( not ent:IsPlayer() or ent:Alive() )

	if valid then tgtEnt = ent end
	tgtAlpha = Lerp( FrameTime() * 8, tgtAlpha, valid and 1 or 0 )

	if tgtAlpha < 0.02 or not IsValid( tgtEnt ) then return end

	local a   = tgtAlpha
	local scr = ( HeadPos( tgtEnt ) + Vector( 0, 0, 6 ) ):ToScreen()

	if tgtEnt:IsNPC() then
		-- компактная плашка, как у Сталкера в референсе
		local box = math.floor( 40 * k )
		local x, y = scr.x + math.floor( 70 * k ), scr.y - box / 2

		surface.SetDrawColor( 244, 246, 248, 24 * a )
		surface.DrawRect( x, y, box, box )
		surface.SetDrawColor( 244, 246, 248, 170 * a )
		surface.DrawOutlinedRect( x, y, box, box, 1 )
		NWORK.Glyph( "question", x, y, box, Color( 240, 243, 247, 230 * a ) )

		local name = NPCName( tgtEnt )
		Text( name, "Nwork.PlateSmall", x + box + math.floor( 22 * k ), y - math.floor( 4 * k ),
			Color( 200, 204, 208, 230 * a ) )
		Text( name, "Nwork.PlateTiny", x + box + math.floor( 22 * k ), y + math.floor( 20 * k ),
			Color( 236, 238, 240, 220 * a ) )
		return
	end

	local box  = math.floor( 112 * k )
	local x, y = scr.x + math.floor( 64 * k ), scr.y - box / 2

	local fac   = tgtEnt:GetFactionTable()
	local known = NWORK.Character.Knows( tgtEnt )

	-- рамка с лёгкой подсветкой
	surface.SetDrawColor( 244, 246, 248, 22 * a )
	surface.DrawRect( x, y, box, box )
	surface.SetDrawColor( 220, 224, 230, 170 * a )
	surface.DrawOutlinedRect( x, y, box, box, 2 )

	local icon = fac and NWORK.GetFactionIcon( fac.id )
	local showIcon = icon and ( known or fac.ShowIcon )

	if showIcon then
		local pad = math.floor( 16 * k )
		surface.SetMaterial( icon )
		surface.SetDrawColor( 255, 255, 255, 60 * a )
		surface.DrawTexturedRect( x + pad - 2, y + pad - 2, box - pad * 2 + 4, box - pad * 2 + 4 )
		surface.SetDrawColor( 255, 255, 255, 240 * a )
		surface.DrawTexturedRect( x + pad, y + pad, box - pad * 2, box - pad * 2 )
	elseif known and fac then
		draw.SimpleText( fac.Initials, "Nwork.PlateInit", x + box / 2, y + box / 2,
			Color( 240, 243, 247, 240 * a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	else
		draw.SimpleText( "?", "Nwork.PlateMark", x + box / 2, y + box / 2,
			Color( 240, 243, 247, 245 * a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end

	local tx = x + box + math.floor( 30 * k )
	Text( NWORK.CharName( tgtEnt ), "Nwork.PlateName", tx, y + math.floor( 8 * k ),
		Color( 176, 190, 202, 250 * a ) )
	Text( fac and fac.Name or "", "Nwork.PlateSub", tx, y + math.floor( 58 * k ),
		Color( 240, 243, 247, 240 * a ) )
end

-------------------------------------------------- реплики и микрофон над головой

local OVERHEAD_LIFE = 6

local function DrawOverhead( k )
	local lp  = LocalPlayer()
	local eye = lp:EyePos()

	for ply, o in pairs( NWORK.Overhead ) do
		local t = CurTime() - o.time
		if not IsValid( ply ) or t > OVERHEAD_LIFE then
			NWORK.Overhead[ ply ] = nil
		elseif O.Get( "overhead" ) and ply:Alive() and not ply:GetNoDraw() then
			local pos  = HeadPos( ply ) + Vector( 0, 0, 14 )
			local dist = eye:Distance( pos )

			if dist < 600 and Visible( ply, pos ) then
				local a   = math.Clamp( math.min( t / 0.25, ( OVERHEAD_LIFE - t ) / 1 ), 0, 1 )
				a = a * math.Clamp( 1 - ( dist - 350 ) / 250, 0, 1 )

				local scr = pos:ToScreen()
				Text( NWORK.Util.Sub( o.text, 90 ), o.italic and "Nwork.OverheadIt" or "Nwork.Overhead",
					scr.x, scr.y, Color( 224, 228, 232, 210 * a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
			end
		end
	end

	-- микрофон над теми, кто говорит в голосовой чат
	for _, ply in ipairs( player.GetAll() ) do
		if ply ~= lp and ply:IsSpeaking() and ply:Alive() then
			local pos  = HeadPos( ply ) + Vector( 0, 0, 22 )
			local dist = eye:Distance( pos )

			if dist < 700 and Visible( ply, pos ) then
				local scr = pos:ToScreen()
				local s   = math.floor( math.Clamp( 90 * k * 220 / math.max( dist, 1 ), 26 * k, 90 * k ) )
				NWORK.Glyph( "mic", scr.x - s / 2, scr.y - s, s, Color( 240, 243, 247, 220 ) )
			end
		end
	end
end

------------------------------------------------------ голос и вотермарк справа

local function MicBadge( cx, cy, r, alpha )
	draw.RoundedBox( r, cx - r, cy - r, r * 2, r * 2, Color( 40, 43, 47, 170 * alpha ) )
	NWORK.Glyph( "mic", cx - r * 0.7, cy - r * 0.7, r * 1.4, Color( 240, 243, 247, 230 * alpha ) )
end

local function DrawRight( w, h, k )
	local right = w - math.floor( 40 * k )
	local y     = h - math.floor( 220 * k )
	local r     = math.floor( 17 * k )

	-- сам игрок: «Говорит» + микрофон
	local lp = LocalPlayer()
	if lp:IsSpeaking() then
		MicBadge( right - r, y, r, 1 )
		Text( "Говорит", "Nwork.Voice", right - r * 2 - math.floor( 12 * k ), y, WHITE,
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		y = y - math.floor( 52 * k )
	end

	-- остальные: микрофон + имя
	for _, ply in ipairs( player.GetAll() ) do
		if ply ~= lp and ply:IsSpeaking() then
			local name = NWORK.CharName( ply )
			surface.SetFont( "Nwork.Voice" )
			local tw = surface.GetTextSize( name )

			local tx = right - tw
			MicBadge( tx - math.floor( 14 * k ) - r, y, r, 1 )
			Text( name, "Nwork.Voice", tx, y, WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			y = y - math.floor( 44 * k )
		end
	end

	-- логотип-вотермарк
	local wm = T.Watermark
	if not O.Get( "watermark" ) then return end

	local mw = math.floor( ( wm.MatWidth or 300 ) * k )
	if UI.WordmarkMat() then
		local m  = UI.WordmarkMat()
		local mh = math.floor( mw * m:Height() / math.max( 1, m:Width() ) )
		UI.Wordmark( w - mw - math.floor( 28 * k ), h - mh - math.floor( 22 * k ), mw, wm.MatAlpha or 150 )
		return
	end

	-- запасной текстовый вариант
	local x  = w - math.floor( 24 * k )
	local by = h - math.floor( 30 * k )
	local wc = wm.Color
	draw.SimpleText( wm.Title, "Nwork.Watermark", x, by - math.floor( 14 * k ),
		Color( wc.r, wc.g, wc.b, 190 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )
	draw.SimpleText( wm.Sub, "Nwork.WatermarkSub", x, by + math.floor( 4 * k ),
		Color( 150, 150, 150, 120 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )
end

------------------------------------------------------------------ смерть

local deadSince

local function DrawDeath( w, h, k )
	local lp = LocalPlayer()

	if lp:Alive() or not lp:HasCharacter() then
		deadSince = nil
		return false
	end

	deadSince = deadSince or CurTime()
	local t = CurTime() - deadSince
	local a = math.Clamp( t / 1.5, 0, 1 )

	surface.SetDrawColor( 0, 0, 0, 235 * a )
	surface.DrawRect( 0, 0, w, h )

	local left = math.ceil( NWORK.Config.RespawnTime - t )
	draw.SimpleText( "ВЫ БЕЗ СОЗНАНИЯ", "Nwork.TabHead", w / 2, h * 0.46,
		Color( 240, 243, 247, 255 * a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	draw.SimpleText( left > 0 and ( "Возрождение через " .. left .. " с." ) or "Нажмите любую клавишу, чтобы очнуться.",
		"Nwork.Notice", w / 2, h * 0.46 + math.floor( 40 * k ),
		Color( 190, 194, 198, 230 * a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	return true
end

--------------------------------------------------------------------- отрисовка

hook.Add( "HUDPaint", "Nwork.HUD", function()
	if UI.Active() then return end
	if NWORK.TabOpen and NWORK.TabOpen() then return end

	local w, h = ScrW(), ScrH()
	local k = h / 1080

	if DrawDeath( w, h, k ) then return end

	if O.Get( "crosshair" ) then
		surface.SetDrawColor( 240, 243, 247, 200 )
		surface.DrawRect( w / 2 - 1, h / 2 - 1, 2, 2 )
	end

	DrawOverhead( k )
	DrawNameplate( k )
	DrawTopLeft( w, h, k )
	DrawRight( w, h, k )

	hook.Run( "NworkHUDPaint", w, h, k )
end )
