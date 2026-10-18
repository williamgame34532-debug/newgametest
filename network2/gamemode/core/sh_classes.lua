-- The classes of the factions: each faction can have any number of classes with their own name, description,
-- colour, statistics, models and things. Made in the game and kept in data/network2/classes.json.
--   /classedit   admins: the editor - the list on the left (by faction), the form on the right: the id, the
--                faction, the name, the description, the colour, the health, the armour, the speed of the
--                walk and the run, the models (one per line, the player picks one), the skin, the things
--                given once (ids through commas), how many may be in it at once (0 - any), by the admins
--                only (the player cannot take it himself), the default class of the faction
--   /class       the player: the classes of his faction as cards (the statistics, the models to choose
--                from, who is in it now / the limit) - «Выбрать». Saved with the character.
-- What a class gives: the health and its maximum, the armour on every spawn; the speeds (sv_movement.lua);
-- the model (the admin's /setmodel still wins; then the class, then the faction); its things once; its
-- name and colour over the faction on the unit card and in the TAB list (nwClassName / nwClassColor).
-- A new faction: the class is dropped (the default class of the new faction, if there is one, is given).

NW.classes = NW.classes or {}

local CS = NW.classes

CS.data = CS.data or {}

CS.fields = {
	faction = "string", name = "string", description = "string", models = "string", items = "string", color = "string",
	health = "number", armor = "number", walk = "number", run = "number", skin = "number", limit = "number",
	adminOnly = "boolean", default = "boolean"
}

function CS.Sanitize(entry)
	local out = {}

	for key, kind in pairs(CS.fields) do
		local value = entry[key]

		if (kind == "string" and isstring(value)) then
			out[key] = string.sub(string.Trim(value), 1, key == "description" and 500 or (key == "models" and 2000 or 120))
		elseif (kind == "number" and tonumber(value)) then
			out[key] = math.Clamp(math.floor(tonumber(value)), 0, 1000)
		elseif (kind == "boolean") then
			out[key] = value == true
		end
	end

	for key, value in pairs(out) do
		if (value == "" or (CS.fields[key] == "number" and value == 0 and key != "skin" and key != "limit")) then
			out[key] = nil
		end
	end

	return out
end

-- the list of the models of a class
function CS.Models(class)
	local out = {}

	for line in string.gmatch(class.models or "", "[^\n,;]+") do
		line = string.lower(string.Trim(line))

		if (line != "") then
			out[#out + 1] = line
		end
	end

	return out
end

function CS.Color(class)
	local r, g, b = string.match(class.color or "", "(%d+)%D+(%d+)%D+(%d+)")

	return r and Color(tonumber(r), tonumber(g), tonumber(b)) or Color(200, 206, 212)
end

-- the class of a player now (the table, the id)
function CS.Of(client)
	local id = client:GetNW2String("nwClass", "")
	local class = CS.data[id]

	if (class and class.faction == client:GetFaction()) then
		return class, id
	end
end

function CS.OfFaction(faction)
	local out = {}

	for id, class in SortedPairsByMemberValue(CS.data, "name") do
		if (class.faction == faction) then
			out[#out + 1] = {id = id, class = class}
		end
	end

	return out
end

function CS.Count(id)
	local count = 0

	for _, client in ipairs(player.GetAll()) do
		if (client:GetNW2String("nwClass", "") == id) then
			count = count + 1
		end
	end

	return count
end

if (SERVER) then
	util.AddNetworkString("nwClasses")
	util.AddNetworkString("nwClassEditOpen")
	util.AddNetworkString("nwClassSave")
	util.AddNetworkString("nwClassDelete")
	util.AddNetworkString("nwClassOpen")
	util.AddNetworkString("nwClassChoose")

	local PATH = "network2/classes.json"

	local function Send(target)
		local json = util.Compress(util.TableToJSON(CS.data))

		net.Start("nwClasses")
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
		file.Write(PATH, util.TableToJSON(CS.data, true))
		Send()
	end

	for id, entry in pairs(util.JSONToTable(file.Read(PATH, "DATA") or "") or {}) do
		if (isstring(id) and istable(entry)) then
			CS.data[id] = CS.Sanitize(entry)
		end
	end

	hook.Add("PlayerInitialSpawn", "nwClasses", function(client)
		timer.Simple(1, function()
			if (IsValid(client)) then
				Send(client)
			end
		end)
	end)

	-- what a class does to the body: on every spawn and when chosen
	function CS.Apply(client)
		local class = CS.Of(client)

		client:SetNW2String("nwClassName", class and class.name or "")
		client:SetNW2String("nwClassColor", class and class.color or "")

		if (NW.movement) then
			NW.movement.Apply(client)
		end

		if (!client:Alive()) then
			return
		end

		local health = class and class.health or 100

		client:SetMaxHealth(health)
		client:SetHealth(math.min(math.max(client:Health(), 1), health))

		if (class and class.armor) then
			client:SetArmor(class.armor)
		end
	end

	function CS.Set(client, id, modelIndex)
		local character = client.nwCharacter

		if (!character) then
			return false, "Нет персонажа"
		end

		character.data = character.data or {}

		local class = id and CS.data[id]

		if (id and !class) then
			return false, "Нет такого класса"
		end

		character.data.class = id
		character.data.classModel = modelIndex
		client:SetNW2String("nwClass", id or "")

		-- its things, once per character
		if (class and class.items) then
			character.data.classItems = character.data.classItems or {}

			if (!character.data.classItems[id]) then
				character.data.classItems[id] = true

				for item in string.gmatch(class.items, "[^,%s]+") do
					if (NW.items.Get(item) and !NW.inventory.Add(client, item)) then
						NW.inventory.SpawnWorldItem(client, {id = item, data = {}})
					end
				end

				NW.inventory.Changed(client)
			end
		end

		NW.char.SaveData(client)

		if (client:Alive()) then
			NW.models.Apply(client)
		end

		CS.Apply(client)

		return true
	end

	hook.Add("NWCharacterLoaded", "nwClasses", function(client, character)
		local id = character.data and character.data.class

		client:SetNW2String("nwClass", (id and CS.data[id]) and id or "")

		timer.Simple(0.3, function()
			if (IsValid(client)) then
				CS.Apply(client)
			end
		end)
	end)

	hook.Add("PlayerSpawn", "nwClasses", function(client)
		timer.Simple(0.2, function()
			if (IsValid(client) and client:GetCharacterID() != 0) then
				CS.Apply(client)
			end
		end)
	end)

	-- a new faction: the old class goes; the default class of the new one comes
	hook.Add("NWFactionChanged", "nwClasses", function(client, faction)
		local default

		for id, class in pairs(CS.data) do
			if (class.faction == faction and class.default) then
				default = id
			end
		end

		CS.Set(client, default)
	end)

	-- ---------------------------------------------------------------- the editor --
	NW.AddChatCommand("classedit", {admin = true, run = function(client)
		Send(client)
		net.Start("nwClassEditOpen")
		net.Send(client)
	end})

	net.Receive("nwClassSave", function(_, client)
		if (!client:IsAdmin()) then
			return
		end

		local id = string.lower(string.gsub(net.ReadString() or "", "[^%w_]", ""))
		local entry = CS.Sanitize(util.JSONToTable(net.ReadString() or "") or {})

		if (id == "" or #id > 40) then
			return NW.Notify(client, "ID: латиница, цифры и _")
		elseif (!entry.name or !entry.faction or !NW.char.factions[entry.faction]) then
			return NW.Notify(client, "Нужны название и фракция")
		end

		CS.data[id] = entry
		Save()
		NW.Notify(client, "Класс сохранён: " .. entry.name .. " (" .. id .. ")")
		MsgN(string.format("[CLASSES] %s (%s) сохранил %s", client:Nick(), client:SteamName(), id))

		for _, target in ipairs(player.GetAll()) do
			if (target:GetNW2String("nwClass", "") == id) then
				CS.Apply(target)

				if (target:Alive()) then
					NW.models.Apply(target)
				end
			end
		end
	end)

	net.Receive("nwClassDelete", function(_, client)
		local id = net.ReadString()

		if (!client:IsAdmin() or !CS.data[id]) then
			return
		end

		CS.data[id] = nil
		Save()

		for _, target in ipairs(player.GetAll()) do
			if (target:GetNW2String("nwClass", "") == id) then
				CS.Set(target, nil)
			end
		end

		NW.Notify(client, "Класс удалён: " .. id)
	end)

	-- ---------------------------------------------------------------- the choice --
	NW.AddChatCommand("class", {run = function(client)
		if (client:GetCharacterID() == 0) then
			return
		end

		Send(client)
		net.Start("nwClassOpen")
		net.Send(client)
	end})

	net.Receive("nwClassChoose", function(_, client)
		local id = net.ReadString()
		local modelIndex = net.ReadUInt(8)
		local class = CS.data[id]

		if ((client.nwClassNext or 0) > CurTime() or client:GetCharacterID() == 0) then
			return
		end

		client.nwClassNext = CurTime() + 2

		if (id == "") then
			CS.Set(client, nil)

			return NW.Notify(client, "Без класса")
		end

		if (!class or class.faction != client:GetFaction()) then
			return NW.Notify(client, "Этот класс не вашей фракции")
		elseif (class.adminOnly and !client:IsAdmin()) then
			return NW.Notify(client, "Этот класс назначает администрация")
		elseif ((class.limit or 0) > 0 and client:GetNW2String("nwClass", "") != id and CS.Count(id) >= class.limit) then
			return NW.Notify(client, "В классе нет мест: " .. class.limit)
		end

		local ok, why = CS.Set(client, id, modelIndex > 0 and modelIndex or nil)

		NW.Notify(client, ok and ("Класс: " .. class.name) or why)
	end)

	-- /setclass <игрок> <id | нет> (admins): any class of the faction of the player, the limits aside
	NW.AddChatCommand("setclass", {admin = true, run = function(client, rest)
		local who, id = string.match(rest or "", "^(%S+)%s+(%S+)")
		local target = NW.FindPlayer(who)

		if (!target or target:GetCharacterID() == 0) then
			return NW.Notify(client, "/setclass <имя> <id класса | нет>")
		end

		if (id == "нет" or id == "none") then
			CS.Set(target, nil)

			return NW.Notify(client, target:Nick() .. ": без класса")
		end

		local class = CS.data[id or ""]

		if (!class or class.faction != target:GetFaction()) then
			return NW.Notify(client, "Нет такого класса у фракции игрока")
		end

		CS.Set(target, id)
		NW.Notify(client, target:Nick() .. ": класс " .. class.name)
	end})

	return
end

-- ------------------------------------------------------------------ client --
net.Receive("nwClasses", function()
	local length = net.ReadUInt(32)

	CS.data = util.JSONToTable(util.Decompress(net.ReadData(length) or "") or "") or {}

	if (CS.Refresh) then
		CS.Refresh()
	end
end)

local W = NW.widgets
local U = NW.ui
local ACCENT = Color(232, 196, 72)
local MUTED = Color(150, 156, 162)

local function Stat(class, key, default, unit)
	return (class[key] or default) .. (unit or "")
end

-- ------------------------------------------------------------------ the editor --
net.Receive("nwClassEditOpen", function()
	if (IsValid(CS.editor)) then
		CS.editor:Remove()
	end

	local sh = ScrH()
	local w, h = math.Round(math.min(ScrW() * 0.85, sh * 1.5)), math.Round(sh * 0.82)
	local frame, box = W.Window("Классы фракций", w, h)
	local pad = math.Round(sh * 0.02)
	local top = box.top + pad * 0.5
	local fh = math.Round(sh * 0.036)
	local listW = math.Round(w * 0.28)

	CS.editor = frame

	local list = W.Scroll(box)

	list:SetPos(pad, top)
	list:SetSize(listW, h - top - pad * 2 - fh)

	local new = W.Button(box, "+ Новый класс", function()
		CS.Select(nil)
	end, true)

	new:SetPos(pad, h - pad - fh)
	new:SetSize(listW, fh)

	local form = box:Add("EditablePanel")

	form:SetPos(pad * 2 + listW, top)
	form:SetSize(w - listW - pad * 3, h - top - pad)

	local function Fill()
		list:Clear()

		for faction, data in SortedPairsByMemberValue(NW.char.factions, "name") do
			local classes = CS.OfFaction(faction)
			local head = list:Add("DLabel")

			head:Dock(TOP)
			head:DockMargin(0, 6, 0, 2)
			head:SetFont("nwWidgetBold")
			head:SetTextColor(data.color or U.color.text)
			head:SetText(data.name .. "  (" .. #classes .. ")")

			for _, entry in ipairs(classes) do
				local row = list:Add("DButton")

				row:Dock(TOP)
				row:DockMargin(8, 0, 6, 3)
				row:SetTall(fh)
				row:SetText("")
				row.Paint = function(self, rw, rh)
					draw.RoundedBox(4, 0, 0, rw, rh, Color(255, 255, 255, CS.selected == entry.id and 30 or
						(self:IsHovered() and 16 or 6)))
					surface.SetDrawColor(CS.Color(entry.class))
					surface.DrawRect(0, 0, 3, rh)
					draw.SimpleText(entry.class.name, "nwWidget", 10, rh / 2, U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					draw.SimpleText(entry.id, "nwWidgetLabel", rw - 8, rh / 2, MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				end
				row.DoClick = function()
					U.Tick()
					CS.Select(entry.id)
				end
			end
		end
	end

	function CS.Select(id)
		CS.selected = id
		form:Clear()

		local edit = id and table.Copy(CS.data[id]) or {faction = LocalPlayer():GetFaction(), name = "", health = 100,
			walk = 100, run = 200}
		local fw = form:GetWide()
		local y = 0

		local function Field(key, label, x, width, multiline, numeric)
			W.Label(form, label, x, y)

			local entry = W.Entry(form, edit[key] != nil and tostring(edit[key]) or "", nil, multiline)

			entry:SetPos(x, y + sh * 0.021)
			entry:SetSize(width, multiline and fh * 2.6 or fh)
			entry.OnChange = function(self)
				edit[key] = numeric and tonumber(self:GetValue()) or self:GetValue()
			end

			return entry
		end

		local idEntry

		if (id) then
			W.Label(form, "ID: " .. id, 0, y + sh * 0.02)
		else
			idEntry = Field("_id", "ID (латиница, цифры, _)", 0, fw * 0.3)
		end

		W.Label(form, "Фракция", fw * 0.34, y)

		local factions = {}

		for faction, data in pairs(NW.char.factions) do
			factions[#factions + 1] = {faction, data.name}
		end

		local combo = W.Combo(form, factions, edit.faction)

		combo:SetPos(fw * 0.34, y + sh * 0.021)
		combo:SetSize(fw * 0.32, fh)
		combo.OnSelect = function(self)
			edit.faction = self:GetSelectedValue()
		end

		Field("color", "Цвет (r, g, b)", fw * 0.7, fw * 0.3)
		y = y + sh * 0.072
		Field("name", "Название", 0, fw)
		y = y + sh * 0.072
		Field("description", "Описание", 0, fw, true)
		y = y + sh * 0.072 + fh * 1.6

		Field("health", "Здоровье", 0, fw * 0.18, false, true)
		Field("armor", "Броня", fw * 0.2, fw * 0.18, false, true)
		Field("walk", "Шаг", fw * 0.4, fw * 0.18, false, true)
		Field("run", "Бег", fw * 0.6, fw * 0.18, false, true)
		Field("skin", "Скин", fw * 0.8, fw * 0.2, false, true)
		y = y + sh * 0.072

		Field("models", "Модели (по одной в строке; игрок выбирает)", 0, fw, true)
		y = y + sh * 0.072 + fh * 1.6
		Field("items", "Выдаётся один раз (ID через запятую)", 0, fw * 0.66)
		Field("limit", "Мест (0 — без лимита)", fw * 0.7, fw * 0.3, false, true)
		y = y + sh * 0.072

		local adminOnly = W.Check(form, "Только назначает администрация (/setclass)", edit.adminOnly == true)

		adminOnly:SetPos(0, y)
		adminOnly:SetSize(fw * 0.48, fh)

		local default = W.Check(form, "Класс по умолчанию при вступлении во фракцию", edit.default == true)

		default:SetPos(fw * 0.5, y)
		default:SetSize(fw * 0.5, fh)

		local by = form:GetTall() - fh
		local save = W.Button(form, "Сохранить", function()
			local saveID = id or string.lower(string.Trim(idEntry and idEntry:GetValue() or ""))
			local out = table.Copy(edit)

			out._id = nil
			out.adminOnly = adminOnly.value
			out.default = default.value

			net.Start("nwClassSave")
				net.WriteString(saveID)
				net.WriteString(util.TableToJSON(out))
			net.SendToServer()

			timer.Simple(0.6, function()
				if (IsValid(frame)) then
					CS.Select(saveID)
				end
			end)
		end, true)

		save:SetPos(0, by)
		save:SetSize(fw * 0.32, fh)

		if (id) then
			local remove = W.Button(form, "Удалить класс", function()
				net.Start("nwClassDelete")
					net.WriteString(id)
				net.SendToServer()
				CS.Select(nil)
			end)

			remove:SetPos(fw * 0.34, by)
			remove:SetSize(fw * 0.3, fh)
		end
	end

	CS.Refresh = function()
		if (IsValid(frame)) then
			Fill()
		end
	end

	Fill()
	CS.Select(nil)
end)

-- ------------------------------------------------------------------ the choice --
net.Receive("nwClassOpen", function()
	if (IsValid(CS.chooser)) then
		CS.chooser:Remove()
	end

	local me = LocalPlayer()
	local classes = CS.OfFaction(me:GetFaction())
	local sh = ScrH()
	local w, h = math.Round(math.min(ScrW() * 0.8, sh * 1.4)), math.Round(sh * 0.72)
	local frame, box = W.Window("Класс: " .. ((NW.char.factions[me:GetFaction()] or {}).name or "?"), w, h)
	local pad = math.Round(sh * 0.02)
	local scroll = W.Scroll(box)

	CS.chooser = frame
	scroll:SetPos(pad, box.top + pad * 0.5)
	scroll:SetSize(w - pad * 2, h - box.top - pad * 1.5)

	if (#classes == 0) then
		W.Label(scroll, "У вашей фракции нет классов", 0, 0)

		return
	end

	local current = me:GetNW2String("nwClass", "")

	for _, entry in ipairs(classes) do
		local class = entry.class
		local models = CS.Models(class)
		local cardH = math.Round(sh * 0.2)
		local card = scroll:Add("DPanel")
		local color = CS.Color(class)
		local picked = 1

		card:Dock(TOP)
		card:DockMargin(0, 0, 8, 8)
		card:SetTall(cardH)
		card.Paint = function(_, cw, ch)
			draw.RoundedBox(6, 0, 0, cw, ch, Color(255, 255, 255, current == entry.id and 22 or 8))
			surface.SetDrawColor(color)
			surface.DrawRect(0, 0, 4, ch)

			local x = ch * 0.95

			draw.SimpleText(class.name .. (current == entry.id and "  · ваш класс" or ""), "nwWidgetTitle", x, ch * 0.13,
				color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			for line, part in ipairs(NW.inventory.WrapText(class.description or "", "nwWidget", cw - x - cw * 0.26)) do
				if (line <= 3) then
					draw.SimpleText(part, "nwWidget", x, ch * 0.3 + (line - 1) * sh * 0.022, U.color.text)
				end
			end

			draw.SimpleText("Здоровье " .. Stat(class, "health", 100) .. "   ·   броня " .. Stat(class, "armor", 0) ..
				"   ·   шаг " .. Stat(class, "walk", "обычный") .. "   ·   бег " .. Stat(class, "run", "обычный") ..
				((class.limit or 0) > 0 and ("   ·   мест " .. CS.Count(entry.id) .. "/" .. class.limit) or ""), "nwWidgetLabel",
				x, ch * 0.78, MUTED)

			if (class.items) then
				draw.SimpleText("Снаряжение: " .. class.items, "nwWidgetLabel", x, ch * 0.9, MUTED)
			end
		end

		-- the model: turning; several - the arrows under it
		local view = card:Add("DModelPanel")

		view:SetPos(8, 4)
		view:SetSize(cardH * 0.85, cardH - 8)
		view:SetFOV(30)
		view.LayoutEntity = function(self, model)
			model:SetAngles(Angle(0, RealTime() * 25 % 360, 0))
		end

		local function Show()
			view:SetModel(models[picked] or me:GetModel())
			view:SetCamPos(Vector(80, 0, 52))
			view:SetLookAt(Vector(0, 0, 38))

			if (IsValid(view.Entity)) then
				view.Entity:SetSkin(class.skin or 0)
			end
		end

		Show()

		if (#models > 1) then
			local prev = W.Button(card, "<", function()
				picked = (picked - 2) % #models + 1
				Show()
			end)

			prev:SetPos(8, cardH - sh * 0.032)
			prev:SetSize(sh * 0.028, sh * 0.026)

			local nxt = W.Button(card, ">", function()
				picked = picked % #models + 1
				Show()
			end)

			nxt:SetPos(cardH * 0.85 - sh * 0.02, cardH - sh * 0.032)
			nxt:SetSize(sh * 0.028, sh * 0.026)
		end

		local locked = class.adminOnly and !me:IsAdmin()
		local choose = W.Button(card, locked and "Назначает администрация" or (current == entry.id and "Сменить модель" or
			"Выбрать"), function()
			net.Start("nwClassChoose")
				net.WriteString(entry.id)
				net.WriteUInt(picked, 8)
			net.SendToServer()
			frame:Remove()
		end, !locked)

		choose:SetSize(w * 0.2, sh * 0.042)
		choose:SetPos(w - pad * 2 - 8 - w * 0.2 - 10, cardH / 2 - sh * 0.021)
		choose:SetEnabled(!locked)
	end
end)
