NETWORK.trade.offers = NETWORK.trade.offers or {}

function NETWORK.trade.Request(action, index)
	net.Start("nwTradeAction")
		net.WriteString(action)
		net.WriteUInt(index or 0, 8)
	net.SendToServer()
end

function NETWORK.trade.SendConfig(entity, payload)
	net.Start("nwTraderConfig")
		net.WriteEntity(entity)
		NETWORK.util.WriteTable(payload)
	net.SendToServer()
end

function NETWORK.trade.SendOffers(entity, offers)
	net.Start("nwTraderOffers")
		net.WriteEntity(entity)
		NETWORK.util.WriteTable(offers)
	net.SendToServer()
end

net.Receive("nwTradeOpen", function()
	local entity = net.ReadEntity()

	NETWORK.trade.level = net.ReadUInt(4)
	NETWORK.trade.offers = NETWORK.util.ReadTable()
	NETWORK.trade.entity = entity

	NETWORK.gui.OpenTrade(entity)
end)

net.Receive("nwTradeStock", function()
	NETWORK.trade.offers = NETWORK.util.ReadTable() or {}

	if (IsValid(NETWORK.gui.trade)) then
		NETWORK.gui.trade:Rebuild()
	end
end)

net.Receive("nwTradeClose", function()
	NETWORK.trade.entity = nil

	NETWORK.gui.CloseTrade()
end)

hook.Add("NetworkInventoryUpdated", "nwTrade", function()
	if (IsValid(NETWORK.gui.trade)) then
		NETWORK.gui.trade:Rebuild()
	end
end)

NETWORK.trade.unlocked = NETWORK.trade.unlocked or {}

NETWORK.trade.levels = NETWORK.trade.levels or {}

net.Receive("nwTradeUnlocked", function()
	NETWORK.trade.unlocked = NETWORK.util.ReadTable() or {}
	NETWORK.trade.levels = NETWORK.util.ReadTable() or {}
end)

NETWORK.trade.editorOffers = NETWORK.trade.editorOffers or {}

function NETWORK.trade.RequestOffers(entity)
	net.Start("nwTraderOffersRequest")
		net.WriteEntity(entity)
	net.SendToServer()
end

net.Receive("nwTraderOffersRequest", function()
	local entity = net.ReadEntity()

	NETWORK.trade.editorOffers = NETWORK.util.ReadTable() or {}

	hook.Run("NetworkTraderOffersLoaded", entity, NETWORK.trade.editorOffers)
end)
