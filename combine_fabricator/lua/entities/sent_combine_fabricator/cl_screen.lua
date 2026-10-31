local C=CFRework local S=C.State
local ink=Color(6,24,30,255) local panel=Color(9,41,48,255)
local cyan=Color(91,230,231) local pale=Color(190,247,240) local muted=Color(69,139,145)
local amber=Color(255,190,97) local white=Color(225,255,249)
surface.CreateFont('CFRTitle',{font='Roboto Condensed',size=54,weight=700,extended=true})
surface.CreateFont('CFRHead',{font='Roboto Condensed',size=28,weight=700,extended=true})
surface.CreateFont('CFRText',{font='Roboto Condensed',size=23,weight=500,extended=true})
surface.CreateFont('CFRSmall',{font='Roboto Condensed',size=17,weight=500,extended=true})
surface.CreateFont('CFRMono',{font='Consolas',size=17,weight=500,extended=true})
surface.CreateFont('CFRNumber',{font='Roboto Condensed',size=58,weight=600,extended=true})
local function rect(x,y,w,h,c) surface.SetDrawColor(c) surface.DrawRect(x,y,w,h) end
local function line(x,y,x2,y2,c) surface.SetDrawColor(c) surface.DrawLine(x,y,x2,y2) end
local function outline(x,y,w,h,c,t) surface.SetDrawColor(c) surface.DrawOutlinedRect(x,y,w,h,t or 1) end
local function text(t,font,x,y,c,align) draw.SimpleText(t,font,x,y,c or pale,align or TEXT_ALIGN_LEFT,TEXT_ALIGN_TOP) end
local function corners(x,y,w,h,c)
 for _,v in ipairs({{x,y,1,1},{x+w,y,-1,1},{x,y+h,1,-1},{x+w,y+h,-1,-1}}) do line(v[1],v[2],v[1]+v[3]*14,v[2],c) line(v[1],v[2],v[1],v[2]+v[4]*14,c) end
end
local function wrap(str,x,y,w,font,c)
 surface.SetFont(font) local l=''
 for word in string.gmatch(str,'%S+') do
  local candidate=l=='' and word or l..' '..word
  local tw=surface.GetTextSize(candidate)
  if tw>w and l~='' then text(l,font,x,y,c) y=y+27 l=word else l=candidate end
 end
 if l~='' then text(l,font,x,y,c) end
 return y+27
end
local function logo(cx,cy,size,c)
 local r=size/2
 line(cx-r,cy,cx,cy-r,c) line(cx,cy-r,cx+r,cy,c) line(cx+r,cy,cx,cy+r,c) line(cx,cy+r,cx-r,cy,c)
 line(cx-r*.6,cy,cx,cy-r*.6,c) line(cx,cy-r*.6,cx+r*.6,cy,c) line(cx+r*.6,cy,cx,cy+r*.6,c) line(cx,cy+r*.6,cx-r*.6,cy,c)
 rect(cx-2,cy-r*.9,4,r*1.8,c) rect(cx-r*.9,cy-2,r*1.8,4,c)
end
local function button(b,label,hover,active)
 rect(b.x,b.y,b.w,b.h,active and Color(42,112,120) or hover and Color(29,91,102) or panel)
 outline(b.x,b.y,b.w,b.h,hover and white or active and cyan or muted,hover and 2 or 1)
 if hover then rect(b.x,b.y,4,b.h,white) end
 text(label,'CFRText',b.x+b.w/2,b.y+(b.h-23)/2,hover and white or pale,TEXT_ALIGN_CENTER)
end
function ENT:PaintFabricatorScreen(cursorX,cursorY)
 local st=self:GetStage() local t=CurTime() local p=self:GetOperator() local viewer=LocalPlayer()
 local operator=IsValid(p) and p or viewer local reserve=IsValid(operator) and operator:GetNWInt('cf_resin',0) or 0
 local selected=C.Items[self:GetSelection()] local hovered=cursorX and C.ButtonAt(st,self:GetTab(),cursorX,cursorY)
 rect(0,0,960,600,ink) outline(1,1,958,598,muted)
 -- Fine scan lines, one faint sweep; no fullscreen effect or light spam.
 for y=4,596,5 do line(2,y,957,y,Color(42,120,128,22)) end
 rect(2,(t*19)%590,956,2,Color(83,224,228,16))
 rect(8,14,3,572,cyan) corners(17,16,926,568,muted)
 if st==S.IDLE then
  text('CMB / INDUSTRIAL SYSTEMS','CFRMono',38,35,muted)
  text('TERMINAL 07  •  ONLINE','CFRMono',920,35,cyan,TEXT_ALIGN_RIGHT)
  logo(480,161,72,cyan)
  text('ФАБРИКАТОР','CFRTitle',480,229,white,TEXT_ALIGN_CENTER)
  text('СТАНЦИЯ СИНТЕЗА И СНАРЯЖЕНИЯ','CFRSmall',480,294,muted,TEXT_ALIGN_CENTER)
  line(330,344,630,344,muted)
  local b=C.Buttons(st,1)[1] button(b,'АВТОРИЗОВАТЬСЯ',hovered~=nil)
  text('НАВЕДИТЕ ПРИЦЕЛ НА КНОПКУ И НАЖМИТЕ E','CFRSmall',480,476,muted,TEXT_ALIGN_CENTER)
 elseif st==S.BOOT then
  text('УСТАНОВЛЕНИЕ СОЕДИНЕНИЯ','CFRHead',480,170,cyan,TEXT_ALIGN_CENTER)
  logo(480,267,80,cyan)
  local f=math.Clamp((t-self:GetStageStarted())/1.5,0,1)
  outline(240,360,480,6,muted) rect(240,360,480*f,6,cyan)
  text(f<.5 and 'ПРОВЕРКА ИДЕНТИФИКАТОРА...' or 'КАТАЛОГ ДОСТУПЕН','CFRMono',480,391,pale,TEXT_ALIGN_CENTER)
 elseif st==S.CATALOG then
  local buttons=C.Buttons(st,self:GetTab())
  for _,b in ipairs(buttons) do
   if b.id=='category' then button(b,C.Categories[b.arg],hovered and hovered.id==b.id and hovered.arg==b.arg,self:GetTab()==b.arg)
   elseif b.id=='logout' then button(b,'ВЫХОД',hovered and hovered.id=='logout') end
  end
  line(24,88,936,88,muted)
  text('НАИМЕНОВАНИЕ','CFRSmall',34,104,muted) text('СМОЛА','CFRSmall',511,104,muted,TEXT_ALIGN_RIGHT)
  text('СВОДКА / ВЫБРАННЫЙ ОБЪЕКТ','CFRSmall',573,104,muted)
  line(552,108,552,506,Color(29,80,87))
  for _,b in ipairs(buttons) do if b.id=='select' then
   local v=C.Items[b.arg] local active=self:GetSelection()==b.arg local over=hovered and hovered.id=='select' and hovered.arg==b.arg
   rect(b.x,b.y,b.w,b.h,active and Color(27,83,92) or over and Color(18,62,72) or panel)
   outline(b.x,b.y,b.w,b.h,active and cyan or over and pale or muted)
   if active then rect(b.x,b.y,4,b.h,cyan) end
   text(v.name,'CFRText',b.x+14,b.y+10,active and white or pale)
   text(v.subtitle,'CFRSmall',b.x+14,b.y+38,muted)
   text(v.cost,'CFRHead',b.x+b.w-15,b.y+17,cyan,TEXT_ALIGN_RIGHT)
  end end
  if selected then
   text('ОБЪЕКТ / '..string.format('%02d',self:GetSelection()),'CFRMono',573,143,muted)
   local nextY=wrap(selected.name,573,181,350,'CFRHead',white)
   nextY=wrap(selected.description,573,nextY+20,350,'CFRText',pale)
   line(573,335,928,335,muted)
   text('СТОИМОСТЬ','CFRSmall',573,353,muted) text(selected.cost,'CFRNumber',928,343,cyan,TEXT_ALIGN_RIGHT)
   for _,b in ipairs(buttons) do if b.id=='order' then button(b,'НАЧАТЬ ИЗГОТОВЛЕНИЕ',hovered and hovered.id=='order') end end
  end
 elseif st==S.DEPOSIT then
  text('ЗАГРУЗКА СМОЛЫ','CFRTitle',480,105,white,TEXT_ALIGN_CENTER)
  text(selected and selected.name or 'ЗАКАЗ','CFRText',480,173,cyan,TEXT_ALIGN_CENTER)
  for i=1,4 do
   local filled=bit.band(self:GetSlotMask(),2^(i-1))~=0 local x=280+(i-1)*105
   outline(x,240,82,100,filled and cyan or muted,2) corners(x-4,236,90,108,filled and cyan or muted)
   if filled then rect(x+9,249,64,66,Color(42,137,141)) end
   text(string.format('%02d',i),'CFRHead',x+41,274,filled and white or muted,TEXT_ALIGN_CENTER)
  end
  text(self:GetPaid()..' / '..self:GetOrderCost(),'CFRNumber',480,360,cyan,TEXT_ALIGN_CENTER)
  for _,b in ipairs(C.Buttons(st,self:GetTab())) do button(b,b.id=='cancel' and 'ОТМЕНИТЬ / ВЕРНУТЬ СМОЛУ' or 'ВЫХОД',hovered and hovered.id==b.id) end
  text('E ПО СВОБОДНОЙ ЯЧЕЙКЕ ПОД ЭКРАНОМ','CFRSmall',480,211,muted,TEXT_ALIGN_CENTER)
 elseif st==S.PRINT then
  text('СИНТЕЗ','CFRTitle',480,137,white,TEXT_ALIGN_CENTER)
  text(selected and selected.name or 'ИЗГОТОВЛЕНИЕ','CFRText',480,209,cyan,TEXT_ALIGN_CENTER)
  local f=math.Clamp((t-self:GetStageStarted())/math.max(.1,self:GetStageUntil()-self:GetStageStarted()),0,1)
  for i=1,32 do rect(176+(i-1)*19,315,13,23,i/32<=f and cyan or panel) end
  text(math.floor(f*100)..'%','CFRNumber',480,361,white,TEXT_ALIGN_CENTER)
  text('НЕ ПРЕРЫВАЙТЕ ПРОЦЕСС','CFRMono',480,446,muted,TEXT_ALIGN_CENTER)
 elseif st==S.DONE then
  logo(480,150,64,cyan)
  text('ГОТОВО','CFRTitle',480,231,white,TEXT_ALIGN_CENTER)
  text('ЗАБЕРИТЕ ИЗГОТОВЛЕННЫЙ ПРЕДМЕТ','CFRText',480,310,cyan,TEXT_ALIGN_CENTER)
  for _,b in ipairs(C.Buttons(st,self:GetTab())) do button(b,b.id=='continue' and 'ЗАБРАТЬ ПРЕДМЕТ' or 'ВЫХОД',hovered and hovered.id==b.id) end
 end
 line(24,531,936,531,muted)
 for i=0,37 do local h=8+((i*13+7)%23) rect(28+i*3,568-h,1,h,muted) end
 text('ЗАПАС СМОЛЫ','CFRSmall',171,548,muted) text(reserve,'CFRHead',320,542,cyan)
 text('CMB  /  07','CFRMono',919,551,muted,TEXT_ALIGN_RIGHT)
 if IsValid(p) and p~=viewer then
  rect(21,75,918,448,Color(3,17,23,235)) text('ТЕРМИНАЛ ЗАНЯТ','CFRTitle',480,230,white,TEXT_ALIGN_CENTER)
  text(string.sub(p:Nick(),1,32),'CFRText',480,307,cyan,TEXT_ALIGN_CENTER)
 end
 local msg=self:GetStatusText()
 if msg~='' then rect(24,494,912,31,Color(51,36,25,250)) text(msg,'CFRSmall',480,500,amber,TEXT_ALIGN_CENTER) end
 if cursorX and (not IsValid(p) or p==viewer) then
  line(cursorX-7,cursorY,cursorX-2,cursorY,white) line(cursorX+2,cursorY,cursorX+7,cursorY,white)
  line(cursorX,cursorY-7,cursorX,cursorY-2,white) line(cursorX,cursorY+2,cursorX,cursorY+7,white)
 end
end
