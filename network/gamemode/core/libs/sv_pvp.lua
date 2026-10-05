util.AddNetworkString("nwPvpKill")
util.AddNetworkString("nwPvpTeamMenu")
util.AddNetworkString("nwPvpTeamData")
util.AddNetworkString("nwPvpNotice")
util.AddNetworkString("nwPvpCrosshair")

local P = NETWORK.pvp

local function AddScore(team, amount)
	SetGlobalInt("nwPvpScore" .. team,
		GetGlobalInt("nwPvpScore" .. team, 0) + (amount or 1))
end

P.spawns = P.spawns or {}

local spawnDir = "network/pvp_spawns"

local function SpawnPath()
	return spawnDir .. "/" .. game.GetMap() .. ".json"
end

function P.LoadSpawns()
	P.spawns = {}

	local contents = file.Read(SpawnPath(), "DATA")
	local data = contents and util.JSONToTable(contents)

	if (!istable(data)) then
		return
	end

	for key, list in pairs(data) do
		local team = tonumber(key)

		if (team and istable(list)) then
			P.spawns[team] = {}

			for _, entry in ipairs(list) do
				P.spawns[team][#P.spawns[team] + 1] = {
					pos = Vector(entry.x or 0, entry.y or 0, entry.z or 0),
					yaw = entry.yaw or 0
				}
			end
		end
	end
end

function P.SaveSpawns()
	local data = {}

	for team, list in pairs(P.spawns) do
		data[tostring(team)] = {}

		for _, entry in ipairs(list) do
			data[tostring(team)][#data[tostring(team)] + 1] = {
				x = math.Round(entry.pos.x, 2),
				y = math.Round(entry.pos.y, 2),
				z = math.Round(entry.pos.z, 2),
				yaw = math.Round(entry.yaw, 1)
			}
		end
	end

	file.CreateDir(spawnDir)
	file.Write(SpawnPath(), util.TableToJSON(data, true))
end

hook.Add("InitPostEntity", "nwPvpSpawns", P.LoadSpawns)

P.LoadSpawns()

function P.PickSpawn(client, team)
	local list = P.spawns[team] or {}

	if (#list == 0) then
		return
	end

	local shuffled = table.Copy(list)

	for index = #shuffled, 2, -1 do
		local swap = math.random(index)

		shuffled[index], shuffled[swap] = shuffled[swap], shuffled[index]
	end

	for _, entry in ipairs(shuffled) do
		local bFree = true

		for _, other in ipairs(player.GetAll()) do
			if (other != client and other:Alive() and
				other:GetPos():Distance(entry.pos) < 48) then
				bFree = false

				break
			end
		end

		if (bFree) then
			return entry.pos, Angle(0, entry.yaw, 0)
		end
	end

	local entry = shuffled[1]

	return entry.pos + Vector(0, 0, 16), Angle(0, entry.yaw, 0)
end

function P.SetSide(client, team)
	if (!P.IsPlayingTeam(team)) then
		return
	end

	client:SetTeam(team)
	client:SetNWBool("nwPvpDead", false)

	local position, angles = P.PickSpawn(client, team)

	client:UnSpectate()
	client:SetNoDraw(false)
	client:SetNotSolid(false)
	client:SetMoveType(MOVETYPE_WALK)

	if (!client:Alive()) then
		client:Spawn()
	end

	if (position) then
		client:SetPos(position)

		if (angles) then
			client:SetEyeAngles(Angle(0, angles.y, 0))
		end
	end

	NETWORK.notice.Send(client, "pvpJoined", "good", L(P.GetTeam(team).name))

	P.SyncTeams()
end

function P.MakeSpectator(client)
	client:SetNWBool("nwPvpDead", true)

	client:StripWeapons()
	client:Spectate(OBS_MODE_ROAMING)
	client:SetMoveType(MOVETYPE_NOCLIP)
	client:SetNoDraw(true)
	client:SetNotSolid(true)
	client:SetNoTarget(true)
end

function P.Revive(client, team)
	team = team or (P.HasSide(client) and client:Team()) or P.TEAM_RED

	client:SetNWBool("nwPvpDead", false)
	client:UnSpectate()
	client:SetNoDraw(false)
	client:SetNotSolid(false)
	client:SetNoTarget(false)
	client:SetMoveType(MOVETYPE_WALK)
	client:Spawn()

	local position, angles = P.PickSpawn(client, team)

	if (position) then
		client:SetPos(position)

		if (angles) then
			client:SetEyeAngles(Angle(0, angles.y, 0))
		end
	end
end

P.watchers = P.watchers or {}

function P.SyncTeams(target)
	local payload = {}

	for _, client in ipairs(player.GetAll()) do
		if (!P.HasSide(client)) then
			continue
		end

		payload[#payload + 1] = {
			name = client:GetCharacterName(),
			team = client:Team(),
			kills = P.GetKills(client),
			deaths = P.GetDeaths(client),
			wins = P.GetWins(client),
			losses = P.GetLosses(client),
			bDead = P.IsDead(client)
		}
	end

	local targets = {}

	if (IsValid(target)) then
		targets[1] = target
	else
		for watcher in pairs(P.watchers) do
			if (IsValid(watcher)) then
				targets[#targets + 1] = watcher
			end
		end
	end

	if (#targets == 0) then
		return
	end

	net.Start("nwPvpTeamData")
		NETWORK.util.WriteTable(payload)
	net.Send(targets)
end

net.Receive("nwPvpTeamMenu", function(_, client)
	local bOpen = net.ReadBool()

	P.watchers[client] = bOpen or nil

	if (bOpen) then
		P.SyncTeams(client)
	end
end)

hook.Add("PlayerShouldTakeDamage", "nwPvp", function(client, attacker)
	if (!P.IsActive() or NETWORK.config.Get("pvpFriendlyFire")) then
		return
	end

	if (P.IsAlly(client, attacker)) then
		return false
	end

	local owner = P.GetEntityOwner(attacker)

	if (IsValid(owner) and owner != client and P.IsAlly(client, owner)) then
		return false
	end
end)

hook.Add("EntityTakeDamage", "nwPvp", function(target, info)
	if (!P.IsActive() or NETWORK.config.Get("pvpFriendlyFire")) then
		return
	end

	if (target:IsPlayer()) then
		return
	end

	local owner = P.GetEntityOwner(target)

	if (!IsValid(owner)) then
		return
	end

	local attacker = info:GetAttacker()

	if (P.IsAlly(owner, attacker) and owner != attacker) then
		return true
	end
end)

hook.Add("PlayerUse", "nwPvp", function(client, entity)
	if (!P.IsActive()) then
		return
	end

	local owner = P.GetEntityOwner(entity)

	if (!IsValid(owner) or owner == client or !P.HasSide(owner)) then
		return
	end

	if (!P.IsAlly(client, owner)) then
		return false
	end
end)

local function KillLine(attacker, victim, weapon)
	local metres = math.Round(attacker:GetPos():Distance(victim:GetPos()) / 40, 1)

	net.Start("nwPvpKill")
		net.WriteEntity(attacker)
		net.WriteEntity(victim)
		net.WriteString(weapon)
		net.WriteFloat(metres)
	net.Broadcast()
end

local function WeaponName(attacker, inflictor)
	local weapon = attacker:GetActiveWeapon()

	if (IsValid(weapon)) then
		return weapon:GetPrintName() or weapon:GetClass()
	end

	if (IsValid(inflictor)) then
		return inflictor:GetClass()
	end

	return "?"
end

hook.Add("PlayerDeath", "nwPvp", function(victim, inflictor, attacker)
	if (!P.IsActive()) then
		return
	end

	victim:SetNWInt("nwPvpDeaths", P.GetDeaths(victim) + 1)

	if (IsValid(attacker) and attacker:IsPlayer() and attacker != victim and
		!P.IsAlly(attacker, victim)) then

		attacker:SetNWInt("nwPvpKills", P.GetKills(attacker) + 1)

		KillLine(attacker, victim, WeaponName(attacker, inflictor))
	end

	timer.Simple(0.5, function()
		if (IsValid(victim) and P.IsActive()) then
			P.MakeSpectator(victim)
		end
	end)

	P.SyncTeams()
end)

hook.Add("PlayerDeathThink", "nwPvp", function(client)
	if (P.IsActive() and P.IsDead(client)) then
		return false
	end
end)

do
	local table_ = hook.GetTable()["PlayerCanHearPlayersVoice"]
	local base = table_ and table_["nwVoice"]

	hook.Add("PlayerCanHearPlayersVoice", "nwVoice", function(listener, speaker)
		if (P.IsActive() and (P.IsDead(listener) or P.IsDead(speaker))) then
			if (P.IsDead(speaker)) then
				return P.IsDead(listener), false
			end

			return true, false
		end

		if (base) then
			return base(listener, speaker)
		end
	end)
end

function P.OnToggled(bEnabled)
	timer.Remove("nwPvpNext")

	SetGlobalString("nwPvpState", bEnabled and "waiting" or "idle")
	SetGlobalInt("nwPvpRound", 0)
	SetGlobalFloat("nwPvpEnd", 0)
	SetGlobalInt("nwPvpScore" .. P.TEAM_RED, 0)
	SetGlobalInt("nwPvpScore" .. P.TEAM_BLUE, 0)

	for _, client in ipairs(player.GetAll()) do
		client:SetNWInt("nwPvpKills", 0)
		client:SetNWInt("nwPvpDeaths", 0)
		client:SetNWInt("nwPvpWins", 0)
		client:SetNWInt("nwPvpLosses", 0)
		client:SetNWBool("nwPvpDead", false)

		if (!bEnabled) then
			client:SetTeam(TEAM_UNASSIGNED)
			client:UnSpectate()
			client:SetNoDraw(false)
			client:SetNotSolid(false)
		end
	end
end

local function SetState(state)
	SetGlobalString("nwPvpState", state)
end

function P.StartRound(round)
	SetGlobalInt("nwPvpRound", round)
	SetState("live")

	local length = NETWORK.config.Get("pvpRoundTime") or 600

	SetGlobalFloat("nwPvpEnd", CurTime() + length)

	for _, client in ipairs(player.GetAll()) do
		if (P.HasSide(client)) then
			P.Revive(client, client:Team())
		end
	end

	P.Announce(L("pvpRoundStart", round), Color(226, 190, 120))

	P.SyncTeams()
end

function P.EndRound(winner)
	if (P.GetState() != "live") then
		return
	end

	SetState("break")
	SetGlobalFloat("nwPvpEnd", CurTime() + 8)

	if (winner) then
		AddScore(winner, 1)

		for _, client in ipairs(player.GetAll()) do
			if (!P.HasSide(client)) then
				continue
			end

			if (client:Team() == winner) then
				client:SetNWInt("nwPvpWins", P.GetWins(client) + 1)
			else
				client:SetNWInt("nwPvpLosses", P.GetLosses(client) + 1)
			end
		end

		P.Announce(L("pvpRoundWin", L(P.GetTeam(winner).name)),
			P.GetTeam(winner).color)
	else
		P.Announce(L("pvpRoundDraw"), Color(190, 190, 190))
	end

	P.SyncTeams()

	timer.Create("nwPvpNext", 8, 1, function()
		if (P.IsActive()) then
			P.StartRound(P.GetRound() + 1)
		end
	end)
end

timer.Create("nwPvpWatch", 1, 0, function()
	if (!P.IsActive() or P.GetState() != "live") then
		return
	end

	local red = P.CountAlive(P.TEAM_RED)
	local blue = P.CountAlive(P.TEAM_BLUE)

	if (red == 0 and blue == 0) then
		return P.EndRound(nil)
	end

	if (red == 0) then
		return P.EndRound(P.TEAM_BLUE)
	end

	if (blue == 0) then
		return P.EndRound(P.TEAM_RED)
	end

	if (P.GetRoundLeft() <= 0) then

		if (red > blue) then
			return P.EndRound(P.TEAM_RED)
		end

		if (blue > red) then
			return P.EndRound(P.TEAM_BLUE)
		end

		return P.EndRound(nil)
	end
end)

function P.Announce(text, color)
	if (NETWORK.events and NETWORK.events.Announce) then
		return NETWORK.events.Announce(text, color, 5)
	end

	for _, client in ipairs(player.GetAll()) do
		NETWORK.chat.Notice(client, text)
	end
end

NETWORK.command.Register("startpvp", {
	adminOnly = true,
	description = "cmdStartPvp",
	usage = "/startpvp [минут на раунд]",
	OnRun = function(command, client, arguments)
		local minutes = tonumber(arguments[1])

		if (minutes) then
			NETWORK.config.Set("pvpRoundTime",
				math.Clamp(math.floor(minutes * 60), 60, 3600))
		end

		if (!P.IsActive()) then
			NETWORK.config.Set("pvpEnabled", true)
		end

		SetGlobalInt("nwPvpScore" .. P.TEAM_RED, 0)
		SetGlobalInt("nwPvpScore" .. P.TEAM_BLUE, 0)

		for _, target in ipairs(player.GetAll()) do
			target:SetNWInt("nwPvpWins", 0)
			target:SetNWInt("nwPvpLosses", 0)
			target:SetNWInt("nwPvpKills", 0)
			target:SetNWInt("nwPvpDeaths", 0)
		end

		P.StartRound(1)

		NETWORK.notice.Send(client, "pvpStarted", "good",
			math.floor((NETWORK.config.Get("pvpRoundTime") or 600) / 60))
	end
})

local teamWords = {
	["red"] = P.TEAM_RED, ["красн"] = P.TEAM_RED, ["красные"] = P.TEAM_RED,
	["красная"] = P.TEAM_RED, ["1"] = P.TEAM_RED,
	["blue"] = P.TEAM_BLUE, ["син"] = P.TEAM_BLUE, ["синие"] = P.TEAM_BLUE,
	["синяя"] = P.TEAM_BLUE, ["2"] = P.TEAM_BLUE
}

NETWORK.command.Register("pvpmode", {
	adminOnly = true,
	description = "cmdPvpMode",
	usage = "/pvpmode [1|0]",
	OnRun = function(command, client, arguments)
		local value = arguments[1] and tobool(arguments[1]) or !P.IsActive()

		NETWORK.config.Set("pvpEnabled", value)

		NETWORK.notice.Send(client, value and "pvpOn" or "pvpOff", "good")

		if (value) then
			NETWORK.chat.Notice(client, L("pvpHelp"))
		end
	end
})

NETWORK.command.Register("team", {
	description = "cmdTeam",
	OnRun = function(command, client)
		if (!P.IsActive()) then
			return NETWORK.notice.Send(client, "pvpOffAlready", "warn")
		end

		net.Start("nwPvpNotice")
			net.WriteString("team")
		net.Send(client)
	end
})

net.Receive("nwPvpNotice", function(_, client)
	local team = net.ReadUInt(4)

	if (!P.IsActive() or !P.IsPlayingTeam(team)) then
		return
	end

	if ((client.nwPvpNext or 0) > CurTime()) then
		return
	end

	client.nwPvpNext = CurTime() + 1

	P.SetSide(client, team)
end)

NETWORK.command.Register("teammenu", {
	description = "cmdTeamMenu",
	OnRun = function(command, client)
		net.Start("nwPvpNotice")
			net.WriteString("scores")
		net.Send(client)

		P.SyncTeams(client)
	end
})

NETWORK.command.Register("spawndead", {
	adminOnly = true,
	description = "cmdSpawnDead",
	OnRun = function(command, client)
		local count = 0

		for _, target in ipairs(player.GetAll()) do
			if (P.IsDead(target) or !target:Alive()) then
				P.Revive(target)

				count = count + 1
			end
		end

		NETWORK.notice.Send(client, "pvpRevived", "good", count)

		P.SyncTeams()
	end
})

local function SpawnPoint(client, team)
	P.spawns[team] = P.spawns[team] or {}

	P.spawns[team][#P.spawns[team] + 1] = {
		pos = client:GetPos(),
		yaw = client:EyeAngles().y
	}

	P.SaveSpawns()

	NETWORK.notice.Send(client, "pvpSpawnAdded", "good",
		L(P.GetTeam(team).name), #P.spawns[team])
end

NETWORK.command.Register("spawnred", {
	adminOnly = true,
	description = "cmdSpawnRed",
	OnRun = function(command, client)
		SpawnPoint(client, P.TEAM_RED)
	end
})

NETWORK.command.Register("spawnblue", {
	adminOnly = true,
	description = "cmdSpawnBlue",
	OnRun = function(command, client)
		SpawnPoint(client, P.TEAM_BLUE)
	end
})

NETWORK.command.Register("crosshairedit", {
	description = "cmdCrosshairEdit",
	OnRun = function(command, client)
		net.Start("nwPvpCrosshair")
		net.Send(client)
	end
})

NETWORK.command.Register("setteam", {
	adminOnly = true,
	description = "cmdSetTeam",
	usage = "/setteam <игрок> <красные|синие>",
	OnRun = function(command, client, arguments)
		local target = NETWORK.permission.Find(arguments[1] or "")

		if (!IsValid(target)) then
			return NETWORK.notice.Send(client, "permNoTarget", "warn")
		end

		local team = teamWords[NETWORK.util.Lower(
			string.Trim(tostring(arguments[2] or "")))]

		if (!team) then
			return NETWORK.notice.Send(client, "pvpTeamUsage", "warn")
		end

		P.SetSide(target, team)
	end
})
