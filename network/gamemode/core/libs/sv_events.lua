util.AddNetworkString("nwEventAnnounce")
util.AddNetworkString("nwEventDrop")

NETWORK.events = NETWORK.events or {}

local E = NETWORK.events

E.drops = {
	supply = {
		name = "dropSupply",
		container = "supply",
		color = Color(120, 200, 255),
		model = "models/items/item_item_crate.mdl"
	},
	medical = {
		name = "dropMedical",
		container = "locker",
		color = Color(120, 255, 150),
		model = "models/items/item_item_crate.mdl"
	},
	weapons = {
		name = "dropWeapons",
		container = "weapons",
		color = Color(255, 140, 110),
		model = "models/items/ammocrate_smg1.mdl"
	}
}

NETWORK.config.Register("dropInterval", {
	name = "cfgDropInterval",
	description = "cfgDropIntervalDesc",
	category = "world",
	default = 0,
	min = 0,
	max = 240,
	decimals = 0
})

NETWORK.config.Register("zombieChance", {
	name = "cfgZombieChance",
	description = "cfgZombieChanceDesc",
	category = "world",
	default = 0,
	min = 0,
	max = 100,
	decimals = 0
})

function E.Announce(text, color, duration)
	net.Start("nwEventAnnounce")
		net.WriteString(text)
		net.WriteColor(color or Color(226, 190, 120))
		net.WriteFloat(duration or 6)
	net.Broadcast()

	for _, client in ipairs(player.GetAll()) do
		NETWORK.chat.Notice(client, text)
	end
end

local function FindDropPoint()
	local players = player.GetAll()

	if (#players == 0) then
		return
	end

	for _ = 1, 24 do
		local anchor = players[math.random(#players)]

		if (!IsValid(anchor) or !anchor:Alive()) then
			continue
		end

		local angle = math.rad(math.random(360))
		local distance = math.random(600, 1500)
		local ground = anchor:GetPos() + Vector(math.cos(angle) * distance,
			math.sin(angle) * distance, 0)

		local down = util.TraceLine({
			start = ground + Vector(0, 0, 200),
			endpos = ground - Vector(0, 0, 1000),
			mask = MASK_SOLID_BRUSHONLY
		})

		if (!down.Hit) then
			continue
		end

		local up = util.TraceLine({
			start = down.HitPos + Vector(0, 0, 16),
			endpos = down.HitPos + Vector(0, 0, 900),
			mask = MASK_SOLID_BRUSHONLY
		})

		local height = (up.Hit and up.HitPos.z or down.HitPos.z + 900) -
			down.HitPos.z

		if (height < 250) then
			continue
		end

		return down.HitPos + Vector(0, 0, math.min(height - 40, 700)),
			down.HitPos
	end
end

function E.Drop(id)
	local drop = E.drops[id] or E.drops[table.Random(table.GetKeys(E.drops))]
	local origin, ground = FindDropPoint()

	if (!origin) then
		return false
	end

	local crate = ents.Create("nw_container")

	if (!IsValid(crate)) then
		return false
	end

	crate.ContainerType = drop.container
	crate:SetPos(origin)
	crate:SetAngles(Angle(0, math.random(360), 0))
	crate:Spawn()

	local physics = crate:GetPhysicsObject()

	if (IsValid(physics)) then
		physics:Wake()
		physics:SetVelocity(Vector(0, 0, -200))
	end

	crate.nwNoTrim = true

	net.Start("nwEventDrop")
		net.WriteVector(origin)
		net.WriteVector(ground or origin)
		net.WriteColor(drop.color)
	net.Broadcast()

	E.Announce(L("dropIncoming"), drop.color, 7)

	timer.Simple(1200, function()
		if (IsValid(crate) and !crate.nwOpened) then
			crate:Remove()
		end
	end)

	return true
end

function E.SpawnZombie(target, class)
	if (!IsValid(target) or !target:Alive()) then
		return false
	end

	local behind = target:GetPos() - target:GetAngles():Forward() *
		math.random(180, 420)

	local trace = util.TraceHull({
		start = behind + Vector(0, 0, 40),
		endpos = behind + Vector(0, 0, 40),
		mins = Vector(-16, -16, 0),
		maxs = Vector(16, 16, 72),
		filter = target
	})

	if (trace.Hit) then
		return false
	end

	local zombie = ents.Create(class or "npc_zombie")

	if (!IsValid(zombie)) then
		return false
	end

	zombie:SetPos(behind)
	zombie:SetAngles((target:GetPos() - behind):Angle())
	zombie:Spawn()
	zombie:Activate()

	zombie.nwSpawnTime = CurTime()

	timer.Simple(300, function()
		if (IsValid(zombie)) then
			zombie:Remove()
		end
	end)

	return true
end

function E.ZombieWave(count)
	local players = player.GetAll()
	local spawned = 0

	for _ = 1, count or 1 do
		local target = players[math.random(#players)]

		if (IsValid(target) and E.SpawnZombie(target)) then
			spawned = spawned + 1
		end
	end

	return spawned
end

timer.Create("nwEvents", 60, 0, function()
	local interval = NETWORK.config.Get("dropInterval") or 0

	if (interval > 0) then
		E.nextDrop = E.nextDrop or (CurTime() + interval * 60)

		if (CurTime() >= E.nextDrop) then
			E.nextDrop = CurTime() + interval * 60

			E.Drop()
		end
	end

	local chance = NETWORK.config.Get("zombieChance") or 0

	if (chance > 0 and #player.GetAll() > 0 and math.random(100) <= chance) then
		E.ZombieWave(math.random(1, 2))
	end
end)

NETWORK.command.Register("updates", {
	adminOnly = true,
	description = "cmdUpdates",
	usage = "/updates [supply|medical|weapons]",
	OnRun = function(command, client, arguments)
		local id = NETWORK.util.Lower(string.Trim(tostring(arguments[1] or "")))

		if (!E.Drop(E.drops[id] and id or nil)) then
			return NETWORK.notice.Send(client, "dropNoRoom", "warn")
		end

		NETWORK.notice.Send(client, "dropSent", "good")
	end
})

NETWORK.command.Register("zombies", {
	adminOnly = true,
	description = "cmdZombies",
	usage = "/zombies [сколько]",
	OnRun = function(command, client, arguments)
		local count = math.Clamp(tonumber(arguments[1]) or 1, 1, 12)
		local spawned = E.ZombieWave(count)

		NETWORK.notice.Send(client, "zombieSpawned", "good", spawned)
	end
})

NETWORK.command.Register("everyone", {
	adminOnly = true,
	description = "cmdEveryone",
	usage = "/everyone <текст>",
	OnRun = function(command, client, arguments)
		local text = string.Trim(table.concat(arguments, " "))

		if (text == "") then
			return NETWORK.notice.Send(client, "everyoneUsage", "warn")
		end

		E.Announce(NETWORK.util.Sanitise(text, 200), Color(226, 190, 120), 8)
	end
})

local function LookedAtContainer(client)
	local entity = client:GetEyeTrace().Entity

	if (IsValid(entity) and entity:GetClass() == "nw_container" and
		client:GetPos():Distance(entity:GetPos()) < 200) then
		return entity
	end
end

NETWORK.command.Register("updatecon", {
	adminOnly = true,
	description = "cmdUpdateCon",
	usage = "/updatecon — смотреть на контейнер",
	OnRun = function(command, client)
		local entity = LookedAtContainer(client)

		if (!IsValid(entity)) then
			return NETWORK.notice.Send(client, "conNotFound", "warn")
		end

		entity:Rebuild(entity.ContainerType or entity:GetContainerID())

		NETWORK.notice.Send(client, "conUpdated", "good")
	end
})

NETWORK.command.Register("savecon", {
	adminOnly = true,
	description = "cmdSaveCon",
	usage = "/savecon — смотреть на контейнер, либо /savecon all",
	OnRun = function(command, client, arguments)
		local word = NETWORK.util.Lower(string.Trim(tostring(arguments[1] or "")))

		if (word == "all" or word == "все") then
			if (NETWORK.mapents and NETWORK.mapents.Save) then
				NETWORK.mapents.Save()
			end

			return NETWORK.notice.Send(client, "conSavedAll", "good")
		end

		local entity = LookedAtContainer(client)

		if (!IsValid(entity)) then
			return NETWORK.notice.Send(client, "conNotFound", "warn")
		end

		entity.nwPersist = true

		if (NETWORK.mapents and NETWORK.mapents.Save) then
			NETWORK.mapents.Save()
		end

		NETWORK.notice.Send(client, "conSaved", "good")
	end
})
