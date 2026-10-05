util.AddNetworkString("nwTerminalOpen")
util.AddNetworkString("nwTerminalClose")
util.AddNetworkString("nwTerminalData")

NETWORK.terminal = NETWORK.terminal or {}

function NETWORK.terminal.BuildData(client)
	local data = NETWORK.terminal.BuildBaseData(client)

	hook.Run("NetworkTerminalData", client, data)

	return data
end

function NETWORK.terminal.BuildBaseData(client)
	local character = client:GetCharacter()

	if (!character) then
		return {}
	end

	local faction = NETWORK.factions.Get(character:GetFaction())
	local home, homeData = NETWORK.terminal.GetHome(client)

	local homeName = home and NETWORK.door.GetHousingName(homeData) or ""
	local housing = home and (homeName != "" and homeName or
		L("termHousingUnnamed")) or nil

	return {
		name = character:GetName(),
		cid = NETWORK.terminal.GetCitizenID(character),
		faction = faction and L(faction.name) or "",

		housing = housing or "",
		bank = NETWORK.terminal.GetBank(client),
		tokens = client:GetTokens(),

		violations = (function()
			local list = NETWORK.detain and NETWORK.detain.GetViolations and
				NETWORK.detain.GetViolations(character) or {}

			if (#list == 0) then
				return nil
			end

			local parts = {}

			for index = #list, math.max(#list - 2, 1), -1 do
				local entry = list[index]

				parts[#parts + 1] = isstring(entry) and entry or
					(entry.reason or "?")
			end

			return table.concat(parts, ", ") ..
				(#list > 3 and ("  (всего: " .. #list .. ")") or "")
		end)(),

		loyalty = client:GetLoyalty(),
		loyaltyBand = L(NETWORK.loyalty.GetBand(client:GetLoyalty()).label),

		business = NETWORK.business and NETWORK.business.Get(character) or nil
	}
end

function NETWORK.terminal.Sync(client)
	if (!IsValid(client) or !IsValid(client.nwTerminal)) then
		return
	end

	net.Start("nwTerminalData")
		NETWORK.util.WriteTable(NETWORK.terminal.BuildData(client))
	net.Send(client)
end

function NETWORK.terminal.Open(client, entity)

	if (!NETWORK.terminal.CanOpen(client)) then
		return
	end

	if (IsValid(client.nwTerminal)) then
		NETWORK.terminal.Close(client)
	end

	client.nwTerminal = entity

	entity:SetUser(client)
	entity:EmitSound(NETWORK.terminal.sounds.select, 65)

	net.Start("nwTerminalOpen")
		net.WriteEntity(entity)
		NETWORK.util.WriteTable(NETWORK.terminal.BuildData(client))
	net.Send(client)
end

function NETWORK.terminal.Close(client)
	local entity = client.nwTerminal

	client.nwTerminal = nil

	if (IsValid(entity) and entity:GetUser() == client) then
		entity:SetUser(NULL)
	end

	net.Start("nwTerminalClose")
	net.Send(client)
end

function NETWORK.terminal.Alarm(client, entity, reason)
	if (!IsValid(entity)) then
		return
	end

	entity:SetAlarm(true)
	entity:SetAlarmReason(string.sub(reason or "", 1, 120))
	entity:EmitSound(NETWORK.terminal.sounds.alarm, 85)

	NETWORK.terminal.Close(client)
end

net.Receive("nwTerminalClose", function(_, client)
	NETWORK.terminal.Close(client)
end)

hook.Add("PlayerDeath", "nwTerminal", function(client)
	NETWORK.terminal.Close(client)
end)

hook.Add("NetworkCharacterUnloaded", "nwTerminal", function(client)
	NETWORK.terminal.Close(client)
end)
