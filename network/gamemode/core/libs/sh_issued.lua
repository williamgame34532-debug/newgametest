NETWORK.issued = NETWORK.issued or {}

local I = NETWORK.issued

I.free = {
	ammo = true,
	medical = true,
	medicine = true,
	food = true,
	rations = true,
	junk = true
}

function I.Is(item)
	if (!istable(item) or !istable(item.data) or item.data.issued != true) then
		return false
	end

	local base = NETWORK.item.Get(item.id)

	if (base and I.free[base.category or ""]) then
		return false
	end

	return true
end

function I.Mark(item, bState)
	if (!istable(item)) then
		return
	end

	item.data = item.data or {}
	item.data.issued = bState != false or nil
end

function I.CanHold(client)
	return NETWORK.factions.IsAlliance(client)
end

if (SERVER) then
	NETWORK.command.Register("issue", {
		description = "cmdIssue",
		usage = "/issue",
		adminOnly = true,
		OnRun = function(command, client)
			local state = NETWORK.inventory.GetState(client)
			local count = 0

			for _, list in ipairs({"items", "equipped", "storage"}) do
				for _, item in pairs((state or {})[list] or {}) do
					if (istable(item) and !I.Is(item)) then
						I.Mark(item, true)

						count = count + 1
					end
				end
			end

			NETWORK.inventory.Sync(client)
			NETWORK.notice.Send(client, "issuedMarked", "good", count)
		end
	})
end
