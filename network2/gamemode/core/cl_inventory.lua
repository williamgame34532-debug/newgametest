-- Inventory menu (Q). Q opens it with an animation and Q again (or the cross in the upper
-- right, or ESC) closes it with the reverse one; admins holding Q get the sandbox spawn menu.
-- The world camera does not move. A grey-dark backdrop over the game, and on it:
--   top     faction icon, name and faction on the left; a row of buttons on the right
--           (Инвентарь, Настройки, Авторы, Конфигурация for admins, the cross), the name of a
--           button under it on hover;
--   cards   ПЕРСОНАЖ - a portrait (head and shoulders, alive) and bars: health, hunger, thirst,
--           stamina; ЭКИПИРОВКА - weapons (Основное, Вторичное, Холодное) and clothing (Голова,
--           Лицо, Торс, Руки, Ноги, Обувь); ИНВЕНТАРЬ - the grid of grey-dark cells.
-- Every item is shown by its 3D model; clothing shows only the piece itself.
-- Items: hover - a tooltip panel with the model; drag - a line runs from the cell the item came
-- from to the cursor; into another cell (swap), into an equipment slot (equips it: weapons are
-- given, clothes change the bodygroups), or outside the cards (drops it into the world); RMB -
-- Взаимодействовать / Выбросить. E on an item in the world: a small panel with "Взять".

NW.inventory = NW.inventory or {}

local INV = NW.inventory
local U = NW.ui
local I = NW.items

INV.data = INV.data or {grid = {}, equip = {}}
INV.page = INV.page or "inventory"
INV.camera = 0

local SLOT = "network2/ui/inv_slot.png"
local CELL = "network2/ui/inv_cell.png"
local TIP = "network2/ui/inv_tip.png"
local OUTLINE = "network2/ui/outline.png"
local MENU = "network2/ui/board_menu.png"
local SHADE = Material("network2/ui/inv_shade.png", "smooth")

local ICON_TINT = Color(226, 230, 234)
local MUTED = Color(124, 128, 134)
local GOOD = Color(150, 214, 138)
local BAD = Color(226, 104, 92)
local AMBER = Color(232, 196, 72)

local SOUND = {
	open = {"network2/inv/cloth_belt.wav", "network2/inv/handle_small_leather2.wav"},
	close = {"network2/inv/cloth2.wav", "network2/inv/cloth3.wav"},
	move = {"network2/inv/inv_move1.wav", "network2/inv/inv_move2.wav", "network2/inv/inv_move3.wav",
		"network2/inv/inv_move4.mp3"},
	lift = {"network2/inv/cloth1.wav", "network2/inv/cloth4.wav"},
	deny = {"network2/ui/char/textline_1.wav"}
}

local function Sound(kind)
	local list = SOUND[kind]

	if (list) then
		surface.PlaySound(list[math.random(#list)])
	end
end

local function Fonts()
	local h = ScrH()
	local function F(name, font, size, weight, extra)
		local data = {font = font, size = math.max(11, math.Round(h * size)), weight = weight, extended = true,
			antialias = true}

		for k, v in pairs(extra or {}) do
			data[k] = v
		end

		surface.CreateFont(name, data)
	end

	F("nwInvTitle", "Jura", 0.027, 700)
	F("nwInvName", "Montserrat SemiBold", 0.024, 600)
	F("nwInvText", "Exo 2", 0.0165, 500)
	F("nwInvSmall", "Exo 2", 0.0145, 500)
	F("nwInvTiny", "Montserrat Medium", 0.0118, 500)
	F("nwInvTipName", "Montserrat SemiBold", 0.0195, 600)
	F("nwInvTipText", "Exo 2", 0.0158, 400)
	F("nwInvTipCat", "Montserrat Medium", 0.0115, 500)
	F("nwInvButton", "Exo 2", 0.0175, 600)
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwInvFonts", Fonts)

local function ItemIcon(item)
	return U.Material("network2/items/" .. (item and item.icon or "bag") .. ".png")
end

local function Ease(t)
	return t * t * (3 - 2 * t)
end

-- words of a text in lines no wider than width
local function WrapText(text, font, width)
	surface.SetFont(font)

	local lines, line = {}, ""

	for word in string.gmatch(text or "", "%S+") do
		local candidate = line == "" and word or (line .. " " .. word)

		if (surface.GetTextSize(candidate) > width and line != "") then
			lines[#lines + 1] = line
			line = word
		else
			line = candidate
		end
	end

	if (line != "") then
		lines[#lines + 1] = line
	end

	return lines
end

INV.WrapText = WrapText

-- ------------------------------------------------------------------- data --
net.Receive("nwInvSync", function()
	local raw = util.JSONToTable(net.ReadString() or "") or {}
	local data = {grid = {}, equip = {}}

	for _, entry in ipairs(raw.grid or {}) do
		local index = tonumber(entry[1])

		if (index) then
			data.grid[index] = {id = entry[2], data = entry[3] or {}}
		end
	end

	for _, entry in ipairs(raw.equip or {}) do
		data.equip[tostring(entry[1])] = {id = entry[2], data = entry[3] or {}}
	end

	INV.data = data
end)

local function Resolve(ref)
	local index = tonumber(string.match(ref or "", "^g(%d+)$") or "")

	if (index) then
		return "grid", index
	end

	local slot = string.match(ref or "", "^e(%a+)$")

	if (slot) then
		return "equip", slot
	end

	local cellIndex, k = string.match(ref or "", "^c(%d+)_(%d+)$")

	if (cellIndex) then
		return "pack", {tonumber(cellIndex), tonumber(k)}
	end
end

-- the thing at a position inside an opened package
local function PackCell(key)
	local cell = INV.data.grid[key[1]]
	local items = cell and cell.data and cell.data.open and cell.data.items
	local id = istable(items) and items[key[2]]

	if (isstring(id) and id != "" and I.Get(id)) then
		return {id = id, data = {}}
	end
end

function INV.Cell(ref)
	local kind, key = Resolve(ref)

	if (kind == "pack") then
		return PackCell(key)
	end

	return kind and INV.data[kind][key]
end

function INV.Capacity()
	return I.Capacity(INV.data.equip)
end

local function Fits(cell, ref)
	if (!cell) then
		return true
	end

	local kind, key = Resolve(ref)

	if (kind == "grid") then
		local item = I.Get(cell.id)

		-- a bag never lies in the cells a bag gives
		return key <= INV.Capacity() and !(item and item.bag and key > I.gridSize)
	elseif (kind == "pack") then
		return false
	end

	local item = I.Get(cell.id)

	return item != nil and item.slot == key
end

function INV.CanPlace(fromRef, toRef)
	local fromKind = Resolve(fromRef)
	local toKind = Resolve(toRef)

	-- out of a package: only into an empty place
	if (fromKind == "pack") then
		return toKind != "pack" and INV.Cell(toRef) == nil and Fits(INV.Cell(fromRef), toRef)
	end

	if (toKind == "pack") then
		return false
	end

	return Fits(INV.Cell(fromRef), toRef) and Fits(INV.Cell(toRef), fromRef)
end

function INV.Count()
	local count = 0

	for index = 1, INV.Capacity() do
		if (INV.data.grid[index]) then
			count = count + 1
		end
	end

	return count
end

function INV.SendMove(fromRef, toRef)
	-- move right away on the screen (the server's answer corrects it if needed)
	local fromKind, fromKey = Resolve(fromRef)
	local toKind, toKey = Resolve(toRef)

	-- putting on / taking off takes time on the server: no early move then
	if (fromKind != "pack" and toKind != "pack" and fromKind != "equip" and toKind != "equip") then
		local a, b = INV.data[fromKind][fromKey], INV.data[toKind][toKey]

		INV.data[toKind][toKey] = a
		INV.data[fromKind][fromKey] = b
	end

	net.Start("nwInvMove")
		net.WriteString(fromRef)
		net.WriteString(toRef)
	net.SendToServer()

	Sound("move")
end

-- a package: open it on the server once, then show / hide what is inside
function INV.OpenPack(ref, bOpened)
	local kind, key = Resolve(ref)

	if (kind != "grid") then
		return
	end

	if (!bOpened) then
		INV.Action(ref, "use")
		INV.openPack = key
	else
		INV.openPack = INV.openPack != key and key or nil
	end

	U.Tick()
end

function INV.Action(ref, action)
	net.Start("nwInvAction")
		net.WriteString(ref)
		net.WriteString(action)
	net.SendToServer()
end

-- ------------------------------------------------------------- the menu --
local function StyledMenu()
	local menu = DermaMenu()

	menu:SetMinimumWidth(math.Round(ScrH() * 0.24))
	menu.Paint = function(self, w, h)
		U.Slice(U.Material(MENU), 0, 0, w, h, 2, 255, 255, 255, 250)
	end

	return menu
end

local function MenuOption(menu, text, icon, hint, callback)
	local option = menu:AddOption(text, callback)
	local oh = math.Round(ScrH() * 0.04)

	option:SetFont("nwInvButton")
	option:SetTextColor(U.color.text)
	option:SetTextInset(math.Round(oh * 1.2), 0)
	option.PerformLayout = function(self)
		self:SizeToContents()
		self:SetSize(math.max(menu:GetMinimumWidth(), self:GetWide() + oh * 2.6), oh)
	end
	option.Paint = function(self, w, h)
		local hovered = self:IsHovered()

		if (hovered) then
			surface.SetDrawColor(255, 255, 255, 16)
			surface.DrawRect(1, 0, w - 2, h)
		end

		local size = math.Round(h * 0.48)

		U.DrawIcon(icon, h * 0.38, (h - size) / 2, size, hovered and U.color.text or U.color.dim)

		if (hint) then
			draw.SimpleText(hint, "nwInvTiny", w - h * 0.4, h / 2, MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	local entered = option.OnCursorEntered

	option.OnCursorEntered = function(self)
		entered(self)
		surface.PlaySound("network2/ui/hover.wav")
	end

	return option
end

function INV.Menu(ref)
	local cell = INV.Cell(ref)
	local item = cell and I.Get(cell.id)

	if (!item) then
		return
	end

	U.Tick()

	local menu = StyledMenu()
	local kind = Resolve(ref)

	local opened = item.contents and cell.data and cell.data.open

	MenuOption(menu, "Взаимодействовать", "interact", opened and "содержимое" or I.UseVerb(item, kind == "equip"),
		function()
			if (item.contents and kind == "grid") then
				INV.OpenPack(ref, opened)
			else
				INV.Action(ref, "use")
			end
		end)
	MenuOption(menu, "Выбросить", "drop", nil, function()
		INV.Action(ref, "drop")
	end)

	menu:Open()
	INV.openMenu = menu
end

-- -------------------------------------------------------------- item views --
-- An item as its 3D model. Ordinary items: framed like a spawn icon. Clothing: only the piece
-- itself - a citizen model wearing it with every other part hidden (the other bodygroups go to
-- their empty variant, the materials of what cannot be emptied - body, torso, legs... - are
-- swapped for an invisible one; which mesh uses which material is read from the .mdl file).
local MANNEQUIN = "models/network/citizens/male01.mdl"
local HIDDEN = CreateMaterial("nw_inv_hidden", "VertexLitGeneric", {
	["$basetexture"] = "color/white",
	["$alpha"] = "0",
	["$translucent"] = "1",
	["$no_draw"] = "1"
})
local partsCache = {}

-- bodyparts of a model: parts[bodygroup][submodel] = {material indices of its meshes}
local function ModelParts(path)
	if (partsCache[path] != nil) then
		return partsCache[path]
	end

	partsCache[path] = false

	local f = file.Open(path, "rb", "GAME")

	if (!f) then
		return false
	end

	local function Int(offset)
		f:Seek(offset)

		return f:ReadLong()
	end

	local parts = {}
	local count, index = Int(232), Int(236)

	if (count < 0 or count > 64) then
		f:Close()

		return false
	end

	for part = 0, count - 1 do
		local base = index + part * 16
		local models, modelIndex = Int(base + 4), Int(base + 12)
		local subs = {}

		for k = 0, math.min(models, 128) - 1 do
			local model = base + modelIndex + k * 148
			local meshes, meshIndex = Int(model + 72), Int(model + 76)
			local materials = {}

			for m = 0, math.min(meshes, 64) - 1 do
				materials[#materials + 1] = Int(model + meshIndex + m * 116)
			end

			subs[k] = materials
		end

		parts[part] = subs
	end

	f:Close()
	partsCache[path] = parts

	return parts
end

-- show only the clothing piece on this entity
local function Isolate(entity, wear)
	local group, index = I.WearIndex(entity, wear)
	local parts = ModelParts(entity:GetModel())

	if (!group or !parts or !parts[group]) then
		return false
	end

	entity:SetSkin(0)

	local keep = {}

	for _, material in ipairs(parts[group][index] or {}) do
		keep[material] = true
	end

	entity:SetBodygroup(group, index)

	for part, subs in pairs(parts) do
		if (part != group) then
			-- an empty variant if there is one
			local chosen = 0

			for k, materials in pairs(subs) do
				if (#materials == 0) then
					chosen = k
					break
				end
			end

			entity:SetBodygroup(part, chosen)

			for _, material in ipairs(subs[chosen] or {}) do
				if (!keep[material]) then
					entity:SetSubMaterial(material, "!nw_inv_hidden")
				end
			end
		end
	end

	return true
end
local FRAMING = {
	head = {"ValveBiped.Bip01_Head1", 26, Vector(0, 0, 5)},
	face = {"ValveBiped.Bip01_Head1", 22, Vector(1, 0, 0)},
	torso = {"ValveBiped.Bip01_Spine2", 60, Vector(0, 0, -6)},
	hands = {"ValveBiped.Bip01_Spine", 58, Vector(0, 0, -4)},
	legs = {"ValveBiped.Bip01_R_Calf", 66, Vector(0, -4, 12)},
	shoes = {"ValveBiped.Bip01_R_Foot", 34, Vector(0, -4, 2)},
	glasses = {"ValveBiped.Bip01_Head1", 18, Vector(2, 0, 2)},
	satchel = {"ValveBiped.Bip01_Spine1", 52, Vector(0, 0, -4), Vector(0.6, 1, 0.1)},
	bag = {"ValveBiped.Bip01_Spine2", 58, Vector(-4, 0, -4), Vector(-1, 0.5, 0.15)}
}
local FRONT = Vector(1, 0.42, 0.14):GetNormalized()

local function FrameBounds(view, entity)
	local mins, maxs = entity:GetRenderBounds()
	local center = (mins + maxs) / 2
	local size = (maxs - mins):Length()

	view.aLookAngle = nil
	view:SetLookAt(center)
	view:SetCamPos(center + Vector(1, 0.9, 0.7):GetNormalized() * size * 1.15)
	view:SetFOV(34)
end

local function ItemView(parent)
	local view = parent:Add("DModelPanel")

	view:SetMouseInputEnabled(false)
	view:SetAmbientLight(Color(86, 88, 94))
	view:SetDirectionalLight(BOX_TOP, Color(255, 248, 236))
	view:SetDirectionalLight(BOX_FRONT, Color(170, 176, 186))
	view:SetDirectionalLight(BOX_RIGHT, Color(70, 82, 100))
	view:SetVisible(false)
	view.spin = 0

	view.SetItem = function(self, item)
		local id = item and item.id

		if (self.itemID == id) then
			return
		end

		self.itemID = id
		self:SetVisible(id != nil)

		if (!item) then
			return
		end

		local model = item.model
		local wear = item.wear
		local client = LocalPlayer()

		if (wear) then
			model = client:FindBodygroupByName(wear.group) >= 0 and client:GetModel() or MANNEQUIN
		end

		self:SetModel(model)

		local entity = self:GetEntity()

		if (!IsValid(entity)) then
			return
		end

		if (wear) then
			if (!Isolate(entity, wear)) then
				local group, index = I.WearIndex(entity, wear)

				if (group) then
					entity:SetBodygroup(group, index)
				end
			end

			local idle = entity:SelectWeightedSequence(ACT_IDLE)

			entity:ResetSequence(idle and idle > 0 and idle or 0)
			self.framing = FRAMING[wear.group] or FRAMING.torso
			self.aLookAngle = nil
			self:SetFOV(26)
		else
			self.framing = nil

			local cam = item.iconCam

			if (cam) then
				self:SetCamPos(cam.pos)
				self:SetLookAng(cam.ang)
				self:SetFOV(cam.fov or 30)
			elseif (PositionSpawnIcon) then
				local tab = PositionSpawnIcon(entity, entity:GetPos())

				if (tab) then
					self:SetCamPos(tab.origin)
					self:SetLookAng(tab.angles)
					self:SetFOV(tab.fov)
				else
					FrameBounds(self, entity)
				end
			else
				FrameBounds(self, entity)
			end
		end
	end

	view.LayoutEntity = function(self, entity)
		-- a slow turn while hovered
		self.spin = Lerp(math.Clamp(FrameTime() * 6, 0, 1), self.spin, self.hovered and 1 or 0)
		entity:SetAngles(Angle(0, math.sin(RealTime() * 1.6) * 16 * self.spin, 0))

		if (self.framing) then
			local bone = entity:LookupBone(self.framing[1])
			local pos = bone and entity:GetBonePosition(bone)

			if (pos) then
				pos = pos + self.framing[3]
				self:SetLookAt(pos)
				self:SetCamPos(pos + (self.framing[4] and self.framing[4]:GetNormalized() or FRONT) * self.framing[2])
			end
		end
	end

	return view
end

INV.ItemView = ItemView

-- --------------------------------------------------------------- tooltip --
-- a panel next to the cursor: the model on the left, name, category, description, effects
local function Tooltip(frame)
	local sh = ScrH()
	local tip = frame:Add("EditablePanel")

	tip:SetZPos(40)
	tip:SetMouseInputEnabled(false)
	tip:SetVisible(false)
	tip.alpha = 0

	local view = ItemView(tip)

	tip.SetItem = function(self, item, data)
		if (self.item == item and self.data == data) then
			return
		end

		self.item = item
		self.data = data
		view:SetItem(item)

		if (!item) then
			return
		end

		local pad = math.Round(sh * 0.016)
		local modelS = math.Round(sh * 0.1)
		local textW = math.Round(sh * 0.26)

		self.cat = I.categories[item.category] or I.categories.misc
		-- a thing with its own line (a key: the door it opens)
		local description = item.description or ""

		if (item.Describe and data) then
			description = item.Describe(data) or description
		end

		self.lines = WrapText(description, "nwInvTipText", textW)
		self.effects = I.Effects(item)

		surface.SetFont("nwInvTipName")

		local nameW, nameH = surface.GetTextSize(item.name)

		surface.SetFont("nwInvTipText")

		local textH = select(2, surface.GetTextSize("Ag"))

		self.layout = {pad = pad, modelS = modelS, nameH = nameH, textH = textH}

		local width = pad * 3 + modelS + math.max(textW, nameW)
		local textBlock = nameH + sh * 0.02 + pad * 0.6 + #self.lines * textH +
			(#self.effects > 0 and (pad * 0.5 + #self.effects * textH) or 0)
		local height = pad * 2 + math.max(modelS, textBlock) + sh * 0.03

		self:SetSize(width, height)
		view:SetPos(pad, pad)
		view:SetSize(modelS, modelS)
	end

	tip.Paint = function(self, w, h)
		local item = self.item

		if (!item) then
			return
		end

		local L = self.layout
		local cat = self.cat

		U.Blur(0, 0, w, h, 3, 255, self, 8)
		U.Slice(U.Material(TIP), 0, 0, w, h, 8)
		U.Slice(U.Material(CELL), L.pad, L.pad, L.modelS, L.modelS, 6)

		surface.SetDrawColor(cat.color.r, cat.color.g, cat.color.b, 230)
		surface.DrawRect(L.pad + L.modelS * 0.25, L.pad + L.modelS - 3, L.modelS * 0.5, 2)

		local x = L.pad * 2 + L.modelS
		local y = L.pad

		draw.SimpleText(item.name, "nwInvTipName", x, y, U.color.text)
		y = y + L.nameH

		local slot = item.slot and I.slotByID[item.slot]

		draw.SimpleText(U.Upper(cat.name) .. (slot and ("  ·  " .. U.Upper(slot.name)) or ""), "nwInvTipCat", x, y,
			cat.color)
		y = y + sh * 0.02

		surface.SetDrawColor(255, 255, 255, 22)
		surface.DrawRect(x, y, w - x - L.pad, 1)
		y = y + L.pad * 0.6

		for _, line in ipairs(self.lines) do
			draw.SimpleText(line, "nwInvTipText", x, y, U.color.dim)
			y = y + L.textH
		end

		if (#self.effects > 0) then
			y = y + L.pad * 0.5

			for _, line in ipairs(self.effects) do
				draw.SimpleText(line, "nwInvTipText", x, y, string.find(line, "+", 1, true) and GOOD or U.color.text)
				y = y + L.textH
			end
		end

		draw.SimpleText("ЛКМ — перетащить    ПКМ — действия", "nwInvTiny", L.pad, h - L.pad, MUTED, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_BOTTOM)
	end

	return tip
end

-- ----------------------------------------------------------------- slots --
INV.slots = INV.slots or {}

function INV.SlotAt(x, y)
	for _, slot in ipairs(INV.slots) do
		if (IsValid(slot) and slot:IsVisible() and slot:GetParent():IsVisible()) then
			local sx, sy = slot:LocalToScreen(0, 0)

			if (x >= sx and y >= sy and x <= sx + slot:GetWide() and y <= sy + slot:GetTall()) then
				return slot
			end
		end
	end
end

local function MakeSlot(parent, ref, x, y, size, info)
	local slot = parent:Add("DPanel")
	local inset = math.max(2, math.Round(size * 0.06))

	slot:SetPos(x, y)
	slot:SetSize(size, size)
	slot.ref = ref
	slot.info = info
	slot.hover = 0

	local view = ItemView(slot)

	view:SetPos(inset, inset)
	view:SetSize(size - inset * 2, size - inset * 2)
	slot.view = view

	slot.Paint = function(self, w, h)
		local cell = INV.Cell(self.ref)
		local item = cell and I.Get(cell.id)
		local dragging = INV.drag and INV.drag.ref == self.ref
		local hovered = (self:IsHovered() and !INV.drag) or INV.dropTarget == self

		self.hover = Lerp(math.Clamp(FrameTime() * 14, 0, 1), self.hover, hovered and 1 or 0)

		-- the model of the item (hidden in the cell it is being dragged from)
		view:SetItem(!dragging and item or nil)
		view.hovered = self:IsHovered() and !INV.drag

		U.Slice(U.Material(CELL), 0, 0, w, h, 6, 255, 255, 255, dragging and 150 or 255)

		if (self.hover > 0.01) then
			U.Slice(U.Material(OUTLINE), 0, 0, w, h, 6, 255, 255, 255, 40 * self.hover)
		end

		if (INV.drag and INV.dropTarget == self and INV.drag.ref != self.ref) then
			local color = INV.CanPlace(INV.drag.ref, self.ref) and GOOD or BAD

			U.Slice(U.Material(OUTLINE), 0, 0, w, h, 6, color.r, color.g, color.b, 170)
		end

		if (item and !dragging) then
			local cat = I.categories[item.category] or I.categories.misc

			-- the category: a short line in the lower left corner
			surface.SetDrawColor(cat.color.r, cat.color.g, cat.color.b, 200)
			surface.DrawRect(inset + 1, h - inset - 2, math.Round(w * 0.22), 2)

			if (item.contents) then
				local press = INV.press

				if (cell.data and cell.data.open) then
					-- opened: a small mark, brighter while its contents are shown
					local kind, key = Resolve(self.ref)
					local shown = kind == "grid" and INV.openPack == key

					draw.RoundedBox(3, w - inset - 8, inset + 2, 6, 6, Color(232, 196, 72, shown and 255 or 120))
				elseif (press and press.ref == self.ref and !press.held and !INV.drag) then
					-- held: unpacking
					local t = math.Clamp((RealTime() - press.time) / INV.holdTime, 0, 1)

					draw.RoundedBox(2, inset + 2, h * 0.5 - 2, (w - inset * 2 - 4), 4, Color(0, 0, 0, 160))
					draw.RoundedBox(2, inset + 2, h * 0.5 - 2, (w - inset * 2 - 4) * t, 4, AMBER)
					draw.SimpleText("Распаковка", "nwInvTiny", w / 2, h * 0.5 + 6, U.color.text, TEXT_ALIGN_CENTER,
						TEXT_ALIGN_TOP)
				end
			end

			if (self:IsHovered() and !INV.drag) then
				INV.hoverRef = self.ref
			end
		elseif (self.info) then
			-- an empty equipment slot: what goes there
			local s = math.Round(w * 0.42)

			surface.SetMaterial(U.Material("network2/items/" .. self.info.icon .. ".png"))
			surface.SetDrawColor(255, 255, 255, 26)
			surface.DrawTexturedRect((w - s) / 2, (h - s) / 2 - h * 0.06, s, s)

			draw.SimpleText(U.Upper(self.info.name), "nwInvTiny", w / 2, h - inset - 2, Color(255, 255, 255, 46),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		end
	end
	slot.OnMousePressed = function(self, code)
		if (!INV.Cell(self.ref)) then
			return
		end

		if (code == MOUSE_LEFT) then
			local mx, my = input.GetCursorPos()

			INV.press = {ref = self.ref, x = mx, y = my, panel = self, time = RealTime()}
			self:MouseCapture(true)
		elseif (code == MOUSE_RIGHT) then
			INV.Menu(self.ref)
		end
	end
	slot.OnMouseReleased = function(self, code)
		if (code == MOUSE_LEFT) then
			self:MouseCapture(false)
			INV.Release()
		end
	end

	INV.slots[#INV.slots + 1] = slot

	return slot
end

INV.holdTime = 0.7

function INV.Release()
	local press = INV.press

	INV.press = nil

	local drag = INV.drag

	if (!drag) then
		-- a click on an opened package shows / hides what is inside
		local cell = press and !press.held and INV.Cell(press.ref)
		local item = cell and I.Get(cell.id)

		if (item and item.contents and cell.data and cell.data.open) then
			INV.OpenPack(press.ref, true)
		end

		return
	end

	INV.drag = nil
	INV.dropTarget = nil

	local mx, my = input.GetCursorPos()
	local target = INV.SlotAt(mx, my)

	if (target) then
		if (target.ref != drag.ref) then
			if (INV.CanPlace(drag.ref, target.ref)) then
				INV.SendMove(drag.ref, target.ref)
			else
				Sound("deny")
			end
		end
	elseif (!INV.OverMenu(mx, my)) then
		-- into the world
		INV.Action(drag.ref, "drop")
	end
end

-- over the grid, the equipment or the buttons: releasing there is not a drop into the world
function INV.OverMenu(x, y)
	local margin = ScrH() * 0.015

	for _, panel in ipairs({INV.gridArea, INV.equipArea, INV.portraitArea, INV.packArea, INV.buttons}) do
		if (IsValid(panel) and panel:IsVisible()) then
			local px, py = panel:LocalToScreen(0, 0)

			if (x >= px - margin and y >= py - margin and x <= px + panel:GetWide() + margin and
				y <= py + panel:GetTall() + margin) then
				return true
			end
		end
	end

	return false
end

-- ---------------------------------------------------------- inventory page --
-- Three cards side by side, centred: ПЕРСОНАЖ (portrait and bars), ЭКИПИРОВКА (weapons row,
-- clothing 3 x 2), ИНВЕНТАРЬ (the grid). A small caption with a square mark over each card.
local function Bar(x, y, w, icon, label, value, max, color)
	local sh = ScrH()
	local fraction = math.Clamp(value / math.max(max, 1), 0, 1)
	local is = math.Round(sh * 0.017)

	U.DrawIcon(icon, x, y - is, is, color)
	draw.SimpleText(label, "nwInvSmall", x + is + sh * 0.006, y - is / 2, U.color.dim, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
	draw.SimpleText(math.Round(value), "nwInvSmall", x + w, y - is / 2, U.color.text, TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)

	local by = y + math.Round(sh * 0.006)
	local bh = math.max(3, math.Round(sh * 0.0042))

	draw.RoundedBox(bh / 2, x, by, w, bh, Color(255, 255, 255, 16))
	draw.RoundedBox(bh / 2, x, by, math.max(bh, w * fraction), bh, ColorAlpha(color, 235))
end

-- head and shoulders of the character, breathing, turning a little after the mouse
local function Portrait(parent, x, y, w, h)
	local panel = parent:Add("DModelPanel")
	local base = baseclass.Get("DModelPanel")

	panel:SetPos(x, y)
	panel:SetSize(w, h)
	panel:SetMouseInputEnabled(false)
	panel:SetFOV(22)
	panel:SetAmbientLight(Color(44, 46, 52))
	panel:SetDirectionalLight(BOX_TOP, Color(255, 244, 228))
	panel:SetDirectionalLight(BOX_FRONT, Color(150, 156, 168))
	panel:SetDirectionalLight(BOX_RIGHT, Color(70, 96, 130))

	local function Setup()
		local client = LocalPlayer()

		panel:SetModel(client:GetModel())

		local entity = panel:GetEntity()

		if (IsValid(entity)) then
			local idle = entity:SelectWeightedSequence(ACT_IDLE)

			entity:ResetSequence(idle and idle > 0 and idle or 0)
		end

		panel.modelPath = client:GetModel()
	end

	Setup()

	panel.yaw = 0
	panel.Paint = function(self, pw, ph)
		local client = LocalPlayer()

		U.Slice(U.Material(CELL), 0, 0, pw, ph, 6)

		if (self.modelPath != client:GetModel()) then
			Setup()
		end

		-- skin and clothes follow the real character
		local entity = self:GetEntity()

		if (IsValid(entity)) then
			if (entity:GetSkin() != client:GetSkin()) then
				entity:SetSkin(client:GetSkin())
			end

			for index = 0, client:GetNumBodyGroups() - 1 do
				local value = client:GetBodygroup(index)

				if (entity:GetBodygroup(index) != value) then
					entity:SetBodygroup(index, value)
				end
			end
		end

		base.Paint(self, pw, ph)

		surface.SetMaterial(U.Material("network2/ui/card_shade.png"))
		surface.SetDrawColor(255, 255, 255, 170)
		surface.DrawTexturedRect(1, ph * 0.6, pw - 2, ph * 0.4 - 1)
	end
	panel.LayoutEntity = function(self, entity)
		local t = RealTime()
		local mx = input.GetCursorPos() / ScrW()

		self.yaw = Lerp(math.Clamp(FrameTime() * 3, 0, 1), self.yaw, (mx - 0.3) * 24)
		entity:SetAngles(Angle(0, 14 + self.yaw + math.sin(t * 0.35) * 3, 0))
		entity:FrameAdvance()

		local head = entity:LookupBone("ValveBiped.Bip01_Head1")
		local pos = head and entity:GetBonePosition(head) or Vector(0, 0, 64)
		local breathe = math.sin(t * 1.1) * 0.4

		self:SetLookAt(pos - Vector(0, 0, 5 - breathe))
		self:SetCamPos(pos + Vector(74, 0, -1 + breathe))
	end

	return panel
end

-- a card: dark plate with a little blur, its caption above
local function Card(parent, x, y, w, h, caption, right)
	local sh = ScrH()
	local card = parent:Add("EditablePanel")
	local capH = math.Round(sh * 0.034)

	card:SetPos(x, y - capH)
	card:SetSize(w, h + capH)
	card.capH = capH
	card.Paint = function(self, pw, ph)
		local mark = math.Round(sh * 0.007)

		surface.SetDrawColor(U.color.text)
		surface.DrawRect(0, capH * 0.4 - mark / 2, mark, mark)
		draw.SimpleText(caption, "nwInvTiny", mark + sh * 0.008, capH * 0.4, U.color.text, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		if (right) then
			draw.SimpleText(right(), "nwInvTiny", pw, capH * 0.4, MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		U.Blur(0, capH, pw, ph - capH, 2, 255, self, 8)
		U.Slice(U.Material(TIP), 0, capH, pw, ph - capH, 8, 255, 255, 255, 235)
	end

	return card, capH
end

local function InventoryPage(parent)
	local sw, sh = ScrW(), ScrH()
	local page = parent:Add("EditablePanel")

	page:SetSize(sw, sh)
	page.baseX, page.baseY = 0, 0

	local pad = math.Round(sh * 0.016)
	local gap = math.Round(sh * 0.028)

	-- sizes of the three cards
	local pw = math.Round(sh * 0.22)
	local ph = math.Round(sh * 0.26)
	local barStep = math.Round(sh * 0.044)
	local c1w, c1h = pw + pad * 2, pad + ph + pad * 1.6 + barStep * 4

	local E = math.Round(sh * 0.072)
	local eg = math.Round(sh * 0.007)
	local label = math.Round(sh * 0.026)
	local c2w = E * 3 + eg * 2 + pad * 2
	local c2h = pad + label + E + pad + label + E * 2 + eg + pad + label + E + pad

	local S = math.Round(sh * 0.072)
	local g = math.Round(sh * 0.007)
	local gw = I.columns * S + (I.columns - 1) * g
	local gh = I.rows * S + (I.rows - 1) * g
	local bagGap = math.Round(sh * 0.026)
	local c3w, c3h = gw + pad * 2, gh + pad * 2

	local total = c1w + gap + c2w + gap + c3w
	local x0 = math.Round((sw - total) / 2)
	local y0 = math.Round(sh * 0.17)

	INV.slots = {}

	-- ПЕРСОНАЖ
	local c1 = Card(page, x0, y0, c1w, c1h, "ПЕРСОНАЖ")
	local cap = c1.capH

	Portrait(c1, pad, cap + pad, pw, ph)

	local bars = {health = 0, hunger = 0, thirst = 0, stamina = 0}
	local paintCard = c1.Paint

	c1.Paint = function(self, w, h)
		paintCard(self, w, h)

		local client = LocalPlayer()
		local speed = math.Clamp(FrameTime() * 6, 0, 1)

		bars.health = Lerp(speed, bars.health, client:Health())
		bars.hunger = Lerp(speed, bars.hunger, client:GetHunger())
		bars.thirst = Lerp(speed, bars.thirst, client:GetThirst())
		bars.stamina = Lerp(speed, bars.stamina, client:GetStamina())

		local by = cap + pad + ph + pad * 1.6 + barStep * 0.45

		Bar(pad, by, pw, "health", "Здоровье", bars.health, client:GetMaxHealth(), Color(214, 88, 80))
		Bar(pad, by + barStep, pw, "hunger", "Сытость", bars.hunger, 100, Color(204, 164, 92))
		Bar(pad, by + barStep * 2, pw, "thirst", "Жажда", bars.thirst, 100, Color(92, 156, 212))
		Bar(pad, by + barStep * 3, pw, "stamina", "Выносливость", bars.stamina, 100, Color(226, 190, 68))

		-- the tokens, on the right of the title
		local tokens = tostring(client:GetNW2Int("nwTokens", 0))
		local is = math.Round(cap * 0.42)

		surface.SetFont("nwInvTiny")

		local tw = surface.GetTextSize(tokens)

		draw.SimpleText(tokens, "nwInvTiny", w - pad, cap / 2, U.color.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		U.DrawIcon("tokens", w - pad - tw - is - 4, cap / 2 - is / 2, is, Color(232, 196, 72), 1)
	end

	-- ЭКИПИРОВКА
	local c2x = x0 + c1w + gap
	local c2 = Card(page, c2x, y0, c2w, c2h, "ЭКИПИРОВКА")
	local weapons, clothing, gear = {}, {}, {}

	for _, slot in ipairs(I.slots) do
		if (slot.group == "weapon") then
			weapons[#weapons + 1] = slot
		elseif (slot.group == "gear") then
			gear[#gear + 1] = slot
		else
			clothing[#clothing + 1] = slot
		end
	end

	local gearY = cap + pad + label + E + pad + label + E * 2 + eg + pad

	local paintEquip = c2.Paint

	c2.Paint = function(self, w, h)
		paintEquip(self, w, h)

		draw.SimpleText("Оружие", "nwInvSmall", pad, cap + pad + label * 0.45, U.color.dim, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
		draw.SimpleText("Одежда", "nwInvSmall", pad, cap + pad + label + E + pad + label * 0.45, U.color.dim,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Снаряжение", "nwInvSmall", pad, gearY + label * 0.45, U.color.dim, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		-- what the bag gives
		local cell = INV.data.equip.bag
		local item = cell and I.Get(cell.id)

		draw.SimpleText(item and ("+" .. item.bag .. " ячеек") or "без сумки", "nwInvSmall",
			pad + (E + eg) * #gear + eg, gearY + label + E / 2, item and U.color.text or MUTED, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	for index, slot in ipairs(gear) do
		MakeSlot(c2, "e" .. slot.id, pad + (index - 1) * (E + eg), gearY + label, E, slot)
	end

	for index, slot in ipairs(weapons) do
		MakeSlot(c2, "e" .. slot.id, pad + (index - 1) * (E + eg), cap + pad + label, E, slot)
	end

	for index, slot in ipairs(clothing) do
		local col = (index - 1) % 3
		local row = math.floor((index - 1) / 3)

		MakeSlot(c2, "e" .. slot.id, pad + col * (E + eg), cap + pad + label + E + pad + label + row * (E + eg), E,
			slot)
	end

	INV.equipArea = c2

	-- ИНВЕНТАРЬ
	local c3 = Card(page, c2x + c2w + gap, y0, c3w, c3h, "ИНВЕНТАРЬ", function()
		return "Занято " .. INV.Count() .. " / " .. INV.Capacity()
	end)

	-- the base grid, then the cells the bags give (shown only while the bags are carried)
	local cells = {}

	for index = 1, I.maxSize do
		local col = (index - 1) % I.columns
		local row = math.floor((index - 1) / I.columns)
		local y = cap + pad + row * (S + g) + (index > I.gridSize and bagGap or 0)

		cells[index] = MakeSlot(c3, "g" .. index, pad + col * (S + g), y, S)
	end

	local paintGrid = c3.Paint

	c3.Paint = function(self, w, h)
		local capacity = INV.Capacity()

		for index, cell in ipairs(cells) do
			cell:SetVisible(index <= capacity)
		end

		local extraRows = math.ceil((capacity - I.gridSize) / I.columns)
		local height = cap + pad * 2 + gh + (extraRows > 0 and (bagGap + extraRows * (S + g)) or 0)

		if (self:GetTall() != height) then
			self:SetTall(height)
		end

		paintGrid(self, w, h)

		if (extraRows > 0) then
			local y = cap + pad + gh + bagGap / 2

			surface.SetDrawColor(255, 255, 255, 20)
			surface.DrawRect(pad, y, w - pad * 2, 1)
			draw.SimpleText("СУМКА  +" .. (capacity - I.gridSize), "nwInvTiny", pad, y - 1, MUTED, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_BOTTOM)
		end
	end

	INV.gridArea = c3
	INV.portraitArea = c1

	-- an opened package: what is inside, under the equipment
	local packY = y0 + c2h + gap + cap
	local packW = c2w
	local packCells = {}
	local pack = Card(page, c2x, packY, packW, label + E + pad * 2, "СОДЕРЖИМОЕ")

	pack:SetVisible(false)

	for k = 1, 3 do
		packCells[k] = MakeSlot(pack, "c0_" .. k, pad + (k - 1) * (E + eg), cap + pad + label, E)
	end

	local paintPack = pack.Paint

	pack.Paint = function(self, w, h)
		paintPack(self, w, h)

		local cell = INV.openPack and INV.data.grid[INV.openPack]
		local item = cell and I.Get(cell.id)

		if (item) then
			draw.SimpleText(item.name, "nwInvSmall", pad, cap + pad + label * 0.45, U.color.dim, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
		end
	end
	-- (the page thinks for it: a hidden panel does not think)
	local function PackThink(self)
		local index = INV.openPack
		local cell = index and INV.data.grid[index]
		local item = cell and I.Get(cell.id)
		local items = item and item.contents and cell.data and cell.data.open and cell.data.items

		if (!istable(items)) then
			if (self:IsVisible()) then
				self:SetVisible(false)
			end

			INV.openPack = nil

			return
		end

		self:SetVisible(true)

		local x = 0

		for k, slot in ipairs(packCells) do
			local filled = isstring(items[k]) and items[k] != ""

			slot.ref = "c" .. index .. "_" .. k
			slot:SetVisible(filled)

			if (filled) then
				slot:SetPos(pad + x * (E + eg), cap + pad + label)
				x = x + 1
			end
		end
	end

	INV.packArea = pack

	page.Think = function()
		PackThink(pack)
	end

	page.Paint = function(self, w, h)
		-- the ring of a running action ("Одеваю", ...) under the grid
		local gx, gy = c3:GetPos()

		NW.progress.Draw(gx + c3:GetWide() / 2, gy + c3:GetTall() + sh * 0.1)

		draw.SimpleText("Перетащите предмет за пределы карточек, чтобы выбросить его  ·  зажмите рацион, чтобы " ..
			"распаковать", "nwInvSmall", sw / 2, sh - sh * 0.05, MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	return page
end

-- -------------------------------------------------------------- other pages --
local function TextPage(parent, title, icon, body)
	local sw, sh = ScrW(), ScrH()
	local page = parent:Add("EditablePanel")
	local width = math.Round(sh * 0.62)
	local lines = {}

	for _, paragraph in ipairs(body) do
		if (paragraph == "") then
			lines[#lines + 1] = {text = "", gap = true}
		else
			for _, line in ipairs(WrapText(paragraph.text or paragraph, paragraph.font or "nwInvText", width -
				sh * 0.06)) do
				lines[#lines + 1] = {text = line, font = paragraph.font, color = paragraph.color}
			end
		end
	end

	local lineH = math.Round(sh * 0.026)
	local height = math.Round(sh * 0.1) + #lines * lineH + math.Round(sh * 0.04)

	page:SetSize(width, height)
	page.baseX = math.Round((sw - width) / 2)
	page.baseY = math.Round((sh - height) / 2)
	page:SetPos(page.baseX, page.baseY)
	page.Paint = function(self, w, h)
		U.Blur(0, 0, w, h, 3, 255, self, 10)
		U.Slice(U.Material(SLOT), 0, 0, w, h, 10, 255, 255, 255, 255)

		local pad = sh * 0.03
		local is = math.Round(sh * 0.03)

		U.DrawIcon(icon, pad, pad, is, U.color.text)
		draw.SimpleText(title, "nwInvTitle", pad + is + sh * 0.012, pad + is / 2, U.color.text, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		surface.SetDrawColor(255, 255, 255, 22)
		surface.DrawRect(pad, pad + is + sh * 0.02, w - pad * 2, 1)

		local y = sh * 0.1

		for _, line in ipairs(lines) do
			if (!line.gap) then
				draw.SimpleText(line.text, line.font or "nwInvText", pad, y, line.color or U.color.dim)
			end

			y = y + lineH
		end
	end

	return page, width, height
end

-- A full-screen page of settings in groups: a title, and the groups as cards spread over columns
-- (each card: a caption with a square mark, then its rows - switches, sliders, text fields).
-- A row: {label, type = "toggle" | "slider" | "text", min, max, decimals, get(), set(value)}.
local function Switch(parent, row, w, h)
	local sh = ScrH()
	local control = parent:Add("DButton")

	control:SetSize(w, h)
	control:SetText("")
	control.knob = row.get() == "1" and 1 or 0
	control.Paint = function(self, cw, ch)
		local on = tobool(row.get())

		self.knob = Lerp(math.Clamp(FrameTime() * 12, 0, 1), self.knob, on and 1 or 0)

		local tw, th = math.Round(ch * 0.95), math.Round(ch * 0.5)
		local tx, ty = cw - tw, (ch - th) / 2

		draw.RoundedBox(th / 2, tx, ty, tw, th, Color(255, 255, 255, 18 + 26 * self.knob))
		draw.RoundedBox(th / 2, tx + (tw - th) * self.knob, ty, th, th, on and GOOD or U.color.dim)
		draw.SimpleText(on and "Вкл" or "Выкл", "nwInvSmall", tx - sh * 0.01, ch / 2, on and U.color.text or MUTED,
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	control.DoClick = function()
		row.set(tobool(row.get()) and "0" or "1")
		U.Tick()
	end

	return control
end

local function Slider(parent, row, w, h)
	local sh = ScrH()
	local control = parent:Add("DButton")
	local valueW = math.Round(sh * 0.05)

	control:SetSize(w, h)
	control:SetText("")

	local function Fraction()
		local value = tonumber(row.get()) or row.min

		return math.Clamp((value - row.min) / (row.max - row.min), 0, 1), value
	end

	local function Format(value)
		return row.decimals and string.format("%." .. row.decimals .. "f", value) or tostring(math.Round(value))
	end

	control.Paint = function(self, cw, ch)
		local fraction, value = Fraction()

		if (self.dragging) then
			fraction, value = self.dragFraction, self.dragValue
		end

		local tx, tw = 0, cw - valueW
		local th = math.max(3, math.Round(sh * 0.004))
		local ty = (ch - th) / 2
		local knob = math.Round(ch * 0.42)

		draw.RoundedBox(th / 2, tx, ty, tw, th, Color(255, 255, 255, 20))
		draw.RoundedBox(th / 2, tx, ty, tw * fraction, th, ColorAlpha(U.color.text, 200))
		draw.RoundedBox(knob / 2, tx + (tw - knob) * fraction, (ch - knob) / 2, knob, knob,
			(self:IsHovered() or self.dragging) and U.color.text or Color(200, 204, 210))
		draw.SimpleText(Format(value), "nwInvSmall", cw, ch / 2, U.color.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	control.OnMousePressed = function(self, code)
		if (code == MOUSE_LEFT) then
			self.dragging = true
			self:MouseCapture(true)
		end
	end
	control.Think = function(self)
		if (!self.dragging) then
			return
		end

		local mx = self:ScreenToLocal(input.GetCursorPos(), 0)
		local fraction = math.Clamp(mx / (self:GetWide() - valueW), 0, 1)
		local value = row.min + (row.max - row.min) * fraction

		value = row.decimals and math.Round(value, row.decimals) or math.Round(value)
		self.dragFraction = (value - row.min) / (row.max - row.min)
		self.dragValue = value

		if (row.live) then
			row.set(tostring(value))
		end

		if (!input.IsMouseDown(MOUSE_LEFT)) then
			self.dragging = false
			self:MouseCapture(false)
			row.set(tostring(value))
			U.Tick()
		end
	end

	return control
end

-- a few fixed values: a click goes to the next one (row.options = {{value, label}, ...})
local function Choice(parent, row, w, h)
	local button = parent:Add("DButton")

	button:SetSize(w, h)
	button:SetText("")
	button.Paint = function(self, bw, bh)
		local current = row.get()
		local label = current

		for _, option in ipairs(row.options) do
			if (option[1] == current) then
				label = option[2]
			end
		end

		draw.RoundedBox(6, 0, 0, bw, bh, Color(255, 255, 255, self:IsHovered() and 22 or 12))
		draw.SimpleText("‹", "nwInvSmall", bh * 0.4, bh / 2, MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("›", "nwInvSmall", bw - bh * 0.4, bh / 2, MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(label, "nwInvSmall", bw / 2, bh / 2, U.color.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	button.DoClick = function()
		local current, index = row.get(), 0

		for i, option in ipairs(row.options) do
			if (option[1] == current) then
				index = i
			end
		end

		row.set(row.options[index % #row.options + 1][1])
		U.Tick()
	end

	return button
end

local function TextField(parent, row, w, h)
	local entry = parent:Add("DTextEntry")

	entry:SetSize(w, h)
	entry:SetFont("nwInvSmall")
	entry:SetPaintBackground(false)
	entry:SetText(row.get() or "")
	entry:SetUpdateOnType(false)
	entry.Paint = function(self, ew, eh)
		draw.RoundedBox(6, 0, 0, ew, eh, Color(255, 255, 255, self:HasFocus() and 20 or 10))
		self:DrawTextEntryText(U.color.text, Color(64, 190, 240, 90), U.color.text)
	end
	entry.OnEnter = function(self)
		row.set(self:GetValue())
		U.Tick()
	end
	entry.OnLoseFocus = function(self)
		row.set(self:GetValue())
	end
	entry.Think = function(self)
		if (!self:HasFocus() and self:GetValue() != (row.get() or "")) then
			self:SetText(row.get() or "")
		end
	end

	return entry
end

local function GroupPage(parent, title, icon, subtitle, groups)
	local sw, sh = ScrW(), ScrH()
	local page = parent:Add("EditablePanel")

	page:SetSize(sw, sh)
	page.baseX, page.baseY = 0, 0

	local M = math.Round(sh * 0.06)
	local top = math.Round(sh * 0.24)
	local colW = math.Round(sh * 0.44)
	local gap = math.Round(sh * 0.026)
	local columns = math.Clamp(math.floor((sw - M * 2 + gap) / (colW + gap)), 1, 3)
	local x0 = math.Round((sw - (columns * colW + (columns - 1) * gap)) / 2)
	local rowH = math.Round(sh * 0.05)
	local pad = math.Round(sh * 0.016)
	local heights = {}

	for i = 1, columns do
		heights[i] = top
	end

	page.Paint = function(self, w, h)
		local is = math.Round(sh * 0.04)

		U.DrawIcon(icon, x0, sh * 0.13, is, U.color.text)
		draw.SimpleText(U.Upper(title), "nwInvTitle", x0 + is + sh * 0.014, sh * 0.13 + is / 2, U.color.text,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(subtitle, "nwInvText", x0, sh * 0.13 + is + sh * 0.018, MUTED, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	for _, group in ipairs(groups) do
		-- into the shortest column
		local column = 1

		for i = 2, columns do
			if (heights[i] < heights[column]) then
				column = i
			end
		end

		local height = pad * 2 + #group.rows * rowH
		local card, capH = Card(page, x0 + (column - 1) * (colW + gap), heights[column], colW, height, U.Upper(group.name))

		heights[column] = heights[column] + height + capH + gap

		for index, row in ipairs(group.rows) do
			local y = capH + pad + (index - 1) * rowH
			local label = card:Add("DLabel")

			label:SetPos(pad, y)
			label:SetSize(colW * 0.5, rowH)
			label:SetFont("nwInvText")
			label:SetTextColor(U.color.text)
			label:SetText(row.label)

			local cw = math.Round(colW * 0.42)
			local ch = math.Round(rowH * 0.7)
			local control

			if (row.type == "toggle") then
				control = Switch(card, row, cw, ch)
			elseif (row.type == "slider") then
				control = Slider(card, row, cw, ch)
			elseif (row.type == "choice") then
				control = Choice(card, row, cw, ch)
			else
				control = TextField(card, row, cw, ch)
			end

			control:SetPos(colW - pad - cw, y + (rowH - ch) / 2)

			if (index > 1) then
				local line = card:Add("DPanel")

				line:SetPos(pad, y)
				line:SetSize(colW - pad * 2, 1)
				line.Paint = function(_, lw, lh)
					surface.SetDrawColor(255, 255, 255, 12)
					surface.DrawRect(0, 0, lw, lh)
				end
			end
		end
	end

	return page
end

-- client convars
local function Client(convar, label, kind, extra)
	local row = {label = label, type = kind}

	for k, v in pairs(extra or {}) do
		row[k] = v
	end

	row.get = function()
		local cv = GetConVar(convar)

		return cv and cv:GetString() or "0"
	end
	row.set = function(value)
		RunConsoleCommand(convar, value)
	end

	return row
end

local SETTINGS = {
	{name = "Камера", rows = {
		Client("nw_thirdperson", "Вид от третьего лица (F3)", "toggle"),
		Client("nw_tp_distance", "Расстояние камеры", "slider", {min = 30, max = 160, live = true}),
		Client("nw_tp_right", "Смещение вбок", "slider", {min = -40, max = 40, live = true}),
		Client("nw_tp_up", "Смещение вверх", "slider", {min = -10, max = 20, live = true}),
		Client("nw_tp_hud", "Интерфейс от третьего лица", "toggle"),
		Client("nw_dyncam", "Динамичная камера", "toggle"),
		Client("nw_dyncam_scale", "Сила динамичной камеры", "slider", {min = 0, max = 2, decimals = 1, live = true}),
		Client("nw_legs", "Ноги от первого лица", "toggle"),
		Client("nw_legs_vehicle", "Ноги в транспорте", "toggle")
	}},
	{name = "Изображение", rows = {
		Client("nw_postfx", "Яркая и насыщенная картинка", "toggle"),
		Client("nw_vignette", "Виньетка по краям экрана", "toggle"),
		Client("nw_watermark", "Логотип в углу экрана", "toggle")
	}},
	{name = "Звук", rows = {
		Client("nw_music", "Музыка", "toggle"),
		Client("nw_music_volume", "Громкость музыки", "slider", {min = 0, max = 1, decimals = 2, live = true})
	}},
	{name = "Интерфейс", rows = {
		Client("nw_stamina_always", "Стамина всегда на экране", "toggle"),
		Client("nw_crosshair", "Динамичный прицел", "toggle"),
		Client("nw_status_icons", "Иконки статуса", "toggle"),
		Client("nw_status_side", "Иконки статуса: сторона", "choice", {options = {{"right", "Справа"}, {"left", "Слева"}}}),
		Client("nw_unit_panel", "Карточка юнита при наведении", "toggle"),
		Client("nw_intro", "Интро при заходе", "toggle")
	}}
}

-- server convars (values come from the server)
INV.serverConfig = INV.serverConfig or {}

net.Receive("nwConfig", function()
	INV.serverConfig = util.JSONToTable(net.ReadString() or "") or {}
end)

local function ConfigGroups()
	local groups = {}

	for _, group in ipairs(NW.config.groups) do
		local rows = {}

		for _, def in ipairs(group.rows) do
			local row = table.Copy(def)

			row.get = function()
				return INV.serverConfig[def.convar] or ""
			end
			row.set = function(value)
				INV.serverConfig[def.convar] = value

				net.Start("nwConfigSet")
					net.WriteString(def.convar)
					net.WriteString(value)
				net.SendToServer()
			end

			rows[#rows + 1] = row
		end

		groups[#groups + 1] = {name = group.name, rows = rows}
	end

	return groups
end

local PAGES = {}

PAGES.inventory = InventoryPage

PAGES.settings = function(parent)
	return GroupPage(parent, "Настройки", "settings", "Личные настройки. Сохраняются сразу.", SETTINGS)
end

PAGES.authors = function(parent)
	return TextPage(parent, "Авторы", "authors", {
		{text = "Network: Half-Life Roleplay", font = "nwInvName", color = U.color.text},
		"Фреймворк, модели и анимации сервера Network.",
		"",
		{text = "Сторонние ресурсы", font = "nwInvButton", color = U.color.text},
		"Шрифты Jura, Exo 2 (и Italic), Montserrat, Oswald — SIL Open Font License.",
		"Иконки интерфейса — Tabler Icons (MIT).",
		"Иконки предметов — game-icons.net (Lorc, Delapouite и др.), CC BY 3.0.",
		"Звуки инвентаря — Kenney «RPG Audio» (CC0) и звуки сервера.",
		"Звуки интерфейса — uisfx (CC0) и звуки сервера.",
		"Звуки еды и питья — глотки: VoxeLibre (CC0); жевание: BlockMen, мод «hunger» (CC BY 3.0).",
		"Ноги от первого лица — плагин Legs: Valkyrie & blackops7799 (public domain).",
		"Двери — по образцу плагина Doors из Helix (Chessnut, MIT).",
		"Гражданский терминал — по образцу ix_civic_terminal (Helix).",
		"Музыка — материалы сервера."
	})
end

PAGES.config = function(parent)
	net.Start("nwConfig")
	net.SendToServer()

	return GroupPage(parent, "Конфигурация", "config", "Настройки сервера (только для суперадминов). " ..
		"Меняются сразу для всех.", ConfigGroups())
end

function INV.ShowPage(id)
	if (!IsValid(INV.frame)) then
		return
	end

	if (IsValid(INV.pagePanel)) then
		INV.pagePanel:Remove()
	end

	INV.slots = {}

	-- pages of other files (Состояние: cl_status.lua)
	INV.extraPages = INV.extraPages or {}

	local builder = PAGES[id] or INV.extraPages[id]

	INV.page = builder and id or "inventory"
	INV.pagePanel = (builder or PAGES.inventory)(INV.frame)
	INV.pagePanel.shown = 0
end

-- ------------------------------------------------------------ the buttons --
-- the top bar: faction icon, name and faction on the left; on the right a row of buttons
-- (Инвентарь, Настройки, Авторы, Конфигурация for admins) and the cross; the name of a button
-- shows under it on hover
local function Buttons(frame)
	local sw, sh = ScrW(), ScrH()
	local size = math.Round(sh * 0.052)
	local gap = math.Round(sh * 0.01)
	local M = math.Round(sh * 0.034)
	local list = {
		{id = "inventory", name = "Инвентарь", icon = "inventory"},
		{id = "status", name = "Меню состояния", icon = "status"},
		{id = "settings", name = "Настройки", icon = "settings"},
		{id = "authors", name = "Авторы", icon = "authors"}
	}

	if (LocalPlayer():IsAdmin()) then
		list[#list + 1] = {id = "config", name = "Конфигурация", icon = "config"}
	end

	list[#list + 1] = {id = "close", name = "Закрыть", icon = "close", separate = true}

	local width = #list * size + (#list - 1) * gap + gap * 2
	local holder = frame:Add("EditablePanel")

	holder:SetZPos(5)
	holder:SetSize(width, size)
	holder:SetPos(sw - M - width, M)

	local x = 0

	for _, info in ipairs(list) do
		if (info.separate) then
			x = x + gap * 2
		end

		local button = holder:Add("DButton")

		button:SetPos(x, 0)
		button:SetSize(size, size)
		button:SetText("")
		button.hover = 0
		button.Paint = function(self, w, h)
			local active = INV.page == info.id

			self.hover = Lerp(math.Clamp(FrameTime() * 14, 0, 1), self.hover, self:IsHovered() and 1 or 0)

			U.Slice(U.Material(TIP), 0, 0, w, h, 8, 255, 255, 255, 235)

			if (self.hover > 0.01 or active) then
				U.Slice(U.Material(OUTLINE), 0, 0, w, h, 8, 255, 255, 255, active and 80 or 44 * self.hover)
			end

			local s = math.Round(w * 0.46)
			local color

			if (info.id == "close") then
				color = self:IsHovered() and BAD or U.color.dim
			else
				color = (active or self:IsHovered()) and U.color.text or U.color.dim
			end

			U.DrawIcon(info.icon, (w - s) / 2, (h - s) / 2, s, color)

			if (active) then
				surface.SetDrawColor(255, 255, 255, 210)
				surface.DrawRect(w * 0.32, h - 4, w * 0.36, 2)
			end

			if (self:IsHovered()) then
				INV.hoverButton = {text = info.name, panel = self}
			end
		end
		button.OnCursorEntered = function()
			surface.PlaySound("network2/ui/hover.wav")
		end
		button.DoClick = function()
			if (info.id == "close") then
				INV.Close()
			elseif (INV.page != info.id) then
				U.Tick()
				INV.ShowPage(info.id)
			end
		end

		x = x + size + gap
	end

	-- the character in the top bar
	local name = frame:Add("EditablePanel")

	name:SetZPos(5)
	name:SetMouseInputEnabled(false)
	name:SetPos(M, M)
	name:SetSize(math.Round(sw * 0.4), size)
	name.Paint = function(self, w, h)
		local client = LocalPlayer()
		local faction = NW.char.factions[client:GetFaction() or ""]
		local is = h

		if (faction) then
			surface.SetMaterial(U.Material("network2/factions/" .. faction.logo .. ".png"))
			surface.SetDrawColor(255, 255, 255, 235)
			surface.DrawTexturedRect(0, 0, is, is)
		end

		local tx = is + math.Round(sh * 0.014)

		draw.SimpleText(client:Nick(), "nwInvName", tx, h * 0.34, U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(faction and faction.name or "", "nwInvText", tx, h * 0.8, faction and faction.color or MUTED,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	return holder
end

-- ----------------------------------------------------------------- frame --
-- a curved dashed line from the cell the item came from to the cursor, running towards it
local function DrawTether(x1, y1, x2, y2, color, alpha)
	local dx, dy = x2 - x1, y2 - y1
	local cx1, cy1 = x1 + dx * 0.25, y1 + dy * 0.25 - math.abs(dx) * 0.18 - 30
	local cx2, cy2 = x1 + dx * 0.75, y1 + dy * 0.75 - math.abs(dx) * 0.12 - 20

	local function Point(t)
		local u = 1 - t

		return u * u * u * x1 + 3 * u * u * t * cx1 + 3 * u * t * t * cx2 + t * t * t * x2,
			u * u * u * y1 + 3 * u * u * t * cy1 + 3 * u * t * t * cy2 + t * t * t * y2
	end

	local steps = 72
	local offset = (RealTime() * 1.8) % 1
	local px, py = Point(0)

	for i = 1, steps do
		local t = i / steps
		local x, y = Point(t)

		if (((i / 3) - offset * 2) % 2 < 1.15) then
			local a = alpha * (0.3 + 0.7 * t)

			surface.SetDrawColor(color.r, color.g, color.b, 255 * a)
			surface.DrawLine(px, py, x, y)
			surface.DrawLine(px + 1, py, x + 1, y)
			surface.DrawLine(px, py + 1, x, y + 1)
		end

		px, py = x, y
	end

	-- a dot where it starts
	draw.RoundedBox(4, x1 - 4, y1 - 4, 8, 8, Color(color.r, color.g, color.b, 200 * alpha))
end

function INV.IsOpen()
	return IsValid(INV.frame) and INV.frame.target == 1
end

local function Build()
	local sw, sh = ScrW(), ScrH()
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(sw, sh)
	frame:SetPos(0, 0)
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	frame.appear = 0
	frame.target = 1
	frame.eased = 0

	-- the grey-dark backdrop: blurred game, grey veil, vignette
	frame.Paint = function(self, w, h)
		U.Blur(0, 0, w, h, 4, 255 * self.eased, nil, 1)
		surface.SetDrawColor(22, 24, 27, 232 * self.eased)
		surface.DrawRect(0, 0, w, h)
		surface.SetMaterial(SHADE)
		surface.SetDrawColor(255, 255, 255, 255 * self.eased)
		surface.DrawTexturedRect(0, 0, w, h)
	end

	-- the drag line and the button names: above the cells, under the dragged item
	local layer = frame:Add("EditablePanel")

	layer:SetSize(sw, sh)
	layer:SetZPos(20)
	layer:SetMouseInputEnabled(false)
	layer.Paint = function(self, w, h)
		local hovered = INV.hoverButton

		if (hovered and IsValid(hovered.panel)) then
			local bx, by = hovered.panel:LocalToScreen(hovered.panel:GetWide() / 2, hovered.panel:GetTall())

			draw.SimpleText(hovered.text, "nwInvSmall", bx, by + sh * 0.006, U.color.text, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_TOP)
		end

		INV.hoverButton = nil

		local drag = INV.drag

		if (drag and IsValid(drag.panel)) then
			local mx, my = input.GetCursorPos()
			local sx, sy = drag.panel:LocalToScreen(drag.panel:GetWide() / 2, drag.panel:GetTall() / 2)
			local outside = !INV.SlotAt(mx, my) and !INV.OverMenu(mx, my)

			DrawTether(sx, sy, mx, my, outside and AMBER or Color(220, 228, 236), outside and 0.95 or 0.6)

			if (outside) then
				local is = math.Round(sh * 0.022)
				local S = math.Round(sh * 0.096)

				U.DrawIcon("drop", mx + S / 2 + 8, my - is / 2, is, AMBER)
				draw.SimpleText("Выбросить", "nwInvSmall", mx + S / 2 + 14 + is, my, AMBER, TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)
			end
		end
	end

	-- the dragged item under the cursor
	local ghost = frame:Add("EditablePanel")
	local GS = math.Round(sh * 0.096)

	ghost:SetSize(GS, GS)
	ghost:SetZPos(30)
	ghost:SetMouseInputEnabled(false)
	ghost:SetVisible(false)
	ghost.Paint = function(self, w, h)
		U.Slice(U.Material(CELL), 0, 0, w, h, 6, 255, 255, 255, 220)
		U.Slice(U.Material(OUTLINE), 0, 0, w, h, 6, 255, 255, 255, 70)
	end

	local ghostView = ItemView(ghost)

	ghostView:SetPos(6, 6)
	ghostView:SetSize(GS - 12, GS - 12)

	local tip = Tooltip(frame)

	frame.Think = function(self)
		self.appear = math.Approach(self.appear, self.target, FrameTime() / (self.target == 1 and 0.28 or 0.22))
		self.eased = Ease(self.appear)
		self:SetAlpha(255 * self.eased)

		-- the page slides in a little
		local page = INV.pagePanel

		if (IsValid(page) and page.baseX) then
			page.shown = math.Approach(page.shown or 0, 1, FrameTime() / 0.32)

			local e = Ease(page.shown) * self.eased

			page:SetPos(math.Round(page.baseX), math.Round(page.baseY + (1 - e) * sh * 0.025))
		end

		if (self.target == 0) then
			ghost:SetVisible(false)
			tip:SetVisible(false)

			if (self.appear <= 0) then
				self:Remove()
			end

			return
		end

		local client = LocalPlayer()

		if (!client:Alive() or client:GetCharacterID() == 0 or (NW.menu and NW.menu.active)) then
			INV.Close()

			return
		end

		-- a press becomes a drag once the mouse moves a little
		local mx, my = input.GetCursorPos()
		local press = INV.press

		if (press and !INV.drag and !press.held and (math.abs(mx - press.x) + math.abs(my - press.y)) > 5 and
			INV.Cell(press.ref)) then
			INV.drag = {ref = press.ref, panel = press.panel}
			Sound("lift")
		end

		-- holding the mouse on a closed package unpacks it
		if (press and !INV.drag and !press.held) then
			local cell = INV.Cell(press.ref)
			local item = cell and I.Get(cell.id)

			if (item and item.contents and !(cell.data and cell.data.open) and
				RealTime() - press.time >= INV.holdTime) then
				press.held = true
				INV.OpenPack(press.ref, false)
			end
		end

		local drag = INV.drag

		if (drag) then
			INV.dropTarget = INV.SlotAt(mx, my)

			local cell = INV.Cell(drag.ref)

			ghostView:SetItem(cell and I.Get(cell.id))
			ghost:SetPos(mx - GS / 2, my - GS / 2)
			ghost:SetVisible(true)

			if (!input.IsMouseDown(MOUSE_LEFT)) then
				INV.Release()
			end
		else
			ghost:SetVisible(false)
		end

		-- the tooltip of the hovered item (set by the cells while painting)
		local ref = !INV.drag and !(IsValid(INV.openMenu) and INV.openMenu:IsVisible()) and INV.lastHoverRef
		local cell = ref and INV.Cell(ref)
		local item = cell and I.Get(cell.id)

		if (item) then
			if (INV.tipRef != ref) then
				INV.tipRef = ref
				INV.tipTime = RealTime()
			end

			tip:SetItem(item, cell.data)

			local tw, th = tip:GetSize()
			local tx, ty = mx + 20, my + 20

			if (tx + tw > sw - 8) then
				tx = mx - tw - 14
			end

			if (ty + th > sh - 8) then
				ty = sh - th - 8
			end

			tip:SetPos(tx, ty)
			tip:SetAlpha(255 * math.Clamp((RealTime() - INV.tipTime - 0.08) * 8, 0, 1))
			tip:SetVisible(true)
		else
			INV.tipRef = nil
			tip:SetVisible(false)
			tip:SetItem(nil)
		end
	end

	-- what the cells reported while painting this frame
	frame.PaintOver = function()
		INV.lastHoverRef = INV.hoverRef
		INV.hoverRef = nil
	end

	INV.frame = frame
	INV.buttons = Buttons(frame)
	INV.ShowPage(INV.page)
end

-- a storage window is open (a container, a body, a search): no Q menu over it
local function StorageOpen()
	return NW.storageUI and NW.storageUI.IsOpen and NW.storageUI.IsOpen()
end

function INV.Open()
	-- unconscious: nothing to open (cl_body.lua)
	if ((NW.Incapable and NW.Incapable(LocalPlayer())) or StorageOpen()) then
		return
	end

	if (INV.IsOpen()) then
		return
	end

	local client = LocalPlayer()

	if (!client:Alive() or client:GetCharacterID() == 0 or (NW.menu and NW.menu.active)) then
		return
	end

	if (IsValid(INV.frame)) then
		-- caught while closing: open again
		INV.frame.target = 1
		INV.frame:SetMouseInputEnabled(true)
		INV.frame:MakePopup()
		INV.frame:SetKeyboardInputEnabled(false)
	else
		INV.yaw = client:EyeAngles().y
		Build()
	end

	Sound("open")
end

function INV.Close()
	if (!INV.IsOpen()) then
		return
	end

	INV.frame.target = 0
	INV.frame:SetMouseInputEnabled(false)
	INV.drag = nil
	INV.press = nil
	INV.dropTarget = nil
	CloseDermaMenus()
	Sound("close")
end

function INV.Toggle()
	if (INV.IsOpen()) then
		INV.Close()
	else
		INV.Open()
	end
end

-- the world camera stays where it is while the menu is open (the character is shown in the
-- menu itself); cl_thirdperson.lua asks this
function INV.CameraWeight()
	return 0
end

-- standing still while the menu is open
hook.Add("CreateMove", "nwInventory", function(command)
	if (INV.IsOpen()) then
		command:ClearMovement()
		command:RemoveKey(IN_JUMP)
		command:RemoveKey(IN_ATTACK)
		command:RemoveKey(IN_ATTACK2)
	end
end)

-- ESC closes it instead of opening the game menu
-- (ESC: cl_pausemenu.lua closes the inventory first)

-- ---------------------------------------------------------------------- Q --
-- a short press opens / closes the inventory; admins holding Q get the spawn menu
local HOLD = 0.25

-- the key of the engine's spawn menu bind (+menu, Q by default)
local function MenuKey()
	local name = input.LookupBinding("+menu", true)

	return name and input.GetKeyCode(name) or KEY_Q
end

local function SameKey()
	return NW.keys.Get("inventory") == MenuKey()
end

-- the inventory key is not the spawn menu key: it works on its own
hook.Add("NWKey", "nwInventory", function(id)
	if (id == "inventory" and !SameKey()) then
		INV.Toggle()
	end
end)

function GM:OnSpawnMenuOpen()
	if (StorageOpen()) then
		return
	end

	-- another key opens the inventory: Q is the spawn menu (admins only)
	if (!SameKey()) then
		if (LocalPlayer():IsAdmin()) then
			INV.spawnMenu = true
			self.BaseClass.OnSpawnMenuOpen(self)
		end

		return
	end

	INV.qDown = true

	if (LocalPlayer():IsAdmin()) then
		timer.Create("nwQHold", HOLD, 1, function()
			if (INV.qDown) then
				INV.spawnMenu = true
				INV.Close()
				self.BaseClass.OnSpawnMenuOpen(self)
			end
		end)
	else
		INV.Toggle()
	end
end

function GM:OnSpawnMenuClose()
	local wasDown = INV.qDown

	INV.qDown = nil

	if (INV.spawnMenu) then
		INV.spawnMenu = nil
		self.BaseClass.OnSpawnMenuClose(self)
	elseif (wasDown and LocalPlayer():IsAdmin() and SameKey()) then
		timer.Remove("nwQHold")
		INV.Toggle()
	end
end

-- ------------------------------------------------------------- take panel --
-- E on an item in the world: its name and "Взять"
function INV.OpenTake(entity)
	if (IsValid(INV.take) or !IsValid(entity) or INV.IsOpen()) then
		return
	end

	local item = entity:GetItem()

	if (!item) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local cat = I.categories[item.category] or I.categories.misc
	local w, h = math.Round(sh * 0.34), math.Round(sh * 0.085)

	-- the whole screen: a click outside closes it
	local back = vgui.Create("EditablePanel")

	back:SetSize(sw, sh)
	back:MakePopup()
	back.appear = 0
	back.target = 1
	back.Paint = function() end
	back.OnMousePressed = function(self)
		self.target = 0
	end
	back.OnKeyCodePressed = function(self, code)
		if (code == KEY_ESCAPE or code == KEY_E or code == KEY_TAB) then
			self.target = 0
		end
	end

	local panel = back:Add("EditablePanel")

	panel:SetSize(w, h)
	panel:SetPos((sw - w) / 2, sh * 0.6)
	panel.Paint = function(self, pw, ph)
		U.Blur(0, 0, pw, ph, 3, 255, self, 8)
		U.Slice(U.Material(TIP), 0, 0, pw, ph, 8)

		surface.SetDrawColor(cat.color.r, cat.color.g, cat.color.b, 220)
		surface.DrawRect(1, ph * 0.2, 2, ph * 0.6)

		local is = math.Round(ph * 0.76)
		local pad = math.Round(ph * 0.12)

		U.Slice(U.Material(CELL), pad, (ph - is) / 2, is, is, 6)

		draw.SimpleText(item.name, "nwInvTipName", pad * 2.4 + is, ph * 0.4, U.color.text, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
		draw.SimpleText(U.Upper(cat.name), "nwInvTipCat", pad * 2.4 + is, ph * 0.66, cat.color, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	-- the model of the item
	local view = ItemView(panel)
	local vs = math.Round(h * 0.76)

	view:SetPos(math.Round(h * 0.12) + 4, math.Round((h - vs) / 2) + 4)
	view:SetSize(vs - 8, vs - 8)
	view:SetItem(item)

	local button = panel:Add("DButton")
	local bw, bh = math.Round(w * 0.3), math.Round(h * 0.52)

	button:SetSize(bw, bh)
	button:SetPos(w - bw - (h - bh) / 2, (h - bh) / 2)
	button:SetText("")
	button.hover = 0
	button.Paint = function(self, pw, ph)
		self.hover = Lerp(math.Clamp(FrameTime() * 14, 0, 1), self.hover, self:IsHovered() and 1 or 0)

		U.Slice(U.Material(SLOT), 0, 0, pw, ph, 8, 255, 255, 255, 255)
		U.Slice(U.Material(OUTLINE), 0, 0, pw, ph, 8, GOOD.r, GOOD.g, GOOD.b, 50 + 120 * self.hover)

		local is = math.Round(ph * 0.5)

		surface.SetFont("nwInvButton")

		local tw = surface.GetTextSize("Взять")
		local x = (pw - is - 6 - tw) / 2

		U.DrawIcon("take", x, (ph - is) / 2, is, self:IsHovered() and GOOD or U.color.text)
		draw.SimpleText("Взять", "nwInvButton", x + is + 6, ph / 2, U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	button.OnCursorEntered = function()
		surface.PlaySound("network2/ui/hover.wav")
	end
	button.DoClick = function()
		net.Start("nwInvTake")
			net.WriteEntity(entity)
		net.SendToServer()

		back.target = 0
	end

	back.Think = function(self)
		self.appear = math.Approach(self.appear, self.target, FrameTime() / 0.18)
		self:SetAlpha(255 * Ease(self.appear))
		panel:SetPos((sw - w) / 2, math.Round(sh * 0.6 + (1 - Ease(self.appear)) * sh * 0.02))

		if (self.target == 1 and (!IsValid(entity) or !LocalPlayer():Alive() or
			entity:GetPos():DistToSqr(LocalPlayer():EyePos()) > 160 * 160)) then
			self.target = 0
		end

		if (self.target == 0 and self.appear <= 0) then
			self:Remove()
		end
	end

	INV.take = back
	U.Play("appear")
end

net.Receive("nwItemOpen", function()
	INV.OpenTake(net.ReadEntity())
end)

