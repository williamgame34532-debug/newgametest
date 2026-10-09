--[[-------------------------------------------------------------------------
	N-work — команды схемы.
---------------------------------------------------------------------------]]

local CMD = NWORK.Command
local U   = NWORK.Util

CMD.Add( "setfaction", {
	Args = "<игрок> <фракция>", Admin = true,
	Desc = "Перевести персонажа в другую фракцию.",
	Run = function( ply, args )
		local target = U.FindPlayer( args[ 1 ] )
		if not IsValid( target ) or not target.NworkChar then return "Игрок не найден." end

		local fid = args[ 2 ]
		if not NWORK.Factions[ fid or "" ] then
			return "Фракции: " .. table.concat( table.GetKeys( NWORK.Factions ), ", " )
		end

		NWORK.Character.SetFaction( target, fid )
		NWORK.Notify( target, "Ваша фракция: " .. NWORK.Factions[ fid ].Name, "ok" )
		return "Готово."
	end,
} )

CMD.Add( "giveitem", {
	Args = "<игрок> <предмет> [кол-во]", Admin = true,
	Desc = "Выдать предмет в инвентарь.",
	Run = function( ply, args )
		local target = U.FindPlayer( args[ 1 ] )
		if not IsValid( target ) or not target.NworkChar then return "Игрок не найден." end
		if not NWORK.Items[ args[ 2 ] or "" ] then
			return "Предметы: " .. table.concat( table.GetKeys( NWORK.Items ), ", " )
		end

		local n = math.Clamp( math.floor( tonumber( args[ 3 ] ) or 1 ), 1, 100 )
		if not NWORK.Inventory.Give( target, args[ 2 ], n ) then return "Нет места." end
		return "Выдано."
	end,
} )

CMD.Add( "chardesc", {
	Args = "<текст>",
	Desc = "Изменить описание своего персонажа.",
	Run = function( ply, _, raw )
		local ok, why = NWORK.Character.SetDesc( ply, raw )
		return ok and "Описание обновлено." or why
	end,
} )
