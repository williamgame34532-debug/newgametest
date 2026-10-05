local dataPath = "network/classes.txt"

local function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

function NETWORK.classes.SaveAll()
	file.CreateDir("network")

	local data = util.TableToJSON(NETWORK.classes.assigned or {}, true)

	if (!data or data == "") then
		return
	end

	file.Write(dataPath, data)

	NETWORK.classes.bDirty = false
end

function NETWORK.classes.LoadAll()
	local raw = file.Read(dataPath, "DATA")

	local data = raw and util.JSONToTable(raw) or {}

	local assigned = {}

	for key, entry in pairs(istable(data) and data or {}) do
		assigned[tostring(key)] = entry
	end

	NETWORK.classes.assigned = assigned
end

hook.Add("Initialize", "nwClassLoad", function()
	NETWORK.classes.LoadAll()
end)

hook.Add("NetworkPersistenceCollect", "nwClass", function(client, data)
	local character = client:GetCharacter()

	if (!character) then
		return
	end

	data.class = NETWORK.classes.GetEntry(character)
end)

hook.Add("NetworkPersistenceRestore", "nwClass", function(client, data)
	local character = client:GetCharacter()

	if (!character or !istable(data) or !istable(data.class)) then
		return
	end

	local key = tostring(character:GetID())

	NETWORK.classes.assigned = NETWORK.classes.assigned or {}

	if (NETWORK.classes.assigned[key]) then
		return
	end

	local class = NETWORK.classes.Get(data.class.id)

	if (!class or class.faction != character:GetFaction()) then
		return
	end

	NETWORK.classes.assigned[key] = {
		id = data.class.id,
		callsign = data.class.callsign
	}

	NETWORK.classes.bDirty = true

	NETWORK.util.Print(string.format("[КЛАСС] персонажу #%s возвращён класс %s",
		key, tostring(data.class.id)))
end)

hook.Add("NetworkCharacterLoaded", "nwClassRestore", function(client, character)
	for _, delay in ipairs({0.6, 1.5, 3}) do
		timer.Simple(delay, function()
			if (!IsValid(client) or !client:HasCharacter() or
				client:GetCharacter() != character) then
				return
			end

			if (NETWORK.classes.GetAssigned(character)) then
				NETWORK.classes.Apply(client, character)
			end
		end)
	end
end)

function NETWORK.classes.GetEntry(character)
	if (!character) then
		return
	end

	local entry = (NETWORK.classes.assigned or {})[tostring(character:GetID())]

	if (istable(entry)) then
		return entry
	end

	return entry and {id = entry} or nil
end

function NETWORK.classes.GetAssigned(character)
	local entry = NETWORK.classes.GetEntry(character)

	return entry and NETWORK.classes.Get(entry.id)
end

function NETWORK.classes.ResolveModel(class)
	if (!class) then
		return
	end

	local model = class.model

	if (class.modelConfig and NETWORK.config and NETWORK.config.Get) then
		local configured = NETWORK.config.Get(class.modelConfig)

		if (isstring(configured) and configured != "") then
			model = configured
		end
	end

	return model
end

function NETWORK.classes.Apply(client, character)
	character = character or client:GetCharacter()

	if (!character) then
		return
	end

	local class = NETWORK.classes.GetAssigned(character)

	if (!class or class.faction != character:GetFaction()) then
		client:SetNWString("nwClass", "")
		client:SetNWString("nwCallsign", "")

		return
	end

	client:SetNWString("nwClass", class.id)

	local entry = NETWORK.classes.GetEntry(character)

	client:SetNWString("nwCallsign", entry and entry.callsign or "")

	local classModel = NETWORK.classes.ResolveModel(class)
	local bForced = character.IsModelForced and character:IsModelForced()

	if (!bForced and classModel and !util.IsValidModel(classModel) and !client.nwClassModelWarned) then
		client.nwClassModelWarned = true

		Notice(client, "classModelMissing")

		ErrorNoHalt("[Network] Модель класса " .. tostring(class.id) .. " не найдена: " ..
			tostring(classModel) .. "\n")
	end

	NETWORK.inventory.RefreshAppearance(client)

	NETWORK.player.ApplyScale(client)

	if (class.health) then
		client:SetMaxHealth(class.health)
		client:SetHealth(class.health)
	end

	if (class.armor) then

		client:SetMaxArmor(math.max(class.armor, 100))
		client:SetArmor(class.armor)
	end

	NETWORK.movement.Apply(client)
	NETWORK.anim.Refresh(client)

	NETWORK.inventory.RefreshWeapons(client)

	if (class.id == "wallhammer") then
		Notice(client, "shieldBindHint")
	end
end

hook.Add("PlayerSpawn", "nwClassRespawn", function(client)
	timer.Simple(0.5, function()
		if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
			return
		end

		if (NETWORK.classes.GetAssigned(client:GetCharacter())) then
			NETWORK.classes.Apply(client)
		end
	end)
end)

timer.Create("nwClassSave", 300, 0, function()
	if (NETWORK.classes.bDirty) then
		NETWORK.classes.bDirty = false

		NETWORK.classes.SaveAll()
	end
end)

hook.Add("NetworkPlayerLoadout", "nwClassApply", function(client, character)
	if (!NETWORK.classes.GetAssigned(character)) then

		client:SetNWString("nwCallsign", "")

		return
	end

	timer.Simple(0.2, function()
		if (IsValid(client) and client:Alive() and
			client:GetCharacter() == character) then
			NETWORK.classes.Apply(client, character)
		end
	end)
end)

NETWORK.command.Register("setclass", {
	adminOnly = true,
	description = "cmdSetclass",
	usage = "/setclass <игрок> <класс|clear>",
	OnRun = function(command, client, arguments)
		local target = NETWORK.permission.Find(arguments[1] or "")

		if (!IsValid(target)) then
			return Notice(client, "permNoTarget")
		end

		if (!target:HasCharacter()) then
			return Notice(client, "adminNoCharacter")
		end

		local character = target:GetCharacter()
		local id = string.lower(arguments[2] or "")

		NETWORK.classes.assigned = NETWORK.classes.assigned or {}

		if (id == "" or id == "clear") then
			local old = NETWORK.classes.GetAssigned(character)

			for _, weaponClass in ipairs(old and old.weapons or {}) do
				target:StripWeapon(weaponClass)
			end

			NETWORK.classes.assigned[tostring(character:GetID())] = nil

			target:SetNWString("nwCallsign", "")

			NETWORK.classes.SaveAll()

			target:SetNWString("nwClass", "")
			target:SetMaxHealth(100)
			target:SetHealth(math.min(target:Health(), 100))
			target:SetMaxArmor(100)
			target:SetArmor(0)
			NETWORK.player.ApplyScale(target)

			NETWORK.movement.Apply(target)
			NETWORK.inventory.RefreshAppearance(target)
			NETWORK.inventory.RefreshWeapons(target)
			NETWORK.character.Refresh(target)

			return Notice(client, "classCleared")
		end

		local class = NETWORK.classes.Get(id)

		if (!class) then
			return Notice(client, "classUnknown")
		end

		if (class.faction != character:GetFaction()) then
			return Notice(client, "classWrongFaction")
		end

		local entry = {id = class.id}

		if (class.callsign) then
			local pattern = class.callsign

			if (class.callsignConfig and NETWORK.config and NETWORK.config.Get) then
				local configured = NETWORK.config.Get(class.callsignConfig)

				if (isstring(configured) and configured != "") then
					pattern = configured
				end
			end

			if (!string.find(pattern, "%%%d*d")) then
				pattern = pattern .. "%03d"
			end

			local bOk, formatted = pcall(string.format, pattern,
				math.random(0, class.callsignMax or 9999))

			entry.callsign = bOk and formatted or (class.callsign and
				string.format(class.callsign, math.random(0, class.callsignMax or 9999)) or "")
		end

		NETWORK.classes.assigned[tostring(character:GetID())] = entry

		target:SetNWString("nwCallsign", entry.callsign or "")

		NETWORK.classes.SaveAll()
		NETWORK.classes.Apply(target, character)

		if (istable(class.items)) then
			local state = NETWORK.inventory.GetState(target)

			for _, id in ipairs(class.items) do
				local bOwned = false

				for _, list in ipairs({state.items, state.equipped}) do
					for _, item in pairs(list) do
						if (istable(item) and item.id == id) then
							bOwned = true

							break
						end
					end
				end

				if (!bOwned and !NETWORK.inventory.Give(target, id, 1)) then
					NETWORK.item.Spawn(id, target:GetPos() + Vector(0, 0, 40), nil, 1)
				end
			end

			NETWORK.inventory.Sync(target)
		end

		hook.Run("NetworkClassAssigned", target, class, character)

		Notice(client, "classAssigned")

		if (target != client) then
			Notice(target, "classReceived")
		end
	end
})
