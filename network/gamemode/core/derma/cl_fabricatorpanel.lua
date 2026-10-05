local F=NETWORK.fabricator
local W,H,SCALE=640,400,49/640
local CYAN=Color(115,219,239)
local function Screen(e) return e:LocalToWorld(Vector(30.3,-24.5,69.5)),e:LocalToWorldAngles(Angle(0,90,90)) end
function F.ScreenButtons(e)
 local rows={}
 if (e:GetPhase()==2) then
  rows[1]={x=24,y=135,w=592,h=70,label="ЗАБРАТЬ ИЗДЕЛИЕ ИЗ ОТСЕКА",action="collect"}
 elseif (e:GetPhase()==0) then
  local page=IsValid(NETWORK.gui.fabricator) and NETWORK.gui.fabricator.page or 1
  local recipes=F.GetAll()
  for index=(page-1)*5+1,math.min(page*5,#recipes) do
   local recipe=recipes[index] local item=NETWORK.item.Get(recipe.item)
   local label=(item and NETWORK.item.GetName({id=recipe.item}) or recipe.item).." / "..(recipe.cost.resin or 0).." СМОЛЫ"
   rows[#rows+1]={x=24,y=84+(#rows)*45,w=592,h=37,label=label,action="craft",id=recipe.id}
  end
  rows[#rows+1]={x=24,y=324,w=365,h=44,label="СДАТЬ СМОЛУ В ФОНД",action="deposit"}
  rows[#rows+1]={x=405,y=324,w=95,h=44,label="<",action="prev"}
  rows[#rows+1]={x=512,y=324,w=104,h=44,label=">",action="next"}
 end
 return rows
end
function F.DrawScreen(e)
 if (EyePos():DistToSqr(e:GetPos())>700*700) then return end
 local pos,ang=Screen(e)
 cam.Start3D2D(pos,ang,SCALE)
  surface.SetDrawColor(3,13,18,255) surface.DrawRect(0,0,W,H)
  draw.SimpleText("C24 // FABRICATION SYSTEM","nwChat",24,15,CYAN)
  draw.SimpleText("ФОНД: "..F.GetPool().." / "..F.poolMax.." СМОЛЫ","nwChatSmall",24,48,Color(135,170,178))
  surface.SetDrawColor(65,145,162) surface.DrawRect(24,73,592,1)
  if (e:GetPhase()==1) then
   local f=math.Clamp(1-(e:GetCompleteAt()-CurTime())/8,0,1)
   draw.SimpleText("СИНТЕЗ ИЗДЕЛИЯ","nwChat",320,150,CYAN,TEXT_ALIGN_CENTER)
   surface.SetDrawColor(25,65,76) surface.DrawRect(40,210,560,12)
   surface.SetDrawColor(CYAN) surface.DrawRect(40,210,560*f,12)
   draw.SimpleText(math.floor(f*100).."%","nwChat",320,248,CYAN,TEXT_ALIGN_CENTER)
  else
   for _,b in ipairs(F.ScreenButtons(e)) do
    local p=NETWORK.gui.fabricator local hovered=IsValid(p) and p.hover==b.action..(b.id or "")
    surface.SetDrawColor(hovered and Color(35,85,99) or Color(12,34,44)) surface.DrawRect(b.x,b.y,b.w,b.h)
    surface.SetDrawColor(CYAN.r,CYAN.g,CYAN.b,hovered and 230 or 70) surface.DrawOutlinedRect(b.x,b.y,b.w,b.h,1)
    draw.SimpleText(b.label,"nwChatSmall",b.x+12,b.y+b.h/2,CYAN,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
   end
  end
 cam.End3D2D()
end
local PANEL={}
function PANEL:Init()
 NETWORK.gui.fabricator=self self.page=1
 self:SetSize(ScrW(),ScrH()) self:SetPos(0,0) self:MakePopup() self:SetCursor("blank")
 self.close=self:Add("DButton") self.close:SetText("Закрыть • ESC") self.close:SetSize(170,36) self.close:SetPos(ScrW()-190,20)
 self.close.DoClick=function() F.Request("close") end
end
function PANEL:Setup(e) self.entity=e end
function PANEL:OnCrafted() end
function PANEL:OnRemove() if (NETWORK.gui.fabricator==self) then NETWORK.gui.fabricator=nil end end
function PANEL:Think()
 if (!IsValid(self.entity) or !LocalPlayer():Alive()) then self:Remove() return end
 if (input.IsKeyDown(KEY_ESCAPE)) then F.Request("close") gui.HideGameUI() return end
 local pos,ang=Screen(self.entity)
 local x,y=gui.MousePos()
 local hit=util.IntersectRayWithPlane(EyePos(),gui.ScreenToVector(x,y),pos,ang:Up())
 self.hover=nil
 if (hit) then
  local relative=hit-pos local sx=relative:Dot(ang:Forward())/SCALE local sy=-relative:Dot(ang:Right())/SCALE
  for _,b in ipairs(F.ScreenButtons(self.entity)) do
   if (sx>=b.x and sx<=b.x+b.w and sy>=b.y and sy<=b.y+b.h) then
    self.hover=b.action..(b.id or "")
    if (input.IsMouseDown(MOUSE_LEFT) and !self.wasDown) then
     if (b.action=="next") then self.page=self.page%math.ceil(#F.GetAll()/5)+1
     elseif (b.action=="prev") then self.page=(self.page-2)%math.ceil(#F.GetAll()/5)+1
     else F.Request(b.action,b.id) end
    end
   end
  end
 end
 self.wasDown=input.IsMouseDown(MOUSE_LEFT)
end
function PANEL:Paint() end
function PANEL:PaintOver()
 local x,y=gui.MousePos() surface.SetDrawColor(CYAN) surface.DrawOutlinedRect(x-4,y-4,8,8,1)
 surface.DrawLine(x+7,y,x+16,y) surface.DrawLine(x,y+7,x,y+16)
end
vgui.Register("nwFabricatorPanel",PANEL,"EditablePanel")
function NETWORK.gui.OpenFabricator(e)
 NETWORK.gui.CloseWindows()
 local p=vgui.Create("nwFabricatorPanel") p:Setup(e) return p
end
function NETWORK.gui.CloseFabricator()
 if (IsValid(NETWORK.gui.fabricator)) then NETWORK.gui.fabricator:Remove() end
 NETWORK.gui.fabricator=nil
end
NETWORK.view.Register("fabricator", 950, function(p,view)
 local panel=NETWORK.gui.fabricator
 if (!IsValid(panel) or !IsValid(panel.entity)) then return end
 local e=panel.entity local origin=e:LocalToWorld(Vector(137,0,82))
 view.origin=origin view.angles=(e:LocalToWorld(Vector(15,0,67))-origin):Angle() view.fov=65 view.drawviewer=true
 return "stop"
end)
hook.Remove("PostDrawTranslucentRenderables","nwFabricatorLabel")
