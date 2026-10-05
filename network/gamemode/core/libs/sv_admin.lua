NETWORK.admin = NETWORK.admin or {}

local function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

local function Find(client, name, bAnyone)
	local target = NETWORK.permission.Find(name)

	if (!IsValid(target)) then
		Notice(client, "permNoTarget")

		return
	end

	if (!bAnyone and !target:HasCharacter()) then
		Notice(client, "adminNoCharacter")

		return
	end

	return target
end

local whitelistPath = "network/whitelist.txt"

NETWORK.admin.storage = NETWORK.admin.storage or {}

function NETWORK.admin.GetWhitelist(steamID)
	if (!steamID or steamID == "") then
		return {}
	end

	NETWORK.admin.storage[steamID] = NETWORK.admin.storage[steamID] or {}

	return NETWORK.admin.storage[steamID]
end

hook.Add("ShutDown", "nwAdminSave", function()
	NETWORK.admin.Save()
end)

function NETWORK.admin.Save()
	local list = {}

	for steamID, factions in pairs(NETWORK.admin.storage) do
		local ids = {}

		for id, bState in pairs(factions) do
			if (bState) then
				ids[#ids + 1] = id
			end
		end

		if (#ids > 0) then
			list[#list + 1] = {steamid = steamID, factions = ids}
		end
	end

	file.CreateDir("network")
	file.Write(whitelistPath, util.TableToJSON({version = 2, list = list}, true))
end

function NETWORK.admin.Load()
	local storage = {}
	local contents = file.Read(whitelistPath, "DATA")
	local data = contents and util.JSONToTable(contents)

	if (istable(data) and istable(data.list)) then
		for _, entry in ipairs(data.list) do
			local steamID = tostring(entry.steamid or "")

			if (steamID != "") then
				local factions = {}

				for _, id in ipairs(entry.factions or {}) do
					factions[tostring(id)] = true
				end

				storage[steamID] = factions
			end
		end
	elseif (istable(data)) then

		for key, factions in pairs(data) do
			local steamID = isnumber(key) and string.format("%.0f", key) or
				tostring(key)

			if (steamID != "" and istable(factions)) then
				local copy = {}

				for id, bState in pairs(factions) do
					if (bState) then
						copy[tostring(id)] = true
					end
				end

				storage[steamID] = copy
			end
		end
	end

	NETWORK.admin.storage = storage
end

util.AddNetworkString("nwWhitelist")
util.AddNetworkString("nwWhitelistRequest")

function NETWORK.admin.Push(client)
	if (!IsValid(client)) then
		return
	end

	local list = {}

	for id, bState in pairs(client.nwWhitelist or {}) do
		if (bState) then
			list[#list + 1] = id
		end
	end

	client:SetNWString("nwWhitelist", table.concat(list, ","))

	net.Start("nwWhitelist")
		net.WriteUInt(#list, 8)

		for _, id in ipairs(list) do
			net.WriteString(id)
		end
	net.Send(client)
end

net.Receive("nwWhitelistRequest", function(length, client)
	NETWORK.admin.Apply(client)
end)

function NETWORK.admin.Apply(client)
	if (!IsValid(client)) then
		return
	end

	client.nwWhitelist = NETWORK.admin.GetWhitelist(client:SteamID64())

	NETWORK.admin.Push(client)
end

function NETWORK.admin.SetWhitelist(client, factionID, bState)
	local factions = NETWORK.admin.GetWhitelist(client:SteamID64())

	factions[factionID] = bState and true or nil

	client.nwWhitelist = factions

	NETWORK.admin.Push(client)
	NETWORK.admin.Save()
end

hook.Add("PlayerInitialSpawn", "nwAdmin", function(client)
	NETWORK.admin.Apply(client)

	timer.Simple(2, function()
		if (IsValid(client)) then
			NETWORK.admin.Apply(client)
		end
	end)
end)

hook.Add("PlayerSpawn", "nwAdminWhitelist", function(client)
	if (client.nwWhitelistPushed) then
		return
	end

	client.nwWhitelistPushed = true

	NETWORK.admin.Apply(client)
end)

hook.Add("Initialize", "nwAdmin", function()
	NETWORK.admin.Load()

	for _, client in ipairs(player.GetAll()) do
		NETWORK.admin.Apply(client)
	end
end)

NETWORK.admin.Load()

hook.Add("NetworkCanUseFaction", "nwWhitelist", function(client, faction)
	if (isstring(faction)) then
		faction = NETWORK.factions.Get(faction)
	end

	if (!faction or !faction.bWhitelist) then
		return
	end

	local factionID = faction.id or faction.uniqueID

	if (client:IsAdmin()) then
		return true
	end

	if (client.nwWhitelist and client.nwWhitelist[factionID]) then
		return true
	end

	local steamID = client:SteamID64()

	if (steamID and (NETWORK.admin.storage[steamID] or {})[factionID]) then
		client.nwWhitelist = NETWORK.admin.storage[steamID]

		return true
	end

	return false
end)

NETWORK.command.Register("savedata", {
	adminOnly = true,
	description = "cmdSaveData",
	usage = "/savedata",
	OnRun = function(command, client)
		local saved, failed = 0, {}

		local function Try(name, callback)
			if (!isfunction(callback)) then
				return
			end

			local bOk, err = pcall(callback)

			if (bOk) then
				saved = saved + 1
			else
				failed[#failed + 1] = name

				ErrorNoHalt("[Network] /saveall: " .. name .. " — " .. tostring(err) .. "\n")
			end
		end

		for _, client in ipairs(player.GetAll()) do
			if (client:HasCharacter() and NETWORK.persistence and NETWORK.persistence.Save) then
				Try("persistence:" .. client:SteamID(), function()
					NETWORK.persistence.Save(client, false)
				end)
			end
		end

		Try("persistence", NETWORK.persistence and NETWORK.persistence.SaveAll)
		Try("entities", NETWORK.entities and NETWORK.entities.Save)
		Try("classes", NETWORK.classes and NETWORK.classes.SaveAll)
		Try("whitelist", NETWORK.admin.Save)
		Try("doors", NETWORK.door and NETWORK.door.Save)
		Try("zones", NETWORK.zone and NETWORK.zone.Save)
		Try("budget", NETWORK.budget and NETWORK.budget.Save)
		Try("cmbterm", NETWORK.cmbterm and NETWORK.cmbterm.Save)
		Try("cwucomputer", NETWORK.admincomp and NETWORK.admincomp.SaveCWU)
		Try("business", NETWORK.business and NETWORK.business.Save)
		Try("config", NETWORK.config and NETWORK.config.Save)
		Try("dialogues", NETWORK.dialogue and NETWORK.dialogue.SaveAll)
		Try("recruiters", NETWORK.recruiter and NETWORK.recruiter.SaveAll)
		Try("spawns", NETWORK.spawns and NETWORK.spawns.Save)
		Try("groups", NETWORK.group and NETWORK.group.Save)
		Try("permissions", NETWORK.permission and NETWORK.permission.Save)
		Try("jail", NETWORK.jail and NETWORK.jail.Save)
		Try("mapents", NETWORK.mapents and NETWORK.mapents.Save)
		Try("playtime", NETWORK.playtime and NETWORK.playtime.Save)
		Try("welcome", NETWORK.welcome and NETWORK.welcome.Save)
		Try("icons", NETWORK.icon and NETWORK.icon.Save)
		Try("cutscenes", NETWORK.cutscene and NETWORK.cutscene.Save)
		Try("fabricator", NETWORK.fabricator and NETWORK.fabricator.SavePool)
		Try("quests", NETWORK.quest and NETWORK.quest.SaveCooldowns)

		hook.Run("NetworkSaveAll", client)

		if (#failed > 0) then
			Notice(client, L("saveDataPartial", saved, table.concat(failed, ", ")))
		else
			Notice(client, L("saveDataDone", saved))
		end
	end
})

NETWORK.command.Register("whitelistcheck", {
	adminOnly = true,
	description = "cmdWhitelistCheck",
	usage = "/whitelistcheck [игрок]",
	OnRun = function(command, client, arguments)
		local target = arguments[1] and Find(client, arguments[1], true) or client

		if (!IsValid(target)) then
			return
		end

		local steamID = target:SteamID64()
		local stored = NETWORK.admin.storage[steamID]
		local live = target.nwWhitelist

		NETWORK.util.Print("Вайтлист " .. target:SteamName() .. " (" ..
			tostring(steamID) .. ")")
		NETWORK.util.Print("  на диске: " ..
			(stored and table.concat(table.GetKeys(stored), ", ") or "нет записи"))
		NETWORK.util.Print("  в памяти игрока: " ..
			(live and table.concat(table.GetKeys(live), ", ") or "нет"))
		NETWORK.util.Print("  отправлено клиенту: " ..
			target:GetNWString("nwWhitelist", "(пусто)"))
	end
})

NETWORK.command.Register("whitelist", {
	adminOnly = true,
	description = "cmdWhitelist",
	usage = "/whitelist <игрок> <фракция> [on/off]",
	OnRun = function(command, client, arguments)
		local target = Find(client, arguments[1], true)

		if (!target) then
			return
		end

		local faction = NETWORK.factions.Find(arguments[2])

		if (!faction) then
			return Notice(client, "adminNoFaction")
		end

		local factionID = faction.id

		local explicit = string.lower(arguments[3] or "")
		local bState

		if (explicit == "on" or explicit == "1" or explicit == "да" or explicit == "+") then
			bState = true
		elseif (explicit == "off" or explicit == "0" or explicit == "нет" or explicit == "-") then
			bState = false
		else
			bState = !(target.nwWhitelist and target.nwWhitelist[factionID])
		end

		NETWORK.admin.SetWhitelist(target, factionID, bState)

		Notice(client, L(bState and "adminWhitelistOnFor" or "adminWhitelistOffFor",
			target:SteamName(), L(faction.name), factionID))
		Notice(target, bState and "adminWhitelistOn" or "adminWhitelistOff")
	end
})

NETWORK.command.Register("setfaction", {
	adminOnly = true,
	description = "cmdSetfaction",
	usage = "/setfaction <игрок> <фракция>",
	OnRun = function(command, client, arguments)
		local target = Find(client, arguments[1])

		if (!target) then
			return
		end

		local faction = NETWORK.factions.Find(arguments[2])

		if (!faction) then
			return Notice(client, "adminNoFaction")
		end

		local factionID = faction.id

		local character = target:GetCharacter()

		if (faction.bWhitelist) then
			NETWORK.admin.SetWhitelist(target, factionID, true)
		end

		if (NETWORK.business and NETWORK.business.Revoke and
			(faction.bCombine or factionID == "cp" or factionID == "cmb")) then
			NETWORK.business.Revoke(target, "businessLostFaction")
		end

		if (NETWORK.classes and character) then
			NETWORK.classes.assigned = NETWORK.classes.assigned or {}
			NETWORK.classes.assigned[tostring(character:GetID())] = nil

			NETWORK.classes.SaveAll()

			target:SetNWString("nwClass", "")
			target:SetNWString("nwCallsign", "")
			target:SetModelScale(1, 0)
			target:SetMaxArmor(100)
			target:SetArmor(0)
		end

		if (character.SetData) then
			character:SetData("modelForced", nil)
		end

		local models = faction.models or {}
		local fields = NETWORK.factions.Transfer(target, character, faction) or {}

		fields.faction = factionID
		fields.model = factionID == "worker" and character:GetModel() or
			(fields.model or (#models > 0 and models[math.random(#models)]) or character:GetModel())
		fields.modelforced = 0
		if (factionID == "worker") then
			NETWORK.classes.assigned[tostring(character:GetID())] = {id = "cwu_employee"}
			NETWORK.classes.SaveAll()
		end

		NETWORK.character.Update(character, fields)
		NETWORK.character.Refresh(target)

		target:Spawn()

		timer.Simple(0.1, function()
			if (!IsValid(target)) then
				return
			end

			NETWORK.anim.Refresh(target)
			NETWORK.inventory.RefreshAppearance(target)
			NETWORK.character.Refresh(target)
		end)

		Notice(client, "adminDone")
		Notice(target, "adminFactionChanged")
	end
})

NETWORK.command.Register("setsize", {
	adminOnly = true,
	description = "cmdSetSize",
	usage = "/setsize <игрок> <множитель>",
	aliases = {"setscale"},
	OnRun = function(command, client, arguments)
		local target = Find(client, arguments[1])

		if (!target) then
			return
		end

		local scale = math.Clamp(tonumber(arguments[2]) or 1, 0.4, 3)

		target.nwScaleOverride = scale != 1 and scale or nil

		NETWORK.player.ApplyScale(target)

		Notice(client, L("adminSizeSet", target:GetCharacterName(),
			string.format("%.2f", scale)))
		Notice(target, L("adminSizeChanged", string.format("%.2f", scale)))
	end
})

NETWORK.command.Register("setname", {
	adminOnly = true,
	description = "cmdSetname",
	usage = "/setname <игрок> <новое имя>",
	OnRun = function(command, client, arguments)
		local target = Find(client, arguments[1])

		if (!target) then
			return
		end

		table.remove(arguments, 1)

		local name = NETWORK.util.Sanitise(table.concat(arguments, " "),
			NETWORK.creation.nameMax * 2)

		if (NETWORK.util.Length(name) < NETWORK.creation.nameMin) then
			return Notice(client, "errNameShort")
		end

		local character = target:GetCharacter()

		if (!character) then
			return Notice(client, "adminNoTarget")
		end

		NETWORK.character.Update(character, {name = name, surname = ""})

		if (target:GetNWString("nwCallsign", "") != "") then
			local entry = NETWORK.classes and NETWORK.classes.GetEntry and
				NETWORK.classes.GetEntry(character)

			if (entry) then
				entry.callsign = name

				local assigned = NETWORK.classes.assigned or {}

				assigned[tostring(character:GetID())] = entry

				NETWORK.classes.assigned = assigned

				NETWORK.classes.SaveAll()
			end

			target:SetNWString("nwCallsign", name)
		end

		NETWORK.character.Refresh(target)

		Notice(client, "adminDone")
	end
})

NETWORK.command.Register("setmodel", {
	adminOnly = true,
	description = "cmdSetmodel",
	usage = "/setmodel <игрок> <путь к модели>",
	OnRun = function(command, client, arguments)
		local target = Find(client, arguments[1])

		if (!target) then
			return
		end

		local model = string.lower(arguments[2] or "")
		local character = target:GetCharacter()

		if (model == "clear" or model == "auto") then
			NETWORK.character.Update(character, {modelforced = 0})
			target.nwBodygroups = nil
			NETWORK.inventory.RefreshAppearance(target)
			NETWORK.character.Refresh(target)

			return Notice(client, "adminDone")
		end

		if (!util.IsValidModel(model)) then
			return Notice(client, "adminNoModel")
		end

		NETWORK.character.Update(character, {model = model, modelforced = 1})

		target.nwBodygroups = nil

		NETWORK.inventory.RefreshAppearance(target)
		NETWORK.anim.Refresh(target)
		NETWORK.character.Refresh(target)

		Notice(client, "adminDone")
	end
})

NETWORK.command.Register("setskin", {
	adminOnly = true,
	description = "cmdSetskin",
	usage = "/setskin <игрок> <номер>",
	example = "/setskin Ivan 2",
	OnRun = function(command, client, arguments)
		local target = Find(client, arguments[1])

		if (!target) then
			return
		end

		local skin = math.max(math.Round(tonumber(arguments[2]) or 0), 0)
		local count = target:SkinCount() or 1

		if (skin >= count) then
			return Notice(client, "adminSkinRange", count - 1)
		end

		NETWORK.character.Update(target:GetCharacter(), {skin = skin})

		target.nwSkin = skin

		target:SetSkin(skin)

		NETWORK.inventory.RefreshAppearance(target)

		Notice(client, "adminDone")
	end
})

NETWORK.command.Register("setdesc", {
	adminOnly = true,
	description = "cmdSetdesc",
	usage = "/setdesc <игрок> <описание>",
	OnRun = function(command, client, arguments)
		local target = Find(client, arguments[1])

		if (!target) then
			return
		end

		table.remove(arguments, 1)

		local description = NETWORK.util.Sanitise(table.concat(arguments, " "),
			NETWORK.creation.descriptionMax, true)

		NETWORK.character.Update(target:GetCharacter(), {description = description})
		NETWORK.character.Refresh(target)

		Notice(client, "adminDone")
	end
})

NETWORK.command.Register("givetokens", {
	adminOnly = true,
	description = "cmdGiveTokens",
	usage = "/givetokens <игрок> <сумма>",
	aliases = {"tokens"},
	OnRun = function(command, client, arguments)
		local target = Find(client, arguments[1])

		if (!target) then
			return
		end

		local amount = math.Clamp(math.Round(tonumber(arguments[2]) or 0), -100000, 100000)

		NETWORK.currency.Add(target, amount)

		Notice(client, "adminDone")
		Notice(target, amount >= 0 and "tokensReceived" or "tokensTaken")
	end
})

util.AddNetworkString("nwBodygroupEdit")

local function CanEditAppearance(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	if (client:IsAdmin()) then
		return true
	end

	return IsValid(client.nwLocker) and (client.nwLockerUntil or 0) > CurTime() and
		client:GetPos():Distance(client.nwLocker:GetPos()) <= client.nwLocker.Range
end

net.Receive("nwBodygroupEdit", function(_, client)
	if (!CanEditAppearance(client)) then
		return
	end

	local payload = NETWORK.util.ReadTable()
	local character = client:GetCharacter()
	local groups = {}

	for index, value in pairs(payload.groups or {}) do
		local id = tonumber(index)

		if (id) then
			groups[id] = math.Round(tonumber(value) or 0)
		end
	end

	client.nwBodygroups = groups
	client.nwSkin = math.Round(tonumber(payload.skin) or 0)

	NETWORK.character.Update(character, {
		bodygroups = util.TableToJSON(groups),
		skin = client.nwSkin
	})

	character.bodygroups = groups
	character.skin = client.nwSkin

	NETWORK.inventory.RefreshAppearance(client)
end)

NETWORK.command.Register("editbg", {
	adminOnly = true,
	description = "cmdEditbg",
	usage = "/editbg",
	OnRun = function(command, client)
		net.Start("nwBodygroupEdit")
			NETWORK.util.WriteTable({bOpen = true})
		net.Send(client)
	end
})

util.AddNetworkString("nwSetDescription")

net.Receive("nwSetDescription", function(_, client)
	if (!client:HasCharacter()) then
		return
	end

	local text = NETWORK.util.Sanitise(net.ReadString(),
		NETWORK.creation.descriptionMax, true)

	if ((client.nwNextDescription or 0) > CurTime()) then
		return Notice(client, "chatWait",
			math.ceil(client.nwNextDescription - CurTime()))
	end

	client.nwNextDescription = CurTime() + 5

	local bValid, key, first = NETWORK.creation.ValidateDescription(text)

	if (!bValid) then
		return Notice(client, key or "errDescriptionShort", first)
	end

	local character = client:GetCharacter()

	NETWORK.character.Update(character, {description = text})

	character.description = text

	NETWORK.character.Refresh(client)

	Notice(client, "descEditSaved")
end)

util.AddNetworkString("nwCommandHelp")

NETWORK.command.Register("commandhelp", {
	description = "cmdCommandhelp",
	usage = "/commandhelp",
	adminOnly = true,
	OnRun = function(command, client)
		local list = {}

		for _, data in ipairs(NETWORK.command.GetAll()) do
			list[#list + 1] = {
				id = data.id,
				usage = data.usage or ("/" .. data.id),
				description = data.description or "",
				example = data.example or "",
				bAdmin = data.adminOnly or false
			}
		end

		net.Start("nwCommandHelp")
			NETWORK.util.WriteTable(list)
		net.Send(client)
	end
})

NETWORK.command.Register("nwents", {
	adminOnly = true,
	description = "cmdNwents",
	usage = "/nwents [радиус]",
	OnRun = function(command, client, arguments)
		local radius = math.Clamp(tonumber(arguments[1]) or 400, 50, 4000)
		local count = 0

		for _, entity in ipairs(ents.FindInSphere(client:GetPos(), radius)) do
			local class = entity:GetClass()

			if (string.sub(class, 1, 3) != "nw_") then
				continue
			end

			count = count + 1

			local model = entity:GetModel() or ""

			NETWORK.chat.Notice(client, string.format("%s  %s  [%s]  %s  %s", class,
				model != "" and model or "(без модели)",
				util.IsValidModel(model) and "ok" or "НЕВЕРНАЯ",
				tostring(entity:GetPos()), entity:GetNoDraw() and "NODRAW" or ""))
		end

		NETWORK.chat.Notice(client, "nwents: " .. count .. " (радиус " .. radius .. ")")
	end
})

NETWORK.command.Register("itembg", {
	adminOnly = true,
	description = "cmdItembg",
	usage = "/itembg <игрок> <слот> <группа> <значение>",
	aliases = {"itembodygroup"},
	OnRun = function(command, client, arguments)
		local target = NETWORK.permission.Find(arguments[1])

		if (!IsValid(target) or !target:HasCharacter()) then
			return NETWORK.chat.Notice(client, "permNoTarget")
		end

		local state = NETWORK.inventory.GetState(target)
		local slot = arguments[2]

		if (!slot or !istable(state.equipped[slot])) then
			local names = {}

			for key, item in pairs(state.equipped) do
				if (istable(item)) then
					names[#names + 1] = key .. " = " .. NETWORK.item.GetName(item)
				end
			end

			return NETWORK.notice.Send(client, "itembgSlots", "info",
				#names > 0 and table.concat(names, ", ") or "-")
		end

		local group = math.Round(tonumber(arguments[3]) or -1)
		local value = math.Round(tonumber(arguments[4]) or 0)
		local count = target:GetBodygroupCount(group)

		if (group < 0 or !count or count <= 1) then
			return NETWORK.notice.Send(client, "itemBodygroupNone", "warn")
		end

		local item = state.equipped[slot]

		item.data = item.data or {}
		item.data.bodygroups = item.data.bodygroups or {}
		item.data.bodygroups[tostring(group)] = math.Clamp(value, 0, count - 1)

		NETWORK.inventory.RefreshAppearance(target)
		NETWORK.inventory.Sync(target)
		NETWORK.notice.Send(client, "itemBodygroupSet", "good", group,
			item.data.bodygroups[tostring(group)])
	end
})
