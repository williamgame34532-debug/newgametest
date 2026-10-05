NETWORK.protect = NETWORK.protect or {}

NETWORK.protect.interval = 120

if (SERVER) then
	util.AddNetworkString("nwIntegrityAsk")
	util.AddNetworkString("nwIntegrityAnswer")

	NETWORK.protect.files = NETWORK.protect.files or {}
	NETWORK.protect.hashes = NETWORK.protect.hashes or {}

	function NETWORK.protect.Build()
		NETWORK.protect.files = {}
		NETWORK.protect.hashes = {}

		local folders = {
			NETWORK.folder .. "/gamemode/core/libs/",
			NETWORK.folder .. "/gamemode/core/derma/"
		}

		for _, folder in ipairs(folders) do
			local files = file.Find(folder .. "cl_*.lua", "LUA")

			for _, name in ipairs(files or {}) do
				local path = folder .. name
				local contents = file.Read(path, "LUA")

				if (contents) then
					NETWORK.protect.files[#NETWORK.protect.files + 1] = path
					NETWORK.protect.hashes[path] = util.CRC(contents)
				end
			end
		end

		NETWORK.util.Print("Проверка целостности: файлов в списке — " ..
			#NETWORK.protect.files)
	end

	hook.Add("Initialize", "nwProtect", function()
		timer.Simple(5, NETWORK.protect.Build)
	end)

	function NETWORK.protect.Ask(client)
		if (#NETWORK.protect.files == 0) then
			return
		end

		local path = NETWORK.protect.files[math.random(#NETWORK.protect.files)]

		client.nwIntegrity = {path = path, time = CurTime()}

		net.Start("nwIntegrityAsk")
			net.WriteString(path)
		net.Send(client)
	end

	net.Receive("nwIntegrityAnswer", function(_, client)
		local hash = net.ReadString()
		local ask = client.nwIntegrity

		client.nwIntegrity = nil

		if (!ask or CurTime() - ask.time > 30) then
			return
		end

		local expected = NETWORK.protect.hashes[ask.path]

		if (!expected or hash == expected) then
			return
		end

		local message = string.format(
			"Несовпадение контрольной суммы у %s: файл %s",
			client:SteamID(), ask.path)

		NETWORK.util.PrintWarning(message)

		if (NETWORK.log and NETWORK.log.Add) then
			NETWORK.log.Add("admin", message)
		end

		hook.Run("NetworkIntegrityFailed", client, ask.path)

		if (NETWORK.config.Get("integrityKick")) then
			client:Kick("Проверка целостности клиентских файлов не пройдена")
		end
	end)

	timer.Create("nwProtect", NETWORK.protect.interval, 0, function()
		for _, client in ipairs(player.GetAll()) do
			if (!client:IsBot()) then
				NETWORK.protect.Ask(client)
			end
		end
	end)

	NETWORK.command.Register("luaaudit", {
		description = "cmdLuaAudit",
		usage = "/luaaudit",
		adminOnly = true,
		OnRun = function(command, client)
			local total = 0
			local list = {}

			for _, path in ipairs(NETWORK.protect.files) do
				local size = file.Size(path, "LUA")

				total = total + math.max(size, 0)
				list[#list + 1] = {path = path, size = size}
			end

			table.sort(list, function(a, b)
				return a.size > b.size
			end)

			client:PrintMessage(HUD_PRINTCONSOLE, string.format(
				"Клиентских файлов: %d, суммарно %.1f КБ",
				#list, total / 1024))

			for index = 1, math.min(#list, 20) do
				client:PrintMessage(HUD_PRINTCONSOLE, string.format(
					"  %6.1f КБ  %s", list[index].size / 1024, list[index].path))
			end

			NETWORK.chat.Notice(client, "logsPrinted")
		end
	})

else
	net.Receive("nwIntegrityAsk", function()
		local path = net.ReadString()
		local contents = file.Read(path, "LUA")

		net.Start("nwIntegrityAnswer")
			net.WriteString(contents and util.CRC(contents) or "")
		net.SendToServer()
	end)

	local guarded = {}

	timer.Simple(10, function()
		for _, name in ipairs({"Start", "SendToServer", "ReadString",
			"WriteString"}) do
			local info = debug.getinfo(net[name], "S")

			guarded[name] = info and info.short_src or "?"
		end
	end)

	timer.Create("nwProtectSelf", 60, 0, function()
		for name, source in pairs(guarded) do
			local info = debug.getinfo(net[name], "S")

			if (info and info.short_src != source) then
				NETWORK.util.PrintWarning(
					"Функция net." .. name .. " была подменена.")

				break
			end
		end
	end)
end

NETWORK.config.Register("integrityKick", {
	name = "cfgIntegrityKick",
	description = "cfgIntegrityKickDesc",
	category = "general",
	type = "bool",
	default = false
})
