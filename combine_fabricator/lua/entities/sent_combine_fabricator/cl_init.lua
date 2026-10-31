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
local beamMat = Material('trails/laser')

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
		local head = Vector(R[1], R[2], R[3] + 17)
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
		render.DrawBeam(zcut - right, zcut + right, 0.8, 0, 1, Color(90, 230, 255, 220))
	elseif st == S.DONE then
		local bob = math.sin(CurTime() * 2) * 0.3
		placeModel(m, center + self:GetUp() * bob, ang, scale)
		m:DrawModel()
	end
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
	local st = self:GetStage()
	self:UpdateFeed(st)
	local pose = C.PoseOf(self, CurTime(), self.Look, self.Feed)
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

	-- loaded resin cartridges sit in their tubes and travel with the magazine
	if st == S.DEPOSIT or (self.Feed and self.Feed.n > 0 and C.Chan(self, 'tray') > 0.01) then self:DrawCartridges(pose) end

	if st == S.PRINT or st == S.DONE then self:DrawItem(pose, st, item) end

	-- display
	if deploy > 0.6 and dist < 420 * 420 then
		local origin, right, down, normal, ang, scale = C.ScreenWorld(self, pose)
		if (EyePos() - origin):Dot(normal) > 0 then
			local cur = C.FocusCursor(self)
			if not cur then
				local x, y = C.HitScreen(self, LocalPlayer(), pose)
				cur = x and {x, y}
			end
			cam.Start3D2D(origin + normal * 0.02, ang, scale)
				C.UI.Draw(D, self:ScreenContext(st, cur))
			cam.End3D2D()
		end
	end
end

-- magazine feed: every loaded cartridge steps the magazine back one tube, a new empty tube
-- arrives at the feed port; after five the lower row is lifted up, after ten the magazine is emptied
function ENT:UpdateFeed(st)
	local f = self.Feed
	if not f then f = {slot = 0, row = 0, n = 0, insertAt = 0} self.Feed = f end
	local paid = (st == S.DEPOSIT) and self:GetPaid() or 0
	if paid ~= f.paid then
		if f.paid and paid > f.paid then f.insertAt = CurTime() end
		f.paid = paid
	end
	local n = paid % 10
	if paid > 0 and n == 0 then n = 10 end
	-- the newest cartridge slides in first, then the magazine steps
	local inserting = CurTime() - f.insertAt < 0.3
	local shown = inserting and math.max(n - 1, 0) or n
	f.n = n
	local slot = (shown >= 10) and 4 or (shown % 5)
	local row = (shown >= 5) and 1 or 0
	local k = math.min(FrameTime() * 9, 1)
	f.slot = Lerp(k, f.slot, slot)
	f.row = Lerp(k, f.row, row)
	f.feedSlot, f.feedRow = f.slot, f.row
end

function ENT:DrawCartridges(pose)
	local f = self.Feed
	if not f or f.n <= 0 then return end
	local m = self:ClientModel('cartridge', C.CartridgeModel)
	if not IsValid(m) then return end
	local clipped, prev = C.Parts.PushClip(self, 'cells')
	local ang = self:LocalToWorldAngles(Angle(0, 0, -90)) -- model axis (Z) along the tubes (Y)
	for i = 1, f.n do
		local c = C.Rig.CellPoint(pose, i)
		local depth = 5.6
		if i == f.n then
			local t = math.Clamp((CurTime() - f.insertAt) / 0.3, 0, 1)
			depth = Lerp(M.smooth(t), -6, 5.6)
		end
		m:SetModelScale(0.95, 0)
		m:SetPos(self:LocalToWorld(Vector(c[1], c[2] + depth, c[3])))
		m:SetAngles(ang)
		m:SetupBones()
		m:DrawModel()
	end
	C.Parts.PopClip(clipped, prev)
end

function ENT:Think()
	if self:GetStage() ~= S.PRINT or EyePos():DistToSqr(self:GetPos()) > 500 * 500 then return end
	if (self.NextSpark or 0) > CurTime() then return end
	self.NextSpark = CurTime() + 0.12
	local pose = C.PoseOf(self, CurTime(), self.Look, self.Feed)
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
-- hints at the crosshair and the HL:A-style resin counter near a station
hook.Add('HUDPaint', C.HintHook or 'CFReworkHints', function()
	local p = LocalPlayer()
	if not IsValid(p) then return end
	local near
	for _, e in ipairs(ents.FindInSphere(p:EyePos(), 220)) do
		if e.IsCombineFabricator then near = e break end
	end
	if not near or C.FocusEnt() then return end
	local amber = Color(255, 196, 70)
	-- the Half-Life: Alyx gamemode shows resin on its own HUD
	if not (HLA and HLA.Hud) then
	draw.RoundedBox(0, 40, ScrH() - 150, 170, 44, Color(20, 16, 6, 150))
	draw.SimpleText('СМОЛА', 'cfr_m', 56, ScrH() - 128, amber, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(p:GetNWInt('cf_resin', 0), 'cfr_l', 196, ScrH() - 128, amber, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	local st = near:GetStage()
	if st ~= S.MENU and near:GetOperator() ~= p then return end
	local part = C.HitPart(near, p)
	local text
	if st == S.MENU and C.HitScreen(near, p) then text = 'E — ВОЙТИ В ТЕРМИНАЛ'
	elseif st == S.DEPOSIT and part == 'cells' then text = 'E — ВНЕСТИ СМОЛУ (удерживайте)'
	elseif st == S.DONE and part == 'chamber' then text = 'E — ЗАБРАТЬ ПРЕДМЕТ' end
	if text then
		draw.SimpleTextOutlined(text, 'cfr_m', ScrW() / 2, ScrH() * 0.6, Color(170, 240, 250), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 180))
	end
end)
