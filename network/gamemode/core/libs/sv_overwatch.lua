local function Notice(client, text)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(text)
	net.Send(client)
end

NETWORK.overwatch = NETWORK.overwatch or {}

local PATH = "framework/cmb/overwatch/"

NETWORK.overwatch.idle = {
	PATH .. "allteamrespond.wav",
	PATH .. "reminder.wav",
	PATH .. "return12.wav",
	PATH .. "reward.wav"
}

NETWORK.overwatch.contact = PATH .. "non-citizen.wav"
NETWORK.overwatch.biosignal = PATH .. "lostbiosignal.wav"

NETWORK.overwatch.idleMin = 150
NETWORK.overwatch.idleMax = 420

NETWORK.overwatch.scanDelay = 12
NETWORK.overwatch.scanRange = 420
NETWORK.overwatch.scanChance = 0.35
NETWORK.overwatch.markTime = 4

util.AddNetworkString("nwOverwatchMark")
util.AddNetworkString("nwOverwatchVO")

function NETWORK.overwatch.Play(client, path)
	if (!IsValid(client) or !path) then
		return
	end

	net.Start("nwOverwatchVO")
		net.WriteString(path)
	net.Send(client)
end

local function Roll(client)
	client.nwOverwatchNext = CurTime() +
		math.Rand(NETWORK.overwatch.idleMin, NETWORK.overwatch.idleMax)
end

function NETWORK.overwatch.Listens(client)
	return client:HasCharacter() and client:GetCharacterFaction() == "cp"
end

function NETWORK.overwatch.Announce(text)
	for _, client in ipairs(player.GetAll()) do
		if (NETWORK.overwatch.Listens(client)) then
			Notice(client, text)
		end
	end
end

local function AllianceNotice(client, text)
	net.Start("nwChatMessage")
		net.WriteString("dispatch")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(text)
	net.Send(client)
end

function NETWORK.overwatch.SendAll(text)
	for _, client in ipairs(player.GetAll()) do
		if (NETWORK.overwatch.Listens(client)) then
			AllianceNotice(client, text)
		end
	end
end

NETWORK.overwatch.Notice = AllianceNotice

hook.Add("Think", "nwOverwatchIdle", function()
	if ((NETWORK.overwatch.nextTick or 0) > CurTime()) then
		return
	end

	NETWORK.overwatch.nextTick = CurTime() + 1

	for _, client in ipairs(player.GetAll()) do
		if (!client:Alive() or !client:HasCharacter() or !client:IsCombine()) then
			continue
		end

		if (!client.nwOverwatchNext) then

			client.nwOverwatchNext = CurTime() + math.Rand(30,
				NETWORK.overwatch.idleMax)

			continue
		end

		if (client.nwOverwatchNext > CurTime()) then
			continue
		end

		Roll(client)

		local list = NETWORK.overwatch.idle

		NETWORK.overwatch.Play(client, list[math.random(#list)])
	end
end)

local function IsArmedCitizen(target)
	if (!target:Alive() or !target:HasCharacter() or target:IsCombine()) then
		return false
	end

	local weapon = target:GetActiveWeapon()

	if (!IsValid(weapon)) then
		return false
	end

	local class = weapon:GetClass()

	return class != NETWORK.weapon.hands and class != "weapon_nwkeys"
end

hook.Add("Think", "nwOverwatchScan", function()
	if ((NETWORK.overwatch.nextScan or 0) > CurTime()) then
		return
	end

	NETWORK.overwatch.nextScan = CurTime() + 2

	for _, client in ipairs(player.GetAll()) do
		if (!client:Alive() or !client:HasCharacter() or !client:IsCombine()) then
			continue
		end

		if ((client.nwOverwatchScan or 0) > CurTime()) then
			continue
		end

		client.nwOverwatchScan = CurTime() + NETWORK.overwatch.scanDelay

		if (math.Rand(0, 1) > NETWORK.overwatch.scanChance) then
			continue
		end

		local best, bestDistance

		for _, target in ipairs(player.GetAll()) do
			if (target == client or !IsArmedCitizen(target)) then
				continue
			end

			local distance = client:GetPos():Distance(target:GetPos())

			if (distance > NETWORK.overwatch.scanRange) then
				continue
			end

			if (!bestDistance or distance < bestDistance) then
				best = target
				bestDistance = distance
			end
		end

		if (!best) then
			continue
		end

		NETWORK.overwatch.Play(client, NETWORK.overwatch.contact)

		net.Start("nwOverwatchMark")
			net.WriteEntity(best)
			net.WriteFloat(NETWORK.overwatch.markTime)
		net.Send(client)
	end
end)

hook.Add("PlayerDeath", "nwOverwatch", function(victim)
	if (!victim:HasCharacter() or !victim:IsCombine()) then
		return
	end

	local zone = NETWORK.zone.AtEntity(victim)
	local type = zone and NETWORK.zone.GetType(zone.type)
	local label = zone and (zone.name != "" and zone.name or
		(type and L(type.name))) or L("owUnknownZone")

	for _, client in ipairs(player.GetAll()) do
		if (client == victim or !client:HasCharacter() or
			!NETWORK.factions.IsAlliance(client)) then
			continue
		end

		NETWORK.overwatch.Play(client, NETWORK.overwatch.biosignal)

		net.Start("nwUnitLostVisual")
			net.WriteVector(victim:GetPos() + Vector(0, 0, 40))
			net.WriteString(victim:GetCharacterName())
		net.Send(client)
	end
end)

NETWORK.command.Register("dispdata", {
	description = "cmdDispdata",
	usage = "/dispdata <номер>",
	OnRun = function(command, client, arguments)
		if (!NETWORK.factions.IsAlliance(client)) then
			return AllianceNotice(client, L("owNoAccess"))
		end

		local id = string.gsub(arguments[1] or "", "[^%d]", "")

		if (id == "") then
			return AllianceNotice(client, L("owDataUsage"))
		end

		id = string.format("%05d", math.min(tonumber(id) or 0, 99999))

		NETWORK.chat.Send(client, "ic", L("owDataRequest", id))

		local target

		for _, other in ipairs(player.GetAll()) do
			local character = other:GetCharacter()

			if (character and NETWORK.terminal.GetCitizenID(character) == id) then
				target = other

				break
			end
		end

		timer.Simple(1.6, function()
			if (!IsValid(client)) then
				return
			end

			AllianceNotice(client, L("owDataHeader", id))

			if (!target) then
				AllianceNotice(client, L("owDataUnknown"))

				return
			end

			local character = target:GetCharacter()
			local faction = NETWORK.factions.Get(character:GetFaction())

			AllianceNotice(client, L("owDataName", character:GetName()))
			local band = NETWORK.loyalty.GetBand(target:GetLoyalty())

			AllianceNotice(client, L("owDataLoyalty",
				L(band.label) .. " (" .. target:GetLoyalty() .. ")"))

			local violations = NETWORK.detain.GetViolations(character)

			if (#violations == 0) then
				AllianceNotice(client, L("owDataViolations",
					L("termViolationsNone")))
			else
				AllianceNotice(client, L("owDataViolations",
					#violations .. ":"))

				for index, entry in ipairs(violations) do
					AllianceNotice(client, string.format(
						"  %d) %s — %d мин. [%s]", index, entry.reason,
						entry.term, entry.officer or "?"))
				end
			end
			AllianceNotice(client, L("owDataStatus",
				faction and L(faction.name) or "?"))
		end)
	end
})

NETWORK.overwatch.announceMin = 300
NETWORK.overwatch.announceMax = 600

NETWORK.overwatch.announcements = {
	{sound = PATH .. "voice1.wav", text = "owAnnounce1"},
	{sound = PATH .. "voice2.wav", text = "owAnnounce2"},
	{sound = PATH .. "voice3.wav", text = "owAnnounce3"},
	{sound = PATH .. "voice4.wav", text = "owAnnounce4"}
}

function NETWORK.overwatch.Announcement(entry)
	entry = entry or NETWORK.overwatch.announcements[
		math.random(#NETWORK.overwatch.announcements)]

	if (!entry) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		if (!client:HasCharacter()) then
			continue
		end

		net.Start("nwChatMessage")
			net.WriteString("announce")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(L(entry.text))
		net.Send(client)

		NETWORK.overwatch.Play(client, entry.sound)
	end

	hook.Run("NetworkAnnouncement", entry)
end

local function RollAnnouncement()
	NETWORK.overwatch.nextAnnounce = CurTime() +
		math.Rand(NETWORK.overwatch.announceMin, NETWORK.overwatch.announceMax)
end

RollAnnouncement()

timer.Create("nwOverwatchAnnounce", 5, 0, function()
	if ((NETWORK.overwatch.nextAnnounce or 0) > CurTime()) then
		return
	end

	RollAnnouncement()

	if (#player.GetAll() == 0) then
		return
	end

	NETWORK.overwatch.Announcement()
end)

function NETWORK.overwatch.Center(text, sender)
	local count = 0

	for _, client in ipairs(player.GetAll()) do
		if (!client:HasCharacter()) then
			continue
		end

		local faction = client:GetCharacterFaction()

		if (!NETWORK.factions.IsAlliance(client) and !NETWORK.factions.IsCWU(client) and
			faction != "disinfector" and faction != "worker") then
			continue
		end

		net.Start("nwChatMessage")
			net.WriteString("center")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString(text)
		net.Send(client)

		client:EmitSound("npc/overwatch/radiovoice/on2.wav", 55, 100)

		count = count + 1
	end

	if (NETWORK.chat and NETWORK.chat.Log) then
		NETWORK.chat.Log(sender, "center", text)
	end

	return count
end

NETWORK.command.Register("center", {
	adminOnly = true,
	description = "cmdCenter",
	usage = "/patrol <текст>",
	aliases = {"patrol", "патруль"},
	OnRun = function(command, client, arguments)
		local text = NETWORK.util.Sanitise(table.concat(arguments, " "), 300)

		if (text == "") then
			return AllianceNotice(client, L("centerUsage"))
		end

		local count = NETWORK.overwatch.Center(text, client)

		if (!NETWORK.factions.IsAlliance(client) and !NETWORK.factions.IsCWU(client)) then

			AllianceNotice(client, L("chatCenter", text))
		end

		NETWORK.notice.Send(client, "centerSent", "good", count)
	end
})

NETWORK.command.Register("центр", {
	adminOnly = true,
	description = "cmdCenter",
	usage = "/центр <текст>",
	OnRun = function(command, client, arguments)
		local handler = NETWORK.command.Get and NETWORK.command.Get("center")

		if (handler and handler.OnRun) then
			return handler.OnRun(handler, client, arguments)
		end
	end
})

NETWORK.command.Register("announce", {
	adminOnly = true,
	description = "cmdAnnounce",
	usage = "/announce [номер]",
	OnRun = function(command, client, arguments)
		local index = tonumber(arguments[1])

		NETWORK.overwatch.Announcement(index and
			NETWORK.overwatch.announcements[index] or nil)
	end
})
