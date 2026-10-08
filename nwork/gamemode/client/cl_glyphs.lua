--[[-------------------------------------------------------------------------
	N-work — векторные глифы интерфейса.

	Иконки в стиле референса (белые силуэты): экипировка, навигация,
	заголовки. Рисуются примитивами, масштабируются от size.

	NWORK.Glyph( name, x, y, size, color [, holeColor] )
---------------------------------------------------------------------------]]

local COL

local function rect( x, y, w, h, r )
	if r and r > 0 then
		draw.RoundedBox( r, x, y, w, h, COL )
	else
		surface.SetDrawColor( COL )
		surface.DrawRect( x, y, w, h )
	end
end

local function rrect( cx, cy, w, h, ang )
	surface.SetDrawColor( COL )
	draw.NoTexture()
	surface.DrawTexturedRectRotated( cx, cy, w, h, ang )
end

local function circle( cx, cy, r )
	local pts = {}
	for i = 0, 20 do
		local a = math.rad( i / 20 * 360 )
		pts[ #pts + 1 ] = { x = cx + math.cos( a ) * r, y = cy + math.sin( a ) * r }
	end
	surface.SetDrawColor( COL )
	draw.NoTexture()
	surface.DrawPoly( pts )
end

local function ring( cx, cy, r, th )
	for i = 0, th - 1 do
		surface.DrawCircle( cx, cy, r - i, COL )
	end
end

local G = {}

G.helmet = function( x, y, s )
	local pts = {}
	for i = 0, 12 do
		local a = math.rad( 180 + i / 12 * 180 )
		pts[ #pts + 1 ] = { x = x + s / 2 + math.cos( a ) * s * 0.38, y = y + s * 0.55 + math.sin( a ) * s * 0.42 }
	end
	surface.SetDrawColor( COL )
	draw.NoTexture()
	surface.DrawPoly( pts )
	rect( x + s * 0.02, y + s * 0.52, s * 0.96, s * 0.14, 2 )
end

G.glasses = function( x, y, s )
	surface.SetDrawColor( COL )
	local ly = y + s * 0.34
	rect( x, ly, s * 0.40, s * 0.30, 3 )
	rect( x + s * 0.60, ly, s * 0.40, s * 0.30, 3 )
	rect( x + s * 0.38, ly + s * 0.04, s * 0.24, s * 0.08 )
end

G.gasmask = function( x, y, s )
	circle( x + s / 2, y + s * 0.42, s * 0.38 )
	rect( x + s * 0.34, y + s * 0.66, s * 0.32, s * 0.30, 4 )
end

G.shirt = function( x, y, s )
	rect( x + s * 0.28, y + s * 0.10, s * 0.44, s * 0.82, 3 )
	rrect( x + s * 0.18, y + s * 0.30, s * 0.30, s * 0.16, 25 )
	rrect( x + s * 0.82, y + s * 0.30, s * 0.30, s * 0.16, -25 )
end

G.shield = function( x, y, s )
	surface.SetDrawColor( COL )
	draw.NoTexture()
	surface.DrawPoly( {
		{ x = x + s * 0.14, y = y + s * 0.12 },
		{ x = x + s * 0.86, y = y + s * 0.12 },
		{ x = x + s * 0.86, y = y + s * 0.55 },
		{ x = x + s * 0.50, y = y + s * 0.92 },
		{ x = x + s * 0.14, y = y + s * 0.55 },
	} )
end

G.gloves = function( x, y, s )
	rect( x + s * 0.30, y + s * 0.30, s * 0.42, s * 0.55, 4 )
	for i = 0, 2 do
		rect( x + s * 0.32 + i * s * 0.14, y + s * 0.10, s * 0.10, s * 0.24, 2 )
	end
	rrect( x + s * 0.24, y + s * 0.48, s * 0.22, s * 0.11, 40 )
end

G.knife = function( x, y, s )
	surface.SetDrawColor( COL )
	draw.NoTexture()
	surface.DrawPoly( {
		{ x = x + s * 0.78, y = y + s * 0.08 },
		{ x = x + s * 0.92, y = y + s * 0.26 },
		{ x = x + s * 0.42, y = y + s * 0.66 },
		{ x = x + s * 0.32, y = y + s * 0.52 },
	} )
	rrect( x + s * 0.30, y + s * 0.66, s * 0.30, s * 0.10, 45 )
	rrect( x + s * 0.20, y + s * 0.78, s * 0.26, s * 0.14, 45 )
end

G.pants = function( x, y, s )
	rect( x + s * 0.24, y + s * 0.10, s * 0.52, s * 0.16 )
	rect( x + s * 0.24, y + s * 0.26, s * 0.20, s * 0.64, 2 )
	rect( x + s * 0.56, y + s * 0.26, s * 0.20, s * 0.64, 2 )
end

G.pistol = function( x, y, s )
	rect( x + s * 0.12, y + s * 0.28, s * 0.72, s * 0.20, 3 )
	rrect( x + s * 0.34, y + s * 0.62, s * 0.18, s * 0.42, 15 )
	rect( x + s * 0.52, y + s * 0.46, s * 0.14, s * 0.10 )
end

G.boots = function( x, y, s )
	rect( x + s * 0.16, y + s * 0.14, s * 0.24, s * 0.50 )
	rect( x + s * 0.16, y + s * 0.56, s * 0.42, s * 0.20, 2 )
	rect( x + s * 0.56, y + s * 0.30, s * 0.22, s * 0.34 )
	rect( x + s * 0.56, y + s * 0.56, s * 0.38, s * 0.20, 2 )
end

G.rifle = function( x, y, s )
	rrect( x + s * 0.50, y + s * 0.42, s * 0.92, s * 0.13, -12 )
	rrect( x + s * 0.18, y + s * 0.60, s * 0.22, s * 0.16, -12 )
	rrect( x + s * 0.52, y + s * 0.62, s * 0.12, s * 0.26, 8 )
end

G.backpack = function( x, y, s )
	rect( x + s * 0.16, y + s * 0.20, s * 0.68, s * 0.70, math.floor( s * 0.12 ) )
	rect( x + s * 0.34, y + s * 0.06, s * 0.32, s * 0.18, math.floor( s * 0.08 ) )
	rect( x + s * 0.30, y + s * 0.54, s * 0.40, s * 0.28, 3 )
	rect( x + s * 0.30, y + s * 0.62, s * 0.40, s * 0.05 )
end

G.people = function( x, y, s )
	local function man( cx, top, k )
		circle( cx, y + top + s * 0.10 * k, s * 0.10 * k )
		rect( cx - s * 0.13 * k, y + top + s * 0.20 * k, s * 0.26 * k, s * 0.34 * k, 3 )
	end
	man( x + s * 0.24, s * 0.28, 0.85 )
	man( x + s * 0.76, s * 0.28, 0.85 )
	man( x + s * 0.50, s * 0.14, 1.1 )
end

G.gear = function( x, y, s, hole )
	local cx, cy, r = x + s / 2, y + s / 2, s * 0.30
	for i = 0, 5 do
		rrect( cx + math.cos( math.rad( i * 60 ) ) * r, cy + math.sin( math.rad( i * 60 ) ) * r,
			s * 0.18, s * 0.18, i * 60 )
	end
	circle( cx, cy, r )
	if hole then
		local old = COL
		COL = hole
		circle( cx, cy, r * 0.45 )
		COL = old
	end
end

G.arrow = function( x, y, s )
	surface.SetDrawColor( COL )
	draw.NoTexture()
	surface.DrawPoly( {
		{ x = x + s * 0.50, y = y + s * 0.08 },
		{ x = x + s * 0.86, y = y + s * 0.88 },
		{ x = x + s * 0.50, y = y + s * 0.66 },
		{ x = x + s * 0.14, y = y + s * 0.88 },
	} )
end

G.stats = function( x, y, s )
	rect( x + s * 0.16, y + s * 0.52, s * 0.16, s * 0.36 )
	rect( x + s * 0.42, y + s * 0.32, s * 0.16, s * 0.56 )
	rect( x + s * 0.68, y + s * 0.14, s * 0.16, s * 0.74 )
end

function NWORK.Glyph( name, x, y, size, color, hole )
	local fn = G[ name ]
	if not fn then return end

	COL = color or color_white
	fn( x, y, size, hole )
end
