--[[-------------------------------------------------------------------------
	N-work — предметы (сервер).

	Инвентарь — список записей { id, n } (одинаковые предметы
	складываются), максимум 20 ячеек. Хранится в колонке inv таблицы
	персонажей (JSON) и пишется вместе с позицией. Новый персонаж
	получает стартовый набор для тестов.
---------------------------------------------------------------------------]]

util.AddNetworkString( "nwork_inv" )
util.AddNetworkString( "nwork_item_drop" )
util.AddNetworkString( "nwork_item_use" )
util.AddNetworkString( "nwork_item_take" )

sql.Query( "ALTER TABLE nwork_characters ADD COLUMN inv TEXT NOT NULL DEFAULT ''" )

local MAX_SLOTS   = 20
local PICKUP_DIST = 130

local function Fail( ply, why )
	net.Start( "nwork_fail" )
		net.WriteString( why )
	net.Send( ply )
end

function NWORK.SyncInv( ply )
	local inv = ply.NworkInv or {}

	net.Start( "nwork_inv" )
		net.WriteUInt( #inv, 8 )
		for _, e in ipairs( inv ) do
			net.WriteString( e.id )
			net.WriteUInt( e.n, 16 )
		end
	net.Send( ply )
end

function NWORK.SaveInv( ply )
	local c = ply.NworkChar
	if not c or not c.id or c.id == 0 then return end

	sql.Query( ( "UPDATE nwork_characters SET inv = %s WHERE id = %d" )
		:format( sql.SQLStr( util.TableToJSON( ply.NworkInv or {} ) ), c.id ) )
end

function NWORK.GiveItem( ply, id, n )
	if not NWORK.Items[ id ] then return false end

	local inv = ply.NworkInv or {}
	ply.NworkInv = inv

	for _, e in ipairs( inv ) do
		if e.id == id then
			e.n = e.n + ( n or 1 )
			NWORK.SyncInv( ply )
			return true
		end
	end

	if #inv >= MAX_SLOTS then return false end

	inv[ #inv + 1 ] = { id = id, n = n or 1 }
	NWORK.SyncInv( ply )
	return true
end

function NWORK.PickupItem( ply, ent )
	if not IsValid( ent ) or ent:GetClass() ~= "nwork_item" then return end
	if not ply.NworkChar then return end
	if ply:GetPos():DistToSqr( ent:GetPos() ) > PICKUP_DIST * PICKUP_DIST then return end

	local id = ent:GetItemID()
	local n  = math.max( ent:GetAmount(), 1 )

	if not NWORK.GiveItem( ply, id, n ) then
		return Fail( ply, "Инвентарь полон." )
	end

	ent:Remove()
	ply:EmitSound( "items/itempickup.wav", 60 )
	NWORK.SaveInv( ply )
end

------------------------------------------------------------------- загрузка

hook.Add( "NworkCharacterLoaded", "Nwork.LoadInv", function( ply, row, fresh )
	if fresh then
		ply.NworkInv = {
			{ id = "scrap",  n = 2 },
			{ id = "cola",   n = 1 },
			{ id = "medkit", n = 1 },
		}
		NWORK.SaveInv( ply )
	else
		ply.NworkInv = util.JSONToTable( row.inv or "" ) or {}
	end

	NWORK.SyncInv( ply )
end )

------------------------------------------------------------------------ сеть

net.Receive( "nwork_item_take", function( _, ply )
	NWORK.PickupItem( ply, net.ReadEntity() )
end )

net.Receive( "nwork_item_drop", function( _, ply )
	local idx = net.ReadUInt( 8 )
	local inv = ply.NworkInv or {}
	local e   = inv[ idx ]
	if not e then return end

	local def = NWORK.Items[ e.id ]
	if not def then return end

	e.n = e.n - 1
	if e.n <= 0 then table.remove( inv, idx ) end

	local ent = ents.Create( "nwork_item" )
	ent:SetItemID( def.id )
	ent:SetAmount( 1 )
	ent:SetPos( ply:EyePos() + ply:GetAimVector() * 32 )
	ent:SetAngles( Angle( 0, ply:EyeAngles().y, 0 ) )
	ent:Spawn()

	local phys = ent:GetPhysicsObject()
	if IsValid( phys ) then
		phys:SetVelocity( ply:GetAimVector() * 120 )
	end

	ply:EmitSound( "physics/cardboard/cardboard_box_impact_soft2.wav", 55 )

	NWORK.SyncInv( ply )
	NWORK.SaveInv( ply )
end )

net.Receive( "nwork_item_use", function( _, ply )
	local idx = net.ReadUInt( 8 )
	local inv = ply.NworkInv or {}
	local e   = inv[ idx ]
	if not e then return end

	local def = NWORK.Items[ e.id ]
	if not def or not def.Use then return end

	if def.Use( ply, e ) then
		e.n = e.n - 1
		if e.n <= 0 then table.remove( inv, idx ) end

		NWORK.SyncInv( ply )
		NWORK.SaveInv( ply )
	end
end )
