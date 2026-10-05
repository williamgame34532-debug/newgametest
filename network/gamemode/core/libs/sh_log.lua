NETWORK.log = NETWORK.log or {}

NETWORK.log.categories = {
	{id = "death", name = "logCatDeath", default = true},
	{id = "lock", name = "logCatLock", default = true},
	{id = "zone", name = "logCatZone", default = true},
	{id = "item", name = "logCatItem", default = false},
	{id = "admin", name = "logCatAdmin", default = true}
}

NETWORK.log.file = "network/logs"

function NETWORK.log.IsEnabled(category)
	return NETWORK.config.Get("log_" .. category) != false
end

if (SERVER) then

	local function Path()
		return NETWORK.log.file .. "/" .. os.date("%Y-%m-%d") .. ".txt"
	end

	function NETWORK.log.Add(category, text, position)
		if (!NETWORK.log.IsEnabled(category)) then
			return
		end

		text = tostring(text or "")

		local stamp = os.date("%H:%M:%S")
		local line = string.format("[%s] [%s] %s", stamp, string.upper(category),
			text)

		if (isvector(position)) then
			line = line .. string.format(" @ %d %d %d", position.x, position.y,
				position.z)
		end

		NETWORK.util.Print(line)

		file.CreateDir("network")
		file.CreateDir(NETWORK.log.file)
		file.Append(Path(), line .. "\n")

		if (!NETWORK.config.Get("logNotifyAdmins")) then
			return
		end

		for _, client in ipairs(player.GetAll()) do
			if (client:IsAdmin()) then
				net.Start("nwChatMessage")
					net.WriteString("notice")
					net.WriteEntity(NULL)
					net.WriteString("")
					net.WriteString(line)
				net.Send(client)
			end
		end
	end

	function NETWORK.log.Name(client)
		if (!IsValid(client) or !client:IsPlayer()) then
			return IsValid(client) and client:GetClass() or "мир"
		end

		if (!client:HasCharacter()) then
			return client:SteamID()
		end

		return client:GetCharacterName() .. " (" .. client:SteamID() .. ")"
	end

	function NETWORK.log.Dispatch(text, color)
		if (!NETWORK.dispatch or !NETWORK.dispatch.Send) then
			return
		end

		NETWORK.dispatch.Send(text, color)
	end

	hook.Add("PlayerDeath", "nwLogDeath", function(client, inflictor, attacker)
		local zone = NETWORK.zone and NETWORK.zone.At and
			NETWORK.zone.At(client:GetPos())

		NETWORK.log.Add("death", string.format("%s погиб от %s%s",
			NETWORK.log.Name(client), NETWORK.log.Name(attacker),
			zone and (" [зона: " .. (zone.name or zone.id or "?") .. "]") or ""),
			client:GetPos())
	end)

	hook.Add("NetworkLockOpened", "nwLogLock", function(client, entity, method)
		local zone = NETWORK.zone and NETWORK.zone.At and
			NETWORK.zone.At(entity:GetPos())

		NETWORK.log.Add("lock", string.format("%s открыл замок (%s)%s",
			NETWORK.log.Name(client), method or "ключ",
			zone and (" в зоне «" .. (zone.name or zone.id) .. "»") or ""),
			entity:GetPos())

		if (!IsValid(client)) then
			return
		end

		local who = client:GetNWString("nwCallsign", "")

		if (who == "") then
			who = client:GetCharacterName()
		end

		NETWORK.log.Dispatch(string.format("%s :: %s %s", who,
			method == "взлом" and "ВЗЛОМ ДВЕРИ" or "ВСКРЫТИЕ ЗАМКА",
			zone and (zone.name or zone.id) or ""),
			method == "взлом" and Color(232, 92, 92) or nil)
	end)

	hook.Add("NetworkForcefieldMode", "nwLogField", function(client, entity, mode)
		local names = {
			[1] = "ОТКЛЮЧЕНО",
			[2] = "АВАРИЯ",
			[3] = "ПРОПУСК ПО КАРТЕ",
			[4] = "ТОЛЬКО АЛЬЯНС",
			[5] = "ПРОПУСК ГСР"
		}

		local label = names[mode] or tostring(mode)

		NETWORK.log.Add("lock", string.format("%s: силовое поле — %s",
			NETWORK.log.Name(client), label), IsValid(entity) and
			entity:GetPos() or nil)

		local who = IsValid(client) and
			(client:GetNWString("nwCallsign", "") != "" and
			client:GetNWString("nwCallsign", "") or client:GetCharacterName()) or
			"СИСТЕМА"

		NETWORK.log.Dispatch(who .. " :: ПОЛЕ — " .. label,
			mode == 1 and Color(232, 92, 92) or nil)
	end)

	hook.Add("NetworkZoneEntered", "nwLogZone", function(client, zone)

		if (!zone or !zone.bRestricted) then
			return
		end

		NETWORK.log.Add("zone", string.format("%s вошёл в закрытую зону «%s»",
			NETWORK.log.Name(client), zone.name or zone.id), client:GetPos())
	end)

	NETWORK.command.Register("logs", {
		description = "cmdLogs",
		usage = "/logs [строк]",
		adminOnly = true,
		OnRun = function(command, client, arguments)
			local count = math.Clamp(math.Round(tonumber(arguments[1]) or 15),
				1, 60)
			local contents = file.Read(Path(), "DATA")

			if (!contents or contents == "") then
				return NETWORK.chat.Notice(client, "logsEmpty")
			end

			local lines = string.Explode("\n", contents)
			local shown = 0

			for index = #lines, 1, -1 do
				if (shown >= count) then
					break
				end

				if (string.Trim(lines[index]) != "") then
					shown = shown + 1
				end
			end

			for index = math.max(#lines - count, 1), #lines do
				if (string.Trim(lines[index] or "") != "") then
					client:PrintMessage(HUD_PRINTCONSOLE, lines[index])
				end
			end

			NETWORK.chat.Notice(client, "logsPrinted")
		end
	})
end

for _, entry in ipairs(NETWORK.log.categories) do
	NETWORK.config.Register("log_" .. entry.id, {
		name = entry.name,
		description = "logCatDescription",
		category = "logs",
		type = "bool",
		default = entry.default
	})
end

NETWORK.config.Register("logNotifyAdmins", {
	name = "logNotify",
	description = "logNotifyDescription",
	category = "logs",
	type = "bool",
	default = false
})
