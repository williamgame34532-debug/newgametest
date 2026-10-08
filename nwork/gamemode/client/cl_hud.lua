--[[-------------------------------------------------------------------------
	N-work — HUD в стиле референса.

	* стандартный HL2-худ (здоровье/броня/патроны) спрятан;
	* прицел — маленькая белая точка;
	* слева сверху — локация и время (курсивом, полупрозрачно);
	* при наведении на игрока — карточка: рамка с «?», имя персонажа,
	  под ним фракция;
	* справа снизу — логотип-материал nwork/watermark.png (стиль
	  PROJECT SYNAPSE), без материала — текстовый λ-вотермарк.
---------------------------------------------------------------------------]]

local T = NWORK.Theme

local HIDE = {
	CHudHealth        = true,
	CHudBattery       = true,
	CHudAmmo          = true,
	CHudSecondaryAmmo = true,
	CHudCrosshair     = true,
}

hook.Add( "HUDShouldDraw", "Nwork.HideHL2HUD", function( name )
	if HIDE[ name ] then return false end
end )

------------------------------------------------------------------ неймплейт

local iconCache = {}

function NWORK.GetFactionIcon( key )
	local f = NWORK.Factions[ key ]
	if not f or not f.Icon then return nil end

	if iconCache[ key ] == nil then
		local m = Material( f.Icon, "smooth" )
		iconCache[ key ] = ( m and not m:IsError() ) and m or false
	end

	return iconCache[ key ] or nil
end

local tgtAlpha = 0
local tgtPly   = nil

local function DrawNameplate()
	local lp = LocalPlayer()

	local tr = util.TraceLine( {
		start  = lp:EyePos(),
		endpos = lp:EyePos() + lp:GetAimVector() * 260,
		filter = lp,
	} )

	local ent   = tr.Entity
	local valid = IsValid( ent ) and ent:IsPlayer()

	if valid then tgtPly = ent end
	tgtAlpha = Lerp( FrameTime() * 8, tgtAlpha, valid and 1 or 0 )

	if tgtAlpha < 0.02 or not IsValid( tgtPly ) then return end

	local k = ScrH() / 1080
	local a = tgtAlpha

	local head = tgtPly:LookupBone( "ValveBiped.Bip01_Head1" )
	local wpos = head and tgtPly:GetBonePosition( head ) or tgtPly:EyePos()
	local scr  = ( wpos + Vector( 0, 0, 8 ) ):ToScreen()

	local box  = math.floor( 76 * k )
	local x, y = scr.x + math.floor( 44 * k ), scr.y - box / 2

	local fkey = tgtPly:GetNWString( "nwork_faction", "citizen" )
	local fac  = NWORK.Factions[ fkey ]

	-- светящаяся плашка с иконкой фракции
	surface.SetDrawColor( 244, 246, 248, 26 * a )
	surface.DrawRect( x, y, box, box )
	surface.SetDrawColor( 244, 246, 248, 190 * a )
	surface.DrawOutlinedRect( x, y, box, box, 1 )

	local icon = NWORK.GetFactionIcon( fkey )
	if icon then
		local pad = math.floor( 8 * k )
		surface.SetMaterial( icon )
		-- лёгкое свечение + сама иконка
		surface.SetDrawColor( 255, 255, 255, 70 * a )
		surface.DrawTexturedRect( x + pad - 2, y + pad - 2, box - pad * 2 + 4, box - pad * 2 + 4 )
		surface.SetDrawColor( 255, 255, 255, 235 * a )
		surface.DrawTexturedRect( x + pad, y + pad, box - pad * 2, box - pad * 2 )
	else
		draw.SimpleText( fac and fac.Initials or "?", "Nwork.PlateInit",
			x + box / 2, y + box / 2, Color( 240, 243, 247, 235 * a ),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end

	-- имя и фракция
	local name = NWORK.CharName( tgtPly )
	local tx   = x + box + math.floor( 20 * k )

	draw.SimpleText( name, "Nwork.PlateName", tx, y - math.floor( 4 * k ),
		Color( 226, 232, 238, 250 * a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
	draw.SimpleText( fac and fac.Name or fkey, "Nwork.PlateSub", tx, y + math.floor( 42 * k ),
		Color( 196, 204, 212, 220 * a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
end

-- F3 — представиться окружающим
hook.Add( "PlayerBindPress", "Nwork.Introduce", function( _, bind, pressed )
	if not pressed or bind ~= "gm_showspare1" then return end
	if NWORK.UI.Active() then return true end

	net.Start( "nwork_introduce" )
	net.SendToServer()
	return true
end )

--------------------------------------------------------------------- вотермарк

local wmMat

local function DrawWatermarkMat( w, h, k )
	local wm = T.Watermark
	if not wm.Mat then return false end

	if wmMat == nil then
		local m = Material( wm.Mat, "smooth mips" )
		wmMat = ( m and not m:IsError() ) and m or false
	end
	if not wmMat then return false end

	local mw = math.floor( ( wm.MatWidth or 300 ) * k )
	local mh = math.floor( mw * wmMat:Height() / math.max( 1, wmMat:Width() ) )

	surface.SetMaterial( wmMat )
	surface.SetDrawColor( 255, 255, 255, wm.MatAlpha or 170 )
	surface.DrawTexturedRect( w - mw - math.floor( 28 * k ), h - mh - math.floor( 22 * k ), mw, mh )
	return true
end

--------------------------------------------------------------------- отрисовка

hook.Add( "HUDPaint", "Nwork.HUD", function()
	if NWORK.UI.Active() then return end

	local w, h = ScrW(), ScrH()
	local k = h / 1080

	-- дот-прицел
	surface.SetDrawColor( 240, 243, 247, 200 )
	surface.DrawRect( w / 2 - 1, h / 2 - 1, 2, 2 )

	-- локация и время
	local wm = T.Watermark
	draw.SimpleText( wm.Location or game.GetMap(), "Nwork.Location",
		math.floor( 16 * k ), math.floor( h * 0.58 ),
		Color( 210, 214, 220, 170 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
	draw.SimpleText( os.date( "%H:%M" ), "Nwork.LocationSub",
		math.floor( 16 * k ), math.floor( h * 0.58 + 26 * k ),
		Color( 190, 194, 200, 140 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )

	DrawNameplate()

	-- вотермарк: логотип-материал, если есть, иначе текстовый
	if wm.Enabled and DrawWatermarkMat( w, h, k ) then
		-- нарисован материал
	elseif wm.Enabled then
		local x = w - math.floor( 24 * k )
		local y = h - math.floor( 30 * k )

		local wc = wm.Color or Color( 190, 120, 50 )
		draw.SimpleText( wm.Title, "Nwork.Watermark", x, y - math.floor( 14 * k ),
			Color( wc.r, wc.g, wc.b, 190 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )
		draw.SimpleText( wm.Sub, "Nwork.WatermarkSub", x, y + math.floor( 4 * k ),
			Color( 150, 150, 150, 120 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )

		surface.SetFont( "Nwork.Watermark" )
		local tw = surface.GetTextSize( wm.Title )
		draw.SimpleText( "λ", "Nwork.WatermarkLambda",
			x - tw - math.floor( 12 * k ), y - math.floor( 8 * k ),
			Color( wc.r, wc.g, wc.b, 190 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )
	end
end )
