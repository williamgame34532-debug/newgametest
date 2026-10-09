--[[-------------------------------------------------------------------------
	N-work — база данных (SQLite сервера, sv.db).

	NWORK.DB.Query( "SELECT * FROM t WHERE id = %d", id )
	NWORK.DB.Escape( str )          -> 'str' с экранированием
	NWORK.DB.AddColumn( t, col, def ) безопасная миграция

	Ошибки SQL печатаются в консоль сервера вместе с запросом.
---------------------------------------------------------------------------]]

NWORK.DB = NWORK.DB or {}
local DB = NWORK.DB

function DB.Escape( s )
	return sql.SQLStr( tostring( s ) )
end

function DB.Query( q, ... )
	if select( "#", ... ) > 0 then q = string.format( q, ... ) end

	local res = sql.Query( q )
	if res == false then
		NWORK.Print( "ошибка SQL: " .. tostring( sql.LastError() ) .. " | " .. q )
	end
	return res
end

function DB.HasColumn( tbl, col )
	for _, r in ipairs( sql.Query( "PRAGMA table_info(" .. tbl .. ")" ) or {} ) do
		if r.name == col then return true end
	end
	return false
end

function DB.AddColumn( tbl, col, def )
	if not DB.HasColumn( tbl, col ) then
		DB.Query( "ALTER TABLE %s ADD COLUMN %s %s", tbl, col, def )
	end
end

------------------------------------------------------------------- таблицы

DB.Query( [[
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

-- колонки, появившиеся в 0.6 и 1.0 (у старых серверов их может не быть)
DB.AddColumn( "nwork_characters", "inv",  "TEXT NOT NULL DEFAULT ''" )
DB.AddColumn( "nwork_characters", "data", "TEXT NOT NULL DEFAULT ''" )
