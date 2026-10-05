NETWORK.rebels = NETWORK.rebels or {}

local R = NETWORK.rebels

R.baseClasses = {rebel = true}
R.classes = R.classes or {rebel = true}

function R.SetClasses(text)
	local list = {}

	for id in pairs(R.baseClasses) do
		list[id] = true
	end

	for _, part in ipairs(string.Explode(",", tostring(text or ""))) do
		local id = string.lower(string.Trim(part))

		if (id != "") then
			list[id] = true
		end
	end

	R.classes = list
end

function R.IsClass(id)
	return R.classes[string.lower(tostring(id or ""))] == true
end

function R.Is(client)
	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
		return false
	end

	if (NETWORK.factions.IsAlliance(client)) then
		return false
	end

	local id = client:GetNWString("nwClass", "")

	if (id == "" and SERVER and NETWORK.classes and NETWORK.classes.GetAssigned) then
		local class = NETWORK.classes.GetAssigned(client:GetCharacter())

		id = class and class.id or ""
	end

	return R.IsClass(id)
end

NETWORK.config.Register("rebelClasses", {
	name = "cfgRebelClasses",
	description = "cfgRebelClassesDesc",
	category = "characters",
	type = "string",
	default = "rebel",
	OnChanged = function(value)
		R.SetClasses(value)
	end
})

R.color = Color(206, 146, 84)
R.jamColor = Color(150, 132, 112)
R.interceptColor = Color(214, 120, 86)

R.sabotage = {
	range = 110,
	holdTime = 0.6,
	timeKit = 6,
	timeHands = 10,
	durationKit = {240, 300},
	durationHands = {180, 220},
	kitConsumeChance = 50,
	dispatchChance = 50,
	moveTolerance = 26,
	cooldown = 20,
	reuseDelay = 120,
	kit = "sabotage_kit"
}

R.kindNames = {
	turret = "rebelKindTurret",
	scanner = "rebelKindScanner",
	field = "rebelKindField",
	lock = "rebelKindLock",
	terminal = "rebelKindTerminal",
	dispenser = "rebelKindDispenser"
}

function R.IsSabotaged(entity)
	return IsValid(entity) and entity:GetNWBool("nwSabotaged", false)
end

function R.IsAllianceDevice(entity)
	local id = entity:GetNWString("nwDeploy", "")

	if (id == "") then
		return true
	end

	local data = NETWORK.deploy and NETWORK.deploy.Get and NETWORK.deploy.Get(id)

	if (data and (data.classes or data.CanControl)) then
		return false
	end

	local owner = entity:GetNWEntity("nwDeployOwner", NULL)

	if (IsValid(owner) and owner:IsPlayer() and owner:HasCharacter() and
		!NETWORK.factions.IsAlliance(owner)) then
		return false
	end

	return true
end

function R.Classify(entity)
	if (!IsValid(entity) or entity:IsPlayer() or R.IsSabotaged(entity)) then
		return
	end

	local class = entity:GetClass()

	if (class == "npc_turret_floor" or class == "npc_turret_ceiling") then
		return R.IsAllianceDevice(entity) and "turret" or nil
	end

	if (class == "npc_cscanner") then
		return (entity:GetNWString("nwDeploy", "") != "" and R.IsAllianceDevice(entity)) and
			"scanner" or nil
	end

	if (class == "nw_scanner") then
		return "scanner"
	end

	if (class == "nw_forcefield") then
		return (entity.IsWorking and entity:IsWorking()) and "field" or nil
	end

	if (class == "nw_lock") then
		if (!entity.GetLocked or !entity:GetLocked()) then
			return
		end

		if (SERVER and entity.nwHacked) then
			return
		end

		return "lock"
	end

	if (class == "nw_cmbterminal") then
		return !entity:GetNWBool("nwBroken", false) and "terminal" or nil
	end

	if (class == "nw_dispenser") then
		return (entity.GetEnabled and entity:GetEnabled()) and "dispenser" or nil
	end
end

function R.FindSabotageTarget(client)
	local entity = NETWORK.util.FindLookedAt(client, R.sabotage.range, function(candidate)
		return R.Classify(candidate) != nil
	end)

	if (!IsValid(entity)) then
		return
	end

	return entity, R.Classify(entity)
end

R.graffiti = {
	perCharacter = 3,
	mapLimit = 60,
	sprayTime = 5,
	cleanTime = 5,
	range = 96,
	spacing = 40,
	rewardTokens = 5,
	rewardLoyalty = 1,
	freshTime = 60,
	chancePer = 0.15,
	chanceMax = 0.6,
	spray = "spray_lambda"
}

R.graffiti.reasons = {
	factory = true,
	supply = true,
	work = true,
	ration = true
}

R.slogans = {
	"rebelSlogan1",
	"rebelSlogan2",
	"rebelSlogan3",
	"rebelSlogan4",
	"rebelSlogan5",
	"rebelSlogan6"
}

R.tints = {
	Color(226, 128, 52),
	Color(206, 58, 46),
	Color(228, 226, 214),
	Color(232, 196, 70)
}

local function ZoneOf(zone)
	if (istable(zone)) then
		return zone
	end

	if (zone == nil or !NETWORK.zone or !NETWORK.zone.list) then
		return
	end

	return NETWORK.zone.list[tostring(zone)] or NETWORK.zone.list[tonumber(zone) or -1]
end

function R.GetGraffitiCount(zone)
	local list = ents.FindByClass("nw_graffiti")

	if (zone == nil) then
		return #list
	end

	zone = ZoneOf(zone)

	if (!zone) then
		return 0
	end

	local count = 0

	for _, entity in ipairs(list) do
		if (NETWORK.zone.Contains(zone, entity:GetPos())) then
			count = count + 1
		end
	end

	return count
end

function R.GetGraffitiCountAt(position)
	local zone = NETWORK.zone and NETWORK.zone.At(position)

	return zone and R.GetGraffitiCount(zone) or 0, zone
end

function R.CanClean(client)
	if (!IsValid(client) or !client:HasCharacter() or !client:Alive()) then
		return false
	end

	return NETWORK.factions.IsAlliance(client) or NETWORK.factions.IsCWU(client)
end

function R.FindGraffiti(client, range)
	range = range or R.graffiti.range

	local start = client:GetShootPos()
	local trace = util.TraceLine({
		start = start,
		endpos = start + client:GetAimVector() * range,
		filter = client,
		mask = MASK_SOLID_BRUSHONLY
	})

	if (!trace.Hit) then
		return
	end

	local best, bestDistance

	for _, entity in ipairs(ents.FindInSphere(trace.HitPos, 56)) do
		if (entity:GetClass() != "nw_graffiti") then
			continue
		end

		local distance = entity:GetPos():Distance(trace.HitPos)

		if (!bestDistance or distance < bestDistance) then
			best = entity
			bestDistance = distance
		end
	end

	return best
end

R.pocket = {
	slots = 2,
	maxCells = 2,
	revealChance = 25,
	rerollDelay = 120
}

function R.CanPocket(item)
	if (!istable(item) or !item.id) then
		return false
	end

	local base = NETWORK.item.Get(item.id)

	if (!base or NETWORK.item.IsContainer(item)) then
		return false
	end

	local width, height = NETWORK.item.GetSize(item)

	return width * height <= R.pocket.maxCells
end

R.radio = {
	nearRange = 90,
	interceptClasses = {ordinal = true, cmd = true},
	interceptZoneChance = 35,
	keepChance = 0.18
}

NETWORK.chat.Register("rebelradio", {
	prefix = {"/rr", "/rebelradio"},
	format = "chatRebelRadio",
	color = R.color,
	font = "nwChat",
	radius = R.radio.nearRange,
	order = 19,
	bSolidColor = true,
	bRadio = true,

	CanHear = function(class, speaker, listener)
		if (!listener:HasCharacter()) then
			return false
		end

		if (R.Is(listener)) then
			return true
		end

		return speaker:GetPos():DistToSqr(listener:GetPos()) <=
			class.radius * class.radius
	end,
	OnRadioListener = function(class, speaker, listener)
		return R.Is(listener)
	end,
	OnCanUse = function(class, client)
		if (!R.Is(client)) then
			return false, "rebelOnly"
		end

		return true
	end
})

NETWORK.chat.Register("rebeljam", {
	format = "chatRebelJam",
	color = R.jamColor,
	font = "nwChatItalic",
	order = 19,
	bNoName = true,
	bSolidColor = true,
	CanHear = function()
		return false
	end,
	OnCanUse = function()
		return false, "rebelOnly"
	end
})

NETWORK.chat.Register("rebelintercept", {
	format = "chatRebelIntercept",
	color = R.interceptColor,
	font = "nwChat",
	order = 19,
	bNoName = true,
	bSolidColor = true,
	CanHear = function()
		return false
	end,
	OnCanUse = function()
		return false, "rebelOnly"
	end
})

if (NETWORK.chat.icons) then
	NETWORK.chat.icons.rebelradio = "framework/chat/md_radio.png"
	NETWORK.chat.icons.rebeljam = "framework/chat/md_radio.png"
	NETWORK.chat.icons.rebelintercept = "framework/chat/md_dispatch.png"
end

local NOISE = {"ш", "-", ".", "ш", "…", "с", "·"}

function R.Garble(text)
	local parts = {}
	local keep = R.radio.keepChance

	local bOk = pcall(function()
		for _, code in utf8.codes(tostring(text or "")) do
			local char = utf8.char(code)

			if (char == " ") then
				parts[#parts + 1] = " "
			elseif (math.random() < keep) then
				parts[#parts + 1] = char
			else
				parts[#parts + 1] = NOISE[math.random(#NOISE)]
			end
		end
	end)

	if (!bOk) then
		parts = {"ш-ш-ш…"}
	end

	return L("rebelJamPrefix") .. " " .. table.concat(parts) .. " " .. L("rebelJamSuffix")
end

NETWORK.command.Register("pocket", {
	description = "cmdPocket",
	usage = "/pocket",
	aliases = {"karman"},
	OnRun = function(command, client)
		if (R.OpenPocket) then
			R.OpenPocket(client)
		end
	end
})

NETWORK.command.Register("cleargraffiti", {
	description = "cmdClearGraffiti",
	usage = "/cleargraffiti [all]",
	adminOnly = true,
	OnRun = function(command, client, arguments)
		if (R.AdminClearGraffiti) then
			R.AdminClearGraffiti(client, string.lower(arguments[1] or "") == "all")
		end
	end
})
