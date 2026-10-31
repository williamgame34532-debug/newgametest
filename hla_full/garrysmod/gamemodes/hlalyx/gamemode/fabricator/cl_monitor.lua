-- Half-Life: Alyx monitor look for in-world screens: the UI is drawn into a render target, the
-- ported HL:A «vr_monitor» pixel shader (shaders/fxc/hla_monitor_ps30.vcs, source in
-- shadersrc/) adds the jitter/chromatic split, scanlines, vignette and film grain, and the result
-- is put on the screen surface. Without the compiled shader everything is drawn directly as before.
CFRework = CFRework or {}
local C = CFRework
local MON = {}
C.Monitor = MON

MON.W, MON.H = 1024, 512
-- effect settings (HL:A material values are subtle: a light split and grain)
MON.JitterSpeed, MON.VSyncJump, MON.Grain = 0.6, 0.04, 0.12
MON.Shift = {0.12, 0.0, -0.12}
MON.ScanTiling, MON.ScanScroll = 128, 0.0
MON.Tint, MON.Vignette = {0.95, 1.0, 1.0}, 0.4

local cvar = CreateClientConVar('hla_monitor_fx', '1', true, false, 'HL:A monitor shader on fabricator screens')

function MON.Available()
	if MON.ok == nil then MON.ok = file.Exists('shaders/fxc/hla_monitor_ps30.vcs', 'GAME') end
	return MON.ok and cvar:GetBool()
end

local rtUI, rtFX, matFX, matOut
local function setup()
	if matOut then return end
	local flags = bit.bor(4, 8, 16, 256) -- clamp s/t, no mip, no lod
	rtUI = GetRenderTargetEx('hla_monitor_ui', MON.W, MON.H, RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE, flags, 0, IMAGE_FORMAT_RGBA8888)
	rtFX = GetRenderTargetEx('hla_monitor_fx', MON.W, MON.H, RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE, flags, 0, IMAGE_FORMAT_RGBA8888)
	matFX = CreateMaterial('hla_monitor_pass', 'screenspace_general', {
		['$pixshader'] = 'hla_monitor_ps30',
		['$basetexture'] = rtUI:GetName(),
		['$texture1'] = 'hla/monitor/scanlines',
		['$texture2'] = 'hla/monitor/grain',
		['$texture3'] = 'hla/monitor/jitter',
		['$ignorez'] = 1, ['$vertextransform'] = 1, ['$vertexcolor'] = 0,
		['$alpha_blend'] = 0, ['$alpha_blend_color_overlay'] = 0, ['$copyalpha'] = 0,
		['$linearread_basetexture'] = 0, ['$linearread_texture1'] = 1, ['$linearread_texture2'] = 1,
		['$linearread_texture3'] = 1, ['$linearwrite'] = 0,
	})
	matOut = CreateMaterial('hla_monitor_out', 'UnlitGeneric', {['$basetexture'] = rtFX:GetName(), ['$translucent'] = 0})
end

-- draw(D-callback) into the screen surface given by the 3D2D frame; returns false if not used
function MON.Draw(pos, ang, scale, paint)
	if not MON.Available() then return false end
	setup()
	render.PushRenderTarget(rtUI)
		render.Clear(0, 0, 0, 255, true, true)
		cam.Start2D()
			paint()
		cam.End2D()
	render.PopRenderTarget()
	local t = CurTime()
	matFX:SetFloat('$c0_x', t)
	matFX:SetFloat('$c0_y', MON.JitterSpeed)
	matFX:SetFloat('$c0_z', MON.VSyncJump)
	matFX:SetFloat('$c0_w', MON.Grain)
	matFX:SetFloat('$c1_x', MON.Shift[1]) matFX:SetFloat('$c1_y', MON.Shift[2]) matFX:SetFloat('$c1_z', MON.Shift[3])
	matFX:SetFloat('$c1_w', MON.ScanTiling)
	matFX:SetFloat('$c2_x', MON.Tint[1]) matFX:SetFloat('$c2_y', MON.Tint[2]) matFX:SetFloat('$c2_z', MON.Tint[3])
	matFX:SetFloat('$c2_w', MON.Vignette)
	matFX:SetFloat('$c3_x', MON.ScanScroll)
	render.PushRenderTarget(rtFX)
		render.SetMaterial(matFX)
		render.DrawScreenQuad()
	render.PopRenderTarget()
	cam.Start3D2D(pos, ang, scale)
		surface.SetMaterial(matOut)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(0, 0, MON.W, MON.H)
	cam.End3D2D()
	return true
end
