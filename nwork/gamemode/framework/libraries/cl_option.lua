--[[-------------------------------------------------------------------------
	N-work — клиентские настройки.

	NWORK.Option.Register( "wm", {
		Name    = "Вотермарк",
		Type    = "bool" | "number",
		Default = true,
		Min = 0, Max = 10, Decimals = 0,      -- для number
		Category = "Интерфейс",
		OnChange = function( value ) end,
	} )

	NWORK.Option.Get( "wm" ) / NWORK.Option.Set( "wm", false )
	Значения хранятся в cookie игрока, вкладка «Настройки» строится
	по реестру автоматически.
---------------------------------------------------------------------------]]

NWORK.Options = NWORK.Options or {}
NWORK.Option  = NWORK.Option or {}

local O = NWORK.Option
O.Order = O.Order or {}

function O.Register( id, def )
	def.id       = id
	def.Type     = def.Type or ( isbool( def.Default ) and "bool" or "number" )
	def.Category = def.Category or "Общее"

	if not NWORK.Options[ id ] then O.Order[ #O.Order + 1 ] = id end
	NWORK.Options[ id ] = def

	local raw = cookie.GetString( "nwork_opt_" .. id, nil )
	if raw == nil then
		def.Value = def.Default
	elseif def.Type == "bool" then
		def.Value = raw == "1"
	else
		def.Value = tonumber( raw ) or def.Default
	end
end

function O.Get( id )
	local def = NWORK.Options[ id ]
	if not def then return end
	return def.Value
end

function O.Set( id, value )
	local def = NWORK.Options[ id ]
	if not def then return end

	if def.Type == "number" then
		value = math.Clamp( tonumber( value ) or def.Default, def.Min or -math.huge, def.Max or math.huge )
		cookie.Set( "nwork_opt_" .. id, tostring( value ) )
	else
		value = tobool( value )
		cookie.Set( "nwork_opt_" .. id, value and "1" or "0" )
	end

	def.Value = value
	if def.OnChange then def.OnChange( value ) end
	hook.Run( "NworkOptionChanged", id, value )
end

-- список по категориям для вкладки настроек
function O.ByCategory()
	local cats, order = {}, {}
	for _, id in ipairs( O.Order ) do
		local def = NWORK.Options[ id ]
		if not def.Hidden then
			if not cats[ def.Category ] then
				cats[ def.Category ] = {}
				order[ #order + 1 ] = def.Category
			end
			table.insert( cats[ def.Category ], def )
		end
	end
	return order, cats
end
