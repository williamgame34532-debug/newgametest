AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include('shared.lua')

function ENT:Initialize()
	self:SetModel(HLA.Items.Model(self:GetItemID()))
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	local ph = self:GetPhysicsObject()
	if IsValid(ph) then ph:Wake() end
end

-- glass items clink when they hit something
function ENT:PhysicsCollide(data)
	if data.Speed > 60 and self:GetItemID() == 'health_vial' and (self.NextClink or 0) < CurTime() then
		self.NextClink = CurTime() + 0.2
		self:EmitSound('hla/health_station/impact_a_0' .. math.random(1, 3) .. '.wav', 60)
	end
end
