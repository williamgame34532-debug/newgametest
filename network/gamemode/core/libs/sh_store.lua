NETWORK.store = NETWORK.store or {}

local S = NETWORK.store

S.deliverTime = 60

S.fixtures = {
	{id = "counter", name = "Прилавок", cost = 150, model = "models/props_c17/FurnitureTable001a.mdl",
		slots = 8},
	{id = "shelf", name = "Стеллаж", cost = 120, model = "models/props_c17/FurnitureShelf001a.mdl",
		slots = 12},
	{id = "display", name = "Витрина", cost = 200, model = "models/props_c17/display_cooler01a.mdl",
		slots = 8},
	{id = "sign", name = "Вывеска", cost = 60, model = "models/props_c17/streetsign004e.mdl"}
}

S.goods = {
	{id = "ration_basic", name = "Партия пайков", cost = 40, amount = 5},
	{id = "water_breen", name = "Партия воды", cost = 30, amount = 5},
	{id = "bandage", name = "Партия бинтов", cost = 60, amount = 4},
	{id = "painkillers", name = "Обезболивающее", cost = 80, amount = 3},
	{id = "scrap", name = "Металлолом", cost = 25, amount = 6}
}

function S.GetFixture(id)
	for _, entry in ipairs(S.fixtures) do
		if (entry.id == id) then
			return entry
		end
	end
end

function S.GetGoods(id)
	for _, entry in ipairs(S.goods) do
		if (entry.id == id) then
			return entry
		end
	end
end

for _, entry in ipairs(S.fixtures) do
	if (entry.slots) then
		NETWORK.container.Register("shop_" .. entry.id, {
			name = entry.name, description = "Товар лавки", model = entry.model,
			slots = entry.slots, minItems = 0, maxItems = 0, loot = {}
		})
	end
end

if (SERVER) then
	NETWORK.container.classes.nw_shop_fixture = true
end

if (CLIENT) then
	return
end

util.AddNetworkString("nwShopOpen")
util.AddNetworkString("nwShopAction")

function S.GetData(client)
	local character = client:GetCharacter()
	local business = character and NETWORK.business.Get(character)

	if (!business or business.status != "approved") then
		return
	end

	business.shop = business.shop or {name = business.what or "Лавка", bOpen = true, fixtures = {}}

	return business, business.shop
end

function S.Sync(client)
	local business, shop = S.GetData(client)

	if (!shop) then
		return
	end

	net.Start("nwShopOpen")
		NETWORK.util.WriteTable({
			name = shop.name,
			bOpen = shop.bOpen,
			fixtures = shop.fixtures,
			what = business.what,
			tokens = client:GetTokens()
		})
	net.Send(client)
end

function S.Open(client)
	local business = S.GetData(client)

	if (!business) then
		return NETWORK.notice.Send(client, "shopNoBusiness", "bad")
	end

	S.Sync(client)
end

S.placeRange = 600

function S.IsInArea(client, position)
	local character = client:GetCharacter()
	local entry = character and NETWORK.business.Get(character)

	if (!entry or !istable(entry.position)) then
		return true
	end

	local origin = Vector(entry.position[1], entry.position[2], entry.position[3])
	local zone = NETWORK.zone.At(origin)
	local here = NETWORK.zone.At(position)

	if (zone and here and zone.id == here.id) then
		return true
	end

	return position:Distance(origin) <= S.placeRange
end

NETWORK.placer.Register("shopFixture", {
	CanPlace = function(client, placing, position)
		local _, shop = S.GetData(client)

		if (!shop or (shop.fixtures[placing.payload] or 0) <= 0) then
			return false, "shopNoFixture"
		end

		if (!S.IsInArea(client, position)) then
			return false, "shopNotHere"
		end

		return true
	end,
	OnPlace = function(client, placing, position, angles)
		local business, shop = S.GetData(client)
		local fixture = S.GetFixture(placing.payload)

		shop.fixtures[placing.payload] = shop.fixtures[placing.payload] - 1
		NETWORK.business.Save()

		local entity = ents.Create("nw_shop_fixture")

		entity:SetPos(position)
		entity:SetAngles(angles)
		entity:SetFixModel(fixture.model)
		entity:SetKind(placing.payload)
		entity:SetOwnerChar(tostring(client:GetCharacterID()))
		entity:SetShopName(shop.name)
		entity:SetOpen(shop.bOpen)
		entity:Spawn()

		NETWORK.notice.Send(client, "shopPlaced", "good")
	end
})

net.Receive("nwShopAction", function(_, client)
	local action = net.ReadString()
	local payload = NETWORK.util.ReadTable() or {}
	local business, shop = S.GetData(client)

	if (!shop) then
		return
	end

	if (action == "settings") then
		shop.name = NETWORK.util.Sanitise(payload.name or shop.name, 32)
		shop.bOpen = payload.bOpen == true

		for _, entity in ipairs(ents.FindByClass("nw_shop_fixture")) do
			if (entity:GetOwnerChar() == tostring(client:GetCharacterID())) then
				entity:SetShopName(shop.name)
				entity:SetOpen(shop.bOpen)
			end
		end

		NETWORK.business.Save()
		NETWORK.notice.Send(client, "shopSaved", "good")
	elseif (action == "buyFixture") then
		local fixture = S.GetFixture(payload.id or "")

		if (!fixture) then
			return
		end

		if (!NETWORK.currency.Take(client, fixture.cost)) then
			return NETWORK.notice.Send(client, "shopNoMoney", "bad")
		end

		timer.Simple(S.deliverTime, function()
			if (!IsValid(client)) then
				return
			end

			local _, current = S.GetData(client)

			if (current) then
				current.fixtures[fixture.id] = (current.fixtures[fixture.id] or 0) + 1
				NETWORK.business.Save()
				NETWORK.notice.Send(client, "shopDelivered", "good", fixture.name)
				S.Sync(client)
			end
		end)

		NETWORK.notice.Send(client, "shopOrdered", "info", fixture.name)
	elseif (action == "buyGoods") then
		local goods = S.GetGoods(payload.id or "")

		if (!goods) then
			return
		end

		if (!NETWORK.currency.Take(client, goods.cost)) then
			return NETWORK.notice.Send(client, "shopNoMoney", "bad")
		end

		timer.Simple(S.deliverTime, function()
			if (IsValid(client) and client:HasCharacter()) then
				NETWORK.inventory.Give(client, goods.id, goods.amount)
				NETWORK.notice.Send(client, "shopDelivered", "good", goods.name)
			end
		end)

		NETWORK.notice.Send(client, "shopOrdered", "info", goods.name)
	elseif (action == "place") then
		local fixture = S.GetFixture(payload.id or "")

		if (!fixture or (shop.fixtures[fixture.id] or 0) <= 0) then
			return NETWORK.notice.Send(client, "shopNoFixture", "warn")
		end

		NETWORK.placer.Begin(client, "shopFixture", fixture.model, fixture.id)
	end

	S.Sync(client)
end)

NETWORK.command.Register("shopmenu", {
	description = "cmdShopmenu",
	usage = "/shopmenu",
	aliases = {"biz", "lavka"},
	OnRun = function(command, client)
		local business = S.GetData(client)

		if (!business) then
			return NETWORK.notice.Send(client, "shopNoBusiness", "bad")
		end

		if (!S.IsInArea(client, client:GetPos())) then
			return NETWORK.notice.Send(client, "shopNotHere", "warn")
		end

		S.Sync(client)
	end
})
