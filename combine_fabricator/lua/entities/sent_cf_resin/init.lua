AddCSLuaFile('shared.lua')
AddCSLuaFile('cl_init.lua')
include('shared.lua')

function ENT:Initialize()
	self:SetModel(CFRework.ResinModel)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:SetTrigger(true)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	local ph = self:GetPhysicsObject()
	if IsValid(ph) then ph:Wake() end
end

function ENT:Take(p)
	if self.Picked or not IsValid(p) or not p:IsPlayer() or not p:Alive() then return end
	if not CFRework.ChangeBalance(p, 1) then return end
	self.Picked = true
	p:EmitSound('items/ammo_pickup.wav', 55, 115)
	self:Remove()
end

function ENT:Use(p)
	if IsValid(p) and p:EyePos():DistToSqr(self:GetPos()) < 120 * 120 then self:Take(p) end
end

-- walking over resin picks it up
function ENT:StartTouch(e)
	if IsValid(e) and e:IsPlayer() then self:Take(e) end
end
