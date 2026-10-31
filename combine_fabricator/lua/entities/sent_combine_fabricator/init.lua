AddCSLuaFile('shared.lua') AddCSLuaFile('cl_init.lua') AddCSLuaFile('cl_screen.lua') AddCSLuaFile('cl_mechanism.lua')
include('shared.lua')
local C=CFRework local S=C.State
function ENT:Initialize()
 self:SetModel(C.Model) self:PhysicsInit(SOLID_VPHYSICS) self:SetMoveType(MOVETYPE_VPHYSICS) self:SetSolid(SOLID_VPHYSICS) self:SetUseType(SIMPLE_USE)
 local ph=self:GetPhysicsObject() if IsValid(ph) then ph:SetMass(200) ph:EnableMotion(false) end
 self:SetTab(1) self:SetSelection(1) self:ResetStation()
end
function ENT:SetAwake(wake)
 local target=wake and 1 or 0
 if self:GetMotionTo()==target then return end
 self:SetMotionFrom(C.Motion(self)) self:SetMotionTo(target) self:SetMotionStarted(CurTime())
 self:EmitSound('combine_fabricator/combine_3d_printer_eyestalk_'..(wake and 'extend' or 'retract')..'_01.wav',58,100)
 self.OpenSoundAt=wake and CurTime()+.55 or nil
end
function ENT:SetTrayTarget(target)
 if self:GetTrayTo()==target then return end
 self:SetTrayFrom(C.Tray(self)) self:SetTrayTo(target) self:SetTrayStarted(CurTime())
end
function ENT:SetPhase(state,duration)
 self:SetTrayTarget(state==S.DEPOSIT and 1 or 0)
 self:SetStage(state) self:SetStageStarted(CurTime()) self:SetStageUntil(CurTime()+(duration or 0))
end
function ENT:ResetStation()
 self:SetOperator(NULL) self:SetSlotMask(0) self:SetPaid(0) self:SetOrderCost(0) self:SetStatusText('')
 self.Order=nil self.OrderID=nil self.DrainAt=nil self:SetBatchDrainAt(0) self.LastAction=nil self:SetPhase(S.IDLE)
end
function ENT:RefundOrder()
 self:StopSound('combine_fabricator/combine_3d_printer_upgrading_01.wav')
 local paid=self:GetPaid() self:SetPaid(0) self:SetOrderCost(0) self:SetSlotMask(0) self.DrainAt=nil self:SetBatchDrainAt(0)
 if self.OrderID and paid>0 then C.Refund(self.OrderID,paid) end
 self.Order=nil self.OrderID=nil
end
function ENT:Notify(p,message)
 self:SetStatusText(message) self.MessageUntil=CurTime()+4
 if IsValid(p) then p:EmitSound('buttons/button10.wav',45,110) end
end
function ENT:Use(p)
 if not IsValid(p) or not p:IsPlayer() or not p:Alive() then return end
 if (p.CFReworkNextUse or 0)>CurTime() then return end
 p.CFReworkNextUse=CurTime()+.2
 local x,y=C.HitScreen(self,p) self:Interact(p,x,y,C.HitSlot(self,p))
end
function ENT:CanOrder(p,item)
 if item.kind=='weapon' and p:HasWeapon(item.class) then return false,'ЭТО ОРУЖИЕ УЖЕ ЕСТЬ' end
 if item.kind=='health' and p:Health()>=p:GetMaxHealth() then return false,'ЗДОРОВЬЕ УЖЕ ВОССТАНОВЛЕНО' end
 if item.kind=='armor' and p:Armor()>=100 then return false,'ЗАЩИТА УЖЕ ВОССТАНОВЛЕНА' end
 return true
end
function ENT:Interact(p,x,y,slot)
 if not IsValid(p) or not p:Alive() or p:EyePos():DistToSqr(self:GetPos())>180*180 then return end
 local state=self:GetStage() local owner=self:GetOperator()
 if IsValid(owner) and owner~=p then return end
 if state==S.IDLE then
  if not x then return end
  local b=C.ButtonAt(state,self:GetTab(),x,y) if not b or b.id~='login' then return end
  self:SetOperator(p) self.LastAction=CurTime() self:SetPhase(S.BOOT,1.5)
  self:EmitSound('combine_fabricator/combine_3d_printer_interface_open_01.wav',65,100) return
 end
 if owner~=p then return end
 self.LastAction=CurTime()
 if slot and state==S.DEPOSIT then self:InsertResin(p,slot) return end
 if not x then return end
 local b=C.ButtonAt(state,self:GetTab(),x,y) if not b then return end
 self:SetStatusText('') self:EmitSound('buttons/lightswitch2.wav',45,120)
 if b.id=='logout' then self:RefundOrder() self:ResetStation()
 elseif b.id=='category' then self:SetTab(b.arg) self:SetSelection(C.CategoryItems(b.arg)[1] or 0)
 elseif b.id=='select' then self:SetSelection(b.arg)
 elseif b.id=='order' then
  local item=C.Items[self:GetSelection()] if not item then return end
  local can,why=self:CanOrder(p,item) if not can then self:Notify(p,why) return end
  self.Order=table.Copy(item) self.OrderID=p:SteamID64() self:SetPaid(0) self:SetOrderCost(item.cost) self:SetSlotMask(0)
  self:SetPhase(S.DEPOSIT) self:EmitSound('combine_fabricator/combine_3d_printer_resin_tray_open_01.wav',60,100)
  if item.cost==0 then self:StartPrinting() end
 elseif b.id=='cancel' then self:RefundOrder() self:SetPhase(S.CATALOG)
 elseif b.id=='continue' then
  if self:Deliver() then
   self.Order=nil self.OrderID=nil self:SetPaid(0) self:SetOrderCost(0) self:SetPhase(S.CATALOG)
   self:EmitSound('combine_fabricator/print_item.wav',60,100)
  else self:RefundOrder() self:SetPhase(S.CATALOG) self:Notify(p,'ВЫДАЧА НЕ УДАЛАСЬ — СМОЛА ВОЗВРАЩЕНА') end
 end
end
function ENT:InsertResin(p,index)
 if not self.Order or self:GetOperator()~=p or self:GetStage()~=S.DEPOSIT or self.DrainAt or (self.NextInsert or 0)>CurTime() then return end
 local flag=2^(index-1) if bit.band(self:GetSlotMask(),flag)~=0 then return end
 if not C.ChangeBalance(p,-1) then self:Notify(p,'НЕТ СМОЛЫ — ПОДБЕРИТЕ ЕЁ ЧЕРЕЗ E') return end
 self:SetStatusText('') self.NextInsert=CurTime()+.25 self:SetPaid(self:GetPaid()+1) self:SetSlotMask(bit.bor(self:GetSlotMask(),flag))
 self:EmitSound('combine_fabricator/combine_3d_printer_resin_tray_advance_01.wav',62,100)
 if self:GetPaid()>=self.Order.cost then self:StartPrinting()
 elseif self:GetSlotMask()==15 then self.DrainAt=CurTime()+1.0 self:SetBatchDrainAt(self.DrainAt) end
end
function ENT:StartPrinting()
 self.DrainAt=nil self:SetBatchDrainAt(CurTime()+.65) self:SetPhase(S.PRINT,4.5)
 self.PrintSoundAt=CurTime()+.8
 self:EmitSound('combine_fabricator/combine_3d_printer_upgrader_open_01.wav',58,100)
 self:EmitSound('combine_fabricator/combine_3d_printer_upgrading_01.wav',68,100)
end
function ENT:Deliver()
 local p=self:GetOperator() local item=self.Order
 if not IsValid(p) or not p:Alive() or not item then return false end
 if item.kind=='weapon' then
  if p:HasWeapon(item.class) then return false end
  return IsValid(p:Give(item.class))
 elseif item.kind=='health' then
  if p:Health()>=p:GetMaxHealth() then return false end
  p:SetHealth(math.min(p:GetMaxHealth(),p:Health()+item.amount)) return true
 elseif item.kind=='armor' then
  if p:Armor()>=100 then return false end
  p:SetArmor(math.min(100,p:Armor()+item.amount)) return true
 elseif item.kind=='ammo' then return p:GiveAmmo(item.amount,item.ammo,true)>0 end
 return false
end
function ENT:Think()
 local now=CurTime() local st=self:GetStage() local p=self:GetOperator()
 if now>=(self.NextProximity or 0) then
  self.NextProximity=now+.35
  local awake=st~=S.IDLE
  if not awake then
   for _,visitor in ipairs(player.GetAll()) do
    if visitor:Alive() and visitor:GetPos():DistToSqr(self:GetPos())<170*170 then awake=true break end
   end
  end
  if awake then self.LastNearby=now end
  self:SetAwake(awake or now-(self.LastNearby or -10)<3)
 end
 if self.OpenSoundAt and now>=self.OpenSoundAt then self.OpenSoundAt=nil self:EmitSound('combine_fabricator/combine_3d_printer_chamber_open_01.wav',60,100) end
 if st~=S.IDLE and (not IsValid(p) or not p:Alive() or p:GetPos():DistToSqr(self:GetPos())>260*260 or now-(self.LastAction or now)>120) then self:RefundOrder() self:ResetStation() end
 if self.MessageUntil and now>=self.MessageUntil then self:SetStatusText('') self.MessageUntil=nil end
 if st==S.BOOT and self:GetStage()==S.BOOT and now>=self:GetStageUntil() then self:SetPhase(S.CATALOG) end
 if self.DrainAt and now>=self.DrainAt then self.DrainAt=nil self:SetBatchDrainAt(0) self:SetSlotMask(0) self:EmitSound('combine_fabricator/combine_3d_printer_resin_tray_retract_01.wav',58,100) end
 if self:GetStage()==S.PRINT and self.PrintSoundAt and now>=self.PrintSoundAt then self.PrintSoundAt=nil self:EmitSound('combine_fabricator/combine_3d_printer_gun_attach_print_01.wav',58,100) end
 if self:GetStage()==S.PRINT and now>=self:GetStageUntil() then
  self:StopSound('combine_fabricator/combine_3d_printer_upgrading_01.wav')
  self:SetBatchDrainAt(0) self:SetSlotMask(0) self:SetPhase(S.DONE)
  self:EmitSound('combine_fabricator/combine_3d_printer_work_complete_01.wav',65,100)
 end
 self:NextThink(now+.1) return true
end
function ENT:OnRemove() self:RefundOrder() end
