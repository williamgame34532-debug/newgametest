-- Main menu (client): golden Half-Life: Alyx style panels drawn in the world (3D2D) at the menu spot,
-- the camera stands in front of them and drifts a little toward the mouse. All looks come from the
-- textures of the hla_menu_content addon (materials/hla/ui); this file only lays them out.
--   ИГРАТЬ > персонажи > (персонаж > ИГРАТЬ / УДАЛИТЬ) | (СОЗДАТЬ ПЕРСОНАЖА > имя, фамилия, модель)
local M = HLA.Menu
local S = {open = false, fade = 0, stack = {}, chars = {}, form = {first = '', last = '', model = 1}, look = {0, 0}}
M.State = S

local mats = {}
local function mat(name)
	mats[name] = mats[name] or Material('hla/ui/' .. name)
	return mats[name]
end

local GOLD = Color(238, 206, 140)
local GOLD_HI = Color(255, 246, 222)
local GOLD_DIM = Color(196, 156, 86)
local W = 560          -- canvas width of a panel (px)
local SCALE = 0.045    -- world units per px (a panel is ~25 units wide)
local R = 40           -- distance of the panel arc from the camera

surface.CreateFont('hlam_big', {font = 'Roboto Condensed', size = 34, weight = 700, extended = true})
surface.CreateFont('hlam_mid', {font = 'Roboto Condensed', size = 25, weight = 700, extended = true})
surface.CreateFont('hlam_small', {font = 'Roboto Condensed', size = 15, weight = 700, extended = true})

local SND = {
	hover = {'hla/ui/textline_5.wav', 'hla/ui/textline_6.wav', 'hla/ui/textline_7.wav', 'hla/ui/textline_8.wav'},
	click = {'hla/ui/textline_end.wav'},
}
local function snd(kind)
	local list = SND[kind]
	if list then surface.PlaySound(list[math.random(#list)]) end
end

---------------------------------------------------------------------------------------------------
-- panel contents: list of items in canvas pixels; kind = row | option | field | section | text | back
-- the list of available player models is checked on disk once, not every frame: the create panel
-- is rebuilt several times per frame, and 16 file.Exists over all mounted paths made it lag badly
local modelCache
local function models()
	if not modelCache then
		modelCache = {}
		for _, m in ipairs(M.Models) do if file.Exists(m, 'GAME') then modelCache[#modelCache + 1] = m end end
	end
	return modelCache
end

local PANELS = {}
function PANELS.main()
	return {title = '', h = 330, items = {
		{id = 'play', kind = 'row', label = 'ИГРАТЬ', y = 50, h = 74},
		{id = 'community', kind = 'row', label = 'СООБЩЕСТВО', y = 132, h = 74},
		{id = 'quit', kind = 'row', label = 'ВЫЙТИ', y = 214, h = 74},
	}}
end

function PANELS.chars()
	local it = {{kind = 'section', label = 'ВАШИ ПЕРСОНАЖИ', y = 40}}
	local y = 62
	for i, c in ipairs(S.chars) do
		it[#it + 1] = {id = 'char', arg = i, kind = 'row', label = string.upper(c.first .. ' ' .. c.last), sub = M.ModelLabel(c.model), y = y, h = 62}
		y = y + 66
	end
	if #S.chars == 0 then it[#it + 1] = {kind = 'text', label = 'ПЕРСОНАЖЕЙ ПОКА НЕТ', y = y + 10} y = y + 50 end
	if #S.chars < M.MaxChars then
		it[#it + 1] = {id = 'new', kind = 'row', label = 'СОЗДАТЬ ПЕРСОНАЖА', y = y + 8, h = 62}
		y = y + 74
	end
	it[#it + 1] = {id = 'back', kind = 'back', label = 'НАЗАД'}
	return {title = 'ПЕРСОНАЖИ', h = math.max(300, y + 30), items = it}
end

function PANELS.char()
	local c = S.chars[S.sel]
	if not c then return {title = 'ПЕРСОНАЖ', h = 200, items = {{id = 'back', kind = 'back', label = 'НАЗАД'}}} end
	local armed = (S.deleteArm or 0) > CurTime()
	return {title = 'ПЕРСОНАЖ', h = 330, items = {
		{kind = 'text', label = string.upper(c.first .. ' ' .. c.last), font = 'hlam_big', y = 58},
		{kind = 'text', label = 'МОДЕЛЬ : ' .. M.ModelLabel(c.model), font = 'hlam_small', y = 98},
		{id = 'play_char', kind = 'row', label = 'ИГРАТЬ', y = 140, h = 66},
		{id = 'delete', kind = 'row', label = armed and 'НАЖМИТЕ ЕЩЁ РАЗ — УДАЛИТЬ' or 'УДАЛИТЬ', y = 214, h = 66, warn = armed},
		{id = 'back', kind = 'back', label = 'НАЗАД'},
	}}
end

function PANELS.create()
	local list = models()
	S.form.model = math.Clamp(S.form.model, 1, math.max(1, #list))
	return {title = 'НОВЫЙ ПЕРСОНАЖ', h = 380, items = {
		{kind = 'section', label = 'ДАННЫЕ', y = 40},
		{id = 'field', arg = 'first', kind = 'field', label = 'ИМЯ', y = 62, h = 60},
		{id = 'field', arg = 'last', kind = 'field', label = 'ФАМИЛИЯ', y = 128, h = 60},
		{kind = 'section', label = 'ВНЕШНОСТЬ', y = 200},
		{id = 'model', kind = 'option', label = 'МОДЕЛЬ : ' .. M.ModelLabel(list[S.form.model]), count = #list, index = S.form.model, y = 222, h = 64},
		{id = 'create', kind = 'row', label = 'СОЗДАТЬ', y = 296, h = 62},
		{id = 'back', kind = 'back', label = 'НАЗАД'},
	}}
end

---------------------------------------------------------------------------------------------------
local catcher     -- full-screen panel that takes the mouse while the menu is up
local closeInput  -- defined with the text field below

local function push(id)
	S.stack[#S.stack + 1] = {id = id, t0 = RealTime(), x = (#S.stack > 0) and S.stack[#S.stack].x + 30 or 0}
	snd('click')
end

local function pop()
	if #S.stack <= 1 then return end
	local top = S.stack[#S.stack]
	if top.closing then return end
	top.closing = RealTime()
	if top.id == 'create' then closeInput(false) end
	snd('click')
end


-- Typing: the full-screen click catcher IS the text entry. Clicking anywhere gives it the keyboard
-- focus by itself (a separate hidden entry lost the focus to the clicked panel), so the letters
-- always arrive; they are routed into the field that is selected on the panel.
closeInput = function()
	S.focus = nil
	if IsValid(catcher) then catcher:SetText('') end
end

local function focusField(name)
	S.focus = name
	if IsValid(catcher) then
		catcher:SetText(S.form[name] or '')
		catcher:SetCaretPos(utf8.len(catcher:GetText()) or 0)
		catcher:RequestFocus()
	end
	snd('click')
end

local function activate(item)
	if not item.id then return end
	local id = item.id
	if id == 'play' then push('chars')
	elseif id == 'community' then gui.OpenURL(M.CommunityURL)
	elseif id == 'quit' then RunConsoleCommand('disconnect')
	elseif id == 'back' then pop()
	elseif id == 'char' then S.sel = item.arg S.deleteArm = nil push('char')
	elseif id == 'new' then S.form = {first = '', last = '', model = 1} S.error = nil push('create')
	elseif id == 'field' then focusField(item.arg)
	elseif id == 'play_char' then
		net.Start('hla_menu_do') net.WriteString('play') net.WriteUInt(S.sel, 8) net.SendToServer()
		snd('click')
	elseif id == 'delete' then
		if (S.deleteArm or 0) > CurTime() then
			net.Start('hla_menu_do') net.WriteString('delete') net.WriteUInt(S.sel, 8) net.SendToServer()
			S.deleteArm = nil
			pop()
		else
			S.deleteArm = CurTime() + 3
			snd('click')
		end
	elseif id == 'create' then
		local f = S.form
		local list = models()
		if not M.ValidName(f.first) or not M.ValidName(f.last) then
			S.error = 'ИМЯ И ФАМИЛИЯ: ' .. M.NameMin .. '–' .. M.NameMax .. ' БУКВ'
			snd('click')
			return
		end
		net.Start('hla_menu_do') net.WriteString('create')
		net.WriteString(f.first) net.WriteString(f.last) net.WriteString(list[f.model] or '')
		net.SendToServer()
		S.focus = nil
		pop()
	end
end

---------------------------------------------------------------------------------------------------
-- placement: panels on an arc in front of the camera, the newest a little right of centre
local function frame(p)
	local origin, base = S.camPos, S.camAng
	local fwd, right, up = base:Forward(), base:Right(), base:Up()
	fwd = Vector(fwd.x, fwd.y, 0):GetNormalized()
	right = Vector(right.x, right.y, 0):GetNormalized()
	local a = p.x / R
	local center = origin + fwd * (R * math.cos(a)) + right * (R * math.sin(a)) - Vector(0, 0, 3)
	local n = (origin - center) n.z = 0 n:Normalize()
	local r = (-n):Cross(Vector(0, 0, 1))
	return center, r, Vector(0, 0, 1), n
end

local function panelHit(p, def, dir)
	local center, r, up, n = frame(p)
	local w, h = W * SCALE, (def.h + 70) * SCALE
	local origin = center - r * (w * 0.5) + up * (h * 0.5)
	local hit = util.IntersectRayWithPlane(S.camPos, dir, origin, n)
	if not hit then return end
	local rel = hit - origin
	return rel:Dot(r) / SCALE, -rel:Dot(up) / SCALE
end

local function itemAt(def, x, y)
	for _, it in ipairs(def.items) do
		if it.id then
			if it.kind == 'back' then
				if x >= W - 170 and x <= W - 20 and y >= def.h + 14 and y <= def.h + 58 then return it end
			elseif it.kind == 'option' then
				-- the whole row turns the option: left third back, the rest forward
				if y >= it.y and y <= it.y + it.h and x >= 0 and x <= W then
					return it, (x < W / 3) and -1 or 1
				end
			elseif x >= 0 and x <= W and y >= it.y and y <= it.y + it.h then
				return it
			end
		end
	end
end

-- what the mouse points at: only the newest panel is interactive (like HL:A); older ones go back
local function pick()
	if not S.camPos then return end
	local mx, my = input.GetCursorPos()
	local dir = gui.ScreenToVector(mx, my)
	for i = #S.stack, 1, -1 do
		local p = S.stack[i]
		if not p.closing then
			local def = PANELS[p.id]()
			local x, y = panelHit(p, def, dir)
			if x and x >= 0 and x <= W and y >= 0 and y <= def.h + 70 then
				if i < #S.stack then return {older = i} end
				local it, side = itemAt(def, x, y)
				return {item = it, side = side, panel = p}
			end
		end
	end
end

local function click()
	local h = pick()
	if not h then return end
	if h.older then
		-- clicking an older panel closes everything after it
		for i = #S.stack, h.older + 1, -1 do if not S.stack[i].closing then S.stack[i].closing = RealTime() end end
		snd('click')
		return
	end
	local it = h.item
	if not it then return end
	if it.kind == 'option' and h.side then
		local n = math.max(1, it.count)
		S.form.model = (S.form.model - 1 + h.side) % n + 1
		snd('hover')
		return
	end
	activate(it)
end

---------------------------------------------------------------------------------------------------
-- drawing
local function smooth(x) x = math.Clamp(x, 0, 1) return x * x * (3 - 2 * x) end

local function tex(name, x, y, w, h, c, a)
	surface.SetMaterial(mat(name))
	surface.SetDrawColor(c.r, c.g, c.b, (c.a or 255) * a)
	surface.DrawTexturedRect(x, y, w, h)
end

local function drawPanel(p, def, hover, a)
	local reveal = smooth((RealTime() - p.t0) / 0.45)
	if p.closing then reveal = math.min(reveal, 1 - smooth((RealTime() - p.closing) / 0.3)) end
	if reveal <= 0 then return end
	local flick = (RealTime() - p.t0 < 0.5) and (0.75 + 0.25 * math.random()) or 1
	a = a * flick
	local white = Color(255, 255, 255)
	-- header first spreads across, then the body unrolls downward
	local hw = W * smooth(reveal * 2)
	tex('header', (W - hw) * 0.5, 0, hw, 20, white, a)
	if def.title ~= '' and reveal > 0.5 then
		draw.SimpleText(def.title, 'hlam_small', W - 14, 10, Color(60, 40, 8, 255 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	local bodyH = def.h * smooth((reveal - 0.25) / 0.75)
	if bodyH <= 1 then return end
	tex('panel_bg', 12, 20, W - 24, bodyH, white, a)
	-- frame bracket in the lower right corner (the texture is a top-left bracket, mirrored by UV)
	surface.SetMaterial(mat('corner'))
	surface.SetDrawColor(GOLD.r, GOLD.g, GOLD.b, 255 * a)
	surface.DrawTexturedRectUV(W - 22, 20 + bodyH - 22, 20, 20, 1, 1, 0, 0)
	if reveal < 0.98 then return end

	for _, it in ipairs(def.items) do
		-- items are rebuilt every frame, so the hovered one is matched by id and argument
		local hot = hover and hover.item and it.id and hover.item.id == it.id and hover.item.arg == it.arg
		if it.kind == 'section' then
			draw.SimpleText(it.label, 'hlam_small', W - 40, it.y, Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 200 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		elseif it.kind == 'text' then
			draw.SimpleText(it.label, it.font or 'hlam_mid', W - 40, it.y, Color(GOLD.r, GOLD.g, GOLD.b, 255 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		elseif it.kind == 'row' then
			if hot then tex('row_hover', 4, it.y, W - 8, it.h, white, a) end
			local col = hot and GOLD_HI or (it.warn and Color(255, 120, 80) or GOLD)
			local cy = it.y + it.h * 0.5 - (it.sub and 8 or 0)
			draw.SimpleText(it.label, 'hlam_big', W - 48, cy, Color(col.r, col.g, col.b, 255 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			if it.sub then
				draw.SimpleText(it.sub, 'hlam_small', W - 48, cy + 24, Color(col.r, col.g, col.b, 200 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
			tex('marker', W - 34, it.y + it.h * 0.5 + 2, 10, 10, col, a)
			tex('line', 40, it.y + it.h, W - 80, 2, white, a * 0.5)
		elseif it.kind == 'field' then
			local focused = S.focus == it.arg
			if hot or focused then tex('row_hover', 4, it.y, W - 8, it.h, white, a * (focused and 0.55 or 0.8)) end
			local value = S.form[it.arg] or ''
			local caret = focused and (math.floor(RealTime() * 2) % 2 == 0) and '|' or ''
			local shown = value ~= '' and string.upper(value) or (focused and '' or '—')
			-- long names switch to the smaller font so they stay on the panel
			local line = it.label .. ' : ' .. shown .. caret
			surface.SetFont('hlam_big')
			local font = (surface.GetTextSize(line) > W - 90) and 'hlam_mid' or 'hlam_big'
			draw.SimpleText(line, font, W - 48, it.y + it.h * 0.5 - 4, Color(GOLD_HI.r, GOLD_HI.g, GOLD_HI.b, 255 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			tex('field', 60, it.y + it.h - 10, W - 108, 8, GOLD, a)
		elseif it.kind == 'option' then
			local col = hot and GOLD_HI or GOLD
			draw.SimpleText(it.label, 'hlam_big', W - 96, it.y + it.h * 0.5 - 6, Color(col.r, col.g, col.b, 255 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			tex('arrow_l', 24, it.y + 6, 48, 48, (hot and hover.side == -1) and GOLD_HI or GOLD, a)
			tex('arrow_r', W - 72, it.y + 6, 48, 48, (hot and hover.side == 1) and GOLD_HI or GOLD, a)
			local n = it.count
			local dx = 12
			local x0 = W - 96 - n * dx
			for i = 1, n do
				tex('dot', x0 + (i - 1) * dx, it.y + it.h - 12, 6, 6, i == it.index and GOLD_HI or GOLD_DIM, a * (i == it.index and 1 or 0.6))
			end
		elseif it.kind == 'back' then
			local col = hot and GOLD_HI or GOLD
			tex('button', W - 170, def.h + 14, 150, 44, hot and Color(255, 230, 170) or white, a)
			draw.SimpleText(it.label, 'hlam_mid', W - 95, def.h + 36, Color(col.r, col.g, col.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
	if p.id == 'create' and S.error then
		draw.SimpleText(S.error, 'hlam_small', W - 40, def.h - 8, Color(255, 120, 80, 255 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

-- Half-Life: Alyx title over the menu: the real vertex animation of the game's logo models
-- (hla_menu_content/data_static/hla/logo_anim.txt: per-frame vertex positions, intro then loop).
local LOGO = {}
-- the logo is two words with their own materials, as in Half-Life: Alyx:
-- «HALF-LIFE» gold (logo_text_halflife_face_*), «ALYX» white (logo_text_alyx_face_*);
-- body = the extruded sides of the letters, face = the front
local LOGO_MAT = {
	halflife = {face = Material('hla/logo/halflife_face'), body = Material('hla/logo/halflife_body')},
	alyx = {face = Material('hla/logo/alyx_face'), body = Material('hla/logo/alyx_body')},
}
local function loadLogo()
	if LOGO.tried then return LOGO.raw ~= nil end
	LOGO.tried = true
	local data = file.Read('data_static/hla/logo_anim.txt', 'GAME')
	if not data then return false end
	local nl1 = string.find(data, '\n', 1, true)
	local nl2 = nl1 and string.find(data, '\n', nl1 + 1, true)
	if not nl2 then return false end
	local hdr = util.JSONToTable(string.sub(data, nl1 + 1, nl2 - 1))
	local raw = hdr and util.Decompress(string.sub(data, nl2 + 1))
	if not raw then return false end
	LOGO.hdr, LOGO.raw = hdr, raw
	LOGO.verts = {}
	for i = 1, hdr.verts do LOGO.verts[i] = Vector() end
	-- which word each part is: «HALF-LIFE» is the small line above (logo Z > 8), «ALYX» below
	local ref = (hdr.seqs[2] and hdr.seqs[2].start or 0) * hdr.verts
	for _, part in ipairs(hdr.parts) do
		local o = (ref + part.first + (part.tris[1] or 0)) * 6 + 1
		local e, f = string.byte(raw, o + 4, o + 5)
		local z = e + f * 256
		if z >= 32768 then z = z - 65536 end
		part.word = (z / hdr.scale > 8) and 'halflife' or 'alyx'
	end
	return true
end

local function logoFrame(fi)
	if LOGO.frame == fi then return LOGO.verts end
	LOGO.frame = fi
	local raw, n, inv = LOGO.raw, LOGO.hdr.verts, 1 / LOGO.hdr.scale
	local o = fi * n * 6 + 1
	for i = 1, n do
		local a, b, c, d, e, f = string.byte(raw, o, o + 5)
		local x, y, z = a + b * 256, c + d * 256, e + f * 256
		if x >= 32768 then x = x - 65536 end
		if y >= 32768 then y = y - 65536 end
		if z >= 32768 then z = z - 65536 end
		LOGO.verts[i]:SetUnpacked(x * inv, y * inv, z * inv)
		o = o + 6
	end
	return LOGO.verts
end

local function drawLogo(alpha)
	if not loadLogo() or alpha <= 0 then return end
	local hdr = LOGO.hdr
	local intro, loop = hdr.seqs[1], hdr.seqs[2]
	local f = math.max(0, math.floor((RealTime() - (S.logoStart or RealTime())) * 30))
	local fi = f < intro.frames and (intro.start + f) or (loop.start + (f - intro.frames) % loop.frames)
	local verts = logoFrame(fi)
	-- logo space: X toward the viewer, Y across (33 units), Z up (10.6 units)
	local base = S.camAng
	local fwd = Vector(base:Forward().x, base:Forward().y, 0):GetNormalized()
	local right = Vector(base:Right().x, base:Right().y, 0):GetNormalized()
	local up = Vector(0, 0, 1)
	local s = 3.4
	local center = S.camPos + fwd * 170 + up * 52
	local m = Matrix()
	m:SetForward(-fwd)
	m:SetRight(-right)
	m:SetUp(up)
	m:SetTranslation(center - right * (16.5 * s) - up * (5.3 * s))
	m:Scale(Vector(s, s, s))
	cam.PushModelMatrix(m)
	local a = math.floor(255 * alpha)
	for pass = 1, 2 do
		local kind = pass == 1 and 'body' or 'face'
		for _, part in ipairs(hdr.parts) do
			if part.kind == kind then
				render.SetMaterial(LOGO_MAT[part.word or 'alyx'][kind])
				local tris, first = part.tris, part.first
				mesh.Begin(MATERIAL_TRIANGLES, #tris / 3)
				for k = 1, #tris do
					mesh.Position(verts[first + tris[k] + 1])
					mesh.Color(255, 255, 255, a)
					mesh.AdvanceVertex()
				end
				mesh.End()
			end
		end
	end
	cam.PopModelMatrix()
end

-- floating gold dust around the panels
local motes = {}
for i = 1, 60 do motes[i] = {math.Rand(-60, 60), math.Rand(10, 90), math.Rand(-30, 30), math.Rand(0.15, 0.6), math.Rand(0, 10)} end

hook.Add('PostDrawTranslucentRenderables', 'HLAMenuDraw', function(depth, sky)
	if sky or S.fade <= 0 or not S.camPos then return end
	local a = smooth(S.fade)
	drawLogo(a)
	local hover = S.open and pick() or nil
	S.hover = hover
	-- slide the panels so the newest one sits a little right of centre
	local n = #S.stack
	for i, p in ipairs(S.stack) do
		local target = (i - n) * 30 + 7
		p.x = Lerp(math.min(1, FrameTime() * 6), p.x, target)
	end
	for i, p in ipairs(S.stack) do
		local def = PANELS[p.id]()
		local center, r, up, nrm = frame(p)
		local w, h = W * SCALE, (def.h + 70) * SCALE
		local origin = center - r * (w * 0.5) + up * (h * 0.5)
		local dim = (i < n) and 0.55 or 1
		cam.Start3D2D(origin, r:AngleEx(nrm), SCALE)
			drawPanel(p, def, i == n and hover or nil, a * dim)
		cam.End3D2D()
	end
	render.SetMaterial(mat('dust'))
	local base = S.camAng
	local f, rt = base:Forward(), base:Right()
	for i, m in ipairs(motes) do
		local t = RealTime() * m[4] + m[5]
		local pos = S.camPos + f * (m[2] + 20) + rt * (m[1] + math.sin(t) * 3) + Vector(0, 0, m[3] + math.cos(t * 0.7) * 2)
		render.DrawSprite(pos, 0.5, 0.5, Color(255, 200, 90, 120 * a))
	end
	-- remove panels that finished closing
	for i = #S.stack, 1, -1 do
		local p = S.stack[i]
		if p.closing and RealTime() - p.closing > 0.3 then table.remove(S.stack, i) end
	end
end)

---------------------------------------------------------------------------------------------------
-- camera, input and the rest of the game while the menu is up
hook.Add('CalcView', 'HLAMenuView', function(p, origin, angles, fov)
	if S.fade <= 0 or not S.camPos then return end
	local mx, my = input.GetCursorPos()
	local want = {(my / math.max(ScrH(), 1) - 0.5) * 5, -(mx / math.max(ScrW(), 1) - 0.5) * 8}
	local k = math.min(1, FrameTime() * 3)
	S.look[1] = Lerp(k, S.look[1], want[1])
	S.look[2] = Lerp(k, S.look[2], want[2])
	local ang = S.camAng + Angle(S.look[1], S.look[2], 0)
	local b = smooth(S.fade)
	return {origin = LerpVector(b, origin, S.camPos), angles = LerpAngle(b, angles, ang), fov = Lerp(b, fov, 70), drawviewer = false}
end)

hook.Add('HUDShouldDraw', 'HLAMenu', function(name)
	if S.fade > 0 and name ~= 'CHudChat' and name ~= 'CHudGMod' then return false end
end)
hook.Add('PreDrawViewModel', 'HLAMenu', function() if S.fade > 0 then return true end end)
hook.Add('OnPauseMenuShow', 'HLAMenu', function()
	if not S.open then return end
	if S.focus then closeInput() return false end
	pop()
	return false
end)

-- black fade at the start and when leaving the menu, plus the screen vignette
hook.Add('HUDPaint', 'HLAMenuFade', function()
	if S.black and S.black > 0 then
		surface.SetDrawColor(0, 0, 0, 255 * smooth(S.black))
		surface.DrawRect(0, 0, ScrW(), ScrH())
	end
	if S.fade > 0 then
		surface.SetMaterial(mat('vignette'))
		surface.SetDrawColor(0, 0, 0, 230 * S.fade)
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
	end
end)

-- background music of the menu (hla_menu_content/sound/hla/hlamenumusic.mp3), fades with the menu
local musicVol = CreateClientConVar('hla_menu_music_volume', '0.5', true, false, 'Main menu music volume (0..1)')
local music, musicLoading
local function updateMusic()
	local want = S.open and math.Clamp(musicVol:GetFloat(), 0, 1) or 0
	if want > 0 and not IsValid(music) and not musicLoading then
		musicLoading = true
		sound.PlayFile('sound/hla/hlamenumusic.mp3', 'noblock noplay', function(ch)
			musicLoading = false
			if not IsValid(ch) then return end
			music = ch
			ch:EnableLooping(true)
			ch:SetVolume(0)
			ch:Play()
		end)
	end
	if IsValid(music) then
		local v = music:GetVolume()
		local target = want * math.Clamp(S.fade, 0, 1)
		v = v + math.Clamp(target - v, -FrameTime() * 0.6, FrameTime() * 0.6)
		music:SetVolume(v)
		if not S.open and v <= 0.001 then music:Stop() music = nil end
	end
end

hook.Add('Think', 'HLAMenu', function()
	updateMusic()
	local dt = FrameTime()
	S.fade = math.Clamp(S.fade + (S.open and dt or -dt) * 1.5, 0, 1)
	if S.black then S.black = math.max(0, S.black - dt * 0.9) end
	if S.open and #S.stack == 0 and RealTime() > (S.mainAt or 0) then push('main') end
	if S.hover then
		local key = S.hover.item and (tostring(S.hover.item.id) .. tostring(S.hover.item.arg) .. tostring(S.hover.side)) or nil
		if key and key ~= S.lastHover then snd('hover') end
		S.lastHover = key
	end
end)

local function makeCatcher()
	if IsValid(catcher) then catcher:Remove() end
	local c = vgui.Create('DTextEntry')
	catcher = c
	c:SetSize(ScrW(), ScrH())
	c:SetPos(0, 0)
	c:SetMultiline(false)
	c:SetAllowNonAsciiCharacters(true) -- Cyrillic names
	c:SetUpdateOnType(true)
	c:SetDrawLanguageID(false)
	c:SetCursor('arrow')
	c.Paint = function() end
	c:MakePopup()
	c:RequestFocus()
	c.OnMouseReleased = function(self, code)
		if code == MOUSE_LEFT then click() elseif code == MOUSE_RIGHT then pop() end
		self:RequestFocus()
		if S.focus then self:SetCaretPos(utf8.len(self:GetText()) or 0) end
	end
	c.AllowInput = function(self)
		if not S.focus then return true end -- nothing selected: ignore typing
		return (utf8.len(self:GetText()) or 0) >= M.NameMax
	end
	c.OnChange = function(self)
		if not S.focus then
			if self:GetText() ~= '' then self:SetText('') end
			return
		end
		local v = self:GetText()
		if v ~= S.form[S.focus] then snd('hover') end
		S.form[S.focus] = v
		S.error = nil
	end
	c.OnEnter = function(self)
		if S.focus == 'first' then focusField('last') else closeInput() end
		self:RequestFocus()
	end
	-- the entry keeps the focus while the menu is up
	c.OnLoseFocus = function(self)
		timer.Simple(0, function() if IsValid(self) and S.open then self:RequestFocus() end end)
	end
end

local function openMenu(chars, pos, ang)
	S.chars = chars
	if S.open then return end
	S.open = true
	S.stack = {}
	S.black = 1
	S.mainAt = RealTime() + 0.6
	S.logoStart = RealTime() + 0.3
	local p = LocalPlayer()
	S.camPos = pos or p:EyePos()
	S.camAng = ang or Angle(0, p:EyeAngles().y, 0)
	makeCatcher()
	snd('click')
end

local function closeMenu()
	S.open = false
	closeInput(false)
	S.black = 1
	for _, p in ipairs(S.stack) do p.closing = p.closing or RealTime() end
	if IsValid(catcher) then catcher:Remove() end
end

net.Receive('hla_menu_open', function()
	local chars = net.ReadTable()
	local pos, ang
	if net.ReadBool() then pos, ang = net.ReadVector(), net.ReadAngle() end
	if S.open then
		S.chars = chars
		if S.sel and not chars[S.sel] then S.sel = nil end
	else
		openMenu(chars, pos, ang)
	end
end)
net.Receive('hla_menu_closed', closeMenu)

hook.Add('InitPostEntity', 'HLAMenuReady', function()
	net.Start('hla_menu_do') net.WriteString('ready') net.SendToServer()
end)
concommand.Add('hla_menu', function()
	net.Start('hla_menu_do') net.WriteString('reopen') net.SendToServer()
end)
