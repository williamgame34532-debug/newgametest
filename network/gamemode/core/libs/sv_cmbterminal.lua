util.AddNetworkString("nwCmbMarkDone")
util.AddNetworkString("nwCmbOpen")
util.AddNetworkString("nwCmbClose")
util.AddNetworkString("nwCmbData")

function NETWORK.cmbterm.Break(entity, client)
	NETWORK.cmbterm.Journal(client, "journalBreak", entity)

	entity:SetNWBool("nwBroken", true)

	if (NETWORK.mechanic and NETWORK.mechanic.StartFault) then
		NETWORK.mechanic.StartFault(entity)
	end
	entity.nwBaseSkin = entity.nwBaseSkin or entity:GetSkin()

	entity:SetSkin(3)
	entity:EmitSound("ambient/levels/labs/electric_explosion" ..
		math.random(5) .. ".wav", 80, math.random(95, 105))

	if (entity.nwLoop) then
		entity.nwLoop:Stop()
		entity.nwLoop = nil
	end

	local effect = EffectData()

	effect:SetOrigin(entity:WorldSpaceCenter())
	util.Effect("cball_explode", effect)
end

function NETWORK.cmbterm.Restore(entity)
	entity:SetNWBool("nwBroken", false)
	entity:SetNWString("nwBreakOwner", "")

	if (NETWORK.mechanic and NETWORK.mechanic.StopFault) then
		NETWORK.mechanic.StopFault(entity)
	end
	entity.nwUses = 0
	entity.nwBreakAt = nil

	entity:SetSkin(entity.nwBaseSkin or 0)
	NETWORK.cmbterm.StartLoop(entity)
end

function NETWORK.cmbterm.StartLoop(entity)
	if (entity.nwLoop) then
		entity.nwLoop:Stop()
	end

	entity.nwLoop = CreateSound(entity, "ambient/machines/combine_terminal_loop1.wav")
	entity.nwLoop:PlayEx(0.35, 100)
end
util.AddNetworkString("nwCmbAction")
util.AddNetworkString("nwCmbOrder")
util.AddNetworkString("nwCmbSnap")
util.AddNetworkString("nwCmbFlash")

NETWORK.cmbterm = NETWORK.cmbterm or {}

NETWORK.cmbterm.notes = NETWORK.cmbterm.notes or {}
NETWORK.cmbterm.detained = NETWORK.cmbterm.detained or {}

local dataPath = "network/cmbterminal.txt"

local function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key or "")
	net.Send(client)
end

function NETWORK.cmbterm.Save()
	file.CreateDir("network")
	file.Write(dataPath, util.TableToJSON({
		notes = NETWORK.cmbterm.notes,
		detained = NETWORK.cmbterm.detained
	}, true))
end

function NETWORK.cmbterm.Load()
	local contents = file.Read(dataPath, "DATA")
	local data = contents and util.JSONToTable(contents)

	if (!istable(data)) then
		return
	end

	NETWORK.cmbterm.notes = istable(data.notes) and data.notes or {}
	NETWORK.cmbterm.detained = istable(data.detained) and data.detained or {}
end

NETWORK.cmbterm.lastZone = NETWORK.cmbterm.lastZone or {}

hook.Add("Think", "nwCmbZoneTrail", function()
	if ((NETWORK.cmbterm.nextTrail or 0) > CurTime()) then
		return
	end

	NETWORK.cmbterm.nextTrail = CurTime() + 2

	for _, client in ipairs(player.GetAll()) do
		if (!client:HasCharacter() or !client:Alive()) then
			continue
		end

		local zone = NETWORK.zone.AtEntity(client)

		if (!zone) then
			continue
		end

		local type = NETWORK.zone.GetType(zone.type)
		local label = zone.name != "" and zone.name or (type and L(type.name)) or "?"
		local id = client:GetCharacterID()
		local entry = NETWORK.cmbterm.lastZone[id]

		if (entry and entry.name == label) then
			entry.time = os.time()

			continue
		end

		NETWORK.cmbterm.lastZone[id] = {name = label, time = os.time()}
	end
end)

function NETWORK.cmbterm.GetZone(id)
	local entry = NETWORK.cmbterm.lastZone[id]

	return entry and entry.name or nil
end

function NETWORK.cmbterm.AddNote(client, subject, text)
	text = NETWORK.util.Sanitise(text, NETWORK.cmbterm.noteMax, true)

	if (text == "" or subject <= 0) then
		return false
	end

	local key = tostring(subject)
	local list = NETWORK.cmbterm.notes[key] or {}

	list[#list + 1] = {
		author = client:GetCharacterName(),
		text = text,
		time = os.time()
	}

	while (#list > NETWORK.cmbterm.notesPerSubject) do
		table.remove(list, 1)
	end

	NETWORK.cmbterm.notes[key] = list

	NETWORK.cmbterm.Save()

	return true
end

local function BuildRecord(target, bFull)
	local character = target:GetCharacter()
	local id = character:GetID()
	local faction = NETWORK.factions.Get(character:GetFaction())
	local band = NETWORK.loyalty.GetBand(target:GetLoyalty())

	local record = {
		id = id,
		cid = NETWORK.terminal.GetCitizenID(character),
		name = character:GetName(),
		faction = faction and L(faction.name) or "?",
		loyalty = target:GetLoyalty(),
		loyaltyBand = L(band.label),

		violations = (function()
			local character = target:GetCharacter()
			local list = character and
				NETWORK.detain.GetViolations(character) or {}

			if (#list == 0) then
				return nil
			end

			local lines = {}

			for index, entry in ipairs(list) do
				lines[#lines + 1] = string.format("%d) %s — %d мин.",
					index, entry.reason, entry.term)
			end

			return table.concat(lines, "  //  ")
		end)(),
		notes = NETWORK.cmbterm.notes[tostring(id)] or {}
	}

	if (bFull) then
		record.zone = NETWORK.cmbterm.GetZone(id)

		local squad = target:GetSquadData()

		record.squad = squad and squad.name or nil
	end

	return record
end

function NETWORK.cmbterm.BuildPayload(client, page, argument)
	local payload = {page = page}

	if (page == "alliance") then
		payload.list = {}

		for _, target in ipairs(player.GetAll()) do
			if (target:HasCharacter() and NETWORK.factions.IsAlliance(target)) then
				payload.list[#payload.list + 1] = BuildRecord(target, true)
			end
		end
	elseif (page == "citizen") then
		local id = string.gsub(tostring(argument or ""), "[^%d]", "")

		for _, target in ipairs(player.GetAll()) do
			local character = target:GetCharacter()

			if (character and NETWORK.terminal.GetCitizenID(character) == id) then
				payload.record = BuildRecord(target, false)

				break
			end
		end
	elseif (page == "squads") then
		payload.list = {}

		for id, squad in pairs(NETWORK.squad.list) do
			if (!NETWORK.squad.CanSee(client, squad)) then
				continue
			end

			local members = NETWORK.squad.GetMembers(id)
			local leader = NETWORK.squad.GetLeader(id)
			local roster = {}

			for _, member in ipairs(members) do
				roster[#roster + 1] = {
					name = member:GetCharacterName(),
					zone = NETWORK.cmbterm.GetZone(member:GetCharacterID()),
					bLeader = member == leader
				}
			end

			payload.list[#payload.list + 1] = {
				id = id,
				name = squad.name,
				size = squad.size,
				count = #members,
				leader = leader and leader:GetCharacterName() or "-",
				zone = leader and NETWORK.cmbterm.GetZone(
					leader:GetCharacterID()) or nil,
				roster = roster,
				bMine = client:GetSquad() == id,
				bLeading = client:IsSquadLeader() and client:GetSquad() == id
			}
		end

		table.sort(payload.list, function(a, b)
			return a.name < b.name
		end)

		payload.squad = client:GetSquad()
	elseif (page == "cameras") then
		payload.list = {}

		for _, camera in ipairs(ents.FindByClass("npc_combine_camera")) do

			if (!IsValid(camera) or camera:GetNWBool("nwBroken", false)) then
				continue
			end

			local position = camera:WorldSpaceCenter()
			local angles = camera:GetAngles()
			local zone = NETWORK.zone.AtEntity and NETWORK.zone.AtEntity(camera)
			local type = zone and NETWORK.zone.GetType(zone.type)

			payload.list[#payload.list + 1] = {
				index = camera:EntIndex(),
				x = position.x,
				y = position.y,
				z = position.z,
				pitch = angles.p,
				yaw = angles.y,
				roll = angles.r,
				zone = zone and (zone.name != "" and zone.name or
					(type and type.name)) or nil,
				bEnabled = camera:GetSequenceName(camera:GetSequence()) != "idle"
			}
		end

		table.sort(payload.list, function(a, b)
			return a.index < b.index
		end)
	elseif (page == "business") then
		payload.list = {}

		payload.doors = {}

		for _, door in ipairs(ents.GetAll()) do
			if (NETWORK.door.IsDoor(door)) then
				local doorData = NETWORK.door.GetData(door)

				if (doorData and doorData.type == "business") then
					local zone = NETWORK.zone.At(door:GetPos())

					payload.doors[#payload.doors + 1] =
						(doorData.name or "Дверь") .. " — " ..
						(zone and zone.name or L("owUnknownZone"))
				end
			end
		end

		payload.bAllowed = client:GetNWString("nwClass", "") == "cmd" or
			client:IsAdmin()

		if (payload.bAllowed) then
			for id, entry in pairs(NETWORK.business.stored) do
				payload.list[#payload.list + 1] = {
					id = id,
					name = entry.name,
					cid = entry.cid,
					what = entry.what,
					why = entry.why,
					status = entry.status,
					location = entry.location,
					time = entry.time
				}
			end

			table.sort(payload.list, function(a, b)
				if ((a.status == "pending") != (b.status == "pending")) then
					return a.status == "pending"
				end

				return (a.time or 0) > (b.time or 0)
			end)
		end
	elseif (page == "detained") then
		payload.list = {}

		for key, entry in pairs(NETWORK.cmbterm.detained) do
			payload.list[#payload.list + 1] = {
				id = tonumber(key),
				cid = entry.cid,
				name = entry.name,
				reason = entry.reason,
				term = entry.term,

				remaining = NETWORK.detain.GetRemaining(entry),
				officer = entry.officer,
				model = entry.model,
				notes = NETWORK.cmbterm.notes[key] or {}
			}
		end

		table.sort(payload.list, function(a, b)
			return (a.remaining or 99999) < (b.remaining or 99999)
		end)
	end

	if (page == "breaks" and (NETWORK.factions.IsCWU(client) or
		client:GetNWString("nwClass", "") == "mechanic" or
		client:IsAdmin())) then
		payload.breaks = NETWORK.cmbterm.BuildBreaks(client)
	end

	if (page == "journal") then
		payload.journal = NETWORK.cmbterm.BuildJournal(client, client.nwCmbTerminal)
	end

	if (page == "maint") then
		payload.maint = NETWORK.cmbterm.BuildMaint(client)
	end

	if (page == "tasks") then
		payload.tasks = NETWORK.cmbterm.BuildTasks(client)
	end

	hook.Run("NetworkCmbPayload", client, page, argument, payload)

	return payload
end

function NETWORK.cmbterm.OpenPage(client, page, argument)
	client.nwCmbPage = page
	client.nwCmbArgument = argument

	NETWORK.cmbterm.Sync(client, page, argument)
end

function NETWORK.cmbterm.Refresh(client)
	if (IsValid(client) and IsValid(client.nwCmbTerminal)) then
		NETWORK.cmbterm.Sync(client, client.nwCmbPage or "home", client.nwCmbArgument)
	end
end

function NETWORK.cmbterm.GetKind(client)
	local entity = client.nwCmbTerminal

	if (IsValid(entity) and entity:GetClass() == "nw_cwuterminal") then
		return "cwu"
	end

	return IsValid(entity) and "alliance" or nil
end

NETWORK.cmbterm.breakClasses = {
	npc_combine_camera = "entCamera",
	nw_fridge = "entFridge",
	nw_vending = "entVending",
	nw_breaker = "entBreaker",
	nw_cmbterminal = "entCmbTerminal",
	nw_cwuterminal = "entCwuTerminal"
}

NETWORK.cmbterm.journal = NETWORK.cmbterm.journal or {}
NETWORK.cmbterm.journalLimit = 60

NETWORK.cmbterm.journalNames = {
	nw_cmbterminal = "entCmbTerminal",
	nw_cwuterminal = "entCwuTerminal",
	nw_forcefield = "entForcefield",
	nw_lock = "entLock",
	nw_breaker = "entBreaker",
	nw_fridge = "entFridge",
	nw_vending = "entVending",
	npc_combine_camera = "entCamera"
}

function NETWORK.cmbterm.Journal(client, action, entity)
	local list = NETWORK.cmbterm.journal
	local class = IsValid(entity) and entity:GetClass() or ""
	local zone = IsValid(entity) and NETWORK.zone and NETWORK.zone.At and
		NETWORK.zone.At(entity:GetPos())

	list[#list + 1] = {
		time = os.date("%H:%M"),
		action = action,
		name = IsValid(client) and client:GetCharacterName() or "?",
		faction = IsValid(client) and client:GetCharacterFaction() or "",
		target = NETWORK.cmbterm.journalNames[class] or class,
		zone = zone and (zone.name or zone.id) or ""
	}

	while (#list > NETWORK.cmbterm.journalLimit) do
		table.remove(list, 1)
	end
end

function NETWORK.cmbterm.BuildJournal(client, entity)
	local list = {}
	local bCWU = IsValid(entity) and entity:GetClass() == "nw_cwuterminal"

	for index = #NETWORK.cmbterm.journal, 1, -1 do
		local entry = NETWORK.cmbterm.journal[index]
		local faction = NETWORK.factions.Get(entry.faction or "")
		local bEntryCWU = faction and faction.bCWU or false

		if (bEntryCWU != bCWU) then
			continue
		end

		list[#list + 1] = {
			time = entry.time,
			action = entry.action,
			name = entry.name,
			target = entry.target != "" and L(entry.target) or "?",
			zone = entry.zone
		}
	end

	return list
end

function NETWORK.cmbterm.BuildBreaks(client)
	local list = {}

	for class, label in pairs(NETWORK.cmbterm.breakClasses) do
		for _, entity in ipairs(ents.FindByClass(class)) do
			if (!entity:GetNWBool("nwBroken", false)) then
				continue
			end

			local zone = NETWORK.zone and NETWORK.zone.At and
				NETWORK.zone.At(entity:GetPos())
			local owner = entity:GetNWString("nwBreakOwner", "")

			list[#list + 1] = {
				name = L(label) .. (owner != "" and (" — " .. L(owner ==
					client:GetCharacterName() and "cmbBreakMine" or "cmbBreakTakenBy", owner)) or ""),
				zone = zone and (zone.name or zone.id) or "",
				distance = math.Round(client:GetPos():Distance(entity:GetPos()) *
					0.0254),
				position = {entity:GetPos().x, entity:GetPos().y,
					entity:GetPos().z},
				entity = entity:EntIndex(),
				owner = owner
			}
		end
	end

	table.sort(list, function(a, b)
		return a.distance < b.distance
	end)

	for index, entry in ipairs(list) do
		entry.index = index
	end

	client.nwBreakList = list

	return list
end

NETWORK.cmbterm.maintClasses = {
	nw_cmbterminal = "entCmbTerminal",
	nw_forcefield = "entForcefield",
	nw_lock = "entLock",
	npc_combine_camera = "entCamera"
}

function NETWORK.cmbterm.IsMaintBroken(entity)
	local class = entity:GetClass()

	if (class == "nw_forcefield") then
		return entity.GetMode and entity.MODE_SHUTDOWN and
			entity:GetMode() == entity.MODE_SHUTDOWN
	end

	if (class == "nw_lock") then
		return entity.nwHacked == true
	end

	return entity:GetNWBool("nwBroken", false)
end

function NETWORK.cmbterm.BuildMaint(client)
	local list = {}

	for class, label in pairs(NETWORK.cmbterm.maintClasses) do
		for _, entity in ipairs(ents.FindByClass(class)) do
			if (!NETWORK.cmbterm.IsMaintBroken(entity)) then
				continue
			end

			local zone = NETWORK.zone and NETWORK.zone.At and
				NETWORK.zone.At(entity:GetPos())
			local owner = entity:GetNWString("nwBreakOwner", "")

			list[#list + 1] = {
				name = L(label) .. (owner != "" and (" — " .. L(owner ==
					client:GetCharacterName() and "cmbBreakMine" or "cmbBreakTakenBy", owner)) or ""),
				zone = zone and (zone.name or zone.id) or "",
				distance = math.Round(client:GetPos():Distance(entity:GetPos()) *
					0.0254),
				position = {entity:GetPos().x, entity:GetPos().y,
					entity:GetPos().z},
				entity = entity:EntIndex(),
				owner = owner
			}
		end
	end

	table.sort(list, function(a, b)
		return a.distance < b.distance
	end)

	for index, entry in ipairs(list) do
		entry.index = index
	end

	client.nwMaintList = list

	return list
end

NETWORK.cmbterm.taskClasses = {
	nw_forcefield = "entForcefield",
	nw_lock = "entLock",
	nw_cmbterminal = "entCmbTerminal",
	nw_cwuterminal = "entCwuTerminal",
	nw_breaker = "entBreaker",
	npc_combine_camera = "entCamera"
}

function NETWORK.cmbterm.IsTaskBroken(entity)
	if (!IsValid(entity)) then
		return false
	end

	return NETWORK.cmbterm.IsMaintBroken(entity)
end

function NETWORK.cmbterm.BuildTasks(client)
	local list = {}
	local seen = {}

	local function Collect(classes, checker, kind)
		for class, label in pairs(classes) do
			for _, entity in ipairs(ents.FindByClass(class)) do
				if (seen[entity] or !checker(entity)) then
					continue
				end

				seen[entity] = true

				local zone = NETWORK.zone and NETWORK.zone.At and
					NETWORK.zone.At(entity:GetPos())

				list[#list + 1] = {
					name = L(label),
					kind = kind,
					class = class,
					zone = zone and (zone.name or zone.id) or "",
					distance = math.Round(client:GetPos():Distance(
						entity:GetPos()) * 0.0254),
					position = {entity:GetPos().x, entity:GetPos().y,
						entity:GetPos().z}
				}
			end
		end
	end

	Collect(NETWORK.cmbterm.taskClasses, NETWORK.cmbterm.IsTaskBroken, "maint")

	hook.Run("NetworkCmbTasks", client, list)

	table.sort(list, function(a, b)
		return a.distance < b.distance
	end)

	for index, entry in ipairs(list) do
		entry.index = index
	end

	client.nwTaskList = list

	return list
end

function NETWORK.cmbterm.Sync(client, page, argument)
	net.Start("nwCmbData")
		NETWORK.util.WriteTable(NETWORK.cmbterm.BuildPayload(client, page, argument))
	net.Send(client)
end

function NETWORK.cmbterm.Open(client, entity)

	if (entity:GetNWBool("nwBroken")) then
		entity:EmitSound("framework/cmb/forcefield/sparkle" ..
			math.random(4) .. ".mp3", 60, 110)

		return
	end

	entity.nwUses = (entity.nwUses or 0) + 1
	entity.nwBreakAt = entity.nwBreakAt or math.random(20, 30)

	if (entity.nwUses >= entity.nwBreakAt) then
		NETWORK.cmbterm.Break(entity)

		return
	end

	if (IsValid(client.nwCmbTerminal)) then
		NETWORK.cmbterm.Close(client)
	end

	client.nwCmbTerminal = entity

	entity:SetUser(client)
	entity:EmitSound(NETWORK.cmbterm.sounds.open, 70)

	net.Start("nwCmbOpen")
		net.WriteEntity(entity)
		net.WriteFloat(math.Rand(NETWORK.cmbterm.bootMin, NETWORK.cmbterm.bootMax))
	net.Send(client)
end

function NETWORK.cmbterm.Close(client)
	local entity = client.nwCmbTerminal

	NETWORK.cmbterm.ReleaseCamera(client, true)

	client.nwCmbTerminal = nil
	client.nwCmbCamera = nil

	if (IsValid(entity) and entity:GetUser() == client) then
		entity:SetUser(NULL)
	end

	net.Start("nwCmbClose")
	net.Send(client)
end

function NETWORK.cmbterm.ReleaseCamera(client, bSilent)
	local index = client.nwCmbControl
	local camera = index and Entity(index)

	client.nwCmbControl = nil

	if (!IsValid(camera) or camera:GetClass() != "npc_combine_camera") then
		return
	end

	camera.nwAimYaw = 0
	camera.nwAimPitch = 0
	camera.nwCurYaw = 0
	camera.nwCurPitch = 0
	camera:RemoveEFlags(EFL_NO_THINK_FUNCTION)

	local bone = camera:LookupBone("Combine_Camera.bone1") or 0

	camera:ManipulateBoneAngles(bone, angle_zero)

	if (bone != 0) then
		camera:ManipulateBoneAngles(0, angle_zero)
	end

	if (!bSilent) then
		camera:EmitSound("NPC_CombineCamera.Retire")
	end
end

net.Receive("nwCmbClose", function(_, client)
	NETWORK.cmbterm.Close(client)
end)

net.Receive("nwCmbAction", function(_, client)
	local action = net.ReadString()
	local argument = net.ReadString()

	local extra = net.ReadString()
	local entity = client.nwCmbTerminal

	local bCWUAccess = IsValid(entity) and
		entity:GetClass() == "nw_cwuterminal" and
		(NETWORK.factions.IsCWU(client) or
		client:GetNWString("nwClass", "") == "mechanic")

	if (!bCWUAccess and !NETWORK.cmbterm.CanUse(client, entity)) then
		return
	end

	if (action == "camwatch") then
		local index = tonumber(argument)
		local camera = index and Entity(index)

		if (IsValid(camera) and camera:GetClass() == "npc_combine_camera") then
			client.nwCmbCamera = index
		else
			client.nwCmbCamera = nil
		end

		NETWORK.cmbterm.ReleaseCamera(client, true)

		return
	end

	if (action == "camcontrol") then
		local index = tonumber(argument)
		local camera = index and Entity(index)

		if (IsValid(camera) and camera:GetClass() == "npc_combine_camera") then
			client.nwCmbCamera = index
			client.nwCmbControl = index

			camera.nwAimYaw = 0
			camera.nwAimPitch = 0
			camera.nwCurYaw = camera.nwCurYaw or 0
			camera.nwCurPitch = camera.nwCurPitch or 0

			camera:AddEFlags(EFL_NO_THINK_FUNCTION)
			camera:EmitSound("NPC_CombineCamera.Active")
		else

			NETWORK.cmbterm.ReleaseCamera(client)
		end

		return
	end

	if (action == "camaim") then
		local index = client.nwCmbControl
		local camera = index and Entity(index)

		if (!IsValid(camera) or camera:GetClass() != "npc_combine_camera") then
			return
		end

		if ((client.nwNextAim or 0) > CurTime()) then
			return
		end

		client.nwNextAim = CurTime() + 0.1

		local yaw, pitch = string.match(argument, "^(%-?%d+%.?%d*) (%-?%d+%.?%d*)$")

		if (!yaw) then
			return
		end

		camera.nwAimYaw = math.Clamp(tonumber(yaw) or 0, -75, 75)
		camera.nwAimPitch = math.Clamp(tonumber(pitch) or 0, -40, 40)

		return
	end

	if (action == "cammark") then
		local index = client.nwCmbControl
		local camera = index and Entity(index)

		if (!IsValid(camera) or camera:GetClass() != "npc_combine_camera") then
			return
		end

		if ((client.nwNextMark or 0) > CurTime()) then
			return
		end

		client.nwNextMark = CurTime() + 1

		local entry = NETWORK.cmbterm.GetCameraMark(argument)

		if (!entry) then
			return
		end

		local x, y, z = string.match(extra,
			"^(%-?%d+%.?%d*) (%-?%d+%.?%d*) (%-?%d+%.?%d*)$")

		if (!x) then
			return
		end

		local origin = camera:WorldSpaceCenter()
		local position = Vector(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)

		if (position:Distance(origin) > NETWORK.cmbterm.markRange) then
			return Notice(client, "camMarkFar")
		end

		local trace = util.TraceLine({
			start = origin,
			endpos = position,
			filter = camera,
			mask = MASK_SOLID_BRUSHONLY
		})

		if (trace.Hit and trace.HitPos:Distance(position) > 64) then
			position = trace.HitPos
		end

		local bOk, reason = NETWORK.waypoint.Add(client, position, L(entry.name),
			entry.color, entry.time, false, entry.kind, true)

		if (!bOk) then
			return Notice(client, reason or "waypointFull")
		end

		for _, target in ipairs(player.GetAll()) do
			if (NETWORK.factions.IsAlliance(target)) then
				target:EmitSound("buttons/button17.wav", 55, 120, 0.4)
			end
		end

		if (NETWORK.log and NETWORK.log.Add) then
			NETWORK.log.Add(string.format("%s поставил метку «%s» с камеры %d",
				client:GetCharacterName(), L(entry.name), index))
		end

		net.Start("nwCmbMarkDone")
			net.WriteString(entry.id)
		net.Send(client)

		return
	end

	if ((client.nwNextCmb or 0) > CurTime()) then
		return
	end

	client.nwNextCmb = CurTime() + 0.2

	if (hook.Run("NetworkCmbAction", client, action, argument, extra, entity) == true) then
		return
	end

	if (action == "note") then
		local subject = tonumber(extra) or 0

		NETWORK.cmbterm.AddNote(client, subject, argument)
		NETWORK.cmbterm.Sync(client, client.nwCmbPage or "alliance",
			client.nwCmbArgument)

		return
	end

	if (action == "squadcreate") then
		local size = tonumber(extra)
		local bOk, key = NETWORK.squad.Create(client, argument, size)

		Notice(client, key)
		NETWORK.cmbterm.Sync(client, "squads")

		return
	end

	if (action == "squadinvite") then
		local squad = client.GetSquadData and client:GetSquadData()

		if (squad and squad.leader == client:SteamID64()) then
			for _, target in ipairs(player.GetAll()) do
				if (target:SteamID64() == argument and
					target:HasCharacter() and
					NETWORK.squad.CanSee(target, squad)) then
					target:SetNWString("nwSquadInvite", squad.name or "")
					target.nwSquadInviteID = squad.id or squad.name

					Notice(target, "squadInvited")
					Notice(client, "squadInviteSent")

					break
				end
			end
		end

		return
	end

	if (action == "tasktake") then
		local entry = (client.nwTaskList or {})[tonumber(argument) or 0]

		if (!entry) then
			return Notice(client, "cmbBreaksGone")
		end

		if (NETWORK.waypoint and NETWORK.waypoint.Add) then
			local position = Vector(entry.position[1], entry.position[2],
				entry.position[3]) + Vector(0, 0, 32)

			NETWORK.waypoint.Add(client, position, entry.name,
				entry.kind == "maint" and Color(96, 190, 255) or
				Color(240, 186, 74), 900, true)
		end

		Notice(client, "cmbBreaksTaken")

		return
	end

	if (action == "breaktake") then
		local entry = (client.nwBreakList or {})[tonumber(argument) or 0]

		if (!entry) then
			return Notice(client, "cmbBreaksGone")
		end

		local entity = ents.GetByIndex(entry.entity or 0)

		if (!IsValid(entity) or !entity:GetNWBool("nwBroken", false)) then
			return Notice(client, "cmbBreaksGone")
		end

		local owner = entity:GetNWString("nwBreakOwner", "")

		if (owner != "" and owner != client:GetCharacterName()) then
			local bOnline = false

			for _, other in ipairs(player.GetAll()) do
				if (other:HasCharacter() and other:GetCharacterName() == owner) then
					bOnline = true

					break
				end
			end

			if (bOnline) then
				return Notice(client, "cmbBreaksBusy")
			end
		end

		entity:SetNWString("nwBreakOwner", client:GetCharacterName())

		if (NETWORK.waypoint and NETWORK.waypoint.Add) then
			local position = Vector(entry.position[1], entry.position[2],
				entry.position[3]) + Vector(0, 0, 32)

			NETWORK.waypoint.Add(client, position, entry.name,
				Color(240, 186, 74), 900, true)
		end

		Notice(client, "cmbBreaksTaken")

		return
	end

	if (action == "mainttake") then
		local entry = (client.nwMaintList or {})[tonumber(argument) or 0]

		if (!entry) then
			return Notice(client, "cmbBreaksGone")
		end

		if (NETWORK.waypoint and NETWORK.waypoint.Add) then
			local position = Vector(entry.position[1], entry.position[2],
				entry.position[3]) + Vector(0, 0, 32)

			NETWORK.waypoint.Add(client, position, entry.name,
				Color(96, 190, 255), 900, true)
		end

		Notice(client, "cmbBreaksTaken")

		return
	end

	if (action == "squadaccept") then
		local id = client.nwSquadInviteID

		if (id) then
			client.nwSquadInviteID = nil
			client:SetNWString("nwSquadInvite", "")

			local bOk, key = NETWORK.squad.Join(client, tostring(id))

			Notice(client, key or "squadJoined")
			NETWORK.cmbterm.Sync(client, "squads")
		end

		return
	end

	if (action == "squadjoin") then
		local bOk, key = NETWORK.squad.Join(client, argument)

		Notice(client, key)
		NETWORK.cmbterm.Sync(client, "squads")

		return
	end

	if (action == "squadleave") then
		NETWORK.squad.Leave(client)
		NETWORK.cmbterm.Sync(client, "squads")

		return
	end

	if (action == "squaddisband") then
		if (client:IsSquadLeader()) then
			NETWORK.squad.Disband(client:GetSquad())
		end

		NETWORK.cmbterm.Sync(client, "squads")

		return
	end

	if (action == "squadleader") then
		local id = client:GetSquad()

		if (id and client:IsSquadLeader()) then
			for _, member in ipairs(NETWORK.squad.GetMembers(id)) do
				if (member:GetCharacterName() == argument) then
					NETWORK.squad.SetLeader(id, member)

					break
				end
			end
		end

		NETWORK.cmbterm.Sync(client, "squads")

		return
	end

	if (action == "loyalty") then
		local amount = math.Clamp(math.Round(tonumber(extra) or 0), -25, 25)

		for _, target in ipairs(player.GetAll()) do
			local character = target:GetCharacter()

			if (character and NETWORK.terminal.GetCitizenID(character) == argument) then
				NETWORK.loyalty.Add(target, amount, client:GetCharacterName())

				break
			end
		end

		NETWORK.cmbterm.Sync(client, "citizen", argument)

		return
	end

	if (bCWUAccess and !NETWORK.cmbterm.CanUse(client, entity)) then
		local allowed = {
			tasks = true,
			squads = true,
			journal = true,
			breaks = true
		}

		if (!allowed[action]) then
			return
		end
	end

	client.nwCmbPage = action
	client.nwCmbArgument = argument

	if (action != "cameras") then
		client.nwCmbCamera = nil

		NETWORK.cmbterm.ReleaseCamera(client, true)
	end

	NETWORK.cmbterm.Sync(client, action, argument)
end)

hook.Add("SetupPlayerVisibility", "nwCmbCamera", function(client)
	if (!client.nwCmbCamera or !IsValid(client.nwCmbTerminal)) then
		return
	end

	local camera = Entity(client.nwCmbCamera)

	if (IsValid(camera) and camera:GetClass() == "npc_combine_camera") then
		AddOriginToPVS(camera:WorldSpaceCenter())
	else
		client.nwCmbCamera = nil
	end
end)

net.Receive("nwCmbSnap", function(_, client)
	local index = client.nwCmbControl
	local camera = index and Entity(index)

	if (!IsValid(camera) or camera:GetClass() != "npc_combine_camera") then
		return
	end

	if (!NETWORK.cmbterm.CanUse(client, client.nwCmbTerminal)) then
		return
	end

	if ((client.nwNextSnap or 0) > CurTime()) then
		return
	end

	client.nwNextSnap = CurTime() + 0.9

	camera:EmitSound("NPC_CombineCamera.Click")

	local origin = camera:WorldSpaceCenter()
	local receivers = {}

	for _, target in ipairs(player.GetAll()) do
		if (target:GetPos():DistToSqr(origin) < 2000 * 2000) then
			receivers[#receivers + 1] = target
		end
	end

	net.Start("nwCmbFlash")
		net.WriteUInt(camera:EntIndex(), 16)
	net.Send(receivers)
end)

timer.Create("nwCmbCameraTurn", 0.05, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local index = client.nwCmbControl
		local camera = index and Entity(index)

		if (!IsValid(camera) or camera:GetClass() != "npc_combine_camera") then
			continue
		end

		local targetYaw = camera.nwAimYaw or 0
		local targetPitch = camera.nwAimPitch or 0
		local currentYaw = camera.nwCurYaw or 0
		local currentPitch = camera.nwCurPitch or 0
		local speed = 120 * 0.05

		local yawStep = math.Clamp(targetYaw - currentYaw, -speed, speed)
		local pitchStep = math.Clamp(targetPitch - currentPitch, -speed, speed)

		if (math.abs(yawStep) < 0.05 and math.abs(pitchStep) < 0.05) then
			continue
		end

		currentYaw = currentYaw + yawStep
		currentPitch = currentPitch + pitchStep

		camera.nwCurYaw = currentYaw
		camera.nwCurPitch = currentPitch

		local bone = camera:LookupBone("Combine_Camera.bone1") or 0

		camera:ManipulateBoneAngles(bone, Angle(currentPitch * 0.5, -currentYaw, 0))

		if (bone != 0) then

			camera:ManipulateBoneAngles(0, Angle(0, -currentYaw * 0.35, 0))
		end

		if ((camera.nwNextMoveSound or 0) < CurTime() and
			(math.abs(targetYaw - currentYaw) > 5 or math.abs(targetPitch - currentPitch) > 5)) then
			camera.nwNextMoveSound = CurTime() + 0.7

			camera:EmitSound("NPC_CombineCamera.Move")
		end
	end
end)

net.Receive("nwCmbOrder", function(_, client)
	if (!NETWORK.factions.IsAlliance(client)) then
		return
	end

	if ((client.nwNextOrder or 0) > CurTime()) then
		return
	end

	client.nwNextOrder = CurTime() + 5

	local text = NETWORK.util.Sanitise(net.ReadString(), 120)

	if (text == "") then
		return
	end

	for _, target in ipairs(player.GetAll()) do
		if (target:HasCharacter() and NETWORK.factions.IsAlliance(target)) then
			net.Start("nwCmbOrder")
				net.WriteString(text)
				net.WriteString(client:GetCharacterName())
			net.Send(target)
		end
	end
end)

hook.Add("Initialize", "nwCmbTerminal", function()
	NETWORK.cmbterm.Load()
end)

hook.Add("ShutDown", "nwCmbTerminal", function()
	NETWORK.cmbterm.Save()
end)

hook.Add("PlayerDeath", "nwCmbTerminal", function(client)
	NETWORK.cmbterm.Close(client)
end)

hook.Add("PlayerDisconnected", "nwCmbCamera", function(client)
	NETWORK.cmbterm.ReleaseCamera(client, true)
end)
