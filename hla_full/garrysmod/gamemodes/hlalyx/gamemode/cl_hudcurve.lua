-- The HUD as on a helmet visor: it is drawn into a render target cleared to black, then added onto the
-- screen (additive: black adds nothing, so no alpha channel is needed — it is not kept on every video
-- card) through a grid curved toward the edges, without any glow copies (they doubled the letters). hla_hud_curve 0 = flat.
-- On the first frame the curved path checks itself; on any error the HUD is drawn flat from then on.
local HC = {}
HLA.HudCurve = HC
local cv = CreateClientConVar('hla_hud_curve', '1', true, false, 'Curved HUD (0/1)')
local strength = CreateClientConVar('hla_hud_curve_strength', '0.07', true, false, 'How much the HUD bends (0 .. 0.15)')

local rt, mat, rtKey
local broken = false
local tested = false
-- one texture per screen size: a new resolution (another monitor, windowed mode) gets its own,
-- the old one is not stretched
local function targets()
	local key = ScrW() .. 'x' .. ScrH()
	if rt and rtKey == key then return true end
	rt = GetRenderTargetEx('hla_hud_rt_' .. key, ScrW(), ScrH(), RT_SIZE_LITERAL, MATERIAL_RT_DEPTH_NONE, 2, 0, IMAGE_FORMAT_RGBA8888)
	if not rt then return false end
	rtKey = key
	mat = CreateMaterial('hla_hud_curve_' .. key, 'UnlitGeneric', {['$basetexture'] = rt:GetName(), ['$additive'] = 1, ['$vertexcolor'] = 1, ['$vertexalpha'] = 1, ['$ignorez'] = 1})
	return true
end

-- the HUD is added onto the picture: a black backing adds nothing, so the backing panels need a colour of
-- their own (cl_hud.lua asks this)
function HC.Additive() return not broken and cv:GetBool() and rt ~= nil end

local function warp(u, v, k, ox, oy)
	local x, y = u * 2 - 1, v * 2 - 1
	local f = 1 - k * (x * x * 0.6 + y * y)
	local g = 1 - k * 0.5 * (x * x)
	return (x * f * 0.985 + 1) * 0.5 * ScrW() + ox, (y * g * 0.985 + 1) * 0.5 * ScrH() + oy
end

local NX, NY = 24, 14
local function drawGrid(m, r, g, b, a, ox, oy)
	local k = math.Clamp(strength:GetFloat(), 0, 0.15)
	render.SetMaterial(m)
	mesh.Begin(MATERIAL_QUADS, NX * NY)
	for j = 0, NY - 1 do
		for i = 0, NX - 1 do
			local u0, u1, v0, v1 = i / NX, (i + 1) / NX, j / NY, (j + 1) / NY
			for _, c in ipairs({{u0, v0}, {u1, v0}, {u1, v1}, {u0, v1}}) do
				local x, y = warp(c[1], c[2], k, ox or 0, oy or 0)
				mesh.Position(Vector(x, y, 0))
				mesh.TexCoord(0, c[1], c[2])
				mesh.Color(r, g, b, a)
				mesh.AdvanceVertex()
			end
		end
	end
	mesh.End()
end

local function curved(fn)
	-- the texture is wiped every frame: colour only (it has no depth buffer — asking to clear depth made
	-- some cards skip the clear, and old text stayed under new text)
	render.ClearRenderTarget(rt, Color(0, 0, 0, 255))
	render.PushRenderTarget(rt)
	render.OverrideAlphaWriteEnable(true, true)
	render.Clear(0, 0, 0, 255)
	render.OverrideAlphaWriteEnable(false)
	cam.Start2D()
		local ok, err = pcall(fn)
		if not ok then ErrorNoHalt('[HLA HUD] ' .. tostring(err) .. '\n') end
		if not tested then
			-- test mark in the middle of the picture
			surface.SetDrawColor(255, 0, 255, 255)
			surface.DrawRect(ScrW() / 2 - 1, ScrH() / 2 - 1, 2, 2)
		end
	cam.End2D()
	render.PopRenderTarget()
	cam.Start2D()
		drawGrid(mat, 255, 255, 255, 255)
	cam.End2D()
end

-- did the test mark reach the screen?
local function selfTest(before)
	render.CapturePixels()
	local r, g, b = render.ReadPixel(ScrW() / 2, ScrH() / 2)
	if not (r and r > 150 and b > 150) then return false end
	-- a point away from the HUD must keep the picture of the world (not go black)
	local x, y = math.floor(ScrW() * 0.5), math.floor(ScrH() * 0.62)
	local r2, g2, b2 = render.ReadPixel(x, y)
	if before and before[1] + before[2] + before[3] > 30 and r2 + g2 + b2 < (before[1] + before[2] + before[3]) * 0.5 then return false end
	return true
end

function HC.Paint(fn)
	if broken or not cv:GetBool() then fn() return end
	local ok, err = pcall(function()
		if not targets() then error('no render target') end
		local before
		if not tested then
			render.CapturePixels()
			local r, g, b = render.ReadPixel(math.floor(ScrW() * 0.5), math.floor(ScrH() * 0.62))
			before = {r or 0, g or 0, b or 0}
		end
		curved(fn)
		if not tested then
			tested = true
			if not selfTest(before) then error('the curved HUD does not show right on this video card') end
		end
	end)
	if not ok then
		broken = true
		MsgC(Color(110, 200, 255), '[HLA HUD] curved HUD is off, drawing flat: ' .. tostring(err) .. '\n')
		fn()
	end
end

cvars.AddChangeCallback('hla_hud_curve', function(_, _, new)
	if new ~= '0' then broken, tested = false, false end
end, 'HLAHudCurve')
