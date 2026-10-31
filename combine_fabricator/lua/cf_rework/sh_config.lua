CFRework = CFRework or {}
local C=CFRework
C.Model='models/cf_rework/station.mdl'
C.ResinModel='models/cf_rework/resin_pickup.mdl'
C.CartridgeModel='models/cf_rework/resin_cartridge.mdl'
C.Width=960 C.Height=600 C.ScreenScale=.03
C.Front=Vector(1,0,0)
C.FramePos=Vector(24.8,0,40)
C.ScreenPos=Vector(26.05,-14.4,49)
C.ScreenDX=Vector(0,1,0) C.ScreenDY=Vector(0,0,-1)
C.ScreenAng=C.ScreenDX:AngleEx(C.ScreenDX:Cross(-C.ScreenDY))
C.Slots={Vector(29,-7.5,26),Vector(29,-2.5,26),Vector(29,2.5,26),Vector(29,7.5,26)}
C.CartridgeAng=Angle(-90,0,0)
C.Categories={'МЕДИЦИНА','ОРУЖИЕ','БОЕПРИПАСЫ'}
C.Items={
 {id='vial',category=1,name='МЕДИЦИНСКАЯ АМПУЛА',subtitle='Восстановление здоровья',description='Восстанавливает 10 единиц здоровья. Применяется после изготовления.',cost=2,kind='health',amount=10,model='models/healthvial.mdl'},
 {id='kit',category=1,name='МЕДИЦИНСКИЙ КОМПЛЕКТ',subtitle='Полевая медицинская помощь',description='Восстанавливает 25 единиц здоровья. Применяется после изготовления.',cost=5,kind='health',amount=25,model='models/items/healthkit.mdl'},
 {id='battery',category=1,name='ЭНЕРГОЯЧЕЙКА',subtitle='Восстановление защиты',description='Восстанавливает 15 единиц брони, до 100 единиц.',cost=4,kind='armor',amount=15,model='models/items/battery.mdl'},
 {id='pistol',category=2,name='ПИСТОЛЕТ 9 ММ',subtitle='Личное оружие',description='Полуавтоматический пистолет. Выдаётся владельцу заказа.',cost=10,kind='weapon',class='weapon_pistol',model='models/weapons/w_pistol.mdl'},
 {id='smg',category=2,name='ПИСТОЛЕТ-ПУЛЕМЁТ',subtitle='Автоматическое оружие',description='Компактное автоматическое оружие ближнего боя.',cost=20,kind='weapon',class='weapon_smg1',model='models/weapons/w_smg1.mdl'},
 {id='shotgun',category=2,name='ДРОБОВИК',subtitle='Оружие ближнего боя',description='Помповый дробовик. Выдаётся владельцу заказа.',cost=35,kind='weapon',class='weapon_shotgun',model='models/weapons/w_shotgun.mdl'},
 {id='ar2',category=2,name='ИМПУЛЬСНАЯ ВИНТОВКА',subtitle='Вооружение Альянса',description='Штурмовая импульсная винтовка.',cost=45,kind='weapon',class='weapon_ar2',model='models/weapons/w_irifle.mdl'},
 {id='ammo_pistol',category=3,name='ПАТРОНЫ 9 ММ',subtitle='30 патронов',description='Пополняет запас пистолетных патронов на 30.',cost=2,kind='ammo',ammo='Pistol',amount=30,model='models/items/boxsrounds.mdl'},
 {id='ammo_smg',category=3,name='ПАТРОНЫ ПП',subtitle='45 патронов',description='Пополняет запас патронов пистолета-пулемёта на 45.',cost=3,kind='ammo',ammo='SMG1',amount=45,model='models/items/boxmrounds.mdl'},
 {id='ammo_shotgun',category=3,name='ДРОБЬ',subtitle='12 патронов',description='Пополняет запас дробовых патронов на 12.',cost=4,kind='ammo',ammo='Buckshot',amount=12,model='models/items/boxbuckshot.mdl'},
 {id='ammo_ar2',category=3,name='ИМПУЛЬСНЫЕ ЗАРЯДЫ',subtitle='30 зарядов',description='Пополняет запас импульсной винтовки на 30.',cost=5,kind='ammo',ammo='AR2',amount=30,model='models/items/combine_rifle_cartridge01.mdl'}
}
C.State={IDLE=0,BOOT=1,CATALOG=2,DEPOSIT=3,PRINT=4,DONE=5}
function C.CategoryItems(cat)
 local out={} for i,v in ipairs(C.Items) do if v.category==cat then out[#out+1]=i end end return out
end
function C.ScreenTransform(e)
 return e:LocalToWorld(C.ScreenPos),e:LocalToWorldAngles(C.ScreenAng)
end
function C.HitScreen(e,p)
 if not IsValid(p) or C.Panel(e)<.98 then return end
 local pos,ang=C.ScreenTransform(e) local eye=p:EyePos() local dir=p:GetAimVector()
 if eye:DistToSqr(pos)>140*140 or dir:Dot(ang:Up())>=-.05 then return end
 local hit=util.IntersectRayWithPlane(eye,dir,pos,ang:Up()) if not hit then return end
 local delta=hit-pos local x=delta:Dot(ang:Forward())/C.ScreenScale local y=delta:Dot(ang:Right())/C.ScreenScale
 if x<0 or x>C.Width or y<0 or y>C.Height then return end
 local tr=util.TraceLine({start=eye,endpos=hit,filter={p,e},mask=MASK_SOLID})
 if tr.Hit and tr.HitPos:DistToSqr(hit)>1 then return end
 return x,y,hit
end
function C.HitSlot(e,p)
 if C.Tray(e)<.95 then return end
 local origin=p:EyePos() local ray=p:GetAimVector() local best,bestd
 for i,v in ipairs(C.Slots) do
  local pos=e:LocalToWorld(C.SlotPosition(e,i)) local diff=pos-origin local t=diff:Dot(ray)
  if (origin-pos):Dot(e:LocalToWorld(C.Front)-e:GetPos())>0 and t>0 and t<130 and (diff-ray*t):LengthSqr()<2.5*2.5 then
   local tr=util.TraceLine({start=origin,endpos=pos,filter={p,e},mask=MASK_SOLID})
   if not tr.Hit and (not bestd or t<bestd) then best=i bestd=t end
  end
 end
 return best
end
function C.Buttons(stage,cat)
 local b={}
 if stage==C.State.IDLE then return {{id='login',x=280,y=385,w=400,h=68}} end
 if stage==C.State.BOOT or stage==C.State.PRINT then return b end
 b[#b+1]={id='logout',x=820,y=26,w=116,h=36}
 if stage==C.State.CATALOG then
  for i=1,3 do b[#b+1]={id='category',arg=i,x=24+(i-1)*205,y=26,w=196,h=46} end
  for row,index in ipairs(C.CategoryItems(cat)) do b[#b+1]={id='select',arg=index,x=24,y=134+(row-1)*73,w=505,h=63} end
  b[#b+1]={id='order',x=572,y=430,w=355,h=62}
 elseif stage==C.State.DEPOSIT then b[#b+1]={id='cancel',x=300,y=450,w=360,h=54}
 elseif stage==C.State.DONE then b[#b+1]={id='continue',x=300,y=410,w=360,h=65} end
 return b
end
function C.ButtonAt(stage,cat,x,y)
 for _,b in ipairs(C.Buttons(stage,cat)) do if x>=b.x and y>=b.y and x<=b.x+b.w and y<=b.y+b.h then return b end end
end
