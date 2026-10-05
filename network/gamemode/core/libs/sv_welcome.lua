util.AddNetworkString("nwWelcome")
util.AddNetworkString("nwWelcomeSave")

NETWORK.welcome = NETWORK.welcome or {}

local dataPath = "network/welcome.txt"

NETWORK.welcome.data = {
	title = "ПРИВЕТ!",
	body = "Добро пожаловать на сервер.\n\nАдминистратор может изменить этот текст " ..
		"кнопкой в правом верхнем углу.",
	icon = "icon16/user.png"
}

function NETWORK.welcome.Load()
	local contents = file.Read(dataPath, "DATA")

	if (!contents) then
		return
	end

	local data = util.JSONToTable(contents)

	if (istable(data)) then
		NETWORK.welcome.data = data
	end
end

function NETWORK.welcome.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(NETWORK.welcome.data, true))
end

function NETWORK.welcome.Send(client)
	net.Start("nwWelcome")
		NETWORK.util.WriteTable(NETWORK.welcome.data)
	net.Send(client)
end

net.Receive("nwWelcomeSave", function(_, client)
	if (!client:IsAdmin()) then
		return
	end

	local payload = NETWORK.util.ReadTable()

	NETWORK.welcome.data = {
		title = NETWORK.util.Sanitise(payload.title, 48),
		body = NETWORK.util.Sanitise(payload.body, 1200, true),
		icon = isstring(payload.icon) and payload.icon or "icon16/user.png"
	}

	NETWORK.welcome.Save()

	for _, target in ipairs(player.GetAll()) do
		if (target:IsAdmin()) then
			NETWORK.welcome.Send(target)
		end
	end
end)

hook.Add("NetworkCharacterLoaded", "nwWelcome", function(client)
	timer.Simple(1.2, function()

		if (IsValid(client) and !NETWORK.factions.IsAlliance(client)) then
			NETWORK.welcome.Send(client)
		end
	end)
end)

NETWORK.welcome.Load()

NETWORK.command.Register("welcome", {
	description = "cmdWelcome",
	usage = "/welcome",
	OnRun = function(command, client)
		NETWORK.welcome.Send(client)
	end
})
