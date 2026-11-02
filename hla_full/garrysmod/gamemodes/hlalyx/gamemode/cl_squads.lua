local SQ = HLA.Squads
local BLUE = HLA.Hud.AMBER_C
local TEXT = Color(196, 232, 248)
local DIM = Color(60, 120, 160)

net.Receive('hla_squads', function()
	local list = {}
	for _ = 1, net.ReadUInt(4) do
		local id = net.ReadUInt(4)
		local s = {id = id, name = net.ReadString(), leader = net.ReadEntity(), members = {}}
		for i = 1, net.ReadUInt(4) do s.members[i] = net.ReadEntity() end
		list[id] = s
	end
	SQ.list = list
end)

local function S() return math.min(ScrW() / 1920, ScrH() / 1080) end
local fontKey
local function fonts()
	local key = ScrW() .. 'x' .. ScrH()
	if fontKey == key then return end
	fontKey = key
	surface.CreateFont('hla_sq', {font = 'Play', size = math.max(13, math.floor(22 * S())), weight = 700, extended = true})
	surface.CreateFont('hla_sq_name', {font = 'Play', size = math.max(18, math.floor(34 * S())), weight = 700, extended = true})
	surface.CreateFont('hla_sq_s', {font = 'Play', size = math.max(12, math.floor(19 * S())), weight = 400, extended = true})
	surface.CreateFont('hla_vis_b', {font = 'Exo 2', size = math.max(14, math.floor(24 * S())), weight = 700, italic = true, extended = true})
	surface.CreateFont('hla_vis_s', {font = 'Exo 2', size = math.max(12, math.floor(18 * S())), weight = 700, italic = true, extended = true})
	surface.CreateFont('hla_combine', {font = 'Combine_alphabet', size = math.max(12, math.floor(22 * S())), weight = 400, extended = true, antialias = true})
	surface.CreateFont('hla_compass', {font = 'IBM Plex Mono', size = math.max(11, math.floor(16 * S())), weight = 500, extended = true})
	surface.CreateFont('hla_bino', {font = 'IBM Plex Mono', size = math.max(12, math.floor(20 * S())), weight = 600, extended = true})
end
surface.CreateFont('hla_mate3d', {font = 'Russo One', size = 42, weight = 400, extended = true, antialias = true})

local function baseHidden()
	local p = LocalPlayer()
	return not IsValid(p) or not p:Alive() or p:GetNWBool('hla_in_menu') or (HLA.Tab and HLA.Tab.fade > 0)
		or (HLA.TerminalFocus and HLA.TerminalFocus.blend > 0) or (CFRework and CFRework.FocusState and CFRework.FocusState.blend > 0)
end
local function hidden() return baseHidden() or (HLA.Binoculars and HLA.Binoculars.k > 0.2) end

local glyphs = Material('hla/hud/glyphs')
local zoneWas, zoneAt
local function line(text, font, x, y, col, right)
	draw.SimpleText(text, font, x, y, col, right and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT)
end
local function rule(x, y, w, col, right)
	local n = 12
	for i = 0, n - 1 do
		local a = col.a * (1 - i / n) ^ 1.6
		surface.SetDrawColor(col.r, col.g, col.b, a)
		local seg = math.ceil(w / n)
		surface.DrawRect(right and (x - (i + 1) * seg) or (x + i * seg), y, seg, 1)
	end
end
local function bracket(x, y, h, col, right)
	surface.SetDrawColor(col.r, col.g, col.b, col.a)
	surface.DrawRect(x, y, 2, h)
	local t = math.max(6, math.floor(h * 0.08))
	surface.DrawRect(right and x - t + 2 or x, y, t, 2)
	surface.DrawRect(right and x - t + 2 or x, y + h - 2, t, 2)
end
local function segments(x, y, n, k, w, h, col, right)
	for i = 0, n - 1 do
		local on = i < math.Round(k * n)
		surface.SetDrawColor(col.r, col.g, col.b, on and 230 or 45)
		local xx = right and (x - (n - i) * (w + 3)) or (x + i * (w + 3))
		surface.DrawRect(xx, y, w, h)
	end
end

hook.Add('HLAHUDPaint', 'HLASquadHUD', function()
	if hidden() then return end
	fonts()
	local s = S()
	local p = LocalPlayer()
	local sq = SQ.Of(p)
	local lh = math.floor(26 * s)
	local GREENC, REDC = Color(110, 236, 150), Color(255, 84, 72)
	local glow = 0.75 + 0.25 * math.sin(RealTime() * 1.7)
	local x0, y0 = math.floor(54 * s), math.floor(42 * s)
	local x, y = x0 + math.floor(14 * s), y0
	line('<:: COMBINE NETWORK STABLE', 'hla_combine', x, y, Color(BLUE.r, BLUE.g, BLUE.b, 230 * glow))
	line('<:: COMBINE UNIT STABLE', 'hla_combine', x, y + math.floor(24 * s), Color(BLUE.r, BLUE.g, BLUE.b, 170))
	y = y + math.floor(58 * s)
	rule(x, y, math.floor(300 * s), Color(BLUE.r, BLUE.g, BLUE.b, 160))
	y = y + math.floor(10 * s)
	if sq then
		line('<:: ' .. string.upper(sq.name), 'hla_vis_b', x, y, Color(BLUE.r, BLUE.g, BLUE.b, 255))
		local alive, total = 0, 0
		for _, m in ipairs(sq.members) do if IsValid(m) then total = total + 1 if m:Alive() then alive = alive + 1 end end end
		y = y + lh + math.floor(12 * s)
		segments(x + math.floor(4 * s), y, math.max(total, 1), total > 0 and alive / total or 0, math.floor(18 * s), math.max(2, math.floor(4 * s)), BLUE)
		y = y + math.floor(12 * s)
		for _, m in ipairs(sq.members) do
			if IsValid(m) then
				local ok = m:Alive()
				local txt = '<:: ' .. string.upper(m:GetNWString('hla_name', m:Nick())) .. (m == sq.leader and ' (К)' or '') .. '  |  ' .. (ok and 'В СТРОЮ' or 'ВЫВЕДЕН')
				line(txt, 'hla_vis_s', x, y, ok and TEXT or REDC)
				y = y + math.floor(22 * s)
			end
		end
	else
		line('<:: ОТРЯД НЕ НАЗНАЧЕН', 'hla_vis_s', x, y, Color(DIM.r + 40, DIM.g + 40, DIM.b + 40, 220))
		y = y + math.floor(22 * s)
	end
	bracket(x0, y0, y - y0 + math.floor(4 * s), Color(BLUE.r, BLUE.g, BLUE.b, 150))
	local rx0, ry0 = ScrW() - math.floor(54 * s), math.floor(42 * s)
	local rx, ry = rx0 - math.floor(14 * s), ry0
	local unit = string.upper(p:GetNWString('hla_name', p:Nick()))
	local zone = HLA.Story and HLA.Story.ZoneAt and HLA.Story.ZoneAt(p:GetPos())
	if zone ~= zoneWas then zoneWas, zoneAt = zone, RealTime() end
	local flash = math.Clamp(1 - (RealTime() - (zoneAt or 0)) / 1.5, 0, 1)
	line('ИНДЕКС БИОСИГНАЛА ::>', 'hla_vis_b', rx, ry, Color(BLUE.r, BLUE.g, BLUE.b, 255), true)
	ry = ry + lh + math.floor(4 * s)
	rule(rx, ry, math.floor(300 * s), Color(BLUE.r, BLUE.g, BLUE.b, 160), true)
	ry = ry + math.floor(8 * s)
	line(unit .. ((sq and sq.leader == p) and ' (К)' or '') .. ' ::>', 'hla_vis_s', rx, ry, TEXT, true)
	ry = ry + math.floor(22 * s)
	line('ЗОНА: ' .. (zone and string.upper(zone) or 'ВНЕ ЗОН') .. ' ::>', 'hla_vis_s', rx, ry,
		Color(TEXT.r + (255 - TEXT.r) * flash, TEXT.g + (255 - TEXT.g) * flash, 255), true)
	ry = ry + math.floor(22 * s)
	local hp = p:Health()
	local okc = hp > 30 and GREENC or REDC
	line('СТАТУС: ' .. (hp > 30 and 'В НОРМЕ' or 'КРИТИЧЕСКИЙ') .. ' ::>', 'hla_vis_s', rx, ry, okc, true)
	ry = ry + math.floor(30 * s)
	segments(rx - math.floor(28 * s), ry, 10, math.Clamp(hp / math.max(p:GetMaxHealth(), 1), 0, 1), math.floor(14 * s), math.max(2, math.floor(4 * s)), okc, true)
	ry = ry + math.floor(18 * s)
	line('ЗАДАЧИ ::>', 'hla_vis_b', rx, ry, Color(BLUE.r, BLUE.g, BLUE.b, 255), true)
	ry = ry + lh + math.floor(4 * s)
	rule(rx, ry, math.floor(200 * s), Color(BLUE.r, BLUE.g, BLUE.b, 120), true)
	ry = ry + math.floor(8 * s)
	local st = HLA.Story and HLA.Story.State and HLA.Story.State()
	local task = st == 'story' and GetGlobal2String('hla_chapter_title', '') or st == 'pvp' and 'ПВП-РАУНД' or nil
	line((task and task ~= '' and string.upper(task) or 'НЕТ АКТИВНЫХ ЗАДАЧ') .. ' ::>', 'hla_vis_s', rx, ry, task and TEXT or REDC, true)
	ry = ry + math.floor(22 * s)
	bracket(rx0 - 2, ry0, ry - ry0 + math.floor(4 * s), Color(BLUE.r, BLUE.g, BLUE.b, 150), true)
	HLA.HudRightBottom = ry + math.floor(20 * s)
end)

local function mates()
	local p = LocalPlayer()
	local sq = SQ.Of(p)
	local out = {}
	if not sq then return out end
	for _, m in ipairs(sq.members) do
		if IsValid(m) and m ~= p and m:Alive() and m:GetPos():DistToSqr(EyePos()) < 4000 * 4000 and not m:GetNoDraw() then out[#out + 1] = m end
	end
	return out
end

local fill = Material('hla/outline/fill')
local rt, comp
local function target()
	if rt then return rt, comp end
	rt = GetRenderTargetEx('hla_outline_fb', ScrW(), ScrH(), RT_SIZE_FULL_FRAME_BUFFER, MATERIAL_RT_DEPTH_SEPARATE, 0, 0, IMAGE_FORMAT_RGBA8888)
	comp = CreateMaterial('hla_outline_comp', 'UnlitGeneric', {['$basetexture'] = rt:GetName(), ['$translucent'] = 1, ['$vertexcolor'] = 1, ['$vertexalpha'] = 1})
	return rt, comp
end

local function drawFlat(list)
	render.MaterialOverride(fill)
	render.SuppressEngineLighting(true)
	render.SetColorModulation(1, 1, 1)
	for _, m in ipairs(list) do
		m:DrawModel()
		local w = m:GetActiveWeapon()
		if IsValid(w) then w:DrawModel() end
	end
	render.SuppressEngineLighting(false)
	render.MaterialOverride()
end

hook.Add('PostDrawEffects', 'HLASquadOutline', function()
	local list = mates()
	if #list == 0 or hidden() then return end
	local t, c = target()
	render.PushRenderTarget(t)
	render.Clear(0, 0, 0, 0, true, true)
	cam.Start3D()
		drawFlat(list)
	cam.End3D()
	render.PopRenderTarget()
	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(255) render.SetStencilTestMask(255)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_REPLACE)
	cam.Start3D()
		render.OverrideColorWriteEnable(true, false)
		drawFlat(list)
		render.OverrideColorWriteEnable(false, false)
	cam.End3D()
	render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
	render.SetStencilPassOperation(STENCIL_KEEP)
	cam.Start2D()
		surface.SetMaterial(c)
		surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 255)
		local w, h = ScrW(), ScrH()
		for _, o in ipairs({{2, 0}, {-2, 0}, {0, 2}, {0, -2}, {1.5, 1.5}, {-1.5, 1.5}, {1.5, -1.5}, {-1.5, -1.5}}) do
			surface.DrawTexturedRect(o[1], o[2], w, h)
		end
	cam.End2D()
	render.SetStencilEnable(false)
end)

hook.Add('PostDrawTranslucentRenderables', 'HLASquadNames', function(_, sky)
	if sky or hidden() then return end
	for _, m in ipairs(mates()) do
		local pos = HLA.TagPos and HLA.TagPos(m) or m:EyePos() + Vector(0, 0, 22)
		local d = pos:Distance(EyePos())
		cam.IgnoreZ(true)
		if HLA.NameTag then HLA.NameTag(pos, string.upper(m:GetNWString('hla_name', m:Nick())), BLUE, 1, math.Clamp(d / 1300, 0.045, 0.45), m) end
		cam.IgnoreZ(false)
	end
end)

local B = {on = false, k = 0}
HLA.Binoculars = B
local overlay = Material('hla/binoculars/overlay')
local function toggle()
	if baseHidden() then B.on = false return end
	B.on = not B.on
	surface.PlaySound(B.on and 'weapons/sniper/sniper_zoomin.wav' or 'weapons/sniper/sniper_zoomout.wav')
end
concommand.Add('hla_binoculars', toggle)
local zoomHeld = false
hook.Add('PlayerBindPress', 'HLABinoculars', function(p, bind, pressed)
	if not string.find(bind, '+zoom', 1, true) then return end
	zoomHeld = pressed
	return true
end)
hook.Add('Think', 'HLABinoculars', function()
	local down = (input.IsKeyDown(KEY_B) or zoomHeld) and not vgui.GetKeyboardFocus() and not gui.IsGameUIVisible() and not gui.IsConsoleVisible()
	if baseHidden() then down = false end
	if down ~= B.on then
		B.on = down
		surface.PlaySound(down and 'weapons/sniper/sniper_zoomin.wav' or 'weapons/sniper/sniper_zoomout.wav')
	end
	B.k = math.Clamp(B.k + (B.on and 1 or -1) * FrameTime() * 5, 0, 1)
end)
hook.Add('CalcView', 'HLABinocularsFOV', function(p, origin, angles, fov)
	if B.k <= 0 then return end
	local view = GAMEMODE:CalcView(p, origin, angles, fov)
	view.fov = Lerp(B.k * B.k * (3 - 2 * B.k), view.fov or fov, (view.fov or fov) / 4)
	return view
end)
hook.Add('AdjustMouseSensitivity', 'HLABinoculars', function() if B.k > 0 then return 1 - B.k * 0.72 end end)
hook.Add('PreDrawViewModel', 'HLABinoculars', function() if B.k > 0.5 then return true end end)

local visorCv = CreateClientConVar('hla_visor', '1', true, false, 'Combine visor overlay (0/1)')
local visor, visorBino = Material('hla/overlay/visor'), Material('hla/overlay/visor_bino')
hook.Add('RenderScreenspaceEffects', 'HLAVisor', function()
	local p = LocalPlayer()
	if not visorCv:GetBool() or not IsValid(p) or not p:Alive() or p:GetNWBool('hla_in_menu') then return end
	if HLA.TerminalFocus and HLA.TerminalFocus.blend > 0.5 then return end
	if p:ShouldDrawLocalPlayer() then return end
	render.SetMaterial(B.k > 0.5 and visorBino or visor)
	render.DrawScreenQuad()
end)

local scan = Material('hla/ui/scanlines')
hook.Add('RenderScreenspaceEffects', 'HLABinoculars', function()
	if B.k <= 0 then return end
	local k = B.k
	DrawColorModify({
		['$pp_colour_addr'] = 0, ['$pp_colour_addg'] = 0.01 * k, ['$pp_colour_addb'] = 0.035 * k,
		['$pp_colour_brightness'] = -0.03 * k, ['$pp_colour_contrast'] = 1 + 0.25 * k, ['$pp_colour_colour'] = 1 - 0.55 * k,
		['$pp_colour_mulr'] = 0, ['$pp_colour_mulg'] = 0.15 * k, ['$pp_colour_mulb'] = 0.4 * k,
	})
	DrawSharpen(0.8 * k, 1.2)
	cam.Start2D()
		surface.SetMaterial(scan)
		surface.SetDrawColor(110, 200, 255, 26 * k)
		surface.DrawTexturedRectUV(0, 0, ScrW(), ScrH(), 0, 0, ScrW() / 64, ScrH() / 64)
	cam.End2D()
end)

local DIRS = {[0] = 'С', [45] = 'СВ', [90] = 'В', [135] = 'ЮВ', [180] = 'Ю', [225] = 'ЮЗ', [270] = 'З', [315] = 'СЗ'}
hook.Add('HUDPaint', 'HLABinocularsOverlay', function()
	if B.k <= 0 then return end
	fonts()
	local a = B.k
	surface.SetMaterial(overlay)
	surface.SetDrawColor(255, 255, 255, 255 * a)
	surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
	local s = S()
	local yaw = (360 - EyeAngles().y + 90) % 360
	local cx, y = ScrW() / 2, math.floor(70 * s)
	local span = 60
	for d = math.floor((yaw - span) / 5) * 5, yaw + span, 5 do
		local x = cx + (d - yaw) / span * 300 * s
		local dd = d % 360
		local big = dd % 15 == 0
		surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 200 * a)
		surface.DrawRect(x, y, 1, big and 12 * s or 6 * s)
		if big then
			draw.SimpleText(DIRS[dd] or tostring(dd), 'hla_compass', x, y + 16 * s, Color(BLUE.r, BLUE.g, BLUE.b, 230 * a), TEXT_ALIGN_CENTER)
		end
	end
	surface.SetDrawColor(TEXT.r, TEXT.g, TEXT.b, 255 * a)
	surface.DrawRect(cx - 1, y - 6 * s, 2, 20 * s)
	local tr = LocalPlayer():GetEyeTrace()
	local m = tr.Hit and math.floor(tr.HitPos:Distance(EyePos()) / 52.5 + 0.5) or nil
	draw.SimpleText('ДАЛЬНОСТЬ :: ' .. (m and (m .. ' М') or '—'), 'hla_bino', cx + 120 * s, ScrH() / 2 + 40 * s, Color(BLUE.r, BLUE.g, BLUE.b, 230 * a))
	draw.SimpleText('УВЕЛИЧЕНИЕ :: 4X', 'hla_bino', cx + 120 * s, ScrH() / 2 + 64 * s, Color(DIM.r, DIM.g, DIM.b, 230 * a))
	if IsValid(tr.Entity) and tr.Entity:IsPlayer() then
		draw.SimpleText('ЦЕЛЬ :: ' .. string.upper(tr.Entity:GetNWString('hla_name', tr.Entity:Nick())), 'hla_bino', cx + 120 * s, ScrH() / 2 + 88 * s, Color(TEXT.r, TEXT.g, TEXT.b, 230 * a))
	end
end)

local ring = Material('hla/ui_blue/crosshair')
hook.Add('HUDShouldDraw', 'HLACrosshair', function(name) if name == 'CHudCrosshair' then return false end end)
hook.Add('InitPostEntity', 'HLACrosshairTFA', function()
	if ConVarExists('cl_tfa_hud_crosshair_enable_custom') then RunConsoleCommand('cl_tfa_hud_crosshair_enable_custom', '0') end
end)
hook.Add('HUDPaint', 'HLACrosshair', function()
	if hidden() or B.k > 0.3 then return end
	local p = LocalPlayer()
	local cx, cy = ScrW() / 2, ScrH() / 2
	if p:ShouldDrawLocalPlayer() then
		if not (HLA.ThirdPerson and HLA.ThirdPerson.Active(p)) then return end
		local x, y, vis = HLA.ThirdPerson.AimScreen()
		if not vis then return end
		cx, cy = x, y
	end
	local size = math.max(10, math.floor(16 * S()))
	surface.SetMaterial(ring)
	surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 220)
	surface.DrawTexturedRect(cx - size / 2, cy - size / 2, size, size)
end)

hook.Add('PlayerFootstep', 'HLAGearRattle', function(p, pos, foot, sound, volume)
	if not IsValid(p) or not p:IsOnGround() then return end
	if p:GetVelocity():Length2D() < p:GetWalkSpeed() * 1.2 then return end
	p:EmitSound('hla/player/gear' .. math.random(1, 4) .. '.wav', 62, math.random(95, 106), 0.55)
end)

local zoneCard = {}
local zcKey
local function zoneFonts()
	local key = ScrW() .. 'x' .. ScrH()
	if zcKey == key then return end
	zcKey = key
	surface.CreateFont('hla_zone_big', {font = 'Exo 2', size = math.max(26, math.floor(58 * S())), weight = 700, italic = true, extended = true})
	surface.CreateFont('hla_zone_small', {font = 'Exo 2', size = math.max(13, math.floor(20 * S())), weight = 700, italic = true, extended = true})
end
local function zup(s) return (CFRework and CFRework.Upper) and CFRework.Upper(s) or string.upper(s) end
local zoneLast
hook.Add('Think', 'HLAZoneCard', function()
	local p = LocalPlayer()
	if not IsValid(p) or not p:Alive() or p:GetNWBool('hla_in_menu') then return end
	local zone = HLA.Story and HLA.Story.ZoneAt and HLA.Story.ZoneAt(p:GetPos())
	if zone == zoneLast then return end
	zoneLast = zone
	if zone then
		zoneCard = {name = zup(zone), t = RealTime()}
		surface.PlaySound('hla/ui/textline_end.wav')
	end
end)
hook.Add('HUDPaint', 'HLAZoneCard', function()
	if not zoneCard.name or baseHidden() then return end
	local age = RealTime() - zoneCard.t
	local life = 4.5
	if age > life then zoneCard = {} return end
	zoneFonts()
	local s = S()
	local a = math.Clamp(math.min(age * 4, (life - age) * 1.5), 0, 1)
	local cx, cy = ScrW() / 2, math.floor(ScrH() * 0.2)
	local name = zoneCard.name
	local n = utf8.len(name) or #name
	local shown = math.min(n, math.floor(math.max(0, age - 0.25) * 28))
	local o = utf8.offset(name, shown + 1)
	local typed = o and string.sub(name, 1, o - 1) or name
	surface.SetFont('hla_zone_big')
	local fw = surface.GetTextSize(name)
	local grow = math.Clamp(age / 0.6, 0, 1)
	grow = grow * grow * (3 - 2 * grow)
	local half = (fw / 2 + math.floor(40 * s)) * grow
	local bandH = math.floor(150 * s)
	for i = 0, 7 do
		local w = (half + math.floor(60 * s)) * (1 - i * 0.09)
		surface.SetDrawColor(0, 6, 12, 22 * a)
		surface.DrawRect(cx - w, cy - bandH / 2 + math.floor(8 * s), w * 2, bandH)
	end
	surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 200 * a)
	surface.DrawRect(cx - half, cy + math.floor(38 * s), half * 2, math.max(1, math.floor(2 * s)))
	local tick = math.floor(10 * s)
	surface.DrawRect(cx - half, cy + math.floor(38 * s) - tick + 2, math.max(2, math.floor(2 * s)), tick)
	surface.DrawRect(cx + half - math.max(2, math.floor(2 * s)), cy + math.floor(38 * s) - tick + 2, math.max(2, math.floor(2 * s)), tick)
	draw.SimpleText('<:: ВХОД В ЗОНУ ::>', 'hla_zone_small', cx, cy - math.floor(52 * s), Color(BLUE.r, BLUE.g, BLUE.b, 230 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(typed, 'hla_zone_big', cx - fw / 2 + 2, cy + 2, Color(0, 8, 16, 120 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(typed, 'hla_zone_big', cx - fw / 2, cy, Color(232, 244, 252, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	local sub = os.date('%H:%M') .. '  ::  ' .. string.upper(LocalPlayer():GetNWString('hla_name', ''))
	draw.SimpleText(sub, 'hla_zone_small', cx, cy + math.floor(62 * s), Color(170, 196, 214, 200 * a * grow), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
