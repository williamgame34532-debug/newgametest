-- The window of a crafting table (sh_craft.lua): over the wall of a workshop
-- (materials/network2/craft/bg_workshop.png, branding/make_craft_assets.py).
--   left     the recipes of this station by category: the icon, the name, can it be made now
--   right    the chosen one: the icon big, the description, the materials (have / need), the time,
--            the skill needed; Создать
--   admins   Редактор: the same list, the recipe as a form - the result, the count, the time, the
--            station, the category, the skill and its level, the experience, the materials (add,
--            remove); Новый, Сохранить, Удалить

local CR = NW.craft
local I = NW.items
local U = NW.ui

local BG = Material("network2/craft/bg_workshop.png", "smooth")
local WARM = Color(236, 196, 120)
local GOOD = Color(150, 214, 138)
local BAD = Color(226, 104, 92)
local MUTED = Color(150, 146, 140)
local PANEL = Color(18, 16, 14, 225)

local function Fonts()
	local h = ScrH()
	local function F(name, font, size, weight)
		surface.CreateFont(name, {font = font, size = math.max(11, math.Round(h * size)), weight = weight,
			extended = true, antialias = true})
	end

	F("nwCraftTitle", "Montserrat SemiBold", 0.034, 600)
	F("nwCraftName", "Montserrat SemiBold", 0.02, 600)
	F("nwCraftBig", "Montserrat SemiBold", 0.028, 600)
	F("nwCraftText", "Exo 2", 0.017, 500)
	F("nwCraftSmall", "Montserrat Medium", 0.0135, 500)
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwCraftFonts", Fonts)

local function Grid()
	return NW.inventory.data and NW.inventory.data.grid or {}
end

local function Level(recipe)
	return recipe.skill != "" and NW.skills.Level(LocalPlayer(), recipe.skill) or 0
end

local function SkillName(id)
	for _, skill in ipairs(NW.char.skills) do
		if (skill.id == id) then
			return skill.name
		end
	end

	return id
end

-- the recipes of a station, sorted by category and name
local function Recipes(station)
	local out = {}

	for id, recipe in pairs(CR.recipes) do
		if (recipe.station == station and I.Get(recipe.result)) then
			out[#out + 1] = {id = id, recipe = recipe}
		end
	end

	table.sort(out, function(a, b)
		if (a.recipe.category != b.recipe.category) then
			return a.recipe.category < b.recipe.category
		end

		return I.Get(a.recipe.result).name < I.Get(b.recipe.result).name
	end)

	return out
end

function CR.OpenWindow(bench)
	if (IsValid(CR.frame)) then
		CR.frame:Remove()
	end

	local W = NW.widgets
	local sw, sh = ScrW(), ScrH()
	local station = CR.stationByID[bench:GetStation()] or CR.stations[1]
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(sw, sh)
	frame:MakePopup()
	frame.born = RealTime()
	frame.bench = bench
	frame.editing = false
	CR.frame = frame

	local pad = math.Round(sh * 0.04)
	local listW = math.Round(sw * 0.3)
	local top = math.Round(sh * 0.13)

	frame.Paint = function(self, w, h)
		local a = math.Clamp((RealTime() - self.born) / 0.3, 0, 1)

		surface.SetDrawColor(0, 0, 0, 255 * a)
		surface.DrawRect(0, 0, w, h)
		surface.SetMaterial(BG)
		surface.SetDrawColor(255, 255, 255, 255 * a)

		-- cover the screen keeping the proportions
		local scale = math.max(w / 1600, h / 900)
		local bw, bh = 1600 * scale, 900 * scale

		surface.DrawTexturedRect((w - bw) / 2, (h - bh) / 2, bw, bh)

		U.DrawIcon(station.icon, pad, pad, sh * 0.044, ColorAlpha(WARM, 255 * a))
		draw.SimpleText(station.name, "nwCraftTitle", pad + sh * 0.058, pad + sh * 0.022, ColorAlpha(U.color.text, 255 * a),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(self.editing and "Редактор рецептов" or "Что можно сделать здесь", "nwCraftText",
			pad + sh * 0.058, pad + sh * 0.056, ColorAlpha(MUTED, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local close = W.Button(frame, "✕", function()
		frame:Remove()
	end)

	close:SetSize(sh * 0.046, sh * 0.046)
	close:SetPos(sw - pad - sh * 0.046, pad)

	if (LocalPlayer():IsAdmin()) then
		local editor = W.Button(frame, "Редактор", function()
			frame.editing = !frame.editing
			CR.Rebuild()
		end, false, "edit")

		editor:SetSize(sh * 0.16, sh * 0.046)
		editor:SetPos(sw - pad - sh * 0.056 - sh * 0.16, pad)
	end

	local list = W.Scroll(frame)

	list:SetPos(pad, top)
	list:SetSize(listW, sh - top - pad)

	local detail = frame:Add("EditablePanel")

	detail:SetPos(pad * 2 + listW, top)
	detail:SetSize(sw - listW - pad * 3, sh - top - pad)

	local selected

	local function ShowDetail()
		detail:Clear()

		local entry = selected and CR.recipes[selected]

		if (frame.editing) then
			return CR.BuildEditor(detail, selected, bench:GetStation())
		end

		if (!entry or !I.Get(entry.result)) then
			return
		end

		local item = I.Get(entry.result)
		local dw, dh = detail:GetSize()
		local panel = detail:Add("DPanel")

		panel:SetSize(math.min(dw, sh * 0.9), dh)
		panel.Paint = function(_, pw, ph)
			draw.RoundedBox(10, 0, 0, pw, ph, PANEL)

			local is = sh * 0.12
			local p = sh * 0.03

			draw.RoundedBox(10, p, p, is, is, Color(255, 255, 255, 10))
			surface.SetMaterial(I.IconMaterial(item))
			surface.SetDrawColor(255, 255, 255, 240)
			surface.DrawTexturedRect(p + is * 0.14, p + is * 0.14, is * 0.72, is * 0.72)

			draw.SimpleText(item.name .. (entry.count > 1 and ("  ×" .. entry.count) or ""), "nwCraftBig", p * 2 + is, p + is * 0.25,
				U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(entry.category, "nwCraftSmall", p * 2 + is, p + is * 0.5, WARM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local lines = NW.inventory.WrapText(item.description or "", "nwCraftText", pw - p * 3 - is)

			for index, line in ipairs(lines) do
				if (index > 3) then
					break
				end

				draw.SimpleText(line, "nwCraftText", p * 2 + is, p + is * 0.72 + (index - 1) * sh * 0.022, Color(200, 196, 190),
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			-- the materials
			local y = p * 2 + is + sh * 0.02

			draw.SimpleText("МАТЕРИАЛЫ", "nwCraftSmall", p, y, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			y = y + sh * 0.03

			for _, need in ipairs(entry.ingredients) do
				local part = I.Get(need.item)
				local have = CR.Count(Grid(), need.item)
				local ok = have >= need.count
				local ms = sh * 0.044

				draw.RoundedBox(6, p, y, pw - p * 2, ms + 8, Color(255, 255, 255, 6))
				surface.SetMaterial(I.IconMaterial(part))
				surface.SetDrawColor(255, 255, 255, 230)
				surface.DrawTexturedRect(p + 6, y + 4, ms, ms)
				draw.SimpleText(part and part.name or need.item, "nwCraftName", p + ms + 18, y + (ms + 8) / 2, U.color.text,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(have .. " / " .. need.count, "nwCraftName", pw - p - 12, y + (ms + 8) / 2, ok and GOOD or BAD,
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				y = y + ms + 14
			end

			-- the time and the skill
			y = y + sh * 0.01

			local seconds = entry.time * NW.skills.Factor(LocalPlayer(), entry.skill != "" and entry.skill or "engineering", -0.04)

			draw.SimpleText(string.format("Время: %.1f с", seconds), "nwCraftText", p, y, Color(200, 196, 190), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			if (entry.skill != "") then
				local enough = Level(entry) >= entry.level

				draw.SimpleText("Навык: " .. SkillName(entry.skill) .. " " .. entry.level .. "  (у вас " .. Level(entry) .. ")",
					"nwCraftText", p, y + sh * 0.028, enough and GOOD or BAD, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end

		local make = W.Button(panel, "Создать", function()
			net.Start("nwCraftMake")
				net.WriteEntity(bench)
				net.WriteString(selected)
			net.SendToServer()
			surface.PlaySound("network2/ui/char/hls_ui_affirm.wav")
		end, true)

		make:SetSize(sh * 0.26, sh * 0.05)
		make:SetPos(panel:GetWide() - sh * 0.29, dh - sh * 0.08)
		make.Think = function(self)
			self:SetEnabled((CR.Can(entry, Grid(), Level(entry))))
		end
	end

	function CR.Rebuild()
		list:Clear()

		local recipes = Recipes(bench:GetStation())
		local category

		if (frame.editing and !selected and recipes[1]) then
			selected = nil
		elseif (!selected and recipes[1]) then
			selected = recipes[1].id
		end

		for _, entry in ipairs(recipes) do
			local recipe = entry.recipe
			local item = I.Get(recipe.result)

			if (recipe.category != category) then
				category = recipe.category

				local head = list:Add("DPanel")

				head:Dock(TOP)
				head:DockMargin(0, 6, 8, 4)
				head:SetTall(sh * 0.03)
				head.Paint = function(_, hw, hh)
					draw.SimpleText(string.upper(category), "nwCraftSmall", 4, hh / 2, WARM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end
			end

			local row = list:Add("DButton")

			row:Dock(TOP)
			row:DockMargin(0, 0, 8, 6)
			row:SetTall(sh * 0.064)
			row:SetText("")
			row.Paint = function(self, rw, rh)
				local active = selected == entry.id
				local ok = CR.Can(recipe, Grid(), Level(recipe))

				draw.RoundedBox(8, 0, 0, rw, rh, active and Color(60, 50, 38, 235) or Color(18, 16, 14, self:IsHovered() and
					230 or 205))

				if (active) then
					draw.RoundedBox(2, 0, rh * 0.2, 3, rh * 0.6, WARM)
				end

				surface.SetMaterial(I.IconMaterial(item))
				surface.SetDrawColor(255, 255, 255, ok and 240 or 120)
				surface.DrawTexturedRect(rh * 0.16, rh * 0.16, rh * 0.68, rh * 0.68)
				draw.SimpleText(item.name .. (recipe.count > 1 and ("  ×" .. recipe.count) or ""), "nwCraftName", rh * 1.05,
					rh * 0.36, ok and U.color.text or Color(170, 166, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				local parts = {}

				for _, need in ipairs(recipe.ingredients) do
					local part = I.Get(need.item)

					parts[#parts + 1] = (part and part.name or need.item) .. " ×" .. need.count
				end

				draw.SimpleText(table.concat(parts, ", "), "nwCraftSmall", rh * 1.05, rh * 0.7, ok and GOOD or MUTED,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			row.DoClick = function()
				U.Tick()
				selected = entry.id
				ShowDetail()
			end
		end

		if (frame.editing) then
			local new = W.Button(list, "+ Новый рецепт", function()
				selected = nil
				ShowDetail()
			end, true)

			new:Dock(TOP)
			new:DockMargin(0, 10, 8, 0)
			new:SetTall(sh * 0.046)
		end

		ShowDetail()
	end

	CR.Rebuild()

	frame.Think = function(self)
		if (!IsValid(bench) or LocalPlayer():GetPos():DistToSqr(bench:GetPos()) > 200 * 200 or !LocalPlayer():Alive()) then
			self:Remove()
		end
	end
end

-- ------------------------------------------------------------------ editor --
function CR.BuildEditor(parent, id, station)
	local W = NW.widgets
	local sh = ScrH()
	local recipe = table.Copy(id and CR.recipes[id] or {result = "", count = 1, ingredients = {}, time = 5,
		station = station, category = "Разное", skill = "", level = 0, xp = 3})
	local pw = math.min(parent:GetWide(), sh * 0.95)
	local panel = parent:Add("DPanel")

	panel:SetSize(pw, parent:GetTall())
	panel.Paint = function(_, w, h)
		draw.RoundedBox(10, 0, 0, w, h, PANEL)
	end

	local p = math.Round(sh * 0.025)
	local fh = math.Round(sh * 0.036)
	local inner = pw - p * 2
	local y = p

	local items = {}

	for itemID, item in SortedPairsByMemberValue(I.list, "name") do
		items[#items + 1] = {itemID, item.name .. "  (" .. itemID .. ")"}
	end

	local stations = {}

	for _, entry in ipairs(CR.stations) do
		stations[#stations + 1] = {entry.id, entry.name}
	end

	local skills = {{"", "Без навыка"}}

	for _, skill in ipairs(NW.char.skills) do
		skills[#skills + 1] = {skill.id, skill.name}
	end

	W.Label(panel, "ID рецепта", p, y)

	local idEntry = W.Entry(panel, id or "")

	idEntry:SetPos(p, y + sh * 0.021)
	idEntry:SetSize(inner * 0.3, fh)
	idEntry:SetEnabled(id == nil)

	W.Label(panel, "Результат", p + inner * 0.33, y)

	local result = W.Combo(panel, items, recipe.result)

	result:SetPos(p + inner * 0.33, y + sh * 0.021)
	result:SetSize(inner * 0.5, fh)
	result.OnSelect = function(self)
		recipe.result = self:GetSelectedValue()
	end

	W.Label(panel, "Кол-во", p + inner * 0.86, y)

	local count = W.Number(panel, recipe.count, 1, 20)

	count:SetPos(p + inner * 0.86, y + sh * 0.021)
	count:SetSize(inner * 0.14, fh)
	y = y + sh * 0.07

	W.Label(panel, "Станция", p, y)

	local stationCombo = W.Combo(panel, stations, recipe.station)

	stationCombo:SetPos(p, y + sh * 0.021)
	stationCombo:SetSize(inner * 0.3, fh)
	stationCombo.OnSelect = function(self)
		recipe.station = self:GetSelectedValue()
	end

	W.Label(panel, "Категория", p + inner * 0.33, y)

	local category = W.Entry(panel, recipe.category)

	category:SetPos(p + inner * 0.33, y + sh * 0.021)
	category:SetSize(inner * 0.35, fh)

	W.Label(panel, "Время, с", p + inner * 0.71, y)

	local time = W.Number(panel, recipe.time, 1, 120)

	time:SetPos(p + inner * 0.71, y + sh * 0.021)
	time:SetSize(inner * 0.29, fh)
	y = y + sh * 0.07

	W.Label(panel, "Навык", p, y)

	local skill = W.Combo(panel, skills, recipe.skill)

	skill:SetPos(p, y + sh * 0.021)
	skill:SetSize(inner * 0.3, fh)
	skill.OnSelect = function(self)
		recipe.skill = self:GetSelectedValue()
	end

	W.Label(panel, "Уровень навыка", p + inner * 0.33, y)

	local level = W.Number(panel, recipe.level, 0, 10)

	level:SetPos(p + inner * 0.33, y + sh * 0.021)
	level:SetSize(inner * 0.2, fh)

	W.Label(panel, "Опыт за создание", p + inner * 0.56, y)

	local xp = W.Number(panel, recipe.xp, 0, 100)

	xp:SetPos(p + inner * 0.56, y + sh * 0.021)
	xp:SetSize(inner * 0.2, fh)
	y = y + sh * 0.08

	W.Label(panel, "Материалы", p, y)
	y = y + sh * 0.024

	local rows = panel:Add("EditablePanel")

	rows:SetPos(p, y)
	rows:SetSize(inner, sh * 0.34)

	local function Rows()
		rows:Clear()

		for index, need in ipairs(recipe.ingredients) do
			local ry = (index - 1) * (fh + 6)
			local combo = W.Combo(rows, items, need.item)

			combo:SetPos(0, ry)
			combo:SetSize(inner * 0.6, fh)
			combo.OnSelect = function(self)
				need.item = self:GetSelectedValue()
			end

			local number = W.Number(rows, need.count, 1, 20)

			number:SetPos(inner * 0.62, ry)
			number:SetSize(inner * 0.16, fh)
			number.OnChange = function(self)
				need.count = self:GetNumber()
			end

			local remove = W.Button(rows, "Убрать", function()
				table.remove(recipe.ingredients, index)
				Rows()
			end)

			remove:SetPos(inner * 0.8, ry)
			remove:SetSize(inner * 0.2, fh)
		end

		if (#recipe.ingredients < 8) then
			local add = W.Button(rows, "+ Материал", function()
				recipe.ingredients[#recipe.ingredients + 1] = {item = items[1] and items[1][1] or "", count = 1}
				Rows()
			end)

			add:SetPos(0, #recipe.ingredients * (fh + 6))
			add:SetSize(inner * 0.3, fh)
		end
	end

	Rows()

	local by = panel:GetTall() - p - fh

	local save = W.Button(panel, "Сохранить рецепт", function()
		recipe.count = count:GetNumber()
		recipe.category = category:GetValue()
		recipe.time = time:GetNumber()
		recipe.level = level:GetNumber()
		recipe.xp = xp:GetNumber()

		net.Start("nwCraftSave")
			net.WriteString(id or idEntry:GetValue())
			net.WriteString(util.TableToJSON(recipe))
		net.SendToServer()
	end, true)

	save:SetPos(pw - p - inner * 0.3, by)
	save:SetSize(inner * 0.3, fh)

	if (id) then
		local remove = W.Button(panel, "Удалить рецепт", function()
			net.Start("nwCraftDelete")
				net.WriteString(id)
			net.SendToServer()
		end)

		remove:SetPos(p, by)
		remove:SetSize(inner * 0.3, fh)
	end
end

net.Receive("nwCraftOpen", function()
	local bench = net.ReadEntity()

	if (IsValid(bench)) then
		CR.OpenWindow(bench)
	end
end)

hook.Add("NWRecipesChanged", "nwCraft", function()
	if (IsValid(CR.frame) and CR.Rebuild) then
		CR.Rebuild()
	end
end)

hook.Add("NWEscape", "nwCraft", function()
	if (IsValid(CR.frame)) then
		CR.frame:Remove()

		return true
	end
end)
