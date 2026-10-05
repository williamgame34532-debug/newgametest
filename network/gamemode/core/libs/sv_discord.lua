NETWORK.discord = NETWORK.discord or {}

local D = NETWORK.discord

local configPath = "network/discord.txt"

D.queue = D.queue or {}
D.interval = 3
D.maxLength = 1800

function D.LoadConfig()
	local raw = file.Read(configPath, "DATA")
	local data = raw and util.JSONToTable(raw)

	if (!istable(data)) then
		data = {
			enabled = false,
			name = "Network",
			webhooks = {chat = "", join = "", admin = "", death = ""}
		}

		file.CreateDir("network")
		file.Write(configPath, util.TableToJSON(data, true))
	end

	D.config = data

	return data
end

hook.Add("Initialize", "nwDiscord", function()
	D.LoadConfig()
end)

function D.Enabled()
	return istable(D.config) and D.config.enabled == true
end

function D.Webhook(kind)
	local url = (D.config and D.config.webhooks or {})[kind]

	return isstring(url) and url != "" and url or nil
end

function D.Clean(text)
	text = string.gsub(tostring(text or ""), "([`*_~|])", "\\%1")
	text = string.gsub(text, "@everyone", "@ everyone")
	text = string.gsub(text, "@here", "@ here")

	return string.sub(text, 1, 240)
end

function D.Send(kind, text)
	if (!D.Enabled() or !D.Webhook(kind)) then
		return
	end

	D.queue[kind] = D.queue[kind] or {}

	local list = D.queue[kind]

	list[#list + 1] = "`" .. os.date("%H:%M:%S") .. "` " .. text
end

timer.Create("nwDiscord", D.interval, 0, function()
	if (!D.Enabled()) then
		return
	end

	for kind, list in pairs(D.queue) do
		if (#list == 0) then
			continue
		end

		local url = D.Webhook(kind)

		D.queue[kind] = {}

		if (!url) then
			continue
		end

		local content = table.concat(list, "\n")

		while (string.len(content) > D.maxLength) do
			content = string.sub(content, 1, D.maxLength)
		end

		http.Post(url, {
			username = (D.config.name or "Network") .. " · " .. kind,
			content = content
		}, function() end, function(err)
			NETWORK.util.PrintWarning("Discord: " .. tostring(err))
		end)
	end
end)

hook.Add("NetworkChatSent", "nwDiscord", function(speaker, id, text)
	if (!IsValid(speaker) or !speaker:HasCharacter()) then
		return
	end

	D.Send("chat", string.format("**%s** [%s]: %s",
		D.Clean(speaker:GetCharacterName()), D.Clean(id), D.Clean(text)))
end)

hook.Add("NetworkCharacterLoaded", "nwDiscord", function(client, character)
	D.Send("join", string.format("→ **%s** (%s) зашёл за персонажа #%s",
		D.Clean(client:Nick()), client:SteamID(), tostring(character:GetID())))
end)

hook.Add("PlayerDisconnected", "nwDiscord", function(client)
	D.Send("join", string.format("← **%s** (%s) вышел",
		D.Clean(client:Nick()), client:SteamID()))
end)

hook.Add("PlayerDeath", "nwDiscord", function(client, inflictor, attacker)
	local killer = IsValid(attacker) and attacker:IsPlayer() and
		attacker:GetCharacterName() or (IsValid(attacker) and attacker:GetClass() or "мир")

	D.Send("death", string.format("† **%s** убит: %s",
		D.Clean(client:GetCharacterName()), D.Clean(killer)))
end)

hook.Add("NetworkCommandRun", "nwDiscord", function(client, command, arguments)
	if (!istable(command) or !command.adminOnly) then
		return
	end

	D.Send("admin", string.format("⚙ **%s** → /%s %s",
		D.Clean(IsValid(client) and client:GetCharacterName() or "консоль"),
		D.Clean(command.id or "?"),
		D.Clean(table.concat(arguments or {}, " "))))
end)

concommand.Add("network_discord_test", function(client)
	if (IsValid(client) and !client:IsSuperAdmin()) then
		return
	end

	D.LoadConfig()

	if (!D.Enabled()) then
		return NETWORK.util.Print("Discord: выключен в data/" .. configPath)
	end

	for kind in pairs(D.config.webhooks or {}) do
		D.Send(kind, "Проверка связи.")
	end

	NETWORK.util.Print("Discord: пробные строки поставлены в очередь.")
end)
