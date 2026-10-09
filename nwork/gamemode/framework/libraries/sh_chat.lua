--[[-------------------------------------------------------------------------
	N-work — чат-классы.

	Каждый тип речи — класс с префиксами, дистанцией и форматом строки:

	NWORK.Chat.Register( "me", {
		Prefix   = { "/me" },
		Range    = "me",                     -- ключ C.ChatRange, число или nil (всем)
		Font     = "Nwork.ChatItalic",
		Desc     = "Действие от лица персонажа.",
		Overhead = true,                     -- показать текст над головой
		AllowEmpty = true,                   -- можно без текста (/roll)
		CanSay   = function( ply, text ) end,         -- сервер, false — запретить
		OnSay    = function( ply, text ) return text end, -- сервер, изменить текст
		Format   = function( speaker, text, name ) return цвет, "текст", ... end,
	} )

	Сервер перехватывает PlayerSay, определяет класс по префиксу, рассылает
	сообщение тем, кто в радиусе, и печатает в консоль. Клиент собирает
	строку через Format (имя — с учётом знакомств) и кладёт в чат-бокс.
	Сообщение без префикса — класс "ic". «/что-то» без класса — команда.
---------------------------------------------------------------------------]]

NWORK.ChatClasses = NWORK.ChatClasses or {}
NWORK.Chat        = NWORK.Chat or {}

local CH = NWORK.Chat
local U  = NWORK.Util

-- палитра строк — как в Monarch
CH.Colors = {
	Name    = Color( 146, 156, 158 ),
	Text    = Color( 236, 238, 240 ),
	Emote   = Color( 232, 226, 190 ),
	Whisper = Color( 196, 200, 206 ),
	Radio   = Color( 92, 204, 236 ),
	OOC     = Color( 205, 72, 62 ),
	OOCText = Color( 190, 194, 198 ),
	Event   = Color( 236, 200, 120 ),
	System  = Color( 168, 172, 178 ),
}

-- маркер смены шрифта внутри строки
function CH.Font( font ) return { nworkFont = font } end

local PREFIXES = {}   -- { prefix, id }, длинные первыми

local function Rebuild()
	PREFIXES = {}
	for id, def in pairs( NWORK.ChatClasses ) do
		for _, p in ipairs( def.Prefix ) do
			PREFIXES[ #PREFIXES + 1 ] = { p = string.lower( p ), id = id }
		end
	end
	table.sort( PREFIXES, function( a, b ) return #a.p > #b.p end )
end

function CH.Register( id, def )
	def.id     = id
	def.Prefix = def.Prefix or {}
	def.Font   = def.Font or "Nwork.Chat"

	NWORK.ChatClasses[ id ] = def
	Rebuild()
	return def
end

function CH.Get( id ) return NWORK.ChatClasses[ id ] end

-- Определить класс: возвращает id и текст без префикса.
-- Префикс из букв требует пробела после себя («/me x», но не «/meow»),
-- префикс из знаков — нет («//привет»).
function CH.Parse( text )
	local low = string.lower( text )

	for _, e in ipairs( PREFIXES ) do
		if string.sub( low, 1, #e.p ) == e.p then
			local rest = string.sub( text, #e.p + 1 )
			local wordy = string.match( e.p, "%w$" ) ~= nil

			if not wordy or rest == "" or string.match( rest, "^%s" ) then
				return e.id, string.Trim( rest )
			end
		end
	end

	return nil, text
end

function CH.Range( def )
	local r = def.Range
	if isstring( r ) then r = NWORK.Config.ChatRange[ r ] end
	return r
end

-------------------------------------------------------------- базовые классы

local C = CH.Colors
local BOLD = CH.Font( "Nwork.ChatBold" )
local REG  = CH.Font( "Nwork.Chat" )

CH.Register( "ic", {
	Range = "talk", Overhead = true,
	Format = function( _, text, name )
		return C.Name, name, BOLD, C.Text, " говорит ", REG, "\"" .. text .. "\""
	end,
} )

CH.Register( "w", {
	Prefix = { "/w", "/whisper" }, Range = "whisper", Font = "Nwork.ChatWhisper",
	Desc = "Шёпот — слышно только вплотную.", Overhead = true,
	Format = function( _, text, name )
		return C.Name, name, C.Whisper, " шепчет \"" .. text .. "\""
	end,
} )

CH.Register( "y", {
	Prefix = { "/y", "/yell" }, Range = "yell", Font = "Nwork.ChatYell",
	Desc = "Крик — слышно издалека.", Overhead = true,
	Format = function( _, text, name )
		return C.Name, name, C.Text, " кричит \"" .. text .. "\""
	end,
} )

CH.Register( "me", {
	Prefix = { "/me" }, Range = "me", Font = "Nwork.ChatItalic", Args = "<действие>",
	Desc = "Действие от лица персонажа.", Overhead = "italic",
	Format = function( _, text, name )
		return C.Emote, "** " .. name .. " " .. U.Period( text )
	end,
	OverheadText = function( _, text, name ) return "** " .. name .. " " .. U.Period( text ) end,
} )

CH.Register( "it", {
	Prefix = { "/it" }, Range = "me", Font = "Nwork.ChatItalic", Args = "<описание>",
	Desc = "Описать сцену без имени персонажа.", Overhead = "italic",
	Format = function( _, text )
		return C.Emote, "** " .. U.Period( text )
	end,
	OverheadText = function( _, text ) return "** " .. U.Period( text ) end,
} )

CH.Register( "roll", {
	Prefix = { "/roll" }, Range = "me", Font = "Nwork.ChatItalic", Args = "[макс]",
	Desc = "Бросить кубик (по умолчанию до 100).", AllowEmpty = true,
	OnSay = function( _, text )
		local max = math.Clamp( math.floor( tonumber( text ) or 100 ), 2, 1000 )
		return math.random( max ) .. "/" .. max
	end,
	Format = function( _, text, name )
		return C.Emote, "** " .. name .. " бросает кубик: " .. text .. "."
	end,
} )

CH.Register( "looc", {
	Prefix = { ".//", "/looc" }, Range = "looc",
	Desc = "Локальный OOC — вне персонажа, рядом.",
	Format = function( speaker, text )
		return C.OOC, "(LOOC) ", C.OOCText, ( IsValid( speaker ) and speaker:Nick() or "Консоль" ) .. ": " .. text
	end,
} )

CH.Register( "ooc", {
	Prefix = { "//", "/ooc" },
	Desc = "Сказать вне персонажа (OOC), видно всем.",
	Format = function( speaker, text )
		return C.OOC, "(OOC) ", C.OOCText, ( IsValid( speaker ) and speaker:Nick() or "Консоль" ) .. ": " .. text
	end,
} )

CH.Register( "event", {
	Prefix = { "/event" }, Font = "Nwork.ChatYell", Args = "<текст>", Admin = true,
	Category = "АДМИН", Desc = "Объявить событие для всех.",
	CanSay = function( ply ) return ply:IsAdmin() end,
	Format = function( _, text )
		return C.Event, text
	end,
} )

------------------------------------------------------------------- сервер

if SERVER then

	util.AddNetworkString( "nwork_chat" )

	-- Отправить сообщение класса от имени игрока (можно звать из модулей)
	function CH.Send( ply, id, text )
		local def = NWORK.ChatClasses[ id ]
		if not def then return end

		if def.CanSay and def.CanSay( ply, text ) == false then
			NWORK.Notify( ply, "Вы не можете этого сделать.", "error" )
			return
		end

		if def.OnSay then
			text = def.OnSay( ply, text )
			if not text then return end
		end

		local range = CH.Range( def )
		local recv  = {}

		for _, other in ipairs( player.GetAll() ) do
			local ok = not range or other == ply
				or other:GetPos():DistToSqr( ply:GetPos() ) <= range * range

			if ok and def.CanHear then ok = def.CanHear( ply, other ) ~= false end
			if ok then recv[ #recv + 1 ] = other end
		end

		net.Start( "nwork_chat" )
			net.WriteString( id )
			net.WriteEntity( ply )
			net.WriteString( text )
		net.Send( recv )

		MsgC( Color( 150, 156, 160 ), ( "[%s] " ):format( id ), color_white,
			( "%s (%s): %s\n" ):format( ply:GetCharName(), ply:Nick(), text ) )

		hook.Run( "NworkChatSent", ply, id, text, recv )
	end

	hook.Add( "PlayerSay", "Nwork.Chat", function( ply, text )
		text = string.Trim( text or "" )
		if text == "" then return "" end

		text = U.Sub( text, NWORK.Config.ChatMaxLength )

		local id, body = CH.Parse( text )

		if not id then
			local name, raw = string.match( text, "^/(%S+)%s*(.*)$" )
			if name then
				if not NWORK.Command.Run( ply, name, raw ) then
					NWORK.Notify( ply, "Неизвестная команда: /" .. name, "error" )
				end
				return ""
			end
			id, body = "ic", text
		end

		if body == "" and not NWORK.ChatClasses[ id ].AllowEmpty then return "" end

		-- без персонажа можно только вне роли
		if not ply:HasCharacter() and id ~= "ooc" and id ~= "looc" then
			return ""
		end

		CH.Send( ply, id, body )
		return ""
	end )

	return
end

------------------------------------------------------------------- клиент

NWORK.Overhead = NWORK.Overhead or {}

net.Receive( "nwork_chat", function()
	local id      = net.ReadString()
	local speaker = net.ReadEntity()
	local text    = net.ReadString()

	local def = NWORK.ChatClasses[ id ]
	if not def or not def.Format then return end

	local name = NWORK.CharName( speaker )

	if NWORK.ChatPush then
		NWORK.ChatPush( def.Font, def.Format( speaker, text, name ) )
	end

	-- текст над головой говорящего
	if def.Overhead and IsValid( speaker ) and speaker ~= LocalPlayer() then
		NWORK.Overhead[ speaker ] = {
			text   = def.OverheadText and def.OverheadText( speaker, text, name ) or text,
			italic = def.Overhead == "italic",
			time   = CurTime(),
		}
	end

	hook.Run( "NworkChatReceived", speaker, id, text )
end )
