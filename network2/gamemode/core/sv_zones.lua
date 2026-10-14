-- Zones, server side (sh_zones.lua): saving, the editor (/areaedit, admins), the radiation, the
-- spawners of items and NPCs.
--   nwZones        server → client   every zone (JSON, compressed); on join and after each change
--   nwZoneEditor   server → client   the editor on / off (/areaedit)
--   nwZoneEdit     client → server   an admin saves ("save", a zone) or deletes ("delete", id) one

util.AddNetworkString("nwZones")
util.AddNetworkString("nwZoneEditor")
util.AddNetworkString("nwZoneEdit")

local Z = NW.zones
local I = NW.items
local DIR = "network2/zones"

local function Path()
	return DIR .. "/" .. game.GetMap() .. ".json"
end

local function Notify(client, text)
	NW.Notify(client, text)
end

-- what is saved and sent: only the settings (no runtime data)
local function Plain(zone)
	return {id = zone.id, name = zone.name, type = zone.type, min = zone.min, max = zone.max,
		damage = zone.damage, items = zone.items, count = zone.count, interval = zone.interval, npc = zone.npc}
end

local function Payload()
	local list = {}

	for _, zone in pairs(Z.list) do
		list[#list + 1] = Plain(zone)
	end

	return util.Compress(util.TableToJSON(list)) or ""
end

function Z.Send(target)
	local data = Payload()

	net.Start("nwZones")
		net.WriteUInt(#data, 24)
		net.WriteData(data, #data)

	if (target) then
		net.Send(target)
	else
		net.Broadcast()
	end
end

function Z.Save()
	local list = {}

	for _, zone in pairs(Z.list) do
		list[#list + 1] = Plain(zone)
	end

	table.SortByMember(list, "id", true)
	file.CreateDir(DIR)
	file.Write(Path(), util.TableToJSON(list, true))
end

-- a zone from what the editor (or the file) gives, checked and clamped; nil when unusable
local function Clean(data)
	if (!istable(data) or !istable(data.min) or !istable(data.max)) then
		return
	end

	local a = Vector(tonumber(data.min[1]) or 0, tonumber(data.min[2]) or 0, tonumber(data.min[3]) or 0)
	local b = Vector(tonumber(data.max[1]) or 0, tonumber(data.max[2]) or 0, tonumber(data.max[3]) or 0)
	local mins = Vector(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z))
	local maxs = Vector(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))

	if (maxs.x - mins.x < 16 or maxs.y - mins.y < 16 or maxs.z - mins.z < 16) then
		return
	end

	local name = string.Trim(string.gsub(tostring(data.name or ""), "[%c]", " "))

	if (name == "") then
		return
	end

	local zone = {
		name = utf8.len(name) and utf8.len(name) > 48 and string.sub(name, 1, utf8.offset(name, 49) - 1) or name,
		type = Z.typeByID[data.type or ""] and data.type or "plain",
		min = {math.Round(mins.x, 1), math.Round(mins.y, 1), math.Round(mins.z, 1)},
		max = {math.Round(maxs.x, 1), math.Round(maxs.y, 1), math.Round(maxs.z, 1)}
	}

	if (zone.type == "radiation") then
		zone.damage = Z.Clamp("damage", data.damage)
	elseif (zone.type == "items") then
		zone.items = {}

		for _, id in ipairs(istable(data.items) and data.items or {}) do
			if (isstring(id) and I.Get(id) and #zone.items < 32) then
				zone.items[#zone.items + 1] = id
			end
		end

		if (#zone.items == 0) then
			return
		end

		zone.count = Z.Clamp("count", data.count)
		zone.interval = Z.Clamp("interval", data.interval)
	elseif (zone.type == "npcs") then
		local npc = string.Trim(tostring(data.npc or ""))

		if (npc == "" or #npc > 64 or !string.match(npc, "^[%w_]+$")) then
			return
		end

		zone.npc = npc
		zone.count = Z.Clamp("count", data.count)
		zone.interval = Z.Clamp("interval", data.interval)
	end

	return zone
end

function Z.Load()
	Z.list = {}

	for _, saved in ipairs(util.JSONToTable(file.Read(Path(), "DATA") or "") or {}) do
		local zone = Clean(saved)

		if (zone) then
			zone.id = math.floor(tonumber(saved.id) or 0)

			if (zone.id <= 0 or Z.list[zone.id]) then
				zone.id = table.Count(Z.list) + 1

				while (Z.list[zone.id]) do
					zone.id = zone.id + 1
				end
			end

			Z.list[zone.id] = zone
		end
	end
end

Z.Load()

local function NextID()
	local id = 1

	while (Z.list[id]) do
		id = id + 1
	end

	return id
end

-- ------------------------------------------------------------------ editor --
hook.Add("PlayerInitialSpawn", "nwZones", function(client)
	timer.Simple(2, function()
		if (IsValid(client)) then
			Z.Send(client)
		end
	end)
end)

NW.AddChatCommand("areaedit", {admin = true, run = function(client)
	client.nwZoneEditing = !client.nwZoneEditing

	net.Start("nwZoneEditor")
		net.WriteBool(client.nwZoneEditing)
	net.Send(client)

	Z.Send(client)
end})

net.Receive("nwZoneEdit", function(_, client)
	if (!client:IsAdmin()) then
		return
	end

	local action = net.ReadString()

	if (action == "delete") then
		local id = net.ReadUInt(16)
		local zone = Z.list[id]

		if (zone) then
			Z.Clear(zone)
			Z.list[id] = nil
			Z.Save()
			Z.Send()
			Notify(client, "Зона удалена: " .. zone.name)
		end

		return
	end

	if (action != "save") then
		return
	end

	local id = net.ReadUInt(16)
	local zone = Clean(util.JSONToTable(net.ReadString() or "") or {})

	if (!zone) then
		return Notify(client, "Зона не сохранена: проверьте название, размер и настройки")
	end

	local old = Z.list[id]

	if (old) then
		Z.Clear(old)
		zone.id = id
	else
		zone.id = NextID()
	end

	Z.list[zone.id] = zone
	Z.Save()
	Z.Send()
	Notify(client, (old and "Зона изменена: " or "Зона создана: ") .. zone.name)
	MsgN(string.format("[Zones] %s %s zone #%d \"%s\" (%s)", client:SteamName(), old and "changed" or "created",
		zone.id, zone.name, zone.type))
end)

-- --------------------------------------------------------------- radiation --
function Z.Protected(client)
	if (Z.IsAlliance(client)) then
		return true
	end

	local inventory = NW.inventory and NW.inventory.Get(client)
	local cell = inventory and inventory.equip and inventory.equip.face
	local item = cell and I.Get(cell.id)

	return item != nil and item.gasmask == true
end

timer.Create("nwZoneRadiation", 1, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local zone = client:Alive() and client:GetCharacterID() != 0 and !NW.IsInMenu(client) and Z.At(Z.Point(client))
		local radiation = zone and zone.type == "radiation"
		local safe = radiation and Z.Protected(client)

		if (client:GetNW2Bool("nwRadiation", false) != (radiation == true)) then
			client:SetNW2Bool("nwRadiation", radiation == true)
		end

		if (client:GetNW2Bool("nwRadSafe", false) != (safe == true)) then
			client:SetNW2Bool("nwRadSafe", safe == true)
		end

		if (radiation and !safe) then
			local damage = DamageInfo()

			damage:SetDamage(zone.damage or 3)
			damage:SetDamageType(DMG_RADIATION)
			damage:SetAttacker(game.GetWorld())
			damage:SetInflictor(game.GetWorld())
			client:TakeDamageInfo(damage)
		end
	end
end)

-- ---------------------------------------------------------------- spawners --
-- a random free spot on the floor inside the zone for a hull of that size (or nil)
local function Spot(zone, mins, maxs)
	local zmin, zmax = Z.Bounds(zone)

	for _ = 1, 12 do
		local x = math.Rand(zmin.x + 8, zmax.x - 8)
		local y = math.Rand(zmin.y + 8, zmax.y - 8)
		local down = util.TraceLine({start = Vector(x, y, zmax.z - 4), endpos = Vector(x, y, zmin.z - 8),
			mask = MASK_SOLID})

		if (down.Hit and !down.StartSolid and down.HitNormal.z > 0.7 and Z.Contains(zone, down.HitPos + Vector(0, 0, 2))) then
			local pos = down.HitPos + Vector(0, 0, 2)
			local room = util.TraceHull({start = pos, endpos = pos, mins = mins, maxs = maxs, mask = MASK_SOLID})

			if (!room.StartSolid) then
				return pos
			end
		end
	end
end

local function Alive(list, check)
	local out = {}

	for _, entity in ipairs(list or {}) do
		if (IsValid(entity) and check(entity)) then
			out[#out + 1] = entity
		end
	end

	return out
end

local function SpawnItem(zone)
	local pos = Spot(zone, Vector(-8, -8, 0), Vector(8, 8, 16))

	if (!pos) then
		return
	end

	local id = zone.items[math.random(#zone.items)]
	local entity = ents.Create("nw_item")

	if (!IsValid(entity)) then
		return
	end

	entity:SetItem(id, {})
	entity:SetPos(pos + Vector(0, 0, 6))
	entity:SetAngles(Angle(0, math.random(0, 359), 0))
	entity:Spawn()

	return entity
end

local function SpawnNPC(zone)
	local pos = Spot(zone, Vector(-16, -16, 0), Vector(16, 16, 72))

	if (!pos) then
		return
	end

	-- a name from the NPC list (class, model, key values, weapon) or a class
	local data = list.Get("NPC")[zone.npc]
	local class = data and data.Class or zone.npc

	if (!string.match(class, "^npc_") and !scripted_ents.GetStored(class)) then
		return
	end

	local entity = ents.Create(class)

	if (!IsValid(entity)) then
		return
	end

	entity:SetPos(pos)
	entity:SetAngles(Angle(0, math.random(0, 359), 0))

	if (data) then
		if (data.Model) then
			entity:SetModel(data.Model)
		end

		for key, value in pairs(data.KeyValues or {}) do
			entity:SetKeyValue(key, tostring(value))
		end

		if (data.Weapons and #data.Weapons > 0) then
			entity:SetKeyValue("additionalequipment", data.Weapons[math.random(#data.Weapons)])
		end

		if (data.SpawnFlags) then
			entity:SetKeyValue("spawnflags", tostring(data.SpawnFlags))
		end
	end

	entity:Spawn()
	entity:Activate()

	return entity
end

-- what a zone spawned goes away with it (deleted or changed)
function Z.Clear(zone)
	for _, entity in ipairs(zone.spawned or {}) do
		if (IsValid(entity) and (entity:IsNPC() or (entity:GetClass() == "nw_item" and !entity.nwTaken))) then
			entity:Remove()
		end
	end

	zone.spawned = nil
end

timer.Create("nwZoneSpawners", 3, 0, function()
	for _, zone in pairs(Z.list) do
		if (zone.type == "items" or zone.type == "npcs") then
			if (zone.type == "items") then
				zone.spawned = Alive(zone.spawned, function(entity)
					return entity:GetClass() == "nw_item" and !entity.nwTaken
				end)
			else
				zone.spawned = Alive(zone.spawned, function(entity)
					return entity:IsNPC() and entity:Health() > 0
				end)
			end

			if (#zone.spawned < (zone.count or 1) and CurTime() >= (zone.nextSpawn or 0)) then
				local entity = zone.type == "items" and SpawnItem(zone) or SpawnNPC(zone)

				if (IsValid(entity)) then
					zone.spawned[#zone.spawned + 1] = entity
					zone.nextSpawn = CurTime() + (zone.interval or 120)
				else
					-- no free spot this time: try again soon
					zone.nextSpawn = CurTime() + 10
				end
			end
		end
	end
end)

-- a map cleanup removes what was spawned: start the timers over
hook.Add("PostCleanupMap", "nwZones", function()
	for _, zone in pairs(Z.list) do
		zone.spawned, zone.nextSpawn = nil, nil
	end
end)
