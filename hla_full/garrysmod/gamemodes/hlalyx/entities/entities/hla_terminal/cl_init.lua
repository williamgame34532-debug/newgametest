include('shared.lua')

-- Screen of the Combine console, laid out like the Combine fabricator screen: tabs on top, a list on
-- the left (the chosen row lit), the details of the chosen row on the right with the action button,
-- a signal strip and the unit number at the bottom. The monitors without power show a red warning.
local SQ = HLA.Squads
local W, H = 1024, 576
local F = {blend = 0, cursor = {W / 2, H / 2}, page = 'index', kind = 1, log = {}, cw = W, sel = {}}
HLA.TerminalFocus = F

local BLUE = Color(110, 200, 255)
local BLUE_DIM = Color(60, 120, 160)
local TEXT = Color(214, 240, 252)
local DARK = Color(6, 20, 30)
local RED = Color(255, 70, 60)
local RED_DIM = Color(150, 40, 36)
local bg, bar = Material('hla/terminal/bg'), Material('hla/terminal/bar')
local ring = Material('hla/ui_blue/crosshair')
local glyphs = Material('hla/hud/glyphs')

surface.CreateFont('hlaterm_xs', {font = 'IBM Plex Mono', size = 14, weight = 500, extended = true})
surface.CreateFont('hlaterm_s', {font = 'IBM Plex Mono', size = 16, weight = 600, extended = true})
surface.CreateFont('hlaterm_tab', {font = 'Play', size = 19, weight = 700, extended = true})
surface.CreateFont('hlaterm_m', {font = 'Play', size = 21, weight = 700, extended = true})
surface.CreateFont('hlaterm_t', {font = 'Play', size = 30, weight = 700, extended = true})
surface.CreateFont('hlaterm_num', {font = 'Russo One', size = 54, weight = 400, extended = true})
surface.CreateFont('hlaterm_big', {font = 'Russo One', size = 52, weight = 400, extended = true})
surface.CreateFont('hlaterm_warn', {font = 'Russo One', size = 38, weight = 400, extended = true})

local function snd(kind)
	local s = kind == 'click' and ('hla/terminal/combine_tech_click_0' .. math.random(1, 5) .. '.wav')
		or ('hla/ui/textline_' .. math.random(5, 8) .. '.wav')
	if not file.Exists('sound/' .. s, 'GAME') then s = 'hla/ui/textline_end.wav' end
	if file.Exists('sound/' .. s, 'GAME') then surface.PlaySound(s) end
end

local function log(text)
	table.insert(F.log, 1, {os.date('%H:%M:%S'), text})
	while #F.log > 9 do table.remove(F.log) end
end

local function unitNumber(p)
	local n = string.match(p:GetNWString('hla_name', ''), '(%d+)%s*$')
	return n or string.format('%03d', p:EntIndex() % 1000)
end

---------------------------------------------------------------------------------------------------
-- layout (canvas px; the canvas is F.cw wide)
local function L()
	local cw = F.cw
	local lw = math.floor((cw - 80) * 0.46)
	local rx = 40 + lw + 34
	return {cw = cw, lx = 40, lw = lw, rx = rx, rw = cw - 40 - rx, top = 70, row = 36, gap = 6}
end

-- rows of the left list for the page: {key, label, value, bright?}
local function rows()
	local me = LocalPlayer()
	local mine = SQ.Of(me)
	local r = {}
	if F.page == 'index' then
		r[1] = {'online', 'ЮНИТОВ В СЕТИ', #player.GetAll() .. ''}
		r[2] = {'squads', 'АКТИВНЫЕ ОТРЯДЫ', SQ.Count() .. ' / ' .. SQ.Max}
		r[3] = {'size', 'СОСТАВ ОТРЯДА', mine and (#mine.members .. ' / ' .. SQ.MaxMembers) or '—'}
		r[4] = {'post', 'НАЗНАЧЕНИЕ', mine and mine.name or 'НЕТ'}
	elseif F.page == 'squads' then
		for id, s in SortedPairs(SQ.list) do
			r[#r + 1] = {id, (s == mine and '» ' or '') .. s.name, #s.members .. ' / ' .. SQ.MaxMembers}
		end
		r[#r + 1] = {'new', '+ НОВЫЙ ОТРЯД', ''}
	else
		for i, l in ipairs(F.log) do r[i] = {i, l[2], l[1]} end
		if #r == 0 then r[1] = {0, 'ЗАПИСЕЙ НЕТ', ''} end
	end
	return r
end

local function selected(r)
	local key = F.sel[F.page]
	for _, row in ipairs(r) do if row[1] == key then return key end end
	if F.page == 'squads' then
		local mine = SQ.Of(LocalPlayer())
		if mine then return mine.id end
	end
	return r[1] and r[1][1]
end

-- everything clickable on the screen
local function buttons()
	local l = L()
	local b = {}
	local tabs = {{'index', 'ИНДЕКС'}, {'squads', 'ОТРЯДЫ'}, {'log', 'ЖУРНАЛ'}}
	for i, t in ipairs(tabs) do
		b[#b + 1] = {id = 'nav', arg = t[1], label = t[2], x = 40 + (i - 1) * 128, y = 18, w = 118, h = 30, tab = true}
	end
	b[#b + 1] = {id = 'exit', label = 'ВЫХОД', x = l.cw - 40 - 120, y = 18, w = 120, h = 30, chip = true}
	local r = rows()
	for i, row in ipairs(r) do
		b[#b + 1] = {id = 'row', arg = row[1], x = l.lx, y = l.top + 24 + (i - 1) * (l.row + l.gap), w = l.lw, h = l.row, row = row}
	end
	-- actions of the chosen row (right column, at the bottom)
	local key = selected(r)
	local ax, ay, aw = l.rx, 446, math.min(l.rw, 300)
	local mine = SQ.Of(LocalPlayer())
	if F.page == 'index' then
		b[#b + 1] = {id = 'nav', arg = 'squads', label = 'ОТРЯДЫ', x = ax, y = ay, w = aw, h = 40, act = true}
	elseif F.page == 'squads' then
		if key == 'new' then
			b[#b + 1] = {id = 'kind', arg = -1, label = '<', x = l.rx, y = 160, w = 36, h = 36}
			b[#b + 1] = {id = 'kind', arg = 1, label = '>', x = l.rx + 290, y = 160, w = 36, h = 36}
			if SQ.Count() < SQ.Max then
				b[#b + 1] = {id = 'create', label = 'СОЗДАТЬ ОТРЯД', x = ax, y = ay, w = aw, h = 40, act = true}
			end
		else
			local s = SQ.list[key]
			if s and s == mine then
				b[#b + 1] = {id = 'leave', label = 'ПОКИНУТЬ ОТРЯД', x = ax, y = ay, w = aw, h = 40, act = true}
				if s.leader == LocalPlayer() and l.rw >= aw * 2 + 10 then
					b[#b + 1] = {id = 'disband', label = 'РАСФОРМИРОВАТЬ', x = ax + aw + 10, y = ay, w = aw, h = 40}
				elseif s.leader == LocalPlayer() then
					b[#b + 1] = {id = 'disband', label = 'РАСФОРМИРОВАТЬ', x = ax, y = ay - 48, w = aw, h = 40}
				end
			elseif s and #s.members < SQ.MaxMembers then
				b[#b + 1] = {id = 'join', arg = key, label = 'ВСТУПИТЬ', x = ax, y = ay, w = aw, h = 40, act = true}
			end
		end
	end
	return b
end

local function bkey(b) return b and (b.id .. ':' .. tostring(b.arg) .. ':' .. tostring(b.label)) or nil end
local function hovered(cur)
	if not cur then return end
	for _, b in ipairs(buttons()) do
		if cur[1] >= b.x and cur[1] <= b.x + b.w and cur[2] >= b.y and cur[2] <= b.y + b.h then return b end
	end
end

local function send(what, arg)
	net.Start('hla_squad_do') net.WriteString(what)
	if arg then net.WriteUInt(arg, 4) end
	net.SendToServer()
end

local PAGE = {index = 'КОМАНДНЫЙ ИНДЕКС', squads = 'ОТРЯДЫ', log = 'ЖУРНАЛ СЕАНСА'}
local function activate(b)
	if not b then return end
	snd('click')
	if b.id == 'nav' then F.page = b.arg log(PAGE[b.arg])
	elseif b.id == 'row' then F.sel[F.page] = b.arg
	elseif b.id == 'kind' then F.kind = (F.kind - 1 + b.arg) % #SQ.Kinds + 1
	elseif b.id == 'create' then send('create', F.kind) log('СОЗДАНИЕ ОТРЯДА') F.sel.squads = nil
	elseif b.id == 'join' then send('join', b.arg) log('ВСТУПЛЕНИЕ В ОТРЯД')
	elseif b.id == 'leave' then send('leave') log('ВЫХОД ИЗ ОТРЯДА')
	elseif b.id == 'disband' then send('disband') log('РАСФОРМИРОВАНИЕ') F.sel.squads = nil
	elseif b.id == 'exit' then net.Start('hla_term') net.SendToServer()
	end
end

---------------------------------------------------------------------------------------------------
-- drawing
local function txt(t, font, x, y, c, ax, ay) draw.SimpleText(t, font, x, y, c, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP) end
local function line(x, y, w, c, a) surface.SetDrawColor(c.r, c.g, c.b, a or 255) surface.DrawRect(x, y, w, 1) end
local function frame(x, y, w, h, c, a)
	surface.SetDrawColor(c.r, c.g, c.b, a or 255)
	surface.DrawOutlinedRect(x, y, w, h, 1)
end
local function fill(x, y, w, h, c, a) surface.SetDrawColor(c.r, c.g, c.b, a or 255) surface.DrawRect(x, y, w, h) end
local function barRect(x, y, w, h, a)
	surface.SetMaterial(bar)
	surface.SetDrawColor(255, 255, 255, 255 * (a or 1))
	surface.DrawTexturedRect(x, y, w, h)
end
-- corner brackets
local function corners(x, y, w, h, c, len)
	surface.SetDrawColor(c.r, c.g, c.b, 255)
	for _, p in ipairs({{x, y, 1, 1}, {x + w, y, -1, 1}, {x, y + h, 1, -1}, {x + w, y + h, -1, -1}}) do
		surface.DrawRect(p[3] > 0 and p[1] or p[1] - len, p[4] > 0 and p[2] or p[2] - 2, len, 2)
		surface.DrawRect(p[3] > 0 and p[1] or p[1] - 2, p[4] > 0 and p[2] or p[2] - len, 2, len)
	end
end

local function wrap(text, font, width)
	surface.SetFont(font)
	local out, cur = {}, ''
	for word in string.gmatch(text, '%S+') do
		local try = cur == '' and word or (cur .. ' ' .. word)
		if surface.GetTextSize(try) > width and cur ~= '' then out[#out + 1] = cur cur = word else cur = try end
	end
	if cur ~= '' then out[#out + 1] = cur end
	return out
end

local function drawButton(b, hot)
	if b.tab then
		local on = F.page == b.arg
		txt(b.label, 'hlaterm_tab', b.x + 6, b.y + b.h / 2, (on or hot) and TEXT or BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		if on then fill(b.x + 6, b.y + b.h - 3, b.w - 18, 3, BLUE) elseif hot then fill(b.x + 6, b.y + b.h - 2, b.w - 18, 1, BLUE_DIM) end
	elseif b.row then
		local on = selected(rows()) == b.arg
		if on then
			barRect(b.x, b.y, b.w, b.h)
			txt(b.row[2], 'hlaterm_m', b.x + 12, b.y + b.h / 2, DARK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			txt(b.row[3], 'hlaterm_m', b.x + b.w - 12, b.y + b.h / 2, DARK, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		else
			fill(b.x, b.y, b.w, b.h, BLUE, hot and 46 or 18)
			frame(b.x, b.y, b.w, b.h, BLUE_DIM)
			txt(b.row[2], 'hlaterm_m', b.x + 12, b.y + b.h / 2, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			txt(b.row[3], 'hlaterm_m', b.x + b.w - 12, b.y + b.h / 2, BLUE, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	elseif b.act or hot then
		if hot then barRect(b.x, b.y, b.w, b.h) else fill(b.x, b.y, b.w, b.h, BLUE, 34) frame(b.x, b.y, b.w, b.h, BLUE) end
		txt(b.label, 'hlaterm_m', b.x + b.w / 2, b.y + b.h / 2, hot and DARK or TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else
		fill(b.x, b.y, b.w, b.h, BLUE, 18)
		frame(b.x, b.y, b.w, b.h, BLUE_DIM)
		txt(b.label, b.chip and 'hlaterm_s' or 'hlaterm_m', b.x + b.w / 2, b.y + b.h / 2, b.chip and BLUE or TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

-- the details of the chosen row (right column)
local function details(l, key)
	local x, y, w = l.rx, l.top + 24, l.rw
	local function title(t, sub)
		txt(t, 'hlaterm_t', x, y - 6, TEXT)
		line(x, y + 30, w, BLUE_DIM)
		if sub then txt(sub, 'hlaterm_s', x, y + 38, BLUE) end
	end
	local function para(t, yy)
		for i, s in ipairs(wrap(t, 'hlaterm_xs', w)) do txt(s, 'hlaterm_xs', x, yy + (i - 1) * 18, BLUE_DIM) end
	end
	local mine = SQ.Of(LocalPlayer())
	if F.page == 'index' then
		local info = {
			online = {'ЮНИТЫ В СЕТИ', 'Все юниты гражданской обороны, подключённые к локальному узлу.'},
			squads = {'АКТИВНЫЕ ОТРЯДЫ', 'Отряды, сформированные в этом секторе. Создание и вступление — модуль «Отряды».'},
			size = {'СОСТАВ ОТРЯДА', 'Число юнитов в вашем отряде. Отряд — до ' .. SQ.MaxMembers .. ' юнитов.'},
			post = {'НАЗНАЧЕНИЕ', 'Текущий отряд юнита. Без отряда юнит действует самостоятельно.'},
		}
		local it = info[key] or info.online
		title(it[1], 'КОМАНДНЫЙ ИНДЕКС :: ОБЗОР')
		para(it[2], y + 64)
	elseif F.page == 'squads' then
		if key == 'new' then
			title('НОВЫЙ ОТРЯД', 'ТИП ОТРЯДА')
			frame(x + 42, 160, 242, 36, BLUE_DIM)
			txt(SQ.Kinds[F.kind], 'hlaterm_s', x + 163, 178, TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			para('Номер отряда назначается автоматически. Создатель становится командиром.', 212)
			if SQ.Count() >= SQ.Max then txt('ЛИМИТ ОТРЯДОВ :: ' .. SQ.Max, 'hlaterm_s', x, 456, RED) end
		else
			local s = SQ.list[key]
			if not s then title('ОТРЯДОВ НЕТ', 'СОЗДАЙТЕ НОВЫЙ ОТРЯД') return end
			local lead = IsValid(s.leader) and string.upper(s.leader:GetNWString('hla_name', s.leader:Nick())) or '—'
			title(s.name, 'КОМАНДИР :: ' .. lead)
			txt('СОСТАВ  ' .. #s.members .. ' / ' .. SQ.MaxMembers .. (s == mine and '   ·   ВАШ ОТРЯД' or ''), 'hlaterm_xs', x, y + 62, BLUE_DIM)
			for i, m in ipairs(s.members) do
				if IsValid(m) then
					local yy = y + 84 + (i - 1) * 22
					fill(x, yy + 7, 6, 6, m:Alive() and BLUE or RED)
					txt(string.upper(m:GetNWString('hla_name', m:Nick())) .. (m == s.leader and '  [К]' or ''), 'hlaterm_s', x + 16, yy, TEXT)
				end
			end
		end
	else
		title('ЖУРНАЛ СЕАНСА', 'ДЕЙСТВИЯ НА ЭТОМ ТЕРМИНАЛЕ')
		para('Записи текущего сеанса. Журнал очищается при выходе из системы.', y + 64)
	end
end

-- signal strip (bars moving like a waveform)
local function wave(x, y, w, h)
	local t = CurTime()
	local n = math.floor(w / 6)
	for i = 0, n - 1 do
		local v = 0.25 + 0.75 * math.abs(math.sin(i * 0.37 + t * 2.1) * math.sin(i * 0.11 - t * 0.7))
		local bh = math.max(2, math.floor(h * v))
		fill(x + i * 6, y + h - bh, 3, bh, BLUE, 120 + 100 * v)
	end
end

local function drawScreen(cur, live)
	local l = L()
	local cw = l.cw
	surface.SetMaterial(bg)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(0, 0, cw, H)
	frame(10, 10, cw - 20, H - 20, BLUE_DIM, 160)
	corners(10, 10, cw - 20, H - 20, BLUE, 22)
	local me = LocalPlayer()
	-- top: date / node chips
	local cx = cw - 40 - 120 - 10
	for _, chip in ipairs({os.date('%H:%M:%S'), os.date('%d.%m.%y'), 'УЗЕЛ 08'}) do
		surface.SetFont('hlaterm_xs')
		local tw = surface.GetTextSize(chip) + 18
		cx = cx - tw
		frame(cx, 22, tw, 22, BLUE_DIM)
		txt(chip, 'hlaterm_xs', cx + tw / 2, 33, BLUE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cx = cx - 8
	end
	line(40, 54, cw - 80, BLUE_DIM)
	-- list header
	local count = F.page == 'squads' and ('АКТИВНЫЕ ОТРЯДЫ  ' .. SQ.Count() .. ' / ' .. SQ.Max) or F.page == 'log' and 'ЗАПИСИ СЕАНСА' or 'ОБЗОР ПЕРСОНАЛА'
	txt(count, 'hlaterm_xs', l.lx, l.top, BLUE_DIM)
	local hot = live and hovered(cur) or nil
	local r = rows()
	if not live then
		for i, row in ipairs(r) do
			drawButton({row = row, arg = row[1], x = l.lx, y = l.top + 24 + (i - 1) * (l.row + l.gap), w = l.lw, h = l.row}, false)
		end
	end
	details(l, selected(r))
	-- glyphs (Combine script) between the list and the bottom, as decoration
	surface.SetMaterial(glyphs)
	surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 60)
	surface.DrawTexturedRectUV(l.rx, 420, math.min(l.rw, 300), 20, 0.3, 0, 0.62, 1 / 6)
	-- bottom: signal, unit number
	line(40, 456, l.lw, BLUE_DIM, 120)
	local nx = 40 + l.lw
	local num = unitNumber(me)
	surface.SetFont('hlaterm_num')
	local nw = surface.GetTextSize(num)
	wave(40, 470, math.floor(math.max(60, math.min(l.lw * 0.52, l.lw - nw - 160))), 54)
	txt(num, 'hlaterm_num', nx, 532, TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	txt('НОМЕР ЮНИТА', 'hlaterm_xs', nx - nw - 14, 522, BLUE_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	txt(live and 'СЕАНС АКТИВЕН' or 'E :: ВХОД В СИСТЕМУ', 'hlaterm_xs', nx - nw - 14, 502, live and BLUE or TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	txt('ГРАЖДАНСКАЯ ОБОРОНА / КОМАНДНЫЙ ДОСТУП', 'hlaterm_xs', cw - 40, 528, BLUE_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	if live then
		local hk = bkey(hot)
		for _, b in ipairs(buttons()) do drawButton(b, bkey(b) == hk) end
	else
		for _, b in ipairs(buttons()) do if b.tab then drawButton(b, false) end end
	end
	-- a squad was just created / joined: its name large across the screen for a few seconds
	local n = F.notice
	if live and n and CurTime() - n.t < 4 then
		local k = CurTime() - n.t
		local a = math.Clamp(math.min(k / 0.2, (4 - k) / 0.5), 0, 1)
		local bh = 130
		local by = H / 2 - bh / 2
		fill(0, 0, cw, H, DARK, 150 * a)
		surface.SetMaterial(bar)
		surface.SetDrawColor(255, 255, 255, 255 * a)
		surface.DrawTexturedRect(40, by, cw - 80, bh)
		txt(n.head, 'hlaterm_s', cw / 2, by + 22, Color(DARK.r, DARK.g, DARK.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetFont('hlaterm_big')
		local font = surface.GetTextSize(n.name) > cw - 140 and 'hlaterm_t' or 'hlaterm_big'
		txt(n.name, font, cw / 2, by + bh / 2 + 14, Color(DARK.r, DARK.g, DARK.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	if cur then
		surface.SetMaterial(ring)
		surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 255)
		surface.DrawTexturedRect(cur[1] - 10, cur[2] - 10, 20, 20)
	end
end

-- a monitor without power: red, «:: ВНИМАНИЕ, ВНИМАНИЕ - ТЕРМИНАЛ ОБЕСТОЧЕН ::» blinking
local function drawDead(cw, seed)
	local t = CurTime() + seed
	surface.SetMaterial(bg)
	surface.SetDrawColor(255, 80, 70, 255)
	surface.DrawTexturedRect(0, 0, cw, H)
	fill(0, 0, cw, H, Color(40, 0, 0), 120)
	frame(10, 10, cw - 20, H - 20, RED_DIM, 200)
	corners(10, 10, cw - 20, H - 20, RED, 22)
	-- warning stripes top and bottom
	for i = 0, math.ceil(cw / 40) do
		local x = i * 40 - (t * 30) % 40
		fill(x, 30, 18, 10, RED, 90)
		fill(x, H - 40, 18, 10, RED, 90)
	end
	local on = (t % 1.2) < 0.85
	local a = on and 255 or 70
	local warn = ':: ВНИМАНИЕ, ВНИМАНИЕ - ТЕРМИНАЛ ОБЕСТОЧЕН ::'
	surface.SetFont('hlaterm_warn')
	local tw = surface.GetTextSize(warn)
	local font = tw > cw - 80 and 'hlaterm_t' or 'hlaterm_warn'
	fill(40, H / 2 - 44, cw - 80, 88, RED, on and 40 or 14)
	line(40, H / 2 - 44, cw - 80, RED, a)
	line(40, H / 2 + 43, cw - 80, RED, a)
	txt(warn, font, cw / 2, H / 2, Color(255, 120, 110, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	txt('ПИТАНИЕ :: 0%   ·   ЛИНИЯ СВЯЗИ :: НЕТ СИГНАЛА   ·   ОБРАТИТЕСЬ К ТЕРМИНАЛУ УЗЛА', 'hlaterm_xs', cw / 2, H / 2 + 70, RED_DIM, TEXT_ALIGN_CENTER)
	-- now and then a torn line
	if math.random() < 0.06 then fill(0, math.random(60, H - 60), cw, math.random(2, 6), RED, 60) end
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:DrawTranslucent()
	local origin, right, down, normal, scale, center, cw = self:Screen()
	if EyePos():DistToSqr(origin) > 900 * 900 then return end
	if (EyePos() - origin):Dot(normal) < 0 then return end -- from behind: nothing
	if not self.Powered then
		cam.Start3D2D(origin, right:AngleEx(normal), scale)
			drawDead(cw, self:EntIndex() * 0.37)
		cam.End3D2D()
		return
	end
	local live = F.ent == self
	-- the screen lights up when someone comes close, goes dark when nobody is around
	local since = CurTime() - self:GetOpenedAt()
	local a = (self:GetOpen() or live) and math.Clamp(since / 0.5, 0, 1) or math.Clamp(1 - since / 0.25, 0, 1)
	if a <= 0 then return end
	local flick = since < 0.8 and (0.7 + 0.3 * math.random()) or 1
	surface.SetAlphaMultiplier(a * flick)
	local prev = F.cw
	F.cw = cw
	cam.Start3D2D(origin, right:AngleEx(normal), scale)
		drawScreen(live and F.cursor or nil, live)
	cam.End3D2D()
	if not live then F.cw = prev end
	surface.SetAlphaMultiplier(1)
end

---------------------------------------------------------------------------------------------------
-- focus: the camera in front of the screen, the mouse moves the cursor, LMB clicks
net.Receive('hla_term', function()
	local e = net.ReadEntity()
	if IsValid(e) then
		F.ent = e
		local _, _, _, _, _, _, cw = e:Screen()
		F.cw = cw or W
		F.cursor = {F.cw / 2, H / 2}
		F.page = 'index'
		log('ДОСТУП РАЗРЕШЁН')
		snd('click')
	else
		if IsValid(F.ent) then F.holdFire = true end
		F.ent = nil
	end
end)

hook.Add('InputMouseApply', 'HLATerminal', function(cmd, x, y)
	if not IsValid(F.ent) then return end
	local k = 0.9 * (GetConVarNumber('sensitivity') / 3)
	F.cursor[1] = math.Clamp(F.cursor[1] + x * k, 0, F.cw)
	F.cursor[2] = math.Clamp(F.cursor[2] + y * k, 0, H)
	cmd:SetMouseX(0) cmd:SetMouseY(0)
	return true
end)

local wasDown, lastHover = false, nil
hook.Add('CreateMove', 'HLATerminal', function(cmd)
	if not IsValid(F.ent) then
		wasDown = false
		if F.holdFire then
			if bit.band(cmd:GetButtons(), bit.bor(IN_ATTACK, IN_ATTACK2)) ~= 0 then
				cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(bit.bor(IN_ATTACK, IN_ATTACK2))))
			else F.holdFire = nil end
		end
		return
	end
	local down = bit.band(cmd:GetButtons(), IN_ATTACK) ~= 0
	if down and not wasDown then activate(hovered(F.cursor)) end
	wasDown = down
	cmd:ClearMovement()
	cmd:SetButtons(bit.band(cmd:GetButtons(), IN_USE))
end)

-- the own squad changed while at the terminal: show its name, choose it in the list
local lastMine
hook.Add('Think', 'HLATerminalSquadNotice', function()
	local p = LocalPlayer()
	if not IsValid(p) then return end
	local mine = SQ.Of(p)
	local id = mine and mine.id or nil
	if id ~= lastMine then
		if id and IsValid(F.ent) then
			local made = mine.leader == p and #mine.members == 1
			F.notice = {head = made and 'ОТРЯД СОЗДАН' or 'ВЫ В СОСТАВЕ ОТРЯДА', name = mine.name, t = CurTime()}
			F.sel.squads = id
			F.page = 'squads'
			log((made and 'СОЗДАН: ' or 'ВСТУПЛЕНИЕ: ') .. mine.name)
			snd('click')
		end
		lastMine = id
	end
end)

hook.Add('Think', 'HLATerminalHover', function()
	if not IsValid(F.ent) then lastHover = nil return end
	local b = hovered(F.cursor)
	local key = b and (b.id .. tostring(b.arg)) or nil
	if key and key ~= lastHover then snd('hover') end
	lastHover = key
end)

-- the camera close in front of the screen: far enough that the whole canvas fits the view
local last
hook.Add('CalcView', 'HLATerminal', function(p, origin, angles, fov)
	local e = IsValid(F.ent) and F.ent or nil
	local dt = FrameTime()
	F.blend = math.Clamp(F.blend + (e and dt or -dt) * 2.6, 0, 1)
	if e then F.last = e end
	local src = e or F.last
	if F.blend <= 0 or not IsValid(src) then last = nil return end
	local o, right, down, normal, scale, center, cw = src:Screen()
	local width = (cw or W) * scale
	local dist = math.max(width * 0.66, H * scale * 1.15, 7)
	local u, v = F.cursor[1] / (cw or W) - 0.5, F.cursor[2] / H - 0.5
	local pos = center + normal * dist + right * (u * width * 0.05) + down * (v * width * 0.03)
	local look = center + right * (u * width * 0.1) + down * (v * width * 0.06)
	local ang = (look - pos):Angle()
	if last then
		local k = math.min(dt * 7, 1)
		pos, ang = LerpVector(k, last.pos, pos), LerpAngle(k, last.ang, ang)
	end
	last = {pos = pos, ang = ang}
	local b = F.blend * F.blend * (3 - 2 * F.blend)
	return {origin = LerpVector(b, origin, pos), angles = LerpAngle(b, angles, ang), fov = Lerp(b, fov, 70), drawviewer = false, znear = 1}
end)

hook.Add('HUDShouldDraw', 'HLATerminal', function(name) if F.blend > 0 then return false end end)
hook.Add('PreDrawViewModel', 'HLATerminal', function() if F.blend > 0 then return true end end)
hook.Add('OnPauseMenuShow', 'HLATerminal', function()
	if IsValid(F.ent) then net.Start('hla_term') net.SendToServer() return false end
end)
