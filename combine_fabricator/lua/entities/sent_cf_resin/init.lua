AddCSLuaFile('shared.lua') AddCSLuaFile('cl_init.lua') include('shared.lua')
function ENT:Initialize()
 self:SetModel(CFRework.ResinModel) self:PhysicsInit(SOLID_VPHYSICS) self:SetMoveType(MOVETYPE_VPHYSICS) self:SetSolid(SOLID_VPHYSICS) self:SetUseType(SIMPLE_USE)
 local ph=self:GetPhysicsObject() if IsValid(ph) then ph:Wake() end
end
function ENT:Use(p)
 if self.Picked or not IsValid(p) or not p:IsPlayer() or not p:Alive() or p:EyePos():DistToSqr(self:GetPos())>120*120 then return end
 if not CFRework.ChangeBalance(p,1) then return end
 self.Picked=true p:EmitSound('items/ammo_pickup.wav',55,110) self:Remove()
end
