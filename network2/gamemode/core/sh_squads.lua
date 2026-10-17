-- Squads of the Alliance (formations). Made and run at the Alliance terminal (nw_cmb_terminal) or
-- with the chat commands; only members of the Alliance, each side (Civil Protection / the Combine)
-- has its own squads (as many as are made; the leader sets how many members, 2..nw_squad_size).
--   create      a name; the one who makes it leads it
--   join        any squad of your side that has room
--   leave       a member leaves; the leader leaving ends the squad - unless the leader turned the
--               succession on: then the one who joined next after them leads (and so on down)
--   the leader dies or leaves the game - the same: the end, or the next one leads
--   disband     the leader (or an admin, or the terminal) ends it
--   kick        the leader sends a member away
-- The squad is shown: top left in the HUD of the Alliance "ОТРЯД :: <name>" and the members (blue
-- for Civil Protection, red for the Combine); every member is outlined through the walls in that
-- colour (cl_squads.lua), with the squad mark over the head - yellow for the leader. /r is the
-- squad's radio; the radio item (sh_radio.lua) carries the voice to the squad.
-- On the player: NW2 int nwSquad (the id, 0 - none). The squads themselves come with nwSquads.

NW.squads = NW.squads or {}

local SQ = NW.squads

SQ.size = CreateConVar("nw_squad_size", "16", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Сколько юнитов может быть в отряде (верх лимита лидера)")
SQ.defaultSize = 6

-- the limit of a squad: set by its leader
function SQ.Limit(squad)
	return math.Clamp(squad and squad.size or SQ.defaultSize, 2, SQ.size:GetInt())
end

SQ.list = SQ.list or {}

SQ.sounds = {
	create = "network2/squad/combine_squad_create.mp3",
	disband = "network2/squad/combine_squad_disband.mp3",
	join = "network2/squad/combine_squad_join.mp3",
	leave = "network2/squad/combine_squad_leave.mp3"
}

SQ.colors = {
	cp = Color(86, 200, 255),
	ota = Color(236, 84, 72),
	leader = Color(250, 210, 70)
}

function SQ.Side(client)
	return NW.units and NW.units.Side(client:GetFaction()) or "cp"
end

function SQ.Of(client)
	local id = IsValid(client) and client:GetNW2Int("nwSquad", 0) or 0

	return id != 0 and SQ.list[id] or nil
end

function SQ.IsLeader(client)
	local squad = SQ.Of(client)

	return squad != nil and squad.leader == client
end

-- the members in order (the leader first, then by the time they joined)
function SQ.Members(squad)
	local out = {}

	for _, member in ipairs(squad and squad.members or {}) do
		if (IsValid(member)) then
			out[#out + 1] = member
		end
	end

	return out
end

function SQ.Count(side)
	local count = 0

	for _, squad in pairs(SQ.list) do
		if (squad.side == side) then
			count = count + 1
		end
	end

	return count
end
