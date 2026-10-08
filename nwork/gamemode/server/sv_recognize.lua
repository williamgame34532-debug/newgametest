--[[-------------------------------------------------------------------------
	N-work — знакомства и дистанции чата (сервер).

	Пока персонаж не представился (F3), окружающие видят его как
	«Неизвестный» — в неймплейте и в чате. Знакомства персональные
	(кто кому представился) и хранятся в SQLite, так что переживают
	перезаходы.

	Дистанции чата:
		шёпот (/w)   ~120 юнитов
		обычная речь ~320
		крик (/y)    ~640
	Рация (/r), OOC (//) и /event слышны всем.
---------------------------------------------------------------------------]]

util.AddNetworkString( "nwork_introduce" )
util.AddNetworkString( "nwork_recog" )

sql.Query( [[
	CREATE TABLE IF NOT EXISTS nwork_recognize (
		char_id  INTEGER NOT NULL,
		other_id INTEGER NOT NULL,
		UNIQUE( char_id, other_id )
	)
]] )

local INTRO_RANGE = 250

-- отправить игроку список всех, кого его персонаж уже знает
local function SendKnown( ply )
	local c = ply.NworkChar
	if not c or not c.id or c.id == 0 then return end

	local rows = sql.Query( ( "SELECT other_id FROM nwork_recognize WHERE char_id = %d" ):format( c.id ) ) or {}

	net.Start( "nwork_recog" )
		net.WriteBool( false )              -- bulk-список
		net.WriteUInt( #rows, 16 )
		for _, r in ipairs( rows ) do
			net.WriteUInt( tonumber( r.other_id ) or 0, 32 )
		end
	net.Send( ply )
end

hook.Add( "NworkCharacterLoaded", "Nwork.SendKnown", function( ply )
	SendKnown( ply )
end )

-- F3 — представиться окружающим
net.Receive( "nwork_introduce", function( _, ply )
	local c = ply.NworkChar
	if not c or not c.id or c.id == 0 then return end

	if ( ply.NworkIntroCD or 0 ) > CurTime() then return end
	ply.NworkIntroCD = CurTime() + 3

	local pos = ply:GetPos()

	for _, other in ipairs( player.GetAll() ) do
		if other ~= ply and other:GetPos():DistToSqr( pos ) <= INTRO_RANGE * INTRO_RANGE then
			local oc = other.NworkChar

			-- людям с персонажем — записываем знакомство
			if oc and oc.id and oc.id ~= 0 then
				sql.Query( ( "INSERT OR IGNORE INTO nwork_recognize (char_id, other_id) VALUES (%d, %d)" )
					:format( oc.id, c.id ) )
			end

			net.Start( "nwork_recog" )
				net.WriteBool( true )       -- интро
				net.WriteBool( false )      -- не сам
				net.WriteUInt( c.id, 32 )
				net.WriteString( c.name )
			net.Send( other )
		end
	end

	net.Start( "nwork_recog" )
		net.WriteBool( true )
		net.WriteBool( true )               -- подтверждение самому
		net.WriteUInt( c.id, 32 )
		net.WriteString( c.name )
	net.Send( ply )
end )

------------------------------------------------------------- дистанции чата

local RANGES = {
	whisper = 120,
	talk    = 320,
	yell    = 640,
}

function GM:PlayerCanSeePlayersChat( text, teamOnly, listener, speaker )
	if not IsValid( speaker ) or not IsValid( listener ) then return true end
	if listener == speaker then return true end

	-- глобальные каналы
	if string.match( text, "^//" ) or string.match( text, "^/r%s" )
		or string.match( text, "^/event%s" ) then
		return true
	end

	local range = RANGES.talk
	if string.match( text, "^/w%S*%s" ) then
		range = RANGES.whisper
	elseif string.match( text, "^/y%S*%s" ) then
		range = RANGES.yell
	end

	return listener:GetPos():DistToSqr( speaker:GetPos() ) <= range * range
end
