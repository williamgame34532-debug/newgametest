NETWORK.plugin = NETWORK.plugin or {}
NETWORK.plugin.stored = NETWORK.plugin.stored or {}
NETWORK.plugin.order = NETWORK.plugin.order or {}

local IGNORED = {
	id = true,
	name = true,
	author = true,
	description = true,
	version = true,
	folder = true,
	path = true,
	config = true,
	utility = true,
	bLoaded = true,
	OnLoaded = true,
	OnUnloaded = true
}

function NETWORK.plugin.Get(id)
	return NETWORK.plugin.stored[id]
end

function NETWORK.plugin.GetAll()
	return NETWORK.plugin.stored
end

function NETWORK.plugin.AttachHooks(plugin)
	for name, callback in pairs(plugin) do
		if (IGNORED[name] or !isfunction(callback)) then
			continue
		end

		hook.Add(name, "nwPlugin." .. plugin.id .. "." .. name, function(...)
			if (plugin.config and plugin.config.enabled == false) then
				return
			end

			return callback(plugin, ...)
		end)
	end
end

function NETWORK.plugin.IsEnabled(id)
	local plugin = NETWORK.plugin.stored[id]

	return plugin != nil and plugin.config.enabled != false
end

function NETWORK.plugin.SetEnabled(id, bEnabled)
	local plugin = NETWORK.plugin.stored[id]

	if (!plugin) then
		return false
	end

	plugin.config.enabled = tobool(bEnabled)

	return true
end

function NETWORK.plugin.IncludeContent(plugin, base)
	local structure = {
		{folder = "libs"},
		{folder = "derma"},
		{folder = "meta"},
		{folder = "hooks"},
		{folder = "commands"},
		{folder = "entities"}
	}

	for i = 1, #structure do
		local path = base .. "/" .. structure[i].folder

		local files, folders = file.Find(path .. "/*", "LUA")

		if (!files) then
			continue
		end

		for _, name in ipairs(files) do
			if (name:sub(-4) == ".lua") then
				NETWORK.util.Include(path .. "/" .. name)
			end
		end

		for _, name in ipairs(folders or {}) do
			local sub = file.Find(path .. "/" .. name .. "/*.lua", "LUA")

			for _, subName in ipairs(sub or {}) do
				NETWORK.util.Include(path .. "/" .. name .. "/" .. subName)
			end
		end
	end
end

function NETWORK.plugin.LoadFile(id, path, base)
	if (NETWORK.plugin.stored[id]) then
		return NETWORK.plugin.stored[id]
	end

	PLUGIN = {
		id = id,
		name = id,
		author = "Unknown",
		description = "",
		version = "1.0",
		folder = base,

		config = {enabled = true}
	}

	if (SERVER) then
		AddCSLuaFile(path)
	end

	include(path)

	if (base) then
		NETWORK.plugin.IncludeContent(PLUGIN, base)
	end

	local plugin = PLUGIN

	PLUGIN = nil

	plugin.config = istable(plugin.config) and plugin.config or {}
	plugin.config.enabled = plugin.config.enabled != false

	NETWORK.plugin.stored[id] = plugin
	NETWORK.plugin.order[#NETWORK.plugin.order + 1] = id

	NETWORK.plugin.AttachHooks(plugin)

	if (plugin.OnLoaded) then
		plugin:OnLoaded()
	end

	plugin.bLoaded = true

	NETWORK.util.Print("Плагин загружен: " .. plugin.name)
end

function NETWORK.plugin.LoadAll()
	local base = NETWORK.folder .. "/gamemode/plugins"
	local files, folders = file.Find(base .. "/*", "LUA")

	for _, name in ipairs(files or {}) do
		if (name:sub(-4) == ".lua") then
			NETWORK.plugin.LoadFile(name:sub(1, -5), base .. "/" .. name)
		end
	end

	for _, name in ipairs(folders or {}) do
		local path = base .. "/" .. name .. "/sh_plugin.lua"

		if (file.Exists(path, "LUA")) then
			NETWORK.plugin.LoadFile(name, path, base .. "/" .. name)
		end
	end
end

function NETWORK.plugin.Describe()
	local lines = {}

	for i = 1, #NETWORK.plugin.order do
		local plugin = NETWORK.plugin.stored[NETWORK.plugin.order[i]]

		lines[#lines + 1] = string.format("%s — %s (%s) — %s%s", plugin.id, plugin.name,
			plugin.version, plugin.author,
			plugin.config.enabled == false and " [выкл]" or "")
	end

	return lines
end

concommand.Add("network_plugins", function()
	for _, line in ipairs(NETWORK.plugin.Describe()) do
		NETWORK.util.Print(line)
	end
end)

NETWORK.plugin.LoadAll()

if (NETWORK.command and NETWORK.command.Register) then
	NETWORK.command.Register("plugins", {
		description = "cmdPlugins",
		usage = "/plugins",
		OnRun = function(command, client)
			local lines = NETWORK.plugin.Describe()

			if (#lines == 0) then
				return NETWORK.chat.Notice(client, L("pluginsNone"))
			end

			NETWORK.chat.Notice(client, L("pluginsList", #lines))

			for _, line in ipairs(lines) do
				NETWORK.chat.Notice(client, "  " .. line)
			end
		end
	})

	NETWORK.command.Register("plugin", {
		adminOnly = true,
		description = "cmdPlugin",
		usage = "/plugin <id> <on|off>",
		OnRun = function(command, client, arguments)
			local id = string.lower(arguments[1] or "")
			local state = string.lower(arguments[2] or "")

			if (!NETWORK.plugin.stored[id]) then
				return NETWORK.chat.Notice(client, L("pluginUnknown"))
			end

			if (state != "on" and state != "off") then
				return NETWORK.chat.Notice(client, L("pluginState", id,
					NETWORK.plugin.IsEnabled(id) and "on" or "off"))
			end

			NETWORK.plugin.SetEnabled(id, state == "on")

			NETWORK.chat.Notice(client, L("pluginState", id, state))
		end
	})
end

hook.Run("NetworkPluginsLoaded")
