NETWORK.mail = NETWORK.mail or {}

local MAIL = NETWORK.mail

MAIL.maxLetters = 30

if (CLIENT) then
	return
end

util.AddNetworkString("nwMailOpen")
util.AddNetworkString("nwMailList")
util.AddNetworkString("nwMailDelete")

local TABLE = "nw_mail"

sql.Query([[
	CREATE TABLE IF NOT EXISTS ]] .. TABLE .. [[ (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		recipient TEXT NOT NULL,
		sender TEXT NOT NULL,
		subject TEXT NOT NULL,
		body TEXT NOT NULL,
		time INTEGER NOT NULL,
		read INTEGER NOT NULL DEFAULT 0
	)
]])

local function Lower(text)
	return NETWORK.util.Lower(string.Trim(text or ""))
end

function MAIL.FindBox(recipient)
	local key = Lower(recipient)

	for _, box in ipairs(ents.FindByClass("nw_mailbox")) do
		if (Lower(box:GetOwnerName()) == key) then
			return box
		end
	end
end

function MAIL.SendTo(sender, recipient, subject, body)
	local box = MAIL.FindBox(recipient)

	if (!IsValid(box)) then
		return false
	end

	sql.Query(string.format(
		"INSERT INTO %s (recipient, sender, subject, body, time) VALUES (%s, %s, %s, %s, %d)",
		TABLE, sql.SQLStr(Lower(recipient)), sql.SQLStr(sender), sql.SQLStr(subject),
		sql.SQLStr(body), os.time()))

	box:SetHasMail(true)
	box:EmitSound("buttons/button3.wav", 60, 110)

	for _, client in ipairs(player.GetAll()) do
		if (client:HasCharacter() and Lower(client:GetCharacterName()) == Lower(recipient)) then
			NETWORK.notice.Send(client, "mailArrived", "good")
			NETWORK.journal.AddTo(client, "note", L("mailJournal", sender))
		end
	end

	return true
end

function MAIL.List(recipient)
	local rows = sql.Query(string.format(
		"SELECT * FROM %s WHERE recipient = %s ORDER BY time DESC LIMIT %d",
		TABLE, sql.SQLStr(Lower(recipient)), MAIL.maxLetters))

	return istable(rows) and rows or {}
end

function MAIL.Count(recipient)
	local row = sql.QueryValue(string.format(
		"SELECT COUNT(*) FROM %s WHERE recipient = %s", TABLE,
		sql.SQLStr(Lower(recipient))))

	return tonumber(row) or 0
end

function MAIL.Open(client, box)
	if (!IsValid(box) or !client:HasCharacter()) then
		return
	end

	local bOwner = Lower(client:GetCharacterName()) == Lower(box:GetOwnerName())

	if (!bOwner and !NETWORK.factions.IsAlliance(client)) then
		box:EmitSound("buttons/combine_button_locked.wav", 60, 70)

		return NETWORK.notice.Send(client, "mailNotYours", "warn")
	end

	local list = MAIL.List(box:GetOwnerName())

	net.Start("nwMailList")
		net.WriteEntity(box)
		NETWORK.util.WriteTable(list)
	net.Send(client)

	box:SetHasMail(false)
end

net.Receive("nwMailDelete", function(_, client)
	local id = net.ReadUInt(32)
	local box = net.ReadEntity()

	if (!IsValid(box) or !client:HasCharacter()) then
		return
	end

	if (Lower(client:GetCharacterName()) != Lower(box:GetOwnerName()) and
		!NETWORK.factions.IsAlliance(client)) then
		return
	end

	sql.Query(string.format("DELETE FROM %s WHERE id = %d AND recipient = %s",
		TABLE, id, sql.SQLStr(Lower(box:GetOwnerName()))))

	MAIL.Open(client, box)
end)

function MAIL.Bind(client, box)
	if (!IsValid(box) or !client:HasCharacter() or box:GetOwnerName() != "") then
		return false
	end

	box:SetOwnerName(client:GetCharacterName())
	box:EmitSound("buttons/button3.wav", 60, 120)

	NETWORK.entities.Save()
	NETWORK.notice.Send(client, "mailBound", "good", client:GetCharacterName())

	return true
end

NETWORK.command.Register("mailboxreset", {
	adminOnly = true,
	description = "cmdMailboxReset",
	usage = "/mailboxreset [имя]",
	OnRun = function(command, client, arguments)
		local box = client:GetEyeTrace().Entity

		if (!IsValid(box) or box:GetClass() != "nw_mailbox" or
			client:GetPos():Distance(box:GetPos()) > 200) then
			return NETWORK.notice.Send(client, "mailResetLook", "warn")
		end

		local name = string.Trim(table.concat(arguments, " "))

		box:SetOwnerName(string.sub(name, 1, 64))
		box:SetHasMail(false)

		NETWORK.entities.Save()
		NETWORK.notice.Send(client, name == "" and "mailResetFree" or "mailResetTo", "good", name)
	end
})

hook.Add("NetworkPlayerLoadout", "nwMailRemind", function(client)
	timer.Simple(6, function()
		if (!IsValid(client) or !client:HasCharacter()) then
			return
		end

		local box = MAIL.FindBox(client:GetCharacterName())

		if (IsValid(box) and MAIL.Count(client:GetCharacterName()) > 0) then
			NETWORK.notice.Send(client, "mailWaiting", "good")
		end
	end)
end)
