NETWORK.decisions = NETWORK.decisions or {}

local D = NETWORK.decisions

D.keep = 40

if (CLIENT) then
	return
end

local dataPath = "network/decisions.txt"

D.list = D.list or {}
D.nextID = D.nextID or 1

function D.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON({list = D.list, nextID = D.nextID}))
end

function D.Load()
	local data = util.JSONToTable(file.Read(dataPath, "DATA") or "") or {}

	D.list = istable(data.list) and data.list or {}
	D.nextID = tonumber(data.nextID) or 1
end

function D.Get(id)
	for _, entry in ipairs(D.list) do
		if (entry.id == id) then
			return entry
		end
	end
end

function D.Propose(author, title, text, acceptDelta, declineDelta)
	local entry = {
		id = D.nextID,
		title = title,
		text = text,
		author = author,
		accept = math.floor(tonumber(acceptDelta) or 0),
		decline = math.floor(tonumber(declineDelta) or 0),
		status = "pending",
		time = os.time()
	}

	D.nextID = D.nextID + 1

	table.insert(D.list, 1, entry)

	while (#D.list > D.keep) do
		table.remove(D.list)
	end

	D.Save()

	for _, client in ipairs(player.GetAll()) do
		if (NETWORK.classes.IsAdministrative(client)) then
			NETWORK.notice.Send(client, "decisionNew", "info", title)
		end
	end

	return entry
end

function D.Decide(client, id, bAccept)
	local entry = D.Get(id)

	if (!entry or entry.status != "pending") then
		return false, "decisionGone"
	end

	local delta = bAccept and entry.accept or entry.decline

	entry.status = bAccept and "accepted" or "declined"
	entry.by = client:GetCharacterName()
	entry.decided = os.time()

	D.Save()

	if (NETWORK.budget and delta != 0) then
		NETWORK.budget.state.balance = math.max(NETWORK.budget.state.balance + delta, 0)
		NETWORK.budget.Log(string.format("Решение «%s» (%s): %+d т.", entry.title,
			bAccept and "принято" or "отклонено", delta))
		NETWORK.budget.Save()
	end

	NETWORK.log.Add("admin", string.format("%s %s предложение «%s» (%+d т.)",
		NETWORK.log.Name(client), bAccept and "принял" or "отклонил", entry.title, delta))

	return true, bAccept and "decisionAccepted" or "decisionDeclined", delta
end

hook.Add("Initialize", "nwDecisions", D.Load)

NETWORK.command.Register("agpropose", {
	adminOnly = true,
	description = "cmdAgPropose",
	usage = "/agpropose Заголовок | Текст | +500 | -200",
	OnRun = function(command, client, arguments)
		local raw = table.concat(arguments, " ")
		local parts = string.Explode("|", raw)

		for index, part in ipairs(parts) do
			parts[index] = string.Trim(part)
		end

		if (!parts[1] or parts[1] == "" or !parts[2] or parts[2] == "") then
			return NETWORK.notice.Send(client, "decisionUsage", "warn")
		end

		D.Propose(client:Nick(), NETWORK.util.Sanitise(parts[1], 60),
			NETWORK.util.Sanitise(parts[2], 600, true), parts[3], parts[4])

		NETWORK.notice.Send(client, "decisionSent", "good")
	end
})
