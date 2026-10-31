local C=CFRework
file.CreateDir('cf_rework') file.CreateDir('cf_rework/balances')
local function validID(id) return isstring(id) and id:match('^%d+$') end
function C.ReadBalance(id)
 if not validID(id) then return 0 end
 return math.Clamp(math.floor(tonumber(file.Read('cf_rework/balances/'..id..'.txt','DATA')) or 0),0,1000000)
end
function C.StoreBalance(id,n)
 if not validID(id) then return false end
 file.Write('cf_rework/balances/'..id..'.txt',tostring(math.Clamp(math.floor(n),0,1000000))) return true
end
function C.Balance(p) return p:GetNWInt('cf_resin',0) end
function C.ChangeBalance(p,delta)
 if not IsValid(p) then return false end
 local n=C.Balance(p)+delta if n<0 or n>1000000 then return false end
 p:SetNWInt('cf_resin',n) C.StoreBalance(p:SteamID64(),n) return true
end
function C.Refund(id,amount)
 if amount<=0 then return end
 for _,p in ipairs(player.GetAll()) do if p:SteamID64()==id then C.ChangeBalance(p,amount) return end end
 C.StoreBalance(id,C.ReadBalance(id)+amount)
end
hook.Add('PlayerInitialSpawn','CFReworkLoadBalance',function(p)
 timer.Simple(0,function() if IsValid(p) then p:SetNWInt('cf_resin',C.ReadBalance(p:SteamID64())) end end)
end)
-- Refunding before disconnect also saves the restored balance.
hook.Add('PlayerDisconnected','CFReworkDisconnect',function(p)
 for _,e in ipairs(ents.FindByClass('sent_combine_fabricator')) do if e:GetOperator()==p then e:RefundOrder() e:ResetStation() end end
end)
hook.Add('KeyPress','CFReworkUseScreen',function(p,key)
 if key~=IN_USE or not p:Alive() then return end
 if (p.CFReworkNextUse or 0)>CurTime() then return end
 for _,e in ipairs(ents.FindInSphere(p:EyePos(),180)) do
  if e:GetClass()=='sent_combine_fabricator' then
   local x,y=C.HitScreen(e,p) local slot=C.HitSlot(e,p)
   if x or slot then p.CFReworkNextUse=CurTime()+.2 e:Interact(p,x,y,slot) return end
  end
 end
end)
-- Optional left-click on the 3D screen: server recomputes gaze and ownership.
util.AddNetworkString('cf_rework_click')
net.Receive('cf_rework_click',function(_,p)
 local e=net.ReadEntity()
 if not IsValid(e) or e:GetClass()~='sent_combine_fabricator' or not p:Alive() or (p.CFReworkNextUse or 0)>CurTime() then return end
 local x,y=C.HitScreen(e,p) if not x then return end
 p.CFReworkNextUse=CurTime()+.2 e:Interact(p,x,y,nil)
end)
concommand.Add('cf_resin_give',function(p,_,args)
 if IsValid(p) and not p:IsAdmin() then return end
 local target=IsValid(p) and p or nil
 if not target then print('Use this command in an admin player console.') return end
 C.ChangeBalance(target,math.Clamp(math.floor(tonumber(args[1]) or 20),1,1000))
end)
