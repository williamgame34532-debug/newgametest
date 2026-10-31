include('shared.lua')

local C = CFRework
local S = C.State
local M = C.M

---------------------------------------------------------------------------------------------------
-- fonts and the draw adapter for cl_ui.lua
local FONTS = {cfr_hdr = {26, 700}, cfr_xs = {14, 500}, cfr_xxs = {11, 500}, cfr_s = {17, 700},
	cfr_m = {22, 700}, cfr_row = {21, 700}, cfr_l = {32, 700}, cfr_num = {42, 700}, cfr_big = {46, 800}}
for name, f in pairs(FONTS) do
	surface.CreateFont(name, {font = 'Roboto Condensed', size = f[1], weight = f[2], extended = true, antialias = true})
end

local function col(c) return c[1], c[2], c[3], c[4] or 255 end
local XA = {[0] = TEXT_ALIGN_LEFT, [1] = TEXT_ALIGN_CENTER, [2] = TEXT_ALIGN_RIGHT}
local YA = {[0] = TEXT_ALIGN_TOP, [1] = TEXT_ALIGN_CENTER, [2] = TEXT_ALIGN_BOTTOM}
local D = {}
local barcode = Material('cf_rework/ui/barcode.png', 'smooth')
function D.barcode(x, y, w, h, c)
	surface.SetMaterial(barcode)
	surface.SetDrawColor(col(c))
	surface.DrawTexturedRect(x, y, w, h)
end
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
local beamMat = Material('trails/laser')
-- teal hologram over the grille, as the station shows it in Half-Life: Alyx
local holoMat = CreateMaterial('cf_hla_holo', 'UnlitGeneric', {
	['$basetexture'] = 'cf_rework/holo/scanlines', ['$additive'] = 1, ['$model'] = 1, ['$nocull'] = 1,
	['$basetexturetransform'] = 'center .5 .5 scale 1 6 rotate 0 translate 0 0',
	['Proxies'] = {['TextureScroll'] = {['texturescrollvar'] = '$basetexturetransform', ['texturescrollrate'] = 0.12, ['texturescrollangle'] = 90}},
})
local blockMat = CreateMaterial('cf_hla_holo_block', 'UnlitGeneric', {
	['$basetexture'] = 'vgui/white', ['$additive'] = 1, ['$vertexcolor'] = 1, ['$vertexalpha'] = 1, ['$nocull'] = 1,
})

function ENT:Initialize()
	self:SetRenderBounds(Vector(-30, -60, -2), Vector(40, 62, 82))
	self.Models = {}
	self.Look = {0, 0}
end

-- helper models are drawn by hand only and removed as soon as a frame does not need them
function ENT:ClientModel(key, path)
	self.ModelsUsed = self.ModelsUsed or {}
	self.ModelsUsed[key] = true
	local m = self.Models[key]
	if IsValid(m) and m.Path == path then m:SetNoDraw(true) return m end
	if IsValid(m) then m:Remove() end
	m = ClientsideModel(path, RENDERGROUP_OPAQUE)
	if not IsValid(m) then return end
	m:SetNoDraw(true)
	m:DrawShadow(false)
	m.Path = path
	self.Models[key] = m
	return m
end

function ENT:FreeUnusedModels()
	local used = self.ModelsUsed or {}
	for key, m in pairs(self.Models) do
		if not used[key] then
			if IsValid(m) then m:Remove() end
			self.Models[key] = nil
		end
	end
	self.ModelsUsed = {}
end

function ENT:OnRemove()
	for _, m in pairs(self.Models or {}) do if IsValid(m) then m:Remove() end end
end

-- the eye follows the operator, else the closest player (yaw on 'eye', pitch on 'joint28')
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
	local eyeBone = self:LookupBone('joint28')
	if IsValid(target) and self:GetDeployed() and eyeBone then
		local head = self:GetBonePosition(eyeBone)
		local d = self:WorldToLocal(target:EyePos()) - self:WorldToLocal(head)
		local yaw = math.deg(math.atan2(d.y, d.x)) -- the eye rests looking along +X
		local pitch = math.deg(math.atan2(d.z, math.sqrt(d.x * d.x + d.y * d.y)))
		want = {math.Clamp(pitch, -35, 35), math.Clamp(math.NormalizeAngle(yaw), -70, 70)}
	end
	local k = 1 - math.exp(-FrameTime() * 4)
	self.Look[1] = Lerp(k, self.Look[1], want[1])
	self.Look[2] = Lerp(k, self.Look[2], want[2])
	local yawBone, pitchBone = self:LookupBone('eye'), eyeBone
	-- 'eye' turns about its local Y (world up); 'joint28' tilts about its local Z (horizontal)
	if yawBone then self:ManipulateBoneAngles(yawBone, Angle(self.Look[2], 0, 0)) end
	if pitchBone then self:ManipulateBoneAngles(pitchBone, Angle(0, -self.Look[1], 0)) end
end

local function placeModel(m, center, ang, scale)
	m:SetModelScale(scale, 0)
	m:SetAngles(ang)
	m:SetPos(center)
	m:SetupBones()
	local off = LocalToWorld(m:OBBCenter() * scale, angle_zero, vector_origin, ang)
	m:SetPos(center - off)
end

-- orientation that lays the longest side of a model along +X of a frame, and its size after that
local function longAxis(m)
	local mins, maxs = m:GetModelBounds()
	local d = maxs - mins
	if d.z > d.x and d.z >= d.y then return Angle(90, 0, 0), d.z, d.y, d.x end
	if d.y > d.x then return Angle(0, 90, 0), d.y, d.x, d.z end
	return Angle(0, 0, 0), d.x, d.y, d.z
end

-- the printed item rests on the item attachment inside the rib bay
function ENT:DrawItem(st, item)
	if not item then return end
	local m = self:ClientModel('item', item.model)
	if not IsValid(m) then return end
	local center, aang = C.ItemPoint(self)
	local a, len, w, h = longAxis(m)
	local scale = math.min(1, C.ItemFit.len / math.max(len, 1), C.ItemFit.cross / math.max(w, h, 1))
	local _, ang = LocalToWorld(vector_origin, a, vector_origin, aang)
	if st == S.PRINT then
		local f = C.BuildProgress(self)
		if f <= 0 then return end
		placeModel(m, center, ang, scale)
		render.MaterialOverride(holoMat)
		local k = 0.45 + 0.2 * math.sin(CurTime() * 12)
		render.SetColorModulation(0.25 * k, 0.9 * k, 1.0 * k)
		m:DrawModel()
		render.SetColorModulation(1, 1, 1)
		render.MaterialOverride()
		local up = self:GetUp()
		local half = math.max(h * scale * 0.5, 1)
		local zcut = center + up * (-half + 2 * half * f)
		local prev = render.EnableClipping(true)
		render.PushCustomClipPlane(-up, (-up):Dot(zcut))
		m:DrawModel()
		render.PopCustomClipPlane()
		render.EnableClipping(prev)
		local along = ang:Forward() * (len * scale * 0.55)
		render.SetMaterial(beamMat)
		render.DrawBeam(zcut - along, zcut + along, 0.8, 0, 1, Color(90, 230, 255, 220))
	else
		placeModel(m, center, ang, scale)
		m:DrawModel()
	end
end

-- deterministic flicker for the hologram blocks
local function hash(i, t) return (math.sin(i * 12.9898 + t * 78.233) * 43758.5453) % 1 end

-- teal hologram of the chosen item over the grille: the item in light, wrapped in flickering blocks
function ENT:DrawHologram(item)
	if not item or not self:GetDeployed() then return end
	local m = self:ClientModel('holo', item.model)
	if not IsValid(m) then return end
	local center = self:LocalToWorld(C.HoloCenter)
	local ang = self:LocalToWorldAngles(Angle(0, 90 + math.sin(CurTime() * 0.5) * 12, 0))
	local mins, maxs = m:GetModelBounds()
	local d = maxs - mins
	local scale = math.min(1.6, C.HoloBox.w / math.max(d.x, d.y, 1), C.HoloBox.h / math.max(d.z, 1))
	placeModel(m, center, ang, scale)
	local flick = 0.9 + 0.1 * math.sin(CurTime() * 23)
	render.MaterialOverride(holoMat)
	render.SetColorModulation(0.75 * flick, 1.0 * flick, 0.95 * flick)
	m:DrawModel()
	render.SetColorModulation(1, 1, 1)
	render.MaterialOverride()
	-- blocks of noise in front of the grille
	local right, up, fwd = self:GetRight(), self:GetUp(), self:GetForward()
	local t = math.floor(CurTime() * 8)
	render.SetMaterial(blockMat)
	for i = 1, 26 do
		local u = (hash(i, 0) - 0.5) * C.HoloBox.w * 1.1
		local v = (hash(i, 1) - 0.5) * C.HoloBox.h * 1.1
		local on = hash(i, t) > 0.35
		if on then
			local s = 1.2 + hash(i, 2) * 2.4
			local p = center + right * u + up * v + fwd * (hash(i, 3) - 0.5) * 2
			local a = 30 + 60 * hash(i, t + 1)
			render.DrawQuadEasy(p, fwd, s * 1.6, s, Color(40, 230, 190, a), 0)
		end
	end
end

-- resin pucks in the tray troughs: one per resin already loaded in this round of ten
function ENT:DrawResin(st)
	if not self:GetTrayOut() then return end
	local paid = self:GetPaid()
	if paid <= 0 then return end
	local n = paid % 10
	local seqName = self:GetSequenceName(self:GetSequence()) or ''
	if n == 0 then n = (seqName == 'tray_cycle_00' or st ~= S.DEPOSIT) and 10 or 0 end
	if n == 0 then return end
	local m = self:ClientModel('resin', C.CartridgeModel)
	if not IsValid(m) then return end
	for i = 0, n - 1 do
		local p, a = C.Attachment(self, string.format('resin_attach_%02d', i))
		if p then
			m:SetModelScale(1, 0)
			m:SetPos(p)
			m:SetAngles(a)
			m:SetupBones()
			m:DrawModel()
		end
	end
end

function ENT:ScreenContext(st, cursor)
	local p = self:GetOperator()
	local viewer = LocalPlayer()
	local owner = IsValid(p) and p or viewer
	local ctx = {
		stage = st, t = CurTime(), tab = self:GetTab(), sel = self:GetSelection(),
		resin = owner:GetNWInt('cf_resin', 0), paid = self:GetPaid(), cost = self:GetCost(),
		printFrac = C.BuildProgress(self), status = self:GetStatusText(),
		boot = math.Clamp((CurTime() - self:GetDeployedAt()) / 0.8, 0, 1),
	}
	if IsValid(p) and p ~= viewer and st > S.MENU then ctx.busy = string.sub(p:Nick(), 1, 32) end
	if cursor then
		ctx.cursor = cursor
		ctx.hover = C.Layout.ButtonAt(st, self:GetTab(), cursor[1], cursor[2])
	end
	return ctx
end

function ENT:Draw()
	self:DrawModel()
	local dist = EyePos():DistToSqr(self:GetPos())
	if dist > 1500 * 1500 then self:FreeUnusedModels() return end
	local st = self:GetStage()
	local item = C.Items[self:GetSelection()]

	self:DrawResin(st)
	if st == S.PRINT or (st == S.DONE) then self:DrawItem(st, item) end

	-- hologram: hovered row in the menu, the chosen item while loading and printing
	local holo
	if st == S.DEPOSIT or st == S.PRINT then holo = item
	elseif st == S.MENU then
		local cur = C.FocusCursor(self)
		if not cur then local x, y = C.HitScreen(self, LocalPlayer()) cur = x and {x, y} end
		local b = cur and C.Layout.ButtonAt(st, self:GetTab(), cur[1], cur[2])
		if b and b.id == 'select' then holo = C.Items[b.arg] end
	end
	self:DrawHologram(holo)
	self:FreeUnusedModels()

	-- display on the model's own screen panel
	if self:GetDeployed() and dist < 420 * 420 then
		local origin, right, down, normal, _, scale, corner = C.ScreenWorld(self)
		if origin and (EyePos() - origin):Dot(normal) > 0 then
			-- dark glass behind the canvas fills the whole panel
			render.SetColorMaterial()
			local h = C.PANEL_H
			local up = -down
			render.DrawQuad(corner + normal * 0.015, corner + right * C.PANEL_W + normal * 0.015,
				corner + right * C.PANEL_W + up * h + normal * 0.015, corner + up * h + normal * 0.015, Color(4, 26, 32, 245))
			local cur = C.FocusCursor(self)
			if not cur then
				local x, y = C.HitScreen(self, LocalPlayer())
				cur = x and {x, y}
			end
			cam.Start3D2D(origin + normal * 0.03, right:AngleEx(normal), scale)
				C.UI.Draw(D, self:ScreenContext(st, cur))
			cam.End3D2D()
		end
	end
end

function ENT:Think()
	self:UpdateLook()
	if self:GetStage() ~= S.PRINT or EyePos():DistToSqr(self:GetPos()) > 500 * 500 then return end
	local progress = C.BuildProgress(self)
	if progress <= 0 or progress >= 1 then return end
	if (self.NextSpark or 0) > CurTime() then return end
	self.NextSpark = CurTime() + 0.12
	local origin = C.ItemPoint(self)
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
-- hints at the crosshair and the resin counter near a station
hook.Add('HUDPaint', C.HintHook or 'CFReworkHints', function()
	local p = LocalPlayer()
	if not IsValid(p) then return end
	local near
	for _, e in ipairs(ents.FindInSphere(p:EyePos(), 220)) do
		if e.IsCombineFabricator then near = e break end
	end
	if not near or C.FocusEnt() then return end
	local amber = Color(255, 196, 70)
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
