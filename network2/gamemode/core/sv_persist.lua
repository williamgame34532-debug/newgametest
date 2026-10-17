-- Entities that stay with the map: the combine locks, the force fields, the ration dispensers, the
-- announcers, the terminals of the Alliance and the CWU, the mailboxes, the factory (whatever
-- registers). Kept in data/network2/entities/<map>.json: {class = {{pos, ang, data}, ...}}.
--   NW.persist.Register(class, {Save = function(entity) return table end,
--                               Load = function(entity, data) end,
--                               Create = function(data) return entity end (optional: when the entity
--                               is not made with ents.Create at pos/ang, a lock on a door)})
--   NW.persist.Save(class)   - after a change (spawned, removed, set up, moved with the physgun)
-- Loaded when the map is ready and after a cleanup.

NW.persist = NW.persist or {}

local P = NW.persist

P.classes = P.classes or {}

local function Path()
	return "network2/entities/" .. game.GetMap() .. ".json"
end

local function Read()
	return util.JSONToTable(file.Read(Path(), "DATA") or "") or {}
end

local loading = false

function P.Register(class, handlers)
	P.classes[class] = handlers or {}
end

function P.Save(class)
	if (loading or !P.classes[class]) then
		return
	end

	local handlers = P.classes[class]
	local all = Read()
	local list = {}

	for _, entity in ipairs(ents.FindByClass(class)) do
		if (IsValid(entity) and !entity.nwRemoving) then
			local pos, ang = entity:GetPos(), entity:GetAngles()

			list[#list + 1] = {
				pos = {math.Round(pos.x, 2), math.Round(pos.y, 2), math.Round(pos.z, 2)},
				ang = {math.Round(ang.p, 2), math.Round(ang.y, 2), math.Round(ang.r, 2)},
				data = handlers.Save and handlers.Save(entity) or nil
			}
		end
	end

	all[class] = list
	file.CreateDir("network2/entities")
	file.Write(Path(), util.TableToJSON(all, true))
end

function P.Load()
	loading = true

	local all = Read()

	for class, list in pairs(all) do
		local handlers = P.classes[class]

		if (handlers) then
			for _, old in ipairs(ents.FindByClass(class)) do
				old.nwRemoving = true
				old:Remove()
			end

			for _, entry in ipairs(list) do
				local pos = Vector(entry.pos[1], entry.pos[2], entry.pos[3])
				local ang = Angle(entry.ang[1], entry.ang[2], entry.ang[3])
				local entity

				if (handlers.Create) then
					entity = handlers.Create(entry.data or {}, pos, ang)
				else
					entity = ents.Create(class)

					if (IsValid(entity)) then
						entity:SetPos(pos)
						entity:SetAngles(ang)
						entity:Spawn()
						entity:Activate()
					end
				end

				if (IsValid(entity) and handlers.Load) then
					handlers.Load(entity, entry.data or {})
				end
			end
		end
	end

	loading = false
end

hook.Add("InitPostEntity", "nwPersist", function()
	timer.Simple(1, P.Load)
end)

hook.Add("PostCleanupMap", "nwPersist", function()
	timer.Simple(0.5, P.Load)
end)

-- moved with the physgun: kept where it was put
hook.Add("PhysgunDrop", "nwPersist", function(client, entity)
	if (IsValid(entity) and P.classes[entity:GetClass()]) then
		local class = entity:GetClass()

		timer.Simple(0.2, function()
			P.Save(class)
		end)
	end
end)

-- spawned from the menu / removed: kept, forgotten
hook.Add("OnEntityCreated", "nwPersist", function(entity)
	local class = IsValid(entity) and entity:GetClass()

	if (!class or !P.classes[class]) then
		return
	end

	timer.Simple(0.5, function()
		if (IsValid(entity) and !loading) then
			P.Save(class)
		end
	end)
end)

hook.Add("EntityRemoved", "nwPersist", function(entity)
	local class = entity:GetClass()

	if (P.classes[class] and !loading and !P.shutdown) then
		entity.nwRemoving = true

		timer.Simple(0, function()
			P.Save(class)
		end)
	end
end)

hook.Add("ShutDown", "nwPersist", function()
	P.shutdown = true
end)

-- the terminals of the Alliance and the CWU: only where they stand
P.Register("nw_cmb_terminal")
P.Register("nw_cwu_terminal")
