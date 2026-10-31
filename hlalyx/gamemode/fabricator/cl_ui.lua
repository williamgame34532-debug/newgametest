-- Fabricator display, drawn in the style of the Half-Life: Alyx fabricator screen.
-- Everything is drawn through the small adapter C.Draw (rect/outline/line/poly/text/size) so the
-- exact same code is rendered offline for previews; cl_init.lua maps it onto surface/draw.
CFRework = CFRework or {}
local C = CFRework
local S = C.State
local Lay = C.Layout
local UI = {}
C.UI = UI

-- palette sampled from the reference screenshots
local function rgb(r, g, b, a) return {r, g, b, a or 255} end
local COL = {
	bg = rgb(6, 36, 48), bg2 = rgb(9, 47, 61), panel = rgb(11, 55, 71), rowbg = rgb(5, 44, 60),
	line = rgb(41, 170, 189), lineDim = rgb(24, 96, 115), bar = rgb(44, 206, 240),
	text = rgb(120, 214, 232), textHi = rgb(214, 247, 251), textDim = rgb(52, 128, 150),
	sel = rgb(78, 206, 232), selText = rgb(4, 32, 44), red = rgb(222, 52, 70), amber = rgb(255, 186, 92),
	x = rgb(26, 104, 128),
}
UI.COL = COL

local function A(c, a) return {c[1], c[2], c[3], a} end

local function wrap(D, str, font, x, y, w, col, lh)
	local line = ''
	for word in string.gmatch(str, '%S+') do
		local cand = line == '' and word or (line .. ' ' .. word)
		if D.size(cand, font) > w and line ~= '' then
			D.text(line, font, x, y, col)
			y = y + lh
			line = word
		else
			line = cand
		end
	end
	if line ~= '' then D.text(line, font, x, y, col) y = y + lh end
	return y
end

-- small Combine glyph used in the top-right corner of every HL:A screen
local function glyph(D, x, y, s, col)
	D.outline(x, y, s, s, col, 2)
	D.poly({{x + s * 0.25, y + s * 0.72}, {x + s * 0.5, y + s * 0.28}, {x + s * 0.75, y + s * 0.72}}, col)
	D.rect(x + s * 0.45, y + s * 0.15, s * 0.1, s * 0.12, col)
end

local function chevron(D, x, y, s, col)
	D.poly({{x, y}, {x + s * 0.32, y}, {x + s * 0.82, y + s * 0.5}, {x + s * 0.32, y + s}, {x, y + s}, {x + s * 0.5, y + s * 0.5}}, col)
end

local function warn(D, x, y, s, col)
	D.poly({{x + s * 0.5, y}, {x + s, y + s * 0.9}, {x, y + s * 0.9}}, col)
	D.rect(x + s * 0.45, y + s * 0.3, s * 0.1, s * 0.32, COL.bg)
	D.rect(x + s * 0.45, y + s * 0.7, s * 0.1, s * 0.1, COL.bg)
end

-- deterministic barcode strip (bottom-left on the reference)
local BARS = {}
do
	local seed = 7
	local x = 0
	while x < 210 do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local w = 1 + seed % 4
		local gap = 2 + math.floor(seed / 7) % 5
		BARS[#BARS + 1] = {x, w, 18 + math.floor(seed / 13) % 14}
		x = x + w + gap
	end
end

local function frame(D, ctx, title)
	local W, H = Lay.W, Lay.H
	D.rect(0, 0, W, H, COL.bg)
	D.rect(0, 0, W, 120, A(COL.bg2, 90))
	-- scanlines and a slow sweep
	for y = 0, H, 4 do D.rect(0, y, W, 1, A(COL.bg2, 70)) end
	D.rect(0, (ctx.t * 40) % H, W, 3, A(COL.line, 10))
	-- bright left bar with the break near the bottom (reference)
	D.rect(6, 0, 11, 424, COL.bar)
	D.rect(6, 436, 11, H - 436, COL.bar)
	-- header
	local tw = D.size(title, 'cfr_hdr')
	D.text(title, 'cfr_hdr', 38, 10, COL.textHi)
	D.text('XXXXXXXXXXXX . .  XXX . X . X', 'cfr_xs', 38 + tw + 16, 16, COL.x)
	D.text('СИСТЕМА ИЗГОТОВЛЕНИЯ  4.4.1', 'cfr_xs', W - 74, 16, COL.textDim, 2)
	glyph(D, W - 58, 9, 26, COL.line)
	D.rect(38, 44, W - 60, 1, COL.lineDim)
	-- bottom strip: barcode, tiny legend, resin counter, diagonal accent
	D.rect(38, Lay.BOTTOM, W - 60, 1, COL.lineDim)
	for _, b in ipairs(BARS) do D.rect(40 + b[1], Lay.BOTTOM + 12 + (32 - b[3]), b[2], b[3], A(COL.lineDim, 220)) end
	D.text('ГРАЖДАНСКАЯ ОБОРОНА  ·  СНАБЖЕНИЕ ПО НОРМЕ', 'cfr_xxs', 40, Lay.BOTTOM + 50, A(COL.red, 200))
	local label = 'СМОЛЫ У ВАС:'
	local num = tostring(ctx.resin or 0)
	local nw = D.size(num, 'cfr_num')
	D.text(num, 'cfr_num', 690, Lay.BOTTOM + 8, COL.textHi)
	D.text(label, 'cfr_s', 682, Lay.BOTTOM + 30, COL.text, 2)
	D.line(690 + nw + 20, Lay.BOTTOM + 44, W - 24, Lay.BOTTOM + 14, COL.lineDim)
end

local function summary(D, item, y0)
	local Sx = Lay.SUMMARY
	D.text('СВОДКА', 'cfr_xs', Sx.x, Sx.y - 2, COL.textDim)
	if not item then return end
	local y = wrap(D, C.Upper(item.name), 'cfr_m', Sx.x, (y0 or Sx.y) + 18, Sx.w, COL.textHi, 24)
	wrap(D, item.text or '', 'cfr_s', Sx.x, y + 6, Sx.w, COL.text, 22)
end

local function button(D, b, label, hover)
	if hover then
		D.rect(b.x, b.y, b.w, b.h, COL.sel)
		D.text(label, 'cfr_m', b.x + b.w / 2, b.y + b.h / 2, COL.selText, 1, 1)
	else
		D.rect(b.x, b.y, b.w, b.h, COL.rowbg)
		D.outline(b.x, b.y, b.w, b.h, COL.line, 2)
		D.text(label, 'cfr_m', b.x + b.w / 2, b.y + b.h / 2, COL.textHi, 1, 1)
	end
end

local function isHover(ctx, id, arg)
	local h = ctx.hover
	return h and h.id == id and (arg == nil or h.arg == arg)
end

function UI.Menu(D, ctx)
	frame(D, ctx, C.Upper(C.Categories[ctx.tab] or ''))
	D.text('НАИМЕНОВАНИЕ', 'cfr_xs', 52, 58, COL.textDim)
	D.text('СТОИМОСТЬ', 'cfr_xs', 626, 58, COL.textDim, 2)
	local shown
	for _, b in ipairs(Lay.Buttons(S.MENU, ctx.tab)) do
		if b.id == 'select' then
			local item = C.Items[b.arg]
			local over = isHover(ctx, 'select', b.arg)
			if over then shown = item end
			local poor = (ctx.resin or 0) < item.cost
			if over then
				D.rect(b.x, b.y, b.w, b.h, COL.sel)
			else
				D.rect(b.x, b.y, b.w, b.h, COL.rowbg)
				D.outline(b.x, b.y, b.w, b.h, COL.line, 2)
			end
			local tc = over and COL.selText or COL.textHi
			D.text(C.Upper(item.name), 'cfr_row', b.x + 18, b.y + b.h / 2, tc, 0, 1)
			local cost = tostring(item.cost)
			D.text(cost, 'cfr_row', b.x + b.w - 16, b.y + b.h / 2, over and COL.selText or COL.text, 2, 1)
			if poor then
				local cw = D.size(cost, 'cfr_row')
				warn(D, b.x + b.w - 16 - cw - 30, b.y + b.h / 2 - 11, 22, over and COL.selText or COL.red)
			end
		elseif b.id == 'tab' then
			local on = ctx.tab == b.arg
			local over = isHover(ctx, 'tab', b.arg)
			D.rect(b.x, b.y, b.w, b.h, (on or over) and COL.panel or COL.bg)
			D.outline(b.x, b.y, b.w, b.h, on and COL.bar or COL.lineDim, on and 2 or 1)
			if on then D.rect(b.x, b.y + b.h - 4, b.w, 4, COL.bar) end
			D.text(C.Categories[b.arg], 'cfr_s', b.x + b.w / 2, b.y + b.h / 2 - 1, (on or over) and COL.textHi or COL.text, 1, 1)
		end
	end
	summary(D, shown)
	if not shown then
		D.text('НАВЕДИТЕ НА ПОЗИЦИЮ', 'cfr_s', Lay.SUMMARY.x, Lay.SUMMARY.y + 20, COL.textDim)
		D.text('И НАЖМИТЕ E', 'cfr_s', Lay.SUMMARY.x, Lay.SUMMARY.y + 42, COL.textDim)
	end
end

local function panel(D)
	local P = Lay.PANEL
	D.rect(P.x, P.y, P.w, P.h, COL.panel)
	D.rect(P.x, P.y, P.w, 6, COL.bar)
end

function UI.Deposit(D, ctx)
	local item = C.Items[ctx.sel]
	frame(D, ctx, C.Upper(item and item.name or ''))
	panel(D)
	local P = Lay.PANEL
	local cx = P.x + P.w / 2
	D.text(string.format('%02d/%02d', ctx.paid or 0, ctx.cost or 0), 'cfr_l', cx, 132, COL.textHi, 1, 1)
	D.text('ВНЕСИТЕ СМОЛУ', 'cfr_l', cx, 172, COL.textHi, 1, 1)
	local bx, by, bw, bh = cx - 250, 214, 500, 30
	D.outline(bx, by, bw, bh, COL.line, 2)
	local f = (ctx.cost or 0) > 0 and math.min(1, (ctx.paid or 0) / ctx.cost) or 0
	if f > 0 then D.rect(bx + 4, by + 4, (bw - 8) * f, bh - 8, COL.bar) end
	-- the ten cells of the magazine
	local filled = (ctx.paid or 0) % 10
	if (ctx.paid or 0) > 0 and filled == 0 and f < 1 then filled = 10 end
	for i = 1, 10 do
		local x = cx - 5 * 34 + (i - 1) * 34 + 6
		local on = i <= filled
		D.outline(x, 268, 22, 22, on and COL.bar or COL.lineDim, 2)
		if on then D.rect(x + 5, 273, 12, 12, COL.bar) end
	end
	D.text('E ПО ЯЧЕЙКЕ  —  ВНЕСТИ СМОЛУ', 'cfr_xs', cx, 312, COL.textDim, 1, 1)
	D.rect(176, 382, 6, 6, COL.red)
	D.rect(190, 382, 6, 6, COL.red)
	button(D, Lay.Buttons(S.DEPOSIT)[1], 'ОТМЕНА', isHover(ctx, 'cancel'))
	summary(D, item)
end

function UI.Print(D, ctx)
	local item = C.Items[ctx.sel]
	frame(D, ctx, C.Upper(item and item.name or ''))
	panel(D)
	local P = Lay.PANEL
	local cx = P.x + P.w / 2
	local f = ctx.printFrac or 0
	D.text('ИЗГОТОВЛЕНИЕ', 'cfr_l', cx, 140, COL.textHi, 1, 1)
	local n = 30
	for i = 1, n do
		local on = i / n <= f
		D.rect(cx - 255 + (i - 1) * 17, 190, 12, 34, on and COL.bar or A(COL.lineDim, 160))
	end
	D.text(math.floor(f * 100) .. '%', 'cfr_num', cx, 262, COL.textHi, 1, 1)
	D.text('НЕ ОТХОДИТЕ ОТ СТАНЦИИ', 'cfr_xs', cx, 310, COL.textDim, 1, 1)
	summary(D, item)
end

function UI.Done(D, ctx)
	local item = C.Items[ctx.sel]
	frame(D, ctx, C.Upper(item and item.name or ''))
	D.text('ИЗДЕЛИЕ ГОТОВО', 'cfr_m', 400, 150, COL.text, 1, 1)
	D.text('ЗАБЕРИТЕ ИЗ КАМЕРЫ  —  E', 'cfr_s', 400, 182, COL.textDim, 1, 1)
	local pulse = 0.55 + 0.45 * math.abs(math.sin(ctx.t * 3))
	chevron(D, 330, 220, 90, A(COL.bar, 255 * pulse))
	chevron(D, 400, 220, 90, A(COL.bar, 255 * pulse))
	summary(D, item)
end

function UI.Boot(D, ctx)
	frame(D, ctx, 'ФАБРИКАТОР')
	local f = ctx.boot or 0
	glyph(D, Lay.W / 2 - 40, 130, 80, A(COL.line, 255 * f))
	D.text('ИНИЦИАЛИЗАЦИЯ', 'cfr_m', Lay.W / 2, 250, COL.text, 1, 1)
	D.outline(Lay.W / 2 - 200, 280, 400, 12, COL.lineDim, 1)
	D.rect(Lay.W / 2 - 198, 282, 396 * f, 8, COL.bar)
end

function UI.Busy(D, ctx)
	D.rect(24, 60, Lay.W - 48, 370, A(COL.bg, 240))
	D.outline(24, 60, Lay.W - 48, 370, COL.line, 2)
	D.text('ТЕРМИНАЛ ЗАНЯТ', 'cfr_l', Lay.W / 2, 210, COL.textHi, 1, 1)
	D.text(ctx.busy or '', 'cfr_m', Lay.W / 2, 252, COL.text, 1, 1)
end

function UI.Draw(D, ctx)
	if ctx.boot and ctx.boot < 1 then
		UI.Boot(D, ctx)
	elseif ctx.stage == S.DEPOSIT then UI.Deposit(D, ctx)
	elseif ctx.stage == S.PRINT then UI.Print(D, ctx)
	elseif ctx.stage == S.DONE then UI.Done(D, ctx)
	else UI.Menu(D, ctx) end
	if ctx.busy then UI.Busy(D, ctx) end
	if ctx.status and ctx.status ~= '' then
		D.rect(38, 400, 610, 32, A(rgb(60, 36, 20), 245))
		D.text(ctx.status, 'cfr_s', 343, 416, COL.amber, 1, 1)
	end
	if ctx.cursor and not ctx.busy then
		local x, y = ctx.cursor[1], ctx.cursor[2]
		D.rect(x - 9, y - 1, 6, 2, COL.textHi) D.rect(x + 3, y - 1, 6, 2, COL.textHi)
		D.rect(x - 1, y - 9, 2, 6, COL.textHi) D.rect(x - 1, y + 3, 2, 6, COL.textHi)
	end
end
