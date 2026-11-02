local S = HLA.Story
local E = {}
HLA.Editor = E

local BLUE = HLA.Hud.AMBER_C
local WHITE = Color(226, 236, 244)
local DARK = Color(6, 14, 22, 245)
local PANEL = Color(12, 26, 38, 255)

local function sc() return math.Clamp(math.min(ScrW() / 1920, ScrH() / 1080), 0.7, 2) end
local fontKey
local function fonts()
	local key = ScrW() .. 'x' .. ScrH()
	if fontKey == key then return end
	fontKey = key
	surface.CreateFont('hla_ed', {font = 'Play', size = math.floor(17 * sc()), weight = 500, extended = true})
	surface.CreateFont('hla_ed_big', {font = 'Play', size = math.floor(26 * sc()), weight = 700, extended = true})
end

concommand.Add('hla_editor', function()
	if not HLA.CanEdit(LocalPlayer()) then chat.AddText(BLUE, '[HLA] ', WHITE, 'Редактор — только для администраторов') return end
	net.Start('hla_story_do') net.WriteString('get') net.WriteString('') net.SendToServer()
end)

local function act(what, arg)
	net.Start('hla_story_do') net.WriteString(what) net.WriteString(arg or '') net.SendToServer()
end

local function save()
	local data = util.Compress(util.TableToJSON(E.cfg))
	net.Start('hla_story_save')
	net.WriteUInt(#data, 32)
	net.WriteData(data, #data)
	net.SendToServer()
	E.dirty = false
end

local function here()
	local p = LocalPlayer()
	local pos = p:GetPos()
	return {p = {math.Round(pos.x, 1), math.Round(pos.y, 1), math.Round(pos.z, 1)}, y = math.Round(p:EyeAngles().y, 1)}
end

local function aimPoint()
	local tr = LocalPlayer():GetEyeTrace()
	local v = tr.HitPos
	return {math.Round(v.x, 1), math.Round(v.y, 1), math.Round(v.z, 1)}
end

local function label(parent, text, font)
	local l = vgui.Create('DLabel', parent)
	l:SetText(text)
	l:SetFont(font or 'hla_ed')
	l:SetTextColor(WHITE)
	l:SizeToContents()
	return l
end

local function button(parent, text, fn)
	local b = vgui.Create('DButton', parent)
	b:SetText(text)
	b:SetFont('hla_ed')
	b:SetTextColor(WHITE)
	b:SetTall(math.floor(30 * sc()))
	b:SizeToContentsX(math.floor(28 * sc()))
	b.Paint = function(self, w, h)
		surface.SetDrawColor(self:IsHovered() and Color(30, 70, 96) or PANEL)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, self:IsHovered() and 255 or 140)
		surface.DrawRect(0, 0, 3, h)
	end
	b.DoClick = function() surface.PlaySound('hla/ui/textline_end.wav') fn() end
	return b
end

local function entry(parent, value, onChange, multiline)
	local e = vgui.Create('DTextEntry', parent)
	e:SetFont('hla_ed')
	e:SetValue(value or '')
	e:SetUpdateOnType(true)
	e:SetMultiline(multiline or false)
	e:SetTall(math.floor((multiline and 90 or 28) * sc()))
	e.OnValueChange = function(self, v) onChange(v) E.dirty = true end
	return e
end

local function number(parent, value, min, max, onChange)
	local n = vgui.Create('DNumberWang', parent)
	n:SetMinMax(min, max)
	n:SetDecimals(0)
	n:SetValue(value)
	n:SetTall(math.floor(26 * sc()))
	n:SetWide(math.floor(90 * sc()))
	n.OnValueChanged = function(self, v) onChange(tonumber(v) or min) E.dirty = true end
	return n
end

local function check(parent, text, value, onChange)
	local c = vgui.Create('DCheckBoxLabel', parent)
	c:SetText(text)
	c:SetFont('hla_ed')
	c:SetTextColor(WHITE)
	c:SetValue(value and 1 or 0)
	c.OnChange = function(self, v) onChange(v) E.dirty = true end
	c:SizeToContents()
	return c
end

local function column(parent)
	local c = vgui.Create('DScrollPanel', parent)
	c:Dock(FILL)
	c:DockMargin(8, 8, 8, 8)
	local api = {}
	function api.add(pnl, gap)
		pnl:SetParent(c)
		pnl:Dock(TOP)
		pnl:DockMargin(0, 0, 0, gap or math.floor(6 * sc()))
		return pnl
	end
	function api.row(...)
		local r = vgui.Create('DPanel', c)
		r:SetPaintBackground(false)
		r:SetTall(math.floor(30 * sc()))
		for _, p in ipairs({...}) do
			p:SetParent(r)
			p:Dock(LEFT)
			p:DockMargin(0, 0, 6, 0)
		end
		return api.add(r)
	end
	function api.panel() return c end
	return api
end

local function list(parent, cols)
	local l = vgui.Create('DListView', parent)
	l:SetMultiSelect(false)
	for _, c in ipairs(cols) do l:AddColumn(c) end
	l:SetDataHeight(math.floor(22 * sc()))
	return l
end

local function dispatchChoices()
	local out = {{'', '— нет —'}}
	for _, l in ipairs(HLA.DispatchLines) do out[#out + 1] = {l.id, S.DispatchText(E.cfg, l.id)} end
	for _, c in ipairs(E.cfg.dispatch.custom) do out[#out + 1] = {c.id, c.ru} end
	return out
end

local function dispatchCombo(parent, value, onChange)
	local cb = vgui.Create('DComboBox', parent)
	cb:SetFont('hla_ed')
	cb:SetTall(math.floor(28 * sc()))
	for _, c in ipairs(dispatchChoices()) do
		local text = utf8.len(c[2]) and utf8.len(c[2]) > 90 and (string.sub(c[2], 1, utf8.offset(c[2], 90) - 1) .. '…') or c[2]
		cb:AddChoice(text, c[1], c[1] == value)
	end
	cb.OnSelect = function(_, _, _, id) onChange(id) E.dirty = true end
	return cb
end

function E.NPCForm(parent, n, changed)
	local col = column(parent)
	col.add(label(nil, 'ИМЯ (над головой и в чате)'))
	col.add(entry(nil, n.name, function(v) n.name = v changed() end))
	col.add(label(nil, 'МОДЕЛЬ'))
	local mc = vgui.Create('DComboBox')
	mc:SetFont('hla_ed')
	mc:SetTall(math.floor(28 * sc()))
	local any = false
	for _, m in ipairs(S.NPCModels) do
		if util.IsValidModel(m.model) then
			mc:AddChoice(m.label .. '   ' .. m.model, m, m.model == n.model)
			any = true
		end
	end
	mc.OnSelect = function(_, _, _, m)
		n.model = m.model
		if n.weapon == '' or not n.weaponSet then n.weapon = m.weapon end
		changed()
		if IsValid(E.modelEntry) then E.modelEntry:SetValue(n.model) end
		if IsValid(E.wepEntry) then E.wepEntry:SetValue(n.weapon) end
	end
	col.add(mc)
	if not any then col.add(label(nil, 'Ни одной модели из списка не установлено — впишите путь ниже.')) end
	col.add(label(nil, 'или путь к модели (.mdl)'))
	E.modelEntry = col.add(entry(nil, n.model, function(v) n.model = v changed() end))
	col.add(label(nil, 'ОРУЖИЕ (класс: tfa_osips, weapon_ar2 …; пусто — без оружия)'))
	E.wepEntry = col.add(entry(nil, n.weapon, function(v) n.weapon = v n.weaponSet = true changed() end))
	col.add(label(nil, 'АНИМАЦИИ ПОКОЯ (имена через запятую; пусто — все idle модели по очереди)'))
	col.add(entry(nil, n.idles or '', function(v) n.idles = v changed() end))
	col.add(check(nil, 'Иногда переговаривается по рации', n.chatter ~= false, function(v) n.chatter = v changed() end))
	col.add(label(nil, 'РЕПЛИКИ ПО E: 1-я при первом нажатии, 2-я при втором … последняя повторяется.'))
	col.add(label(nil, 'Фраза из войслайнов (Tab в чате подсказывает) произносится голосом.'))
	n.lines = n.lines or {}
	for i = 1, math.max(3, #n.lines + 1) do
		col.add(label(nil, i .. '-й раз'))
		col.add(entry(nil, n.lines[i] or '', function(v)
			n.lines[i] = v
			for k = 1, i - 1 do n.lines[k] = n.lines[k] or '' end
			changed()
		end))
	end
	col.add(label(nil, 'Ещё строки появятся после сохранения и повторного открытия.'))
	return col
end

local function openNPCForm(ent)
	if not IsValid(ent) then return end
	fonts()
	local n = {name = ent:GetNWString('hla_name', ''), model = ent:GetModel(), weapon = ent:GetWeapon(), lines = {}, chatter = true, idles = ''}
	local best, bestD
	for _, c in ipairs(E.cfg and E.cfg.npcs or {}) do
		if c.pos then
			local d = Vector(c.pos[1], c.pos[2], c.pos[3]):DistToSqr(ent:GetPos())
			if not bestD or d < bestD then best, bestD = c, d end
		end
	end
	if best and bestD < 64 * 64 then n = table.Copy(best) end
	local f = vgui.Create('DFrame')
	f:SetTitle('NPC: ' .. (n.name ~= '' and n.name or 'без имени'))
	f:SetSize(math.floor(560 * sc()), math.floor(640 * sc()))
	f:Center()
	f:MakePopup()
	f.Paint = function(self, w, h) surface.SetDrawColor(DARK) surface.DrawRect(0, 0, w, h) surface.SetDrawColor(BLUE) surface.DrawRect(0, 0, w, 2) end
	E.NPCForm(f, n, function() end)
	local b = button(f, 'СОХРАНИТЬ NPC', function()
		net.Start('hla_npc_edit') net.WriteEntity(ent) net.WriteTable(n) net.SendToServer()
		if E.cfg and best then
			for i, c in ipairs(E.cfg.npcs) do if c == best then E.cfg.npcs[i] = n end end
		end
		f:Close()
	end)
	b:Dock(BOTTOM)
end

local function openNPC(ent)
	if not IsValid(ent) or not HLA.CanEdit(LocalPlayer()) then return end
	E.pendingNPC = ent
	act('get')
end
E.OpenNPC = openNPC

properties.Add('hla_npc_edit', {
	MenuLabel = 'NPC: реплики и настройки', Order = 1, MenuIcon = 'icon16/comments.png',
	Filter = function(self, ent, p) return IsValid(ent) and ent.IsHLANPC and HLA.CanEdit(p) end,
	Action = function(self, ent) openNPC(ent) end,
})
hook.Add('GUIMousePressed', 'HLANPCEdit', function(code, aim)
	if code ~= MOUSE_LEFT or not HLA.CanEdit(LocalPlayer()) then return end
	local tr = util.TraceLine({start = EyePos(), endpos = EyePos() + aim * 400, filter = LocalPlayer()})
	if IsValid(tr.Entity) and tr.Entity.IsHLANPC then openNPC(tr.Entity) end
end)

local function chaptersTab(sheet)
	local root = vgui.Create('DPanel', sheet)
	root:SetPaintBackground(false)
	local left = vgui.Create('DPanel', root)
	left:Dock(LEFT)
	left:SetWide(math.floor(380 * sc()))
	left:SetPaintBackground(false)
	local lst = list(left, {'№', 'ЗАГОЛОВОК', 'НАЗВАНИЕ', 'СПАВНЫ', 'ТРИГГЕР'})
	lst:Dock(FILL)
	local right = vgui.Create('DPanel', root)
	right:Dock(FILL)
	right:SetPaintBackground(false)
	local sel = 1
	local function fill()
		lst:Clear()
		for i, ch in ipairs(E.cfg.chapters) do
			lst:AddLine(i, ch.title, ch.name, #ch.spawns, ch.trigger and 'да' or '—')
		end
		if lst:GetLine(sel) then lst:SelectItem(lst:GetLine(sel)) end
	end
	local function form()
		right:Clear()
		local ch = E.cfg.chapters[sel]
		if not ch then return end
		E.selChapter = sel
		local col = column(right)
		col.add(label(nil, 'ГЛАВА ' .. sel, 'hla_ed_big'))
		col.add(label(nil, 'ЗАГОЛОВОК (маленький, сверху: «ГЛАВА 1»)'))
		col.add(entry(nil, ch.title, function(v) ch.title = v fill() end))
		col.add(label(nil, 'НАЗВАНИЕ (крупно)'))
		col.add(entry(nil, ch.name, function(v) ch.name = v fill() end))
		col.add(label(nil, 'ПОДЗАГОЛОВОК (необязательно)'))
		col.add(entry(nil, ch.sub, function(v) ch.sub = v end))
		col.add(label(nil, 'ДИСПЕТЧЕР В НАЧАЛЕ ГЛАВЫ'))
		col.add(dispatchCombo(nil, ch.dispatch, function(id) ch.dispatch = id end))
		col.add(label(nil, 'ТОЧКИ ПОЯВЛЕНИЯ: ' .. #ch.spawns .. '  (встаньте и смотрите, куда должен смотреть игрок)'))
		col.row(
			button(nil, '+ ЗДЕСЬ', function() ch.spawns[#ch.spawns + 1] = here() E.dirty = true fill() form() end),
			button(nil, 'УБРАТЬ ПОСЛЕДНЮЮ', function() table.remove(ch.spawns) E.dirty = true fill() form() end),
			button(nil, 'ОЧИСТИТЬ', function() ch.spawns = {} E.dirty = true fill() form() end))
		col.add(label(nil, 'ТРИГГЕР ПЕРЕХОДА: живой игрок вошёл — все переходят на следующую главу.'))
		col.add(label(nil, 'Наведитесь на точку пола и нажмите «угол 1», затем на противоположную — «угол 2».'))
		col.add(label(nil, ch.trigger and 'Триггер задан.' or 'Триггера нет: на эту главу переходят только командой.'))
		col.row(
			button(nil, 'УГОЛ 1 (куда смотрю)', function()
				local a = aimPoint()
				ch.trigger = ch.trigger or {}
				ch.trigger.a = {a[1], a[2], a[3] - 16}
				ch.trigger.b = ch.trigger.b or {a[1] + 64, a[2] + 64, a[3] + 128}
				E.dirty = true fill() form()
			end),
			button(nil, 'УГОЛ 2 (куда смотрю)', function()
				local b = aimPoint()
				ch.trigger = ch.trigger or {a = {b[1] - 64, b[2] - 64, b[3] - 16}}
				ch.trigger.b = {b[1], b[2], b[3] + 128}
				E.dirty = true fill() form()
			end),
			button(nil, 'УБРАТЬ ТРИГГЕР', function() ch.trigger = nil E.dirty = true fill() form() end))
		if ch.trigger and ch.trigger.b then
			col.row(
				button(nil, 'ВЫШЕ +32', function() ch.trigger.b[3] = ch.trigger.b[3] + 32 E.dirty = true end),
				button(nil, 'НИЖЕ −32', function() ch.trigger.b[3] = math.max(ch.trigger.a[3] + 16, ch.trigger.b[3] - 32) E.dirty = true end))
		end
		col.add(label(nil, sel == #E.cfg.chapters and 'Это последняя глава: её триггер завершает сюжет.' or ''))
		col.add(button(nil, 'ЗАПУСТИТЬ С ЭТОЙ ГЛАВЫ (сначала сохраните)', function() act('chapter', tostring(sel)) end))
	end
	lst.OnRowSelected = function(_, i) sel = i form() end
	local bar = vgui.Create('DPanel', left)
	bar:Dock(BOTTOM)
	bar:SetTall(math.floor(34 * sc()))
	bar:SetPaintBackground(false)
	for _, b in ipairs({
		{'+ ГЛАВА', function()
			local n = #E.cfg.chapters + 1
			table.insert(E.cfg.chapters, {title = 'ГЛАВА ' .. n, name = 'НОВАЯ ГЛАВА', sub = '', spawns = {}, dispatch = ''})
			sel = n
		end},
		{'УДАЛИТЬ', function() if #E.cfg.chapters > 1 then table.remove(E.cfg.chapters, sel) sel = math.max(1, sel - 1) end end},
		{'▲', function() if sel > 1 then local c = E.cfg.chapters c[sel], c[sel - 1] = c[sel - 1], c[sel] sel = sel - 1 end end},
		{'▼', function() local c = E.cfg.chapters if sel < #c then c[sel], c[sel + 1] = c[sel + 1], c[sel] sel = sel + 1 end end},
	}) do
		local btn = button(bar, b[1], function() b[2]() E.dirty = true fill() form() end)
		btn:Dock(LEFT)
		btn:SetWide(math.floor(90 * sc()))
		btn:DockMargin(0, 4, 4, 0)
	end
	fill()
	form()
	return root
end

local function spawnRow(col, name, listRef, refresh)
	col.add(label(nil, name .. ': ' .. #listRef() .. ' точек'))
	col.row(
		button(nil, '+ ЗДЕСЬ', function() local l = listRef() l[#l + 1] = here() E.dirty = true refresh() end),
		button(nil, 'УБРАТЬ ПОСЛЕДНЮЮ', function() table.remove(listRef()) E.dirty = true refresh() end),
		button(nil, 'ОЧИСТИТЬ', function() local l = listRef() for k in pairs(l) do l[k] = nil end E.dirty = true refresh() end))
end

local function pvpTab(sheet)
	local root = vgui.Create('DPanel', sheet)
	root:SetPaintBackground(false)
	local function build()
		root:Clear()
		local v = E.cfg.pvp
		local col = column(root)
		col.add(label(nil, 'ПВП', 'hla_ed_big'))
		col.add(label(nil, 'НАЗВАНИЕ КОМАНДЫ 1'))
		col.add(entry(nil, v.team1, function(x) v.team1 = x end))
		col.add(label(nil, 'НАЗВАНИЕ КОМАНДЫ 2'))
		col.add(entry(nil, v.team2, function(x) v.team2 = x end))
		col.add(label(nil, 'ВРЕМЯ РАУНДА, МИНУТ (потом — победа по живым / по убийствам)'))
		col.add(number(nil, v.time, 1, 60, function(x) v.time = x end))
		col.add(check(nil, 'Урон по своей команде', v.friendly, function(x) v.friendly = x end))
		spawnRow(col, 'СПАВНЫ КОМАНДЫ 1', function() return v.spawns.t1 end, build)
		spawnRow(col, 'СПАВНЫ КОМАНДЫ 2', function() return v.spawns.t2 end, build)
		spawnRow(col, 'СПАВНЫ «КАЖДЫЙ САМ ЗА СЕБЯ» (и запасные для команд)', function() return v.spawns.ffa end, build)
		col.add(label(nil, 'Без своих точек ПвП берёт точки первой главы.'))
		col.row(button(nil, 'ЗАПУСТИТЬ: КОМАНДЫ', function() act('start', 'teams') end),
			button(nil, 'ЗАПУСТИТЬ: КАЖДЫЙ САМ ЗА СЕБЯ', function() act('start', 'ffa') end))
	end
	build()
	return root
end

local function npcTab(sheet)
	local root = vgui.Create('DPanel', sheet)
	root:SetPaintBackground(false)
	local left = vgui.Create('DPanel', root)
	left:Dock(LEFT)
	left:SetWide(math.floor(380 * sc()))
	left:SetPaintBackground(false)
	local lst = list(left, {'№', 'ИМЯ', 'РЕПЛИК'})
	lst:Dock(FILL)
	local right = vgui.Create('DPanel', root)
	right:Dock(FILL)
	right:SetPaintBackground(false)
	local sel
	local function fill()
		lst:Clear()
		for i, n in ipairs(E.cfg.npcs) do
			local k = 0
			for _, l in ipairs(n.lines or {}) do if string.Trim(l) ~= '' then k = k + 1 end end
			lst:AddLine(i, n.name, k)
		end
	end
	local function form()
		right:Clear()
		local n = sel and E.cfg.npcs[sel]
		if not n then
			local col = column(right)
			col.add(label(nil, 'Выберите NPC слева или поставьте нового.'))
			col.add(label(nil, 'Изменения появятся в мире после «СОХРАНИТЬ».'))
			col.add(label(nil, 'В игре: зажмите C и кликните по NPC — откроются его реплики.'))
			return
		end
		E.NPCForm(right, n, function() E.dirty = true fill() end)
	end
	lst.OnRowSelected = function(_, i) sel = i form() end
	local bar = vgui.Create('DPanel', left)
	bar:Dock(BOTTOM)
	bar:SetTall(math.floor(34 * sc()))
	bar:SetPaintBackground(false)
	local place = button(bar, '+ ГДЕ СМОТРЮ', function()
		local a = aimPoint()
		local yaw = (LocalPlayer():GetPos() - Vector(a[1], a[2], a[3])):Angle().y
		local m = S.NPCModels[1]
		for _, c in ipairs(S.NPCModels) do if util.IsValidModel(c.model) then m = c break end end
		table.insert(E.cfg.npcs, {pos = a, yaw = math.Round(yaw, 1), name = 'ЭХО-' .. math.random(100, 999), model = m.model,
			weapon = m.weapon, lines = {'', '', ''}, chatter = true, idles = ''})
		sel = #E.cfg.npcs
		E.dirty = true fill() form()
	end)
	place:Dock(LEFT) place:SetWide(math.floor(160 * sc())) place:DockMargin(0, 4, 4, 0)
	local del = button(bar, 'УДАЛИТЬ', function()
		if sel and E.cfg.npcs[sel] then table.remove(E.cfg.npcs, sel) sel = nil E.dirty = true fill() form() end
	end)
	del:Dock(LEFT) del:SetWide(math.floor(110 * sc())) del:DockMargin(0, 4, 4, 0)
	fill()
	form()
	return root
end

local function dispatchTab(sheet)
	local root = vgui.Create('DPanel', sheet)
	root:SetPaintBackground(false)
	local d = E.cfg.dispatch
	local top = vgui.Create('DPanel', root)
	top:Dock(TOP)
	top:SetTall(math.floor(300 * sc()))
	top:SetPaintBackground(false)
	local lst = list(top, {'ЭФИР', 'ФРАЗА'})
	lst:Dock(FILL)
	if lst.Columns and lst.Columns[1] then lst.Columns[1]:SetFixedWidth(math.floor(60 * sc())) end
	local items = {}
	local function inPool(id) return table.HasValue(d.pool, id) end
	local function fill()
		lst:Clear()
		items = {}
		for _, l in ipairs(HLA.DispatchLines) do items[#items + 1] = {id = l.id, snd = l.snd, en = l.en} end
		for _, c in ipairs(d.custom) do items[#items + 1] = {id = c.id, snd = c.snd, own = true} end
		for _, it in ipairs(items) do lst:AddLine(inPool(it.id) and '●' or '', (S.DispatchText(E.cfg, it.id))) end
	end
	local col = column(root)
	local cur
	local text = entry(nil, '', function(v)
		if not cur then return end
		if cur.own then
			for _, c in ipairs(d.custom) do if c.id == cur.id then c.ru = v end end
		else d.edits[cur.id] = v end
		local line = lst:GetLine(table.KeyFromValue(items, cur) or 0)
		if IsValid(line) then line:SetColumnText(2, v) end
	end, true)
	local en = label(nil, '')
	lst.OnRowSelected = function(_, i)
		cur = items[i]
		text:SetValue(S.DispatchText(E.cfg, cur.id) or '')
		en:SetText(cur.en and ('EN: ' .. cur.en) or (cur.snd ~= '' and ('звук: ' .. cur.snd) or 'без звука'))
		en:SizeToContents()
	end
	col.add(label(nil, 'Текст выбранной фразы (можно поправить перевод):'))
	col.add(text)
	col.add(en)
	col.row(
		button(nil, 'ПРОСЛУШАТЬ', function()
			if not (cur and cur.snd and cur.snd ~= '') then return end
			local at = 0
			for part in string.gmatch(cur.snd, '[^;]+') do
				local id = string.match(part, '^hla/radiovoice/(.+)%.wav$')
				local dur = id and HLA.RadioVoiceByID[id] and HLA.RadioVoiceByID[id].dur or SoundDuration(part)
				timer.Simple(at, function() LocalPlayer():EmitSound(part, 0, 100, 1, CHAN_STATIC) end)
				at = at + math.max(0.06, (dur and dur > 0 and dur or 1.2) - 0.03)
			end
		end),
		button(nil, 'В ЭФИР СЕЙЧАС', function()
			if not cur then return end
			if E.dirty then save() end
			timer.Simple(0.3, function() act('dispatch', cur.id) end)
		end),
		button(nil, 'СЛУЧАЙНЫЙ ЭФИР: ВКЛ/ВЫКЛ', function()
			if not cur then return end
			if inPool(cur.id) then table.RemoveByValue(d.pool, cur.id) else d.pool[#d.pool + 1] = cur.id end
			E.dirty = true fill()
		end))
	col.add(label(nil, 'СЛУЧАЙНЫЙ ЭФИР: раз в столько минут — одна из отмеченных ● фраз (0 — выкл.)'))
	col.add(number(nil, d.every, 0, 120, function(x) d.every = x end))
	col.add(label(nil, 'СВОЯ ФРАЗА: текст и (необязательно) звук, например npc/overwatch/cityvoice/f_localunrest_spkr.wav'))
	local ownText, ownSnd = '', ''
	col.add(entry(nil, '', function(v) ownText = v end))
	col.add(entry(nil, '', function(v) ownSnd = v end))
	col.add(button(nil, 'ДОБАВИТЬ СВОЮ ФРАЗУ', function()
		if string.Trim(ownText) == '' then return end
		d.custom[#d.custom + 1] = {id = 'own_' .. os.time() .. '_' .. math.random(100, 999), ru = ownText, snd = string.Trim(ownSnd)}
		E.dirty = true fill()
	end))
	fill()
	return root
end

local function zonesTab(sheet)
	local root = vgui.Create('DPanel', sheet)
	root:SetPaintBackground(false)
	local left = vgui.Create('DPanel', root)
	left:Dock(LEFT)
	left:SetWide(math.floor(360 * sc()))
	left:SetPaintBackground(false)
	local lst = list(left, {'№', 'НАЗВАНИЕ'})
	lst:Dock(FILL)
	local right = vgui.Create('DPanel', root)
	right:Dock(FILL)
	right:SetPaintBackground(false)
	E.cfg.zones = E.cfg.zones or {}
	local sel
	local function fill()
		lst:Clear()
		for i, z in ipairs(E.cfg.zones) do lst:AddLine(i, z.name) end
	end
	local function form()
		right:Clear()
		local z = sel and E.cfg.zones[sel]
		E.selZone = sel
		local col = column(right)
		if not z then
			col.add(label(nil, 'Зона — место с названием («Блок 4», «Вокзал»). Юнит видит на визоре, в какой он зоне;'))
			col.add(label(nil, 'название зоны пишется и под метками. Выберите зону слева или добавьте новую.'))
			return
		end
		col.add(label(nil, 'ЗОНА ' .. sel, 'hla_ed_big'))
		col.add(label(nil, 'НАЗВАНИЕ'))
		col.add(entry(nil, z.name, function(v) z.name = v fill() end))
		col.add(label(nil, 'Наведитесь на угол зоны на полу — «УГОЛ 1», на противоположный — «УГОЛ 2».'))
		col.row(
			button(nil, 'УГОЛ 1 (куда смотрю)', function()
				local a = aimPoint()
				z.a = {a[1], a[2], a[3] - 16}
				z.b = z.b or {a[1] + 128, a[2] + 128, a[3] + 256}
				E.dirty = true form()
			end),
			button(nil, 'УГОЛ 2 (куда смотрю)', function()
				local b = aimPoint()
				z.a = z.a or {b[1] - 128, b[2] - 128, b[3] - 16}
				z.b = {b[1], b[2], b[3] + 256}
				E.dirty = true form()
			end))
		if z.a and z.b then
			col.row(
				button(nil, 'ВЫШЕ +64', function() z.b[3] = z.b[3] + 64 E.dirty = true end),
				button(nil, 'НИЖЕ −64', function() z.b[3] = math.max(z.a[3] + 32, z.b[3] - 64) E.dirty = true end))
		end
	end
	lst.OnRowSelected = function(_, i) sel = i form() end
	local bar = vgui.Create('DPanel', left)
	bar:Dock(BOTTOM)
	bar:SetTall(math.floor(34 * sc()))
	bar:SetPaintBackground(false)
	local add = button(bar, '+ ЗОНА', function()
		table.insert(E.cfg.zones, {name = 'ЗОНА ' .. (#E.cfg.zones + 1)})
		sel = #E.cfg.zones E.dirty = true fill() form()
	end)
	add:Dock(LEFT) add:DockMargin(0, 4, 4, 0)
	local del = button(bar, 'УДАЛИТЬ', function()
		if sel and E.cfg.zones[sel] then table.remove(E.cfg.zones, sel) sel = nil E.dirty = true fill() form() end
	end)
	del:Dock(LEFT) del:DockMargin(0, 4, 4, 0)
	fill() form()
	return root
end

local function dropshipTab(sheet)
	local root = vgui.Create('DPanel', sheet)
	root:SetPaintBackground(false)
	local function build()
		root:Clear()
		E.cfg.dropship = E.cfg.dropship or {points = {}, every = 5, container = true, speed = 700}
		local v = E.cfg.dropship
		local col = column(root)
		col.add(label(nil, 'ДЕСАНТНИК', 'hla_ed_big'))
		col.add(label(nil, 'Встаньте (или зависните в noclip) там, где он должен пролететь, и нажмите «+ ТОЧКА ЗДЕСЬ».'))
		col.add(label(nil, 'Первую и последнюю точку ставьте за краем карты / за зданиями: там он появляется и исчезает.'))
		col.add(label(nil, 'ТОЧЕК: ' .. #v.points))
		col.row(
			button(nil, '+ ТОЧКА ЗДЕСЬ', function()
				local pos = LocalPlayer():GetPos()
				v.points[#v.points + 1] = {math.Round(pos.x, 1), math.Round(pos.y, 1), math.Round(pos.z, 1)}
				E.dirty = true build()
			end),
			button(nil, 'УБРАТЬ ПОСЛЕДНЮЮ', function() table.remove(v.points) E.dirty = true build() end),
			button(nil, 'ОЧИСТИТЬ', function() v.points = {} E.dirty = true build() end))
		col.add(label(nil, 'КАК ЧАСТО, МИНУТ (0 — только вручную)'))
		col.add(number(nil, v.every, 0, 120, function(x) v.every = x end))
		col.add(label(nil, 'СКОРОСТЬ, ЮНИТОВ В СЕКУНДУ'))
		col.add(number(nil, v.speed, 100, 3000, function(x) v.speed = x end))
		col.add(check(nil, 'С контейнером', v.container, function(x) v.container = x end))
		col.row(button(nil, 'ЗАПУСТИТЬ СЕЙЧАС (сначала сохраните)', function() act('dropship') end))
	end
	build()
	return root
end

local function fabricatorTab(sheet)
	local root = vgui.Create('DPanel', sheet)
	root:SetPaintBackground(false)
	local C = CFRework
	local F = HLA.FabCfg
	local edit = F and F.Current() or {}
	local col = column(root)
	col.add(label(nil, 'ФАБРИКАТОР', 'hla_ed_big'))
	col.add(label(nil, 'Цена в смоле, количество (здоровье / броня / патроны) и есть ли предмет в меню фабрикатора. Для всего сервера.'))
	local cats = C and C.Categories or {}
	for ci, cname in ipairs(cats) do
		col.add(label(nil, cname, 'hla_ed_big'))
		for _, it in ipairs(C.Items) do
			if it.category == ci then
				local e = edit[it.id] or {}
				edit[it.id] = e
				local name = label(nil, it.name)
				name:SetWide(math.floor(330 * sc()))
				local parts = {name, label(nil, 'СМОЛА'), number(nil, e.cost or it.cost, 0, 9999, function(x) e.cost = x end)}
				if F.Base[it.id] and F.Base[it.id].amount then
					parts[#parts + 1] = label(nil, 'КОЛ-ВО')
					parts[#parts + 1] = number(nil, e.amount or it.amount, 1, 9999, function(x) e.amount = x end)
				end
				parts[#parts + 1] = check(nil, 'В МЕНЮ', not e.off, function(x) e.off = not x end)
				col.row(unpack(parts))
			end
		end
	end
	col.row(button(nil, 'СОХРАНИТЬ ФАБРИКАТОР', function() if F then F.SendEdit(edit) end end),
		button(nil, 'СБРОСИТЬ ЦЕНЫ', function()
			for id, b in pairs(F.Base) do
				local e = edit[id] or {}
				edit[id] = e
				e.cost, e.amount, e.off = b.cost, b.amount, false
			end
			F.SendEdit(edit)
			if IsValid(E.frame) then E.frame:Remove() end
			timer.Simple(0.3, function() act('get') end)
		end))
	return root
end

local function radioTab(sheet)
	local root = vgui.Create('DPanel', sheet)
	root:SetPaintBackground(false)
	local top = vgui.Create('DPanel', root)
	top:Dock(TOP)
	top:SetTall(math.floor(320 * sc()))
	top:SetPaintBackground(false)
	local lst = list(top, {'ПЕРЕВОД', 'ОРИГИНАЛ', 'С'})
	lst:Dock(FILL)
	if lst.Columns and lst.Columns[3] then lst.Columns[3]:SetFixedWidth(math.floor(50 * sc())) end
	for _, l in ipairs(HLA.RadioVoice) do lst:AddLine(l.ru, l.en, l.dur) end
	local chain = {}
	local col = column(root)
	local chainLabel = label(nil, '')
	local text = ''
	local textEntry
	local function chainText()
		local parts = {}
		for _, id in ipairs(chain) do
			local l = HLA.RadioVoiceByID[id]
			if l and not string.find(l.ru, '^%(') then parts[#parts + 1] = l.ru end
		end
		local t = table.concat(parts, ' ')
		return (string.gsub(t, '^%l', string.upper)), t
	end
	local function refresh()
		local names = {}
		local total = 0
		for _, id in ipairs(chain) do names[#names + 1] = id total = total + (HLA.RadioVoiceByID[id] and HLA.RadioVoiceByID[id].dur or 0) end
		chainLabel:SetText(#chain == 0 and 'Цепочка пуста: выберите фразу и «+ В ЦЕПОЧКУ»' or (table.concat(names, ' + ') .. string.format('   (%.1f с)', total)))
		chainLabel:SizeToContents()
		text = chainText()
		if IsValid(textEntry) then textEntry:SetValue(text) end
	end
	local function play(ids)
		local at = 0
		for _, id in ipairs(ids) do
			local l = HLA.RadioVoiceByID[id]
			if l then
				timer.Simple(at, function() LocalPlayer():EmitSound(HLA.RadioVoicePath(id), 0, 100, 1, CHAN_STATIC) end)
				at = at + math.max(0.06, l.dur - 0.03)
			end
		end
	end
	local function sel()
		local line = lst:GetSelectedLine()
		return line and HLA.RadioVoice[line] and HLA.RadioVoice[line].id
	end
	lst.DoDoubleClick = function(_, i) play({HLA.RadioVoice[i].id}) end
	col.add(label(nil, 'Двойной клик — прослушать. Слова и фразы собираются в одно объявление (в эфире: «// ДИСПЕТЧЕР — …»).'))
	col.row(
		button(nil, 'ПРОСЛУШАТЬ', function() local id = sel() if id then play({id}) end end),
		button(nil, '+ В ЦЕПОЧКУ', function() local id = sel() if id then chain[#chain + 1] = id refresh() end end),
		button(nil, '+ НАЧАЛО И КОНЕЦ СВЯЗИ', function() table.insert(chain, 1, 'on3') chain[#chain + 1] = 'off2' refresh() end))
	col.add(chainLabel)
	col.row(
		button(nil, 'ПРОСЛУШАТЬ ЦЕПОЧКУ', function() play(chain) end),
		button(nil, 'УБРАТЬ ПОСЛЕДНЮЮ', function() table.remove(chain) refresh() end),
		button(nil, 'ОЧИСТИТЬ', function() chain = {} refresh() end))
	col.add(label(nil, 'ТЕКСТ В ЧАТЕ (собирается из перевода, можно поправить)'))
	textEntry = col.add(entry(nil, '', function(v) text = v end))
	local function paths()
		local t = {}
		for _, id in ipairs(chain) do t[#t + 1] = HLA.RadioVoicePath(id) end
		return table.concat(t, ';')
	end
	col.row(
		button(nil, 'В ЭФИР СЕЙЧАС', function()
			if #chain == 0 or string.Trim(text) == '' then return end
			act('dispatch_chain', util.TableToJSON({text = text, snd = paths()}))
		end),
		button(nil, 'СОХРАНИТЬ КАК ФРАЗУ', function()
			if #chain == 0 or string.Trim(text) == '' then return end
			local d = E.cfg.dispatch
			d.custom[#d.custom + 1] = {id = 'rv_' .. os.time() .. '_' .. math.random(100, 999), ru = text, snd = paths()}
			E.dirty = true
			chat.AddText(BLUE, '[HLA] ', WHITE, 'Фраза добавлена: вкладка ДИСПЕТЧЕР и выбор фразы для главы. Не забудьте СОХРАНИТЬ.')
		end))
	refresh()
	return root
end

local function generalTab(sheet)
	local root = vgui.Create('DPanel', sheet)
	root:SetPaintBackground(false)
	local v = E.cfg.settings
	local col = column(root)
	col.add(label(nil, 'ОБЩЕЕ', 'hla_ed_big'))
	col.add(label(nil, 'ИГРОКОВ ДЛЯ СТАРТА (до этого — свободная игра, потом голосование)'))
	col.add(number(nil, v.minPlayers, 1, 64, function(x) v.minPlayers = x end))
	col.add(label(nil, 'ВРЕМЯ ГОЛОСОВАНИЯ, СЕКУНД'))
	col.add(number(nil, v.voteTime, 5, 120, function(x) v.voteTime = x end))
	col.add(label(nil, 'ЗАСТАВКА ГЛАВЫ, СЕКУНД'))
	col.add(number(nil, v.cardTime, 2, 30, function(x) v.cardTime = x end))
	col.add(check(nil, 'Урон между игроками в сюжете', v.storyFriendlyFire, function(x) v.storyFriendlyFire = x end))
	col.add(check(nil, 'Доклад по рации после убийства', v.killCallout, function(x) v.killCallout = x end))
	col.add(label(nil, 'ДОКЛАДЫ ПОСЛЕ УБИЙСТВА NPC (по строке; войслайны звучат голосом)'))
	col.add(entry(nil, table.concat(v.killLines, '\n'), function(x)
		v.killLines = {}
		for l in string.gmatch(x, '[^\n]+') do if string.Trim(l) ~= '' then v.killLines[#v.killLines + 1] = string.Trim(l) end end
	end, true))
	col.add(label(nil, 'ДОКЛАДЫ ПОСЛЕ УБИЙСТВА ИГРОКА'))
	col.add(entry(nil, table.concat(v.killLinesPlayer, '\n'), function(x)
		v.killLinesPlayer = {}
		for l in string.gmatch(x, '[^\n]+') do if string.Trim(l) ~= '' then v.killLinesPlayer[#v.killLinesPlayer + 1] = string.Trim(l) end end
	end, true))
	col.add(label(nil, 'РАУНД', 'hla_ed_big'))
	col.row(button(nil, 'ГОЛОСОВАНИЕ', function() act('vote') end),
		button(nil, 'СЮЖЕТ СЕЙЧАС', function() act('start', 'story') end),
		button(nil, 'ОСТАНОВИТЬ РАУНД', function() act('stop') end))
	return root
end

function E.Open()
	if IsValid(E.frame) then E.frame:Remove() end
	local s = sc()
	fonts()
	local f = vgui.Create('DFrame')
	E.frame = f
	f:SetTitle('')
	f:SetSize(math.min(ScrW() - 40, math.floor(1180 * s)), math.min(ScrH() - 40, math.floor(780 * s)))
	f:Center()
	f:MakePopup()
	f:SetSizable(true)
	f.Paint = function(self, w, h)
		surface.SetDrawColor(DARK)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(BLUE)
		surface.DrawRect(0, 0, w, 2)
		draw.SimpleText('РЕДАКТОР СЮЖЕТА  ::  ' .. string.upper(game.GetMap()) .. (E.dirty and '   (не сохранено)' or ''), 'hla_ed', 12, 12, BLUE)
	end
	f.OnClose = function()
		if E.dirty then chat.AddText(BLUE, '[HLA] ', WHITE, 'Редактор закрыт без сохранения: изменения не отправлены на сервер.') end
	end
	local sheet = vgui.Create('DPropertySheet', f)
	sheet:Dock(FILL)
	sheet:DockMargin(0, 10, 0, 0)
	sheet.Paint = function(self, w, h) surface.SetDrawColor(PANEL) surface.DrawRect(0, 20, w, h - 20) end
	sheet:AddSheet('ГЛАВЫ', chaptersTab(sheet))
	sheet:AddSheet('ПВП', pvpTab(sheet))
	sheet:AddSheet('NPC', npcTab(sheet))
	sheet:AddSheet('ЗОНЫ', zonesTab(sheet))
	sheet:AddSheet('ДЕСАНТНИК', dropshipTab(sheet))
	sheet:AddSheet('ФАБРИКАТОР', fabricatorTab(sheet))
	sheet:AddSheet('ДИСПЕТЧЕР', dispatchTab(sheet))
	sheet:AddSheet('РАЦИЯ', radioTab(sheet))
	sheet:AddSheet('ОБЩЕЕ', generalTab(sheet))
	local b = button(f, 'СОХРАНИТЬ', function() save() end)
	b:Dock(BOTTOM)
	b:DockMargin(0, 6, 0, 0)
	b:SetTall(math.floor(38 * s))
end

net.Receive('hla_story_cfg', function()
	local len = net.ReadUInt(32)
	local t = util.JSONToTable(util.Decompress(net.ReadData(len)) or '')
	if not t then return end
	E.cfg = S.Normalize(t)
	E.dirty = false
	if IsValid(E.pendingNPC) then
		local ent = E.pendingNPC
		E.pendingNPC = nil
		openNPCForm(ent)
		return
	end
	E.Open()
end)

local function v3(t) return Vector(t[1], t[2], t[3]) end
surface.CreateFont('hla_ed3d', {font = 'Play', size = 40, weight = 700, extended = true})
local function mark(pos, yaw, col, text)
	render.DrawWireframeBox(pos, Angle(0, yaw or 0, 0), Vector(-16, -16, 0), Vector(16, 16, 72), col, true)
	local fwd = Angle(0, yaw or 0, 0):Forward()
	render.DrawLine(pos + Vector(0, 0, 36), pos + Vector(0, 0, 36) + fwd * 40, col, true)
	cam.Start3D2D(pos + Vector(0, 0, 84), Angle(0, EyeAngles().y - 90, 90), 0.15)
		draw.SimpleTextOutlined(text, 'hla_ed3d', 0, 0, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 200))
	cam.End3D2D()
end

hook.Add('PostDrawTranslucentRenderables', 'HLAEditorDraw', function(_, sky)
	if sky or not IsValid(E.frame) or not E.cfg then return end
	render.SetColorMaterial()
	for i, ch in ipairs(E.cfg.chapters) do
		local on = E.selChapter == i
		local col = on and Color(110, 200, 255) or Color(70, 110, 140)
		for k, sp in ipairs(ch.spawns) do mark(v3(sp.p), sp.y, col, 'ГЛ.' .. i .. ' #' .. k) end
		if ch.trigger and ch.trigger.a and ch.trigger.b then
			local a, b = v3(ch.trigger.a), v3(ch.trigger.b)
			local mn = Vector(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z))
			local mx = Vector(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))
			local tc = on and Color(255, 200, 60) or Color(150, 120, 50)
			render.DrawWireframeBox(vector_origin, angle_zero, mn, mx, tc, true)
			render.DrawBox(vector_origin, angle_zero, mn, mx, Color(tc.r, tc.g, tc.b, on and 18 or 6))
			cam.Start3D2D((mn + mx) / 2 + Vector(0, 0, (mx.z - mn.z) / 2 + 12), Angle(0, EyeAngles().y - 90, 90), 0.2)
				draw.SimpleTextOutlined('ПЕРЕХОД ИЗ ГЛАВЫ ' .. i, 'hla_ed3d', 0, 0, tc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 200))
			cam.End3D2D()
		end
	end
	for i, z in ipairs(E.cfg.zones or {}) do
		if z.a and z.b then
			local a, b = v3(z.a), v3(z.b)
			local mn = Vector(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z))
			local mx = Vector(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))
			local on = E.selZone == i
			local zc = on and Color(120, 255, 200) or Color(70, 150, 120)
			render.DrawWireframeBox(vector_origin, angle_zero, mn, mx, zc, true)
			render.DrawBox(vector_origin, angle_zero, mn, mx, Color(zc.r, zc.g, zc.b, on and 14 or 5))
			cam.Start3D2D((mn + mx) / 2 + Vector(0, 0, (mx.z - mn.z) / 2 + 12), Angle(0, EyeAngles().y - 90, 90), 0.25)
				draw.SimpleTextOutlined('ЗОНА: ' .. (z.name or ''), 'hla_ed3d', 0, 0, zc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 200))
			cam.End3D2D()
		end
	end
	local ds = E.cfg.dropship and E.cfg.dropship.points or {}
	for k, pt in ipairs(ds) do
		local pos = v3(pt)
		render.DrawWireframeSphere(pos, 24, 8, 8, Color(255, 170, 60), true)
		if ds[k + 1] then render.DrawLine(pos, v3(ds[k + 1]), Color(255, 170, 60), true) end
		cam.Start3D2D(pos + Vector(0, 0, 40), Angle(0, EyeAngles().y - 90, 90), 0.2)
			draw.SimpleTextOutlined('ДЕСАНТНИК #' .. k, 'hla_ed3d', 0, 0, Color(255, 170, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 200))
		cam.End3D2D()
	end
	local pv = E.cfg.pvp.spawns
	for k, sp in ipairs(pv.t1) do mark(v3(sp.p), sp.y, Color(110, 200, 255), 'К1 #' .. k) end
	for k, sp in ipairs(pv.t2) do mark(v3(sp.p), sp.y, Color(236, 96, 72), 'К2 #' .. k) end
	for k, sp in ipairs(pv.ffa) do mark(v3(sp.p), sp.y, Color(200, 200, 200), 'FFA #' .. k) end
	for k, n in ipairs(E.cfg.npcs) do
		if n.pos then mark(v3(n.pos), n.yaw, Color(120, 255, 160), 'NPC ' .. k .. ': ' .. (n.name or '')) end
	end
end)

_G.list.Set('DesktopWindows', 'HLAStoryEditor', {
	title = 'Редактор сюжета', icon = 'icon64/tool.png', width = 10, height = 10, onewindow = true,
	init = function(icon, window)
		if IsValid(window) then window:Remove() end
		RunConsoleCommand('hla_editor')
	end,
})
