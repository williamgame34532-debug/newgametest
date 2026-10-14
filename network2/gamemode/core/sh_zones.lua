-- Zones: boxes on the map with a name and a kind. Made by admins in the editor (/areaedit,
-- cl_zones.lua): the first corner, the second corner, then the name and the kind. Kept per map in
-- data/network2/zones/<map>.json (sv_zones.lua).
--   plain       just a named place
--   radiation   green smoke inside; hurts every second (damage) everyone who has no gas mask on
--               (a face item with gasmask = true) and is not of the Alliance (a faction with
--               alliance = true, or an Alliance / Civil Protection model)
--   items       puts items (one of items, at random) on the ground inside, every interval seconds,
--               while fewer than count of them lie there
--   npcs        spawns NPCs (npc: a class or an NPC list name) inside, every interval seconds,
--               while fewer than count of them are alive
-- Walking into a zone shows its name on the left of the screen for 7 seconds (cl_zones.lua).

NW.zones = NW.zones or {}

local Z = NW.zones

Z.list = Z.list or {}

Z.types = {
	{id = "plain", name = "Обычная", caption = "Зона"},
	{id = "radiation", name = "Радиация", caption = "Радиационная зона"},
	{id = "items", name = "Спавн предметов", caption = "Зона"},
	{id = "npcs", name = "Спавн NPC", caption = "Опасная зона"}
}

Z.typeByID = {}

for _, kind in ipairs(Z.types) do
	Z.typeByID[kind.id] = kind
end

-- limits of the settings (the server clamps to them)
Z.limits = {
	damage = {1, 50, 3},
	count = {1, 30, 3},
	interval = {5, 3600, 120},
	height = {32, 2048, 200}
}

function Z.Clamp(key, value)
	local limit = Z.limits[key]

	return math.Clamp(math.floor(tonumber(value) or limit[3]), limit[1], limit[2])
end

-- the box of a zone as vectors
function Z.Bounds(zone)
	if (!zone.vmin) then
		zone.vmin = Vector(zone.min[1], zone.min[2], zone.min[3])
		zone.vmax = Vector(zone.max[1], zone.max[2], zone.max[3])
	end

	return zone.vmin, zone.vmax
end

function Z.Contains(zone, pos)
	local mins, maxs = Z.Bounds(zone)

	return pos.x >= mins.x and pos.x <= maxs.x and pos.y >= mins.y and pos.y <= maxs.y and
		pos.z >= mins.z and pos.z <= maxs.z
end

-- the zone at pos (the smallest one when they overlap)
function Z.At(pos)
	local best, size

	for _, zone in pairs(Z.list) do
		if (Z.Contains(zone, pos)) then
			local mins, maxs = Z.Bounds(zone)
			local volume = (maxs.x - mins.x) * (maxs.y - mins.y) * (maxs.z - mins.z)

			if (!best or volume < size) then
				best, size = zone, volume
			end
		end
	end

	return best
end

-- the point that counts for a player (the middle of the body)
function Z.Point(client)
	return client:GetPos() + Vector(0, 0, 36)
end

-- Alliance: by the faction (FACTION.alliance = true) or by the model (Alliance, Civil Protection)
local ALLIANCE_CLASSES = {overwatch = true, metrocop = true, combine_heavy = true}

function Z.IsAlliance(client)
	local faction = NW.char and NW.char.factions and NW.char.factions[client:GetFaction() or ""]

	if (faction and faction.alliance) then
		return true
	end

	local class = NW.anim and NW.anim.GetModelClass and NW.anim.GetModelClass(string.lower(client:GetModel() or ""))

	return ALLIANCE_CLASSES[class or ""] == true
end
