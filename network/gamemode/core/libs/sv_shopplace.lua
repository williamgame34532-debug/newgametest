util.AddNetworkString("nwShopPlace")

net.Receive("nwShopPlace", function(_, client)
	if (!IsValid(client) or !client:HasCharacter() or !client:Alive()) then
		return
	end

	local index = net.ReadUInt(8)
	local position = net.ReadVector()
	local angles = net.ReadAngle()
	local price = math.Clamp(math.Round(net.ReadUInt(16)), 0,
		NETWORK.shop.maxPrice)

	if ((client.nwNextShopPlace or 0) > CurTime()) then
		return
	end

	client.nwNextShopPlace = CurTime() + 0.5

	local state = NETWORK.inventory.GetState(client)
	local item = state.items[index]

	if (!item) then
		return NETWORK.chat.Notice(client, "shopNoItem")
	end

	if (!NETWORK.shop.CanSell(item)) then
		return NETWORK.chat.Notice(client, "shopCantSell")
	end

	if (client:GetPos():Distance(position) > NETWORK.shop.range) then
		return NETWORK.chat.Notice(client, "shopTooFar")
	end

	if (!NETWORK.shop.CanPlaceAt(client, position)) then
		return NETWORK.chat.Notice(client, "shopNotYours")
	end

	local entity = ents.Create("nw_shopitem")

	if (!IsValid(entity)) then
		return
	end

	entity:SetPos(position)
	entity:SetAngles(angles)
	entity:Spawn()
	entity:Activate()

	local character = client:GetCharacter()

	entity:Setup(item.id, price, tostring(character:GetID()), client:SteamID())

	if ((item.amount or 1) > 1) then
		item.amount = item.amount - 1
	else
		NETWORK.inventory.Put(state, "items", index, nil, nil)
	end

	NETWORK.inventory.Sync(client)

	client:EmitSound("physics/cardboard/cardboard_box_impact_soft3.wav", 60)

	NETWORK.log.Add("item", string.format("%s выставил на продажу %s (%d)",
		NETWORK.log.Name(client), item.id, price), position)

	NETWORK.chat.Notice(client, "shopPlaced")
end)
