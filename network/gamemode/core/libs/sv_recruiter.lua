util.AddNetworkString("nwRecruiterSync")
util.AddNetworkString("nwRecruiterOpen")
util.AddNetworkString("nwRecruiterPick")
util.AddNetworkString("nwRecruiterSave")
util.AddNetworkString("nwRecruiterEditor")

local dataPath = "network/recruiters.txt"

local previousPath = "network/recruiter_previous.txt"

NETWORK.recruiter.previous = NETWORK.recruiter.previous or {}

function NETWORK.recruiter.SavePrevious()
	timer.Create("nwRecruiterPrevSave", 2, 1, function()
		file.CreateDir("network")
		file.Write(previousPath, util.TableToJSON(NETWORK.recruiter.previous, true))
	end)
end

function NETWORK.recruiter.LoadPrevious()
	local raw = file.Read(previousPath, "DATA")
	local data = raw and util.JSONToTable(raw)

	NETWORK.recruiter.previous = istable(data) and data or {}
end

function NETWORK.recruiter.SaveAll()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(NETWORK.recruiter.configs, true))
end

function NETWORK.recruiter.LoadAll()
	local contents = file.Read(dataPath, "DATA")

	if (!contents) then
		return
	end

	local data = util.JSONToTable(contents)

	if (!istable(data)) then
		return
	end

	NETWORK.recruiter.configs = {}

	for id, config in pairs(data) do
		NETWORK.recruiter.configs[id] = NETWORK.recruiter.Clean(config)
	end
end

function NETWORK.recruiter.Broadcast(target)
	net.Start("nwRecruiterSync")
		NETWORK.util.WriteTable(NETWORK.recruiter.configs)

	if (IsValid(target)) then
		net.Send(target)
	else
		net.Broadcast()
	end
end

local function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

function NETWORK.recruiter.Open(client, entity)
	local config = NETWORK.recruiter.Get(entity:GetConfigID())

	if (!config or #config.entries == 0) then
		Notice(client, "recruiterEmpty")

		if (client:IsAdmin()) then
			Notice(client, "/recruiteredit " .. entity:GetConfigID())
		end

		return
	end

	client.nwRecruiter = entity

	net.Start("nwRecruiterOpen")
		net.WriteEntity(entity)
	net.Send(client)
end

net.Receive("nwRecruiterPick", function(_, client)
	local entity = client.nwRecruiter

	if (!IsValid(entity) or !client:HasCharacter() or
		client:GetPos():Distance(entity:GetPos()) > NETWORK.recruiter.range) then
		client.nwRecruiter = nil

		return
	end

	local key = net.ReadString()
	local spawnIndex = net.ReadUInt(8)
	local config = NETWORK.recruiter.Get(entity:GetConfigID())
	local entry = NETWORK.recruiter.GetEntry(config, key)

	if (!entry) then
		return
	end

	local faction = entry.faction

	local factionTable = NETWORK.factions.Get(faction)

	if (!factionTable or !NETWORK.factions.CanUse(client, faction)) then
		return Notice(client, "recruiterNoAccess")
	end

	if (NETWORK.recruiter.IsFull(entry)) then
		return Notice(client, "recruiterFull")
	end

	local spawn = entry.spawns[spawnIndex]

	if (#entry.spawns > 0 and !spawn) then
		return Notice(client, "recruiterNoSpawn")
	end

	local character = client:GetCharacter()
	local fields = NETWORK.factions.Transfer(client, character, factionTable) or {}

	NETWORK.recruiter.previous = NETWORK.recruiter.previous or {}

	local previousKey = tostring(character:GetID())
	local previousRecord = NETWORK.recruiter.previous[previousKey]

	if (!previousRecord) then
		previousRecord = {
			faction = character:GetFaction(),
			model = character:GetModel(),
			uniforms = {}
		}

		NETWORK.recruiter.previous[previousKey] = previousRecord
	end

	previousRecord.uniforms = previousRecord.uniforms or {}

	if (entry.uniform != "" and
		!table.HasValue(previousRecord.uniforms, entry.uniform)) then
		previousRecord.uniforms[#previousRecord.uniforms + 1] = entry.uniform
	end

	NETWORK.recruiter.SavePrevious()

	fields.faction = faction

	local entryModels = NETWORK.recruiter.ModelList(entry)

	if (#entryModels == 0 and fields.model and fields.model != "") then

	else
		fields.model = NETWORK.recruiter.PickModel(entry, factionTable,
			character:GetModel()) or fields.model or character:GetModel()
	end

	fields.modelforced = 0

	NETWORK.character.Update(character, fields)
	NETWORK.character.Refresh(client)

	if (NETWORK.classes) then
		local key = tostring(character:GetID())
		local classTable = entry.class != "" and
			NETWORK.classes.Get(entry.class)

		NETWORK.classes.assigned = NETWORK.classes.assigned or {}

		if (classTable and classTable.faction == faction) then
			local record = {id = classTable.id}

			if (classTable.callsign) then
				record.callsign = string.format(classTable.callsign,
					math.random(0, 9999))
			end

			NETWORK.classes.assigned[key] = record

			client:SetNWString("nwCallsign", record.callsign or "")
		else
			NETWORK.classes.assigned[key] = nil

			client:SetNWString("nwClass", "")
			client:SetNWString("nwCallsign", "")
		end

		NETWORK.classes.SaveAll()
	end

	client:Spawn()

	if (spawn) then
		client:SetPos(Vector(spawn.pos[1], spawn.pos[2], spawn.pos[3]))
		client:SetEyeAngles(Angle(0, spawn.yaw, 0))
	end

	timer.Simple(0.1, function()
		if (!IsValid(client)) then
			return
		end

		NETWORK.anim.Refresh(client)
		NETWORK.inventory.RefreshAppearance(client)
		NETWORK.character.Refresh(client)

		if (NETWORK.classes and NETWORK.classes.Apply) then
			NETWORK.classes.Apply(client, character)
		end

		if (entry.uniform != "") then
			NETWORK.recruiter.GiveUniform(client, entry.uniform)
		end

		if (NETWORK.factorywork and NETWORK.factorywork.ResetShift) then
			NETWORK.factorywork.ResetShift(client)
		end
	end)

	client.nwRecruiter = nil

	Notice(client, "recruiterJoined")
end)

net.Receive("nwRecruiterSave", function(_, client)
	if (!client:IsAdmin()) then
		return Notice(client, "errNoAccess")
	end

	local id = string.gsub(string.lower(NETWORK.util.Sanitise(net.ReadString(), 32)),
		"[^%w_]", "")
	local payload = NETWORK.util.ReadTable()

	if (id == "" or !istable(payload)) then
		return Notice(client, "editorNoID")
	end

	if (payload.bDelete) then
		NETWORK.recruiter.configs[id] = nil
	else
		NETWORK.recruiter.configs[id] = NETWORK.recruiter.Clean(payload)
	end

	NETWORK.recruiter.SaveAll()
	NETWORK.recruiter.Broadcast()

	Notice(client, "editorServerSaved")
end)

function NETWORK.recruiter.GiveUniform(client, id)
	local base = NETWORK.item.Get(id)

	if (!base or !client:HasCharacter()) then
		return
	end

	local state = NETWORK.inventory.GetState(client)
	local slot = base.equipSlot
	local item = NETWORK.item.New(id, 1)

	item.data.uniform = true

	NETWORK.item.OnCreated(item, client, client:GetCharacter())

	if (slot) then
		local worn = state.equipped[slot]

		if (worn) then
			if (NETWORK.inventory.Insert(state, worn) > 0) then
				NETWORK.item.Spawn(worn.id, client:GetPos() + Vector(0, 0, 8), nil,
					worn.amount, worn.data)
			end
		end

		state.equipped[slot] = item
	elseif (NETWORK.inventory.Insert(state, item) > 0) then
		NETWORK.item.Spawn(id, client:GetPos() + Vector(0, 0, 8))
	end

	NETWORK.inventory.Sync(client)
	Notice(client, "recruiterUniformGiven")
end

function NETWORK.recruiter.TakeUniform(client, id)
	local state = NETWORK.inventory.GetState(client)
	local bChanged = false

	for slot, item in pairs(state.equipped) do
		if (istable(item) and item.id == id and item.data and item.data.uniform) then
			state.equipped[slot] = nil
			bChanged = true
		end
	end

	for _, list in ipairs({"items", "storage"}) do
		for index, item in pairs(state[list] or {}) do
			if (istable(item) and item.id == id and item.data and item.data.uniform) then
				state[list][index] = nil
				bChanged = true
			end
		end
	end

	if (bChanged) then
		NETWORK.inventory.Sync(client)
		Notice(client, "recruiterUniformTaken")
	end
end

hook.Add("PlayerInitialSpawn", "nwRecruiter", function(client)
	timer.Simple(1.6, function()
		if (IsValid(client)) then
			NETWORK.recruiter.Broadcast(client)
		end
	end)
end)

hook.Add("Initialize", "nwRecruiter", function()
	NETWORK.recruiter.LoadAll()
	NETWORK.recruiter.LoadPrevious()
end)

hook.Add("Think", "nwRecruiterRange", function()
	if (!NETWORK.util.Throttle("recruiter.range", 0.25)) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		local entity = client.nwRecruiter

		if (!entity) then
			continue
		end

		if (!IsValid(entity) or !client:Alive() or
			client:GetPos():Distance(entity:GetPos()) > NETWORK.recruiter.range) then
			client.nwRecruiter = nil
		end
	end
end)

NETWORK.command.Register("recruiteredit", {
	description = "cmdRecruiteredit",
	usage = "/recruiteredit [id]",
	adminOnly = true,
	aliases = {"recruiter"},
	OnRun = function(command, client, arguments)
		net.Start("nwRecruiterEditor")
			net.WriteString(arguments[1] or "")
			net.WriteVector(client:GetPos())
			net.WriteFloat(client:EyeAngles().y)
		net.Send(client)
	end
})

util.AddNetworkString("nwRecruitLeave")

function NETWORK.recruiter.Revert(client, reason)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	local character = client:GetCharacter()
	local charID = tostring(character:GetID())
	local previous = (NETWORK.recruiter.previous or {})[charID]
	local bHadClass = ((NETWORK.classes or {}).assigned or {})[charID] != nil

	if (!previous and !bHadClass) then
		return false, "recruiterNoPrev"
	end

	if (bHadClass) then
		NETWORK.classes.assigned[charID] = nil

		client:SetNWString("nwClass", "")
		client:SetNWString("nwCallsign", "")

		NETWORK.classes.SaveAll()
	end

	if (previous) then
		NETWORK.character.Update(character, {
			faction = previous.faction or character:GetFaction(),
			model = previous.model or character:GetModel()
		})

		NETWORK.recruiter.previous[charID] = nil
		NETWORK.recruiter.SavePrevious()

		local uniforms = istable(previous.uniforms) and previous.uniforms or {}

		if (previous.uniform) then
			uniforms[#uniforms + 1] = previous.uniform
		end

		for _, uniform in ipairs(uniforms) do
			NETWORK.recruiter.TakeUniform(client, uniform)
		end
	end

	NETWORK.character.Refresh(client)
	client:Spawn()

	timer.Simple(0.1, function()
		if (IsValid(client)) then
			NETWORK.anim.Refresh(client)
			NETWORK.inventory.RefreshAppearance(client)
			NETWORK.character.Refresh(client)
		end
	end)

	if (reason) then
		Notice(client, reason)
	end

	return true
end

net.Receive("nwRecruitLeave", function(_, client)
	local entity = client.nwRecruiter

	if (!IsValid(entity) or !client:HasCharacter() or
		client:GetPos():Distance(entity:GetPos()) > NETWORK.recruiter.range) then
		return
	end

	local bDone, failure = NETWORK.recruiter.Revert(client, "recruiterLeft")

	if (!bDone) then
		Notice(client, failure or "recruiterNoPrev")
	end
end)
