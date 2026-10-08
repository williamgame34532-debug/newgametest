--[[-------------------------------------------------------------------------
	N-work — персонажи (сервер).

	Хранение в SQLite сервера (sv.db), таблица nwork_characters.
	Позиция/углы/карта пишутся при выходе игрока, при выключении сервера
	и раз в 2 минуты — при повторном заходе на ту же карту игрок
	возвращается на своё место.
---------------------------------------------------------------------------]]

util.AddNetworkString( "nwork_ready" )
util.AddNetworkString( "nwork_chars" )
util.AddNetworkString( "nwork_create" )
util.AddNetworkString( "nwork_select" )
util.AddNetworkString( "nwork_delete" )
util.AddNetworkString( "nwork_fail" )
util.AddNetworkString( "nwork_loaded" )
util.AddNetworkString( "nwork_intro" )

sql.Query( [[
	CREATE TABLE IF NOT EXISTS nwork_characters (
		id      INTEGER PRIMARY KEY AUTOINCREMENT,
		steamid TEXT NOT NULL,
		name    TEXT NOT NULL,
		descr   TEXT NOT NULL,
		model   TEXT NOT NULL,
		skin    INTEGER NOT NULL DEFAULT 0,
		faction TEXT NOT NULL,
		map     TEXT NOT NULL DEFAULT '',
		pos     TEXT NOT NULL DEFAULT '',
		ang     TEXT NOT NULL DEFAULT ''
	)
]] )

local C = NWORK.Config

local function esc( s ) return sql.SQLStr( tostring( s ) ) end

local function CharsOf( sid )
	return sql.Query( ( "SELECT * FROM nwork_characters WHERE steamid = %s ORDER BY id" )
		:format( esc( sid ) ) ) or {}
end

local function SendChars( ply )
	local rows = CharsOf( ply:SteamID64() )

	net.Start( "nwork_chars" )
		net.WriteUInt( #rows, 8 )
		for _, r in ipairs( rows ) do
			net.WriteUInt( tonumber( r.id ) or 0, 32 )
			net.WriteString( r.name )
			net.WriteString( r.descr )
			net.WriteString( r.model )
			net.WriteUInt( tonumber( r.skin ) or 0, 8 )
			net.WriteString( r.faction )
		end
	net.Send( ply )
end

local function Fail( ply, why )
	net.Start( "nwork_fail" )
		net.WriteString( why )
	net.Send( ply )
end

---------------------------------------------------------- загрузка персонажа

function NWORK.LoadCharacter( ply, row, fresh )
	row.id   = tonumber( row.id )
	row.skin = tonumber( row.skin ) or 0

	ply.NworkChar = row
	ply:SetNWString( "nwork_name", row.name )
	ply:SetNWInt( "nwork_charid", row.id or 0 )
	ply:SetNWString( "nwork_faction", row.faction or NWORK.Config.CreateFaction )

	ply:GodDisable()
	ply:Freeze( false )

	ply:SetModel( row.model )
	ply:SetSkin( row.skin )
	ply:SetupHands()

	-- возврат на сохранённую позицию (только при заходе, не после создания)
	if not fresh and row.map == game.GetMap() and row.pos ~= "" then
		local pos = util.StringToType( row.pos, "Vector" )
		local ang = util.StringToType( row.ang, "Angle" )

		timer.Simple( 0, function()
			if not IsValid( ply ) then return end
			if pos then ply:SetPos( pos ) end
			if ang then ply:SetEyeAngles( Angle( 0, ang.y, 0 ) ) end
		end )
	end

	net.Start( "nwork_loaded" )
	net.Send( ply )

	if fresh then
		net.Start( "nwork_intro" )
		net.Send( ply )
	end

	hook.Run( "NworkCharacterLoaded", ply, row, fresh )
end

------------------------------------------------------------------ сохранение

local function SavePosition( ply )
	local c = ply.NworkChar
	if not c or not c.id then return end

	local pos = ply:GetPos()
	local ang = ply:EyeAngles()

	sql.Query( ( "UPDATE nwork_characters SET map = %s, pos = %s, ang = %s WHERE id = %d" ):format(
		esc( game.GetMap() ),
		esc( string.format( "%.2f %.2f %.2f", pos.x, pos.y, pos.z ) ),
		esc( string.format( "%.2f %.2f %.2f", ang.p, ang.y, ang.r ) ),
		c.id
	) )
end

hook.Add( "PlayerDisconnected", "Nwork.SavePos", SavePosition )

hook.Add( "ShutDown", "Nwork.SaveAll", function()
	for _, ply in ipairs( player.GetAll() ) do SavePosition( ply ) end
end )

timer.Create( "Nwork.AutoSave", 120, 0, function()
	for _, ply in ipairs( player.GetAll() ) do SavePosition( ply ) end
end )

------------------------------------------------------------------------ сеть

net.Receive( "nwork_ready", function( _, ply )
	SendChars( ply )
end )

net.Receive( "nwork_create", function( _, ply )
	if ply.NworkChar then return Fail( ply, "Персонаж уже загружен." ) end

	local name  = string.Trim( net.ReadString() )
	local descr = string.Trim( net.ReadString() )
	local mdl   = net.ReadString()
	local skin  = net.ReadUInt( 8 )

	local rows = CharsOf( ply:SteamID64() )
	if #rows >= C.MaxCharacters then
		return Fail( ply, "Достигнут лимит персонажей." )
	end

	local nlen = utf8.len( name ) or #name
	if nlen < C.MinName or nlen > C.MaxName then
		return Fail( ply, ( "Имя: от %d до %d символов." ):format( C.MinName, C.MaxName ) )
	end

	local dlen = utf8.len( descr ) or #descr
	if dlen < C.MinDesc or dlen > C.MaxDesc then
		return Fail( ply, ( "Описание: от %d до %d символов." ):format( C.MinDesc, C.MaxDesc ) )
	end

	if not NWORK.FactionHasModel( C.CreateFaction, mdl ) then
		return Fail( ply, "Эта модель недоступна для фракции." )
	end

	sql.Query( ( "INSERT INTO nwork_characters (steamid, name, descr, model, skin, faction) VALUES (%s, %s, %s, %s, %d, %s)" ):format(
		esc( ply:SteamID64() ), esc( name ), esc( descr ), esc( mdl ),
		math.Clamp( skin, 0, 255 ), esc( C.CreateFaction )
	) )

	SendChars( ply )

	local fresh = CharsOf( ply:SteamID64() )
	NWORK.LoadCharacter( ply, fresh[ #fresh ], true )
end )

net.Receive( "nwork_select", function( _, ply )
	if ply.NworkChar then return end

	local id = net.ReadUInt( 32 )

	for _, r in ipairs( CharsOf( ply:SteamID64() ) ) do
		if tonumber( r.id ) == id then
			NWORK.LoadCharacter( ply, r, false )
			return
		end
	end

	Fail( ply, "Персонаж не найден." )
end )

net.Receive( "nwork_delete", function( _, ply )
	local id = net.ReadUInt( 32 )

	sql.Query( ( "DELETE FROM nwork_characters WHERE id = %d AND steamid = %s" )
		:format( id, esc( ply:SteamID64() ) ) )

	if ply.NworkChar and ply.NworkChar.id == id then
		ply.NworkChar = nil
	end

	SendChars( ply )
end )
