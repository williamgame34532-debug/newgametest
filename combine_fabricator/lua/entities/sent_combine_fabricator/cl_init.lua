include('shared.lua')

local C = CFRework
local S = C.State
local M = C.M

---------------------------------------------------------------------------------------------------
-- fonts and the draw adapter for cl_ui.lua
local FONTS = {cfr_hdr = {26, 700}, cfr_xs = {14, 500}, cfr_xxs = {11, 500}, cfr_s = {17, 700},
	cfr_m = {22, 700}, cfr_row = {21, 700}, cfr_l = {32, 700}, cfr_num = {42, 700}}
for name, f in pairs(FONTS) do
	surface.CreateFont(name, {font = 'Roboto Condensed', size = f[1], weight = f[2], extended = true, antialias = true})
end

local function col(c) return c[1], c[2], c[3], c[4] or 255 end
local XA = {[0] = TEXT_ALIGN_LEFT, [1] = TEXT_ALIGN_CENTER, [2] = TEXT_ALIGN_RIGHT}
local YA = {[0] = TEXT_ALIGN_TOP, [1] = TEXT_ALIGN_CENTER, [2] = TEXT_ALIGN_BOTTOM}
local D = {}
function D.rect(x, y, w, h, c) surface.SetDrawColor(col(c)) surface.DrawRect(x, y, w, h) end
function D.outline(x, y, w, h, c, t) surface.SetDrawColor(col(c)) surface.DrawOutlinedRect(x, y, w, h, t or 1) end
function D.line(x1, y1, x2, y2, c) surface.SetDrawColor(col(c)) surface.DrawLine(x1, y1, x2, y2) end
function D.poly(pts, c)
	local p = {}
	for i, v in ipairs(pts) do p[i] = {x = v[1], y = v[2]} end
	draw.NoTexture()
	surface.SetDrawColor(col(c))
	surface.DrawPoly(p)
end
function D.size(s, font) surface.SetFont(font) return surface.GetTextSize(s) end
function D.text(s, font, x, y, c, ax, ay)
	draw.SimpleText(s, font, x, y, Color(col(c)), XA[ax or 0], YA[ay or 0])
end

---------------------------------------------------------------------------------------------------
local glowSprite = Material('sprites/light_glow02_add')
local wire = Material('models/wireframe')
local beamMat = Material('cable/blue_elec')

function ENT:Initialize()
	self:SetRenderBounds(Vector(-40, -60, -2), Vector(60, 62, 80))
	self.Models = {}
	self.Look = {0, 0}
	C.Parts.Prepare()
end

function ENT:ClientModel(key, path)
	local m = self.Models[key]
	if IsValid(m) and m.Path == path then return m end
	if IsValid(m) then m:Remove() end
	m = ClientsideModel(path, RENDERGROUP_OPAQUE)
	if not IsValid(m) then return end
	m:SetNoDraw(true)
	m.Path = path
	self.Models[key] = m
	return m
end

function ENT:OnRemove()
	for _, m in pairs(self.Models or {}) do if IsValid(m) then m:Remove() end end
end

-- eye head aims at the operator, else at the closest player
function ENT:UpdateLook()
	local target = self:GetOperator()
	if not IsValid(target) then
		local best
		for _, p in ipairs(player.GetAll()) do
			local d = p:GetPos():DistToSqr(self:GetPos())
			if p:Alive() and d < 300 * 300 and (not best or d < best) then best, target = d, p end
		end
	end
	local want = {0, 0}
	if IsValid(target) then
		local R = C.Rig.HATCH
		local head = Vector(R[1], R[2], R[3] + 21)
		local loc = self:WorldToLocal(target:EyePos()) - head
		local a = loc:Angle()
		want = {math.Clamp(math.NormalizeAngle(a.p), -35, 35), math.Clamp(math.NormalizeAngle(a.y), -70, 70)}
	end
	local k = math.min(FrameTime() * 4, 1)
	self.Look[1] = Lerp(k, self.Look[1], want[1])
	self.Look[2] = Lerp(k, self.Look[2], want[2])
end

local function placeModel(m, center, ang, scale)
	m:SetModelScale(scale, 0)
	m:SetAngles(ang)
	m:SetPos(center)
	m:SetupBones()
	local off = LocalToWorld(m:OBBCenter() * scale, angle_zero, vector_origin, ang)
	m:SetPos(center - off)
end

function ENT:DrawItem(pose, st, item)
	if not item then return end
	local m = self:ClientModel('item', item.model)
	if not IsValid(m) then return end
	local center = C.ItemPoint(self, pose)
	local ang = self:LocalToWorldAngles(Angle(0, 0, 0))
	local size = m:GetModelRadius() or 8
	local scale = math.Clamp(9 / math.max(size, 1), 0.4, 1.3)
	if st == S.PRINT then
		-- the item materialises inside the rib chamber from the bottom up
		local f = math.Clamp((CurTime() - self:GetStageStarted()) / math.max(0.1, self:GetStageUntil() - self:GetStageStarted()), 0, 1)
		placeModel(m, center, ang, scale)
		render.MaterialOverride(wire)
		render.SetColorModulation(0.2, 0.85, 1)
		render.SetBlend(0.35 + 0.25 * math.sin(CurTime() * 12))
		m:DrawModel()
		render.SetBlend(1)
		render.SetColorModulation(1, 1, 1)
		render.MaterialOverride()
		local up = self:GetUp()
		local zcut = center + up * (-6 + 12 * f)
		local prev = render.EnableClipping(true)
		render.PushCustomClipPlane(-up, (-up):Dot(zcut))
		m:DrawModel()
		render.PopCustomClipPlane()
		render.EnableClipping(prev)
		-- scanning line at the print height
		local right = self:GetForward() * 9
		render.SetMaterial(beamMat)
		render.DrawBeam(zcut - right, zcut + right, 1.2, CurTime() * 3, CurTime() * 3 + 1, Color(90, 230, 255))
	elseif st == S.DONE then
		local bob = math.sin(CurTime() * 2) * 0.3
		placeModel(m, center + self:GetUp() * bob, ang, scale)
		m:DrawModel()
	end
end

-- wireframe hologram of the chosen item floating over the grille (reference: hologram above the rods)
function ENT:DrawHologram(pose, item)
	if not item then return end
	local m = self:ClientModel('holo', item.model)
	if not IsValid(m) then return end
	local x, y, z = M.point(pose.rods, -5.4, -10.7, 26)
	local center = self:LocalToWorld(Vector(x + 1.5, y, z))
	local ang = self:LocalToWorldAngles(Angle(0, CurTime() * 25 % 360, 0))
	placeModel(m, center, ang, math.Clamp(10 / math.max(m:GetModelRadius() or 8, 1), 0.4, 1.5))
	render.MaterialOverride(wire)
	render.SetColorModulation(0.25, 0.9, 1)
	render.SetBlend(0.55)
	m:DrawModel()
	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
	render.MaterialOverride()
end

function ENT:ScreenContext(st, cursor)
	local p = self:GetOperator()
	local viewer = LocalPlayer()
	local owner = IsValid(p) and p or viewer
	local f = math.Clamp((CurTime() - self:GetStageStarted()) / math.max(0.1, self:GetStageUntil() - self:GetStageStarted()), 0, 1)
	local ctx = {
		stage = st, t = CurTime(), tab = self:GetTab(), sel = self:GetSelection(),
		resin = owner:GetNWInt('cf_resin', 0), paid = self:GetPaid(), cost = self:GetCost(),
		printFrac = f, status = self:GetStatusText(), boot = math.Clamp((C.Chan(self, 'deploy') - 0.6) / 0.4, 0, 1),
	}
	if IsValid(p) and p ~= viewer and st > S.MENU then ctx.busy = string.sub(p:Nick(), 1, 32) end
	if cursor then
		ctx.cursor = cursor
		ctx.hover = C.Layout.ButtonAt(st, self:GetTab(), cursor[1], cursor[2])
	end
	return ctx
end

function ENT:Draw()
	local dist = EyePos():DistToSqr(self:GetPos())
	self:UpdateLook()
	local pose = C.PoseOf(self, CurTime(), self.Look)
	local st = self:GetStage()
	local deploy = C.Chan(self, 'deploy')
	local item = C.Items[self:GetSelection()]

	-- strip brightness: dim when dormant, cells bright while loading, ribs pulse while printing
	local glow = {all = 0.25 + 0.75 * deploy}
	if st == S.DEPOSIT then glow.cellglow = 0.6 + 0.4 * math.abs(math.sin(CurTime() * 4)) end
	if st == S.PRINT then glow.ribglow = 0.6 + 0.4 * math.abs(math.sin(CurTime() * 9)) end

	if dist > 2500 * 2500 or not C.Parts.Draw(self, pose, glow) then
		self:DrawModel()
		return
	end
	if dist > 900 * 900 then return end

	-- eye lens halo
	local h = pose.head
	local lx, ly, lz = M.point(h, 1.0, 0, 0)
	local lens = self:LocalToWorld(Vector(lx, ly, lz))
	render.SetMaterial(glowSprite)
	render.DrawSprite(lens, 4 * deploy + 0.5, 4 * deploy + 0.5, deploy > 0.5 and Color(60, 220, 255) or Color(255, 40, 30))

	-- filled resin cells glow
	if st == S.DEPOSIT then
		local filled = self:GetPaid() % 10
		if self:GetPaid() > 0 and filled == 0 then filled = 10 end
		for i = 1, math.min(filled, 10) do
			local c = C.Rig.CellPoint(pose, i)
			render.DrawSprite(self:LocalToWorld(Vector(c[1], c[2] - 0.3, c[3])), 3.2, 3.2, Color(80, 230, 255, 200))
		end
		self:DrawResinFeed(pose)
	end

	if st == S.PRINT or st == S.DONE then self:DrawItem(pose, st, item) end
	if (st == S.DEPOSIT or st == S.PRINT) and deploy > 0.9 then self:DrawHologram(pose, item) end

	if st == S.PRINT then
		-- the eye scans the chamber
		local target = C.ItemPoint(self, pose) + VectorRand() * 2.5
		render.SetMaterial(beamMat)
		render.DrawBeam(lens, target, 0.6, CurTime() * 4, CurTime() * 4 + 1, Color(80, 220, 255, 200))
	end

	-- display
	if deploy > 0.6 and dist < 420 * 420 then
		local origin, right, down, normal, ang, scale = C.ScreenWorld(self, pose)
		if (EyePos() - origin):Dot(normal) > 0 then
			local x, y = C.HitScreen(self, LocalPlayer(), pose)
			cam.Start3D2D(origin + normal * 0.02, ang, scale)
				C.UI.Draw(D, self:ScreenContext(st, x and {x, y}))
			cam.End3D2D()
		end
	end
end

-- resin pucks sliding into the cells as they are paid
function ENT:DrawResinFeed(pose)
	local paid = self:GetPaid()
	if paid ~= self.LastPaid then
		if self.LastPaid and paid > self.LastPaid then self.FeedAt = CurTime() self.FeedCell = ((paid - 1) % 10) + 1 end
		self.LastPaid = paid
	end
	if not self.FeedAt then return end
	local f = (CurTime() - self.FeedAt) / 0.35
	if f > 1 then self.FeedAt = nil return end
	local m = self:ClientModel('puck', C.ResinModel)
	if not IsValid(m) then return end
	local c = C.Rig.CellPoint(pose, self.FeedCell)
	local from = Vector(c[1] + 10, c[2] - 12, c[3] + 6)
	local to = Vector(c[1], c[2] + 2, c[3])
	local p = LerpVector(M.smooth(f), from, to)
	m:SetModelScale(0.6, 0)
	m:SetPos(self:LocalToWorld(p))
	m:SetAngles(self:LocalToWorldAngles(Angle(90, 90, 0)))
	m:SetupBones()
	m:DrawModel()
end

function ENT:Think()
	if self:GetStage() ~= S.PRINT or EyePos():DistToSqr(self:GetPos()) > 500 * 500 then return end
	if (self.NextSpark or 0) > CurTime() then return end
	self.NextSpark = CurTime() + 0.12
	local pose = C.PoseOf(self, CurTime(), self.Look)
	local origin = C.ItemPoint(self, pose)
	local em = ParticleEmitter(origin, false)
	if not em then return end
	for i = 1, 3 do
		local p = em:Add('effects/spark', origin + VectorRand() * 4)
		if p then
			p:SetVelocity(VectorRand() * 30 + self:GetUp() * 15)
			p:SetDieTime(0.35)
			p:SetStartAlpha(255) p:SetEndAlpha(0)
			p:SetStartSize(0.6) p:SetEndSize(0)
			p:SetStartLength(1.5) p:SetEndLength(0)
			p:SetColor(120, 230, 255)
			p:SetGravity(Vector(0, 0, -200))
		end
	end
	em:Finish()
	local dl = DynamicLight(self:EntIndex())
	if dl then
		dl.pos = origin dl.r = 60 dl.g = 200 dl.b = 255 dl.brightness = 1.5
		dl.decay = 600 dl.size = 120 dl.dietime = CurTime() + 0.2
	end
end

---------------------------------------------------------------------------------------------------
-- left click on a display is forwarded to the server (it recomputes the aim itself)
hook.Add('PlayerBindPress', 'CFReworkScreenClick', function(p, bind, pressed)
	if not pressed or bind ~= '+attack' then return end
	for _, e in ipairs(ents.FindInSphere(p:EyePos(), C.UseRange + 60)) do
		if e:GetClass() == 'sent_combine_fabricator' and C.HitScreen(e, p) then
			net.Start('cf_rework_click') net.SendToServer()
			return true
		end
	end
end)

-- hints at the crosshair and the HL:A-style resin counter near a station
hook.Add('HUDPaint', 'CFReworkHints', function()
	local p = LocalPlayer()
	if not IsValid(p) then return end
	local near
	for _, e in ipairs(ents.FindInSphere(p:EyePos(), 220)) do
		if e:GetClass() == 'sent_combine_fabricator' then near = e break end
	end
	if not near then return end
	local amber = Color(255, 196, 70)
	draw.RoundedBox(0, 40, ScrH() - 150, 170, 44, Color(20, 16, 6, 150))
	draw.SimpleText('СМОЛА', 'cfr_m', 56, ScrH() - 128, amber, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(p:GetNWInt('cf_resin', 0), 'cfr_l', 196, ScrH() - 128, amber, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	local st = near:GetStage()
	if near:GetOperator() ~= p then return end
	local part = C.HitPart(near, p)
	local text
	if st == S.DEPOSIT and part == 'cells' then text = 'E — ВНЕСТИ СМОЛУ (удерживайте)'
	elseif st == S.DONE and part == 'chamber' then text = 'E — ЗАБРАТЬ ПРЕДМЕТ' end
	if text then
		draw.SimpleTextOutlined(text, 'cfr_m', ScrW() / 2, ScrH() * 0.6, Color(170, 240, 250), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 180))
	end
end)
