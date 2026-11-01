include('shared.lua')

-- the picture of the chosen camera: rendered into a texture of its own ~20 times a second while someone is
-- near, then put on the screen of the monitor over the terminal (and as a preview on the terminal's screen)
local CT = HLA.CamTerminals or {lists = {}}
HLA.CamTerminals = CT
local RW, RH = 640, 360

net.Receive('hla_cams', function()
	local t = net.ReadEntity()
	local list = {}
	for i = 1, net.ReadUInt(8) do
		list[i] = {idx = net.ReadUInt(16), pos = net.ReadVector(), zone = net.ReadString(), n = i}
	end
	if IsValid(t) then CT.lists[t:EntIndex()] = list end
end)

local targets = {}
function CT.Target(t)
	local id = t:EntIndex()
	local r = targets[id]
	if r then return r end
	local rt = GetRenderTargetEx('hla_camrt_' .. id, RW, RH, RT_SIZE_LITERAL, MATERIAL_RT_DEPTH_SEPARATE, 0, 0, IMAGE_FORMAT_RGB888)
	local mat = CreateMaterial('hla_camrt_' .. id, 'UnlitGeneric', {['$basetexture'] = rt:GetName(), ['$model'] = 1})
	r = {rt = rt, mat = mat, next = 0}
	targets[id] = r
	return r
end

local scan = Material('hla/ui/scanlines')
surface.CreateFont('hla_cam_osd', {font = 'Exo 2', size = 22, weight = 700, extended = true})
local rendering = false
hook.Add('PreRender', 'HLACamTerminals', function()
	if rendering then return end
	local eye = EyePos()
	for _, t in ipairs(ents.FindByClass('hla_terminal_cams')) do
		if t:GetCamIndex() > 0 and t:GetPos():DistToSqr(eye) < 1200 * 1200 then
			local r = CT.Target(t)
			if RealTime() >= r.next then
				r.next = RealTime() + 0.05
				rendering = true
				render.PushRenderTarget(r.rt)
				render.Clear(0, 0, 0, 255, true, true)
				render.RenderView({origin = t:GetCamPos(), angles = t:GetCamAng(), x = 0, y = 0, w = RW, h = RH, fov = 80,
					drawviewmodel = false, drawhud = false, dopostprocess = false, drawmonitors = false, znear = 4})
				-- the look of a Combine feed: cold tint, scanlines, the camera number and the time
				cam.Start2D()
					surface.SetDrawColor(20, 60, 90, 70)
					surface.DrawRect(0, 0, RW, RH)
					surface.SetMaterial(scan)
					surface.SetDrawColor(120, 210, 255, 40)
					surface.DrawTexturedRectUV(0, 0, RW, RH, 0, 0, RW / 64, RH / 64)
					local n = 0
					for _, c in ipairs(CT.lists[t:EntIndex()] or {}) do if c.idx == t:GetCamIndex() then n = c.n end end
					draw.SimpleTextOutlined('КАМ-' .. string.format('%02d', n) .. '  ::  ' .. os.date('%H:%M:%S'), 'hla_cam_osd', 14, 12, Color(170, 230, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 180))
					if math.floor(RealTime() * 2) % 2 == 0 then
						draw.NoTexture()
						surface.SetDrawColor(255, 60, 50, 230)
						surface.DrawRect(RW - 30, 16, 14, 14)
					end
				cam.End2D()
				render.PopRenderTarget()
				rendering = false
			end
		end
	end
end)

-- the monitor's screen material is swapped for the feed (or back when no camera is chosen)
local function screenIndex(m)
	if m.HLAScreenIdx ~= nil then return m.HLAScreenIdx end
	m.HLAScreenIdx = false
	for i, name in ipairs(m:GetMaterials() or {}) do
		if string.find(name, 'intmonitor001_disp', 1, true) or string.find(name, '_disp', 1, true) then m.HLAScreenIdx = i - 1 break end
	end
	return m.HLAScreenIdx
end

function ENT:Think()
	local m = self:GetMonitor()
	if not IsValid(m) then return end
	local idx = screenIndex(m)
	if not idx then return end
	local on = self:GetCamIndex() > 0
	if on ~= self.HLAFeedOn then
		self.HLAFeedOn = on
		if on then
			CT.Target(self)
			m:SetSubMaterial(idx, '!hla_camrt_' .. self:EntIndex())
		else
			m:SetSubMaterial(idx, nil)
		end
	end
end
