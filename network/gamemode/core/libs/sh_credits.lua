NETWORK.credits = NETWORK.credits or {}

local C = NETWORK.credits

C.owner = "76561199171490769"

C.list = C.list or {}
C.maxEntries = 64

C.defaults = {
	{role = "Основатель", name = "Shreder", about = "Основатель проекта."},
	{role = "Второй основатель", name = "Shar4ik", about = "Сооснователь проекта, идеи."},
	{role = "Карта", name = "Singularity", about = "Карта города."},
	{role = "Звуки, музыка, модели", name = "Project: Synapse", about = "Звуковое оформление, музыка и модели."},
	{role = "Сервер", name = "Ranya, Леня, Дони, Ulioper, Дефчик, Dave Tirint и другие",
		about = "Занимались сервером: настройка, поддержка, администрирование."},
	{role = "Идеи", name = "Васька, Shar4ik, Фелино и другие", about = "Идеи и предложения по механикам."}
}

function C.Reset()
	C.list = {}

	for _, entry in ipairs(C.defaults) do
		C.list[#C.list + 1] = {role = entry.role, name = entry.name, about = entry.about or ""}
	end
end

function C.IsOwner(client)
	return IsValid(client) and client:SteamID64() == C.owner
end

function C.Count()
	return #C.list
end

if (SERVER) then
	util.AddNetworkString("nwCreditsSync")

	local dataPath = "network/credits.txt"

	function C.Save()
		file.CreateDir("network")
		file.Write(dataPath, util.TableToJSON(C.list, true))
	end

	function C.Load()
		local raw = file.Read(dataPath, "DATA")
		local data = raw and util.JSONToTable(raw)

		C.list = istable(data) and data or {}

		if (#C.list == 0) then
			C.Reset()
		end
	end

	function C.Sync(target)
		net.Start("nwCreditsSync")
			NETWORK.util.WriteTable(C.list)

		if (IsValid(target)) then
			net.Send(target)
		else
			net.Broadcast()
		end
	end

	hook.Add("Initialize", "nwCredits", function()
		C.Load()
	end)

	hook.Add("PlayerInitialSpawn", "nwCredits", function(client)
		timer.Simple(2, function()
			if (IsValid(client)) then
				C.Sync(client)
			end
		end)
	end)

	local function Deny(client)
		NETWORK.notice.Send(client, "creditsNoAccess", "warn")
	end

	NETWORK.command.Register("creditsadd", {
		description = "cmdCreditsAdd",
		usage = "/creditsadd <роль> / <имя> / <описание>",
		OnRun = function(command, client, arguments)
			if (!C.IsOwner(client)) then
				return Deny(client)
			end

			local text = table.concat(arguments, " ")
			local parts = string.Explode("/", text)

			local role = NETWORK.util.Sanitise(parts[1] or "", 40)
			local name = NETWORK.util.Sanitise(parts[2] or "", 40)
			local about = NETWORK.util.Sanitise(parts[3] or "", 200, true)

			if (role == "" or name == "") then
				return NETWORK.notice.Send(client, "creditsFormat", "warn")
			end

			if (#C.list >= C.maxEntries) then
				return NETWORK.notice.Send(client, "creditsFull", "warn")
			end

			C.list[#C.list + 1] = {role = role, name = name, about = about}

			C.Save()
			C.Sync()

			NETWORK.notice.Send(client, "creditsAdded", "good", #C.list)
		end
	})

	NETWORK.command.Register("creditsreset", {
		description = "cmdCreditsReset",
		usage = "/creditsreset",
		OnRun = function(command, client)
			if (!C.IsOwner(client)) then
				return Deny(client)
			end

			C.Reset()
			C.Save()
			C.Sync()

			NETWORK.notice.Send(client, "creditsAdded", "good", #C.list)
		end
	})

	NETWORK.command.Register("creditsdel", {
		description = "cmdCreditsDel",
		usage = "/creditsdel <номер>",
		OnRun = function(command, client, arguments)
			if (!C.IsOwner(client)) then
				return Deny(client)
			end

			local index = math.floor(tonumber(arguments[1]) or 0)

			if (!C.list[index]) then
				return NETWORK.notice.Send(client, "creditsNoRow", "warn")
			end

			table.remove(C.list, index)

			C.Save()
			C.Sync()

			NETWORK.notice.Send(client, "creditsRemoved", "good")
		end
	})

	NETWORK.command.Register("creditsmove", {
		description = "cmdCreditsMove",
		usage = "/creditsmove <номер> <новый номер>",
		OnRun = function(command, client, arguments)
			if (!C.IsOwner(client)) then
				return Deny(client)
			end

			local from = math.floor(tonumber(arguments[1]) or 0)
			local to = math.Clamp(math.floor(tonumber(arguments[2]) or 0), 1, #C.list)

			if (!C.list[from] or from == to) then
				return NETWORK.notice.Send(client, "creditsNoRow", "warn")
			end

			local entry = table.remove(C.list, from)

			table.insert(C.list, to, entry)

			C.Save()
			C.Sync()

			NETWORK.notice.Send(client, "creditsMoved", "good", to)
		end
	})

	return
end

net.Receive("nwCreditsSync", function()
	C.list = NETWORK.util.ReadTable() or {}
end)
