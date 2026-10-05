NETWORK.mail = NETWORK.mail or {}

local MAIL = NETWORK.mail

MAIL.subjectMax = 60
MAIL.textMax = 600
MAIL.cooldown = 60
MAIL.keep = 80

if (CLIENT) then
	return
end

local dataPath = "network/mail.txt"

MAIL.letters = MAIL.letters or {}
MAIL.nextID = MAIL.nextID or 1

function MAIL.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON({letters = MAIL.letters, nextID = MAIL.nextID}))
end

function MAIL.Load()
	local data = util.JSONToTable(file.Read(dataPath, "DATA") or "") or {}

	MAIL.letters = istable(data.letters) and data.letters or {}
	MAIL.nextID = tonumber(data.nextID) or 1
end

function MAIL.Get(id)
	for _, letter in ipairs(MAIL.letters) do
		if (letter.id == id) then
			return letter
		end
	end
end

local function NotifyAdministration(key, ...)
	for _, client in ipairs(player.GetAll()) do
		if (NETWORK.classes.IsAdministrative(client)) then
			NETWORK.notice.Send(client, key, "info", ...)
		end
	end
end

function MAIL.Create(client, subject, text, kind, extra)
	local character = client:GetCharacter()

	if (!character) then
		return false
	end

	local letter = {
		id = MAIL.nextID,
		kind = kind or "letter",
		from = character:GetName(),
		fromChar = character:GetID(),
		cid = NETWORK.terminal.GetCitizenID(character),
		subject = subject,
		text = text,
		time = os.time(),
		bRead = false
	}

	if (extra) then
		table.Merge(letter, extra)
	end

	MAIL.nextID = MAIL.nextID + 1

	table.insert(MAIL.letters, 1, letter)

	while (#MAIL.letters > MAIL.keep) do
		table.remove(MAIL.letters)
	end

	MAIL.Save()

	NotifyAdministration("mailNewLetter", letter.from)

	return true, letter
end

local STATUS_TEXT = {
	pending = "ожидает сборки на складе ГСР",
	assigned = "собран, рабочий ГСР несёт на точку приёма",
	transit = "везёт транспорт Альянса",
	delivered = "доставлен на точку приёма",
	opened = "получен и вскрыт",
	lost = "утерян в пути",
	cancelled = "заказ отменён"
}

function MAIL.SupplyWaybill(order, client)
	local entry = NETWORK.supply.GetEntry(order.entry)

	if (!entry) then
		return
	end

	local letter

	for _, existing in ipairs(MAIL.letters) do
		if (existing.kind == "supply" and existing.orderID == order.id) then
			letter = existing

			break
		end
	end

	local name = L(entry.name)
	local text = string.format(
		"НАКЛАДНАЯ №%03d\n\nНаименование: %s\nСтоимость: %d очков фонда\nЗаказчик: %s\n" ..
		"Исполнитель: %s\nСостояние: %s",
		order.id, name, entry.cost or 0, order.by or "?", order.workerName or "—",
		STATUS_TEXT[order.status] or order.status)

	if (letter) then
		letter.text = text
		letter.status = order.status
		letter.worker = order.workerName
		letter.bRead = false

		MAIL.Save()

		return
	end

	letter = {
		id = MAIL.nextID,
		kind = "supply",
		orderID = order.id,
		from = "Склад ГСР · снабжение",
		fromChar = 0,
		cid = "00000",
		subject = string.format("Накладная №%03d — %s", order.id, name),
		text = text,
		status = order.status,
		time = os.time(),
		bRead = false
	}

	MAIL.nextID = MAIL.nextID + 1

	table.insert(MAIL.letters, 1, letter)

	while (#MAIL.letters > MAIL.keep) do
		table.remove(MAIL.letters)
	end

	MAIL.Save()

	NotifyAdministration("mailNewWaybill", name)
end

function MAIL.Send(client, subject, text)
	if ((client.nwNextMail or 0) > CurTime()) then
		return false, "mailCooldown"
	end

	subject = NETWORK.util.Sanitise(subject or "", MAIL.subjectMax)
	text = NETWORK.util.Sanitise(text or "", MAIL.textMax, true)

	if (subject == "" or text == "") then
		return false, "mailEmpty"
	end

	client.nwNextMail = CurTime() + MAIL.cooldown

	MAIL.Create(client, subject, text, "letter")

	return true, "mailSent"
end

function MAIL.Reply(admin, id, text)
	local letter = MAIL.Get(id)

	text = NETWORK.util.Sanitise(text or "", MAIL.textMax, true)

	if (!letter or text == "") then
		return false, "mailEmpty"
	end

	letter.reply = {author = admin:GetCharacterName(), text = text, time = os.time()}
	letter.bRead = true

	MAIL.Save()

	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (character and character:GetID() == letter.fromChar) then
			NETWORK.notice.Send(client, "mailReplied", "good")
		end
	end

	return true, "mailReplySent"
end

function MAIL.GetFor(character, limit)
	local list = {}

	for _, letter in ipairs(MAIL.letters) do
		if (letter.fromChar == character:GetID() and letter.kind == "letter") then
			list[#list + 1] = {
				subject = letter.subject,
				text = letter.text,
				time = os.date("%d.%m %H:%M", letter.time),
				reply = letter.reply and {
					author = letter.reply.author,
					text = letter.reply.text,
					time = os.date("%d.%m %H:%M", letter.reply.time)
				} or nil
			}

			if (#list >= (limit or 6)) then
				break
			end
		end
	end

	return list
end

hook.Add("Initialize", "nwMail", function()
	MAIL.Load()

	local baseApply = NETWORK.business.Apply

	NETWORK.business.Apply = function(client, character, what, why)
		baseApply(client, character, what, why)

		MAIL.Create(client, "Заявка на бизнес: " .. string.sub(what, 1, 40), why, "business",
			{businessID = tostring(character:GetID()), what = what})
	end

	local actions = NETWORK.terminal.actions

	if (actions) then
		actions.mail_send = function(client, entity, payload)
			local _, key = MAIL.Send(client, payload.subject, payload.text)

			return key
		end
	end
end)

hook.Add("NetworkTerminalData", "nwMail", function(client, data)
	local character = client:GetCharacter()

	data.mail = character and MAIL.GetFor(character) or {}
end)
