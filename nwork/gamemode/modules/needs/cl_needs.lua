--[[-------------------------------------------------------------------------
	Нужды (клиент): полосы в меню персонажа, значки эффектов и
	статус-строка слева сверху («Вы чувствуете усталость.»).
---------------------------------------------------------------------------]]

local N = NWORK.Needs

hook.Add( "NworkTabStats", "Nwork.Needs", function( list )
	local lp = LocalPlayer()
	for _, n in ipairs( N.List ) do
		local v = N.Get( lp, n.id )
		list[ #list + 1 ] = { label = n.Labels[ N.Stage( v ) ], frac = v / 100, color = n.Color }
	end
end )

hook.Add( "NworkTabEffects", "Nwork.Needs", function( list )
	local lp = LocalPlayer()
	for _, n in ipairs( N.List ) do
		if N.Stage( N.Get( lp, n.id ) ) >= 2 then
			list[ #list + 1 ] = { glyph = n.Glyph, color = n.Color }
		end
	end
end )

-- одна строка — самая острая нужда
hook.Add( "NworkHUDStatus", "Nwork.Needs", function( lines )
	local lp = LocalPlayer()
	if not lp:HasCharacter() then return end

	local worst, text = 2, nil
	for _, n in ipairs( N.List ) do
		local st = N.Stage( N.Get( lp, n.id ) )
		if st >= worst and n.Status[ st ] then worst, text = st, n.Status[ st ] end
	end

	if text then
		lines[ #lines + 1 ] = { text = text, color = worst >= 4 and Color( 232, 150, 140 ) or nil }
	end
end )
