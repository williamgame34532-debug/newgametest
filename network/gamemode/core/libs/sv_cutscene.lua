util.AddNetworkString("nwCutscenePlay")
util.AddNetworkString("nwCutsceneStop")

local PATH = "network/cutscenes"

local function Notice(client, text)
	NETWORK.chat.Notice(client, text)
end

local function File()
	return PATH .. "/" .. game.GetMap() .. ".json"
end

function NETWORK.cutscene.Save()
	file.CreateDir(PATH)
	file.Write(File(), util.TableToJSON(NETWORK.cutscene.stored))
end

function NETWORK.cutscene.Load()
	local data = file.Read(File(), "DATA")

	if (!data) then
		return
	end

	NETWORK.cutscene.stored = util.JSONToTable(data) or {}
end

hook.Add("Initialize", "nwCutscene", function()
	NETWORK.cutscene.Load()
end)

function NETWORK.cutscene.Play(scene, targets)
	if (!scene or #(scene.shots or {}) == 0) then
		return false
	end

	targets = targets or player.GetAll()

	net.Start("nwCutscenePlay")
		NETWORK.util.WriteTable(scene)
	net.Send(targets)

	local length = NETWORK.cutscene.GetLength(scene)

	for _, client in ipairs(targets) do
		client:Freeze(true)

		timer.Simple(length, function()
			if (IsValid(client)) then
				client:Freeze(false)
			end
		end)
	end

	return true
end

timer.Create("nwCutsceneZones", 1, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (!client:Alive() or !client:HasCharacter()) then
			continue
		end

		local zone = NETWORK.zone.AtEntity(client)

		if (!zone or !zone.cutscene or zone.cutscene == "") then
			continue
		end

		client.nwSeenScenes = client.nwSeenScenes or {}

		if (client.nwSeenScenes[zone.cutscene]) then
			continue
		end

		client.nwSeenScenes[zone.cutscene] = true

		NETWORK.cutscene.Play(NETWORK.cutscene.Get(zone.cutscene), {client})
	end
end)

NETWORK.command.Register("cutzone", {
	adminOnly = true,
	description = "cmdCutZone",
	usage = "/cutzone <идентификатор сцены | -> ",
	example = "/cutzone convoy",
	OnRun = function(command, client, arguments)

		local zone = NETWORK.zone.At(client:GetPos())

		if (!zone) then
			return Notice(client, "cutNoZone")
		end

		local id = string.lower(arguments[1] or "")

		if (id == "-" or id == "") then
			zone.cutscene = nil

			NETWORK.zone.Set(zone)

			return Notice(client, "cutZoneCleared")
		end

		if (!NETWORK.cutscene.Get(id)) then
			return Notice(client, "cutNoScene")
		end

		zone.cutscene = id

		NETWORK.zone.Set(zone)

		Notice(client, "cutZoneSet")
	end
})

NETWORK.command.Register("cutnew", {
	adminOnly = true,
	description = "cmdCutNew",
	usage = "/cutnew <идентификатор>",
	example = "/cutnew convoy",
	OnRun = function(command, client, arguments)
		local id = string.lower(NETWORK.util.Sanitise(arguments[1] or "", 24))

		if (id == "") then
			return Notice(client, "cutNoName")
		end

		if (table.Count(NETWORK.cutscene.stored) >=
			NETWORK.cutscene.maxScenes) then
			return Notice(client, "cutTooMany")
		end

		NETWORK.cutscene.stored[id] = {id = id, shots = {}}

		NETWORK.cutscene.Save()

		Notice(client, "cutCreated")
	end
})

NETWORK.command.Register("cutshot", {
	adminOnly = true,
	description = "cmdCutShot",
	usage = "/cutshot <идентификатор> [перелёт] [выдержка] [подпись]",
	example = "/cutshot convoy 3 2 Конвой входит в сектор",
	OnRun = function(command, client, arguments)
		local scene = NETWORK.cutscene.Get(arguments[1])

		if (!scene) then
			return Notice(client, "cutNoScene")
		end

		if (#scene.shots >= NETWORK.cutscene.maxShots) then
			return Notice(client, "cutTooManyShots")
		end

		local position = client:EyePos()
		local angles = client:EyeAngles()

		local caption = table.concat(arguments, " ", 4)

		scene.shots[#scene.shots + 1] = {
			pos = {position.x, position.y, position.z},
			ang = {angles.p, angles.y, angles.r},
			fov = 75,
			travel = math.Clamp(tonumber(arguments[2]) or 2, 0, 20),
			hold = math.Clamp(tonumber(arguments[3]) or 1.5, 0, 20),
			text = NETWORK.util.Sanitise(caption, 120)
		}

		NETWORK.cutscene.Save()

		Notice(client, "cutShotAdded")
	end
})

NETWORK.command.Register("cutplay", {
	adminOnly = true,
	description = "cmdCutPlay",
	usage = "/cutplay <идентификатор> [all]",
	example = "/cutplay convoy all",
	OnRun = function(command, client, arguments)
		local scene = NETWORK.cutscene.Get(arguments[1])

		if (!scene) then
			return Notice(client, "cutNoScene")
		end

		local bAll = string.lower(arguments[2] or "") == "all"

		NETWORK.cutscene.Play(scene, bAll and player.GetAll() or {client})
	end
})

NETWORK.command.Register("cutdrop", {
	adminOnly = true,
	description = "cmdCutDrop",
	usage = "/cutdrop <идентификатор> [номер кадра]",
	example = "/cutdrop convoy 2",
	OnRun = function(command, client, arguments)
		local scene = NETWORK.cutscene.Get(arguments[1])

		if (!scene) then
			return Notice(client, "cutNoScene")
		end

		local index = tonumber(arguments[2])

		if (index) then
			table.remove(scene.shots, math.Round(index))
		else
			NETWORK.cutscene.stored[string.lower(arguments[1])] = nil
		end

		NETWORK.cutscene.Save()

		Notice(client, "cutDropped")
	end
})

NETWORK.command.Register("cutlist", {
	adminOnly = true,
	description = "cmdCutList",
	usage = "/cutlist",
	OnRun = function(command, client)
		for id, scene in pairs(NETWORK.cutscene.stored) do
			NETWORK.chat.Notice(client, string.format("%s — кадров: %d (%.1f с)",
				id, #scene.shots, NETWORK.cutscene.GetLength(scene)))
		end
	end
})
