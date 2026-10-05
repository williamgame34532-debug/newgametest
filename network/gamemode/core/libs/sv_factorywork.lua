local WORK = NETWORK.factorywork

local dataPath = "network/factorywork.txt"

WORK.records = WORK.records or {}

local function Notice(client, key, tone, ...)
	NETWORK.notice.Send(client, key, tone or "info", ...)
end

function WORK.NormaliseRecords(data)
	local records = {}

	for key, record in pairs(istable(data) and data or {}) do
		if (!istable(record)) then
			continue
		end

		key = tostring(key)

		local existing = records[key]

		if (!existing or (tonumber(record.updated) or 0) >= (tonumber(existing.updated) or 0)) then
			records[key] = record
		end
	end

	return records
end

function WORK.Load()
	local raw = file.Read(dataPath, "DATA")
	local data = raw and util.JSONToTable(raw)

	WORK.records = WORK.NormaliseRecords(data)
end

function WORK.WriteNow()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(WORK.records, true))
end

function WORK.Save()
	if (timer.Exists("nwFactoryWorkSave")) then
		return
	end

	timer.Create("nwFactoryWorkSave", 2, 1, WORK.WriteNow)
end

hook.Add("Initialize", "nwFactoryWork", function()
	WORK.Load()
end)

hook.Add("ShutDown", "nwFactoryWork", function()
	timer.Remove("nwFactoryWorkSave")

	WORK.WriteNow()
end)

util.AddNetworkString("nwFactoryProgress")

function NETWORK.FactoryProgress(client, label, duration)
	if (!IsValid(client) or !client:IsPlayer()) then
		return
	end

	net.Start("nwFactoryProgress")
		net.WriteString(label or "")
		net.WriteFloat(tonumber(duration) or 0)
	net.Send(client)
end

local function Key(client)
	return client:HasCharacter() and tostring(client:GetCharacterID()) or nil
end

local function FindByKey(key)
	for _, target in ipairs(player.GetAll()) do
		if (target:HasCharacter() and tostring(target:GetCharacterID()) == key) then
			return target
		end
	end
end

function WORK.Get(client, bCreate)
	local key = Key(client)

	if (!key) then
		return
	end

	local record = WORK.records[key]

	if (!record and bCreate) then
		record = {
			shiftMade = 0,
			shiftDelivered = 0,
			box = 0,
			quotas = 0,
			done = false,
			made = 0,
			delivered = 0,
			shifts = 0,
			shiftEarned = 0,
			earned = 0,
			shiftPoints = 0
		}

		WORK.records[key] = record
	end

	if (record) then
		local character = client:GetCharacter()

		record.name = client:GetCharacterName()
		record.cid = NETWORK.terminal and NETWORK.terminal.GetCitizenID and
			NETWORK.terminal.GetCitizenID(character) or ""
	end

	return record
end

function WORK.RefreshViewers()
	if (!NETWORK.cmbterm or !NETWORK.cmbterm.Refresh) then
		return
	end

	for _, viewer in ipairs(player.GetAll()) do
		if (viewer.nwCmbPage == "factory" and IsValid(viewer.nwCmbTerminal)) then
			NETWORK.cmbterm.Refresh(viewer)
		end
	end
end

function WORK.Push(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	local record = WORK.Get(client, WORK.IsWorker(client)) or {}

	client:SetNWInt("nwWorkShiftMade", record.shiftMade or 0)
	client:SetNWInt("nwWorkShiftDelivered", record.shiftDelivered or 0)
	client:SetNWInt("nwWorkBox", record.box or 0)
	client:SetNWInt("nwWorkQuotas", record.quotas or 0)
	client:SetNWBool("nwWorkDone", record.done == true)
	client:SetNWInt("nwWorkMade", record.made or 0)
	client:SetNWInt("nwWorkDelivered", record.delivered or 0)
	client:SetNWInt("nwWorkShifts", record.shifts or 0)
	client:SetNWInt("nwWorkEarned", record.shiftEarned or 0)
	client:SetNWInt("nwWorkPoints", record.shiftPoints or 0)

	if (IsValid(client.nwTerminal) and NETWORK.terminal.Sync) then
		NETWORK.terminal.Sync(client)
	end
end

local function Changed(client, record)
	record.updated = os.time()

	WORK.Save()
	WORK.Push(client)
	WORK.RefreshViewers()
end

function WORK.CanAssemble(client)
	if (!WORK.IsWorker(client)) then
		return true
	end

	local record = WORK.Get(client, true)

	return !record.done
end

function WORK.CreditMade(crew)
	for _, entry in ipairs(istable(crew) and crew or {}) do
		local target = FindByKey(entry.id)

		if (!WORK.IsWorker(target)) then
			continue
		end

		local record = WORK.Get(target, true)

		if (record.done) then
			continue
		end

		record.shiftMade = record.shiftMade + 1
		record.made = record.made + 1

		Changed(target, record)
	end
end

function WORK.CreditDelivered(client, amount)
	if (!WORK.IsWorker(client)) then
		return
	end

	local record = WORK.Get(client, true)

	amount = math.max(math.floor(amount or 1), 1)

	record.delivered = record.delivered + amount

	if (record.done) then
		Notice(client, "workShiftAlreadyDoneV2", "warn")

		return Changed(client, record)
	end

	for _ = 1, amount do
		record.shiftDelivered = record.shiftDelivered + 1
		record.box = record.box + 1

		if (record.box < WORK.boxSize) then
			continue
		end

		record.box = 0
		record.quotas = record.quotas + 1

		local economy = NETWORK.economy
		local pointsBefore = economy and economy.Points and economy.Points(client) or 0

		hook.Run("NetworkFactoryQuota", client, record)

		local pointsAfter = economy and economy.Points and economy.Points(client) or 0

		record.shiftPoints = (record.shiftPoints or 0) + math.max(pointsAfter - pointsBefore, 0)

		if (record.quotas >= WORK.quotas) then
			record.quotas = WORK.quotas
			record.done = true
			record.shifts = record.shifts + 1

			client:EmitSound("buttons/combine_button7.wav", 60)
			Notice(client, "workShiftDone", "good")

			WORK.EndShift(client)

			if (NETWORK.log and NETWORK.log.Add) then
				NETWORK.log.Add("item", string.format("%s закрыл смену на заводе",
					NETWORK.log.Name(client)), client:GetPos())
			end

			break
		end

		client:EmitSound("buttons/button14.wav", 55)
		Notice(client, "workQuotaDone", "good", record.quotas, WORK.quotas)
	end

	if (!record.done and record.box > 0) then
		Notice(client, "workBoxProgress", "info", record.box, WORK.boxSize)
	end

	Changed(client, record)
end

function WORK.EndShift(client)
	if (!IsValid(client)) then
		return
	end

	timer.Simple(2, function()
		if (!IsValid(client) or !client:HasCharacter()) then
			return
		end

		if (!WORK.IsWorker(client)) then
			return
		end

		if (NETWORK.recruiter and NETWORK.recruiter.Revert) then
			NETWORK.recruiter.Revert(client, "workShiftFired")
		end

		WORK.Push(client)
		WORK.RefreshViewers()
	end)
end

function WORK.ResetShift(client)
	if (!WORK.IsWorker(client)) then
		return false
	end

	local record = WORK.Get(client, true)

	record.done = false
	record.box = 0
	record.quotas = 0
	record.shiftMade = 0
	record.shiftDelivered = 0
	record.shiftEarned = 0
	record.shiftPoints = 0

	Changed(client, record)

	return true
end

function WORK.Restart(client)
	if (!WORK.IsWorker(client)) then
		return false, "workNotWorker"
	end

	local record = WORK.Get(client, true)

	if (!record.done) then
		return false, "workShiftNotDone"
	end

	record.done = false
	record.box = 0
	record.quotas = 0
	record.shiftMade = 0
	record.shiftDelivered = 0
	record.shiftEarned = 0
	record.shiftPoints = 0

	Changed(client, record)

	return true, "workShiftRestarted"
end

function WORK.CreditEarned(client, amount)
	if (!WORK.IsWorker(client)) then
		return
	end

	amount = math.floor(tonumber(amount) or 0)

	if (amount <= 0) then
		return
	end

	local record = WORK.Get(client, true)

	record.shiftEarned = (record.shiftEarned or 0) + amount
	record.earned = (record.earned or 0) + amount

	Changed(client, record)
end

hook.Add("NetworkRationPaid", "nwFactoryWork", function(client, amount)
	WORK.CreditEarned(client, amount)
end)

local function PushLater(client)
	timer.Simple(0.6, function()
		if (IsValid(client)) then
			WORK.Push(client)
		end
	end)
end

hook.Add("NetworkCharacterLoaded", "nwFactoryWorkFire", function(client)
	timer.Simple(1.2, function()
		if (!IsValid(client) or !WORK.IsWorker(client)) then
			return
		end

		local record = WORK.Get(client)

		if (record and record.done) then
			WORK.EndShift(client)
		end
	end)
end)

hook.Add("NetworkCharacterLoaded", "nwFactoryWork", PushLater)
hook.Add("PlayerSpawn", "nwFactoryWork", PushLater)

hook.Add("NetworkTerminalData", "nwFactoryWork", function(client, data)
	local entity = client.nwTerminal

	if (!IsValid(entity) or entity:GetClass() != "nw_workterminal") then
		return
	end

	local record = WORK.Get(client, WORK.IsWorker(client)) or {}

	data.work = {
		bWorker = WORK.IsWorker(client),
		shiftMade = record.shiftMade or 0,
		shiftDelivered = record.shiftDelivered or 0,
		box = record.box or 0,
		quotas = record.quotas or 0,
		bDone = record.done == true,
		made = record.made or 0,
		delivered = record.delivered or 0,
		shifts = record.shifts or 0,
		shiftEarned = record.shiftEarned or 0,
		earned = record.earned or 0,
		shiftPoints = record.shiftPoints or 0,
		bOpen = !NETWORK.schedule or !NETWORK.schedule.IsFactoryShift or
			NETWORK.schedule.IsFactoryShift()
	}
end)

if (NETWORK.terminal.actions) then
	NETWORK.terminal.actions.work_restart = function(client, entity)
		if (!IsValid(entity) or entity:GetClass() != "nw_workterminal") then
			return
		end

		local bOk, key = WORK.Restart(client)

		if (bOk) then
			entity:EmitSound(NETWORK.terminal.sounds.select, 65)
		end

		return key
	end
end

function WORK.CanView(client, kind)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	if (kind == "alliance") then
		return NETWORK.factions.IsAlliance(client)
	end

	if (kind == "cwu") then
		return NETWORK.factions.IsCWU(client) or NETWORK.factions.IsAlliance(client) or
			client:IsAdmin()
	end

	return false
end

WORK.listLimit = 24

function WORK.BuildList()
	local online = {}

	for _, target in ipairs(player.GetAll()) do
		local key = Key(target)

		if (key) then
			online[key] = target
		end
	end

	local list = {}

	for key, record in pairs(WORK.records) do
		local target = online[key]

		if (IsValid(target)) then
			WORK.Get(target)
		end

		list[#list + 1] = {
			id = key,
			name = record.name or "?",
			cid = record.cid or "",
			bOnline = IsValid(target),
			bWorker = WORK.IsWorker(target),
			shiftMade = record.shiftMade or 0,
			shiftDelivered = record.shiftDelivered or 0,
			box = record.box or 0,
			quotas = record.quotas or 0,
			bDone = record.done == true,
			made = record.made or 0,
			delivered = record.delivered or 0,
			shifts = record.shifts or 0,
			shiftEarned = record.shiftEarned or 0,
			earned = record.earned or 0,
			updated = record.updated or 0
		}
	end

	table.sort(list, function(a, b)
		local aActive = a.bOnline and a.bWorker
		local bActive = b.bOnline and b.bWorker

		if (aActive != bActive) then
			return aActive
		end

		if (a.updated != b.updated) then
			return a.updated > b.updated
		end

		return a.name < b.name
	end)

	local summary = {working = 0, closed = 0, made = 0, delivered = 0, quotas = 0}

	for _, entry in ipairs(list) do
		if (!(entry.bOnline and entry.bWorker)) then
			continue
		end

		if (entry.bDone) then
			summary.closed = summary.closed + 1
		else
			summary.working = summary.working + 1
		end

		summary.made = summary.made + entry.shiftMade
		summary.delivered = summary.delivered + entry.shiftDelivered
		summary.quotas = summary.quotas + entry.quotas
	end

	local total = #list

	while (#list > WORK.listLimit) do
		table.remove(list)
	end

	return list, summary, total
end

hook.Add("NetworkCmbPayload", "nwFactoryWork", function(client, page, argument, payload)
	if (page != "factory") then
		return
	end

	local kind = NETWORK.cmbterm.GetKind(client)

	if (!WORK.CanView(client, kind)) then
		return
	end

	local list, summary, total = WORK.BuildList()

	payload.kind = kind
	payload.list = list
	payload.summary = summary
	payload.total = total
	payload.bOpen = !NETWORK.schedule or !NETWORK.schedule.IsFactoryShift or
		NETWORK.schedule.IsFactoryShift()
end)

hook.Add("NetworkCmbAction", "nwFactoryWork", function(client, action, argument, extra, entity)
	if (action != "factory") then
		return
	end

	if (WORK.CanView(client, NETWORK.cmbterm.GetKind(client))) then
		NETWORK.cmbterm.OpenPage(client, "factory", "")
	end

	return true
end)
