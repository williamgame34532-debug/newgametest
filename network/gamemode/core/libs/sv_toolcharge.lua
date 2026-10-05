NETWORK.toolcharge = NETWORK.toolcharge or {}

local T = NETWORK.toolcharge

T.max = 12
T.repairCost = 1
T.chargerCost = 3
T.range = 120

T.stations = {
	nw_supply_point = true,
	nw_supply_depot = true,
	nw_supply_crate = true,
	nw_dispenser = true,
	nw_breaker = true
}

T.chargers = {
	item_suitcharger = true,
	item_healthcharger = true
}

function T.FindKit(client)
	local state = NETWORK.inventory.GetState(client)

	for _, list in ipairs({"items", "storage", "equipped"}) do
		for _, item in pairs((state or {})[list] or {}) do
			if (istable(item) and NETWORK.mechanic.kits[item.id]) then
				item.data = item.data or {}

				if (item.data.charge == nil) then
					item.data.charge = T.max
				end

				return item
			end
		end
	end
end

function T.Get(client)
	local item = T.FindKit(client)

	return item and (item.data.charge or 0) or 0, item
end

function T.Spend(client, amount)
	local charge, item = T.Get(client)

	amount = amount or 1

	if (!item or charge < amount) then
		return false
	end

	item.data.charge = charge - amount

	NETWORK.inventory.Sync(client)

	return true
end

function T.Refill(client)
	local item = T.FindKit(client)

	if (!item) then
		return false, "toolNoKit"
	end

	if ((item.data.charge or 0) >= T.max) then
		return false, "toolFull"
	end

	item.data.charge = T.max

	NETWORK.inventory.Sync(client)

	return true
end

function T.NearStation(client)
	for _, entity in ipairs(ents.FindInSphere(client:GetPos(), T.range)) do
		if (IsValid(entity) and T.stations[entity:GetClass()]) then
			return entity
		end
	end
end

hook.Add("NetworkMechanicRepaired", "nwToolCharge", function(client)
	T.Spend(client, T.repairCost)

	local charge = T.Get(client)

	if (charge <= 2) then
		NETWORK.notice.Send(client, "toolLow", "warn", charge)
	end
end)

NETWORK.command.Register("toolcharge", {
	description = "cmdToolCharge",
	usage = "/toolcharge",
	aliases = {"zaryad"},
	OnRun = function(command, client)
		local charge, item = T.Get(client)

		if (!item) then
			return NETWORK.notice.Send(client, "toolNoKit", "warn")
		end

		NETWORK.notice.Send(client, "toolCharge", "info", charge, T.max)
	end
})

NETWORK.command.Register("toolrefill", {
	description = "cmdToolRefill",
	usage = "/toolrefill",
	aliases = {"popolnit"},
	OnRun = function(command, client)
		if (!T.NearStation(client)) then
			return NETWORK.notice.Send(client, "toolNoStation", "warn")
		end

		local bOk, reason = T.Refill(client)

		if (!bOk) then
			return NETWORK.notice.Send(client, reason, "warn")
		end

		client:EmitSound("items/battery_pickup.wav", 60, 110)
		NETWORK.notice.Send(client, "toolRefilled", "good", T.max)
	end
})

hook.Add("PlayerUse", "nwToolCharge", function(client, entity)
	if (!IsValid(entity) or !T.chargers[entity:GetClass()]) then
		return
	end

	if (!client:HasCharacter() or !NETWORK.factions.IsCWU(client)) then
		return
	end

	if ((client.nwNextCharger or 0) > CurTime()) then
		return
	end

	client.nwNextCharger = CurTime() + 1

	if (entity:GetInternalVariable("m_iJuice") and
		entity:GetInternalVariable("m_iJuice") > 0) then
		return
	end

	if (!T.Spend(client, T.chargerCost)) then
		NETWORK.notice.Send(client, "toolEmpty", "warn")

		return
	end

	entity:Fire("Recharge")
	entity:SetSaveValue("m_iJuice", 75)
	entity:EmitSound("items/suitchargeok1.wav", 65, 100)

	NETWORK.notice.Send(client, "toolChargerFilled", "good")
end)
