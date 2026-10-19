-- The settings of the entities of the server in the C menu: hold C, the right click on the entity →
-- «Настройки» (admins). A window with the fields of that kind of entity; «Сохранить» - the entity
-- takes them and they stay with the map (sv_persist.lua).
--   NW.entSettings.Register(class, {title = "...", fields = {{id, name, type, ...}},
--                           Get = function(entity) return values end,      (server)
--                           Set = function(entity, values) end})           (server)
--   field types: text, number (min, max), bool, choice (options = {{value, label}} or a function
--   giving them), item (any item
--   or none), model (a path; the preview, empty - the default model)
-- Registered here: the stations of the factory (the model), the breakdown points (the kind, the name,
-- the model, the tool and whether it is used up, the time, the pay, who may repair).

NW.entSettings = NW.entSettings or {}

local ES = NW.entSettings

ES.list = ES.list or {}

function ES.Register(class, data)
	ES.list[class] = data
end

-- the model only (entity.nwModel, kept by the persist handlers of the class): the default when empty
function ES.ModelOnly(class, title, default)
	ES.Register(class, {
		title = title,
		fields = {{id = "model", name = "Модель (пусто — по умолчанию)", type = "model", default = default}},
		Get = function(entity)
			return {model = entity.nwModel or ""}
		end,
		Set = function(entity, values)
			local model = string.Trim(values.model or "")

			if (model != "" and !util.IsValidModel(model)) then
				return false, "Нет такой модели: " .. model
			end

			entity.nwModel = model != "" and model or nil
			entity:SetModel(entity.nwModel or default)
			entity:PhysicsInit(SOLID_VPHYSICS)

			local physics = entity:GetPhysicsObject()

			if (IsValid(physics)) then
				physics:EnableMotion(false)
			end
		end
	})
end

ES.ModelOnly("nw_factory_terminal", "Терминал завода", "models/props_combine/combine_interface001.mdl")
ES.ModelOnly("nw_fabricator", "Фабрикатор Альянса", "models/hla_prop/fabricator.mdl")

-- ------------------------------------------------------------- the factory --
local function Physics(entity)
	entity:PhysicsInit(SOLID_VPHYSICS)

	local physics = entity:GetPhysicsObject()

	if (IsValid(physics)) then
		physics:EnableMotion(false)
	end
end

for _, id in ipairs(NW.cwu.order) do
	local station = NW.cwu.stations[id]

	ES.Register("nw_factory_" .. id, {
		title = "Станция: " .. station.name,
		fields = {
			{id = "model", name = "Модель (пусто — по умолчанию)", type = "model", default = station.model}
		},
		Get = function(entity)
			return {model = entity.nwModel or ""}
		end,
		Set = function(entity, values)
			local model = string.Trim(values.model or "")

			if (model != "" and !util.IsValidModel(model)) then
				return false, "Нет такой модели: " .. model
			end

			entity.nwModel = model != "" and model or nil
			entity:SetModel(entity.nwModel or station.model)
			Physics(entity)
		end
	})
end

-- the kinds of the point (the entities load after the gamemode: asked when the window opens)
local function Kinds()
	local stored = scripted_ents.GetStored("nw_breakdown")
	local out = {}

	for index, kind in ipairs(stored and stored.t.Kinds or {}) do
		out[#out + 1] = {index, kind.name}
	end

	return out
end

ES.Register("nw_breakdown", {
	title = "Точка поломки",
	fields = {
		{id = "kind", name = "Тип поломки", type = "choice", options = Kinds},
		{id = "name", name = "Название (пусто — по типу)", type = "text"},
		{id = "model", name = "Модель (пусто — по типу)", type = "model"},
		{id = "tool", name = "Чем чинить", type = "item"},
		{id = "consume", name = "Инструмент расходуется", type = "bool"},
		{id = "time", name = "Время ремонта, с (до навыка)", type = "number", min = 1, max = 120},
		{id = "reward", name = "Оплата, ток. (0 — по классу ГСР)", type = "number", min = 0, max = 500},
		{id = "cwuOnly", name = "Чинят только рабочие ГСР", type = "bool"}
	},
	Get = function(entity)
		local conf = entity:Conf()

		return {kind = entity:GetKind(), name = conf.name, model = entity.nwModel or "", tool = conf.tool,
			consume = conf.consume, time = conf.time, reward = conf.reward, cwuOnly = conf.cwuOnly}
	end,
	Set = function(entity, values)
		local model = string.Trim(values.model or "")

		if (model != "" and !util.IsValidModel(model)) then
			return false, "Нет такой модели: " .. model
		end

		local tool = tostring(values.tool or "")

		if (tool != "" and !NW.items.Get(tool)) then
			return false, "Нет такого предмета: " .. tool
		end

		entity:SetKind(math.Clamp(math.floor(tonumber(values.kind) or 1), 1, #entity.Kinds))
		entity:SetConf({name = tostring(values.name or ""), tool = tool,
			consume = values.consume == true, time = tonumber(values.time) or 10, reward = tonumber(values.reward) or 0,
			cwuOnly = values.cwuOnly != false})
		entity.nwModel = model != "" and model or nil
		entity:ApplyModel()
	end
})

-- ------------------------------------------------------------------ server --
if (SERVER) then
	util.AddNetworkString("nwEntSettingsGet")
	util.AddNetworkString("nwEntSettings")
	util.AddNetworkString("nwEntSettingsSet")

	local function Allowed(client, entity)
		return IsValid(entity) and ES.list[entity:GetClass()] and client:IsAdmin() and
			client:GetPos():DistToSqr(entity:GetPos()) < 2000 * 2000
	end

	net.Receive("nwEntSettingsGet", function(_, client)
		local entity = net.ReadEntity()

		if (!Allowed(client, entity)) then
			return
		end

		net.Start("nwEntSettings")
			net.WriteEntity(entity)
			net.WriteString(util.TableToJSON(ES.list[entity:GetClass()].Get(entity)))
		net.Send(client)
	end)

	net.Receive("nwEntSettingsSet", function(_, client)
		local entity = net.ReadEntity()
		local values = util.JSONToTable(net.ReadString() or "") or {}

		if (!Allowed(client, entity)) then
			return
		end

		local ok, why = ES.list[entity:GetClass()].Set(entity, values)

		if (ok == false) then
			return NW.Notify(client, why)
		end

		if (NW.persist.classes[entity:GetClass()]) then
			NW.persist.Save(entity:GetClass())
		end

		NW.Notify(client, "Настройки сохранены")
		MsgN(string.format("[SETTINGS] %s (%s): %s #%d", client:Nick(), client:SteamName(), entity:GetClass(),
			entity:EntIndex()))
	end)

	return
end

-- ------------------------------------------------------------------ client --
properties.Add("nw_settings", {
	MenuLabel = "Настройки",
	Order = 50,
	MenuIcon = "icon16/cog.png",
	Filter = function(_, entity, client)
		return IsValid(entity) and ES.list[entity:GetClass()] != nil and client:IsAdmin()
	end,
	Action = function(_, entity)
		net.Start("nwEntSettingsGet")
			net.WriteEntity(entity)
		net.SendToServer()
	end
})

local BG = Color(18, 20, 24, 248)
local ROW = Color(30, 33, 38)
local TEXT = Color(232, 228, 220)
local MUTED = Color(150, 156, 162)
local ACCENT = Color(232, 170, 64)

local frame

local function Items()
	local out = {{"", "— руками, без инструмента —"}}

	for id, item in SortedPairsByMemberValue(NW.items.list, "name") do
		out[#out + 1] = {id, item.name .. "  (" .. id .. ")"}
	end

	return out
end

net.Receive("nwEntSettings", function()
	local entity = net.ReadEntity()
	local values = util.JSONToTable(net.ReadString() or "") or {}
	local data = IsValid(entity) and ES.list[entity:GetClass()]

	if (!data) then
		return
	end

	if (IsValid(frame)) then
		frame:Remove()
	end

	local sh = ScrH()
	local rowH = 34
	local preview = false

	for _, field in ipairs(data.fields) do
		preview = preview or field.type == "model"
	end

	local w = math.min(ScrW() - 40, 620)
	local h = 70 + #data.fields * (rowH + 22) + (preview and 180 or 0) + 60

	frame = vgui.Create("DFrame")
	frame:SetSize(w, math.min(h, sh - 40))
	frame:Center()
	frame:SetTitle("")
	frame:MakePopup()
	frame.Paint = function(_, pw, ph)
		draw.RoundedBox(8, 0, 0, pw, ph, BG)
		draw.RoundedBox(2, 0, 0, pw, 3, ACCENT)
		draw.SimpleText(data.title, "nwWidgetTitle", 18, 14, TEXT)
		draw.SimpleText(entity:GetClass() .. "  #" .. entity:EntIndex(), "nwWidgetLabel", 18, 46, MUTED)
	end

	local scroll = vgui.Create("DScrollPanel", frame)

	scroll:SetPos(16, 70)
	scroll:SetSize(w - 32, frame:GetTall() - 70 - 60)

	local getters = {}
	local modelPanel

	for _, field in ipairs(data.fields) do
		local holder = scroll:Add("DPanel")

		holder:Dock(TOP)
		holder:DockMargin(0, 0, 0, 6)
		holder:SetTall(rowH + 18)
		holder.Paint = function(_, pw, ph)
			draw.SimpleText(field.name, "nwWidgetLabel", 2, 0, MUTED)
		end

		local value = values[field.id]
		local control

		if (field.type == "bool") then
			control = vgui.Create("DCheckBoxLabel", holder)
			control:SetText(value and "да" or "нет")
			control:SetTextColor(TEXT)
			control:SetValue(value == true)
			control.OnChange = function(self, bOn)
				self:SetText(bOn and "да" or "нет")
			end
			getters[field.id] = function()
				return control:GetChecked()
			end
		elseif (field.type == "number") then
			control = vgui.Create("DNumSlider", holder)
			control:SetMin(field.min or 0)
			control:SetMax(field.max or 100)
			control:SetDecimals(0)
			control:SetValue(tonumber(value) or field.min or 0)
			control.Label:SetVisible(false)
			getters[field.id] = function()
				return math.Round(control:GetValue())
			end
		elseif (field.type == "choice" or field.type == "item") then
			local options = field.type == "item" and Items() or
				(isfunction(field.options) and field.options() or field.options)

			control = vgui.Create("DComboBox", holder)
			control:SetSortItems(false)

			for _, option in ipairs(options) do
				control:AddChoice(option[2], option[1], option[1] == value)
			end

			getters[field.id] = function()
				local _, chosen = control:GetSelected()

				if (chosen == nil) then
					return value
				end

				return chosen
			end
		else
			control = vgui.Create("DTextEntry", holder)
			control:SetText(tostring(value or ""))
			control:SetPlaceholderText(field.default or "")
			getters[field.id] = function()
				return control:GetValue()
			end

			if (field.type == "model") then
				control.OnChange = function(self)
					if (IsValid(modelPanel)) then
						local path = string.Trim(self:GetValue())

						modelPanel:SetModel(path != "" and path or (field.default or entity:GetModel()))
					end
				end
				control.OnValueChange = control.OnChange
			end
		end

		control:SetPos(0, 18)
		control:SetSize(w - 48, rowH - 4)

		if (field.type == "model") then
			modelPanel = scroll:Add("DModelPanel")
			modelPanel:Dock(TOP)
			modelPanel:DockMargin(0, 0, 0, 8)
			modelPanel:SetTall(170)
			modelPanel:SetModel(entity:GetModel())
			modelPanel.LayoutEntity = function(self, model)
				model:SetAngles(Angle(0, RealTime() * 30 % 360, 0))
			end

			local base = modelPanel.SetModel

			modelPanel.SetModel = function(self, path)
				base(self, path)

				local model = self:GetEntity()

				if (IsValid(model)) then
					local mins, maxs = model:GetRenderBounds()
					local size = math.max(maxs:Distance(mins), 8)

					self:SetCamPos(Vector(size, size, size * 0.6))
					self:SetLookAt((mins + maxs) / 2)
				end
			end
			modelPanel:SetModel(entity:GetModel())
		end
	end

	local save = vgui.Create("DButton", frame)

	save:SetText("")
	save:SetSize(w * 0.45, 38)
	save:SetPos(16, frame:GetTall() - 52)
	save.Paint = function(self, pw, ph)
		draw.RoundedBox(6, 0, 0, pw, ph, self:IsHovered() and Color(250, 190, 80) or ACCENT)
		draw.SimpleText("Сохранить", "nwWidgetBold", pw / 2, ph / 2, Color(20, 16, 10), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end
	save.DoClick = function()
		local out = {}

		for id, get in pairs(getters) do
			out[id] = get()
		end

		net.Start("nwEntSettingsSet")
			net.WriteEntity(entity)
			net.WriteString(util.TableToJSON(out))
		net.SendToServer()
		surface.PlaySound("network2/ui/confirm.mp3")
		frame:Remove()
	end

	local cancel = vgui.Create("DButton", frame)

	cancel:SetText("")
	cancel:SetSize(w * 0.3, 38)
	cancel:SetPos(w - 16 - w * 0.3, frame:GetTall() - 52)
	cancel.Paint = function(self, pw, ph)
		draw.RoundedBox(6, 0, 0, pw, ph, self:IsHovered() and Color(52, 58, 66) or ROW)
		draw.SimpleText("Отмена", "nwWidgetBold", pw / 2, ph / 2, TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	cancel.DoClick = function()
		frame:Remove()
	end
end)
