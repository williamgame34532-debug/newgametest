util.AddNetworkString("nwTradeOpen")
util.AddNetworkString("nwTradeStock")
util.AddNetworkString("nwTradeClose")
util.AddNetworkString("nwTradeAction")
util.AddNetworkString("nwTraderConfig")
util.AddNetworkString("nwTraderOffers")
util.AddNetworkString("nwTraderOffersRequest")
util.AddNetworkString("nwTradeUnlocked")

function NETWORK.trade.BuyPrice(client, entry)
	local charisma = NETWORK.skills and NETWORK.skills.Get(client, "charisma") or 0

	return math.max(math.Round((entry.price or 0) *
		(1 - charisma * NETWORK.skills.Effect("charisma", "buy"))), 0)
end

NETWORK.trade.range = 180

local Notice

function NETWORK.trade.SetUnlocked(client, traderID)
	if (!isstring(traderID) or traderID == "") then
		return
	end

	client.nwTraderUnlocked = client.nwTraderUnlocked or {}
	client.nwTraderUnlocked[traderID] = true
end

function NETWORK.trade.CanOpen(client, entity)
	if (!NETWORK.dialogue.EntityAllows(entity, client)) then
		return false, "tradeWrongFaction"
	end

	if (entity:GetUnlockItem() == "") then
		return true
	end

	if (NETWORK.trade.IsUnlocked(client, entity:GetTraderID())) then
		return true
	end

	return false, "tradeLocked"
end

function NETWORK.trade.Open(client, entity)
	if (!IsValid(entity)) then
		return
	end

	local bAllowed, reason = NETWORK.trade.CanOpen(client, entity)

	if (!bAllowed) then
		Notice(client, reason)
		entity:EmitSound("buttons/button2.wav", 55)

		return
	end

	if (entity.FaceEntity) then
		entity:FaceEntity(client)
	end

	client.nwTrader = entity

	client:SetNWBool("nwBusy", true)

	net.Start("nwTradeOpen")
		net.WriteEntity(entity)
		net.WriteUInt(NETWORK.trade.GetLevel(client, entity:GetTraderID()), 4)
		NETWORK.util.WriteTable(NETWORK.trade.GetVisible(client, entity))
	net.Send(client)
end

function NETWORK.trade.GetVisible(client, entity)
	local level = NETWORK.trade.GetLevel(client, entity:GetTraderID())
	local visible = {}

	for index, entry in ipairs(entity.offers or {}) do
		if ((entry.level or 1) <= level) then
			local copy = table.Copy(entry)

			copy.index = index

			visible[#visible + 1] = copy
		end
	end

	return visible
end

function NETWORK.trade.SyncViewers(entity)
	for _, client in ipairs(player.GetAll()) do
		if (client.nwTrader != entity) then
			continue
		end

		net.Start("nwTradeStock")
			NETWORK.util.WriteTable(NETWORK.trade.GetVisible(client, entity))
		net.Send(client)
	end
end

function NETWORK.trade.Close(client)
	local entity = client.nwTrader

	if (IsValid(entity) and entity.RestoreAngles) then
		entity:RestoreAngles()
	end

	client.nwTrader = nil

	client:SetNWBool("nwBusy", false)

	net.Start("nwTradeClose")
	net.Send(client)
end

function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

local function CountItems(state, id)
	local total = 0

	for _, list in ipairs({state.items, state.storage}) do
		for _, item in pairs(list) do
			if (item.id == id) then
				total = total + (item.amount or 1)
			end
		end
	end

	return total
end

local function TakeItems(state, id, amount, bPreferOutlands)
	local left = amount
	local outlands = 0
	local passes = bPreferOutlands and {true, false} or {nil}

	for _, wantOutlands in ipairs(passes) do
		for _, key in ipairs({"items", "storage"}) do
			for index, item in pairs(state[key]) do
				if (left <= 0) then
					break
				end

				if (item.id != id) then
					continue
				end

				local bOutlands = NETWORK.trade.IsOutlandsItem(item)

				if (wantOutlands != nil and bOutlands != wantOutlands) then
					continue
				end

				local taken = math.min(item.amount or 1, left)

				left = left - taken

				if (bOutlands) then
					outlands = outlands + taken
				end

				if ((item.amount or 1) > taken) then
					item.amount = item.amount - taken
				else
					state[key][index] = nil
				end
			end
		end
	end

	return left <= 0, outlands
end

net.Receive("nwTradeAction", function(_, client)
	local entity = client.nwTrader

	if (!IsValid(entity)) then
		entity = client:GetEyeTrace().Entity

		if (IsValid(entity) and entity:GetClass() == "nw_trader" and
			client:GetPos():Distance(entity:GetPos()) <= NETWORK.trade.range) then
			client.nwTrader = entity
		else
			return NETWORK.trade.Close(client)
		end
	end

	if (client:GetPos():Distance(entity:GetPos()) > NETWORK.trade.range) then
		return NETWORK.trade.Close(client)
	end

	if ((client.nwNextTrade or 0) > CurTime()) then
		return
	end

	client.nwNextTrade = CurTime() + 0.15

	local action = net.ReadString()
	local index = net.ReadUInt(8)

	if (action == "close") then
		return NETWORK.trade.Close(client)
	end

	if (action == "open") then
		return NETWORK.trade.Open(client, entity)
	end

	if (action == "noop") then
		return
	end

	local entry = (entity.offers or {})[index]

	if (!entry) then
		return
	end

	local state = NETWORK.inventory.GetState(client)

	if (action == "buy" and entry.side == "sell") then
		if (!NETWORK.trade.HasStock(entry)) then
			return Notice(client, "tradeNoStock")
		end

		if (entry.mode == "item") then
			if (CountItems(state, entry.tradeID) < entry.tradeAmount) then
				return Notice(client, "tradeNoItems")
			end
		elseif (client:GetTokens() < NETWORK.trade.BuyPrice(client, entry)) then
			return Notice(client, "tradeNoTokens")
		end

		local free = NETWORK.inventory.FirstFree(state.items, NETWORK.inventory.GetSize())

		if (!free) then
			return Notice(client, "errSlotsFull")
		end

		if (entry.mode == "item") then
			TakeItems(state, entry.tradeID, entry.tradeAmount)
		else
			NETWORK.currency.Take(client, NETWORK.trade.BuyPrice(client, entry))

			hook.Run("NetworkTraded", client, "buy", NETWORK.trade.BuyPrice(client, entry))
		end

		local item = NETWORK.item.New(entry.id, entry.amount)

		NETWORK.item.OnCreated(item, client, client:GetCharacter())

		state.items[free] = item

		if (NETWORK.trade.IsLimited(entry)) then
			local restock = NETWORK.trade.GetRestock(entity)

			entry.stock = math.max(entry.stock - 1, 0)

			entry.nextRestock = restock >= 0 and (CurTime() + restock) or nil

			NETWORK.trade.SyncViewers(entity)
		end

		NETWORK.inventory.Sync(client)

		Notice(client, "tradeBought")

		return
	end

	if (action == "sell" and entry.side == "buy") then
		if (CountItems(state, entry.id) < entry.amount) then
			return Notice(client, "tradeNoItems")
		end

		local entity = client.nwTrader
		local bCity = !(IsValid(entity) and NETWORK.zone.IsOutlands and
			NETWORK.zone.IsOutlands(entity:GetPos()))
		local _, outlands = TakeItems(state, entry.id, entry.amount, bCity)

		if (entry.mode == "item") then
			local free = NETWORK.inventory.FirstFree(state.items, NETWORK.inventory.GetSize())

			if (free) then
				state.items[free] = NETWORK.item.New(entry.tradeID, entry.tradeAmount)
			end
		else

			local price = entry.price

			if (bCity and outlands > 0) then
				local bonus = NETWORK.trade.outlandsBonus or 1
				local share = outlands / math.max(entry.amount, 1)

				price = math.Round(entry.price * (1 + (bonus - 1) * share))

				NETWORK.notice.Send(client, "tradeSoldBonus", "good", price - entry.price)
			end

			price = math.Round(price * (1 + (NETWORK.skills and
				NETWORK.skills.Get(client, "charisma") or 0) * NETWORK.skills.Effect("charisma", "sell")))

			NETWORK.currency.Add(client, price)

			hook.Run("NetworkTraded", client, "sell", price)
		end

		NETWORK.inventory.Sync(client)

		Notice(client, "tradeSold")
	end
end)

net.Receive("nwTraderConfig", function(_, client)
	if (!client:IsAdmin()) then
		return
	end

	local entity = net.ReadEntity()
	local payload = NETWORK.util.ReadTable()

	if (!IsValid(entity) or entity:GetClass() != "nw_trader") then
		return
	end

	entity:SetNPCName(NETWORK.util.Sanitise(payload.name, 48))
	entity:SetTraderDescription(NETWORK.util.Sanitise(payload.description, 200, true))
	entity:SetDialogue(isstring(payload.dialogue) and payload.dialogue or "")

	if (isstring(payload.model) and payload.model != "") then
		entity:SetNPCModel(payload.model)
	end

	entity:SetNPCSequence(isstring(payload.sequence) and payload.sequence or "")
	entity:SetTraderID(string.lower(string.gsub(
		NETWORK.util.Sanitise(payload.traderID, 24), "[^%w_]", "")))

	entity:SetFactions(table.concat(
		NETWORK.dialogue.ParseFactions(payload.factions), ","))

	entity:SetUnlockItem(NETWORK.item.Get(payload.unlockItem) and payload.unlockItem or "")
	entity:SetUnlockAmount(math.Clamp(math.Round(tonumber(payload.unlockAmount) or 1), 1, 99))

	entity:SetRestock(math.Clamp(math.Round(tonumber(payload.restock) or 0),
		-1, 86400))
	entity:SetRestockAmount(math.Clamp(
		math.Round(tonumber(payload.restockAmount) or 1), 1, 99))

	entity:Apply()
end)

net.Receive("nwTraderOffers", function(_, client)
	if (!client:IsAdmin()) then
		return
	end

	local entity = net.ReadEntity()
	local payload = NETWORK.util.ReadTable()

	if (!IsValid(entity) or entity:GetClass() != "nw_trader") then
		return
	end

	entity.offers = NETWORK.trade.CleanOffers(payload)

	Notice(client, "tradeSaved")
end)

net.Receive("nwTraderOffersRequest", function(_, client)
	if (!client:IsAdmin()) then
		return
	end

	local entity = net.ReadEntity()

	if (!IsValid(entity) or entity:GetClass() != "nw_trader") then
		return
	end

	net.Start("nwTraderOffersRequest")
		net.WriteEntity(entity)
		NETWORK.util.WriteTable(entity.offers or {})
	net.Send(client)
end)

hook.Add("Think", "nwTradeRange", function()
	if (!NETWORK.util.Throttle("trade.range", 0.25)) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		local entity = client.nwTrader

		if (!entity) then
			continue
		end

		if (!IsValid(entity) or !client:Alive() or
			client:GetPos():Distance(entity:GetPos()) > NETWORK.trade.range) then
			NETWORK.trade.Close(client)
		end
	end
end)

hook.Add("PlayerDisconnected", "nwTrade", function(client)
	client.nwTrader = nil
end)

function NETWORK.trade.SetLevel(client, traderID, level)
	if (traderID == "") then
		return
	end

	client.nwTraderLevels = client.nwTraderLevels or {}
	client.nwTraderLevels[traderID] = math.max(client.nwTraderLevels[traderID] or 1,
		math.Clamp(level, 1, NETWORK.trade.maxLevel))
end

hook.Add("NetworkQuestCompleted", "nwTradeLevel", function(client, quest)
	local reward = quest.rewards and quest.rewards.trader

	if (!istable(reward) or !reward.id) then
		return
	end

	NETWORK.trade.SetLevel(client, reward.id, tonumber(reward.level) or 2)

	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString("tradeLevelUp")
	net.Send(client)
end)

function NETWORK.trade.SyncUnlocked(client)
	net.Start("nwTradeUnlocked")
		NETWORK.util.WriteTable(client.nwTraderUnlocked or {})
		NETWORK.util.WriteTable(client.nwTraderLevels or {})
	net.Send(client)
end

hook.Add("NetworkCharacterLoaded", "nwTradeUnlocked", function(client)
	timer.Simple(0.5, function()
		if (IsValid(client)) then
			NETWORK.trade.SyncUnlocked(client)
		end
	end)
end)

timer.Create("nwTradeRestock", 30, 0, function()
	for _, entity in ipairs(ents.FindByClass("nw_trader")) do
		local restock = NETWORK.trade.GetRestock(entity)

		if (restock < 0 or restock == 0) then
			continue
		end

		local amount = NETWORK.trade.GetRestockAmount(entity)
		local bChanged = false

		for _, entry in ipairs(entity.offers or {}) do
			if (!NETWORK.trade.IsLimited(entry) or (entry.stockMax or -1) < 0) then
				continue
			end

			if (entry.stock >= entry.stockMax) then
				continue
			end

			if ((entry.nextRestock or 0) > CurTime()) then
				continue
			end

			entry.stock = math.min(entry.stock + amount, entry.stockMax)
			entry.nextRestock = CurTime() + restock
			bChanged = true
		end

		if (bChanged) then
			NETWORK.trade.SyncViewers(entity)
		end
	end
end)
