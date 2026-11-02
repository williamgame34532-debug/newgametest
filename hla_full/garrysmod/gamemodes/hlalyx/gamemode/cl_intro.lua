local I = {active = false}
HLA.Intro = I
local cvIntro = CreateClientConVar('hla_intro', '1', true, false, 'The dropship intro before the main menu (0/1)')

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

local SHIP = 'models/combine_dropship.mdl'
local BOX = 'models/combine_dropship_container.mdl'
local SND = {
	near = {'npc/combine_gunship/dropship_engine_near_loop1.wav'},
	far = {'npc/combine_gunship/dropship_engine_distant_loop1.wav'},
}
local function has(s) return file.Exists('sound/' .. s, 'GAME') end
local function first(list) for _, s in ipairs(list) do if has(s) then return s end end end

local SIDES = {
	{suffix = 'rt', c = {Vector(1, 1, 1), Vector(1, -1, 1), Vector(1, -1, -1), Vector(1, 1, -1)}},
	{suffix = 'bk', c = {Vector(-1, 1, 1), Vector(1, 1, 1), Vector(1, 1, -1), Vector(-1, 1, -1)}},
	{suffix = 'lf', c = {Vector(-1, -1, 1), Vector(-1, 1, 1), Vector(-1, 1, -1), Vector(-1, -1, -1)}},
	{suffix = 'ft', c = {Vector(1, -1, 1), Vector(-1, -1, 1), Vector(-1, -1, -1), Vector(1, -1, -1)}},
	{suffix = 'up', c = {Vector(-1, 1, 1), Vector(-1, -1, 1), Vector(1, -1, 1), Vector(1, 1, 1)}},
	{suffix = 'dn', c = {Vector(1, 1, -1), Vector(1, -1, -1), Vector(-1, -1, -1), Vector(-1, 1, -1)}},
}

local skyMats
local function skyMaterials()
	if skyMats then return skyMats end
	skyMats = {}
	local name = GetConVarString('sv_skyname')
	if not name or name == '' then name = 'sky_day01_01' end
	for _, side in ipairs(SIDES) do
		local mat
		for _, n in ipairs({'skybox/' .. name .. side.suffix, 'skybox/' .. name .. '_hdr' .. side.suffix, 'skybox/sky_day01_01' .. side.suffix}) do
			local m = Material(n)
			local tex
			if m and not m:IsError() then
				for _, key in ipairs({'$basetexture', '$hdrcompressedtexture', '$hdrbasetexture'}) do
					local t = m:GetTexture(key)
					if t and not t:IsError() then tex = t break end
				end
			end
			if tex and not tex:IsError() then
				mat = CreateMaterial('hla_intro_sky_' .. side.suffix .. '_' .. string.gsub(n, '[^%w]', '_'), 'UnlitGeneric',
					{['$basetexture'] = tex:GetName(), ['$nocull'] = 1, ['$ignorez'] = 1})
				break
			end
		end
		skyMats[side.suffix] = mat or false
	end
	return skyMats
end

local white = Color(255, 255, 255)
local fallbackTop, fallbackBottom = Color(40, 70, 100), Color(150, 170, 185)
local plain = CreateMaterial('hla_intro_plain2', 'UnlitGeneric', {['$basetexture'] = 'vgui/white', ['$vertexcolor'] = 1, ['$nocull'] = 1, ['$ignorez'] = 1})

local function drawSky(origin, yaw)
	local mats = skyMaterials()
	local R = 4000
	for _, side in ipairs(SIDES) do
		local m = mats[side.suffix]
		local c = {}
		for i, v in ipairs(side.c) do
			local r = Vector(v.x, v.y, v.z)
			r:Rotate(Angle(0, yaw or 0, 0))
			c[i] = r
		end
		local top, bottom = white, white
		if not m then
			render.SetMaterial(plain)
			top = side.suffix == 'dn' and fallbackBottom or fallbackTop
			bottom = side.suffix == 'up' and fallbackTop or fallbackBottom
		else
			render.SetMaterial(m)
		end
		local eps = 0.002
		mesh.Begin(MATERIAL_QUADS, 1)
			mesh.Position(origin + c[1] * R) mesh.TexCoord(0, eps, eps) mesh.Color(top.r, top.g, top.b, 255) mesh.AdvanceVertex()
			mesh.Position(origin + c[2] * R) mesh.TexCoord(0, 1 - eps, eps) mesh.Color(top.r, top.g, top.b, 255) mesh.AdvanceVertex()
			mesh.Position(origin + c[3] * R) mesh.TexCoord(0, 1 - eps, 1 - eps) mesh.Color(bottom.r, bottom.g, bottom.b, 255) mesh.AdvanceVertex()
			mesh.Position(origin + c[4] * R) mesh.TexCoord(0, eps, 1 - eps) mesh.Color(bottom.r, bottom.g, bottom.b, 255) mesh.AdvanceVertex()
		mesh.End()
	end
end

local SHIP_POS = Vector(560, 0, -60)
local SKY_SPEED = 3

local function startSounds()
	local p = LocalPlayer()
	I.loops = {}
	for key, vol in pairs({near = 0, far = 0.6}) do
		local s = first(SND[key])
		if s then
			local cs = CreateSound(p, s)
			cs:SetSoundLevel(0)
			cs:PlayEx(vol, 100)
			I.loops[key] = cs
		end
	end
	if p.SetDSP then p:SetDSP(0, false) end
end

local function stopSounds()
	for _, cs in pairs(I.loops or {}) do cs:FadeOut(1.2) end
	I.loops = {}
end

local function makeShip()
	I.ship, I.box = nil, nil
	if not file.Exists(SHIP, 'GAME') then return end
	local e = ClientsideModel(SHIP, RENDERGROUP_OPAQUE)
	if not IsValid(e) then return end
	e:SetNoDraw(true)
	local seq = e:LookupSequence('cargo_idle')
	if not seq or seq < 0 then seq = e:LookupSequence('idle') end
	if seq and seq >= 0 then e:ResetSequence(seq) end
	I.ship = e
	if file.Exists(BOX, 'GAME') then
		local b = ClientsideModel(BOX, RENDERGROUP_OPAQUE)
		if IsValid(b) then b:SetNoDraw(true) I.box = b end
	end
end

local function dropShip()
	if IsValid(I.ship) then I.ship:Remove() end
	if IsValid(I.box) then I.box:Remove() end
	I.ship, I.box = nil, nil
end

function I.Start(onDone)
	if not cvIntro:GetBool() or I.active then return false end
	I.active = true
	I.born = RealTime()
	I.leaving = nil
	I.onDone = onDone
	makeShip()
	makePanel()
	startSounds()
	return true
end

local function finish()
	I.active = false
	stopSounds()
	dropShip()
	if IsValid(I.panel) then I.panel:Remove() end
	I.panel = nil
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
	local L = I.loops or {}
	if L.near then L.near:ChangeVolume(0.8, 0.5) end
	if L.far then L.far:ChangeVolume(0.45, 0.5) end
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

local function drawShip(t)
	if not IsValid(I.ship) then return end
	local pos = SHIP_POS + Vector(math.sin(t * 0.35) * 18, math.sin(t * 0.23) * 10, math.sin(t * 0.9) * 10)
	local a = Angle(4 + math.sin(t * 0.5) * 1.5, 90, math.sin(t * 0.6) * 3)
	render.SetColorModulation(1, 1, 1)
	render.SetBlend(1)
	render.SetLightingOrigin(SHIP_POS)
	render.SuppressEngineLighting(true)
	render.ResetModelLighting(0.45, 0.5, 0.56)
	render.SetModelLighting(BOX_TOP, 0.95, 0.97, 1)
	render.SetModelLighting(BOX_BOTTOM, 0.18, 0.2, 0.24)
	I.ship:SetPos(pos)
	I.ship:SetAngles(a)
	I.ship:FrameAdvance()
	I.ship:SetupBones()
	I.ship:DrawModel()
	if IsValid(I.box) then
		I.box:SetPos(pos)
		I.box:SetAngles(a)
		I.box:SetupBones()
		I.box:DrawModel()
	end
	render.SuppressEngineLighting(false)
end

local function paintIntro(panel, W, H)
	local t = RealTime() - I.born
	local origin = Vector(0, 0, 0)
	local ang = (SHIP_POS - origin):Angle()
	local x, y = panel:LocalToScreen(0, 0)
	cam.Start3D(origin, ang, 60, x, y, W, H, 4, 20000)
		drawSky(origin, -t * SKY_SPEED)
		render.ClearDepth()
		drawShip(t)
	cam.End3D()
	do
		local bar = math.floor(H * 0.09)
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(0, 0, W, bar)
		surface.DrawRect(0, H - bar, W, bar)
		local k = math.Clamp((t - 1.5) / 2, 0, 1)
		draw.SimpleText('<:: COMBINE AIR TRANSPORT  ::  ' .. string.upper(game.GetMap()), 'hla_intro_small', W * 0.05, bar + H * 0.03, Color(110, 200, 255, 200 * k))
		draw.SimpleText('<:: OVERWATCH SECTOR  ::  ' .. os.date('%H:%M'), 'hla_intro_small', W * 0.05, bar + H * 0.03 + 24, Color(110, 200, 255, 140 * k))
		local tk = math.Clamp((t - 3) / 2, 0, 1) * math.Clamp((14 - t) / 2, 0, 1)
		if tk > 0 then
			draw.SimpleText(string.upper(GAMEMODE and GAMEMODE.Name or 'HALF-LIFE: ALYX'), 'hla_intro_title', W / 2, H * 0.42, Color(226, 240, 250, 230 * tk), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		local pulse = 0.55 + 0.45 * math.sin(RealTime() * 3)
		local hk = math.Clamp((t - 2) / 1.5, 0, 1)
		draw.SimpleText('[ ПРОБЕЛ ]   ПРОДОЛЖИТЬ', 'hla_intro_hint', W / 2, H - bar / 2, Color(170, 230, 255, (120 + 135 * pulse) * hk), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		local black = math.Clamp(1 - t / 2.5, 0, 1)
		if I.leaving then black = math.max(black, math.Clamp((RealTime() - I.leaving) / 1.1, 0, 1)) end
		if black > 0 then
			surface.SetDrawColor(0, 0, 0, 255 * black)
			surface.DrawRect(0, 0, W, H)
		end
	end
end

local function makePanel()
	if IsValid(I.panel) then I.panel:Remove() end
	local p = vgui.Create('DPanel')
	p:SetPos(0, 0)
	p:SetSize(ScrW(), ScrH())
	p:SetMouseInputEnabled(false)
	p:SetKeyboardInputEnabled(false)
	p:SetZPos(-100)
	p.Paint = function(self, w, h) paintIntro(self, w, h) end
	I.panel = p
end

hook.Add('RenderScene', 'HLAIntro', function()
	if not I.active then return end
	render.Clear(0, 0, 0, 255, true, true)
	return true
end)

hook.Add('HUDShouldDraw', 'HLAIntro', function(name) if I.active and name ~= 'CHudChat' then return false end end)
