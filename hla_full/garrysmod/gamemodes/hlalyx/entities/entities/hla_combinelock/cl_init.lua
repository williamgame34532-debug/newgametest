include('shared.lua')

local glow = Material('sprites/glow04_noz')
local GREEN = Color(40, 255, 90)
local BLUE = Color(40, 140, 255)
local RED = Color(255, 50, 50)

function ENT:Draw()
	self:DrawModel()
end

function ENT:DrawTranslucent()
	local col = self:GetDisplayError() and RED or (self:GetLocked() and BLUE or GREEN)
	local pos = self:GetPos() + self:GetUp() * -8.7 + self:GetForward() * -3.85 + self:GetRight() * -6
	local pulse = self:GetDisplayError() and (math.floor(RealTime() * 10) % 2 == 0 and 1 or 0.3) or 1
	render.SetMaterial(glow)
	render.DrawSprite(pos, 10, 10, Color(col.r, col.g, col.b, 255 * pulse))
end
