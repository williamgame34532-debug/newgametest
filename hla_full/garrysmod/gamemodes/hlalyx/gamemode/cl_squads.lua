-- Squad on the HUD (top right), squad mates outlined in blue with their name over the head,
-- Combine binoculars (the zoom key), the ring crosshair, gear rattle while running.
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
	surface.CreateFont('hla_compass', {font = 'IBM Plex Mono', size = math.max(11, math.floor(16 * S())), weight = 500, extended = true})
	surface.CreateFont('hla_bino', {font = 'IBM Plex Mono', size = math.max(12, math.floor(20 * S())), weight = 600, extended = true})
end
surface.CreateFont('hla_mate3d', {font = 'Russo One', size = 42, weight = 400, extended = true, antialias = true})

local function hidden()
	local p = LocalPlayer()
	return not IsValid(p) or not p:Alive() or p:GetNWBool('hla_in_menu') or (HLA.Tab and HLA.Tab.fade > 0)
		or (HLA.TerminalFocus and HLA.TerminalFocus.blend > 0) or (CFRework and CFRework.FocusState and CFRework.FocusState.blend > 0)
end

---------------------------------------------------------------------------------------------------
-- top left of the visor, as on the Combine screens: Combine glyphs, ОТРЯД :: / ЮНИТ :: and the squad
local glyphs = Material('hla/hud/glyphs')
hook.Add('HLAHUDPaint', 'HLASquadHUD', function()
	if hidden() then return end
	fonts()
	local s = S()
	local p = LocalPlayer()
	local sq = SQ.Of(p)
	local lh = math.floor(24 * s)
	-- left
	local x, y = math.floor(70 * s), math.floor(46 * s)
	surface.SetMaterial(glyphs)
	surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 210)
	surface.DrawTexturedRectUV(x, y, math.floor(330 * s), math.floor(62 * s), 0, 0, 0.32, 0.333)
	y = y + math.floor(86 * s)
	-- the squad: a small label, the name large on its own line
	draw.SimpleText('ОТРЯД', 'hla_sq_s', x, y, Color(BLUE.r, BLUE.g, BLUE.b, 170))
	y = y + math.floor(20 * s)
	draw.SimpleText(sq and sq.name or 'НЕ НАЗНАЧЕН', 'hla_sq_name', x, y, sq and TEXT or Color(BLUE.r, BLUE.g, BLUE.b, 150))
	y = y + math.floor(40 * s)
	draw.SimpleText('ЮНИТ  ·  ' .. string.upper(p:GetNWString('hla_name', p:Nick())), 'hla_sq', x, y, BLUE)
	if sq then
		y = y + lh + math.floor(8 * s)
		for _, m in ipairs(sq.members) do
			if IsValid(m) and m ~= p then
				local name = string.upper(m:GetNWString('hla_name', m:Nick())) .. (m == sq.leader and '  [К]' or '')
				draw.SimpleText('   ' .. name, 'hla_sq_s', x, y, m:Alive() and TEXT or Color(220, 90, 80))
				y = y + math.floor(20 * s)
			end
		end
	end
end)

---------------------------------------------------------------------------------------------------
-- outline: the squad mates are drawn flat white (through walls) into a render target, the screen
-- gets that silhouette shifted around in blue, except where the mates themselves are (stencil)
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
	-- 1) silhouettes into the render target
	render.PushRenderTarget(t)
	render.Clear(0, 0, 0, 0, true, true)
	cam.Start3D()
		drawFlat(list)
	cam.End3D()
	render.PopRenderTarget()
	-- 2) stencil: where the mates are
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
	-- 3) the blue edge around them
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

-- the name of a squad mate over the head, always (other players only when looked at, see cl_world)
hook.Add('PostDrawTranslucentRenderables', 'HLASquadNames', function(_, sky)
	if sky or hidden() then return end
	for _, m in ipairs(mates()) do
		local bone = m:LookupBone('ValveBiped.Bip01_Head1')
		local pos = (bone and m:GetBonePosition(bone) or m:EyePos()) + Vector(0, 0, 16)
		local d = pos:Distance(EyePos())
		local sc = math.Clamp(d / 900, 0.06, 0.6)
		cam.IgnoreZ(true)
		cam.Start3D2D(pos, Angle(0, EyeAngles().y - 90, 90), sc)
			draw.SimpleTextOutlined(string.upper(m:GetNWString('hla_name', m:Nick())), 'hla_mate3d', 0, 0, BLUE, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, Color(0, 8, 14, 200))
		cam.End3D2D()
		cam.IgnoreZ(false)
	end
end)

---------------------------------------------------------------------------------------------------
-- Combine binoculars: B or the zoom key (Z, «+zoom»), or the console command hla_binoculars:
-- zoom 4x with the visor overlay, a blue picture, scanlines, a compass, range and the target's name
local B = {on = false, k = 0}
HLA.Binoculars = B
local overlay = Material('hla/binoculars/overlay')
local function toggle()
	if hidden() then B.on = false return end
	B.on = not B.on
	surface.PlaySound(B.on and 'weapons/sniper/sniper_zoomin.wav' or 'weapons/sniper/sniper_zoomout.wav')
end
concommand.Add('hla_binoculars', toggle)
hook.Add('PlayerBindPress', 'HLABinoculars', function(p, bind, pressed)
	if not pressed or not string.find(bind, '+zoom', 1, true) then return end
	toggle()
	return true
end)
local keyWas = false
hook.Add('Think', 'HLABinoculars', function()
	-- B, when nothing is typed into
	local down = input.IsKeyDown(KEY_B) and not vgui.GetKeyboardFocus() and not gui.IsGameUIVisible() and not gui.IsConsoleVisible()
	if down and not keyWas then toggle() end
	keyWas = down
	if B.on and hidden() then B.on = false end
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

-- the visor of the unit's mask: the glass only tints the picture (blue rounded edges), nothing is
-- bent, the HUD is drawn later on top of it. hla_visor 0 = off.
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

-- the picture through the visor: cold blue, harder contrast, scanlines
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
	-- compass strip at the top
	local yaw = (360 - EyeAngles().y + 90) % 360 -- 0 = north (map +Y)
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
	-- range to what is in the middle
	local tr = LocalPlayer():GetEyeTrace()
	local m = tr.Hit and math.floor(tr.HitPos:Distance(EyePos()) / 52.5 + 0.5) or nil
	draw.SimpleText('ДАЛЬНОСТЬ :: ' .. (m and (m .. ' М') or '—'), 'hla_bino', cx + 120 * s, ScrH() / 2 + 40 * s, Color(BLUE.r, BLUE.g, BLUE.b, 230 * a))
	draw.SimpleText('УВЕЛИЧЕНИЕ :: 4X', 'hla_bino', cx + 120 * s, ScrH() / 2 + 64 * s, Color(DIM.r, DIM.g, DIM.b, 230 * a))
	if IsValid(tr.Entity) and tr.Entity:IsPlayer() then
		draw.SimpleText('ЦЕЛЬ :: ' .. string.upper(tr.Entity:GetNWString('hla_name', tr.Entity:Nick())), 'hla_bino', cx + 120 * s, ScrH() / 2 + 88 * s, Color(TEXT.r, TEXT.g, TEXT.b, 230 * a))
	end
end)

---------------------------------------------------------------------------------------------------
-- crosshair: a small ring instead of the standard cross
local ring = Material('hla/ui_blue/crosshair')
hook.Add('HUDShouldDraw', 'HLACrosshair', function(name) if name == 'CHudCrosshair' then return false end end)
hook.Add('InitPostEntity', 'HLACrosshairTFA', function()
	-- TFA weapons draw their own cross unless told to use the game's (which is hidden above)
	if ConVarExists('cl_tfa_hud_crosshair_enable_custom') then RunConsoleCommand('cl_tfa_hud_crosshair_enable_custom', '0') end
end)
hook.Add('HUDPaint', 'HLACrosshair', function()
	if hidden() or B.k > 0.3 then return end
	local p = LocalPlayer()
	if p:ShouldDrawLocalPlayer() then return end
	local size = math.max(10, math.floor(16 * S()))
	surface.SetMaterial(ring)
	surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 220)
	surface.DrawTexturedRect(ScrW() / 2 - size / 2, ScrH() / 2 - size / 2, size, size)
end)

---------------------------------------------------------------------------------------------------
-- running: the gear rattles with the steps (hla_menu_content/sound/hla/player/gear1-4.wav)
hook.Add('PlayerFootstep', 'HLAGearRattle', function(p, pos, foot, sound, volume)
	if not IsValid(p) or not p:IsOnGround() then return end
	if p:GetVelocity():Length2D() < p:GetWalkSpeed() * 1.2 then return end
	p:EmitSound('hla/player/gear' .. math.random(1, 4) .. '.wav', 62, math.random(95, 106), 0.55)
end)
