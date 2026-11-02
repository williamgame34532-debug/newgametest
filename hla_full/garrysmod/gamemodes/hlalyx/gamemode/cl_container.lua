local L = HLA.Loot
local I = HLA.Items
local CU = {}
HLA.ContainerUI = CU

local BLUE = Color(110, 200, 255)
local BLUE_DIM = Color(60, 120, 160)
local WHITE = Color(232, 244, 252)
local GREY = Color(150, 178, 198)
local GLASS = Color(5, 13, 21, 238)
local CELL = Color(12, 26, 38, 230)

local function sc() return math.Clamp(math.min(ScrW() / 1920, ScrH() / 1080), 0.7, 2) end
local fontKey
local function fonts()
	local key = ScrW() .. 'x' .. ScrH()
	if fontKey == key then return end
	fontKey = key
	local s = sc()
	surface.CreateFont('hla_ct_title', {font = 'Tektur', size = math.floor(26 * s), weight = 600, italic = true, extended = true, antialias = true})
	surface.CreateFont('hla_ct_head', {font = 'Tektur', size = math.floor(17 * s), weight = 600, extended = true, antialias = true})
	surface.CreateFont('hla_ct_text', {font = 'Exo 2', size = math.floor(16 * s), weight = 600, extended = true, antialias = true})
	surface.CreateFont('hla_ct_small', {font = 'Exo 2', size = math.floor(13 * s), weight = 600, italic = true, extended = true, antialias = true})
	surface.CreateFont('hla_ct_count', {font = 'Tektur', size = math.floor(15 * s), weight = 600, extended = true, antialias = true})
end

local function btn(parent, text, fn)
	local b = vgui.Create('DButton', parent)
	b:SetText('')
	b.Paint = function(self, w, h)
		local hot = self:IsHovered()
		surface.SetDrawColor(hot and BLUE.r or 12, hot and BLUE.g or 26, hot and BLUE.b or 38, hot and 220 or 230)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, hot and 255 or 160)
		surface.DrawRect(0, 0, 3, h)
		draw.SimpleText(text, 'hla_ct_head', w / 2, h / 2, hot and Color(4, 14, 24) or WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	b.DoClick = function() surface.PlaySound('hla/ui/textline_end.wav') fn() end
	return b
end

local function cell(parent, size, onClick, onHover)
	local c = vgui.Create('DButton', parent)
	c:SetText('')
	c:SetSize(size, size)
	c.Paint = function(self, w, h)
		local hot = self:IsHovered()
		surface.SetDrawColor(CELL)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, hot and 230 or (self.id and 90 or 35))
		surface.DrawOutlinedRect(0, 0, w, h, hot and 2 or 1)
		if hot then onHover(self.id) end
	end
	c.PaintOver = function(self, w, h)
		if self.id and self.n and self.n > 1 then
			draw.SimpleText('×' .. self.n, 'hla_ct_count', w - 5, h - 3, WHITE, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end
	end
	c.DoClick = function(self) if self.id then onClick() end end
	c.icon = vgui.Create('ModelImage', c)
	c.icon:SetSize(size - 10, size - 10)
	c.icon:SetPos(5, 5)
	c.icon:SetMouseInputEnabled(false)
	c.icon:SetVisible(false)
	c.Set = function(self, id, n)
		self.n = n
		if self.id == id then return end
		self.id = id
		if id then
			self.icon:SetModel(I.Model(id))
			self.icon:SetVisible(true)
		else
			self.icon:SetVisible(false)
		end
	end
	return c
end

local function send(what, a)
	net.Start('hla_cont_do')
	net.WriteString(what)
	if a then net.WriteUInt(a, 5) end
	net.SendToServer()
end

function CU.Close(silent)
	if IsValid(CU.frame) then CU.frame:Remove() end
	CU.frame = nil
	if not silent then send('close') end
	CU.ent = nil
end

local function build()
	local f = CU.frame
	if not IsValid(f) then return end
	local s = sc()
	local size = math.floor(78 * s)
	local gap = math.floor(8 * s)
	if f.contSlots ~= CU.slots then
		f.cont:Clear()
		f.contCells = {}
		f.contSlots = CU.slots
		for i = 1, CU.slots do
			local c = cell(f.cont, size, function() send('take', i) end, function(id) f.hoverID = id end)
			c:SetPos(((i - 1) % 4) * (size + gap), math.floor((i - 1) / 4) * (size + gap))
			f.contCells[i] = c
		end
	end
	if not f.invCells then
		f.invCells = {}
		for i = 1, I.Slots do
			local c = cell(f.inv, size, function() send('put', i) end, function(hid) f.hoverID = hid end)
			c:SetPos(((i - 1) % 4) * (size + gap), math.floor((i - 1) / 4) * (size + gap))
			f.invCells[i] = c
		end
	end
	for i = 1, CU.slots do
		local it = CU.items[i]
		f.contCells[i]:Set(it and it.id, it and it.n)
	end
	local T = HLA.Tab
	for i = 1, I.Slots do
		f.invCells[i]:Set(T and T.inv[i], T and T.invN and T.invN[i])
	end
end

local function open()
	fonts()
	local s = sc()
	if IsValid(CU.frame) then build() return end
	local size, gap = math.floor(78 * s), math.floor(8 * s)
	local gridW = 4 * size + 3 * gap
	local pad = math.floor(28 * s)
	local W = gridW * 2 + pad * 3 + math.floor(40 * s)
	local H = math.floor(130 * s) + 4 * (size + gap) + math.floor(150 * s)
	local f = vgui.Create('EditablePanel')
	CU.frame = f
	f:SetSize(W, H)
	f:Center()
	f:MakePopup()
	f:SetKeyboardInputEnabled(true)
	f.born = RealTime()
	f.Paint = function(self, w, h)
		local k = math.Clamp((RealTime() - self.born) * 6, 0, 1)
		Derma_DrawBackgroundBlur(self, self.born - 0.3)
		surface.SetDrawColor(GLASS.r, GLASS.g, GLASS.b, GLASS.a * k)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 230 * k)
		surface.DrawRect(0, 0, w, math.max(2, math.floor(3 * s)))
		draw.SimpleText('<:: ' .. string.upper(CU.title or ''), 'hla_ct_title', pad, math.floor(22 * s), Color(BLUE.r, BLUE.g, BLUE.b, 255 * k))
		draw.SimpleText('ЛКМ ПО ПРЕДМЕТУ — ПЕРЕЛОЖИТЬ', 'hla_ct_small', w - pad, math.floor(30 * s), Color(GREY.r, GREY.g, GREY.b, 220 * k), TEXT_ALIGN_RIGHT)
		local hy = math.floor(80 * s)
		draw.SimpleText('КОНТЕЙНЕР', 'hla_ct_head', pad, hy, Color(WHITE.r, WHITE.g, WHITE.b, 230 * k))
		draw.SimpleText('ИНВЕНТАРЬ ЮНИТА', 'hla_ct_head', w - pad - gridW, hy, Color(WHITE.r, WHITE.g, WHITE.b, 230 * k))
		surface.SetDrawColor(BLUE_DIM.r, BLUE_DIM.g, BLUE_DIM.b, 160 * k)
		surface.DrawRect(pad, hy + math.floor(24 * s), gridW, 1)
		surface.DrawRect(w - pad - gridW, hy + math.floor(24 * s), gridW, 1)
		local ty = h - math.floor(118 * s)
		surface.SetDrawColor(BLUE_DIM.r, BLUE_DIM.g, BLUE_DIM.b, 120 * k)
		surface.DrawRect(pad, ty - math.floor(10 * s), w - pad * 2, 1)
		local d = self.hoverID and I.Get(self.hoverID)
		if d then
			draw.SimpleText(string.upper(d.name), 'hla_ct_head', pad, ty, Color(BLUE.r, BLUE.g, BLUE.b, 255 * k))
			draw.SimpleText(d.text or '', 'hla_ct_text', pad, ty + math.floor(24 * s), Color(GREY.r, GREY.g, GREY.b, 230 * k))
		else
			draw.SimpleText('НАВЕДИТЕ НА ПРЕДМЕТ', 'hla_ct_head', pad, ty, Color(GREY.r, GREY.g, GREY.b, 180 * k))
		end
		self.hoverID = nil
	end
	f.OnKeyCodePressed = function(self, code)
		if code == KEY_ESCAPE or code == KEY_E or code == KEY_TAB then CU.Close() end
	end
	f.Think = function(self)
		local e = CU.ent
		local p = LocalPlayer()
		if not IsValid(e) or not IsValid(p) or not p:Alive() or p:GetPos():DistToSqr(e:GetPos()) > 170 * 170 then CU.Close() end
	end
	local top = math.floor(118 * s)
	f.cont = vgui.Create('Panel', f)
	f.cont:SetPos(pad, top)
	f.cont:SetSize(gridW, 4 * (size + gap))
	f.inv = vgui.Create('Panel', f)
	f.inv:SetPos(W - pad - gridW, top)
	f.inv:SetSize(gridW, 4 * (size + gap))
	local bw, bh = math.floor(190 * s), math.floor(38 * s)
	local all = btn(f, 'ВЗЯТЬ ВСЁ', function() send('takeall') end)
	all:SetSize(bw, bh)
	all:SetPos(pad, H - bh - math.floor(18 * s))
	local close = btn(f, 'ЗАКРЫТЬ', function() CU.Close() end)
	close:SetSize(bw, bh)
	close:SetPos(W - pad - bw, H - bh - math.floor(18 * s))
	build()
end

net.Receive('hla_cont', function()
	if not net.ReadBool() then CU.Close(true) return end
	local e = net.ReadEntity()
	CU.ent = e
	CU.title = net.ReadString()
	CU.slots = net.ReadUInt(5)
	CU.items = {}
	for i = 1, CU.slots do
		local id, n = net.ReadString(), net.ReadUInt(8)
		if id ~= '' then CU.items[i] = {id = id, n = n} end
	end
	open()
end)

hook.Add('HLAInventoryChanged', 'HLAContainerUI', function()
	if IsValid(CU.frame) then build() end
end)

local function cfgFrame(title, w, h)
	fonts()
	local s = sc()
	local f = vgui.Create('DFrame')
	f:SetTitle('')
	f:SetSize(math.floor(w * s), math.floor(h * s))
	f:Center()
	f:MakePopup()
	f.Paint = function(self, pw, ph)
		surface.SetDrawColor(GLASS)
		surface.DrawRect(0, 0, pw, ph)
		surface.SetDrawColor(BLUE)
		surface.DrawRect(0, 0, pw, 2)
		draw.SimpleText(title, 'hla_ct_head', 12, 12, BLUE)
	end
	return f, s
end

local function label(parent, text)
	local l = vgui.Create('DLabel', parent)
	l:SetText(text)
	l:SetFont('hla_ct_text')
	l:SetTextColor(WHITE)
	l:SizeToContents()
	l:Dock(TOP)
	l:DockMargin(0, 6, 0, 2)
	return l
end

CU.tables = {}
net.Receive('hla_loot_tables', function()
	local len = net.ReadUInt(32)
	CU.tables = util.JSONToTable(util.Decompress(net.ReadData(len)) or '') or {}
	hook.Run('HLALootTables')
end)

function CU.OpenTables()
	local f, s = cfgFrame('ТАБЛИЦЫ ЛУТА', 900, 620)
	local tables = table.Copy(CU.tables)
	local sel
	local left = vgui.Create('DPanel', f)
	left:Dock(LEFT)
	left:SetWide(math.floor(240 * s))
	left:DockMargin(0, 14, 8, 0)
	left:SetPaintBackground(false)
	local lst = vgui.Create('DListView', left)
	lst:Dock(FILL)
	lst:AddColumn('ТАБЛИЦА')
	local right = vgui.Create('DScrollPanel', f)
	right:Dock(FILL)
	right:DockMargin(0, 14, 0, 0)
	local fill, form
	fill = function()
		lst:Clear()
		local names = table.GetKeys(tables)
		table.sort(names)
		for _, n in ipairs(names) do
			local line = lst:AddLine(n)
			line.name = n
			if n == sel then line:SetSelected(true) end
		end
	end
	local itemIDs = table.GetKeys(I.Defs)
	table.sort(itemIDs, function(a, b) return I.Defs[a].name < I.Defs[b].name end)
	form = function()
		right:Clear()
		local list = sel and tables[sel]
		if not list then label(right, 'Выберите таблицу слева или создайте новую.') return end
		label(right, 'ТАБЛИЦА «' .. sel .. '»: шанс выпадения %, количество от–до')
		for idx, e in ipairs(list) do
			local row = vgui.Create('DPanel', right)
			row:Dock(TOP)
			row:DockMargin(0, 4, 0, 0)
			row:SetTall(math.floor(30 * s))
			row:SetPaintBackground(false)
			local combo = vgui.Create('DComboBox', row)
			combo:Dock(LEFT)
			combo:SetWide(math.floor(250 * s))
			for _, id in ipairs(itemIDs) do combo:AddChoice(I.Defs[id].name, id, e.id == id) end
			combo.OnSelect = function(_, _, _, id) e.id = id end
			local function num(v, mn, mx, cb, lab)
				local l = vgui.Create('DLabel', row)
				l:SetText(lab) l:SetFont('hla_ct_small') l:SetTextColor(GREY) l:SizeToContents()
				l:Dock(LEFT) l:DockMargin(10, 0, 4, 0)
				local n = vgui.Create('DNumberWang', row)
				n:SetMinMax(mn, mx) n:SetDecimals(0) n:SetValue(v) n:SetWide(math.floor(60 * s))
				n:Dock(LEFT)
				n.OnValueChanged = function(_, x) cb(math.floor(tonumber(x) or mn)) end
			end
			num(e.chance or 50, 1, 100, function(x) e.chance = x end, 'ШАНС %')
			num(e.min or 1, 1, 99, function(x) e.min = x end, 'ОТ')
			num(e.max or 1, 1, 99, function(x) e.max = x end, 'ДО')
			local del = btn(row, 'УБРАТЬ', function() table.remove(list, idx) form() end)
			del:Dock(RIGHT)
			del:SetWide(math.floor(100 * s))
		end
		local add = btn(right, '+ ПРЕДМЕТ', function()
			list[#list + 1] = {id = itemIDs[1], chance = 50, min = 1, max = 1}
			form()
		end)
		add:Dock(TOP)
		add:DockMargin(0, 8, 0, 0)
		add:SetTall(math.floor(32 * s))
	end
	lst.OnRowSelected = function(_, _, line) sel = line.name form() end
	local bar = vgui.Create('DPanel', left)
	bar:Dock(BOTTOM)
	bar:SetTall(math.floor(76 * s))
	bar:SetPaintBackground(false)
	local nameEntry = vgui.Create('DTextEntry', bar)
	nameEntry:Dock(TOP)
	nameEntry:SetPlaceholderText('имя новой таблицы')
	local newB = btn(bar, '+ ТАБЛИЦА', function()
		local n = string.Trim(nameEntry:GetValue() or '')
		if n == '' or tables[n] then return end
		tables[n] = {}
		sel = n
		fill() form()
	end)
	newB:Dock(LEFT) newB:SetWide(math.floor(115 * s)) newB:DockMargin(0, 4, 4, 0)
	local delB = btn(bar, 'УДАЛИТЬ', function()
		if sel and sel ~= 'default' then tables[sel] = nil sel = nil fill() form() end
	end)
	delB:Dock(FILL) delB:DockMargin(0, 4, 0, 0)
	local save = btn(f, 'СОХРАНИТЬ ТАБЛИЦЫ', function()
		local data = util.Compress(util.TableToJSON(tables))
		net.Start('hla_loot_save') net.WriteUInt(#data, 32) net.WriteData(data, #data) net.SendToServer()
	end)
	save:Dock(BOTTOM)
	save:SetTall(math.floor(38 * s))
	save:DockMargin(0, 8, 0, 0)
	fill() form()
end

net.Receive('hla_cont_cfg', function()
	local e = net.ReadEntity()
	local cfg = util.JSONToTable(net.ReadString()) or {}
	if not IsValid(e) then return end
	local f, s = cfgFrame('КОНТЕЙНЕР', 520, 520)
	local body = vgui.Create('DPanel', f)
	body:Dock(FILL)
	body:DockMargin(0, 14, 0, 0)
	body:SetPaintBackground(false)
	label(body, 'НАЗВАНИЕ')
	local title = vgui.Create('DTextEntry', body)
	title:Dock(TOP) title:SetValue(cfg.title or '') title:SetUpdateOnType(true)
	title.OnValueChange = function(_, v) cfg.title = v end
	label(body, 'МОДЕЛЬ')
	local mdl = vgui.Create('DComboBox', body)
	mdl:Dock(TOP)
	for _, m in ipairs(L.Models) do mdl:AddChoice(m.label, m.model, cfg.model == m.model) end
	mdl.OnSelect = function(_, _, _, v) cfg.model = v end
	label(body, 'ЯЧЕЕК (1–' .. L.MaxSlots .. ')')
	local slots = vgui.Create('DNumberWang', body)
	slots:Dock(TOP) slots:SetMinMax(1, L.MaxSlots) slots:SetDecimals(0) slots:SetValue(cfg.slots or 8)
	slots.OnValueChanged = function(_, v) cfg.slots = math.floor(tonumber(v) or 8) end
	label(body, 'ТАБЛИЦА ЛУТА')
	local tbl = vgui.Create('DComboBox', body)
	tbl:Dock(TOP)
	local function fillTables()
		tbl:Clear()
		local names = table.GetKeys(CU.tables)
		table.sort(names)
		for _, n in ipairs(names) do tbl:AddChoice(n, n, cfg.table == n) end
	end
	fillTables()
	hook.Add('HLALootTables', tbl, fillTables)
	tbl.OnSelect = function(_, _, v) cfg.table = v end
	label(body, 'ПОПОЛНЯЕТСЯ КАЖДЫЕ, МИНУТ')
	local resp = vgui.Create('DNumberWang', body)
	resp:Dock(TOP) resp:SetMinMax(1, 600) resp:SetDecimals(0) resp:SetValue(cfg.respawn or 10)
	resp.OnValueChanged = function(_, v) cfg.respawn = math.floor(tonumber(v) or 10) end
	local function act(what, payload)
		net.Start('hla_cont_cfg') net.WriteEntity(e) net.WriteString(what)
		if payload then net.WriteString(payload) end
		net.SendToServer()
	end
	local save = btn(body, 'СОХРАНИТЬ', function() act('set', util.TableToJSON(cfg)) end)
	save:Dock(TOP) save:SetTall(math.floor(36 * s)) save:DockMargin(0, 14, 0, 0)
	local refill = btn(body, 'НАПОЛНИТЬ СЕЙЧАС', function() act('refill') end)
	refill:Dock(TOP) refill:SetTall(math.floor(36 * s)) refill:DockMargin(0, 6, 0, 0)
	local tables = btn(body, 'ТАБЛИЦЫ ЛУТА…', function() CU.OpenTables() end)
	tables:Dock(TOP) tables:SetTall(math.floor(36 * s)) tables:DockMargin(0, 6, 0, 0)
end)

properties.Add('hla_container_cfg', {
	MenuLabel = 'Настроить контейнер',
	Order = 100,
	MenuIcon = 'icon16/box.png',
	Filter = function(self, e, p) return IsValid(e) and e.IsHLAContainer and HLA.CanEdit and HLA.CanEdit(p) end,
	Action = function(self, e)
		net.Start('hla_cont_cfg') net.WriteEntity(e) net.WriteString('get') net.SendToServer()
	end,
})

list.Set('DesktopWindows', 'HLALootTables', {
	title = 'Таблицы лута', icon = 'icon64/tool.png', width = 10, height = 10, onewindow = true,
	init = function(icon, window)
		if IsValid(window) then window:Remove() end
		if not (HLA.CanEdit and HLA.CanEdit(LocalPlayer())) then return end
		net.Start('hla_cont_cfg') net.WriteEntity(NULL) net.WriteString('tables') net.SendToServer()
		hook.Add('HLALootTables', 'HLAOpenTables', function()
			hook.Remove('HLALootTables', 'HLAOpenTables')
			CU.OpenTables()
		end)
	end,
})
