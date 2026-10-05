NETWORK.meddb = NETWORK.meddb or {}

local M = NETWORK.meddb

M.maxDiagnosis = 400
M.recordsPerPage = 40

function M.CanUse(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	if (client:GetNWString("nwClass", "") == "medic") then
		return true
	end

	return NETWORK.factions.IsAlliance(client)
end

if (CLIENT) then
	return
end

util.AddNetworkString("nwMedComputer")
util.AddNetworkString("nwMedComputerList")
util.AddNetworkString("nwMedComputerAdd")
util.AddNetworkString("nwMedComputerDoc")
util.AddNetworkString("nwMedComputerLetter")

local TABLE = "nw_medical"

sql.Query([[
	CREATE TABLE IF NOT EXISTS ]] .. TABLE .. [[ (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		patient TEXT NOT NULL,
		name TEXT NOT NULL,
		diagnosis TEXT NOT NULL,
		doctor TEXT NOT NULL,
		time INTEGER NOT NULL
	)
]])

function M.Add(patientKey, name, diagnosis, doctor)
	sql.Query(string.format(
		"INSERT INTO %s (patient, name, diagnosis, doctor, time) VALUES (%s, %s, %s, %s, %d)",
		TABLE, sql.SQLStr(patientKey), sql.SQLStr(name), sql.SQLStr(diagnosis),
		sql.SQLStr(doctor), os.time()))
end

function M.Find(query, limit)
	query = string.Trim(query or "")

	local where = query != "" and ("WHERE patient LIKE " .. sql.SQLStr("%" .. query .. "%") ..
		" OR name LIKE " .. sql.SQLStr("%" .. query .. "%")) or ""

	local rows = sql.Query(string.format(
		"SELECT * FROM %s %s ORDER BY time DESC LIMIT %d", TABLE, where,
		limit or M.recordsPerPage))

	return istable(rows) and rows or {}
end

local function Send(client, rows)
	net.Start("nwMedComputerList")
		NETWORK.util.WriteTable(rows)
	net.Send(client)
end

net.Receive("nwMedComputer", function(_, client)
	if (!M.CanUse(client)) then
		return
	end

	Send(client, M.Find(net.ReadString(), M.recordsPerPage))
end)

local function PatientKey(target)
	local character = target:GetCharacter()
	local cid = character and character.GetData and character:GetData("cid")

	return cid and tostring(cid) or target:GetCharacterName()
end

net.Receive("nwMedComputerAdd", function(_, client)
	if (!M.CanUse(client)) then
		return
	end

	local name = string.sub(net.ReadString(), 1, 64)
	local diagnosis = string.sub(net.ReadString(), 1, M.maxDiagnosis)

	if (string.Trim(name) == "" or string.Trim(diagnosis) == "") then
		return
	end

	local key = name

	for _, target in ipairs(player.GetAll()) do
		if (target:HasCharacter() and
			NETWORK.util.Lower(target:GetCharacterName()) == NETWORK.util.Lower(name)) then
			key = PatientKey(target)

			break
		end
	end

	M.Add(key, name, diagnosis, client:GetCharacterName())

	NETWORK.journal.AddTo(client, "work", L("medJournalWrote", name))
	NETWORK.notice.Send(client, "medRecordAdded", "good", name)

	Send(client, M.Find("", M.recordsPerPage))
end)

net.Receive("nwMedComputerDoc", function(_, client)
	if (!M.CanUse(client)) then
		return
	end

	local holder = string.sub(net.ReadString(), 1, 64)
	local text = string.sub(net.ReadString(), 1, 300)

	if (string.Trim(holder) == "") then
		return
	end

	if (NETWORK.documents and NETWORK.documents.Issue) then
		NETWORK.documents.Issue(client, "medical", {
			holder = holder,
			body = text,
			issuer = client:GetCharacterName()
		})
	end

	NETWORK.notice.Send(client, "medDocIssued", "good", holder)
end)

util.AddNetworkString("nwMedComputerCall")

M.callCooldown = 45
M.nextCall = M.nextCall or 0

net.Receive("nwMedComputerCall", function(_, client)
	if (!M.CanUse(client)) then
		return
	end

	if (M.nextCall > CurTime()) then
		return NETWORK.notice.Send(client, "acCallCooldown", "warn")
	end

	M.nextCall = CurTime() + M.callCooldown

	local reason = NETWORK.util.Sanitise(net.ReadString(), 120)

	if (reason == "") then
		reason = L("medCallDefault")
	end

	local zone = NETWORK.zone and NETWORK.zone.AtEntity and NETWORK.zone.AtEntity(client)
	local place = zone and zone.name != "" and zone.name or L("acCallPlaceDefault")
	local count = 0

	for _, other in ipairs(player.GetAll()) do
		if (!other:HasCharacter() or !NETWORK.factions.IsAlliance(other)) then
			continue
		end

		net.Start("nwChatMessage")
			net.WriteString("center")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(L("medCallAlert", client:GetCharacterName(), place, reason))
		net.Send(other)

		other:EmitSound("npc/overwatch/radiovoice/on1.wav", 60, 100)

		if (NETWORK.waypoint and NETWORK.waypoint.Add) then
			NETWORK.waypoint.Add(other, client:GetPos() + Vector(0, 0, 32),
				L("callWaypoint", reason), Color(86, 150, 226), 600, true, "call")
		end

		count = count + 1
	end

	NETWORK.notice.Send(client, "medCallSent", "good", count)
end)

net.Receive("nwMedComputerLetter", function(_, client)
	if (!M.CanUse(client)) then
		return
	end

	local to = string.sub(net.ReadString(), 1, 64)
	local subject = string.sub(net.ReadString(), 1, 80)
	local body = string.sub(net.ReadString(), 1, 600)

	if (NETWORK.mail and NETWORK.mail.SendTo) then
		local bOk = NETWORK.mail.SendTo(client:GetCharacterName(), to, subject, body)

		NETWORK.notice.Send(client, bOk and "mailBoxSent" or "mailNoBox",
			bOk and "good" or "warn", to)
	end
end)
