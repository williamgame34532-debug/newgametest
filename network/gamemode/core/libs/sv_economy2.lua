NETWORK.economy = NETWORK.economy or {}

local E = NETWORK.economy

E.rate = 4
E.transferFee = 0.05
E.historyMax = 40

function E.Points(client)
	return client:GetNWInt("nwLabour", 0)
end

function E.AddPoints(client, amount)
	if (!IsValid(client) or !client:HasCharacter() or amount == 0) then
		return
	end

	client:SetNWInt("nwLabour", math.max(E.Points(client) + amount, 0))
end

function E.Log(client, amount, source)
	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	local character = client:GetCharacter()

	character.nwLedger = character.nwLedger or {}

	table.insert(character.nwLedger, 1, {
		amount = math.Round(amount),
		source = string.sub(tostring(source or "?"), 1, 48),
		at = os.time()
	})

	while (#character.nwLedger > E.historyMax) do
		table.remove(character.nwLedger)
	end
end

function E.Ledger(client)
	local character = client:GetCharacter()

	return (character and character.nwLedger) or {}
end

function E.Give(client, amount, source)
	NETWORK.currency.Add(client, amount)
	E.Log(client, amount, source)
end

function E.Take(client, amount, source)
	if (!NETWORK.currency.Take(client, amount)) then
		return false
	end

	E.Log(client, -amount, source)

	return true
end

hook.Add("NetworkFactoryQuota", "nwEconomy", function(client)
	E.AddPoints(client, 5)
end)

hook.Add("NetworkXenRemoved", "nwEconomy", function(_, client)
	if (IsValid(client)) then
		E.AddPoints(client, 1)
	end
end)

hook.Add("NetworkMechanicRepaired", "nwEconomy", function(client)
	E.AddPoints(client, 2)
end)

NETWORK.command.Register("labour", {
	description = "cmdLabour",
	usage = "/labour",
	aliases = {"trud", "ochki"},
	OnRun = function(command, client)
		NETWORK.notice.Send(client, "labourHave", "info", E.Points(client),
			E.Points(client) * E.rate)
	end
})

NETWORK.command.Register("labourexchange", {
	description = "cmdLabourExchange",
	usage = "/labourexchange [очки]",
	aliases = {"obmen"},
	OnRun = function(command, client, arguments)
		local points = math.floor(tonumber(arguments[1]) or E.Points(client))

		if (points <= 0 or points > E.Points(client)) then
			return NETWORK.notice.Send(client, "labourNone", "warn")
		end

		E.AddPoints(client, -points)
		E.Give(client, points * E.rate, L("labourSource"))

		NETWORK.notice.Send(client, "labourExchanged", "good", points,
			points * E.rate)
	end
})

NETWORK.command.Register("transfer", {
	description = "cmdTransfer",
	usage = "/transfer <имя> <сумма>",
	aliases = {"perevod"},
	OnRun = function(command, client, arguments)
		local target = NETWORK.permission.Find(arguments[1])
		local amount = math.floor(tonumber(arguments[2]) or 0)

		if (!IsValid(target) or !target:HasCharacter() or target == client) then
			return NETWORK.notice.Send(client, "permNoTarget", "warn")
		end

		if (amount <= 0) then
			return NETWORK.notice.Send(client, "tokensBadAmount", "warn")
		end

		local fee = math.max(math.Round(amount * E.transferFee), 1)

		if (!E.Take(client, amount + fee, L("transferTo",
			target:GetCharacterName()))) then
			return NETWORK.notice.Send(client, "tokensNotEnough", "warn")
		end

		E.Give(target, amount, L("transferFrom", client:GetCharacterName()))

		NETWORK.notice.Send(client, "transferSent", "good", amount,
			target:GetCharacterName(), fee)
		NETWORK.notice.Send(target, "transferGot", "good", amount,
			client:GetCharacterName())
	end
})

NETWORK.command.Register("ledger", {
	description = "cmdLedger",
	usage = "/ledger",
	aliases = {"istoriya", "schet"},
	OnRun = function(command, client)
		local list = E.Ledger(client)

		if (#list == 0) then
			return NETWORK.notice.Send(client, "ledgerEmpty", "info")
		end

		NETWORK.notice.Send(client, "ledgerHeader", "info", client:GetTokens())

		for index = 1, math.min(#list, 8) do
			local entry = list[index]

			NETWORK.notice.Send(client, "ledgerRow", "info",
				entry.amount > 0 and ("+" .. entry.amount) or tostring(entry.amount),
				entry.source, os.date("%d.%m %H:%M", entry.at))
		end
	end
})

hook.Add("NetworkPersistenceCollect", "nwEconomy", function(client, data)
	data.labour = E.Points(client)
	data.ledger = E.Ledger(client)
end)

hook.Add("NetworkPersistenceRestore", "nwEconomy", function(client, data)
	if (!istable(data)) then
		return
	end

	client:SetNWInt("nwLabour", tonumber(data.labour) or 0)

	local character = client:GetCharacter()

	if (character and istable(data.ledger)) then
		character.nwLedger = data.ledger
	end
end)
