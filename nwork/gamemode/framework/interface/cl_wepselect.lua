--[[-------------------------------------------------------------------------
	N-work — селектор оружия.

	Слева столбик слотов [1]..[6]; активный слот подсвечен, справа от
	него плашка с именем оружия и патронами (∞ у холодного). Колесо и
	клавиши 1-6 листают, клик (атака) — взять. Стандартная панель
	выбора спрятана.
---------------------------------------------------------------------------]]

local T = NWORK.Theme

local showUntil = 0
local curSlot   = 1
local curIdx    = 1

hook.Add( "HUDShouldDraw", "Nwork.HideWepSelect", function( name )
	if name == "CHudWeaponSelection" then return false end
end )

local function Buckets()
	local b = { {}, {}, {}, {}, {}, {} }

	for _, w in ipairs( LocalPlayer():GetWeapons() ) do
		local s = math.Clamp( ( w:GetSlot() or 0 ) + 1, 1, 6 )
		b[ s ][ #b[ s ] + 1 ] = w
	end

	for _, list in ipairs( b ) do
		table.sort( list, function( a, c ) return ( a:GetSlotPos() or 0 ) < ( c:GetSlotPos() or 0 ) end )
	end

	return b
end

local function Flat( b )
	local out = {}
	for s = 1, 6 do
		for i, w in ipairs( b[ s ] ) do
			out[ #out + 1 ] = { s = s, i = i, w = w }
		end
	end
	return out
end

local function Step( dir )
	local b = Buckets()
	local flat = Flat( b )
	if #flat == 0 then return end

	local at = 1
	for idx, e in ipairs( flat ) do
		if e.s == curSlot and e.i == curIdx then at = idx break end
	end

	local e = flat[ ( ( at - 1 + dir ) % #flat ) + 1 ]
	curSlot, curIdx = e.s, e.i
	showUntil = CurTime() + 3
	surface.PlaySound( "common/wpn_moveselect.wav" )
end

hook.Add( "PlayerBindPress", "Nwork.WepSelect", function( _, bind, pressed )
	if not pressed then return end
	if NWORK.UI.Active() then return end

	local lp = LocalPlayer()
	if not IsValid( lp ) or not lp:Alive() then return end

	if bind == "invnext" then Step( 1 ) return true end
	if bind == "invprev" then Step( -1 ) return true end

	local slot = string.match( bind, "^slot([1-6])$" )
	if slot then
		slot = tonumber( slot )
		local b = Buckets()
		if #b[ slot ] == 0 then return true end

		if curSlot == slot and showUntil > CurTime() then
			curIdx = ( curIdx % #b[ slot ] ) + 1
		else
			curSlot, curIdx = slot, 1
		end

		showUntil = CurTime() + 3
		surface.PlaySound( "common/wpn_moveselect.wav" )
		return true
	end

	if bind == "+attack" and showUntil > CurTime() then
		local b = Buckets()
		local w = b[ curSlot ] and b[ curSlot ][ curIdx ]
		if IsValid( w ) then
			input.SelectWeapon( w )
			surface.PlaySound( "common/wpn_select.wav" )
		end
		showUntil = 0
		return true
	end
end )

hook.Add( "HUDPaint", "Nwork.WepSelectDraw", function()
	if showUntil < CurTime() then return end
	if NWORK.UI.Active() then return end

	local k = ScrH() / 1080
	local b = Buckets()

	local box = math.floor( 44 * k )
	local gap = math.floor( 12 * k )
	local x   = math.floor( 56 * k )
	local y0  = math.floor( ScrH() / 2 - ( box * 6 + gap * 5 ) / 2 )

	for s = 1, 6 do
		local y = y0 + ( s - 1 ) * ( box + gap )
		local has = #b[ s ] > 0
		local active = s == curSlot and has

		draw.RoundedBox( 4, x, y, box, box, Color( 18, 20, 22, active and 225 or 150 ) )
		surface.SetDrawColor( 255, 255, 255, active and 200 or ( has and 60 or 22 ) )
		surface.DrawOutlinedRect( x, y, box, box, 1 )

		draw.SimpleText( "[" .. s .. "]", "Nwork.WepSlot", x + box / 2, y + box / 2,
			Color( 235, 238, 242, active and 255 or ( has and 170 or 70 ) ),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

		-- плашка с именем у активного слота
		if active then
			local w = b[ s ][ math.Clamp( curIdx, 1, #b[ s ] ) ]
			if IsValid( w ) then
				local name = language.GetPhrase( w:GetPrintName() or w:GetClass() )
				local pw   = math.floor( 230 * k )

				draw.RoundedBox( 4, x + box + gap, y, pw, box, Color( 18, 20, 22, 225 ) )
				surface.SetDrawColor( 255, 255, 255, 60 )
				surface.DrawOutlinedRect( x + box + gap, y, pw, box, 1 )

				draw.SimpleText( name, "Nwork.WepName",
					x + box + gap + math.floor( 12 * k ), y + math.floor( 5 * k ),
					Color( 235, 238, 242 ) )

				local clip = w:Clip1() or -1
				draw.SimpleText( clip < 0 and "∞" or tostring( clip ), "Nwork.WepAmmo",
					x + box + gap + math.floor( 12 * k ), y + box - math.floor( 17 * k ),
					Color( 170, 176, 184 ) )
			end
		end
	end
end )
