local FE = {}
HLA.FabEditor = FE
local C = CFRework
local BLUE = Color(110, 200, 255)
local WHITE = Color(226, 236, 244)
local GREY = Color(122, 150, 170)
local DARK = Color(6, 12, 18, 248)
local PANEL = Color(14, 26, 36)

local function sc() return math.Clamp(math.min(ScrW() / 1920, ScrH() / 1080), 0.7, 2) end
local fontKey
local function fonts()
	local key = ScrW() .. 'x' .. ScrH()
	if fontKey == key then return end
	fontKey = key
	local s = sc()
	surface.CreateFont('hla_fe', {font = 'Exo 2', size = math.floor(17 * s), weight = 600, extended = true})
	surface.CreateFont('hla_fe_b', {font = 'Exo 2', size = math.floor(24 * s), weight = 700, extended = true})
end

local function btn(parent, text, fn)
	local b = vgui.Create('DButton', parent)
	b:SetText(text)
	b:SetFont('hla_fe')
	b:SetTextColor(WHITE)
	b:SetTall(math.floor(30 * sc()))
	b.Paint = function(self, w, h)
		surface.SetDrawColor(self:IsHovered() and Color(30, 70, 96) or PANEL)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, self:IsHovered() and 255 or 140)
		surface.DrawRect(0, 0, 3, h)
	end
	b.DoClick = function() surface.PlaySound('hla/ui/textline_end.wav') fn() end
	return b
end

local function lbl(parent, text, font)
	local l = vgui.Create('DLabel', parent)
	l:SetText(text)
	l:SetFont(font or 'hla_fe')
	l:SetTextColor(WHITE)
	l:SizeToContents()
	return l
end

local function weaponClasses()
	local out, seen = {}, {}
	for cls in pairs(HLA.FabCfg.EngineModels) do out[#out + 1] = cls seen[cls] = true end
	for _, w in ipairs(weapons.GetList()) do
		local cls = w.ClassName
		if isstring(cls) and not seen[cls] and (w.Spawnable or w.AdminSpawnable) then out[#out + 1] = cls seen[cls] = true end
	end
	table.sort(out)
	return out
end

local function ammoTypes()
	local out = {}
	for _, name in pairs(game.GetAmmoTypes and game.GetAmmoTypes() or {}) do out[#out + 1] = name end
	table.sort(out)
	return out
end

local function snapshot()
	local F = HLA.FabCfg
	local list = {}
	for _, it in ipairs(F.BaseList) do
		list[#list + 1] = {base = true, id = it.id, name = it.name, category = it.category, cost = it.cost, amount = it.amount,
			hasAmount = F.Base[it.id].amount ~= nil, off = it.off or false, kind = it.kind}
	end
	for _, it in ipairs(F.Custom) do
		list[#list + 1] = {id = it.id, kind = it.srcKind or it.kind, name = it.name, category = it.category, cost = it.cost, off = it.off,
			text = it.text, model = it.model, class = it.class, ammo = it.ammo, amount = it.amount}
	end
	return list
end

local function pack(list)
	local base, custom = {}, {}
	for _, r in ipairs(list) do
		if r.base then
			base[r.id] = {cost = r.cost, amount = r.amount, off = r.off}
		else
			custom[#custom + 1] = {id = r.id, kind = r.kind, name = r.name, category = r.category, cost = r.cost, off = r.off,
				text = r.text, model = r.model, class = r.class, ammo = r.ammo, amount = r.amount}
		end
	end
	return {base = base, custom = custom}
end

local KIND_LABEL = {weapon = 'ОРУЖИЕ', ammo = 'ПАТРОНЫ', health = 'ЗДОРОВЬЕ', armor = 'БРОНЯ', item = 'ПРЕДМЕТ'}

function FE.Open()
	local p = LocalPlayer()
	if not (HLA.CanEdit and HLA.CanEdit(p)) then chat.AddText(BLUE, '[HLA] ', WHITE, 'Настройка фабрикатора — только для админов') return end
	if IsValid(FE.frame) then FE.frame:Remove() end
	fonts()
	local s = sc()
	local list = snapshot()
	local dirty = false
	local f = vgui.Create('DFrame')
	FE.frame = f
	f:SetTitle('')
	f:SetSize(math.min(ScrW() - 40, math.floor(1100 * s)), math.min(ScrH() - 40, math.floor(720 * s)))
	f:Center()
	f:MakePopup()
	f:SetSizable(true)
	f.Paint = function(self, w, h)
		surface.SetDrawColor(DARK)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(BLUE)
		surface.DrawRect(0, 0, w, 2)
		draw.SimpleText('ФАБРИКАТОР  ::  ПРЕДМЕТЫ' .. (dirty and '   (не сохранено)' or ''), 'hla_fe', 12, 10, BLUE)
	end
	local left = vgui.Create('DPanel', f)
	left:Dock(LEFT)
	left:DockMargin(0, 14, 8, 0)
	left:SetWide(math.floor(480 * s))
	left:SetPaintBackground(false)
	local lst = vgui.Create('DListView', left)
	lst:Dock(FILL)
	lst:SetMultiSelect(false)
	lst:AddColumn('КАТЕГОРИЯ'):SetFixedWidth(math.floor(110 * s))
	lst:AddColumn('ПРЕДМЕТ')
	lst:AddColumn('ТИП'):SetFixedWidth(math.floor(80 * s))
	lst:AddColumn('СМОЛА'):SetFixedWidth(math.floor(56 * s))
	lst:AddColumn('В МЕНЮ'):SetFixedWidth(math.floor(60 * s))
	local right = vgui.Create('DScrollPanel', f)
	right:Dock(FILL)
	right:DockMargin(0, 14, 0, 0)
	local sel
	local fill, form
	local function changed() dirty = true fill() end
	fill = function()
		lst:Clear()
		for i, r in ipairs(list) do
			local line = lst:AddLine(C.Categories[r.category] or '?', r.name, (r.base and '' or '+ ') .. (KIND_LABEL[r.kind] or r.kind), r.cost, r.off and '—' or 'да')
			line.idx = i
			if i == sel then line:SetSelected(true) end
		end
	end
	local function add(r)
		r.id = HLA.FabCfg.NewID() .. #list
		r.category = r.category or 2
		r.cost = r.cost or 10
		r.off = false
		list[#list + 1] = r
		sel = #list
		changed()
		form()
	end
	local function row(parent, ...)
		local pnl = vgui.Create('DPanel', parent)
		pnl:SetPaintBackground(false)
		pnl:SetTall(math.floor(30 * s))
		pnl:Dock(TOP)
		pnl:DockMargin(0, 0, 0, 6)
		for _, c in ipairs({...}) do
			c:SetParent(pnl)
			c:Dock(LEFT)
			c:DockMargin(0, 0, 8, 0)
		end
		return pnl
	end
	local function put(parent, c, gap)
		c:SetParent(parent)
		c:Dock(TOP)
		c:DockMargin(0, 0, 0, gap or 6)
		return c
	end
	form = function()
		right:Clear()
		local r = list[sel or 0]
		local cv = right
		put(cv, lbl(nil, 'ДОБАВИТЬ', 'hla_fe_b'))
		local inHand = btn(nil, '+ ОРУЖИЕ В РУКАХ', function()
			local w = LocalPlayer():GetActiveWeapon()
			if not IsValid(w) then return end
			local cls = w:GetClass()
			add({kind = 'weapon', class = cls, name = HLA.FabCfg.WeaponName(cls), category = 2, cost = 25})
		end)
		inHand:SetWide(math.floor(220 * s))
		local fromList = btn(nil, '+ ОРУЖИЕ ИЗ СПИСКА', function()
			local m = DermaMenu()
			for _, cls in ipairs(weaponClasses()) do
				m:AddOption(HLA.FabCfg.WeaponName(cls) .. '  (' .. cls .. ')', function()
					add({kind = 'weapon', class = cls, name = HLA.FabCfg.WeaponName(cls), category = 2, cost = 25})
				end)
			end
			m:Open()
		end)
		fromList:SetWide(math.floor(220 * s))
		row(cv, inHand, fromList)
		local ammo = btn(nil, '+ ПАТРОНЫ', function()
			local w = LocalPlayer():GetActiveWeapon()
			local at = IsValid(w) and w:GetPrimaryAmmoType() or -1
			local name = at >= 0 and game.GetAmmoName(at) or 'SMG1'
			add({kind = 'ammo', ammo = name, amount = 30, name = 'Патроны ' .. name, category = 3, cost = 4})
		end)
		ammo:SetWide(math.floor(140 * s))
		local hp = btn(nil, '+ ЗДОРОВЬЕ', function() add({kind = 'health', amount = 25, name = 'Аптечка', category = 1, cost = 5}) end)
		hp:SetWide(math.floor(140 * s))
		local ar = btn(nil, '+ БРОНЯ', function() add({kind = 'armor', amount = 15, name = 'Броня', category = 1, cost = 4}) end)
		ar:SetWide(math.floor(140 * s))
		row(cv, ammo, hp, ar)
		if not r then
			put(cv, lbl(nil, 'Выберите предмет слева, чтобы изменить его.'))
			return
		end
		put(cv, lbl(nil, r.base and 'ВСТРОЕННЫЙ ПРЕДМЕТ' or 'СВОЙ ПРЕДМЕТ', 'hla_fe_b'), 10)
		put(cv, lbl(nil, 'НАЗВАНИЕ'))
		local name = vgui.Create('DTextEntry')
		name:SetFont('hla_fe')
		name:SetTall(math.floor(28 * s))
		name:SetValue(r.name or '')
		name:SetUpdateOnType(true)
		name:SetEnabled(not r.base)
		name.OnValueChange = function(_, v) r.name = v changed() end
		put(cv, name)
		local cat = vgui.Create('DComboBox')
		cat:SetWide(math.floor(200 * s))
		for i, c in ipairs(C.Categories) do cat:AddChoice(c, i, r.category == i) end
		cat:SetEnabled(not r.base)
		cat.OnSelect = function(_, _, _, v) r.category = v changed() end
		local cost = vgui.Create('DNumberWang')
		cost:SetMinMax(0, 9999)
		cost:SetDecimals(0)
		cost:SetValue(r.cost or 0)
		cost:SetWide(math.floor(90 * s))
		cost.OnValueChanged = function(_, v) r.cost = math.floor(tonumber(v) or 0) changed() end
		row(cv, lbl(nil, 'КАТЕГОРИЯ'), cat, lbl(nil, 'СМОЛА'), cost)
		if r.kind == 'weapon' then
			local cls = vgui.Create('DComboBox')
			cls:SetWide(math.floor(320 * s))
			cls:SetValue(r.class or '')
			for _, c in ipairs(weaponClasses()) do cls:AddChoice(c) end
			cls.OnSelect = function(_, _, v) r.class = v r.model = nil changed() end
			row(cv, lbl(nil, 'КЛАСС ОРУЖИЯ'), cls)
		end
		if r.kind == 'ammo' then
			local at = vgui.Create('DComboBox')
			at:SetWide(math.floor(220 * s))
			at:SetValue(r.ammo or '')
			for _, a in ipairs(ammoTypes()) do at:AddChoice(a) end
			at.OnSelect = function(_, _, v) r.ammo = v changed() end
			row(cv, lbl(nil, 'ТИП ПАТРОНОВ'), at)
		end
		if r.hasAmount or (not r.base and r.kind ~= 'weapon') then
			local am = vgui.Create('DNumberWang')
			am:SetMinMax(1, 9999)
			am:SetDecimals(0)
			am:SetValue(r.amount or 1)
			am:SetWide(math.floor(90 * s))
			am.OnValueChanged = function(_, v) r.amount = math.floor(tonumber(v) or 1) changed() end
			row(cv, lbl(nil, 'КОЛИЧЕСТВО'), am)
		end
		if not r.base then
			put(cv, lbl(nil, 'МОДЕЛЬ (пусто — по оружию / по типу)'))
			local mdl = vgui.Create('DTextEntry')
			mdl:SetFont('hla_fe')
			mdl:SetTall(math.floor(28 * s))
			mdl:SetValue(r.model or '')
			mdl:SetUpdateOnType(true)
			mdl.OnValueChange = function(_, v) r.model = v ~= '' and v or nil dirty = true end
			put(cv, mdl)
			put(cv, lbl(nil, 'ОПИСАНИЕ (пусто — само)'))
			local tx = vgui.Create('DTextEntry')
			tx:SetFont('hla_fe')
			tx:SetTall(math.floor(28 * s))
			tx:SetValue(r.text or '')
			tx:SetUpdateOnType(true)
			tx.OnValueChange = function(_, v) r.text = v dirty = true end
			put(cv, tx)
		end
		local on = vgui.Create('DCheckBoxLabel')
		on:SetText('Есть в меню фабрикатора')
		on:SetFont('hla_fe')
		on:SetTextColor(WHITE)
		on:SetValue(r.off and 0 or 1)
		on.OnChange = function(_, v) r.off = not v changed() end
		put(cv, on, 10)
		if not r.base then
			put(cv, btn(nil, 'УДАЛИТЬ ПРЕДМЕТ', function()
				table.remove(list, sel)
				sel = nil
				changed()
				form()
			end))
		end
	end
	lst.OnRowSelected = function(_, _, line) sel = line.idx form() end
	local bar = vgui.Create('DPanel', f)
	bar:Dock(BOTTOM)
	bar:SetTall(math.floor(40 * s))
	bar:DockMargin(0, 8, 0, 0)
	bar:SetPaintBackground(false)
	local save = btn(bar, 'СОХРАНИТЬ', function()
		HLA.FabCfg.SendEdit(pack(list))
		dirty = false
	end)
	save:Dock(FILL)
	local reset = btn(bar, 'ЦЕНЫ ВСТРОЕННЫХ ПО УМОЛЧАНИЮ', function()
		for _, r in ipairs(list) do
			local b = r.base and HLA.FabCfg.Base[r.id]
			if b then r.cost, r.amount, r.off = b.cost, b.amount, false end
		end
		changed()
		form()
	end)
	reset:Dock(RIGHT)
	reset:SetWide(math.floor(330 * s))
	reset:DockMargin(8, 0, 0, 0)
	f.refresh = function()
		list = snapshot()
		sel = nil
		dirty = false
		fill()
		form()
	end
	fill()
	form()
end

hook.Add('HLAFabCfgChanged', 'HLAFabEditor', function()
	if IsValid(FE.frame) and FE.frame.refresh then FE.frame.refresh() end
end)

concommand.Add('hla_fabricator_editor', function() FE.Open() end)

list.Set('DesktopWindows', 'HLAFabricatorEditor', {
	title = 'Фабрикатор', icon = 'icon64/tool.png', width = 10, height = 10, onewindow = true,
	init = function(icon, window)
		if IsValid(window) then window:Remove() end
		FE.Open()
	end,
})
