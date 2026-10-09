--[[-------------------------------------------------------------------------
	N-work — команды чата.

	NWORK.Command.Add( "roll", {
		Args     = "[макс]",
		Desc     = "Бросить кубик.",
		Category = "ОБЩЕЕ",
		Admin    = false,           -- только для админов
		Alias    = { "dice" },
		Run      = function( ply, args, raw ) ... end,   -- сервер
	} )

	Игрок пишет в чат «/roll 20». Чат-классы (/me, /w, ...) живут в
	sh_chat.lua — команды для всего остального. Список для автодополнения
	и вкладки «Помощь» — NWORK.Command.Help().
---------------------------------------------------------------------------]]

NWORK.Commands = NWORK.Commands or {}
NWORK.Command  = NWORK.Command or {}

local CMD = NWORK.Command
local ALIAS = {}

function CMD.Add( name, def )
	name = string.lower( name )
	def.Name     = name
	def.Args     = def.Args or ""
	def.Desc     = def.Desc or ""
	def.Category = def.Category or ( def.Admin and "АДМИН" or "ОБЩЕЕ" )

	NWORK.Commands[ name ] = def
	for _, a in ipairs( def.Alias or {} ) do ALIAS[ string.lower( a ) ] = name end
end

function CMD.Get( name )
	name = string.lower( name or "" )
	return NWORK.Commands[ name ] or NWORK.Commands[ ALIAS[ name ] or "" ]
end

function CMD.CanRun( ply, def )
	if not def.Admin then return true end
	return not IsValid( ply ) or ply:IsAdmin()
end

-- Единый список «команда — аргументы — описание» для подсказок и справки:
-- чат-классы + команды, отсортированные по категории и имени.
function CMD.Help( ply )
	local out = {}

	for _, def in pairs( NWORK.ChatClasses or {} ) do
		if def.Prefix[ 1 ] and def.Desc then
			if not def.Admin or ( IsValid( ply ) and ply:IsAdmin() ) then
				out[ #out + 1 ] = { cmd = def.Prefix[ 1 ], args = def.Args or "<сообщение>",
					desc = def.Desc, cat = def.Category or "ЧАТ" }
			end
		end
	end

	for name, def in pairs( NWORK.Commands ) do
		if CMD.CanRun( ply, def ) then
			out[ #out + 1 ] = { cmd = "/" .. name, args = def.Args, desc = def.Desc, cat = def.Category }
		end
	end

	table.sort( out, function( a, b )
		if a.cat ~= b.cat then return a.cat < b.cat end
		return a.cmd < b.cmd
	end )

	return out
end

if CLIENT then return end

-- Выполнить «/имя аргументы». true — команда найдена.
function CMD.Run( ply, name, raw )
	local def = CMD.Get( name )
	if not def then return false end

	if not CMD.CanRun( ply, def ) then
		NWORK.Notify( ply, "Эта команда только для администрации.", "error" )
		return true
	end

	if not def.Run then return true end

	local ok, err = pcall( def.Run, ply, NWORK.Util.ParseArgs( raw or "" ), raw or "" )
	if not ok then
		NWORK.Print( "ошибка команды /" .. def.Name .. ": " .. tostring( err ) )
		NWORK.Notify( ply, "Команда завершилась с ошибкой.", "error" )
	elseif isstring( err ) then
		NWORK.Notify( ply, err, "info" )   -- строка из Run — ответ игроку
	end

	return true
end
