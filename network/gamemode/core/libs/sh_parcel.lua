NETWORK.parcel = NETWORK.parcel or {}

local T = NETWORK.parcel

T.offerInterval = 480
T.offerChance = 0.5
T.deliverDelay = {120, 240}
T.shipDelay = {1200, 1800}
T.range = 220
T.priceMax = 3000

T.cities = {
	{id = "c8", name = "Сити-8"},
	{id = "c11", name = "Сити-11"},
	{id = "c17", name = "Сити-17"},
	{id = "c45", name = "Сити-45"},
	{id = "c14", name = "Сити-14"}
}

T.goods = {
	{name = "Медикаменты", base = 900, model = "models/items/ammocrate_smg1.mdl"},
	{name = "Стандартные рационы", base = 600, model = "models/props_junk/wood_crate001a.mdl"},
	{name = "Запчасти для фабрикаторов", base = 1200, model = "models/props_junk/wood_crate002a.mdl"},
	{name = "Ткань и униформа", base = 500, model = "models/props_junk/cardboard_box001a.mdl"},
	{name = "Фильтры для противогазов", base = 800, model = "models/props_junk/cardboard_box004a.mdl"}
}

T.senders = {
	"Администратор Сити-8",
	"Администратор Сити-11",
	"Юнит 3-2, сектор 17",
	"Администратор Сити-45",
	"Юнит 7-4, сектор 14",
	"Отдел снабжения Сити-17"
}

T.offerTexts = {
	"Приветствую. У нас образовался излишек: %s. Можем отправить вам посылку ближайшим составом. " ..
		"Дайте ответ — принимаете ли груз.",
	"Говорит %s. По распоряжению сверху перераспределяем запасы: %s. Готовы передать вам одну посылку. " ..
		"Подтвердите приём или откажитесь.",
	"Коллеги, у нас на складе лишнее: %s. Если нужно — отправим поездом. Ответьте письмом."
}

T.thankTexts = {
	"Посылка получена. Благодарим за содействие, оплата в размере %d т. переведена в ваш бюджет.",
	"Груз «%s» принят в полном объёме. Спасибо, %d т. перечислены на счёт вашего города.",
	"Администрация %s выражает благодарность за поставку. Перевод: %d т."
}

function T.GetCity(id)
	for _, city in ipairs(T.cities) do
		if (city.id == id) then
			return city
		end
	end
end

if (CLIENT) then
	return
end

util.AddNetworkString("nwParcelShip")
util.AddNetworkString("nwParcelShipOpen")
util.AddNetworkString("nwParcelUnpack")

local dataPath = "network/parcel.txt"

T.offers = T.offers or {}
T.nextID = T.nextID or 1
T.nextOffer = 0

function T.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON({offers = T.offers, nextID = T.nextID}))
end

function T.Load()
	local data = util.JSONToTable(file.Read(dataPath, "DATA") or "") or {}

	T.offers = istable(data.offers) and data.offers or {}
	T.nextID = tonumber(data.nextID) or 1
end

function T.Get(id)
	for _, offer in ipairs(T.offers) do
		if (offer.id == id) then
			return offer
		end
	end
end

local function AnyAdministration()
	for _, client in ipairs(player.GetAll()) do
		if (NETWORK.classes.IsAdministrative(client)) then
			return true
		end
	end

	return false
end

function T.HasPending()
	for _, offer in ipairs(T.offers) do
		if (offer.status == "offered" or offer.status == "accepted" or offer.status == "delivered" or
			offer.status == "shipped") then
			return true
		end
	end

	return false
end

function T.MakeOffer()
	local goods = T.goods[math.random(#T.goods)]
	local sender = T.senders[math.random(#T.senders)]
	local template = T.offerTexts[math.random(#T.offerTexts)]
	local text = string.format(template, sender, goods.name)

	if (!string.find(template, "%%s.-%%s")) then
		text = string.format(template, goods.name)
	end

	local offer = {
		id = T.nextID,
		goods = goods.name,
		model = goods.model,
		base = goods.base,
		sender = sender,
		status = "offered",
		time = os.time()
	}

	T.nextID = T.nextID + 1
	T.offers[#T.offers + 1] = offer

	while (#T.offers > 30) do
		table.remove(T.offers, 1)
	end

	T.Save()

	local letter = {
		id = NETWORK.mail.nextID,
		kind = "offer",
		offerID = offer.id,
		from = sender,
		fromChar = 0,
		cid = "—",
		subject = "Предложение посылки: " .. goods.name,
		text = text,
		time = os.time(),
		bRead = false
	}

	NETWORK.mail.nextID = NETWORK.mail.nextID + 1

	table.insert(NETWORK.mail.letters, 1, letter)
	NETWORK.mail.Save()

	for _, client in ipairs(player.GetAll()) do
		if (NETWORK.classes.IsAdministrative(client)) then
			NETWORK.notice.Send(client, "tradeOfferArrived", "info", sender)
		end
	end
end

local function Letter(from, subject, text, kind, extra)
	local letter = {
		id = NETWORK.mail.nextID,
		kind = kind or "letter",
		from = from,
		fromChar = 0,
		cid = "—",
		subject = subject,
		text = text,
		time = os.time(),
		bRead = false
	}

	if (extra) then
		table.Merge(letter, extra)
	end

	NETWORK.mail.nextID = NETWORK.mail.nextID + 1

	table.insert(NETWORK.mail.letters, 1, letter)
	NETWORK.mail.Save()
end

T.contents = {
	["Медикаменты"] = {{"bandage", 4}, {"medkit", 1}, {"painkillers", 2}},
	["Стандартные рационы"] = {{"ration_standard", 4}},
	["Запчасти для фабрикаторов"] = {{"scrap", 4}, {"wire", 3}, {"battery", 2}},
	["Ткань и униформа"] = {{"rag", 5}},
	["Фильтры для противогазов"] = {{"gasmask_filter", 3}}
}

local function SpawnLoose(client, package, id, amount)
	local item = NETWORK.item.New(id, amount)

	if (!item) then
		return
	end

	local entity = ents.Create("nw_item")

	if (!IsValid(entity)) then
		return
	end

	entity:SetPos(package:GetPos() + VectorRand() * 12 + Vector(0, 0, 24))
	entity:SetAngles(Angle(0, math.random(0, 359), 0))
	entity:SetItem(item)
	entity:Spawn()
	entity:Activate()
end

function T.Unpack(client, package)
	if (!IsValid(package) or !NETWORK.admincomp.CanUse(client)) then
		return false
	end

	local offer = T.Get(package:GetOfferID())

	if (!offer or offer.status != "delivered") then
		return false, "tradeOfferGone"
	end

	local list = T.contents[offer.goods] or {{"scrap", 3}}
	local given = 0

	for _, entry in ipairs(list) do
		local id, amount = entry[1], entry[2]

		if (NETWORK.item.Get(id)) then
			for _ = 1, amount do
				if (!NETWORK.inventory.Give(client, id, 1)) then
					SpawnLoose(client, package, id, 1)
				end

				given = given + 1
			end
		end
	end

	offer.status = "unpacked"
	offer.package = nil
	T.Save()

	package:EmitSound("physics/cardboard/cardboard_box_break" .. math.random(1, 3) .. ".wav", 70)
	package:Remove()

	NETWORK.chat.Send(client, "me", L("tradeUnpackMe"))

	if (NETWORK.budget) then
		NETWORK.budget.Log(string.format("Посылка «%s» распакована на месте (%s), без оплаты.",
			offer.goods, client:GetCharacterName()))
		NETWORK.budget.Save()
	end

	Letter("Диспетчер поездов", "Распаковано: " .. offer.goods,
		string.format("Посылка «%s» вскрыта на месте сотрудником %s. Содержимое передано в город, " ..
			"оплаты от другого сектора не будет.", offer.goods, client:GetCharacterName()), "letter")

	return true, "tradeUnpacked", given
end

net.Receive("nwParcelUnpack", function(_, client)
	local package = net.ReadEntity()

	if ((client.nwNextShip or 0) > CurTime()) then
		return
	end

	client.nwNextShip = CurTime() + 1

	if (!IsValid(package) or client:GetPos():Distance(package:GetPos()) > 160) then
		return
	end

	local bOk, key, count = T.Unpack(client, package)

	if (key) then
		NETWORK.notice.Send(client, key, bOk and "good" or "bad", count)
	end
end)

local function FindTrainPoint()
	local list = ents.FindByClass("nw_train_point")

	if (#list > 0) then
		return list[math.random(#list)]
	end

	list = ents.FindByClass("nw_admin_computer")

	if (#list == 0) then
		list = ents.FindByClass("nw_council_computer")
	end

	return list[1]
end

function T.Decide(client, id, bAccept)
	local offer = T.Get(id)

	if (!offer or offer.status != "offered") then
		return false, "tradeOfferGone"
	end

	if (!bAccept) then
		offer.status = "declined"
		T.Save()

		Letter(offer.sender, "Re: " .. offer.goods, "Понял, посылку не отправляем. Обращайтесь.",
			"letter")

		return true, "tradeDeclined"
	end

	offer.status = "accepted"
	offer.deliverAt = CurTime() + math.random(T.deliverDelay[1], T.deliverDelay[2])
	T.Save()

	Letter(offer.sender, "Re: " .. offer.goods,
		"Принято. Посылка отправлена ближайшим составом — встречайте на точке поезда " ..
		"через несколько минут.", "letter")

	return true, "tradeAccepted"
end

function T.Deliver(offer)
	local point = FindTrainPoint()

	if (!IsValid(point)) then
		offer.deliverAt = CurTime() + 120

		return
	end

	for _, existing in ipairs(ents.FindByClass("nw_trade_package")) do
		if (existing.GetOfferID and existing:GetOfferID() == offer.id) then
			offer.status = "delivered"
			offer.package = existing:EntIndex()
			T.Save()

			return
		end
	end

	local package = ents.Create("nw_trade_package")

	if (!IsValid(package)) then
		return
	end

	local spot = NETWORK.supply and NETWORK.supply.FindSpot and NETWORK.supply.FindSpot(point) or
		(point:GetPos() + point:GetForward() * 48 + Vector(0, 0, 8))

	package:SetPos(spot)
	package:SetAngles(Angle(0, point:GetAngles().y, 0))
	package:Spawn()
	package:Activate()
	package:SetPos(spot - Vector(0, 0, package:OBBMins().z - 1))
	package:SetOfferID(offer.id)
	package:SetGoods(offer.goods)

	offer.status = "delivered"
	offer.package = package:EntIndex()
	T.Save()

	Letter("Диспетчер поездов", "Посылка прибыла: " .. offer.goods,
		"Состав прибыл, посылка выгружена на точке поезда. Подойдите к ней и нажмите E, " ..
		"чтобы отправить дальше — выберите город и цену.", "letter")

	for _, client in ipairs(player.GetAll()) do
		if (NETWORK.classes.IsAdministrative(client)) then
			NETWORK.notice.Send(client, "tradePackageArrived", "good")
		end
	end
end

function T.Ship(client, package, cityID, price)
	if (!IsValid(package) or !NETWORK.admincomp.CanUse(client)) then
		return false
	end

	local offer = T.Get(package:GetOfferID())
	local city = T.GetCity(cityID)

	price = math.Clamp(math.floor(tonumber(price) or 0), 1, T.priceMax)

	if (!offer or offer.status != "delivered" or !city) then
		return false, "tradeOfferGone"
	end

	local point = FindTrainPoint()

	if (!IsValid(point) or package:GetPos():Distance(point:GetPos()) > T.range) then
		return false, "tradeNotAtTrain"
	end

	offer.status = "shipped"
	offer.city = city.id
	offer.price = price
	offer.shipAt = CurTime() + math.random(T.shipDelay[1], T.shipDelay[2])
	offer.package = nil
	T.Save()

	package:EmitSound("physics/cardboard/cardboard_box_impact_hard2.wav", 70)
	package:Remove()

	NETWORK.chat.Send(client, "me", L("tradeShipMe"))

	Letter("Диспетчер поездов", "Отправлено: " .. offer.goods .. " → " .. city.name,
		string.format("Посылка «%s» погружена на состав до %s. Заявленная цена: %d т. " ..
			"Ответ от администрации города придёт после получения.", offer.goods, city.name, price),
		"letter")

	return true, "tradeShipped", city.name
end

function T.Complete(offer)
	local city = T.GetCity(offer.city)
	local name = city and city.name or "?"

	local paid = offer.price

	if (offer.price > offer.base * 2) then
		paid = math.floor(offer.base * 1.5)
	end

	offer.status = "done"
	offer.paid = paid
	T.Save()

	if (NETWORK.budget) then
		NETWORK.budget.state.balance = NETWORK.budget.state.balance + paid
		NETWORK.budget.Log(string.format("Посылка «%s» продана в %s: +%d т.", offer.goods, name, paid))
		NETWORK.budget.Save()
	end

	local template = T.thankTexts[math.random(#T.thankTexts)]
	local text

	if (string.find(template, "%%s.-%%d")) then
		text = string.format(template, string.find(template, "^Администрация") and name or offer.goods,
			paid)
	else
		text = string.format(template, paid)
	end

	if (paid < offer.price) then
		text = text .. " Цена показалась завышенной — заплатили по нашей оценке."
	end

	Letter("Администрация " .. name, "Благодарность за посылку", text, "letter")

	for _, client in ipairs(player.GetAll()) do
		if (NETWORK.classes.IsAdministrative(client)) then
			NETWORK.notice.Send(client, "tradeThanks", "good", name, paid)
		end
	end
end

hook.Add("Initialize", "nwParcel", function()
	T.Load()

	for _, offer in ipairs(T.offers) do
		if (offer.status == "delivered") then
			offer.status = "accepted"
			offer.deliverAt = CurTime() + 60
		elseif (offer.status == "shipped") then
			offer.shipAt = CurTime() + math.random(T.shipDelay[1], T.shipDelay[2]) * 0.5
		elseif (offer.status == "accepted") then
			offer.deliverAt = CurTime() + 90
		end
	end

	T.nextOffer = CurTime() + T.offerInterval
end)

timer.Create("nwParcel", 5, 0, function()
	if (CurTime() >= T.nextOffer) then
		T.nextOffer = CurTime() + T.offerInterval

		if (AnyAdministration() and !T.HasPending() and
			math.random() < math.Rand(T.offerChance - 0.1, T.offerChance + 0.1)) then
			T.MakeOffer()
		end
	end

	for _, offer in ipairs(T.offers) do
		if (offer.status == "accepted" and offer.deliverAt and CurTime() >= offer.deliverAt) then
			T.Deliver(offer)
		elseif (offer.status == "shipped" and offer.shipAt and CurTime() >= offer.shipAt) then
			T.Complete(offer)
		end
	end
end)

net.Receive("nwParcelShip", function(_, client)
	local package = net.ReadEntity()
	local cityID = net.ReadString()
	local price = net.ReadUInt(16)

	if ((client.nwNextShip or 0) > CurTime()) then
		return
	end

	client.nwNextShip = CurTime() + 1

	if (!IsValid(package) or client:GetPos():Distance(package:GetPos()) > 160) then
		return
	end

	local bOk, key, name = T.Ship(client, package, cityID, price)

	if (key) then
		NETWORK.notice.Send(client, key, bOk and "good" or "bad", name)
	end
end)

NETWORK.command.Register("tradeoffer", {
	adminOnly = true,
	description = "cmdTradeOffer",
	usage = "/tradeoffer",
	OnRun = function(command, client)
		T.MakeOffer()
		NETWORK.notice.Send(client, "tradeOfferForced", "good")
	end
})
