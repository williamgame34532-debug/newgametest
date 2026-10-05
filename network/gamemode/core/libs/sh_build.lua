NETWORK.build = NETWORK.build or {}

if (SERVER) then
	util.AddNetworkString("nwBuildCheck")

	NETWORK.command.Register("build", {
		description = "cmdBuild",
		usage = "/build",
		aliases = {"sborka", "version"},
		OnRun = function(command, client)

			NETWORK.notice.Send(client, "buildServer", "info",
				NETWORK.buildTag or "?")

			net.Start("nwBuildCheck")
				net.WriteString(NETWORK.buildTag or "?")
			net.Send(client)
		end
	})

	return
end

net.Receive("nwBuildCheck", function()
	local server = net.ReadString()
	local own = NETWORK.buildTag or "?"

	chat.AddText(Color(126, 176, 220), L("buildServer", server))
	chat.AddText(Color(126, 176, 220), L("buildClient", own))

	if (server == own) then
		chat.AddText(Color(120, 220, 140), L("buildMatch"))
	else
		chat.AddText(Color(232, 92, 92), L("buildStale"))
	end

	print("[Network] Сборка сервера: " .. server .. ", клиента: " .. own)
end)
