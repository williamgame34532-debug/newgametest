-- A business of one's own: the way from the application to the counter.
--   1 the application   the civic terminal → «Бизнес и торговля» → «Подать заявку»: the name, the kind
--                       of trade, what will be sold; nw_business_fee credits (60) from the account.
--                       Needed: the CID card on you, not of the Alliance, no license already
--   2 the check         Civil Protection decides at the Alliance terminal (ЗАЯВКИ): approve or refuse
--                       with a reason; with no unit in the city the administration decides by itself
--                       (sh_requests.lua)
--   3 the license       approved: the document «Лицензия на торговлю» and a «Торговая стойка» into the
--                       inventory (or by the terminal, if there is no room); the license opens renting
--                       commercial premises at the terminal
--   4 the premises      «Аренда помещений» (only with the license) - a business door of the city
--   5 the counter       the stand is put down inside one's own premises (use it in the inventory; up to
--                       nw_business_stands of them). E at the stand:
--                         the owner   puts things from the inventory up for sale with a price, takes them
--                                     back, changes the prices, the sign, opens and closes, takes the money
--                         a buyer     sees what is for sale, buys with the tokens on hand
--                       nw_business_tax percent (10) of a sale goes to the city, the rest into the till
--   the kinds of trade  each sells its own categories (never weapons, never contraband)
--   revoked             Civil Protection can revoke a license (ЗАЯВКИ): the stands close and stay closed
-- The stands stay with the map (sv_persist.lua): the owner, the sign, the goods, the till.

NW.business = NW.business or {}

local BU = NW.business

BU.kinds = {
	{id = "food", name = "Продукты и напитки", categories = {food = true, drink = true}},
	{id = "clothes", name = "Одежда и сумки", categories = {clothing = true}, bags = true},
	{id = "pharmacy", name = "Аптека", categories = {medical = true}},
	{id = "repair", name = "Ремонт и детали", categories = {misc = true}},
	{id = "bar", name = "Бар и столовая", categories = {food = true, drink = true}},
	{id = "general", name = "Лавка всякой всячины", categories = {food = true, drink = true, misc = true, clothing = true,
		medical = true}, bags = true}
}

BU.kindByID = {}

for _, kind in ipairs(BU.kinds) do
	BU.kindByID[kind.id] = kind
end

-- what never goes on a counter
BU.never = {cid = true, license = true, shop_stand = true}

function BU.CanSell(kindID, item, id)
	local kind = BU.kindByID[kindID or ""]

	if (!kind or !item or BU.never[id] or item.contraband or item.category == "weapon" or item.weapon) then
		return false
	end

	if (item.bag and kind.bags) then
		return true
	end

	return kind.categories[item.category or "misc"] == true
end

NW.requests.kinds.license = {
	name = "Лицензия на торговлю",
	auto = true,
	revocable = true,
	Describe = function(fields)
		local kind = BU.kindByID[fields.kind or ""]

		return "«" .. tostring(fields.title or "") .. "»  ·  " .. (kind and kind.name or "?") .. "  ·  " ..
			tostring(fields.goods or "")
	end
}

-- the C menu of the stand (sh_entsettings.lua): the model
NW.entSettings.Register("nw_shop", {
	title = "Торговая стойка",
	fields = {
		{id = "model", name = "Модель (пусто — по умолчанию)", type = "model",
			default = "models/props_c17/FurnitureTable002a.mdl"}
	},
	Get = function(entity)
		return {model = entity.nwModel or ""}
	end,
	Set = function(entity, values)
		local model = string.Trim(values.model or "")

		if (model != "" and !util.IsValidModel(model)) then
			return false, "Нет такой модели: " .. model
		end

		entity.nwModel = model != "" and model or nil
		entity:SetModel(entity.nwModel or "models/props_c17/FurnitureTable002a.mdl")
		entity:PhysicsInit(SOLID_VPHYSICS)

		local physics = entity:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end
	end
})

-- -------------------------------------------------------------- server --
if (SERVER) then
	util.AddNetworkString("nwShop")
	util.AddNetworkString("nwShopAction")
	util.AddNetworkString("nwBusinessForm")

	local fee = CreateConVar("nw_business_fee", "60", FCVAR_ARCHIVE, "Пошлина за заявку на лицензию (кредиты со счёта)")
	local stands = CreateConVar("nw_business_stands", "2", FCVAR_ARCHIVE, "Сколько торговых стоек у одной лицензии")
	local tax = CreateConVar("nw_business_tax", "10", FCVAR_ARCHIVE, "Налог города с продажи, %")

	local RQ = NW.requests
	local T = NW.terminal
	local D = NW.doors
	local SO = NW.social
	local INV = NW.inventory
	local I = NW.items

	-- the license of a character now (approved), or nil
	function BU.License(charID)
		local entry = RQ.Of(charID, "license")

		return entry and entry.status == "approved" and entry or nil
	end

	function BU.Licensed(client)
		return BU.License(client:GetCharacterID()) != nil
	end

	local function Give(client, id, data)
		if (!INV.Add(client, id, data)) then
			INV.SpawnWorldItem(client, {id = id, data = data or {}})
		end
	end

	RQ.kinds.license.Approved = function(entry, client)
		Give(client, "license", {title = entry.fields.title, kind = entry.fields.kind, owner = entry.name})
		Give(client, "shop_stand")
		INV.Changed(client)
	end

	RQ.kinds.license.Revoked = function(entry)
		for _, shop in ipairs(ents.FindByClass("nw_shop")) do
			if (shop:GetOwnerChar() == entry.char) then
				shop:SetOpen(false)
			end
		end

		NW.persist.Save("nw_shop")
	end

	-- what the auto decision checks: the name, the kind
	RQ.kinds.license.Check = function(entry)
		if (!BU.kindByID[entry.fields.kind or ""] or (entry.fields.title or "") == "") then
			return false, "заявка заполнена неверно"
		end

		return true, "решение администрации"
	end

	hook.Add("NWTerminalProfile", "nwBusiness", function(client, extra)
		local entry = RQ.Of(client:GetCharacterID(), "license")

		extra.license = entry and {status = entry.status, title = entry.fields.title, kind = entry.fields.kind,
			reason = entry.reason or "", by = entry.by or ""} or nil
		extra.fee = fee:GetInt()
	end)

	-- the form of the application: from the terminal (the window on the client)
	T.actions.license_form = function(client, terminal)
		net.Start("nwBusinessForm")
			net.WriteEntity(terminal)
			net.WriteUInt(fee:GetInt(), 16)
		net.Send(client)
	end

	T.actions.license_apply = function(client, terminal, input)
		local title = string.Trim(tostring(input.title or ""))
		local goods = string.Trim(tostring(input.goods or ""))
		local kind = BU.kindByID[tostring(input.kind or "")]

		if (NW.zones.IsAlliance(client)) then
			return T.Result(client, terminal, "СЛУЖАЩИМ АЛЬЯНСА ТОРГОВЛЯ ЗАПРЕЩЕНА")
		elseif (!INV.Has(client, "cid")) then
			return T.Result(client, terminal, "НУЖНА CID-КАРТА")
		elseif (BU.Licensed(client)) then
			return T.Result(client, terminal, "ЛИЦЕНЗИЯ УЖЕ ВЫДАНА")
		elseif (!kind or (utf8.len(title) or 0) < 3) then
			return T.Result(client, terminal, "ЗАПОЛНИТЕ НАЗВАНИЕ И ВИД ТОРГОВЛИ")
		end

		local data = T.Data(client)

		if (data.bank < fee:GetInt()) then
			return T.Result(client, terminal, "НА СЧЁТЕ НЕДОСТАТОЧНО СРЕДСТВ: " .. fee:GetInt() .. " ТК")
		end

		local entry, why = RQ.Submit(client, "license", {title = string.sub(title, 1, 60), kind = kind.id,
			goods = string.sub(goods, 1, 140)})

		if (!entry) then
			return T.Result(client, terminal, why)
		end

		data.bank = data.bank - fee:GetInt()
		T.Log(client, "ПОШЛИНА ЗА ЛИЦЕНЗИЮ −" .. fee:GetInt() .. " ТК", false)
		T.SaveData(client)
		T.Send(client, "profile", terminal, T.Profile(client))
		T.Result(client, terminal, "ЗАЯВКА ПРИНЯТА К РАССМОТРЕНИЮ")
	end

	T.actions.license_cancel = function(client, terminal)
		local entry = RQ.Of(client:GetCharacterID(), "license")

		if (entry and entry.status == "pending") then
			RQ.Decide(entry, false, "отозвана заявителем", client:Nick())
		end

		T.Send(client, "profile", terminal, T.Profile(client))
	end

	-- -------------------------------------------------------- the stand --
	-- put down inside one's own premises (the item «Торговая стойка»)
	function BU.PlaceStand(client)
		local license = BU.License(client:GetCharacterID())

		if (!license) then
			NW.Notify(client, "Нужна лицензия на торговлю")

			return false
		end

		local count = 0

		for _, shop in ipairs(ents.FindByClass("nw_shop")) do
			if (shop:GetOwnerChar() == client:GetCharacterID()) then
				count = count + 1
			end
		end

		if (count >= stands:GetInt()) then
			NW.Notify(client, "Стоек уже " .. count .. " — больше нельзя")

			return false
		end

		local trace = client:GetEyeTrace()

		if (!trace.Hit or trace.HitPos:DistToSqr(client:GetShootPos()) > 160 * 160 or trace.HitNormal.z < 0.7) then
			NW.Notify(client, "Посмотрите на пол рядом с собой")

			return false
		end

		-- inside one's own business: a door of it close by
		local inside = false

		for _, door in ipairs(ents.FindInSphere(trace.HitPos, 700)) do
			if (D.IsDoor(door) and door:GetNW2String("nwDoorKind", "") == "business" and D.IsOwner(client, door)) then
				inside = true

				break
			end
		end

		if (!inside) then
			NW.Notify(client, "Стойку ставят в своём арендованном помещении")

			return false
		end

		local shop = ents.Create("nw_shop")
		local angles = Angle(0, (client:GetPos() - trace.HitPos):Angle().y, 0)

		shop:SetPos(trace.HitPos)
		shop:SetAngles(angles)
		shop:Spawn()
		shop:Activate()
		shop:SetOwnerChar(client:GetCharacterID())
		shop:SetOwnerName(client:Nick())
		shop:SetTitle(license.fields.title or "Лавка")
		shop:SetKind(license.fields.kind or "general")
		shop:SetOpen(true)
		shop.stock, shop.till = {}, 0
		NW.persist.Save("nw_shop")
		NW.Notify(client, "Стойка поставлена: E — управление")

		return true
	end

	-- the goods grouped: the same item at the same price is one line
	local function Lines(shop)
		local out, byKey = {}, {}

		for _, entry in ipairs(shop.stock or {}) do
			local key = entry.id .. "|" .. entry.price
			local line = byKey[key]

			if (!line) then
				local item = I.Get(entry.id) or {name = entry.id}

				line = {key = key, id = entry.id, name = item.name, price = entry.price, count = 0}
				byKey[key] = line
				out[#out + 1] = line
			end

			line.count = line.count + 1
		end

		table.SortByMember(out, "name", true)

		return out
	end

	local function IsOwner(client, shop)
		return client:GetCharacterID() != 0 and client:GetCharacterID() == shop:GetOwnerChar()
	end

	function BU.OpenShop(client, shop)
		local owner = IsOwner(client, shop)
		local mine = {}

		if (owner) then
			local inventory = INV.Get(client)

			for index = 1, I.maxSize do
				local cell = inventory.grid[index]
				local item = cell and I.Get(cell.id)

				if (item) then
					mine[#mine + 1] = {index = index, id = cell.id, name = item.name, sellable = BU.CanSell(shop:GetKind(), item,
						cell.id), price = item.price or 0}
				end
			end
		end

		net.Start("nwShop")
			net.WriteEntity(shop)
			net.WriteString(util.TableToJSON({owner = owner, lines = Lines(shop), till = owner and shop.till or 0,
				mine = mine, tokens = SO.GetTokens(client), revoked = !BU.License(shop:GetOwnerChar())}))
		net.Send(client)
	end

	local ACTIONS = {}

	function ACTIONS.buy(client, shop, input)
		if (IsOwner(client, shop)) then
			return "Это ваш товар"
		elseif (!shop:GetOpen()) then
			return "Лавка закрыта"
		end

		for index, entry in ipairs(shop.stock or {}) do
			if (entry.id .. "|" .. entry.price == input.key) then
				if (SO.GetTokens(client) < entry.price) then
					return "Не хватает токенов: нужно " .. entry.price
				end

				if (!INV.Add(client, entry.id, entry.data)) then
					return "Нет места в инвентаре"
				end

				local cut = math.floor(entry.price * math.Clamp(tax:GetFloat(), 0, 90) / 100)

				SO.SetTokens(client, SO.GetTokens(client) - entry.price)
				table.remove(shop.stock, index)
				shop.till = (shop.till or 0) + entry.price - cut
				INV.Changed(client)
				shop:EmitSound("buttons/button17.wav", 60)

				return nil, "Куплено: " .. ((I.Get(entry.id) or {}).name or entry.id) .. " за " .. entry.price .. " ток."
			end
		end

		return "Этого уже нет"
	end

	function ACTIONS.put(client, shop, input)
		local inventory = INV.Get(client)
		local index = math.floor(tonumber(input.index) or 0)
		local cell = inventory.grid[index]
		local item = cell and I.Get(cell.id)
		local price = math.Clamp(math.floor(tonumber(input.price) or 0), 1, 100000)

		if (!item) then
			return "Нет такого предмета"
		elseif (!BU.CanSell(shop:GetKind(), item, cell.id)) then
			return "Это нельзя продавать по вашей лицензии"
		elseif (#(shop.stock or {}) >= 60) then
			return "На стойке нет места (60 вещей)"
		end

		inventory.grid[index] = nil
		shop.stock = shop.stock or {}
		shop.stock[#shop.stock + 1] = {id = cell.id, data = cell.data or {}, price = price}
		INV.Changed(client)

		return nil, "Выставлено: " .. item.name .. " за " .. price .. " ток."
	end

	function ACTIONS.take(client, shop, input)
		for index, entry in ipairs(shop.stock or {}) do
			if (entry.id .. "|" .. entry.price == input.key) then
				if (!INV.Add(client, entry.id, entry.data)) then
					return "Нет места в инвентаре"
				end

				table.remove(shop.stock, index)
				INV.Changed(client)

				return
			end
		end
	end

	function ACTIONS.price(client, shop, input)
		local price = math.Clamp(math.floor(tonumber(input.price) or 0), 1, 100000)

		for _, entry in ipairs(shop.stock or {}) do
			if (entry.id .. "|" .. entry.price == input.key) then
				entry.price = price
			end
		end
	end

	function ACTIONS.withdraw(client, shop)
		local amount = shop.till or 0

		if (amount <= 0) then
			return "Касса пуста"
		end

		shop.till = 0
		SO.SetTokens(client, SO.GetTokens(client) + amount)
		client:EmitSound("network2/ui/confirm.mp3", 55)

		return nil, "Из кассы: " .. amount .. " ток."
	end

	function ACTIONS.toggle(client, shop)
		if (!shop:GetOpen() and !BU.License(shop:GetOwnerChar())) then
			return "Лицензия отозвана: лавку открыть нельзя"
		end

		shop:SetOpen(!shop:GetOpen())
	end

	function ACTIONS.rename(client, shop, input)
		local title = string.Trim(tostring(input.title or ""))

		if ((utf8.len(title) or 0) >= 2) then
			shop:SetTitle(string.sub(title, 1, 60))
		end
	end

	function ACTIONS.pickup(client, shop)
		if (#(shop.stock or {}) > 0 or (shop.till or 0) > 0) then
			return "Сначала заберите товар и выручку"
		end

		Give(client, "shop_stand")
		INV.Changed(client)
		shop:Remove()
	end

	net.Receive("nwShopAction", function(_, client)
		local shop = net.ReadEntity()
		local action = net.ReadString()
		local input = util.JSONToTable(net.ReadString() or "") or {}

		if ((client.nwShopNext or 0) > CurTime() or !IsValid(shop) or shop:GetClass() != "nw_shop" or
			client:GetPos():DistToSqr(shop:GetPos()) > 160 * 160 or !ACTIONS[action] or client:GetCharacterID() == 0) then
			return
		end

		client.nwShopNext = CurTime() + 0.2

		if (action != "buy" and !IsOwner(client, shop)) then
			return
		end

		local problem, done = ACTIONS[action](client, shop, input)

		if (problem or done) then
			NW.Notify(client, problem or done)
		end

		if (IsValid(shop)) then
			NW.persist.Save("nw_shop")
			BU.OpenShop(client, shop)
		end
	end)

	return
end

-- -------------------------------------------------------------- client --
local W = NW.widgets
local U = NW.ui
local I = NW.items

local ACCENT = Color(232, 170, 64)
local MUTED = Color(150, 156, 162)

-- the application (from the civic terminal)
net.Receive("nwBusinessForm", function()
	local terminal = net.ReadEntity()
	local cost = net.ReadUInt(16)

	if (IsValid(BU.form)) then
		BU.form:Remove()
	end

	local sh = ScrH()
	local w, h = math.Round(sh * 0.62), math.Round(sh * 0.6)
	local frame, box = W.Window("Заявка на лицензию торговли", w, h)
	local pad = math.Round(sh * 0.03)
	local fh = math.Round(sh * 0.04)
	local y = math.Round(sh * 0.085)

	BU.form = frame

	W.Label(box, "Название лавки (на вывеске)", pad, y)

	local title = W.Entry(box, "")

	title:SetPos(pad, y + sh * 0.024)
	title:SetSize(w - pad * 2, fh)
	y = y + sh * 0.085

	W.Label(box, "Вид торговли", pad, y)

	local choices = {}

	for _, kind in ipairs(BU.kinds) do
		choices[#choices + 1] = {kind.id, kind.name}
	end

	local kind = W.Combo(box, choices, "general")

	kind:SetPos(pad, y + sh * 0.024)
	kind:SetSize(w - pad * 2, fh)
	y = y + sh * 0.085

	W.Label(box, "Что будете продавать", pad, y)

	local goods = W.Entry(box, "", nil, true)

	goods:SetPos(pad, y + sh * 0.024)
	goods:SetSize(w - pad * 2, fh * 2)
	y = y + sh * 0.13

	local note = box:Add("DLabel")

	note:SetPos(pad, y)
	note:SetSize(w - pad * 2, sh * 0.08)
	note:SetWrap(true)
	note:SetFont("nwWidget")
	note:SetTextColor(MUTED)
	note:SetText("Пошлина " .. cost .. " кредитов со счёта. Заявку рассматривает Гражданская Оборона; если её нет в " ..
		"городе — администрация. После одобрения: лицензия и торговая стойка, затем аренда помещения.")

	local send = W.Button(box, "Подать заявку (" .. cost .. " кр.)", function()
		if (IsValid(terminal)) then
			terminal:Request("license_apply", {title = title:GetValue(), kind = kind:GetSelectedValue() or "general",
				goods = goods:GetValue()})
		end

		frame:Remove()
	end, true)

	send:SetPos(pad, h - pad - fh)
	send:SetSize(w * 0.55, fh)

	local cancel = W.Button(box, "Отмена", function()
		frame:Remove()
	end)

	cancel:SetPos(w - pad - w * 0.3, h - pad - fh)
	cancel:SetSize(w * 0.3, fh)
end)

-- the stand
local function Action(shop, action, input)
	net.Start("nwShopAction")
		net.WriteEntity(shop)
		net.WriteString(action)
		net.WriteString(util.TableToJSON(input or {}))
	net.SendToServer()
end

net.Receive("nwShop", function()
	local shop = net.ReadEntity()
	local data = util.JSONToTable(net.ReadString() or "") or {}

	if (!IsValid(shop)) then
		return
	end

	if (IsValid(BU.shop)) then
		BU.shop:Remove()
	end

	local sh = ScrH()
	local owner = data.owner
	local w, h = math.Round(owner and sh * 1.15 or sh * 0.66), math.Round(sh * 0.74)
	local frame, box = W.Window(shop:GetTitle(), w, h)
	local pad = math.Round(sh * 0.026)
	local fh = math.Round(sh * 0.038)
	local top = math.Round(sh * 0.085)
	local kind = BU.kindByID[shop:GetKind()]

	frame.entity = shop
	BU.shop = frame

	box.PaintOver = function(_, pw)
		draw.SimpleText((kind and kind.name or "") .. "  ·  " .. shop:GetOwnerName() .. "  ·  " .. (shop:GetOpen() and
			"ОТКРЫТО" or "ЗАКРЫТО"), "nwWidgetLabel", pad, top - sh * 0.014, shop:GetOpen() and Color(130, 214, 120) or
			Color(232, 96, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("У вас: " .. (data.tokens or 0) .. " ток." .. (owner and ("   ·   в кассе: " .. (data.till or 0) ..
			" ток.") or ""), "nwWidgetBold", pw - pad, top - sh * 0.014, ACCENT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	local listW = owner and math.Round((w - pad * 3) * 0.55) or (w - pad * 2)
	local list = W.Scroll(box)

	list:SetPos(pad, top + 8)
	list:SetSize(listW, h - top - pad - (owner and fh + 12 or 8))

	if (#(data.lines or {}) == 0) then
		W.Label(list, owner and "Витрина пуста: выставьте товар справа" or "Сейчас ничего не продаётся", 0, 0)
	end

	for _, line in ipairs(data.lines or {}) do
		local row = list:Add("DPanel")
		local rowH = math.Round(sh * 0.056)

		row:Dock(TOP)
		row:DockMargin(0, 0, 6, 4)
		row:SetTall(rowH)
		row.Paint = function(_, rw, rh)
			draw.RoundedBox(6, 0, 0, rw, rh, Color(255, 255, 255, 8))
			surface.SetMaterial(I.IconMaterial(I.Get(line.id)))
			surface.SetDrawColor(255, 255, 255, 235)
			surface.DrawTexturedRect(rh * 0.14, rh * 0.14, rh * 0.72, rh * 0.72)
			draw.SimpleText(line.name .. (line.count > 1 and ("  ×" .. line.count) or ""), "nwWidgetBold", rh, rh * 0.34,
				U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(line.price .. " ток.", "nwWidget", rh, rh * 0.7, ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		if (owner) then
			local price = W.Entry(row, tostring(line.price))

			price:SetNumeric(true)
			price:SetSize(listW * 0.16, rowH * 0.6)
			price:SetPos(listW - 6 - listW * 0.52, rowH * 0.2)

			local set = W.Button(row, "Цена", function()
				Action(shop, "price", {key = line.key, price = price:GetValue()})
			end)

			set:SetSize(listW * 0.15, rowH * 0.6)
			set:SetPos(listW - 6 - listW * 0.35, rowH * 0.2)

			local take = W.Button(row, "Снять", function()
				Action(shop, "take", {key = line.key})
			end)

			take:SetSize(listW * 0.17, rowH * 0.6)
			take:SetPos(listW - 6 - listW * 0.19, rowH * 0.2)
		else
			local buy = W.Button(row, "Купить", function()
				Action(shop, "buy", {key = line.key})
			end, (data.tokens or 0) >= line.price)

			buy:SetSize(listW * 0.22, rowH * 0.6)
			buy:SetPos(listW - 6 - listW * 0.24, rowH * 0.2)
			buy:SetEnabled(shop:GetOpen())
		end
	end

	if (!owner) then
		return
	end

	-- the owner: the inventory, the prices
	local rx = pad * 2 + listW
	local rw = w - rx - pad

	W.Label(box, "Ваш инвентарь: цена и «Выставить»", rx, top + 8)

	local mine = W.Scroll(box)

	mine:SetPos(rx, top + 8 + sh * 0.03)
	mine:SetSize(rw, h - top - pad - fh * 3 - sh * 0.06)

	for _, cell in ipairs(data.mine or {}) do
		local row = mine:Add("DPanel")
		local rowH = math.Round(sh * 0.05)

		row:Dock(TOP)
		row:DockMargin(0, 0, 6, 4)
		row:SetTall(rowH)
		row.Paint = function(_, pw, ph)
			draw.RoundedBox(6, 0, 0, pw, ph, Color(255, 255, 255, cell.sellable and 8 or 3))
			surface.SetMaterial(I.IconMaterial(I.Get(cell.id)))
			surface.SetDrawColor(255, 255, 255, cell.sellable and 235 or 80)
			surface.DrawTexturedRect(ph * 0.14, ph * 0.14, ph * 0.72, ph * 0.72)
			draw.SimpleText(cell.name, "nwWidget", ph, ph / 2, cell.sellable and U.color.text or MUTED, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
		end

		if (cell.sellable) then
			local price = W.Entry(row, tostring(math.max(1, cell.price or 1)))

			price:SetNumeric(true)
			price:SetSize(rw * 0.2, rowH * 0.62)
			price:SetPos(rw - 6 - rw * 0.5, rowH * 0.19)

			local put = W.Button(row, "Выставить", function()
				Action(shop, "put", {index = cell.index, price = price:GetValue()})
			end, true)

			put:SetSize(rw * 0.28, rowH * 0.62)
			put:SetPos(rw - 6 - rw * 0.29, rowH * 0.19)
		end
	end

	local sign = W.Entry(box, shop:GetTitle())

	sign:SetPos(rx, h - pad - fh * 2 - 8)
	sign:SetSize(rw * 0.64, fh)

	local rename = W.Button(box, "Вывеска", function()
		Action(shop, "rename", {title = sign:GetValue()})
	end)

	rename:SetPos(rx + rw * 0.66, h - pad - fh * 2 - 8)
	rename:SetSize(rw * 0.34, fh)

	local bw = (w - pad * 2 - 16) / 3
	local withdraw = W.Button(box, "Забрать выручку (" .. (data.till or 0) .. ")", function()
		Action(shop, "withdraw")
	end, (data.till or 0) > 0)

	withdraw:SetPos(pad, h - pad - fh)
	withdraw:SetSize(bw, fh)

	local toggle = W.Button(box, shop:GetOpen() and "Закрыть лавку" or (data.revoked and "Лицензия отозвана" or
		"Открыть лавку"), function()
		Action(shop, "toggle")
	end)

	toggle:SetPos(pad + bw + 8, h - pad - fh)
	toggle:SetSize(bw, fh)

	local pickup = W.Button(box, "Убрать стойку", function()
		Action(shop, "pickup")
		frame:Remove()
	end)

	pickup:SetPos(pad + (bw + 8) * 2, h - pad - fh)
	pickup:SetSize(bw, fh)
end)
