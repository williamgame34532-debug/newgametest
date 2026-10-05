NETWORK.trade = NETWORK.trade or {}

NETWORK.trade.outlandsBonus = 2.5

function NETWORK.trade.IsOutlandsItem(item)
	return istable(item) and istable(item.data) and item.data.sector == "outlands"
end

function NETWORK.trade.CleanOffers(list)
	local clean = {}

	for _, entry in ipairs(list or {}) do
		if (!NETWORK.item.Get(entry.id)) then
			continue
		end

		clean[#clean + 1] = {
			id = tostring(entry.id),
			level = math.Clamp(math.Round(tonumber(entry.level) or 1), 1, 5),
			side = entry.side == "buy" and "buy" or "sell",
			mode = entry.mode == "item" and "item" or "tokens",
			price = math.max(math.Round(tonumber(entry.price) or 10), 0),
			tradeID = isstring(entry.tradeID) and entry.tradeID or nil,
			tradeAmount = math.max(math.Round(tonumber(entry.tradeAmount) or 1), 1),
			amount = math.max(math.Round(tonumber(entry.amount) or 1), 1),

			stock = math.max(math.Round(tonumber(entry.stock) or -1), -1),
			stockMax = math.max(math.Round(tonumber(entry.stockMax) or
				tonumber(entry.stock) or -1), -1)
		}
	end

	return clean
end

function NETWORK.trade.Describe(entry)
	if (entry.mode == "item" and entry.tradeID) then
		local base = NETWORK.item.Get(entry.tradeID)

		return (base and base.name or entry.tradeID) .. " x" .. entry.tradeAmount
	end

	return NETWORK.currency.Format(entry.price)
end

NETWORK.trade.maxLevel = 5

function NETWORK.trade.GetLevel(client, traderID)
	if (traderID == "") then
		return NETWORK.trade.maxLevel
	end

	if (SERVER) then
		return math.max((client.nwTraderLevels or {})[traderID] or 1, 1)
	end

	return math.max((NETWORK.trade.levels or {})[traderID] or 1, 1)
end

function NETWORK.trade.IsAvailable(client, traderID, entry)
	return (entry.level or 1) <= NETWORK.trade.GetLevel(client, traderID)
end

function NETWORK.trade.IsUnlocked(client, traderID)
	if (!isstring(traderID) or traderID == "") then
		return true
	end

	if (SERVER) then
		return (client.nwTraderUnlocked or {})[traderID] == true
	end

	return (NETWORK.trade.unlocked or {})[traderID] == true
end

NETWORK.trade.restock = 600

function NETWORK.trade.GetRestock(entity)
	if (!IsValid(entity) or !entity.GetRestock) then
		return NETWORK.trade.restock
	end

	local value = entity:GetRestock() or 0

	if (value < 0) then
		return -1
	end

	return value > 0 and value or NETWORK.trade.restock
end

function NETWORK.trade.GetRestockAmount(entity)
	if (!IsValid(entity) or !entity.GetRestockAmount) then
		return 1
	end

	return math.max(entity:GetRestockAmount() or 1, 1)
end

function NETWORK.trade.IsLimited(entry)
	return (entry.stock or -1) >= 0
end

function NETWORK.trade.HasStock(entry)
	return !NETWORK.trade.IsLimited(entry) or entry.stock > 0
end
