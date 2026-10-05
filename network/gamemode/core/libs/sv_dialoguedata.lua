util.AddNetworkString("nwDialogueSync")
util.AddNetworkString("nwDialogueSave")
util.AddNetworkString("nwDialogueEditor")
util.AddNetworkString("nwDialogueCursor")

net.Receive("nwDialogueCursor", function(_, client)
	if (!client:IsAdmin()) then
		return
	end

	local id = net.ReadString()
	local x = net.ReadFloat()
	local y = net.ReadFloat()
	local receivers = {}

	for _, target in ipairs(player.GetAll()) do
		if (target != client and target:IsAdmin()) then
			receivers[#receivers + 1] = target
		end
	end

	if (#receivers == 0) then
		return
	end

	net.Start("nwDialogueCursor")
		net.WriteEntity(client)
		net.WriteString(id)
		net.WriteFloat(x)
		net.WriteFloat(y)
	net.Send(receivers)
end)

local dataPath = "network/dialogues.txt"

NETWORK.dialogue.custom = NETWORK.dialogue.custom or {}

function NETWORK.dialogue.SaveAll()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(NETWORK.dialogue.custom, true))
end

function NETWORK.dialogue.LoadAll()
	local contents = file.Read(dataPath, "DATA")

	if (contents) then
		local data = util.JSONToTable(contents)

		if (istable(data)) then
			NETWORK.dialogue.custom = data
		end
	end

	NETWORK.dialogue.ApplyAll()
end

function NETWORK.dialogue.ApplyAll()
	for id, data in pairs(NETWORK.dialogue.custom) do
		NETWORK.dialogue.Register(id, table.Copy(data))

		for questID, quest in pairs(data.quests or {}) do
			NETWORK.quest.Register(questID, table.Copy(quest))
		end
	end
end

function NETWORK.dialogue.Broadcast(target)
	net.Start("nwDialogueSync")
		NETWORK.util.WriteTable(NETWORK.dialogue.custom)

	if (IsValid(target)) then
		net.Send(target)
	else
		net.Broadcast()
	end
end

local function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

net.Receive("nwDialogueSave", function(_, client)
	if (!client:IsAdmin()) then
		Notice(client, "errNoAccess")

		return
	end

	local id = string.lower(NETWORK.util.Sanitise(net.ReadString(), 32))

	id = string.gsub(id, "[^%w_]", "")
	local payload = NETWORK.util.ReadTable()

	if (id == "" or !istable(payload)) then
		Notice(client, "editorNoID")

		return
	end

	if (payload.bDelete) then
		NETWORK.dialogue.custom[id] = nil
	else
		payload.id = id
		payload.nodes = payload.nodes or {}
		payload.quests = payload.quests or {}

		NETWORK.dialogue.custom[id] = payload
	end

	NETWORK.dialogue.SaveAll()
	NETWORK.dialogue.ApplyAll()
	NETWORK.dialogue.Broadcast()

	NETWORK.quest.Sync(client)

	Notice(client, "editorServerSaved")

	NETWORK.util.Print(string.format("%s сохранил диалог %s (узлов: %d)", client:SteamID(), id,
		table.Count(payload.nodes or {})))
end)

hook.Add("PlayerInitialSpawn", "nwDialogueData", function(client)
	timer.Simple(1.5, function()
		if (IsValid(client)) then
			NETWORK.dialogue.Broadcast(client)
		end
	end)
end)

hook.Add("Initialize", "nwDialogueData", function()
	NETWORK.dialogue.LoadAll()
end)

NETWORK.command.Register("dialogueedit", {
	description = "cmdDialogueedit",
	usage = "/dialogueedit [id]",
	adminOnly = true,
	aliases = {"dialogue", "diaedit"},
	OnRun = function(command, client, arguments)
		net.Start("nwDialogueEditor")
			net.WriteString(arguments[1] or "")
		net.Send(client)
	end
})

concommand.Add("network_dialogues", function(client)
	if (IsValid(client) and !client:IsAdmin()) then
		return
	end

	NETWORK.util.Print("Зарегистрировано диалогов: " .. #NETWORK.dialogue.GetAll())

	for _, data in ipairs(NETWORK.dialogue.GetAll()) do
		NETWORK.util.Print(string.format("  %s (%s) узлов: %d", data.id, data.name,
			table.Count(data.nodes or {})))
	end
end)
