-- Purchasable apartments (server). See sh_apartments.lua for the settings.
local A = NETWORK.apartments
local requestPath = "network/apartment_requests.txt"

A.requests = A.requests or {}
A.refunds = A.refunds or {}

local function Notice(client, text, tone)
	if (IsValid(client)) then
		NETWORK.notice.Send(client, text, tone or "info")
	end
end

local function CharID(client)
	local character = IsValid(client) and client.GetCharacter and client:GetCharacter()

	return character and tostring(character:GetID()) or nil
end

local function Log(text, position)
	MsgN("[Network] Квартиры: " .. text)

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("housing", text, position)
	end
end

function A.SaveRequests()
	file.CreateDir("network")
	file.Write(requestPath, util.TableToJSON({requests = A.requests, refunds = A.refunds}, true))
end

function A.LoadRequests()
	local data = util.JSONToTable(file.Read(requestPath, "DATA") or "")

	A.requests = istable(data) and istable(data.requests) and data.requests or {}
	A.refunds = istable(data) and istable(data.refunds) and data.refunds or {}
end

A.LoadRequests()

function A.CID(charID)
	local id = tonumber(charID)

	return id and NETWORK.cid and NETWORK.cid.Get(id) or "—"
end

-- Removes an owner entry without touching furniture (used when the buyer is offline or on another character).
function A.DropOwner(data, steamID)
	local owners = NETWORK.door.GetOwners(data)

	owners[steamID] = nil
	data.owners = next(owners) and owners or nil

	if (data.owner == steamID) then
		local nextID, entry = next(owners)

		data.owner = nextID
		data.ownerName = entry and entry.name or nil
		data.ownerChar = entry and entry.char or nil
		data.ownerFaction = entry and entry.faction or nil
	end
end

-- Iterate every stored door key with a purchase record. Callback gets (key, data).
function A.EachPurchase(callback)
	for key, data in pairs(NETWORK.door.list) do
		if (A.IsPurchased(data) and !data.linkKey) then
			if (callback(key, data) == true) then
				return
			end
		end
	end
end

-- Live entity + data of the apartment bought by a character.
function A.GetOwned(charID)
	charID = tostring(charID or "")

	local foundEntity, foundData

	A.EachPurchase(function(key, data)
		if (tostring(data.purchase.char) == charID) then
			local entity = NETWORK.door.FindByKey(key)

			if (IsValid(entity)) then
				foundEntity, foundData = entity, NETWORK.door.GetData(entity)

				return true
			end
		end
	end)

	return foundEntity, foundData
end

-- Where does a character live? Returns entity, data, kind ("purchase" | "temp").
function A.FindResidence(charID)
	charID = tostring(charID or "")

	local entity, data = A.GetOwned(charID)

	if (IsValid(entity)) then
		return entity, data, "purchase"
	end

	for _, door in ipairs(ents.GetAll()) do
		if (NETWORK.door.IsDoor(door)) then
			local doorData = NETWORK.door.GetData(door)

			if (doorData and doorData.type == "residential") then
				for _, entry in pairs(NETWORK.door.GetOwners(doorData)) do
					if (tostring(entry.char or "") == charID) then
						return door, doorData, "temp"
					end
				end
			end
		end
	end
end

function A.Address(data)
	local name = NETWORK.door.GetHousingName(data)

	return name != "" and name or "Квартира без номера"
end

-- Data block for the PDA / CID record.
function A.Describe(charID)
	local entity, data, kind = A.FindResidence(charID)

	if (!IsValid(entity)) then
		return {address = "", kind = "none"}
	end

	local purchase = kind == "purchase" and data.purchase or nil

	return {
		address = A.Address(data),
		kind = kind,
		debt = purchase and (purchase.debt or 0) or 0,
		unpaid = purchase and (purchase.unpaid or 0) or 0,
		since = purchase and purchase.since or nil
	}
end

function A.Registry()
	local rows, seen = {}, {}
	local online = {}

	for _, client in ipairs(player.GetAll()) do
		local id = CharID(client)

		if (id) then
			online[id] = client
		end
	end

	A.EachPurchase(function(key, data)
		local char = tostring(data.purchase.char)

		if (!seen[char]) then
			seen[char] = true
			rows[#rows + 1] = {
				char = char, cid = A.CID(char), name = data.purchase.name or "?",
				address = A.Address(data), kind = "purchase", debt = data.purchase.debt or 0,
				online = online[char] != nil
			}
		end
	end)

	for _, door in ipairs(ents.GetAll()) do
		local data = NETWORK.door.IsDoor(door) and NETWORK.door.GetData(door)

		if (data and data.type == "residential" and !A.IsPurchased(data)) then
			for _, entry in pairs(NETWORK.door.GetOwners(data)) do
				local char = tostring(entry.char or "")

				if (char != "" and !seen[char]) then
					seen[char] = true
					rows[#rows + 1] = {
						char = char, cid = A.CID(char), name = entry.name or "?",
						address = A.Address(data), kind = "temp", debt = 0, online = online[char] != nil
					}
				end
			end
		end
	end

	table.sort(rows, function(a, b)
		if (a.kind != b.kind) then
			return a.kind == "purchase"
		end

		return a.address < b.address
	end)

	return rows
end

-- Restore/hide the buyer's owner entry depending on which character is loaded.
function A.SyncOwner(client)
	local steamID = client:SteamID64()
	local char = CharID(client)
	local entities = {}

	A.EachPurchase(function(key, data)
		if (data.purchase.steamID == steamID) then
			local entity = NETWORK.door.FindByKey(key)

			if (IsValid(entity)) then
				entities[entity] = true
			end
		end
	end)

	for entity in pairs(entities) do
		local data = NETWORK.door.GetData(entity)

		if (A.IsPurchased(data)) then
			local owners = NETWORK.door.GetOwners(data)

			if (tostring(data.purchase.char) == char) then
				data.purchase.name = client:GetCharacterName()
				NETWORK.terminal.AddResident(data, client)
			elseif (owners[steamID]) then
				A.DropOwner(data, steamID)
			end

			NETWORK.door.Set(entity, data)
		end
	end
end

hook.Add("NetworkCharacterLoaded", "nwApartmentsOwner", function(client)
	timer.Simple(1.2, function()
		if (!IsValid(client) or !client:HasCharacter()) then
			return
		end

		A.SyncOwner(client)

		local char = CharID(client)
		local refund = char and tonumber(A.refunds[char])

		if (refund and refund > 0) then
			NETWORK.terminal.SetBank(client, NETWORK.terminal.GetBank(client) + refund)
			A.refunds[char] = nil
			A.SaveRequests()

			if (NETWORK.persistence and NETWORK.persistence.Save) then
				NETWORK.persistence.Save(client)
			end

			Notice(client, string.format("Возврат за заявку на квартиру: %d т. зачислено на счёт.", refund), "good")
		end

		local entity, data = A.GetOwned(char)

		if (IsValid(entity) and (data.purchase.debt or 0) > 0) then
			Notice(client, string.format("Налоговая задолженность по квартире: %d т.", data.purchase.debt), "warn")
		end
	end)
end)

function A.NotifyAdmins(text)
	for _, admin in ipairs(player.GetAll()) do
		if (admin:IsAdmin()) then
			Notice(admin, text, "info")
		end
	end
end

-- Citizen pays for an apartment; an administrator assigns the actual door later.
function A.Buy(client, wish)
	if (!client:HasCharacter()) then
		return
	end

	if (NETWORK.factions.IsAlliance(client)) then
		return "Сотрудникам Альянса квартиры не продаются."
	end

	local char = CharID(client)

	if (IsValid((A.GetOwned(char)))) then
		return "У вас уже есть собственная квартира."
	end

	if (A.requests[char]) then
		return "Заявка уже подана — ожидайте администратора."
	end

	wish = NETWORK.util.Sanitise(tostring(wish or ""), 120)

	if (utf8.len(wish) == nil or utf8.len(wish) < 3) then
		return "Укажите, где хотите жить: дом, этаж, номер."
	end

	local bank, cash = NETWORK.terminal.GetBank(client), client:GetTokens()

	if (bank + cash < A.price) then
		return string.format("Недостаточно средств: нужно %d т. (счёт + наличные).", A.price)
	end

	local fromBank = math.min(bank, A.price)

	NETWORK.terminal.SetBank(client, bank - fromBank)

	if (A.price - fromBank > 0) then
		NETWORK.currency.Take(client, A.price - fromBank)
	end

	A.requests[char] = {
		steamID = client:SteamID64(), name = client:GetCharacterName(), cid = A.CID(char),
		wish = wish, paid = A.price, time = os.time()
	}

	A.SaveRequests()

	if (NETWORK.persistence and NETWORK.persistence.Save) then
		NETWORK.persistence.Save(client)
	end

	A.NotifyAdmins(string.format("Новая заявка на квартиру: %s (CID %s) — «%s». /aptrequests",
		client:GetCharacterName(), A.CID(char), wish))
	Log(string.format("%s оплатил квартиру (%d т.): %s", client:GetCharacterName(), A.price, wish), client:GetPos())

	return string.format("Оплачено %d т. Заявка передана администрации — вам выделят квартиру.", A.price)
end

function A.Cancel(client)
	local char = CharID(client)
	local request = char and A.requests[char]

	if (!request) then
		return "Активной заявки нет."
	end

	NETWORK.terminal.SetBank(client, NETWORK.terminal.GetBank(client) + (request.paid or 0))
	A.requests[char] = nil
	A.SaveRequests()

	if (NETWORK.persistence and NETWORK.persistence.Save) then
		NETWORK.persistence.Save(client)
	end

	Log(client:GetCharacterName() .. " отозвал заявку на квартиру")

	return string.format("Заявка отозвана. %d т. возвращено на счёт.", request.paid or 0)
end

-- Administrator: give the aimed door to a player as a permanent apartment.
function A.Assign(entity, target, admin)
	local data = NETWORK.door.GetData(entity) or {type = "residential"}

	if (data.type != "residential") then
		return false, "Это не жилая дверь. Сначала: /doorset residential <название>"
	end

	local char = CharID(target)
	local steamID = target:SteamID64()

	if (A.IsPurchased(data) and tostring(data.purchase.char) != char) then
		return false, "Квартира уже принадлежит: " .. (data.purchase.name or "?") .. ". Сначала /aptrevoke."
	end

	local owned = A.GetOwned(char)

	if (IsValid(owned) and owned != entity) then
		return false, "У игрока уже есть собственная квартира."
	end

	-- Free the target's temporary home elsewhere.
	local home, homeData = NETWORK.terminal.GetHome(target)

	if (IsValid(home) and !A.IsPurchased(homeData) and NETWORK.door.GetData(home) != data) then
		NETWORK.terminal.RemoveResident(homeData, steamID)
		NETWORK.door.Set(home, homeData)
	end

	-- A bought apartment is private: move temporary residents out.
	for otherID, entry in pairs(table.Copy(NETWORK.door.GetOwners(data))) do
		if (otherID != steamID) then
			NETWORK.terminal.RemoveResident(data, otherID)

			local other = player.GetBySteamID64(otherID)

			if (IsValid(other)) then
				NETWORK.terminal.ClearMarker(other)
				Notice(other, "Ваше временное жильё выкуплено. Получите новое в терминале.", "warn")
			end
		end
	end

	local request = A.requests[char]

	data.purchase = {
		char = char, steamID = steamID, name = target:GetCharacterName(), since = os.time(),
		debt = 0, unpaid = 0, taxPaid = 0, paid = request and request.paid or 0,
		by = IsValid(admin) and admin:GetCharacterName() or "Консоль"
	}

	NETWORK.terminal.AddResident(data, target)
	data.bLocked = true

	NETWORK.door.Set(entity, data)

	A.requests[char] = nil
	A.SaveRequests()

	if (NETWORK.dialogue and NETWORK.dialogue.CountItem and NETWORK.dialogue.CountItem(target, "keys") < 1) then
		NETWORK.inventory.Give(target, "keys", 1)
	end

	NETWORK.terminal.SetMarker(target, entity:GetPos(), A.Address(data))
	Notice(target, string.format("Квартира «%s» оформлена в собственность. Налог: %d т. за выплату.",
		A.Address(data), A.tax), "good")
	Log(string.format("%s выдал квартиру «%s» игроку %s%s", IsValid(admin) and admin:Nick() or "Консоль",
		A.Address(data), target:GetCharacterName(), request and "" or " (без оплаты через терминал)"), entity:GetPos())

	return true, "Квартира выдана: " .. target:GetCharacterName() .. " → " .. A.Address(data)
end

function A.Revoke(entity, reason)
	local data = NETWORK.door.GetData(entity)

	if (!A.IsPurchased(data)) then
		return false, "Эта квартира не куплена."
	end

	local purchase = data.purchase
	local steamID = purchase.steamID

	data.purchase = nil
	NETWORK.terminal.RemoveResident(data, steamID)
	data.bLocked = false

	NETWORK.door.Set(entity, data)
	NETWORK.door.EachLeaf(entity, function(leaf)
		leaf:Fire("Unlock")
	end)

	local owner = player.GetBySteamID64(steamID)

	if (IsValid(owner)) then
		NETWORK.terminal.ClearMarker(owner)
		Notice(owner, "Право собственности на квартиру отозвано" .. (reason and (": " .. reason) or "."), "warn")
	end

	Log(string.format("Квартира «%s» (%s) освобождена%s", A.Address(data), purchase.name or "?",
		reason and (": " .. reason) or ""), entity:GetPos())

	return true, "Квартира освобождена: " .. A.Address(data)
end

-- Tax: collected after every budget payday from online owners playing the buyer character.
function A.CollectTax()
	if (A.tax <= 0) then
		return
	end

	local total = 0

	for _, client in ipairs(player.GetAll()) do
		local char = CharID(client)
		local entity, data

		if (char) then
			entity, data = A.GetOwned(char)
		end

		if (IsValid(entity) and data.purchase.steamID == client:SteamID64()) then
			local purchase = data.purchase
			local due = A.tax + (purchase.debt or 0)
			local bank = NETWORK.terminal.GetBank(client)
			local fromBank = math.min(bank, due)
			local fromCash = math.min(client:GetTokens(), due - fromBank)

			NETWORK.terminal.SetBank(client, bank - fromBank)

			if (fromCash > 0) then
				NETWORK.currency.Take(client, fromCash)
			end

			local paid = fromBank + fromCash

			total = total + paid
			purchase.taxPaid = (purchase.taxPaid or 0) + paid
			purchase.debt = due - paid

			if (purchase.debt > 0) then
				purchase.unpaid = (purchase.unpaid or 0) + 1

				Notice(client, string.format("Налог на квартиру не оплачен полностью. Долг: %d т.", purchase.debt), "warn")
			else
				purchase.unpaid = 0

				Notice(client, string.format("Налог на квартиру: −%d т.", paid), "info")
			end

			if (A.seizeAfter > 0 and purchase.unpaid >= A.seizeAfter) then
				A.Revoke(entity, "изъята за неуплату налога")
			else
				NETWORK.door.Set(entity, data)
			end

			if (NETWORK.persistence and NETWORK.persistence.Save) then
				NETWORK.persistence.Save(client)
			end
		end
	end

	local B = NETWORK.budget

	if (total > 0 and B and B.state) then
		B.state.balance = B.state.balance + total

		if (B.Log) then
			B.Log(string.format("Налог с квартир: +%d т.", total))
		end

		if (B.Save) then
			B.Save()
		end
	end
end

hook.Add("Initialize", "nwApartmentsTax", function()
	local B = NETWORK.budget

	if (!B or !B.Payday or B.bApartmentTax) then
		return
	end

	local base = B.Payday

	B.bApartmentTax = true
	B.Payday = function(...)
		base(...)
		A.CollectTax()
	end
end)

function A.PayDebt(client)
	local entity, data = A.GetOwned(CharID(client))

	if (!IsValid(entity)) then
		return "У вас нет собственной квартиры."
	end

	local debt = data.purchase.debt or 0

	if (debt <= 0) then
		return "Задолженности нет."
	end

	local bank = NETWORK.terminal.GetBank(client)
	local fromBank = math.min(bank, debt)
	local fromCash = math.min(client:GetTokens(), debt - fromBank)

	NETWORK.terminal.SetBank(client, bank - fromBank)

	if (fromCash > 0) then
		NETWORK.currency.Take(client, fromCash)
	end

	local paid = fromBank + fromCash

	data.purchase.debt = debt - paid
	data.purchase.taxPaid = (data.purchase.taxPaid or 0) + paid

	if (data.purchase.debt <= 0) then
		data.purchase.unpaid = 0
	end

	NETWORK.door.Set(entity, data)

	if (NETWORK.budget and NETWORK.budget.state) then
		NETWORK.budget.state.balance = NETWORK.budget.state.balance + paid
		NETWORK.budget.Save()
	end

	if (NETWORK.persistence and NETWORK.persistence.Save) then
		NETWORK.persistence.Save(client)
	end

	return string.format("Оплачено %d т. Остаток долга: %d т.", paid, data.purchase.debt)
end

-- Terminal integration -----------------------------------------------------------------------
hook.Add("NetworkTerminalData", "nwApartments", function(client, data)
	local char = CharID(client)
	local entity, apartment = A.GetOwned(char)
	local request = char and A.requests[char]

	data.apartment = {
		price = A.price,
		tax = A.tax,
		owned = IsValid(entity) and {address = A.Address(apartment), debt = apartment.purchase.debt or 0} or nil,
		request = request and {wish = request.wish, time = request.time} or nil
	}
end)

local function RegisterTerminalActions()
	local actions = NETWORK.terminal and NETWORK.terminal.actions

	if (!actions) then
		return
	end

	actions.aptBuy = function(client, entity, payload)
		return A.Buy(client, payload.wish)
	end

	actions.aptCancel = function(client)
		return A.Cancel(client)
	end

	actions.aptPay = function(client)
		return A.PayDebt(client)
	end
end

RegisterTerminalActions()
hook.Add("Initialize", "nwApartmentsTerminal", RegisterTerminalActions)

-- Commands ----------------------------------------------------------------------------------
local function AimDoor(client)
	local trace = client:GetEyeTrace()
	local entity = trace.Entity

	if (!NETWORK.door.IsDoor(entity)) then
		local best, bestDistance

		for _, other in ipairs(ents.FindInSphere(trace.HitPos, 96)) do
			if (NETWORK.door.IsDoor(other)) then
				local distance = other:GetPos():DistToSqr(trace.HitPos)

				if (!bestDistance or distance < bestDistance) then
					best, bestDistance = other, distance
				end
			end
		end

		entity = best
	end

	if (NETWORK.door.IsDoor(entity) and client:GetPos():Distance(entity:GetPos()) <= 250) then
		return entity
	end
end

local function Reply(client, text)
	if (IsValid(client)) then
		Notice(client, text, "info")
	else
		MsgN(text)
	end
end

local function FindRequestChar(argument)
	argument = string.Trim(tostring(argument or ""))

	if (argument:sub(1, 1) == "#") then
		return argument:sub(2)
	end

	local target = NETWORK.permission.Find(argument)

	return IsValid(target) and CharID(target) or nil
end

NETWORK.command.Register("aptgive", {
	description = "Выдать квартиру (дверь под прицелом) в собственность игроку",
	usage = "/aptgive <игрок>",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		local entity = AimDoor(client)

		if (!entity) then
			return Reply(client, "Посмотрите на дверь квартиры (до 250 юнитов).")
		end

		local target = NETWORK.permission.Find(arguments[1] or "")

		if (!IsValid(target) or !target:HasCharacter()) then
			return Reply(client, "Игрок не найден. /aptgive <имя персонажа или ник>")
		end

		local _, text = A.Assign(entity, target, client)

		Reply(client, text)
	end
})

NETWORK.command.Register("aptrevoke", {
	description = "Отозвать купленную квартиру (дверь под прицелом или игрок)",
	usage = "/aptrevoke [игрок]",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		local entity

		if ((arguments[1] or "") != "") then
			local target = NETWORK.permission.Find(arguments[1])

			entity = IsValid(target) and A.GetOwned(CharID(target)) or nil
		else
			entity = AimDoor(client)
		end

		if (!IsValid(entity)) then
			return Reply(client, "Купленная квартира не найдена.")
		end

		local _, text = A.Revoke(entity, "решение администрации")

		Reply(client, text)
	end
})

NETWORK.command.Register("aptrequests", {
	description = "Заявки на покупку квартир",
	usage = "/aptrequests",
	adminOnly = true,
	OnRun = function(command, client)
		local count = 0

		for char, request in SortedPairsByMemberValue(A.requests, "time") do
			count = count + 1

			Reply(client, string.format("#%s  %s (CID %s): «%s», %s, оплачено %d т.", char, request.name or "?",
				request.cid or "—", request.wish or "", os.date("%d.%m %H:%M", request.time or 0), request.paid or 0))
		end

		Reply(client, count == 0 and "Заявок нет." or "Выдать: подойдите к двери и /aptgive <игрок>. Отказ с возвратом: /aptdecline <игрок|#id>.")
	end
})

NETWORK.command.Register("aptdecline", {
	description = "Отклонить заявку на квартиру с возвратом жетонов",
	usage = "/aptdecline <игрок|#id>",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		local char = FindRequestChar(arguments[1])
		local request = char and A.requests[char]

		if (!request) then
			return Reply(client, "Заявка не найдена. Список: /aptrequests")
		end

		A.requests[char] = nil

		local target

		for _, other in ipairs(player.GetAll()) do
			if (CharID(other) == char) then
				target = other
			end
		end

		if (IsValid(target)) then
			NETWORK.terminal.SetBank(target, NETWORK.terminal.GetBank(target) + (request.paid or 0))

			if (NETWORK.persistence and NETWORK.persistence.Save) then
				NETWORK.persistence.Save(target)
			end

			Notice(target, string.format("Заявка на квартиру отклонена. %d т. возвращено на счёт.", request.paid or 0), "warn")
		else
			A.refunds[char] = (tonumber(A.refunds[char]) or 0) + (request.paid or 0)
		end

		A.SaveRequests()
		Reply(client, "Заявка отклонена, жетоны возвращены: " .. (request.name or "?"))
	end
})

NETWORK.command.Register("aptinfo", {
	description = "Информация о квартире под прицелом",
	usage = "/aptinfo",
	adminOnly = true,
	OnRun = function(command, client)
		local entity = AimDoor(client)
		local data = entity and NETWORK.door.GetData(entity)

		if (!data) then
			return Reply(client, "Дверь не настроена.")
		end

		local owners = {}

		for _, entry in pairs(NETWORK.door.GetOwners(data)) do
			owners[#owners + 1] = entry.name or "?"
		end

		Reply(client, string.format("%s — жильцов: %d/%d (%s)", A.Address(data), #owners, A.capacity,
			#owners > 0 and table.concat(owners, ", ") or "пусто"))

		if (A.IsPurchased(data)) then
			local p = data.purchase

			Reply(client, string.format("Собственник: %s (CID %s) с %s, долг %d т., выдал: %s", p.name or "?",
				A.CID(p.char), os.date("%d.%m.%Y", p.since or 0), p.debt or 0, p.by or "?"))
		end
	end
})

NETWORK.command.Register("myapt", {
	description = "Моя квартира и налог",
	usage = "/myapt",
	OnRun = function(command, client)
		local char = CharID(client)
		local entity, data = A.GetOwned(char)

		if (IsValid(entity)) then
			return Reply(client, string.format("Квартира: %s. Налог %d т. за выплату, долг: %d т. Оплатить долг: /aptpay",
				A.Address(data), A.tax, data.purchase.debt or 0))
		end

		if (char and A.requests[char]) then
			return Reply(client, "Заявка на квартиру ожидает администратора: «" .. A.requests[char].wish .. "».")
		end

		Reply(client, string.format("Собственной квартиры нет. Купить: гражданский терминал → Жильё (%d т.).", A.price))
	end
})

NETWORK.command.Register("aptpay", {
	description = "Оплатить налоговый долг по квартире",
	usage = "/aptpay",
	OnRun = function(command, client)
		Reply(client, A.PayDebt(client))
	end
})
