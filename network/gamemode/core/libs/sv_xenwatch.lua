local X = NETWORK.xenwatch

X.interval = 30

function X.Recount()
	local count = #ents.FindByClass("nw_xenlife")

	SetGlobalInt("nwXenCount", count)

	return count
end

function X.Apply(level)
	if (X.lastLevel == level) then
		return
	end

	local previous = X.lastLevel or 0

	X.lastLevel = level

	if (level < previous) then
		return
	end

	if (level == 2) then
		for _, client in ipairs(player.GetAll()) do
			if (NETWORK.factions.IsAlliance(client) or
				(client.IsCWUMember and client:IsCWUMember())) then
				NETWORK.notice.Send(client, "xenWarn", "warn")
			end
		end
	elseif (level >= 3) then
		for _, client in ipairs(player.GetAll()) do
			NETWORK.notice.Send(client, "xenCritical", "bad")
		end

		if (NETWORK.budget and NETWORK.budget.state) then
			NETWORK.budget.state.balance = math.max(
				NETWORK.budget.state.balance - 300, 0)

			if (NETWORK.budget.Log) then
				NETWORK.budget.Log("Штраф Альянса: заражение зен-флорой — 300 т.")
			end
		end
	end
end

timer.Create("nwXenWatch", X.interval, 0, function()
	X.Apply(X.Level())
	X.Recount()
end)

hook.Add("InitPostEntity", "nwXenWatch", function()
	timer.Simple(5, X.Recount)
end)

function X.Credit(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	local faction = client:GetCharacterFaction()
	local share = 0

	if (faction == "disinfector" or client:GetNWString("nwClass", "") == "cwu_disinfector") then
		share = 1
	elseif (client.IsCWUMember and client:IsCWUMember()) then
		share = 0.5
	end

	if (share <= 0) then
		return
	end

	local amount = math.max(math.Round(X.Reward() * share), 1)

	NETWORK.currency.Add(client, amount)
	NETWORK.notice.Send(client, "xenPaid", "good", amount)

	client.nwXenCleaned = (client.nwXenCleaned or 0) + 1
end

hook.Add("NetworkXenRemoved", "nwXenWatch", function(entity, client)
	X.Credit(client)

	timer.Simple(0.2, X.Recount)
end)

NETWORK.command.Register("xenlevel", {
	description = "cmdXenLevel",
	usage = "/xenlevel",
	aliases = {"zen", "flora"},
	OnRun = function(command, client)
		NETWORK.notice.Send(client, "xenStatus", "info", X.Count(),
			L(X.LevelName()))
	end
})
