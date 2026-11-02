local R = HLA.Radial
local RM = {open = false, k = 0, stack = {}, hover = nil}
HLA.RadialMenu = RM

local BLUE = Color(110, 200, 255)
local WHITE = Color(232, 244, 252)
local GREY = Color(150, 178, 198)

local function sc() return math.min(ScrW() / 1920, ScrH() / 1080) end
local fontKey
local function fonts()
	local key = ScrW() .. 'x' .. ScrH()
	if fontKey == key then return end
	fontKey = key
	local s = sc()
	surface.CreateFont('hla_rad_item', {font = 'Tektur', size = math.max(12, math.floor(17 * s)), weight = 600, extended = true, antialias = true})
	surface.CreateFont('hla_rad_title', {font = 'Tektur', size = math.max(14, math.floor(22 * s)), weight = 600, italic = true, extended = true, antialias = true})
	surface.CreateFont('hla_rad_hint', {font = 'Exo 2', size = math.max(11, math.floor(15 * s)), weight = 600, italic = true, extended = true, antialias = true})
end

local function menuItems(id)
	if id == 'root' then
		local out = {{label = 'РУКИ', sub = 'poses'}}
		for i, c in ipairs(R.Phrases) do out[#out + 1] = {label = c.label, sub = 'phr' .. i} end
		return out, 'ДЕЙСТВИЯ ЮНИТА'
	elseif id == 'poses' then
		local out = {}
		local cur = LocalPlayer():GetNW2String('hla_pose', '')
		for _, p in ipairs(R.Poses) do out[#out + 1] = {label = p.label, pose = p.id, on = (cur == p.id) or (cur == '' and p.id == 'none')} end
		return out, 'РУКИ'
	else
		local c = R.Phrases[tonumber(string.match(id, '^phr(%d+)$') or 0)]
		local out = {}
		for _, l in ipairs(c and c.lines or {}) do out[#out + 1] = {label = l, say = l} end
		return out, c and c.label or ''
	end
end

local function can()
	local p = LocalPlayer()
	if not IsValid(p) or not p:Alive() or p:GetNWBool('hla_in_menu') then return false end
	if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or gui.IsConsoleVisible() then return false end
	if HLA.ChatBox and HLA.ChatBox.open then return false end
	if HLA.Tab and HLA.Tab.open then return false end
	return true
end

local function openMenu()
	RM.open = true
	RM.stack = {'root'}
	RM.hover = nil
	RM.born = RealTime()
	gui.EnableScreenClicker(true)
	input.SetCursorPos(ScrW() / 2, ScrH() / 2)
	surface.PlaySound('hla/ui/textline_5.wav')
end

local function closeMenu()
	RM.open = false
	local other = (HLA.ContainerUI and IsValid(HLA.ContainerUI.frame)) or (HLA.Tab and HLA.Tab.open) or (HLA.ChatBox and HLA.ChatBox.open)
	if not other then gui.EnableScreenClicker(false) end
end

local function run(item)
	if not item then return end
	if item.pose then
		net.Start('hla_radial') net.WriteString('pose') net.WriteString(item.pose) net.SendToServer()
	elseif item.say then
		net.Start('hla_radial') net.WriteString('say') net.WriteString(item.say) net.SendToServer()
	end
	surface.PlaySound('hla/ui/textline_end.wav')
end

local wasL, wasR, wasG = false, false, false
hook.Add('Think', 'HLARadial', function()
	local g = input.IsKeyDown(KEY_G)
	local l, r = input.IsMouseDown(MOUSE_LEFT), input.IsMouseDown(MOUSE_RIGHT)
	if not RM.open then
		if g and not wasG and can() then openMenu() RM.toggle = false end
	else
		local me = LocalPlayer()
		if not IsValid(me) or not me:Alive() or me:GetNWBool('hla_in_menu') then closeMenu() return end
		local items = menuItems(RM.stack[#RM.stack])
		local item = RM.hover and items[RM.hover]
		if l and not wasL then
			if item and item.sub then
				RM.stack[#RM.stack + 1] = item.sub
				RM.hover = nil
				surface.PlaySound('hla/ui/textline_6.wav')
			elseif item then
				run(item)
				closeMenu()
			end
		elseif r and not wasR then
			if #RM.stack > 1 then
				table.remove(RM.stack)
				RM.hover = nil
				surface.PlaySound('hla/ui/textline_6.wav')
			else
				closeMenu()
			end
		elseif not g and wasG then
			if RealTime() - (RM.born or 0) < 0.25 then
				RM.toggle = true
			else
				if item and not item.sub then run(item) end
				closeMenu()
			end
		elseif g and not wasG and RM.toggle then
			closeMenu()
		end
	end
	wasL, wasR, wasG = l, r, g
	RM.k = math.Clamp(RM.k + (RM.open and 1 or -1) * FrameTime() * 8, 0, 1)
end)

hook.Add('PlayerBindPress', 'HLARadial', function(_, bind)
	if RM.open and (string.find(bind, '+attack', 1, true) or string.find(bind, 'invnext', 1, true) or string.find(bind, 'invprev', 1, true)) then return true end
end)

local function sector(cx, cy, r0, r1, a0, a1, col)
	local steps = math.max(3, math.ceil((a1 - a0) / 6))
	surface.SetDrawColor(col.r, col.g, col.b, col.a)
	draw.NoTexture()
	for i = 0, steps - 1 do
		local t0 = math.rad(a0 + (a1 - a0) * i / steps)
		local t1 = math.rad(a0 + (a1 - a0) * (i + 1) / steps)
		surface.DrawPoly({
			{x = cx + math.cos(t0) * r1, y = cy + math.sin(t0) * r1},
			{x = cx + math.cos(t1) * r1, y = cy + math.sin(t1) * r1},
			{x = cx + math.cos(t1) * r0, y = cy + math.sin(t1) * r0},
			{x = cx + math.cos(t0) * r0, y = cy + math.sin(t0) * r0},
		})
	end
end

local function wrap(text, font, maxW)
	surface.SetFont(font)
	local rows, cur = {}, ''
	for word in string.gmatch(text, '%S+') do
		local cand = cur == '' and word or (cur .. ' ' .. word)
		if surface.GetTextSize(cand) > maxW and cur ~= '' then rows[#rows + 1] = cur cur = word else cur = cand end
	end
	if cur ~= '' then rows[#rows + 1] = cur end
	return rows
end

hook.Add('HUDPaint', 'HLARadial', function()
	if RM.k <= 0 then return end
	fonts()
	local s = sc()
	local a = RM.k * RM.k * (3 - 2 * RM.k)
	local cx, cy = ScrW() / 2, ScrH() / 2
	local r1 = math.floor(250 * s * (0.85 + 0.15 * a))
	local r0 = math.floor(110 * s)
	local items, title = menuItems(RM.stack[#RM.stack] or 'root')
	local n = math.max(#items, 1)
	local step = 360 / n
	local mx, my = input.GetCursorPos()
	local dx, dy = mx - cx, my - cy
	local dist = math.sqrt(dx * dx + dy * dy)
	if RM.open then
		if dist > r0 * 0.75 then
			local ang = (math.deg(math.atan2(dy, dx)) + 90 + step / 2) % 360
			local h = math.floor(ang / step) + 1
			if h ~= RM.hover then RM.hover = h surface.PlaySound('hla/ui/textline_5.wav') end
		else
			RM.hover = nil
		end
	end
	surface.SetDrawColor(0, 6, 12, 120 * a)
	surface.DrawRect(0, 0, ScrW(), ScrH())
	for i, it in ipairs(items) do
		local a0 = -90 - step / 2 + (i - 1) * step + 1.2
		local a1 = a0 + step - 2.4
		local hot = RM.hover == i
		local rr1 = hot and r1 + math.floor(14 * s) or r1
		sector(cx, cy, r0, rr1, a0, a1, hot and Color(BLUE.r, BLUE.g, BLUE.b, 170 * a) or Color(6, 16, 26, 215 * a))
		sector(cx, cy, rr1 - math.max(2, math.floor(3 * s)), rr1, a0, a1, Color(BLUE.r, BLUE.g, BLUE.b, (hot and 255 or 150) * a))
		if it.on then sector(cx, cy, r0, r0 + math.max(2, math.floor(4 * s)), a0, a1, Color(110, 236, 150, 230 * a)) end
		local mid = math.rad((a0 + a1) / 2)
		local lr = (r0 + rr1) / 2
		local lx, ly = cx + math.cos(mid) * lr, cy + math.sin(mid) * lr
		local maxW = math.max(70 * s, 2 * math.sin(math.rad(math.min(step, 179) / 2)) * lr * 0.85)
		local rows = wrap(it.label, 'hla_rad_item', math.min(maxW, 190 * s))
		local lh = math.floor(19 * s)
		for j, row in ipairs(rows) do
			draw.SimpleText(row, 'hla_rad_item', lx, ly + (j - (#rows + 1) / 2) * lh, hot and Color(4, 14, 24, 255 * a) or Color(WHITE.r, WHITE.g, WHITE.b, 240 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		if it.sub then
			draw.SimpleText('›', 'hla_rad_item', cx + math.cos(mid) * (rr1 - 16 * s), cy + math.sin(mid) * (rr1 - 16 * s), hot and Color(4, 14, 24, 255 * a) or Color(BLUE.r, BLUE.g, BLUE.b, 220 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
	sector(cx, cy, 0, r0 - math.floor(8 * s), 0, 360, Color(4, 12, 20, 230 * a))
	sector(cx, cy, r0 - math.floor(10 * s), r0 - math.floor(8 * s), 0, 360, Color(BLUE.r, BLUE.g, BLUE.b, 160 * a))
	draw.SimpleText(title, 'hla_rad_title', cx, cy - math.floor(14 * s), Color(BLUE.r, BLUE.g, BLUE.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	local sub = RM.hover and items[RM.hover] and (items[RM.hover].sub and 'открыть' or 'выбрать') or (#RM.stack > 1 and 'ПКМ — назад' or 'ПКМ — закрыть')
	draw.SimpleText(sub, 'hla_rad_hint', cx, cy + math.floor(16 * s), Color(GREY.r, GREY.g, GREY.b, 230 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(RM.toggle and 'ЛКМ — выбрать   ·   ПКМ — назад   ·   G — закрыть' or 'ЛКМ — выбрать   ·   ПКМ — назад   ·   отпустите G — выполнить', 'hla_rad_hint', cx, cy + r1 + math.floor(40 * s), Color(GREY.r, GREY.g, GREY.b, 210 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
