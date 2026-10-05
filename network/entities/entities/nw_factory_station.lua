AddCSLuaFile()
ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Завод: производство / ОТК / отгрузка"
ENT.Category="Network"
ENT.Spawnable=true
ENT.AdminOnly=true
ENT.PhysgunDisabled=true
if (SERVER) then
 function ENT:SpawnFunction(p,tr)
  if (!tr.Hit or !p:IsAdmin()) then return end
  local e=ents.Create("nw_factory_station") e:SetPos(tr.HitPos+tr.HitNormal*4) e:SetAngles(Angle(0,p:EyeAngles().y+180,0)) e:Spawn() e:Activate()
  NETWORK.entities.Save() return e
 end
 function ENT:Initialize()
  self:SetModel("models/props_wasteland/controlroom_desk001b.mdl")
  self:PhysicsInit(SOLID_VPHYSICS) self:SetMoveType(MOVETYPE_NONE) self:SetSolid(SOLID_VPHYSICS) self:SetUseType(SIMPLE_USE)
 end
 function ENT:Use(p) if (IsValid(p) and p:IsPlayer() and p:HasCharacter()) then NETWORK.city.StartFactory(p,self) end end
 function ENT:Think() NETWORK.city.FactoryThink(self) self:NextThink(CurTime()+0.2) return true end
else
 function ENT:Draw()
  self:DrawModel()
  if (LocalPlayer():GetPos():DistToSqr(self:GetPos())>500*500) then return end
  local a=LocalPlayer():EyeAngles() a:RotateAroundAxis(a:Up(),-90) a:RotateAroundAxis(a:Forward(),90)
  cam.Start3D2D(self:WorldSpaceCenter()+Vector(0,0,32),a,0.1)
   draw.RoundedBox(4,-230,-35,460,80,Color(8,17,23,240))
   draw.SimpleText("C24 / ПРОИЗВОДСТВЕННАЯ ЛИНИЯ","nwChat",0,-15,Color(226,190,84),TEXT_ALIGN_CENTER)
   draw.SimpleText(self:GetNWString("nwOperation","")!="" and self:GetNWString("nwOperation") or "E • операция по вашей профессии","nwChatSmall",0,15,color_white,TEXT_ALIGN_CENTER)
  cam.End3D2D()
 end
end
