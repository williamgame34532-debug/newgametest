function NETWORK.currency.Set(client, amount)
	client:SetNWInt("nwTokens", math.max(math.Round(amount), 0))
end

function NETWORK.currency.Add(client, amount)
	NETWORK.currency.Set(client, client:GetTokens() + amount)
end

function NETWORK.currency.Take(client, amount)
	if (client:GetTokens() < amount) then
		return false
	end

	NETWORK.currency.Add(client, -amount)

	return true
end

hook.Add("NetworkCharacterLoaded", "nwCurrency", function(client)
	if (NETWORK.persistence and NETWORK.persistence.Get(client:GetCharacter())) then
		return
	end

	if (client:GetNWInt("nwTokens", -1) < 0) then
		NETWORK.currency.Set(client, NETWORK.config.Get("startTokens") or 50)
	end
end)

concommand.Add("network_tokens_give", function(client, _, arguments)
	if (IsValid(client) and !client:IsAdmin()) then
		return
	end

	local target = IsValid(client) and client or player.GetAll()[1]

	if (IsValid(target)) then
		NETWORK.currency.Add(target, tonumber(arguments[1]) or 100)
	end
end)

hook.Add("Initialize", "nwCurrencyCommands", function()

NETWORK.command.Register("givetokens2", {
	description = "cmdGiveMoney",
	usage = "/givemoney <игрок> <сумма>",
	aliases = {"givemoney", "paymoney"},
	OnRun = function(command, client, arguments)
		local function Notice(text)
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString(text)
			net.Send(client)
		end

		local target = NETWORK.permission.Find(arguments[1])
		local amount = math.floor(tonumber(arguments[2]) or 0)

		if (!IsValid(target) or !target:HasCharacter() or target == client) then
			return Notice(L("permNoTarget"))
		end

		if (amount <= 0) then
			return Notice(L("tokensBadAmount"))
		end

		if (client:GetPos():Distance(target:GetPos()) > 200) then
			return Notice(L("pmTooFar"))
		end

		if (!NETWORK.currency.Take(client, amount)) then
			return Notice(L("tokensNotEnough"))
		end

		NETWORK.currency.Add(target, amount)

		Notice(L("tokensGiven", amount, target:GetRecognisedName(client)))

		NETWORK.notice.Send(target, "tokensHandOver", "good",
			client:GetRecognisedName(target), amount)

		if (NETWORK.log and NETWORK.log.Add) then
			NETWORK.log.Add("token", string.format("%s передал %d токенов игроку %s",
				NETWORK.log.Name(client), amount, NETWORK.log.Name(target)),
				client:GetPos())
		end
	end
})

NETWORK.command.Register("droptokens", {
	description = "cmdDropTokens",
	usage = "/droptokens <количество>",
	aliases = {"dropmoney"},
	OnRun = function(command, client, arguments)
		local function Notice(text)
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString(text)
			net.Send(client)
		end

		local amount = math.floor(tonumber(arguments[1]) or 0)

		if (amount <= 0) then
			return Notice(L("tokensBadAmount"))
		end

		if ((client.nwNextDrop or 0) > CurTime()) then
			return
		end

		client.nwNextDrop = CurTime() + 1

		if (!NETWORK.currency.Take(client, amount)) then
			return Notice(L("tokensNotEnough"))
		end

		local trace = util.TraceLine({
			start = client:EyePos(),
			endpos = client:EyePos() + client:GetAimVector() * 72,
			filter = client
		})

		local entity = NETWORK.currency.Drop(trace.HitPos + trace.HitNormal * 8,
			amount, Angle(0, client:EyeAngles().y, 0))

		if (!IsValid(entity)) then

			NETWORK.currency.Add(client, amount)

			return
		end

		Notice(L("tokensDropped", amount))

		if (NETWORK.log and NETWORK.log.Add) then
			NETWORK.log.Add("token", string.format("%s выбросил %d токенов",
				NETWORK.log.Name(client), amount), client:GetPos())
		end
	end
})

end)
