NETWORK.journal = NETWORK.journal or {}

local J = NETWORK.journal

J.limit = 20

J.kinds = {
	fine = {name = "journalFine", color = Color(226, 162, 78)},
	injury = {name = "journalInjury", color = Color(226, 86, 76)},
	arrest = {name = "journalArrest", color = Color(226, 86, 76)},
	heal = {name = "journalHeal", color = Color(99, 201, 138)},
	work = {name = "journalWork", color = Color(74, 168, 224)},
	note = {name = "journalNote", color = Color(150, 158, 168)}
}

function J.GetKind(id)
	return J.kinds[id] or J.kinds.note
end

function J.Get(character)
	if (!character or !character.GetData) then
		return {}
	end

	return character:GetData("journal") or {}
end

if (CLIENT) then

	function J.GetOwn()
		local character = LocalPlayer():GetCharacter()

		return character and J.Get(character) or {}
	end

	function J.Ago(stamp)
		local diff = os.time() - (stamp or 0)

		if (diff < 60) then
			return L("journalNow")
		end

		if (diff < 3600) then
			return L("journalMinutes", math.floor(diff / 60))
		end

		if (diff < 86400) then
			return L("journalHours", math.floor(diff / 3600))
		end

		return L("journalDays", math.floor(diff / 86400))
	end

	return
end

function J.Add(character, kind, text)
	if (!character or !character.GetData or !isstring(text) or text == "") then
		return
	end

	local list = character:GetData("journal") or {}

	table.insert(list, 1, {
		kind = J.kinds[kind] and kind or "note",
		text = string.sub(text, 1, 120),
		time = os.time()
	})

	while (#list > J.limit) do
		table.remove(list)
	end

	character:SetData("journal", list)
end

function J.AddTo(client, kind, text)
	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	J.Add(client:GetCharacter(), kind, text)
end

hook.Add("NetworkPlayerInjured", "nwJournal", function(client, damage)
	if ((damage or 0) < 25) then
		return
	end

	J.AddTo(client, "injury", L("journalInjuryText", math.floor(damage)))
end)

hook.Add("NetworkPlayerArrested", "nwJournal", function(client, reason)
	J.AddTo(client, "arrest", reason and tostring(reason) or
		L("journalArrestText"))
end)

hook.Add("NetworkPlayerFined", "nwJournal", function(client, amount, reason)
	J.AddTo(client, "fine", L("journalFineText", math.floor(amount or 0),
		reason and tostring(reason) or L("journalNoReason")))
end)

NETWORK.command.Register("note", {
	adminOnly = true,
	description = "cmdNote",
	usage = "/note <игрок> <текст>",
	OnRun = function(command, client, arguments)
		local target = NETWORK.permission.Find(arguments[1] or "")

		if (!IsValid(target)) then
			return NETWORK.notice.Send(client, "permNoTarget", "warn")
		end

		local text = string.Trim(table.concat(arguments, " ", 2))

		if (text == "") then
			return NETWORK.notice.Send(client, "noteUsage", "warn")
		end

		J.AddTo(target, "note", text)

		NETWORK.notice.Send(client, "noteAdded", "good", target:Name())
		NETWORK.notice.Send(target, "noteReceived", "warn")
	end
})
