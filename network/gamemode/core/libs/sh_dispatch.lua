NETWORK.dispatch = NETWORK.dispatch or {}

NETWORK.dispatch.levels = {
	green = {label = "statusGreen", color = Color(96, 212, 120), speed = 1},
	yellow = {label = "statusYellow", color = Color(232, 206, 96), speed = 1.7},
	orange = {label = "statusOrange", color = Color(238, 152, 70), speed = 2.6},
	red = {label = "statusRed", color = Color(238, 88, 78), speed = 3.7},
	black = {label = "statusBlack", color = Color(220, 220, 228), speed = 5}
}

NETWORK.dispatch.order = {"green", "yellow", "orange", "red", "black"}
NETWORK.dispatch.maxLines = 6

function NETWORK.dispatch.GetStatus()
	local id = GetGlobalString("nwCityStatus", "green")

	return NETWORK.dispatch.levels[id] and id or "green"
end

function NETWORK.dispatch.GetLevel()
	return NETWORK.dispatch.levels[NETWORK.dispatch.GetStatus()]
end

if (SERVER) then
	util.AddNetworkString("nwDispatchLine")

	NETWORK.dispatch.lines = NETWORK.dispatch.lines or {}

	function NETWORK.dispatch.SetStatus(id)
		if (!NETWORK.dispatch.levels[id]) then
			return false
		end

		SetGlobalString("nwCityStatus", id)

		return true
	end

	function NETWORK.dispatch.Send(text, color)
		text = NETWORK.util.Sanitise(text, 90)

		if (text == "") then
			return
		end

		NETWORK.dispatch.lines[#NETWORK.dispatch.lines + 1] = text

		while (#NETWORK.dispatch.lines > NETWORK.dispatch.maxLines) do
			table.remove(NETWORK.dispatch.lines, 1)
		end

		for _, client in ipairs(player.GetAll()) do
			if (client:HasCharacter() and NETWORK.factions.IsAlliance(client)) then
				net.Start("nwDispatchLine")
					net.WriteString(text)
					net.WriteColor(color or Color(126, 200, 240), false)
					net.WriteString(NETWORK.dispatch.pendingSound or "")
				net.Send(client)
			end
		end

		NETWORK.dispatch.pendingSound = nil
	end

	function NETWORK.dispatch.SendRadio(text, color)
		NETWORK.dispatch.pendingSound = "framework/cmb/radio/off" ..
			math.random(9) .. ".wav"

		NETWORK.dispatch.Send(text, color)
	end

	NETWORK.command.Register("citystatus", {
		description = "cmdCityStatus",
		usage = "/citystatus <green|yellow|orange|red|black>",
		adminOnly = true,
		OnRun = function(command, client, arguments)
			local function Notice(key)
				net.Start("nwChatMessage")
					net.WriteString("notice")
					net.WriteEntity(NULL)
					net.WriteString("")
					net.WriteString(key)
				net.Send(client)
			end

			if (!NETWORK.dispatch.SetStatus(string.lower(arguments[1] or ""))) then
				Notice("statusUsage")

				return Notice(table.concat(NETWORK.dispatch.order, ", "))
			end

			NETWORK.dispatch.Send(L("statusChanged", string.upper(arguments[1])),
				NETWORK.dispatch.GetLevel().color)

			Notice("adminDone")
		end
	})

	NETWORK.command.Register("dispatch", {
		description = "cmdDispatch",
		usage = "/dispatch <текст>",
		adminOnly = true,
		OnRun = function(command, client, arguments)
			NETWORK.dispatch.Send(table.concat(arguments, " "))
		end
	})

	function NETWORK.dispatch.Broadcast(text)
		text = NETWORK.util.Sanitise(text, 200)

		if (text == "") then
			return false
		end

		NETWORK.dispatch.Send(text)

		local line = L("dispatchPrefix") .. " " .. text

		for _, client in ipairs(player.GetAll()) do
			if (client:HasCharacter() and NETWORK.factions.IsAlliance(client)) then
				net.Start("nwChatMessage")
					net.WriteString("dispatch")
					net.WriteEntity(NULL)
					net.WriteString("")
					net.WriteString(text)
				net.Send(client)
			end
		end

		hook.Run("NetworkDispatchBroadcast", text)

		return true
	end

	NETWORK.command.Register("disp", {
		description = "cmdDisp",
		usage = "/disp <текст>",
		adminOnly = true,
		aliases = {"dispsay"},
		OnRun = function(command, client, arguments)
			if (!NETWORK.dispatch.Broadcast(table.concat(arguments, " "))) then
				net.Start("nwChatMessage")
					net.WriteString("notice")
					net.WriteEntity(NULL)
					net.WriteString("")
					net.WriteString("dispEmpty")
				net.Send(client)
			end
		end
	})

	hook.Add("NetworkTerminalCall", "nwDispatch", function(caller, entity, reason)
		NETWORK.dispatch.Send(L("dispatchTerminal", reason), Color(238, 88, 78))
	end)
end
