AddCSLuaFile()
ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Фабрикатор С24"
ENT.Category="Network"
ENT.Spawnable=true
ENT.AdminOnly=true
ENT.PhysgunDisabled=true
ENT.RenderGroup=RENDERGROUP_BOTH
function ENT:SetupDataTables()
 self:NetworkVar("String",0,"FabricatorName")
 self:NetworkVar("String",1,"Product")
 self:NetworkVar("String",2,"ProductData")
 self:NetworkVar("Int",0,"Phase")
 self:NetworkVar("Int",1,"Buyer")
 self:NetworkVar("Float",0,"CompleteAt")
 self:NetworkVar("Float",1,"BeginAt")
end
function ENT:GetDisplayName() return self:GetFabricatorName()!="" and self:GetFabricatorName() or "Фабрикатор С24" end
if (SERVER) then
 function ENT:SpawnFunction(p,tr)
  if (!tr.Hit) then return end
  local e=ents.Create("nw_fabricator") e:SetPos(tr.HitPos) e:SetAngles(Angle(0,p:EyeAngles().y+180,0)) e:Spawn() e:Activate() return e
 end
 function ENT:Initialize()
  self:SetModel(NETWORK.fabricator.GetModel())
  self:PhysicsInitBox(Vector(-24,-35,0),Vector(34,35,129))
  self:SetCollisionBounds(Vector(-24,-35,0),Vector(34,35,129))
  self:SetSolid(SOLID_VPHYSICS) self:SetMoveType(MOVETYPE_NONE) self:SetUseType(SIMPLE_USE)
  self.users={}
 end
 function ENT:Use(p)
  if (IsValid(p) and p:IsPlayer()) then NETWORK.fabricator.Open(p,self) end
 end
 function ENT:Think() NETWORK.fabricator.Tick(self) self:NextThink(CurTime()+0.1) return true end
 function ENT:OnRemove()
  for p in pairs(self.users or {}) do if (IsValid(p)) then NETWORK.fabricator.Close(p) end end
 end
else
 function ENT:Initialize() self:SetRenderBounds(Vector(-40,-65,0),Vector(60,65,135)) end
 function ENT:Draw()
  self:DrawModel()
  if (NETWORK.fabricator.DrawScreen) then NETWORK.fabricator.DrawScreen(self) end
  local id=self:GetProduct()
  if (id!="" and phase==2) then
   local base=NETWORK.item.Get(id)
   if (base and self.previewID!=id) then
    if (IsValid(self.preview)) then self.preview:Remove() end
    self.preview=ClientsideModel(base.model,RENDERGROUP_OPAQUE) self.previewID=id
    if (IsValid(self.preview)) then self.preview:SetNoDraw(true) end
   end
   if (IsValid(self.preview)) then
    self.preview:SetPos(self:LocalToWorld(Vector(14,0,87)))
    self.preview:SetAngles(self:LocalToWorldAngles(Angle(0,90,0))) self.preview:DrawModel()
   end
  elseif (IsValid(self.preview)) then self.preview:Remove() self.preview=nil self.previewID=nil end
 end
 function ENT:OnRemove() if (IsValid(self.preview)) then self.preview:Remove() end end
end
