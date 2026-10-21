-- The treasury of the city and the state orders (госзаказы) of the factory for other cities.
--   1 the order        the city administration (an admin, or a character made «Администрация города» by
--                      /cityadmin) at the CWU terminal → «Госзаказы»: the city, the goods of the factory,
--                      how many, the price of a piece. The sum is taken from the treasury at once (reserved)
--   2 the packing      the CWU (and anyone hired at the factory) brings the goods to the «Стол комплектации
--                      заказов» (nw_export_bench), E: what they carry goes into the oldest open order of that
--                      kind; who put how much is written down. Full - the bench gives «Посылка госзаказа»
--   3 the delivery     the parcel is carried to the «Точка сбыта» (nw_export_point), E: taken away, the
--                      order closed. The money comes from the treasury: nw_export_courier percent (15) to
--                      the one who brought it, the rest to the packers by their share (who is not in the
--                      city - their share goes back into the treasury)
--   cancelled          by the administration: the money back into the treasury, the parcel is worthless
-- The treasury: nw_treasury_start (3000) at first; the tax of the shops goes into it (sh_business.lua);
-- /treasury [add|set N] - admins. Everything is kept in data/network2/exports.json.

NW.exports = NW.exports or {}

local EX = NW.exports

-- what the factory makes for export and the price of a piece the form starts from
EX.goods = {
	{id = "factory_crate", price = 20},
	{id = "unit_core", price = 9},
	{id = "parts", price = 4},
	{id = "scrap", price = 2}
}

EX.goodByID = {}

for _, entry in ipairs(EX.goods) do
	EX.goodByID[entry.id] = entry
end

EX.cities = {"Сити-8", "Сити-11", "Сити-14", "Сити-20", "Сити-24", "Сити-45", "Нова Проспект", "Цитадель"}

EX.statuses = {open = "Сборка", packed = "Собран: везти на точку сбыта", delivered = "Доставлен",
	cancelled = "Отменён"}

function EX.CanManage(client)
	return IsValid(client) and (client:IsAdmin() or client:GetNW2Bool("nwCityAdmin", false))
end

-- who may pack and carry: the CWU and the hired workers of the factory
function EX.CanWork(client)
	return IsValid(client) and (client:GetFaction() == "cwu" or client:GetNW2Bool("nwFactoryHired", false))
end

function EX.ItemName(id)
	local item = NW.items.Get(id)

	return item and item.name or tostring(id)
end

if (SERVER) then
	util.AddNetworkString("nwExports")

	local startMoney = CreateConVar("nw_treasury_start", "3000", FCVAR_ARCHIVE, "С какой суммы начинается казна города")
	local courierCut = CreateConVar("nw_export_courier", "15", FCVAR_ARCHIVE,
		"Доля доставщика посылки госзаказа, % (остальное — сборщикам)")
	local maxOpen = CreateConVar("nw_export_max", "6", FCVAR_ARCHIVE, "Сколько госзаказов может быть открыто сразу")

	local FILE = "network2/exports.json"
	local INV = NW.inventory
	local I = NW.items

	EX.state = EX.state or nil

	local function Save()
		file.CreateDir("network2")
		file.Write(FILE, util.TableToJSON(EX.state))
	end

	local function Load()
		local saved = file.Read(FILE, "DATA")

		EX.state = saved and util.JSONToTable(saved) or nil

		if (!istable(EX.state)) then
			EX.state = {treasury = startMoney:GetInt(), nextID = 1, orders = {}, log = {}}
		end

		EX.state.orders = EX.state.orders or {}
		EX.state.log = EX.state.log or {}
		EX.state.nextID = EX.state.nextID or 1
	end

	-- the list everyone sees (the terminal, the bench): open and packed, then the last closed ones
	local function Public()
		local out = {}
		local closed = 0

		for index = #EX.state.orders, 1, -1 do
			local order = EX.state.orders[index]
			local active = order.status == "open" or order.status == "packed"

			if (active or closed < 8) then
				closed = closed + (active and 0 or 1)
				out[#out + 1] = {id = order.id, city = order.city, item = order.item, qty = order.qty, filled = order.filled,
					price = order.price, status = order.status, by = order.by, time = order.time, done = order.done}
			end
		end

		return {treasury = EX.state.treasury, orders = out, log = EX.state.log}
	end

	function EX.Broadcast(target)
		net.Start("nwExports")
			net.WriteString(util.TableToJSON(Public()))

		if (target) then
			net.Send(target)
		else
			net.Broadcast()
		end
	end

	local function Log(text)
		table.insert(EX.state.log, 1, os.date("%d.%m %H:%M") .. "  " .. text)

		while (#EX.state.log > 12) do
			table.remove(EX.state.log)
		end
	end

	function EX.Deposit(amount, reason)
		if (!EX.state or amount <= 0) then
			return
		end

		EX.state.treasury = EX.state.treasury + math.floor(amount)

		-- the small taxes of the shops are not written down one by one
		if (amount >= 20 or reason != "налог с продажи") then
			Log("+" .. math.floor(amount) .. " ток. — " .. (reason or "поступление"))
		end

		Save()
		EX.Broadcast()
	end

	local function Get(id)
		for _, order in ipairs(EX.state.orders) do
			if (order.id == id) then
				return order
			end
		end
	end

	local function Notify(client, text)
		NW.Notify(client, text)
	end

	local function Workers(text)
		for _, client in ipairs(player.GetAll()) do
			if (EX.CanWork(client)) then
				Notify(client, text)
			end
		end
	end

	hook.Add("Initialize", "nwExports", Load)

	if (GAMEMODE) then
		Load()
	end

	hook.Add("NWCharacterLoaded", "nwExports", function(client, character)
		client:SetNW2Bool("nwCityAdmin", character.data and character.data.cityAdmin == true)
		EX.Broadcast(client)
	end)

	-- ----------------------------------------------------------- the terminal --
	local ACTIONS = NW.cmbTerminalActions

	local function AtTerminal(terminal)
		return IsValid(terminal) and terminal:GetClass() == "nw_cwu_terminal"
	end

	function ACTIONS.exp_list(client, terminal)
		if (AtTerminal(terminal)) then
			EX.Broadcast(client)
		end
	end

	function ACTIONS.exp_create(client, terminal, arg)
		if (!AtTerminal(terminal)) then
			return
		end

		if (!EX.CanManage(client)) then
			return Notify(client, "Госзаказы оформляет администрация города")
		end

		local input = util.JSONToTable(arg or "") or {}
		local good = EX.goodByID[tostring(input.item or "")]
		local qty = math.floor(tonumber(input.qty) or 0)
		local price = math.floor(tonumber(input.price) or 0)
		local city = string.sub(string.Trim(tostring(input.city or "")), 1, 32)

		if (!good or qty < 1 or qty > 50 or price < 1 or price > 500 or city == "") then
			return Notify(client, "Заказ: город, товар, количество 1–50, цена за штуку 1–500")
		end

		local open = 0

		for _, order in ipairs(EX.state.orders) do
			if (order.status == "open" or order.status == "packed") then
				open = open + 1
			end
		end

		if (open >= maxOpen:GetInt()) then
			return Notify(client, "Открытых заказов уже " .. open .. " — сначала закройте старые")
		end

		local total = qty * price

		if (EX.state.treasury < total) then
			return Notify(client, "В казне " .. EX.state.treasury .. " ток., заказ стоит " .. total)
		end

		local order = {id = EX.state.nextID, city = city, item = good.id, qty = qty, price = price, filled = 0,
			status = "open", by = client:Nick(), time = os.time(), contrib = {}}

		EX.state.nextID = EX.state.nextID + 1
		EX.state.treasury = EX.state.treasury - total
		EX.state.orders[#EX.state.orders + 1] = order
		Log("−" .. total .. " ток. — заказ №" .. order.id .. " (" .. city .. ")")

		-- the oldest closed ones are forgotten
		while (#EX.state.orders > 40) do
			local first = EX.state.orders[1]

			if (first.status == "open" or first.status == "packed") then
				break
			end

			table.remove(EX.state.orders, 1)
		end

		Save()
		EX.Broadcast()
		Notify(client, "Госзаказ №" .. order.id .. " оформлен: " .. qty .. "× " .. EX.ItemName(good.id) .. " → " .. city)
		Workers("Новый госзаказ №" .. order.id .. ": " .. qty .. "× " .. EX.ItemName(good.id) .. " для «" .. city ..
			"», " .. price .. " ток./шт. Стол комплектации — на заводе")
		MsgN(string.format("[EXPORT] %s создал заказ #%d: %d x %s -> %s (%d)", client:Nick(), order.id, qty, good.id, city,
			total))
	end

	function ACTIONS.exp_cancel(client, terminal, arg)
		local order = Get(tonumber(arg) or 0)

		if (!AtTerminal(terminal) or !order or !EX.CanManage(client) or
			(order.status != "open" and order.status != "packed")) then
			return
		end

		local total = order.qty * order.price

		order.status = "cancelled"
		order.done = os.time()
		EX.state.treasury = EX.state.treasury + total
		Log("+" .. total .. " ток. — заказ №" .. order.id .. " отменён")
		Save()
		EX.Broadcast()
		Notify(client, "Заказ №" .. order.id .. " отменён, " .. total .. " ток. вернулись в казну")
		Workers("Госзаказ №" .. order.id .. " отменён администрацией")
	end

	-- -------------------------------------------------------------- the bench --
	local function Count(client, id)
		local inventory = INV.Get(client)
		local count = 0

		for index = 1, I.maxSize do
			if (inventory.grid[index] and inventory.grid[index].id == id) then
				count = count + 1
			end
		end

		return count
	end

	local function Take(client, id, count)
		local inventory = INV.Get(client)

		for index = 1, I.maxSize do
			if (count <= 0) then
				break
			end

			if (inventory.grid[index] and inventory.grid[index].id == id) then
				inventory.grid[index] = nil
				count = count - 1
			end
		end
	end

	local function Near(client, entity)
		return IsValid(client) and IsValid(entity) and client:Alive() and client:GetPos():DistToSqr(entity:GetPos()) < 150 * 150
	end

	function EX.Bench(client, bench)
		if (!EX.CanWork(client)) then
			return Notify(client, "Заказы собирают рабочие ГСР и оформленные на заводе")
		end

		-- the oldest open order the worker carries goods for
		local order

		for _, entry in ipairs(EX.state.orders) do
			if (entry.status == "open" and Count(client, entry.item) > 0) then
				order = entry

				break
			end
		end

		if (!order) then
			local any

			for _, entry in ipairs(EX.state.orders) do
				if (entry.status == "open") then
					any = entry

					break
				end
			end

			return Notify(client, any and ("Нужно для заказа №" .. any.id .. ": " .. EX.ItemName(any.item) .. " (ещё " ..
				(any.qty - any.filled) .. ")") or "Открытых госзаказов нет")
		end

		local started = NW.progress.Start(client, "Комплектую заказ №" .. order.id, 4, function()
			if (order.status != "open") then
				return Notify(client, "Заказ уже закрыт")
			end

			local put = math.min(Count(client, order.item), order.qty - order.filled)

			if (put <= 0) then
				return
			end

			Take(client, order.item, put)
			INV.Changed(client)

			local key = tostring(client:GetCharacterID())

			order.contrib[key] = order.contrib[key] or {name = client:Nick(), n = 0}
			order.contrib[key].n = order.contrib[key].n + put
			order.filled = order.filled + put
			bench:EmitSound("physics/cardboard/cardboard_box_impact_hard" .. math.random(1, 7) .. ".wav", 60)
			NW.skills.Add(client, "strength", 2)

			if (order.filled >= order.qty) then
				order.status = "packed"

				local parcel = {id = "export_parcel", data = {order = order.id, city = order.city,
					text = order.qty .. "× " .. EX.ItemName(order.item)}}

				if (!INV.Add(client, parcel.id, parcel.data)) then
					INV.SpawnWorldItem(client, parcel)
				end

				INV.Changed(client)
				bench:EmitSound("items/ammocrate_close.wav", 65)
				Notify(client, "Заказ №" .. order.id .. " собран: посылку — на точку сбыта")
				Workers("Госзаказ №" .. order.id .. " собран, " .. client:Nick() .. " везёт посылку на точку сбыта")
			else
				Notify(client, "Заказ №" .. order.id .. ": +" .. put .. ", собрано " .. order.filled .. " / " .. order.qty)
			end

			Save()
			EX.Broadcast()
		end, function()
			return Near(client, bench)
		end)

		if (started) then
			NW.SayMe(client, "укладывает продукцию в ящик заказа")
		end
	end

	-- -------------------------------------------------------- the delivery --
	local function Online(charID)
		for _, client in ipairs(player.GetAll()) do
			if (tostring(client:GetCharacterID()) == charID) then
				return client
			end
		end
	end

	local function Pay(client, amount)
		NW.social.SetTokens(client, NW.social.GetTokens(client) + amount)
	end

	function EX.Deliver(client, point)
		local inventory = INV.Get(client)
		local index

		for cell = 1, I.maxSize do
			if (inventory.grid[cell] and inventory.grid[cell].id == "export_parcel") then
				index = cell

				break
			end
		end

		if (!index) then
			return Notify(client, "Сюда привозят посылки госзаказов: соберите заказ на столе комплектации")
		end

		local started = NW.progress.Start(client, "Сдаю посылку", 3, function()
			local cell = inventory.grid[index]

			if (!cell or cell.id != "export_parcel") then
				return
			end

			local order = Get(tonumber(cell.data and cell.data.order) or 0)

			inventory.grid[index] = nil
			INV.Changed(client)

			if (!order or order.status != "packed") then
				return Notify(client, "Этот заказ отменён или уже сдан: посылку списали")
			end

			local total = order.qty * order.price
			local courier = math.floor(total * math.Clamp(courierCut:GetFloat(), 0, 100) / 100)
			local rest = total - courier
			local paid = courier

			Pay(client, courier)

			-- the packers by their share
			for charID, entry in pairs(order.contrib) do
				local share = math.floor(rest * entry.n / order.qty)
				local worker = Online(charID)

				if (IsValid(worker)) then
					Pay(worker, share)
					paid = paid + share
					Notify(worker, "Госзаказ №" .. order.id .. " доставлен: +" .. share .. " ток. за сборку (" .. entry.n ..
						" шт.)")
				end
			end

			order.status = "delivered"
			order.done = os.time()
			order.courier = client:Nick()
			-- the shares of those not in the city and the rounding stay in the treasury
			EX.state.treasury = EX.state.treasury + (total - paid)

			Log("заказ №" .. order.id .. " доставлен в «" .. order.city .. "», выплачено " .. paid .. " ток.")
			Save()
			EX.Broadcast()
			point:EmitSound("items/ammocrate_open.wav", 65)
			Notify(client, "Посылка сдана: +" .. courier .. " ток. за доставку")
			MsgN(string.format("[EXPORT] %s доставил заказ #%d (%d)", client:Nick(), order.id, total))
		end, function()
			return Near(client, point)
		end)

		if (started) then
			NW.SayMe(client, "сдаёт посылку на точке сбыта")
		end
	end

	-- -------------------------------------------------------------- commands --
	NW.AddChatCommand("cityadmin", {admin = true, run = function(client, rest)
		local target = NW.FindPlayer(rest or "")

		if (!target or target:GetCharacterID() == 0 or !target.nwCharacter) then
			return Notify(client, "/cityadmin <имя> — выдать или снять «Администрация города»")
		end

		local data = target.nwCharacter.data or {}

		target.nwCharacter.data = data
		data.cityAdmin = !data.cityAdmin or nil
		NW.char.SaveData(target)
		target:SetNW2Bool("nwCityAdmin", data.cityAdmin == true)
		Notify(client, target:Nick() .. ": " .. (data.cityAdmin and "администрация города" or "больше не администрация"))
		Notify(target, data.cityAdmin and "Вы — администрация города: госзаказы на терминале ГСР" or
			"Полномочия администрации города сняты")
	end})

	NW.AddChatCommand("treasury", {admin = true, run = function(client, rest)
		local action, amount = string.match(rest or "", "^(%a+)%s+(%-?%d+)")

		amount = tonumber(amount)

		if (action == "add" and amount) then
			EX.state.treasury = math.max(0, EX.state.treasury + amount)
			Log((amount >= 0 and "+" or "") .. amount .. " ток. — " .. client:Nick())
		elseif (action == "set" and amount) then
			EX.state.treasury = math.max(0, amount)
			Log("казна = " .. amount .. " — " .. client:Nick())
		elseif (string.Trim(rest or "") != "") then
			return Notify(client, "/treasury  ·  /treasury add <N>  ·  /treasury set <N>")
		end

		Save()
		EX.Broadcast()
		Notify(client, "Казна города: " .. EX.state.treasury .. " ток.")
	end})

	-- the bench and the point stay with the map; the model - the C menu
	timer.Simple(0, function()
		for _, class in ipairs({"nw_export_bench", "nw_export_point"}) do
			NW.persist.Register(class, {
				Save = function(entity)
					return {model = entity.nwModel}
				end,
				Load = function(entity, data)
					if (isstring(data.model) and util.IsValidModel(data.model)) then
						entity.nwModel = data.model
						entity:SetModel(data.model)
						entity:PhysicsInit(SOLID_VPHYSICS)

						local physics = entity:GetPhysicsObject()

						if (IsValid(physics)) then
							physics:EnableMotion(false)
						end
					end
				end
			})
		end
	end)
end

NW.entSettings.ModelOnly("nw_export_bench", "Стол комплектации заказов", "models/props_wasteland/controlroom_desk001a.mdl")
NW.entSettings.ModelOnly("nw_export_point", "Точка сбыта", "models/props_junk/wood_pallet001a.mdl")

if (SERVER) then
	return
end

-- ------------------------------------------------------------------ client --
EX.data = EX.data or {treasury = 0, orders = {}, log = {}}

local CT = NW.cmbTerminal
local C = CT.colors
local GREEN = Color(130, 214, 120)
local RED = Color(232, 100, 80)

net.Receive("nwExports", function()
	EX.data = util.JSONToTable(net.ReadString() or "") or EX.data

	local focus = vgui.GetKeyboardFocus()

	-- not while something is typed in the form
	if (CT.kind == "cwu" and CT.page == "exports" and IsValid(CT.area) and
		!(IsValid(focus) and focus:GetClassName() == "TextEntry")) then
		CT.Refresh()
	end
end)

local function Up(text)
	return NW.terminal.Upper(tostring(text or ""))
end

local SCREEN = CT.screens.cwu

table.insert(SCREEN.order, {"exports", "Госзаказы"})

SCREEN.pages.exports = {
	title = "Госзаказы",
	subtitle = "Поставки в другие города / казна",
	Build = function(area, w, h)
		local me = LocalPlayer()
		local gap = math.Round(h * 0.025)
		local data = EX.data
		local active = 0

		if (!EX.asked or EX.asked < RealTime() - 3) then
			EX.asked = RealTime()
			CT.Send("exp_list")
		end

		for _, order in ipairs(data.orders or {}) do
			if (order.status == "open" or order.status == "packed") then
				active = active + 1
			end
		end

		local cw, ch = (w - gap * 2) / 3, math.Round(h * 0.15)

		CT.Card(area, 0, 0, cw, ch, "Казна города", function()
			return (EX.data.treasury or 0) .. " ток."
		end)
		CT.Card(area, cw + gap, 0, cw, ch, "Открытых заказов", active)
		CT.Card(area, (cw + gap) * 2, 0, cw, ch, "Ваш доступ", EX.CanManage(me) and "Администрация" or
			(EX.CanWork(me) and "Сборка и доставка" or "Только просмотр"))

		local y = ch + gap

		-- the form of the administration
		if (EX.CanManage(me)) then
			local form = EX.form or {city = 1, good = 1, qty = "10", price = nil}

			EX.form = form

			local good = EX.goods[form.good]
			local fh = math.Round(h * 0.07)
			local x = 0

			CT.Button(area, EX.cities[form.city], x, y, w * 0.18, fh, function()
				form.city = form.city % #EX.cities + 1
				CT.Refresh()
			end)
			x = x + w * 0.18 + gap * 0.5

			CT.Button(area, EX.ItemName(good.id), x, y, w * 0.24, fh, function()
				form.good = form.good % #EX.goods + 1
				form.price = nil
				CT.Refresh()
			end)
			x = x + w * 0.24 + gap * 0.5

			local qty = CT.Entry(area, x, y, w * 0.12, fh, "Кол-во")

			qty:SetValue(form.qty or "")
			qty.OnChange = function(self)
				form.qty = self:GetValue()
			end
			x = x + w * 0.12 + gap * 0.5

			local price = CT.Entry(area, x, y, w * 0.14, fh, "Цена/шт")

			price:SetValue(form.price or tostring(good.price))
			price.OnChange = function(self)
				form.price = self:GetValue()
			end
			x = x + w * 0.14 + gap * 0.5

			CT.Button(area, "Оформить", x, y, w - x, fh, function()
				CT.Send("exp_create", util.TableToJSON({city = EX.cities[form.city], item = good.id,
					qty = tonumber(form.qty) or 0, price = tonumber(form.price or good.price) or 0}))
			end, true)

			y = y + fh + gap * 0.4
			CT.Label(area, "Город и товар — нажатием. Сумма заказа сразу резервируется из казны.", 0, y, "nwCmtSmall", C.dim)
			y = y + h * 0.045
		end

		local scroll = CT.Scroll(area, 0, y, w, h - y)
		local orders = data.orders or {}

		if (#orders == 0) then
			CT.Label(scroll, "Заказов нет", 0, 0, "nwCmtText", C.dim)
		end

		for _, order in ipairs(orders) do
			local rowH = math.Round(h * 0.12)
			local row = scroll:Add("DPanel")
			local status = order.status
			local color = status == "open" and C.cyan or (status == "packed" and Color(236, 206, 90) or
				(status == "delivered" and GREEN or RED))

			row:Dock(TOP)
			row:DockMargin(0, 0, 8, gap * 0.4)
			row:SetTall(rowH)
			row.Paint = function(_, rw, rh)
				surface.SetDrawColor(C.dark.r, C.dark.g, C.dark.b, 190)
				surface.DrawRect(0, 0, rw, rh)
				surface.SetDrawColor(color.r, color.g, color.b, 220)
				surface.DrawRect(0, 0, 3, rh)
				draw.SimpleText("№" .. order.id .. "  ·  " .. Up(order.city) .. "  ·  " .. Up(EX.ItemName(order.item)) .. " ×" ..
					order.qty .. "  ·  " .. order.price .. " ТОК./ШТ", "nwCmtText", rh * 0.15, rh * 0.3, C.text, TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)
				draw.SimpleText(Up(EX.statuses[status] or status) .. "  ·  СОБРАНО " .. order.filled .. " / " .. order.qty ..
					"  ·  СУММА " .. (order.qty * order.price) .. " ТОК.  ·  " .. Up(order.by or ""), "nwCmtSmall", rh * 0.15,
					rh * 0.7, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				if (status == "open") then
					local bw = rw * 0.18
					local bx = rw - bw - rh * 0.15 - (EX.CanManage(me) and rw * 0.16 or 0)

					surface.SetDrawColor(255, 255, 255, 18)
					surface.DrawRect(bx, rh * 0.62, bw, rh * 0.14)
					surface.SetDrawColor(color.r, color.g, color.b, 220)
					surface.DrawRect(bx, rh * 0.62, bw * order.filled / math.max(order.qty, 1), rh * 0.14)
				end
			end

			if (EX.CanManage(me) and (status == "open" or status == "packed")) then
				CT.Button(row, "Отменить", w - 8 - w * 0.15, rowH * 0.2, w * 0.14, rowH * 0.6, function()
					CT.Send("exp_cancel", tostring(order.id))
				end, false, true)
			end
		end
	end
}

-- the board over the bench and the point: the open orders, what is needed, where it goes
surface.CreateFont("nwExportTitle", {font = "Montserrat SemiBold", size = 42, weight = 600, extended = true,
	antialias = true})
surface.CreateFont("nwExportText", {font = "Exo 2", size = 28, weight = 500, extended = true, antialias = true})

local AMBER = Color(232, 170, 64)

function EX.DrawBoard(entity, kind)
	local distance = EyePos():DistToSqr(entity:GetPos())

	if (distance > 450 * 450) then
		return
	end

	local alpha = math.Clamp((450 - math.sqrt(distance)) / 120, 0, 1)
	local lines = {}

	for index = #(EX.data.orders or {}), 1, -1 do
		local order = EX.data.orders[index]

		if (kind == "bench" and order.status == "open") then
			lines[#lines + 1] = {"№" .. order.id .. "  " .. EX.ItemName(order.item) .. ": " .. order.filled .. " / " .. order.qty ..
				"  →  " .. order.city, C.text}
		elseif (order.status == "packed") then
			lines[#lines + 1] = {"№" .. order.id .. "  посылка для «" .. order.city .. "» — " .. (order.qty * order.price) ..
				" ток.", Color(236, 206, 90)}
		end
	end

	if (#lines == 0) then
		lines[1] = {kind == "bench" and "Открытых госзаказов нет" or "Посылок к отправке нет", Color(170, 164, 150)}
	end

	local top = entity:LocalToWorld(Vector(0, 0, entity:OBBMaxs().z + 16))
	local angle = Angle(0, EyeAngles().y - 90, 90)
	local height = 110 + math.min(#lines, 5) * 34

	cam.Start3D2D(top, angle, 0.08)
		draw.RoundedBox(10, -300, -height, 600, height, Color(14, 16, 20, 215 * alpha))
		draw.RoundedBox(2, -300, -height, 600, 4, ColorAlpha(AMBER, 255 * alpha))
		draw.SimpleText(kind == "bench" and "Стол комплектации заказов" or "Точка сбыта", "nwExportTitle", 0, -height + 34,
			Color(236, 238, 242, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		for index = 1, math.min(#lines, 5) do
			draw.SimpleText(lines[index][1], "nwExportText", 0, -height + 60 + index * 34, ColorAlpha(lines[index][2],
				255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		draw.SimpleText(kind == "bench" and "E — сложить продукцию в заказ" or "E — сдать посылку госзаказа", "nwExportText",
			0, -22, ColorAlpha(AMBER, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end
