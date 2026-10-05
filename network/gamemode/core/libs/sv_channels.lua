local CH = NETWORK.channels
local dataPath = "network/channels.txt"

CH.messages = CH.messages or {}

function CH.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(CH.messages))
end

function CH.Load()
	CH.messages = util.JSONToTable(file.Read(dataPath, "DATA") or "") or {}
end

function CH.GetMessages(id)
	CH.messages[id] = CH.messages[id] or {}

	return CH.messages[id]
end

local function Signature(client)
	if (NETWORK.factions.IsAlliance(client)) then
		return client:GetCharacterName()
	end

	local character = client:GetCharacter()

	return client:GetCharacterName() .. " #" ..
		(character and NETWORK.terminal.GetCitizenID(character) or "?")
end

function CH.Post(client, terminal, id, text)
	local channel = CH.Get(id)

	if (!channel or !channel.terminals[terminal] or !channel.write(client)) then
		return false, "chanNoAccess"
	end

	text = NETWORK.util.Sanitise(text or "", CH.textMax)

	if (text == "") then
		return false
	end

	if ((client.nwNextChannel or 0) > CurTime()) then
		return false, "chanCooldown"
	end

	client.nwNextChannel = CurTime() + CH.cooldown

	local list = CH.GetMessages(id)

	list[#list + 1] = {
		author = Signature(client),
		faction = client:GetCharacterFaction() or "",
		text = text,
		time = os.date("%d.%m %H:%M")
	}

	while (#list > CH.max) do
		table.remove(list, 1)
	end

	CH.Save()

	if (NETWORK.chat and NETWORK.chat.Log) then
		NETWORK.chat.Log(client, "channel_" .. id, text)
	end

	CH.RefreshViewers(id)

	return true
end

function CH.Clear(id)
	CH.messages[id] = {}

	CH.Save()
	CH.RefreshViewers(id)
end

function CH.Delete(id, index)
	local list = CH.GetMessages(id)

	if (list[index]) then
		table.remove(list, index)

		CH.Save()
		CH.RefreshViewers(id)
	end
end

function CH.RefreshViewers(id)
	for _, client in ipairs(player.GetAll()) do
		if (client.nwCmbPage == "channels" and client.nwChannel == id) then
			NETWORK.cmbterm.Refresh(client)
		end

		if (IsValid(client.nwTerminal)) then
			NETWORK.terminal.Sync(client)
		end
	end
end

function CH.BuildPayload(client, terminal, current)
	local channels = {}

	for _, data in ipairs(CH.GetFor(client, terminal)) do
		channels[#channels + 1] = {
			id = data.id,
			name = data.name,
			color = {data.color.r, data.color.g, data.color.b},
			bWrite = data.write(client)
		}
	end

	if (!current or !CH.Get(current) or !CH.Get(current).terminals[terminal] or
		!CH.Get(current).read(client)) then
		current = channels[1] and channels[1].id or nil
	end

	client.nwChannel = current

	return {
		channels = channels,
		current = current,
		messages = current and CH.GetMessages(current) or {},
		bAdmin = client:IsAdmin()
	}
end

hook.Add("Initialize", "nwChannels", function()
	CH.Load()

	local actions = NETWORK.terminal.actions

	if (!actions) then
		return
	end

	actions.board_post = function(client, entity, payload)
		local bOk, key = CH.Post(client, "civic", "board", payload.text)

		return key or (bOk and "chanPosted" or nil)
	end
end)

hook.Add("NetworkTerminalData", "nwChannels", function(client, data)
	local board = CH.Get("board")

	data.board = CH.GetMessages("board")
	data.bBoardWrite = board != nil and board.write(client) == true
end)

NETWORK.command.Register("channelclear", {
	description = "cmdChannelClear",
	usage = "/channelclear <канал>",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		local id = string.lower(arguments[1] or "")

		if (!CH.Get(id)) then
			return NETWORK.notice.Send(client, "chanUnknown", "bad")
		end

		CH.Clear(id)

		NETWORK.notice.Send(client, "chanCleared", "good")
	end
})
