--[[-------------------------------------------------------------------------
	N-work — персонажи (сервер).

	ply.NworkChar — запись активного персонажа:
		id, name, descr, model, skin, faction, map, pos, ang, inv, data
	data — произвольная таблица модулей (нужды и т.п.), пишется в JSON.

	NWORK.Character.Load( ply, row, fresh )
	NWORK.Character.Save( ply )                 позиция + data
	NWORK.Character.Unload( ply )               вернуться в меню
	NWORK.Character.GetData( ply, key, default )
	NWORK.Character.SetData( ply, key, value )
	NWORK.Character.SetFaction( ply, id )
	NWORK.Character.SetDesc( ply, text )

	Хуки: NworkCharacterLoaded( ply, char, fresh ),
	      NworkCharacterSave( ply, char ), NworkCharacterUnloaded( ply, char )
---------------------------------------------------------------------------]]

util.AddNetworkString( "nwork_ready" )
util.AddNetworkString( "nwork_chars" )
util.AddNetworkString( "nwork_create" )
util.AddNetworkString( "nwork_select" )
util.AddNetworkString( "nwork_delete" )
util.AddNetworkString( "nwork_unload" )
util.AddNetworkString( "nwork_setdesc" )
util.AddNetworkString( "nwork_loaded" )
util.AddNetworkString( "nwork_intro" )

local CH = NWORK.Character
local DB = NWORK.DB
local C  = NWORK.Config
local U  = NWORK.Util

local function CharsOf( sid )
	return DB.Query( "SELECT * FROM nwork_characters WHERE steamid = %s ORDER BY id", DB.Escape( sid ) ) or {}
end

function CH.SendList( ply )
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

------------------------------------------------------------------ загрузка

function CH.Load( ply, row, fresh )
	row.id   = tonumber( row.id ) or 0
	row.skin = tonumber( row.skin ) or 0
	row.data = istable( row.data ) and row.data or ( util.JSONToTable( row.data or "" ) or {} )

	if not NWORK.Factions[ row.faction ] then row.faction = C.CreateFaction end

	ply.NworkChar = row
	ply:SetNWString( "nwork_name", row.name )
	ply:SetNWInt( "nwork_charid", row.id )
	ply:SetNWString( "nwork_faction", row.faction )
	ply:SetNWString( "nwork_desc", row.descr or "" )

	ply:GodDisable()
	ply:Freeze( false )
	ply:Spawn()

	-- возврат на сохранённую позицию (при входе, не после создания)
	if not fresh and row.map == game.GetMap() and ( row.pos or "" ) ~= "" then
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

function CH.Save( ply )
	local c = ply.NworkChar
	if not c or not c.id or c.id == 0 then return end

	hook.Run( "NworkCharacterSave", ply, c )

	local pos, ang = ply:GetPos(), ply:EyeAngles()

	DB.Query( "UPDATE nwork_characters SET map = %s, pos = %s, ang = %s, data = %s WHERE id = %d",
		DB.Escape( game.GetMap() ),
		DB.Escape( string.format( "%.2f %.2f %.2f", pos.x, pos.y, pos.z ) ),
		DB.Escape( string.format( "%.2f %.2f %.2f", ang.p, ang.y, ang.r ) ),
		DB.Escape( util.TableToJSON( c.data or {} ) ),
		c.id )
end

function CH.SaveAll()
	for _, ply in ipairs( player.GetAll() ) do CH.Save( ply ) end
end

function CH.GetData( ply, key, default )
	local c = ply.NworkChar
	if not c or not c.data then return default end
	local v = c.data[ key ]
	if v == nil then return default end
	return v
end

function CH.SetData( ply, key, value )
	local c = ply.NworkChar
	if not c then return end
	c.data = c.data or {}
	c.data[ key ] = value
end

------------------------------------------------------------- смена данных

function CH.SetFaction( ply, id )
	local c = ply.NworkChar
	if not c or not NWORK.Factions[ id ] then return false end

	c.faction = id
	ply:SetNWString( "nwork_faction", id )

	-- модель должна принадлежать фракции
	if not NWORK.Faction.HasModel( id, c.model ) then
		c.model = NWORK.Faction.RandomModel( id ) or c.model
		c.skin  = 0
		ply:SetModel( c.model )
		ply:SetSkin( 0 )
		ply:SetupHands()
	end

	if c.id ~= 0 then
		DB.Query( "UPDATE nwork_characters SET faction = %s, model = %s, skin = %d WHERE id = %d",
			DB.Escape( id ), DB.Escape( c.model ), c.skin or 0, c.id )
	end

	hook.Run( "NworkFactionChanged", ply, id )
	return true
end

function CH.SetDesc( ply, text )
	local c = ply.NworkChar
	if not c then return false, "Нет персонажа." end

	text = string.Trim( text or "" )
	local len = U.Len( text )
	if len < C.MinDesc or len > C.MaxDesc then
		return false, ( "Описание: от %d до %d символов." ):format( C.MinDesc, C.MaxDesc )
	end

	c.descr = text
	ply:SetNWString( "nwork_desc", text )
	if c.id ~= 0 then
		DB.Query( "UPDATE nwork_characters SET descr = %s WHERE id = %d", DB.Escape( text ), c.id )
	end
	return true
end

-------------------------------------------------------------------- выгрузка

function CH.Unload( ply )
	local c = ply.NworkChar
	if not c then return end

	CH.Save( ply )
	hook.Run( "NworkCharacterUnloaded", ply, c )

	ply.NworkChar = nil
	ply.NworkInv  = nil
	ply:SetNWString( "nwork_name", "" )
	ply:SetNWInt( "nwork_charid", 0 )
	ply:SetNWString( "nwork_desc", "" )

	ply:KillSilent()
	ply:Spawn()
	CH.SendList( ply )
end

hook.Add( "PlayerDisconnected", "Nwork.SaveChar", CH.Save )
hook.Add( "ShutDown", "Nwork.SaveAll", CH.SaveAll )
timer.Create( "Nwork.AutoSave", C.AutoSave, 0, CH.SaveAll )

-------------------------------------------------------------------- проверки

local function ValidName( name )
	local len = U.Len( name )
	if len < C.MinName or len > C.MaxName then
		return false, ( "Имя: от %d до %d символов." ):format( C.MinName, C.MaxName )
	end
	if string.find( name, "[%c<>\"\\/]" ) then
		return false, "Имя содержит недопустимые символы."
	end
	if hook.Run( "NworkValidateName", name ) == false then
		return false, "Имя не подходит."
	end
	return true
end

------------------------------------------------------------------------ сеть

net.Receive( "nwork_ready", function( _, ply )
	CH.SendList( ply )
	hook.Run( "NworkPlayerReady", ply )
end )

net.Receive( "nwork_create", function( _, ply )
	if ply.NworkChar then return NWORK.Notify( ply, "Персонаж уже загружен.", "error" ) end
	if ( ply.NworkCreateCD or 0 ) > CurTime() then return end
	ply.NworkCreateCD = CurTime() + 2

	local name  = string.Trim( net.ReadString() )
	local descr = string.Trim( net.ReadString() )
	local mdl   = net.ReadString()
	local skin  = net.ReadUInt( 8 )

	if #CharsOf( ply:SteamID64() ) >= C.MaxCharacters then
		return NWORK.Notify( ply, "Достигнут лимит персонажей.", "error" )
	end

	local ok, why = ValidName( name )
	if not ok then return NWORK.Notify( ply, why, "error" ) end

	local dlen = U.Len( descr )
	if dlen < C.MinDesc or dlen > C.MaxDesc then
		return NWORK.Notify( ply, ( "Описание: от %d до %d символов." ):format( C.MinDesc, C.MaxDesc ), "error" )
	end

	if not NWORK.Faction.HasModel( C.CreateFaction, mdl ) then
		return NWORK.Notify( ply, "Эта модель недоступна для фракции.", "error" )
	end

	DB.Query( "INSERT INTO nwork_characters (steamid, name, descr, model, skin, faction) VALUES (%s, %s, %s, %s, %d, %s)",
		DB.Escape( ply:SteamID64() ), DB.Escape( name ), DB.Escape( descr ), DB.Escape( mdl ),
		math.Clamp( skin, 0, 255 ), DB.Escape( C.CreateFaction ) )

	CH.SendList( ply )

	local rows = CharsOf( ply:SteamID64() )
	CH.Load( ply, rows[ #rows ], true )
end )

net.Receive( "nwork_select", function( _, ply )
	if ply.NworkChar then return end

	local id = net.ReadUInt( 32 )

	for _, r in ipairs( CharsOf( ply:SteamID64() ) ) do
		if tonumber( r.id ) == id then
			-- один персонаж не может быть загружен дважды
			for _, other in ipairs( player.GetAll() ) do
				if other ~= ply and other:GetCharID() == id then
					return NWORK.Notify( ply, "Этот персонаж уже в игре.", "error" )
				end
			end
			return CH.Load( ply, r, false )
		end
	end

	NWORK.Notify( ply, "Персонаж не найден.", "error" )
end )

net.Receive( "nwork_delete", function( _, ply )
	local id = net.ReadUInt( 32 )

	if ply.NworkChar and ply.NworkChar.id == id then
		return NWORK.Notify( ply, "Нельзя удалить персонажа, за которого играете.", "error" )
	end

	DB.Query( "DELETE FROM nwork_characters WHERE id = %d AND steamid = %s", id, DB.Escape( ply:SteamID64() ) )
	hook.Run( "NworkCharacterDeleted", ply, id )
	CH.SendList( ply )
end )

net.Receive( "nwork_unload", function( _, ply )
	if ( ply.NworkUnloadCD or 0 ) > CurTime() then return end
	ply.NworkUnloadCD = CurTime() + 3
	CH.Unload( ply )
end )

net.Receive( "nwork_setdesc", function( _, ply )
	local ok, why = CH.SetDesc( ply, net.ReadString() )
	NWORK.Notify( ply, ok and "Описание обновлено." or why, ok and "ok" or "error" )
end )

NWORK.LoadCharacter = CH.Load   -- совместимость с 0.x
