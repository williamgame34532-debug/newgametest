include('shared.lua') include('cl_screen.lua') include('cl_mechanism.lua')
local C=CFRework local S=C.State
local glow=Material('sprites/light_glow02_add') local socketmat=Material('models/cf_rework/socket')
local wire=Material('models/wireframe')
local sleeve
local function socketMesh()
 if sleeve then return sleeve end
 local tris={}
 local function vertex(p,n,u,v) return {pos=p,normal=n,u=u,v=v} end
 local function quad(a,b,c,d,n)
  for _,v in ipairs({vertex(a,n,0,0),vertex(b,n,1,0),vertex(c,n,1,1),vertex(a,n,0,0),vertex(c,n,1,1),vertex(d,n,0,1)}) do tris[#tris+1]=v end
 end
 for i=0,47 do
  local a=i*math.pi/24 local b=(i+1)*math.pi/24
  local function pt(r,z,t) return Vector(math.cos(t)*r,math.sin(t)*r,z) end
  local n=Vector(math.cos((a+b)/2),math.sin((a+b)/2),0)
  quad(pt(2.25,-1,a),pt(2.25,-1,b),pt(2.25,3,b),pt(2.25,3,a),n)
  quad(pt(1.65,-1,b),pt(1.65,-1,a),pt(1.65,3,a),pt(1.65,3,b),-n)
  quad(pt(1.65,-1,a),pt(1.65,-1,b),pt(2.25,-1,b),pt(2.25,-1,a),Vector(0,0,-1))
  quad(pt(2.25,3,a),pt(2.25,3,b),pt(1.65,3,b),pt(1.65,3,a),Vector(0,0,1))
 end
 sleeve=Mesh() sleeve:BuildFromTriangles(tris) return sleeve
end
function ENT:Initialize()
 self.CFModels={} self.CFSlotLerp={0,0,0,0} self.CFSlotPull={} self.CFSlotFilled={}
 self:SetRenderBounds(Vector(-55,-100,-5),Vector(55,65,100))
end
function ENT:ClientModel(key,path)
 self.CFModels=self.CFModels or {}
 local m=self.CFModels[key]
 if not IsValid(m) then m=ClientsideModel(path,RENDERGROUP_OPAQUE) if not IsValid(m) then return end m:SetNoDraw(true) self.CFModels[key]=m end
 return m
end
function ENT:OnRemove()
 for _,m in pairs(self.CFModels or {}) do if IsValid(m) then m:Remove() end end
end
function ENT:Draw()
 local open=C.Motion(self)
 self:DrawAnimatedShell(open)
 local d=EyePos():DistToSqr(self:GetPos()) if d>1600*1600 then return end
 if open<.01 then return end
 self:DrawMechanism(open)
 if d>700*700 then return end
 local state=self:GetStage() local mask=self:GetSlotMask()
 for i,slot in ipairs(C.Slots) do
  local v=C.SlotPosition(self,i)
  local filled=bit.band(mask,2^(i-1))~=0 local previous=self.CFSlotLerp[i] or 0
  self.CFSlotLerp[i]=Lerp(math.min(FrameTime()*10,1),previous,filled and 1 or 0)
  local a=self:LocalToWorldAngles(C.CartridgeAng) local pos=self:LocalToWorld(v)
  local matrix=Matrix() matrix:SetTranslation(pos) matrix:SetAngles(a)
  render.SetMaterial(socketmat) cam.PushModelMatrix(matrix) socketMesh():Draw() cam.PopModelMatrix()
  if self.CFSlotLerp[i]>.01 then
   local m=self:ClientModel('resin'..i,C.CartridgeModel)
   if IsValid(m) then local drain=self:GetBatchDrainAt()
    if filled and not self.CFSlotFilled[i] then self.CFSlotPull[i]=0 end
    local pull=drain>0 and C.Ease((CurTime()-(drain-.55))/.55)*9 or (filled and 0 or (self.CFSlotPull[i] or 0))
    self.CFSlotPull[i]=pull
    m:SetPos(self:LocalToWorld(v+Vector(5-self.CFSlotLerp[i]*3-pull,0,0))) m:SetAngles(a) m:SetupBones() m:DrawModel() end
  end
  self.CFSlotFilled[i]=filled
  render.SetMaterial(glow) render.DrawSprite(self:LocalToWorld(v+Vector(1.2,0,2.7)),.7,.7,filled and Color(93,244,233) or Color(43,90,95))
 end
 if d<500*500 then
  local item=C.Items[self:GetSelection()]
  if item and state>=S.CATALOG then
   if self.CFPreviewPath~=item.model then
    if self.CFModels and IsValid(self.CFModels.preview) then self.CFModels.preview:Remove() self.CFModels.preview=nil end
    self.CFPreviewPath=item.model
   end
   local m=self:ClientModel('preview',item.model)
   if IsValid(m) then
    local center=self:LocalToWorld(Vector(15,0,66))
    m:SetModelScale(.65,0) m:SetAngles(self:LocalToWorldAngles(Angle(0,CurTime()*18,0)))
    m:SetPos(center) m:SetupBones()
    local localCenter=m:OBBCenter() local offset=LocalToWorld(localCenter*.65,angle_zero,vector_origin,m:GetAngles())
    m:SetPos(center-offset)
    local printed=state==S.PRINT and math.Clamp((CurTime()-self:GetStageStarted())/4.5,0,1) or 0
    if state~=S.DONE then render.MaterialOverride(wire) render.SetColorModulation(.2,.65,.68) end
    render.SetBlend(state==S.DONE and 1 or (state==S.PRINT and .2+printed*.5 or .18))
    m:DrawModel() render.SetBlend(1) render.SetColorModulation(1,1,1) render.MaterialOverride()
    if state==S.PRINT then
     local up=self:GetUp() local scan=self:LocalToWorld(Vector(15,0,57+printed*19))
     local previousClip=render.EnableClipping(true)
     render.PushCustomClipPlane(-up,(-up):Dot(scan))
     m:DrawModel()
     render.PopCustomClipPlane() render.EnableClipping(previousClip)
     render.SetMaterial(glow) render.DrawSprite(center,7,7,Color(55,220,225,110))
     local z=58+((CurTime()-self:GetStageStarted())*8)%19
     render.SetMaterial(wire) render.DrawBeam(self:LocalToWorld(Vector(15,-10,z)),self:LocalToWorld(Vector(15,10,z)),.15,0,1,Color(77,240,245,160))
    end
   end
  end
 end
 if d>420*420 or C.Panel(self)<.05 then return end
 local pos,ang=C.ScreenTransform(self) if (EyePos()-pos):Dot(ang:Up())<=0 then return end
 local x,y=C.HitScreen(self,LocalPlayer())
 cam.Start3D2D(pos,ang,C.ScreenScale) self:PaintFabricatorScreen(x,y) cam.End3D2D()
end
hook.Add('PlayerBindPress','CFReworkScreenClick',function(p,bind,pressed)
 if not pressed or bind~='+attack' then return end
 for _,e in ipairs(ents.FindInSphere(p:EyePos(),180)) do
  if e:GetClass()=='sent_combine_fabricator' then
   local x,y=C.HitScreen(e,p)
   if x then net.Start('cf_rework_click') net.WriteEntity(e) net.SendToServer() return true end
  end
 end
end)
hook.Add('HUDPaint','CFReworkSlotHint',function()
 local p=LocalPlayer() if not IsValid(p) then return end
 for _,e in ipairs(ents.FindInSphere(p:EyePos(),150)) do
  if e:GetClass()=='sent_combine_fabricator' and e:GetStage()==S.DEPOSIT and e:GetOperator()==p then
   local i=C.HitSlot(e,p)
   if i then
    local filled=bit.band(e:GetSlotMask(),2^(i-1))~=0
    draw.SimpleTextOutlined(filled and 'ЯЧЕЙКА '..i..' ЗАПОЛНЕНА' or 'E — ВСТАВИТЬ СМОЛУ В ЯЧЕЙКУ '..i,'CFRText',ScrW()/2,ScrH()*.64,Color(172,243,238),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,Color(0,0,0,160))
   end
  end
 end
end)

function ENT:Think()
 if self:GetStage()~=S.PRINT or EyePos():DistToSqr(self:GetPos())>450*450 then return end
 local elapsed=CurTime()-self:GetStageStarted()
 if elapsed<.65 or elapsed>3.8 or (self.CFNextParticle or 0)>CurTime() then return end
 self.CFNextParticle=CurTime()+.22
 local origin=self:LocalToWorld(Vector(19,0,52))
 local emitter=ParticleEmitter(origin,false)
 if not emitter then return end
 local p=emitter:Add('particle/particle_smokegrenade',origin)
 if p then
  p:SetVelocity(self:GetUp()*7+self:GetRight()*3) p:SetDieTime(.8) p:SetStartAlpha(28) p:SetEndAlpha(0)
  p:SetStartSize(1) p:SetEndSize(4) p:SetRoll(math.Rand(-1,1)) p:SetRollDelta(.15)
  p:SetColor(93,116,118) p:SetAirResistance(20) p:SetLighting(true) p:SetCollide(false)
 end
 emitter:Finish()
end
