util.AddNetworkString("nwDoorSync")

local dataPath = "network/doors.txt"

function NETWORK.door.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON(NETWORK.door.list, true))
end

function NETWORK.door.Load()
	local contents = file.Read(dataPath, "DATA")

	if (!contents) then
		return
	end

	local data = util.JSONToTable(contents)

	if (istable(data)) then
		NETWORK.door.list = data

		local cleared = 0
		local keepFurniture = {}

		for _, entry in pairs(NETWORK.door.list) do
			if (istable(entry) and entry.type == "residential" and NETWORK.door.HasOwner(entry)) then
				local purchase = NETWORK.apartments and NETWORK.apartments.IsPurchased(entry) and entry.purchase

				if (purchase) then
					-- Bought apartment: the buyer stays the owner, temporary residents are reset.
					local owners = NETWORK.door.GetOwners(entry)
					local keep = owners[purchase.steamID]

					entry.owners = keep and {[purchase.steamID] = keep} or nil
					entry.owner = keep and purchase.steamID or nil
					entry.ownerName = keep and keep.name or nil
					entry.ownerChar = keep and keep.char or nil
					entry.ownerFaction = keep and keep.faction or nil
					keepFurniture[tostring(purchase.char)] = true
				else
					entry.owner = nil
					entry.ownerName = nil
					entry.ownerChar = nil
					entry.ownerFaction = nil
					entry.owners = nil
					entry.bLocked = false

					cleared = cleared + 1
				end
			end
		end

		if (cleared > 0) then
			MsgN("[Network] Жильё сброшено после перезапуска: квартир — " .. cleared)
			NETWORK.door.Save()
		end

		timer.Simple(4, function()
			for _, entity in ipairs(ents.FindByClass("nw_furniture")) do
				if (!keepFurniture[tostring(entity:GetOwnerChar())]) then
					entity:Remove()
				end
			end
		end)
	end

	NETWORK.door.ApplyAll()
end

function NETWORK.door.IsRestricted(data)
	return NETWORK.door.IsLocked(data)
end

function NETWORK.door.FindByKey(key)
	NETWORK.door.entities = NETWORK.door.entities or {}

	local cached = NETWORK.door.entities[key]

	if (IsValid(cached)) then
		return cached
	end

	for _, entity in ipairs(ents.GetAll()) do
		if (NETWORK.door.IsDoor(entity) and NETWORK.door.GetKey(entity) == key) then
			NETWORK.door.entities[key] = entity

			return entity
		end
	end
end

function NETWORK.door.ApplyOne(entity)
	local data = NETWORK.door.GetData(entity)

	if (!NETWORK.door.IsRestricted(data)) then
		return
	end

	NETWORK.door.EachLeaf(entity, function(leaf)
		leaf:Fire("lock")
	end)
end

function NETWORK.door.ApplyAll()
	for _, entity in ipairs(ents.GetAll()) do
		if (NETWORK.door.IsDoor(entity)) then
			NETWORK.door.ApplyOne(entity)
		end
	end
end

function NETWORK.door.Sync(target)
	net.Start("nwDoorSync")
		NETWORK.util.WriteTable(NETWORK.door.list)

	if (IsValid(target)) then
		net.Send(target)
	else
		net.Broadcast()
	end
end

function NETWORK.door.Set(entity, data)
	local key = NETWORK.door.GetKey(entity)

	if (!key) then
		return
	end

	for _, leaf in ipairs(NETWORK.door.GetLeaves(entity)) do
		local leafKey = NETWORK.door.GetKey(leaf)

		if (leafKey) then
			NETWORK.door.list[leafKey] = data
		end
	end

	NETWORK.door.Save()
	NETWORK.door.Sync()
	NETWORK.door.ApplyOne(entity)
end

function NETWORK.door.SetData(entity, data)
	return NETWORK.door.Set(entity, data)
end

function NETWORK.door.SetLocked(entity, bLocked)
	local data = NETWORK.door.GetData(entity)

	if (!data) then
		return false
	end

	bLocked = bLocked and true or false

	data.bLocked = bLocked

	if (bLocked) then
		NETWORK.door.Close(entity, data)
	else
		NETWORK.door.CancelAutoClose(entity)

		NETWORK.door.EachLeaf(entity, function(leaf)
			leaf:Fire("Unlock")
		end)
	end

	entity:EmitSound(bLocked and "doors/door_latch3.wav" or
		"doors/door_latch1.wav", 65, 100)

	NETWORK.door.Save()
	NETWORK.door.Sync()

	return true
end

local function GetDoor(client)
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

	if (!NETWORK.door.IsDoor(entity)) then
		return
	end

	if (client:GetPos():Distance(entity:GetPos()) > 200) then
		return
	end

	return entity
end

local function Notice(client, key, ...)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

NETWORK.command.Register("doorset", {
	description = "cmdDoorset",
	usage = "/doorset <тип> <название>",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		local entity = GetDoor(client)

		if (!entity) then
			return Notice(client, "doorNone")
		end

		local id = string.lower(arguments[1] or "")

		table.remove(arguments, 1)

		local bKnown = false

		for _, entry in ipairs(NETWORK.door.types) do
			if (entry.id == id) then
				bKnown = true

				break
			end
		end

		if (!bKnown) then
			Notice(client, "doorUsage")

			local names = {}

			for _, entry in ipairs(NETWORK.door.types) do
				names[#names + 1] = entry.id
			end

			return Notice(client, table.concat(names, ", "))
		end

		local data = NETWORK.door.GetData(entity) or {}

		data.type = id

		if (id == "faction") then
			local factions = NETWORK.door.ParseFactions(arguments[1])

			if (factions) then
				table.remove(arguments, 1)

				data.factions = factions
				data.faction = nil
			end
		else
			data.factions = nil
			data.faction = nil
		end

		data.title = NETWORK.util.Sanitise(table.concat(arguments, " "), 48)

		NETWORK.door.Set(entity, data)

		Notice(client, "doorSaved")

		if (data.factions) then
			Notice(client, "doorFactionList")
			Notice(client, table.concat(data.factions, ", "))
		end
	end
})

NETWORK.command.Register("doorblock", {
	description = "cmdDoorblock",
	usage = "/doorblock <блок> <номер>",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		local entity = GetDoor(client)

		if (!entity) then
			return Notice(client, "doorNone")
		end

		local data = NETWORK.door.GetData(entity) or {type = "residential"}

		data.block = NETWORK.util.Sanitise(arguments[1] or "", 24)
		data.number = NETWORK.util.Sanitise(arguments[2] or "", 12)

		NETWORK.door.Set(entity, data)

		Notice(client, "doorSaved")
	end
})

NETWORK.command.Register("doorown", {
	description = "cmdDoorown",
	usage = "/doorown <игрок|clear>",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		local entity = GetDoor(client)

		if (!entity) then
			return Notice(client, "doorNone")
		end

		local data = NETWORK.door.GetData(entity) or {type = "residential"}

		if ((arguments[1] or "") == "" or arguments[1] == "clear") then
			data.owner = nil
			data.ownerName = nil
			data.ownerChar = nil
			data.owners = nil
		else
			local target = NETWORK.permission.Find(arguments[1])

			if (!IsValid(target)) then
				return Notice(client, "permNoTarget")
			end

			local sid = target:SteamID64()

			data.owner = sid
			data.ownerName = target:GetCharacterName()
			data.ownerChar = target:GetCharacterID()
			data.owners = data.owners or {}
			data.owners[sid] = {name = target:GetCharacterName(), char = target:GetCharacterID(),
				faction = target:GetCharacterFaction()}
		end

		NETWORK.door.Set(entity, data)

		Notice(client, "doorSaved")
	end
})

NETWORK.command.Register("doorlabel", {
	description = "cmdDoorlabel",
	usage = "/doorlabel",
	adminOnly = true,
	OnRun = function(command, client)
		local entity = GetDoor(client)

		if (!entity) then
			return Notice(client, "doorNone")
		end

		local data = NETWORK.door.GetData(entity)

		if (!data) then
			return Notice(client, "doorFree")
		end

		data.bShow = data.bShow == false or nil

		NETWORK.door.Set(entity, data)

		Notice(client, data.bShow == nil and "doorLabelOff" or "doorLabelOn")
	end
})

NETWORK.command.Register("doorinfo", {
	adminOnly = true,
	description = "cmdDoorinfo",
	usage = "/doorinfo",
	OnRun = function(command, client)
		local entity = GetDoor(client)

		if (!entity) then
			return Notice(client, "doorNone")
		end

		local data = NETWORK.door.GetData(entity)

		if (!data) then
			return Notice(client, "doorFree")
		end

		Notice(client, data.bShow == false and "doorHidden" or "doorSaved")
	end
})

local function GetDoorModel(entity)
	local model = entity:GetModel()

	if (!isstring(model) or model == "" or string.sub(model, 1, 1) == "*") then
		return
	end

	return string.lower(model)
end

function NETWORK.door.FindSimilar(entity, radius)
	local class = entity:GetClass()
	local model = GetDoorModel(entity)
	local origin = entity:GetPos()
	local list = {}

	for _, other in ipairs(ents.GetAll()) do
		if (!NETWORK.door.IsDoor(other) or other:GetClass() != class) then
			continue
		end

		if (model and GetDoorModel(other) != model) then
			continue
		end

		if (radius and radius > 0 and
			other:GetPos():Distance(origin) > radius) then
			continue
		end

		list[#list + 1] = other
	end

	return list
end

NETWORK.command.Register("doorsetall", {
	description = "cmdDoorsetall",
	usage = "/doorsetall <тип> [радиус] [фракция]",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		local entity = GetDoor(client)

		if (!entity) then
			return Notice(client, "doorNone")
		end

		local id = string.lower(arguments[1] or "")
		local bKnown = false

		for _, entry in ipairs(NETWORK.door.types) do
			if (entry.id == id) then
				bKnown = true

				break
			end
		end

		if (!bKnown) then
			return Notice(client, "doorUsage")
		end

		local radius = tonumber(arguments[2]) or 0
		local raw = string.lower(arguments[3] or "")
		local factions

		if (raw != "") then
			factions = NETWORK.door.ParseFactions(raw)

			if (!factions) then
				return Notice(client, "adminNoFaction")
			end
		end

		local doors = NETWORK.door.FindSimilar(entity, radius)

		for _, door in ipairs(doors) do
			local data = NETWORK.door.GetData(door) or {}

			data.type = id
			data.factions = factions
			data.faction = nil

			NETWORK.door.list[NETWORK.door.GetKey(door)] = data
		end

		NETWORK.door.Save()
		NETWORK.door.Sync()

		Notice(client, "doorMassDone")
		Notice(client, tostring(#doors))
	end
})

NETWORK.command.Register("doorfaction", {
	description = "cmdDoorfaction",
	usage = "/doorfaction <фракция|clear>",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		local entity = GetDoor(client)

		if (!entity) then
			return Notice(client, "doorNone")
		end

		local data = NETWORK.door.GetData(entity) or {}
		local id = string.lower(arguments[1] or "")

		if (id == "" or id == "clear") then
			data.faction = nil
			data.factions = nil
			data.type = "faction"

			NETWORK.door.Set(entity, data)

			return Notice(client, "doorFactionAny")
		end

		local factions = NETWORK.door.ParseFactions(id)

		if (!factions) then
			return Notice(client, "adminNoFaction")
		end

		data.factions = factions
		data.faction = nil
		data.type = "faction"

		NETWORK.door.Set(entity, data)

		Notice(client, "doorSaved")
		Notice(client, table.concat(factions, ", "))
	end
})

NETWORK.command.Register("doorfactionsclear", {
	description = "cmdDoorfactionsclear",
	usage = "/doorfactionsclear [фракция]",
	superAdminOnly = true,
	aliases = {"doorsclearfaction"},
	OnRun = function(command, client, arguments)
		local id = string.lower(arguments[1] or "")

		if (id != "" and !NETWORK.factions.Get(id)) then
			return Notice(client, "adminNoFaction")
		end

		local removed = 0

		for key, data in pairs(NETWORK.door.list) do

			local assigned = NETWORK.door.GetFactions(data)

			if (data.type != "faction" and !assigned) then
				continue
			end

			if (id != "") then
				local bMatch = false

				for _, faction in ipairs(assigned or {}) do
					if (faction == id) then
						bMatch = true

						break
					end
				end

				if (!bMatch) then
					continue
				end
			end

			NETWORK.door.list[key] = nil
			removed = removed + 1

			local door = NETWORK.door.FindByKey(key)

			if (IsValid(door)) then
				NETWORK.door.EachLeaf(door, function(leaf)
					leaf:Fire("unlock")
				end)
			end
		end

		NETWORK.door.Save()
		NETWORK.door.Sync()

		Notice(client, "doorFactionsCleared")
		Notice(client, tostring(removed))
	end
})

NETWORK.command.Register("doorlock", {
	description = "cmdDoorlock",
	usage = "/doorlock",
	adminOnly = true,
	OnRun = function(command, client)
		local entity = GetDoor(client)

		if (!entity) then
			return Notice(client, "doorNone")
		end

		local data = NETWORK.door.GetData(entity)

		if (!data) then
			data = {type = "faction"}

			NETWORK.door.Set(entity, data)
		end

		local bLocked = !data.bLocked

		NETWORK.door.SetLocked(entity, bLocked)

		Notice(client, bLocked and "doorLockOn" or "doorLockOff")
	end
})

NETWORK.command.Register("doorclear", {
	description = "cmdDoorclear",
	usage = "/doorclear",
	adminOnly = true,
	aliases = {"doorfree"},
	OnRun = function(command, client)
		local entity = GetDoor(client)

		if (!entity) then
			return Notice(client, "doorNone")
		end

		NETWORK.door.EachLeaf(entity, function(leaf)
			NETWORK.door.list[NETWORK.door.GetKey(leaf)] = nil

			leaf:Fire("unlock")
			leaf:Fire("open")
			leaf:Fire("close")
		end)

		NETWORK.door.Save()
		NETWORK.door.Sync()

		Notice(client, "doorCleared")
	end
})

function NETWORK.door.HasFactionAccess(client, data)
	if (!data) then
		return false
	end

	local faction = client:GetCharacterFaction()

	if (!faction) then
		return false
	end

	local allowed = NETWORK.door.GetFactions(data)

	if (allowed) then
		for _, id in ipairs(allowed) do

			if (id == "alliance" and NETWORK.factions.IsAlliance(client)) then
				return true
			end

			if (id == "cwu" and NETWORK.factions.IsCWU(client)) then
				return true
			end

			if (faction == id) then
				return true
			end
		end

		return false
	end

	return NETWORK.factions.IsAlliance(client)
end

function NETWORK.door.EachLeaf(entity, callback)
	for _, leaf in ipairs(NETWORK.door.GetLeaves(entity)) do
		callback(leaf)
	end
end

local SF_USE_OPENS = 256
local SF_TOUCH_OPENS = 1024

function NETWORK.door.NeedsDriving(entity)
	local class = entity:GetClass()

	if (class != "func_door" and class != "func_door_rotating") then
		return false
	end

	local flags = entity:GetSpawnFlags()

	return bit.band(flags, SF_USE_OPENS) == 0 and
		bit.band(flags, SF_TOUCH_OPENS) == 0
end

function NETWORK.door.IsSealed(entity, data)
	if (data and data.bLocked) then
		return true
	end

	return entity:GetInternalVariable("m_bLocked") == true
end

NETWORK.door.lockTime = 1.1

local function Progress(client, key, duration)
	if (!IsValid(client)) then
		return
	end

	net.Start("nwProgress")
		net.WriteString(key or "")
		net.WriteFloat(duration or 0)
	net.Send(client)
end

local function IsBusy(client)
	return IsValid(client) and (client.nwDoorBusy or 0) > CurTime()
end

NETWORK.door.autoClose = 6

function NETWORK.door.IsOpen(entity)
	if (!IsValid(entity)) then
		return false
	end

	if (entity:GetClass() == "prop_door_rotating") then
		local state = entity:GetInternalVariable("m_eDoorState")

		if (state != nil) then

			return state == 1 or state == 2
		end
	else
		local state = entity:GetInternalVariable("m_toggle_state")

		if (state != nil) then

			return state == 0 or state == 2
		end
	end

	return entity.nwOpen == true
end

local function AutoCloseName(entity)
	return "nwDoorShut" .. entity:EntIndex()
end

function NETWORK.door.CancelAutoClose(entity)
	timer.Remove(AutoCloseName(entity))
end

function NETWORK.door.Open(client, entity, data)
	data = data or NETWORK.door.GetData(entity)

	NETWORK.door.CancelAutoClose(entity)

	NETWORK.door.EachLeaf(entity, function(leaf)
		leaf.nwOpen = true

		leaf:Fire("Unlock")
		leaf:Fire("Open")
	end)

	entity.nwOpen = true
	entity:EmitSound("doors/door_latch1.wav", 65, 100)

	hook.Run("NetworkLockOpened", client, entity, "ключ")

	if (NETWORK.door.IsRestricted(data) or entity.nwMapLocked) then
		timer.Create(AutoCloseName(entity), NETWORK.door.autoClose, 1,
			function()
				if (IsValid(entity)) then
					NETWORK.door.Close(entity)
				end
			end)
	end
end

function NETWORK.door.Close(entity, data)
	data = data or NETWORK.door.GetData(entity)

	NETWORK.door.CancelAutoClose(entity)

	NETWORK.door.EachLeaf(entity, function(leaf)
		leaf.nwOpen = false

		leaf:Fire("Close")
	end)

	entity.nwOpen = false
	entity:EmitSound("doors/door_latch3.wav", 65, 100)

	local attempts = 0

	timer.Create("nwDoorShutCheck" .. entity:EntIndex(), 1, 5, function()
		if (!IsValid(entity)) then
			return
		end

		attempts = attempts + 1

		if (NETWORK.door.IsOpen(entity) and attempts < 5) then
			NETWORK.door.EachLeaf(entity, function(leaf)
				leaf.nwOpen = false

				leaf:Fire("Close")
			end)

			return
		end

		NETWORK.door.ApplyOne(entity)

		timer.Remove("nwDoorShutCheck" .. entity:EntIndex())
	end)
end

function NETWORK.door.Toggle(client, entity, data)
	if ((entity.nwNextOpen or 0) > CurTime()) then
		return
	end

	if (IsBusy(client)) then
		return
	end

	entity.nwNextOpen = CurTime() + 0.5

	local bOpen = NETWORK.door.IsOpen(entity)
	local duration = 0

	if (!bOpen and IsValid(client) and !NETWORK.factions.IsAlliance(client)) then
		duration = NETWORK.door.lockTime
	end

	if (IsValid(client) and duration > 0) then
		client.nwDoorBusy = CurTime() + duration

		Progress(client, "doorUnlocking", duration)
	end

	timer.Simple(duration, function()
		if (!IsValid(entity)) then
			return
		end

		if (IsValid(client)) then
			client.nwDoorBusy = nil

			Progress(client, "", 0)

			if (!client:Alive() or
				client:GetPos():Distance(entity:GetPos()) > 140) then
				return
			end
		end

		NETWORK.door.FinishToggle(client, entity, NETWORK.door.GetData(entity))
	end)
end

function NETWORK.door.FinishToggle(client, entity, data)
	data = data or NETWORK.door.GetData(entity)

	if (NETWORK.door.IsOpen(entity)) then
		return NETWORK.door.Close(entity, data)
	end

	return NETWORK.door.Open(client, entity, data)
end

function NETWORK.door.ForceOpen(client, entity, data)
	if ((entity.nwNextOpen or 0) > CurTime()) then
		return
	end

	entity.nwNextOpen = CurTime() + 1

	NETWORK.door.Open(client, entity, data)
end

function NETWORK.door.CanAccess(client, entity, data)
	if (client:IsAdmin()) then
		return true
	end

	if (data and data.type == "faction") then
		return NETWORK.door.HasFactionAccess(client, data)
	end

	if (data and NETWORK.door.HasOwner(data)) then
		return NETWORK.door.HasKey(client, entity, data)
	end

	if (data and data.type == "residential") then
		return NETWORK.factions.IsAlliance(client) or NETWORK.factions.IsCWU(client)
	end

	return true
end

function GM:PlayerUse(client, entity)

	return true
end

function NETWORK.door.CanUseKeys(client, entity)
	local data = NETWORK.door.GetData(entity)

	if (!data) then
		return false
	end

	if (client:IsAdmin()) then
		return true
	end

	if (data.type == "faction" and NETWORK.door.HasFactionAccess(client, data)) then
		return true
	end

	return NETWORK.door.HasKey(client, entity, data)
end

NETWORK.door.lent = NETWORK.door.lent or {}

function NETWORK.door.HasKey(client, entity, data)
	if (!IsValid(client) or !client:IsPlayer()) then
		return false
	end

	local key

	if (data) then
		key = NETWORK.door.GetRootKey(entity)
	else
		key, data = NETWORK.door.GetRootKey(entity)
	end

	if (!data) then
		return false
	end

	local steamID = client:SteamID64()

	if (NETWORK.door.IsOwner(data, steamID)) then
		return true
	end

	local lent = key and NETWORK.door.lent[key]
	local entry = lent and lent[steamID]

	if (!entry) then
		return false
	end

	if (entry.expires <= CurTime()) then
		lent[steamID] = nil

		return false
	end

	return true
end

function NETWORK.door.GetSeal(entity)
	if (!NETWORK.barricade or !NETWORK.barricade.IsDoorSealed) then
		return
	end

	return (NETWORK.barricade.IsDoorSealed(entity))
end

NETWORK.door.pickTime = 10

function NETWORK.door.IsPicked(entity)
	for _, leaf in ipairs(NETWORK.door.GetLeaves(entity)) do
		if ((leaf.nwPickedUntil or 0) > CurTime()) then
			return true
		end
	end

	return false
end

function NETWORK.door.Pick(client, entity, duration)
	duration = duration or NETWORK.door.pickTime

	local expires = CurTime() + duration

	NETWORK.door.CancelAutoClose(entity)

	NETWORK.door.EachLeaf(entity, function(leaf)
		leaf.nwPickedUntil = expires
		leaf.nwOpen = true

		leaf:Fire("Unlock")
		leaf:Fire("Open")
	end)

	entity:EmitSound("doors/door_latch1.wav", 65, 112)

	hook.Run("NetworkLockOpened", client, entity, "отмычка")

	timer.Create("nwDoorPicked" .. entity:EntIndex(), duration, 1, function()
		if (!IsValid(entity)) then
			return
		end

		NETWORK.door.EachLeaf(entity, function(leaf)
			leaf.nwPickedUntil = nil
		end)

		local data = NETWORK.door.GetData(entity)

		if (NETWORK.door.IsRestricted(data)) then
			NETWORK.door.Close(entity, data)
		elseif (entity.nwMapLocked) then
			NETWORK.door.EachLeaf(entity, function(leaf)
				leaf.nwOpen = false

				leaf:Fire("Close")
				leaf:Fire("Lock")
			end)
		end
	end)
end

function NETWORK.door.LendKey(client, target, key, minutes)
	local data = NETWORK.door.list[key]

	if (!istable(data) or data.linkKey or !NETWORK.door.CanLend(data)) then
		return false
	end

	if (!IsValid(client) or !NETWORK.door.IsOwner(data, client:SteamID64())) then
		return false
	end

	if (!IsValid(target) or !target:IsPlayer()) then
		return false
	end

	local steamID = target:SteamID64()

	NETWORK.door.lent[key] = NETWORK.door.lent[key] or {}
	NETWORK.door.lent[key][steamID] = {
		expires = CurTime() + minutes * 60,
		from = client:SteamID64()
	}

	local title = NETWORK.door.GetTitle(data)

	timer.Create("nwDoorLent:" .. key .. ":" .. steamID, minutes * 60, 1, function()
		local lent = NETWORK.door.lent[key]

		if (!lent or !lent[steamID]) then
			return
		end

		lent[steamID] = nil

		for _, other in ipairs(player.GetAll()) do
			if (other:SteamID64() == steamID) then
				NETWORK.notice.Send(other, "doorKeyExpired", "warn", title)

				break
			end
		end
	end)

	return true, title
end

function NETWORK.door.CancelKeyTurn(client, bSilent)
	if (!IsValid(client) or !client.nwKeyTask) then
		return
	end

	client.nwKeyTask = nil
	client.nwDoorBusy = nil

	Progress(client, "", 0)

	if (!bSilent) then
		NETWORK.notice.Send(client, "doorKeyCancelled", "warn")
	end
end

function NETWORK.door.BeginKeyTurn(client, entity)
	if (!IsValid(client) or !NETWORK.door.IsDoor(entity)) then
		return false
	end

	if (client.nwKeyTask or IsBusy(client)) then
		return false
	end

	if (IsValid(entity.nwLock)) then
		Notice(client, "doorCombineLock")

		return false
	end

	local sealed = NETWORK.door.GetSeal(entity)

	if (sealed) then
		Notice(client, sealed == "boarded" and "doorBoarded" or "doorPadlocked")

		return false
	end

	if (!NETWORK.door.CanUseKeys(client, entity)) then
		Notice(client, "doorNoAccess")

		return false
	end

	local data = NETWORK.door.GetData(entity)

	if (!data) then
		return false
	end

	local duration = NETWORK.door.lockTime
	local bLock = !NETWORK.door.IsLocked(data)

	client.nwKeyTask = {
		door = entity,
		key = NETWORK.door.GetKey(entity),
		start = client:GetPos(),
		finish = CurTime() + duration,
		bLock = bLock
	}
	client.nwDoorBusy = CurTime() + duration

	Progress(client, bLock and "doorLocking" or "doorUnlocking", duration)

	return true
end

local function IsLookingAt(client, entity)
	local trace = client:GetEyeTrace()
	local hit = trace.Entity

	if (!NETWORK.door.IsDoor(hit)) then
		return false
	end

	if (client:GetPos():Distance(trace.HitPos) > 200) then
		return false
	end

	local hitKey = NETWORK.door.GetKey(hit)

	for _, leaf in ipairs(NETWORK.door.GetLeaves(entity)) do
		if (NETWORK.door.GetKey(leaf) == hitKey) then
			return true
		end
	end

	return false
end

local function FinishKeyTurn(client, task)
	local entity = task.door

	client.nwKeyTask = nil
	client.nwDoorBusy = nil

	Progress(client, "", 0)

	if (IsValid(entity.nwLock) or NETWORK.door.GetSeal(entity) or
		!NETWORK.door.CanUseKeys(client, entity)) then
		return
	end

	local data = NETWORK.door.GetData(entity)

	if (!data or NETWORK.door.IsLocked(data) == task.bLock) then
		return
	end

	NETWORK.door.SetLocked(entity, task.bLock)

	client:SetAnimation(PLAYER_ATTACK1)

	NETWORK.chat.Send(client, "it", L(task.bLock and "doorActLock" or "doorActUnlock"))
end

timer.Create("nwDoorKeyTurn", 0.1, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local task = client.nwKeyTask

		if (!task) then
			continue
		end

		local entity = task.door
		local weapon = client:GetActiveWeapon()

		local bBroken = !IsValid(entity) or !client:Alive() or
			!IsValid(weapon) or weapon:GetClass() != "weapon_nwkeys" or
			client:GetPos():Distance(task.start) > 48 or
			!IsLookingAt(client, entity)

		if (bBroken) then
			NETWORK.door.CancelKeyTurn(client)

			continue
		end

		if (CurTime() >= task.finish) then
			FinishKeyTurn(client, task)
		end
	end
end)

hook.Add("PlayerDeath", "nwDoorKeyTurn", function(client)
	NETWORK.door.CancelKeyTurn(client, true)
end)

hook.Add("PlayerDisconnected", "nwDoorKeyTurn", function(client)
	client.nwKeyTask = nil
end)

hook.Add("PlayerInitialSpawn", "nwDoor", function(client)
	timer.Simple(1.8, function()
		if (IsValid(client)) then
			NETWORK.door.Sync(client)
		end
	end)
end)

hook.Add("InitPostEntity", "nwDoor", function()
	NETWORK.door.Load()
end)

hook.Add("Initialize", "nwDoorInit", function()
	timer.Simple(1, function()
		NETWORK.door.Load()
	end)
end)

hook.Add("PlayerUse", "nwDoorAccess", function(client, entity)
	if (!NETWORK.door.IsDoor(entity) or !client:HasCharacter()) then
		return
	end

	local sealed = NETWORK.door.GetSeal(entity)

	if (sealed) then
		if (sealed == "padlock" and NETWORK.padlock and NETWORK.padlock.TryKey and
			NETWORK.padlock.TryKey(client, entity)) then
			return false
		end

		if ((client.nwDoorDenied or 0) < CurTime()) then
			client.nwDoorDenied = CurTime() + 1.5

			entity:EmitSound(sealed == "boarded" and
				"physics/wood/wood_box_impact_hard" .. math.random(1, 3) .. ".wav" or
				"doors/default_locked.wav", 60, 100)

			Notice(client, sealed == "boarded" and "doorBoarded" or "doorPadlocked")
		end

		return false
	end

	local data = NETWORK.door.GetData(entity)
	local lock = entity.nwLock

	local bPicked = NETWORK.door.IsPicked(entity)

	if (IsValid(lock) and lock:GetLocked()) then
		if ((client.nwDoorDenied or 0) < CurTime()) then
			client.nwDoorDenied = CurTime() + 1.5

			lock:Refuse(client)

			Notice(client, NETWORK.factions.IsAlliance(client) and
				"lockUseLock" or "lockNoAccess")
		end

		return false
	end

	if (!bPicked and !NETWORK.door.CanAccess(client, entity, data)) then
		if ((client.nwDoorDenied or 0) < CurTime()) then
			client.nwDoorDenied = CurTime() + 1.5

			entity:EmitSound("doors/default_locked.wav", 60, 100)

			Notice(client, data and data.type == "faction" and "doorCantOpen" or
				"doorNoAccess")
		end

		return false
	end

	if (!data) then
		return
	end

	local bLocked = (NETWORK.door.IsLocked(data) or entity.nwMapLocked) and !bPicked

	if (bLocked) then

		local bOwner = NETWORK.door.HasKey(client, entity, data)
		local bFaction = data.type == "faction" and NETWORK.door.HasFactionAccess(client, data)
		local bAdminNoclip = client:IsAdmin() and client:GetMoveType() == MOVETYPE_NOCLIP

		if (!bFaction and !bAdminNoclip) then
			if ((client.nwDoorDenied or 0) < CurTime()) then
				client.nwDoorDenied = CurTime() + 1.5

				entity:EmitSound("doors/default_locked.wav", 60, 100)

				Notice(client, bOwner and "doorLockedUseKeys" or "doorLockedKeys")
			end

			return false
		end
	end

	if (!bLocked) then

		if (entity:GetInternalVariable("m_bLocked") == true) then
			NETWORK.door.EachLeaf(entity, function(leaf)
				leaf:Fire("Unlock")
			end)
		end

		if (!NETWORK.door.NeedsDriving(entity)) then
			return
		end
	end

	NETWORK.door.Toggle(client, entity, data)

	return false
end)

timer.Create("nwDoorReseal", 0.5, 0, function()
	for key, data in pairs(NETWORK.door.list) do
		if (!NETWORK.door.IsRestricted(data)) then
			continue
		end

		local entity = NETWORK.door.FindByKey and NETWORK.door.FindByKey(key)

		if (!IsValid(entity) or NETWORK.door.IsOpen(entity) or NETWORK.door.IsPicked(entity)) then
			continue
		end

		if (entity:GetInternalVariable("m_bLocked") == true) then
			continue
		end

		NETWORK.door.EachLeaf(entity, function(leaf)
			leaf:Fire("lock")
		end)
	end
end)

NETWORK.command.Register("doordebug", {
	description = "cmdDoordebug",
	usage = "/doordebug",
	adminOnly = true,
	OnRun = function(command, client)
		local entity = client:GetEyeTrace().Entity
		local function Line(text)
			net.Start("nwChatMessage")
				net.WriteString("notice")
				net.WriteEntity(NULL)
				net.WriteString("")
				net.WriteString(text)
			net.Send(client)

			NETWORK.util.Print("[doordebug] " .. text)
		end

		if (!IsValid(entity)) then
			return Line("Наведитесь на дверь")
		end

		Line("class = " .. entity:GetClass() ..
			" | IsDoor = " .. tostring(NETWORK.door.IsDoor(entity)))

		local data, key = NETWORK.door.GetData(entity)

		Line("key = " .. tostring(key) .. " | registered = " .. tostring(data != nil) ..
			" | type = " .. tostring(data and data.type) ..
			" | factions = " .. table.concat(NETWORK.door.GetFactions(data) or
				{"(любая фракция Альянса)"}, ", ") ..
			" | bLocked = " .. tostring(data and data.bLocked))

		Line("m_bLocked = " .. tostring(entity:GetInternalVariable("m_bLocked")) ..
			" | sealed = " .. tostring(NETWORK.door.IsSealed(entity, data)) ..
			" | lock = " .. tostring(IsValid(entity.nwLock)) ..
			" | flags = " .. entity:GetSpawnFlags() ..
			" | needsDriving = " .. tostring(NETWORK.door.NeedsDriving(entity)))

		if (!data) then
			Line("ДВЕРЬ НЕ ЗАРЕГИСТРИРОВАНА — выполните: /doorset faction <название>")
		elseif (data.type != "faction") then
			Line("ТИП НЕ faction (сейчас: " .. tostring(data.type) ..
				") — выполните: /doorset faction <название>")
		end

		Line("faction = " .. tostring(client:GetCharacterFaction()) ..
			" | alliance = " .. tostring(NETWORK.factions.IsAlliance(client)) ..
			" | admin = " .. tostring(client:IsAdmin()) ..
			" | access = " .. tostring(NETWORK.door.CanAccess(client, entity, data)))

		local partner = entity.GetDoorPartner and entity:GetDoorPartner()

		Line("partner = " .. tostring(IsValid(partner)) ..
			" | open = " .. tostring(NETWORK.door.IsOpen(entity)) ..
			" | locked = " .. tostring(NETWORK.door.IsLocked(data)) ..
			" | mapLocked = " .. tostring(entity.nwMapLocked == true))
	end
})

hook.Add("InitPostEntity", "nwDoorMapLocks", function()
	timer.Simple(2, function()
		for _, entity in ipairs(ents.GetAll()) do
			if (NETWORK.door.IsDoor(entity)) then
				entity.nwMapLocked = entity:GetInternalVariable("m_bLocked") == true
			end
		end
	end)
end)

function NETWORK.door.ClearAll()
	local count = 0

	for _, entity in ipairs(ents.GetAll()) do
		if (NETWORK.door.IsDoor(entity)) then
			NETWORK.door.SetData(entity, nil)

			count = count + 1
		end

		if (entity:GetClass() == "nw_lock") then
			entity:Remove()
		end
	end

	NETWORK.door.Save()

	return count
end

NETWORK.command.Register("cleardoor", {
	description = "cmdCleardoor",
	usage = "/cleardoor confirm",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		if (arguments[1] != "confirm") then
			return Notice(client, "cleardoorConfirm")
		end

		NETWORK.door.ClearAll()
		Notice(client, "cleardoorDone")
	end
})

NETWORK.command.Register("doorclearradius", {
	description = "cmdDoorClear",
	usage = "/doorclearradius [радиус]",
	example = "/doorclearradius 300",
	adminOnly = true,
	aliases = {"doorsclear"},
	OnRun = function(command, client, arguments)
		local radius = math.Clamp(tonumber(arguments[1]) or 200, 64, 1024)
		local count = 0
		local seen = {}

		for _, entity in ipairs(ents.FindInSphere(client:GetPos(), radius)) do
			if (!NETWORK.door.IsDoor(entity) or seen[entity]) then
				continue
			end

			NETWORK.door.Set(entity, {})

			for _, leaf in ipairs(NETWORK.door.GetLeaves(entity)) do
				seen[leaf] = true
			end

			seen[entity] = true
			count = count + 1
		end

		if (count == 0) then
			return Notice(client, "doorClearNone")
		end

		if (NETWORK.log and NETWORK.log.Add) then
			NETWORK.log.Add("admin", string.format(
				"%s очистил двери в радиусе %d (%d шт.)",
				NETWORK.log.Name(client), radius, count), client:GetPos())
		end

		NETWORK.chat.Notice(client, L("doorClearDone", count))
	end
})
