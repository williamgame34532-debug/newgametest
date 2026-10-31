include('shared.lua')

local holo = Material('cf_rework/holo/hologram')
local glow = Material('sprites/light_glow02_add')

function ENT:Initialize()
	self:SetRenderBounds(Vector(-4, -16, -20), Vector(20, 14, 24))
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
		local m = HLA.Station.Dir .. 'vial_hologram.mdl'
		self.Ghost = ClientsideModel(util.IsValidModel(m) and m or (HLA.Station.Dir .. 'health_vial.mdl'), RENDERGROUP_TRANSLUCENT)
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
