-- Items made and changed in the game (/itemedit, cl_itemedit.lua). Kept in
-- data/network2/items.json: {id = {type, name, description, model, icon, iconURL, ...}}. An id of a
-- framework item (framework/items) changes that item (the fields given win; "Сбросить" brings the
-- file back), a new id is a new item. Every player gets them on joining and after every change.
-- The type gives the item what makes it work:
--   misc       a thing (junk, a document, a part)
--   food       hunger;                     drink      thirst
--   medical    heal;                       weapon     slot (primary / secondary / melee), weapon (SWEP)
--   clothing   slot (head, face, torso, hands, legs, feet), wear = bodygroup + submodel, protect,
--              gasmask
--   bag        bag (extra cells), the "Сумка" slot
--   radio      a radio (sh_radio.lua): E - the channels, the key - talk
--   package    contents (ids, comma separated): opened by holding the mouse
--   nvg        night vision goggles (cl_vision.lua): put on the head, the key ПНВ (F)
--   light      a flashlight: while carried the HL2 flashlight works; using it switches it
-- Every item may have a price (the shops of the businesses, sv_business.lua, start from it).
-- The icon: one of materials/network2/items/*.png, or a picture by a link (iconURL, png / jpg; the
-- client downloads it to data/network2/icons).

NW.itemEdit = NW.itemEdit or {}

local IE = NW.itemEdit
local I = NW.items

IE.types = {
	{id = "misc", name = "Предмет", category = "misc",
		hint = "Вещь без особых действий: хлам, документ, деталь, товар, сырьё для крафта."},
	{id = "food", name = "Еда", category = "food", base = "food",
		hint = "Съедается: снимает голод. «Остаётся после» — что ляжет в ячейку (пустая банка)."},
	{id = "drink", name = "Напиток", category = "drink", base = "drink",
		hint = "Выпивается: снимает жажду. Может оставлять пустую бутылку."},
	{id = "medical", name = "Медицина", category = "medical", base = "medical",
		hint = "Лечит: здоровье + и одно из ранений (кровотечение, перелом, боль, отравление) или всё сразу. " ..
			"Видна на странице «Состояние» инвентаря."},
	{id = "weapon", name = "Оружие", category = "weapon", base = "weapon",
		hint = "Кладётся в слот оружия и выдаёт SWEP (класс оружия, например weapon_pistol)."},
	{id = "clothing", name = "Одежда", category = "clothing", base = "clothing",
		hint = "Надевается в слот. Бодигруппа и вариант — как выглядит на модели; защита снижает урон."},
	{id = "bag", name = "Сумка", category = "misc", base = "bag",
		hint = "Слот «Сумка»: добавляет ячейки под сеткой инвентаря."},
	{id = "radio", name = "Рация", category = "misc",
		hint = "Работает как рация: ПКМ → каналы, говорить — клавиша рации (H)."},
	{id = "package", name = "Упаковка", category = "misc", base = "package",
		hint = "Внутри лежат предметы (ID через запятую): зажать мышь, чтобы открыть."},
	{id = "nvg", name = "ПНВ", category = "clothing", base = "clothing",
		hint = "Прибор ночного видения: надевается на голову, включается клавишей ПНВ (F), 30 с работы."},
	{id = "light", name = "Фонарик", category = "misc",
		hint = "Пока при себе — работает фонарик (F); «Использовать» включает и выключает свет."}
}

IE.typeByID = {}

for _, entry in ipairs(IE.types) do
	IE.typeByID[entry.id] = entry
end

-- the fields an entry may have (and what kind of value)
IE.fields = {
	type = "string", name = "string", description = "string", model = "string", icon = "string", iconURL = "string",
	useVerb = "string", useSound = "string", leaves = "string", slot = "string", weapon = "string",
	wearGroup = "string", contents = "string", cure = "string",
	hunger = "number", thirst = "number", heal = "number", protect = "number", bag = "number", wearIndex = "number",
	price = "number", gasmask = "boolean"
}

-- the numbers that may be bigger
IE.limits = {price = 100000}

IE.data = IE.data or {}
IE.originals = IE.originals or {}

-- an entry (from the file / the editor) made clean
function IE.Sanitize(entry)
	local out = {}

	for key, kind in pairs(IE.fields) do
		local value = entry[key]

		if (kind == "string" and isstring(value)) then
			out[key] = string.sub(string.Trim(value), 1, key == "description" and 600 or 200)
		elseif (kind == "number" and tonumber(value)) then
			out[key] = math.Clamp(tonumber(value), IE.limits[key] and 0 or -1000, IE.limits[key] or 1000)
		elseif (kind == "boolean" and value != nil) then
			out[key] = tobool(value)
		end
	end

	if (!IE.typeByID[out.type or ""]) then
		out.type = "misc"
	end

	if (out.cure and NW.medical and !NW.medical.cureNames[out.cure]) then
		out.cure = nil
	end

	if (out.iconURL and !string.match(out.iconURL, "^https?://")) then
		out.iconURL = nil
	end

	for key, value in pairs(out) do
		if (value == "") then
			out[key] = nil
		end
	end

	return out
end

-- one entry onto the list of items
local function Apply(id, entry)
	local original = IE.originals[id]

	if (I.list[id] and !original) then
		original = table.Copy(I.list[id])
		IE.originals[id] = original
	end

	local kind = IE.typeByID[entry.type or "misc"] or IE.typeByID.misc
	local item = table.Copy(original or I.bases[kind.base or ""] or {})

	item.custom = original == nil
	item.edited = true
	item.type = entry.type
	item.category = kind.category

	for key, value in pairs(entry) do
		if (key != "type") then
			item[key] = value
		end
	end

	if (entry.wearGroup) then
		item.wear = {group = entry.wearGroup, index = entry.wearIndex or 1}
	end

	if (entry.type == "bag") then
		item.slot = "bag"
	end

	if (entry.contents) then
		local list = {}

		for part in string.gmatch(entry.contents, "[^,%s]+") do
			list[#list + 1] = part
		end

		item.contents = list
	end

	-- a radio works like the radio of the framework
	if (entry.type == "radio") then
		item.radio = true
		item.icon = entry.icon or "radio"
		item.useVerb = entry.useVerb or "настроить"
		item.OnUse = function(client)
			NW.radio.Open(client)

			return false
		end
	end

	-- night vision goggles: on the head
	if (entry.type == "nvg") then
		item.nvg = true
		item.slot = "head"
		item.icon = entry.icon or "nvg"
	end

	-- a flashlight: the light while carried (sv_inventory.lua)
	if (entry.type == "light") then
		item.flashlight = true
		item.icon = entry.icon or "flashlight"
		item.useVerb = entry.useVerb or "включить / выключить"
		item.OnUse = function(client)
			client:Flashlight(!client:FlashlightIsOn())
			client:EmitSound("items/flashlight1.wav", 55)

			return false
		end
	end

	-- weapons and clothes without a slot: the first fitting one
	if (entry.type == "weapon" and !item.slot) then
		item.slot = "secondary"
	elseif (entry.type == "clothing" and !item.slot) then
		item.slot = "torso"
	end

	item.icon = item.icon or id
	I.Register(id, item)
end

-- all the entries (after a reset of the ones gone)
function IE.ApplyAll(data)
	for id, original in pairs(IE.originals) do
		if (!data[id]) then
			I.Register(id, table.Copy(original))
			IE.originals[id] = nil
		end
	end

	for id, item in pairs(I.list) do
		if (item.custom and !data[id]) then
			I.list[id] = nil
		end
	end

	for id, entry in pairs(data) do
		Apply(id, entry)
	end

	IE.data = data
	hook.Run("NWItemsChanged")
end

if (SERVER) then
	util.AddNetworkString("nwItemEditData")
	util.AddNetworkString("nwItemEditOpen")
	util.AddNetworkString("nwItemEditSave")
	util.AddNetworkString("nwItemEditDelete")
	util.AddNetworkString("nwItemEditGive")

	local PATH = "network2/items.json"

	local function Send(target)
		local json = util.Compress(util.TableToJSON(IE.data))

		net.Start("nwItemEditData")
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
		file.Write(PATH, util.TableToJSON(IE.data, true))
		Send()
	end

	local loaded = util.JSONToTable(file.Read(PATH, "DATA") or "") or {}
	local clean = {}

	for id, entry in pairs(loaded) do
		if (isstring(id) and istable(entry)) then
			clean[id] = IE.Sanitize(entry)
		end
	end

	IE.ApplyAll(clean)

	hook.Add("PlayerInitialSpawn", "nwItemEdit", function(client)
		timer.Simple(1, function()
			if (IsValid(client)) then
				Send(client)
			end
		end)
	end)

	NW.AddChatCommand("itemedit", {admin = true, run = function(client)
		net.Start("nwItemEditOpen")
		net.Send(client)
	end})

	net.Receive("nwItemEditSave", function(_, client)
		if (!client:IsAdmin()) then
			return
		end

		local id = string.lower(string.gsub(net.ReadString() or "", "[^%w_]", ""))
		local entry = util.JSONToTable(net.ReadString() or "") or {}

		if (id == "" or #id > 40) then
			return NW.Notify(client, "ID: латиница, цифры и _")
		end

		entry = IE.Sanitize(entry)

		if (!entry.name) then
			return NW.Notify(client, "Нужно название")
		end

		local data = table.Copy(IE.data)

		data[id] = entry
		IE.ApplyAll(data)
		Save()
		NW.Notify(client, "Предмет сохранён: " .. entry.name .. " (" .. id .. ")")
		MsgN(string.format("[ITEMEDIT] %s (%s) сохранил %s", client:Nick(), client:SteamName(), id))
	end)

	net.Receive("nwItemEditDelete", function(_, client)
		local id = net.ReadString()

		if (!client:IsAdmin() or !IE.data[id]) then
			return
		end

		local data = table.Copy(IE.data)
		local framework = IE.originals[id] != nil

		data[id] = nil
		IE.ApplyAll(data)
		Save()
		NW.Notify(client, framework and ("Предмет сброшен к исходному: " .. id) or ("Предмет удалён: " .. id))
	end)

	net.Receive("nwItemEditGive", function(_, client)
		local id = net.ReadString()

		if (!client:IsAdmin() or !I.Get(id)) then
			return
		end

		if (!NW.inventory.Add(client, id)) then
			NW.inventory.SpawnWorldItem(client, {id = id, data = {}})
		end

		NW.inventory.Changed(client)
	end)

	return
end

net.Receive("nwItemEditData", function()
	local length = net.ReadUInt(32)
	local json = util.Decompress(net.ReadData(length) or "")

	IE.ApplyAll(util.JSONToTable(json or "") or {})
end)

-- ------------------------------------------------------------------ icons --
-- the material of the icon of an item: the picture of its link (downloaded once) or the file
local downloads = {}

local function Downloaded(url)
	local entry = downloads[url]

	if (entry) then
		return entry.material
	end

	entry = {}
	downloads[url] = entry

	local name = "network2/icons/" .. util.CRC(url) .. (string.find(string.lower(url), "%.jpe?g") and ".jpg" or ".png")

	local function Load()
		entry.material = Material("../data/" .. name, "smooth mips")
	end

	if (file.Exists(name, "DATA")) then
		Load()
	else
		http.Fetch(url, function(body)
			file.CreateDir("network2/icons")
			file.Write(name, body)
			Load()
		end)
	end

	return entry.material
end

function I.IconMaterial(item)
	if (item and item.iconURL) then
		local material = Downloaded(item.iconURL)

		if (material and !material:IsError()) then
			return material
		end
	end

	return NW.ui.Material("network2/items/" .. (item and item.icon or "bag") .. ".png")
end
