-- /itemedit (admins): the editor of the items (sh_itemedit.lua). Left: every item with its icon,
-- a search and "+ Новый предмет". Right: the item - the id, the type, the name, the description,
-- the model (with a turning preview), the icon (a picker of the icons of the server or a link to a
-- picture) and what its type needs; Сохранить, Выдать себе, Удалить / Сбросить.

local IE = NW.itemEdit
local I = NW.items
local U = NW.ui

local ACCENT = Color(232, 196, 72)
local MUTED = Color(130, 134, 140)

local SLOTS_WEAPON = {{"primary", "Основное"}, {"secondary", "Вторичное"}, {"melee", "Холодное"}}
local SLOTS_CLOTHING = {{"head", "Голова"}, {"face", "Лицо"}, {"torso", "Торс"}, {"hands", "Руки"}, {"legs", "Ноги"},
	{"feet", "Обувь"}}

-- the icons of the server (materials/network2/items)
local function Icons()
	local out = {}

	for _, name in ipairs(file.Find("materials/network2/items/*.png", "GAME") or {}) do
		out[#out + 1] = string.StripExtension(name)
	end

	table.sort(out)

	return out
end

-- an item as an entry of the editor
local function EntryOf(id)
	if (IE.data[id]) then
		return table.Copy(IE.data[id])
	end

	local item = I.Get(id)

	if (!item) then
		return {type = "misc"}
	end

	local kind = "misc"

	if (item.radio) then
		kind = "radio"
	elseif (item.contents) then
		kind = "package"
	elseif (item.bag) then
		kind = "bag"
	elseif (IE.typeByID[item.category or ""]) then
		kind = item.category
	end

	return {type = kind, name = item.name, description = item.description, model = item.model, icon = item.icon,
		iconURL = item.iconURL, hunger = item.hunger, thirst = item.thirst, heal = item.heal, slot = item.slot,
		weapon = item.weapon, wearGroup = item.wear and item.wear.group, wearIndex = item.wear and item.wear.index,
		protect = item.protect, gasmask = item.gasmask, bag = item.bag,
		contents = item.contents and table.concat(item.contents, ", ") or nil, useVerb = item.useVerb,
		useSound = item.useSound, leaves = item.leaves}
end

function IE.Open()
	if (IsValid(IE.frame)) then
		IE.frame:Remove()
	end

	local W = NW.widgets
	local sw, sh = ScrW(), ScrH()
	local w, h = math.Round(math.min(sw * 0.9, sh * 1.7)), math.Round(sh * 0.86)
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(w, h)
	frame:Center()
	frame:MakePopup()
	frame.Paint = function(_, pw, ph)
		U.Blur(0, 0, pw, ph, 3, 255, frame, 10)
		draw.RoundedBox(10, 0, 0, pw, ph, Color(14, 16, 20, 245))
		draw.RoundedBox(2, 0, 0, pw, 3, ACCENT)
		U.DrawIcon("edit", sh * 0.024, sh * 0.022, sh * 0.03, ACCENT)
		draw.SimpleText("Редактор предметов", "nwNpcTitle", sh * 0.064, sh * 0.037, U.color.text, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
		draw.SimpleText("Свои предметы и правки сохраняются на сервере и сразу видны всем", "nwNpcSmall", pw - sh * 0.08,
			sh * 0.037, MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	IE.frame = frame

	local close = W.Button(frame, "✕", function()
		frame:Remove()
	end)

	close:SetSize(sh * 0.04, sh * 0.04)
	close:SetPos(w - sh * 0.06, sh * 0.017)

	local pad = math.Round(sh * 0.022)
	local top = math.Round(sh * 0.075)
	local listW = math.Round(w * 0.27)
	local fh = math.Round(sh * 0.036)

	-- ------------------------------------------------------------ the list --
	local search = W.Entry(frame, "")

	search:SetPos(pad, top)
	search:SetSize(listW, fh)
	search.placeholder = "Поиск: название или ID"

	local list = W.Scroll(frame)

	list:SetPos(pad, top + fh + 8)
	list:SetSize(listW, h - top - fh * 2 - pad - 16)

	local new = W.Button(frame, "+ Новый предмет", function()
		IE.Select(nil)
	end, true)

	new:SetPos(pad, h - pad - fh)
	new:SetSize(listW, fh)

	local form = frame:Add("EditablePanel")

	form:SetPos(pad * 2 + listW, top)
	form:SetSize(w - listW - pad * 3, h - top - pad)

	local function Fill()
		list:Clear()

		local query = string.lower(search:GetValue() or "")
		local ids = table.GetKeys(I.list)

		table.sort(ids, function(a, b)
			return (I.list[a].name or a) < (I.list[b].name or b)
		end)

		for _, id in ipairs(ids) do
			local item = I.list[id]

			if (query == "" or string.find(string.lower(item.name or ""), query, 1, true) or string.find(id, query, 1, true)) then
				local row = list:Add("DButton")

				row:Dock(TOP)
				row:DockMargin(0, 0, 6, 4)
				row:SetTall(sh * 0.046)
				row:SetText("")
				row.Paint = function(self, rw, rh)
					local active = IE.selected == id

					draw.RoundedBox(6, 0, 0, rw, rh, Color(255, 255, 255, active and 34 or (self:IsHovered() and 18 or 7)))
					surface.SetMaterial(I.IconMaterial(item))
					surface.SetDrawColor(255, 255, 255, 235)
					surface.DrawTexturedRect(rh * 0.15, rh * 0.15, rh * 0.7, rh * 0.7)
					draw.SimpleText(item.name or id, "nwNpcAnswer", rh, rh * 0.36, U.color.text, TEXT_ALIGN_LEFT,
						TEXT_ALIGN_CENTER)
					draw.SimpleText(id .. (item.custom and "  · свой" or (IE.data[id] and "  · изменён" or "")), "nwNpcSmall",
						rh, rh * 0.72, item.custom and ACCENT or MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end
				row.DoClick = function()
					U.Tick()
					IE.Select(id)
				end
			end
		end
	end

	search.OnChange = Fill
	IE.Fill = Fill

	-- ------------------------------------------------------------ the form --
	-- keep: the values being edited (a new type rebuilds the form with them)
	function IE.Select(id, keep)
		IE.selected = id
		form:Clear()

		local edit = keep or (id and EntryOf(id)) or {type = "misc", name = "",
			model = "models/props_junk/cardboard_box004a.mdl", icon = "bag"}
		local fw = form:GetWide()
		local col = math.Round(fw * 0.62)
		local y = 0

		local function Label(text, x, ly)
			W.Label(form, text, x, ly)
		end

		local function Text(key, label, x, ly, width)
			Label(label, x, ly)

			local entry = W.Entry(form, tostring(edit[key] or ""))

			entry:SetPos(x, ly + sh * 0.021)
			entry:SetSize(width, fh)
			entry.OnChange = function(self)
				edit[key] = self:GetValue()
			end

			return entry
		end

		local function Num(key, label, x, ly, width, min, max)
			Label(label, x, ly)

			local entry = W.Entry(form, edit[key] and tostring(edit[key]) or "")

			entry:SetPos(x, ly + sh * 0.021)
			entry:SetSize(width, fh)
			entry.OnChange = function(self)
				local value = tonumber(self:GetValue())

				edit[key] = value and math.Clamp(value, min, max) or nil
			end

			return entry
		end

		local function Choice(key, label, x, ly, width, choices, onSelect)
			Label(label, x, ly)

			local combo = W.Combo(form, choices, edit[key])

			combo:SetPos(x, ly + sh * 0.021)
			combo:SetSize(width, fh)
			combo.OnSelect = function(self)
				edit[key] = self:GetSelectedValue()

				if (onSelect) then
					onSelect()
				end
			end

			return combo
		end

		-- the id: only for a new one
		local idEntry

		if (id) then
			Label("ID: " .. id .. (I.list[id] and I.list[id].custom and "  (свой предмет)" or "  (предмет фреймворка)"), 0, y)
		else
			idEntry = Text("_id", "ID (латиница, цифры, _)", 0, y, col * 0.45)
		end

		local types = {}

		for _, entry in ipairs(IE.types) do
			types[#types + 1] = {entry.id, entry.name}
		end

		Choice("type", "Тип", col * 0.5, y, col * 0.5, types, function()
			-- the new type, the values kept
			timer.Simple(0, function()
				if (IsValid(form)) then
					IE.Select(id, edit)
				end
			end)
		end)
		y = y + sh * 0.07

		Text("name", "Название", 0, y, col)
		y = y + sh * 0.07
		Text("description", "Описание", 0, y, col)
		y = y + sh * 0.07
		Text("model", "Модель (.mdl)", 0, y, col)
		y = y + sh * 0.07
		Text("useVerb", "Действие в меню (ПКМ)", 0, y, col * 0.48)
		Text("useSound", "Звук использования", col * 0.52, y, col * 0.48)
		y = y + sh * 0.07

		-- what the type needs
		local kind = edit.type or "misc"

		if (kind == "food") then
			Num("hunger", "Сытость +", 0, y, col * 0.3, 0, 100)
			Text("leaves", "Остаётся после (ID)", col * 0.34, y, col * 0.3)
		elseif (kind == "drink") then
			Num("thirst", "Жажда +", 0, y, col * 0.3, 0, 100)
			Text("leaves", "Остаётся после (ID)", col * 0.34, y, col * 0.3)
		elseif (kind == "medical") then
			Num("heal", "Здоровье +", 0, y, col * 0.3, 0, 100)
			Text("leaves", "Остаётся после (ID)", col * 0.34, y, col * 0.3)
		elseif (kind == "weapon") then
			Choice("slot", "Слот", 0, y, col * 0.3, SLOTS_WEAPON)
			Text("weapon", "Класс оружия (SWEP)", col * 0.34, y, col * 0.66)
		elseif (kind == "clothing") then
			Choice("slot", "Слот", 0, y, col * 0.24, SLOTS_CLOTHING)
			Text("wearGroup", "Бодигруппа", col * 0.27, y, col * 0.24)
			Num("wearIndex", "Вариант", col * 0.54, y, col * 0.14, 0, 64)
			Num("protect", "Защита 0..0.9", col * 0.71, y, col * 0.14, 0, 0.9)
			Choice("gasmask", "Противогаз", col * 0.88, y, col * 0.12, {{true, "да"}, {false, "нет"}})
		elseif (kind == "bag") then
			Num("bag", "Ячеек +", 0, y, col * 0.3, 1, 24)
		elseif (kind == "package") then
			Text("contents", "Внутри: ID через запятую", 0, y, col)
		elseif (kind == "radio") then
			Label("Рация: ПКМ → каналы, говорить — клавиша рации (H)", 0, y + sh * 0.02)
		else
			Label("Обычный предмет: без особых действий", 0, y + sh * 0.02)
		end

		y = y + sh * 0.08

		-- the icon
		Label("Иконка: выберите или дайте ссылку на картинку (png / jpg)", 0, y)
		y = y + sh * 0.024

		local url = W.Entry(form, edit.iconURL or "")

		url:SetPos(0, y)
		url:SetSize(col, fh)
		url.placeholder = "https://... (пусто — иконка из списка)"
		url.OnChange = function(self)
			edit.iconURL = self:GetValue()
		end
		y = y + fh + 8

		local picker = W.Scroll(form)
		local cell = math.Round(sh * 0.05)
		local perRow = math.floor(col / (cell + 4))

		picker:SetPos(0, y)
		picker:SetSize(col, form:GetTall() - y - fh - 16)

		local grid = picker:Add("EditablePanel")
		local icons = Icons()

		grid:SetSize(col - 10, math.ceil(#icons / perRow) * (cell + 4))

		for index, name in ipairs(icons) do
			local button = grid:Add("DButton")

			button:SetPos(((index - 1) % perRow) * (cell + 4), math.floor((index - 1) / perRow) * (cell + 4))
			button:SetSize(cell, cell)
			button:SetText("")
			button:SetTooltip(name)
			button.Paint = function(self, bw, bh)
				local chosen = edit.icon == name

				draw.RoundedBox(6, 0, 0, bw, bh, chosen and ColorAlpha(ACCENT, 70) or Color(255, 255, 255,
					self:IsHovered() and 22 or 8))
				surface.SetMaterial(U.Material("network2/items/" .. name .. ".png"))
				surface.SetDrawColor(255, 255, 255, 235)
				surface.DrawTexturedRect(bw * 0.16, bh * 0.16, bw * 0.68, bh * 0.68)
			end
			button.DoClick = function()
				U.Tick()
				edit.icon = name
			end
		end

		-- the preview: the model turning, the icon as it is
		local px = col + pad
		local pw = fw - px
		local preview = form:Add("DModelPanel")

		preview:SetPos(px, 0)
		preview:SetSize(pw, pw)
		preview:SetModel(edit.model or "models/props_junk/cardboard_box004a.mdl")
		preview:SetFOV(40)
		preview.lastModel = edit.model
		preview.LayoutEntity = function(self, ent)
			if (self.lastModel != edit.model and util.IsValidModel(edit.model or "")) then
				self.lastModel = edit.model
				self:SetModel(edit.model)
			end

			if (IsValid(self.Entity)) then
				local mins, maxs = self.Entity:GetRenderBounds()
				local size = math.max(maxs:Distance(mins), 4)

				self:SetCamPos(Vector(size * 1.2, size * 0.6, size * 0.6))
				self:SetLookAt((mins + maxs) / 2)
				self.Entity:SetAngles(Angle(0, RealTime() * 30 % 360, 0))
			end
		end
		preview.PaintOver = function(_, ppw, pph)
			local is = pph * 0.22
			local fake = {icon = edit.icon, iconURL = (edit.iconURL or "") != "" and edit.iconURL or nil}

			draw.RoundedBox(8, ppw - is - 12, pph - is - 12, is + 8, is + 8, Color(0, 0, 0, 160))
			surface.SetMaterial(I.IconMaterial(fake))
			surface.SetDrawColor(255, 255, 255, 240)
			surface.DrawTexturedRect(ppw - is - 8, pph - is - 8, is, is)
		end

		-- the buttons
		local by = form:GetTall() - fh
		local bw = math.Round(pw / 2 - 4)

		local save = W.Button(form, "Сохранить", function()
			local saveID = id or string.lower(string.Trim(idEntry and idEntry:GetValue() or ""))
			local out = table.Copy(edit)

			out._id = nil

			net.Start("nwItemEditSave")
				net.WriteString(saveID)
				net.WriteString(util.TableToJSON(out))
			net.SendToServer()

			timer.Simple(0.6, function()
				if (IsValid(frame)) then
					Fill()
					IE.Select(saveID)
				end
			end)
		end, true)

		save:SetPos(px, by)
		save:SetSize(bw, fh)

		if (id) then
			local give = W.Button(form, "Выдать себе", function()
				net.Start("nwItemEditGive")
					net.WriteString(id)
				net.SendToServer()
			end)

			give:SetPos(px + bw + 8, by)
			give:SetSize(bw, fh)

			if (IE.data[id]) then
				local remove = W.Button(form, I.list[id] and I.list[id].custom and "Удалить предмет" or
					"Сбросить к исходному", function()
					net.Start("nwItemEditDelete")
						net.WriteString(id)
					net.SendToServer()

					timer.Simple(0.6, function()
						if (IsValid(frame)) then
							Fill()
							IE.Select(I.list[id] and id or nil)
						end
					end)
				end)

				remove:SetPos(px, by - fh - 8)
				remove:SetSize(pw, fh)
			end
		end

		IE.edit = edit
	end

	Fill()
	IE.Select(nil)
end

net.Receive("nwItemEditOpen", IE.Open)

hook.Add("NWItemsChanged", "nwItemEdit", function()
	if (IsValid(IE.frame) and IE.Fill) then
		IE.Fill()
	end
end)
