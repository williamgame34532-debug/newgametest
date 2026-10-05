NETWORK.pvp = NETWORK.pvp or {}

local P = NETWORK.pvp

P.TEAM_RED = 4
P.TEAM_BLUE = 5
P.TEAM_DEAD = 6

P.teams = {
	[P.TEAM_RED] = {
		id = P.TEAM_RED,
		name = "pvpTeamRed",
		color = Color(222, 82, 74),
		spawns = {}
	},
	[P.TEAM_BLUE] = {
		id = P.TEAM_BLUE,
		name = "pvpTeamBlue",
		color = Color(84, 148, 232),
		spawns = {}
	}
}

P.order = {P.TEAM_RED, P.TEAM_BLUE}

function P.GetTeam(id)
	return P.teams[id]
end

function P.IsPlayingTeam(id)
	return id == P.TEAM_RED or id == P.TEAM_BLUE
end

function P.IsActive()
	return NETWORK.config.Get("pvpEnabled") == true
end

function P.GetSide(client)
	return IsValid(client) and client:Team() or 0
end

function P.HasSide(client)
	return P.IsPlayingTeam(P.GetSide(client))
end

function P.IsDead(client)
	return IsValid(client) and client:GetNWBool("nwPvpDead", false)
end

function P.IsAlly(a, b)
	if (!IsValid(a) or !IsValid(b)) then
		return false
	end

	if (!P.HasSide(a) or !P.HasSide(b)) then
		return false
	end

	return P.GetSide(a) == P.GetSide(b)
end

function P.GetScore(team)
	return GetGlobalInt("nwPvpScore" .. team, 0)
end

function P.GetRound()
	return GetGlobalInt("nwPvpRound", 0)
end

function P.GetRoundEnd()
	return GetGlobalFloat("nwPvpEnd", 0)
end

function P.GetRoundLeft()
	return math.max(P.GetRoundEnd() - CurTime(), 0)
end

function P.GetState()
	return GetGlobalString("nwPvpState", "idle")
end

function P.GetWins(client)
	return IsValid(client) and client:GetNWInt("nwPvpWins", 0) or 0
end

function P.GetLosses(client)
	return IsValid(client) and client:GetNWInt("nwPvpLosses", 0) or 0
end

function P.CountAlive(team)
	local count = 0

	for _, client in ipairs(player.GetAll()) do
		if (client:Team() == team and client:Alive() and !P.IsDead(client)) then
			count = count + 1
		end
	end

	return count
end

function P.GetKills(client)
	return IsValid(client) and client:GetNWInt("nwPvpKills", 0) or 0
end

function P.GetDeaths(client)
	return IsValid(client) and client:GetNWInt("nwPvpDeaths", 0) or 0
end

function P.GetEntityOwner(entity)
	if (!IsValid(entity)) then
		return
	end

	if (entity.IsPlayer and entity:IsPlayer()) then
		return entity
	end

	local owner = entity.nwOwner

	if (IsValid(owner)) then
		return owner
	end

	if (entity.CPPIGetOwner) then
		owner = entity:CPPIGetOwner()

		if (IsValid(owner) and owner:IsPlayer()) then
			return owner
		end
	end

	owner = entity:GetOwner()

	if (IsValid(owner) and owner:IsPlayer()) then
		return owner
	end

	if (entity.GetOwner) then
		local weaponOwner = entity.GetOwner and entity:GetOwner()

		if (IsValid(weaponOwner) and weaponOwner.GetOwner) then
			local holder = weaponOwner:GetOwner()

			if (IsValid(holder) and holder:IsPlayer()) then
				return holder
			end
		end
	end
end

NETWORK.config.Register("pvpEnabled", {
	name = "cfgPvpEnabled",
	description = "cfgPvpEnabledDesc",
	category = "world",
	type = "bool",
	default = false,
	OnChanged = function(value)
		if (SERVER and NETWORK.pvp.OnToggled) then
			NETWORK.pvp.OnToggled(value)
		end
	end
})

NETWORK.config.Register("pvpRoundTime", {
	name = "cfgPvpRoundTime",
	description = "cfgPvpRoundTimeDesc",
	category = "world",
	default = 600,
	min = 60,
	max = 3600,
	decimals = 0
})

NETWORK.config.Register("pvpFriendlyFire", {
	name = "cfgPvpFriendly",
	description = "cfgPvpFriendlyDesc",
	category = "world",
	type = "bool",
	default = false
})
