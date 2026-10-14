-- The storage window (server: sv_storage.lua): a container, a body, a searched player. Two halves
-- over the blurred scene: on the left ИНВЕНТАРЬ (your grid), on the right the storage; a round
-- swap mark between them. Under each grid - the tokens: how many, a field and an arrow to move
-- them across (only where the storage keeps tokens).
-- Drag a thing from cell to cell (either side); double click or RMB - to the other side, into the
-- first free cell. Hover - the name and description. ESC / ✕ / walking away closes it.
-- Admins see "Настроить" on containers (cl_container_config below).

NW.storageUI = NW.storageUI or {}

local SU = NW.storageUI
local U = NW.ui
local I = NW.items
local INV = NW.inventory
local CELL = "network2/ui/inv_cell.png"
local OUTLINE = "network2/ui/outline.png"
local ACCENT = Color(232, 196, 72)
local MUTED = Color(124, 128, 134)
local GOOD = Color(150, 214, 138)
local BAD = Color(226, 104, 92)

local function Fonts()
	local h = ScrH()
	local function F(name, font, size, weight)
		surface.CreateFont(name, {font = font, size = math.max(11, math.Round(h * size)), weight = weight,
			extended = true, antialias = true})
	end

	F("nwStoreTitle", "Montserrat SemiBold", 0.034, 600)
	F("nwStoreHead", "Montserrat SemiBold", 0.02, 600)
	F("nwStoreSmall", "Montserrat Medium", 0.0135, 500)
	F("nwStoreText", "Exo 2", 0.0165, 500)
	F("nwStoreTipName", "Montserrat SemiBold", 0.018, 600)
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwStoreFonts", Fonts)

local function Ease(t)
	return 1 - (1 - t) ^ 3
end

-- ------------------------------------------------------------------ state --
SU.data = SU.data or {cells = {}, tokens = -1}

local function ParseCells(json)
	local cells = {}

	for _, entry in ipairs(util.JSONToTable(json or "") or {}) do
		local index = tonumber(entry[1])

		if (index and I.Get(entry[2])) then
			cells[index] = {id = entry[2], data = istable(entry[3]) and entry[3] or {}}
		end
	end

	return cells
end

-- a cell by ref: "g<n>" mine, "s<n>" the storage
local function Cell(ref)
	local side, index = string.match(ref or "", "^([gs])(%d+)$")

	index = tonumber(index)

	if (side == "g") then
		return INV.data.grid[index]
	elseif (side == "s") then
		return SU.data.cells[index]
	end
end

local function Send(fromRef, toRef)
	net.Start("nwStorageMove")
		net.WriteString(fromRef)
		net.WriteString(toRef)
	net.SendToServer()
end

function SU.IsOpen()
	return IsValid(SU.frame)
end

function SU.Close(bQuiet)
	if (IsValid(SU.frame) and !SU.frame.closing) then
		SU.frame.closing = true
		SU.frame:SetMouseInputEnabled(false)
		SU.frame:SetKeyboardInputEnabled(false)

		if (!bQuiet) then
			net.Start("nwStorageClose")
			net.SendToServer()
		end
	end
end

-- ------------------------------------------------------------------ cells --
local function MakeCell(parent, ref, size)
	local slot = parent:Add("DPanel")
	local inset = math.max(2, math.Round(size * 0.06))

	slot:SetSize(size, size)
	slot.ref = ref
	slot.hover = 0

	local view = INV.ItemView(slot)

	view:SetPos(inset, inset)
	view:SetSize(size - inset * 2, size - inset * 2)

	slot.Paint = function(self, w, h)
		local cell = Cell(self.ref)
		local item = cell and I.Get(cell.id)
		local drag = SU.drag
		local dragging = drag and drag.ref == self.ref

		self.hover = Lerp(math.Clamp(FrameTime() * 14, 0, 1), self.hover, self:IsHovered() and 1 or 0)
		view:SetItem(!dragging and item or nil)
		view.hovered = self:IsHovered() and !drag

		U.Slice(U.Material(CELL), 0, 0, w, h, 6, 255, 255, 255, dragging and 140 or 255)

		if (self.hover > 0.01) then
			U.Slice(U.Material(OUTLINE), 0, 0, w, h, 6, 255, 255, 255, 40 * self.hover)
		end

		if (drag and drag.over == self and drag.ref != self.ref) then
			U.Slice(U.Material(OUTLINE), 0, 0, w, h, 6, GOOD.r, GOOD.g, GOOD.b, 170)
		end

		if (item and !dragging) then
			local cat = I.categories[item.category] or I.categories.misc

			surface.SetDrawColor(cat.color.r, cat.color.g, cat.color.b, 200)
			surface.DrawRect(inset + 1, h - inset - 2, math.Round(w * 0.22), 2)

			if (self:IsHovered() and !drag) then
				SU.hoverItem = item
			end
		end
	end

	slot.OnMousePressed = function(self, code)
		if (!Cell(self.ref)) then
			return
		end

		local other = string.sub(self.ref, 1, 1) == "g" and "s0" or "g0"

		if (code == MOUSE_RIGHT) then
			Send(self.ref, other)

			return
		end

		if (code == MOUSE_LEFT) then
			-- a double click: to the other side
			if (self.lastClick and RealTime() - self.lastClick < 0.3) then
				self.lastClick = nil
				Send(self.ref, other)

				return
			end

			self.lastClick = RealTime()
			SU.drag = {ref = self.ref, item = I.Get(Cell(self.ref).id), panel = self}
			self:MouseCapture(true)
		end
	end

	slot.OnMouseReleased = function(self, code)
		if (code != MOUSE_LEFT or !SU.drag) then
			return
		end

		self:MouseCapture(false)

		local drag = SU.drag

		SU.drag = nil

		if (IsValid(drag.over) and drag.over.ref != drag.ref) then
			Send(drag.ref, drag.over.ref)
			surface.PlaySound("network2/inv/inv_move" .. math.random(1, 3) .. ".wav")
		end
	end

	return slot
end

-- ----------------------------------------------------------------- tokens --
local function TokenRow(parent, x, y, w, h, put)
	local row = parent:Add("EditablePanel")

	row:SetPos(x, y)
	row:SetSize(w, h)

	local entry = NW.widgets.Number(row, 0, 0, 16000000)
	local bw = h

	entry:SetPos(put and 0 or bw + 6, 0)
	entry:SetSize(w - bw - 6, h)
	entry:SetText("")
	entry.placeholder = "Сколько токенов"

	local button = NW.widgets.Button(row, put and "▶" or "◀", function()
		local amount = entry:GetNumber()

		if (amount > 0) then
			net.Start("nwStorageTokens")
				net.WriteBool(put)
				net.WriteUInt(amount, 24)
			net.SendToServer()
			entry:SetText("")
			surface.PlaySound("network2/ui/char/hls_ui_affirm.wav")
		end
	end, true)

	button:SetSize(bw, h)
	button:SetPos(put and w - bw or 0, 0)

	return row
end

-- ----------------------------------------------------------------- window --
local function Build()
	if (IsValid(SU.frame)) then
		SU.frame:Remove()
	end

	if (INV.IsOpen and INV.IsOpen()) then
		INV.Close()
	end

	local data = SU.data
	local sw, sh = ScrW(), ScrH()
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(sw, sh)
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	frame.appear = 0
	SU.frame = frame

	-- the cell size: both grids fit, never bigger than the inventory's
	local capacity = INV.Capacity()
	local myRows = math.ceil(capacity / I.columns)
	local maxCols = math.max(I.columns, data.cols)
	local maxRows = math.max(myRows, data.rows)
	local gap = math.Round(sh * 0.004)
	local size = math.floor(math.min(sh * 0.08, (sw * 0.4 - gap * maxCols) / maxCols,
		(sh * 0.62 - gap * maxRows) / maxRows))
	local halfW = sw / 2
	local top = math.Round(math.max(sh * 0.16, (sh - (maxRows * (size + gap))) / 2 - sh * 0.03))
	local tokenH = math.Round(sh * 0.038)

	local function Grid(cols, rows, prefix, count)
		local panel = frame:Add("EditablePanel")
		local gw, gh = cols * size + (cols - 1) * gap, rows * size + (rows - 1) * gap

		panel:SetSize(gw, gh)
		panel.cells = {}

		for index = 1, count do
			local col, row = (index - 1) % cols, math.floor((index - 1) / cols)
			local cell = MakeCell(panel, prefix .. index, size)

			cell:SetPos(col * (size + gap), row * (size + gap))
			panel.cells[#panel.cells + 1] = cell
		end

		return panel
	end

	local mine = Grid(I.columns, myRows, "g", capacity)
	local theirs = Grid(data.cols, data.rows, "s", data.cols * data.rows)
	local mx = math.Round(halfW / 2 - mine:GetWide() / 2)
	local tx = math.Round(halfW + halfW / 2 - theirs:GetWide() / 2)

	mine:SetPos(mx, top)
	theirs:SetPos(tx, top)
	frame.cellsAll = {}

	for _, cell in ipairs(mine.cells) do
		frame.cellsAll[#frame.cellsAll + 1] = cell
	end

	for _, cell in ipairs(theirs.cells) do
		frame.cellsAll[#frame.cellsAll + 1] = cell
	end

	-- the round button between the grids: LMB - everything from the storage into the inventory (or,
	-- when the storage is empty, the whole inventory into it), RMB - the whole inventory into it
	local swapR = math.Round(sh * 0.042)
	local swapY = top + math.max(mine:GetTall(), theirs:GetTall()) / 2
	local swap = frame:Add("DButton")

	swap:SetText("")
	swap:SetSize(swapR * 2, swapR * 2)
	swap:SetPos(sw / 2 - swapR, swapY - swapR)
	swap.Paint = nil
	swap.hover = 0

	local function StorageEmpty()
		return next(SU.data.cells or {}) == nil
	end

	local function All(put)
		net.Start("nwStorageAll")
			net.WriteBool(put)
		net.SendToServer()
		surface.PlaySound("network2/ui/click.wav")
		swap.pressed = RealTime()
	end

	swap.DoClick = function()
		All(StorageEmpty())
	end
	swap.DoRightClick = function()
		All(true)
	end
	swap.OnCursorEntered = function()
		surface.PlaySound("network2/ui/hover.wav")
	end
	swap.Think = function(self)
		self.hover = math.Approach(self.hover, self:IsHovered() and 1 or 0, FrameTime() * 8)
	end
	frame.swap = swap
	frame.swapHint = function()
		return StorageEmpty() and "ЛКМ — всё из инвентаря сюда" or "ЛКМ — забрать всё  ·  ПКМ — сложить всё сюда"
	end

	-- the tokens
	local myTokensY = top + mine:GetTall() + sh * 0.045

	TokenRow(frame, mx, myTokensY, mine:GetWide(), tokenH, true)

	local theirTokensY = top + theirs:GetTall() + sh * 0.045

	if (data.tokens >= 0) then
		TokenRow(frame, tx, theirTokensY, theirs:GetWide(), tokenH, false)
	end

	-- close
	local close = NW.widgets.Button(frame, "✕", function()
		SU.Close()
	end)

	close:SetSize(math.Round(sh * 0.045), math.Round(sh * 0.045))
	close:SetPos(sw - math.Round(sh * 0.065), math.Round(sh * 0.025))

	-- admins: the settings of a container
	if (data.config != "" and IsValid(data.entity)) then
		local settings = NW.widgets.Button(frame, "Настроить", function()
			SU.OpenConfig(data.entity, util.JSONToTable(data.config) or {})
		end, false, "settings")

		settings:SetSize(math.Round(sh * 0.17), math.Round(sh * 0.045))
		settings:SetPos(sw - math.Round(sh * 0.075) - math.Round(sh * 0.17), math.Round(sh * 0.025))
	end

	frame.Think = function(self)
		self.appear = math.Approach(self.appear, self.closing and 0 or 1, FrameTime() / 0.18)

		if (self.closing and self.appear <= 0) then
			self:Remove()

			return
		end

		-- what the dragged thing is over
		if (SU.drag) then
			local cx, cy = input.GetCursorPos()

			SU.drag.over = nil

			for _, cell in ipairs(self.cellsAll) do
				local x, y = cell:LocalToScreen(0, 0)

				if (cx >= x and cx < x + size and cy >= y and cy < y + size) then
					SU.drag.over = cell

					break
				end
			end
		end
	end

	frame.Paint = function(self, w, h)
		local e = Ease(self.appear)

		U.Blur(0, 0, w, h, 6 * e, 255 * e, self, 0)
		surface.SetDrawColor(10, 12, 16, 215 * e)
		surface.DrawRect(0, 0, w, h)

		-- the band on top with the title
		surface.SetDrawColor(6, 8, 10, 200 * e)
		surface.DrawRect(0, 0, w, sh * 0.09)
		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 160 * e)
		surface.DrawRect(w / 2 - sh * 0.04, sh * 0.09 - 2, sh * 0.08, 2)
		draw.SimpleText(data.title, "nwStoreTitle", w / 2, sh * 0.045, Color(236, 238, 242, 255 * e), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)

		-- the line between the halves and the swap mark
		surface.SetDrawColor(255, 255, 255, 14 * e)
		surface.DrawRect(w / 2, sh * 0.09, 1, h)

		local r = swapR
		local cy = swapY
		local hover = IsValid(self.swap) and self.swap.hover or 0
		local press = IsValid(self.swap) and self.swap.pressed and math.Clamp(1 - (RealTime() - self.swap.pressed) / 0.25, 0, 1) or 0
		local grow = r * (1 + hover * 0.08 - press * 0.06)

		draw.RoundedBox(grow, w / 2 - grow, cy - grow, grow * 2, grow * 2, Color(16, 18, 22, 240 * e))
		draw.RoundedBox(grow, w / 2 - grow, cy - grow, grow * 2, grow * 2,
			Color(ACCENT.r, ACCENT.g, ACCENT.b, (10 + hover * 40 + press * 80) * e))
		surface.DrawCircle(w / 2, cy, grow, ACCENT.r, ACCENT.g, ACCENT.b, (40 + hover * 180) * e)
		U.DrawIcon("swap", w / 2 - grow * 0.55, cy - grow * 0.55, grow * 1.1,
			hover > 0.5 and ACCENT or Color(230, 232, 236), e)

		if (hover > 0.01) then
			draw.SimpleText(self.swapHint(), "nwStoreSmall", w / 2, cy + grow + sh * 0.018,
				Color(236, 238, 242, 255 * e * hover), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end

		-- the captions over the grids
		local function Caption(x, icon, text, right)
			local is = math.Round(sh * 0.022)

			U.DrawIcon(icon, x, top - sh * 0.04, is, ACCENT, e)
			draw.SimpleText(U.Upper(text), "nwStoreHead", x + is + sh * 0.008, top - sh * 0.04 + is / 2,
				Color(236, 238, 242, 255 * e), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if (right) then
				draw.SimpleText(right, "nwStoreSmall", x + (x == mx and mine or theirs):GetWide(), top - sh * 0.04 + is / 2,
					Color(MUTED.r, MUTED.g, MUTED.b, 255 * e), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		local count = 0

		for index = 1, capacity do
			if (INV.data.grid[index]) then
				count = count + 1
			end
		end

		local used = 0

		for _ in pairs(data.cells) do
			used = used + 1
		end

		Caption(mx, "inventory", "Инвентарь", count .. " / " .. capacity)
		Caption(tx, data.icon, data.title, used .. " / " .. data.cols * data.rows)

		-- the tokens over their rows
		local function Tokens(x, y, amount, text)
			surface.SetFont("nwStoreSmall")

			local aw = surface.GetTextSize(amount)

			draw.SimpleText(amount, "nwStoreSmall", x, y - sh * 0.006, ColorAlpha(ACCENT, 255 * e), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_BOTTOM)
			draw.SimpleText(text, "nwStoreSmall", x + aw + sh * 0.006, y - sh * 0.006, Color(200, 204, 210, 255 * e),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		end

		Tokens(mx, myTokensY, tostring(LocalPlayer():GetNW2Int("nwTokens", 0)), "ТОКЕНОВ У ВАС")

		if (data.tokens >= 0) then
			Tokens(tx, theirTokensY, tostring(data.tokens), "ТОКЕНОВ ВНУТРИ")
		end

		draw.SimpleText("Перетаскивайте вещи между сетками  ·  двойной клик или ПКМ — на другую сторону  ·  " ..
			"кнопка в центре — всё сразу  ·  ESC — закрыть",
			"nwStoreSmall", w / 2, h - sh * 0.04, Color(MUTED.r, MUTED.g, MUTED.b, 255 * e), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)

		SU.hoverItem = nil
	end

	-- the dragged thing and the hint, over everything
	frame.PaintOver = function(self, w, h)
		local mxp, myp = input.GetCursorPos()

		if (SU.drag and SU.drag.item) then
			local s = size * 0.8

			surface.SetMaterial(U.Material("network2/items/" .. SU.drag.item.icon .. ".png"))
			surface.SetDrawColor(255, 255, 255, 230)
			surface.DrawTexturedRect(mxp - s / 2, myp - s / 2, s, s)

			return
		end

		local item = SU.hoverItem

		if (!item) then
			return
		end

		local pad = math.Round(sh * 0.012)
		local tw = math.Round(sh * 0.28)
		local lines = INV.WrapText(item.description or "", "nwStoreText", tw)
		local lh = math.Round(sh * 0.021)
		local th = pad * 2 + sh * 0.026 + #lines * lh
		local x = math.min(mxp + 18, w - tw - pad * 2 - 8)
		local y = math.min(myp + 18, h - th - 8)
		local cat = I.categories[item.category] or I.categories.misc

		draw.RoundedBox(6, x, y, tw + pad * 2, th, Color(12, 14, 17, 245))
		surface.SetDrawColor(cat.color)
		surface.DrawRect(x, y + 4, 3, th - 8)
		draw.SimpleText(item.name, "nwStoreTipName", x + pad, y + pad, U.color.text)

		for i, line in ipairs(lines) do
			draw.SimpleText(line, "nwStoreText", x + pad, y + pad + sh * 0.026 + (i - 1) * lh, Color(186, 192, 198))
		end
	end

	frame.OnMouseReleased = function()
		SU.drag = nil
	end

	U.Play("appear")
end

net.Receive("nwStorageOpen", function()
	SU.data = {
		title = net.ReadString(),
		icon = net.ReadString(),
		cols = net.ReadUInt(5),
		rows = net.ReadUInt(5),
		cells = ParseCells(net.ReadString()),
		tokens = net.ReadInt(32),
		entity = net.ReadEntity(),
		config = net.ReadString()
	}

	-- the inventory sync comes right after: build on the next frame
	timer.Simple(0, Build)
end)

net.Receive("nwStorageSync", function()
	SU.data.cells = ParseCells(net.ReadString())
	SU.data.tokens = net.ReadInt(32)
end)

net.Receive("nwStorageClose", function()
	SU.Close(true)
end)

hook.Add("NWEscape", "nwStorage", function()
	if (IsValid(SU.config)) then
		SU.config:Remove()

		return true
	end

	if (SU.IsOpen() and !SU.frame.closing) then
		SU.Close()

		return true
	end
end)

-- ----------------------------------------------------- container settings --
-- name, model, grid, how often the loot comes back, the loot table
function SU.OpenConfig(entity, config)
	local W = NW.widgets
	local sh = ScrH()
	local w, h = math.Round(sh * 0.95), math.Round(sh * 0.8)
	local frame, box = W.Window("Настройка контейнера", w, h)
	local pad = math.Round(sh * 0.02)
	local fh = math.Round(sh * 0.036)
	local y = box.top

	SU.config = frame

	W.Label(box, "Название", pad, y)

	local title = W.Entry(box, config.title or "Контейнер")

	title:SetPos(pad, y + sh * 0.018)
	title:SetSize(w * 0.42, fh)

	W.Label(box, "Модель", pad + w * 0.45, y)

	local model = W.Entry(box, config.model or "", "models/...mdl")

	model:SetPos(pad + w * 0.45, y + sh * 0.018)
	model:SetSize(w * 0.55 - pad * 2, fh)

	y = y + sh * 0.07

	local function NumberField(label, value, min, max, x, width)
		W.Label(box, label, x, y)

		local field = W.Number(box, value, min, max)

		field:SetPos(x, y + sh * 0.018)
		field:SetSize(width, fh)

		return field
	end

	local cols = NumberField("Колонки (1-10)", config.cols or 6, 1, 10, pad, w * 0.14)
	local rows = NumberField("Ряды (1-10)", config.rows or 4, 1, 10, pad + w * 0.16, w * 0.14)
	local refresh = NumberField("Лут обновляется, сек (0 — нет)", config.refresh or 0, 0, 86400, pad + w * 0.32,
		w * 0.25)

	y = y + sh * 0.075

	W.Label(box, "Лут: предмет, шанс %, сколько (от-до). При обновлении содержимое заменяется новым", pad, y)
	y = y + sh * 0.022

	local scroll = W.Scroll(box)

	scroll:SetPos(pad, y)
	scroll:SetSize(w - pad * 2, h - y - sh * 0.085)

	local rowsList = {}
	local choices = W.ItemChoices()

	local function AddRow(entry)
		local row = scroll:Add("EditablePanel")

		row:Dock(TOP)
		row:DockMargin(0, 0, 8, 6)
		row:SetTall(fh)

		local item = W.Combo(row, choices, entry.item)

		item:Dock(LEFT)
		item:SetWide(w * 0.46)

		local chance = W.Number(row, entry.chance or 50, 0, 100)

		chance:Dock(LEFT)
		chance:DockMargin(8, 0, 0, 0)
		chance:SetWide(w * 0.1)

		local min = W.Number(row, entry.min or 1, 1, 20)

		min:Dock(LEFT)
		min:DockMargin(8, 0, 0, 0)
		min:SetWide(w * 0.09)

		local max = W.Number(row, entry.max or 1, 1, 20)

		max:Dock(LEFT)
		max:DockMargin(8, 0, 0, 0)
		max:SetWide(w * 0.09)

		local remove = W.Button(row, "Убрать", function()
			row:Remove()

			for index, data in ipairs(rowsList) do
				if (data.row == row) then
					table.remove(rowsList, index)

					break
				end
			end
		end)

		remove:Dock(LEFT)
		remove:DockMargin(8, 0, 0, 0)
		remove:SetWide(w * 0.13)

		rowsList[#rowsList + 1] = {row = row, item = item, chance = chance, min = min, max = max}
	end

	for _, entry in ipairs(config.loot or {}) do
		AddRow(entry)
	end

	local function Collect()
		local loot = {}

		for _, data in ipairs(rowsList) do
			local id = data.item:GetSelectedValue()

			if (id and id != "") then
				loot[#loot + 1] = {item = id, chance = data.chance:GetNumber(), min = data.min:GetNumber(),
					max = math.max(data.min:GetNumber(), data.max:GetNumber())}
			end
		end

		return {title = title:GetValue(), model = model:GetValue(), cols = cols:GetNumber(), rows = rows:GetNumber(),
			refresh = refresh:GetNumber(), loot = loot}
	end

	local function Send(action)
		net.Start("nwContainerConfig")
			net.WriteEntity(entity)
			net.WriteString(action)
			net.WriteString(util.TableToJSON(Collect()))
		net.SendToServer()
	end

	local by = h - sh * 0.065
	local bw = math.Round(w * 0.2)

	local add = W.Button(box, "+ Предмет", function()
		AddRow({})
	end)

	add:SetPos(pad, by)
	add:SetSize(bw, fh)

	local fill = W.Button(box, "Заполнить сейчас", function()
		Send("fill")
	end)

	fill:SetPos(pad + bw + 8, by)
	fill:SetSize(bw, fh)

	local clear = W.Button(box, "Очистить", function()
		Send("clear")
	end)

	clear:SetPos(pad + (bw + 8) * 2, by)
	clear:SetSize(bw, fh)

	local save = W.Button(box, "Сохранить", function()
		Send("save")
		frame:Remove()
	end, true)

	save:SetPos(w - pad - bw, by)
	save:SetSize(bw, fh)
end
