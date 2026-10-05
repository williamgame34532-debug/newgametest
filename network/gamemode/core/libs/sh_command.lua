NETWORK.command = NETWORK.command or {}
NETWORK.command.stored = NETWORK.command.stored or {}

function NETWORK.command.Register(id, data)
	data.id = id
	data.aliases = data.aliases or {}
	data.adminOnly = tobool(data.adminOnly)
	data.description = data.description or ""
	data.usage = data.usage or ("/" .. id)

	NETWORK.command.stored[string.lower(id)] = data

	for _, alias in ipairs(data.aliases) do
		NETWORK.command.stored[string.lower(alias)] = data
	end

	return data
end

function NETWORK.command.GetAll()
	local list = {}
	local seen = {}

	for _, data in pairs(NETWORK.command.stored) do
		if (seen[data.id]) then
			continue
		end

		seen[data.id] = true
		list[#list + 1] = data
	end

	table.sort(list, function(a, b)
		return a.id < b.id
	end)

	return list
end

function NETWORK.command.Get(id)
	return NETWORK.command.stored[string.lower(id or "")]
end

function NETWORK.command.Parse(client, text)
	if (string.sub(text, 1, 1) != "/") then
		return false
	end

	local arguments = string.Explode(" ", string.sub(text, 2))
	local name = table.remove(arguments, 1)
	local command = NETWORK.command.Get(name)

	if (!command and NETWORK.chat and NETWORK.chat.GetPrefixes) then

		local lower = NETWORK.util.Lower(text)

		for _, entry in ipairs(NETWORK.chat.GetPrefixes()) do
			local length = entry.length

			if (string.sub(lower, 1, length + 1) == entry.prefix .. " ") then
				return false
			end

			if (entry.class.bNoSpaceAfter and
				string.sub(lower, 1, length) == entry.prefix) then
				return false
			end
		end
	end

	if (!command) then
		if (SERVER) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString(L("cmdUnknown", name))
			net.Send(client)
		end

		return true
	end

	if (SERVER) then
		if (command.adminOnly and !client:IsAdmin()) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString(L("cmdNoAccess"))
			net.Send(client)

			return true
		end

		if (command.OnRun) then
			command:OnRun(client, arguments)

			hook.Run("NetworkCommandRun", client, command, arguments)
		end
	end

	return true
end
