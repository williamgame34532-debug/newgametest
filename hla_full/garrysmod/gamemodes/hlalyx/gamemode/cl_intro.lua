local I = {active = false}
HLA.Intro = I
local cvIntro = CreateClientConVar('hla_intro', '1', true, false, 'The train intro before the main menu (0/1)')

local blink = {t = 0, mode = 0}
function HLA.FadeSwap(fn, dIn, dOut)
	blink.dIn, blink.dOut = dIn or 0.16, dOut or 0.28
	blink.start = RealTime()
	blink.fn = fn
end
hook.Add('PostRenderVGUI', 'HLAFadeSwap', function()
	if not blink.start then return end
	local t = RealTime() - blink.start
	local a
	if t < blink.dIn then a = t / blink.dIn
	else
		if blink.fn then local f = blink.fn blink.fn = nil f() end
		a = 1 - (t - blink.dIn) / blink.dOut
		if a <= 0 then blink.start = nil return end
	end
	surface.SetDrawColor(0, 0, 0, 255 * math.Clamp(a, 0, 1))
	surface.DrawRect(0, 0, ScrW(), ScrH())
end)

local function pick(list)
	for _, name in ipairs(list) do
		local m = Material(name)
		if m and not m:IsError() then
			local tex = m:GetTexture('$basetexture')
			if tex and not tex:IsError() then
				return CreateMaterial('hla_intro_' .. string.gsub(name, '[^%w]', '_'), 'UnlitGeneric',
					{['$basetexture'] = tex:GetName(), ['$vertexcolor'] = 1, ['$model'] = 0})
			end
		end
	end
	return CreateMaterial('hla_intro_plain', 'UnlitGeneric', {['$basetexture'] = 'vgui/white', ['$vertexcolor'] = 1})
end
local MAT
local function mats()
	if MAT then return MAT end
	MAT = {
		wall = pick({'metal/metalwall048b', 'metal/metalwall026a', 'metal/metalwall001a', 'metal/metalcombine001'}),
		floor = pick({'metal/metalfloor005a', 'metal/metalfloor001a', 'metal/metalgrate013a', 'concrete/concretefloor001a'}),
		ceil = pick({'metal/metalceiling005a', 'metal/metalwall048b', 'metal/metalwall001a'}),
		plain = CreateMaterial('hla_intro_plain', 'UnlitGeneric', {['$basetexture'] = 'vgui/white', ['$vertexcolor'] = 1}),
		glow = Material('sprites/light_glow02_add'),
	}
	return MAT
end

local function quad(a, b, c, d, tile, ca, cb, cc, cd)
	local w, h = a:Distance(b) / tile, a:Distance(d) / tile
	mesh.Begin(MATERIAL_QUADS, 1)
		mesh.Position(a) mesh.TexCoord(0, 0, h) mesh.Color(ca.r, ca.g, ca.b, 255) mesh.AdvanceVertex()
		mesh.Position(b) mesh.TexCoord(0, w, h) mesh.Color(cb.r, cb.g, cb.b, 255) mesh.AdvanceVertex()
		mesh.Position(c) mesh.TexCoord(0, w, 0) mesh.Color(cc.r, cc.g, cc.b, 255) mesh.AdvanceVertex()
		mesh.Position(d) mesh.TexCoord(0, 0, 0) mesh.Color(cd.r, cd.g, cd.b, 255) mesh.AdvanceVertex()
	mesh.End()
end

local L, Wd, Hh = 400, 56, 100
local WIN_LO, WIN_HI, WIN_W, WIN_STEP = 44, 80, 72, 120
local SPEED = 900

local function light(x, z, outside)
	local base = 0.30 + 0.28 * math.Clamp(z / Hh, 0, 1)
	for k = -3, 3 do
		local lx = k * 160
		base = base + 0.35 * math.exp(-((x - lx) / 70) ^ 2) * math.Clamp(z / Hh, 0.3, 1)
	end
	local pass = 0
	for _, lx in ipairs(outside) do pass = pass + math.exp(-((x - lx) / 90) ^ 2) end
	return base * (I.flick or 1), pass
end
local function col(x, z, outside, tint)
	local l, pass = light(x, z, outside)
	local r, g, b = tint[1] * l + 60 * pass, tint[2] * l + 110 * pass, tint[3] * l + 150 * pass
	return Color(math.min(255, r), math.min(255, g), math.min(255, b))
end

local function wallStrip(sy, x0, x1, z0, z1, outside, tint)
	local y = sy * Wd
	local step = 40
	local x = x0
	while x < x1 - 0.01 do
		local xn = math.min(x1, x + step)
		local ca, cb = col(x, z0, outside, tint), col(xn, z0, outside, tint)
		local cc, cd = col(xn, z1, outside, tint), col(x, z1, outside, tint)
		if sy > 0 then
			quad(Vector(xn, y, z0), Vector(x, y, z0), Vector(x, y, z1), Vector(xn, y, z1), 64, cb, ca, cd, cc)
		else
			quad(Vector(x, y, z0), Vector(xn, y, z0), Vector(xn, y, z1), Vector(x, y, z1), 64, ca, cb, cc, cd)
		end
		x = xn
	end
end

local function box(mn, mx, c)
	local function q(a, b, cc, d) quad(a, b, cc, d, 64, c, c, c, c) end
	q(Vector(mn.x, mn.y, mx.z), Vector(mx.x, mn.y, mx.z), Vector(mx.x, mx.y, mx.z), Vector(mn.x, mx.y, mx.z))
	q(Vector(mn.x, mn.y, mn.z), Vector(mx.x, mn.y, mn.z), Vector(mx.x, mn.y, mx.z), Vector(mn.x, mn.y, mx.z))
	q(Vector(mx.x, mx.y, mn.z), Vector(mn.x, mx.y, mn.z), Vector(mn.x, mx.y, mx.z), Vector(mx.x, mx.y, mx.z))
	q(Vector(mx.x, mn.y, mn.z), Vector(mx.x, mx.y, mn.z), Vector(mx.x, mx.y, mx.z), Vector(mx.x, mn.y, mx.z))
	q(Vector(mn.x, mx.y, mn.z), Vector(mn.x, mn.y, mn.z), Vector(mn.x, mn.y, mx.z), Vector(mn.x, mx.y, mx.z))
end

local city = {}
local function buildCity()
	if #city > 0 then return end
	local rng = 1337
	local function rnd() rng = (rng * 1103515245 + 12345) % 2147483648 return rng / 2147483648 end
	for side = -1, 1, 2 do
		local x = 0
		while x < 6000 do
			local w = 180 + rnd() * 320
			local b = {side = side, x = x, w = w, h = 300 + rnd() * 900, d = 700 + rnd() * 700, lit = {}}
			for _ = 1, math.floor(rnd() * 7) do
				b.lit[#b.lit + 1] = {u = rnd() * 0.8 + 0.1, v = rnd() * 0.7 + 0.15, warm = rnd() < 0.6}
			end
			city[#city + 1] = b
			x = x + w + 40 + rnd() * 160
		end
	end
end

local function drawOutside(t, half, reach)
	half = half or Wd
	reach = reach or L
	local M = mats()
	render.SetMaterial(M.plain)
	for side = -1, 1, 2 do
		local y = side * 3000
		local a, b = Vector(-9000, y, -400), Vector(9000, y, -400)
		local c, d = Vector(9000, y, 2600), Vector(-9000, y, 2600)
		local lo, hi = Color(22, 34, 46), Color(4, 8, 14)
		if side > 0 then quad(b, a, d, c, 9000, lo, lo, hi, hi) else quad(a, b, c, d, 9000, lo, lo, hi, hi) end
	end
	for _, b in ipairs(city) do
		local x = (b.x - t * SPEED * 0.35) % 6000 - 3000
		local y = b.side * b.d
		local x0, x1 = x, x + b.w
		local c = Color(8, 12, 17)
		local z0, z1 = -300, b.h - 200
		if b.side > 0 then quad(Vector(x1, y, z0), Vector(x0, y, z0), Vector(x0, y, z1), Vector(x1, y, z1), 9000, c, c, c, c)
		else quad(Vector(x0, y, z0), Vector(x1, y, z0), Vector(x1, y, z1), Vector(x0, y, z1), 9000, c, c, c, c) end
		for _, l in ipairs(b.lit) do
			local lx, lz = x0 + b.w * l.u, z0 + (z1 - z0) * l.v
			local lc = l.warm and Color(150, 120, 70) or Color(70, 120, 160)
			local yy = y - b.side * 2
			if b.side > 0 then quad(Vector(lx + 14, yy, lz), Vector(lx, yy, lz), Vector(lx, yy, lz + 18), Vector(lx + 14, yy, lz + 18), 9000, lc, lc, lc, lc)
			else quad(Vector(lx, yy, lz), Vector(lx + 14, yy, lz), Vector(lx + 14, yy, lz + 18), Vector(lx, yy, lz + 18), 9000, lc, lc, lc, lc) end
		end
	end
	local lamps = {}
	local POLE = 420
	for side = -1, 1, 2 do
		local off = side > 0 and 0 or POLE / 2
		for k = -6, 6 do
			local x = ((k * POLE + off - t * SPEED) % (POLE * 13)) - POLE * 6.5
			local y = side * (half + 94)
			local c = Color(6, 8, 10)
			box(Vector(x - 5, y - 5, -200), Vector(x + 5, y + 5, 230), c)
			box(Vector(x - 5, y - side * 40, 220), Vector(x + 5, y, 226), c)
			lamps[#lamps + 1] = {pos = Vector(x, y - side * 36, 216), x = x}
		end
	end
	render.SetMaterial(M.glow)
	for _, l in ipairs(lamps) do
		render.DrawSprite(l.pos, 90, 90, Color(140, 200, 255, 220))
		render.DrawSprite(l.pos, 24, 24, Color(230, 245, 255, 255))
	end
	local near = {}
	for _, l in ipairs(lamps) do if math.abs(l.x) < reach + 200 then near[#near + 1] = l.x end end
	return near
end

local function drawCar(outside)
	local M = mats()
	local tintWall, tintFloor, tintCeil = {120, 140, 150}, {80, 90, 96}, {90, 104, 114}
	render.SetMaterial(M.wall)
	for sy = -1, 1, 2 do
		wallStrip(sy, -L, L, 0, WIN_LO, outside, tintWall)
		wallStrip(sy, -L, L, WIN_HI, Hh, outside, tintWall)
		local x = -L
		for wx = -L + 40, L - WIN_W, WIN_STEP do
			wallStrip(sy, x, wx, WIN_LO, WIN_HI, outside, tintWall)
			x = wx + WIN_W
		end
		wallStrip(sy, x, L, WIN_LO, WIN_HI, outside, tintWall)
	end
	render.SetMaterial(M.floor)
	for x = -L, L - 40, 40 do
		local a, b = col(x, 0, outside, tintFloor), col(x + 40, 0, outside, tintFloor)
		quad(Vector(x, -Wd, 0), Vector(x + 40, -Wd, 0), Vector(x + 40, Wd, 0), Vector(x, Wd, 0), 64, a, b, b, a)
	end
	render.SetMaterial(M.ceil)
	for x = -L, L - 40, 40 do
		local a, b = col(x, Hh, outside, tintCeil), col(x + 40, Hh, outside, tintCeil)
		quad(Vector(x, Wd, Hh), Vector(x + 40, Wd, Hh), Vector(x + 40, -Wd, Hh), Vector(x, -Wd, Hh), 64, a, b, b, a)
	end
	render.SetMaterial(M.wall)
	local e = Color(70, 82, 90)
	quad(Vector(L, -Wd, 0), Vector(L, Wd, 0), Vector(L, Wd, Hh), Vector(L, -Wd, Hh), 64, e, e, e, e)
	quad(Vector(-L, Wd, 0), Vector(-L, -Wd, 0), Vector(-L, -Wd, Hh), Vector(-L, Wd, Hh), 64, e, e, e, e)
	render.SetMaterial(M.plain)
	local dc = Color(30, 38, 44)
	quad(Vector(L - 1, -22, 0), Vector(L - 1, 22, 0), Vector(L - 1, 22, 86), Vector(L - 1, -22, 86), 64, dc, dc, dc, dc)
	local wc = Color(110, 170, 210)
	quad(Vector(L - 2, -12, 50), Vector(L - 2, 12, 50), Vector(L - 2, 12, 76), Vector(L - 2, -12, 76), 64, wc, wc, wc, wc)
	render.SetMaterial(M.wall)
	for sy = -1, 1, 2 do
		local y0, y1 = sy > 0 and Wd - 24 or -Wd, sy > 0 and Wd or -Wd + 24
		for bx = -L + 20, L - 160, 200 do
			box(Vector(bx, y0, 16), Vector(bx + 150, y1, 20), Color(52, 60, 66))
			box(Vector(bx, sy > 0 and Wd - 4 or -Wd, 20), Vector(bx + 150, sy > 0 and Wd or -Wd + 4, 44), Color(46, 54, 60))
			box(Vector(bx + 6, y0 + 4, 0), Vector(bx + 144, y1 - 4, 16), Color(20, 24, 28))
		end
		box(Vector(-L, sy * (Wd - 30) - 1, 86), Vector(L, sy * (Wd - 30) + 1, 88), Color(90, 100, 108))
	end
	render.SetMaterial(M.plain)
	for k = -2, 2 do
		local lx = k * 160
		local c = Color(200, 228, 245)
		quad(Vector(lx - 40, -6, Hh - 1), Vector(lx + 40, -6, Hh - 1), Vector(lx + 40, 6, Hh - 1), Vector(lx - 40, 6, Hh - 1), 64, c, c, c, c)
	end
end

local SND = {
	rumble = {'ambient/machines/train_rumble_loop1.wav', 'plats/ttrain4.wav', 'plats/tram_move.wav', 'ambient/machines/machine6.wav'},
	wheels = {'ambient/machines/train_wheels_loop1.wav', 'plats/ttrain1.wav', 'ambient/machines/city_ventpump_loop1.wav'},
	echo = {'ambient/atmosphere/undercity_loop1.wav', 'ambient/atmosphere/tone_alley.wav', 'ambient/atmosphere/ambience_base.wav'},
	horn = {'ambient/alarms/train_horn2.wav', 'ambient/alarms/train_horn_distant1.wav'},
	clank = {'ambient/materials/metal_stress1.wav', 'ambient/materials/metal_stress2.wav', 'ambient/materials/metal_stress3.wav',
		'physics/metal/metal_box_impact_soft1.wav', 'physics/metal/metal_box_impact_soft2.wav'},
}
local function has(s) return file.Exists('sound/' .. s, 'GAME') end
local function first(list) for _, s in ipairs(list) do if has(s) then return s end end end
local function all(list) local o = {} for _, s in ipairs(list) do if has(s) then o[#o + 1] = s end end return o end

local function startSounds()
	local p = LocalPlayer()
	I.loops = {}
	for key, vol in pairs({rumble = 0.75, wheels = 0.45, echo = 0.5}) do
		local s = first(SND[key])
		if s then
			local cs = CreateSound(p, s)
			cs:SetSoundLevel(0)
			cs:PlayEx(vol, key == 'rumble' and 90 or 100)
			I.loops[#I.loops + 1] = cs
		end
	end
	I.horns, I.clanks = all(SND.horn), all(SND.clank)
	I.nextHorn = RealTime() + 4 + math.random() * 4
	I.nextClank = RealTime() + 1.5
	if p.SetDSP then p:SetDSP(4, false) end
end

local function stopSounds()
	for _, cs in ipairs(I.loops or {}) do cs:FadeOut(1.2) end
	I.loops = {}
	local p = LocalPlayer()
	if IsValid(p) and p.SetDSP then p:SetDSP(0, false) end
end

local TRAIN_CAR = 'models/props_combine/combine_train02b.mdl'
local TRAIN_HEAD = 'models/props_combine/combine_train02a.mdl'
local cvTrain = CreateClientConVar('hla_intro_train', '1', true, false, 'Intro: the HL2 Combine train model (1) or the simple car (0)')
local cvCamX = CreateClientConVar('hla_intro_cam_x', '0.25', true, false, 'Intro camera along the car, 0..1')
local cvCamY = CreateClientConVar('hla_intro_cam_y', '0.32', true, false, 'Intro camera across the car, 0..1')
local cvCamZ = CreateClientConVar('hla_intro_cam_z', '0.45', true, false, 'Intro camera height in the car, 0..1')
local EXTERIOR = 7

local function makeTrain()
	I.cars = {}
	if not cvTrain:GetBool() or not util.IsValidModel(TRAIN_CAR) then return end
	local probe = ClientsideModel(TRAIN_CAR, RENDERGROUP_OPAQUE)
	if not IsValid(probe) then return end
	local mn, mx = probe:GetModelBounds()
	local yaw = 0
	if (mx.y - mn.y) > (mx.x - mn.x) then
		yaw = 90
		mn, mx = Vector(-mx.y, mn.x, mn.z), Vector(-mn.y, mx.x, mx.z)
	end
	local len = mx.x - mn.x
	local cy, cz = (mn.y + mx.y) / 2, mn.z
	I.box = {len = len, half = (mx.y - mn.y) / 2, h = mx.z - mn.z}
	local function place(e, k)
		e:SetNoDraw(true)
		e:SetAngles(Angle(0, yaw, 0))
		e:SetPos(Vector(-(mn.x + mx.x) / 2 + k * (len + 18), -cy, -cz))
		e:SetRenderBounds(Vector(-2000, -2000, -500), Vector(2000, 2000, 800))
		e.HLAK = k
	end
	place(probe, 0)
	I.cars[1] = probe
	for k = -2, 2 do
		if k ~= 0 then
			local mdl = (k == 2 and util.IsValidModel(TRAIN_HEAD)) and TRAIN_HEAD or TRAIN_CAR
			local e = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
			if IsValid(e) then place(e, k) I.cars[#I.cars + 1] = e end
		end
	end
end

local function dropTrain()
	for _, e in ipairs(I.cars or {}) do if IsValid(e) then e:Remove() end end
	I.cars = {}
	I.box = nil
end

local function trainLight(pass, k)
	local b = (0.16 + 0.5 * pass) * k
	render.SuppressEngineLighting(true)
	render.ResetModelLighting(b * 0.55, b * 0.7, b * 0.85)
	render.SetModelLighting(BOX_TOP, b * 1.4, b * 1.6, b * 1.8)
	render.SetModelLighting(BOX_BOTTOM, b * 0.2, b * 0.25, b * 0.3)
end

local function drawTrain(inside, pass)
	if inside then render.CullMode(MATERIAL_CULLMODE_CW) end
	trainLight(pass, inside and 1.2 or 1)
	for _, e in ipairs(I.cars) do
		if IsValid(e) and (not inside or e.HLAK == 0) then e:DrawModel() end
	end
	render.SuppressEngineLighting(false)
	if inside then render.CullMode(MATERIAL_CULLMODE_CCW) end
end

function I.Start(onDone)
	if not cvIntro:GetBool() or I.active then return false end
	buildCity()
	I.active = true
	I.born = RealTime()
	I.leaving = nil
	I.onDone = onDone
	I.monitor = nil
	if util.IsValidModel('models/props_combine/combine_intmonitor001.mdl') then
		I.monitor = ClientsideModel('models/props_combine/combine_intmonitor001.mdl', RENDERGROUP_OPAQUE)
		if IsValid(I.monitor) then
			I.monitor:SetNoDraw(true)
			I.monitor:SetPos(Vector(L - 4, 34, 58))
			I.monitor:SetAngles(Angle(0, 180, 0))
		end
	end
	makeTrain()
	startSounds()
	return true
end

local function finish()
	I.active = false
	stopSounds()
	if IsValid(I.monitor) then I.monitor:Remove() end
	I.monitor = nil
	dropTrain()
	local f = I.onDone
	I.onDone = nil
	if f then f() end
	HLA.FadeSwap(nil, 0.01, 1.2)
end

function I.Leave()
	if not I.active or I.leaving then return end
	I.leaving = RealTime()
	surface.PlaySound('hla/ui/textline_end.wav')
end

concommand.Add('hla_intro_play', function() I.Start(nil) end)

hook.Add('Think', 'HLAIntro', function()
	if not I.active then return end
	if not I.leaving and RealTime() - I.born > 1 and input.IsKeyDown(KEY_SPACE) and not vgui.GetKeyboardFocus() then I.Leave() end
	if I.leaving and RealTime() - I.leaving > 1.3 then finish() return end
	local now = RealTime()
	if now >= I.nextHorn then
		I.nextHorn = now + 14 + math.random() * 16
		if #I.horns > 0 then surface.PlaySound(I.horns[math.random(#I.horns)]) end
	end
	if now >= I.nextClank then
		I.nextClank = now + 2.5 + math.random() * 5
		if #I.clanks > 0 then LocalPlayer():EmitSound(I.clanks[math.random(#I.clanks)], 60, 90 + math.random(20), 0.35) end
	end
end)
hook.Add('PlayerBindPress', 'HLAIntro', function(_, bind)
	if not I.active then return end
	if string.find(bind, 'jump', 1, true) then I.Leave() end
	if string.find(bind, 'messagemode', 1, true) then return end
	return true
end)

surface.CreateFont('hla_intro_hint', {font = 'Exo 2', size = math.max(16, math.floor(ScrH() / 1080 * 24)), weight = 700, extended = true})
surface.CreateFont('hla_intro_small', {font = 'Exo 2', size = math.max(13, math.floor(ScrH() / 1080 * 17)), weight = 700, italic = true, extended = true})
surface.CreateFont('hla_intro_title', {font = 'Exo 2', size = math.max(28, math.floor(ScrH() / 1080 * 64)), weight = 700, extended = true})

hook.Add('RenderScene', 'HLAIntro', function()
	if not I.active then return end
	local t = RealTime() - I.born
	local sway = math.sin(t * 0.9) * 0.8 + math.sin(t * 2.3) * 0.25
	local shake = (math.sin(t * 31) + math.sin(t * 47)) * 0.12
	local B = I.box
	local outsideShot = B and t < EXTERIOR
	local origin, ang
	if not B then
		origin = Vector(-250 + math.sin(t * 0.05) * 6, -22 + sway * 0.6, 60 + shake)
		ang = Angle(4 + math.sin(t * 0.21) * 1.5 + shake * 0.5, 14 + math.sin(t * 0.13) * 6, sway * 0.9)
	elseif outsideShot then
		local k = t / EXTERIOR
		origin = Vector(-B.len * 0.9 + k * B.len * 0.7, -(B.half + 330), B.h * 0.55 + math.sin(t * 0.7) * 4)
		ang = Angle(6 + shake * 0.3, 74 - k * 18, 0)
	else
		local fx, fy, fz = math.Clamp(cvCamX:GetFloat(), 0.05, 0.95), math.Clamp(cvCamY:GetFloat(), 0.05, 0.95), math.Clamp(cvCamZ:GetFloat(), 0.1, 0.9)
		origin = Vector(-B.len / 2 + B.len * fx + math.sin(t * 0.05) * 4, -B.half + 2 * B.half * fy + sway * 0.6, B.h * fz + shake)
		ang = Angle(4 + math.sin(t * 0.21) * 1.5 + shake * 0.5, 12 + math.sin(t * 0.13) * 6, sway * 0.9)
	end
	render.Clear(0, 0, 0, 255, true, true)
	cam.Start3D(origin, ang, 72, 0, 0, ScrW(), ScrH(), 2, 12000)
		I.flick = (math.random() < 0.01) and 0.7 or 1
		if B then
			local outside = drawOutside(t, B.half, B.len / 2)
			local pass = 0
			for _, lx in ipairs(outside) do pass = pass + math.exp(-((lx - origin.x) / 160) ^ 2) end
			drawTrain(not outsideShot, math.min(pass, 1.5) * (I.flick or 1))
		else
			local outside = drawOutside(t)
			drawCar(outside)
		end
		if IsValid(I.monitor) and not B then
			render.SuppressEngineLighting(true)
			render.ResetModelLighting(0.5, 0.6, 0.7)
			I.monitor:DrawModel()
			render.SuppressEngineLighting(false)
		end
	cam.End3D()
	cam.Start2D()
		local W, H = ScrW(), ScrH()
		local bar = math.floor(H * 0.09)
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(0, 0, W, bar)
		surface.DrawRect(0, H - bar, W, bar)
		local k = math.Clamp((t - 1.5) / 2, 0, 1)
		draw.SimpleText('<:: COMBINE TRANSIT  ::  LINE 17', 'hla_intro_small', W * 0.05, bar + H * 0.03, Color(110, 200, 255, 200 * k))
		draw.SimpleText('<:: CITY 17  ::  SECTOR C', 'hla_intro_small', W * 0.05, bar + H * 0.03 + 24, Color(110, 200, 255, 140 * k))
		local tk = math.Clamp((t - 3) / 2, 0, 1) * math.Clamp((14 - t) / 2, 0, 1)
		if tk > 0 then
			draw.SimpleText(string.upper(GAMEMODE and GAMEMODE.Name or 'HALF-LIFE: ALYX'), 'hla_intro_title', W / 2, H * 0.42, Color(226, 240, 250, 230 * tk), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		local pulse = 0.55 + 0.45 * math.sin(RealTime() * 3)
		local hk = math.Clamp((t - 2) / 1.5, 0, 1)
		draw.SimpleText('[ ПРОБЕЛ ]   ПРОДОЛЖИТЬ', 'hla_intro_hint', W / 2, H - bar / 2, Color(170, 230, 255, (120 + 135 * pulse) * hk), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		local black = math.Clamp(1 - t / 2.5, 0, 1)
		if I.box then black = math.max(black, 1 - math.Clamp(math.abs(t - EXTERIOR) / 0.6, 0, 1)) end
		if I.leaving then black = math.max(black, math.Clamp((RealTime() - I.leaving) / 1.1, 0, 1)) end
		if black > 0 then
			surface.SetDrawColor(0, 0, 0, 255 * black)
			surface.DrawRect(0, 0, W, H)
		end
	cam.End2D()
	return true
end)

hook.Add('HUDShouldDraw', 'HLAIntro', function(name) if I.active and name ~= 'CHudChat' then return false end end)
