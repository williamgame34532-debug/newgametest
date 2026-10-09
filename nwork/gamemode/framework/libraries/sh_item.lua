--[[-------------------------------------------------------------------------
	N-work — реестр предметов.

	NWORK.Item.Register( "id", {
		Name     = "Название",
		Desc     = "Описание",
		Model    = "models/....mdl",   -- из неё же строится иконка
		Category = "Еда",
		Stack    = 10,                 -- максимум в одной ячейке
		Actions  = {
			use = {
				Name  = "Съесть",
				Order = 1,
				-- выполняется на сервере; true — предмет расходуется
				Run   = function( ply, def ) ... return true end,
			},
		},
	} )

	«Выбросить» есть у всех предметов и обрабатывается фреймворком.
	Старый формат (UseName + Use) поддерживается.
---------------------------------------------------------------------------]]

NWORK.Items = NWORK.Items or {}
NWORK.Item  = NWORK.Item or {}

local I = NWORK.Item

-- цвет уголка ячейки по категории
I.CategoryColors = {
	[ "Еда" ]       = Color( 196, 168, 96 ),
	[ "Медицина" ]  = Color( 190, 70, 70 ),
	[ "Энергия" ]   = Color( 92, 150, 210 ),
	[ "Документы" ] = Color( 120, 170, 200 ),
	[ "Разное" ]    = Color( 150, 150, 150 ),
}

local BASE = {
	Name     = "Предмет",
	Desc     = "",
	Model    = "models/props_junk/cardboard_box001a.mdl",
	Category = "Разное",
	Stack    = 99,
}
BASE.__index = BASE

function I.Register( id, t )
	setmetatable( t, BASE )
	t.id      = id
	t.Actions = t.Actions or {}

	-- старый формат 0.6
	if t.UseName and t.Use and not t.Actions.use then
		t.Actions.use = { Name = t.UseName, Order = 1, Run = t.Use }
	end

	NWORK.Items[ id ] = t
	return t
end

function I.Get( id )
	return NWORK.Items[ id ]
end

function I.Color( def )
	return def.Color or I.CategoryColors[ def.Category ] or I.CategoryColors[ "Разное" ]
end

-- действия предмета в порядке Order (для меню)
function I.ActionList( def )
	local out = {}
	for key, a in pairs( def.Actions or {} ) do
		out[ #out + 1 ] = { key = key, Name = a.Name or key, Order = a.Order or 50 }
	end
	table.sort( out, function( a, b ) return a.Order < b.Order end )
	return out
end

NWORK.RegisterItem = I.Register
