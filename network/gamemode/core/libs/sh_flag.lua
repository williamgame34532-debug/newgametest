NETWORK.flag = NETWORK.flag or {}
NETWORK.flag.list = NETWORK.flag.list or {}

function NETWORK.flag.Register(flag, description, callback)
	NETWORK.flag.list[flag] = {
		flag = flag,
		description = description,
		OnChanged = callback
	}
end

function NETWORK.flag.Get(flag)
	return NETWORK.flag.list[flag]
end

NETWORK.flag.Register("t", "flagTrade")
NETWORK.flag.Register("w", "flagWeapons")
NETWORK.flag.Register("o", "flagOutside")
NETWORK.flag.Register("b", "flagBusiness")

local PLAYER = FindMetaTable("Player")

function PLAYER:GetFlags()
	return self:GetNWString("nwFlags", "")
end

function PLAYER:HasFlag(flags)
	local current = self:GetFlags()

	for index = 1, #flags do
		if (string.find(current, string.sub(flags, index, index), 1, true)) then
			return true
		end
	end

	return false
end

if (SERVER) then
	local dataPath = "network/flags.txt"

	NETWORK.flag.stored = NETWORK.flag.stored or {}

	function NETWORK.flag.SaveAll()
		file.CreateDir("network")
		file.Write(dataPath, util.TableToJSON(NETWORK.flag.stored, true))
	end

	function NETWORK.flag.LoadAll()
		local raw = file.Read(dataPath, "DATA")

		NETWORK.flag.stored = raw and util.JSONToTable(raw) or {}
	end

	hook.Add("Initialize", "nwFlagLoad", function()
		NETWORK.flag.LoadAll()
	end)

	local function Key(client)
		local character = client:GetCharacter()

		return character and tostring(character:GetID())
	end

	function NETWORK.flag.Apply(client)
		local key = Key(client)

		client:SetNWString("nwFlags", key and NETWORK.flag.stored[key] or "")
	end

	hook.Add("NetworkCharacterLoaded", "nwFlags", function(client)
		NETWORK.flag.Apply(client)
	end)

	function NETWORK.flag.Give(client, flags)
		local key = Key(client)

		if (!key) then
			return
		end

		local current = NETWORK.flag.stored[key] or ""

		for index = 1, #flags do
			local flag = string.sub(flags, index, index)

			if (NETWORK.flag.Get(flag) and !string.find(current, flag, 1, true)) then
				current = current .. flag

				local data = NETWORK.flag.Get(flag)

				if (data.OnChanged) then
					data.OnChanged(client, true)
				end
			end
		end

		NETWORK.flag.stored[key] = current

		NETWORK.flag.SaveAll()
		NETWORK.flag.Apply(client)
	end

	function NETWORK.flag.Take(client, flags)
		local key = Key(client)

		if (!key) then
			return
		end

		local current = NETWORK.flag.stored[key] or ""

		for index = 1, #flags do
			local flag = string.sub(flags, index, index)

			if (string.find(current, flag, 1, true)) then
				current = string.gsub(current, flag, "")

				local data = NETWORK.flag.Get(flag)

				if (data and data.OnChanged) then
					data.OnChanged(client, false)
				end
			end
		end

		NETWORK.flag.stored[key] = current != "" and current or nil

		NETWORK.flag.SaveAll()
		NETWORK.flag.Apply(client)
	end

	NETWORK.command.Register("flag", {
		description = "cmdFlag",
		usage = "/flag <игрок> <+буквы|-буквы>",
		example = "/flag Иванов +tw",
		adminOnly = true,
		OnRun = function(command, client, arguments)
			local target = NETWORK.permission.Find(arguments[1] or "")

			if (!IsValid(target)) then
				return NETWORK.chat.Notice(client, "permNoTarget")
			end

			if (!target:HasCharacter()) then
				return NETWORK.chat.Notice(client, "adminNoCharacter")
			end

			local text = arguments[2] or ""
			local sign = string.sub(text, 1, 1)
			local flags = string.sub(text, 2)

			if ((sign != "+" and sign != "-") or flags == "") then
				return NETWORK.chat.Notice(client, "flagUsage")
			end

			if (sign == "+") then
				NETWORK.flag.Give(target, flags)
			else
				NETWORK.flag.Take(target, flags)
			end

			NETWORK.log.Add("admin", string.format("%s изменил флаги %s: %s",
				NETWORK.log.Name(client), NETWORK.log.Name(target), text))

			NETWORK.chat.Notice(client, "flagDone")
			NETWORK.chat.Notice(target, sign == "+" and "flagGiven" or "flagTaken")
		end
	})

	NETWORK.command.Register("flaghelp", {
		description = "cmdFlaghelp",
		usage = "/flaghelp",
		adminOnly = true,
		OnRun = function(command, client)
			for flag, data in SortedPairs(NETWORK.flag.list) do
				client:PrintMessage(HUD_PRINTCONSOLE,
					flag .. " — " .. L(data.description))
			end

			NETWORK.chat.Notice(client, "logsPrinted")
		end
	})
end
