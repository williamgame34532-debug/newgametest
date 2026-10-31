include('shared.lua')

local glow = Material('sprites/light_glow02_add')

function ENT:Initialize()
	self:SetRenderBounds(Vector(-6, -6, -4), Vector(6, 6, 6))
end

function ENT:Draw()
	self:DrawModel()
	local k = 0.6 + 0.4 * math.sin(CurTime() * 3 + self:EntIndex())
	render.SetMaterial(glow)
	render.DrawSprite(self:WorldSpaceCenter(), 9 * k, 9 * k, Color(255, 170, 60, 160))
end
