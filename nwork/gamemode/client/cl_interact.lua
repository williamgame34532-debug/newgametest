--[[-------------------------------------------------------------------------
	N-work — взаимодействие (клиент).

	Подсказка у прицела: тёмно-серая плашка с клавишей [E] и текстом:
		предмет   ->  Взять «Название»
		дверь     ->  Взаимодействовать с дверью
		энтити    ->  Взаимодействовать

	По E на предмете открывается одна полупрозрачная кнопка «Взять» —
	клик подбирает предмет.
---------------------------------------------------------------------------]]

local DOORS = {
	[ "prop_door_rotating" ] = true,
	[ "func_door" ]          = true,
	[ "func_door_rotating" ] = true,
}

local POPUP
local hintAlpha = 0
local hintText  = ""

local function Target()
	local lp = LocalPlayer()
	if not IsValid( lp ) or not lp:Alive() then return end

	local tr = util.TraceLine( {
		start  = lp:EyePos(),
		endpos = lp:EyePos() + lp:GetAimVector() * 110,
		filter = lp,
	} )

	local ent = tr.Entity
	if not IsValid( ent ) or ent:IsPlayer() then return end

	return ent
end

local function LabelFor( ent )
	local class = ent:GetClass()

	if class == "nwork_item" then
		local def = NWORK.Items[ ent:GetItemID() ]
		local n   = ent:GetAmount()
		return "Взять «" .. ( def and def.Name or "Предмет" ) .. ( n > 1 and ( "» x" .. n ) or "»" )
	end

	if DOORS[ class ] then
		return "Взаимодействовать с дверью"
	end

	return "Взаимодействовать"
end

----------------------------------------------------------------- отрисовка

hook.Add( "HUDPaint", "Nwork.InteractHint", function()
	if NWORK.UI.Active() then return end

	local ent = ( not IsValid( POPUP ) ) and Target() or nil

	if ent then hintText = LabelFor( ent ) end
	hintAlpha = Lerp( FrameTime() * 10, hintAlpha, ent and 1 or 0 )

	if hintAlpha < 0.03 or hintText == "" then return end

	local w, h = ScrW(), ScrH()
	local k = h / 1080
	local a = hintAlpha

	surface.SetFont( "Nwork.Small" )
	local tw = surface.GetTextSize( hintText )

	local key  = math.floor( 30 * k )
	local pad  = math.floor( 10 * k )
	local bw   = key + pad * 3 + tw
	local bh   = key + pad * 2
	local x, y = math.floor( ( w - bw ) / 2 ), math.floor( h * 0.60 )

	-- тёмно-серая плашка
	draw.RoundedBox( 6, x, y, bw, bh, Color( 28, 31, 35, 215 * a ) )

	-- клавиша E
	draw.RoundedBox( 4, x + pad, y + pad, key, key, Color( 52, 56, 61, 235 * a ) )
	surface.SetDrawColor( 255, 255, 255, 70 * a )
	surface.DrawOutlinedRect( x + pad, y + pad, key, key, 1 )
	draw.SimpleText( "E", "Nwork.WepSlot", x + pad + key / 2, y + pad + key / 2,
		Color( 240, 243, 247, 255 * a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

	draw.SimpleText( hintText, "Nwork.Small", x + pad * 2 + key, y + bh / 2,
		Color( 226, 231, 237, 240 * a ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
end )

------------------------------------------------------------- кнопка «Взять»

local function OpenPickup( ent )
	if IsValid( POPUP ) then POPUP:Remove() end

	local k = ScrH() / 1080
	local bw, bh = math.floor( 200 * k ), math.floor( 44 * k )

	POPUP = vgui.Create( "DButton" )
	POPUP:SetText( "" )
	POPUP:SetSize( bw, bh )
	POPUP:SetPos( math.floor( ( ScrW() - bw ) / 2 ), math.floor( ScrH() * 0.58 ) )
	POPUP:MakePopup()
	POPUP:SetKeyboardInputEnabled( false )

	POPUP.Ent     = ent
	POPUP.Expire  = CurTime() + 5

	POPUP.Paint = function( s, w, h )
		local hov = s:IsHovered()

		-- чуть прозрачная плашка в общем стиле
		draw.RoundedBox( 6, 0, 0, w, h, Color( 20, 22, 25, hov and 205 or 165 ) )

		surface.SetDrawColor( 255, 255, 255, s:IsDown() and 235 or ( hov and 70 or 30 ) )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )

		draw.SimpleText( "Взять", "Nwork.Button", w / 2, h / 2,
			Color( 240, 243, 247, 235 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end

	POPUP.DoClick = function( s )
		if IsValid( s.Ent ) then
			net.Start( "nwork_item_take" )
				net.WriteEntity( s.Ent )
			net.SendToServer()
		end
		s:Remove()
	end

	POPUP.Think = function( s )
		local lp = LocalPlayer()
		if not IsValid( s.Ent )
			or CurTime() > s.Expire
			or input.IsKeyDown( KEY_ESCAPE )
			or lp:GetPos():DistToSqr( s.Ent:GetPos() ) > 140 * 140 then
			s:Remove()
		end
	end
end

hook.Add( "PlayerBindPress", "Nwork.InteractUse", function( _, bind, pressed )
	if not pressed or bind ~= "+use" then return end
	if NWORK.UI.Active() then return end

	if IsValid( POPUP ) then
		POPUP:Remove()
		return true
	end

	local ent = Target()
	if IsValid( ent ) and ent:GetClass() == "nwork_item" then
		OpenPickup( ent )
		return true
	end
end )
