include('shared.lua')

local holo = Material('cf_rework/holo/hologram')
local glow = Material('sprites/light_glow02_add')

function ENT:Initialize()
	self:SetRenderBounds(Vector(-4, -20, -25), Vector(25, 18, 30))
end

function ENT:Think()
	if not self:GetHasVial() then return end
	local f, draining = self:Levels()
	local g = self:GetGauge()
	if IsValid(g) and g:GetSequence() == g:LookupSequence('idle_full') then g:SetCycle(math.Clamp(f, 0, 0.995)) end
	local v = self:GetVial()
	if IsValid(v) and draining and v:GetSequence() == v:LookupSequence('health_vial_larva_flush_anim') then v:SetCycle(math.Clamp(f, 0, 0.995)) end
end

function ENT:OnRemove()
	if IsValid(self.Ghost) then self.Ghost:Remove() end
end

function ENT:Draw()
	self:DrawModel()
	if self:GetHasVial() or EyePos():DistToSqr(self:GetPos()) > 600 * 600 then return end
	-- empty slot: the vial hologram, as in HL:A
	local pos, ang = self:VialSlot()
	if not pos then return end
	if not IsValid(self.Ghost) then
		-- the vial itself in the hologram material: the same shape and place as the real one
		self.Ghost = ClientsideModel(HLA.Station.Dir .. 'health_vial.mdl', RENDERGROUP_TRANSLUCENT)
		if not IsValid(self.Ghost) then return end
		self.Ghost:SetNoDraw(true)
	end
	self.Ghost:SetPos(pos)
	self.Ghost:SetAngles(ang)
	self.Ghost:SetupBones()
	local k = 0.6 + 0.4 * math.abs(math.sin(CurTime() * 2))
	render.MaterialOverride(holo)
	render.SetColorModulation(0.4 * k, 0.7 * k, 1.0 * k)
	self.Ghost:DrawModel()
	render.SetColorModulation(1, 1, 1)
	render.MaterialOverride()
	render.SetMaterial(glow)
	render.DrawSprite(pos, 10 * k, 10 * k, Color(80, 170, 255, 90))
end
