local function Notice(client, text)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(text)
	net.Send(client)
end

NETWORK.command.Register("roll", {
	description = "cmdRoll",
	usage = "/roll [максимум]",
	OnRun = function(command, client, arguments)
		local maximum = math.Clamp(tonumber(arguments[1]) or 100, 2, 1000000)
		local result = math.random(1, maximum)

		NETWORK.chat.Send(client, "it", string.format(L("rollResult"), result, maximum))
	end
})

NETWORK.command.Register("advert", {
	description = "cmdAdvert",
	usage = "/advert <текст>",
	aliases = {"reklama"},
	OnRun = function(command, client, arguments)

		if (!client:HasPermission("advert")) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("advertNoAccess")
			net.Send(client)

			return
		end

		local text = NETWORK.util.Sanitise(table.concat(arguments, " "), 180)

		if (NETWORK.util.Length(text) < 3) then
			return
		end

		if ((client.nwNextAdvert or 0) > CurTime()) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("advertWait")
			net.Send(client)

			return
		end

		client.nwNextAdvert = CurTime() + 60

		for _, target in ipairs(player.GetAll()) do
			net.Start("nwChatMessage")
				net.WriteString("advert")
				net.WriteEntity(client)
				net.WriteString(client:GetCharacterName())
				net.WriteString(NETWORK.chat.Format(text))
			net.Send(target)
		end
	end
})

NETWORK.command.Register("advertaccess", {
	adminOnly = true,
	description = "cmdAdvertAccess",
	usage = "/advertaccess <игрок> [0/1]",
	aliases = {"advertperm"},
	OnRun = function(command, client, arguments)
		local target = NETWORK.permission.Find(arguments[1] or "")

		if (!IsValid(target)) then
			return Notice(client, L("permNoTarget"))
		end

		local bValue = arguments[2] == nil and !target:HasPermission("advert") or
			tobool(arguments[2])

		NETWORK.permission.Set(target, "advert", bValue)

		Notice(client, L(bValue and "advertGranted" or "advertRevoked",
			target:GetCharacterName()))

		Notice(target, L(bValue and "advertYouGranted" or "advertYouRevoked"))
	end
})

NETWORK.command.Register("give", {
	adminOnly = true,
	description = "cmdGive",
	usage = "/give <игрок> <предмет> [количество]",
	OnRun = function(command, client, arguments)
		local target = NETWORK.permission.Find(arguments[1])

		if (!IsValid(target) or !target:HasCharacter()) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("permNoTarget")
			net.Send(client)

			return
		end

		local base = NETWORK.item.Find(arguments[2])

		if (!base) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("giveNoItem")
			net.Send(client)

			return
		end

		NETWORK.inventory.Give(target, base.id,
			math.Clamp(tonumber(arguments[3]) or 1, 1, 64))

		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString("adminDone")
		net.Send(client)
	end
})

NETWORK.command.Register("pm", {
	description = "cmdPM",
	usage = "/pm <игрок> <текст>",
	aliases = {"w2", "lichka"},
	OnRun = function(command, client, arguments)
		local target = NETWORK.permission.Find(arguments[1])

		if (!IsValid(target) or !target:HasCharacter()) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("permNoTarget")
			net.Send(client)

			return
		end

		if (target == client) then
			return
		end

		table.remove(arguments, 1)

		local text = NETWORK.chat.Format(NETWORK.util.Sanitise(
			table.concat(arguments, " "), 240))

		if (NETWORK.util.Length(text) < 2) then
			return
		end

		local name = client:GetCharacterName()

		net.Start("nwChatMessage")
			net.WriteString("pm")
			net.WriteEntity(client)
			net.WriteString(name)
			net.WriteString(text)
		net.Send(target)

		net.Start("nwChatMessage")
			net.WriteString("pmOut")
			net.WriteEntity(target)
			net.WriteString(target:GetCharacterName())
			net.WriteString(text)
		net.Send(client)

		client.nwLastPM = target
		target.nwLastPM = client
	end
})

NETWORK.command.Register("re", {
	description = "cmdReply",
	usage = "/re <текст>",
	aliases = {"reply"},
	OnRun = function(command, client, arguments)
		local target = client.nwLastPM

		if (!IsValid(target)) then
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString("pmNobody")
			net.Send(client)

			return
		end

		table.insert(arguments, 1, target:SteamID())

		NETWORK.command.Get("pm").OnRun(nil, client, arguments)
	end
})
