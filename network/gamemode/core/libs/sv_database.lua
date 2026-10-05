NETWORK.db = NETWORK.db or {}

local D = NETWORK.db

local configPath = "network/mysql.txt"

D.mode = D.mode or "sqlite"
D.queue = D.queue or {}

function D.DefaultConfig()
	return {
		enabled = false,
		host = "127.0.0.1",
		port = 3306,
		user = "network",
		password = "",
		database = "network"
	}
end

function D.LoadConfig()
	local raw = file.Read(configPath, "DATA")
	local data = raw and util.JSONToTable(raw)

	if (!istable(data)) then
		data = D.DefaultConfig()

		file.CreateDir("network")
		file.Write(configPath, util.TableToJSON(data, true))
	end

	return data
end

function D.Escape(value)
	value = tostring(value or "")

	if (D.mode == "mysql" and D.connection) then
		return "'" .. D.connection:escape(value) .. "'"
	end

	return sql.SQLStr(value)
end

function D.IsMySQL()
	return D.mode == "mysql" and D.connection != nil
end

function D.Query(query, callback)
	if (D.IsMySQL()) then
		local object = D.connection:query(query)

		object.onSuccess = function(_, data)
			if (callback) then
				callback(data, nil)
			end
		end

		object.onError = function(_, err)
			NETWORK.util.PrintWarning("MySQL: " .. tostring(err))

			if (callback) then
				callback(nil, err)
			end
		end

		object:start()

		return
	end

	local result = sql.Query(query)
	local err = result == false and sql.LastError() or nil

	if (result == false) then
		NETWORK.util.PrintWarning("SQL: " .. tostring(sql.LastError()))
		result = nil
	end

	if (callback) then
		callback(result, err)
	end

	return result
end

function D.CreateTable(name, columns)
	local parts = {}

	for _, column in ipairs(columns) do
		local kind = column[2]

		if (D.IsMySQL()) then
			kind = string.gsub(kind, "INTEGER PRIMARY KEY", "BIGINT PRIMARY KEY")
			kind = string.gsub(kind, "TEXT", "LONGTEXT")
		end

		parts[#parts + 1] = column[1] .. " " .. kind
	end

	D.Query("CREATE TABLE IF NOT EXISTS " .. name .. " (" ..
		table.concat(parts, ", ") .. ")")
end

function D.Connect()
	local config = D.LoadConfig()

	if (!config.enabled) then
		NETWORK.util.Print("База данных: SQLite (MySQL выключен в data/" ..
			configPath .. ").")

		return
	end

	if (!pcall(require, "mysqloo") or !mysqloo) then
		NETWORK.util.PrintWarning("MySQL включён, но модуля mysqloo нет — " ..
			"остаёмся на SQLite. Модуль кладётся в garrysmod/lua/bin/.")

		return
	end

	local connection = mysqloo.connect(config.host, config.user, config.password,
		config.database, tonumber(config.port) or 3306)

	connection.onConnected = function()
		D.connection = connection
		D.mode = "mysql"

		NETWORK.util.Print("База данных: MySQL " .. config.host .. "/" ..
			config.database .. " — подключено.")

		hook.Run("NetworkDatabaseReady", "mysql")
	end

	connection.onConnectionFailed = function(_, err)
		NETWORK.util.PrintWarning("MySQL не подключился (" .. tostring(err) ..
			") — работаем на SQLite.")
	end

	connection:connect()
end

hook.Add("Initialize", "nwDatabase", function()
	D.Connect()
end)

concommand.Add("network_db_status", function(client)
	if (IsValid(client) and !client:IsAdmin()) then
		return
	end

	NETWORK.util.Print("База данных: SQLite (основная), MySQL-зеркало: " .. (D.IsMySQL() and "подключено" or "выключено/недоступно"))
end)
