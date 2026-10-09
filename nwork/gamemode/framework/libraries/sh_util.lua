--[[-------------------------------------------------------------------------
	N-work — утилиты.
---------------------------------------------------------------------------]]

NWORK.Util = NWORK.Util or {}
local U = NWORK.Util

local C_TAG = Color( 205, 72, 62 )

function NWORK.Print( ... )
	MsgC( C_TAG, "[N-work] ", color_white, table.concat( { ... }, " " ), "\n" )
end

-- Символы UTF-8 строки по одному (для разрядки текста и т.п.)
function U.Chars( text )
	local out = {}
	for _, code in utf8.codes( text ) do
		out[ #out + 1 ] = utf8.char( code )
	end
	return out
end

function U.Len( text )
	return utf8.len( text ) or #text
end

-- Обрезать строку до n символов UTF-8
function U.Sub( text, n )
	if U.Len( text ) <= n then return text end
	local pos = utf8.offset( text, n + 1 )
	return pos and string.sub( text, 1, pos - 1 ) or text
end

-- string.lower не понимает кириллицу — переводим вручную
local LOWER = {}
for code = 0x0410, 0x042F do LOWER[ utf8.char( code ) ] = utf8.char( code + 32 ) end
LOWER[ "Ё" ] = "ё"

function U.Lower( text )
	text = string.lower( text )
	return ( string.gsub( text, "[\208\209][\128-\191]", LOWER ) )
end

local UPPER = {}
for k, v in pairs( LOWER ) do UPPER[ v ] = k end

function U.Upper( text )
	text = string.upper( text )
	return ( string.gsub( text, "[\208\209][\128-\191]", UPPER ) )
end

-- Разбор аргументов команды с учётом кавычек: a "b c" d -> { a, b c, d }
function U.ParseArgs( str )
	local args = {}
	local i, n = 1, #str

	while i <= n do
		local c = string.sub( str, i, i )

		if c == "\"" then
			local j = string.find( str, "\"", i + 1, true ) or ( n + 1 )
			args[ #args + 1 ] = string.sub( str, i + 1, j - 1 )
			i = j + 1
		elseif string.match( c, "%s" ) then
			i = i + 1
		else
			local j = string.find( str, "%s", i ) or ( n + 1 )
			args[ #args + 1 ] = string.sub( str, i, j - 1 )
			i = j
		end
	end

	return args
end

-- Найти игрока по части имени персонажа, ника или SteamID
function U.FindPlayer( query )
	if not query or query == "" then return end

	local q = U.Lower( query )

	for _, ply in ipairs( player.GetAll() ) do
		if ply:SteamID() == query or ply:SteamID64() == query then return ply end
	end

	for _, ply in ipairs( player.GetAll() ) do
		if string.find( U.Lower( ply:GetCharName() ), q, 1, true )
			or string.find( U.Lower( ply:Nick() ), q, 1, true ) then
			return ply
		end
	end
end

-- Точка в конце фразы, если игрок не поставил знак сам
function U.Period( text )
	if string.match( text, "[%.!%?]$" ) or string.EndsWith( text, "…" ) then
		return text
	end
	return text .. "."
end
