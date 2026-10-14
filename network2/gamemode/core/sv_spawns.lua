-- Faction spawn points, set by the staff in chat:
--   /spawnadd [фракция]   a spawn point of that faction (yours when left out) right where you stand,
--                         looking where you look
--   /spawnremove          removes the nearest point (within 128 units)
-- Points are kept per map in data/network2/spawns/<map>.json. A character comes into the world on
-- one of its faction's points (a random free one) when it has no saved place: a new character, and
-- every time after death. Without points of its faction the map's own spawns are used.

local S = {}
local DIR = "network2/spawns"

NW.spawns = S

local function Path()
	return DIR .. "/" .. game.GetMap() .. ".json"
end

function S.Load()
	S.list = util.JSONToTable(file.Read(Path(), "DATA") or "") or {}
end

function S.Save()
	file.CreateDir(DIR)
	file.Write(Path(), util.TableToJSON(S.list, true))
end

S.Load()

local function Notify(client, text)
	NW.Notify(client, text)
end

-- a faction by its id or (part of) its name
local function FindFaction(query)
	query = string.lower(string.Trim(query or ""))

	if (NW.char.factions[query]) then
		return query
	end

	for id, faction in pairs(NW.char.factions) do
		if (string.find(string.lower(faction.name or id), query, 1, true)) then
			return id
		end
	end
end

NW.AddChatCommand("spawnadd", {admin = true, run = function(client, rest)
	local faction = rest != "" and FindFaction(rest) or client:GetFaction()

	if (!faction or !NW.char.factions[faction]) then
		return Notify(client, "Фракция не найдена: " .. rest)
	end

	local pos = client:GetPos()

	S.list[faction] = S.list[faction] or {}
	table.insert(S.list[faction], {math.Round(pos.x, 1), math.Round(pos.y, 1), math.Round(pos.z + 2, 1),
		math.Round(client:EyeAngles().y, 1)})
	S.Save()

	Notify(client, string.format("Точка появления добавлена: %s (всего %d)", NW.char.factions[faction].name or faction,
		#S.list[faction]))
end})

NW.AddChatCommand("spawnremove", {admin = true, run = function(client)
	local best, bestFaction, bestIndex = 128 * 128

	for faction, points in pairs(S.list) do
		for index, point in ipairs(points) do
			local distance = client:GetPos():DistToSqr(Vector(point[1], point[2], point[3]))

			if (distance < best) then
				best, bestFaction, bestIndex = distance, faction, index
			end
		end
	end

	if (!bestFaction) then
		return Notify(client, "Рядом нет точек появления")
	end

	table.remove(S.list[bestFaction], bestIndex)
	S.Save()

	local faction = NW.char.factions[bestFaction]

	Notify(client, "Точка появления убрана: " .. (faction and faction.name or bestFaction))
end})

-- a free point of the faction (nobody standing on it), or any of them
function S.Pick(client, faction)
	local points = S.list[faction or ""]

	if (!points or #points == 0) then
		return
	end

	local order = table.Copy(points)

	table.Shuffle(order)

	local mins, maxs = client:GetHull()

	for _, point in ipairs(order) do
		local pos = Vector(point[1], point[2], point[3])
		local trace = util.TraceHull({start = pos, endpos = pos, mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID,
			filter = client})

		if (!trace.StartSolid) then
			return pos, Angle(0, point[4] or 0, 0)
		end
	end

	local point = order[1]

	return Vector(point[1], point[2], point[3]), Angle(0, point[4] or 0, 0)
end

-- no saved place: onto a point of the faction (sv_character.lua puts it on the saved place instead)
hook.Add("PlayerSpawn", "nwSpawns", function(client)
	if (!client.nwCharacter or NW.IsInMenu(client)) then
		return
	end

	local saved = client.nwSpawnSpot and client.nwSpawnSpot[1]

	if (saved) then
		return
	end

	local pos, ang = S.Pick(client, client:GetFaction())

	if (!pos) then
		return
	end

	timer.Simple(0, function()
		if (IsValid(client) and client:Alive()) then
			client:SetPos(pos)
			client:SetEyeAngles(ang)
		end
	end)
end)
