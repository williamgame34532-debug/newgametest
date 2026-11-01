include('shared.lua')

-- the field: the HL:A energy field (hla_forcefield_content: combine_shield_02a baked into an animated
-- texture) or the HL2 Combine shield; the posts: the two HL:A emitters (combine_fence01a/01b_128) at the
-- ends of the field, otherwise the HL2 fence emitters
-- the field: comshieldwall3 (two scrolling textures, additive) as in ix_forcefield, from the
-- Combine Animated Prop's Pack; our own HL:A bake and the HL2 shield as fallbacks
local FIELD = {'effects/combineshield/comshieldwall3', 'hla/forcefield/field', 'effects/com_shield003a', 'effects/combinedisplay002a'}
local SHIELD_TILE = 64 -- world units per repeat of comshieldwall (ix_forcefield: 3 repeats over ~190)
local HL2_POSTS = {'models/props_combine/combine_fence01b.mdl', 'models/props_combine/combine_fence01a.mdl'}
local TILE = 96 -- HL2 shield: world units per texture repeat (the HL:A field spans the whole field once)

function ENT:Initialize()
	self.parts = {}
end

-- the entity itself is a tiny plate: without wide render bounds the engine stops drawing the posts and
-- the field as soon as its centre leaves the screen (they «vanished» when you came close)
function ENT:Think()
	local key = self:GetWidth() .. 'x' .. self:GetHeight()
	if self.boundsFor ~= key then
		self.boundsFor = key
		local mn, mx = self:Box()
		local d = self:GetPosts() and 8 or 24 -- room for the HL2 emitters drawn by the field itself
		self:SetRenderBounds(Vector(-d, mn.y - 30, -2), Vector(d, mx.y + 30, mx.z + 8))
	end
	self:SetNextClientThink(CurTime() + 0.2)
	return true
end

-- file.Exists on materials needs the .vmt
for i, f in ipairs(FIELD) do FIELD[i] = f .. '.vmt' end
local mats = {}
local LAYER2, BH = Material('hla/forcefield/field_layer2'), Material('hla/forcefield/field_bh')

-- one plane of the field at depth x, texture repeated u x v times; both faces when asked
function ENT:Quad(m, x, u, v, scroll, both)
	local w, h = self:GetWidth(), self:GetHeight()
	scroll = scroll or 0
	local p1 = self:LocalToWorld(Vector(x, w / 2, h))
	local p2 = self:LocalToWorld(Vector(x, -w / 2, h))
	local p3 = self:LocalToWorld(Vector(x, -w / 2, 0))
	local p4 = self:LocalToWorld(Vector(x, w / 2, 0))
	render.SetMaterial(m)
	-- two triangles per face, drawn explicitly
	for side = 1, both and 2 or 1 do
		local a, b, c, d = p1, p2, p3, p4
		local ua, ub = 0, u
		if side == 2 then a, b, c, d = p2, p1, p4, p3 ua, ub = u, 0 end
		mesh.Begin(MATERIAL_TRIANGLES, 2)
		mesh.Position(a) mesh.TexCoord(0, ua, scroll) mesh.Color(255, 255, 255, 255) mesh.AdvanceVertex()
		mesh.Position(b) mesh.TexCoord(0, ub, scroll) mesh.Color(255, 255, 255, 255) mesh.AdvanceVertex()
		mesh.Position(c) mesh.TexCoord(0, ub, scroll + v) mesh.Color(255, 255, 255, 255) mesh.AdvanceVertex()
		mesh.Position(a) mesh.TexCoord(0, ua, scroll) mesh.Color(255, 255, 255, 255) mesh.AdvanceVertex()
		mesh.Position(c) mesh.TexCoord(0, ub, scroll + v) mesh.Color(255, 255, 255, 255) mesh.AdvanceVertex()
		mesh.Position(d) mesh.TexCoord(0, ua, scroll + v) mesh.Color(255, 255, 255, 255) mesh.AdvanceVertex()
		mesh.End()
	end
end

function ENT:Parts()
	local hla = self:GetPosts()
	if self.partsKind == hla then return end
	self.partsKind = hla
	for _, m in ipairs(self.parts or {}) do if IsValid(m) then m:Remove() end end
	self.parts = {}
	local list = hla and {} or HL2_POSTS -- HL:A posts are entities of their own (hla_forcefield_post)
	for i, mdl in ipairs(list) do
		if file.Exists(mdl, 'GAME') then
			local m = ClientsideModel(mdl)
			if IsValid(m) then
				m:SetNoDraw(true)
				m.side = i == 1 and -1 or 1
				self.parts[#self.parts + 1] = m
			end
		end
	end
end

function ENT:OnRemove()
	for _, m in ipairs(self.parts or {}) do if IsValid(m) then m:Remove() end end
end

-- without HL:A posts the field shows the HL2 fence emitters at its ends itself
function ENT:Draw()
	self:Parts()
	local w = self:GetWidth()
	for _, m in ipairs(self.parts) do
		if IsValid(m) then
			m:SetPos(self:LocalToWorld(Vector(0, m.side * w / 2, 0)))
			m:SetAngles(self:LocalToWorldAngles(Angle(0, m.side == -1 and 0 or 180, 0)))
			m:SetupBones()
			m:DrawModel()
		end
	end
end

function ENT:DrawTranslucent()
	local since = CurTime() - self:GetSwitched()
	local on = self:GetOn()
	-- flickers when switched: on — comes up in bursts, off — dies in bursts
	local vis
	if on then vis = since > 0.5 or math.random() < since * 2
	else vis = since < 0.35 and math.random() < 0.5 end
	if not vis then return end
	-- the material chosen in the adjuster's menu (0 = the first one installed)
	local choice = self:GetMat()
	local name
	if choice > 0 and FIELD[choice] and file.Exists('materials/' .. FIELD[choice], 'GAME') then name = FIELD[choice]
	else name = self.Pick(FIELD, 'materials/') or 'effects/com_shield003a.vmt' end
	name = string.StripExtension(name)
	mats[name] = mats[name] or Material(name)
	local mat = mats[name]
	local matHLA, matShield = name == 'hla/forcefield/field', name == 'effects/combineshield/comshieldwall3'
	local w, h = self:GetWidth(), self:GetHeight()
	if matShield then
		-- both faces (the material does not draw its back), repeated over the size of the field
		self:Quad(mat, 0, w / SHIELD_TILE, h / SHIELD_TILE, 0, true)
	elseif matHLA then
		-- as on the HL:A maps: the energy field combine_shield_02a in the middle, and through the
		-- thickness of the field (8 units) the plasma layer combine_shield_layer2_temp and the faint
		-- combine_shield_bh, each on its own plane
		local t = self.Thick - 1
		self:Quad(mat, 0, 1, 1)
		self:Quad(LAYER2, t, 1, 1)
		self:Quad(BH, -t, 0.2, 1)
	else
		local scroll = CurTime() * 0.05
		self:Quad(mat, 0, w / TILE, h / TILE, scroll, true)
	end
	-- blue light on the floor and walls
	local dl = DynamicLight(self:EntIndex())
	if dl then
		dl.pos = self:LocalToWorld(Vector(0, 0, h / 2))
		dl.r, dl.g, dl.b = 70, 150, 255
		dl.brightness = 1.2
		dl.decay = 1000
		dl.size = math.max(w, h) * 1.3
		dl.dietime = CurTime() + 0.1
	end
end
