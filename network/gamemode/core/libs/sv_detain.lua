NETWORK.detain = NETWORK.detain or {}

NETWORK.detain.reasonMax = 90
NETWORK.detain.termMax = 60 * 24
NETWORK.detain.termDefault = 30

local function Notice(client, key, ...)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(L(key, ...))
	net.Send(client)
end

function NETWORK.detain.Get(id)
	return NETWORK.cmbterm.detained[tostring(id)]
end

function NETWORK.detain.GetRemaining(record)
	if (!record or !record.term or record.term <= 0) then
		return
	end

	return math.max(math.ceil((record.until_ - os.time()) / 60), 0)
end

function NETWORK.detain.AddViolation(character, reason, term, officer)
	NETWORK.cmbterm.violations = NETWORK.cmbterm.violations or {}

	local id = tostring(character:GetID())
	local list = NETWORK.cmbterm.violations[id] or {}

	list[#list + 1] = {
		reason = reason,
		term = term,
		officer = officer,
		time = os.time()
	}

	while (#list > 12) do
		table.remove(list, 1)
	end

	NETWORK.cmbterm.violations[id] = list

	NETWORK.cmbterm.Save()
end

function NETWORK.detain.GetViolations(character)
	return (NETWORK.cmbterm.violations or {})[tostring(character:GetID())] or {}
end

function NETWORK.detain.Add(client, target, term, reason)
	local character = target:GetCharacter()

	if (!character) then
		return false, "permNoTarget"
	end

	term = math.Clamp(math.Round(tonumber(term) or NETWORK.detain.termDefault), 0,
		NETWORK.detain.termMax)
	reason = NETWORK.util.Sanitise(reason, NETWORK.detain.reasonMax)

	if (reason == "") then
		return false, "detainNoReason"
	end

	local id = character:GetID()

	NETWORK.cmbterm.detained[tostring(id)] = {
		id = id,
		cid = NETWORK.terminal.GetCitizenID(character),
		name = character:GetName(),
		model = character:GetModel(),
		reason = reason,
		term = term,
		until_ = os.time() + term * 60,
		officer = client:GetCharacterName(),
		time = os.time()
	}

	NETWORK.detain.AddViolation(character, reason, term,
		client:GetCharacterName())

	NETWORK.cmbterm.Save()

	NETWORK.loyalty.Add(target, -10, client:GetCharacterName())

	Notice(target, "detainNotified", reason)

	return true, "detainAdded"
end

function NETWORK.detain.Release(id)
	local key = tostring(id)

	if (!NETWORK.cmbterm.detained[key]) then
		return false
	end

	NETWORK.cmbterm.detained[key] = nil

	NETWORK.cmbterm.Save()

	return true
end

timer.Create("nwDetainExpiry", 30, 0, function()
	local bChanged = false

	for key, record in pairs(NETWORK.cmbterm.detained) do
		if (!record.term or record.term <= 0) then
			continue
		end

		if (record.until_ > os.time()) then
			continue
		end

		NETWORK.cmbterm.detained[key] = nil
		bChanged = true

		for _, client in ipairs(player.GetAll()) do
			local character = client:GetCharacter()

			if (character and character:GetID() == record.id) then
				Notice(client, "detainExpired")

				break
			end
		end
	end

	if (bChanged) then
		NETWORK.cmbterm.Save()
	end
end)

local function FindByCID(id)
	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (character and NETWORK.terminal.GetCitizenID(character) == id) then
			return client, character
		end
	end
end

NETWORK.command.Register("detain", {
	description = "cmdDetain",
	usage = "/detain <игрок> <минуты> <причина>",
	OnRun = function(command, client, arguments)
		if (!NETWORK.factions.IsAlliance(client)) then
			return Notice(client, "owNoAccess")
		end

		local target = NETWORK.permission.Find(arguments[1])

		if (!IsValid(target) or !target:HasCharacter()) then
			return Notice(client, "permNoTarget")
		end

		local term = tonumber(arguments[2])

		local first = term and 3 or 2
		local reason = table.concat(arguments, " ", first)

		local bOk, key = NETWORK.detain.Add(client, target,
			term or NETWORK.detain.termDefault, reason)

		Notice(client, key)
	end
})

NETWORK.command.Register("release", {
	description = "cmdRelease",
	usage = "/release <номер>",
	OnRun = function(command, client, arguments)
		if (!NETWORK.factions.IsAlliance(client)) then
			return Notice(client, "owNoAccess")
		end

		local cid = string.gsub(arguments[1] or "", "[^%d]", "")
		local target, character = FindByCID(cid)

		if (character and NETWORK.detain.Release(character:GetID())) then
			Notice(client, "detainReleased")

			if (IsValid(target)) then
				Notice(target, "detainFreed")
			end

			return
		end

		for key, record in pairs(NETWORK.cmbterm.detained) do
			if (record.cid == cid) then
				NETWORK.detain.Release(key)

				return Notice(client, "detainReleased")
			end
		end

		Notice(client, "detainNoRecord")
	end
})
