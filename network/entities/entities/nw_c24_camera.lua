AddCSLuaFile()
ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Камера С24"
ENT.Category="Network"
ENT.Spawnable=false
ENT.PhysgunDisabled=true
function ENT:SetupDataTables()
 self:NetworkVar("String",0,"CamName")
 self:NetworkVar("String",1,"HackData")
 self:NetworkVar("Int",0,"Integrity")
 self:NetworkVar("Int",1,"OwnerCharacter")
end
if (SERVER) then
 function ENT:Initialize()
  self:SetModel("models/dav0r/camera.mdl") self:PhysicsInit(SOLID_VPHYSICS)
  self:SetMoveType(MOVETYPE_NONE) self:SetSolid(SOLID_VPHYSICS) self:SetUseType(SIMPLE_USE)
  self:SetIntegrity(20)
  local phys=self:GetPhysicsObject() if (IsValid(phys)) then phys:EnableMotion(false) end
 end
 function ENT:Use(p) if (IsValid(p) and p:IsPlayer()) then NETWORK.city.HackCamera(p,self) end end
 function ENT:Think()
  if (!self.hackedBy) then
   self.hackedBy={}
   for id,v in pairs(util.JSONToTable(self:GetHackData()) or {}) do self.hackedBy[tonumber(id)]=v end
  end
  NETWORK.city.CameraThink(self) self:NextThink(CurTime()+0.15) return true
 end
 function ENT:OnTakeDamage(info)
  self:SetIntegrity(math.max(self:GetIntegrity()-math.ceil(info:GetDamage()),0))
  if (self:GetIntegrity()<=0) then self:DestroyCamera() end
 end
 function ENT:DestroyCamera()
  if (self.destroyed) then return end self.destroyed=true
  NETWORK.item.Spawn("scrap",self:GetPos()+Vector(0,0,8),nil,2)
  self:EmitSound("physics/metal/metal_box_break1.wav",65)
  self:Remove()
  timer.Simple(0,function() NETWORK.entities.Save() end)
 end
else
 function ENT:Draw() self:DrawModel() end
end
