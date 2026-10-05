AddCSLuaFile()
SWEP.PrintName="Служебный КПК"
SWEP.Author="Network"
SWEP.Category="Network"
SWEP.Spawnable=false
SWEP.Slot=4
SWEP.DrawAmmo=false
SWEP.DrawCrosshair=false
SWEP.UseHands=false
SWEP.ViewModel="models/weapons/c_arms_animations.mdl"
SWEP.WorldModel="models/props_lab/clipboard.mdl"
SWEP.Primary.ClipSize=-1
SWEP.Primary.DefaultClip=-1
SWEP.Primary.Automatic=false
SWEP.Primary.Ammo="none"
SWEP.Secondary.ClipSize=-1
SWEP.Secondary.DefaultClip=-1
SWEP.Secondary.Automatic=false
SWEP.Secondary.Ammo="none"
function SWEP:Initialize() self:SetHoldType("slam") end
function SWEP:Deploy() self.equipAt=CurTime() return true end
function SWEP:PrimaryAttack()
 self:SetNextPrimaryFire(CurTime()+1)
 if (SERVER) then NETWORK.city.OpenPDA(self:GetOwner()) end
end
function SWEP:SecondaryAttack() end
function SWEP:Reload()
 if (CLIENT and IsValid(NETWORK.city.frame)) then NETWORK.city.frame:Close() end
end
function SWEP:Holster()
 if (CLIENT and IsValid(NETWORK.city.frame) and !NETWORK.city.frame.terminal) then NETWORK.city.frame:Close() end
 return true
end
if (CLIENT) then
 function SWEP:PreDrawViewModel() return true end
 function SWEP:DrawWorldModel()
  local p=self:GetOwner()
  if (!IsValid(p) or !NETWORK.cityModels) then return end
  local bone=p:LookupBone("ValveBiped.Bip01_R_Hand")
  if (!bone) then return end
  local pos,ang=p:GetBonePosition(bone)
  ang:RotateAroundAxis(ang:Forward(),90)
  NETWORK.cityModels.Draw("pda_",pos,ang,.55,0)
 end
 function SWEP:DrawHUD()
  local p=self:GetOwner()
  if (!IsValid(p) or !NETWORK.cityModels or (NETWORK.city and NETWORK.city.rendering)) then return end
  local f=math.Clamp((CurTime()-(self.equipAt or CurTime()))/.46,0,1) f=f*f*(3-2*f)
  local ang=EyeAngles() local pos=EyePos()+ang:Forward()*25+ang:Up()*(-1-(1-f)*18)
  ang=Angle(ang.p,ang.y+180,ang.r)
  local idle=math.sin(CurTime()*1.2)*.04
  cam.Start3D(EyePos(),EyeAngles())
   render.SuppressEngineLighting(false)
   NETWORK.cityModels.Draw("pda_",pos+Vector(0,0,idle),ang,1,0)
   NETWORK.cityModels.Draw("hand_",pos+Vector(0,0,idle),ang,1,input.IsMouseDown(MOUSE_LEFT) and 1 or 0)
  cam.End3D()
  if (!IsValid(NETWORK.city.frame)) then
   draw.SimpleText("ЛКМ — открыть КПК  •  R — закрыть","nwChatSmall",ScrW()/2,ScrH()-80,Color(139,213,235),TEXT_ALIGN_CENTER)
  end
 end
end
