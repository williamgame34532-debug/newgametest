include('shared.lua')
function ENT:Initialize() self:SetRenderBounds(Vector(-4,-4,-3),Vector(4,4,3)) end
function ENT:Draw() self:DrawModel() end
