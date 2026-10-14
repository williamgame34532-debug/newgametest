-- Model menu (nw_models): pick a character, its skin and bodygroups. The preview plays the
-- model's own idle (the living idles of the build when the model has them). "Применить" stores
-- the choice in nw_model / nw_skin / nw_bodygroups and changes the model right away.

local COLOR = {
	bg = Color(14, 17, 21, 245),
	panel = Color(24, 29, 35, 255),
	line = Color(255, 255, 255, 14),
	accent = Color(70, 170, 220),
	text = Color(220, 228, 235),
	dim = Color(140, 150, 160)
}

surface.CreateFont("nwMenuTitle", {font = "Roboto", size = 22, weight = 600, extended = true})
surface.CreateFont("nwMenuText", {font = "Roboto", size = 16, weight = 500, extended = true})
surface.CreateFont("nwMenuSmall", {font = "Roboto", size = 14, weight = 400, extended = true})

local IDLES = {"nw_ota_live_1", "nw_hla_idle_unarmed_1", "nw_civ_idle", "idle_unarmed", "idle_all_01",
	"idle_subtle", "idle01", "idle"}

local function PreviewSequence(entity)
	for _, name in ipairs(IDLES) do
		local sequence = entity:LookupSequence(name)

		if (sequence and sequence > 0) then
			return sequence
		end
	end

	local sequence = entity:SelectWeightedSequence(ACT_IDLE)

	return (sequence and sequence >= 0) and sequence or 0
end

local function Button(parent, text, callback)
	local button = parent:Add("DButton")

	button:SetText("")
	button.Paint = function(self, w, h)
		local hover = self:IsHovered()

		draw.RoundedBox(4, 0, 0, w, h, hover and COLOR.accent or COLOR.panel)
		draw.SimpleText(text, "nwMenuText", w / 2, h / 2, hover and color_black or COLOR.text, 1, 1)
	end
	button.DoClick = function()
		surface.PlaySound("ui/buttonclick.wav")
		callback()
	end

	return button
end

local frame

local function Open()
	if (IsValid(frame)) then
		frame:Remove()
	end

	local selected = {
		model = GetConVarString("nw_model"),
		skin = GetConVarNumber("nw_skin"),
		groups = GetConVarString("nw_bodygroups")
	}

	frame = vgui.Create("DFrame")
	frame:SetSize(math.min(ScrW() - 80, 1000), math.min(ScrH() - 80, 640))
	frame:Center()
	frame:SetTitle("")
	frame:MakePopup()
	frame:ShowCloseButton(false)
	frame.Paint = function(self, w, h)
		draw.RoundedBox(6, 0, 0, w, h, COLOR.bg)
		draw.SimpleText("Модель персонажа", "nwMenuTitle", 18, 14, COLOR.text)
		surface.SetDrawColor(COLOR.line)
		surface.DrawRect(0, 48, w, 1)
	end
	frame.OnKeyCodePressed = function(self, key)
		if (key == KEY_F1 or key == KEY_ESCAPE) then
			self:Remove()
		end
	end

	local close = Button(frame, "✕", function() frame:Remove() end)
	close:SetSize(36, 30)
	close:SetPos(frame:GetWide() - 46, 10)

	-- right: preview, skin, bodygroups, apply
	local side = frame:Add("DPanel")
	side:Dock(RIGHT)
	side:DockMargin(0, 30, 0, 0)
	side:SetWide(320)
	side.Paint = function(self, w, h)
		draw.RoundedBox(6, 0, 0, w, h, COLOR.panel)
	end

	local preview = side:Add("DModelPanel")
	preview:Dock(TOP)
	preview:SetTall(330)
	preview:SetFOV(32)
	preview:SetCamPos(Vector(95, 0, 50))
	preview:SetLookAt(Vector(0, 0, 38))
	preview.LayoutEntity = function(self, entity)
		entity:SetAngles(Angle(0, 20 + math.sin(CurTime() * 0.4) * 25, 0))
		self:RunAnimation()
	end

	local name = side:Add("DLabel")
	name:Dock(TOP)
	name:DockMargin(12, 6, 12, 2)
	name:SetFont("nwMenuText")
	name:SetTextColor(COLOR.text)
	name:SetTall(22)

	local options = side:Add("DScrollPanel")
	options:Dock(FILL)
	options:DockMargin(10, 4, 10, 4)

	local apply = Button(side, "Применить", function()
		RunConsoleCommand("nw_model", selected.model)
		RunConsoleCommand("nw_skin", tostring(selected.skin))
		RunConsoleCommand("nw_bodygroups", selected.groups)

		timer.Simple(0.1, function()
			RunConsoleCommand("nw_model_apply")
		end)

		frame:Remove()
	end)
	apply:Dock(BOTTOM)
	apply:DockMargin(10, 6, 10, 10)
	apply:SetTall(40)

	local function Groups()
		local entity = preview:GetEntity()
		local out = {}

		if (!IsValid(entity)) then
			return ""
		end

		for index = 0, entity:GetNumBodyGroups() - 1 do
			out[#out + 1] = tostring(entity:GetBodygroup(index))
		end

		return table.concat(out, ",")
	end

	local function Slider(text, max, value, callback)
		local slider = options:Add("DNumSlider")

		slider:Dock(TOP)
		slider:SetTall(28)
		slider:SetText(text)
		slider:SetMin(0)
		slider:SetMax(max)
		slider:SetDecimals(0)
		slider:SetValue(value)
		slider.Label:SetTextColor(COLOR.dim)
		slider.Label:SetFont("nwMenuSmall")
		slider.OnValueChanged = function(_, v)
			callback(math.Round(v))
		end
	end

	local function Show(path, title, bKeepLook)
		local model = NW.models.Resolve(path)

		selected.model = path
		preview:SetModel(model)
		name:SetText(title or string.GetFileFromFilename(path))

		local entity = preview:GetEntity()

		if (!IsValid(entity)) then
			return
		end

		entity:ResetSequence(PreviewSequence(entity))
		entity:SetCycle(math.Rand(0, 1))

		if (bKeepLook) then
			entity:SetSkin(selected.skin)

			local values = string.Explode(",", selected.groups)

			for index = 0, entity:GetNumBodyGroups() - 1 do
				entity:SetBodygroup(index, tonumber(values[index + 1]) or 0)
			end
		else
			selected.skin = 0
			selected.groups = ""
		end

		options:Clear()

		if (entity:SkinCount() > 1) then
			Slider("Скин", entity:SkinCount() - 1, entity:GetSkin(), function(v)
				entity:SetSkin(v)
				selected.skin = v
			end)
		end

		for index = 0, entity:GetNumBodyGroups() - 1 do
			local count = entity:GetBodygroupCount(index)

			if (count > 1) then
				Slider(entity:GetBodygroupName(index), count - 1, entity:GetBodygroup(index), function(v)
					entity:SetBodygroup(index, v)
					selected.groups = Groups()
				end)
			end
		end

		selected.groups = Groups()
	end

	-- left: categories with icons
	local sheet = frame:Add("DPropertySheet")
	sheet:Dock(FILL)
	sheet:DockMargin(0, 30, 10, 0)
	sheet.Paint = function() end

	local function Grid(entries)
		local scroll = vgui.Create("DScrollPanel")
		local grid = scroll:Add("DIconLayout")

		grid:Dock(FILL)
		grid:SetSpaceX(6)
		grid:SetSpaceY(6)

		for _, entry in ipairs(entries) do
			local icon = grid:Add("SpawnIcon")

			icon:SetSize(84, 84)
			icon:SetModel(NW.models.Resolve(entry.path))
			icon:SetTooltip(entry.title)
			icon.DoClick = function()
				surface.PlaySound("ui/buttonclickrelease.wav")
				Show(entry.path, entry.title)
			end
			icon.PaintOver = function(self, w, h)
				if (selected.model == entry.path) then
					surface.SetDrawColor(COLOR.accent)
					surface.DrawOutlinedRect(0, 0, w, h, 2)
				end
			end
		end

		return scroll
	end

	local categories, order = {}, {}

	for _, entry in ipairs(NW.models.list) do
		if (!categories[entry.category]) then
			categories[entry.category] = {}
			order[#order + 1] = entry.category
		end

		table.insert(categories[entry.category], {path = entry[1], title = entry.title})
	end

	for _, category in ipairs(order) do
		sheet:AddSheet(category, Grid(categories[category]))
	end

	local all = {}

	for id, path in SortedPairs(player_manager.AllValidModels()) do
		if (!NW.models.byPath[string.lower(path)]) then
			all[#all + 1] = {path = string.lower(path), title = id}
		end
	end

	sheet:AddSheet("Все модели", Grid(all))

	Show(selected.model, NW.models.byPath[selected.model] and NW.models.byPath[selected.model].title, true)
end

concommand.Add("nw_models", function()
	if (LocalPlayer():IsSuperAdmin()) then
		Open()
	end
end)

-- F1 opens nothing now (it answers requests, sh_keys.lua): the menu is nw_models (superadmins)
