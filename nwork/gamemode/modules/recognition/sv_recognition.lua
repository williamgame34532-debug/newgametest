--[[-------------------------------------------------------------------------
	Знакомства (сервер).

	F3 или «Представиться» — назвать имя всем в радиусе C.IntroduceRange.
	Знакомства персональные (кто кого знает) и хранятся в SQLite.
---------------------------------------------------------------------------]]

util.AddNetworkString( "nwork_introduce" )
util.AddNetworkString( "nwork_recog" )

local DB = NWORK.DB

DB.Query( [[
	CREATE TABLE IF NOT EXISTS nwork_recognize (
		char_id  INTEGER NOT NULL,
		other_id INTEGER NOT NULL,
		UNIQUE( char_id, other_id )
	)
]] )

-- отправить игроку всех, кого знает его персонаж
local function SendKnown( ply )
	local id = ply:GetCharID()
	if id == 0 then return end

	local rows = DB.Query( "SELECT other_id FROM nwork_recognize WHERE char_id = %d", id ) or {}

	net.Start( "nwork_recog" )
		net.WriteBool( false )
		net.WriteUInt( #rows, 16 )
		for _, r in ipairs( rows ) do net.WriteUInt( tonumber( r.other_id ) or 0, 32 ) end
	net.Send( ply )
end

hook.Add( "NworkCharacterLoaded", "Nwork.Recognition", SendKnown )

hook.Add( "NworkCharacterDeleted", "Nwork.Recognition", function( _, id )
	DB.Query( "DELETE FROM nwork_recognize WHERE char_id = %d OR other_id = %d", id, id )
end )

local function Intro( to, id, name, self_ )
	net.Start( "nwork_recog" )
		net.WriteBool( true )
		net.WriteBool( self_ )
		net.WriteUInt( id, 32 )
		net.WriteString( name )
	net.Send( to )
end

function NWORK.Introduce( ply )
	local id = ply:GetCharID()
	if id == 0 or not ply:Alive() then return end

	if ( ply.NworkIntroCD or 0 ) > CurTime() then return end
	ply.NworkIntroCD = CurTime() + 3

	local range = NWORK.Config.IntroduceRange
	local name  = ply:GetCharName()

	for _, other in ipairs( player.GetAll() ) do
		if other ~= ply and other:GetPos():DistToSqr( ply:GetPos() ) <= range * range then
			if other:GetCharID() ~= 0 then
				DB.Query( "INSERT OR IGNORE INTO nwork_recognize (char_id, other_id) VALUES (%d, %d)",
					other:GetCharID(), id )
			end
			Intro( other, id, name, false )
		end
	end

	Intro( ply, id, name, true )
end

net.Receive( "nwork_introduce", function( _, ply )
	NWORK.Introduce( ply )
end )
