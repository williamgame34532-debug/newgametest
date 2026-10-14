-- Containers (entities/entities/nw_container.lua): settings, loot, saving.
-- Settings (an admin, the storage window → Настроить): title, model, cols x rows (1..10),
-- refresh (seconds; 0 - the loot never comes back), loot = {{item, chance %, min, max}, ...}.
-- Filling: the grid is emptied, then every loot line rolls its chance and puts min..max of its
-- item into random free cells. Every container on the map is saved to
-- data/network2/containers/<map>.json with its settings and what lies in it, and comes back
-- after a restart or a map cleanup.

util.AddNetworkString("nwContainerConfig")

NW.containers = NW.containers or {}

local CT = NW.containers
local I = NW.items
local DIR = "network2/containers"

function CT.Default()
	return {title = "Контейнер", model = "models/props_junk/wood_crate001a.mdl", cols = 6, rows = 4, refresh = 0,
		loot = {}, grid = {}, tokens = 0}
end

-- the storage source of a container (sv_storage.lua)
function CT.Source(entity)
	local data = entity.nwData

	return {
		key = "container" .. entity:EntIndex(),
		title = data.title or "Контейнер",
		icon = "storage",
		entity = entity,
		cols = data.cols,
		rows = data.rows,
		Get = function(index)
			return data.grid[index]
		end,
		Set = function(index, cell)
			data.grid[index] = cell
		end,
		GetTokens = function()
			return data.tokens or 0
		end,
		SetTokens = function(amount)
			data.tokens = amount
		end,
		Valid = function(client)
			return IsValid(entity) and client:GetPos():DistToSqr(entity:GetPos()) < 140 * 140
		end,
		Changed = CT.Changed,
		config = function()
			return {title = data.title, model = data.model, cols = data.cols, rows = data.rows, refresh = data.refresh,
				loot = data.loot}
		end
	}
end

function CT.Fill(entity)
	local data = entity.nwData
	local size = data.cols * data.rows

	data.grid = {}

	for _, line in ipairs(data.loot or {}) do
		if (I.Get(line.item) and math.random() * 100 < (line.chance or 0)) then
			for _ = 1, math.random(line.min or 1, math.max(line.min or 1, line.max or 1)) do
				local free = {}

				for index = 1, size do
					if (!data.grid[index]) then
						free[#free + 1] = index
					end
				end

				if (#free == 0) then
					break
				end

				data.grid[free[math.random(#free)]] = {id = line.item, data = {}}
			end
		end
	end

	NW.storage.Refresh("container" .. entity:EntIndex())
	CT.Changed()
end

-- ------------------------------------------------------------------ saving --
local loading = false

local function Path()
	return DIR .. "/" .. game.GetMap() .. ".json"
end

local function Save()
	local list = {}

	for _, entity in ipairs(ents.FindByClass("nw_container")) do
		local data = entity.nwData

		if (data) then
			local grid = {}

			for index, cell in pairs(data.grid or {}) do
				grid[#grid + 1] = {index, cell.id, cell.data or {}}
			end

			local pos, ang = entity:GetPos(), entity:GetAngles()

			list[#list + 1] = {
				pos = {pos.x, pos.y, pos.z}, ang = {ang.p, ang.y, ang.r},
				title = data.title, model = data.model, cols = data.cols, rows = data.rows, refresh = data.refresh,
				loot = data.loot, tokens = data.tokens, grid = grid
			}
		end
	end

	file.CreateDir(DIR)
	file.Write(Path(), util.TableToJSON(list, true))
end

function CT.Changed()
	if (loading) then
		return
	end

	timer.Create("nwContainersSave", 1, 1, Save)
end

local function Load()
	loading = true

	for _, saved in ipairs(util.JSONToTable(file.Read(Path(), "DATA") or "") or {}) do
		local entity = ents.Create("nw_container")

		if (IsValid(entity)) then
			local data = CT.Default()

			data.title, data.model = saved.title or data.title, saved.model or data.model
			data.cols = math.Clamp(tonumber(saved.cols) or 6, 1, 10)
			data.rows = math.Clamp(tonumber(saved.rows) or 4, 1, 10)
			data.refresh = math.max(0, tonumber(saved.refresh) or 0)
			data.loot = istable(saved.loot) and saved.loot or {}
			data.tokens = math.max(0, tonumber(saved.tokens) or 0)

			for _, entry in ipairs(saved.grid or {}) do
				if (I.Get(entry[2])) then
					data.grid[tonumber(entry[1])] = {id = entry[2], data = istable(entry[3]) and entry[3] or {}}
				end
			end

			entity.nwData = data
			entity:SetPos(Vector(saved.pos[1], saved.pos[2], saved.pos[3]))
			entity:SetAngles(Angle(saved.ang[1], saved.ang[2], saved.ang[3]))
			entity:Spawn()
			entity:Activate()
		end
	end

	loading = false
end

hook.Add("InitPostEntity", "nwContainers", Load)
hook.Add("PostCleanupMap", "nwContainers", Load)

hook.Add("ShutDown", "nwContainers", function()
	Save()
	loading = true
end)

-- moved with the physgun: saved where it was left
hook.Add("PhysgunDrop", "nwContainers", function(_, entity)
	if (IsValid(entity) and entity:GetClass() == "nw_container") then
		local physics = entity:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:EnableMotion(false)
		end

		CT.Changed()
	end
end)

-- ---------------------------------------------------------------- settings --
net.Receive("nwContainerConfig", function(_, client)
	local entity = net.ReadEntity()
	local action = net.ReadString()
	local config = util.JSONToTable(net.ReadString()) or {}

	if (!client:IsAdmin() or !IsValid(entity) or entity:GetClass() != "nw_container") then
		return
	end

	local data = entity.nwData

	if (action == "clear") then
		data.grid = {}
		NW.storage.Refresh("container" .. entity:EntIndex())
		CT.Changed()

		return
	end

	data.title = string.sub(string.Trim(tostring(config.title or "")), 1, 64)
	data.title = data.title != "" and data.title or "Контейнер"
	data.model = string.sub(tostring(config.model or ""), 1, 200)
	data.cols = math.Clamp(math.floor(tonumber(config.cols) or 6), 1, 10)
	data.rows = math.Clamp(math.floor(tonumber(config.rows) or 4), 1, 10)
	data.refresh = math.Clamp(math.floor(tonumber(config.refresh) or 0), 0, 86400)
	data.loot = {}

	for _, line in ipairs(istable(config.loot) and config.loot or {}) do
		if (#data.loot < 40 and istable(line) and I.Get(line.item)) then
			local min = math.Clamp(math.floor(tonumber(line.min) or 1), 1, 20)

			data.loot[#data.loot + 1] = {item = line.item, chance = math.Clamp(tonumber(line.chance) or 0, 0, 100),
				min = min, max = math.Clamp(math.floor(tonumber(line.max) or min), min, 20)}
		end
	end

	-- what no longer fits in a smaller grid is lost
	for index in pairs(data.grid) do
		if (index > data.cols * data.rows) then
			data.grid[index] = nil
		end
	end

	entity.nwNextRefresh = nil
	entity:Apply()

	if (action == "fill") then
		CT.Fill(entity)
	end

	CT.Changed()

	-- whoever looks at it gets the new grid
	for viewer in pairs(NW.storage.viewers["container" .. entity:EntIndex()] or {}) do
		if (IsValid(viewer) and viewer.nwStorage and viewer.nwStorage.key == "container" .. entity:EntIndex()) then
			NW.storage.Open(viewer, CT.Source(entity))
		end
	end

	NW.Notify(client, "Контейнер сохранён: " .. data.title)
end)
