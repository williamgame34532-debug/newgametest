NETWORK.loyaltyreq = NETWORK.loyaltyreq or {}

local R = NETWORK.loyaltyreq

local dataPath = "network/loyaltyreq.txt"

R.list = R.list or {}
R.cooldown = 600

function R.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(R.list, true))
end

function R.Load()
	local raw = file.Read(dataPath, "DATA")
	local data = raw and util.JSONToTable(raw)

	R.list = istable(data) and data or {}
end

hook.Add("Initialize", "nwLoyaltyReq", R.Load)

function R.CanReview(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	return client:IsAdmin() or NETWORK.classes.IsAdministrative(client)
end

function R.Find(id)
	for index, entry in ipairs(R.list) do
		if (tostring(entry.id) == tostring(id)) then
			return entry, index
		end
	end
end

NETWORK.command.Register("loyalty", {
	description = "cmdLoyalty",
	usage = "/loyalty <текст заявки>",
	aliases = {"loyal", "zayavka"},
	OnRun = function(command, client, arguments)
		local text = NETWORK.util.Sanitise(table.concat(arguments, " "), 300)

		if (string.len(text) < 12) then
			return NETWORK.notice.Send(client, "loyaltyReqShort", "warn")
		end

		if ((client.nwNextLoyaltyReq or 0) > CurTime()) then
			return NETWORK.notice.Send(client, "loyaltyReqWait", "warn")
		end

		local character = client:GetCharacter()
		local charID = tostring(character:GetID())

		if (R.Find(charID)) then
			return NETWORK.notice.Send(client, "loyaltyReqPending", "warn")
		end

		client.nwNextLoyaltyReq = CurTime() + R.cooldown

		R.list[#R.list + 1] = {
			id = charID,
			name = client:GetCharacterName(),
			level = client:GetLoyalty(),
			text = text,
			at = os.time()
		}

		R.Save()

		NETWORK.notice.Send(client, "loyaltyReqSent", "good")

		for _, target in ipairs(player.GetAll()) do
			if (R.CanReview(target)) then
				NETWORK.notice.Send(target, "loyaltyReqNew", "info",
					client:GetCharacterName())
			end
		end
	end
})

NETWORK.command.Register("loyaltyreqs", {
	description = "cmdLoyaltyReqs",
	usage = "/loyaltyreqs",
	aliases = {"zayavki"},
	OnRun = function(command, client)
		if (!R.CanReview(client)) then
			return NETWORK.notice.Send(client, "errNoAccess", "warn")
		end

		if (#R.list == 0) then
			return NETWORK.notice.Send(client, "loyaltyReqEmpty", "info")
		end

		for _, entry in ipairs(R.list) do
			NETWORK.notice.Send(client, "loyaltyReqRow", "info", entry.name,
				entry.level, entry.text)
		end
	end
})

NETWORK.command.Register("loyaltyapprove", {
	description = "cmdLoyaltyApprove",
	usage = "/loyaltyapprove <имя> [+уровней]",
	aliases = {"odobrit"},
	OnRun = function(command, client, arguments)
		if (!R.CanReview(client)) then
			return NETWORK.notice.Send(client, "errNoAccess", "warn")
		end

		local target = NETWORK.permission.Find(arguments[1])

		if (!IsValid(target) or !target:HasCharacter()) then
			return NETWORK.notice.Send(client, "permNoTarget", "warn")
		end

		local charID = tostring(target:GetCharacter():GetID())
		local entry, index = R.Find(charID)

		if (!entry) then
			return NETWORK.notice.Send(client, "loyaltyReqNone", "warn")
		end

		local step = math.Clamp(math.floor(tonumber(arguments[2]) or 1), 1, 3)

		NETWORK.loyalty.Set(target, target:GetLoyalty() + step)

		table.remove(R.list, index)
		R.Save()

		NETWORK.notice.Send(target, "loyaltyReqApproved", "good",
			target:GetLoyalty())
		NETWORK.notice.Send(client, "adminDone", "good")

		if (NETWORK.log and NETWORK.log.Add) then
			NETWORK.log.Add("city", string.format("%s одобрил заявку %s (+%d)",
				NETWORK.log.Name(client), NETWORK.log.Name(target), step))
		end
	end
})

NETWORK.command.Register("loyaltydeny", {
	description = "cmdLoyaltyDeny",
	usage = "/loyaltydeny <имя>",
	aliases = {"otkaz"},
	OnRun = function(command, client, arguments)
		if (!R.CanReview(client)) then
			return NETWORK.notice.Send(client, "errNoAccess", "warn")
		end

		local target = NETWORK.permission.Find(arguments[1])

		if (!IsValid(target) or !target:HasCharacter()) then
			return NETWORK.notice.Send(client, "permNoTarget", "warn")
		end

		local _, index = R.Find(tostring(target:GetCharacter():GetID()))

		if (!index) then
			return NETWORK.notice.Send(client, "loyaltyReqNone", "warn")
		end

		table.remove(R.list, index)
		R.Save()

		NETWORK.notice.Send(target, "loyaltyReqDenied", "warn")
		NETWORK.notice.Send(client, "adminDone", "good")
	end
})
