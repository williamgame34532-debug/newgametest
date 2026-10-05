local C = NETWORK.city
util.AddNetworkString("nwCityRequest")
util.AddNetworkString("nwCityReply")
util.AddNetworkString("nwPDAOpen")
C.logs = util.JSONToTable(file.Read("network/city_logs.txt", "DATA") or "[]") or {}
function C.Log(p, action, target)
 local row = {time = os.time(), name = IsValid(p) and p:GetCharacterName() or "Система", faction = IsValid(p) and p:GetCharacterFaction() or "", action = action, target = target or ""}
 table.insert(C.logs, 1, row)
 while (#C.logs > 200) do table.remove(C.logs) end
 file.CreateDir("network")
 file.Write("network/city_logs.txt", util.TableToJSON(C.logs))
end
local function Notice(p,text) NETWORK.notice.Send(p,text,"info") end
function C.Commit(p,state)
 p.nwInventory = state
 NETWORK.inventory.Sync(p)
 NETWORK.persistence.Save(p)
end
-- Copy first; validate all costs and output space before touching the live inventory.
function C.Transaction(p,cost,result,amount,cleanRations)
 local state = table.Copy(NETWORK.inventory.GetState(p))
 for id,needed in pairs(cost or {}) do
  local left = needed
  for _, key in ipairs({"items", "storage"}) do
   for index,item in pairs(state[key] or {}) do
    if (item.id == id and left > 0 and (!cleanRations or !item.data or item.data.left == nil)) then
     local take = math.min(left,item.amount or 1)
     left = left - take
     item.amount = (item.amount or 1) - take
     if (item.amount <= 0) then state[key][index] = nil end
    end
   end
  end
  if (left > 0) then return false,"Недостаточно ресурсов или паёк уже распакован: " .. id end
 end
 if (result) then
  local item = NETWORK.item.New(result,amount or 1)
  if (!item) then return false,"Предмет не зарегистрирован." end
  NETWORK.item.OnCreated(item,p,p:GetCharacter())
  if (NETWORK.inventory.Insert(state,item)>0) then return false,"Освободите место в инвентаре." end
 end
 C.Commit(p,state)
 return true
end
function C.UnpackTrash(p)
 local drops = {"scrap","wire"}
 local ok,err = C.Transaction(p,{trash_full=1},drops[math.random(#drops)],1)
 Notice(p,ok and "Мусор разобран: найден пригодный материал." or err)
end
function C.CanPlaceCamera(p)
 if (!C.IsCWU(p)) then return false,"Камеры устанавливает ГСР." end
 local own,total=0,0
 for _,e in ipairs(ents.FindByClass("nw_c24_camera")) do
  total=total+1
  if (e:GetOwnerCharacter()==p:GetCharacterID()) then own=own+1 end
 end
 if (total>=C.cameraLimit or own>=C.cameraPerChar) then return false,"Достигнут лимит камер." end
 for _,cp in ipairs(player.GetAll()) do
  if (cp:Alive() and cp:HasCharacter() and cp:GetCharacterFaction()=="cp" and
   cp:GetPos():DistToSqr(p:GetPos())<=C.cpRange*C.cpRange and cp:Visible(p)) then return true end
 end
 return false,"Для монтажа рядом должен находиться сотрудник ГО." 
end
function C.CameraAllowed(p,e)
 if (!IsValid(e) or e:GetClass()!="nw_c24_camera" or e:GetIntegrity()<=0) then return false end
 if (C.IsCWU(p) or C.IsAlliance(p)) then return true end
 return NETWORK.trap.IsRebel(p) and e.hackedBy and e.hackedBy[p:GetCharacterID()] == true
end
function C.CanTerminal(p)
 local e=p.nwCmbTerminal
 return IsValid(e) and e:GetClass()=="nw_cwuterminal" and !e:GetNWBool("nwBroken") and
  p:GetPos():DistToSqr(e:GetPos())<180*180
end
-- The PDA has no weapon: using the item opens the tablet as a stand-alone panel.
function C.OpenPDA(p)
 if (!p:Alive() or !C.HasPDA(p)) then return Notice(p,"Этот КПК недоступен вашей фракции.") end
 p.nwPDAChar=p:GetCharacterID()
 net.Start("nwPDAOpen") net.Send(p)
end
function C.Detonate(p)
 if (!p:Alive() or !NETWORK.trap.IsRebel(p) or !C.HasItem(p,"detonator")) then return end
 if ((p.nwDetonateAt or 0)>CurTime()) then return end
 p.nwDetonateAt=CurTime()+1
 local n=0
 for _,e in ipairs(ents.FindByClass("nw_remote_charge")) do
  if (e.nwOwnerChar==p:GetCharacterID() and e:GetArmed() and !e:GetSprung() and p:GetPos():DistToSqr(e:GetPos())<=2000*2000) then
   e.nwOwner=p e:Trigger(p) n=n+1
  end
 end
 Notice(p,"Сигнал отправлен. Зарядов: "..n)
end
function C.HackCamera(p,e)
 if (!NETWORK.trap.IsRebel(p) or !p:Alive() or p:GetPos():DistToSqr(e:GetPos())>110*110 or !p:Visible(e)) then return end
 if (e.hacker or (e.hackedBy and e.hackedBy[p:GetCharacterID()])) then return end
 e.hacker=p e.hackChar=p:GetCharacterID() e.hackEnd=CurTime()+C.hackTime
 NETWORK.FactoryProgress(p,"Взлом камеры С24",C.hackTime)
end
function C.CameraThink(e)
 local p=e.hacker
 if (!p) then return end
 if (!IsValid(p) or !p:Alive() or p:GetCharacterID()!=e.hackChar or !NETWORK.trap.IsRebel(p) or
  p:GetPos():DistToSqr(e:GetPos())>110*110 or !p:Visible(e)) then e.hacker=nil return end
 if (CurTime()<e.hackEnd) then return end
 e.hacker=nil
 e.hackedBy=e.hackedBy or {} e.hackedBy[p:GetCharacterID()]=true
 e:SetHackData(util.TableToJSON(e.hackedBy))
 e:SetIntegrity(math.max(e:GetIntegrity()-5,0))
 if (e:GetIntegrity()<=0) then e:DestroyCamera() return end
 NETWORK.entities.Save()
 C.Log(p,"Взлом камеры",e:GetCamName())
 Notice(p,"Перехват открыт. Прочность камеры снижена на 5. Команда: network_c24_cameras")
end
local function Reply(p,kind,data)
 net.Start("nwCityReply") net.WriteString(kind) NETWORK.util.WriteTable(data or {}) net.Send(p)
end
local function Profile(p)
 local c=p:GetCharacter()
 local class=NETWORK.classes.Get(p:GetNWString("nwClass",""))
 return {name=p:GetCharacterName(),cid=NETWORK.cid.Get(c:GetID()),faction=NETWORK.factions.GetName(c:GetFaction()),
  class=class and L(class.name) or "—",loyalty=p:GetLoyalty(),status=p:Alive() and "АКТИВЕН" or "НЕТ СИГНАЛА",id=c:GetID(),
  housing=NETWORK.apartments and NETWORK.apartments.Describe(c:GetID()) or nil,
  notes=NETWORK.cmbterm and NETWORK.cmbterm.notes and NETWORK.cmbterm.notes[tostring(c:GetID())] or nil}
end
local function Lookup(text)
 local cid=NETWORK.cid.Normalise(text)
 if (!cid) then return end
 for _,row in ipairs(sql.Query("SELECT id FROM network_characters") or {}) do
  local id=tonumber(row.id)
  if (NETWORK.cid.Get(id)==cid) then return id end
 end
end
local function Record(id)
 local record=NETWORK.admincomp.BuildRecord(id)
 if (!record) then return end
 record.loyalty=tonumber(NETWORK.loyalty.stored[tostring(id)]) or record.loyalty
 record.band=L(NETWORK.loyalty.GetBand(record.loyalty).label)
 record.status=record.bOnline and "В СЕТИ" or "НЕ В СЕТИ"
 record.housing=NETWORK.apartments and NETWORK.apartments.Describe(id) or nil
 return record
end
net.Receive("nwCityRequest",function(_,p)
 local action=net.ReadString()
 local payload=NETWORK.util.ReadTable() or {}
 if (!istable(payload)) then return end
 if (!p:HasCharacter() or !p:Alive()) then return end
 if (action=="close") then p.nwCityCamera=nil p.nwPDAChar=nil return end
 if ((p.nwCityNext or 0)>CurTime()) then return end
 p.nwCityNext=CurTime()+0.2
 local terminal=C.CanTerminal(p)
 local pda=C.HasPDA(p)
 if (action=="cameras") then
  local list={}
  for _,e in ipairs(ents.FindByClass("nw_c24_camera")) do
   if (C.CameraAllowed(p,e)) then list[#list+1]={index=e:EntIndex(),name=e:GetCamName(),hp=e:GetIntegrity()} end
  end
  return Reply(p,"cameras",{list=list})
 elseif (action=="watch") then
  local e=Entity(tonumber(payload.index) or -1)
  if (!C.CameraAllowed(p,e)) then return end
  if (!(terminal or pda or NETWORK.trap.IsRebel(p))) then return end
  p.nwCityCamera=e p.nwCityCameraChar=p:GetCharacterID() p.nwCityCameraExpires=CurTime()+12
  return Reply(p,"watch",{index=e:EntIndex(),name=e:GetCamName(),hp=e:GetIntegrity()})
 end
 if (!(terminal or pda)) then return end
 if (action=="profile") then return Reply(p,"profile",Profile(p)) end
 if (action=="logs") then
  local list={}
  for _,entry in ipairs(C.logs) do
   if (entry.faction=="worker" and #list<80) then list[#list+1]=entry end
  end
  -- Include existing equipment repair/terminal logs as well.
  for i=#NETWORK.cmbterm.journal,1,-1 do
   local entry=NETWORK.cmbterm.journal[i]
   if (entry.faction=="worker" and #list<100) then list[#list+1]=entry end
  end
  return Reply(p,"logs",{list=list})
 end
 if (action=="craft_camera" or action=="ration2" or action=="ration3" or action=="craft_pda") then
  if (!terminal or !C.IsCWU(p)) then return Notice(p,"Производство доступно ГСР у терминала.") end
  local costs=action=="craft_camera" and C.cameraCost or (action=="craft_pda" and {scrap=4,wire=2,resin=1} or {ration_basic=action=="ration2" and 3 or 5})
  local result=action=="craft_camera" and "c24_camera_kit" or (action=="craft_pda" and "pda_cwu" or (action=="ration2" and "ration_standard" or "ration_premium"))
  local ok,err=C.Transaction(p,costs,result,1,action=="ration2" or action=="ration3")
  if (ok) then C.Log(p,"Производство",result) end
  return Notice(p,ok and "Готово: "..NETWORK.item.Get(result).name or err)
 end
 if (!C.IsAlliance(p)) then return end
 -- Housing registry and address marking (purchased apartments are permanent registered residences).
 if (action=="housing") then return Reply(p,"housing",{list=NETWORK.apartments.Registry()}) end
 if (action=="mark") then
  local char=tonumber(payload.char) or Lookup(payload.cid)
  if (!char) then return Notice(p,"CID не найден.") end
  local door,data,kind=NETWORK.apartments.FindResidence(char)
  if (!IsValid(door)) then return Notice(p,"У гражданина нет зарегистрированного адреса.") end
  local who=NETWORK.cid.Get(char)
  NETWORK.terminal.SetMarker(p,door:GetPos(),"Адрес CID "..who..": "..NETWORK.apartments.Address(data),Color(226,62,58))
  C.Log(p,"Запрос адреса","CID "..who)
  return Notice(p,(kind=="purchase" and "Постоянный адрес" or "Временное жильё")..": "..NETWORK.apartments.Address(data).." — отмечено на карте.")
 end
 local id=Lookup(payload.cid)
 if (!id) then return Reply(p,"record",{error="CID не найден. Введите 5 цифр."}) end
 if (action=="loyalty" or action=="note") then
  local reason=NETWORK.util.Sanitise(tostring(payload.text or ""),240,true)
  if (#reason<3) then return Notice(p,"Укажите причину/заметку (3–240 символов).") end
  if ((p.nwPDAMutate or 0)>CurTime()) then return end
  p.nwPDAMutate=CurTime()+2
  if (action=="note") then NETWORK.cmbterm.AddNote(p,id,reason)
  else
   if (id==p:GetCharacterID()) then return Notice(p,"Нельзя менять собственные ОЛ.") end
   local delta=tonumber(payload.delta)
   if (delta!=1 and delta!=-1 and delta!=5 and delta!=-5) then return end
   local current=Record(id) if (!current) then return end
   local value=math.Clamp(current.loyalty+delta,NETWORK.loyalty.min,NETWORK.loyalty.max)
   NETWORK.loyalty.stored[tostring(id)]=value NETWORK.loyalty.Save()
   if (NETWORK.persistence.cache[tostring(id)]) then
    NETWORK.persistence.cache[tostring(id)].loyalty=value NETWORK.persistence.SaveAll()
   end
   for _,target in ipairs(player.GetAll()) do
    if (target:HasCharacter() and target:GetCharacterID()==id) then NETWORK.loyalty.Set(target,value) end
   end
   NETWORK.cmbterm.AddNote(p,id,"ОЛ "..(delta>0 and "+" or "")..delta..": "..reason)
  end
  C.Log(p,action=="note" and "Запись в базе CID" or "Изменение ОЛ",NETWORK.cid.Get(id)..": "..reason)
 end
 Reply(p,"record",Record(id) or {error="Запись недоступна."})
end)
hook.Add("SetupPlayerVisibility","nwCityCamera",function(p)
 local e=p.nwCityCamera
 if (IsValid(e) and p:Alive() and p:GetCharacterID()==p.nwCityCameraChar and (p.nwCityCameraExpires or 0)>CurTime() and C.CameraAllowed(p,e)) then
  AddOriginToPVS(e:GetPos()+e:GetForward()*8)
 else p.nwCityCamera=nil end
end)
hook.Add("NetworkMechanicRepaired","nwCityLog",function(p,e) C.Log(p,"Ремонт",NETWORK.mechanic.DescribeEntity(e)) end)
function C.StartFactory(p,e)
 local role=p:GetNWString("nwClass","") local recipe=C.jobRecipes[role]
 if (!C.IsCWU(p) or !recipe or !p:Alive()) then return Notice(p,"Здесь работают оператор, ОТК и логист завода.") end
 if (e.worker) then return end
 if (NETWORK.schedule and NETWORK.schedule.IsFactoryShift and !NETWORK.schedule.IsFactoryShift()) then return Notice(p,"Заводская смена закрыта.") end
 for _,breaker in ipairs(ents.FindInSphere(e:GetPos(),600)) do
  if (breaker:GetClass()=="nw_breaker" and breaker:GetNWBool("nwBroken")) then return Notice(p,"Нет питания: вызовите электрика.") end
 end
 e.worker=p e.workChar=p:GetCharacterID() e.role=role e.ends=CurTime()+recipe.duration
 e:SetNWString("nwOperation",recipe.name) e:SetNWFloat("nwWorkEnd",e.ends)
 NETWORK.FactoryProgress(p,recipe.name,recipe.duration)
end
function C.FactoryThink(e)
 local p=e.worker if (!p) then return end
 if (!IsValid(p) or !p:Alive() or p:GetCharacterID()!=e.workChar or p:GetNWString("nwClass","")!=e.role or !C.IsCWU(p) or p:GetPos():DistToSqr(e:GetPos())>130*130) then
  e.worker=nil e:SetNWString("nwOperation","") return
 end
 if (CurTime()<e.ends) then return end
 e.worker=nil e:SetNWString("nwOperation","")
 if (NETWORK.schedule and NETWORK.schedule.IsFactoryShift and !NETWORK.schedule.IsFactoryShift()) then return Notice(p,"Смена завершена; ресурсы сохранены.") end
 for _,breaker in ipairs(ents.FindInSphere(e:GetPos(),600)) do
  if (breaker:GetClass()=="nw_breaker" and breaker:GetNWBool("nwBroken")) then return Notice(p,"Производство прервано: нет питания. Ресурсы сохранены.") end
 end
 local recipe=C.jobRecipes[e.role]
 local ok,err=C.Transaction(p,recipe.cost,recipe.result)
 if (!ok) then return Notice(p,err) end
 if (recipe.reward) then NETWORK.currency.Add(p,recipe.reward) NETWORK.persistence.Save(p) end
 C.Log(p,recipe.name,recipe.result or "Отгрузка: +"..recipe.reward.." жетонов")
 Notice(p,recipe.name..": выполнено.")
end
-- Native context menu model configuration for the electrical box.
properties.Add("nw_factory_breaker_model",{
 MenuLabel="Модель электрощитка",Order=990,MenuIcon="icon16/brick_edit.png",
 Filter=function(_,e,p) return IsValid(e) and e:GetClass()=="nw_breaker" and p:IsAdmin() end,
 Receive=function(self,_,p)
  local e=net.ReadEntity() local model=net.ReadString()
  if (!self:Filter(e,p) or p:GetPos():DistToSqr(e:GetPos())>500*500 or #model>200 or !util.IsValidModel(model)) then return end
  e:SetBreakerModel(model) e:Apply() e:PhysicsInit(SOLID_VPHYSICS) e:SetMoveType(MOVETYPE_NONE)
  local phys=e:GetPhysicsObject() if (IsValid(phys)) then phys:EnableMotion(false) end
  NETWORK.entities.Save()
 end
})
-- Resistance supplies use existing crafting tables; no extra CWU workbench.
NETWORK.command.Register("radiocraft",{usage="/radiocraft charge|detonator",OnRun=function(_,p,args)
 if (!p:Alive() or !NETWORK.trap.IsRebel(p) or (p.nwRadioCraftAt or 0)>CurTime()) then return end
 local kind=args[1]
 if (kind!="charge" and kind!="detonator") then return Notice(p,"/radiocraft charge или /radiocraft detonator — у обычного верстака.") end
 local nearby=false
 for _,e in ipairs(ents.FindInSphere(p:GetPos(),120)) do
  if (NETWORK.craft.IsTable(e) and p:Visible(e)) then nearby=true break end
 end
 if (!nearby) then return Notice(p,"Подойдите к обычному верстаку.") end
 p.nwRadioCraftAt=CurTime()+2
 local cost=kind=="charge" and {scrap=6,wire=2,resin=2} or {scrap=3,wire=2}
 local ok,err=C.Transaction(p,cost,kind=="charge" and "remote_charge" or "detonator")
 Notice(p,ok and "Снаряжение готово." or err)
end})
