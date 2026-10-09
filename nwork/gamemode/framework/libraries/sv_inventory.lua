--[[-------------------------------------------------------------------------
	N-work — инвентарь (сервер).

	NWORK.Inventory.Give( ply, id, n )   положить, false — нет места
	NWORK.Inventory.Take( ply, id, n )   забрать, false — не хватает
	NWORK.Inventory.Has( ply, id, n )
	NWORK.Inventory.Sync( ply )          отправить клиенту
	NWORK.Inventory.Save( ply )          записать в базу

	Хранится в колонке inv персонажа (JSON), пишется при каждом изменении.
---------------------------------------------------------------------------]]

util.AddNetworkString( "nwork_inv" )
util.AddNetworkString( "nwork_item_action" )
util.AddNetworkString( "nwork_item_take" )

local INV = NWORK.Inventory
local C   = NWORK.Config

local function Get( ply )
	ply.NworkInv = ply.NworkInv or {}
	return ply.NworkInv
end

function INV.Sync( ply )
	local inv = Get( ply )

	net.Start( "nwork_inv" )
		net.WriteUInt( #inv, 8 )
		for _, e in ipairs( inv ) do
			net.WriteString( e.id )
			net.WriteUInt( e.n, 16 )
		end
	net.Send( ply )
end

function INV.Save( ply )
	local c = ply.NworkChar
	if not c or not c.id or c.id == 0 then return end

	NWORK.DB.Query( "UPDATE nwork_characters SET inv = %s WHERE id = %d",
		NWORK.DB.Escape( util.TableToJSON( Get( ply ) ) ), c.id )
end

local function Changed( ply )
	INV.Sync( ply )
	INV.Save( ply )
	hook.Run( "NworkInventoryChanged", ply, Get( ply ) )
end

function INV.Has( ply, id, n )
	return INV.Count( Get( ply ), id ) >= ( n or 1 )
end

function INV.Give( ply, id, n )
	local def = NWORK.Items[ id ]
	if not def then return false end

	n = n or 1
	local inv = Get( ply )

	-- сначала проверяем, влезет ли всё
	local free = 0
	for _, e in ipairs( inv ) do
		if e.id == id then free = free + math.max( 0, def.Stack - e.n ) end
	end
	free = free + ( C.InvSlots - #inv ) * def.Stack
	if free < n then return false end

	for _, e in ipairs( inv ) do
		if n <= 0 then break end
		if e.id == id and e.n < def.Stack then
			local add = math.min( n, def.Stack - e.n )
			e.n, n = e.n + add, n - add
		end
	end

	while n > 0 do
		local add = math.min( n, def.Stack )
		inv[ #inv + 1 ] = { id = id, n = add }
		n = n - add
	end

	Changed( ply )
	return true
end

-- забрать из конкретной ячейки
local function TakeAt( inv, idx, n )
	local e = inv[ idx ]
	e.n = e.n - n
	if e.n <= 0 then table.remove( inv, idx ) end
end

function INV.Take( ply, id, n )
	n = n or 1
	if not INV.Has( ply, id, n ) then return false end

	local inv = Get( ply )
	for i = #inv, 1, -1 do
		if n <= 0 then break end
		if inv[ i ].id == id then
			local take = math.min( n, inv[ i ].n )
			TakeAt( inv, i, take )
			n = n - take
		end
	end

	Changed( ply )
	return true
end

------------------------------------------------------------- предмет в мире

function INV.Spawn( id, n, pos, ang )
	local ent = ents.Create( "nwork_item" )
	ent:SetItemID( id )
	ent:SetAmount( n or 1 )
	ent:SetPos( pos )
	ent:SetAngles( ang or angle_zero )
	ent:Spawn()
	return ent
end

function INV.Pickup( ply, ent )
	if not IsValid( ent ) or ent:GetClass() ~= "nwork_item" then return end
	if not ply:HasCharacter() or not ply:Alive() then return end
	if ply:GetPos():DistToSqr( ent:GetPos() ) > C.PickupRange * C.PickupRange then return end
	if ent.NworkTaken then return end

	if not INV.Give( ply, ent:GetItemID(), math.max( ent:GetAmount(), 1 ) ) then
		return NWORK.Notify( ply, "Инвентарь полон.", "error" )
	end

	ent.NworkTaken = true
	ent:Remove()
	ply:EmitSound( "items/itempickup.wav", 60 )
end

NWORK.PickupItem = INV.Pickup   -- совместимость с энтити 0.x

------------------------------------------------------------------- загрузка

hook.Add( "NworkCharacterLoaded", "Nwork.Inventory", function( ply, row, fresh )
	if fresh then
		ply.NworkInv = {}
		for _, e in ipairs( C.StartItems ) do
			if NWORK.Items[ e.id ] then
				ply.NworkInv[ #ply.NworkInv + 1 ] = { id = e.id, n = e.n or 1 }
			end
		end
		INV.Save( ply )
	else
		ply.NworkInv = util.JSONToTable( row.inv or "" ) or {}
	end

	-- предметы, которых больше нет в схеме, выбрасываем молча
	for i = #ply.NworkInv, 1, -1 do
		if not NWORK.Items[ ply.NworkInv[ i ].id ] then table.remove( ply.NworkInv, i ) end
	end

	INV.Sync( ply )
end )

------------------------------------------------------------------------ сеть

net.Receive( "nwork_item_take", function( _, ply )
	INV.Pickup( ply, net.ReadEntity() )
end )

net.Receive( "nwork_item_action", function( _, ply )
	local idx    = net.ReadUInt( 8 )
	local action = net.ReadString()

	if not ply:HasCharacter() or not ply:Alive() then return end
	if ( ply.NworkActCD or 0 ) > CurTime() then return end
	ply.NworkActCD = CurTime() + 0.25

	local inv = Get( ply )
	local e   = inv[ idx ]
	if not e then return end

	local def = NWORK.Items[ e.id ]
	if not def then return end

	if action == "drop" then
		TakeAt( inv, idx, 1 )

		local ent = INV.Spawn( def.id, 1, ply:EyePos() + ply:GetAimVector() * 32,
			Angle( 0, ply:EyeAngles().y, 0 ) )

		local phys = ent:GetPhysicsObject()
		if IsValid( phys ) then phys:SetVelocity( ply:GetAimVector() * 120 ) end

		ply:EmitSound( "physics/cardboard/cardboard_box_impact_soft2.wav", 55 )
		Changed( ply )
		return
	end

	local act = def.Actions[ action ]
	if not act or not act.Run then return end

	if hook.Run( "NworkCanUseItem", ply, def, action ) == false then return end

	local ok, consumed = pcall( act.Run, ply, def, e )
	if not ok then
		NWORK.Print( ( "ошибка предмета %s/%s: %s" ):format( def.id, action, tostring( consumed ) ) )
		return
	end

	if consumed then
		-- ячейка могла сдвинуться, пока работал Run
		for i, cell in ipairs( inv ) do
			if cell == e then TakeAt( inv, i, 1 ) break end
		end
	end

	Changed( ply )
end )
