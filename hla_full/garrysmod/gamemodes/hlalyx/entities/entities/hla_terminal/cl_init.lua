include('shared.lua')

-- Screen of the Combine console in the look of the Combine Civil Authority terminal: identification and
-- navigation on the left, the squad register in the middle (cards with bright head bars), session activity
-- and the big buttons on the right. The monitors without power show a red warning.
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

surface.CreateFont('hlaterm_xs', {font = 'Roboto Condensed', size = 17, weight = 500, extended = true})
surface.CreateFont('hlaterm_s', {font = 'Roboto Condensed', size = 20, weight = 700, extended = true})
surface.CreateFont('hlaterm_tab', {font = 'Roboto Condensed', size = 21, weight = 700, extended = true})
surface.CreateFont('hlaterm_m', {font = 'Roboto Condensed', size = 24, weight = 700, extended = true})
surface.CreateFont('hlaterm_t', {font = 'Roboto Condensed', size = 32, weight = 700, extended = true})
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
-- Layout of the Combine terminal (as the HL:A / Combine Civil Authority screens): a header line,
-- three columns — identification and navigation on the left, the working list in the middle (bright
-- title bar, then cards with a bright head bar: cyan, green for the own squad, a chip button on the
-- right, a dark body with the units), session activity and the big buttons on the right — and a footer.
local CYAN = Color(96, 198, 236)
local CYAN_HI = Color(150, 222, 248)
local GREEN = Color(72, 214, 156)
local NAVY = Color(8, 26, 40)
local PANEL_BG = Color(10, 34, 48)
surface.CreateFont('hlaterm_cmb', {font = 'Combine_alphabet', size = 17, weight = 400, extended = true, antialias = true})
surface.CreateFont('hlaterm_id', {font = 'Roboto Condensed', size = 36, weight = 700, extended = true})
surface.CreateFont('hlaterm_bar', {font = 'Roboto Condensed', size = 25, weight = 700, extended = true})

local function L()
	local cw = F.cw
	local lw = math.floor(cw * 0.2)
	local rw = math.floor(cw * 0.2)
	local mx = 40 + lw + 24
	return {cw = cw, lx = 40, lw = lw, mx = mx, mw = cw - 40 - rw - 24 - mx, rx = cw - 40 - rw, rw = rw, top = 74}
end

-- the squad cards of the middle column
local CARD_H, CARD_GAP = 64, 8
local function cardY(i) return 150 + (i - 1) * (CARD_H + CARD_GAP) end

-- rows are kept for the selection logic (squad notice); the middle column draws them as cards
local function rows()
	local r = {}
	for id, s in SortedPairs(SQ.list) do r[#r + 1] = {id, s.name, #s.members .. ' / ' .. SQ.MaxMembers} end
	return r
end
local function selected(r)
	local mine = SQ.Of(LocalPlayer())
	return mine and mine.id or (r[1] and r[1][1])
end

-- everything clickable on the screen
local function buttons()
	local l = L()
	local b = {}
	-- navigation (left column)
	for i, t in ipairs({{'index', 'КОМАНДНЫЙ ИНДЕКС'}, {'squads', 'ОТРЯДЫ'}}) do
		b[#b + 1] = {id = 'nav', arg = t[1], label = t[2], x = l.lx, y = 214 + (i - 1) * 34, w = l.lw, h = 30, tab = true}
	end
	local mine = SQ.Of(LocalPlayer())
	if F.page == 'squads' then
		local i = 0
		for id, s in SortedPairs(SQ.list) do
			i = i + 1
			if i > 5 then break end
			local y = cardY(i)
			if s == mine then
				b[#b + 1] = {id = 'leave', label = 'ПОКИНУТЬ', x = l.mx + l.mw - 128, y = y + 4, w = 120, h = 24, chip = true}
			elseif #s.members < SQ.MaxMembers then
				b[#b + 1] = {id = 'join', arg = id, label = 'ВСТУПИТЬ', x = l.mx + l.mw - 128, y = y + 4, w = 120, h = 24, chip = true}
			end
			if s == mine and s.leader == LocalPlayer() then
				b[#b + 1] = {id = 'disband', label = 'РАСФОРМ.', x = l.mx + l.mw - 128, y = y + 36, w = 120, h = 22, chip = true, dim = true}
			end
		end
	end
	-- right column: forming a squad, then the big buttons at the bottom
	local rx, rw = l.rx, l.rw
	b[#b + 1] = {id = 'kind', arg = -1, label = '<', x = rx, y = 360, w = 30, h = 30, chip = true}
	b[#b + 1] = {id = 'kind', arg = 1, label = '>', x = rx + rw - 30, y = 360, w = 30, h = 30, chip = true}
	if SQ.Count() < SQ.Max then
		b[#b + 1] = {id = 'create', label = 'СФОРМИРОВАТЬ ОТРЯД', x = rx, y = 396, w = rw, h = 30, big = true}
	end
	b[#b + 1] = {id = 'nav', arg = 'index', label = 'НАЗАД / ИНДЕКС', x = rx, y = 440, w = rw, h = 30, big = true}
	b[#b + 1] = {id = 'logout', label = 'ВЫХОД ИЗ СИСТЕМЫ', x = rx, y = 476, w = rw, h = 30, big = true}
	b[#b + 1] = {id = 'exit', label = 'ЗАКРЫТЬ ТЕРМИНАЛ', x = rx, y = 512, w = rw, h = 30, big = true}
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

local PAGE = {index = 'КОМАНДНЫЙ ИНДЕКС', squads = 'РЕЕСТР ОТРЯДОВ'}
local function activate(b)
	if not b then return end
	snd('click')
	if b.id == 'nav' then F.page = b.arg log(PAGE[b.arg] or '')
	elseif b.id == 'kind' then F.kind = (F.kind - 1 + b.arg) % #SQ.Kinds + 1
	elseif b.id == 'create' then send('create', F.kind) log('ФОРМИРОВАНИЕ ОТРЯДА') F.page = 'squads'
	elseif b.id == 'join' then send('join', b.arg) log('ПРИКРЕПЛЕНИЕ К ОТРЯДУ')
	elseif b.id == 'leave' then send('leave') log('ОТКРЕПЛЕНИЕ ОТ ОТРЯДА')
	elseif b.id == 'disband' then send('disband') log('РАСФОРМИРОВАНИЕ')
	elseif b.id == 'logout' then F.log = {} net.Start('hla_term') net.SendToServer()
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
-- a bright bar with a soft scratch texture over it (the HL:A screens are not flat)
local function brightBar(x, y, w, h, c, a)
	fill(x, y, w, h, Color(c.r * 0.82, c.g * 0.82, c.b * 0.82), 235 * (a or 1))
	surface.SetMaterial(bar)
	surface.SetDrawColor(255, 255, 255, 50 * (a or 1))
	surface.DrawTexturedRect(x, y, w, h)
	fill(x, y, w, 1, CYAN_HI, 180 * (a or 1))
end

local function fit(text, font, width)
	surface.SetFont(font)
	if surface.GetTextSize(text) <= width then return text end
	while utf8.len(text) > 1 and surface.GetTextSize(text .. '…') > width do
		text = string.sub(text, 1, utf8.offset(text, utf8.len(text)) - 1)
	end
	return text .. '…'
end

local function drawButton(b, hot)
	if b.tab then
		local on = F.page == b.arg
		if on then fill(b.x, b.y, 3, b.h, CYAN) end
		txt(b.label, 'hlaterm_s', b.x + 12, b.y + b.h / 2, (on or hot) and CYAN_HI or BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	elseif b.big then
		brightBar(b.x, b.y, b.w, b.h, hot and CYAN_HI or CYAN, hot and 1 or 0.85)
		txt(b.label, 'hlaterm_xs', b.x + b.w / 2, b.y + b.h / 2, NAVY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else -- chips on the cards, arrows
		fill(b.x, b.y, b.w, b.h, hot and CYAN_HI or (b.dim and BLUE_DIM or CYAN), hot and 255 or 210)
		txt(b.label, 'hlaterm_xs', b.x + b.w / 2, b.y + b.h / 2, NAVY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

-- Combine script lines: the same for a terminal every time (seeded by its index)
local CMB = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
local function combineLines(seed, n)
	local out, x = {}, seed * 7919
	for i = 1, n do
		local len = 6 + (x % 7)
		local t = {}
		for k = 1, len do
			x = (x * 1103515245 + 12345) % 2147483648
			local c = (x % #CMB) + 1
			t[k] = string.sub(CMB, c, c)
		end
		out[i] = table.concat(t)
	end
	return out
end

local function middle(l)
	local mine = SQ.Of(LocalPlayer())
	local x, w = l.mx, l.mw
	if F.page == 'squads' then
		brightBar(x, l.top, w, 34, CYAN)
		txt('РЕЕСТР ОТРЯДОВ', 'hlaterm_bar', x + 12, l.top + 17, NAVY, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		txt('ПРИКРЕПИТЕСЬ / ОТКРЕПИТЕСЬ, ЧТОБЫ ОБНОВИТЬ НАЗНАЧЕНИЕ', 'hlaterm_xs', x, l.top + 46, CYAN)
		line(x, l.top + 66, w, BLUE_DIM, 120)
		local i = 0
		for _, s in SortedPairs(SQ.list) do
			i = i + 1
			if i > 5 then break end
			local y = cardY(i)
			local own = s == mine
			fill(x, y, w, CARD_H, PANEL_BG, 230)
			frame(x, y, w, CARD_H, own and GREEN or BLUE_DIM, 150)
			brightBar(x, y, w - 136, 32, own and GREEN or CYAN)
			txt(fit(s.name .. '   [' .. #s.members .. '/' .. SQ.MaxMembers .. ']', 'hlaterm_bar', w - 160), 'hlaterm_bar', x + 12, y + 16, NAVY, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			local names = {}
			for _, m in ipairs(s.members) do
				if IsValid(m) then names[#names + 1] = string.upper(m:GetNWString('hla_name', m:Nick())) .. (m == s.leader and ' (К)' or '') end
			end
			local body = #names > 0 and table.concat(names, '   ') or 'НЕТ ПРИКРЕПЛЁННЫХ ЮНИТОВ'
			txt(fit(body, 'hlaterm_xs', w - 160), 'hlaterm_xs', x + 12, y + 48, own and GREEN or CYAN, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			fill(x, y + CARD_H - 2, math.floor(w * 0.18), 2, own and GREEN or CYAN, 160)
		end
		if i == 0 then
			txt('АКТИВНЫХ ОТРЯДОВ НЕТ', 'hlaterm_m', x + w / 2, 260, CYAN_HI, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			txt('СФОРМИРУЙТЕ ОТРЯД СПРАВА', 'hlaterm_xs', x + w / 2, 290, BLUE_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	else
		brightBar(x, l.top, w, 34, CYAN)
		txt('КОМАНДНЫЙ ИНДЕКС', 'hlaterm_bar', x + 12, l.top + 17, NAVY, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		txt('СВОДКА УЗЛА И НАЗНАЧЕНИЕ ЮНИТА', 'hlaterm_xs', x, l.top + 46, CYAN)
		line(x, l.top + 66, w, BLUE_DIM, 120)
		local cards = {
			{'ЮНИТОВ В СЕТИ', tostring(#player.GetAll())},
			{'АКТИВНЫЕ ОТРЯДЫ', SQ.Count() .. ' / ' .. SQ.Max},
			{'НАЗНАЧЕНИЕ', mine and mine.name or 'НЕ НАЗНАЧЕН', mine ~= nil},
			{'СОСТАВ ОТРЯДА', mine and (#mine.members .. ' / ' .. SQ.MaxMembers) or '—'},
		}
		for i, c in ipairs(cards) do
			local y = cardY(i)
			fill(x, y, w, CARD_H, PANEL_BG, 230)
			frame(x, y, w, CARD_H, c[3] and GREEN or BLUE_DIM, 150)
			brightBar(x, y, w, 32, c[3] and GREEN or CYAN)
			txt(c[1], 'hlaterm_bar', x + 12, y + 16, NAVY, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			txt(fit(c[2], 'hlaterm_m', w - 24), 'hlaterm_m', x + 12, y + 48, c[3] and GREEN or CYAN_HI, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
end

local function drawScreen(cur, live, seed)
	local l = L()
	local cw = l.cw
	surface.SetMaterial(bg)
	surface.SetDrawColor(110, 170, 190, 255)
	surface.DrawTexturedRect(0, 0, cw, H)
	fill(0, 0, cw, H, NAVY, 205) -- dark teal glass, like the Civil Authority screens
	local me = LocalPlayer()
	-- header
	txt('ГРАЖДАНСКАЯ ВЛАСТЬ АЛЬЯНСА / КОМАНДНЫЙ ДОСТУП', 'hlaterm_m', 40, 34, CYAN_HI, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	txt('ЛОКАЛЬНЫЙ УЗЕЛ :: 08', 'hlaterm_xs', cw - 92, 34, CYAN, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	-- the Combine mark: a ring cut by a wedge
	draw.NoTexture()
	surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 220)
	for k = 0, 23 do
		if k % 8 ~= 0 then
			local a0, a1 = math.rad(k * 15), math.rad(k * 15 + 12)
			surface.DrawPoly({{x = cw - 60 + math.cos(a0) * 16, y = 34 + math.sin(a0) * 16}, {x = cw - 60 + math.cos(a1) * 16, y = 34 + math.sin(a1) * 16},
				{x = cw - 60 + math.cos(a1) * 10, y = 34 + math.sin(a1) * 10}, {x = cw - 60 + math.cos(a0) * 10, y = 34 + math.sin(a0) * 10}})
		end
	end
	line(40, 56, cw - 80, BLUE_DIM, 140)
	-- left: identification, navigation, Combine script
	txt('ИДЕНТИФИКАЦИЯ', 'hlaterm_xs', l.lx, l.top + 2, BLUE_DIM)
	txt(fit(string.upper(me:GetNWString('hla_name', me:Nick())), 'hlaterm_id', l.lw), 'hlaterm_id', l.lx, l.top + 20, CYAN_HI)
	txt(live and 'СЕАНС АКТИВЕН' or 'E :: ВХОД В СИСТЕМУ', 'hlaterm_xs', l.lx, l.top + 58, live and CYAN or TEXT)
	local sq = SQ.Of(me)
	txt(fit(sq and ('ОТРЯД :: ' .. sq.name) or 'ОТРЯД :: НЕ НАЗНАЧЕН', 'hlaterm_xs', l.lw), 'hlaterm_xs', l.lx, l.top + 80, sq and GREEN or BLUE_DIM)
	for i, s in ipairs(combineLines(seed or 1, 7)) do
		txt(s, 'hlaterm_cmb', l.lx, 306 + (i - 1) * 24, Color(CYAN.r, CYAN.g, CYAN.b, 140))
	end
	-- middle
	middle(l)
	-- right: session activity, forming a squad
	txt('АКТИВНОСТЬ СЕАНСА', 'hlaterm_s', l.rx, l.top + 2, CYAN_HI)
	for i, e in ipairs(F.log) do
		if i > 5 then break end
		local y = l.top + 30 + (i - 1) * 46
		txt(e[1], 'hlaterm_xs', l.rx, y, BLUE_DIM)
		txt(fit(e[2], 'hlaterm_s', l.rw), 'hlaterm_s', l.rx, y + 16, CYAN)
	end
	txt('ТИП НОВОГО ОТРЯДА', 'hlaterm_xs', l.rx, 340, BLUE_DIM)
	txt(fit(SQ.Kinds[F.kind] or '', 'hlaterm_xs', l.rw - 70), 'hlaterm_xs', l.rx + l.rw / 2, 375, CYAN_HI, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	-- footer
	line(40, H - 22, cw - 80, BLUE_DIM, 90)
	txt('ВЛАСТЬ АЛЬЯНСА / ЗАЩИЩЁННЫЙ ДОСТУП', 'hlaterm_xs', 40, H - 12, BLUE_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	txt(os.date('%H:%M:%S') .. '  /  ЮНИТ ' .. unitNumber(me), 'hlaterm_xs', cw - 40, H - 12, BLUE_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	-- buttons
	local hot = live and hovered(cur) or nil
	local hk = bkey(hot)
	for _, b in ipairs(buttons()) do drawButton(b, live and bkey(b) == hk) end
	-- a squad was just created / joined: its name large across the screen for a few seconds
	local n = F.notice
	if live and n and CurTime() - n.t < 4 then
		local k = CurTime() - n.t
		local a = math.Clamp(math.min(k / 0.2, (4 - k) / 0.5), 0, 1)
		local bh = 130
		local by = H / 2 - bh / 2
		fill(0, 0, cw, H, NAVY, 170 * a)
		brightBar(40, by, cw - 80, bh, GREEN, a)
		txt(n.head, 'hlaterm_s', cw / 2, by + 22, Color(NAVY.r, NAVY.g, NAVY.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetFont('hlaterm_big')
		local font = surface.GetTextSize(n.name) > cw - 140 and 'hlaterm_t' or 'hlaterm_big'
		txt(n.name, font, cw / 2, by + bh / 2 + 14, Color(NAVY.r, NAVY.g, NAVY.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	if cur then
		surface.SetMaterial(ring)
		surface.SetDrawColor(CYAN_HI.r, CYAN_HI.g, CYAN_HI.b, 255)
		surface.DrawTexturedRect(cur[1] - 10, cur[2] - 10, 20, 20)
	end
end

-- corner brackets
local function corners(x, y, w, h, c, len)
	surface.SetDrawColor(c.r, c.g, c.b, 255)
	for _, p in ipairs({{x, y, 1, 1}, {x + w, y, -1, 1}, {x, y + h, 1, -1}, {x + w, y + h, -1, -1}}) do
		surface.DrawRect(p[3] > 0 and p[1] or p[1] - len, p[4] > 0 and p[2] or p[2] - 2, len, 2)
		surface.DrawRect(p[3] > 0 and p[1] or p[1] - 2, p[4] > 0 and p[2] or p[2] - len, 2, len)
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
		drawScreen(live and F.cursor or nil, live, self:EntIndex())
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
