-- Crafting. A crafting table (entities/entities/nw_craft_table.lua) is a station of a kind (Верстак,
-- Кухня, Химический стол - NW.craft.stations); E - its window (cl_craft.lua) with the recipes of
-- that kind. A recipe:
--   id, result (item id), count, ingredients = {{item, count}, ...}, time (seconds), station,
--   category (a group in the list), skill + level (a skill needed, sh_skills.lua), xp (experience of
--   that skill or of Инженерия for making it)
-- Everything is set up in the game by admins: the window → Редактор (new, change, delete). Kept in
-- data/network2/recipes.json, sent to every player.

NW.craft = NW.craft or {}

local CR = NW.craft

CR.stations = {
	{id = "workbench", name = "Верстак", icon = "tool"},
	{id = "kitchen", name = "Кухня", icon = "hunger"},
	{id = "chem", name = "Химический стол", icon = "biohazard"}
}

CR.stationByID = {}

for _, station in ipairs(CR.stations) do
	CR.stationByID[station.id] = station
end

CR.recipes = CR.recipes or {}

CR.defaults = {
	parts = {result = "parts", count = 1, ingredients = {{item = "scrap", count = 2}}, time = 5, station = "workbench",
		category = "Материалы", skill = "engineering", level = 0, xp = 3},
	toolkit = {result = "toolkit", count = 1, ingredients = {{item = "parts", count = 2}, {item = "scrap", count = 1}},
		time = 8, station = "workbench", category = "Инструменты", skill = "engineering", level = 2, xp = 6},
	flashlight = {result = "flashlight", count = 1, ingredients = {{item = "parts", count = 1}, {item = "can_empty",
		count = 1}}, time = 6, station = "workbench", category = "Инструменты", skill = "engineering", level = 1, xp = 4},
	radio = {result = "radio", count = 1, ingredients = {{item = "unit_core", count = 1}, {item = "parts", count = 1}},
		time = 12, station = "workbench", category = "Электроника", skill = "engineering", level = 4, xp = 10},
	bandage = {result = "bandage", count = 1, ingredients = {{item = "water", count = 1}, {item = "bottle_empty",
		count = 1}}, time = 6, station = "chem", category = "Медицина", skill = "medicine", level = 1, xp = 4}
}

function CR.Sanitize(recipe)
	recipe = istable(recipe) and recipe or {}

	local out = {
		result = isstring(recipe.result) and recipe.result or "",
		count = math.Clamp(math.floor(tonumber(recipe.count) or 1), 1, 20),
		time = math.Clamp(tonumber(recipe.time) or 5, 0.5, 120),
		station = CR.stationByID[recipe.station or ""] and recipe.station or "workbench",
		category = string.sub(string.Trim(tostring(recipe.category or "Разное")), 1, 32),
		skill = (NW.skills and NW.skills.info[recipe.skill or ""]) and recipe.skill or "",
		level = math.Clamp(math.floor(tonumber(recipe.level) or 0), 0, 10),
		xp = math.Clamp(math.floor(tonumber(recipe.xp) or 0), 0, 100),
		ingredients = {}
	}

	for _, entry in ipairs(istable(recipe.ingredients) and recipe.ingredients or {}) do
		if (#out.ingredients < 8 and istable(entry) and isstring(entry.item) and entry.item != "") then
			out.ingredients[#out.ingredients + 1] = {item = entry.item,
				count = math.Clamp(math.floor(tonumber(entry.count) or 1), 1, 20)}
		end
	end

	if (out.category == "") then
		out.category = "Разное"
	end

	return out
end

-- how many of an item a grid holds
function CR.Count(grid, id)
	local count = 0

	for index = 1, NW.items.maxSize do
		if (grid[index] and grid[index].id == id) then
			count = count + 1
		end
	end

	return count
end

-- can it be made from this grid (and this skill level)? ok, why not
function CR.Can(recipe, grid, level)
	if (!NW.items.Get(recipe.result)) then
		return false, "Предмета больше нет"
	end

	if (recipe.skill != "" and (level or 0) < recipe.level) then
		return false, "Нужен навык"
	end

	for _, entry in ipairs(recipe.ingredients) do
		if (CR.Count(grid, entry.item) < entry.count) then
			return false, "Не хватает материалов"
		end
	end

	return true
end

if (SERVER) then
	util.AddNetworkString("nwCraftData")
	util.AddNetworkString("nwCraftOpen")
	util.AddNetworkString("nwCraftMake")
	util.AddNetworkString("nwCraftSave")
	util.AddNetworkString("nwCraftDelete")

	local PATH = "network2/recipes.json"

	local function Send(target)
		local json = util.Compress(util.TableToJSON(CR.recipes))

		net.Start("nwCraftData")
			net.WriteUInt(#json, 32)
			net.WriteData(json, #json)
		if (target) then
			net.Send(target)
		else
			net.Broadcast()
		end
	end

	local function Save()
		file.CreateDir("network2")
		file.Write(PATH, util.TableToJSON(CR.recipes, true))
		Send()
	end

	local saved = file.Read(PATH, "DATA")

	CR.recipes = {}

	for id, recipe in pairs(saved and (util.JSONToTable(saved) or {}) or CR.defaults) do
		CR.recipes[id] = CR.Sanitize(recipe)
	end

	hook.Add("PlayerInitialSpawn", "nwCraft", function(client)
		timer.Simple(1.5, function()
			if (IsValid(client)) then
				Send(client)
			end
		end)
	end)

	function CR.Open(client, table)
		net.Start("nwCraftOpen")
			net.WriteEntity(table)
		net.Send(client)
	end

	net.Receive("nwCraftMake", function(_, client)
		local bench = net.ReadEntity()
		local id = net.ReadString()
		local recipe = CR.recipes[id]

		if (!recipe or !IsValid(bench) or bench:GetClass() != "nw_craft_table" or bench:GetStation() != recipe.station or
			client:GetPos():DistToSqr(bench:GetPos()) > 160 * 160 or client:GetCharacterID() == 0 or
			(NW.Incapable and NW.Incapable(client))) then
			return
		end

		local inventory = NW.inventory.Get(client)
		local level = recipe.skill != "" and NW.skills.Level(client, recipe.skill) or 0
		local ok, why = CR.Can(recipe, inventory.grid, level)

		if (!ok) then
			return NW.Notify(client, why)
		end

		local seconds = recipe.time * NW.skills.Factor(client, recipe.skill != "" and recipe.skill or "engineering", -0.04)

		if (NW.progress.Start(client, "Создаю: " .. (NW.items.Get(recipe.result).name or recipe.result), seconds, function()
			if (!CR.Can(recipe, inventory.grid, level)) then
				return NW.Notify(client, "Не хватает материалов")
			end

			for _, entry in ipairs(recipe.ingredients) do
				local left = entry.count

				for index = 1, NW.items.maxSize do
					if (left > 0 and inventory.grid[index] and inventory.grid[index].id == entry.item) then
						inventory.grid[index] = nil
						left = left - 1
					end
				end
			end

			for _ = 1, recipe.count do
				if (!NW.inventory.Add(client, recipe.result)) then
					NW.inventory.SpawnWorldItem(client, {id = recipe.result, data = {}})
				end
			end

			NW.inventory.Changed(client)
			NW.skills.Add(client, recipe.skill != "" and recipe.skill or "engineering", recipe.xp)
			bench:EmitSound("physics/metal/metal_solid_impact_soft" .. math.random(1, 3) .. ".wav", 60)
			NW.Notify(client, "Создано: " .. NW.items.Get(recipe.result).name .. (recipe.count > 1 and (" ×" .. recipe.count) or ""))
		end, function()
			return IsValid(bench) and client:Alive() and client:GetPos():DistToSqr(bench:GetPos()) < 160 * 160
		end)) then
			bench:EmitSound("physics/wood/wood_box_impact_soft" .. math.random(1, 3) .. ".wav", 60)
		end
	end)

	net.Receive("nwCraftSave", function(_, client)
		if (!client:IsAdmin()) then
			return
		end

		local id = string.lower(string.gsub(net.ReadString() or "", "[^%w_]", ""))
		local recipe = CR.Sanitize(util.JSONToTable(net.ReadString() or "") or {})

		if (id == "" or !NW.items.Get(recipe.result) or #recipe.ingredients == 0) then
			return NW.Notify(client, "Рецепт: нужен ID, результат и хотя бы один материал")
		end

		CR.recipes[id] = recipe
		Save()
		NW.Notify(client, "Рецепт сохранён: " .. id)
	end)

	net.Receive("nwCraftDelete", function(_, client)
		local id = net.ReadString()

		if (client:IsAdmin() and CR.recipes[id]) then
			CR.recipes[id] = nil
			Save()
			NW.Notify(client, "Рецепт удалён: " .. id)
		end
	end)

	return
end

net.Receive("nwCraftData", function()
	local length = net.ReadUInt(32)
	local json = util.Decompress(net.ReadData(length) or "")

	CR.recipes = util.JSONToTable(json or "") or {}
	hook.Run("NWRecipesChanged")
end)
