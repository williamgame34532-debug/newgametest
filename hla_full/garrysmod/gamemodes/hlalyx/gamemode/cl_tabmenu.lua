-- Tab menu in the style of the HL:A menu, drawn in the world in front of the player (3D2D).
-- The camera does not move: the player stands, the mouse drives a cursor on the panel.
-- Pages: root (Инвентарь / Помощь / Главное меню), inventory (4 x 4 + item info), help.
-- From the inventory a health vial goes into «placement»: a ghost vial follows the aim and snaps
-- into a health station; LMB puts it in.
local I = HLA.Items
local T = {open = false, page = 'root', cursor = {450, 260}, sel = nil, moveFrom = nil, fade = 0}
HLA.Tab = T

local W, H = 900, 520
local SCALE = 0.03          -- 27 x 15.6 units
local DIST = 28
local GOLD = Color(238, 206, 140)
local GOLD_HI = Color(255, 246, 222)
local GOLD_DIM = Color(196, 156, 86)
local DARK = Color(20, 14, 6)

local mats = {}
local function mat(n) mats[n] = mats[n] or Material('hla/ui/' .. n) return mats[n] end
local function tex(n, x, y, w, h, c, a)
	surface.SetMaterial(mat(n))
	surface.SetDrawColor(c.r, c.g, c.b, (c.a or 255) * a)
	surface.DrawTexturedRect(x, y, w, h)
end
local function click(kind)
	local list = kind == 'press' and {'hla/ui/textline_end.wav'} or {'hla/ui/textline_5.wav', 'hla/ui/textline_6.wav'}
	local s = list[math.random(#list)]
	if file.Exists('sound/' .. s, 'GAME') then surface.PlaySound(s) else surface.PlaySound('buttons/lightswitch2.wav') end
end

surface.CreateFont('hlat_big', {font = 'Roboto Condensed', size = 34, weight = 700, extended = true})
surface.CreateFont('hlat_mid', {font = 'Roboto Condensed', size = 24, weight = 700, extended = true})
surface.CreateFont('hlat_small', {font = 'Roboto Condensed', size = 17, weight = 500, extended = true})

-- inventory as sent by the server
T.inv = {}
net.Receive('hla_inv', function()
	for i = 1, I.Slots do
		local id = net.ReadString()
		T.inv[i] = id ~= '' and id or nil
	end
end)

local function send(what, a, b)
	net.Start('hla_inv_do')
	net.WriteString(what)
	if a then net.WriteUInt(a, 5) end
	if isnumber(b) then net.WriteUInt(b, 5) elseif b then net.WriteEntity(b) end
	net.SendToServer()
end

---------------------------------------------------------------------------------------------------
-- layout: buttons per page, in canvas pixels
local GRID = {x = 40, y = 80, cell = 92, gap = 8}
local function slotRect(i)
	local c, r = (i - 1) % 4, math.floor((i - 1) / 4)
	return GRID.x + c * (GRID.cell + GRID.gap), GRID.y + r * (GRID.cell + GRID.gap), GRID.cell, GRID.cell
end

local function buttons()
	local b = {}
	if T.page == 'root' then
		b[#b + 1] = {id = 'inventory', label = 'ИНВЕНТАРЬ', x = 300, y = 120, w = 560, h = 70}
		b[#b + 1] = {id = 'help', label = 'ПОМОЩЬ', x = 300, y = 200, w = 560, h = 70}
		b[#b + 1] = {id = 'mainmenu', label = 'ГЛАВНОЕ МЕНЮ', x = 300, y = 280, w = 560, h = 70}
		b[#b + 1] = {id = 'close', label = 'ЗАКРЫТЬ', x = 300, y = 360, w = 560, h = 70}
	elseif T.page == 'inventory' then
		for i = 1, I.Slots do
			local x, y, w, h = slotRect(i)
			b[#b + 1] = {id = 'slot', arg = i, x = x, y = y, w = w, h = h}
		end
		local id = T.sel and T.inv[T.sel]
		local d = id and I.Get(id)
		if d then
			local useLabel = d.use == 'place' and 'ВСТАВИТЬ В СТАНЦИЮ' or 'ИСПОЛЬЗОВАТЬ'
			b[#b + 1] = {id = 'use', label = useLabel, x = 470, y = 330, w = 400, h = 56}
			b[#b + 1] = {id = 'drop', label = 'ВЫБРОСИТЬ', x = 470, y = 394, w = 400, h = 56}
		end
		b[#b + 1] = {id = 'back', label = 'НАЗАД', x = 720, y = 462, w = 150, h = 44}
	elseif T.page == 'help' then
		b[#b + 1] = {id = 'back', label = 'НАЗАД', x = 720, y = 462, w = 150, h = 44}
	end
	return b
end

local function hovered()
	local x, y = T.cursor[1], T.cursor[2]
	for _, b in ipairs(buttons()) do
		if x >= b.x and y >= b.y and x <= b.x + b.w and y <= b.y + b.h then return b end
	end
end

---------------------------------------------------------------------------------------------------
function T.Open()
	if T.open or T.placing then return end
	local p = LocalPlayer()
	if not IsValid(p) or not p:Alive() or p:GetNWBool('hla_in_menu') then return end
	if CFRework and CFRework.FocusEnt and CFRework.FocusEnt() then return end
	T.open, T.page, T.sel, T.moveFrom = true, 'root', nil, nil
	T.cursor = {W / 2, H / 2}
	local ang = Angle(0, p:EyeAngles().y, 0)
	T.pos = p:EyePos() + ang:Forward() * DIST + Vector(0, 0, -2)
	T.ang = Angle(0, ang.y - 90, 90)
	T.right = ang:Right()
	click('press')
end

function T.Close()
	if not T.open then return end
	T.open = false
	T.holdFire = true
	click('hover')
end

function GM:ScoreboardShow()
	if T.placing then T.placing = nil return end
	if T.open then T.Close() else T.Open() end
end
function GM:ScoreboardHide() end

local function activate(b)
	if not b then return end
	click('press')
	if b.id == 'inventory' or b.id == 'help' then T.page = b.id T.sel = nil
	elseif b.id == 'mainmenu' then T.Close() RunConsoleCommand('hla_menu')
	elseif b.id == 'close' then T.Close()
	elseif b.id == 'back' then
		if T.page == 'root' then T.Close() else T.page = 'root' end
	elseif b.id == 'slot' then
		local i = b.arg
		if T.moveFrom and T.moveFrom ~= i then
			send('move', T.moveFrom, i)
			T.sel, T.moveFrom = i, nil
		elseif T.inv[i] then
			if T.sel == i then T.moveFrom = i else T.sel, T.moveFrom = i, nil end
		else
			T.sel, T.moveFrom = nil, nil
		end
	elseif b.id == 'use' and T.sel then
		local d = I.Get(T.inv[T.sel])
		if d and d.use == 'place' then
			T.placing = {slot = T.sel, id = T.inv[T.sel]}
			T.Close()
		else
			send('use', T.sel)
		end
	elseif b.id == 'drop' and T.sel then
		send('drop', T.sel)
		T.sel = nil
	end
end

-- input: the cursor follows the mouse, no movement or shooting while the panel is up
hook.Add('InputMouseApply', 'HLATab', function(cmd, x, y)
	if not T.open then return end
	T.cursor[1] = math.Clamp(T.cursor[1] + x * 0.6, 0, W)
	T.cursor[2] = math.Clamp(T.cursor[2] + y * 0.6, 0, H)
	cmd:SetMouseX(0) cmd:SetMouseY(0)
	return true
end)

local wasL, wasR, lastHover
hook.Add('CreateMove', 'HLATab', function(cmd)
	local btn = cmd:GetButtons()
	local L, R = bit.band(btn, IN_ATTACK) ~= 0, bit.band(btn, IN_ATTACK2) ~= 0
	if T.open then
		if L and not wasL then activate(hovered()) end
		if R and not wasR then
			if T.page == 'root' then T.Close() else T.page = 'root' click('press') end
		end
		cmd:ClearMovement()
		cmd:SetButtons(0)
	elseif T.placing then
		if L and not wasL and T.target then
			send('place', T.placing.slot, T.target)
			T.placing = nil
			T.holdFire = true
		elseif R and not wasR then
			T.placing = nil
			T.holdFire = true
		end
		cmd:SetButtons(bit.band(btn, bit.bnot(bit.bor(IN_ATTACK, IN_ATTACK2))))
	elseif T.holdFire then
		if L or R then cmd:SetButtons(bit.band(btn, bit.bnot(bit.bor(IN_ATTACK, IN_ATTACK2)))) else T.holdFire = nil end
	end
	wasL, wasR = L, R
end)

hook.Add('Think', 'HLATabHover', function()
	if not T.open then lastHover = nil return end
	local b = hovered()
	local k = b and (b.id .. (b.arg or '')) or nil
	if k and k ~= lastHover then click('hover') end
	lastHover = k
end)

hook.Add('HUDShouldDraw', 'HLATab', function(name)
	if T.open and name ~= 'CHudGMod' then return false end
end)
hook.Add('PreDrawViewModel', 'HLATab', function() if T.open then return true end end)

---------------------------------------------------------------------------------------------------
-- drawing
local icons = {}
local function iconModel(id)
	local m = icons[id]
	if IsValid(m) then return m end
	m = ClientsideModel(I.Model(id), RENDERGROUP_OPAQUE)
	if not IsValid(m) then return end
	m:SetNoDraw(true)
	icons[id] = m
	return m
end

local function button(b, label, hot, a)
	if hot then tex('row_hover', b.x, b.y, b.w, b.h, Color(255, 255, 255), a) end
	draw.SimpleText(label, 'hlat_big', b.x + b.w - 30, b.y + b.h / 2, Color(GOLD_HI.r, GOLD_HI.g, GOLD_HI.b, 255 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	tex('line', b.x + 10, b.y + b.h - 2, b.w - 20, 2, Color(255, 255, 255), a * 0.5)
end

local function wrap(text, font, x, y, w, col)
	surface.SetFont(font)
	local line = ''
	for word in string.gmatch(text, '%S+') do
		local cand = line == '' and word or line .. ' ' .. word
		if surface.GetTextSize(cand) > w and line ~= '' then
			draw.SimpleText(line, font, x, y, col) y = y + 22 line = word
		else line = cand end
	end
	if line ~= '' then draw.SimpleText(line, font, x, y, col) end
end

local HELP = {
	'TAB — это меню. ПКМ — назад.',
	'E по предмету (удерживать) — подобрать в инвентарь.',
	'Инвентарь: клик по предмету — сведения справа;',
	'  клик ещё раз — переложить, затем клик по другой ячейке.',
	'Колба с личинкой: «Вставить в станцию», наведитесь на станцию',
	'  первой помощи и нажмите ЛКМ. Удерживайте E у станции — лечение.',
	'  Пустую колбу — E по ней, она выпадет.',
	'Фабрикатор: E по корпусу — он раскроется. E по экрану — терминал.',
	'Смола: падает с врагов и из ящиков, нужна фабрикатору.',
}

local function drawPanel(a)
	local white = Color(255, 255, 255)
	tex('header', 0, 0, W, 40, white, a)
	local title = T.page == 'inventory' and 'ИНВЕНТАРЬ' or T.page == 'help' and 'ПОМОЩЬ' or 'МЕНЮ'
	draw.SimpleText(title, 'hlat_small', W - 16, 20, Color(DARK.r, DARK.g, DARK.b, 255 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	tex('panel_bg', 0, 40, W, H - 40, white, a)
	local hot = hovered()
	if T.page == 'root' then
		for _, b in ipairs(buttons()) do button(b, b.label, hot == b, a) end
		draw.SimpleText(string.upper(LocalPlayer():GetNWString('hla_name', '')), 'hlat_mid', 40, 80, Color(GOLD.r, GOLD.g, GOLD.b, 255 * a))
	elseif T.page == 'inventory' then
		for i = 1, I.Slots do
			local x, y, w, h = slotRect(i)
			local on = T.sel == i
			surface.SetDrawColor(GOLD.r, GOLD.g, GOLD.b, (on and 200 or (hot and hot.arg == i and 120 or 50)) * a)
			surface.DrawOutlinedRect(x, y, w, h, on and 3 or 1)
			if T.moveFrom == i then
				surface.SetDrawColor(GOLD_HI.r, GOLD_HI.g, GOLD_HI.b, 90 * a)
				surface.DrawRect(x, y, w, h)
			end
		end
		local id = T.sel and T.inv[T.sel]
		local d = id and I.Get(id)
		if d then
			draw.SimpleText(string.upper(d.name), 'hlat_big', 470, 84, Color(GOLD_HI.r, GOLD_HI.g, GOLD_HI.b, 255 * a))
			wrap(d.text, 'hlat_small', 470, 132, 400, Color(GOLD.r, GOLD.g, GOLD.b, 230 * a))
			if T.moveFrom then
				draw.SimpleText('ВЫБЕРИТЕ ЯЧЕЙКУ, КУДА ПЕРЕЛОЖИТЬ', 'hlat_small', 470, 300, Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 255 * a))
			end
		else
			draw.SimpleText('ВЫБЕРИТЕ ПРЕДМЕТ', 'hlat_mid', 470, 84, Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 255 * a))
		end
		for _, b in ipairs(buttons()) do
			if b.id ~= 'slot' then button(b, b.label, hot == b, a) end
		end
	elseif T.page == 'help' then
		for i, line in ipairs(HELP) do draw.SimpleText(line, 'hlat_small', 40, 70 + (i - 1) * 34, Color(GOLD.r, GOLD.g, GOLD.b, 240 * a)) end
		for _, b in ipairs(buttons()) do button(b, b.label, hot == b, a) end
	end
	-- cursor
	local cx, cy = T.cursor[1], T.cursor[2]
	surface.SetDrawColor(GOLD_HI.r, GOLD_HI.g, GOLD_HI.b, 255 * a)
	surface.DrawRect(cx - 8, cy - 1, 16, 2)
	surface.DrawRect(cx - 1, cy - 8, 2, 16)
end

-- item models standing in the slots, slowly turning
local function drawIcons()
	if T.page ~= 'inventory' then return end
	local origin = T.pos
	for i = 1, I.Slots do
		local id = T.inv[i]
		if id then
			local m = iconModel(id)
			if IsValid(m) then
				local x, y, w, h = slotRect(i)
				local cx, cy = x + w / 2, y + h / 2
				local world = origin + T.right * ((cx - W / 2) * SCALE) + Vector(0, 0, -(cy - H / 2) * SCALE)
				local fwd = (EyePos() - world):GetNormalized()
				world = world + fwd * 1.5
				local rad = m:GetModelRadius() or 5
				local s = math.Clamp((GRID.cell * SCALE * 0.42) / math.max(rad, 0.1), 0.05, 2)
				m:SetModelScale(s, 0)
				m:SetAngles(Angle(0, (CurTime() * 40 + i * 30) % 360, 0))
				local off = m:OBBCenter() * s
				m:SetPos(world - LocalToWorld(off, angle_zero, vector_origin, m:GetAngles()))
				m:SetupBones()
				m:DrawModel()
			end
		end
	end
end

hook.Add('PostDrawTranslucentRenderables', 'HLATab', function(depth, sky)
	if sky then return end
	T.fade = math.Clamp(T.fade + (T.open and FrameTime() * 5 or -FrameTime() * 6), 0, 1)
	if T.fade <= 0 or not T.pos then return end
	local corner = T.pos - T.right * (W / 2 * SCALE) + Vector(0, 0, H / 2 * SCALE)
	cam.IgnoreZ(true)
	cam.Start3D2D(corner, T.ang, SCALE)
		drawPanel(T.fade)
	cam.End3D2D()
	if T.open then drawIcons() end
	cam.IgnoreZ(false)
end)

---------------------------------------------------------------------------------------------------
-- placement of a vial into a health station
local ghostMat = Material('cf_rework/holo/hologram')
local ghost
hook.Add('PostDrawTranslucentRenderables', 'HLAPlace', function(depth, sky)
	if sky or not T.placing then T.target = nil return end
	local p = LocalPlayer()
	if not p:Alive() or T.inv[T.placing.slot] ~= T.placing.id then T.placing = nil return end
	if not IsValid(ghost) or ghost.id ~= T.placing.id then
		if IsValid(ghost) then ghost:Remove() end
		ghost = ClientsideModel(I.Model(T.placing.id), RENDERGROUP_TRANSLUCENT)
		if not IsValid(ghost) then return end
		ghost:SetNoDraw(true)
		ghost.id = T.placing.id
	end
	local tr = p:GetEyeTrace()
	local e = tr.Entity
	if IsValid(e) and IsValid(e:GetParent()) and e:GetParent().VialSlot then e = e:GetParent() end
	local pos, ang
	T.target = nil
	if IsValid(e) and e.VialSlot and tr.HitPos:DistToSqr(p:EyePos()) < 120 * 120 then
		pos, ang = e:VialSlot()
		if pos and e:CanTakeVial() then T.target = e end
	end
	if not pos then
		pos = p:EyePos() + p:GetAimVector() * 30
		ang = Angle(0, p:EyeAngles().y + 90, 0)
	end
	ghost:SetPos(pos)
	ghost:SetAngles(ang)
	ghost:SetupBones()
	if T.target then
		ghost:DrawModel()
	else
		render.MaterialOverride(ghostMat)
		render.SetColorModulation(0.6, 0.9, 1)
		ghost:DrawModel()
		render.SetColorModulation(1, 1, 1)
		render.MaterialOverride()
	end
end)

hook.Add('HUDPaint', 'HLAPlaceHint', function()
	if not T.placing then return end
	local text = T.target and 'ЛКМ — ВСТАВИТЬ КОЛБУ   ·   ПКМ — ОТМЕНА' or 'НАВЕДИТЕСЬ НА СТАНЦИЮ ПЕРВОЙ ПОМОЩИ   ·   ПКМ — ОТМЕНА'
	draw.SimpleTextOutlined(text, 'hla_label', ScrW() / 2, ScrH() * 0.62, Color(241, 196, 61), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 160))
end)
